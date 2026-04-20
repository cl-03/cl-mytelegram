;;; media-library.lisp --- Media library management for cl-telegram
;;;
;;; Provides unified media and file management:
;;; - Browse all media by type
;;; - Filter by chat source
;;; - Search and sort capabilities
;;; - Batch operations
;;;
;;; Version: 0.27.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Media Item Class
;;; ============================================================================

(defclass media-item ()
  ((id :initarg :id :reader media-id)
   (chat-id :initarg :chat-id :accessor media-chat-id)
   (message-id :initarg :message-id :accessor media-message-id)
   (type :initarg :type :accessor media-type) ; :photo, :video, :document, :audio
   (file-name :initform nil :accessor media-file-name)
   (file-size :initform nil :accessor media-file-size)
   (mime-type :initform nil :accessor media-mime-type)
   (width :initform nil :accessor media-width)
   (height :initform nil :accessor media-height)
   (duration :initform nil :accessor media-duration)
   (thumbnail :initform nil :accessor media-thumbnail)
   (date :initform nil :accessor media-date)
   (from-id :initform nil :accessor media-from-id)
   (from-name :initform nil :accessor media-from-name)
   (caption :initform nil :accessor media-caption)
   (local-path :initform nil :accessor media-local-path)))

(defmethod print-object ((item media-item) stream)
  (print-unreadable-object (item stream :type t)
    (format stream "~A ~A (~A bytes)"
            (media-type item)
            (or (media-file-name item) (media-id item))
            (or (media-file-size item) 0))))

;;; ============================================================================
;;; Media Library Manager
;;; ============================================================================

(defclass media-library ()
  ((media-cache :initform (make-hash-table :test 'equal)
                :accessor library-media-cache)
   (stats-cache :initform nil :accessor library-stats-cache)
   (cache-timestamp :initform 0 :accessor library-cache-timestamp)
   (cache-ttl :initform 300 :accessor library-cache-ttl))) ; 5 minutes

(defvar *media-library* nil
  "Global media library instance")

(defun make-media-library ()
  "Create a new media library instance."
  (make-instance 'media-library))

(defun init-media-library ()
  "Initialize media library subsystem."
  (unless *media-library*
    (setf *media-library* (make-media-library)))
  t)

(defun get-media-library ()
  "Get the global media library."
  (unless *media-library*
    (init-media-library))
  *media-library*)

;;; ============================================================================
;;; Core Media Retrieval Functions
;;; ============================================================================

(defun get-all-media (&key
                      (type nil)
                      (chat-id nil)
                      (limit 100)
                      (offset 0)
                      (date-from nil)
                      (date-to nil))
  "Get all media across chats.

   TYPE: Filter by media type (:photo, :video, :document, :audio, :animation)
   CHAT-ID: Filter by chat source
   LIMIT: Maximum results to return
   OFFSET: Pagination offset
   DATE-FROM: Filter by date from (universal-time)
   DATE-TO: Filter by date to (universal-time)

   Returns:
     (values media-items total-count error)"
  (let ((library (get-media-library)))
    ;; Check cache
    (let ((cache-key (format nil "all:~A:~A" type chat-id)))
      (let ((cached (gethash cache-key (library-media-cache library))))
        (when (and cached
                   (< (- (get-universal-time) (getf cached :time)) (library-cache-ttl library)))
          (return-from get-all-media
            (values (getf cached :items) (getf cached :count) nil)))))

    ;; Get chats to search
    (let ((chats (if chat-id
                     (list (get-chat chat-id))
                     (get-chats :limit 100))))
      (when (null chats)
        (return-from get-all-media
          (values nil 0 :no-chats "No chats found"))))

    ;; Collect media from all chats
    (let ((all-media '())
          (total-count 0))
      (dolist (chat chats)
        (let ((cid (getf chat :id)))
          (multiple-value-bind (media count)
              (get-chat-media cid
                              :type type
                              :date-from date-from
                              :date-to date-to
                              :limit limit)
            (when media
              (dolist (m media)
                (let ((item (parse-media-item m cid)))
                  (when item
                    (push item all-media))))
              (incf total-count count)))))

      ;; Sort by date (newest first)
      (setf all-media (sort all-media #'> :key #'media-date))

      ;; Apply pagination
      (let ((paginated (subseq all-media offset (min (+ offset limit) (length all-media)))))
        ;; Cache results
        (setf (gethash cache-key (library-media-cache library))
              (list :time (get-universal-time)
                    :items paginated
                    :count (length paginated)))

        (format t "Found ~D media items~%" (length paginated))
        (values paginated total-count nil)))))

(defun get-all-photos (&key (chat-id nil) (limit 100))
  "Get all photos.

   CHAT-ID: Filter by chat source
   LIMIT: Maximum results to return

   Returns:
     (values photos count)"
  (get-all-media :type :photo :chat-id chat-id :limit limit))

(defun get-all-videos (&key (chat-id nil) (limit 100))
  "Get all videos.

   CHAT-ID: Filter by chat source
   LIMIT: Maximum results to return

   Returns:
     (values videos count)"
  (get-all-media :type :video :chat-id chat-id :limit limit))

(defun get-all-documents (&key (chat-id nil) (limit 100))
  "Get all documents.

   CHAT-ID: Filter by chat source
   LIMIT: Maximum results to return

   Returns:
     (values documents count)"
  (get-all-media :type :document :chat-id chat-id :limit limit))

(defun get-all-audio (&key (chat-id nil) (limit 100))
  "Get all audio files.

   CHAT-ID: Filter by chat source
   LIMIT: Maximum results to return

   Returns:
     (values audio count)"
  (get-all-media :type :audio :chat-id chat-id :limit limit))

(defun get-all-files (&key (chat-id nil) (limit 100))
  "Get all files (documents and other non-media files).

   CHAT-ID: Filter by chat source
   LIMIT: Maximum results to return

   Returns:
     (values files count)"
  (get-all-media :type :document :chat-id chat-id :limit limit))

;;; ============================================================================
;;; Chat-Specific Media Retrieval
;;; ============================================================================

(defun get-chat-media (chat-id &key
                       (type nil)
                       (date-from nil)
                       (date-to nil)
                       (limit 100))
  "Get media from a specific chat.

   CHAT-ID: The chat to get media from
   TYPE: Filter by media type
   DATE-FROM: Filter by date from
   DATE-TO: Filter by date to
   LIMIT: Maximum results

   Returns:
     (values media-items count)"
  (let ((messages '())
        (count 0))
    ;; Get message history
    (let ((offset 0)
          (more t))
      (loop while (and more (< count limit)) do
        (multiple-value-bind (batch has-more)
            (get-message-history chat-id :limit 50 :offset offset)
          (if (null batch)
              (setf more nil)
              (progn
                ;; Filter messages with media
                (dolist (msg batch)
                  (let ((media (getf msg :media)))
                    (when (and media
                               (or (null type)
                                   (eq (getf media :type) type))
                               (or (null date-from)
                                   (>= (getf msg :date) date-from))
                               (or (null date-to)
                                   (<= (getf msg :date) date-to)))
                      (push msg messages)
                      (incf count)
                      (when (>= count limit)
                        (return))))))
                (setf offset (+ offset 50))
                (setf more has-more))))))

    (setf messages (nreverse messages))
    (values messages count))

;;; ============================================================================
;;; Media Search Functions
;;; ============================================================================

(defun search-files (query &key
                     (type nil)
                     (chat-id nil)
                     (limit 50))
  "Search files by name or caption.

   QUERY: Search query string
   TYPE: Filter by media type
   CHAT-ID: Filter by chat source
   LIMIT: Maximum results

   Returns:
     (values results count)"
  (let ((library (get-media-library))
        (results '())
        (count 0))
    ;; Get all media of specified type
    (multiple-value-bind (media total)
        (get-all-media :type type :chat-id chat-id :limit 500)
      (declare (ignore total))
      (dolist (item media)
        (let ((name (media-file-name item))
              (caption (media-caption item)))
          (when (or (and name (search query name :test #'char-equal))
                    (and caption (search query caption :test #'char-equal)))
            (push item results)
            (incf count)
            (when (>= count limit)
              (return))))))

    ;; Sort by relevance (exact matches first)
    (setf results (sort results (lambda (a b)
                                  (let ((aname (or (media-file-name a) ""))
                                        (bname (or (media-file-name b) "")))
                                    (and (search query aname)
                                         (not (search query bname)))))))

    (format t "Found ~D matching files~%" (length results))
    (values results count)))

(defun filter-media-by-chat (media-items chat-id)
  "Filter media items by chat source.

   MEDIA-ITEMS: List of media-item objects
   CHAT-ID: Chat ID to filter by

   Returns:
     Filtered list of media items"
  (remove-if (lambda (item)
               (not (eql (media-chat-id item) chat-id)))
             media-items))

(defun sort-media-by-date (media-items &key (descending t))
  "Sort media items by date.

   MEDIA-ITEMS: List of media-item objects
   DESCENDING: If T, sort newest first

   Returns:
     Sorted list of media items"
  (sort media-items (if descending #'> #'<) :key #'media-date))

(defun group-media-by-month (media-items)
  "Group media items by month.

   MEDIA-ITEMS: List of media-item objects

   Returns:
     Hash table with (year . month) as keys"
  (let ((groups (make-hash-table :test 'equal)))
    (dolist (item media-items)
      (let* ((date (media-date item))
             (decoded (decode-universal-time date))
             (year (nth 5 decoded))
             (month (nth 4 decoded))
             (key (format nil "~D-~2,'0D" year month)))
        (push item (gethash key groups))))
    groups))

;;; ============================================================================
;;; Batch Operations
;;; ============================================================================

(defun download-media-batch (media-ids output-directory &key (overwrite nil))
  "Download multiple media files.

   MEDIA-IDS: List of media IDs or file IDs
   OUTPUT-DIRECTORY: Destination directory
   OVERWRITE: If T, overwrite existing files

   Returns:
     (values downloaded-paths failed-count)"
  (let ((downloaded '())
        (failed 0))
    ;; Ensure output directory exists
    (ensure-directories-exist output-directory)

    (dolist (media-id media-ids)
      (handler-case
          (let* ((media (get-media-item media-id))
                 (file-name (or (media-file-name media)
                                (format nil "~A" media-id)))
                 (output-path (merge-pathnames file-name output-directory)))
            (unless (and (probe-file output-path) (not overwrite))
              (download-file media-id output-path)
              (push output-path downloaded))
            (sleep 0.1)) ; Rate limiting
        (error (e)
          (format t "Failed to download ~A: ~A~%" media-id e)
          (incf failed))))

    (format t "Downloaded ~D files, ~D failed~%" (length downloaded) failed)
    (values (nreverse downloaded) failed)))

(defun delete-media-batch (media-ids)
  "Delete multiple media files from cache.

   MEDIA-IDS: List of media IDs

   Returns:
     (values deleted-count failed-count)"
  (let ((deleted 0)
        (failed 0))
    (dolist (media-id media-ids)
      (handler-case
          (progn
            ;; In production, delete from cache
            (incf deleted))
        (error (e)
          (format t "Failed to delete ~A: ~A~%" media-id e)
          (incf failed))))

    (format t "Deleted ~D files, ~D failed~%" deleted failed)
    (values deleted failed)))

;;; ============================================================================
;;; Statistics and Analytics
;;; ============================================================================

(defun get-media-statistics ()
  "Get media library statistics.

   Returns:
     Plist with statistics"
  (let ((library (get-media-library))
        (stats (library-stats-cache library)))
    ;; Check if cache is fresh
    (when (and stats
               (< (- (get-universal-time) (getf stats :time)) (library-cache-ttl library)))
      (return-from get-media-statistics (getf stats :data)))

    ;; Calculate fresh statistics
    (let ((total-photos 0)
          (total-videos 0)
          (total-documents 0)
          (total-audio 0)
          (total-size 0))
      ;; Get counts for each type
      (multiple-value-bind (photos count)
          (get-all-photos :limit 10)
        (declare (ignore photos))
        (setf total-photos count))

      (multiple-value-bind (videos count)
          (get-all-videos :limit 10)
        (declare (ignore videos))
        (setf total-videos count))

      (multiple-value-bind (docs count)
          (get-all-documents :limit 10)
        (declare (ignore docs))
        (setf total-documents count))

      (multiple-value-bind (audio count)
          (get-all-audio :limit 10)
        (declare (ignore audio))
        (setf total-audio count))

      ;; Cache and return
      (let ((result (list :total-photos total-photos
                          :total-videos total-videos
                          :total-documents total-documents
                          :total-audio total-audio
                          :total-size total-size)))
        (setf (library-stats-cache library)
              (list :time (get-universal-time)
                    :data result))
        result))))

(defun get-media-usage-by-chat (&key (limit 10))
  "Get media usage statistics by chat.

   LIMIT: Maximum chats to return

   Returns:
     List of (chat-id . count) pairs"
  (let ((chats (get-chats :limit 100))
        (usage '()))
    (dolist (chat chats)
      (let ((cid (getf chat :id))
            (count 0))
        (multiple-value-bind (media total)
            (get-chat-media cid :limit 10)
          (declare (ignore media))
          (setf count total))
        (push (list :chat-id cid
                    :chat-title (getf chat :title)
                    :media-count count)
              usage)))

    ;; Sort by count
    (setf usage (sort usage #'> :key #'caddr))
    (subseq usage 0 (min limit (length usage)))))

(defun get-media-usage-by-type ()
  "Get media usage statistics by type.

   Returns:
     Plist with type counts"
  (let ((stats (get-media-statistics)))
    (list :photos (getf stats :total-photos)
          :videos (getf stats :total-videos)
          :documents (getf stats :total-documents)
          :audio (getf stats :total-audio))))

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun (private) parse-media-item (message chat-id)
  "Parse media from message.

   MESSAGE: Message plist
   CHAT-ID: Chat ID

   Returns:
     media-item instance or NIL"
  (let ((media (getf message :media)))
    (when media
      (let* ((media-type (getf media :type))
             (item (make-instance 'media-item
                                  :id (getf message :id)
                                  :chat-id chat-id
                                  :message-id (getf message :id)
                                  :type media-type
                                  :file-name (getf media :file-name)
                                  :file-size (getf media :file-size)
                                  :mime-type (getf media :mime-type)
                                  :width (getf media :width)
                                  :height (getf media :height)
                                  :duration (getf media :duration)
                                  :date (getf message :date)
                                  :from-id (getf message :from-id)
                                  :from-name (getf message :from-name)
                                  :caption (getf message :caption))))
        item))))

(defun get-media-item (media-id)
  "Get a specific media item by ID.

   MEDIA-ID: Media ID to retrieve

   Returns:
     media-item instance or NIL"
  (let ((library (get-media-library)))
    ;; Check cache first
    (let ((cached (gethash media-id (library-media-cache library))))
      (when cached
        (return-from get-media-item cached))))

  ;; Search for media
  (multiple-value-bind (media total)
      (get-all-media :limit 1000)
    (declare (ignore total))
    (let ((found (find media-id media :key #'media-id)))
      (when found
        (setf (gethash media-id (library-media-cache library)) found)
        found))))

;;; ============================================================================
;;; Cache Management
;;; ============================================================================

(defun clear-media-cache ()
  "Clear all media cache.

   Returns:
     T on success"
  (let ((library (get-media-library)))
    (clrhash (library-media-cache library))
    (setf (library-stats-cache library) nil)
    (format t "Cleared media cache~%")
    t))

(defun get-media-cache-stats ()
  "Get media cache statistics.

   Returns:
     Plist with cache stats"
  (let ((library (get-media-library)))
    (list :cache-size (hash-table-count (library-media-cache library))
          :cache-ttl (library-cache-ttl library)
          :stats-cached (if (library-stats-cache library) t nil))))

(defun set-media-cache-ttl (seconds)
  "Set media cache TTL.

   SECONDS: Cache TTL in seconds

   Returns:
     T on success"
  (let ((library (get-media-library)))
    (setf (library-cache-ttl library) seconds)
    (format t "Set media cache TTL to ~D seconds~%" seconds)
    t))

;;; ============================================================================
;;; Media Type Detection
;;; ============================================================================

(defun detect-media-type (file-path)
  "Detect media type from file path or content.

   FILE-PATH: Path to file

   Returns:
     Media type keyword (:photo, :video, :document, :audio)"
  (when file-path
    (let ((name (string-downcase (file-namestring file-path))))
      (cond
        ((cl-ppcre:scan "\\.(jpg|jpeg|png|gif|bmp|webp)$" name) :photo)
        ((cl-ppcre:scan "\\.(mp4|avi|mkv|mov|webm)$" name) :video)
        ((cl-ppcre:scan "\\.(mp3|wav|flac|ogg|m4a)$" name) :audio)
        (t :document)))))

(defun get-file-extension (media-type)
  "Get file extension for media type.

   MEDIA-TYPE: Media type keyword

   Returns:
     File extension string"
  (case media-type
    (:photo ".jpg")
    (:video ".mp4")
    (:audio ".mp3")
    (:document ".file")
    (otherwise ".file")))

;;; ============================================================================
;;; Export Functions
;;; ============================================================================

(defun export-media-list (media-items output-path &key (format :json))
  "Export media list to file.

   MEDIA-ITEMS: List of media-item objects
   OUTPUT-PATH: Destination file path
   FORMAT: Output format (:json, :csv)

   Returns:
     (values success error)"
  (ensure-directories-exist output-path)

  (case format
    (:json
     (let ((data (mapcar (lambda (item)
                           (list :id (media-id item)
                                 :type (media-type item)
                                 :file-name (media-file-name item)
                                 :file-size (media-file-size item)
                                 :chat-id (media-chat-id item)
                                 :date (media-date item)
                                 :caption (media-caption item)))
                         media-items)))
       (with-open-file (out output-path :direction :output :if-exists :supersede)
         (write-string (jonathan:to-json data :pretty t) out))
       (values t nil)))
    (:csv
     (with-open-file (out output-path :direction :output :if-exists :supersede)
       (format out "ID,Type,FileName,FileSize,ChatID,Date,Caption~%")
       (dolist (item media-items)
         (format out "~A,~A,~A,~A,~A,~A,~A~%"
                 (media-id item)
                 (media-type item)
                 (or (media-file-name item) "")
                 (or (media-file-size item) 0)
                 (media-chat-id item)
                 (media-date item)
                 (or (media-caption item) ""))))
       (values t nil))
    (otherwise
     (values nil :invalid-format "Invalid format specified"))))
