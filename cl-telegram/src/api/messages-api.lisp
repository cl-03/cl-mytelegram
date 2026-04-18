;;; messages-api.lisp --- Messages API implementation

(in-package #:cl-telegram/api)

;;; ### Message Sending

(defun send-message (chat-id text &key (parse-mode nil) (entities nil))
  "Send a text message to a chat.

   CHAT-ID: The unique identifier of the chat
   TEXT: Text of the message to send (1-4096 characters)
   PARSE-MODE: Optional parsing mode (:markdown, :html)
   ENTITIES: Optional message entities for formatting

   Returns: message object on success, error on failure"
  (unless (authorized-p)
    (return-from send-message
      (values nil :not-authorized "User not authenticated")))

  (unless (and text (> (length text) 0) (<= (length text) 4096))
    (return-from send-message
      (values nil :invalid-message "Message text must be 1-4096 characters")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-message
        (values nil :no-connection "No active connection")))

    ;; Create sendMessage TL object
    (let ((request (make-tl-object
                    'messages.sendMessage
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :message text
                    :random-id (random (expt 2 63)))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Message send timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Retrieval

(defun get-messages (chat-id &key (limit 50) (offset 0) (from-message-id nil))
  "Get message history for a chat.

   CHAT-ID: The unique identifier of the chat
   LIMIT: Number of messages to retrieve (1-100)
   OFFSET: Number of messages to skip
   FROM-MESSAGE-ID: Optional starting message ID

   Returns: list of messages on success, error on failure"
  (unless (authorized-p)
    (return-from get-messages
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max limit 1) 100))
  (setf offset (max offset 0))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-messages
        (values nil :no-connection "No active connection")))

    ;; Create searchMessages TL object
    (let ((request (make-tl-object
                    'messages.search
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :filter (make-tl-object 'inputMessagesFilterEmpty)
                    :limit limit
                    :offset-id (or from-message-id 0))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :messages)
              (values (getf result :messages) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Get messages timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-message-history (chat-id &key (limit 50) (offset-id 0))
  "Get message history with pagination.

   CHAT-ID: The unique identifier of the chat
   LIMIT: Number of messages to retrieve
   OFFSET-ID: Start from this message ID (0 for newest)

   Returns: (values messages has-more)"
  (multiple-value-bind (messages error)
      (get-messages chat-id :limit limit :offset offset-id)
    (if error
        (values nil nil)
        (values messages (>= (length messages) limit)))))

;;; ### Message Deletion

(defun delete-messages (chat-id message-ids)
  "Delete messages from a chat.

   CHAT-ID: The unique identifier of the chat
   MESSAGE-IDS: List of message IDs to delete

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from delete-messages
      (values nil :not-authorized "User not authenticated")))

  (unless (and message-ids (listp message-ids) (> (length message-ids) 0))
    (return-from delete-messages
      (values nil :invalid-argument "Message IDs must be a non-empty list")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from delete-messages
        (values nil :no-connection "No active connection")))

    ;; Create deleteMessages TL object
    (let ((request (make-tl-object
                    'messages.deleteMessages
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :id message-ids
                    :revoke t)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :messagesAffected)
              (values t nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Delete messages timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Editing

(defun edit-message (chat-id message-id new-text &key (parse-mode nil))
  "Edit a message text.

   CHAT-ID: The unique identifier of the chat
   MESSAGE-ID: ID of the message to edit
   NEW-TEXT: New text for the message

   Returns: edited message on success, error on failure"
  (unless (authorized-p)
    (return-from edit-message
      (values nil :not-authorized "User not authenticated")))

  (unless (and new-text (> (length new-text) 0) (<= (length new-text) 4096))
    (return-from edit-message
      (values nil :invalid-message "Message text must be 1-4096 characters")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from edit-message
        (values nil :no-connection "No active connection")))

    ;; Create editMessageText TL object
    (let ((request (make-tl-object
                    'messages.editMessage
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :message-id message-id
                    :message new-text)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Edit message timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Forwarding

(defun forward-messages (from-chat-id to-chat-id message-ids &key (as-silent nil))
  "Forward messages from one chat to another.

   FROM-CHAT-ID: Source chat ID
   TO-CHAT-ID: Destination chat ID
   MESSAGE-IDS: List of message IDs to forward
   AS-SILENT: Send silently (no notification)

   Returns: forwarded messages on success, error on failure"
  (unless (authorized-p)
    (return-from forward-messages
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from forward-messages
        (values nil :no-connection "No active connection")))

    ;; Create forwardMessages TL object
    (let ((request (make-tl-object
                    'messages.forwardMessages
                    :from-peer (make-tl-object 'inputPeerUser :user-id from-chat-id)
                    :to-peer (make-tl-object 'inputPeerUser :user-id to-chat-id)
                    :id message-ids
                    :random-id (list (random (expt 2 63)))
                    :silent as-silent)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :updates)
              (values (getf result :updates) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Forward messages timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Reactions

(defun send-reaction (chat-id message-id reaction-type)
  "Send a reaction to a message.

   CHAT-ID: The unique identifier of the chat
   MESSAGE-ID: ID of the message to react to
   REACTION-TYPE: Type of reaction (:emoji :custom-emoji)

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from send-reaction
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-reaction
        (values nil :no-connection "No active connection")))

    ;; Create sendReaction TL object
    (let ((request (make-tl-object
                    'messages.sendReaction
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :message-id message-id
                    :reaction reaction-type)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :messageReaction)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Search

(defun search-messages (chat-id query &key (limit 50))
  "Search for messages containing text.

   CHAT-ID: The unique identifier of the chat
   QUERY: Search query string
   LIMIT: Maximum number of results

   Returns: list of matching messages"
  (unless (authorized-p)
    (return-from search-messages
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-messages
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.search
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :query query
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values (getf result :messages) nil))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### TDLib Compatibility

(defun |sendMessage| (chat-id text &key parse-mode entities)
  "TDLib compatible sendMessage."
  (send-message chat-id text :parse-mode parse-mode :entities entities))

(defun |getMessages| (chat-id message-ids)
  "TDLib compatible getMessages by IDs."
  (declare (ignore message-ids))
  (get-messages chat-id))

(defun |deleteMessages| (chat-id message-ids &key revoke)
  "TDLib compatible deleteMessages."
  (declare (ignore revoke))
  (delete-messages chat-id message-ids))

(defun |editMessageText| (chat-id message-id text &key parse-mode)
  "TDLib compatible editMessageText."
  (edit-message chat-id message-id text :parse-mode parse-mode))

(defun |forwardMessages| (from-chat-id to-chat-id message-ids &key as-silent)
  "TDLib compatible forwardMessages."
  (forward-messages from-chat-id to-chat-id message-ids :as-silent as-silent))
