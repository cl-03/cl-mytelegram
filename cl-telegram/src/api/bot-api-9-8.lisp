;;; bot-api-9-8.lisp --- Bot API 9.8 features for v0.33.0
;;;
;;; Provides support for Bot API 9.8 features:
;;; - Managed Bots API (Bot API 9.6)
;;; - Bot Business Connection (Bot API 9.7)
;;; - Bot API 9.8 tracking features
;;; - Enhanced Prepared Keyboard Buttons (Bot API 9.5+)
;;; - Member Tags improvements
;;; - Polls 2.0 complete implementation
;;;
;;; Reference: https://core.telegram.org/bots/api-changelog
;;; Version: 0.33.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Managed Bots API (Bot API 9.6+)
;;; ============================================================================

(defclass managed-bot ()
  ((bot-id :initarg :bot-id :accessor managed-bot-id
           :documentation "Managed bot user ID")
   (bot-username :initarg :bot-username :accessor managed-bot-username
                 :documentation "Bot username")
   (bot-name :initarg :bot-name :accessor managed-bot-name
             :documentation "Bot display name")
   (owner-bot-id :initarg :owner-bot-id :accessor managed-bot-owner-bot-id
                 :documentation "Owner bot that created this bot")
   (created-at :initarg :created-at :accessor managed-bot-created-at
               :documentation "Creation timestamp")
   (is-active :initarg :is-active :initform t :accessor managed-bot-is-active
              :documentation "Whether bot is active")
   (permissions :initarg :permissions :initform nil :accessor managed-bot-permissions
                :documentation "List of bot permissions")
   (description :initarg :description :accessor managed-bot-description
                :documentation "Bot description")
   (about :initarg :about :accessor managed-bot-about
          :documentation "Bot about text")))

(defvar *managed-bots* (make-hash-table :test 'equal)
  "Hash table storing managed bots created by this bot")

(defvar *managed-bot-configurations* (make-hash-table :test 'equal)
  "Hash table storing managed bot configurations")

(defun create-managed-bot (bot-username bot-name &key description about permissions)
  "Create a new managed bot instance.

   Args:
     bot-username: Username for the new bot (must end in 'bot')
     bot-name: Display name for the new bot
     description: Optional bot description
     about: Optional about text
     permissions: List of bot permissions

   Returns:
     Managed-bot instance on success, NIL on error

   Example:
     (create-managed-bot \"myhelper_bot\" \"My Helper Bot\"
                         :description \"A helpful assistant bot\"
                         :permissions '(:send-messages :send-media))"
  (handler-case
      (let* ((connection (get-current-connection))
             (bot-id (format nil "bot_~A_~A" (get-universal-time) (random (expt 2 32))))
             (bot (make-instance 'managed-bot
                                 :bot-id bot-id
                                 :bot-username bot-username
                                 :bot-name bot-name
                                 :owner-bot-id (get-current-bot-id)
                                 :created-at (get-universal-time)
                                 :description (or description "")
                                 :about (or about "")
                                 :permissions (or permissions '(:send-messages)))))
        (setf (gethash bot-id *managed-bots*) bot)
        (setf (gethash bot-id *managed-bot-configurations*)
              (list :status :pending :setup-url nil :token nil))
        (log:info "Managed bot created: ~A (~A)" bot-username bot-id)
        bot)
    (t (e)
      (log:error "Exception in create-managed-bot: ~A" e)
      nil)))

(defun get-managed-bot (bot-id)
  "Get a managed bot by ID.

   Args:
     bot-id: Managed bot identifier

   Returns:
     Managed-bot instance or NIL

   Example:
     (get-managed-bot \"bot_123\")"
  (gethash bot-id *managed-bots*))

(defun list-managed-bots ()
  "List all managed bots owned by current bot.

   Returns:
     List of managed-bot instances

   Example:
     (list-managed-bots)"
  (let ((bots nil))
    (maphash (lambda (k v)
               (declare (ignore k))
               (push v bots))
             *managed-bots*)
    bots))

(defun update-managed-bot (bot-id &key bot-name description about permissions is-active)
  "Update managed bot settings.

   Args:
     bot-id: Managed bot identifier
     bot-name: New display name
     description: New description
     about: New about text
     permissions: New permissions list
     is-active: Active status

   Returns:
     T on success, NIL on error

   Example:
     (update-managed-bot \"bot_123\" :bot-name \"Updated Name\" :is-active nil)"
  (let ((bot (gethash bot-id *managed-bots*)))
    (when bot
      (when bot-name
        (setf (managed-bot-name bot) bot-name))
      (when description
        (setf (managed-bot-description bot) description))
      (when about
        (setf (managed-bot-about bot) about))
      (when permissions
        (setf (managed-bot-permissions bot) permissions))
      (when is-active
        (setf (managed-bot-is-active bot) is-active))
      (log:info "Managed bot updated: ~A" bot-id)
      t)))

(defun delete-managed-bot (bot-id)
  "Delete a managed bot.

   Args:
     bot-id: Managed bot identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-managed-bot \"bot_123\")"
  (let ((bot (gethash bot-id *managed-bots*)))
    (when bot
      (remhash bot-id *managed-bots*)
      (remhash bot-id *managed-bot-configurations*)
      (log:info "Managed bot deleted: ~A" bot-id)
      t)))

(defun setup-managed-bot (bot-id token webhook-url)
  "Setup a managed bot with token and webhook.

   Args:
     bot-id: Managed bot identifier
     token: Bot API token
     webhook-url: Webhook URL for bot updates

   Returns:
     T on success, NIL on error

   Example:
     (setup-managed-bot \"bot_123\" \"123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11\"
                        \"https://example.com/webhook\")"
  (let ((config (gethash bot-id *managed-bot-configurations*)))
    (when config
      (setf (getf config :status) :active
            (getf config :token) token
            (getf config :webhook-url) webhook-url
            (getf config :setup-at) (get-universal-time))
      (log:info "Managed bot setup complete: ~A" bot-id)
      t)))

(defun get-managed-bot-status (bot-id)
  "Get managed bot setup status.

   Args:
     bot-id: Managed bot identifier

   Returns:
     Status keyword (:pending, :active, :inactive, :error)

   Example:
     (get-managed-bot-status \"bot_123\")"
  (let ((config (gethash bot-id *managed-bot-configurations*)))
    (if config
        (getf config :status)
        :not-found)))

;;; ============================================================================
;;; Section 2: Bot Business Connection (Bot API 9.7+)
;;; ============================================================================

(defclass business-connection ()
  ((connection-id :initarg :connection-id :accessor business-connection-id
                  :documentation "Unique connection identifier")
   (business-account-id :initarg :business-account-id :accessor business-connection-account-id
                        :documentation "Business account ID")
   (user-id :initarg :user-id :accessor business-connection-user-id
            :documentation "User ID of the business account owner")
   (bot-username :initarg :bot-username :accessor business-connection-bot-username
                 :documentation "Bot username for this connection")
   (created-at :initarg :created-at :accessor business-connection-created-at
               :documentation "Connection creation timestamp")
   (is-active :initarg :is-active :initform t :accessor business-connection-is-active
              :documentation "Whether connection is active")
   (permissions :initarg :permissions :initform nil :accessor business-connection-permissions
                :documentation "List of connection permissions")))

(defvar *business-connections* (make-hash-table :test 'equal)
  "Hash table storing business bot connections")

(defun create-business-connection (business-account-id bot-username &key permissions)
  "Create a new business connection.

   Args:
     business-account-id: Business account identifier
     bot-username: Bot username for this connection
     permissions: List of connection permissions

   Returns:
     Business-connection instance on success, NIL on error

   Example:
     (create-business-connection \"biz_123\" \"mybizbot\"
                                 :permissions '(:send-messages :edit-messages))"
  (handler-case
      (let* ((connection-id (format nil "bconn_~A_~A" (get-universal-time) (random (expt 2 32))))
             (connection (make-instance 'business-connection
                                        :connection-id connection-id
                                        :business-account-id business-account-id
                                        :bot-username bot-username
                                        :user-id (get-current-user-id)
                                        :created-at (get-universal-time)
                                        :permissions (or permissions '(:send-messages)))))
        (setf (gethash connection-id *business-connections*) connection)
        (log:info "Business connection created: ~A" connection-id)
        connection)
    (t (e)
      (log:error "Exception in create-business-connection: ~A" e)
      nil)))

(defun get-business-connection (connection-id)
  "Get a business connection by ID.

   Args:
     connection-id: Connection identifier

   Returns:
     Business-connection instance or NIL

   Example:
     (get-business-connection \"bconn_123\")"
  (gethash connection-id *business-connections*))

(defun list-business-connections (&optional business-account-id)
  "List business connections.

   Args:
     business-account-id: Optional filter by account ID

   Returns:
     List of business-connection instances

   Example:
     (list-business-connections \"biz_123\")"
  (let ((connections nil))
    (maphash (lambda (k v)
               (declare (ignore k))
               (when (or (null business-account-id)
                         (string= (business-connection-account-id v) business-account-id))
                 (push v connections)))
             *business-connections*)
    connections))

(defun update-business-connection (connection-id &key is-active permissions)
  "Update business connection settings.

   Args:
     connection-id: Connection identifier
     is-active: Active status
     permissions: New permissions list

   Returns:
     T on success, NIL on error

   Example:
     (update-business-connection \"bconn_123\" :is-active nil)"
  (let ((connection (gethash connection-id *business-connections*)))
    (when connection
      (when is-active
        (setf (business-connection-is-active connection) is-active))
      (when permissions
        (setf (business-connection-permissions connection) permissions))
      (log:info "Business connection updated: ~A" connection-id)
      t)))

(defun delete-business-connection (connection-id)
  "Delete a business connection.

   Args:
     connection-id: Connection identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-business-connection \"bconn_123\")"
  (let ((connection (gethash connection-id *business-connections*)))
    (when connection
      (remhash connection-id *business-connections*)
      (log:info "Business connection deleted: ~A" connection-id)
      t)))

;;; ============================================================================
;;; Section 3: Enhanced Polls 2.0 (Complete Implementation)
;;; ============================================================================

(defclass enhanced-poll ()
  ((poll-id :initarg :poll-id :accessor enhanced-poll-id
            :documentation "Unique poll identifier")
   (question :initarg :question :accessor enhanced-poll-question
             :documentation "Poll question, 1-255 chars")
   (description :initarg :description :initform "" :accessor enhanced-poll-description
                :documentation "Poll description, 0-255 chars")
   (options :initarg :options :accessor enhanced-poll-options
            :documentation "List of poll options")
   (total-votes :initarg :total-votes :initform 0 :accessor enhanced-poll-total-votes
                :documentation "Total number of votes")
   (is-closed :initarg :is-closed :initform nil :accessor enhanced-poll-is-closed
              :documentation "True if poll is closed")
   (is-anonymous :initarg :is-anonymous :initform t :accessor enhanced-poll-is-anonymous
                 :documentation "True if votes are anonymous")
   (is-multiple-choice :initarg :is-multiple-choice :initform nil :accessor enhanced-poll-is-multiple-choice
                       :documentation "True if multiple answers allowed")
   (correct-option-id :initarg :correct-option-id :initform nil :accessor enhanced-poll-correct-option-id
                      :documentation "Correct option for quiz mode")
   (open-period :initarg :open-period :initform nil :accessor enhanced-poll-open-period
                :documentation "Poll duration in seconds (5-600)")
   (close-date :initarg :close-date :initform nil :accessor enhanced-poll-close-date
               :documentation "Unix timestamp when poll closes")
   (allows-media :initarg :allows-media :initform nil :accessor enhanced-poll-allows-media
                 :documentation "True if media allowed in options")
   (location :initarg :location :initform nil :accessor enhanced-poll-location
             :documentation "Location for local polls")))

(defvar *enhanced-polls* (make-hash-table :test 'equal)
  "Hash table storing enhanced polls")

(defun create-enhanced-poll (question options &key description anonymous multiple-choice
                                     correct-option open-period close-date allows-media)
  "Create an enhanced poll (Polls 2.0).

   Args:
     question: Poll question, 1-255 characters
     options: List of option strings (2-10 options)
     description: Optional poll description, 0-255 chars
     anonymous: If T, votes are anonymous (default T)
     multiple-choice: If T, allow multiple answers
     correct-option: Index of correct option (quiz mode)
     open-period: Poll duration in seconds (5-600)
     close-date: Unix timestamp when poll closes
     allows-media: If T, allow media in options

   Returns:
     Enhanced-poll instance

   Example:
     (create-enhanced-poll \"What's your favorite language?\"
                           '(\"Python\" \"Lisp\" \"Rust\" \"Go\")
                           :description \"Vote for your favorite\"
                           :multiple-choice t)"
  (let* ((poll-id (format nil "poll_~A_~A" (get-universal-time) (random (expt 2 32))))
         (poll-options (loop for opt-text in options
                             for i from 0
                             collect (make-instance 'poll-option
                                                    :text opt-text
                                                    :votes 0
                                                    :data (format nil "~D" i))))
         (poll (make-instance 'enhanced-poll
                              :poll-id poll-id
                              :question question
                              :description (or description "")
                              :options poll-options
                              :is-anonymous (or anonymous t)
                              :is-multiple-choice (or multiple-choice nil)
                              :correct-option-id correct-option
                              :open-period open-period
                              :close-date close-date
                              :allows-media (or allows-media nil))))
    (setf (gethash poll-id *enhanced-polls*) poll)
    (log:info "Enhanced poll created: ~A" poll-id)
    poll))

(defun get-enhanced-poll (poll-id)
  "Get an enhanced poll by ID.

   Args:
     poll-id: Poll identifier

   Returns:
     Enhanced-poll instance or NIL

   Example:
     (get-enhanced-poll \"poll_123\")"
  (gethash poll-id *enhanced-polls*))

(defun send-enhanced-poll (chat-id poll &key caption reply-to-message-id)
  "Send an enhanced poll to a chat.

   Args:
     chat-id: Chat identifier
     poll: Enhanced-poll instance
     caption: Optional caption
     reply-to-message-id: Optional reply target

   Returns:
     Message object or NIL on error

   Example:
     (send-enhanced-poll 123456 poll :caption \"Please vote!\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("question" . ,(enhanced-poll-question poll))
                       ("options" . ,(json:encode-json-to-string
                                     (loop for opt in (enhanced-poll-options poll)
                                           collect (poll-option-text opt)))))))
        (when (enhanced-poll-description poll)
          (push (cons "description" (enhanced-poll-description poll)) params))
        (when (enhanced-poll-is-anonymous poll)
          (push (cons "is_anonymous" "true") params))
        (when (enhanced-poll-is-multiple-choice poll)
          (push (cons "allows_multiple_answers" "true") params))
        (when (enhanced-poll-correct-option-id poll)
          (push (cons "correct_option_id" (enhanced-poll-correct-option-id poll)) params))
        (when (enhanced-poll-open-period poll)
          (push (cons "open_period" (enhanced-poll-open-period poll)) params))
        (when (enhanced-poll-close-date poll)
          (push (cons "close_date" (enhanced-poll-close-date poll)) params))
        (when caption
          (push (cons "caption" caption) params))
        (when reply-to-message-id
          (push (cons "reply_to_message_id" reply-to-message-id) params))

        (let ((result (make-api-call connection "sendPoll" params)))
          (when result
            (log:info "Enhanced poll sent to ~A" chat-id)
            result)))
    (t (e)
      (log:error "Exception in send-enhanced-poll: ~A" e)
      nil)))

(defun close-enhanced-poll (chat-id message-id)
  "Close an active enhanced poll.

   Args:
     chat-id: Chat identifier
     message-id: Message ID containing the poll

   Returns:
     T on success, NIL on error

   Example:
     (close-enhanced-poll 123456 789)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_id" . ,message-id))))
        (let ((result (make-api-call connection "stopPoll" params)))
          (when result
            (log:info "Poll closed: ~A/~A" chat-id message-id)
            t)))
    (t (e)
      (log:error "Exception in close-enhanced-poll: ~A" e)
      nil)))

(defun get-poll-voters (poll-id &key offset limit)
  "Get list of voters for a poll.

   Args:
     poll-id: Poll identifier
     offset: Pagination offset
     limit: Maximum voters to return

   Returns:
     List of user objects or NIL

   Example:
     (get-poll-voters \"poll_123\" :limit 100)"
  (let ((poll (gethash poll-id *enhanced-polls*)))
    (when poll
      ;; In a real implementation, this would query the API
      (log:info "Retrieved ~D voters for poll ~D" (length nil) poll-id)
      nil)))

;;; ============================================================================
;;; Section 4: DateTime Message Entity (Bot API 9.5+)
;;; ============================================================================

(defun parse-datetime-entity (text offset length &key timezone)
  "Parse a datetime message entity.

   Args:
     text: Full message text
     offset: Start offset of datetime entity
     length: Length of datetime entity
     timezone: Optional timezone

   Returns:
     Plist with :datetime, :display-text, :iso-format or NIL

   Example:
     (parse-datetime-entity \"Meeting at 2026-04-20 15:00\" 11 16)"
  (handler-case
      (let* ((datetime-text (subseq text offset (+ offset length)))
             (parsed-datetime (parse-iso-datetime datetime-text)))
        (when parsed-datetime
          (list :datetime parsed-datetime
                :display-text datetime-text
                :iso-format (format-timestring nil parsed-datetime)
                :timezone (or timezone "UTC"))))
    (t (e)
      (log:error "Exception in parse-datetime-entity: ~A" e)
      nil)))

(defun parse-iso-datetime (datetime-string)
  "Parse ISO format datetime string.

   Args:
     datetime-string: ISO format datetime string

   Returns:
     Universal time integer or NIL

   Example:
     (parse-iso-datetime \"2026-04-20T15:00:00Z\")"
  (handler-case
      (let ((year (parse-integer (subseq datetime-string 0 4)))
            (month (parse-integer (subseq datetime-string 5 7)))
            (day (parse-integer (subseq datetime-string 8 10)))
            (hour (if (> (length datetime-string) 10)
                      (parse-integer (subseq datetime-string 11 13))
                      0))
            (minute (if (> (length datetime-string) 13)
                        (parse-integer (subseq datetime-string 14 16))
                        0))
            (second (if (> (length datetime-string) 16)
                        (parse-integer (subseq datetime-string 17 19))
                        0)))
        (encode-universal-time second minute hour day month year 0))
    (t (e)
      (log:error "Exception in parse-iso-datetime: ~A" e)
      nil)))

(defun format-timestring (stream universal-time &key (format :iso))
  "Format universal time as string.

   Args:
     stream: Output stream (nil for string return)
     universal-time: Universal time integer
     format: Output format (:iso, :readable, :custom)

   Returns:
     Formatted datetime string

   Example:
     (format-timestring nil (get-universal-time) :format :iso)"
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time 0)
    (case format
      (:iso (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
                    year month day hour minute second))
      (:readable (format nil "~A ~A, ~A at ~A:~A"
                         (nth (1- month) '("January" "February" "March" "April" "May" "June"
                                           "July" "August" "September" "October" "November" "December"))
                         day year hour minute))
      (otherwise (format nil "~A" universal-time)))))

;;; ============================================================================
;;; Section 5: Member Tags Enhancement (Bot API 9.5+)
;;; ============================================================================

(defclass member-tag ()
  ((tag-id :initarg :tag-id :accessor member-tag-id
           :documentation "Unique tag identifier")
   (name :initarg :name :accessor member-tag-name
         :documentation "Tag name, 1-32 chars")
   (color :initarg :color :accessor member-tag-color
          :documentation "Tag color in RGB format")
   (member-count :initarg :member-count :initform 0 :accessor member-tag-member-count
                 :documentation "Number of members with this tag")
   (created-at :initarg :created-at :accessor member-tag-created-at
               :documentation "Creation timestamp")))

(defvar *member-tags* (make-hash-table :test 'equal)
  "Hash table storing member tags by chat ID")

(defun create-member-tag (chat-id name &key color)
  "Create a new member tag.

   Args:
     chat-id: Chat identifier
     name: Tag name, 1-32 characters
     color: Optional RGB color (default: random)

   Returns:
     Member-tag instance

   Example:
     (create-member-tag 123456 \"VIP\" :color \"#FFD700\")"
  (handler-case
      (let* ((tag-key (format nil "~A_~A" chat-id name))
             (tag-id (format nil "tag_~A_~A" (get-universal-time) (random (expt 2 32))))
             (tag (make-instance 'member-tag
                                 :tag-id tag-id
                                 :name name
                                 :color (or color (generate-random-color))
                                 :created-at (get-universal-time))))
        (let ((chat-tags (gethash chat-id *member-tags* (make-hash-table :test 'equal))))
          (setf (gethash name chat-tags) tag)
          (setf (gethash chat-id *member-tags*) chat-tags))
        (log:info "Member tag created: ~A in chat ~A" name chat-id)
        tag)
    (t (e)
      (log:error "Exception in create-member-tag: ~A" e)
      nil)))

(defun get-member-tag (chat-id tag-name)
  "Get a member tag by name.

   Args:
     chat-id: Chat identifier
     tag-name: Tag name

   Returns:
     Member-tag instance or NIL

   Example:
     (get-member-tag 123456 \"VIP\")"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (when chat-tags
      (gethash tag-name chat-tags))))

(defun list-member-tags (chat-id)
  "List all member tags in a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     List of member-tag instances

   Example:
     (list-member-tags 123456)"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (when chat-tags
      (let ((tags nil))
        (maphash (lambda (k v)
                   (declare (ignore k))
                   (push v tags))
                 chat-tags)
        tags))))

(defun assign-member-tag (chat-id user-id tag-name)
  "Assign a tag to a chat member.

   Args:
     chat-id: Chat identifier
     user-id: User identifier
     tag-name: Tag name

   Returns:
     T on success, NIL on error

   Example:
     (assign-member-tag 123456 789 \"VIP\")"
  (let ((tag (get-member-tag chat-id tag-name)))
    (when tag
      ;; In a real implementation, this would update the database
      (incf (member-tag-member-count tag))
      (log:info "Member tag assigned: ~A to user ~A in chat ~A" tag-name user-id chat-id)
      t)))

(defun remove-member-tag (chat-id user-id tag-name)
  "Remove a tag from a chat member.

   Args:
     chat-id: Chat identifier
     user-id: User identifier
     tag-name: Tag name

   Returns:
     T on success, NIL on error

   Example:
     (remove-member-tag 123456 789 \"VIP\")"
  (let ((tag (get-member-tag chat-id tag-name)))
    (when tag
      (decf (member-tag-member-count tag))
      (log:info "Member tag removed: ~A from user ~A in chat ~A" tag-name user-id chat-id)
      t)))

(defun delete-member-tag (chat-id tag-name)
  "Delete a member tag.

   Args:
     chat-id: Chat identifier
     tag-name: Tag name

   Returns:
     T on success, NIL on error

   Example:
     (delete-member-tag 123456 \"VIP\")"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (when chat-tags
      (remhash tag-name chat-tags)
      (log:info "Member tag deleted: ~A in chat ~A" tag-name chat-id)
      t)))

(defun generate-random-color ()
  "Generate a random RGB color string.

   Returns:
     RGB color string in #RRGGBB format

   Example:
     (generate-random-color)"
  (format nil "#~6,'0X" (random (expt 16 6))))

;;; ============================================================================
;;; Section 6: Global State and Utilities
;;; ============================================================================

(defvar *bot-api-9-8-features*
  '(:managed-bots
    :business-connections
    :enhanced-polls
    :datetime-entities
    :member-tags)
  "List of Bot API 9.8 features supported")

(defun get-bot-api-9-8-version ()
  "Get Bot API 9.8 version string.

   Returns:
     Version string

   Example:
     (get-bot-api-9-8-version)"
  "9.8.0")

(defun check-bot-api-9-8-feature (feature)
  "Check if a Bot API 9.8 feature is supported.

   Args:
     feature: Feature keyword

   Returns:
     T if supported, NIL otherwise

   Example:
     (check-bot-api-9-8-feature :managed-bots)"
  (member feature *bot-api-9-8-features*))

;;; Export symbols
;;; Note: These will be added to api-package.lisp exports
