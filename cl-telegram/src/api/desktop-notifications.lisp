;;; desktop-notifications.lisp --- Desktop notification system
;;;
;;; Provides native desktop notifications for new messages, calls, and events.
;;; Supports Windows, macOS, and Linux with platform-specific implementations.

(in-package #:cl-telegram/api)

;;; ### Notification State

(defclass notification-manager ()
  ((platform :initform (detect-platform) :accessor notif-platform
             :documentation "Current platform (:windows, :macos, :linux)")
   (enabled-p :initform t :accessor notif-enabled-p
              :documentation "Whether notifications are enabled")
   (sound-enabled-p :initform t :accessor notif-sound-enabled-p
                    :documentation "Whether sound is enabled")
   (badge-enabled-p :initform t :accessor notif-badge-enabled-p
                    :documentation "Whether app badge updates are enabled")
   (notification-count :initform 0 :accessor notif-count
                       :documentation "Total notifications sent")
   (last-notification-time :initform 0 :accessor notif-last-time
                           :documentation "Universal time of last notification")
   (quiet-hours-start :initform nil :accessor notif-quiet-start
                      :documentation "Quiet hours start hour (0-23)")
   (quiet-hours-end :initform nil :accessor notif-quiet-end
                    :documentation "Quiet hours end hour (0-23)")
   (notification-history :initform (make-array 100 :adjustable t :fill-pointer 0)
                         :accessor notif-history
                         :documentation "Recent notification history"))
  (:documentation "Desktop notification manager"))

;;; ### Platform Detection

(defun detect-platform ()
  "Detect current operating system.

   Returns:
     Keyword: :windows, :macos, or :linux"
  (cond
    ((search "Windows" (software-type)) :windows)
    ((search "Darwin" (uname)) :macos)
    ((search "Linux" (software-type)) :linux)
    (t :unknown)))

(defun uname ()
  "Get Unix name string."
  (handler-case
      (with-output-to-string (out)
        (uiop:run-program "uname" :output out))
    (error () "")))

;;; ### Global Notification Manager

(defvar *notification-manager* nil
  "Global notification manager instance")

(defun make-notification-manager ()
  "Create notification manager instance.

   Returns:
     Notification manager instance"
  (make-instance 'notification-manager))

(defun initialize-notifications ()
  "Initialize the notification system.

   Returns:
     T on success"
  (setf *notification-manager* (make-notification-manager))
  t)

;;; ### Send Notification

(defun send-notification (title message &key type icon action-url sound-p badge-p)
  "Send a desktop notification.

   Args:
     title: Notification title
     message: Notification body text
     type: Notification type (:message, :call, :mention, :reaction, :system)
     icon: Icon file path or NIL for default
     action-url: Optional URL/action to trigger on click
     sound-p: Play sound (default follows global setting)
     badge-p: Update app badge (default follows global setting)

   Returns:
     T on success, NIL on failure"
  (unless *notification-manager*
    (initialize-notifications))

  (let ((mgr *notification-manager*))
    ;; Check if enabled
    (unless (notif-enabled-p mgr)
      (return-from send-notification nil))

    ;; Check quiet hours
    (when (in-quiet-hours-p mgr)
      (return-from send-notification nil))

    ;; Send platform-specific notification
    (let ((success
           (case (notif-platform mgr)
             (:windows (send-windows-notification title message :icon icon))
             (:macos (send-macos-notification title message :icon icon))
             (:linux (send-linux-notification title message :icon icon))
             (otherwise
              (send-fallback-notification title message)))))
      (when success
        ;; Update counters
        (incf (notif-count mgr))
        (setf (notif-last-time mgr) (get-universal-time))
        ;; Play sound if enabled
        (when (or sound-p (notif-sound-enabled-p mgr))
          (play-notification-sound (or type :message)))
        ;; Update badge if enabled
        (when (or badge-p (notif-badge-enabled-p mgr))
          (update-notification-badge (1+ (count-unread-notifications))))
        ;; Add to history
        (add-to-notification-history title message type))
      success)))

;;; ### Windows Notifications

(defun send-windows-notification (title message &key icon)
  "Send notification on Windows using PowerShell.

   Args:
     title: Notification title
     message: Notification body
     icon: Optional icon path

   Returns:
     T on success"
  (handler-case
      (let ((script
             (format nil
                     "Add-Type -AssemblyName System.Windows.Forms~%
[System.Windows.Forms.MessageBox]::Show('~A'~% '~A')"
                     (escape-powershell-string message)
                     (escape-powershell-string title))))
        (uiop:run-program
         (list "powershell" "-Command" script)
         :output :ignore
         :error-output :ignore)
        t)
    (error (e)
      (format *error-output* "Windows notification failed: ~A~%" e)
      nil)))

(defun escape-powershell-string (string)
  "Escape string for PowerShell."
  (string-replace-all string "'" "''"))

(defun string-replace-all (string old new)
  "Replace all occurrences of old with new in string."
  (let ((re (cl-ppcre:create-scanner (cl-ppcre:quote-meta-chars old))))
    (cl-ppcre:regex-replace-all re string new)))

;;; ### macOS Notifications

(defun send-macos-notification (title message &key icon)
  "Send notification on macOS using osascript.

   Args:
     title: Notification title
     message: Notification body
     icon: Optional icon path

   Returns:
     T on success"
  (handler-case
      (let ((script
             (format nil
                     "display notification \"~A\" with title \"~A\"~@[ subtitle \"~A\"~]"
                     (escape-applescript-string message)
                     (escape-applescript-string title)
                     (if icon "Telegram" nil))))
        (uiop:run-program
         (list "osascript" "-e" script)
         :output :ignore
         :error-output :ignore)
        t)
    (error (e)
      (format *error-output* "macOS notification failed: ~A~%" e)
      nil)))

(defun escape-applescript-string (string)
  "Escape string for AppleScript."
  (string-replace-all string "\"" "\\\""))

;;; ### Linux Notifications

(defun send-linux-notification (title message &key icon)
  "Send notification on Linux using notify-send.

   Args:
     title: Notification title
     message: Notification body
     icon: Optional icon name

   Returns:
     T on success"
  (handler-case
      (let ((args (list "notify-send")))
        (when icon
          (push "-i" args)
          (push (or icon "telegram") args))
        (push title args)
        (push message args)
        (uiop:run-program
         args
         :output :ignore
         :error-output :ignore)
        t)
    (error (e)
      (format *error-output* "Linux notification failed: ~A~%" e)
      nil)))

;;; ### Fallback Notification

(defun send-fallback-notification (title message)
  "Send fallback notification to terminal.

   Args:
     title: Notification title
     message: Notification body

   Returns:
     T on success"
  (format t "~%[NOTIFICATION] ~A: ~A~%" title message)
  (finish-output)
  t)

;;; ### Notification Sound

(defun play-notification-sound (type)
  "Play notification sound.

   Args:
     type: Notification type (:message, :call, :mention, :reaction)

   Returns:
     T on success"
  (let ((sound-file (get-notification-sound type)))
    (when sound-file
      (handler-case
          (case (notif-platform *notification-manager*)
            (:windows
             (play-windows-sound sound-file))
            (:macos
             (play-macos-sound sound-file))
            (:linux
             (play-linux-sound sound-file)))
        (error (e)
          (format *error-output* "Failed to play sound: ~A~%" e))))))

(defun get-notification-sound (type)
  "Get sound file path for notification type.

   Args:
     type: Notification type

   Returns:
     Sound file path or NIL"
  (case type
    (:message "message.wav")
    (:call "call.wav")
    (:mention "mention.wav")
    (:reaction "reaction.wav")
    (otherwise "default.wav")))

(defun play-windows-sound (sound-file)
  "Play sound on Windows."
  (uiop:run-program
   (list "powershell" "-Command"
         (format nil "(New-Object Media.SoundPlayer '~A').PlaySync()" sound-file))
   :output :ignore
   :error-output :ignore))

(defun play-macos-sound (sound-file)
  "Play sound on macOS."
  (uiop:run-program
   (list "afplay" sound-file)
   :output :ignore
   :error-output :ignore))

(defun play-linux-sound (sound-file)
  "Play sound on Linux."
  (uiop:run-program
   (list "paplay" sound-file)
   :output :ignore
   :error-output :ignore))

;;; ### Badge Management

(defun update-notification-badge (count)
  "Update application badge/dock count.

   Args:
     count: Number to display

   Returns:
     T on success"
  (unless (notif-badge-enabled-p *notification-manager*)
    (return-from update-notification-badge nil))

  (case (notif-platform *notification-manager*)
    (:macos (update-macos-badge count))
    (:windows (update-windows-badge count))
    (:linux (update-linux-badge count))))

(defun update-macos-badge (count)
  "Update macOS dock badge."
  (handler-case
      (let ((script
             (if (> count 0)
                 (format nil "tell application \"System Events\" to set badge label of dock item \"Telegram\" to \"~A\"" count)
                 "tell application \"System Events\" to set badge label of dock item \"Telegram\" to \"\"")))
        (uiop:run-program
         (list "osascript" "-e" script)
         :output :ignore
         :error-output :ignore)
        t)
    (error () nil)))

(defun update-windows-badge (count)
  "Update Windows taskbar badge."
  ;; Windows 10+ toast notifications handle this automatically
  ;; For custom implementation, would need UWP APIs
  (declare (ignore count))
  nil)

(defun update-linux-badge (count)
  "Update Linux dock badge (Ubuntu/GNOME)."
  ;; Would require D-Bus integration with dock
  (declare (ignore count))
  nil)

;;; ### Quiet Hours

(defun set-quiet-hours (start-hour end-hour)
  "Set quiet hours during which notifications are silenced.

   Args:
     start-hour: Start hour (0-23)
     end-hour: End hour (0-23)

   Returns:
     T on success"
  (unless *notification-manager*
    (initialize-notifications))
  (setf (notif-quiet-start *notification-manager*) start-hour
        (notif-quiet-end *notification-manager*) end-hour)
  t)

(defun disable-quiet-hours ()
  "Disable quiet hours.

   Returns:
     T on success"
  (when *notification-manager*
    (setf (notif-quiet-start *notification-manager*) nil
          (notif-quiet-end *notification-manager*) nil))
  t)

(defun in-quiet-hours-p (mgr)
  "Check if current time is within quiet hours.

   Args:
     mgr: Notification manager instance

   Returns:
     T if in quiet hours"
  (let ((start (notif-quiet-start mgr))
        (end (notif-quiet-end mgr)))
    (if (and start end)
        (let ((current-hour (nth-value 1 (get-decoded-time))))
          (if (< start end)
              (and (>= current-hour start) (< current-hour end))
              (or (>= current-hour start) (< current-hour end))))
        nil)))

;;; ### Notification History

(defun add-to-notification-history (title message type)
  "Add notification to history.

   Args:
     title: Notification title
     message: Notification body
     type: Notification type"
  (let ((history (notif-history *notification-manager*)))
    (vector-push-extend
     (list :title title :message message :type type :time (get-universal-time))
     history)
    ;; Trim to max size
    (when (> (length history) 100)
      (adjust-array history 100 :fill-pointer 100))))

(defun get-notification-history (&key limit type)
  "Get notification history.

   Args:
     limit: Maximum notifications to return (default 50)
     type: Filter by type or NIL for all

   Returns:
     List of notification entries"
  (let ((history (notif-history *notification-manager*)))
    (loop for i from (- (length history) 1) downto 0
          for entry = (aref history i)
          when (or (null type) (eq (getf entry :type) type))
          collect entry
          into result
          when (>= (length result) (or limit 50))
          return result
          finally (return result))))

(defun clear-notification-history ()
  "Clear notification history.

   Returns:
     T on success"
  (setf (fill-pointer (notif-history *notification-manager*)) 0)
  t)

(defun count-unread-notifications ()
  "Count unread notifications.

   Returns:
     Number of unread notifications"
  ;; This would integrate with actual unread count from the app
  ;; For now, returns a simple counter
  0)

;;; ### Notification Settings UI

(defun create-notification-settings-panel (win container)
  "Create notification settings UI panel.

   Args:
     win: CLOG window
     container: Parent container

   Returns:
     Panel element"
  (declare (ignore win container))
  ;; Would create CLOG UI elements for settings
  ;; Placeholder for CLOG integration
  (format t "Notification settings panel created~%"))

(defun show-notification-preview (type)
  "Show notification preview.

   Args:
     type: Notification type to preview"
  (let ((preview-data
         (case type
           (:message '("New Message" "Hello from Telegram!"))
           (:call '("Incoming Call" "John is calling..."))
           (:mention '("You were mentioned" "Alice mentioned you in Group"))
           (:reaction '("New Reaction" "❤️ Your message"))
           (otherwise '("Test" "Test notification")))))
    (apply #'send-notification preview-data :type type)))

;;; ### Integration with Update Handler

(defun setup-notification-handlers ()
  "Setup notification handlers for update events.

   Returns:
     T on success"
  (unless *update-handler*
    (return-from setup-notification-handlers nil))

  ;; New message notification
  (register-update-handler :update-new-message
    (lambda (update)
      (let* ((message (getf update :message))
             (from (getf message :from))
             (text (getf message :text))
             (chat-id (getf message :chat-id)))
        (send-notification
         (format nil "Message from ~A" (getf from :first-name))
         (or text "[non-text message]")
         :type :message))))

  ;; Call notification
  (register-update-handler :update-new-call
    (lambda (update)
      (let ((call (getf update :call)))
        (send-notification
         "Incoming Call"
         (format nil "~A is calling..." (getf call :from-name))
         :type :call))))

  ;; Mention notification
  (register-update-handler :update-message-mention
    (lambda (update)
      (send-notification
       "You were mentioned"
       (getf update :message-text)
       :type :mention)))

  ;; Reaction notification
  (register-update-handler :update-message-reaction
    (lambda (update)
      (send-notification
       "New Reaction"
       (format nil "~A reacted to your message" (getf update :user-name))
       :type :reaction)))

  t)
