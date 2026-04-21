;;; bot-api-9-6-inline.lisp --- Bot API 9.6+ Inline Mode Enhancements
;;;
;;; Provides enhanced support for Inline Mode features (Bot API 9.6+):
;;; - SwitchInlineQueryChosenChat support
;;; - MenuButton types (commands, bot_apps, default)
;;; - InlineQueryResultsButton with custom actions
;;; - KeyboardButtonRequestManagedBot
;;; - Enhanced callback query with game short name
;;;
;;; Reference: https://core.telegram.org/bots/api#inline-mode
;;; Version: 0.38.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Switch Inline Query Chosen Chat
;;; ============================================================================

(defclass switch-inline-query-chosen-chat ()
  ((query :initarg :query :accessor switch-inline-query-chosen-chat-query
          :initform nil :documentation "Default query text for inline mode")
   (allow-user-chats :initarg :allow-user-chats :accessor switch-inline-query-allow-users
                     :initform t :documentation "Allow switching to user chats")
   (allow-bot-chats :initarg :allow-bot-chats :accessor switch-inline-query-allow-bots
                    :initform nil :documentation "Allow switching to bot chats")
   (allow-group-chats :initarg :allow-group-chats :accessor switch-inline-query-allow-groups
                      :initform nil :documentation "Allow switching to group chats")
   (allow-channel-chats :initarg :allow-channel-chats :accessor switch-inline-query-allow-channels
                        :initform nil :documentation "Allow switching to channel chats")))

(defun make-switch-inline-query-chosen-chat (&key (query nil)
                                                  (allow-user-chats t)
                                                  (allow-bot-chats nil)
                                                  (allow-group-chats nil)
                                                  (allow-channel-chats nil))
  "Create SwitchInlineQueryChosenChat object.

   Args:
     query: Default inline query text (optional)
     allow-user-chats: Allow user chats (default: t)
     allow-bot-chats: Allow bot chats (default: nil)
     allow-group-chats: Allow group chats (default: nil)
     allow-channel-chats: Allow channel chats (default: nil)

   Returns:
     Switch-inline-query-chosen-chat object

   Example:
     (make-switch-inline-query-chosen-chat
       :query \"Share this\"
       :allow-user-chats t
       :allow-group-chats t)"
  (make-instance 'switch-inline-query-chosen-chat
                 :query query
                 :allow-user-chats allow-user-chats
                 :allow-bot-chats allow-bot-chats
                 :allow-group-chats allow-group-chats
                 :allow-channel-chats allow-channel-chats))

;;; ============================================================================
;;; Section 2: Enhanced Inline Keyboard Button
;;; ============================================================================

(defun make-inline-keyboard-button-enhanced (text &key (url nil)
                                             (callback-data nil)
                                             (switch-inline-query nil)
                                             (switch-inline-query-chosen-chat nil)
                                             (switch-bot nil)
                                             (web-app nil)
                                             (login-url nil)
                                             (pay nil)
                                             (request-user nil)
                                             (request-chat nil)
                                             (request-geo nil))
  "Create enhanced inline keyboard button with Bot API 9.6+ features.

   Args:
     text: Button text
     url: HTTP or tg:// URL
     callback-data: Callback data for bot (0-64 bytes)
     switch-inline-query: Deprecated, use switch-inline-query-chosen-chat
     switch-inline-query-chosen-chat: SwitchInlineQueryChosenChat object (Bot API 9.6+)
     switch-bot: Parameter to switch to PM with bot
     web-app: WebAppInfo for launching Mini Apps
     login-url: LoginUrl for Telegram Login
     pay: True for pay button
     request-user: Request user info (KeyboardButtonRequestUser)
     request-chat: Request chat info (KeyboardButtonRequestChat)
     request-geo: Request user location

   Returns:
     Inline-keyboard-button object with extended fields

   Example:
     (make-inline-keyboard-button-enhanced
       \"Share in Group\"
       :switch-inline-query-chosen-chat
       (make-switch-inline-query-chosen-chat
         :query \"Check this out\"
         :allow-group-chats t
         :allow-user-chats t))"
  (let ((button (make-instance 'inline-keyboard-button
                               :text text
                               :url url
                               :callback-data callback-data
                               :switch-inline-query switch-inline-query
                               :switch-bot switch-bot
                               :web-app web-app
                               :login-url login-url)))
    ;; Add extended fields dynamically
    (when switch-inline-query-chosen-chat
      (setf (slot-value button 'switch-inline-query-chosen-chat) switch-inline-query-chosen-chat))
    (when pay
      (setf (slot-value button 'pay) pay))
    (when request-user
      (setf (slot-value button 'request-user) request-user))
    (when request-chat
      (setf (slot-value button 'request-chat) request-chat))
    (when request-geo
      (setf (slot-value button 'request-geo) request-geo))
    button))

;;; ============================================================================
;;; Section 3: InlineQueryResultsButton
;;; ============================================================================

(defclass inline-query-results-button ()
  ((text :initarg :text :accessor inline-query-results-button-text
         :documentation "Button text")
   (web-app :initarg :web-app :accessor inline-query-results-button-web-app
            :initform nil :documentation "WebAppInfo for launching Mini Apps")
   (start-parameter :initarg :start-parameter :accessor inline-query-results-button-start-param
                    :initform nil :documentation "Bot API 9.6+ start parameter")))

(defun make-inline-query-results-button (text &key (web-app nil) (start-parameter nil))
  "Create InlineQueryResultsButton object (Bot API 9.6+).

   Args:
     text: Button text (0-40 characters)
     web-app: WebAppInfo for launching Mini Apps
     start-parameter: Deep linking parameter for private chats

   Returns:
     Inline-query-results-button object

   Example:
     (make-inline-query-results-button
       \"Launch App\"
       :start-parameter \"app_launch\")"
  (make-instance 'inline-query-results-button
                 :text text
                 :web-app web-app
                 :start-parameter start-parameter))

;;; ============================================================================
;;; Section 4: MenuButton Types
;;; ============================================================================

(defclass menu-button ()
  ((type :initarg :type :accessor menu-button-type
         :initform :default :documentation "Type: :default, :commands, :web_app")
   (text :initarg :text :accessor menu-button-text
         :initform nil :documentation "Button text (for web_app type)")
   (web-app :initarg :web-app :accessor menu-button-web-app
            :initform nil :documentation "WebAppInfo (for web_app type)")))

(defun make-menu-button-default ()
  "Create default menu button.

   Returns:
     Menu-button with type :default

   Example:
     (make-menu-button-default)"
  (make-instance 'menu-button :type :default))

(defun make-menu-button-commands ()
  "Create commands menu button (shows bot commands list).

   Returns:
     Menu-button with type :commands

   Example:
     (make-menu-button-commands)"
  (make-instance 'menu-button :type :commands))

(defun make-menu-button-web-app (text web-app)
  "Create web_app menu button (launches Mini App).

   Args:
     text: Button text
     web-app: WebAppInfo object

   Returns:
     Menu-button with type :web_app

   Example:
     (make-menu-button-web-app
       \"Open App\"
       (make-web-app-info :url \"https://example.com\"))"
  (make-instance 'menu-button
                 :type :web_app
                 :text text
                 :web-app web-app))

;;; ============================================================================
;;; Section 5: KeyboardButtonRequestManagedBot (Bot API 9.6)
;;; ============================================================================

(defclass keyboard-button-request-managed-bot ()
  ((request-id :initarg :request-id :accessor keyboard-button-request-managed-bot-id
               :documentation "Unique request identifier")
   (user-is-bot :initarg :user-is-bot :accessor keyboard-button-request-managed-bot-is-bot
                :initform nil :documentation "Require user to be a bot")
   (user-is-premium :initarg :user-is-premium :accessor keyboard-button-request-managed-bot-is-premium
                   :initform nil :documentation "Require user to have Telegram Premium")
   (request-name :initarg :request-name :accessor keyboard-button-request-managed-bot-name
                :initform nil :documentation "Request managed bot name")
   (request-username :initarg :request-username :accessor keyboard-button-request-managed-bot-username
                    :initform nil :documentation "Request managed bot username")))

(defun make-keyboard-button-request-managed-bot (request-id &key
                                                 (user-is-bot nil)
                                                 (user-is-premium nil)
                                                 (request-name nil)
                                                 (request-username nil))
  "Create KeyboardButtonRequestManagedBot object (Bot API 9.6).

   Args:
     request-id: Unique request identifier
     user-is-bot: Require user to be a bot (optional)
     user-is-premium: Require Telegram Premium (optional)
     request-name: Request bot name (optional)
     request-username: Request bot username (optional)

   Returns:
     Keyboard-button-request-managed-bot object

   Example:
     (make-keyboard-button-request-managed-bot
       12345
       :request-username t
       :request-name t)"
  (make-instance 'keyboard-button-request-managed-bot
                 :request-id request-id
                 :user-is-bot user-is-bot
                 :user-is-premium user-is-premium
                 :request-name request-name
                 :request-username request-username))

;;; ============================================================================
;;; Section 6: API Methods - Menu Button
;;; ============================================================================

(defun set-chat-menu-button (&key (chat-id nil) (menu-button nil))
  "Set menu button for bot or chat.

   Args:
     chat-id: Chat ID or NIL for default menu button
     menu-button: Menu-button object (default, commands, or web_app)

   Returns:
     T on success, NIL on failure

   Example:
     (set-chat-menu-button
       :chat-id -1001234567890
       :menu-button (make-menu-button-web-app \"Open\" web-app-info))"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        (when chat-id
          (push (cons "chat_id" chat-id) params))
        (when menu-button
          (push (cons "menu_button"
                      (json:encode-to-string
                        (list :type (menu-button-type menu-button)
                              :text (menu-button-text menu-button)
                              :web_app (menu-button-web-app menu-button))))
                params))
        (let ((result (make-api-call connection "setChatMenuButton" params)))
          (if result t nil)))
    (error (e)
      (log-message :error "Error setting menu button: ~A" (princ-to-string e))
      nil)))

(defun get-chat-menu-button (&key (chat-id nil))
  "Get menu button for bot or chat.

   Args:
     chat-id: Chat ID or NIL for default menu button

   Returns:
     Menu-button object on success, NIL on failure

   Example:
     (get-chat-menu-button :chat-id -1001234567890)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        (when chat-id
          (push (cons "chat_id" chat-id) params))
        (let ((result (make-api-call connection "getChatMenuButton" params)))
          (when result
            (let* ((type (getf result :type :default))
                   (text (getf result :text nil))
                   (web-app (getf result :web_app nil)))
              (make-instance 'menu-button
                             :type type
                             :text text
                             :web-app web-app)))))
    (error (e)
      (log-message :error "Error getting menu button: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 7: API Methods - Enhanced Inline Query Answer
;;; ============================================================================

(defun answer-inline-query-enhanced (query-id results &key
                                     (cache-time 300)
                                     (is-personal nil)
                                     (next-offset nil)
                                     (button nil)
                                     (switch-pm-text nil)
                                     (switch-pm-parameter nil))
  "Answer inline query with Bot API 9.6+ enhancements.

   Args:
     query-id: Inline query ID
     results: List of inline-result objects
     cache-time: How long to cache results (seconds, default: 300)
     is-personal: Whether results are for this user only
     next-offset: Offset for next page of results
     button: InlineQueryResultsButton object (Bot API 9.6+)
     switch-pm-text: Deprecated, use button instead
     switch-pm-parameter: Deprecated, use button instead

   Returns:
     T on success, NIL on failure

   Example:
     (answer-inline-query-enhanced
       query-id results
       :button (make-inline-query-results-button
                 \"Launch App\"
                 :start-parameter \"app_launch\"))"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("inline_query_id" . ,query-id)
                       ("results" . ,(json:encode-to-string results)))))
        (when cache-time
          (push (cons "cache_time" cache-time) params))
        (when is-personal
          (push (cons "is_personal" (if is-personal "true" "false")) params))
        (when next-offset
          (push (cons "next_offset" next-offset) params))
        (when button
          (push (cons "button"
                      (json:encode-to-string
                        (list :text (inline-query-results-button-text button)
                              :start_parameter (inline-query-results-button-start-param button))))
                params))
        (let ((result (make-api-call connection "answerInlineQuery" params)))
          (if result t nil)))
    (error (e)
      (log-message :error "Error answering inline query: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 8: Utility Functions
;;; ============================================================================

(defun inline-keyboard-button-with-switch-chat (text query &key
                                                (allow-users t)
                                                (allow-bots nil)
                                                (allow-groups t)
                                                (allow-channels nil))
  "Create inline keyboard button with switch inline query chosen chat.

   Args:
     text: Button text
     query: Default inline query text
     allow-users: Allow user chats (default: t)
     allow-bots: Allow bot chats (default: nil)
     allow-groups: Allow group chats (default: t)
     allow-channels: Allow channel chats (default: nil)

   Returns:
     Inline-keyboard-button object

   Example:
     (inline-keyboard-button-with-switch-chat
       \"Share in Chat\"
       \"Check this out\"
       :allow-groups t
       :allow-channels t)"
  (let ((chosen-chat (make-switch-inline-query-chosen-chat
                       :query query
                       :allow-user-chats allow-users
                       :allow-bot-chats allow-bots
                       :allow-group-chats allow-groups
                       :allow-channel-chats allow-channels)))
    (make-inline-keyboard-button-enhanced
      text
      :switch-inline-query-chosen-chat chosen-chat)))

(defun serialize-switch-inline-query-chosen-chat (chosen-chat)
  "Serialize SwitchInlineQueryChosenChat to JSON-compatible plist.

   Args:
     chosen-chat: Switch-inline-query-chosen-chat object

   Returns:
     Plist suitable for JSON encoding"
  (when chosen-chat
    (list :query (switch-inline-query-chosen-chat-query chosen-chat)
          :allow_user_chats (switch-inline-query-allow-users chosen-chat)
          :allow_bot_chats (switch-inline-query-allow-bots chosen-chat)
          :allow_group_chats (switch-inline-query-allow-groups chosen-chat)
          :allow_channel_chats (switch-inline-query-allow-channels chosen-chat))))

;;; End of bot-api-9-6-inline.lisp
