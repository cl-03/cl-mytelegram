;;; file-management.lisp --- File upload and download management
;;;
;;; Provides support for:
;;; - File download with location resolution
;;; - Large file upload with part management
;;; - Web file retrieval from URLs
;;; - Media file upload and download
;;; - File CDN integration

(in-package #:cl-telegram/api)

;;; ### File Types

(defclass file-location ()
  ((dc-id :initarg :dc-id :initform 0 :accessor file-location-dc-id)
   (volume-id :initarg :volume-id :initform 0 :accessor file-location-volume-id)
   (local-id :initarg :local-id :initform 0 :accessor file-location-local-id)
   (secret :initarg :secret :initform 0 :accessor file-location-secret)
   (file-reference :initarg :file-reference :initform nil :accessor file-location-file-reference)))

(defclass uploaded-file ()
  ((file-id :initarg :file-id :reader uploaded-file-id)
   (file-parts :initarg :file-parts :reader uploaded-file-parts)
   (file-size :initarg :file-size :reader uploaded-file-size)
   (file-path :initarg :file-path :reader uploaded-file-path)))

(defclass web-file ()
  ((location :initarg :location :reader web-file-location)
   (access-hash :initarg :access-hash :reader web-file-access-hash)
   (size :initarg :size :reader web-file-size)
   (mime-type :initarg :mime-type :reader web-file-mime-type)
   (dc-id :initarg :dc-id :reader web-file-dc-id)))

;;; ### Global State

(defvar *file-download-queue* (make-hash-table :test 'equal)
  "Queue for pending file downloads")

(defvar *active-uploads* (make-hash-table :test 'equal)
  "Active file upload sessions")

(defvar *download-part-size* 524288 ; 512KB
  "Default part size for downloads")

(defvar *upload-part-size* 524288 ; 512KB
  "Default part size for uploads")

(defvar *max-upload-parts* 4000
  "Maximum number of parts for big file upload")

(defvar *cdn-download-enabled* t
  "Whether to use CDN for downloads")

;;; ============================================================================
;;; ### File Download
;;; ============================================================================

(defun get-file-location (file-id)
  "Get file location from file ID.

   Args:
     file-id: File identifier

   Returns:
     File-location object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getMedia
                                      :id (list file-id))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (let* ((media (getf result :media))
                   (doc (getf media :document)))
              (when doc
                (let ((location (getf doc :dc-id)))
                  (make-instance 'file-location
                                 :dc-id location
                                 :volume-id (getf doc :volume-id 0)
                                 :local-id (getf doc :local-id 0)
                                 :secret (getf doc :access-hash 0)
                                 :file-reference (getf doc :file-reference nil)))))))
          (t (c)
            (log-error "Get file location failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in get-file-location: ~A" c)
      nil)))

(defun download-file (file-id &key (output-path nil) (dc-id nil))
  "Download a file from Telegram.

   Args:
     file-id: File identifier
     output-path: Optional path to save file
     dc-id: Optional DC ID for CDN download

   Returns:
     File data as byte vector or saved path"
  (handler-case
      (let* ((location (get-file-location file-id))
             (target-dc (or dc-id (file-location-dc-id location))))
        (unless location
          (return-from download-file (values nil "Failed to get file location")))

        ;; Get connection to target DC
        (let* ((connection (get-connection-for-dc target-dc))
               (file-size 0)
               (downloaded-data nil)
               (offset 0)
               (limit *download-part-size*))

          ;; First request to get file size
          (let ((request (make-tl-object 'upload.getFile
                                         :location (make-tl-object 'inputDocumentFileLocation
                                                                   :dc-id (file-location-dc-id location)
                                                                   :volume-id (file-location-volume-id location)
                                                                   :local-id (file-location-local-id location)
                                                                   :secret (file-location-secret location))
                                         :offset 0
                                         :limit 1)))
            (let ((result (rpc-call connection request :timeout 10000)))
              (when (and result (getf result :type))
                (setf file-size (getf (getf result :type) :size 0)))))

          ;; Download file in parts
          (setf downloaded-data (make-array file-size :element-type '(unsigned-byte 8)))
          (setf offset 0)

          (loop while (< offset file-size)
                do (let* ((bytes-to-read (min limit (- file-size offset)))
                          (request (make-tl-object 'upload.getFile
                                                   :location (make-tl-object 'inputDocumentFileLocation
                                                                             :dc-id (file-location-dc-id location)
                                                                             :volume-id (file-location-volume-id location)
                                                                             :local-id (file-location-local-id location)
                                                                             :secret (file-location-secret location))
                                                   :offset offset
                                                   :limit bytes-to-read)))
                     (let ((result (rpc-call connection request :timeout 30000)))
                       (when (and result (getf result :bytes))
                         (let ((part-data (getf result :bytes)))
                           (replace downloaded-data part-data :start1 offset)
                           (incf offset (length part-data)))))))

          ;; Save to file if path provided
          (if output-path
              (progn
                (with-open-file (stream output-path :direction :output
                                                    :element-type '(unsigned-byte 8)
                                                    :if-exists :supersede)
                  (write-sequence downloaded-data stream))
                (values output-path nil))
              (values downloaded-data nil)))))
    (t (c)
      (log-error "Download file failed: ~A" c)
      (values nil (format nil "Download error: ~A" c)))))

(defun download-file-partial (file-id offset limit &key (dc-id nil))
  "Download a portion of a file.

   Args:
     file-id: File identifier
     offset: Starting byte offset
     limit: Number of bytes to download
     dc-id: Optional DC ID

   Returns:
     Byte vector of downloaded data"
  (handler-case
      (let* ((location (get-file-location file-id))
             (target-dc (or dc-id (file-location-dc-id location))))
        (unless location
          (return-from download-file-partial nil))

        (let* ((connection (get-connection-for-dc target-dc))
               (request (make-tl-object 'upload.getFile
                                        :location (make-tl-object 'inputDocumentFileLocation
                                                                  :dc-id (file-location-dc-id location)
                                                                  :volume-id (file-location-volume-id location)
                                                                  :local-id (file-location-local-id location)
                                                                  :secret (file-location-secret location))
                                        :offset offset
                                        :limit limit)))
          (let ((result (rpc-call connection request :timeout 30000)))
            (when (and result (getf result :bytes))
              (getf result :bytes)))))
    (t (c)
      (log-error "Partial download failed: ~A" c)
      nil)))

;;; ============================================================================
;;; ### File Upload
;;; ============================================================================

(defun upload-file (file-path &key (file-name nil) (mime-type nil) (dc-id nil))
  "Upload a file to Telegram.

   Args:
     file-path: Path to file to upload
     file-name: Optional file name
     mime-type: Optional MIME type
     dc-id: Optional DC ID for upload

   Returns:
     Uploaded-file object or NIL on error"
  (unless (probe-file file-path)
    (return-from upload-file (values nil "File not found")))

  (let* ((file-size (file-length file-path))
         (name (or file-name (file-namestring file-path)))
         (mime (or mime-type (guess-mime-type file-path))))

    ;; Check if file is small enough for single-part upload
    (if (< file-size (* 10 1024 1024)) ; 10MB
        ;; Small file upload
        (upload-file-small file-path name mime dc-id)
        ;; Large file upload (split into parts)
        (upload-file-large file-path name mime dc-id))))

(defun upload-file-small (file-path file-name mime-type dc-id)
  "Upload a small file (< 10MB) in a single request.

   Args:
     file-path: Path to file
     file-name: File name
     mime-type: MIME type
     dc-id: Target DC ID

   Returns:
     Uploaded-file object"
  (handler-case
      (let* ((connection (if dc-id
                             (get-connection-for-dc dc-id)
                             (get-connection)))
             (file-data (alexandria:read-file-into-byte-vector file-path))
             (request (make-tl-object 'messages.uploadMedia
                                      :peer (make-tl-object 'inputPeerSelf)
                                      :file (make-tl-object 'inputFile
                                                            :name file-name
                                                            :parts (list file-data))
                                      :mime-type mime-type)))
        (rpc-handler-case (rpc-call connection request :timeout 60000)
          (:no-error (result)
            (when (and result (getf result :id))
              (make-instance 'uploaded-file
                             :file-id (getf result :id)
                             :file-parts 1
                             :file-size (length file-data)
                             :file-path file-path)))
          (t (c)
            (log-error "Small file upload failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in upload-file-small: ~A" c)
      nil)))

(defun upload-file-large (file-path file-name mime-type dc-id)
  "Upload a large file (>= 10MB) using part upload.

   Args:
     file-path: Path to file
     file-name: File name
     mime-type: MIME type
     dc-id: Target DC ID

   Returns:
     Uploaded-file object"
  (let* ((file-size (file-length file-path))
         (part-size *upload-part-size*)
         (total-parts (ceiling file-size part-size))
         (file-id (random (expt 2 63)))
         (connection (if dc-id
                         (get-connection-for-dc dc-id)
                         (get-connection))))

    ;; Create upload session
    (setf (gethash file-id *active-uploads*)
          (list :file-path file-path
                :file-name file-name
                :file-size file-size
                :part-size part-size
                :total-parts total-parts
                :uploaded-parts 0
                :start-time (get-universal-time)))

    ;; Upload parts
    (with-open-file (stream file-path :element-type '(unsigned-byte 8))
      (loop for part-index from 0 below total-parts
            do (let* ((offset (* part-index part-size))
                      (buffer (make-array part-size :element-type '(unsigned-byte 8)))
                      (bytes-read (read-sequence buffer stream)))
                 (when (< bytes-read part-size)
                   (setf buffer (subseq buffer 0 bytes-read)))

                 ;; Upload part
                 (let ((request (make-tl-object 'upload.saveBigFilePart
                                                :file-id file-id
                                                :file-part part-index
                                                :file-name file-name
                                                :file-parts total-parts
                                                :bytes buffer)))
                   (rpc-call connection request :timeout 30000))

                 (incf (getf (gethash file-id *active-uploads*) :uploaded-parts))))

    ;; Complete upload
    (let ((uploaded-file (make-instance 'uploaded-file
                                        :file-id file-id
                                        :file-parts total-parts
                                        :file-size file-size
                                        :file-path file-path)))
      ;; Clean up session
      (remhash file-id *active-uploads*)
      uploaded-file)))

;;; ============================================================================
;;; ### Web File Retrieval
;;; ============================================================================

(defun get-web-file (url &key (dc-id nil))
  "Get file from a URL (for bots and web files).

   Args:
     url: URL of the file
     dc-id: Optional DC ID

   Returns:
     Web-file object or NIL on error"
  (handler-case
      (let* ((connection (if dc-id
                             (get-connection-for-dc dc-id)
                             (get-connection)))
             (request (make-tl-object 'messages.getWebFile
                                      :web-file-id url)))
        (rpc-handler-case (rpc-call connection request :timeout 30000)
          (:no-error (result)
            (when (and result (getf result :location))
              (make-instance 'web-file
                             :location (getf result :location)
                             :access-hash (getf result :access-hash)
                             :size (getf result :size)
                             :mime-type (getf result :mime-type)
                             :dc-id (getf result :dc-id))))
          (t (c)
            (log-error "Get web file failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in get-web-file: ~A" c)
      nil)))

;;; ============================================================================
;;; ### Media File Management
;;; ============================================================================

(defun upload-media (file-path &key (caption nil) (media-type :auto))
  "Upload media file (photo, video, document, audio).

   Args:
     file-path: Path to media file
     caption: Optional caption
     media-type: Media type (:photo, :video, :document, :audio, :auto)

   Returns:
     Media object for use in send-message"
  (let* ((uploaded (upload-file file-path))
         (mime-type (guess-mime-type file-path))
         (media-type (if (eq media-type :auto)
                         (determine-media-type mime-type)
                         media-type)))

    (case media-type
      (:photo
       (make-tl-object 'inputMediaUploadedPhoto
                       :file (getf uploaded :file-id)
                       :caption (or caption "")))
      (:video
       (make-tl-object 'inputMediaUploadedDocument
                       :file (getf uploaded :file-id)
                       :mime-type "video/mp4"
                       :caption (or caption "")
                       :attributes (list (make-tl-object 'documentAttributeVideo
                                                         :duration 0
                                                         :w 640
                                                         :h 480))))
      (:audio
       (make-tl-object 'inputMediaUploadedDocument
                       :file (getf uploaded :file-id)
                       :mime-type "audio/mpeg"
                       :caption (or caption "")
                       :attributes (list (make-tl-object 'documentAttributeAudio
                                                         :duration 0
                                                         :voice nil))))
      (:document
       (make-tl-object 'inputMediaUploadedDocument
                       :file (getf uploaded :file-id)
                       :mime-type mime-type
                       :caption (or caption "")))
      (t nil))))

(defun download-media (media-id &key (output-path nil))
  "Download media file.

   Args:
     media-id: Media identifier
     output-path: Optional output path

   Returns:
     File data or saved path"
  (download-file media-id :output-path output-path))

(defun determine-media-type (mime-type)
  "Determine media type from MIME type.

   Args:
     mime-type: MIME type string

   Returns:
     Keyword symbol of media type"
  (cond
    ((search "image/" mime-type) :photo)
    ((search "video/" mime-type) :video)
    ((search "audio/" mime-type) :audio)
    (t :document)))

(defun guess-mime-type (file-path)
  "Guess MIME type from file extension.

   Args:
     file-path: File path

   Returns:
     MIME type string"
  (let ((ext (pathname-type file-path)))
    (case (intern (string-upcase ext) :keyword)
      (:jpg "image/jpeg")
      (:jpeg "image/jpeg")
      (:png "image/png")
      (:gif "image/gif")
      (:mp4 "video/mp4")
      (:webm "video/webm")
      (:mp3 "audio/mpeg")
      (:ogg "audio/ogg")
      (:pdf "application/pdf")
      (:doc "application/msword")
      (:docx "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
      (:txt "text/plain")
      (t "application/octet-stream"))))

;;; ============================================================================
;;; ### Upload Session Management
;;; ============================================================================

(defun get-upload-session (file-id)
  "Get upload session information.

   Args:
     file-id: File identifier

   Returns:
     Upload session plist or NIL"
  (gethash file-id *active-uploads*))

(defun cancel-upload (file-id)
  "Cancel an active upload.

   Args:
     file-id: File identifier

   Returns:
     T on success"
  (remhash file-id *active-uploads*)
  t)

(defun get-upload-progress (file-id)
  "Get upload progress percentage.

   Args:
     file-id: File identifier

   Returns:
     Progress percentage (0-100) or NIL"
  (let ((session (gethash file-id *active-uploads*)))
    (when session
      (let ((uploaded (getf session :uploaded-parts))
            (total (getf session :total-parts)))
        (if (plusp total)
            (* 100.0 (/ uploaded total))
            0)))))

(defun get-active-uploads ()
  "Get all active upload sessions.

   Returns:
     List of upload session plists"
  (loop for file-id being the hash-keys of *active-uploads*
        collect (cons file-id (gethash file-id *active-uploads*))))

;;; ============================================================================
;;; ### CDN Integration
;;; ============================================================================

(defun enable-cdn-download ()
  "Enable CDN for file downloads.

   Returns:
     T on success"
  (setf *cdn-download-enabled* t)
  t)

(defun disable-cdn-download ()
  "Disable CDN for file downloads.

   Returns:
     T on success"
  (setf *cdn-download-enabled* nil)
  t)

(defun cdn-download-enabled-p ()
  "Check if CDN download is enabled.

   Returns:
     T if enabled, NIL otherwise"
  *cdn-download-enabled*)

(defun set-cdn-config (&key (enabled t) (preferred-dc nil))
  "Configure CDN settings.

   Args:
     enabled: Whether CDN is enabled
     preferred-dc: Preferred DC for CDN

   Returns:
     T on success"
  (setf *cdn-download-enabled* enabled)
  t)

;;; ============================================================================
;;; ### File Utilities
;;; ============================================================================

(defun file-size-string (file-size)
  "Get human-readable file size string.

   Args:
     file-size: Size in bytes

   Returns:
     Formatted string (e.g., \"1.5 MB\")"
  (cond
    ((< file-size 1024) (format nil "~A B" file-size))
    ((< file-size (* 1024 1024)) (format nil "~,2F KB" (/ file-size 1024.0)))
    ((< file-size (* 1024 1024 1024)) (format nil "~,2F MB" (/ file-size (* 1024.0 1024.0))))
    (t (format nil "~,2F GB" (/ file-size (* 1024.0 1024.0 1024.0))))))

(defun format-upload-speed (bytes-per-second)
  "Get human-readable upload speed string.

   Args:
     bytes-per-second: Speed in bytes/second

   Returns:
     Formatted string"
  (cond
    ((< bytes-per-second 1024) (format nil "~A B/s" bytes-per-second))
    ((< bytes-per-second (* 1024 1024)) (format nil "~,2F KB/s" (/ bytes-per-second 1024.0)))
    (t (format nil "~,2F MB/s" (/ bytes-per-second (* 1024.0 1024.0))))))

(defun estimate-upload-time (file-size &key (current-speed nil))
  "Estimate upload time based on average speed.

   Args:
     file-size: File size in bytes
     current-speed: Current upload speed (bytes/sec)

   Returns:
     Estimated time in seconds"
  (let ((speed (or current-speed 1048576))) ; Default 1MB/s
    (ceiling file-size speed)))

;;; Export symbols
(export '(;; Classes
          file-location
          uploaded-file
          web-file

          ;; File Location
          get-file-location

          ;; Download
          download-file
          download-file-partial
          download-media

          ;; Upload
          upload-file
          upload-file-small
          upload-file-large
          upload-media

          ;; Web File
          get-web-file

          ;; Session Management
          get-upload-session
          cancel-upload
          get-upload-progress
          get-active-uploads

          ;; CDN
          enable-cdn-download
          disable-cdn-download
          cdn-download-enabled-p
          set-cdn-config

          ;; Utilities
          file-size-string
          format-upload-speed
          estimate-upload-time
          determine-media-type
          guess-mime-type

          ;; Configuration
          *file-download-queue*
          *active-uploads*
          *download-part-size*
          *upload-part-size*
          *max-upload-parts*
          *cdn-download-enabled*))
