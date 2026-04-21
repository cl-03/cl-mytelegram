;;; file-transfer-progress.lisp --- File transfer progress callbacks
;;;
;;; Provides support for:
;;; - Progress callback registration
;;; - Real-time progress updates
;;; - Speed calculation
;;; - ETA estimation
;;; - Progress event dispatching
;;;
;;; Version: 0.39.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Progress Callback State
;;; ============================================================================

(defvar *progress-callbacks* (make-hash-table :test 'equal)
  "Hash table storing progress callbacks keyed by transfer ID")

(defvar *progress-callback-interval* 1024
  "Default interval (in bytes) for progress callback invocation")

(defvar *progress-history* (make-hash-table :test 'equal)
  "History of progress updates for speed calculation")

(defvar *max-progress-history* 10
  "Maximum number of progress history entries to keep")

;;; ============================================================================
;;; Section 2: Progress Callback Structure
;;; ============================================================================

(defstruct transfer-progress
  "Structure representing transfer progress information"
  (transfer-id "" :type string)
  (transferred 0 :type integer)
  (total 0 :type integer)
  (percentage 0.0 :type float)
  (speed 0.0 :type float)
  (speed-human "" :type string)
  (eta nil :type (or null integer))
  (eta-human "" :type string)
  (status :pending :type keyword)
  (timestamp 0 :type integer))

;;; ============================================================================
;;; Section 3: Progress Callback Registration
;;; ============================================================================

(defun register-progress-callback (transfer-id callback &key (interval 1024))
  "Register a progress callback for a transfer.

   Args:
     transfer-id: Transfer ID (download or upload ID)
     callback: Function to call on progress update
               Signature: (lambda (progress-transfer-id transferred total percentage speed eta) ...)
     interval: Callback invocation interval in bytes (default: 1024)

   Returns:
     T on success

   Example:
     (register-progress-callback
      \"download_123\"
      (lambda (progress)
        (format t \"~A: ~A / ~A (~A%) - ~A/s - ETA: ~A~%\"
                (transfer-progress-transfer-id progress)
                (transfer-progress-transferred progress)
                (transfer-progress-total progress)
                (floor (transfer-progress-percentage progress))
                (transfer-progress-speed-human progress)
                (transfer-progress-eta-human progress))))"
  (setf (gethash transfer-id *progress-callbacks*) callback
        (gethash (format nil "~A-interval" transfer-id) *progress-callbacks*) interval)
  (log-message :debug "Registered progress callback for ~A" transfer-id)
  t)

(defun unregister-progress-callback (transfer-id)
  "Unregister a progress callback.

   Args:
     transfer-id: Transfer ID

   Returns:
     T on success

   Example:
     (unregister-progress-callback \"download_123\")"
  (remhash transfer-id *progress-callbacks*)
  (remhash (format nil "~A-interval" transfer-id) *progress-callbacks*)
  (remhash transfer-id *progress-history*)
  (log-message :debug "Unregistered progress callback for ~A" transfer-id)
  t)

(defun get-progress-callback (transfer-id)
  "Get the progress callback for a transfer.

   Args:
     transfer-id: Transfer ID

   Returns:
     Callback function or NIL"
  (gethash transfer-id *progress-callbacks*))

;;; ============================================================================
;;; Section 4: Progress Update Functions
;;; ============================================================================

(defun update-progress (transfer-id transferred total &key (status :downloading))
  "Update transfer progress and invoke callback if registered.

   Args:
     transfer-id: Transfer ID
     transferred: Bytes transferred so far
     total: Total bytes
     status: Current status (:downloading, :uploading, :completed, :error)

   Returns:
     T if callback was invoked, NIL otherwise

   Example:
     (update-progress \"download_123\" 1024000 5242880 :status :downloading)"
  (let ((callback (get-progress-callback transfer-id)))
    (when callback
      ;; Update history for speed calculation
      (update-progress-history transfer-id transferred)

      ;; Calculate speed and ETA
      (multiple-value-bind (speed eta)
          (calculate-speed-and-eta transfer-id transferred total)
        (let* ((percentage (if (> total 0) (/ (* transferred 100.0) total) 0.0))
               (progress (make-transfer-progress
                          :transfer-id transfer-id
                          :transferred transferred
                          :total total
                          :percentage percentage
                          :speed speed
                          :speed-human (format-human-speed speed)
                          :eta eta
                          :eta-human (if eta (format-human-time eta) "N/A")
                          :status status
                          :timestamp (get-universal-time))))
          ;; Invoke callback
          (funcall callback progress)
          t)))))

(defun update-progress-history (transfer-id transferred)
  "Update progress history for speed calculation.

   Args:
     transfer-id: Transfer ID
     transferred: Current transferred bytes"
  (let* ((history (gethash transfer-id *progress-history* '()))
         (now (get-universal-time))
         (entry (list :bytes transferred :time now)))
    (push entry history)
    ;; Keep only last N entries
    (when (> (length history) *max-progress-history*)
      (setf history (subseq history 0 *max-progress-history*)))
    (setf (gethash transfer-id *progress-history*) history)))

(defun calculate-speed-and-eta (transfer-id transferred total)
  "Calculate transfer speed and ETA.

   Args:
     transfer-id: Transfer ID
     transferred: Bytes transferred so far
     total: Total bytes

   Returns:
     Values: speed (bytes/sec), eta (seconds or NIL)"
  (let* ((history (gethash transfer-id *progress-history* '())))
    (if (< (length history) 2)
        (values 0.0 nil)
        ;; Calculate speed from first and last entry
        (let* ((first-entry (first (last history)))
               (last-entry (first history))
               (bytes-delta (- (getf last-entry :bytes) (getf first-entry :bytes)))
               (time-delta (- (getf last-entry :time) (getf first-entry :time))))
          (if (<= time-delta 0)
              (values 0.0 nil)
              (let* ((speed (/ (abs bytes-delta) time-delta))
                     (remaining (- total transferred))
                     (eta (if (> speed 0) (floor (/ remaining speed)) nil)))
                (values speed eta)))))))

;;; ============================================================================
;;; Section 5: Human-Readable Format Utilities
;;; ============================================================================

(defun format-human-speed (bytes-per-second)
  "Format speed in human-readable format.

   Args:
     bytes-per-second: Speed in bytes per second

   Returns:
     Human-readable speed string

   Example:
     (format-human-speed 1048576) => \"1.0 MB/s\""
  (cond
    ((>= bytes-per-second 1073741824)
     (format nil "~,1f GB/s" (/ bytes-per-second 1073741824.0)))
    ((>= bytes-per-second 1048576)
     (format nil "~,1f MB/s" (/ bytes-per-second 1048576.0)))
    ((>= bytes-per-second 1024)
     (format nil "~,1f KB/s" (/ bytes-per-second 1024.0)))
    (t
     (format nil "~D B/s" (floor bytes-per-second)))))

(defun format-human-time (seconds)
  "Format time duration in human-readable format.

   Args:
     seconds: Time in seconds

   Returns:
     Human-readable time string

   Example:
     (format-human-time 3665) => \"1h 1m 5s\""
  (cond
    ((null seconds) "N/A")
    ((>= seconds 86400)
     (let ((days (floor seconds 86400))
           (hours (floor (mod seconds 86400) 3600))
           (mins (floor (mod seconds 3600) 60)))
       (format nil "~Ad ~Ah ~Am" days hours mins)))
    ((>= seconds 3600)
     (let ((hours (floor seconds 3600))
           (mins (floor (mod seconds 3600) 60))
           (secs (mod seconds 60)))
       (format nil "~Ah ~Am ~As" hours mins secs)))
    ((>= seconds 60)
     (let ((mins (floor seconds 60))
           (secs (mod seconds 60)))
       (format nil "~Am ~As" mins secs)))
    (t
     (format nil "~As" seconds))))

;;; ============================================================================
;;; Section 6: Progress Batch Updates
;;; ============================================================================

(defvar *progress-batch-queue* '()
  "Queue for batched progress updates")

(defvar *progress-batch-interval* 0.5
  "Batch interval in seconds")

(defun enqueue-progress-update (transfer-id transferred total &key (status :downloading))
  "Enqueue a progress update for batch processing.

   Args:
     transfer-id: Transfer ID
     transferred: Bytes transferred
     total: Total bytes
     status: Current status

   Returns:
     T on success"
  (push (list :transfer-id transfer-id
              :transferred transferred
              :total total
              :status status
              :timestamp (get-universal-time))
        *progress-batch-queue*)
  t)

(defun flush-progress-updates ()
  "Flush batched progress updates.

   Returns:
     Number of updates flushed"
  (let ((count 0))
    (dolist (update (nreverse *progress-batch-queue*))
      (update-progress
       (getf update :transfer-id)
       (getf update :transferred)
       (getf update :total)
       :status (getf update :status))
      (incf count))
    (setf *progress-batch-queue* '())
    count))

;;; ============================================================================
;;; Section 7: Progress Monitoring
;;; ============================================================================

(defun get-transfer-progress (transfer-id)
  "Get current progress for a transfer.

   Args:
     transfer-id: Transfer ID

   Returns:
     Transfer-progress structure or NIL"
  (let ((history (gethash transfer-id *progress-history* '())))
    (when history
      (let* ((latest (first history))
             (transferred (getf latest :bytes))
             (total (or (getf latest :total) transferred))
             (multiple-value-bind (speed eta)
                  (calculate-speed-and-eta transfer-id transferred total)
                (make-transfer-progress
                 :transfer-id transfer-id
                 :transferred transferred
                 :total total
                 :percentage (if (> total 0) (/ (* transferred 100.0) total) 0.0)
                 :speed speed
                 :speed-human (format-human-speed speed)
                 :eta eta
                 :eta-human (if eta (format-human-time eta) "N/A")
                 :status :active
                 :timestamp (get-universal-time)))))))

(defun list-active-transfers ()
  "List all active transfers with their progress.

   Returns:
     List of (transfer-id . progress) pairs"
  (let ((transfers '()))
    (maphash (lambda (id callback)
               (declare (ignore callback))
               (let ((progress (get-transfer-progress id)))
                 (when progress
                   (push (cons id progress) transfers))))
             *progress-callbacks*)
    (nreverse transfers)))

(defun get-transfer-stats (transfer-id)
  "Get detailed statistics for a transfer.

   Args:
     transfer-id: Transfer ID

   Returns:
     Plist with transfer statistics"
  (let ((progress (get-transfer-progress transfer-id)))
    (when progress
      (list :transfer-id transfer-id
            :transferred (transfer-progress-transferred progress)
            :total (transfer-progress-total progress)
            :percentage (transfer-progress-percentage progress)
            :speed (transfer-progress-speed progress)
            :speed-human (transfer-progress-speed-human progress)
            :eta (transfer-progress-eta progress)
            :eta-human (transfer-progress-eta-human progress)
            :status (transfer-progress-status progress)
            :timestamp (transfer-progress-timestamp progress)))))

;;; ============================================================================
;;; Section 8: Progress Callback Cleanup
;;; ============================================================================

(defun clear-progress-callbacks ()
  "Clear all progress callbacks and history.

   Returns:
     T on success"
  (clrhash *progress-callbacks*)
  (clrhash *progress-history*)
  (setf *progress-batch-queue* '())
  (log-message :info "Cleared all progress callbacks")
  t)

(defun cleanup-completed-transfers ()
  "Cleanup progress data for completed transfers.

   Returns:
     Number of entries cleaned up"
  (let ((count 0))
    (maphash (lambda (id callback)
               (declare (ignore callback))
               (let* ((progress (get-transfer-progress id))
                      (status (when progress (transfer-progress-status progress))))
                 (when (member status '(:completed :error :cancelled))
                   (unregister-progress-callback id)
                   (incf count))))
             *progress-callbacks*)
    count))

;;; ============================================================================
;;; Section 9: Integration with File Download
;;; ============================================================================

(defun notify-download-progress (download-id transferred total &key (status :downloading))
  "Notify progress update for a download.

   Args:
     download-id: Download ID
     transferred: Bytes downloaded
     total: Total bytes
     status: Current status

   Returns:
     T if notification was sent"
  (update-progress download-id transferred total :status status))

(defun notify-upload-progress (upload-id transferred total &key (status :uploading))
  "Notify progress update for an upload.

   Args:
     upload-id: Upload ID
     transferred: Bytes uploaded
     total: Total bytes
     status: Current status

   Returns:
     T if notification was sent"
  (update-progress upload-id transferred total :status status))

;;; ============================================================================
;;; Section 10: Progress Event Hooks
;;; ============================================================================

(defparameter *progress-event-hooks* '()
  "List of hook functions to call on progress events")

(defun register-progress-hook (hook-function)
  "Register a global progress event hook.

   Args:
     hook-function: Function to call on every progress update
                    Signature: (lambda (progress) ...)

   Returns:
     T on success"
  (pushnew hook-function *progress-event-hooks*)
  (log-message :debug "Registered progress hook: ~A" hook-function)
  t)

(defun unregister-progress-hook (hook-function)
  "Unregister a global progress event hook.

   Args:
     hook-function: Hook function to remove

   Returns:
     T on success"
  (setf *progress-event-hooks* (remove hook-function *progress-event-hooks*))
  (log-message :debug "Unregistered progress hook: ~A" hook-function)
  t)

(defun dispatch-progress-event (progress)
  "Dispatch progress event to all registered hooks.

   Args:
     progress: Transfer-progress structure

   Returns:
     Number of hooks invoked"
  (let ((count 0))
    (dolist (hook *progress-event-hooks*)
      (handler-case
          (funcall hook progress)
        (error (e)
          (log-message :error "Progress hook error: ~A" e)))
      (incf count))
    count))

;;; ============================================================================
;;; Section 11: Progress Callback with Logging
;;; ============================================================================

(defun make-logging-progress-callback (&key (log-level :info) (prefix "Transfer"))
  "Create a progress callback that logs to the console.

   Args:
     log-level: Logging level (:debug, :info, :warning, :error)
     prefix: Log message prefix

   Returns:
     Callback function

   Example:
     (register-progress-callback
      \"download_123\"
      (make-logging-progress-callback :prefix \"My Download\"))"
  (lambda (progress)
    (let ((msg (format nil "~A: ~A/~A (~A%) @ ~A, ETA: ~A"
                       prefix
                       (format-human-size (transfer-progress-transferred progress))
                       (format-human-size (transfer-progress-total progress))
                       (floor (transfer-progress-percentage progress))
                       (transfer-progress-speed-human progress)
                       (transfer-progress-eta-human progress))))
      (log-message log-level msg))))

(defun format-human-size (bytes)
  "Format file size in human-readable format.

   Args:
     bytes: Size in bytes

   Returns:
     Human-readable size string"
  (cond
    ((>= bytes 1073741824)
     (format nil "~,1f GB" (/ bytes 1073741824.0)))
    ((>= bytes 1048576)
     (format nil "~,1f MB" (/ bytes 1048576.0)))
    ((>= bytes 1024)
     (format nil "~,1f KB" (/ bytes 1024.0)))
    (t
     (format nil "~D B" bytes))))

;;; ============================================================================
;;; Section 12: Progress Aggregator
;;; ============================================================================

(defun create-progress-aggregator (&key (update-interval 1.0))
  "Create a progress aggregator function that limits update frequency.

   Args:
     update-interval: Minimum interval between updates in seconds

   Returns:
     Aggregator function that wraps a progress callback

   Example:
     (let ((agg (create-progress-aggregator :update-interval 0.5)))
       (register-progress-callback \"download_123\" (agg original-callback)))"
  (let ((last-update 0))
    (lambda (progress)
      (let ((now (get-universal-time)))
        (when (>= (- now last-update) update-interval)
          (funcall (lambda (p)
                     ;; Your callback logic here
                     (declare (ignore p)))
                   progress)
          (setf last-update now))))))

;;; End of file-transfer-progress.lisp
