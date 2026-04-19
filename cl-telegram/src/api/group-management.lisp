;;; group-management.lisp --- Enhanced group management features
;;;
;;; Provides advanced group and channel management including:
;;; - Administrator permissions and roles
;;; - Member approval and moderation
;;; - Auto-moderation rules
;;; - Polls and voting
;;; - Group statistics and logging

(in-package #:cl-telegram/api)

;;; ### Administrator Permissions

(defstruct group-admin-permissions
  "Administrator permissions bitmask"
  (can-change-info nil :type boolean)
  (can-post-messages nil :type boolean)
  (can-edit-messages nil :type boolean)
  (can-delete-messages nil :type boolean)
  (can-invite-users nil :type boolean)
  (can-restrict-members nil :type boolean)
  (can-pin-messages nil :type boolean)
  (can-promote-members nil :type boolean)
  (can-manage-voice-chats nil :type boolean)
  (can-manage-topics nil :type boolean))

(defun make-admin-permissions (&key
                               change-info
                               post-messages
                               edit-messages
                               delete-messages
                               invite-users
                               restrict-members
                               pin-messages
                               promote-members
                               manage-voice-chats
                               manage-topics)
  "Create administrator permissions object.

   Args:
     change-info: Can change chat info (default nil)
     post-messages: Can post messages (channels) (default nil)
     edit-messages: Can edit messages (default nil)
     delete-messages: Can delete messages (default nil)
     invite-users: Can invite users (default nil)
     restrict-members: Can restrict members (default nil)
     pin-messages: Can pin messages (default nil)
     promote-members: Can promote admins (default nil)
     manage-voice-chats: Can manage voice chats (default nil)
     manage-topics: Can manage topics (default nil)

   Returns:
     Admin permissions struct"
  (make-group-admin-permissions
   :can-change-info change-info
   :can-post-messages post-messages
   :can-edit-messages edit-messages
   :can-delete-messages delete-messages
   :can-invite-users invite-users
   :can-restrict-members restrict-members
   :can-pin-messages pin-messages
   :can-promote-members promote-members
   :can-manage-voice-chats manage-voice-chats
   :can-manage-topics manage-topics))

(defun permissions-to-bitmask (permissions)
  "Convert permissions struct to bitmask.

   Args:
     permissions: Admin permissions struct

   Returns:
     Integer bitmask"
  (let ((mask 0))
    (when (group-admin-permissions-can-change-info permissions)
      (setf (logior mask #x0001)))
    (when (group-admin-permissions-can-post-messages permissions)
      (setf (logior mask #x0002)))
    (when (group-admin-permissions-can-edit-messages permissions)
      (setf (logior mask #x0004)))
    (when (group-admin-permissions-can-delete-messages permissions)
      (setf (logior mask #x0008)))
    (when (group-admin-permissions-can-invite-users permissions)
      (setf (logior mask #x0010)))
    (when (group-admin-permissions-can-restrict-members permissions)
      (setf (logior mask #x0020)))
    (when (group-admin-permissions-can-pin-messages permissions)
      (setf (logior mask #x0040)))
    (when (group-admin-permissions-can-promote-members permissions)
      (setf (logior mask #x0080)))
    (when (group-admin-permissions-can-manage-voice-chats permissions)
      (setf (logior mask #x0100)))
    (when (group-admin-permissions-can-manage-topics permissions)
      (setf (logior mask #x0200)))
    mask))

(defun bitmask-to-permissions (bitmask)
  "Convert bitmask to permissions struct.

   Args:
     bitmask: Integer bitmask

   Returns:
     Admin permissions struct"
  (make-group-admin-permissions
   :can-change-info (not (zerop (logand bitmask #x0001)))
   :can-post-messages (not (zerop (logand bitmask #x0002)))
   :can-edit-messages (not (zerop (logand bitmask #x0004)))
   :can-delete-messages (not (zerop (logand bitmask #x0008)))
   :can-invite-users (not (zerop (logand bitmask #x0010)))
   :can-restrict-members (not (zerop (logand bitmask #x0020)))
   :can-pin-messages (not (zerop (logand bitmask #x0040)))
   :can-promote-members (not (zerop (logand bitmask #x0080)))
   :can-manage-voice-chats (not (zerop (logand bitmask #x0100)))
   :can-manage-topics (not (zerop (logand bitmask #x0200)))))

;;; ### Administrator Management

(defun get-chat-administrators (chat-id)
  "Get list of chat administrators.

   Args:
     chat-id: Chat ID

   Returns:
     List of administrator objects"
  (unless (authorized-p)
    (return-from get-chat-administrators
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-chat-administrators
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.getChatAdministrators
                    :chat-id chat-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatAdministrators)
              (values (getf result :administrators) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun set-chat-administrator (chat-id user-id permissions &key custom-title)
  "Set chat administrator permissions.

   Args:
     chat-id: Chat ID
     user-id: User ID to promote
     permissions: Admin permissions struct
     custom-title: Optional custom title

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from set-chat-administrator
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from set-chat-administrator
        (values nil :no-connection)))

    (let ((bitmask (permissions-to-bitmask permissions))
          (request (make-tl-object
                    'messages.editChatAdmin
                    :chat-id chat-id
                    :user-id user-id
                    :admin-rights (make-tl-object
                                   'chatAdminRights
                                   :rights bitmask)
                    :rank (or custom-title ""))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun remove-chat-administrator (chat-id user-id)
  "Remove administrator from chat.

   Args:
     chat-id: Chat ID
     user-id: Admin user ID to remove

   Returns:
     T on success"
  (set-chat-administrator chat-id user-id
                          (make-admin-permissions)))

;;; ### Member Restrictions

(defstruct member-restrictions
  "Member restriction flags"
  (is-restricted nil :type boolean)
  (can-send-messages nil :type boolean)
  (can-send-media nil :type boolean)
  (can-send-polls nil :type boolean)
  (can-send-other nil :type boolean)
  (can-add-web-page-previews nil :type boolean)
  (can-change-info nil :type boolean)
  (can-invite-users nil :type boolean)
  (can-pin-messages nil :type boolean)
  (until-date nil :type (or null integer)))

(defun make-member-restrictions (&key
                                 restricted
                                 send-messages
                                 send-media
                                 send-polls
                                 send-other
                                 add-web-previews
                                 invite-users
                                 pin-messages
                                 change-info
                                 until-date)
  "Create member restrictions object.

   Args:
     restricted: Is member restricted (default nil)
     send-messages: Can send messages (default t)
     send-media: Can send media (default t)
     send-polls: Can send polls (default t)
     send-other: Can send other content (default t)
     add-web-previews: Can add web previews (default t)
     invite-users: Can invite users (default t)
     pin-messages: Can pin messages (default t)
     change-info: Can change info (default t)
     until-date: Restriction end time (default nil = forever)

   Returns:
     Member restrictions struct"
  (make-member-restrictions
   :is-restricted restricted
   :can-send-messages (or send-messages (not restricted))
   :can-send-media (or send-media (not restricted))
   :can-send-polls (or send-polls (not restricted))
   :can-send-other (or send-other (not restricted))
   :can-add-web-page-previews (or add-web-previews (not restricted))
   :can-invite-users (or invite-users (not restricted))
   :can-pin-messages (or pin-messages (not restricted))
   :can-change-info (or change-info (not restricted))
   :until-date until-date))

(defun ban-chat-member (chat-id user-id &key duration until-date)
  "Ban a user from a chat (kick with option to unban later).

   Args:
     chat-id: Chat ID
     user-id: User ID to ban
     duration: Ban duration in seconds (0 = forever)
     until-date: Specific date to unban (Unix timestamp)

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from ban-chat-member
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from ban-chat-member
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.editBanned
                    :chat-id chat-id
                    :user-id user-id
                    :banned-rights (make-tl-object
                                    'chatBannedRights
                                    :view-messages t
                                    :send-messages t
                                    :send-media t
                                    :send-stickers t
                                    :send-gifs t
                                    :send-games t
                                    :send-inline t
                                    :embed-links t
                                    :until-date (or until-date
                                                    (if duration
                                                        (+ (get-universal-time) duration)
                                                        0))))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun unban-chat-member (chat-id user-id)
  "Unban a previously banned user.

   Args:
     chat-id: Chat ID
     user-id: User ID to unban

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from unban-chat-member
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from unban-chat-member
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.editBanned
                    :chat-id chat-id
                    :user-id user-id
                    :banned-rights (make-tl-object
                                    'chatBannedRights
                                    :view-messages nil
                                    :send-messages nil
                                    :send-media nil
                                    :send-stickers nil
                                    :send-gifs nil
                                    :send-games nil
                                    :send-inline nil
                                    :embed-links nil
                                    :until-date 0))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun restrict-chat-member (chat-id user-id restrictions)
  "Restrict a chat member's permissions.

   Args:
     chat-id: Chat ID
     user-id: User ID to restrict
     restrictions: Member restrictions struct

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from restrict-chat-member
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from restrict-chat-member
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.editBanned
                    :chat-id chat-id
                    :user-id user-id
                    :banned-rights (make-tl-object
                                    'chatBannedRights
                                    :view-messages (not (member-restrictions-can-send-messages restrictions))
                                    :send-messages (not (member-restrictions-can-send-messages restrictions))
                                    :send-media (not (member-restrictions-can-send-media restrictions))
                                    :send-polls (not (member-restrictions-can-send-polls restrictions))
                                    :send-stickers (not (member-restrictions-can-send-other restrictions))
                                    :send-gifs (not (member-restrictions-can-send-other restrictions))
                                    :send-inline (not (member-restrictions-can-send-other restrictions))
                                    :embed-links (not (member-restrictions-can-add-web-page-previews restrictions))
                                    :until-date (or (member-restrictions-until-date restrictions) 0)))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Invite Link Management

(defstruct chat-invite-link
  "Chat invite link information"
  (link nil :type string)
  (creator-id nil :type integer)
  (create-date nil :type integer)
  (start-date nil :type integer)
  (expire-date nil :type (or null integer))
  (usage-limit nil :type (or null integer))
  (usage-count nil :type integer)
  (name nil :type string)
  (requests-pending nil :type boolean)
  (is-primary nil :type boolean)
  (is-revoked nil :type boolean))

(defun create-chat-invite-link (chat-id &key name expire-seconds usage-limit)
  "Create a new chat invite link.

   Args:
     chat-id: Chat ID
     name: Optional link name
     expire-seconds: Seconds until expiration (0 = never)
     usage-limit: Maximum usage count (0 = unlimited)

   Returns:
     Invite link object on success"
  (unless (authorized-p)
    (return-from create-chat-invite-link
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from create-chat-invite-link
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.exportChatInvite
                    :chat-id chat-id
                    :title (or name "")
                    :expire-date (if (and expire-seconds (> expire-seconds 0))
                                     (+ (get-universal-time) expire-seconds)
                                     0)
                    :usage-limit (or usage-limit 0))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatInvite)
              (let ((link (make-chat-invite-link
                           :link (getf result :link)
                           :creator-id (getf result :admin-id)
                           :create-date (getf result :date)
                           :name (or name ""))))
                (values link nil))
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-chat-invite-link (chat-id)
  "Get primary invite link for a chat.

   Args:
     chat-id: Chat ID

   Returns:
     Invite link string"
  (unless (authorized-p)
    (return-from get-chat-invite-link
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-chat-invite-link
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.exportChatInvite
                    :chat-id chat-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values (getf result :link) nil))
        (:error (err)
          (values nil :rpc-error err))))))

(defun revoke-chat-invite-link (chat-id link)
  "Revoke a chat invite link.

   Args:
     chat-id: Chat ID
     link: Invite link to revoke

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from revoke-chat-invite-link
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from revoke-chat-invite-link
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.revokeChatInvite
                    :chat-id chat-id
                    :link link)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatInvite)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-chat-invite-link-members (chat-id link &key (limit 100))
  "Get members who joined via invite link.

   Args:
     chat-id: Chat ID
     link: Invite link
     limit: Maximum members to retrieve

   Returns:
     List of members"
  (unless (authorized-p)
    (return-from get-chat-invite-link-members
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-chat-invite-link-members
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.getChatInviteMembers
                    :chat-id chat-id
                    :link link
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatInviteMembers)
              (values (getf result :members) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Polls and Voting

(defstruct poll-option
  "Poll option"
  (text nil :type string)
  (votes nil :type integer)
  (is-selected nil :type boolean)
  (data nil :type string))

(defstruct poll
  "Poll object"
  (id nil :type integer)
  (question nil :type string)
  (options nil :type list)
  (total-votes nil :type integer)
  (is-closed nil :type boolean)
  (is-anonymous nil :type boolean)
  (is-multiple-choice nil :type boolean)
  (correct-option-id nil :type (or null integer))
  (open-period nil :type (or null integer))
  (close-date nil :type (or null integer)))

(defun make-poll (question options &key anonymous multiple-choice open-period)
  "Create a poll.

   Args:
     question: Poll question
     options: List of option strings
     anonymous: Is vote anonymous (default t)
     multiple-choice: Allow multiple answers (default nil)
     open-period: Poll duration in seconds (0-604800)

   Returns:
     Poll struct"
  (make-poll
   :question question
   :options (loop for opt-text in options
                  for i from 0
                  collect (make-poll-option
                           :text opt-text
                           :votes 0
                           :is-selected nil
                           :data (format nil "~D" i)))
   :total-votes 0
   :is-closed nil
   :is-anonymous (or anonymous t)
   :is-multiple-choice (or multiple-choice nil)
   :open-period open-period))

(defun send-poll (chat-id poll &key caption reply-to-message-id)
  "Send a poll to a chat.

   Args:
     chat-id: Chat ID
     poll: Poll object
     caption: Optional caption
     reply-to-message-id: Optional reply target

   Returns:
     Message object on success"
  (unless (authorized-p)
    (return-from send-poll
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-poll
        (values nil :no-connection)))

    (let* ((options-payload (loop for opt in (poll-options poll)
                                  collect (make-tl-object
                                           'pollOption
                                           :text (poll-option-text opt)
                                           :data (babel:string-to-octets
                                                  (poll-option-data opt)))))
           (request (make-tl-object
                     'messages.sendMedia
                     :chat-id chat-id
                     :media (make-tl-object
                             'messageMediaPoll
                             :poll (make-tl-object
                                    'poll
                                    :id (random-most-positive-fixnum)
                                    :question (poll-question poll)
                                    :answers options-payload
                                    :closed (poll-is-closed poll)
                                    :public-voters (not (poll-is-anonymous poll))
                                    :multiple-choice (poll-is-multiple-choice poll)
                                    :quiz-p nil
                                    :open-period (poll-open-period poll)))
                     :message (or caption "")
                     :reply-to-msg-id reply-to-message-id))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun stop-poll (chat-id message-id)
  "Stop an active poll.

   Args:
     chat-id: Chat ID
     message-id: Message ID containing poll

   Returns:
     Updated poll object"
  (unless (authorized-p)
    (return-from stop-poll
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from stop-poll
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.editMessage
                    :chat-id chat-id
                    :id message-id
                    :media (make-tl-object
                            'messageMediaPoll
                            :poll-closed t))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values result nil))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Group Statistics

(defstruct group-stats
  "Group statistics"
  (member-count nil :type integer)
  (message-count nil :type integer)
  (viewer-count nil :type integer)
  (sharer-count nil :type integer)
  (period-start nil :type integer)
  (period-end nil :type integer))

(defun get-group-statistics (chat-id &key start-date end-date)
  "Get group/channel statistics.

   Args:
     chat-id: Chat ID
     start-date: Start of period (Unix timestamp)
     end-date: End of period (Unix timestamp)

   Returns:
     Group stats object"
  (unless (authorized-p)
    (return-from get-group-statistics
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-group-statistics
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'stats.getMegagroupStats
                    :channel chat-id
                    :from-date (or start-date 0)
                    :to-date (or end-date (get-universal-time)))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :stats.megagroupStats)
              (values (make-group-stats
                       :member-count (getf result :members)
                       :message-count (getf result :messages)
                       :viewer-count (getf result :viewers)
                       :sharer-count (getf result :sharers))
                      nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-group-admin-log (chat-id &key limit event-types)
  "Get group admin action log.

   Args:
     chat-id: Chat ID
     limit: Maximum entries to retrieve
     event-types: Filter by event types (nil = all)

   Returns:
     List of log entries"
  (unless (authorized-p)
    (return-from get-group-admin-log
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-group-admin-log
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'channels.getAdminLog
                    :channel chat-id
                    :q ""
                    :limit (or limit 100)
                    :events-filter (when event-types
                                     (make-tl-object
                                      'chatAdminLogEventsFilter
                                      :join (member :join event-types)
                                      :leave (member :leave event-types)
                                      :invite (member :invite event-types)
                                      :ban (member :ban event-types)
                                      :unban (member :unban event-types)
                                      :kick (member :kick event-types)
                                      :promo (member :promo event-types)
                                      :messages (member :messages event-types)
                                      :settings (member :settings event-types)
                                      :info (member :info event-types)))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatAdminLog)
              (values (getf result :events) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Auto-Moderation Rules

(defstruct auto-mod-rule
  "Auto-moderation rule"
  (rule-type nil :type keyword)
  (pattern nil :type (or null string))
  (action nil :type keyword)
  (enabled nil :type boolean)
  (exceptions nil :type list))

(defvar *auto-mod-rules* (make-hash-table :test 'equal)
  "Auto-moderation rules per chat")

(defun add-auto-mod-rule (chat-id rule-type pattern action &key exceptions)
  "Add auto-moderation rule.

   Args:
     chat-id: Chat ID
     rule-type: Rule type (:spam, :flood, :link, :keyword, :media)
     pattern: Pattern to match (for keyword rules)
     action: Action (:delete, :warn, :ban, :mute)
     exceptions: List of exempt user IDs

   Returns:
     T on success"
  (let ((rules (gethash chat-id *auto-mod-rules* (make-array 10 :adjustable t :fill-pointer 0))))
    (vector-push-extend
     (make-auto-mod-rule
      :rule-type rule-type
      :pattern pattern
      :action action
      :enabled t
      :exceptions (or exceptions nil))
     rules)
    (setf (gethash chat-id *auto-mod-rules*) rules))
  t)

(defun remove-auto-mod-rule (chat-id rule-index)
  "Remove auto-moderation rule by index.

   Args:
     chat-id: Chat ID
     rule-index: Rule index to remove

   Returns:
     T on success"
  (let ((rules (gethash chat-id *auto-mod-rules*)))
    (when (and rules (> (length rules) rule-index))
      (delete rule-index rules))
    t))

(defun get-auto-mod-rules (chat-id)
  "Get auto-moderation rules for a chat.

   Args:
     chat-id: Chat ID

   Returns:
     List of rules"
  (let ((rules (gethash chat-id *auto-mod-rules*)))
    (if rules
        (coerce rules 'list)
        nil)))

(defun check-auto-mod (chat-id user-id message)
  "Check message against auto-mod rules.

   Args:
     chat-id: Chat ID
     user-id: Sender user ID
     message: Message object

   Returns:
     Action keyword or nil"
  (let ((rules (gethash chat-id *auto-mod-rules*)))
    (when rules
      (loop for rule across rules
            when (and (auto-mod-rule-enabled rule)
                      (not (member user-id (auto-mod-rule-exceptions rule))))
            do (let ((action (check-rule rule message)))
                 (when action
                   (return action)))))))

(defun check-rule (rule message)
  "Check single rule against message.

   Args:
     rule: Auto-mod rule
     message: Message object

   Returns:
     Action keyword or nil"
  (let ((text (getf message :text)))
    (case (auto-mod-rule-rule-type rule)
      (:keyword
       (when (and text (search (auto-mod-rule-pattern rule) text))
         (auto-mod-rule-action rule)))
      (:link
       (when (and text (or (search "http://" text) (search "https://" text)))
         (auto-mod-rule-action rule)))
      (otherwise nil))))

;;; ### Member Approval Mode

(defun enable-member-approval (chat-id)
  "Enable member approval mode for chat.

   Args:
     chat-id: Chat ID

   Returns:
     T on success"
  (set-chat-permissions chat-id :require-approval t))

(defun disable-member-approval (chat-id)
  "Disable member approval mode.

   Args:
     chat-id: Chat ID

   Returns:
     T on success"
  (set-chat-permissions chat-id :require-approval nil))

(defun get-pending-join-requests (chat-id)
  "Get pending member join requests.

   Args:
     chat-id: Chat ID

   Returns:
     List of pending requests"
  (unless (authorized-p)
    (return-from get-pending-join-requests
      (values nil :not-authorized)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-pending-join-requests
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.getChatJoinRequests
                    :chat-id chat-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chatJoinRequests)
              (values (getf result :requests) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun approve-join-request (chat-id user-id)
  "Approve a join request.

   Args:
     chat-id: Chat ID
     user-id: Requesting user ID

   Returns:
     T on success"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from approve-join-request
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.hideChatJoinRequest
                    :chat-id chat-id
                    :user-id user-id
                    :approved t)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values t nil))
        (:error (err)
          (values nil :rpc-error err))))))

(defun decline-join-request (chat-id user-id)
  "Decline a join request.

   Args:
     chat-id: Chat ID
     user-id: Requesting user ID

   Returns:
     T on success"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from decline-join-request
        (values nil :no-connection)))

    (let ((request (make-tl-object
                    'messages.hideChatJoinRequest
                    :chat-id chat-id
                    :user-id user-id
                    :approved nil)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values t nil))
        (:error (err)
          (values nil :rpc-error err))))))
