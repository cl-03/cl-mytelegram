;;; scheduled-messages.lisp --- Scheduled messages and drafts management
;;;
;;; Provides support for:
;;; - Scheduled message creation and management
;;; - Draft message saving and retrieval
;;; - Message scheduling with custom dates
;;; - Draft synchronization across chats
;;;
;;; Version: 0.37.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Classes and Global State
;;; ============================================================================

(defclass scheduled-message ()
  ((id :initarg :id :accessor scheduled-message-id
       :initform 0 :documentation "Scheduled message ID")
   (chat-id :initarg :chat-id :accessor scheduled-message-chat-id
            :initform 0 :documentation "Target chat ID")
   (text :initarg :text :accessor scheduled-message-text
         :initform "" :documentation "Message text")
   (send-date :initarg :send-date :accessor scheduled-message-send-date
              :initform 0 :documentation "Unix timestamp when to send")
   (created-at :initarg :created-at :accessor scheduled-message-created-at
               :initform 0 :documentation "Creation timestamp")
   (status :initarg :status :accessor scheduled-message-status
           :initform :pending :documentation "Message status")
   (media :initarg :media :accessor scheduled-message-media
          :initform nil :documentation "Optional media attachment")
   (reply-markup :initarg :reply-markup :accessor scheduled-message-reply-markup
                 :initform nil :documentation "Reply keyboard markup")
   (parse-mode :initarg :parse-mode :accessor scheduled-message-parse-mode
               :initform nil :documentation "Parse mode (HTML/Markdown)")))

(defclass message-draft ()
  ((id :initarg :id :accessor message-draft-id
       :initform "" :documentation "Draft identifier")
   (chat-id :initarg :chat-id :accessor message-draft-chat-id
            :initform 0 :documentation "Chat ID")
   (message-thread-id :initarg :message-thread-id :accessor message-draft-message-thread-id
                      :initform nil :documentation "Thread ID for supergroups")
   (text :initarg :text :accessor message-draft-text
         :initform "" :documentation "Draft text content")
   (entities :initarg :entities :accessor message-draft-entities
             :initform nil :documentation "Message entities")
   (updated-at :initarg :updated-at :accessor message-draft-updated-at
               :initform 0 :documentation "Last update timestamp")))

(defvar *scheduled-messages* (make-hash-table :test 'eql)
  "Hash table storing scheduled messages by ID")

(defvar *message-drafts* (make-hash-table :test 'equal)
  "Hash table storing message drafts by chat-id key")

(defvar *draft-cache-timeout* 3600
  "Draft cache timeout in seconds (default: 1 hour)")

;;; ============================================================================
;;; Section 2: Scheduled Message Functions
;;; ============================================================================

(defun send-scheduled-message (chat-id text send-date &key (media nil) (reply-markup nil) (parse-mode nil) (message-thread-id nil))
  "Schedule a message to be sent at a specific time.

   Args:
     chat-id: Unique identifier for target chat or channel username
     text: Message text (1-4096 characters)
     send-date: Unix timestamp when to send the message (must be in future)
     media: Optional media attachment (photo, video, document, etc.)
     reply-markup: Optional reply keyboard or inline keyboard
     parse-mode: Parse mode for message text (HTML, Markdown, MarkdownV2)
     message-thread-id: Optional thread ID for supergroups

   Returns:
     Scheduled-message object on success, NIL on failure

   Example:
     (send-scheduled-message 123456 \"Reminder: Meeting tomorrow\" (+ (get-universal-time) 86400))"
  (handler-case
      (let* ((connection (get-current-connection))
             (scheduled-id (random (expt 2 31)))
             (params `(("chat_id" . ,chat-id)
                       ("text" . ,text)
                       ("schedule_date" . ,send-date))))
        ;; Add optional parameters
        (when media
          (push (cons "media" (json:encode-to-string media)) params))
        (when reply-markup
          (push (cons "reply_markup" (json:encode-to-string reply-markup)) params))
        (when parse-mode
          (push (cons "parse_mode" parse-mode) params))
        (when message-thread-id
          (push (cons "message_thread_id" message-thread-id) params))

        (let ((result (make-api-call connection "sendScheduledMessage" params)))
          (if result
              (let ((scheduled-msg (make-instance 'scheduled-message
                                                  :id scheduled-id
                                                  :chat-id chat-id
                                                  :text text
                                                  :send-date send-date
                                                  :created-at (get-universal-time)
                                                  :status :scheduled
                                                  :media media
                                                  :reply-markup reply-markup
                                                  :parse-mode parse-mode)))
                (setf (gethash scheduled-id *scheduled-messages*) scheduled-msg)
                (log-message :info "Scheduled message ~A for ~A" scheduled-id send-date)
                scheduled-msg)
              nil)))
    (error (e)
      (log-message :error "Error scheduling message: ~A" (princ-to-string e))
      nil)))

(defun get-scheduled-messages (chat-id &key (limit 100) (offset 0))
  "Get list of scheduled messages for a chat.

   Args:
     chat-id: Unique identifier for target chat
     limit: Maximum number of messages to return (1-100)
     offset: Offset for pagination

   Returns:
     List of scheduled-message objects on success, NIL on failure

   Example:
     (get-scheduled-messages 123456 :limit 50)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("limit" . ,limit)
                       ("offset" . ,offset))))
        (let ((result (make-api-call connection "getScheduledMessages" params)))
          (if result
              (let ((messages (getf result :messages)))
                (mapcar (lambda (msg-data)
                          (let* ((id (getf msg-data :id))
                                 (scheduled-msg (or (gethash id *scheduled-messages*)
                                                    (make-instance 'scheduled-message))))
                            (setf (scheduled-message-chat-id scheduled-msg) chat-id
                                  (scheduled-message-text scheduled-msg) (getf msg-data :text "")
                                  (scheduled-message-send-date scheduled-msg) (getf msg-data :send-date 0)
                                  (scheduled-message-status scheduled-msg) (getf msg-data :status :scheduled))
                            scheduled-msg))
                        messages))
              nil)))
    (error (e)
      (log-message :error "Error getting scheduled messages: ~A" (princ-to-string e))
      nil)))

(defun delete-scheduled-message (chat-id scheduled-message-id)
  "Delete a scheduled message.

   Args:
     chat-id: Unique identifier for target chat
     scheduled-message-id: ID of the scheduled message to delete

   Returns:
     T on success, NIL on failure

   Example:
     (delete-scheduled-message 123456 789)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("scheduled_message_id" . ,scheduled-message-id))))
        (let ((result (make-api-call connection "deleteScheduledMessage" params)))
          (if result
              (progn
                (remhash scheduled-message-id *scheduled-messages*)
                (log-message :info "Deleted scheduled message ~A" scheduled-message-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting scheduled message: ~A" (princ-to-string e))
      nil)))

(defun edit-scheduled-message (chat-id scheduled-message-id &key (text nil) (media nil) (reply-markup nil) (parse-mode nil))
  "Edit a scheduled message.

   Args:
     chat-id: Unique identifier for target chat
     scheduled-message-id: ID of the scheduled message to edit
     text: New message text (optional)
     media: New media attachment (optional)
     reply-markup: New reply keyboard (optional)
     parse-mode: New parse mode (optional)

   Returns:
     Updated scheduled-message object on success, NIL on failure

   Example:
     (edit-scheduled-message 123456 789 :text \"Updated reminder text\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("scheduled_message_id" . ,scheduled-message-id))))
        ;; Add optional parameters
        (when text
          (push (cons "text" text) params))
        (when media
          (push (cons "media" (json:encode-to-string media)) params))
        (when reply-markup
          (push (cons "reply_markup" (json:encode-to-string reply-markup)) params))
        (when parse-mode
          (push (cons "parse_mode" parse-mode) params))

        (let ((result (make-api-call connection "editScheduledMessage" params)))
          (if result
              (let ((scheduled-msg (gethash scheduled-message-id *scheduled-messages*)))
                (when scheduled-msg
                  (when text
                    (setf (scheduled-message-text scheduled-msg) text))
                  (when media
                    (setf (scheduled-message-media scheduled-msg) media))
                  (when reply-markup
                    (setf (scheduled-message-reply-markup scheduled-msg) reply-markup))
                  (when parse-mode
                    (setf (scheduled-message-parse-mode scheduled-msg) parse-mode)))
                scheduled-msg)
              nil)))
    (error (e)
      (log-message :error "Error editing scheduled message: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 3: Draft Message Functions
;;; ============================================================================

(defun save-message-draft (chat-id text &key (message-thread-id nil) (entities nil))
  "Save a message draft.

   Args:
     chat-id: Unique identifier for target chat
     text: Draft text content (1-4096 characters)
     message-thread-id: Optional thread ID for supergroups
     entities: Optional list of message entities

   Returns:
     T on success, NIL on failure

   Example:
     (save-message-draft 123456 \"Draft: Need to follow up on this\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (draft-key (format nil "~A:~A" chat-id (or message-thread-id "main")))
             (params `(("chat_id" . ,chat-id)
                       ("message" . ,text))))
        ;; Add optional parameters
        (when message-thread-id
          (push (cons "message_thread_id" message-thread-id) params))
        (when entities
          (push (cons "entities" (json:encode-to-string entities)) params))

        (let ((result (make-api-call connection "saveDraft" params)))
          (if (or result (eq result t))
              (let ((draft (make-instance 'message-draft
                                          :id draft-key
                                          :chat-id chat-id
                                          :message-thread-id message-thread-id
                                          :text text
                                          :entities entities
                                          :updated-at (get-universal-time))))
                (setf (gethash draft-key *message-drafts*) draft)
                (log-message :info "Saved draft for chat ~A" chat-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error saving draft: ~A" (princ-to-string e))
      nil)))

(defun get-message-drafts (&key (chat-ids nil))
  "Get all message drafts or drafts for specific chats.

   Args:
     chat-ids: Optional list of chat IDs to filter drafts

   Returns:
     List of message-draft objects on success, NIL on failure

   Example:
     (get-message-drafts)
     (get-message-drafts :chat-ids '(123456 789012))"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        ;; If specific chat IDs requested, fetch from API
        (when chat-ids
          (push (cons "chat_ids" (json:encode-to-string chat-ids)) params))

        (let ((result (make-api-call connection "getMessageDrafts" params)))
          (if result
              (let ((drafts (getf result :drafts)))
                (mapcar (lambda (draft-data)
                          (let* ((chat-id (getf draft-data :chat-id))
                                 (thread-id (getf draft-data :message-thread-id))
                                 (draft-key (format nil "~A:~A" chat-id (or thread-id "main")))
                                 (draft (or (gethash draft-key *message-drafts*)
                                            (make-instance 'message-draft))))
                            (setf (message-draft-chat-id draft) chat-id
                                  (message-draft-message-thread-id draft) thread-id
                                  (message-draft-text draft) (getf draft-data :text "")
                                  (message-draft-entities draft) (getf draft-data :entities)
                                  (message-draft-updated-at draft) (getf draft-data :updated-at 0))
                            draft))
                        drafts))
              ;; Fallback to local cache
              (let (draft-list)
                (maphash (lambda (k v)
                           (declare (ignore k))
                           (push v draft-list))
                         *message-drafts*)
                draft-list))))
    (error (e)
      (log-message :error "Error getting message drafts: ~A" (princ-to-string e))
      nil)))

(defun get-message-draft (chat-id &key (message-thread-id nil))
  "Get a specific message draft for a chat.

   Args:
     chat-id: Unique identifier for target chat
     message-thread-id: Optional thread ID for supergroups

   Returns:
     Message-draft object or NIL

   Example:
     (get-message-draft 123456)
     (get-message-draft 123456 :message-thread-id 100)"
  (let ((draft-key (format nil "~A:~A" chat-id (or message-thread-id "main"))))
    (gethash draft-key *message-drafts*)))

(defun delete-message-draft (chat-id &key (message-thread-id nil))
  "Delete a message draft.

   Args:
     chat-id: Unique identifier for target chat
     message-thread-id: Optional thread ID for supergroups

   Returns:
     T on success, NIL on failure

   Example:
     (delete-message-draft 123456)
     (delete-message-draft 123456 :message-thread-id 100)"
  (handler-case
      (let* ((connection (get-current-connection))
             (draft-key (format nil "~A:~A" chat-id (or message-thread-id "main")))
             (params `(("chat_id" . ,chat-id))))
        (when message-thread-id
          (push (cons "message_thread_id" message-thread-id) params))

        (let ((result (make-api-call connection "deleteDraft" params)))
          (if (or result (eq result t))
              (progn
                (remhash draft-key *message-drafts*)
                (log-message :info "Deleted draft for chat ~A" chat-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting draft: ~A" (princ-to-string e))
      nil)))

(defun delete-all-message-drafts ()
  "Delete all message drafts.

   Returns:
     T on success, NIL on failure

   Example:
     (delete-all-message-drafts)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        (let ((result (make-api-call connection "deleteAllDrafts" params)))
          (if (or result (eq result t))
              (progn
                (clrhash *message-drafts*)
                (log-message :info "Deleted all drafts")
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting all drafts: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 4: Scheduled Message Sending
;;; ============================================================================

(defun send-pending-scheduled-messages ()
  "Send all scheduled messages that are due.

   Returns:
     Number of messages sent

   Example:
     (send-pending-scheduled-messages)"
  (let ((now (get-universal-time))
        (sent-count 0))
    (maphash (lambda (id msg)
               (when (and (eq (scheduled-message-status msg) :scheduled)
                          (<= (scheduled-message-send-date msg) now))
                 (handler-case
                     (let* ((connection (get-current-connection))
                            (params `(("chat_id" . ,(scheduled-message-chat-id msg))
                                      ("text" . ,(scheduled-message-text msg)))))
                       (when (scheduled-message-media msg)
                         (push (cons "media" (json:encode-to-string (scheduled-message-media msg))) params))
                       (when (scheduled-message-reply-markup msg)
                         (push (cons "reply_markup" (json:encode-to-string (scheduled-message-reply-markup msg))) params))
                       (when (scheduled-message-parse-mode msg)
                         (push (cons "parse_mode" (scheduled-message-parse-mode msg)) params))

                       (let ((result (make-api-call connection "sendMessage" params)))
                         (when result
                           (setf (scheduled-message-status msg) :sent)
                           (remhash id *scheduled-messages*)
                           (incf sent-count)
                           (log-message :info "Sent scheduled message ~A" id))))
                   (error (e)
                     (log-message :error "Error sending scheduled message ~A: ~A" id e)))))
             *scheduled-messages*)
    sent-count))

;;; ============================================================================
;;; Section 5: Utilities and Cache Management
;;; ============================================================================

(defun get-scheduled-message (scheduled-message-id)
  "Get a scheduled message by ID.

   Args:
     scheduled-message-id: ID of the scheduled message

   Returns:
     Scheduled-message object or NIL

   Example:
     (get-scheduled-message 789)"
  (gethash scheduled-message-id *scheduled-messages*))

(defun list-scheduled-messages ()
  "List all scheduled messages.

   Returns:
     List of scheduled-message objects

   Example:
     (list-scheduled-messages)"
  (let (msg-list)
    (maphash (lambda (k v)
               (declare (ignore k))
               (push v msg-list))
             *scheduled-messages*)
    msg-list))

(defun count-scheduled-messages ()
  "Count all scheduled messages.

   Returns:
     Number of scheduled messages

   Example:
     (count-scheduled-messages)"
  (hash-table-count *scheduled-messages*))

(defun clear-scheduled-message-cache ()
  "Clear scheduled message cache.

   Returns:
     T on success

   Example:
     (clear-scheduled-message-cache)"
  (clrhash *scheduled-messages*)
  t)

(defun clear-draft-cache ()
  "Clear draft message cache.

   Returns:
     T on success

   Example:
     (clear-draft-cache)"
  (clrhash *message-drafts*)
  t)

(defun cleanup-expired-drafts (&key (timeout *draft-cache-timeout*))
  "Clean up expired drafts from cache.

   Args:
     timeout: Timeout in seconds (default: *draft-cache-timeout*)

   Returns:
     Number of drafts cleaned up

   Example:
     (cleanup-expired-drafts)"
  (let ((now (get-universal-time))
        (count 0))
    (maphash (lambda (k v)
               (when (>= (- now (message-draft-updated-at v)) timeout)
                 (remhash k *message-drafts*)
                 (incf count)))
             *message-drafts*)
    (log-message :info "Cleaned up ~A expired drafts" count)
    count))

;;; ============================================================================
;;; Section 6: Initialization
;;; ============================================================================

(defun initialize-scheduled-messages ()
  "Initialize scheduled messages system.

   Returns:
     T on success

   Example:
     (initialize-scheduled-messages)"
  (handler-case
      (progn
        (log-message :info "Scheduled messages system initialized")
        t)
    (error (e)
      (log-message :error "Failed to initialize scheduled messages: ~A" e)
      nil)))

(defun shutdown-scheduled-messages ()
  "Shutdown scheduled messages system.

   Returns:
     T on success

   Example:
     (shutdown-scheduled-messages)"
  (handler-case
      (progn
        (clrhash *scheduled-messages*)
        (clrhash *message-drafts*)
        (log-message :info "Scheduled messages system shutdown complete")
        t)
    (error (e)
      (log-message :error "Failed to shutdown scheduled messages: ~A" e)
      nil)))

;;; End of scheduled-messages.lisp
