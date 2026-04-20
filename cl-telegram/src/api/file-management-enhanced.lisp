;;; file-management-enhanced.lisp --- Enhanced file management for v0.31.0
;;;
;;; Provides support for:
;;; - Chunked file upload with progress tracking
;;; - File download with resume capability
;;; - Media metadata extraction
;;; - File cache management
;;; - Upload/download queue management
;;;
;;; Version: 0.31.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Enhanced File Upload
;;; ============================================================================

(defclass upload-session ()
  ((file-id :initarg :file-id :accessor upload-session-file-id)
   (file-path :initarg :file-path :accessor upload-session-file-path)
   (file-name :initarg :file-name :accessor upload-session-file-name)
   (file-size :initarg :file-size :accessor upload-session-file-size)
   (part-size :initarg :part-size :accessor upload-session-part-size)
   (total-parts :initarg :total-parts :accessor upload-session-total-parts)
   (uploaded-parts :initarg :uploaded-parts :initform 0 :accessor upload-session-uploaded-parts)
   (uploaded-hashes :initarg :uploaded-hashes :initform (make-hash-table) :accessor upload-session-uploaded-hashes)
   (start-time :initarg :start-time :accessor upload-session-start-time)
   (last-activity :initarg :last-activity :accessor upload-session-last-activity)
   (status :initarg :status :initform :pending :accessor upload-session-status)
   (error :initarg :error :initform nil :accessor upload-session-error)
   (callback :initarg :callback :initform nil :accessor upload-session-callback)
   (lock :initform (bt:make-lock) :accessor upload-session-lock)))

(defvar *upload-sessions* (make-hash-table :test 'equal)
  "Hash table storing upload sessions")

(defvar *max-concurrent-uploads* 4
  "Maximum number of concurrent uploads")

(defvar *default-chunk-size* 524288 ; 512KB
  "Default chunk size for uploads")

(defun make-upload-session (file-path &key (chunk-size *default-chunk-size*) callback)
  "Create a new upload session.

   Args:
     file-path: Path to file to upload
     chunk-size: Size of each chunk in bytes (default: 512KB)
     callback: Optional callback function for progress updates

   Returns:
     Upload-session instance

   Example:
     (make-upload-session \"/path/to/file.zip\" :callback #'update-ui)"
  (let* ((file-size (file-length file-path))
         (total-parts (ceiling file-size chunk-size))
         (file-id (format nil "upload_~A_~A" (get-universal-time) (random (expt 2 32))))
         (session (make-instance 'upload-session
                                 :file-id file-id
                                 :file-path file-path
                                 :file-name (file-namestring file-path)
                                 :file-size file-size
                                 :part-size chunk-size
                                 :total-parts total-parts
                                 :start-time (get-universal-time)
                                 :last-activity (get-universal-time)
                                 :callback callback)))
    (setf (gethash file-id *upload-sessions*) session)
    (log:info "Upload session created: ~A (size=~A, parts=~D)" file-id file-size total-parts)
    session))

(defun upload-file-chunk (session-id chunk-index chunk-data &key (is-last nil))
  "Upload a single chunk of a file.

   Args:
     session-id: Upload session identifier
     chunk-index: Index of chunk (0-based)
     chunk-data: Byte vector of chunk data
     is-last: Whether this is the last chunk

   Returns:
     T on success, NIL on error

   Example:
     (upload-file-chunk session-id 0 chunk-data)"
  (let ((session (gethash session-id *upload-sessions*)))
    (unless session
      (return-from upload-file-chunk (values nil "Session not found")))

    (bt:with-lock-held ((upload-session-lock session))
      (handler-case
          (let* ((connection (get-connection))
                 (request (make-tl-object 'upload.saveBigFilePart
                                          :file-id (parse-integer (subseq session-id 7))
                                          :file-part chunk-index
                                          :file-name (upload-session-file-name session)
                                          :file-parts (upload-session-total-parts session)
                                          :bytes chunk-data)))
            (let ((result (rpc-call connection request :timeout 30000)))
              (when result
                ;; Mark chunk as uploaded
                (setf (gethash chunk-index (upload-session-uploaded-hashes session)) t)
                (incf (upload-session-uploaded-parts session))
                (setf (upload-session-last-activity session) (get-universal-time))

                ;; Call progress callback if provided
                (when (upload-session-callback session)
                  (handler-case
                      (funcall (upload-session-callback session)
                               :progress (/ (upload-session-uploaded-parts session)
                                           (upload-session-total-parts session))
                               :uploaded (upload-session-uploaded-parts session)
                               :total (upload-session-total-parts session))
                    (t (e)
                      (log:warn "Upload callback error: ~A" e))))

                (log:debug "Chunk ~D uploaded (~,1F%)" chunk-index
                          (* 100.0 (/ (upload-session-uploaded-parts session)
                                     (upload-session-total-parts session))))
                t)))
        (t (e)
          (log:error "Chunk upload failed: ~A" e)
          (setf (upload-session-error session) (format nil "Chunk ~D failed: ~A" chunk-index e))
          (values nil e))))))

(defun get-upload-status (session-id)
  "Get upload session status.

   Args:
     session-id: Upload session identifier

   Returns:
     Plist with status information

   Example:
     (get-upload-status \"upload_123\")"
  (let ((session (gethash session-id *upload-sessions*)))
    (unless session
      (return-from get-upload-status nil))

    (let ((uploaded (upload-session-uploaded-parts session))
          (total (upload-session-total-parts session))
          (start (upload-session-start-time session))
          (now (get-universal-time)))
      (list :session-id session-id
            :file-name (upload-session-file-name session)
            :file-size (upload-session-file-size session)
            :uploaded-parts uploaded
            :total-parts total
            :progress (if (plusp total) (* 100.0 (/ uploaded total)) 0)
            :status (upload-session-status session)
            :error (upload-session-error session)
            :elapsed-seconds (- now start)
            :speed-bps (if (> (- now start) 0)
                          (/ (* (upload-session-file-size session) 8)
                             (- now start))
                          0)))))

(defun cancel-upload-session (session-id)
  "Cancel an upload session.

   Args:
     session-id: Upload session identifier

   Returns:
     T on success

   Example:
     (cancel-upload-session \"upload_123\")"
  (let ((session (gethash session-id *upload-sessions*)))
    (unless session
      (return-from cancel-upload-session nil))

    (bt:with-lock-held ((upload-session-lock session))
      (setf (upload-session-status session) :cancelled)
      (remhash session-id *upload-sessions*))

    (log:info "Upload session cancelled: ~A" session-id)
    t))

(defun complete-upload-session (session-id)
  "Complete an upload session and get the uploaded file reference.

   Args:
     session-id: Upload session identifier

   Returns:
     File reference plist on success

   Example:
     (complete-upload-session \"upload_123\")"
  (let ((session (gethash session-id *upload-sessions*)))
    (unless session
      (return-from complete-upload-session (values nil "Session not found")))

    ;; Check if all parts are uploaded
    (let ((uploaded (upload-session-uploaded-parts session))
          (total (upload-session-total-parts session)))
      (unless (= uploaded total)
        (return-from complete-upload-session
          (values nil (format nil "Incomplete upload: ~D/~D parts" uploaded total)))))

    ;; Get file reference
    (handler-case
        (let* ((connection (get-connection))
               (file-id (parse-integer (subseq session-id 7)))
               (request (make-tl-object 'upload.getFile
                                        :location (make-tl-object 'inputFileBig
                                                                  :id file-id
                                                                  :parts total
                                                                  :file-reference (upload-session-file-name session))
                                        :offset 0
                                        :limit 1)))
          (let ((result (rpc-call connection request :timeout 10000)))
            (setf (upload-session-status session) :completed)
            (remhash session-id *upload-sessions*)
            (log:info "Upload session completed: ~A" session-id)
            result))
      (t (e)
        (log:error "Complete upload failed: ~A" e)
        (values nil e)))))

;;; ============================================================================
;;; Section 2: Enhanced File Download with Resume
;;; ============================================================================

(defclass download-session ()
  ((file-id :initarg :file-id :accessor download-session-file-id)
   (file-location :initarg :file-location :accessor download-session-file-location)
   (file-size :initarg :file-size :accessor download-session-file-size)
   (downloaded-size :initarg :downloaded-size :initform 0 :accessor download-session-downloaded-size)
   (output-path :initarg :output-path :accessor download-session-output-path)
   (downloaded-chunks :initarg :downloaded-chunks :initform (make-hash-table) :accessor download-session-downloaded-chunks)
   (start-time :initarg :start-time :accessor download-session-start-time)
   (last-activity :initarg :last-activity :accessor download-session-last-activity)
   (status :initarg :status :initform :pending :accessor download-session-status)
   (error :initarg :error :initform nil :accessor download-session-error)
   (callback :initarg :callback :initform nil :accessor download-session-callback)
   (lock :initform (bt:make-lock) :accessor download-session-lock)))

(defvar *download-sessions* (make-hash-table :test 'equal)
  "Hash table storing download sessions")

(defvar *max-concurrent-downloads* 4
  "Maximum number of concurrent downloads")

(defun make-download-session (file-id output-path &key callback)
  "Create a new download session.

   Args:
     file-id: File identifier to download
     output-path: Path to save file
     callback: Optional callback for progress updates

   Returns:
     Download-session instance

   Example:
     (make-download-session \"AgAD1234\" \"/tmp/file.zip\" :callback #'update-ui)"
  (let* ((session-id (format nil "download_~A_~A" (get-universal-time) (random (expt 2 32))))
         (session (make-instance 'download-session
                                 :file-id file-id
                                 :output-path output-path
                                 :start-time (get-universal-time)
                                 :last-activity (get-universal-time)
                                 :callback callback)))
    (setf (gethash session-id *download-sessions*) session)

    ;; Get file location and size
    (let ((location (get-file-location file-id)))
      (when location
        (setf (download-session-file-location session) location)
        ;; Get file size from first byte
        (let ((connection (get-connection)))
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
                (setf (download-session-file-size session)
                      (getf (getf result :type) :size 0))))))))

    (log:info "Download session created: ~A (file=~A)" session-id file-id)
    session))

(defun download-file-chunk (session-id offset limit &key (force nil))
  "Download a chunk of a file.

   Args:
     session-id: Download session identifier
     offset: Byte offset to start downloading
     limit: Number of bytes to download
     force: Force download even if chunk exists

   Returns:
     Chunk data on success, NIL on error

   Example:
     (download-file-chunk session-id 0 524288)"
  (let ((session (gethash session-id *download-sessions*)))
    (unless session
      (return-from download-file-chunk (values nil "Session not found")))

    ;; Check if chunk already downloaded
    (let ((chunk-key (format nil "~D_~D" offset limit)))
      (unless force
        (when (gethash chunk-key (download-session-downloaded-chunks session))
          (return-from download-file-chunk :already-downloaded))))

    (bt:with-lock-held ((download-session-lock session))
      (handler-case
          (let* ((location (download-session-file-location session))
                 (connection (get-connection-for-dc (file-location-dc-id location)))
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
                (let ((chunk-data (getf result :bytes)))
                  ;; Mark chunk as downloaded
                  (setf (gethash chunk-key (download-session-downloaded-chunks session)) t)
                  (incf (download-session-downloaded-size session) (length chunk-data))
                  (setf (download-session-last-activity session) (get-universal-time))

                  ;; Append to output file
                  (with-open-file (stream (download-session-output-path session)
                                          :direction :output
                                          :element-type '(unsigned-byte 8)
                                          :if-exists :append
                                          :if-does-not-exist :create)
                    (write-sequence chunk-data stream))

                  ;; Call progress callback
                  (when (download-session-callback session)
                    (handler-case
                        (funcall (download-session-callback session)
                                 :progress (/ (download-session-downloaded-size session)
                                             (download-session-file-size session))
                                 :downloaded (download-session-downloaded-size session)
                                 :total (download-session-file-size session))
                      (t (e)
                        (log:warn "Download callback error: ~A" e))))

                  chunk-data)))))
        (t (e)
          (log:error "Chunk download failed: ~A" e)
          (setf (download-session-error session) (format nil "Chunk at ~D failed: ~A" offset e))
          (values nil e))))))

(defun resume-download (session-id)
  "Resume a paused or failed download.

   Args:
     session-id: Download session identifier

   Returns:
     T on success

   Example:
     (resume-download \"download_123\")"
  (let ((session (gethash session-id *download-sessions*)))
    (unless session
      (return-from resume-download (values nil "Session not found")))

    (setf (download-session-status session) :downloading)
    (setf (download-session-error session) nil)

    (log:info "Download resumed: ~A" session-id)
    t))

(defun pause-download (session-id)
  "Pause a download.

   Args:
     session-id: Download session identifier

   Returns:
     T on success

   Example:
     (pause-download \"download_123\")"
  (let ((session (gethash session-id *download-sessions*)))
    (unless session
      (return-from pause-download nil))

    (setf (download-session-status session) :paused)

    (log:info "Download paused: ~A" session-id)
    t))

;;; ============================================================================
;;; Section 3: Media Metadata Extraction
;;; ============================================================================

(defclass media-metadata ()
  ((file-id :initarg :file-id :accessor media-metadata-file-id)
   (mime-type :initarg :mime-type :accessor media-metadata-mime-type)
   (file-size :initarg :file-size :accessor media-metadata-file-size)
   (duration :initarg :duration :initform nil :accessor media-metadata-duration)
   (width :initarg :width :initform nil :accessor media-metadata-width)
   (height :initarg :height :initform nil :accessor media-metadata-height)
   (thumbnail :initarg :thumbnail :initform nil :accessor media-metadata-thumbnail)
   (attributes :initarg :attributes :initform nil :accessor media-metadata-attributes)))

(defun get-media-metadata (file-id)
  "Get metadata for a media file.

   Args:
     file-id: File identifier

   Returns:
     Media-metadata object or NIL

   Example:
     (get-media-metadata \"AgAD1234\")"
  (handler-case
      (let* ((location (get-file-location file-id))
             (connection (get-connection-for-dc (file-location-dc-id location)))
             (request (make-tl-object 'messages.getMedia
                                      :id (list file-id))))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when (and result (getf result :media))
            (let* ((media (getf result :media))
                   (doc (getf media :document)))
              (when doc
                (let ((metadata (make-instance 'media-metadata
                                               :file-id file-id
                                               :mime-type (getf doc :mime-type "application/octet-stream")
                                               :file-size (getf doc :size 0))))
                  ;; Extract attributes
                  (dolist (attr (getf doc :attributes nil))
                    (let ((type (getf attr :type)))
                      (cond
                        ((eq type :video)
                         (setf (media-metadata-duration metadata) (getf attr :duration)
                               (media-metadata-width metadata) (getf attr :w)
                               (media-metadata-height metadata) (getf attr :h)))
                        ((eq type :audio)
                         (setf (media-metadata-duration metadata) (getf attr :duration)))
                        ((eq type :image-size)
                         (setf (media-metadata-width metadata) (getf attr :w)
                               (media-metadata-height metadata) (getf attr :h)))))))
                  metadata))))))
    (t (e)
      (log:error "Get media metadata failed: ~A" e)
      nil)))

(defun extract-video-thumbnail (video-file-id &key (output-path nil))
  "Extract thumbnail from a video file.

   Args:
     video-file-id: Video file identifier
     output-path: Optional path to save thumbnail

   Returns:
     Thumbnail data or saved path

   Example:
     (extract-video-thumbnail \"video_123\" :output-path \"/tmp/thumb.jpg\")"
  (let ((metadata (get-media-metadata video-file-id)))
    (unless metadata
      (return-from extract-video-thumbnail (values nil "Failed to get metadata")))

    ;; Get thumbnail from metadata
    (let ((thumbnail (media-metadata-thumbnail metadata)))
      (if thumbnail
          (if output-path
              (progn
                (with-open-file (stream output-path :direction :output
                                                   :element-type '(unsigned-byte 8)
                                                   :if-exists :supersede)
                  (write-sequence thumbnail stream))
                (values output-path nil))
              (values thumbnail nil))
          (values nil "No thumbnail available")))))

(defun get-file-info (file-id)
  "Get detailed file information.

   Args:
     file-id: File identifier

   Returns:
     Plist with file information

   Example:
     (get-file-info \"AgAD1234\")"
  (handler-case
      (let ((metadata (get-media-metadata file-id)))
        (when metadata
          (list :file-id file-id
                :mime-type (media-metadata-mime-type metadata)
                :file-size (media-metadata-file-size metadata)
                :duration (media-metadata-duration metadata)
                :width (media-metadata-width metadata)
                :height (media-metadata-height metadata)
                :has-thumbnail (and (media-metadata-thumbnail metadata) t))))
    (t (e)
      (log:error "Get file info failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: File Cache Management
;;; ============================================================================

(defclass file-cache-entry ()
  ((file-id :initarg :file-id :accessor cache-entry-file-id)
   (file-path :initarg :file-path :accessor cache-entry-file-path)
   (file-size :initarg :file-size :accessor cache-entry-file-size)
   (created-at :initarg :created-at :accessor cache-entry-created-at)
   (last-accessed :initarg :last-accessed :accessor cache-entry-last-accessed)
   (access-count :initarg :access-count :initform 1 :accessor cache-entry-access-count)
   (checksum :initarg :checksum :accessor cache-entry-checksum)))

(defclass file-cache ()
  ((cache-dir :initarg :cache-dir :accessor file-cache-dir)
   (max-size :initarg :max-size :accessor file-cache-max-size)
   (entries :initarg :entries :initform (make-hash-table :test 'equal) :accessor file-cache-entries)
   (lock :initform (bt:make-lock) :accessor file-cache-lock)))

(defvar *file-cache* nil
  "Global file cache instance")

(defun initialize-file-cache (&key (cache-dir nil) (max-size (* 1 1024 1024 1024))) ; 1GB default
  "Initialize the file cache.

   Args:
     cache-dir: Directory to store cached files (default: system temp)
     max-size: Maximum cache size in bytes (default: 1GB)

   Returns:
     File-cache instance

   Example:
     (initialize-file-cache :cache-dir \"/tmp/tg-cache\" :max-size (* 2 1024 1024 1024))"
  (let* ((dir (or cache-dir
                  (namestring (merge-pathnames "cl-telegram-cache/" (uiop:temporary-directory)))))
         (cache (make-instance 'file-cache
                               :cache-dir dir
                               :max-size max-size)))
    ;; Create cache directory if it doesn't exist
    (ensure-directories-exist dir)

    (setf *file-cache* cache)
    (log:info "File cache initialized: ~A (max-size=~A)" dir (file-size-string max-size))
    cache))

(defun get-cache-entry (file-id)
  "Get a cached file entry.

   Args:
     file-id: File identifier

   Returns:
     Cache-entry or NIL

   Example:
     (get-cache-entry \"AgAD1234\")"
  (unless *file-cache*
    (return-from get-cache-entry nil))

  (bt:with-lock-held ((file-cache-lock *file-cache*))
    (let ((entry (gethash file-id (file-cache-entries *file-cache*))))
      (when entry
        ;; Update access time and count
        (setf (cache-entry-last-accessed entry) (get-universal-time)
              (cache-entry-access-count entry) (1+ (cache-entry-access-count entry)))
        entry))))

(defun cache-file (file-id file-path &key (keep-original nil))
  "Add a file to the cache.

   Args:
     file-id: File identifier
     file-path: Path to file
     keep-original: Whether to keep original file (default: NIL, moves file)

   Returns:
     Cached file path

   Example:
     (cache-file \"AgAD1234\" \"/tmp/file.zip\")"
  (unless *file-cache*
    (return-from cache-file file-path))

  (let* ((cache *file-cache*)
         (cache-path (merge-pathnames (format nil "~A.dat" file-id) (file-cache-dir cache)))
         (file-size (file-length file-path)))

    (bt:with-lock-held ((file-cache-lock cache))
      ;; Move or copy file to cache
      (if keep-original
          (uiop:copy-file file-path cache-path)
          (uiop:rename-file-overwriting-target file-path cache-path))

      ;; Create cache entry
      (let ((entry (make-instance 'file-cache-entry
                                  :file-id file-id
                                  :file-path (namestring cache-path)
                                  :file-size file-size
                                  :created-at (get-universal-time)
                                  :last-accessed (get-universal-time)
                                  :checksum (calculate-file-checksum cache-path))))
        (setf (gethash file-id (file-cache-entries cache)) entry)

        ;; Check cache size and evict if necessary
        (evict-cache-entries-if-needed cache)

        (log:info "File cached: ~A (~A)" file-id (file-size-string file-size))
        (namestring cache-path)))))

(defun get-cached-file (file-id &key (download-if-missing t))
  "Get a cached file, optionally downloading if not cached.

   Args:
     file-id: File identifier
     download-if-missing: Download if not in cache (default: T)

   Returns:
     Cached file path or NIL

   Example:
     (get-cached-file \"AgAD1234\")"
  (let ((entry (get-cache-entry file-id)))
    (if entry
        (progn
          ;; Update access time
          (setf (cache-entry-last-accessed entry) (get-universal-time)
                (cache-entry-access-count entry) (1+ (cache-entry-access-count entry)))
          (cache-entry-file-path entry))
        (when download-if-missing
          ;; Download and cache
          (let ((temp-path (format nil "/tmp/tg_download_~A.tmp" (get-universal-time))))
            (multiple-value-bind (path error)
                (download-file file-id :output-path temp-path)
              (if path
                  (cache-file file-id path :keep-original t)
                  (progn
                    (log:error "Download failed: ~A" error)
                    nil))))))))

(defun evict-cache-entries-if-needed (cache)
  "Evict cache entries if cache exceeds max size.

   Args:
     cache: File-cache instance

   Returns:
     Number of entries evicted"
  (let ((current-size 0)
        (evicted 0))

    ;; Calculate current cache size
    (maphash (lambda (k v)
               (declare (ignore k))
               (incf current-size (cache-entry-file-size v)))
             (file-cache-entries cache))

    ;; Evict LRU entries if over limit
    (when (> current-size (file-cache-max-size cache))
      (let* ((entries (loop for entry being the hash-values of (file-cache-entries cache)
                            collect entry))
             (sorted (sort entries #'< :key #'cache-entry-last-accessed)))
        (dolist (entry sorted)
          (when (> current-size (file-cache-max-size cache))
            ;; Delete file and remove entry
            (ignore-errors (uiop:delete-file-if-exists (cache-entry-file-path entry)))
            (remhash (cache-entry-file-id entry) (file-cache-entries cache))
            (decf current-size (cache-entry-file-size entry))
            (incf evicted)
            (log:debug "Evicted: ~A (~A)" (cache-entry-file-id entry)
                      (file-size-string (cache-entry-file-size entry)))))))

    evicted))

(defun clear-file-cache (&key (older-than nil) (max-size nil))
  "Clear file cache entries.

   Args:
     older-than: Only clear entries older than this many seconds
     max-size: Maximum cache size to keep (evict oldest if exceeded)

   Returns:
     Number of entries cleared

   Example:
     (clear-file-cache :older-than (* 7 24 60 60)) ; Clear entries older than 7 days"
  (unless *file-cache*
    (return-from clear-file-cache 0))

  (let ((cache *file-cache*)
        (cleared 0)
        (now (get-universal-time)))

    (bt:with-lock-held ((file-cache-lock cache))
      (loop for file-id being the hash-keys of (file-cache-entries cache)
            using (hash-value entry)
            do (let ((age (- now (cache-entry-last-accessed entry))))
                 (when (or (null older-than) (>= age older-than))
                   (ignore-errors (uiop:delete-file-if-exists (cache-entry-file-path entry)))
                   (remhash file-id (file-cache-entries cache))
                   (incf cleared)))))

    ;; Also enforce max-size if specified
    (when max-size
      (setf (file-cache-max-size cache) max-size)
      (incf cleared (evict-cache-entries-if-needed cache)))

    (log:info "Cache cleared: ~D entries" cleared)
    cleared))

(defun get-file-cache-stats ()
  "Get file cache statistics.

   Returns:
     Plist with cache statistics

   Example:
     (get-file-cache-stats)"
  (unless *file-cache*
    (return-from get-file-cache-stats nil))

  (let ((cache *file-cache*)
        (total-size 0)
        (entry-count 0)
        (oldest nil)
        (newest nil)
        (now (get-universal-time)))

    (maphash (lambda (k v)
               (declare (ignore k))
               (incf entry-count)
               (incf total-size (cache-entry-file-size v))
               (let ((age (- now (cache-entry-last-accessed v))))
                 (when (or (null oldest) (> age oldest))
                   (setf oldest age))
                 (when (or (null newest) (< age newest))
                   (setf newest age))))
             (file-cache-entries cache))

    (list :entry-count entry-count
          :total-size total-size
          :total-size-string (file-size-string total-size)
          :max-size (file-cache-max-size cache)
          :max-size-string (file-size-string (file-cache-max-size cache))
          :utilization (if (plusp (file-cache-max-size cache))
                          (* 100.0 (/ total-size (file-cache-max-size cache)))
                          0)
          :oldest-entry-age (and oldest (* 60 60 oldest)) ; Convert to hours
          :newest-entry-age (and newest (* 60 newest))))) ; Convert to minutes

;;; Helper function
(defun calculate-file-checksum (file-path)
  "Calculate MD5 checksum of a file.

   Args:
     file-path: Path to file

   Returns:
     Checksum string"
  (handler-case
      (let ((data (uiop:read-file-byte-vector file-path)))
        (ironclad:byte-array-to-hex-string (ironclad:digest-sequence :md5 data)))
    (t (e)
      (log:warn "Checksum calculation failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 5: Queue Management
;;; ============================================================================

(defun get-active-uploads-stats ()
  "Get statistics of active uploads.

   Returns:
     Plist with upload statistics

   Example:
     (get-active-uploads-stats)"
  (let ((active-count 0)
        (pending-count 0)
        (completed-count 0)
        (failed-count 0)
        (total-bytes 0)
        (uploaded-bytes 0))

    (maphash (lambda (k v)
               (declare (ignore k))
               (incf active-count)
               (let ((status (upload-session-status v)))
                 (case status
                   (:pending (incf pending-count))
                   (:uploading (incf uploaded-bytes
                                     (* (upload-session-uploaded-parts v)
                                        (upload-session-part-size v))))
                   (:completed (incf completed-count))
                   (:failed (incf failed-count))
                   (:cancelled (incf failed-count))))
               (incf total-bytes (upload-session-file-size v)))
             *upload-sessions*)

    (list :active-count active-count
          :pending-count pending-count
          :uploading-count (- active-count pending-count)
          :completed-count completed-count
          :failed-count failed-count
          :total-bytes total-bytes
          :uploaded-bytes uploaded-bytes
          :progress (if (plusp total-bytes)
                       (* 100.0 (/ uploaded-bytes total-bytes))
                       0))))

(defun get-active-downloads-stats ()
  "Get statistics of active downloads.

   Returns:
     Plist with download statistics

   Example:
     (get-active-downloads-stats)"
  (let ((active-count 0)
        (pending-count 0)
        (downloading-count 0)
        (paused-count 0)
        (completed-count 0)
        (failed-count 0)
        (total-bytes 0)
        (downloaded-bytes 0))

    (maphash (lambda (k v)
               (declare (ignore k))
               (incf active-count)
               (let ((status (download-session-status v)))
                 (case status
                   (:pending (incf pending-count))
                   (:downloading (incf downloading-count)
                                 (incf downloaded-bytes (download-session-downloaded-size v)))
                   (:paused (incf paused-count))
                   (:completed (incf completed-count))
                   (:failed (incf failed-count))))
               (incf total-bytes (download-session-file-size v)))
             *download-sessions*)

    (list :active-count active-count
          :pending-count pending-count
          :downloading-count downloading-count
          :paused-count paused-count
          :completed-count completed-count
          :failed-count failed-count
          :total-bytes total-bytes
          :downloaded-bytes downloaded-bytes
          :progress (if (plusp total-bytes)
                       (* 100.0 (/ downloaded-bytes total-bytes))
                       0))))

;;; ============================================================================
;;; Section 6: Cleanup and Maintenance
;;; ============================================================================

(defun cleanup-stale-sessions (&key (max-age (* 24 60 60))) ; 24 hours default
  "Clean up stale upload/download sessions.

   Args:
     max-age: Maximum session age in seconds (default: 24 hours)

   Returns:
     Number of sessions cleaned

   Example:
     (cleanup-stale-sessions :max-age (* 7 24 60 60))"
  (let ((now (get-universal-time))
        (cleaned 0))

    ;; Clean upload sessions
    (maphash (lambda (k v)
               (when (and (eq (upload-session-status v) :uploading)
                          (> (- now (upload-session-last-activity v)) max-age))
                 (setf (upload-session-status v) :failed
                       (upload-session-error v) "Session timed out")
                 (remhash k *upload-sessions*)
                 (incf cleaned)))
             *upload-sessions*)

    ;; Clean download sessions
    (maphash (lambda (k v)
               (when (and (eq (download-session-status v) :downloading)
                          (> (- now (download-session-last-activity v)) max-age))
                 (setf (download-session-status v) :failed
                       (download-session-error v) "Session timed out")
                 (remhash k *download-sessions*)
                 (incf cleaned)))
             *download-sessions*)

    (log:info "Cleaned up ~D stale sessions" cleaned)
    cleaned))

(defun get-performance-file-stats ()
  "Get comprehensive file management statistics.

   Returns:
     Plist with all file management statistics

   Example:
     (get-performance-file-stats)"
  (list :uploads (get-active-uploads-stats)
        :downloads (get-active-downloads-stats)
        :cache (get-file-cache-stats)
        :max-concurrent-uploads *max-concurrent-uploads*
        :max-concurrent-downloads *max-concurrent-downloads*
        :default-chunk-size *default-chunk-size*))

;;; ============================================================================
;;; Section 7: Initialization
;;; ============================================================================

(defun initialize-file-management-enhanced (&key (cache-dir nil) (cache-size (* 1 1024 1024 1024)))
  "Initialize enhanced file management.

   Args:
     cache-dir: Optional cache directory
     cache-size: Maximum cache size in bytes (default: 1GB)

   Returns:
     T on success

   Example:
     (initialize-file-management-enhanced :cache-dir \"/tmp/tg-cache\")"
  (handler-case
      (progn
        ;; Initialize file cache
        (initialize-file-cache :cache-dir cache-dir :max-size cache-size)

        ;; Clean up stale sessions on startup
        (cleanup-stale-sessions :max-age (* 2 60 60)) ; 2 hours

        (log:info "Enhanced file management initialized")
        t)
    (t (e)
      (log:error "Failed to initialize file management: ~A" e)
      nil)))

(defun shutdown-file-management-enhanced ()
  "Shutdown enhanced file management.

   Returns:
     T on success"
  (handler-case
      (progn
        ;; Cancel all active uploads
        (maphash (lambda (k v)
                   (declare (ignore k))
                   (setf (upload-session-status v) :cancelled))
                 *upload-sessions*)
        (clrhash *upload-sessions*)

        ;; Pause all active downloads
        (maphash (lambda (k v)
                   (declare (ignore k))
                   (setf (download-session-status v) :paused))
                 *download-sessions*)
        (clrhash *download-sessions*)

        (log:info "Enhanced file management shutdown complete")
        t)
    (t (e)
      (log:error "Failed to shutdown file management: ~A" e)
      nil)))

;;; Export symbols
(export '(;; Upload Session
          upload-session
          make-upload-session
          upload-file-chunk
          get-upload-status
          cancel-upload-session
          complete-upload-session

          ;; Download Session
          download-session
          make-download-session
          download-file-chunk
          resume-download
          pause-download

          ;; Media Metadata
          media-metadata
          get-media-metadata
          extract-video-thumbnail
          get-file-info

          ;; File Cache
          file-cache
          file-cache-entry
          initialize-file-cache
          get-cache-entry
          cache-file
          get-cached-file
          clear-file-cache
          get-file-cache-stats

          ;; Statistics
          get-active-uploads-stats
          get-active-downloads-stats
          get-performance-file-stats

          ;; Maintenance
          cleanup-stale-sessions

          ;; Configuration
          *max-concurrent-uploads*
          *max-concurrent-downloads*
          *default-chunk-size*

          ;; Initialization
          initialize-file-management-enhanced
          shutdown-file-management-enhanced))
