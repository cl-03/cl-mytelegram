;;; emoji-customization.lisp --- Custom emoji, effects, and wallpaper customization
;;; Part of v0.21.0 - User Experience Enhancements

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Custom Emoji Classes
;;; ======================================================================

(defclass custom-emoji ()
  ((id :initarg :id :accessor custom-emoji-id
       :initform "" :documentation "Unique custom emoji identifier")
   (emoji :initarg :emoji :accessor custom-emoji-emoji
         :initform "" :documentation "Unicode emoji representation")
   (file-id :initarg :file-id :accessor custom-emoji-file-id
            :initform "" :documentation "File ID for animation")
   (file-unique-id :initarg :file-unique-id :accessor custom-emoji-file-unique-id
                   :initform "" :documentation "Unique file identifier")
   (needs-premium :initarg :needs-premium :accessor custom-emoji-needs-premium
                  :initform t :documentation "True if requires Premium")
   (is-animated :initarg :is-animated :accessor custom-emoji-is-animated
                :initform nil :documentation "True if animated")
   (is-video :initarg :is-video :accessor custom-emoji-is-video
             :initform nil :documentation "True if video emoji")))

(defclass emoji-category ()
  ((name :initarg :name :accessor emoji-category-name
         :initform "" :documentation "Category name")
  (emoji-list :initarg :emoji-list :accessor emoji-category-emoji-list
              :initform nil :documentation "List of custom-emoji objects")
  (is-premium :initarg :is-premium :accessor emoji-category-is-premium
              :initform nil :documentation "True if premium category")))

(defclass message-effect ()
  ((id :initarg :id :accessor message-effect-id
       :initform "" :documentation "Unique effect identifier")
   (effect-type :initarg :effect-type :accessor message-effect-type
                :initform :animation :documentation "Effect type: :animation, :sticker, :emoji")
   (animation :initarg :animation :accessor message-effect-animation
              :initform nil :documentation "Animation data")
   (emoji :initarg :emoji :accessor message-effect-emoji
          :initform nil :documentation "Associated emoji")))

(defclass chat-wallpaper ()
  ((id :initarg :id :accessor chat-wallpaper-id
       :initform 0 :documentation "Wallpaper identifier")
   (type :initarg :type :accessor chat-wallpaper-type
         :initform :solid :documentation "Type: :solid, :gradient, :image, :pattern")
   (document :initarg :document :accessor chat-wallpaper-document
             :initform nil :documentation "Document for custom wallpapers")
   (dark-theme-dimensions :initarg :dark-theme-dimensions
                          :accessor chat-wallpaper-dark-dimensions
                          :initform nil :documentation "Dark theme settings")
   (light-theme-dimensions :initarg :light-theme-dimensions
                           :accessor chat-wallpaper-light-dimensions
                           :initform nil :documentation "Light theme settings")))

(defclass chat-theme ()
  ((name :initarg :name :accessor chat-theme-name
         :initform "" :documentation "Theme name")
   (colors :initarg :colors :accessor chat-theme-colors
           :initform nil :documentation "Color scheme plist")
   (wallpaper :initarg :wallpaper :accessor chat-theme-wallpaper
              :initform nil :documentation "Default wallpaper")
   (is-premium :initarg :is-premium :accessor chat-theme-is-premium
               :initform nil :documentation "True if premium theme")))

;;; ======================================================================
;;; Custom Emoji Management
;;; ======================================================================

(defun get-custom-emoji-stickers (custom-emoji-ids)
  "Get custom emoji stickers by their IDs.

   CUSTOM-EMOJI-IDS: List of custom emoji identifiers

   Returns list of sticker objects on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("custom_emoji_ids" . ,(json:encode-to-string custom-emoji-ids)))))
        (let ((result (make-api-call connection "getCustomEmojiStickers" params)))
          (if result
              (gethash "stickers" result nil)
              nil)))
    (error (e)
      (log-message :error "Error getting custom emoji stickers: ~A" (princ-to-string e))
      nil)))

(defun get-emoji-categories (&key include-premium)
  "Get list of emoji categories.

   INCLUDE-PREMIUM: Include premium categories if T

   Returns list of emoji-category objects."
  (handler-case
      (let ((connection (get-current-connection)))
        (let ((result (make-api-call connection "getEmojiCategories" nil)))
          (if result
              (loop for cat-data across (gethash "categories" result)
                    when (or include-premium
                             (not (gethash "is_premium" cat-data)))
                    collect (make-instance 'emoji-category
                                           :name (gethash "name" cat-data "")
                                           :emoji-list (gethash "emojis" cat-data nil)
                                           :is-premium (gethash "is_premium" cat-data)))
              nil)))
    (error (e)
      (log-message :error "Error getting emoji categories: ~A" (princ-to-string e))
      nil)))

(defun search-custom-emoji (query &key limit category)
  "Search for custom emoji.

   QUERY: Search query string
   LIMIT: Maximum results to return
   CATEGORY: Optional category filter

   Returns list of custom-emoji objects."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("q" . ,query))))
        (when limit
          (push (cons "limit" limit) params))
        (when category
          (push (cons "category" category) params))

        (let ((result (make-api-call connection "searchCustomEmoji" params)))
          (if result
              (loop for emoji-data across (gethash "results" result)
                    collect (make-instance 'custom-emoji
                                           :id (gethash "id" emoji-data "")
                                           :emoji (gethash "emoji" emoji-data "")
                                           :file-id (gethash "file_id" emoji-data "")
                                           :needs-premium (gethash "needs_premium" emoji-data)))
              nil)))
    (error (e)
      (log-message :error "Error searching custom emoji: ~A" (princ-to-string e))
      nil)))

(defun get-premium-emojis (&key category)
  "Get premium-only custom emoji.

   CATEGORY: Optional category filter

   Returns list of premium custom-emoji objects."
  (search-custom-emoji "" :limit 100 :category category))

;;; ======================================================================
;; Message Effects
;;; ======================================================================

(defun get-available-message-effects (&key chat-type)
  "Get list of available message effects.

   CHAT-TYPE: Optional chat type filter (:private, :group, :channel)

   Returns list of message-effect objects."
  (handler-case
      (let ((connection (get-current-connection)))
        (let ((result (make-api-call connection "getAvailableMessageEffects" nil)))
          (if result
              (loop for effect-data across (gethash "effects" result)
                    collect (make-instance 'message-effect
                                           :id (gethash "id" effect-data "")
                                           :effect-type (gethash "type" effect-data :animation)
                                           :emoji (gethash "emoji" effect-data)))
              nil)))
    (error (e)
      (log-message :error "Error getting message effects: ~A" (princ-to-string e))
      nil)))

(defun send-message-with-effect (chat-id text &key message-effect-id reply-markup
                                                      disable-notification protect-content)
  "Send a message with a message effect.

   CHAT-ID: Target chat ID
   TEXT: Message text
   MESSAGE-EFFECT-ID: Effect identifier
   REPLY-MARKUP: Optional keyboard
   DISABLE-NOTIFICATION: Send silently if T
   PROTECT-CONTENT: Protect from forwarding if T

   Returns sent Message object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("text" . ,text))))
        (when message-effect-id
          (push (cons "message_effect_id" message-effect-id) params))
        (when reply-markup
          (push (cons "reply_markup" (json:encode-to-string reply-markup)) params))
        (when disable-notification
          (push (cons "disable_notification" "true") params))
        (when protect-content
          (push (cons "protect_content" "true") params))

        (let ((result (make-api-call connection "sendMessage" params)))
          (if result
              (progn
                (log-message :info "Message with effect sent to ~A" chat-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error sending message with effect: ~A" (princ-to-string e))
      nil)))

(defun send-dice (chat-id &key emoji message-thread-id disable-notification)
  "Send an animated dice emoji with random value.

   CHAT-ID: Target chat ID
   EMOJI: Dice emoji (default 🎲, also 🎯, 🏀, ⚽, 🎳, 🎰)
   MESSAGE-THREAD-ID: Optional thread ID for forums
   DISABLE-NOTIFICATION: Send silently if T

   Returns sent Message object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id))))
        (when emoji
          (push (cons "emoji" emoji) params))
        (when message-thread-id
          (push (cons "message_thread_id" message-thread-id) params))
        (when disable-notification
          (push (cons "disable_notification" "true") params))

        (let ((result (make-api-call connection "sendDice" params)))
          (if result
              (progn
                (log-message :info "Dice sent to ~A" chat-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error sending dice: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Chat Wallpaper Management
;;; ======================================================================

(defun get-wallpapers (&key include-premium)
  "Get available wallpapers.

   INCLUDE-PREMIUM: Include premium wallpapers if T

   Returns list of chat-wallpaper objects."
  (handler-case
      (let ((connection (get-current-connection)))
        (let ((result (make-api-call connection "getWallpapers" nil)))
          (if result
              (loop for wp-data across (gethash "wallpapers" result)
                    when (or include-premium
                             (not (gethash "is_premium" wp-data)))
                    collect (make-instance 'chat-wallpaper
                                           :id (gethash "id" wp-data 0)
                                           :type (gethash "type" wp-data :solid)
                                           :document (gethash "document" wp-data)))
              nil)))
    (error (e)
      (log-message :error "Error getting wallpapers: ~A" (princ-to-string e))
      nil)))

(defun set-chat-wallpaper (chat-id wallpaper &key is-dark-theme account-id)
  "Set wallpaper for a chat.

   CHAT-ID: Target chat ID
   WALLPAPER: chat-wallpaper object
   IS-DARK-THEME: Use dark theme version if T
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("wallpaper_id" . ,(chat-wallpaper-id wallpaper)))))
        (when is-dark-theme
          (push (cons "is_dark_theme" "true") params))

        (let ((result (make-api-call connection "setChatWallPaper" params)))
          (if result
              (progn
                (log-message :info "Wallpaper set for chat ~A" chat-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error setting chat wallpaper: ~A" (princ-to-string e))
      nil)))

(defun upload-wallpaper (file-path &key file-name)
  "Upload a custom wallpaper file.

   FILE-PATH: Path to wallpaper file
   FILE-NAME: Optional file name

   Returns uploaded document on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("file_path" . ,file-path))))
        (when file-name
          (push (cons "file_name" file-name) params))

        (let ((result (make-api-call connection "uploadWallpaper" params)))
          (if result
              (make-instance 'chat-wallpaper
                             :type :image
                             :document result)
              nil)))
    (error (e)
      (log-message :error "Error uploading wallpaper: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Chat Theme Management
;;; ======================================================================

(defun get-chat-themes (&key include-premium)
  "Get available chat themes.

   INCLUDE-PREMIUM: Include premium themes if T

   Returns list of chat-theme objects."
  (handler-case
      (let ((connection (get-current-connection)))
        (let ((result (make-api-call connection "getChatThemes" nil)))
          (if result
              (loop for theme-data across (gethash "themes" result)
                    when (or include-premium
                             (not (gethash "is_premium" theme-data)))
                    collect (make-instance 'chat-theme
                                           :name (gethash "name" theme-data "")
                                           :colors (gethash "colors" theme-data)
                                           :wallpaper (gethash "wallpaper" theme-data)
                                           :is-premium (gethash "is_premium" theme-data))
              nil)))
    (error (e)
      (log-message :error "Error getting chat themes: ~A" (princ-to-string e))
      nil)))

(defun set-chat-theme (chat-id theme &key account-id)
  "Set theme for a chat.

   CHAT-ID: Target chat ID
   THEME: chat-theme object
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("theme_name" . ,(chat-theme-name theme)))))
        (let ((result (make-api-call connection "setChatTheme" params)))
          (if result
              (progn
                (log-message :info "Theme ~A set for chat ~A" (chat-theme-name theme) chat-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error setting chat theme: ~A" (princ-to-string e))
      nil)))

(defun get-premium-themes ()
  "Get premium-only chat themes.

   Returns list of premium chat-theme objects."
  (get-chat-themes :include-premium t))

;;; ======================================================================
;;; Star Reactions and Giveaways
;;; ======================================================================

(defun send-star-reaction (chat-id message-id star-count &key is-anonymous)
  "Send a star reaction to a message.

   CHAT-ID: Target chat ID
   MESSAGE-ID: Target message ID
   STAR-COUNT: Number of stars (1-1000)
   IS-ANONYMOUS: Send anonymously if T

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_id" . ,message-id)
                       ("star_count" . ,star-count))))
        (when is-anonymous
          (push (cons "is_anonymous" "true") params))

        (let ((result (make-api-call connection "sendStarReaction" params)))
          (if result
              (progn
                (log-message :info "~A stars sent to message ~A" star-count message-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error sending star reaction: ~A" (princ-to-string e))
      nil)))

(defun create-giveaway (chat-id prize-description &key winner-count duration
                                              subscription-months only-new-members
                                              countries)
  "Create a Telegram Stars giveaway.

   CHAT-ID: Target channel/supergroup ID
   PRIZE-DESCRIPTION: Description of the prize
   WINNER-COUNT: Number of winners to select
   DURATION: Giveaway duration in seconds
   SUBSCRIPTION-MONTHS: Optional Premium subscription months
   ONLY-NEW-MEMBERS: Restrict to new members if T
   COUNTRIES: Optional list of country codes

   Returns giveaway object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("prize_description" . ,prize-description)
                       ("winner_count" . ,winner-count)
                       ("duration" . ,duration))))
        (when subscription-months
          (push (cons "subscription_months" subscription-months) params))
        (when only-new-members
          (push (cons "only_new_members" "true") params))
        (when countries
          (push (cons "countries" (json:encode-to-string countries)) params))

        (let ((result (make-api-call connection "createGiveaway" params)))
          (if result
              (progn
                (log-message :info "Giveaway created in ~A" chat-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error creating giveaway: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Global State
;;; ======================================================================

(defvar *custom-emoji-cache* (make-hash-table :test 'equal)
  "Cache of custom emoji by ID")

(defvar *wallpaper-cache* nil
  "Cached wallpaper list")

(defvar *theme-cache* nil
  "Cached theme list")

(defvar *available-message-effects* nil
  "Cached available message effects")

(defvar *default-dice-emojis*
  '("🎲" "🎯" "🏀" "⚽" "🎳" "🎰")
  "Available dice emoji options")
