;;; performance-optimizations-v2.lisp --- Performance Optimizations v2
;;;
;;; Advanced optimizations for cl-telegram:
;;; - Object pooling to reduce GC pressure
;;; - Large file upload optimization (4GB premium support)
;;; - Stories lazy loading and thumbnail caching
;;; - Media gallery virtual scrolling
;;; - Memory-efficient batch operations

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; ### Object Pooling - Reduce GC Pressure
;;; ============================================================================

(defvar *object-pools* (make-hash-table :test 'equal)
  "Global registry of object pools")

(defstruct object-pool
  "Object pool for reducing GC pressure"
  (type nil :type symbol)
  (free-list nil :type list)
  (max-size 100 :type fixnum)
  (current-size 0 :type fixnum)
  (allocator nil :type function)
  (deallocator nil :type function))

(defun make-object-pool (type allocator &key (max-size 100) deallocator)
  "Create an object pool.

   Args:
     type: Symbol identifying object type
     allocator: Function to create new objects
     max-size: Maximum pool size
     deallocator: Optional function to cleanup objects

   Returns:
     Object-pool structure"
  (make-object-pool
   :type type
   :free-list nil
   :max-size max-size
   :current-size 0
   :allocator allocator
   :deallocator deallocator))

(defun pool-acquire (pool-name)
  "Acquire an object from pool.

   Args:
     pool-name: Name of the pool

   Returns:
     Object from pool or newly created one"
  (let ((pool (gethash pool-name *object-pools*)))
    (unless pool
      (error "Object pool ~A not found" pool-name))
    (if (object-pool-free-list pool)
        (pop (object-pool-free-list pool))
        (funcall (object-pool-allocator pool)))))

(defun pool-release (pool-name object)
  "Release an object back to pool.

   Args:
     pool-name: Name of the pool
     object: Object to release

   Returns:
     T on success"
  (let ((pool (gethash pool-name *object-pools*)))
    (unless pool
      (return-from pool-release nil))
    (when (and (object-pool-deallocator pool)
               (funcall (object-pool-deallocator pool) object))
      (push object (object-pool-free-list pool))
      (incf (object-pool-current-size pool)))
    t))

(defun pool-initialize (pool-name allocator &key (initial-count 10) (max-size 100) deallocator)
  "Initialize object pool with pre-allocated objects.

   Args:
     pool-name: Name of the pool
     allocator: Function to create objects
     initial-count: Number of objects to pre-allocate
     max-size: Maximum pool size
     deallocator: Optional cleanup function

   Returns:
     T on success"
  (let ((pool (make-object-pool pool-name allocator
                                :max-size max-size
                                :deallocator deallocator)))
    ;; Pre-allocate objects
    (dotimes (i initial-count)
      (push (funcall allocator) (object-pool-free-list pool))
      (incf (object-pool-current-size pool)))
    (setf (gethash pool-name *object-pools*) pool)
    t))

;;; Message Plist Pool - Reduces consing in message handling

(defun make-message-plist ()
  "Create a reusable message plist structure.

   Returns:
     Message plist with default values"
  (list :id 0
        :chat-id 0
        :from nil
        :text ""
        :date 0
        :is-outgoing nil
        :has-media nil
        :media nil
        :reply-to-message-id nil
        :entities nil))

(defun reset-message-plist (msg)
  "Reset message plist to default values.

   Args:
     msg: Message plist to reset

   Returns:
     Reset message plist"
  (setf (getf msg :id) 0
        (getf msg :chat-id) 0
        (getf msg :text) ""
        (getf msg :date) 0
        (getf msg :is-outgoing) nil
        (getf msg :has-media) nil
        (getf msg :media) nil
        (getf msg :reply-to-message-id) nil
        (getf msg :entities) nil)
  msg)

;; Initialize message pool at startup
(pool-initialize 'message-plist #'make-message-plist
                 :initial-count 50
                 :max-size 200
                 :deallocator #'reset-message-plist)

;;; Byte Buffer Pool - For network operations

(defstruct byte-buffer
  "Reusable byte buffer"
  (data nil :type (simple-array (unsigned-byte 8) (*)))
  (size 0 :type fixnum)
  (position 0 :type fixnum))

(defun make-byte-buffer (&key (initial-size 4096))
  "Create a new byte buffer.

   Args:
     initial-size: Initial buffer size in bytes

   Returns:
     Byte-buffer structure"
  (make-byte-buffer
   :data (make-array initial-size :element-type '(unsigned-byte 8))
   :size initial-size
   :position 0))

(defun reset-byte-buffer (buf)
  "Reset byte buffer position.

   Args:
     buf: Byte-buffer to reset

   Returns:
     Reset byte-buffer"
  (setf (byte-buffer-position buf) 0)
  buf)

(defun ensure-buffer-capacity (buf required-size)
  "Ensure buffer has sufficient capacity.

   Args:
     buf: Byte-buffer
     required-size: Required size in bytes

   Returns:
     Byte-buffer with sufficient capacity"
  (when (> required-size (byte-buffer-size buf))
    (let ((new-size (max (* 2 (byte-buffer-size buf)) required-size)))
      (setf (byte-buffer-data buf)
            (let ((new-data (make-array new-size :element-type '(unsigned-byte 8))))
              (replace new-data (byte-buffer-data buf))
              new-data))
      (setf (byte-buffer-size buf) new-size)))
  buf)

(pool-initialize 'byte-buffer
                 (lambda () (make-byte-buffer :initial-size 4096))
                 :initial-count 20
                 :max-size 50
                 :deallocator #'reset-byte-buffer)

;;; ============================================================================
;;; ### Large File Upload Optimization (4GB Premium)
;;; ============================================================================

(defvar *upload-part-size* (* 512 1024) ; 512 KB default
  "Size of each upload part")

(defvar *max-premium-file-size* (* 4 1024 1024 1024) ; 4GB
  "Maximum file size for premium users")

(defvar *max-free-file-size* (* 2 1024 1024 1024) ; 2GB
  "Maximum file size for free users")

(defvar *active-uploads* (make-hash-table :test 'equal)
  "Active file uploads with progress tracking")

(defstruct upload-session
  "Upload session for large files"
  (file-id nil :type string)
  (file-size 0 :type integer)
  (total-parts 0 :type fixnum)
  (uploaded-parts 0 :type fixnum)
  (part-size 0 :type fixnum)
  (file-path nil :type string)
  (start-time 0 :type integer)
  (last-part-time 0 :type integer)
  (is-paused nil :type boolean)
  (can-resume nil :type boolean))

(defun calculate-optimal-part-size (file-size)
  "Calculate optimal part size for file upload.

   Args:
     file-size: File size in bytes

   Returns:
     Optimal part size in bytes"
  (cond
    ;; Small files (< 10MB) - single part
    ((< file-size (* 10 1024 1024))
     file-size)
    ;; Medium files (10MB - 100MB) - 256KB parts
    ((< file-size (* 100 1024 1024))
     (* 256 1024))
    ;; Large files (100MB - 1GB) - 512KB parts
    ((< file-size (* 1024 1024 1024))
     (* 512 1024))
    ;; Very large files (> 1GB) - 1MB parts
    (t
     (* 1024 1024))))

(defun start-file-upload (file-path &key (chat-id nil) (caption ""))
  "Start a new file upload session.

   Args:
     file-path: Path to file
     chat-id: Target chat ID (optional)
     caption: File caption

   Returns:
     Upload session ID or NIL on failure"
  (unless (probe-file file-path)
    (return-from start-file-upload nil))

  (let* ((file-size (file-length file-path))
         (session-id (format nil "upload-~A-~A"
                             (get-universal-time)
                             (random 1000000)))
         (part-size (calculate-optimal-part-size file-size))
         (total-parts (ceiling file-size part-size)))
    ;; Check file size limits
    (let ((is-premium (check-premium-status))
          (max-size (if is-premium *max-premium-file-size* *max-free-file-size*)))
      (when (> file-size max-size)
        (error "File size ~A exceeds maximum ~A" file-size max-size)))

    ;; Create upload session
    (let ((session (make-upload-session
                    :file-id session-id
                    :file-size file-size
                    :total-parts total-parts
                    :uploaded-parts 0
                    :part-size part-size
                    :file-path file-path
                    :start-time (get-universal-time)
                    :last-part-time 0
                    :is-paused nil
                    :can-resume t)))
      (setf (gethash session-id *active-uploads*) session)
      session-id)))

(defun upload-file-part (session-id part-index)
  "Upload a single file part.

   Args:
     session-id: Upload session ID
     part-index: Index of part to upload (0-based)

   Returns:
     Part result plist or NIL on failure"
  (let ((session (gethash session-id *active-uploads*)))
    (unless session
      (return-from upload-file-part nil))

    (when (upload-session-is-paused session)
      (return-from upload-file-part :paused))

    (let* ((file-path (upload-session-file-path session))
           (part-size (upload-session-part-size session))
           (offset (* part-index part-size))
           (bytes-to-read (min part-size (- (upload-session-file-size session) offset))))

      (with-open-file (stream file-path :element-type '(unsigned-byte 8)
                                       :from-end t)
        (file-position stream offset)
        (let ((buffer (make-array bytes-to-read :element-type '(unsigned-byte 8))))
          (read-sequence buffer stream)

          ;; TODO: Call MTProto uploadPart API
          ;; For now, simulate success
          (incf (upload-session-uploaded-parts session))
          (setf (upload-session-last-part-time session) (get-universal-time))

          (list :part-index part-index
                :bytes-sent bytes-to-read
                :offset offset
                :success t))))))

(defun get-upload-progress (session-id)
  "Get upload progress.

   Args:
     session-id: Upload session ID

   Returns:
     Progress plist with :percent, :uploaded, :total, :speed"
  (let ((session (gethash session-id *active-uploads*)))
    (unless session
      (return-from get-upload-progress nil))

    (let* ((uploaded (upload-session-uploaded-parts session))
           (total (upload-session-total-parts session))
           (percent (if (plusp total) (* 100.0 (/ uploaded total)) 0))
           (elapsed (- (get-universal-time) (upload-session-start-time session)))
           (bytes-per-sec (if (plusp elapsed)
                              (/ (* uploaded (upload-session-part-size session)) elapsed)
                              0)))
      (list :session-id session-id
            :uploaded-parts uploaded
            :total-parts total
            :percent (round percent 0.1)
            :bytes-per-second (round bytes-per-sec)
            :is-paused (upload-session-is-paused session)
            :is-complete (>= uploaded total)))))

(defun pause-upload (session-id)
  "Pause an upload session.

   Args:
     session-id: Upload session ID

   Returns:
     T on success"
  (let ((session (gethash session-id *active-uploads*)))
    (when session
      (setf (upload-session-is-paused session) t)
      t)))

(defun resume-upload (session-id)
  "Resume a paused upload session.

   Args:
     session-id: Upload session ID

   Returns:
     T on success"
  (let ((session (gethash session-id *active-uploads*)))
    (when (and session (upload-session-is-paused session))
      (setf (upload-session-is-paused session) nil)
      t)))

(defun cancel-upload (session-id)
  "Cancel an upload session.

   Args:
     session-id: Upload session ID

   Returns:
     T on success"
  (remhash session-id *active-uploads*)
  t)

(defun cleanup-completed-uploads ()
  "Remove completed upload sessions.

   Returns:
     Number of sessions cleaned"
  (let ((cleaned 0))
    (maphash (lambda (key session)
               (when (>= (upload-session-uploaded-parts session)
                         (upload-session-total-parts session))
                 (remhash key *active-uploads*)
                 (incf cleaned)))
             *active-uploads*)
    cleaned))

;;; ============================================================================
;;; ### Stories Lazy Loading and Thumbnail Cache
;;; ============================================================================

(defvar *stories-thumbnail-cache* (make-hash-table :test 'equal)
  "Cache for story thumbnails")

(defvar *stories-thumbnail-max-size* (* 5 1024 1024) ; 5MB
  "Maximum size of thumbnail cache")

(defvar *current-thumbnail-cache-size* 0
  "Current thumbnail cache size in bytes")

(defstruct story-thumbnail
  "Cached story thumbnail"
  (story-id nil :type integer)
  (data nil :type (simple-array (unsigned-byte 8) (*)))
  (size 0 :type fixnum)
  (width 0 :type fixnum)
  (height 0 :type fixnum)
  (mime-type nil :type string)
  (access-time 0 :type integer))

(defun cache-story-thumbnail (story-id thumbnail-data &key (width 320) (height 568) (mime-type "image/jpeg"))
  "Cache a story thumbnail.

   Args:
     story-id: Story identifier
     thumbnail-data: Thumbnail image data
     width: Thumbnail width
     height: Thumbnail height
     mime-type: MIME type of thumbnail

   Returns:
     T on success"
  (let ((size (length thumbnail-data)))
    ;; Evict if cache too large
    (when (> (+ *current-thumbnail-cache-size* size)
             *stories-thumbnail-max-size*)
      (evict-oldest-thumbnails))

    ;; Create and cache thumbnail
    (let ((thumb (make-story-thumbnail
                  :story-id story-id
                  :data thumbnail-data
                  :size size
                  :width width
                  :height height
                  :mime-type mime-type
                  :access-time (get-universal-time))))
      (setf (gethash story-id *stories-thumbnail-cache*) thumb)
      (incf *current-thumbnail-cache-size* size)
      t)))

(defun get-cached-story-thumbnail (story-id)
  "Get cached story thumbnail.

   Args:
     story-id: Story identifier

   Returns:
     Story-thumbnail or NIL"
  (let ((thumb (gethash story-id *stories-thumbnail-cache*)))
    (when thumb
      ;; Update access time for LRU
      (setf (story-thumbnail-access-time thumb) (get-universal-time))
      thumb)))

(defun evict-oldest-thumbnails ()
  "Evict oldest thumbnails to make room.

   Returns:
     Number of thumbnails evicted"
  (let ((evicted 0)
        (current-time (get-universal-time))
        (threshold (- current-time 3600))) ; 1 hour ago
    (maphash (lambda (key thumb)
               (when (< (story-thumbnail-access-time thumb) threshold)
                 (decf *current-thumbnail-cache-size* (story-thumbnail-size thumb))
                 (remhash key *stories-thumbnail-cache*)
                 (incf evicted)))
             *stories-thumbnail-cache*)
    evicted))

(defun clear-story-thumbnail-cache ()
  "Clear entire thumbnail cache.

   Returns:
     T on success"
  (clrhash *stories-thumbnail-cache*)
  (setf *current-thumbnail-cache-size* 0)
  t)

(defun preload-stories-thumbnails (story-ids)
  "Preload thumbnails for stories.

   Args:
     story-ids: List of story IDs to preload

   Returns:
     Number of thumbnails preloaded"
  (let ((preloaded 0))
    (dolist (story-id story-ids)
      (handler-case
          (let* ((story (get-story-by-id story-id))
                 (media (when story (cl-telegram/api:story-media story))))
            (when media
              ;; TODO: Download and cache thumbnail
              ;; For now, simulate
              (incf preloaded)))
        (error () nil)))
    preloaded))

;;; ============================================================================
;;; ### Memory-Efficient Batch Operations
;;; ============================================================================

(defun batch-get-users-no-cons (user-ids)
  "Batch get users without excessive consing.

   Args:
     user-ids: List of user IDs

   Returns:
     Vector of user plists"
  (let ((result (make-array (length user-ids) :initial-element nil)))
    (loop for uid in user-ids
          for i from 0
          do (setf (aref result i)
                   (let ((cached (get-cached-user uid)))
                     (or cached
                         (list :id uid :first-name "Unknown")))))
    result))

(defun batch-insert-messages-no-cons (chat-id messages)
  "Batch insert messages with minimal consing.

   Args:
     chat-id: Chat identifier
     messages: Vector of message plists

   Returns:
     Number of messages inserted"
  (unless (and *db-connection* (> (length messages) 0))
    (return-from batch-insert-messages-no-cons 0))

  (let ((inserted 0))
    (handler-case
        (progn
          (dbi:with-transaction (*db-connection*)
            (loop for msg across messages
                  do (let ((query "INSERT OR REPLACE INTO messages
                                   (chat_id, id, from_id, text, date, is_outgoing, has_media)
                                   VALUES (?, ?, ?, ?, ?, ?, ?)"))
                       (dbi:execute-query
                        *db-connection*
                        query
                        (list chat-id
                              (getf msg :id)
                              (getf msg :from)
                              (getf msg :text)
                              (getf msg :date)
                              (if (getf msg :is-outgoing) 1 0)
                              (if (getf msg :has-media) 1 0)))
                       (incf inserted))))
          inserted)
      (error () 0))))

;;; Fast string operations

(defun format-chat-id-fast (chat-id)
  "Fast chat ID formatting.

   Args:
     chat-id: Chat ID integer

   Returns:
     Formatted string"
  (cond
    ((minusp chat-id)
     (format nil "-100~A" (abs chat-id)))
    (t
     (format nil "~A" chat-id))))

(defun concat-strings-fast (&rest strings)
  "Fast string concatenation.

   Args:
     strings: Strings to concatenate

   Returns:
     Concatenated string"
  (let ((total-length (reduce #'+ strings :key #'length :initial-value 0)))
    (with-output-to-string (out)
      (declare (optimize (speed 3) (space 0)))
      (dolist (s strings)
        (write-string s out)))))

(defun keyword-from-string-fast (string)
  "Fast keyword creation from string.

   Args:
     string: Input string

   Returns:
     Keyword symbol"
  (intern (string-upcase string) :keyword))

;;; ============================================================================
;;; ### Connection Pool Statistics and Monitoring
;;; ============================================================================

(defvar *connection-pool-stats*
  (list :total-connections 0
        :healthy-connections 0
        :unhealthy-connections 0
        :reconnecting 0
        :created-count 0
        :destroyed-count 0
        :avg-latency 0
        :total-requests 0)
  "Connection pool statistics")

(defun record-connection-stats (&key (created nil) (destroyed nil) (latency nil) (request nil))
  "Record connection pool statistics.

   Args:
     created: T if connection was created
     destroyed: T if connection was destroyed
     latency: Measured latency in ms
     request: T if a request was made

   Returns:
     Updated stats"
  (when created
    (incf (getf *connection-pool-stats* :created-count))
    (incf (getf *connection-pool-stats* :total-connections)))
  (when destroyed
    (incf (getf *connection-pool-stats* :destroyed-count))
    (decf (getf *connection-pool-stats* :total-connections)))
  (when latency
    (let ((avg (getf *connection-pool-stats* :avg-latency))
          (count (getf *connection-pool-stats* :total-requests)))
      (setf (getf *connection-pool-stats* :avg-latency)
            (if (zerop count)
                latency
                (/ (+ (* avg count) latency) (1+ count))))))
  (when request
    (incf (getf *connection-pool-stats* :total-requests)))
  *connection-pool-stats*)

(defun get-connection-pool-stats ()
  "Get current connection pool statistics.

   Returns:
     Stats plist"
  *connection-pool-stats*)

(defun reset-connection-pool-stats ()
  "Reset connection pool statistics.

   Returns:
     T on success"
  (setf *connection-pool-stats*
        (list :total-connections 0
              :healthy-connections 0
              :unhealthy-connections 0
              :reconnecting 0
              :created-count 0
              :destroyed-count 0
              :avg-latency 0
              :total-requests 0))
  t)

;;; ============================================================================
;;; ### Error Handling Utilities
;;; ============================================================================

(define-condition telegram-error (error)
  "Base condition for Telegram errors"
  ((code :initarg :code :reader telegram-error-code)
   (message :initarg :message :reader telegram-error-message)))

(define-condition telegram-auth-error (telegram-error)
  "Authentication error")

(define-condition telegram-network-error (telegram-error)
  "Network error")

(define-condition telegram-database-error (telegram-error)
  "Database error")

(defun handle-telegram-error (condition)
  "Handle Telegram error condition.

   Args:
     condition: Error condition

   Returns:
     Error description string"
  (format nil "Telegram error ~A: ~A"
          (telegram-error-code condition)
          (telegram-error-message condition)))

(defun safe-api-call (function &key (retries 3) (delay 1000))
  "Safely call API function with retries.

   Args:
     function: Function to call
     retries: Number of retry attempts
     delay: Delay between retries in ms

   Returns:
     Function result or NIL on failure"
  (loop for i from 0 below retries
        collect (handler-case
                    (progn
                      (funcall function)
                      (return-from safe-api-call t))
                  (telegram-error (e)
                    (format t "Attempt ~A failed: ~A~%" i (handle-telegram-error e))
                    (when (< i (1- retries))
                      (sleep (/ delay 1000.0)))
                    nil)
                  (error (e)
                    (format t "Unexpected error: ~A~%" e)
                    (return-from safe-api-call nil)))))

;;; ============================================================================
;;; ### Memory and Performance Utilities
;;; ============================================================================

(defun time-operation (name function)
  "Time an operation and log the result.

   Args:
     name: Operation name
     function: Function to time

   Returns:
     Function result"
  (let ((start (get-internal-real-time))
        result)
    (unwind-protect
         (setf result (funcall function))
      (let ((elapsed (/ (- (get-internal-real-time) start)
                        internal-time-units-per-second)))
        (format t "[PERF] ~A: ~Ams~%" name (* elapsed 1000))))
    result))

(defun get-memory-usage ()
  "Get current memory usage.

   Returns:
     Memory stats plist"
  (list :dynamic-usage (room 'dynamic)
        :static-usage (room 'static)
        :read-only-usage (room 'read-only)))

(defun truncate-text (text max-length &key (ellipsis "..."))
  "Truncate text to maximum length.

   Args:
     text: Text to truncate
     max-length: Maximum length
     ellipsis: Ellipsis string

   Returns:
     Truncated text"
  (if (<= (length text) max-length)
      text
      (concatenate 'string
                   (subseq text 0 (- max-length (length ellipsis)))
                   ellipsis)))

(defun normalize-phone-number (phone)
  "Normalize phone number to international format.

   Args:
     phone: Phone number string

   Returns:
     Normalized phone number"
  (let ((cleaned (remove-if-not #'digit-char-p phone)))
    (cond
      ((string-prefix-p "00" cleaned)
       (subseq cleaned 2))
      ((string-prefix-p "+" cleaned)
       (subseq cleaned 1))
      (t
       cleaned))))

(defun fix-message-entities (entities)
  "Fix malformed message entities.

   Args:
     entities: List of message entities

   Returns:
     Fixed entities list"
  (remove-if (lambda (e)
               (or (null (getf e :offset))
                   (null (getf e :length))
                   (minusp (getf e :offset))
                   (minusp (getf e :length))))
             entities))

(defun validate-chat-id (chat-id)
  "Validate chat ID format.

   Args:
     chat-id: Chat ID to validate

   Returns:
     T if valid, NIL otherwise"
  (and (integerp chat-id)
       (not (zerop chat-id))))

(defun validate-user-id (user-id)
  "Validate user ID format.

   Args:
     user-id: User ID to validate

   Returns:
     T if valid, NIL otherwise"
  (and (integerp user-id)
       (plusp user-id)))

;;; ============================================================================
;;; ### Cache Cleanup
;;; ============================================================================

(defun cleanup-old-cache (&key (max-age-days 7))
  "Clean up old cached data.

   Args:
     max-age-days: Maximum age of cached items in days

   Returns:
     Number of items cleaned"
  (let ((cleaned 0)
        (threshold (- (get-universal-time) (* max-age-days 24 60 60))))
    ;; Clean old messages from database
    (when *db-connection*
      (handler-case
          (let ((count (dbi:execute-query
                        *db-connection*
                        "DELETE FROM messages WHERE cached_at < ?"
                        (list threshold))))
            (incf cleaned count))
        (error () nil)))
    cleaned))

(defun vacuum-all-caches ()
  "Vacuum all caches and databases.

   Returns:
     T on success"
  (optimize-database)
  (evict-oldest-thumbnails)
  (cleanup-completed-uploads)
  t)
