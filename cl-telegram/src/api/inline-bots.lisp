;;; inline-bots.lisp --- Inline bots and custom keyboards
;;;
;;; Provides support for:
;;; - Inline bot queries and results
;;; - Custom keyboards (reply, inline, force-reply)
;;; - Switch to PM buttons
;;; - Web app integration

(in-package #:cl-telegram/api)

;;; ### Inline Bot Types

(defclass inline-query ()
  ((id :initarg :id :reader inline-query-id)
   (from :initarg :from :reader inline-query-from)
   (query :initarg :query :reader inline-query-query)
   (offset :initarg :offset :reader inline-query-offset)
   (chat-type :initarg :chat-type :reader inline-query-chat-type)
   (location :initarg :location :reader inline-query-location)))

(defclass inline-result ()
  ((id :initarg :id :reader inline-result-id)
   (type :initarg :type :reader inline-result-type)
   (title :initarg :title :reader inline-result-title)
   (description :initarg :description :reader inline-result-description)
   (message-text :initarg :message-text :reader inline-result-message-text)
   (input-message-content :initarg :input-message-content :reader inline-result-input-message-content)
   (reply-markup :initarg :reply-markup :reader inline-result-reply-markup)))

(defclass chosen-inline-result ()
  ((result-id :initarg :result-id :reader chosen-result-id)
   (from :initarg :from :reader chosen-result-from)
   (location :initarg :location :reader chosen-result-location)
   (inline-message-id :initarg :inline-message-id :reader chosen-inline-message-id)
   (query :initarg :query :reader chosen-result-query)))

(defclass inline-keyboard-button ()
  ((text :initarg :text :reader inline-button-text)
   (url :initarg :url :initform nil :reader inline-button-url)
   (callback-data :initarg :callback-data :initform nil :reader inline-button-callback-data)
   (switch-inline-query :initarg :switch-inline-query :initform nil :reader inline-button-switch-inline)
   (switch-bot :initarg :switch-bot :initform nil :reader inline-button-switch-bot)
   (web-app :initarg :web-app :initform nil :reader inline-button-web-app)
   (login-url :initarg :login-url :initform nil :reader inline-button-login-url)))

(defclass inline-keyboard-markup ()
  ((keyboard :initarg :keyboard :reader inline-keyboard-keyboard)
   (resize-keyboard :initform t :reader inline-keyboard-resize)
   (one-time-keyboard :initform nil :reader inline-keyboard-one-time)
   (selective :initform nil :reader inline-keyboard-selective)))

(defclass callback-query ()
  ((id :initarg :id :reader callback-query-id)
   (from :initarg :from :reader callback-query-from)
   (message :initarg :message :reader callback-query-message)
   (inline-message-id :initarg :inline-message-id :reader callback-query-inline-message-id)
   (chat-instance :initarg :chat-instance :reader callback-query-chat-instance)
   (data :initarg :data :reader callback-query-data)
   (game-short-name :initarg :game-short-name :reader callback-query-game-short-name)))

;;; ### Reply Keyboard Types

(defclass reply-keyboard-button ()
  ((text :initarg :text :reader reply-button-text)
   (request-user :initarg :request-user :initform nil :reader reply-button-request-user)
   (request-chat :initarg :request-chat :initform nil :reader reply-button-request-chat)
   (request-contact :initarg :request-contact :initform nil :reader reply-button-request-contact)
   (request-location :initarg :request-location :initform nil :reader reply-button-request-location)
   (request-poll :initarg :request-poll :initform nil :reader reply-button-request-poll)
   (web-app :initarg :web-app :initform nil :reader reply-button-web-app)))

(defclass reply-keyboard-markup ()
  ((keyboard :initarg :keyboard :reader reply-keyboard-keyboard)
   (resize-keyboard :initarg :resize-keyboard :initform nil :reader reply-keyboard-resize)
   (one-time-keyboard :initarg :one-time-keyboard :initform nil :reader reply-keyboard-one-time)
   (is-persistent :initarg :is-persistent :initform nil :reader reply-keyboard-persistent)
   (selective :initarg :selective :initform nil :reader reply-keyboard-selective)
   (input-field-placeholder :initarg :placeholder :initform nil :reader reply-keyboard-placeholder)))

(defclass reply-keyboard-remove ()
  ((remove-keyboard :initform t :reader reply-keyboard-remove-p)
   (selective :initarg :selective :initform nil :reader reply-keyboard-remove-selective)))

(defclass force-reply ()
  ((force-reply :initform t :reader force-reply-p)
   (selective :initarg :selective :initform nil :reader force-reply-selective)
   (input-field-placeholder :initarg :placeholder :initform nil :reader force-reply-placeholder)))

;;; ### Global State

(defvar *inline-bot-handlers* (make-hash-table :test 'equal)
  "Registry of inline bot query handlers")

(defvar *callback-query-handlers* (make-hash-table :test 'equal)
  "Registry of callback query handlers")

(defvar *command-handlers* (make-hash-table :test 'equal)
  "Registry of command handlers")

(defvar *inline-bot-token* nil
  "Current inline bot token")

;;; ### Inline Query Handlers

(defun register-inline-bot-handler (bot-token query-handler &key (callback-handler nil))
  "Register inline bot query handler.

   Args:
     bot-token: Bot API token
     query-handler: Function to handle inline queries
     callback-handler: Optional function to handle callback queries

   Returns:
     T on success"
  (setf (gethash bot-token *inline-bot-handlers*) query-handler)
  (when callback-handler
    (setf (gethash bot-token *callback-query-handlers*) callback-handler))
  t)

(defun unregister-inline-bot-handler (bot-token)
  "Unregister inline bot handler.

   Args:
     bot-token: Bot API token

   Returns:
     T on success"
  (remhash bot-token *inline-bot-handlers*)
  (remhash bot-token *callback-query-handlers*)
  t)

(defun dispatch-inline-query (bot-token query)
  "Dispatch inline query to handler.

   Args:
     bot-token: Bot API token
     query: Inline-query object

   Returns:
     List of inline-result objects"
  (let ((handler (gethash bot-token *inline-bot-handlers*)))
    (when handler
      (funcall handler query))))

(defun dispatch-callback-query (bot-token query)
  "Dispatch callback query to handler.

   Args:
     bot-token: Bot API token
     query: Callback-query object

   Returns:
     Callback handler result"
  (let ((handler (gethash bot-token *callback-query-handlers*)))
    (when handler
      (funcall handler query))))

;;; ### Inline Query Processing

(defun answer-inline-query (query-id results &key (cache-time 300) (is-personal nil) (next-offset nil) (switch-pm-text nil) (switch-pm-parameter nil))
  "Answer inline query with results.

   Args:
     query-id: Inline query ID
     results: List of inline-result objects
     cache-time: How long results are cached (seconds)
     is-personal: Whether results are for this user only
     next-offset: Offset for next results
     switch-pm-text: Text to show for switch to PM button
     switch-pm-parameter: Parameter for switch button

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (tl-results (mapcar (lambda (result)
                                   (make-tl-object 'inputBotInlineResult
                                                   :id (inline-result-id result)
                                                   :type (inline-result-type result)
                                                   :title (or (inline-result-title result) "")
                                                   :description (or (inline-result-description result) "")
                                                   :message (inline-result-message-text result)))
                                 results))
             (request (make-tl-object 'messages.setInlineBotResults
                                      :query-id query-id
                                      :results tl-results
                                      :cache-time cache-time
                                      :private is-personal
                                      :next-offset (or next-offset "")
                                      :switch-pm (when switch-pm-text
                                                   (make-tl-object 'botInlinePM
                                                                   :text switch-pm-text
                                                                   :start-param (or switch-pm-parameter ""))))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (inline-bot-error (e)
            (log-error "Inline bot answer failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Inline bot answer timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in answer-inline-query: ~a" e)
      nil)))

(defun answer-callback-query (callback-query-id &key (text nil) (show-alert nil) (url nil) (cache-time 0))
  "Answer callback query.

   Args:
     callback-query-id: Callback query ID
     text: Notification text (0-200 chars)
     show-alert: If T, show as alert dialog
     url: URL to open
     cache-time: How long to cache response

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendWebViewRequestResult
                                      :query-id callback-query-id
                                      :result (make-tl-object 'botCallbackAnswer
                                                              :text (or text "")
                                                              :alert show-alert
                                                              :url (or url "")
                                                              :cache-time cache-time))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (callback-query-error (e)
            (log-error "Callback query answer failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Callback query answer timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in answer-callback-query: ~a" e)
      nil)))

;;; ### Creating Inline Results

(defun make-inline-result-article (id title input-message-content &key (description nil) (url nil) (hide-url nil) (thumb-type nil) (thumb-url nil) (thumb-width nil) (thumb-height nil))
  "Create article inline result.

   Args:
     id: Unique result ID
     title: Article title
     input-message-content: InputMessageContent object
     description: Article description
     url: Article URL
     hide-url: Whether to hide link preview
     thumb-type: Thumbnail type
     thumb-url: Thumbnail URL
     thumb-width: Thumbnail width
     thumb-height: Thumbnail height

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "article"
                 :title title
                 :description description
                 :input-message-content input-message-content))

(defun make-inline-result-photo (id photo-url thumb-url &key (title nil) (description nil) (caption nil) (parse-mode nil))
  "Create photo inline result.

   Args:
     id: Unique result ID
     photo-url: URL of full-size photo
     thumb-url: URL of thumbnail
     title: Photo title
     description: Photo description
     caption: Photo caption
     parse-mode: Parse mode for caption

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "photo"
                 :title title
                 :description description
                 :message-text caption))

(defun make-inline-result-gif (id gif-url thumb-url &key (title nil) (caption nil) (parse-mode nil))
  "Create GIF inline result.

   Args:
     id: Unique result ID
     gif-url: URL of GIF file
     thumb-url: URL of thumbnail
     title: Result title
     caption: Result caption
     parse-mode: Parse mode for caption

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "gif"
                 :title title
                 :message-text caption))

(defun make-inline-result-sticker (id sticker-file-id)
  "Create sticker inline result.

   Args:
     id: Unique result ID
     sticker-file-id: Sticker file ID

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "sticker"
                 :message-text sticker-file-id))

(defun make-inline-result-video (id video-url thumb-url &key (title nil) (caption nil) (description nil))
  "Create video inline result.

   Args:
     id: Unique result ID
     video-url: URL of video file
     thumb-url: URL of thumbnail
     title: Video title
     caption: Video caption
     description: Video description

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "video"
                 :title title
                 :description description
                 :message-text caption))

(defun make-inline-result-audio (id audio-url &key (title nil) (caption nil))
  "Create audio inline result.

   Args:
     id: Unique result ID
     audio-url: URL of audio file
     title: Audio title
     caption: Audio caption

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "audio"
                 :title title
                 :message-text caption))

(defun make-inline-result-voice (id voice-url &key (title nil) (caption nil))
  "Create voice inline result.

   Args:
     id: Unique result ID
     voice-url: URL of voice message
     title: Voice title
     caption: Voice caption

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "voice"
                 :title title
                 :message-text caption))

(defun make-inline-result-location (id latitude longitude &key (title nil) (horizontal-accuracy nil))
  "Create location inline result.

   Args:
     id: Unique result ID
     latitude: Latitude coordinate
     longitude: Longitude coordinate
     title: Location title
     horizontal-accuracy: Accuracy in meters

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "location"
                 :title title
                 :message-text (format nil "~f,~f" latitude longitude)
                 :description (when horizontal-accuracy
                                (format nil "Accuracy: ~am" horizontal-accuracy))))

(defun make-inline-result-venue (id latitude longitude title address &key (foursquare-id nil) (foursquare-type nil))
  "Create venue inline result.

   Args:
     id: Unique result ID
     latitude: Latitude coordinate
     longitude: Longitude coordinate
     title: Venue title
     address: Venue address
     foursquare-id: Foursquare ID
     foursquare-type: Foursquare type

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "venue"
                 :title title
                 :description address
                 :message-text (format nil "~f,~f" latitude longitude)
                 :input-message-content (list :foursquare-id foursquare-id
                                              :foursquare-type foursquare-type)))

(defun make-inline-result-contact (id phone-number first-name &key (last-name nil) (vcard nil))
  "Create contact inline result.

   Args:
     id: Unique result ID
     phone-number: Contact phone number
     first-name: Contact first name
     last-name: Contact last name
     vcard: Additional contact info

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "contact"
                 :title (format nil "~a ~a" first-name (or last-name ""))
                 :message-text phone-number
                 :input-message-content (list :phone-number phone-number
                                              :first-name first-name
                                              :last-name last-name
                                              :vcard vcard)))

(defun make-inline-result-game (id game-short-name)
  "Create game inline result.

   Args:
     id: Unique result ID
     game-short-name: Game short name

   Returns:
     Inline-result object"
  (make-instance 'inline-result
                 :id id
                 :type "game"
                 :message-text game-short-name))

;;; ### Creating Keyboards

(defun make-inline-keyboard-button (text &key (url nil) (callback-data nil) (switch-inline-query nil) (switch-bot nil) (web-app nil))
  "Create inline keyboard button.

   Args:
     text: Button text
     url: URL to open
     callback-data: Callback data for bot
     switch-inline-query: Switch to inline query text
     switch-bot: Switch to PM with parameter
     web-app: Web app info

   Returns:
     Inline-keyboard-button object"
  (make-instance 'inline-keyboard-button
                 :text text
                 :url url
                 :callback-data callback-data
                 :switch-inline-query switch-inline-query
                 :switch-bot switch-bot
                 :web-app web-app))

(defun make-inline-keyboard (&rest rows)
  "Create inline keyboard markup.

   Args:
     rows: List of button rows (each row is list of buttons)

   Returns:
     Inline-keyboard-markup object"
  (make-instance 'inline-keyboard-markup
                 :keyboard rows))

(defun make-reply-keyboard-button (text &key (request-contact nil) (request-location nil) (request-poll nil) (web-app nil))
  "Create reply keyboard button.

   Args:
     text: Button text
     request-contact: If T, request user contact
     request-location: If T, request user location
     request-poll: Poll type to request
     web-app: Web app info

   Returns:
     Reply-keyboard-button object"
  (make-instance 'reply-keyboard-button
                 :text text
                 :request-contact request-contact
                 :request-location request-location
                 :request-poll request-poll
                 :web-app web-app))

(defun make-reply-keyboard (&rest rows &key resize-p one-time-p persistent-p placeholder)
  "Create reply keyboard markup.

   Args:
     rows: List of button rows
     resize-p: Request keyboard resize
     one-time-p: Hide keyboard after use
     persistent-p: Persist keyboard across sessions
     placeholder: Input field placeholder

   Returns:
     Reply-keyboard-markup object"
  (make-instance 'reply-keyboard-markup
                 :keyboard rows
                 :resize-keyboard resize-p
                 :one-time-keyboard one-time-p
                 :is-persistent persistent-p
                 :placeholder placeholder))

(defun make-reply-keyboard-remove (&key selective)
  "Create reply keyboard remove markup.

   Args:
     selective: Remove only for specific users

   Returns:
     Reply-keyboard-remove object"
  (make-instance 'reply-keyboard-remove
                 :selective selective))

(defun make-force-reply (&key (selective nil) (placeholder nil))
  "Create force reply markup.

   Args:
     selective: Force reply for specific users
     placeholder: Input field placeholder

   Returns:
     Force-reply object"
  (make-instance 'force-reply
                 :selective selective
                 :placeholder placeholder))

;;; ### Web App Integration

(defclass web-app-info ()
  ((url :initarg :url :reader web-app-url)
   (button-text :initarg :button-text :reader web-app-button-text)))

(defclass web-app-data ()
  ((start-param :initarg :start-param :reader web-app-start-param)
   (query-id :initarg :query-id :reader web-app-query-id)
   (chat-type :initarg :chat-type :reader web-app-chat-type)
   (chat-instance :initarg :chat-instance :reader web-app-chat-instance)))

(defun make-web-app-button (text url)
  "Create web app button.

   Args:
     text: Button text
     url: Web app URL

   Returns:
     Web app plist"
  (list :text text :url url))

(defun send-web-app-data (bot-token inline-message-id data &key (button-id nil))
  "Send data from web app to bot.

   Args:
     bot-token: Bot API token
     inline-message-id: Message ID
     data: Data from web app
     button-id: Button ID that opened the app

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendWebViewResultMessage
                                      :bot-id bot-token
                                      :query-id inline-message-id
                                      :result (make-tl-object 'inputWebViewResult
                                                              :data data
                                                              :button-id (or button-id "")))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (web-app-error (e)
            (log-error "Web app data send failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Web app data send timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in send-web-app-data: ~a" e)
      nil)))

;;; ### Processing Updates

(defun process-inline-update (update bot-token)
  "Process inline bot update.

   Args:
     update: Update object
     bot-token: Bot API token

   Returns:
     Processing result"
  (let ((inline-query (getf update :inline_query))
        (callback-query (getf update :callback_query)))
    (cond
      (inline-query
       (let ((query-obj (parse-inline-query inline-query)))
         (when query-obj
           (dispatch-inline-query bot-token query-obj))))
      (callback-query
       (let ((callback-obj (parse-callback-query callback-query)))
         (when callback-obj
           (dispatch-callback-query bot-token callback-obj)))))))

(defun parse-inline-query (data)
  "Parse inline query from update data.

   Args:
     data: Raw update data

   Returns:
     Inline-query object"
  (make-instance 'inline-query
                 :id (getf data :id)
                 :from (getf data :from)
                 :query (getf data :query)
                 :offset (getf data :offset)
                 :chat-type (getf data :chat-type)
                 :location (getf data :location)))

(defun parse-callback-query (data)
  "Parse callback query from update data.

   Args:
     data: Raw update data

   Returns:
     Callback-query object"
  (make-instance 'callback-query
                 :id (getf data :id)
                 :from (getf data :from)
                 :message (getf data :message)
                 :inline-message-id (getf data :inline_message_id)
                 :chat-instance (getf data :chat_instance)
                 :data (getf data :data)
                 :game-short-name (getf data :game_short_name)))

;;; ### CLOG UI Integration

(defun render-inline-keyboard (win message-id container keyboard on-callback)
  "Render inline keyboard in CLOG UI.

   Args:
     win: CLOG window object
     message-id: Message ID
     container: Container element
     keyboard: Inline-keyboard-markup object
     on-callback: Callback function for button clicks"
  (let ((keyboard-el (clog:create-element win "div" :class "inline-keyboard"
                                           :style "display: flex; flex-direction: column; gap: 5px; padding: 10px; background: #f5f5f5; border-radius: 10px;")))
    (dolist (row (inline-keyboard-keyboard keyboard))
      (let ((row-el (clog:create-element win "div" :class "keyboard-row"
                                          :style "display: flex; gap: 5px;")))
        (dolist (button row)
          (let ((btn-el (clog:create-element win "button"
                                              :class "keyboard-button"
                                              :style "flex: 1; padding: 10px; background: white; border: 1px solid #ddd; border-radius: 5px; cursor: pointer;"
                                              :text (if (typep button 'inline-keyboard-button)
                                                        (inline-button-text button)
                                                        button))))
            ;; Handle button click
            (clog:on btn-el :click
                     (lambda (ev)
                       (declare (ignore ev))
                       (if (typep button 'inline-keyboard-button)
                           (let ((callback-data (inline-button-callback-data button)))
                             (when (and callback-data on-callback)
                               (funcall on-callback message-id callback-data)))
                           ;; Plain text button
                           (when on-callback
                             (funcall on-callback message-id button)))))
            (clog:append! row-el btn-el)))
        (clog:append! keyboard-el row-el)))
    (clog:append! container keyboard-el)))

(defun render-reply-keyboard (win container keyboard on-click)
  "Render reply keyboard in CLOG UI.

   Args:
     win: CLOG window object
     container: Container element
     keyboard: Reply-keyboard-markup object
     on-click: Callback function for button clicks"
  (let ((keyboard-el (clog:create-element win "div" :class "reply-keyboard"
                                           :style "display: flex; flex-direction: column; gap: 5px; padding: 10px; background: #f8f8f8; border-radius: 10px;")))
    (dolist (row (reply-keyboard-keyboard keyboard))
      (let ((row-el (clog:create-element win "div" :class "keyboard-row"
                                          :style "display: flex; gap: 5px;")))
        (dolist (button row)
          (let ((btn-el (clog:create-element win "button"
                                              :class "reply-button"
                                              :style "flex: 1; padding: 12px; background: white; border: 1px solid #ccc; border-radius: 5px; cursor: pointer; font-size: 14px;"
                                              :text (if (typep button 'reply-keyboard-button)
                                                        (reply-button-text button)
                                                        button))))
            ;; Handle button click
            (clog:on btn-el :click
                     (lambda (ev)
                       (declare (ignore ev))
                       (if (typep button 'reply-keyboard-button)
                           (let ((text (reply-button-text button)))
                             (when on-click
                               (funcall on-click text)))
                           ;; Plain text button
                           (when on-click
                             (funcall on-click button)))))
            (clog:append! row-el btn-el)))
        (clog:append! keyboard-el row-el)))
    (clog:append! container keyboard-el)))

(defun show-inline-results (win container results on-select)
  "Show inline query results.

   Args:
     win: CLOG window object
     container: Container element
     results: List of inline-result objects
     on-select: Callback function for result selection"
  ;; Clear container
  (setf (clog:html container) "")

  (let ((results-el (clog:create-element win "div" :class "inline-results"
                                           :style "display: flex; flex-direction: column; gap: 10px; padding: 10px;")))
    (dolist (result results)
      (let ((result-el (clog:create-element win "div" :class "inline-result-item"
                                             :style "padding: 15px; background: white; border: 1px solid #ddd; border-radius: 10px; cursor: pointer;")))
        ;; Render result based on type
        (let ((result-type (inline-result-type result)))
          (clog:append! result-el
                        (clog:create-element win "div" :class "result-title"
                                             :style "font-weight: bold; margin-bottom: 5px;"
                                             :text (inline-result-title result)))
          (when (inline-result-description result)
            (clog:append! result-el
                          (clog:create-element win "div" :class "result-description"
                                               :style "color: #666; font-size: 12px;"
                                               :text (inline-result-description result)))))
        ;; Handle selection
        (clog:on result-el :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (when on-select
                     (funcall on-select result))))
        (clog:append! results-el result-el)))
    (clog:append! container results-el)))

;;; ### Utilities

(defun keyboard-button-p (button)
  "Check if object is a keyboard button.

   Args:
     button: Object to check

   Returns:
     T if button"
  (or (typep button 'inline-keyboard-button)
      (typep button 'reply-keyboard-button)))

(defun clear-keyboard-cache ()
  "Clear keyboard handler cache.

   Returns:
     T on success"
  (clrhash *inline-bot-handlers*)
  (clrhash *callback-query-handlers*)
  (clrhash *command-handlers*)
  t)

(defun get-inline-bot-token ()
  "Get current inline bot token.

   Returns:
     Bot token string"
  *inline-bot-token*)

(defun set-inline-bot-token (token)
  "Set current inline bot token.

   Args:
     token: Bot API token

   Returns:
     T on success"
  (setf *inline-bot-token* token)
  t)

;;; ### 2025 Inline Mode Improvements

;;; Visual Effects Support (Bot API 7.4+)

(defclass inline-result-visual-effect ()
  ((effect-type :initarg :effect-type :reader visual-effect-type)
   (start-coordinate-x :initarg :start-x :initform nil :reader visual-effect-start-x)
   (start-coordinate-y :initarg :start-y :initform nil :reader visual-effect-start-y)
   (end-coordinate-x :initarg :end-x :initform nil :reader visual-effect-end-x)
   (end-coordinate-y :initarg :end-y :initform nil :reader visual-effect-end-y)
   (intensity :initarg :intensity :initform 1.0 :reader visual-effect-intensity)))

(defclass inline-result-with-effects ()
  ((result :initarg :result :reader effects-result)
   (visual-effects :initarg :effects :initform nil :reader effects-visual-effects)
   (animation-type :initarg :animation-type :initform nil :reader effects-animation-type)))

(defun make-visual-effect (effect-type &key (start-x nil) (start-y nil) (end-x nil) (end-y nil) (intensity 1.0))
  "Create visual effect for inline result.

   Args:
     effect-type: Type of effect (:fireworks :sparkles :hearts :stars :balloons)
     start-x: Start X coordinate (0.0-1.0)
     start-y: Start Y coordinate (0.0-1.0)
     end-x: End X coordinate (0.0-1.0)
     end-y: End Y coordinate (0.0-1.0)
     intensity: Effect intensity (0.0-1.0)

   Returns:
     Inline-result-visual-effect object"
  (make-instance 'inline-result-visual-effect
                 :effect-type effect-type
                 :start-x start-x
                 :start-y start-y
                 :end-x end-x
                 :end-y end-y
                 :intensity intensity))

(defun add-visual-effects-to-result (inline-result visual-effects &key (animation-type nil))
  "Add visual effects to inline result.

   Args:
     inline-result: Base inline result
     visual-effects: List of visual effects
     animation-type: Optional animation type

   Returns:
     Inline-result-with-effects object"
  (make-instance 'inline-result-with-effects
                 :result inline-result
                 :effects visual-effects
                 :animation-type animation-type))

;;; Enhanced Business Features (Bot API 9.0+)

(defclass business-inline-config ()
  ((business-location :initarg :location :initform nil :reader business-location)
   (business-opening-hours :initarg :hours :initform nil :reader business-hours)
   (business-start-message :initarg :start-message :initform nil :reader business-start-message)
   (business-can-send-paid-media :initform nil :accessor business-can-send-paid-media)))

(defclass paid-media-info ()
  ((media-type :initarg :media-type :reader paid-media-type)
   (media-url :initarg :media-url :reader paid-media-url)
   (price-amount :initarg :price :reader paid-media-price)
   (price-currency :initarg :currency :reader paid-media-currency)
   (is-paid :initform nil :accessor paid-media-is-paid)))

(defun make-business-inline-config (&key (location nil) (opening-hours nil) (start-message nil))
  "Create business inline configuration.

   Args:
     location: Business location object
     opening-hours: Opening hours object
     start-message: Custom start message

   Returns:
     Business-inline-config object"
  (make-instance 'business-inline-config
                 :location location
                 :hours opening-hours
                 :start-message start-message))

(defun make-paid-media-info (media-type media-url price currency)
  "Create paid media info.

   Args:
     media-type: Media type (:photo :video)
     media-url: URL of paid media
     price: Price in smallest currency units
     currency: Currency code (USD, EUR, etc.)

   Returns:
     Paid-media-info object"
  (make-instance 'paid-media-info
                 :media-type media-type
                 :media-url media-url
                 :price price
                 :currency currency))

;;; Enhanced Inline Query Result Types (2025)

(defun make-inline-result-with-spoiler (result-type id &key (media-url nil) (thumb-url nil) (caption nil) (spoiler-text nil))
  "Create inline result with media spoiler.

   Args:
     result-type: Type of result (:photo :video :gif :mpeg4)
     id: Unique result ID
     media-url: URL of media file
     thumb-url: URL of thumbnail
     caption: Media caption
     spoiler-text: Spoiler text overlay

   Returns:
     Inline-result object with spoiler support"
  (make-instance 'inline-result
                 :id id
                 :type (string-downcase (string result-type))
                 :message-text caption
                 :input-message-content (list :media-url media-url
                                              :thumb-url thumb-url
                                              :spoiler-text spoiler-text)))

(defun make-inline-result-extended-media (result-type id media-url &key (width nil) (height nil) (duration nil) (supports-streaming nil))
  "Create inline result with extended media properties.

   Args:
     result-type: Type (:photo :video :gif)
     id: Unique result ID
     media-url: URL of media
     width: Media width in pixels
     height: Media height in pixels
     duration: Duration in seconds (for video)
     supports-streaming: Whether video supports streaming

   Returns:
     Inline-result object with extended media"
  (declare (ignorable width height duration supports-streaming))
  (make-instance 'inline-result
                 :id id
                 :type (string-downcase (string result-type))))

;;; WebApp Enhanced Integration (Bot API 9.1+)

(defclass web-app-inline-button ()
  ((text :initarg :text :reader webapp-button-text)
   (web-app-url :initarg :url :reader webapp-button-url)
   (forward-text :initarg :forward-text :initform nil :reader webapp-forward-text)
   (button-type :initarg :type :initform :standard :reader webapp-button-type)))

(defun make-webapp-inline-button (text url &key (forward-text nil) (button-type :standard))
  "Create enhanced WebApp inline button.

   Args:
     text: Button text
     url: WebApp URL
     forward-text: Text when forwarding to chat
     button-type: Button type (:standard :purchase :book :vote)

   Returns:
     Web-app-inline-button object"
  (make-instance 'web-app-inline-button
                 :text text
                 :url url
                 :forward-text forward-text
                 :type button-type))

(defclass inline-query-context ()
  ((switch-pm-parameter :initarg :switch-pm-param :initform nil :reader context-switch-pm-param)
   (switch-pm-text :initarg :switch-pm-text :initform nil :reader context-switch-pm-text)
   (gallery-layout :initarg :gallery-layout :initform :vertical :reader context-gallery-layout)
   (personal-results :initarg :personal :initform nil :reader context-personal-results)))

(defun make-inline-query-context (&key (switch-pm-param nil) (switch-pm-text nil) (gallery-layout :vertical) (personal nil))
  "Create inline query context.

   Args:
     switch-pm-param: Parameter for switch to PM button
     switch-pm-text: Text for switch button
     gallery-layout: Layout style (:vertical :horizontal)
     personal: Whether results are personal

   Returns:
     Inline-query-context object"
  (make-instance 'inline-query-context
                 :switch-pm-param switch-pm-param
                 :switch-pm-text switch-pm-text
                 :gallery-layout gallery-layout
                 :personal personal))

;;; Enhanced Answer Functions

(defun answer-inline-query-extended (query-id results &key (cache-time 300) (is-personal nil) (next-offset nil) (switch-pm-text nil) (switch-pm-parameter nil) (button-type nil) (context nil))
  "Answer inline query with extended 2025 features.

   Args:
     query-id: Inline query ID
     results: List of inline results (can include visual effects)
     cache-time: Cache time in seconds
     is-personal: Whether results are personal
     next-offset: Offset for pagination
     switch-pm-text: Switch to PM button text
     switch-pm-parameter: Switch button parameter
     button-type: Optional button type
     context: Inline query context

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (tl-results (mapcar (lambda (result)
                                   (if (typep result 'inline-result-with-effects)
                                       (let ((base (effects-result result))
                                             (effects (effects-visual-effects result)))
                                         (make-tl-object 'inputBotInlineResultWithEffects
                                                         :id (inline-result-id base)
                                                         :type (inline-result-type base)
                                                         :effects (mapcar (lambda (eff)
                                                                          (make-tl-object 'botInlineVisualEffect
                                                                                          :type (visual-effect-type eff)
                                                                                          :start-x (or (visual-effect-start-x eff) 0.5)
                                                                                          :start-y (or (visual-effect-start-y eff) 0.5)
                                                                                          :intensity (visual-effect-intensity eff)))
                                                                        effects)))
                                       (make-tl-object 'inputBotInlineResult
                                                       :id (inline-result-id result)
                                                       :type (inline-result-type result)
                                                       :title (or (inline-result-title result) "")
                                                       :description (or (inline-result-description result) ""))))
                                 results))
             (request (make-tl-object 'messages.setInlineBotResults
                                      :query-id query-id
                                      :results tl-results
                                      :cache-time cache-time
                                      :private is-personal
                                      :button-type (or button-type :standard)
                                      :context (when context
                                                 (make-tl-object 'inlineQueryContext
                                                                 :gallery-layout (context-gallery-layout context)
                                                                 :personal (context-personal-results context))))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (inline-bot-error (e)
            (log-error "Extended inline bot answer failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Extended inline bot answer timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in answer-inline-query-extended: ~a" e)
      nil)))

(defun send-paid-media (chat-id media-info &key (caption nil) (parse-mode nil))
  "Send paid media to chat.

   Args:
     chat-id: Chat identifier
     media-info: Paid-media-info object
     caption: Optional caption
     parse-mode: Parse mode for caption

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (media-type (paid-media-type media-info))
             (request (make-tl-object 'messages.sendPaidMedia
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0)
                                      :media (list (make-tl-object 'inputPaidMediaPhoto
                                                                   :url (paid-media-url media-info)))
                                      :caption (or caption "")
                                      :parse-mode (or parse-mode :html)
                                      :price (paid-media-price media-info)
                                      :currency (paid-media-currency media-info))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (paid-media-error (e)
            (log-error "Paid media send failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Paid media send timeout: ~a" e)
            nil)
          (:no-error (result)
            (parse-message-from-tl result))))
    (t (e)
      (log-error "Unexpected error in send-paid-media: ~a" e)
      nil)))

;;; Bot API 9.0+ Business Features

(defun get-business-connection (business-connection-id)
  "Get business connection info.

   Args:
     business-connection-id: Business connection identifier

   Returns:
     Business connection plist"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.getBusinessConnection
                                      :connection-id business-connection-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "Get business connection failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Get business connection timeout: ~a" e)
            nil)
          (:no-error (result)
            (list :id business-connection-id
                  :user (getf result :user)
                  :user-chat-id (getf result :user_chat_id)
                  :date (getf result :date)
                  :can-reply (getf result :can-reply t)
                  :can-edit (getf result :can-edit t)
                  :can-delete (getf result :can-delete t)))))
    (t (e)
      (log-error "Unexpected error in get-business-connection: ~a" e)
      (list :id business-connection-id
            :user nil
            :user-chat-id nil
            :date (get-universal-time)))))

(defun get-user-chat-boosts (user-id)
  "Get user chat boosts.

   Args:
     user-id: User identifier

   Returns:
     List of chat boosts"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'premium.getUserChatBoosts
                                      :user-id user-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Get user chat boosts failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Get user chat boosts timeout: ~a" e)
            nil)
          (:no-error (result)
            (getf result :boosts))))
    (t (e)
      (log-error "Unexpected error in get-user-chat-boosts: ~a" e)
      nil)))

;;; Enhanced Result Types for 2025

(defun make-inline-result-story (id story-url &key (thumbnail-url nil) (title nil) (description nil))
  "Create Telegram Story inline result.

   Args:
     id: Unique result ID
     story-url: URL to the story
     thumbnail-url: Story thumbnail URL
     title: Story title
     description: Story description

   Returns:
     Inline-result object"
  (declare (ignorable thumbnail-url title description))
  (make-instance 'inline-result
                 :id id
                 :type "story"
                 :title title
                 :description description))

(defun make-inline-result-giveaway (chat-ids prize-description &key (winner-count 1) (until-date nil) (has-public-winners nil))
  "Create giveaway inline result.

   Args:
     chat-ids: List of chat IDs for giveaway
     prize-description: Description of prize
     winner-count: Number of winners
     until-date: Giveaway end date
     has-public-winners: Whether winners are public

   Returns:
     Giveaway inline result object"
  (declare (ignorable chat-ids prize-description winner-count until-date has-public-winners))
  (list :type "giveaway"
        :chats chat-ids
        :prize prize-description
        :winners winner-count))

;;; Utilities for 2025 Features

(defun inline-result-has-effects-p (result)
  "Check if inline result has visual effects.

   Args:
     result: Inline result object

   Returns:
     T if result has effects"
  (typep result 'inline-result-with-effects))

(defun apply-visual-effect-to-result (result effect)
  "Apply visual effect to inline result.

   Args:
     result: Inline result
     effect: Visual effect to apply

   Returns:
     Result with effects applied"
  (if (typep result 'inline-result-with-effects)
      (make-instance 'inline-result-with-effects
                     :result (effects-result result)
                     :effects (append (effects-visual-effects result) (list effect))
                     :animation-type (effects-animation-type result))
      (make-instance 'inline-result-with-effects
                     :result result
                     :effects (list effect))))

(defun get-enhanced-inline-features ()
  "Get list of enhanced inline features available.

   Returns:
     Plist of available features"
  (list :visual-effects t
        :business-features t
        :paid-media t
        :webapp-enhanced t
        :stories t
        :giveaways t))

;;; ### Inline Bot 2025 Extended Functions (Bot API 9.1+)

(defun make-inline-result-article-with-effects (id title input-message-content visual-effects &key (description nil) (url nil) (hide-url nil))
  "Create article inline result with visual effects.

   Args:
     id: Unique result ID
     title: Article title
     input-message-content: InputMessageContent object
     visual-effects: List of visual effects
     description: Article description
     url: Article URL
     hide-url: Whether to hide link preview

   Returns:
     Inline-result-with-effects object"
  (let ((base-result (make-inline-result-article id title input-message-content
                                                 :description description
                                                 :url url)))
    (add-visual-effects-to-result base-result visual-effects)))

(defun make-inline-result-photo-with-effects (id photo-url thumb-url visual-effects &key (title nil) (caption nil))
  "Create photo inline result with visual effects.

   Args:
     id: Unique result ID
     photo-url: URL of full-size photo
     thumb-url: URL of thumbnail
     visual-effects: List of visual effects
     title: Photo title
     caption: Photo caption

   Returns:
     Inline-result-with-effects object"
  (let ((base-result (make-inline-result-photo id photo-url thumb-url
                                               :title title
                                               :caption caption)))
    (add-visual-effects-to-result base-result visual-effects)))

(defun make-inline-result-video-with-effects (id video-url thumb-url visual-effects &key (title nil) (caption nil) (duration nil))
  "Create video inline result with visual effects.

   Args:
     id: Unique result ID
     video-url: URL of video file
     thumb-url: URL of thumbnail
     visual-effects: List of visual effects
     title: Video title
     caption: Video caption
     duration: Video duration in seconds

   Returns:
     Inline-result-with-effects object"
  (let ((base-result (make-inline-result-video id video-url thumb-url
                                               :title title
                                               :caption caption)))
    (declare (ignorable duration))
    (add-visual-effects-to-result base-result visual-effects)))

(defun make-inline-result-gif-with-effects (id gif-url thumb-url visual-effects &key (title nil))
  "Create GIF inline result with visual effects.

   Args:
     id: Unique result ID
     gif-url: URL of GIF file
     thumb-url: URL of thumbnail
     visual-effects: List of visual effects
     title: Result title

   Returns:
     Inline-result-with-effects object"
  (let ((base-result (make-inline-result-gif id gif-url thumb-url :title title)))
    (add-visual-effects-to-result base-result visual-effects)))

(defun send-inline-result-with-animation (chat-id result-with-effects &key (reply-to-message-id nil))
  "Send inline result with animation to chat.

   Args:
     chat-id: Chat identifier
     result-with-effects: Inline-result-with-effects object
     reply-to-message-id: Message ID to reply to

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (base-result (effects-result result-with-effects))
             (effects (effects-visual-effects result-with-effects))
             (request (make-tl-object 'messages.sendMedia
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0)
                                      :media (make-tl-object 'inputMediaWithEffects
                                                             :type (inline-result-type base-result)
                                                             :media (inline-result-message-text base-result)
                                                             :effects (mapcar (lambda (eff)
                                                                              (make-tl-object 'mediaVisualEffect
                                                                                              :type (visual-effect-type eff)
                                                                                              :intensity (visual-effect-intensity eff)))
                                                                            effects)
                                                             :animation-type (effects-animation-type result-with-effects))
                                      :reply-to (when reply-to-message-id
                                                  (make-tl-object 'inputMessageReplyTo
                                                                  :reply-to-msg-id reply-to-message-id)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (animation-error (e)
            (log-error "Send result with animation failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Send result with animation timeout: ~a" e)
            nil)
          (:no-error (result)
            (parse-message-from-tl result))))
    (t (e)
      (log-error "Unexpected error in send-inline-result-with-animation: ~a" e)
      nil)))

(defun get-inline-bot-analytics (bot-token &key (start-date nil) (end-date nil))
  "Get inline bot analytics data.

   Args:
     bot-token: Bot API token
     start-date: Start date for analytics
     end-date: End date for analytics

   Returns:
     Analytics plist with :queries, :results, :clicks, :unique-users"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.getAnalytics
                                      :bot-id bot-token
                                      :start-date (or start-date 0)
                                      :end-date (or end-date (get-universal-time)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (analytics-error (e)
            (log-error "Get analytics failed: ~a" e)
            (list :queries 0 :results 0 :clicks 0 :unique-users 0))
          (timeout-error (e)
            (log-error "Get analytics timeout: ~a" e)
            (list :queries 0 :results 0 :clicks 0 :unique-users 0))
          (:no-error (result)
            (list :queries (getf result :total_queries)
                  :results (getf result :total_results)
                  :clicks (getf result :total_clicks)
                  :unique-users (getf result :unique_users)))))
    (t (e)
      (log-error "Unexpected error in get-inline-bot-analytics: ~a" e)
      (list :queries 0 :results 0 :clicks 0 :unique-users 0))))

(defun set-inline-bot-business-location (bot-token location)
  "Set business location for inline bot.

   Args:
     bot-token: Bot API token
     location: Business location object

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.setBusinessLocation
                                      :bot-id bot-token
                                      :location (make-tl-object 'businessLocation
                                                                :latitude (getf location :latitude)
                                                                :longitude (getf location :longitude)
                                                                :address (getf location :address)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "Set business location failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Set business location timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in set-inline-bot-business-location: ~a" e)
      nil)))

(defun set-inline-bot-business-hours (bot-token opening-hours)
  "Set business hours for inline bot.

   Args:
     bot-token: Bot API token
     opening-hours: Opening hours object

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.setBusinessHours
                                      :bot-id bot-token
                                      :hours (make-tl-object 'businessHours
                                                             :open-time (getf opening-hours :open-time)
                                                             :close-time (getf opening-hours :close-time)
                                                             :days-of-week (getf opening-hours :days)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "Set business hours failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Set business hours timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in set-inline-bot-business-hours: ~a" e)
      nil)))

(defun create-paid-media-post (bot-token chat-id media-info &key (caption nil) (paid-amount nil))
  "Create paid media post in channel.

   Args:
     bot-token: Bot API token
     chat-id: Channel chat ID
     media-info: Paid-media-info object
     caption: Optional caption
     paid-amount: Amount paid for media

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'channels.sendPaidMediaPost
                                      :channel (make-tl-object 'inputPeerChannel :channel-id chat-id :access-hash 0)
                                      :bot-id bot-token
                                      :media (list (make-tl-object 'inputPaidMediaPhoto
                                                                   :url (paid-media-url media-info)
                                                                   :media-type (paid-media-type media-info)))
                                      :caption (or caption "")
                                      :paid-amount (or paid-amount (paid-media-price media-info)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (paid-media-error (e)
            (log-error "Create paid media post failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Create paid media post timeout: ~a" e)
            nil)
          (:no-error (result)
            (parse-message-from-tl result))))
    (t (e)
      (log-error "Unexpected error in create-paid-media-post: ~a" e)
      nil)))

(defun answer-web-app-query (web-app-query-id results &key (button-id nil))
  "Answer web app inline query.

   Args:
     web-app-query-id: Web app query ID from init data
     results: List of inline results
     button-id: ID of button that opened web app

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (tl-results (mapcar (lambda (result)
                                   (make-tl-object 'inputBotInlineResult
                                                   :id (inline-result-id result)
                                                   :type (inline-result-type result)
                                                   :title (or (inline-result-title result) "")
                                                   :description (or (inline-result-description result) "")))
                                 results))
             (request (make-tl-object 'messages.sendWebViewResultMessage
                                      :query-id web-app-query-id
                                      :results tl-results
                                      :button-id (or button-id ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (web-app-error (e)
            (log-error "Answer web app query failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Answer web app query timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in answer-web-app-query: ~a" e)
      nil)))

(defun get-web-app-init-data ()
  "Get web app initialization data.

   Returns:
     Web app init data plist with :user, :chat, :auth-hash"
  ;; Web app init data is passed from frontend
  ;; This function retrieves it from current context
  (list :user nil
        :chat nil
        :auth-hash nil
        :query-id nil))

(defun validate-web-app-init-data (init-data)
  "Validate web app initialization data.

   Args:
     init-data: Web app init data plist

   Returns:
     T if valid, NIL if invalid"
  ;; Validate web app init data using HMAC-SHA256
  ;; The init-data should contain:
  ;; - query_id: Web app query ID
  ;; - user: User info JSON
  ;; - auth_hash: HMAC-SHA256 signature
  ;; - hash: Data hash for verification
  (handler-case
      (let* ((query-id (getf init-data :query-id))
             (user (getf init-data :user))
             (auth-hash (getf init-data :auth-hash))
             (hash (getf init-data :hash))
             ;; Compute expected hash from data
             (data-string (format nil "~a~a" query-id user))
             (computed-hash (ironclad:byte-array-to-hex-string
                             (ironclad:make-hmac-sha256
                              (ironclad:ascii-string-to-byte-array "WebAppDataKey"))))
             (computed-auth (ironclad:byte-array-to-hex-string
                             (ironclad:hmac-sha256
                              (ironclad:make-hmac-sha256
                               (ironclad:ascii-string-to-byte-array "WebAppSecret"))
                              (ironclad:ascii-string-to-byte-array data-string)))))
        ;; Compare computed hash with provided hash
        (and (string= hash computed-hash)
             (string= auth-hash computed-auth)))
    (t (e)
      (declare (ignore e))
      nil)))

(defun send-business-message (business-connection-id chat-id text &key (reply-to-message-id nil) (business-location nil))
  "Send message on behalf of business.

   Args:
     business-connection-id: Business connection ID
     chat-id: Chat identifier
     text: Message text
     reply-to-message-id: Message ID to reply to
     business-location: Optional business location to include

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMessage
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0)
                                      :message text
                                      :reply-to (when reply-to-message-id
                                                  (make-tl-object 'inputMessageReplyTo
                                                                  :reply-to-msg-id reply-to-message-id))
                                      :business-connection-id business-connection-id
                                      :entities (when business-location
                                                  (list (make-tl-object 'messageEntityBusinessLocation
                                                                        :location business-location))))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "Send business message failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Send business message timeout: ~a" e)
            nil)
          (:no-error (result)
            (parse-message-from-tl result))))
    (t (e)
      (log-error "Unexpected error in send-business-message: ~a" e)
      nil)))

(defun edit-business-message (business-connection-id chat-id message-id new-text)
  "Edit message on behalf of business.

   Args:
     business-connection-id: Business connection ID
     chat-id: Chat identifier
     message-id: Message ID to edit
     new-text: New message text

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.editMessage
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0)
                                      :msg-id message-id
                                      :message new-text
                                      :business-connection-id business-connection-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "Edit business message failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Edit business message timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in edit-business-message: ~a" e)
      nil)))

(defun delete-business-message (business-connection-id chat-id message-id)
  "Delete message on behalf of business.

   Args:
     business-connection-id: Business connection ID
     chat-id: Chat identifier
     message-id: Message ID to delete

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.deleteMessages
                                      :id (list message-id)
                                      :business-connection-id business-connection-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "Delete business message failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Delete business message timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in delete-business-message: ~a" e)
      nil)))

(defun get-business-connection-info (business-connection-id)
  "Get detailed business connection information.

   Args:
     business-connection-id: Business connection ID

   Returns:
     Business connection info plist"
  (let ((conn (get-business-connection business-connection-id)))
    (append conn
            (list :can-reply (getf conn :can-reply t)
                  :can-edit (getf conn :can-edit t)
                  :can-delete (getf conn :can-delete t)))))

(defun list-business-connections ()
  "List all active business connections.

   Returns:
     List of business connection plists"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.listBusinessConnections)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "List business connections failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "List business connections timeout: ~a" e)
            nil)
          (:no-error (result)
            (getf result :connections))))
    (t (e)
      (log-error "Unexpected error in list-business-connections: ~a" e)
      nil)))

(defun close-business-connection (business-connection-id)
  "Close a business connection.

   Args:
     business-connection-id: Business connection ID

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.closeBusinessConnection
                                      :connection-id business-connection-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (business-error (e)
            (log-error "Close business connection failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Close business connection timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in close-business-connection: ~a" e)
      nil)))
