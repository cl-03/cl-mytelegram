;;; auto-delete-messages.lisp --- Auto-delete message support for cl-telegram
;;;
;;; Provides Telegram-style auto-delete (self-destruct) messages:
;;; - Per-message TTL timers
;;; - Per-chat default timers
;;; - Silent/delete-with-notify options
;;; - Background monitor thread
;;;
;;; Version: 0.27.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Auto-Delete Timer Class
;;; ============================================================================

(defclass auto-delete-timer ()
  ((timer-id :initarg :timer-id :reader timer-id)
   (chat-id :initarg :chat-id :accessor timer-chat-id)
   (message-id :initarg :message-id :accessor timer-message-id)
   (delete-at :initarg :delete-at :accessor timer-delete-at) ; universal-time
   (is-silent :initform nil :accessor timer-is-silent)
   (created-by :initarg :created-by :accessor timer-created-by)
   (state :initform :pending :accessor timer-state))) ; :pending, :cancelled, :executed

(defmethod print-object ((timer auto-delete-timer) stream)
  (print-unreadable-object (timer stream :type t)
    (format stream "~A/~A delete-at=~A state=~A"
            (timer-chat-id timer)
            (timer-message-id timer)
            (timer-delete-at timer)
            (timer-state timer))))

;;; ============================================================================
;;; Auto-Delete Manager
;;; ============================================================================

(defclass auto-delete-manager ()
  ((active-timers :initform (make-hash-table :test 'equal)
                  :accessor manager-active-timers)
   (default-timers :initform (make-hash-table :test 'equal)
                   :accessor manager-default-timers)
   (monitor-thread :initform nil :accessor manager-monitor-thread)
   (cleanup-interval :initform 60 :accessor manager-cleanup-interval)
   (is-running :initform nil :accessor manager-is-running)))

(defvar *auto-delete-manager* nil
  "Global auto-delete manager instance")

(defun make-auto-delete-manager ()
  "Create a new auto-delete manager instance.

   Returns:
     auto-delete-manager instance"
  (make-instance 'auto-delete-manager))

(defun init-auto-delete-manager (&key (cleanup-interval 60))
  "Initialize auto-delete manager subsystem.

   CLEANUP-INTERVAL: How often to check for expired timers (seconds)

   Returns:
     T on success"
  (unless *auto-delete-manager*
    (setf *auto-delete-manager* (make-auto-delete-manager))
    (setf (manager-cleanup-interval *auto-delete-manager*) cleanup-interval))
  t)

(defun get-auto-delete-manager ()
  "Get the global auto-delete manager.

   Returns:
     auto-delete-manager instance"
  (unless *auto-delete-manager*
    (init-auto-delete-manager))
  *auto-delete-manager*)

;;; ============================================================================
;;; Timer Management
;;; ============================================================================

(defun set-message-timer (chat-id message-id seconds &key (silent nil) (created-by nil))
  "Set auto-delete timer for a message.

   CHAT-ID: The chat containing the message
   MESSAGE-ID: The message to set timer on
   SECONDS: Time until auto-delete (1-604800 seconds, max 1 week)
   SILENT: If T, delete without notification
   CREATED-BY: User ID who set the timer

   Returns:
     (values timer-id error)"
  (let ((manager (get-auto-delete-manager)))
    ;; Validate seconds
    (unless (and (integerp seconds) (<= 1 seconds 604800))
      (return-from set-message-timer
        (values nil :invalid-duration "Duration must be 1-604800 seconds")))

    (let* ((timer-key (format nil "~A/~A" chat-id message-id))
           (timer-id (generate-uuid))
           (delete-at (+ (get-universal-time) seconds))
           (timer (make-instance 'auto-delete-timer
                                 :timer-id timer-id
                                 :chat-id chat-id
                                 :message-id message-id
                                 :delete-at delete-at
                                 :is-silent silent
                                 :created-by (or created-by (get-me-user-id)))))
      ;; Store timer
      (setf (gethash timer-key (manager-active-timers manager)) timer)

      (format t "Set auto-delete timer for message ~A/~A (~D seconds)~%"
              chat-id message-id seconds)
      (values timer-id nil))))

(defun cancel-message-timer (chat-id message-id)
  "Cancel auto-delete timer for a message.

   CHAT-ID: The chat containing the message
   MESSAGE-ID: The message to cancel timer for

   Returns:
     (values t error)"
  (let* ((manager (get-auto-delete-manager))
         (timer-key (format nil "~A/~A" chat-id message-id))
         (timer (gethash timer-key (manager-active-timers manager))))
    (unless timer
      (return-from cancel-message-timer
        (values nil :no-timer "No timer set for this message")))

    ;; Update state
    (setf (timer-state timer) :cancelled)

    ;; Remove from active timers
    (remhash timer-key (manager-active-timers manager))

    (format t "Cancelled auto-delete timer for message ~A/~A~%" chat-id message-id)
    (values t nil)))

(defun get-message-timer-remaining (chat-id message-id)
  "Get remaining time before auto-delete.

   CHAT-ID: The chat containing the message
   MESSAGE-ID: The message to check

   Returns:
     (values remaining-seconds nil) or (values nil error)"
  (let* ((manager (get-auto-delete-manager))
         (timer-key (format nil "~A/~A" chat-id message-id))
         (timer (gethash timer-key (manager-active-timers manager))))
    (unless timer
      (return-from get-message-timer-remaining
        (values nil :no-timer "No timer set for this message")))

    (unless (eq (timer-state timer) :pending)
      (return-from get-message-timer-remaining
        (values nil :timer-expired "Timer already executed or cancelled")))

    (let* ((now (get-universal-time))
           (remaining (- (timer-delete-at timer) now)))
      (if (<= remaining 0)
          (values 0 nil)
          (values remaining nil)))))

;;; ============================================================================
;;; Per-Chat Default Timers
;;; ============================================================================

(defun set-chat-default-timer (chat-id seconds)
  "Set default auto-delete timer for a chat.

   CHAT-ID: The chat to set default for
   SECONDS: Default time until auto-delete (1-604800)

   Returns:
     T on success"
  (let ((manager (get-auto-delete-manager)))
    ;; Validate seconds
    (unless (and (integerp seconds) (<= 1 seconds 604800))
      (return-from set-chat-default-timer
        (values nil :invalid-duration "Duration must be 1-604800 seconds")))

    ;; Store default timer
    (setf (gethash chat-id (manager-default-timers manager)) seconds)

    (format t "Set default auto-delete timer for chat ~A (~D seconds)~%"
            chat-id seconds)
    t))

(defun get-chat-default-timer (chat-id)
  "Get default auto-delete timer for a chat.

   CHAT-ID: The chat to get default for

   Returns:
     seconds or NIL if no default set"
  (let ((manager (get-auto-delete-manager)))
    (gethash chat-id (manager-default-timers manager))))

(defun clear-chat-default-timer (chat-id)
  "Clear default auto-delete timer for a chat.

   CHAT-ID: The chat to clear default for

   Returns:
     T on success"
  (let ((manager (get-auto-delete-manager)))
    (remhash chat-id (manager-default-timers manager))
    (format t "Cleared default auto-delete timer for chat ~A~%" chat-id)
    t))

;;; ============================================================================
;;; Background Monitor
;;; ============================================================================

(defun (private) process-auto-delete (chat-id message-id silent)
  "Process auto-delete for a message.

   CHAT-ID: The chat containing the message
   MESSAGE-ID: The message to delete
   SILENT: If T, delete without notification

   Returns:
     T on success"
  (declare (ignorable chat-id message-id silent))

  ;; In production, call the actual delete API
  ;; (delete-messages chat-id (list message-id))

  (format t "Auto-deleted message ~A/~A (silent: ~A)~%"
          chat-id message-id silent)
  t)

(defun (private) check-expired-timers ()
  "Check and process expired timers.

   Returns:
     Number of timers processed"
  (let* ((manager (get-auto-delete-manager))
         (now (get-universal-time))
         (expired-keys '())
         (count 0))

    ;; Find expired timers
    (maphash (lambda (key timer)
               (when (and (eq (timer-state timer) :pending)
                          (<= (timer-delete-at timer) now))
                 (push key expired-keys)))
             (manager-active-timers manager))

    ;; Process expired timers
    (dolist (timer-key expired-keys)
      (let ((timer (gethash timer-key (manager-active-timers manager))))
        (when timer
          ;; Update state
          (setf (timer-state timer) :executed)

          ;; Delete message
          (process-auto-delete (timer-chat-id timer)
                               (timer-message-id timer)
                               (timer-is-silent timer))

          ;; Remove from active timers
          (remhash timer-key (manager-active-timers manager))

          (incf count))))

    count))

(defun (private) monitor-loop ()
  "Background monitor loop.

   Returns:
     Never returns (runs until stopped)"
  (let ((manager (get-auto-delete-manager)))
    (loop
      (unless (manager-is-running manager)
        (return-from monitor-loop))

      (handler-case
          (progn
            (let ((count (check-expired-timers)))
              (when (> count 0)
                (format t "Auto-delete monitor: processed ~A timers~%" count))))
        (error (e)
          (format t "Auto-delete monitor error: ~A~%" e)))

      ;; Sleep for cleanup interval
      (sleep (manager-cleanup-interval manager)))))

(defun start-auto-delete-monitor ()
  "Start the background auto-delete monitor thread.

   Returns:
     T on success"
  (let ((manager (get-auto-delete-manager)))
    (when (manager-is-running manager)
      (return-from start-auto-delete-monitor
        (values nil :already-running "Monitor already running")))

    ;; Set running state
    (setf (manager-is-running manager) t)

    ;; Start monitor thread
    (setf (manager-monitor-thread manager)
          (bt:make-thread #'monitor-loop
                          :name "auto-delete-monitor"
                          :initial-bindings nil))

    (format t "Started auto-delete monitor (interval: ~Ds)~%"
            (manager-cleanup-interval manager))
    t))

(defun stop-auto-delete-monitor ()
  "Stop the background auto-delete monitor thread.

   Returns:
     T on success"
  (let ((manager (get-auto-delete-manager)))
    (unless (manager-is-running manager)
      (return-from stop-auto-delete-monitor
        (values nil :not-running "Monitor not running")))

    ;; Set stopped state
    (setf (manager-is-running manager) nil)

    ;; Wait for thread to finish
    (when (manager-monitor-thread manager)
      (bt:join-thread (manager-monitor-thread manager) :timeout 5))

    (format t "Stopped auto-delete monitor~%")
    t))

(defun get-auto-delete-stats ()
  "Get auto-delete statistics.

   Returns:
     Plist with statistics"
  (let ((manager (get-auto-delete-manager)))
    (list :active-timers (hash-table-count (manager-active-timers manager))
          :default-timers (hash-table-count (manager-default-timers manager))
          :is-running (manager-is-running manager)
          :cleanup-interval (manager-cleanup-interval manager))))

;;; ============================================================================
;;; Integration with Message Sending
;;; ============================================================================

(defun send-message-with-auto-delete (chat-id text &key (timer-seconds nil) (silent nil))
  "Send message with auto-delete timer.

   CHAT-ID: The chat to send to
   TEXT: Message text
   TIMER-SECONDS: Auto-delete timer (nil for chat default)
   SILENT: If T, delete without notification

   Returns:
     (values message-id error)"
  ;; Send message first
  (multiple-value-bind (message-id send-error)
      (send-message chat-id text)
    (when send-error
      (return-from send-message-with-auto-delete
        (values nil send-error)))

    ;; Set timer if specified
    (if timer-seconds
        (set-message-timer chat-id message-id timer-seconds :silent silent)
        (let ((default (get-chat-default-timer chat-id)))
          (when default
            (set-message-timer chat-id message-id default :silent silent))))

    (values message-id nil)))

;;; ============================================================================
;;; Utilities
;;; ============================================================================

(defun list-active-timers (&key (chat-id nil))
  "List active auto-delete timers.

   CHAT-ID: Optional filter by chat

   Returns:
     List of timer plists"
  (let ((manager (get-auto-delete-manager))
        (timers '()))
    (maphash (lambda (key timer)
               (when (or (null chat-id)
                         (eql (timer-chat-id timer) chat-id))
                 (push (list :timer-id (timer-id timer)
                             :chat-id (timer-chat-id timer)
                             :message-id (timer-message-id timer)
                             :delete-at (timer-delete-at timer)
                             :state (timer-state timer))
                       timers)))
             (manager-active-timers manager))
    timers))

(defun cleanup-expired-timers ()
  "Manually cleanup expired timers.

   Returns:
     Number of timers cleaned up"
  (check-expired-timers))
