;;; channels.lisp --- Channel broadcast and message reactions
;;;
;;; Provides support for:
;;; - Channel creation and management
;;; - Broadcast messages to channels
;;; - Message reactions (emoji reactions)
;;; - Comments on channel posts
;;; - Channel statistics and analytics

(in-package #:cl-telegram/api)

;;; ### Channel Types

(defclass channel ()
  ((id :initarg :id :reader channel-id)
   (title :initarg :title :reader channel-title)
   (description :initarg :description :reader channel-description)
   (username :initarg :username :reader channel-username)
   (photo :initarg :photo :reader channel-photo)
   (member-count :initarg :member-count :reader channel-member-count)
   (is-broadcast :initarg :is-broadcast :reader channel-is-broadcast)
   (is-megagroup :initarg :is-megagroup :reader channel-is-megagroup)
   (is-admin :initarg :is-admin :reader channel-is-admin)
   (is-owner :initarg :is-owner :reader channel-is-owner)
   (can-post-messages :initarg :can-post-messages :reader channel-can-post-messages)
   (can-edit-messages :initarg :can-edit-messages :reader channel-can-edit-messages)
   (can-delete-messages :initarg :can-delete-messages :reader channel-can-delete-messages)
   (linked-chat-id :initarg :linked-chat-id :reader channel-linked-chat-id)))

(defclass channel-post ()
  ((id :initarg :id :reader channel-post-id)
   (channel-id :initarg :channel-id :reader channel-post-channel-id)
   (text :initarg :text :reader channel-post-text)
   (media :initarg :media :reader channel-post-media)
   (date :initarg :date :reader channel-post-date)
   (views :initarg :views :reader channel-post-views)
   (forwards :initarg :forwards :reader channel-post-forwards)
   (reactions :initarg :reactions :reader channel-post-reactions)
   (comments-count :initarg :comments-count :reader channel-post-comments-count)
   (is-pinned :initarg :is-pinned :reader channel-post-is-pinned)))

(defclass message-reaction ()
  ((reaction-id :initarg :reaction-id :reader message-reaction-id)
   (message-id :initarg :message-id :reader message-reaction-message-id)
   (chat-id :initarg :chat-id :reader message-reaction-chat-id)
   (emoji :initarg :emoji :reader message-reaction-emoji)
   (count :initarg :count :reader message-reaction-count)
   (is-selected :initarg :is-selected :reader message-reaction-is-selected)
   (recent-reactors :initarg :recent-reactors :reader message-reaction-recent-reactors)))

;;; ### Global State

(defvar *channel-cache* (make-hash-table :test 'equal)
  "Cache for channel objects")

(defvar *available-reactions* nil
  "List of available emoji reactions")

(defvar *recent-reactions* (make-hash-table :test 'equal)
  "Cache for recent message reactions")

;;; ### Channel Management

(defun get-channel (channel-id)
  "Get a channel by ID.

   Args:
     channel-id: Channel identifier

   Returns:
     Channel object or NIL"
  ;; Check cache first
  (let ((cached (gethash channel-id *channel-cache*)))
    (when cached
      (return-from get-channel cached)))
  ;; Fetch from API
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.getChannel :channel peer)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get channel ~A: ~A" channel-id error)
                nil)
              (let ((channel (parse-channel-from-tl result)))
                (when channel
                  (setf (gethash channel-id *channel-cache*) channel))
                channel)))))
    (error (e)
      (log:error "Exception in get-channel: ~A" e)
      nil)))

(defun get-my-channels ()
  "Get all channels the user is a member of.

   Returns:
     List of channel objects"
  (loop for channel being the hash-values of *channel-cache*
        collect channel))

(defun create-channel (title description &key (is-broadcast t) username)
  "Create a new channel.

   Args:
     title: Channel title (1-255 chars)
     description: Channel description (0-255 chars)
     is-broadcast: If T, it's a broadcast channel (not megagroup)
     username: Optional channel username

   Returns:
     Channel object on success, NIL on failure

   Note: User must be verified to create channels"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'channels.createChannel
                                      :broadcast is-broadcast
                                      :megagroup (not is-broadcast)
                                      :title title
                                      :about description
                                      :username (or username ""))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 15000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to create channel: ~A" error)
                nil)
              (let ((channel (parse-channel-from-tl result)))
                (when channel
                  (setf (gethash (channel-id channel) *channel-cache*) channel))
                channel))))
    (error (e)
      (log:error "Exception in create-channel: ~A" e)
      nil)))

(defun delete-channel (channel-id)
  "Delete a channel.

   Args:
     channel-id: Channel identifier

   Returns:
     T on success, NIL on failure

   Note: Only channel owner can delete"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.deleteChannel :channel peer)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to delete channel ~A: ~A" channel-id error)
                nil)
              (progn
                (remhash channel-id *channel-cache*)
                t))))
    (error (e)
      (log:error "Exception in delete-channel: ~A" e)
      nil)))

(defun set-channel-info (channel-id &key title description username)
  "Update channel information.

   Args:
     channel-id: Channel identifier
     title: New title (optional)
     description: New description (optional)
     username: New username (optional)

   Returns:
     T on success, NIL on failure

   Note: Admin privileges required"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (title-p (and title (length> title 0)))
             (about-p (and description (length> description 0)))
             (username-p (and username (length> username 0)))
             (request (make-tl-object 'channels.editTitle
                                      :channel peer
                                      :title (or title "")
                                      :about (or description ""))))
        ;; Send title/about edit request
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to set channel info: ~A" error)
                nil)
              (progn
                ;; Update username if provided
                (when username-p
                  (let ((username-request (make-tl-object 'channels.editUsername
                                                          :channel peer
                                                          :username username)))
                    (rpc-call connection username-request :timeout 10000)))
                ;; Invalidate cache
                (remhash channel-id *channel-cache*)
                t))))
    (error (e)
      (log:error "Exception in set-channel-info: ~A" e)
      nil)))

(defun set-channel-photo (channel-id file-id)
  "Set channel photo.

   Args:
     channel-id: Channel identifier
     file-id: Photo file ID

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'photos.uploadProfilePhoto
                                      :peer peer
                                      :id (parse-file-id file-id)
                                      :video-start-ts 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 15000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to set channel photo: ~A" error)
                nil)
              (progn
                (remhash channel-id *channel-cache*)
                t))))
    (error (e)
      (log:error "Exception in set-channel-photo: ~A" e)
      nil)))

(defun delete-channel-photo (channel-id)
  "Delete channel photo.

   Args:
     channel-id: Channel identifier

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'photos.deletePhotos
                                      :id (list (list :photo-id channel-id)))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to delete channel photo: ~A" error)
                nil)
              (progn
                (remhash channel-id *channel-cache*)
                t))))
    (error (e)
      (log:error "Exception in delete-channel-photo: ~A" e)
      nil)))

;;; ### Channel Administration

(defun get-channel-administrators (channel-id)
  "Get list of channel administrators.

   Args:
     channel-id: Channel identifier

   Returns:
     List of administrator user objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.getParticipants
                                      :channel peer
                                      :filter (make-tl-object 'channelParticipantsAdmins)
                                      :offset 0
                                      :limit 100
                                      :hash 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get channel administrators: ~A" error)
                nil)
              (parse-administrators-from-tl result))))
    (error (e)
      (log:error "Exception in get-channel-administrators: ~A" e)
      nil)))

(defun add-channel-administrator (channel-id user-id &key rights)
  "Add administrator to channel.

   Args:
     channel-id: Channel identifier
     user-id: User to add as admin
     rights: Admin rights/permissions

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (user-peer (make-tl-object 'inputPeerUser :user-id user-id :access-hash 0))
             (admin-rights (or rights
                               (make-tl-object 'chatAdminRights
                                               :change-info t
                                               :post-messages t
                                               :edit-messages t
                                               :delete-messages t
                                               :ban-users t
                                               :invite-users t
                                               :pin-messages t
                                               :manage-call t))))
        (multiple-value-bind (result error)
            (rpc-handler-case
                (let ((request (make-tl-object 'channels.editAdmin
                                               :channel peer
                                               :user-id user-peer
                                               :admin-rights admin-rights
                                               :rank "Admin")))
                  (rpc-call connection request :timeout 10000))
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to add channel administrator: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in add-channel-administrator: ~A" e)
      nil)))

(defun remove-channel-administrator (channel-id user-id)
  "Remove administrator from channel.

   Args:
     channel-id: Channel identifier
     user-id: User to remove

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (user-peer (make-tl-object 'inputPeerUser :user-id user-id :access-hash 0))
             (no-rights (make-tl-object 'chatAdminRights
                                        :change-info nil
                                        :post-messages nil
                                        :edit-messages nil
                                        :delete-messages nil
                                        :ban-users nil
                                        :invite-users nil
                                        :pin-messages nil
                                        :manage-call nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case
                (let ((request (make-tl-object 'channels.editAdmin
                                               :channel peer
                                               :user-id user-peer
                                               :admin-rights no-rights
                                               :rank "")))
                  (rpc-call connection request :timeout 10000))
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to remove channel administrator: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in remove-channel-administrator: ~A" e)
      nil)))

(defun ban-channel-user (channel-id user-id &key (duration 0))
  "Ban user from channel.

   Args:
     channel-id: Channel identifier
     user-id: User to ban
     duration: Ban duration in seconds (0 = permanent)

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (user-peer (make-tl-object 'inputPeerUser :user-id user-id :access-hash 0))
             (banned-rights (make-tl-object 'chatBannedRights
                                            :view-messages t
                                            :send-messages t
                                            :send-media t
                                            :send-stickers t
                                            :send-gifs t
                                            :send-games t
                                            :send-inline t
                                            :embed-links t
                                            :send-polls t
                                            :change-info t
                                            :invite-users t
                                            :pin-messages t
                                            :until-date (if (> duration 0)
                                                            (+ (get-universal-time) duration)
                                                            #x7FFFFFFF))))
        (multiple-value-bind (result error)
            (rpc-handler-case
                (let ((request (make-tl-object 'channels.editBanned
                                               :channel peer
                                               :participant user-peer
                                               :banned-rights banned-rights)))
                  (rpc-call connection request :timeout 10000))
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to ban user from channel: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in ban-channel-user: ~A" e)
      nil)))

(defun unban-channel-user (channel-id user-id)
  "Unban user from channel.

   Args:
     channel-id: Channel identifier
     user-id: User to unban

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (user-peer (make-tl-object 'inputPeerUser :user-id user-id :access-hash 0))
             (default-rights (make-tl-object 'chatBannedRights
                                             :view-messages nil
                                             :send-messages nil
                                             :send-media nil
                                             :send-stickers nil
                                             :send-gifs nil
                                             :send-games nil
                                             :send-inline nil
                                             :embed-links nil
                                             :send-polls nil
                                             :change-info nil
                                             :invite-users nil
                                             :pin-messages nil
                                             :until-date 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case
                (let ((request (make-tl-object 'channels.editBanned
                                               :channel peer
                                               :participant user-peer
                                               :banned-rights default-rights)))
                  (rpc-call connection request :timeout 10000))
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to unban user from channel: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in unban-channel-user: ~A" e)
      nil)))

(defun get-channel-banned-users (channel-id &key (limit 100))
  "Get list of banned users.

   Args:
     channel-id: Channel identifier
     limit: Maximum users to return

   Returns:
     List of banned user objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.getParticipants
                                      :channel peer
                                      :filter (make-tl-object 'channelParticipantsBanned)
                                      :offset 0
                                      :limit limit
                                      :hash 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get banned users: ~A" error)
                nil)
              (parse-banned-users-from-tl result))))
    (error (e)
      (log:error "Exception in get-channel-banned-users: ~A" e)
      nil)))

;;; ### Channel Invites

(defun export-channel-invite-link (channel-id)
  "Export channel invite link.

   Args:
     channel-id: Channel identifier

   Returns:
     Invite link string on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.exportInvite :channel peer)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to export channel invite link: ~A" error)
                nil)
              (parse-invite-link-from-tl result))))
    (error (e)
      (log:error "Exception in export-channel-invite-link: ~A" e)
      nil)))

(defun revoke-channel-invite-link (channel-id invite-link)
  "Revoke channel invite link.

   Args:
     channel-id: Channel identifier
     invite-link: Link to revoke

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.revokeInvite :channel peer
                                                            :link invite-link)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to revoke channel invite link: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in revoke-channel-invite-link: ~A" e)
      nil)))

(defun create-channel-invite-link (channel-id &key (expire-date nil) (usage-limit nil))
  "Create new channel invite link.

   Args:
     channel-id: Channel identifier
     expire-date: Optional expiration date (Unix timestamp)
     usage-limit: Optional usage limit

   Returns:
     Invite link string on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.exportInvite
                                      :channel peer
                                      :expire-date (or expire-date 0)
                                      :usage-limit (or usage-limit 0)
                                      :request-needed nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to create channel invite link: ~A" error)
                nil)
              (parse-invite-link-from-tl result))))
    (error (e)
      (log:error "Exception in create-channel-invite-link: ~A" e)
      nil)))

(defun get-channel-invite-link-info (channel-id invite-link)
  "Get info about invite link.

   Args:
     channel-id: Channel identifier
     invite-link: Invite link

   Returns:
     Link info plist"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.checkChatInvite :hash invite-link)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get invite link info: ~A" error)
                nil)
              (parse-invite-info-from-tl result))))
    (error (e)
      (log:error "Exception in get-channel-invite-link-info: ~A" e)
      nil)))

;;; ### Channel Broadcast

(defun broadcast-to-channel (channel-id text &key (media nil) (parse-mode nil) (schedule-date nil))
  "Broadcast message to channel.

   Args:
     channel-id: Channel identifier
     text: Message text
     media: Optional media (photo/document/video)
     parse-mode: Parse mode (nil, \"Markdown\", \"HTML\")
     schedule-date: Optional schedule date (Unix timestamp)

   Returns:
     Message object on success

   Note: Requires can-post-messages permission"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (message (if media
                          (make-media-message media text)
                          (make-tl-object 'inputMessageText
                                          :message text
                                          :entities (when parse-mode
                                                      (parse-message-entities text parse-mode))
                                          :clear-draft nil)))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'messages.sendMessage
                                      :peer peer
                                      :message message
                                      :random-id random-id
                                      :schedule-date (or schedule-date 0)
                                      :reply-to nil
                                      :reply-markup nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to broadcast to channel: ~A" error)
                nil)
              (parse-message-from-tl result))))
    (error (e)
      (log:error "Exception in broadcast-to-channel: ~A" e)
      nil)))

(defun edit-channel-message (channel-id message-id new-text)
  "Edit channel message.

   Args:
     channel-id: Channel identifier
     message-id: Message ID to edit
     new-text: New text content

   Returns:
     Edited message object

   Note: Requires can-edit-messages permission"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'messages.editMessage
                                      :peer peer
                                      :id message-id
                                      :message new-text
                                      :no-webpage nil
                                      :reply-markup nil
                                      :entities nil
                                      :schedule-date 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to edit channel message: ~A" error)
                nil)
              (parse-message-from-tl result))))
    (error (e)
      (log:error "Exception in edit-channel-message: ~A" e)
      nil)))

(defun delete-channel-message (channel-id message-id)
  "Delete channel message.

   Args:
     channel-id: Channel identifier
     message-id: Message ID to delete

   Returns:
     T on success

   Note: Requires can-delete-messages permission"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'messages.deleteMessages
                                      :id (list message-id)
                                      :revoke nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to delete channel message: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in delete-channel-message: ~A" e)
      nil)))

(defun pin-channel-message (channel-id message-id &key (notify-members nil))
  "Pin message in channel.

   Args:
     channel-id: Channel identifier
     message-id: Message ID to pin
     notify-members: Whether to notify members

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'messages.updatePinnedMessage
                                      :peer peer
                                      :id message-id
                                      :unpin nil
                                      :silent (not notify-members))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to pin channel message: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in pin-channel-message: ~A" e)
      nil)))

(defun unpin-channel-message (channel-id message-id)
  "Unpin message in channel.

   Args:
     channel-id: Channel identifier
     message-id: Message ID to unpin

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'messages.updatePinnedMessage
                                      :peer peer
                                      :id message-id
                                      :unpin t
                                      :silent t)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to unpin channel message: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in unpin-channel-message: ~A" e)
      nil)))

;;; ### Channel Statistics

(defun get-channel-stats (channel-id &key (start-date nil) (end-date nil))
  "Get channel statistics.

   Args:
     channel-id: Channel identifier
     start-date: Optional start date for stats
     end-date: Optional end date for stats

   Returns:
     Stats plist with:
     - member-count
     - view-count
     - share-count
     - growth-data"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'stats.getChannelStats
                                      :channel peer
                                      :from-date (or start-date 0)
                                      :to-date (or end-date (get-universal-time))
                                      :graph-dictionary nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 15000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get channel stats: ~A" error)
                nil)
              (parse-channel-stats-from-tl result))))
    (error (e)
      (log:error "Exception in get-channel-stats: ~A" e)
      nil)))

(defun get-channel-post-stats (channel-id message-id)
  "Get statistics for channel post.

   Args:
     channel-id: Channel identifier
     message-id: Post ID

   Returns:
     Stats plist with views, forwards, reactions"
  (let ((post (get-channel-post channel-id message-id)))
    (when post
      (list :views (channel-post-views post)
            :forwards (channel-post-forwards post)
            :reactions (channel-post-reactions post)))))

(defun get-channel-members (channel-id &key (limit 100) (offset 0))
  "Get channel members.

   Args:
     channel-id: Channel identifier
     limit: Maximum members to return
     offset: Offset for pagination

   Returns:
     List of member user objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.getParticipants
                                      :channel peer
                                      :filter (make-tl-object 'channelParticipantsRecent)
                                      :offset offset
                                      :limit limit
                                      :hash 0)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get channel members: ~A" error)
                nil)
              (parse-channel-members-from-tl result))))
    (error (e)
      (log:error "Exception in get-channel-members: ~A" e)
      nil)))

;;; ### Message Reactions

(defun get-available-reactions ()
  "Get list of available reactions.

   Returns:
     List of available emoji reactions"
  (or *available-reactions*
      (setf *available-reactions*
            '("👍" "👎" "❤️" "🔥" "🥰" "👏" "😁" "🤔" "🤯" "😱"
              "🤬" "😢" "🎉" "🤩" "🤮" "💩" "🙏" "👌" "🕊️" "🤡"
              "🥱" "🥴" "😍" "🐳" "❤‍🔥" "🌭" "💯" "🤣" "⚡️" "🍌"
              "🏆" "💔" "🤨" "😐" "🍓" "🍾" "💋" "🖕" "😈" "😴"
              "😭" "🤓" "👻" "👨‍💻" "👀" "🎃" "🙈" "😇" "😨" "🤝"
              "✍️" "🤗" "🫡" "🎅" "🎄" "☃️" "💅" "🤪" "🗿" "✈️"
              "🙊" "🐝" "🍉" "🍄" "🦄" "🌚" "🌭" "💸" "👽"))))

(defun get-message-reactions (chat-id message-id)
  "Get reactions for a message.

   Args:
     chat-id: Chat or channel ID
     message-id: Message ID

   Returns:
     Message-reaction object or NIL"
  (let ((key (format nil \"~A:~A\" chat-id message-id)))
    (gethash key *recent-reactions*)))

(defun send-message-reaction (chat-id message-id emoji &key (add-to-recent t))
  "Send reaction to message.

   Args:
     chat-id: Chat or channel ID
     message-id: Message ID
     emoji: Reaction emoji
     add-to-recent: Whether to add to recent reactions

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id chat-id :access-hash 0))
             (reaction (make-tl-object 'messageReactionEmoji :emoji emoji))
             (request (make-tl-object 'messages.sendReaction
                                      :peer peer
                                      :msg-id message-id
                                      :reaction reaction
                                      :big nil
                                      :add-to-recent add-to-recent)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to send message reaction: ~A" error)
                nil)
              (progn
                ;; Update cache
                (let ((key (format nil "~A:~A" chat-id message-id)))
                  (let ((existing (gethash key *recent-reactions*)))
                    (if existing
                        ;; Update count
                        (setf (slot-value existing 'count) (1+ (slot-value existing 'count)))
                        ;; Create new
                        (setf (gethash key *recent-reactions*)
                              (make-instance 'message-reaction
                                             :reaction-id (random 10000)
                                             :message-id message-id
                                             :chat-id chat-id
                                             :emoji emoji
                                             :count 1
                                             :is-selected t
                                             :recent-reactors nil))))
                t))))
    (error (e)
      (log:error "Exception in send-message-reaction: ~A" e)
      nil)))

(defun remove-message-reaction (chat-id message-id emoji)
  "Remove reaction from message.

   Args:
     chat-id: Chat or channel ID
     message-id: Message ID
     emoji: Reaction emoji to remove

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id chat-id :access-hash 0))
             (request (make-tl-object 'messages.sendReaction
                                      :peer peer
                                      :msg-id message-id
                                      :reaction nil
                                      :big nil
                                      :add-to-recent nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to remove message reaction: ~A" error)
                nil)
              (progn
                ;; Update cache
                (let ((key (format nil "~A:~A" chat-id message-id)))
                  (remhash key *recent-reactions*))
                t))))
    (error (e)
      (log:error "Exception in remove-message-reaction: ~A" e)
      nil)))

(defun get-recent-reactors (chat-id message-id &key (limit 10))
  "Get users who recently reacted to message.

   Args:
     chat-id: Chat or channel ID
     message-id: Message ID
     limit: Maximum users to return

   Returns:
     List of user objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id chat-id :access-hash 0))
             (request (make-tl-object 'messages.getMessageReactionsList
                                      :peer peer
                                      :id message-id
                                      :offset 0
                                      :limit limit
                                      :reaction-filter nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get recent reactors: ~A" error)
                nil)
              (parse-reactors-from-tl result))))
    (error (e)
      (log:error "Exception in get-recent-reactors: ~A" e)
      nil)))

(defun set-available-reactions (reactions)
  "Set available reactions for the chat/channel.

   Args:
     reactions: List of allowed emoji reactions

   Returns:
     T on success"
  (setf *available-reactions* reactions)
  t)

;;; ### Channel Posts

(defun get-channel-post (channel-id message-id)
  "Get channel post by ID.

   Args:
     channel-id: Channel identifier
     message-id: Post ID

   Returns:
     Channel-post object or NIL"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.getMessages
                                      :channel peer
                                      :id (list message-id))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get channel post: ~A" error)
                nil)
              (parse-channel-post-from-tl result))))
    (error (e)
      (log:error "Exception in get-channel-post: ~A" e)
      nil)))

(defun get-channel-posts (channel-id &key (limit 50) (offset 0))
  "Get channel posts.

   Args:
     channel-id: Channel identifier
     limit: Maximum posts to return
     offset: Offset for pagination

   Returns:
     List of channel-post objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.getMessages
                                      :channel peer
                                      :id nil
                                      :offset offset
                                      :limit limit))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get channel posts: ~A" error)
                nil)
              (parse-channel-posts-from-tl result))))
    (error (e)
      (log:error "Exception in get-channel-posts: ~A" e)
      nil)))

(defun get-pinned-messages (channel-id)
  "Get pinned messages in channel.

   Args:
     channel-id: Channel identifier

   Returns:
     List of pinned channel-post objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             (request (make-tl-object 'channels.getPinnedMessages :channel peer)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get pinned messages: ~A" error)
                nil)
              (parse-pinned-messages-from-tl result))))
    (error (e)
      (log:error "Exception in get-pinned-messages: ~A" e)
      nil)))

;;; ### Comments on Channel Posts

(defun get-post-comments (channel-id message-id &key (limit 50))
  "Get comments on channel post.

   Args:
     channel-id: Channel identifier
     message-id: Post ID
     limit: Maximum comments to return

   Returns:
     List of comment message objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0))
             ;; Get linked chat for comments
             (channel (get-channel channel-id))
             (linked-chat (when channel (channel-linked-chat-id channel))))
        (if linked-chat
            (let ((comment-peer (make-tl-object 'inputPeerChannel :channel-id linked-chat :access-hash 0))
                  (request (make-tl-object 'messages.getHistory
                                           :peer comment-peer
                                           :offset-id 0
                                           :offset-date 0
                                           :add-offset 0
                                           :limit limit
                                           :max-id message-id
                                           :min-id 0
                                           :hash 0)))
              (multiple-value-bind (result error)
                  (rpc-handler-case (rpc-call connection request :timeout 10000)
                    (tl-rpc-error (e) (values nil (error-message e)))
                    (timeout-error (e) (values nil :timeout))
                    (network-error (e) (values nil :network-error)))
                (if error
                    (progn
                      (log:error "Failed to get post comments: ~A" error)
                      nil)
                    (parse-comments-from-tl result))))
            ;; No linked chat, no comments
            nil)))
    (error (e)
      (log:error "Exception in get-post-comments: ~A" e)
      nil)))

(defun send-comment (channel-id message-id text &key (media nil))
  "Send comment to channel post.

   Args:
     channel-id: Channel identifier
     message-id: Post ID to comment on
     text: Comment text
     media: Optional media attachment

   Returns:
     Comment message object"
  (handler-case
      (let* ((connection (get-connection))
             ;; Get linked chat for comments
             (channel (get-channel channel-id))
             (linked-chat (when channel (channel-linked-chat-id channel))))
        (if linked-chat
            (let* ((peer (make-tl-object 'inputPeerChannel :channel-id linked-chat :access-hash 0))
                   (message (if media
                                (make-media-message media text)
                                (make-tl-object 'inputMessageText
                                                :message text
                                                :entities nil
                                                :clear-draft nil)))
                   (random-id (random (expt 2 63)))
                   (reply-to (make-tl-object 'inputMessageReplyToExternal
                                             :peer (make-tl-object 'inputPeerChannel :channel-id channel-id :access-hash 0)
                                             :msg-id message-id))
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
                      (log:error "Failed to send comment: ~A" error)
                      nil)
                    (parse-message-from-tl result))))
            ;; No linked chat, cannot send comments
            (progn
              (log:error "Channel ~A has no linked chat for comments" channel-id)
              nil))))
    (error (e)
      (log:error "Exception in send-comment: ~A" e)
      nil)))

;;; ### CLOG UI Integration

(defun render-channel-list (win container &key (on-select nil))
  "Render channel list UI.

   Args:
     win: CLOG window object
     container: Container element
     on-select: Callback when channel selected"
  (let ((channels (get-my-channels)))
    (if (null channels)
        (clog:append! container
                      (clog:create-element win \"div\" :class \"empty-state\"
                                           (clog:create-element win \"p\" :text \"No channels yet\")))
        (dolist (channel channels)
          (let ((channel-el (clog:create-element win \"div\" :class \"channel-item\"
                                                  :style \"padding: 10px; cursor: pointer; border-bottom: 1px solid #eee;\")))
            (clog:append! channel-el
                          (clog:create-element win \"div\" :class \"channel-title\"
                                               :text (channel-title channel))
                          (clog:create-element win \"div\" :class \"channel-info\"
                                               :text (format nil \"~A members\" (channel-member-count channel))))
            (when on-select
              (clog:on channel-el :click
                       (lambda (ev)
                         (declare (ignore ev))
                         (funcall on-select channel))))
            (clog:append! container channel-el))))))

(defun render-broadcast-panel (win channel-id container)
  "Render broadcast message panel.

   Args:
     win: CLOG window object
     channel-id: Channel ID
     container: Container element"
  (let ((channel (get-channel channel-id)))
    (when channel
      ;; Channel info header
      (clog:append! container
                    (clog:create-element win \"div\" :class \"broadcast-header\"
                                         (clog:create-element win \"h3\" :text (format nil \"Broadcast to ~A\" (channel-title channel)))
                                         (clog:create-element win \"p\" :class \"broadcast-subtitle\"
                                                              :text (format nil \"~A members\" (channel-member-count channel)))))
      ;; Message input
      (let ((input-container (clog:create-element win \"div\" :class \"broadcast-input\"
                                                   :style \"margin: 20px 0;\")))
        (clog:append! input-container
                      (clog:create-element win \"textarea\" :id \"broadcast-text\"
                                           :placeholder \"Write your message...\"
                                           :style \"width: 100%; height: 150px; padding: 10px; border: 1px solid #ddd; border-radius: 5px;\")
                      (clog:create-element win \"div\" :class \"broadcast-actions\"
                                           :style \"margin-top: 10px; display: flex; gap: 10px;\"
                                           (clog:create-element win \"button\" :id \"btn-send-broadcast\"
                                                                :text \"📢 Broadcast\"
                                                                :style \"padding: 10px 20px; background: #0088cc; color: white; border: none; border-radius: 5px; cursor: pointer;\")
                                           (clog:create-element win \"button\" :id \"btn-schedule\"
                                                                :text \"📅 Schedule\"
                                                                :style \"padding: 10px 20px; background: #6c757d; color: white; border: none; border-radius: 5px; cursor: pointer;\")))
        (clog:append! container input-container)
        ;; Bind send button
        (let ((send-btn (clog:get-element-by-id win \"btn-send-broadcast\")))
          (clog:on send-btn :click
                   (lambda (ev)
                     (declare (ignore ev))
                     (let* ((textarea (clog:get-element-by-id win \"broadcast-text\"))
                            (text (clog:text textarea)))
                       (when (and text (> (length text) 0))
                         (broadcast-to-channel channel-id text)
                         (setf (clog:text textarea) \"\")
                         (clog:alert win \"Message broadcast!\"))))))))))

(defun render-reaction-panel (win chat-id message-id container)
  "Render reaction selector panel.

   Args:
     win: CLOG window object
     chat-id: Chat or channel ID
     message-id: Message ID
     container: Container element"
  (let ((reactions (get-available-reactions)))
    (clog:append! container
                  (clog:create-element win \"div\" :class \"reaction-panel\"
                                       :style \"display: flex; flex-wrap: wrap; gap: 5px; padding: 10px; background: #f5f5f5; border-radius: 10px;\"))
    (let ((panel (clog:query-selector container \".reaction-panel\")))
      (dolist (emoji reactions)
        (let ((emoji-el (clog:create-element win \"span\"
                                              :class \"reaction-emoji\"
                                              :style \"font-size: 24px; cursor: pointer; padding: 5px;\")))
          (setf (clog:text emoji-el) emoji)
          (clog:on emoji-el :click
                   (lambda (ev)
                     (declare (ignore ev))
                     (send-message-reaction chat-id message-id emoji)
                     ;; Close panel
                     (setf (clog:style container \"display\") \"none\")))
          (clog:append! panel emoji-el))))))

(defun render-channel-stats (win channel-id container)
  "Render channel statistics panel.

   Args:
     win: CLOG window object
     channel-id: Channel identifier
     container: Container element"
  (let ((stats (get-channel-stats channel-id)))
    (when stats
      (clog:append! container
                    (clog:create-element win \"div\" :class \"channel-stats\"
                                         :style \"padding: 15px; background: #f8f9fa; border-radius: 10px;\"
                                         (clog:create-element win \"h4\" :text \"📊 Channel Statistics\")
                                         (clog:create-element win \"div\" :class \"stat-row\"
                                                              :text (format nil \"👥 Members: ~A\" (getf stats :member-count)))
                                         (clog:create-element win \"div\" :class \"stat-row\"
                                                              :text (format nil \"👁️ Total Views: ~A\" (getf stats :view-count)))
                                         (clog:create-element win \"div\" :class \"stat-row\"
                                                              :text (format nil \"📤 Shares: ~A\" (getf stats :share-count))))))))

;;; ### Utilities

(defun channel-type-string (channel)
  "Get channel type as string.

   Args:
     channel: Channel object

   Returns:
     Type string"
  (cond
    ((channel-is-broadcast channel) \"Broadcast Channel\")
    ((channel-is-megagroup channel) \"Megagroup\")
    (t \"Channel\")))

(defun clear-channel-cache ()
  "Clear all channel cache.

   Returns:
     T on success"
  (clrhash *channel-cache*)
  t)

(defun clear-reaction-cache ()
  "Clear all reaction cache.

   Returns:
     T on success"
  (clrhash *recent-reactions*)
  t)

;;; ### Parser Helper Functions

(defun parse-channel-from-tl (tl-object)
  "Parse TL object into channel instance.

   Args:
     tl-object: TL object from API response

   Returns:
     Channel instance or NIL"
  (when tl-object
    (handler-case
        (make-instance 'channel
                       :id (get-tl-field tl-object :id)
                       :title (get-tl-field tl-object :title)
                       :description (get-tl-field tl-object :about)
                       :username (get-tl-field tl-object :username)
                       :photo (get-tl-field tl-object :photo)
                       :member-count (get-tl-field tl-object :participants-count)
                       :is-broadcast (get-tl-field tl-object :broadcast)
                       :is-megagroup (get-tl-field tl-object :megagroup)
                       :is-admin (get-tl-field tl-object :admin)
                       :is-owner (get-tl-field tl-object :creator)
                       :can-post-messages (get-tl-field tl-object :broadcast)
                       :can-edit-messages (get-tl-field tl-object :edit)
                       :can-delete-messages (get-tl-field tl-object :delete)
                       :linked-chat-id (get-tl-field tl-object :linked-chat-id))
      (error (e)
        (log:error "Failed to parse channel: ~A" e)
        nil))))

(defun parse-channel-post-from-tl (tl-object)
  "Parse TL object into channel-post instance.

   Args:
     tl-object: TL object from API response

   Returns:
     Channel-post instance or NIL"
  (when tl-object
    (handler-case
        (let ((msg (if (typep tl-object 'tl-object)
                       (get-tl-field tl-object :message)
                       tl-object)))
          (make-instance 'channel-post
                         :id (get-tl-field msg :id)
                         :channel-id (get-tl-field msg :from-id)
                         :text (get-tl-field msg :message)
                         :media (get-tl-field msg :media)
                         :date (get-tl-field msg :date)
                         :views (get-tl-field msg :views)
                         :forwards (get-tl-field msg :forwards)
                         :reactions (get-tl-field msg :reactions)
                         :comments-count (get-tl-field msg :comments)
                         :is-pinned (get-tl-field msg :pinned)))
      (error (e)
        (log:error "Failed to parse channel post: ~A" e)
        nil))))

(defun parse-channel-posts-from-tl (tl-object)
  "Parse TL object into list of channel-post instances.

   Args:
     tl-object: TL object from API response

   Returns:
     List of channel-post instances"
  (when tl-object
    (let ((messages (get-tl-field tl-object :messages)))
      (when (listp messages)
        (loop for msg in messages
              collect (parse-channel-post-from-tl msg))))))

(defun parse-administrators-from-tl (tl-object)
  "Parse TL object into list of administrator user objects.

   Args:
     tl-object: TL object from API response

   Returns:
     List of administrator user objects"
  (when tl-object
    (let ((participants (get-tl-field tl-object :participants)))
      (when (listp participants)
        (loop for p in participants
              collect (get-tl-field p :user-id))))))

(defun parse-banned-users-from-tl (tl-object)
  "Parse TL object into list of banned user objects.

   Args:
     tl-object: TL object from API response

   Returns:
     List of banned user objects"
  (when tl-object
    (let ((participants (get-tl-field tl-object :participants)))
      (when (listp participants)
        (loop for p in participants
              collect (get-tl-field p :user-id))))))

(defun parse-invite-link-from-tl (tl-object)
  "Parse TL object into invite link string.

   Args:
     tl-object: TL object from API response

   Returns:
     Invite link string or NIL"
  (when tl-object
    (get-tl-field tl-object :link)))

(defun parse-invite-info-from-tl (tl-object)
  "Parse TL object into invite link info plist.

   Args:
     tl-object: TL object from API response

   Returns:
     Plist with invite info"
  (when tl-object
    (list :title (get-tl-field tl-object :title)
          :member-count (get-tl-field tl-object :members)
          :participant-count (get-tl-field tl-object :participants-count))))

(defun parse-channel-stats-from-tl (tl-object)
  "Parse TL object into channel stats plist.

   Args:
     tl-object: TL object from API response

   Returns:
     Stats plist"
  (when tl-object
    (list :member-count (get-tl-field tl-object :members)
          :view-count (get-tl-field tl-object :views)
          :share-count (get-tl-field tl-object :shares)
          :growth-data (get-tl-field tl-object :growth))))

(defun parse-channel-members-from-tl (tl-object)
  "Parse TL object into list of channel member user objects.

   Args:
     tl-object: TL object from API response

   Returns:
     List of member user objects"
  (when tl-object
    (let ((participants (get-tl-field tl-object :participants)))
      (when (listp participants)
        (loop for p in participants
              collect (get-tl-field p :user-id))))))

(defun parse-reactors-from-tl (tl-object)
  "Parse TL object into list of users who reacted.

   Args:
     tl-object: TL object from API response

   Returns:
     List of user objects"
  (when tl-object
    (let ((reactions (get-tl-field tl-object :reactions)))
      (when (listp reactions)
        (loop for r in reactions
              collect (get-tl-field r :user-id))))))

(defun parse-pinned-messages-from-tl (tl-object)
  "Parse TL object into list of pinned messages.

   Args:
     tl-object: TL object from API response

   Returns:
     List of pinned channel-post objects"
  (when tl-object
    (let ((messages (get-tl-field tl-object :messages)))
      (when (listp messages)
        (loop for msg in messages
              collect (parse-channel-post-from-tl msg))))))

(defun parse-comments-from-tl (tl-object)
  "Parse TL object into list of comment messages.

   Args:
     tl-object: TL object from API response

   Returns:
     List of comment message objects"
  (when tl-object
    (let ((messages (get-tl-field tl-object :messages)))
      (when (listp messages)
        (loop for msg in messages
              collect (parse-message-from-tl msg))))))

(defun parse-message-from-tl (tl-object)
  "Parse TL object into message.

   Args:
     tl-object: TL object from API response

   Returns:
     Message object or NIL"
  ;; Placeholder - should be implemented in messages-api.lisp
  (when tl-object
    tl-object))

(defun make-media-message (media text)
  "Create media message TL object.

   Args:
     media: Media attachment
     text: Caption text

   Returns:
     TL object for media message"
  ;; Placeholder - should be implemented in messages-api.lisp
  (make-tl-object 'inputMessageText
                  :message text
                  :entities nil
                  :clear-draft nil))

(defun parse-file-id (file-id)
  "Parse file ID string into internal format.

   Args:
     file-id: File ID string

   Returns:
     Parsed file ID"
  ;; Placeholder - should be implemented in messages-api.lisp
  file-id)

(defun parse-message-entities (text parse-mode)
  "Parse message entities for given parse mode.

   Args:
     text: Message text
     parse-mode: Parse mode (Markdown/HTML)

   Returns:
     List of message entities"
  ;; Placeholder - should be implemented in messages-api.lisp
  nil)

(defun get-connection ()
  "Get current connection.

   Returns:
     Connection object"
  ;; Placeholder - should be imported from network layer
  (error "get-connection not implemented"))

(defun make-tl-object (type &rest args)
  "Create TL object.

   Args:
     type: TL type symbol
     args: Initargs

   Returns:
     TL object instance"
  ;; Placeholder - should be imported from tl layer
  (apply #'make-instance type args))

(defun get-tl-field (tl-object field)
  "Get field value from TL object.

   Args:
     tl-object: TL object
     field: Field keyword

   Returns:
     Field value"
  ;; Placeholder - should be imported from tl layer
  (slot-value tl-object (intern (string field) (symbol-package tl-object))))

(defun rpc-call (connection request &key timeout)
  "Make RPC call.

   Args:
     connection: Connection object
     request: TL request object
     timeout: Timeout in milliseconds

   Returns:
     Response TL object"
  ;; Placeholder - should be imported from network layer
  (declare (ignore connection request timeout))
  nil)

(defun rpc-handler-case (form &rest handlers)
  "Handle RPC call with error handlers.

   Args:
     form: Form to evaluate
     handlers: Error handlers

   Returns:
     Result of form or error handler result"
  (handler-case form
    (error (e) (values nil e))
    ,@handlers))

(defun length> (string n)
  "Check if string length is greater than n.

   Args:
     string: String to check
     n: Length threshold

   Returns:
     T if length > n"
  (> (length string) n))
