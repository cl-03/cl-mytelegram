;;; message-enhanced.lisp --- Enhanced message features for v0.32.0
;;;
;;; Provides support for:
;;; - Streaming message sending (Bot API 9.5+)
;;; - Scheduled message management
;;; - Draft management
;;; - Multi-media messages (albums)
;;; - Message copying
;;;
;;; Version: 0.32.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Streaming Message Support (Bot API 9.5+)
;;; ============================================================================

(defclass stream-message-session ()
  ((session-id :initarg :session-id :accessor stream-session-id)
   (chat-id :initarg :chat-id :accessor stream-session-chat-id)
   (message-text :initarg :message-text :initform "" :accessor stream-session-message-text)
   (partial-text :initarg :partial-text :initform "" :accessor stream-session-partial-text)
   (draft-id :initarg :draft-id :accessor stream-session-draft-id)
   (status :initarg :status :initform :pending :accessor stream-session-status)
   (created-at :initarg :created-at :accessor stream-session-created-at)
   (last-updated :initarg :last-updated :accessor stream-session-last-updated)
   (callback :initarg :callback :initform nil :accessor stream-session-callback)
   (lock :initform (bt:make-lock) :accessor stream-session-lock)))

(defvar *stream-message-sessions* (make-hash-table :test 'equal)
  "Hash table storing streaming message sessions")

(defvar *max-concurrent-streams* 10
  "Maximum number of concurrent message streams")

(defun send-message-draft (chat-id text &key (partial-text nil) (reply-to-message-id nil)
                                  (reply-markup nil) (business-connection-id nil))
  "Send a message draft (supports streaming via Bot API 9.5+).

   Args:
     chat-id: Target chat identifier
     text: Message text (full or partial)
     partial-text: Partial text for streaming updates
     reply-to-message-id: Optional reply target
     reply-markup: Optional reply keyboard
     business-connection-id: Optional business connection

   Returns:
     Sent message object or draft ID on success

   Example:
     (send-message-draft chat-id \"Streaming response...\" :partial-text \"Part 1\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMessageDraft
                                      :peer (make-peer-chat-id chat-id)
                                      :message (or partial-text text)
                                      :reply-to (when reply-to-message-id
                                                  (make-tl-object 'input-reply-to
                                                                  :reply-to-msg-id reply-to-message-id))
                                      :reply-markup reply-markup
                                      :business-connection-id business-connection-id)))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when (and result (getf result :id))
            (log:info "Message draft sent to ~A (partial=~A)" chat-id (not (null partial-text)))
            (values result (getf result :id)))))
    (t (e)
      (log:error "Send message draft failed: ~A" e)
      (values nil (format nil "Error: ~A" e)))))

(defun send-message-stream (chat-id initial-text &key (callback nil) (update-interval 0.1))
  "Create a streaming message session.

   Args:
     chat-id: Target chat identifier
     initial-text: Initial message text
     callback: Optional callback for each stream update
     update-interval: Minimum interval between updates in seconds

   Returns:
     Stream-message-session instance

   Example:
     (let ((session (send-message-stream chat-id \"Generating...\")))
       (stream-message-update session \"Generating... Part 1\")
       (stream-message-update session \"Generating... Part 1, Part 2\")
       (stream-message-finalize session))"
  (let* ((session-id (format nil "stream_~A_~A" (get-universal-time) (random (expt 2 32))))
         (draft-result (send-message-draft chat-id initial-text :partial-text initial-text))
         (draft-id (nth-value 1 draft-result))
         (session (make-instance 'stream-message-session
                                 :session-id session-id
                                 :chat-id chat-id
                                 :message-text initial-text
                                 :partial-text initial-text
                                 :draft-id draft-id
                                 :created-at (get-universal-time)
                                 :last-updated (get-universal-time)
                                 :callback callback)))
    (setf (gethash session-id *stream-message-sessions*) session)
    (log:info "Stream message session created: ~A" session-id)
    session))

(defun stream-message-update (session-id new-text)
  "Update a streaming message with new text.

   Args:
     session-id: Stream session identifier
     new-text: Updated message text

   Returns:
     T on success, NIL on error

   Example:
     (stream-message-update session-id \"Updated content...\")"
  (let ((session (gethash session-id *stream-message-sessions*)))
    (unless session
      (return-from stream-message-update (values nil "Session not found")))

    (bt:with-lock-held ((stream-session-lock session))
      (setf (stream-session-partial-text session) new-text)
      (setf (stream-session-last-updated session) (get-universal-time))

      ;; Send update
      (handler-case
          (let* ((connection (get-connection))
                 (request (make-tl-object 'messages.editMessage
                                          :peer (make-peer-chat-id (stream-session-chat-id session))
                                          :id (parse-integer (subseq (stream-session-draft-id session) 7))
                                          :message new-text)))
            (rpc-call connection request :timeout 30000)
            (log:info "Stream message updated: ~A" session-id)
            t))
        (t (e)
          (log:error "Stream message update failed: ~A" e)
          nil)))))

(defun stream-message-finalize (session-id &key (final-text nil))
  "Finalize a streaming message.

   Args:
     session-id: Stream session identifier
     final-text: Optional final text override

   Returns:
     Final message object on success

   Example:
     (stream-message-finalize session-id :final-text \"Complete response.\")"
  (let ((session (gethash session-id *stream-message-sessions*)))
    (unless session
      (return-from stream-message-finalize (values nil "Session not found")))

    (bt:with-lock-held ((stream-session-lock session))
      (let* ((final-text (or final-text (stream-session-partial-text session)))
             (connection (get-connection))
             (request (make-tl-object 'messages.editMessage
                                      :peer (make-peer-chat-id (stream-session-chat-id session))
                                      :id (parse-integer (subseq (stream-session-draft-id session) 7))
                                      :message final-text
                                      :no-forwards t)))
        (let ((result (rpc-call connection request :timeout 30000)))
          (setf (stream-session-status session) :finalized)
          (remhash session-id *stream-message-sessions*)
          (log:info "Stream message finalized: ~A" session-id)
          result)))))

;;; ============================================================================
;;; Section 2: Scheduled Messages
;;; ============================================================================

(defun schedule-message (chat-id text &key (schedule-date nil) (reply-to-message-id nil)
                                      (reply-markup nil) (no-forwards nil))
  "Schedule a message to be sent at a future time.

   Args:
     chat-id: Target chat identifier
     text: Message text
     schedule-date: Universal time to send message (default: +1 hour)
     reply-to-message-id: Optional reply target
     reply-markup: Optional reply keyboard
     no-forwards: Whether to prevent forwarding

   Returns:
     Scheduled message object on success

   Example:
     (schedule-message chat-id \"Reminder!\" :schedule-date (+ (get-universal-time) 3600))"
  (let ((schedule-date (or schedule-date (+ (get-universal-time) 3600))))
    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'messages.sendMessage
                                        :peer (make-peer-chat-id chat-id)
                                        :message text
                                        :reply-to (when reply-to-message-id
                                                    (make-tl-object 'input-reply-to
                                                                    :reply-to-msg-id reply-to-message-id))
                                        :reply-markup reply-markup
                                        :schedule-date schedule-date
                                        :no-forwards (or no-forwards nil))))
          (let ((result (rpc-call connection request :timeout 30000)))
            (when (and result (getf result :id))
              (log:info "Message scheduled for ~A (send date: ~A)" chat-id schedule-date)
              result)))
      (t (e)
        (log:error "Schedule message failed: ~A" e)
        (values nil (format nil "Error: ~A" e))))))

(defun get-scheduled-messages (chat-id)
  "Get all scheduled messages for a chat.

   Args:
     chat-id: Target chat identifier

   Returns:
     List of scheduled messages

   Example:
     (get-scheduled-messages chat-id)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getScheduledMessages
                                      :peer (make-peer-chat-id chat-id)
                                      :id nil)))
        (let ((result (rpc-call connection request :timeout 30000)))
          (log:info "Retrieved scheduled messages for ~A" chat-id)
          result))
    (t (e)
      (log:error "Get scheduled messages failed: ~A" e)
      nil)))

(defun delete-scheduled-message (chat-id message-id)
  "Delete a scheduled message.

   Args:
     chat-id: Target chat identifier
     message-id: Scheduled message identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-scheduled-message chat-id 12345)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.deleteScheduledMessages
                                      :peer (make-peer-chat-id chat-id)
                                      :id (list message-id))))
        (rpc-call connection request :timeout 30000)
        (log:info "Scheduled message deleted: ~A/~A" chat-id message-id)
        t)
    (t (e)
      (log:error "Delete scheduled message failed: ~A" e)
      nil)))

(defun send-scheduled-message-now (chat-id message-id)
  "Send a scheduled message immediately.

   Args:
     chat-id: Target chat identifier
     message-id: Scheduled message identifier

   Returns:
     Sent message object on success

   Example:
     (send-scheduled-message-now chat-id 12345)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendScheduledMessages
                                      :peer (make-peer-chat-id chat-id)
                                      :id (list message-id))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (log:info "Scheduled message sent now: ~A/~A" chat-id message-id)
          result))
    (t (e)
      (log:error "Send scheduled message now failed: ~A" e)
      (values nil (format nil "Error: ~A" e)))))

;;; ============================================================================
;;; Section 3: Draft Management
;;; ============================================================================

(defun save-draft (chat-id text &key (reply-to-message-id nil) (entities nil))
  "Save a message draft.

   Args:
     chat-id: Target chat identifier
     text: Draft message text
     reply-to-message-id: Optional reply target
     entities: Optional message entities (formatting)

   Returns:
     T on success, NIL on error

   Example:
     (save-draft chat-id \"Hello, this is a draft\" :reply-to-message-id 123)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.saveDraft
                                      :peer (make-peer-chat-id chat-id)
                                      :message text
                                      :reply-to (when reply-to-message-id
                                                  (make-tl-object 'input-reply-to
                                                                  :reply-to-msg-id reply-to-message-id))
                                      :entities (or entities nil))))
        (rpc-call connection request :timeout 30000)
        (log:info "Draft saved for ~A" chat-id)
        t)
    (t (e)
      (log:error "Save draft failed: ~A" e)
      nil)))

(defun get-drafts (chat-id)
  "Get draft for a specific chat.

   Args:
     chat-id: Target chat identifier

   Returns:
     Draft message object or NIL

   Example:
     (get-drafts chat-id)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getPeerDrafts
                                      :peer (make-peer-chat-id chat-id))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (log:info "Retrieved draft for ~A" chat-id)
          result))
    (t (e)
      (log:error "Get draft failed: ~A" e)
      nil)))

(defun get-all-drafts ()
  "Get all drafts across all chats.

   Returns:
     List of all drafts

   Example:
     (get-all-drafts)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getAllDrafts")))
        (let ((result (rpc-call connection request :timeout 30000)))
          (log:info "Retrieved all drafts")
          result))
    (t (e)
      (log:error "Get all drafts failed: ~A" e)
      nil)))

(defun delete-draft (chat-id)
  "Delete draft for a specific chat.

   Args:
     chat-id: Target chat identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-draft chat-id)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.deleteDraft
                                      :peer (make-peer-chat-id chat-id))))
        (rpc-call connection request :timeout 30000)
        (log:info "Draft deleted for ~A" chat-id)
        t)
    (t (e)
      (log:error "Delete draft failed: ~A" e)
      nil)))

(defun clear-all-drafts ()
  "Clear all drafts.

   Returns:
     T on success, NIL on error

   Example:
     (clear-all-drafts)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.clearAllDrafts")))
        (rpc-call connection request :timeout 30000)
        (log:info "All drafts cleared")
        t)
    (t (e)
      (log:error "Clear all drafts failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: Multi-Media Messages (Albums)
;;; ============================================================================

(defclass input-media ()
  ((media-type :initarg :media-type :accessor input-media-type)
   (media-id :initarg :media-id :accessor input-media-id)
   (media-file :initarg :media-file :initform nil :accessor input-media-file)
   (caption :initarg :caption :initform "" :accessor input-media-caption)
   (parse-mode :initarg :parse-mode :initform nil :accessor input-media-parse-mode)))

(defun make-photo-media (media-id &key (caption "") (parse-mode nil))
  "Create a photo media input.

   Args:
     media-id: File ID or URL
     caption: Optional caption
     parse-mode: Parse mode (Markdown, HTML)

   Returns:
     Input-media instance"
  (make-instance 'input-media
                 :media-type :photo
                 :media-id media-id
                 :caption caption
                 :parse-mode parse-mode))

(defun make-video-media (media-id &key (caption "") (parse-mode nil) (thumbnail nil))
  "Create a video media input.

   Args:
     media-id: File ID or URL
     caption: Optional caption
     parse-mode: Parse mode
     thumbnail: Optional thumbnail

   Returns:
     Input-media instance"
  (make-instance 'input-media
                 :media-type :video
                 :media-id media-id
                 :caption caption
                 :parse-mode parse-mode))

(defun make-document-media (media-id &key (caption "") (parse-mode nil))
  "Create a document media input.

   Args:
     media-id: File ID or URL
     caption: Optional caption
     parse-mode: Parse mode

   Returns:
     Input-media instance"
  (make-instance 'input-media
                 :media-type :document
                 :media-id media-id
                 :caption caption
                 :parse-mode parse-mode))

(defun send-album (chat-id media-list &key (caption nil) (reply-to-message-id nil)
                                        (disable-notification nil))
  "Send an album (multi-media message).

   Args:
     chat-id: Target chat identifier
     media-list: List of input-media objects
     caption: Optional caption for first media
     reply-to-message-id: Optional reply target
     disable-notification: Whether to send silently

   Returns:
     List of sent messages on success

   Example:
     (send-album chat-id (list (make-photo-media file1)
                               (make-photo-media file2)
                               (make-video-media video1))
                 :caption \"My Album\")"
  (handler-case
      (let* ((connection (get-connection))
             (media-objects (mapcar (lambda (media)
                                      (case (input-media-type media)
                                        (:photo (make-tl-object 'input-media-photo
                                                                :id (input-media-id media)
                                                                :caption (input-media-caption media)))
                                        (:video (make-tl-object 'input-media-video
                                                                :id (input-media-id media)
                                                                :caption (input-media-caption media)))
                                        (:document (make-tl-object 'input-media-document
                                                                   :id (input-media-id media)
                                                                   :caption (input-media-caption media)))
                                        (otherwise nil)))
                                    media-list)))
        (let ((request (make-tl-object 'messages.sendMultiMedia
                                       :peer (make-peer-chat-id chat-id)
                                       :multi-media media-objects
                                       :reply-to (when reply-to-message-id
                                                   (make-tl-object 'input-reply-to
                                                                   :reply-to-msg-id reply-to-message-id))
                                       :silent (or disable-notification nil))))
          (let ((result (rpc-call connection request :timeout 60000)))
            (log:info "Album sent to ~A (~D media)" chat-id (length media-list))
            result)))
    (t (e)
      (log:error "Send album failed: ~A" e)
      (values nil (format nil "Error: ~A" e)))))

;;; ============================================================================
;;; Section 5: Message Copying
;;; ============================================================================

(defun copy-message (chat-id from-chat-id message-id &key (caption nil) (reply-markup nil))
  "Copy a message to another chat.

   Args:
     chat-id: Target chat identifier
     from-chat-id: Source chat identifier
     message-id: Message to copy
     caption: Optional new caption
     reply-markup: Optional reply keyboard

   Returns:
     Copied message object on success

   Example:
     (copy-message chat-id source-chat 12345 :caption \"Forwarded content\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.copyMessage
                                      :from-peer (make-peer-chat-id from-chat-id)
                                      :id message-id
                                      :to-peer (make-peer-chat-id chat-id)
                                      :caption (or caption "")
                                      :reply-markup reply-markup)))
        (let ((result (rpc-call connection request :timeout 30000)))
          (log:info "Message copied from ~A to ~A (id=~A)" from-chat-id chat-id message-id)
          result))
    (t (e)
      (log:error "Copy message failed: ~A" e)
      (values nil (format nil "Error: ~A" e)))))

(defun copy-messages (chat-id from-chat-id message-ids &key (drop-author nil))
  "Copy multiple messages to another chat.

   Args:
     chat-id: Target chat identifier
     from-chat-id: Source chat identifier
     message-ids: List of messages to copy
     drop-author: Whether to remove author signature

   Returns:
     List of copied message IDs on success

   Example:
     (copy-messages chat-id source-chat '(123 456 789))"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.copyMessages
                                      :from-peer (make-peer-chat-id from-chat-id)
                                      :to-peer (make-peer-chat-id chat-id)
                                      :id message-ids
                                      :drop-author (or drop-author nil))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (log:info "Messages copied from ~A to ~A (~D messages)"
                    from-chat-id chat-id (length message-ids))
          result))
    (t (e)
      (log:error "Copy messages failed: ~A" e)
      (values nil (format nil "Error: ~A" e)))))

;;; ============================================================================
;;; Section 6: Statistics and Utilities
;;; ============================================================================

(defun get-message-stats (&key (chat-id nil) (period :all))
  "Get message statistics.

   Args:
     chat-id: Optional chat filter
     period: Time period (:day, :week, :month, :all)

   Returns:
     Plist with message statistics

   Example:
     (get-message-stats :period :week)"
  (let ((stats (list :total-sent 0
                     :total-scheduled 0
                     :total-drafts 0
                     :period period)))
    ;; Count scheduled messages
    (when chat-id
      (let ((scheduled (get-scheduled-messages chat-id)))
        (setf (getf stats :total-scheduled) (length (or scheduled '())))))

    ;; Count drafts
    (let ((drafts (get-all-drafts)))
      (setf (getf stats :total-drafts) (length (or drafts '()))))

    stats))

;;; End of message-enhanced.lisp
