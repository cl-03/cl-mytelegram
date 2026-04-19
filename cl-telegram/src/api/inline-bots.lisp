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
  (declare (ignorable query-id results cache-time is-personal next-offset switch-pm-text switch-pm-parameter))
  ;; TODO: Implement API call
  t)

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
  (declare (ignorable callback-query-id text show-alert url cache-time))
  ;; TODO: Implement API call
  t)

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
  (declare (ignorable id latitude longitude title horizontal-accuracy))
  ;; TODO: Implement location result
  nil)

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
  (declare (ignorable id latitude longitude title address foursquare-id foursquare-type))
  ;; TODO: Implement venue result
  nil)

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
  (declare (ignorable id phone-number first-name last-name vcard))
  ;; TODO: Implement contact result
  nil)

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
  (declare (ignorable bot-token inline-message-id data button-id))
  ;; TODO: Implement API call
  t)

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
