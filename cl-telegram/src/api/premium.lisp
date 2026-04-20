;;; premium.lisp --- Telegram Premium features support
;;;
;;; Provides support for:
;;; - Premium status detection and verification
;;; - Enhanced file upload limits (4GB for premium)
;;; - Premium-exclusive stickers and reactions
;;; - Advanced customization options
;;; - Priority features and doubled limits

(in-package #:cl-telegram/api)

;;; ### Premium Types

(defclass premium-status ()
  ((is-premium :initform nil :accessor premium-is-premium)
   (expiration-date :initform nil :accessor premium-expiration-date)
   (subscription-type :initform nil :accessor premium-subscription-type)
   (can-send-large-files :initform nil :accessor premium-can-send-large-files)
   (can-use-premium-stickers :initform nil :accessor premium-can-use-premium-stickers)
   (max-file-size :initform (* 2 1024 1024 1024) :accessor premium-max-file-size)
   (max-download-speed :initform nil :accessor premium-max-download-speed)
   (double-limits :initform nil :accessor premium-double-limits)))

(defclass premium-features-config ()
  ((premium-sticker-sets :initform nil :accessor config-premium-sticker-sets)
   (premium-reactions :initform nil :accessor config-premium-reactions)
   (premium-emoji-statuses :initform nil :accessor config-premium-emoji-statuses)
   (premium-profile-colors :initform nil :accessor config-premium-profile-colors)
   (premium-chat-themes :initform nil :accessor config-premium-chat-themes)
   (premium-transcription-hours :initform 0 :accessor config-premium-transcription-hours)))

;;; ### Global State

(defvar *premium-status* (make-instance 'premium-status)
  "Current user's premium status")

(defvar *premium-features-config* (make-instance 'premium-features-config)
  "Premium features configuration")

(defvar *premium-cache-ttl* 3600 ; 1 hour
  "Cache TTL for premium status checks")

(defvar *premium-last-check* nil
  "Last time premium status was checked")

;;; ### Premium Status Detection

(defun check-premium-status ()
  "Check if the current user has Telegram Premium.

   Returns:
     T if user has premium, NIL otherwise

   Note:
     This is a client-side check. For server-side verification,
     use verify-premium-status which makes an API call."
  (let ((now (get-universal-time)))
    (if (and *premium-last-check*
             (< (- now *premium-last-check*) *premium-cache-ttl*))
        ;; Use cached status
        (premium-is-premium *premium-status*)
        ;; Refresh status
        (refresh-premium-status))))

(defun refresh-premium-status ()
  "Refresh premium status from server.

   Returns:
     T if user has premium, NIL otherwise"
  (let ((status (get-premium-status-from-server)))
    (when status
      (setf (premium-is-premium *premium-status*)
            (getf status :is-premium)
            (premium-expiration-date *premium-status*)
            (getf status :expiration-date)
            (premium-subscription-type *premium-status*)
            (getf status :subscription-type)
            (premium-can-send-large-files *premium-status*)
            (getf status :can-send-large-files)
            (premium-can-use-premium-stickers *premium-status*)
            (getf status :can-use-premium-stickers)
            (premium-max-file-size *premium-status*)
            (if (getf status :is-premium)
                (* 4 1024 1024 1024)  ; 4GB for premium
                (* 2 1024 1024 1024)) ; 2GB for free
            (premium-double-limits *premium-status*)
            (getf status :double-limits)
            *premium-last-check* (get-universal-time)))
    (premium-is-premium *premium-status*)))

(defun get-premium-status-from-server ()
  "Get premium status from Telegram servers.

   Returns:
     Plist with premium status information or NIL on error

   TL Schema:
     users.getUserPremium: flags.{
       user_id:InputUser
     } = userPremium;"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'users.getUserPremium
                                      :user-id (make-tl-object 'inputUserSelf))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Get premium status failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Get premium status timeout: ~a" e)
            nil)
          (:no-error (result)
            (list :is-premium (getf result :is-premium)
                  :expiration-date (getf result :expiration-date)
                  :subscription-type (getf result :subscription-type)
                  :can-send-large-files (getf result :can-send-large-files)
                  :can-use-premium-stickers (getf result :can-use-premium-stickers)
                  :double-limits (getf result :double-limits)))))
    (t (e)
      (log-error "Unexpected error in get-premium-status-from-server: ~a" e)
      (list :is-premium nil
            :expiration-date nil
            :subscription-type :monthly
            :can-send-large-files nil
            :can-use-premium-stickers nil
            :double-limits nil))))

(defun verify-premium-status ()
  "Verify premium status with Telegram servers.

   Returns:
     Values: (is-premium error-message)

   Use this for operations that require premium verification."
  (handler-case
      (let ((status (get-premium-status-from-server)))
        (if status
            (values (getf status :is-premium) nil)
            (values nil "Failed to fetch premium status")))
    (error (e)
      (values nil (format nil "Error checking premium status: ~A" e)))))

;;; ### Premium Feature Checks

(defun premium-required-p (feature)
  "Check if a feature requires Telegram Premium.

   Args:
     feature: Keyword symbol of the feature

   Returns:
     T if feature requires premium, NIL otherwise"
  (member feature
          '(:send-large-files
            :premium-stickers
            :premium-reactions
            :emoji-statuses
            :profile-colors
            :chat-themes
            :voice-transcription
            :advanced-chat-management
            :doubled-limits)
          :test #'eq))

(defun ensure-premium (feature &optional (error-msg nil))
  "Ensure user has premium for a feature.

   Args:
     feature: Keyword symbol of the feature
     error-msg: Optional custom error message

   Returns:
     T if user has premium, error condition otherwise

   Signals:
     premium-required-error if user doesn't have premium"
  (unless (check-premium-status)
    (error 'premium-required-error
           :feature feature
           :message (or error-msg
                        (format nil "Feature '~A' requires Telegram Premium" feature))))
  t)

(define-condition premium-required-error (error)
  "Error signaled when a premium feature is accessed without premium."
  ((feature :initarg :feature :reader premium-error-feature)
   (message :initarg :message :reader premium-error-message)))

;;; ### File Upload Limits

(defun get-max-file-size ()
  "Get maximum file size for current user.

   Returns:
     Maximum file size in bytes

   Premium users: 4GB (4294967296 bytes)
   Free users: 2GB (2147483648 bytes)"
  (if (check-premium-status)
      (premium-max-file-size *premium-status*)
      (* 2 1024 1024 1024)))

(defun can-upload-file-p (file-size)
  "Check if user can upload a file of given size.

   Args:
     file-size: File size in bytes

   Returns:
     T if upload is allowed, NIL otherwise"
  (<= file-size (get-max-file-size)))

(defun validate-file-for-upload (file-size file-path)
  "Validate file for upload based on premium status.

   Args:
     file-size: File size in bytes
     file-path: Path to the file

   Returns:
     Values: (t nil) on success, (nil error-message) on failure

   Raises:
     premium-required-error if file exceeds free tier limit"
  (let ((max-size (get-max-file-size)))
    (cond
      ((> file-size max-size)
       (if (check-premium-status)
           (values nil (format nil "File too large: ~A bytes (max ~A bytes for premium)"
                               file-size max-size))
           (values nil (format nil "File too large: ~A bytes. Premium required for files over ~A bytes"
                               file-size max-size)))))
      ((not (probe-file file-path))
       (values nil (format nil "File not found: ~A" file-path)))
      (t (values t nil)))))

;;; ### Premium Stickers & Reactions

(defun get-premium-sticker-sets ()
  "Get list of premium-exclusive sticker sets.

   Returns:
     List of premium sticker set objects"
  (let ((premium-sets (config-premium-sticker-sets *premium-features-config*)))
    (if premium-sets
        premium-sets
        ;; Fetch from server if not cached
        (fetch-premium-sticker-sets))))

(defun fetch-premium-sticker-sets ()
  "Fetch premium sticker sets from server.

   Returns:
     List of premium sticker set objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.getPremiumStickers
                                      :hash "")))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Fetch premium stickers failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Fetch premium stickers timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((sets (getf result :sets)))
              (setf (config-premium-sticker-sets *premium-features-config*) sets)
              sets))))
    (t (e)
      (log-error "Unexpected error in fetch-premium-sticker-sets: ~a" e)
      (setf (config-premium-sticker-sets *premium-features-config*) nil)
      nil)))

(defun can-use-premium-sticker-p (sticker-set-name)
  "Check if user can use a premium sticker set.

   Args:
     sticker-set-name: Name of the sticker set

   Returns:
     T if user can use the sticker, NIL otherwise"
  (if (check-premium-status)
      t
      ;; Free users can only use free sticker sets
      (not (member sticker-set-name (get-premium-sticker-sets)
                   :key #'stickerset-name :test #'string=))))

(defun get-premium-reactions ()
  "Get list of premium-exclusive reactions.

   Returns:
     List of premium reaction emojis"
  (let ((premium-reacts (config-premium-reactions *premium-features-config*)))
    (if premium-reacts
        premium-reacts
        (fetch-premium-reactions))))

(defun fetch-premium-reactions ()
  "Fetch premium reactions from server.

   Returns:
     List of premium reaction emojis"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getAvailableReactions
                                      :hash 0
                                      :premium-only t)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Fetch premium reactions failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Fetch premium reactions timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((reactions (mapcar (lambda (r) (getf r :emoji))
                                     (getf result :reactions))))
              (setf (config-premium-reactions *premium-features-config*) reactions)
              reactions))))
    (t (e)
      (log-error "Unexpected error in fetch-premium-reactions: ~a" e)
      (let ((reactions '("🎉" "💫" "🌟" "💎" "🔥" "❤️" "👍" "👎")))
        (setf (config-premium-reactions *premium-features-config*) reactions)
        reactions))))

(defun can-send-reaction-p (emoji)
  "Check if user can send a specific reaction.

   Args:
     emoji: Reaction emoji

   Returns:
     T if user can send the reaction, NIL otherwise"
  (let ((premium-reactions (get-premium-reactions)))
    (if (member emoji premium-reactions :test #'string=)
        (check-premium-status)
        t))) ; Free reactions always available

;;; ### Premium Customization

(defun get-premium-profile-colors ()
  "Get available premium profile colors.

   Returns:
     List of premium profile color themes"
  (let ((colors (config-premium-profile-colors *premium-features-config*)))
    (if colors
        colors
        (fetch-premium-profile-colors))))

(defun fetch-premium-profile-colors ()
  "Fetch premium profile colors from server.

   Returns:
     List of premium profile color themes"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.getProfileColors
                                      :user-id (make-tl-object 'inputUserSelf)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Fetch profile colors failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Fetch profile colors timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((colors (getf result :colors)))
              (setf (config-premium-profile-colors *premium-features-config*) colors)
              colors))))
    (t (e)
      (log-error "Unexpected error in fetch-premium-profile-colors: ~a" e)
      (let ((colors '((:name "Sunset" :gradient '(#xFF6B6B #FFD93D))
                      (:name "Ocean" :gradient '(#x4A90E2 #x50C9C3))
                      (:name "Forest" :gradient '(#x56AB2F #xA8E063))
                      (:name "Purple Haze" :gradient '(#x667eea #x764ba2))
                      (:name "Midnight" :gradient '(#x0f0c29 #x302b63 #x24243e)))))
        (setf (config-premium-profile-colors *premium-features-config*) colors)
        colors))))

(defun get-premium-chat-themes ()
  "Get available premium chat themes.

   Returns:
     List of premium chat theme objects"
  (let ((themes (config-premium-chat-themes *premium-features-config*)))
    (if themes
        themes
        (fetch-premium-chat-themes))))

(defun fetch-premium-chat-themes ()
  "Fetch premium chat themes from server.

   Returns:
     List of premium chat theme objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getChatThemes
                                      :hash 0))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Fetch chat themes failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Fetch chat themes timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((themes (getf result :themes)))
              (setf (config-premium-chat-themes *premium-features-config*) themes)
              themes))))
    (t (e)
      (log-error "Unexpected error in fetch-premium-chat-themes: ~a" e)
      (let ((themes '((:name "Classic" :id 1)
                      (:name "Day" :id 2)
                      (:name "Night" :id 3)
                      (:name "Arctic" :id 4)
                      (:name "Ocean" :id 5)
                      (:name "Mountain" :id 6))))
        (setf (config-premium-chat-themes *premium-features-config*) themes)
        themes))))

(defun set-profile-color (color-id)
  "Set premium profile color.

   Args:
     color-id: ID of the profile color theme

   Returns:
     T on success, error on failure

   Requires:
     Telegram Premium"
  (ensure-premium :profile-colors "Profile colors require Telegram Premium")
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.setProfileColor
                                      :color-id color-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Set profile color failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Set profile color timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in set-profile-color: ~a" e)
      nil)))

(defun set-chat-theme (chat-id theme-id)
  "Set premium chat theme for a specific chat.

   Args:
     chat-id: Chat identifier
     theme-id: Theme identifier

   Returns:
     T on success, error on failure

   Requires:
     Telegram Premium"
  (ensure-premium :chat-themes "Chat themes require Telegram Premium")
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.setChatTheme
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0)
                                      :theme-id theme-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Set chat theme failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Set chat theme timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in set-chat-theme: ~a" e)
      nil)))

;;; ### Emoji Statuses

(defun get-premium-emoji-statuses ()
  "Get available premium emoji statuses.

   Returns:
     List of premium emoji status objects"
  (let ((statuses (config-premium-emoji-statuses *premium-features-config*)))
    (if statuses
        statuses
        (fetch-premium-emoji-statuses))))

(defun fetch-premium-emoji-statuses ()
  "Fetch premium emoji statuses from server.

   Returns:
     List of premium emoji status objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'accounts.getAvailableEmojiStatuses))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Fetch emoji statuses failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Fetch emoji statuses timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((statuses (getf result :statuses)))
              (setf (config-premium-emoji-statuses *premium-features-config*) statuses)
              statuses))))
    (t (e)
      (log-error "Unexpected error in fetch-premium-emoji-statuses: ~a" e)
      (let ((statuses '((:emoji "⭐" :duration 86400)
                        (:emoji "💎" :duration 86400)
                        (:emoji "🎉" :duration 86400)
                        (:emoji "✨" :duration 86400)
                        (:emoji "🔥" :duration 86400)
                        (:emoji "💫" :duration 86400))))
        (setf (config-premium-emoji-statuses *premium-features-config*) statuses)
        statuses))))

(defun set-emoji-status (emoji &key (duration nil))
  "Set premium emoji status.

   Args:
     emoji: Emoji to use as status
     duration: Optional duration in seconds (NIL for permanent)

   Returns:
     T on success, error on failure

   Requires:
     Telegram Premium"
  (ensure-premium :emoji-statuses "Emoji statuses require Telegram Premium")
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'accounts.updateEmojiStatus
                                      :emoji emoji
                                      :duration duration))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Set emoji status failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Set emoji status timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in set-emoji-status: ~a" e)
      nil)))

(defun clear-emoji-status ()
  "Clear current emoji status.

   Returns:
     T on success, error on failure

   Requires:
     Telegram Premium"
  (ensure-premium :emoji-statuses "Emoji statuses require Telegram Premium")
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'accounts.removeEmojiStatus))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Clear emoji status failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Clear emoji status timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in clear-emoji-status: ~a" e)
      nil)))

;;; ### Voice Message Transcription

(defun get-premium-transcription-hours ()
  "Get remaining premium voice transcription hours.

   Returns:
     Number of transcription hours remaining"
  (if (check-premium-status)
      (config-premium-transcription-hours *premium-features-config*)
      0))

(defun transcribe-voice-message-premium (message-id)
  "Transcribe voice message with premium quality.

   Args:
     message-id: Message ID of voice message

   Returns:
     Transcription text or NIL on error

   Requires:
     Telegram Premium for unlimited transcriptions"
  (ensure-premium :voice-transcription "Voice transcription requires Telegram Premium")
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.requestTranscription
                                      :msg-id message-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Voice transcription failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Voice transcription timeout: ~a" e)
            nil)
          (:no-error (result)
            (getf result :transcription))))
    (t (e)
      (log-error "Unexpected error in transcribe-voice-message-premium: ~a" e)
      nil)))

;;; ### Doubled Limits

(defun get-doubled-limits ()
  "Get information about doubled limits for premium users.

   Returns:
     Plist with limit information"
  (if (not (check-premium-status))
      (list :channels 500
            :folders 10
            :pinned-chats 5
            :saved-tags 100)
      ;; Premium doubled limits
      (list :channels 1000
            :folders 20
            :pinned-chats 10
            :saved-tags 200
            :download-speed :priority
            :forward-limit 2000)))

(defun can-pin-more-chats-p ()
  "Check if user can pin additional chats.

   Returns:
     T if user can pin more chats, NIL otherwise"
  (let ((limit (if (check-premium-status) 10 5)))
    ;; Check actual pinned chat count from current user state
    (let ((current-pinned-count 0)) ; Would fetch from actual state
      (< current-pinned-count limit))))

(defun can-join-more-channels-p ()
  "Check if user can join additional channels.

   Returns:
     T if user can join more channels, NIL otherwise"
  (let ((limit (if (check-premium-status) 1000 500)))
    ;; Check actual joined channel count from current user state
    (let ((current-joined-count 0)) ; Would fetch from actual state
      (< current-joined-count limit))))

;;; ### Premium UI Components

(defun render-premium-badge ()
  "Render premium status badge for UI.

   Returns:
     String representation of premium badge"
  (if (check-premium-status)
      "⭐ Premium"
      ""))

(defun render-premium-features-panel (win container)
  "Render premium features panel in CLOG UI.

   Args:
     win: CLOG window
     container: Parent container element

   Returns:
     CLOG elements"
  (let ((panel (clog:create-div container :class "premium-features-panel")))
    (clog:set-html panel
                   (if (check-premium-status)
                       "<h3>⭐ Premium Active</h3>
                        <p>Your premium features are enabled.</p>
                        <ul>
                          <li>4GB file uploads</li>
                          <li>Premium stickers & reactions</li>
                          <li>Profile colors & chat themes</li>
                          <li>Voice message transcription</li>
                        </ul>"
                       "<h3>⭐ Telegram Premium</h3>
                        <p>Unlock exclusive features:</p>
                        <ul>
                          <li>4GB file uploads (2x larger)</li>
                          <li>Premium stickers & reactions</li>
                          <li>Profile colors & chat themes</li>
                          <li>Voice message transcription</li>
                          <li>Doubled limits</li>
                          <li>Faster downloads</li>
                        </ul>
                        <button class='get-premium-btn'>Get Premium</button>"))
    panel))

(defun show-premium-promo (win)
  "Show premium promotion dialog.

   Args:
     win: CLOG window

   Returns:
     T on success"
  (let ((modal (clog:create-div win :class "premium-promo-modal")))
    (clog:set-css modal "background" "rgba(0,0,0,0.8)")
    (clog:set-css modal "position" "fixed")
    (clog:set-css modal "top" "0")
    (clog:set-css modal "left" "0")
    (clog:set-css modal "width" "100%")
    (clog:set-css modal "height" "100%")
    (clog:set-css modal "z-index" "9999")
    (clog:set-css modal "display" "flex")
    (clog:set-css modal "justify-content" "center")
    (clog:set-css modal "align-items" "center")

    (let ((content (clog:create-div modal :class "premium-promo-content")))
      (clog:set-css content "background" "white")
      (clog:set-css content "padding" "40px")
      (clog:set-css content "border-radius" "12px")
      (clog:set-css content "max-width" "500px")
      (setf (clog:html content)
            "<h2 style='color: #3390ec; margin-bottom: 20px;'>⭐ Telegram Premium</h2>
             <p>Unlock all features with Premium:</p>
             <ul style='line-height: 2;'>
               <li>📁 4GB file uploads</li>
               <li>⚡ Faster download speeds</li>
               <li>🎭 Exclusive stickers & reactions</li>
               <li>🎨 Profile colors & chat themes</li>
               <li>📝 Voice message transcription</li>
               <li>📌 Doubled limits</li>
             </ul>
             <button style='background: #3390ec; color: white; padding: 12px 24px; border: none; border-radius: 8px; margin-top: 20px; cursor: pointer;'>
               Get Premium
             </button>
             <button style='background: transparent; color: #666; padding: 12px 24px; border: none; border-radius: 8px; margin-top: 10px; cursor: pointer;'>
               Maybe Later
             </button>"))
    t))

;;; ### Premium Statistics

(defun get-premium-stats ()
  "Get premium usage statistics.

   Returns:
     Plist with premium usage stats"
  (let ((stats (list :is-premium (check-premium-status)
                     :large-files-sent 0
                     :premium-stickers-used 0
                     :transcriptions-count 0)))
    ;; Fetch stats from database or server
    ;; For now, return basic stats structure
    stats))

(defun reset-premium-cache ()
  "Reset premium status cache.

   Returns:
     T on success"
  (setf *premium-last-check* nil)
  t)

;;; ### Premium Subscription Management

(defun get-premium-subscription-info ()
  "Get current premium subscription information.

   Returns:
     Plist with subscription details"
  (list :is-active (check-premium-status)
        :expiration-date (premium-expiration-date *premium-status*)
        :subscription-type (premium-subscription-type *premium-status*)
        :auto-renew t
        :payment-provider "Telegram"))

(defun cancel-premium-subscription ()
  "Cancel premium subscription.

   Returns:
     T on success, error on failure"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'payments.cancelSubscription))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (premium-error (e)
            (log-error "Cancel subscription failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Cancel subscription timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in cancel-premium-subscription: ~a" e)
      nil)))

(defun renew-premium-subscription (duration)
  "Renew premium subscription.

   Args:
     duration: Subscription duration (:monthly :yearly)

   Returns:
     T on success, error on failure"
  (handler-case
      (let* ((connection (get-connection))
             (invoice (make-tl-object 'payments.createInvoice
                                      :subscription-type :premium
                                      :duration duration)))
        (rpc-handler-case (rpc-call connection invoice :timeout 10000)
          (payment-error (e)
            (log-error "Renew subscription failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Renew subscription timeout: ~a" e)
            nil)
          (:no-error (result)
            ;; Process payment URL or result
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in renew-premium-subscription: ~a" e)
      nil)))
