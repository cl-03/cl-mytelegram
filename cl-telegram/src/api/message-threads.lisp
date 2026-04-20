;;; message-threads.lisp --- Message replies and threads
;;;
;;; Provides support for:
;;; - Message replies (reply to specific message)
;;; - Message threads (grouped messages by topic)
;;; - Forward messages with reply chain
;;; - Quote messages in replies
;;; - Thread statistics

(in-package #:cl-telegram/api)

;;; ### Message Thread Types

(defclass message-reply ()
  ((reply-id :initarg :reply-id :reader message-reply-id)
   (message-id :initarg :message-id :reader message-reply-message-id)
   (chat-id :initarg :chat-id :reader message-reply-chat-id)
   (reply-to-message-id :initarg :reply-to-message-id :reader message-reply-to-id)
   (from :initarg :from :reader message-reply-from)
   (text :initarg :text :reader message-reply-text)
   (date :initarg :date :reader message-reply-date)
   (quote-text :initarg :quote-text :reader message-reply-quote-text)
   (quote-entities :initarg :quote-entities :reader message-reply-quote-entities)))

(defclass message-thread ()
  ((thread-id :initarg :thread-id :reader message-thread-id)
   (chat-id :initarg :chat-id :reader message-thread-chat-id)
   (topic :initarg :topic :reader message-thread-topic)
   (root-message-id :initarg :root-message-id :reader message-thread-root-id)
   (message-count :initarg :message-count :reader message-thread-message-count)
   (unread-count :initarg :unread-count :reader message-thread-unread-count)
   (last-message-id :initarg :last-message-id :reader message-thread-last-id)
   (last-message-date :initarg :last-message-date :reader message-thread-last-date)
   (participants :initarg :participants :reader message-thread-participants)
   (is-closed :initarg :is-closed :initform nil :reader message-thread-is-closed)
   (is-pinned :initarg :is-pinned :initform nil :reader message-thread-is-pinned)))

(defclass reply-chain ()
  ((chain-id :initarg :chain-id :reader reply-chain-id)
   (message-id :initarg :message-id :reader reply-chain-message-id)
   (chat-id :initarg :chat-id :reader reply-chain-chat-id)
   (replies :initarg :replies :initform nil :reader reply-chain-replies)
   (total-reply-count :initarg :total-reply-count :initform 0 :reader reply-chain-total-count)))

;;; ### Global State

(defvar *reply-cache* (make-hash-table :test 'equal)
  "Cache for message replies")

(defvar *thread-cache* (make-hash-table :test 'equal)
  "Cache for message threads")

(defvar *active-threads* (make-hash-table :test 'equal)
  "Active thread tracking by chat-id")

;;; ### Message Replies

(defun send-message-with-reply (chat-id text reply-to-message-id &key (quote-text nil) (parse-mode nil) (entities nil))
  "Send message with reply to another message.

   Args:
     chat-id: Chat identifier
     text: Message text
     reply-to-message-id: Message ID to reply to
     quote-text: Optional quote from original message
     parse-mode: Parse mode (nil, \"Markdown\", \"HTML\")
     entities: Message entities for formatting

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (reply-to (make-tl-object 'inputMessageReplyTo
                                       :reply-to-msg-id reply-to-message-id
                                       :quote-text (or quote-text "")
                                       :quote-entities (or entities nil)))
             (message (make-tl-object 'inputMessageText
                                      :message text
                                      :entities (when parse-mode
                                                  (parse-message-entities text parse-mode))
                                      :clear-draft nil))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'messages.sendMessage
                                      :peer peer
                                      :message message
                                      :random-id random-id
                                      :schedule-date 0
                                      :reply-to reply-to
                                      :reply-markup nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to send message with reply: ~A" error)
                nil)
              (let ((msg (parse-message-from-tl result)))
                ;; Cache the reply
                (let ((key (format nil "~A:~A" chat-id reply-to-message-id)))
                  (let ((chain (gethash key *reply-cache*)))
                    (if chain
                        (progn
                          (push msg (slot-value chain 'replies))
                          (incf (slot-value chain 'total-reply-count)))
                        (setf (gethash key *reply-cache*)
                              (make-instance 'reply-chain
                                             :chain-id key
                                             :message-id reply-to-message-id
                                             :chat-id chat-id
                                             :replies (list msg)
                                             :total-reply-count 1)))))
                msg))))
    (error (e)
      (log:error "Exception in send-message-with-reply: ~A" e)
      nil)))

(defun get-message-replies (chat-id message-id &key (limit 50) (offset 0))
  "Get all replies to a message.

   Args:
     chat-id: Chat identifier
     message-id: Message ID to get replies for
     limit: Maximum replies to return
     offset: Offset for pagination

   Returns:
     List of message-reply objects"
  (let ((key (format nil \"~A:~A\" chat-id message-id)))
    (gethash key *reply-cache*)))

(defun get-reply-to-message (reply-message)
  "Get the message that a reply is replying to.

   Args:
     reply-message: Reply message object

   Returns:
     Original message object or NIL"
  (handler-case
      (when (and reply-message (getf reply-message :reply-to))
        (let* ((connection (get-connection))
               (reply-to (getf reply-message :reply-to))
               (peer (make-tl-object 'inputPeerUser :user-id (getf reply-to :chat-id) :access-hash 0))
               (msg-id (getf reply-to :msg-id))
               (request (make-tl-object 'messages.getMessages
                                        :id (list msg-id))))
          (multiple-value-bind (result error)
              (rpc-handler-case (rpc-call connection request :timeout 10000)
                (tl-rpc-error (e) (values nil (error-message e)))
                (timeout-error (e) (values nil :timeout))
                (network-error (e) (values nil :network-error)))
            (if error
                (progn
                  (log:error "Failed to get reply-to message: ~A" error)
                  nil)
                (parse-message-from-tl result)))))
    (error (e)
      (log:error "Exception in get-reply-to-message: ~A" e)
      nil)))

(defun edit-message-with-reply (chat-id message-id new-text &key (reply-to-message-id nil))
  "Edit message and optionally add/change reply.

   Args:
     chat-id: Chat identifier
     message-id: Message ID to edit
     new-text: New message text
     reply-to-message-id: Optional message ID to reply to

   Returns:
     Edited message object"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (request (make-tl-object 'messages.editMessage
                                      :peer peer
                                      :id message-id
                                      :message new-text
                                      :no-webpage nil
                                      :reply-markup nil
                                      :entities nil
                                      :schedule-date 0
                                      :reply-to (when reply-to-message-id
                                                  (make-tl-object 'inputMessageReplyTo
                                                                    :reply-to-msg-id reply-to-message-id
                                                                    :quote-text ""
                                                                    :quote-entities nil)))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to edit message with reply: ~A" error)
                nil)
              (parse-message-from-tl result))))
    (error (e)
      (log:error "Exception in edit-message-with-reply: ~A" e)
      nil)))

(defun forward-message-with-reply (from-chat-id to-chat-id message-id &key (as-reply nil))
  "Forward message, optionally as reply.

   Args:
     from-chat-id: Source chat ID
     to-chat-id: Destination chat ID
     message-id: Message ID to forward
     as-reply: If T, forward as reply to latest message

   Returns:
     Forwarded message object"
  (handler-case
      (let* ((connection (get-connection))
             (from-peer (make-tl-object 'inputPeerUser :user-id from-chat-id :access-hash 0))
             (to-peer (make-tl-object 'inputPeerUser :user-id to-chat-id :access-hash 0))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'messages.forwardMessages
                                      :from-peer from-peer
                                      :to-peer to-peer
                                      :id (list message-id)
                                      :random-id (list random-id)
                                      :as-reply as-reply
                                      :drop-author nil
                                      :drop-media-captions nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to forward message with reply: ~A" error)
                nil)
              (parse-message-from-tl result))))
    (error (e)
      (log:error "Exception in forward-message-with-reply: ~A" e)
      nil)))

;;; ### Message Threads

(defun create-message-thread (chat-id topic &key (message-id nil))
  "Create a new message thread.

   Args:
     chat-id: Chat identifier
     topic: Thread topic/title
     message-id: Optional root message ID

   Returns:
     Message-thread object on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'messages.createForumTopic
                                      :channel peer
                                      :title topic
                                      :random-id random-id
                                      :video-chat-id 0
                                      :icon-color 0
                                      :icon-emoji-id 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to create message thread: ~A" error)
                nil)
              (let ((thread (parse-thread-from-tl result)))
                (when thread
                  (let ((key (format nil "~A:~A" chat-id (message-thread-id thread))))
                    (setf (gethash key *thread-cache*) thread))
                  (setf (gethash (format nil "~A:~A" chat-id topic) *active-threads*) thread))
                thread))))
    (error (e)
      (log:error "Exception in create-message-thread: ~A" e)
      nil)))

(defun get-message-thread (chat-id thread-id)
  "Get message thread by ID.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier

   Returns:
     Message-thread object or NIL"
  (let ((key (format nil \"~A:~A\" chat-id thread-id)))
    (gethash key *thread-cache*)))

(defun get-threads-by-chat (chat-id)
  "Get all threads in a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     List of message-thread objects"
  (loop for key being the hash-keys of *thread-cache*
        when (search (format nil \"~A:\" chat-id) key)
        collect (gethash key *thread-cache*)))

(defun get-active-threads (chat-id &key (limit 20))
  "Get active (non-closed) threads.

   Args:
     chat-id: Chat identifier
     limit: Maximum threads to return

   Returns:
     List of active message-thread objects"
  (let ((threads (get-threads-by-chat chat-id)))
    (subseq (remove-if #'message-thread-is-closed threads) 0
            (min limit (length threads)))))

(defun get-closed-threads (chat-id &key (limit 20))
  "Get closed threads.

   Args:
     chat-id: Chat identifier
     limit: Maximum threads to return

   Returns:
     List of closed message-thread objects"
  (let ((threads (get-threads-by-chat chat-id)))
    (subseq (remove-if-not #'message-thread-is-closed threads) 0
            (min limit (length threads)))))

(defun send-message-to-thread (chat-id thread-id text &key (reply-to-message-id nil))
  "Send message to a thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier
     text: Message text
     reply-to-message-id: Optional message ID to reply to within thread

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (message (make-tl-object 'inputMessageText
                                      :message text
                                      :entities nil
                                      :clear-draft nil))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'messages.sendMessage
                                      :peer peer
                                      :message message
                                      :random-id random-id
                                      :schedule-date 0
                                      :reply-to (when reply-to-message-id
                                                  (make-tl-object 'inputMessageReplyTo
                                                                    :reply-to-msg-id reply-to-message-id
                                                                    :quote-text ""
                                                                    :quote-entities nil))
                                      :reply-markup nil
                                      :top-msg-id thread-id)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to send message to thread: ~A" error)
                nil)
              (parse-message-from-tl result))))
    (error (e)
      (log:error "Exception in send-message-to-thread: ~A" e)
      nil)))

(defun close-message-thread (chat-id thread-id)
  "Close a message thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier

   Returns:
     T on success"
  (let ((key (format nil \"~A:~A\" chat-id thread-id)))
    (let ((thread (gethash key *thread-cache*)))
      (when thread
        (setf (slot-value thread 'is-closed) t)
        t))))

(defun reopen-message-thread (chat-id thread-id)
  "Reopen a closed thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier

   Returns:
     T on success"
  (let ((key (format nil \"~A:~A\" chat-id thread-id)))
    (let ((thread (gethash key *thread-cache*)))
      (when thread
        (setf (slot-value thread 'is-closed) nil)
        t))))

(defun pin-message-thread (chat-id thread-id)
  "Pin a message thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier

   Returns:
     T on success"
  (let ((key (format nil \"~A:~A\" chat-id thread-id)))
    (let ((thread (gethash key *thread-cache*)))
      (when thread
        (setf (slot-value thread 'is-pinned) t)
        t))))

(defun unpin-message-thread (chat-id thread-id)
  "Unpin a message thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier

   Returns:
     T on success"
  (let ((key (format nil \"~A:~A\" chat-id thread-id)))
    (let ((thread (gethash key *thread-cache*)))
      (when thread
        (setf (slot-value thread 'is-pinned) nil)
        t))))

(defun delete-message-thread (chat-id thread-id)
  "Delete a message thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier

   Returns:
     T on success"
  (let ((key (format nil \"~A:~A\" chat-id thread-id)))
    (remhash key *thread-cache*)
    t))

(defun edit-message-thread (chat-id thread-id &key (topic nil))
  "Edit message thread properties.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier
     topic: New topic title

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (request (make-tl-object 'messages.editForumTopic
                                      :channel peer
                                      :topic thread-id
                                      :title (or topic "")
                                      :icon-emoji-id 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to edit message thread: ~A" error)
                nil)
              (progn
                ;; Update cache
                (let ((thread (get-message-thread chat-id thread-id)))
                  (when thread
                    (setf (slot-value thread 'topic) topic)))
                t))))
    (error (e)
      (log:error "Exception in edit-message-thread: ~A" e)
      nil)))

;;; ### Reply Chains

(defun get-reply-chain (chat-id message-id)
  "Get reply chain for a message.

   Args:
     chat-id: Chat identifier
     message-id: Root message ID

   Returns:
     Reply-chain object"
  (let ((key (format nil \"~A:~A\" chat-id message-id)))
    (gethash key *reply-cache*)))

(defun add-reply-to-chain (chat-id root-message-id reply-message)
  "Add reply to chain.

   Args:
     chat-id: Chat identifier
     root-message-id: Root message ID
     reply-message: Reply message object

   Returns:
     T on success"
  (let ((key (format nil \"~A:~A\" chat-id root-message-id)))
    (let ((chain (gethash key *reply-cache*)))
      (if chain
          (progn
            (push reply-message (slot-value chain 'replies))
            (incf (slot-value chain 'total-reply-count)))
          (setf (gethash key *reply-cache*)
                (make-instance 'reply-chain
                               :chain-id key
                               :message-id root-message-id
                               :chat-id chat-id
                               :replies (list reply-message)
                               :total-reply-count 1))))
    t))

(defun get-thread-messages (chat-id thread-id &key (limit 50) (offset 0))
  "Get messages in a thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier
     limit: Maximum messages to return
     offset: Offset for pagination

   Returns:
     List of message objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (request (make-tl-object 'messages.getHistory
                                      :peer peer
                                      :offset-id offset
                                      :offset-date 0
                                      :add-offset 0
                                      :limit limit
                                      :max-id 0
                                      :min-id 0
                                      :hash 0
                                      :top-msg-id thread-id)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get thread messages: ~A" error)
                nil)
              (parse-messages-from-tl result))))
    (error (e)
      (log:error "Exception in get-thread-messages: ~A" e)
      nil)))

;;; ### Quote/Context in Replies

(defun make-quote-text (text &key (entities nil) (max-length 100))
  "Create quote text for reply.

   Args:
     text: Text to quote
     entities: Text entities for formatting
     max-length: Maximum quote length

   Returns:
     Quote string"
  (if (> (length text) max-length)
      (format nil \"~A...\" (subseq text 0 max-length))
      text))

(defun parse-quote-from-message (message &key (max-length 100))
  "Parse quote from message for reply.

   Args:
     message: Message object
     max-length: Maximum quote length

   Returns:
     Quote plist with text and entities"
  (let ((text (getf message :text)))
    (when text
      (list :text (make-quote-text text :max-length max-length)
            :entities (getf message :entities)))))

;;; ### Thread Statistics

(defun get-thread-stats (chat-id thread-id)
  "Get statistics for a thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier

   Returns:
     Stats plist with message-count, participant-count, etc."
  (let ((thread (get-message-thread chat-id thread-id)))
    (when thread
      (list :message-count (message-thread-message-count thread)
            :participant-count (length (message-thread-participants thread))
            :unread-count (message-thread-unread-count thread)
            :last-activity (message-thread-last-date thread)))))

(defun get-thread-participants (chat-id thread-id &key (limit 100))
  "Get participants in a thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier
     limit: Maximum participants to return

   Returns:
     List of user objects"
  (let ((thread (get-message-thread chat-id thread-id)))
    (when thread
      (subseq (message-thread-participants thread) 0
              (min limit (length (message-thread-participants thread)))))))

(defun add-participant-to-thread (chat-id thread-id user-id)
  "Add participant to thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier
     user-id: User to add

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (user-peer (make-tl-object 'inputPeerUser :user-id user-id :access-hash 0))
             (request (make-tl-object 'messages.addChatUser
                                      :chat-id peer
                                      :user-id user-peer
                                      :fwd-limit 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to add participant to thread: ~A" error)
                nil)
              (progn
                ;; Update cache
                (let ((thread (get-message-thread chat-id thread-id)))
                  (when thread
                    (pushnew user-id (slot-value thread 'participants))))
                t))))
    (error (e)
      (log:error "Exception in add-participant-to-thread: ~A" e)
      nil)))

(defun remove-participant-from-thread (chat-id thread-id user-id)
  "Remove participant from thread.

   Args:
     chat-id: Chat identifier
     thread-id: Thread identifier
     user-id: User to remove

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0))
             (user-peer (make-tl-object 'inputPeerUser :user-id user-id :access-hash 0))
             (request (make-tl-object 'messages.deleteChatUser
                                      :chat-id peer
                                      :user-id user-peer)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to remove participant from thread: ~A" error)
                nil)
              (progn
                ;; Update cache
                (let ((thread (get-message-thread chat-id thread-id)))
                  (when thread
                    (setf (slot-value thread 'participants)
                          (remove user-id (slot-value thread 'participants)))))
                t))))
    (error (e)
      (log:error "Exception in remove-participant-from-thread: ~A" e)
      nil)))

;;; ### CLOG UI Integration

(defun render-reply-preview (win container reply-message on-click)
  "Render reply preview in message input area.

   Args:
     win: CLOG window object
     container: Container element
     reply-message: Message being replied to
     on-click: Callback for canceling reply"
  (let ((preview-el (clog:create-element win \"div\" :class \"reply-preview\"
                                          :style \"padding: 10px; background: #f0f0f0; border-left: 3px solid #0088cc; margin-bottom: 10px;\")))
    (clog:append! preview-el
                  (clog:create-element win \"div\" :class \"reply-header\"
                                       :style \"font-size: 12px; color: #666; margin-bottom: 5px;\"
                                       :text \"Replying to message\")
                  (clog:create-element win \"div\" :class \"reply-text\"
                                       :style \"font-size: 14px; color: #333;\"
                                       :text (if (and reply-message (getf reply-message :text))
                                                 (subseq (getf reply-message :text) 0 (min 50 (length (getf reply-message :text))))
                                                 \"[No text]\"))
                  (clog:create-element win \"button\" :class \"cancel-reply\"
                                       :style \"font-size: 12px; color: #666; cursor: pointer; margin-top: 5px;\"
                                       :text \"✕ Cancel\"))
    ;; Cancel reply handler
    (let ((cancel-btn (clog:query-selector preview-el \".cancel-reply\")))
      (clog:on cancel-btn :click
               (lambda (ev)
                 (declare (ignore ev))
                 (when on-click
                   (funcall on-click))
                 ;; Remove preview
                 (clog:remove-element preview-el))))
    (clog:append! container preview-el)))

(defun render-message-thread (win container thread on-select)
  "Render message thread in UI.

   Args:
     win: CLOG window object
     container: Container element
     thread: Message-thread object
     on-select: Callback for thread selection"
  (let ((thread-el (clog:create-element win \"div\" :class \"thread-item\"
                                         :style \"padding: 15px; border-bottom: 1px solid #eee; cursor: pointer;\")))
    ;; Thread header
    (clog:append! thread-el
                  (clog:create-element win \"div\" :class \"thread-topic\"
                                       :style \"font-weight: bold; margin-bottom: 5px;\"
                                       :text (message-thread-topic thread))
                  (clog:create-element win \"div\" :class \"thread-meta\"
                                       :style \"font-size: 12px; color: #666;\"
                                       :text (format nil \"~A messages • ~A unread\"
                                                     (message-thread-message-count thread)
                                                     (message-thread-unread-count thread))))
    ;; Click handler
    (clog:on thread-el :click
             (lambda (ev)
               (declare (ignore ev))
               (when on-select
                 (funcall on-select thread))))
    (clog:append! container thread-el)))

(defun render-thread-view (win container chat-id thread-id)
  "Render thread message view.

   Args:
     win: CLOG window object
     container: Container element
     chat-id: Chat identifier
     thread-id: Thread identifier"
  (let ((thread (get-message-thread chat-id thread-id)))
    (when thread
      ;; Thread header
      (clog:append! container
                    (clog:create-element win \"div\" :class \"thread-header\"
                                         :style \"padding: 15px; border-bottom: 1px solid #ddd;\"
                                         (clog:create-element win \"h3\" :text (message-thread-topic thread))
                                         (clog:create-element win \"div\" :class \"thread-actions\"
                                                              :style \"margin-top: 10px;\"
                                                              (if (message-thread-is-closed thread)
                                                                  (clog:create-element win \"button\" :class \"reopen-thread-btn\"
                                                                                       :text \"📖 Reopen Thread\"
                                                                                       :style \"padding: 5px 15px; cursor: pointer;\")
                                                                  (clog:create-element win \"button\" :class \"close-thread-btn\"
                                                                                       :text \"✓ Close Thread\"
                                                                                       :style \"padding: 5px 15px; cursor: pointer;\"))))
      ;; Thread actions
      (let ((close-btn (clog:query-selector container \".close-thread-btn\"))
            (reopen-btn (clog:query-selector container \".reopen-thread-btn\")))
        (when close-btn
          (clog:on close-btn :click
                   (lambda (ev)
                     (declare (ignore ev))
                     (close-message-thread chat-id thread-id)
                     ;; Refresh UI
                     (render-thread-view win container chat-id thread-id))))
        (when reopen-btn
          (clog:on reopen-btn :click
                   (lambda (ev)
                     (declare (ignore ev))
                     (reopen-message-thread chat-id thread-id)
                     ;; Refresh UI
                     (render-thread-view win container chat-id thread-id)))))
      ;; Messages container
      (let ((messages-el (clog:create-element win \"div\" :class \"thread-messages\"
                                               :style \"padding: 15px; height: 400px; overflow-y: auto;\"))
            (messages (get-thread-messages chat-id thread-id)))
        (clog:append! container messages-el)
        ;; Render messages
        (dolist (msg messages)
          (let ((msg-el (clog:create-element win \"div\" :class \"message\"
                                              :style \"margin-bottom: 10px;\")))
            (clog:append! msg-el
                          (clog:create-element win \"div\" :class \"message-from\"
                                               :style \"font-size: 12px; color: #666;\"
                                               :text (format nil \"From: ~A\" (getf msg :from)))
                          (clog:create-element win \"div\" :class \"message-text\"
                                               :text (getf msg :text)))
            (clog:append! messages-el msg-el)))
        ;; Reply input
        (let ((input-container (clog:create-element win \"div\" :class \"thread-input\"
                                                     :style \"padding: 15px; border-top: 1px solid #ddd;\")))
          (clog:append! input-container
                        (clog:create-element win \"input\" :type \"text\" :class \"thread-message-input\"
                                             :placeholder \"Reply in thread...\"
                                             :style \"width: 70%; padding: 10px; border: 1px solid #ddd; border-radius: 5px;\")
                        (clog:create-element win \"button\" :class \"send-thread-message\"
                                             :text \"Send\"
                                             :style \"margin-left: 10px; padding: 10px 20px; background: #0088cc; color: white; border: none; border-radius: 5px; cursor: pointer;\"))
          (clog:append! container input-container)
          ;; Send handler
          (let ((send-btn (clog:query-selector container \".send-thread-message\"))
                (input (clog:query-selector container \".thread-message-input\")))
            (clog:on send-btn :click
                     (lambda (ev)
                       (declare (ignore ev))
                       (let ((text (clog:text input)))
                         (when (and text (> (length text) 0))
                           (send-message-to-thread chat-id thread-id text)
                           (setf (clog:text input) \"\")
                           ;; Refresh messages
                           (render-thread-view win container chat-id thread-id)))))))))))

(defun render-thread-list-panel (win chat-id container &key (on-select nil))
  "Render thread list panel.

   Args:
     win: CLOG window object
     chat-id: Chat identifier
     container: Container element
     on-select: Callback for thread selection"
  ;; Tabs
  (clog:append! container
                (clog:create-element win \"div\" :class \"thread-tabs\"
                                     :style \"display: flex; border-bottom: 1px solid #ddd; margin-bottom: 15px;\"
                                     (clog:create-element win \"button\" :id \"active-threads-tab\"
                                                          :text \"Active\"
                                                          :style \"flex: 1; padding: 10px; border: none; background: #f5f5f5; cursor: pointer;\")
                                     (clog:create-element win \"button\" :id \"closed-threads-tab\"
                                                          :text \"Closed\"
                                                          :style \"flex: 1; padding: 10px; border: none; background: #f5f5f5; cursor: pointer;\")))
  ;; Content container
  (clog:append! container
                (clog:create-element win \"div\" :id \"thread-list-content\"
                                     :style \"max-height: 400px; overflow-y: auto;\"))

  ;; Load active threads by default
  (let ((content (clog:get-element-by-id win \"thread-list-content\"))
        (active-tab (clog:get-element-by-id win \"active-threads-tab\"))
        (closed-tab (clog:get-element-by-id win \"closed-threads-tab\")))
    ;; Render active threads
    (render-thread-list-content win content chat-id :show-active t :on-select on-select)

    ;; Tab handlers
    (clog:on active-tab :click
             (lambda (ev)
               (declare (ignore ev))
               (render-thread-list-content win content chat-id :show-active t :on-select on-select)))
    (clog:on closed-tab :click
             (lambda (ev)
               (declare (ignore ev))
               (render-thread-list-content win content chat-id :show-active nil :on-select on-select)))))

(defun render-thread-list-content (win container chat-id &key (show-active t) (on-select nil))
  "Render thread list content.

   Args:
     win: CLOG window object
     container: Container element
     chat-id: Chat identifier
     show-active: If T, show active threads; else show closed
     on-select: Callback for thread selection"
  (setf (clog:html container) \"\")
  (let ((threads (if show-active
                     (get-active-threads chat-id)
                     (get-closed-threads chat-id))))
    (if (null threads)
        (clog:append! container
                      (clog:create-element win \"div\" :class \"empty-state\"
                                           :text (if show-active \"No active threads\" \"No closed threads\")))
        (dolist (thread threads)
          (render-message-thread win container thread on-select)))))

;;; ### Utilities

(defun get-thread-by-root-message (chat-id root-message-id)
  "Get thread by root message ID.

   Args:
     chat-id: Chat identifier
     root-message-id: Root message ID

   Returns:
     Message-thread object or NIL"
  (loop for key being the hash-keys of *thread-cache*
        for thread = (gethash key *thread-cache*)
        when (and thread (= (message-thread-root-id thread) root-message-id))
        return thread))

(defun clear-thread-cache (&optional chat-id)
  "Clear thread cache.

   Args:
     chat-id: Optional chat ID to clear specific cache

   Returns:
     T on success"
  (if chat-id
      (loop for key being the hash-keys of *thread-cache*
            when (search (format nil \"~A:\" chat-id) key)
            do (remhash key *thread-cache*))
      (clrhash *thread-cache*))
  t)

(defun clear-reply-cache (&optional chat-id)
  "Clear reply cache.

   Args:
     chat-id: Optional chat ID to clear specific cache

   Returns:
     T on success"
  (if chat-id
      (loop for key being the hash-keys of *reply-cache*
            when (search (format nil \"~A:\" chat-id) key)
            do (remhash key *reply-cache*))
      (clrhash *reply-cache*))
  t)

(defun thread-is-active-p (thread)
  "Check if thread is active (not closed).

   Args:
     thread: Message-thread object

   Returns:
     T if thread is active"
  (not (message-thread-is-closed thread)))

(defun get-reply-count (chat-id message-id)
  "Get count of replies to a message.

   Args:
     chat-id: Chat identifier
     message-id: Message ID

   Returns:
     Reply count"
  (let ((chain (get-reply-chain chat-id message-id)))
    (if chain
        (reply-chain-total-count chain)
        0)))

;;; ### Parser Helper Functions

(defun parse-thread-from-tl (tl-object)
  "Parse TL object into message-thread instance.

   Args:
     tl-object: TL object from API response

   Returns:
     Message-thread instance or NIL"
  (when tl-object
    (handler-case
        (make-instance 'message-thread
                       :thread-id (get-tl-field tl-object :id)
                       :chat-id (get-tl-field tl-object :chat-id)
                       :topic (get-tl-field tl-object :title)
                       :root-message-id (get-tl-field tl-object :root-id)
                       :message-count (get-tl-field tl-object :messages-count)
                       :unread-count (get-tl-field tl-object :unread-count)
                       :last-message-id (get-tl-field tl-object :last-msg-id)
                       :last-message-date (get-tl-field tl-object :last-date)
                       :participants (get-tl-field tl-object :participants)
                       :is-closed (get-tl-field tl-object :closed)
                       :is-pinned (get-tl-field tl-object :pinned))
      (error (e)
        (log:error "Failed to parse thread: ~A" e)
        nil))))

(defun parse-messages-from-tl (tl-object)
  "Parse TL object into list of message objects.

   Args:
     tl-object: TL object from API response

   Returns:
     List of message objects"
  (when tl-object
    (let ((messages (get-tl-field tl-object :messages)))
      (when (listp messages)
        (loop for msg in messages
              collect (parse-message-from-tl msg))))))

(defun parse-reply-from-tl (tl-object)
  "Parse TL object into message-reply instance.

   Args:
     tl-object: TL object from API response

   Returns:
     Message-reply instance or NIL"
  (when tl-object
    (handler-case
        (make-instance 'message-reply
                       :reply-id (get-tl-field tl-object :id)
                       :message-id (get-tl-field tl-object :msg-id)
                       :chat-id (get-tl-field tl-object :chat-id)
                       :reply-to-message-id (get-tl-field tl-object :reply-to-msg-id)
                       :from (get-tl-field tl-object :from-id)
                       :text (get-tl-field tl-object :message)
                       :date (get-tl-field tl-object :date)
                       :quote-text (get-tl-field tl-object :quote-text)
                       :quote-entities (get-tl-field tl-object :quote-entities))
      (error (e)
        (log:error "Failed to parse reply: ~A" e)
        nil))))

(defun parse-replies-from-tl (tl-object)
  "Parse TL object into list of message-reply instances.

   Args:
     tl-object: TL object from API response

   Returns:
     List of message-reply instances"
  (when tl-object
    (let ((replies (get-tl-field tl-object :replies)))
      (when (listp replies)
        (loop for reply in replies
              collect (parse-reply-from-tl reply))))))
