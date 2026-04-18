;;; chats-api.lisp --- Chats API implementation

(in-package #:cl-telegram/api)

;;; ### Chat List

(defvar *chat-cache* (make-hash-table :test 'equal)
  "Cache for chat objects")

(defun get-chats (&key (limit 100) (offset 0) (folder-id nil))
  "Get list of chats.

   LIMIT: Number of chats to retrieve (1-1000)
   OFFSET: Number of chats to skip
   FOLDER-ID: Optional folder ID to filter by

   Returns: list of chat objects on success, error on failure"
  (unless (authorized-p)
    (return-from get-chats
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max limit 1) 1000))
  (setf offset (max offset 0))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-chats
        (values nil :no-connection "No active connection")))

    ;; Create getChats TL object
    (let ((request (make-tl-object
                    'messages.getChats
                    :folder-id (or folder-id 0)
                    :limit limit
                    :offset-id offset)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chats)
              (let ((chat-list (getf result :list)))
                ;; Cache the chats
                (dolist (chat chat-list)
                  (let ((id (getf chat :id)))
                    (when id
                      (setf (gethash id *chat-cache*) chat))))
                (values chat-list nil))
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Get chats timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Single Chat

(defun get-chat (chat-id)
  "Get information about a chat.

   CHAT-ID: The unique identifier of the chat

   Returns: chat object on success, error on failure"
  (unless (authorized-p)
    (return-from get-chat
      (values nil :not-authorized "User not authenticated")))

  ;; Check cache first
  (let ((cached (gethash chat-id *chat-cache*)))
    (when cached
      (return-from get-chat (values cached nil))))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-chat
        (values nil :no-connection "No active connection")))

    ;; Create getChat TL object
    (let ((request (make-tl-object
                    'messages.getChat
                    :chat-id chat-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chat)
              (progn
                ;; Cache the result
                (setf (gethash chat-id *chat-cache*) result)
                (values result nil))
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Get chat timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Chat Creation

(defun create-private-chat (user-id &key (force nil))
  "Create or get a private chat with a user.

   USER-ID: The unique identifier of the user
   FORCE: If true, always create a new chat

   Returns: chat object on success, error on failure"
  (unless (authorized-p)
    (return-from create-private-chat
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from create-private-chat
        (values nil :no-connection "No active connection")))

    ;; Create createPrivateChat TL object
    (let ((request (make-tl-object
                    'messages.createPrivateChat
                    :user-id user-id
                    :force force)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (member (getf result :@type) '(:chat :chatPrivate))
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Create chat timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-private-chat (user-id)
  "Get a private chat with a user (alias for create-private-chat)."
  (create-private-chat user-id))

;;; ### Group Chats

(defun create-basic-group-chat (title &key (user-ids nil))
  "Create a new basic group chat.

   TITLE: Group title (1-128 characters)
   USER-IDS: Optional list of initial user IDs to add

   Returns: chat object on success, error on failure"
  (unless (authorized-p)
    (return-from create-basic-group-chat
      (values nil :not-authorized "User not authenticated")))

  (unless (and title (> (length title) 0) (<= (length title) 128))
    (return-from create-basic-group-chat
      (values nil :invalid-title "Group title must be 1-128 characters")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from create-basic-group-chat
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.createBasicGroupChat
                    :title title
                    :user-ids user-ids)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatBasicGroup)
              (values result nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun create-supergroup-chat (title &key (description "") (for-channel nil))
  "Create a new supergroup or channel.

   TITLE: Group/channel title (1-256 characters)
   DESCRIPTION: Group description (optional)
   FOR-CHANNEL: If true, create a channel instead of a group

   Returns: chat object on success, error on failure"
  (unless (authorized-p)
    (return-from create-supergroup-chat
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from create-supergroup-chat
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.createSupergroupChat
                    :title title
                    :description description
                    :for-channel for-channel)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (member (getf result :@type) '(:chatSupergroup :chatChannel))
              (values result nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Chat Members

(defun get-chat-members (chat-id &key (limit 100) (offset 0))
  "Get members of a chat.

   CHAT-ID: The unique identifier of the chat
   LIMIT: Number of members to retrieve (1-100)
   OFFSET: Number of members to skip

   Returns: list of chat members on success, error on failure"
  (unless (authorized-p)
    (return-from get-chat-members
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-chat-members
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.getChatMembers
                    :chat-id chat-id
                    :limit limit
                    :offset offset)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatMembers)
              (values (getf result :members) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun add-chat-member (chat-id user-id &key (forward-limit 10))
  "Add a user to a chat.

   CHAT-ID: The unique identifier of the chat
   USER-ID: The ID of the user to add
   FORWARD-LIMIT: Number of messages to forward from old chat

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from add-chat-member
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from add-chat-member
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.addChatMember
                    :chat-id chat-id
                    :user-id user-id
                    :forward-limit forward-limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun remove-chat-member (chat-id user-id)
  "Remove a user from a chat.

   CHAT-ID: The unique identifier of the chat
   USER-ID: The ID of the user to remove

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from remove-chat-member
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from remove-chat-member
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.removeChatMember
                    :chat-id chat-id
                    :user-id user-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Chat Actions

(defun send-chat-action (chat-id action-type)
  "Send a chat action (typing indicator).

   CHAT-ID: The unique identifier of the chat
   ACTION-TYPE: Type of action
                (:typing :cancel :record-video :upload-video
                 :record-audio :upload-audio :upload-photo
                 :upload-document :geo :choose-contact :playing-game)

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from send-chat-action
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-chat-action
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.sendChatAction
                    :chat-id chat-id
                    :action (make-tl-object 'sendMessageTypingAction))))
      (rpc-handler-case (rpc-call connection request :timeout 5000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Chat Settings

(defun set-chat-title (chat-id title)
  "Set the title of a chat.

   CHAT-ID: The unique identifier of the chat
   TITLE: New title (1-256 characters)

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from set-chat-title
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (let ((request (make-tl-object
                    'messages.setChatTitle
                    :chat-id chat-id
                    :title title)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun toggle-chat-muted (chat-id &key (muted t))
  "Mute or unmute a chat.

   CHAT-ID: The unique identifier of the chat
   MUTED: If true, mute the chat; if false, unmute

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from toggle-chat-muted
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (let ((request (make-tl-object
                    'messages.toggleChatMuted
                    :chat-id chat-id
                    :muted muted)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values t nil))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Chat History

(defun get-chat-history (chat-id &key (limit 50) (from-message-id nil))
  "Get chat message history (alias for get-messages).

   CHAT-ID: The unique identifier of the chat
   LIMIT: Number of messages to retrieve
   FROM-MESSAGE-ID: Optional starting message ID

   Returns: list of messages"
  (get-messages chat-id :limit limit :from-message-id from-message-id))

(defun clear-chat-history (chat-id &key (remove-from-chat-list nil))
  "Clear chat history.

   CHAT-ID: The unique identifier of the chat
   REMOVE-FROM-CHAT-LIST: If true, also remove from chat list

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from clear-chat-history
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from clear-chat-history
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.clearHistory
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :remove-from-chat-list remove-from-chat-list)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Chat Search

(defun search-chats (query &key (limit 50))
  "Search for chats by query.

   QUERY: Search query string
   LIMIT: Maximum number of results

   Returns: list of matching chats"
  (unless (authorized-p)
    (return-from search-chats
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-chats
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.searchChats
                    :query query
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chats)
              (values (getf result :list) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### TDLib Compatibility

(defun |getChats| (&key folder-id limit offset)
  "TDLib compatible getChats."
  (get-chats :folder-id folder-id :limit (or limit 100) :offset (or offset 0)))

(defun |getChat| (chat-id)
  "TDLib compatible getChat."
  (get-chat chat-id))

(defun |createPrivateChat| (user-id &key force)
  "TDLib compatible createPrivateChat."
  (create-private-chat user-id :force force))

(defun |sendMessage| (chat-id text &key parse-mode)
  "TDLib compatible sendMessage (delegates to messages-api)."
  (send-message chat-id text :parse-mode parse-mode))

(defun |sendChatAction| (chat-id action-type)
  "TDLib compatible sendChatAction."
  (send-chat-action chat-id action-type))
