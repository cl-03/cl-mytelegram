;;; notifications.lisp --- Notification system enhancements
;;; Part of v0.22.0 - Notification System, Contacts, and Utilities

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Notification Classes
;;; ======================================================================

(defclass notification-settings ()
  ((show-preview :initarg :show-preview :accessor notification-show-preview
                 :initform t :documentation "Show message preview in notifications")
   (show-sender :initarg :show-sender :accessor notification-show-sender
                :initform t :documentation "Show sender name in notifications")
   (show-message-count :initarg :show-message-count
                       :accessor notification-show-message-count
                       :initform t :documentation "Show unread message count badge")
   (sound-enabled :initarg :sound-enabled :accessor notification-sound-enabled
                  :initform t :documentation "Play notification sound")
   (vibration-enabled :initarg :vibration-enabled
                      :accessor notification-vibration-enabled
                      :initform t :documentation "Vibrate on notification")
   (popup-enabled :initarg :popup-enabled :accessor notification-popup-enabled
                  :initform t :documentation "Show popup notification")
   (light-enabled :initarg :light-enabled :accessor notification-light-enabled
                  :initform t :documentation "LED light on notification")
   (sound-path :initarg :sound-path :accessor notification-sound-path
               :initform "" :documentation "Custom sound file path")
   (priority :initarg :priority :accessor notification-priority
             :initform :default :documentation "Notification priority: :low, :default, :high")))

(defclass chat-notification-settings ()
  ((chat-id :initarg :chat-id :accessor chat-notification-chat-id
            :initform 0 :documentation "Chat ID")
   (use-default :initarg :use-default :accessor chat-notification-use-default
                :initform t :documentation "Use default settings if T")
   (settings :initarg :settings :accessor chat-notification-settings
             :initform nil :documentation "Custom notification-settings object")
   (mute-until :initarg :mute-until :accessor chat-notification-mute-until
               :initform nil :documentation "Mute until timestamp (NIL = unmuted)")))

(defclass notification ()
  ((id :initarg :id :accessor notification-id
       :initform 0 :documentation "Unique notification ID")
   (type :initarg :type :accessor notification-type
         :initform :message :documentation "Type: :message, :mention, :reaction, :system")
   (chat-id :initarg :chat-id :accessor notification-chat-id
            :initform 0 :documentation "Source chat ID")
   (message-id :initarg :message-id :accessor notification-message-id
               :initform 0 :documentation "Source message ID")
   (title :initarg :title :accessor notification-title
          :initform "" :documentation "Notification title")
   (message :initarg :message :accessor notification-message
            :initform "" :documentation "Notification message body")
   (timestamp :initarg :timestamp :accessor notification-timestamp
              :initform 0 :documentation "Unix timestamp")
   (is-read :initarg :is-read :accessor notification-is-read
            :initform nil :documentation "True if notification was read")
   (data :initarg :data :accessor notification-data
         :initform nil :documentation "Additional data plist")))

(defclass notification-center ()
  ((notifications :initarg :notifications :accessor notification-center-notifications
                  :initform nil :documentation "List of notification objects")
   (unread-count :initarg :unread-count :accessor notification-center-unread-count
                 :initform 0 :documentation "Count of unread notifications")
   (max-size :initarg :max-size :accessor notification-center-max-size
             :initform 100 :documentation "Maximum notifications to keep")
   (auto-clear-read :initarg :auto-clear-read
                    :accessor notification-center-auto-clear-read
                    :initform nil :documentation "Auto-clear read notifications")))

;;; ======================================================================
;;; Global State
;;; ======================================================================

(defvar *notification-settings* nil
  "Global notification settings")

(defvar *chat-notification-settings* (make-hash-table :test 'equal)
  "Per-chat notification settings")

(defvar *notification-center* nil
  "Global notification center instance")

(defvar *notification-queue* (make-instance 'message-queue)
  "Queue for outgoing notifications")

(defvar *notification-hooks* nil
  "List of notification hook functions")

;;; ======================================================================
;;; Notification Settings Management
;;; ======================================================================

(defun initialize-notification-settings ()
  "Initialize default notification settings.
   Returns notification-settings object."
  (setq *notification-settings*
        (make-instance 'notification-settings
                       :show-preview t
                       :show-sender t
                       :show-message-count t
                       :sound-enabled t
                       :vibration-enabled t
                       :popup-enabled t
                       :light-enabled t
                       :priority :default)))

(defun get-notification-settings ()
  "Get current global notification settings.
   Returns notification-settings object."
  (or *notification-settings*
      (initialize-notification-settings)))

(defun update-notification-settings (&key show-preview show-sender show-message-count
                                         sound-enabled vibration-enabled popup-enabled
                                         light-enabled sound-path priority)
  "Update global notification settings.
   Returns updated notification-settings object."
  (let ((settings (get-notification-settings)))
    (when (not (null show-preview))
      (setf (notification-show-preview settings) show-preview))
    (when (not (null show-sender))
      (setf (notification-show-sender settings) show-sender))
    (when (not (null show-message-count))
      (setf (notification-show-message-count settings) show-message-count))
    (when (not (null sound-enabled))
      (setf (notification-sound-enabled settings) sound-enabled))
    (when (not (null vibration-enabled))
      (setf (notification-vibration-enabled settings) vibration-enabled))
    (when (not (null popup-enabled))
      (setf (notification-popup-enabled settings) popup-enabled))
    (when (not (null light-enabled))
      (setf (notification-light-enabled settings) light-enabled))
    (when sound-path
      (setf (notification-sound-path settings) sound-path))
    (when priority
      (setf (notification-priority settings) priority))
    settings))

(defun set-custom-notification-sound (sound-path)
  "Set custom notification sound.
   SOUND-PATH: Path to sound file (WAV, MP3, OGG)
   Returns T on success, NIL on failure."
  (when (probe-file sound-path)
    (update-notification-settings :sound-path sound-path)
    t))

;;; ======================================================================
;;; Per-Chat Notification Settings
;;; ======================================================================

(defun get-chat-notification-settings (chat-id)
  "Get notification settings for a specific chat.
   CHAT-ID: Target chat ID
   Returns chat-notification-settings object."
  (or (gethash (format nil "~A" chat-id) *chat-notification-settings*)
      (setf (gethash (format nil "~A" chat-id) *chat-notification-settings*)
            (make-instance 'chat-notification-settings
                           :chat-id chat-id
                           :use-default t))))

(defun set-chat-notification-settings (chat-id settings &key mute-duration)
  "Set custom notification settings for a chat.
   CHAT-ID: Target chat ID
   SETTINGS: notification-settings object
   MUTE-DURATION: Optional mute duration in seconds
   Returns T on success, NIL on failure."
  (let ((chat-settings (make-instance 'chat-notification-settings
                                      :chat-id chat-id
                                      :use-default nil
                                      :settings settings)))
    (when mute-duration
      (setf (chat-notification-mute-until chat-settings)
            (+ (get-universal-time) mute-duration)))
    (setf (gethash (format nil "~A" chat-id) *chat-notification-settings*)
          chat-settings)
    t))

(defun mute-chat (chat-id &key duration)
  "Mute notifications for a chat.
   CHAT-ID: Target chat ID
   DURATION: Mute duration in seconds (NIL = forever)
   Returns T on success, NIL on failure."
  (let* ((chat-settings (get-chat-notification-settings chat-id))
         (mute-until (if duration
                         (+ (get-universal-time) duration)
                         9999999999))) ; Far future for "forever"
    (setf (chat-notification-mute-until chat-settings) mute-until)
    (setf (chat-notification-use-default chat-settings) nil)
    (setf (gethash (format nil "~A" chat-id) *chat-notification-settings*)
          chat-settings)
    (log-message :info "Chat ~A muted until ~A" chat-id mute-until)
    t))

(defun unmute-chat (chat-id)
  "Unmute notifications for a chat.
   CHAT-ID: Target chat ID
   Returns T on success, NIL on failure."
  (let ((chat-settings (get-chat-notification-settings chat-id)))
    (setf (chat-notification-mute-until chat-settings) nil)
    (setf (gethash (format nil "~A" chat-id) *chat-notification-settings*)
          chat-settings)
    (log-message :info "Chat ~A unmuted" chat-id)
    t))

(defun chat-muted-p (chat-id)
  "Check if a chat is muted.
   CHAT-ID: Target chat ID
   Returns T if muted, NIL otherwise."
  (let ((chat-settings (get-chat-notification-settings chat-id)))
    (let ((mute-until (chat-notification-mute-until chat-settings)))
      (and mute-until (> mute-until (get-universal-time))))))

;;; ======================================================================
;;; Notification Center Operations
;;; ======================================================================

(defun initialize-notification-center ()
  "Initialize the notification center.
   Returns notification-center object."
  (setq *notification-center*
        (make-instance 'notification-center
                       :max-size 100
                       :auto-clear-read nil)))

(defun add-notification (&key type chat-id message-id title message data)
  "Add a notification to the notification center.
   TYPE: Notification type (:message, :mention, :reaction, :system)
   CHAT-ID: Source chat ID
   MESSAGE-ID: Source message ID
   TITLE: Notification title
   MESSAGE: Notification body
   DATA: Additional data plist
   Returns notification object."
  (unless *notification-center*
    (initialize-notification-center))

  (let* ((settings (get-notification-settings))
         (notification (make-instance 'notification
                                      :id (get-universal-time)
                                      :type type
                                      :chat-id chat-id
                                      :message-id message-id
                                      :title title
                                      :message message
                                      :timestamp (get-universal-time)
                                      :is-read nil
                                      :data data)))
    ;; Add to center
    (push notification (notification-center-notifications *notification-center*))
    (incf (notification-center-unread-count *notification-center*))

    ;; Trim if over max size
    (when (> (length (notification-center-notifications *notification-center*))
             (notification-center-max-size *notification-center*))
      (setf (notification-center-notifications *notification-center*)
            (subseq (notification-center-notifications *notification-center*)
                    0 (notification-center-max-size *notification-center*))))

    ;; Trigger hooks
    (dolist (hook *notification-hooks*)
      (funcall hook notification))

    ;; Show desktop notification if enabled
    (when (and (notification-popup-enabled settings)
               (not (chat-muted-p chat-id)))
      (show-desktop-notification notification))

    notification))

(defun get-notifications (&key limit unread-only type)
  "Get notifications from the notification center.
   LIMIT: Maximum number to return
   UNREAD-ONLY: Return only unread if T
   TYPE: Filter by notification type
   Returns list of notification objects."
  (unless *notification-center*
    (initialize-notification-center))

  (let ((result (notification-center-notifications *notification-center*)))
    ;; Filter by unread
    (when unread-only
      (setq result (remove-if-not (lambda (n) (not (notification-is-read n))) result)))
    ;; Filter by type
    (when type
      (setq result (remove-if-not (lambda (n) (eq (notification-type n) type)) result)))
    ;; Apply limit
    (when limit
      (setq result (subseq result 0 (min limit (length result)))))
    result))

(defun mark-notification-read (notification-id)
  "Mark a notification as read.
   NOTIFICATION-ID: Target notification ID
   Returns T on success, NIL on failure."
  (unless *notification-center*
    (initialize-notification-center))

  (let ((notification (find notification-id
                            (notification-center-notifications *notification-center*)
                            :key #'notification-id)))
    (when (and notification (not (notification-is-read notification)))
      (setf (notification-is-read notification) t)
      (decf (notification-center-unread-count *notification-center*))
      t)))

(defun mark-all-notifications-read ()
  "Mark all notifications as read.
   Returns number of notifications marked read."
  (unless *notification-center*
    (initialize-notification-center))

  (let ((count 0))
    (dolist (notification (notification-center-notifications *notification-center*))
      (when (not (notification-is-read notification))
        (setf (notification-is-read notification) t)
        (incf count)))
    (setf (notification-center-unread-count *notification-center*) 0)
    count))

(defun clear-notifications (&key read-only type)
  "Clear notifications from the notification center.
   READ-ONLY: Clear only read notifications if T
   TYPE: Clear only notifications of this type
   Returns number of cleared notifications."
  (unless *notification-center*
    (initialize-notification-center))

  (let ((initial-length (length (notification-center-notifications *notification-center*))))
    (cond
      (read-only
       (setf (notification-center-notifications *notification-center*)
             (remove-if #'notification-is-read
                        (notification-center-notifications *notification-center*))))
      (type
       (setf (notification-center-notifications *notification-center*)
             (remove-if (lambda (n) (eq (notification-type n) type))
                        (notification-center-notifications *notification-center*))))
      (t
       (setf (notification-center-notifications *notification-center*) nil)
       (setf (notification-center-unread-count *notification-center*) 0)))
    (- initial-length (length (notification-center-notifications *notification-center*)))))

;;; ======================================================================
;;; Desktop Notifications
;;; ======================================================================

(defun show-desktop-notification (notification)
  "Show a desktop notification.
   NOTIFICATION: notification object to display
   Returns T on success, NIL on failure."
  (handler-case
      (let ((settings (get-notification-settings)))
        ;; Use CLOG or system notification
        (when (and (notification-show-sender settings)
                   (notification-show-preview settings))
          #+linux
          (uiop:run-program
           `("notify-send" ,(notification-title notification)
             ,(notification-message notification)
             "-u" ,(case (notification-priority settings)
                     (:low "low")
                     (:high "critical")
                     (otherwise "normal")))
           :error-output :null)
          #+darwin
          (uiop:run-program
           `("osascript" "-e"
             ,(format nil "display notification \"~A\" with title \"~A\""
                      (notification-message notification)
                      (notification-title notification)))
           :error-output :null)
          #+win32
          (uiop:run-program
           `("powershell" "-Command"
             ,(format nil "[System.Windows.Forms.MessageBox]::Show(\"~A\", \"~A\")"
                      (notification-message notification)
                      (notification-title notification)))
           :error-output :null))
        t))
    (error (e)
      (log-message :error "Error showing desktop notification: ~A" e)
      nil)))

;;; ======================================================================
;;; Notification Hooks
;;; ======================================================================

(defun register-notification-hook (hook-function)
  "Register a hook function to be called on new notifications.
   HOOK-FUNCTION: Function taking notification object as argument
   Returns T on success, NIL on failure."
  (pushnew hook-function *notification-hooks*)
  t)

(defun unregister-notification-hook (hook-function)
  "Unregister a notification hook function.
   HOOK-FUNCTION: Previously registered hook function
   Returns T on success, NIL on failure."
  (setf *notification-hooks* (remove hook-function *notification-hooks*))
  t)

;;; ======================================================================
;;; Server API Integration
;;; ======================================================================

(defun get-server-notification-settings (&key account-id)
  "Get notification settings from Telegram server.
   ACCOUNT-ID: Optional account identifier
   Returns notification-settings object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (result (make-api-call connection "getNotificationSettings" nil)))
        (if result
            (make-instance 'notification-settings
                           :show-preview (gethash "show_preview" result t)
                           :show-sender (gethash "show_sender" result t)
                           :sound-enabled (gethash "sound_enabled" result t)
                           :priority (gethash "priority" result :default))
            nil))
    (error (e)
      (log-message :error "Error getting server notification settings: ~A" e)
      nil)))

(defun set-server-notification-settings (settings &key account-id)
  "Update notification settings on Telegram server.
   SETTINGS: notification-settings object
   ACCOUNT-ID: Optional account identifier
   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("show_preview" . ,(notification-show-preview settings))
                       ("show_sender" . ,(notification-show-sender settings))
                       ("sound_enabled" . ,(notification-sound-enabled settings))
                       ("priority" . ,(string-downcase (notification-priority settings))))))
        (let ((result (make-api-call connection "setNotificationSettings" params)))
          (if result
              (progn
                (log-message :info "Server notification settings updated")
                t)
              nil)))
    (error (e)
      (log-message :error "Error setting server notification settings: ~A" e)
      nil)))

(defun export-notification-settings ()
  "Export notification settings to JSON file.
   Returns exported JSON string on success, NIL on failure."
  (let ((settings (get-notification-settings)))
    (json:encode-json-to-string
     `(("show_preview" . ,(notification-show-preview settings))
       ("show_sender" . ,(notification-show-sender settings))
       ("show_message_count" . ,(notification-show-message-count settings))
       ("sound_enabled" . ,(notification-sound-enabled settings))
       ("vibration_enabled" . ,(notification-vibration-enabled settings))
       ("popup_enabled" . ,(notification-popup-enabled settings))
       ("light_enabled" . ,(notification-light-enabled settings))
       ("sound_path" . ,(notification-sound-path settings))
       ("priority" . ,(string (notification-priority settings)))))))

(defun import-notification-settings (json-string)
  "Import notification settings from JSON file.
   JSON-STRING: JSON string with settings
   Returns T on success, NIL on failure."
  (handler-case
      (let ((data (json:decode-json-from-string json-string)))
        (update-notification-settings
         :show-preview (gethash "show_preview" data t)
         :show-sender (gethash "show_sender" data t)
         :show-message-count (gethash "show_message_count" data t)
         :sound-enabled (gethash "sound_enabled" data t)
         :vibration-enabled (gethash "vibration_enabled" data t)
         :popup-enabled (gethash "popup_enabled" data t)
         :light-enabled (gethash "light_enabled" data t)
         :sound-path (gethash "sound_path" data "")
         :priority (intern (string-upcase (gethash "priority" data "DEFAULT")) :keyword))
        t))
    (error (e)
      (log-message :error "Error importing notification settings: ~A" e)
      nil)))

;;; ======================================================================
;;; v0.32.0 Enhancements: Silent Mode and Global Settings
;;; ======================================================================

(defvar *silent-mode-enabled* nil
  "Global silent mode (do not disturb) flag")

(defvar *silent-mode-until* nil
  "Silent mode until timestamp (NIL = indefinite)")

(defvar *global-notify-settings* nil
  "Global notification settings override")

(defvar *peer-notify-settings* (make-hash-table :test 'equal)
  "Per-peer notification settings")

(defun get-notify-settings (&key (scope :global))
  "Get notification settings for a scope.

   SCOPE: :global, :private, :groups, :channels

   Returns notification-settings object."
  (case scope
    (:global *notification-settings*)
    (:private (gethash :private *peer-notify-settings* *notification-settings*))
    (:groups (gethash :groups *peer-notify-settings* *notification-settings*))
    (:channels (gethash :channels *peer-notify-settings* *notification-settings*))
    (otherwise *notification-settings*)))

(defun update-notify-settings (scope &key show-preview show-sender sound-enabled
                                      vibration-enabled priority mute-until)
  "Update notification settings for a scope.

   SCOPE: :global, :private, :groups, :channels
   SHOW-PREVIEW: Show message preview
   SHOW-SENDER: Show sender name
   SOUND-ENABLED: Enable notification sound
   VIBRATION-ENABLED: Enable vibration
   PRIORITY: Priority level (:low, :default, :high)
   MUTE-UNTIL: Timestamp to mute until (NIL = unmute)

   Returns T on success."
  (let ((settings (get-notify-settings :scope scope)))
    (when show-preview (setf (notification-show-preview settings) show-preview))
    (when show-sender (setf (notification-show-sender settings) show-sender))
    (when sound-enabled (setf (notification-sound-enabled settings) sound-enabled))
    (when vibration-enabled (setf (notification-vibration-enabled settings) vibration-enabled))
    (when priority (setf (notification-priority settings) priority)))
  (when (and scope (not (eq scope :global)))
    (setf (gethash scope *peer-notify-settings*) (get-notify-settings :scope scope)))
  (log:info "Notification settings updated for ~A" scope)
  t)

(defun reset-notify-settings (&key (scope :global))
  "Reset notification settings to defaults.

   SCOPE: :global, :private, :groups, :channels

   Returns T on success."
  (case scope
    (:global
     (setf *notification-settings* (make-instance 'notification-settings)))
    (otherwise
     (remhash scope *peer-notify-settings*)))
  (log:info "Notification settings reset for ~A" scope)
  t)

(defun get-peer-notify-settings (peer-id)
  "Get notification settings for a specific peer.

   PEER-ID: Peer (chat/user/channel) identifier

   Returns chat-notification-settings object."
  (gethash peer-id *peer-notify-settings*
           (make-instance 'chat-notification-settings
                          :chat-id peer-id
                          :use-default t)))

(defun set-peer-notify-settings (peer-id &key mute-until show-preview
                                          sound-enabled priority)
  "Set notification settings for a specific peer.

   PEER-ID: Peer identifier
   MUTE-UNTIL: Timestamp to mute until
   SHOW-PREVIEW: Show message preview
   SOUND-ENABLED: Enable notification sound
   PRIORITY: Priority level

   Returns T on success."
  (let ((settings (get-peer-notify-settings peer-id)))
    (setf (chat-notification-use-default settings) nil)
    (when mute-until (setf (chat-notification-mute-until settings) mute-until))
    (when (null (chat-notification-settings settings))
      (setf (chat-notification-settings settings)
            (make-instance 'notification-settings)))
    (let ((s (chat-notification-settings settings)))
      (when show-preview (setf (notification-show-preview s) show-preview))
      (when sound-enabled (setf (notification-sound-enabled s) sound-enabled))
      (when priority (setf (notification-priority s) priority))))
  (setf (gethash peer-id *peer-notify-settings*) settings)
  (log:info "Peer notification settings set for ~A" peer-id)
  t)

(defun get-global-notify-settings ()
  "Get global notification settings override.

   Returns notification-settings object or NIL."
  *global-notify-settings*)

(defun set-global-notify-settings (settings)
  "Set global notification settings override.

   SETTINGS: notification-settings object

   Returns T on success."
  (setf *global-notify-settings* settings)
  (log:info "Global notification settings updated")
  t)

(defun enable-silent-mode (&key (until nil) (duration-minutes nil))
  "Enable silent mode (do not disturb).

   UNTIL: Timestamp to disable silent mode
   DURATION-MINUTES: Duration in minutes (alternative to UNTIL)

   Returns T on success."
  (let ((until-ts (or until
                      (when duration-minutes
                        (+ (get-universal-time) (* duration-minutes 60))))))
    (setf *silent-mode-enabled* t)
    (setf *silent-mode-until* until-ts))
  (log:info "Silent mode enabled until ~A" *silent-mode-until*)
  t)

(defun disable-silent-mode ()
  "Disable silent mode.

   Returns T on success."
  (setf *silent-mode-enabled* nil)
  (setf *silent-mode-until* nil)
  (log:info "Silent mode disabled")
  t)

(defun get-silent-mode-status ()
  "Get silent mode status.

   Returns plist with :enabled, :until, :remaining-seconds."
  (let* ((now (get-universal-time))
         (until *silent-mode-until*)
         (remaining (when (and until (> until now))
                      (- until now))))
    (list :enabled (and *silent-mode-enabled*
                        (or (null until) (> until now)))
          :until until
          :remaining-seconds remaining)))

(defun is-peer-muted-p (peer-id)
  "Check if a peer is muted.

   PEER-ID: Peer identifier

   Returns T if muted, NIL otherwise."
  (let ((settings (get-peer-notify-settings peer-id)))
    (let ((mute-until (chat-notification-mute-until settings)))
      (if mute-until
          (> mute-until (get-universal-time))
          nil))))

(defun is-silent-mode-active-p ()
  "Check if silent mode is currently active.

   Returns T if active, NIL otherwise."
  (and *silent-mode-enabled*
       (or (null *silent-mode-until*)
           (> *silent-mode-until* (get-universal-time)))))

(defun get-notification-stats ()
  "Get notification statistics.

   Returns plist with statistics."
  (let ((total-peers 0)
        (muted-peers 0)
        (silent-active (is-silent-mode-active-p)))
    (maphash (lambda (k v)
               (declare (ignore k))
               (incf total-peers)
               (when (chat-notification-mute-until v)
                 (incf muted-peers)))
             *peer-notify-settings*)
    (list :total-peers total-peers
          :muted-peers muted-peers
          :silent-mode-active silent-active
          :silent-mode-until *silent-mode-until*)))
