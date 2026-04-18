;;; bot-api.lisp --- Telegram Bot API HTTP client
;;;
;;; Implements the Telegram Bot API over HTTP for building Telegram bots.
;;; Reference: https://core.telegram.org/bots/api

(in-package #:cl-telegram/api)

;;; ### Bot Configuration

(defstruct bot-config
  "Telegram Bot configuration"
  (token "" :type string)
  (api-url "https://api.telegram.org" :type string)
  (timeout 30 :type integer)
  (use-test-environment nil :type boolean))

(defun make-bot (token &key timeout use-test-environment)
  "Create a new Bot instance.

   Args:
     token: Bot token from @BotFather
     timeout: Request timeout in seconds (default 30)
     use-test-environment: Use Telegram test server (default nil)

   Returns:
     Bot config struct

   Example:
     (defparameter *bot* (make-bot \"123456:ABC-DEF1234ghIkl-zyx57W2v1u123ewF135\"))"
  (make-bot-config
   :token token
   :timeout (or timeout 30)
   :use-test-environment (or use-test-environment nil)))

(defun bot-api-url (bot method)
  "Generate API URL for method.

   Args:
     bot: Bot config struct
     method: API method name

   Returns:
     Full API URL string"
  (format nil "~A/bot~A/~A"
          (if (bot-config-use-test-environment bot)
              "https://api.telegram.org/bot"
              (bot-config-api-url bot))
          (bot-config-token bot)
          method))

;;; ### HTTP Request Helper

(defun bot-request (bot method &key params)
  "Make a Bot API request.

   Args:
     bot: Bot config struct
     method: API method name (e.g., \"sendMessage\")
     params: Alist of parameters to send

   Returns:
     (values result error)
     - result: Decoded JSON response on success
     - error: Error description on failure

   Example:
     (bot-request *bot* \"sendMessage\"
                  :params '((:chat-id . 123456)
                            (:text . \"Hello\")))"
  (let* ((url (bot-api-url bot method))
         (json-params (when params
                        (jonathan:to-json (alist-to-hash params)))))
    (handler-case
        (let ((response (dex:post url
                                  :content json-params
                                  :headers '(("Content-Type" . "application/json"))
                                  :timeout (* (bot-config-timeout bot) 1000))))
          (let ((json (jonathan:from-json response)))
            (if (gethash "ok" json)
                (values (gethash "result" json) nil)
                (values nil (gethash "description" json)))))
      (error (e)
        (values nil (format nil "HTTP error: ~A" e))))))

(defun alist-to-hash (alist)
  "Convert alist to hash table for JSON serialization.

   Args:
     alist: Alist with keyword keys

   Returns:
     Hash table"
  (let ((hash (make-hash-table :test 'equal)))
    (dolist (pair alist hash)
      (let ((key (string-downcase (string (car pair))))
            (value (cdr pair)))
        (when value
          (setf (gethash key hash) value))))))

;;; ### Bot Information Methods

(defun get-me (bot)
  "Get information about the bot.

   Args:
     bot: Bot config struct

   Returns:
     Bot user object on success

   Example:
     (let ((user (get-me *bot*)))
       (format t \"Bot name: ~A\" (getf user :username)))"
  (multiple-value-bind (result error)
      (bot-request bot "getMe")
    (declare (ignore error))
    (json-to-plist result)))

(defun get-my-name (bot)
  "Get the current bot name.

   Args:
     bot: Bot config struct

   Returns:
     Name string or nil"
  (multiple-value-bind (result error)
      (bot-request bot "getMyName")
    (declare (ignore error))
    (when result
      (gethash "name" result))))

(defun get-my-description (bot)
  "Get the current bot description.

   Args:
     bot: Bot config struct

   Returns:
     Description string or nil"
  (multiple-value-bind (result error)
      (bot-request bot "getMyDescription")
    (declare (ignore error))
    (when result
      (gethash "description" result))))

(defun get-my-short-description (bot)
  "Get the current bot short description.

   Args:
     bot: Bot config struct

   Returns:
     Short description string or nil"
  (multiple-value-bind (result error)
      (bot-request bot "getMyShortDescription")
    (declare (ignore error))
    (when result
      (gethash "short_description" result))))

;;; ### Message Sending Methods

(defun bot-send-message (bot chat-id text &key parse-mode entities reply-markup disable-notification)
  "Send a text message.

   Args:
     bot: Bot config struct
     chat-id: Unique identifier for the target chat
     text: Text of the message (1-4096 characters)
     parse-mode: Optional parsing mode (:markdown, :markdownv2, :html)
     entities: Optional list of message entities
     reply-markup: Optional reply keyboard/markup
     disable-notification: True to send silently

   Returns:
     Message object on success, error description on failure

   Example:
     (bot-send-message *bot* 123456 \"Hello, World!\"
                       :parse-mode :html)"
  (let ((params `((:chat-id . ,chat-id)
                  (:text . ,text)
                  ,@(when parse-mode `((:parse-mode . ,(string-downcase parse-mode))))
                  ,@(when entities `((:entities . ,entities)))
                  ,@(when reply-markup `((:reply_markup . ,reply-markup)))
                  ,@(when disable-notification `((:disable_notification . ,disable-notification))))))
    (multiple-value-bind (result error)
        (bot-request bot "sendMessage" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-send-photo (bot chat-id photo &key caption parse-mode caption-entities has-spoiler disable-notification reply-markup)
  "Send a photo.

   Args:
     bot: Bot config struct
     chat-id: Target chat ID
     photo: File ID to send or file path (starts with /)
     caption: Optional photo caption
     parse-mode: Caption parsing mode
     has-spoiler: True to show spoiler animation
     disable-notification: True for silent send
     reply-markup: Optional markup

   Returns:
     Message object on success"
  (let ((params `((:chat-id . ,chat-id)
                  ,@(if (and (stringp photo) (char= (char photo 0) #\/))
                        `((:photo . (:type \"input_file\" :path ,photo)))
                        `((:photo . ,photo)))
                  ,@(when caption `((:caption . ,caption)))
                  ,@(when parse-mode `((:parse_mode . ,(string-downcase parse-mode))))
                  ,@(when has-spoiler `((:has_spoiler . ,has-spoiler)))
                  ,@(when disable-notification `((:disable_notification . ,disable-notification)))
                  ,@(when reply-markup `((:reply_markup . ,reply-markup))))))
    (multiple-value-bind (result error)
        (bot-request bot "sendPhoto" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-send-document (bot chat-id document &key caption parse-mode disable-notification reply-markup)
  "Send a document.

   Args:
     bot: Bot config struct
     chat-id: Target chat ID
     document: File ID or file path
     caption: Optional caption
     parse-mode: Caption parsing mode
     disable-notification: True for silent send
     reply-markup: Optional markup

   Returns:
     Message object on success"
  (let ((params `((:chat-id . ,chat-id)
                  ,@(if (and (stringp document) (char= (char document 0) #\/))
                        `((:document . (:type \"input_file\" :path ,document)))
                        `((:document . ,document)))
                  ,@(when caption `((:caption . ,caption)))
                  ,@(when parse-mode `((:parse_mode . ,(string-downcase parse-mode))))
                  ,@(when disable-notification `((:disable_notification . ,disable-notification)))
                  ,@(when reply-markup `((:reply_markup . ,reply-markup))))))
    (multiple-value-bind (result error)
        (bot-request bot "sendDocument" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-send-sticker (bot chat-id sticker &key emoji disable-notification reply-markup)
  "Send a sticker.

   Args:
     bot: Bot config struct
     chat-id: Target chat ID
     sticker: File ID of sticker
     emoji: Optional emoji associated with sticker
     disable-notification: True for silent send
     reply-markup: Optional markup

   Returns:
     Message object on success"
  (let ((params `((:chat-id . ,chat-id)
                  (:sticker . ,sticker)
                  ,@(when emoji `((:emoji . ,emoji)))
                  ,@(when disable-notification `((:disable_notification . ,disable-notification)))
                  ,@(when reply-markup `((:reply_markup . ,reply-markup))))))
    (multiple-value-bind (result error)
        (bot-request bot "sendSticker" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-send-location (bot chat-id latitude longitude &key horizontal-accuracy live-period heading heading-speed disable-notification reply-markup)
  "Send a location.

   Args:
     bot: Bot config struct
     chat-id: Target chat ID
     latitude: Latitude in degrees
     longitude: Longitude in degrees
     horizontal-accuracy: Optional accuracy radius in meters
     live-period: Optional period for live location
     heading: Optional direction of movement
     disable-notification: True for silent send

   Returns:
     Message object on success"
  (let ((params `((:chat-id . ,chat-id)
                  (:latitude . ,latitude)
                  (:longitude . ,longitude)
                  ,@(when horizontal-accuracy `((:horizontal_accuracy . ,horizontal-accuracy)))
                  ,@(when live-period `((:live_period . ,live-period)))
                  ,@(when disable-notification `((:disable_notification . ,disable-notification)))
                  ,@(when reply-markup `((:reply_markup . ,reply-markup))))))
    (multiple-value-bind (result error)
        (bot-request bot "sendLocation" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-send-chat-action (bot chat-id action)
  "Send a chat action (typing indicator).

   Args:
     bot: Bot config struct
     chat-id: Target chat ID
     action: Action type (:typing, :upload_photo, :record_video, :upload_video,
              :record_voice, :upload_voice, :upload_document, :choose_sticker,
              :find_location, :record_video_note, :upload_video_note)

   Returns:
     T on success

   Example:
     (bot-send-chat-action *bot* 123456 :typing)"
  (let ((action-map '(:typing "typing")
                    (:upload-photo "upload_photo")
                    (:record-video "record_video")
                    (:upload-video "upload_video")
                    (:record-voice "record_voice")
                    (:upload-voice "upload_voice")
                    (:upload-document "upload_document")
                    (:choose-sticker "choose_sticker")
                    (:find-location "find_location")
                    (:record-video-note "record_video_note")
                    (:upload-video-note "upload_video_note")))
    (let ((action-string (or (cdr (find action action-map :key #'car)) "typing")))
      (let ((params `((:chat-id . ,chat-id)
                      (:action . ,action-string))))
        (multiple-value-bind (result error)
            (bot-request bot "sendChatAction" :params params)
          (if result t (values nil error)))))))

(defun bot-edit-message-text (bot chat-id message-id text &key parse-mode entities reply-markup)
  "Edit text of a message.

   Args:
     bot: Bot config struct
     chat-id: Target chat ID
     message-id: ID of message to edit
     text: New text
     parse-mode: Optional parsing mode
     reply-markup: Optional new markup

   Returns:
     Message object on success"
  (let ((params `((:chat-id . ,chat-id)
                  (:message_id . ,message-id)
                  (:text . ,text)
                  ,@(when parse-mode `((:parse_mode . ,(string-downcase parse-mode))))
                  ,@(when reply-markup `((:reply_markup . ,reply-markup))))))
    (multiple-value-bind (result error)
        (bot-request bot "editMessageText" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-delete-message (bot chat-id message-id)
  "Delete a message.

   Args:
     bot: Bot config struct
     chat-id: Target chat ID
     message-id: ID of message to delete

   Returns:
     T on success"
  (let ((params `((:chat-id . ,chat-id)
                  (:message_id . ,message-id))))
    (multiple-value-bind (result error)
        (bot-request bot "deleteMessage" :params params)
      (if result t (values nil error)))))

;;; ### Update Retrieval (Long Polling)

(defun get-updates (bot &key offset limit timeout allowed-updates)
  "Get updates using long polling.

   Args:
     bot: Bot config struct
     offset: Identifier of first update to get (default: 0)
     limit: Maximum number of updates (1-100, default: 100)
     timeout: Timeout in seconds (default: bot timeout)
     allowed-updates: List of update types to receive

   Returns:
     List of update objects

   Example:
     (loop
       (let ((updates (get-updates *bot* :offset *last-update-id*)))
         (dolist (update updates)
           (process-update update))
         (when updates
           (setf *last-update-id*
                 (getf (car (last updates)) :update-id)))))"
  (let ((params `((:offset . ,(or offset 0))
                  (:limit . ,(or limit 100))
                  ,@(when timeout `((:timeout . ,timeout)))
                  ,@(when allowed-updates `((:allowed_updates . ,allowed-updates))))))
    (multiple-value-bind (result error)
        (bot-request bot "getUpdates" :params params)
      (if result
          (mapcar #'json-to-plist result)
          (values nil error)))))

(defun set-webhook (bot url &key certificate ip-address max-connections allowed-updates drop-pending-updates secret-token)
  "Set a webhook for receiving updates.

   Args:
     bot: Bot config struct
     url: HTTPS URL for webhook
     certificate: Optional public key certificate
     max-connections: Optional maximum connections (default: 40)
     allowed-updates: Optional list of update types
     drop-pending-updates: True to drop pending updates

   Returns:
     T on success"
  (let ((params `((:url . ,url)
                  ,@(when certificate `((:certificate . ,certificate)))
                  ,@(when max-connections `((:max_connections . ,max-connections)))
                  ,@(when allowed-updates `((:allowed_updates . ,allowed-updates)))
                  ,@(when drop-pending-updates `((:drop_pending_updates . ,drop-pending-updates)))
                  ,@(when secret-token `((:secret_token . ,secret-token))))))
    (multiple-value-bind (result error)
        (bot-request bot "setWebhook" :params params)
      (if result t (values nil error)))))

(defun delete-webhook (bot &key drop-pending-updates)
  "Remove webhook.

   Args:
     bot: Bot config struct
     drop-pending-updates: True to drop pending updates

   Returns:
     T on success"
  (let ((params (when drop-pending-updates
                  `((:drop_pending_updates . ,drop-pending-updates)))))
    (multiple-value-bind (result error)
        (bot-request bot "deleteWebhook" :params params)
      (if result t (values nil error)))))

(defun get-webhook-info (bot)
  "Get webhook status information.

   Args:
     bot: Bot config struct

   Returns:
     Webhook info object"
  (multiple-value-bind (result error)
      (bot-request bot "getWebhookInfo")
    (declare (ignore error))
    (when result
      (json-to-plist result))))

;;; ### Chat Methods

(defun bot-get-chat (bot chat-id)
  "Get information about a chat.

   Args:
     bot: Bot config struct
     chat-id: Unique identifier of the chat

   Returns:
     Chat object"
  (let ((params `((:chat-id . ,chat-id))))
    (multiple-value-bind (result error)
        (bot-request bot "getChat" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-get-chat-member (bot chat-id user-id)
  "Get information about a chat member.

   Args:
     bot: Bot config struct
     chat-id: Chat identifier
     user-id: User identifier

   Returns:
     ChatMember object"
  (let ((params `((:chat-id . ,chat-id)
                  (:user_id . ,user-id))))
    (multiple-value-bind (result error)
        (bot-request bot "getChatMember" :params params)
      (if result
          (json-to-plist result)
          (values nil error)))))

(defun bot-get-chat-administrators (bot chat-id)
  "Get list of administrators in a chat.

   Args:
     bot: Bot config struct
     chat-id: Chat identifier

   Returns:
     List of ChatMember objects"
  (let ((params `((:chat-id . ,chat-id))))
    (multiple-value-bind (result error)
        (bot-request bot "getChatAdministrators" :params params)
      (if result
          (mapcar #'json-to-plist result)
          (values nil error)))))

(defun bot-ban-chat-member (bot chat-id user-id &key until-date revoke-messages)
  "Ban a user in a chat.

   Args:
     bot: Bot config struct
     chat-id: Chat identifier
     user-id: User identifier to ban
     until-date: Optional unban date (Unix timestamp)
     revoke-messages: True to revoke all messages

   Returns:
     T on success"
  (let ((params `((:chat-id . ,chat-id)
                  (:user_id . ,user-id)
                  ,@(when until-date `((:until_date . ,until-date)))
                  ,@(when revoke-messages `((:revoke_messages . ,revoke-messages))))))
    (multiple-value-bind (result error)
        (bot-request bot "banChatMember" :params params)
      (if result t (values nil error)))))

(defun bot-unban-chat-member (bot chat-id user-id &key only-if-banned)
  "Unban a user in a chat.

   Args:
     bot: Bot config struct
     chat-id: Chat identifier
     user-id: User identifier to unban

   Returns:
     T on success"
  (let ((params `((:chat-id . ,chat-id)
                  (:user_id . ,user-id)
                  ,@(when only-if-banned `((:only_if_banned . ,only-if-banned))))))
    (multiple-value-bind (result error)
        (bot-request bot "unbanChatMember" :params params)
      (if result t (values nil error)))))

(defun bot-restrict-chat-member (bot chat-id user-id &key permissions until-date)
  "Restrict a chat member.

   Args:
     bot: Bot config struct
     chat-id: Chat identifier
     user-id: User identifier
     permissions: New permissions (ChatPermissions object)
     until-date: Optional restriction end date

   Returns:
     T on success"
  (let ((params `((:chat-id . ,chat-id)
                  (:user_id . ,user-id)
                  ,@(when permissions `((:permissions . ,permissions)))
                  ,@(when until-date `((:until_date . ,until-date))))))
    (multiple-value-bind (result error)
        (bot-request bot "restrictChatMember" :params params)
      (if result t (values nil error)))))

;;; ### Utility Functions

(defun json-to-plist (json)
  "Convert JSON hash table to plist.

   Args:
     json: Hash table from jonathan:from-json

   Returns:
     Property list with keyword keys"
  (when (typep json 'hash-table)
    (let ((result nil))
      (maphash (lambda (key value)
                 (push (keywordify key) result)
                 (push (if (typep value 'hash-table)
                           (json-to-plist value)
                           value)
                       result))
               json)
      (nreverse result))))

(defun keywordify (string)
  "Convert string to keyword.

   Args:
     string: String to convert

   Returns:
     Keyword symbol"
  (intern (string-upcase (substitute-if #\- (lambda (c) (member c '(#\\= #\\-)))) string)))
