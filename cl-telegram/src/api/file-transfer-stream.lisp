;;; file-transfer-stream.lisp --- Streaming file transfer support
;;;
;;; Provides support for:
;;; - Stream-based file download
;;; - Stream-based file upload
;;; - Chunked transfer with callbacks
;;; - Memory-efficient large file handling
;;; - Transfer session management
;;;
;;; Version: 0.39.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Stream Classes
;;; ============================================================================

(defclass transfer-stream ()
  ((id :initarg :id :accessor transfer-stream-id
       :initform "" :documentation "Stream identifier")
   (type :initarg :type :accessor transfer-stream-type
         :initform :download :documentation "Stream type: :download or :upload")
   (file-id :initarg :file-id :accessor transfer-stream-file-id
            :initform nil :documentation "File ID for downloads")
   (file-path :initarg :file-path :accessor transfer-stream-file-path
              :initform nil :documentation "Local file path")
   (file-size :initarg :file-size :accessor transfer-stream-file-size
              :initform 0 :documentation "Total file size")
   (chunk-size :initarg :chunk-size :accessor transfer-stream-chunk-size
              :initform 65536 :documentation "Chunk size in bytes")
   (position :initarg :position :accessor transfer-stream-position
             :initform 0 :documentation "Current position in stream")
   (completed-p :initarg :completed-p :accessor transfer-stream-completed-p
                :initform nil :documentation "Whether transfer is complete")
   (cancelled-p :initarg :cancelled-p :accessor transfer-stream-cancelled-p
                :initform nil :documentation "Whether transfer was cancelled")
   (error :initarg :error :accessor transfer-stream-error
          :initform nil :documentation "Error message if any")
   (started-at :initarg :started-at :accessor transfer-stream-started-at
               :initform nil :documentation "Transfer start time")
   (completed-at :initarg :completed-at :accessor transfer-stream-completed-at
                 :initform nil :documentation "Transfer completion time")
   (data :initarg :data :accessor transfer-stream-data
         :initform nil :documentation "Optional in-memory data buffer")))

(defclass download-stream (transfer-stream)
  ((output-stream :initarg :output-stream :accessor download-stream-output
                  :initform nil :documentation "Output stream to write to")
   (dc-id :initarg :dc-id :accessor download-stream-dc-id
          :initform 0 :documentation "Datacenter ID")
   (access-hash :initarg :access-hash :accessor download-stream-access-hash
                :initform 0 :documentation "File access hash")
   (buffer :initarg :buffer :accessor download-stream-buffer
           :initform nil :documentation "Current download buffer")))

(defclass upload-stream (transfer-stream)
  ((input-stream :initarg :input-stream :accessor upload-stream-input
                 :initform nil :documentation "Input stream to read from")
   (file-name :initarg :file-name :accessor upload-stream-file-name
              :initform "" :documentation "File name")
   (mime-type :initarg :mime-type :accessor upload-stream-mime-type
              :initform "application/octet-stream" :documentation "MIME type")
   (parts :initarg :parts :accessor upload-stream-parts
          :initform nil :documentation "List of uploaded part IDs")
   (total-parts :initarg :total-parts :accessor upload-stream-total-parts
                :initform 0 :documentation "Total number of parts")
   (uploaded-parts :initarg :uploaded-parts :accessor upload-stream-uploaded-parts
                   :initform 0 :documentation "Number of parts uploaded")
   (session-id :initarg :session-id :accessor upload-stream-session-id
               :initform nil :documentation "Upload session ID")))

;;; ============================================================================
;;; Section 2: Global State
;;; ============================================================================

(defvar *active-streams* (make-hash-table :test 'equal)
  "Hash table storing active transfer streams")

(defvar *stream-chunk-size* 65536  ; 64KB
  "Default chunk size for stream transfers")

(defvar *max-stream-buffer-size* (* 10 1024 1024)  ; 10MB
  "Maximum buffer size for in-memory streams")

;;; ============================================================================
;;; Section 3: Download Stream Functions
;;; ============================================================================

(defun create-download-stream (file-id output-path &key (chunk-size nil) (dc-id nil) (access-hash nil))
  "Create a download stream for a file.

   Args:
     file-id: File ID to download
     output-path: Local path to save file (or NIL for in-memory)
     chunk-size: Chunk size in bytes (default: *stream-chunk-size*)
     dc-id: Optional datacenter ID
     access-hash: Optional file access hash

   Returns:
     download-stream object on success, NIL on failure

   Example:
     (let ((stream (create-download-stream \"AgAD1234\" \"/tmp/file.jpg\")))
       (when stream
         (loop for chunk = (read-download-chunk stream)
               while chunk
               do (process-chunk chunk))
         (close-download-stream stream)))"
  (handler-case
      (let* ((connection (get-current-connection))
             ;; Get file location first
             (file-location (get-file-location file-id))
             (actual-dc-id (or dc-id (getf file-location :dc_id) 0))
             (actual-access-hash (or access-hash (getf file-location :access_hash) 0))
             (file-size (getf file-location :size 0))
             (stream (make-instance 'download-stream
                                    :id (format nil "download_stream_~A_~A" file-id (get-universal-time))
                                    :file-id file-id
                                    :file-path output-path
                                    :file-size file-size
                                    :chunk-size (or chunk-size *stream-chunk-size*)
                                    :dc-id actual-dc-id
                                    :access-hash actual-access-hash
                                    :started-at (get-universal-time))))
        ;; Open output stream if path provided
        (when output-path
          (let ((dir (pathname-directory-pathname output-path)))
            (when dir
              (ensure-directories-exist output-path)))
          (setf (download-stream-output stream)
                (open output-path :element-type '(unsigned-byte 8)
                      :if-does-not-exist :create
                      :if-exists :supersede)))
        ;; Store in active streams
        (setf (gethash (transfer-stream-id stream) *active-streams*) stream)
        (log-message :info "Created download stream for file ~A (~A bytes)" file-id file-size)
        stream)
    (error (e)
      (log-message :error "Failed to create download stream: ~A" e)
      nil)))

(defun read-download-chunk (stream &key (callback nil))
  "Read a chunk from the download stream.

   Args:
     stream: download-stream object
     callback: Optional callback function for each chunk
               Signature: (lambda (chunk-data chunk-num total-chunks position) ...)

   Returns:
     Chunk data (simple-array (unsigned-byte 8)) or NIL if complete/error

   Example:
     (loop for chunk = (read-download-chunk stream)
           while chunk
           do (write-sequence chunk output-stream))"
  (when (or (transfer-stream-completed-p stream)
            (transfer-stream-cancelled-p stream)
            (transfer-stream-error stream))
    (return-from read-download-chunk nil))

  (handler-case
      (let* ((connection (get-current-connection))
             (position (transfer-stream-position stream))
             (limit (+ position (transfer-stream-chunk-size stream)))
             (offset position)
             (len (min (transfer-stream-chunk-size stream)
                       (- (transfer-stream-file-size stream) position))))
        (when (<= len 0)
          ;; Download complete
          (setf (transfer-stream-completed-p stream) t
                (transfer-stream-completed-at stream) (get-universal-time))
          (return-from read-download-chunk nil))

        ;; Request chunk from Telegram
        (let* ((params `(("file_id" . ,(transfer-stream-file-id stream))
                         ("offset" . ,offset)
                         ("limit" . ,len)))
               (chunk-data (make-api-call connection "getFileDownloadChunk" params)))
          (when chunk-data
            (let ((data (getf chunk-data :data)))
              ;; Update position
              (setf (transfer-stream-position stream) limit)

              ;; Write to output stream if available
              (when (and data (download-stream-output stream))
                (write-sequence data (download-stream-output stream)))

              ;; Invoke callback if provided
              (when callback
                (funcall callback data
                         (floor position (transfer-stream-chunk-size stream))
                         (ceiling (transfer-stream-file-size stream)
                                  (transfer-stream-chunk-size stream))
                         position))

              ;; Update progress notification
              (notify-download-progress (transfer-stream-id stream)
                                        limit
                                        (transfer-stream-file-size stream)
                                        :status :downloading)

              data))))
    (error (e)
      (setf (transfer-stream-error stream) (princ-to-string e))
      (log-message :error "Error reading download chunk: ~A" e)
      nil)))

(defun close-download-stream (stream)
  "Close a download stream.

   Args:
     stream: download-stream object

   Returns:
     T on success

   Example:
     (close-download-stream stream)"
  (handler-case
      (progn
        ;; Close output stream
        (when (download-stream-output stream)
          (close (download-stream-output stream)))
        ;; Remove from active streams
        (remhash (transfer-stream-id stream) *active-streams*)
        (setf (transfer-stream-completed-at stream) (get-universal-time))
        (log-message :info "Closed download stream ~A" (transfer-stream-id stream))
        t)
    (error (e)
      (log-message :error "Error closing download stream: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: Upload Stream Functions
;;; ============================================================================

(defun create-upload-stream (file-path &key (file-name nil) (mime-type nil) (chunk-size nil))
  "Create an upload stream for a file.

   Args:
     file-path: Local file path to upload
     file-name: Optional file name (defaults to pathname name)
     mime-type: Optional MIME type (auto-detected if nil)
     chunk-size: Chunk size in bytes (default: *stream-chunk-size*)

   Returns:
     upload-stream object on success, NIL on failure

   Example:
     (let ((stream (create-upload-stream \"/path/to/large_file.zip\")))
       (when stream
         (loop for chunk = (read-upload-chunk stream)
               while chunk
               do (upload-chunk stream chunk))
         (finalize-upload stream)))"
  (handler-case
      (unless (probe-file file-path)
        (log-message :error "File not found: ~A" file-path)
        (return-from create-upload-stream nil))

      (let* ((file-size (file-length file-path))
             (actual-file-name (or file-name (file-namestring file-path)))
             (actual-mime-type (or mime-type (detect-mime-type file-path)))
             (stream (make-instance 'upload-stream
                                    :id (format nil "upload_stream_~A_~A" actual-file-name (get-universal-time))
                                    :file-path file-path
                                    :file-name actual-file-name
                                    :mime-type actual-mime-type
                                    :file-size file-size
                                    :chunk-size (or chunk-size *stream-chunk-size*)
                                    :total-parts (ceiling file-size (or chunk-size *stream-chunk-size*))
                                    :started-at (get-universal-time))))
        ;; Open input stream
        (setf (upload-stream-input stream)
              (open file-path :element-type '(unsigned-byte 8)
                    :direction :input))
        ;; Create upload session
        (let ((session-id (create-upload-session actual-file-name actual-mime-type file-size)))
          (when session-id
            (setf (upload-stream-session-id stream) session-id)))
        ;; Store in active streams
        (setf (gethash (transfer-stream-id stream) *active-streams*) stream)
        (log-message :info "Created upload stream for ~A (~A bytes)" actual-file-name file-size)
        stream)
    (error (e)
      (log-message :error "Failed to create upload stream: ~A" e)
      nil)))

(defun read-upload-chunk (stream &key (callback nil))
  "Read a chunk from the upload stream.

   Args:
     stream: upload-stream object
     callback: Optional callback function for each chunk
               Signature: (lambda (chunk-data chunk-num total-chunks position) ...)

   Returns:
     Chunk data (simple-array (unsigned-byte 8)) or NIL if complete/error

   Example:
     (loop for chunk = (read-upload-chunk stream)
           while chunk
           do (upload-chunk stream chunk))"
  (when (or (transfer-stream-completed-p stream)
            (transfer-stream-cancelled-p stream)
            (transfer-stream-error stream))
    (return-from read-upload-chunk nil))

  (handler-case
      (let* ((input (upload-stream-input stream))
             (position (transfer-stream-position stream))
             (chunk-size (transfer-stream-chunk-size stream))
             (chunk-data (make-array chunk-size :element-type '(unsigned-byte 8)))
             (bytes-read (read-sequence chunk-data input)))
        (if (zerop bytes-read)
            ;; End of file
            (progn
              (setf (transfer-stream-completed-p stream) t
                    (transfer-stream-completed-at stream) (get-universal-time))
              nil)
            ;; Got data
            (progn
              (when (< bytes-read chunk-size)
                (setf chunk-data (subseq chunk-data 0 bytes-read)))
              ;; Update position
              (setf (transfer-stream-position stream) (+ position bytes-read))
              (setf (upload-stream-uploaded-parts stream)
                    (1+ (upload-stream-uploaded-parts stream)))

              ;; Invoke callback if provided
              (when callback
                (funcall callback chunk-data
                         (upload-stream-uploaded-parts stream)
                         (upload-stream-total-parts stream)
                         position))

              ;; Update progress notification
              (notify-upload-progress (transfer-stream-id stream)
                                      (transfer-stream-position stream)
                                      (transfer-stream-file-size stream)
                                      :status :uploading)

              chunk-data))))
    (error (e)
      (setf (transfer-stream-error stream) (princ-to-string e))
      (log-message :error "Error reading upload chunk: ~A" e)
      nil)))

(defun upload-chunk (stream chunk-data &key (part-num nil))
  "Upload a chunk to Telegram.

   Args:
     stream: upload-stream object
     chunk-data: Chunk data to upload
     part-num: Optional part number (auto-incremented if nil)

   Returns:
     Part ID on success, NIL on failure

   Example:
     (let ((part-id (upload-chunk stream chunk-data)))
       (when part-id
         (push part-id (upload-stream-parts stream))))"
  (handler-case
      (let* ((connection (get-current-connection))
             (part (or part-num (upload-stream-uploaded-parts stream)))
             (params `(("file_id" . ,(upload-stream-session-id stream))
                       ("file_part" . ,part)
                       ("file_total_parts" . ,(upload-stream-total-parts stream)))))
        ;; Add chunk data
        (push (cons "bytes" (cl-base64:usb8-array-to-base64 chunk-data)) params)

        (let ((result (make-api-call connection "uploadFilePart" params)))
          (when result
            (let ((part-id (getf result :file_part_id)))
              (push part-id (upload-stream-parts stream))
              part-id))))
    (error (e)
      (log-message :error "Error uploading chunk: ~A" e)
      nil)))

(defun finalize-upload (stream &key (file-id nil))
  "Finalize an upload stream.

   Args:
     stream: upload-stream object
     file-id: Optional existing file ID to associate with

   Returns:
     File ID on success, NIL on failure

   Example:
     (let ((file-id (finalize-upload stream)))
       (when file-id
         (send-photo chat-id file-id)))"
  (handler-case
      (progn
        ;; Close input stream
        (when (upload-stream-input stream)
          (close (upload-stream-input stream)))
        ;; Save file if all parts uploaded
        (if (= (upload-stream-uploaded-parts stream) (upload-stream-total-parts stream))
            (let* ((connection (get-current-connection))
                   (params `(("file_id" . ,(upload-stream-session-id stream))
                             ("file_name" . ,(upload-stream-file-name stream))
                             ("mime_type" . ,(upload-stream-mime-type))))
                   (result (make-api-call connection "saveFilePartList" params)))
              (when result
                (let ((saved-file-id (getf result :file_id)))
                  (log-message :info "Upload finalized: ~A" saved-file-id)
                  saved-file-id)))
            (progn
              (log-message :error "Upload incomplete: ~A/~A parts"
                           (upload-stream-uploaded-parts stream)
                           (upload-stream-total-parts stream))
              nil)))
    (error (e)
      (log-message :error "Error finalizing upload: ~A" e)
      nil)))

(defun close-upload-stream (stream)
  "Close an upload stream.

   Args:
     stream: upload-stream object

   Returns:
     T on success"
  (handler-case
      (progn
        ;; Close input stream if still open
        (when (and (upload-stream-input stream)
                   (open-stream-p (upload-stream-input stream)))
          (close (upload-stream-input stream)))
        ;; Remove from active streams
        (remhash (transfer-stream-id stream) *active-streams*)
        (setf (transfer-stream-completed-at stream) (get-universal-time))
        (log-message :info "Closed upload stream ~A" (transfer-stream-id stream))
        t)
    (error (e)
      (log-message :error "Error closing upload stream: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 5: Stream Control Functions
;;; ============================================================================

(defun cancel-transfer-stream (stream &key (reason "User cancelled"))
  "Cancel a transfer stream.

   Args:
     stream: transfer-stream object
     reason: Cancellation reason

   Returns:
     T on success"
  (setf (transfer-stream-cancelled-p stream) t
        (transfer-stream-error stream) reason)
  (remhash (transfer-stream-id stream) *active-streams*)
  (log-message :info "Cancelled transfer stream ~A: ~A"
               (transfer-stream-id stream) reason)
  t)

(defun pause-transfer-stream (stream)
  "Pause a transfer stream.

   Args:
     stream: transfer-stream object

   Returns:
     T on success"
  ;; Mark for pause - actual pausing happens in read/write loop
  (setf (gethash (format nil "~A-paused" (transfer-stream-id stream)) *active-streams*) t)
  (log-message :info "Paused transfer stream ~A" (transfer-stream-id stream))
  t)

(defun resume-transfer-stream (stream)
  "Resume a paused transfer stream.

   Args:
     stream: transfer-stream object

   Returns:
     T on success"
  (remhash (format nil "~A-paused" (transfer-stream-id stream)) *active-streams*)
  (log-message :info "Resumed transfer stream ~A" (transfer-stream-id stream))
  t)

(defun stream-transfer-status (stream)
  "Get the status of a transfer stream.

   Args:
     stream: transfer-stream object

   Returns:
     Keyword: :pending, :downloading, :uploading, :paused, :completed, :cancelled, :error

   Example:
     (stream-transfer-status stream) => :downloading"
  (cond
    ((transfer-stream-cancelled-p stream) :cancelled)
    ((transfer-stream-error stream) :error)
    ((transfer-stream-completed-p stream) :completed)
    ((gethash (format nil "~A-paused" (transfer-stream-id stream)) *active-streams*) :paused)
    ((eq (transfer-stream-type stream) :download) :downloading)
    ((eq (transfer-stream-type stream) :upload) :uploading)
    (t :pending)))

;;; ============================================================================
;;; Section 6: Stream Utilities
;;; ============================================================================

(defun get-stream (stream-id)
  "Get a transfer stream by ID.

   Args:
     stream-id: Stream identifier

   Returns:
     transfer-stream object or NIL"
  (gethash stream-id *active-streams*))

(defun list-active-streams ()
  "List all active transfer streams.

   Returns:
     List of transfer-stream objects"
  (let ((streams '()))
    (maphash (lambda (id stream)
               (declare (ignore id))
               (push stream streams))
             *active-streams*)
    (nreverse streams)))

(defun cleanup-completed-streams ()
  "Cleanup completed transfer streams.

   Returns:
     Number of streams cleaned up"
  (let ((count 0))
    (maphash (lambda (id stream)
               (when (or (transfer-stream-completed-p stream)
                         (transfer-stream-cancelled-p stream)
                         (transfer-stream-error stream))
                 (close-transfer-stream stream)
                 (incf count)))
             *active-streams*)
    count))

(defun close-transfer-stream (stream)
  "Close a transfer stream (generic).

   Args:
     stream: transfer-stream object

   Returns:
     T on success"
  (if (typep stream 'download-stream)
      (close-download-stream stream)
      (close-upload-stream stream)))

;;; ============================================================================
;;; Section 7: High-Level Stream API
;;; ============================================================================

(defun with-download-stream ((stream-var file-id output-path &key (chunk-size nil)) &body body)
  "Macro for safe download stream handling.

   Args:
     stream-var: Variable to bind stream to
     file-id: File ID to download
     output-path: Output file path
     chunk-size: Optional chunk size

   Example:
     (with-download-stream (stream \"AgAD1234\" \"/tmp/file.jpg\")
       (loop for chunk = (read-download-chunk stream)
             while chunk
             do (process-chunk chunk)))"
  `(let ((,stream-var (create-download-stream ,file-id ,output-path :chunk-size ,chunk-size)))
     (unwind-protect
          (progn ,@body)
       (when ,stream-var
         (close-download-stream ,stream-var)))))

(defun with-upload-stream ((stream-var file-path &key (file-name nil) (mime-type nil)) &body body)
  "Macro for safe upload stream handling.

   Args:
     stream-var: Variable to bind stream to
     file-path: File path to upload
     file-name: Optional file name
     mime-type: Optional MIME type

   Example:
     (with-upload-stream (stream \"/path/to/file.zip\")
       (loop for chunk = (read-upload-chunk stream)
             while chunk
             do (upload-chunk stream chunk))
       (finalize-upload stream))"
  `(let ((,stream-var (create-upload-stream ,file-path
                                           :file-name ,file-name
                                           :mime-type ,mime-type)))
     (unwind-protect
          (progn ,@body)
       (when ,stream-var
         (close-upload-stream ,stream-var)))))

;;; End of file-transfer-stream.lisp
