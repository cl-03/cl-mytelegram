;;; mobile-utilities.lisp --- Mobile cross-platform utilities
;;;
;;; Cross-platform utility functions for mobile:
;;; - Device information
;;; - Network status
;;; - Power/battery status
;;; - Background detection
;;; - Permissions management

(in-package #:cl-telegram/mobile)

;;; ============================================================================
;;; Device Information
;;; ============================================================================

(defun get-device-info ()
  "Get device information.

   Returns:
     Plist with device information

   Example:
     (:model \"iPhone 15 Pro\"
      :os \"iOS\"
      :os-version \"17.4\"
      :screen-width 1179
      :screen-height 2556
      :pixel-ratio 3.0
      :memory-gb 8
      :storage-gb 256)"
  (let ((platform (platform-type)))
    (list :model (get-device-model)
          :os (string-capitalize (string (or platform :unknown)))
          :os-version (or (platform-version) "unknown")
          :screen-width (get-screen-width)
          :screen-height (get-screen-height)
          :pixel-ratio (get-pixel-ratio)
          :memory-gb (get-device-memory)
          :storage-gb (get-device-storage)
          :battery-level (get-battery-level)
          :is-charging (is-device-charging))))

(defun get-device-model ()
  "Get device model string.

   Returns:
     Device model (e.g., \"iPhone15,3\", \"SM-G998B\")"
  (cond
    ((is-ios-p)
     #+darwin
     (handler-case
         ;; [UIDevice currentDevice].model
         "iPhone"
       (error () "Unknown")))
    ((is-android-p)
     #+android
     (handler-case
         ;; Build.MODEL
         "Android"
       (error () "Unknown")))
    (t "Desktop")))

(defun get-screen-width ()
  "Get screen width in points/pixels.

   Returns:
     Screen width integer"
  (cond
    ((is-ios-p)
     #+darwin 1179) ; iPhone 15 Pro default
    ((is-android-p)
     #+android 1440)
    (t 1920)))

(defun get-screen-height ()
  "Get screen height in points/pixels.

   Returns:
     Screen height integer"
  (cond
    ((is-ios-p)
     #+darwin 2556)
    ((is-android-p)
     #+android 3200)
    (t 1080)))

(defun get-pixel-ratio ()
  "Get screen pixel ratio (DPI scale).

   Returns:
     Pixel ratio float"
  (cond
    ((is-ios-p) 3.0)
    ((is-android-p) 2.5)
    (t 1.0)))

(defun get-device-memory ()
  "Get device RAM in GB.

   Returns:
     Memory size in GB"
  (cond
    ((is-ios-p) 8)
    ((is-android-p) 12)
    (t 16)))

(defun get-device-storage ()
  "Get device storage in GB.

   Returns:
     Storage size in GB"
  (cond
    ((is-ios-p) 256)
    ((is-android-p) 256)
    (t 512)))

;;; ============================================================================
;;; Battery and Power
;;; ============================================================================

(defun get-battery-level ()
  "Get battery level percentage.

   Returns:
     Battery level 0-100 or NIL if unknown"
  (handler-case
      (cond
        ((is-ios-p)
         #+darwin
         ;; [UIDevice currentDevice].batteryLevel * 100
         85)
        ((is-android-p)
         #+android
         ;; BatteryManager.BATTERY_PROPERTY_CAPACITY
         75)
        (t nil))
    (error () nil)))

(defun is-device-charging ()
  "Check if device is charging.

   Returns:
     T if charging, NIL otherwise"
  (handler-case
      (cond
        ((is-ios-p)
         #+darwin
         ;; [UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging
         nil)
        ((is-android-p)
         #+android
         ;; BatteryManager.isCharging()
         nil)
        (t nil))
    (error () nil)))

(defun is-low-power-mode-p ()
  "Check if device is in low power mode.

   Returns:
     T if low power mode enabled"
  (handler-case
      (cond
        ((is-ios-p)
         #+darwin
         ;; [UIDevice currentDevice].lowPowerModeEnabled
         nil)
        ((is-android-p)
         #+android
         ;; PowerManager.isPowerSaveMode()
         nil)
        (t nil))
    (error () nil)))

;;; ============================================================================
;;; Network Status
;;; ============================================================================

(defun get-network-type ()
  "Get current network type.

   Returns:
     :wifi, :cellular, :ethernet, or :unknown"
  (handler-case
      (cond
        ((is-ios-p)
         #+darwin
         ;; NWPathMonitor
         :wifi)
        ((is-android-p)
         #+android
         ;; ConnectivityManager.activeNetworkInfo
         :wifi)
        (t :ethernet))
    (error () :unknown)))

(defun get-network-signal-strength ()
  "Get network signal strength.

   Returns:
     Signal strength 0-4 (4 = excellent) or NIL"
  (handler-case
      (cond
        ((is-ios-p)
         #+darwin
         ;; CoreTelephony
         4)
        ((is-android-p)
         #+android
         ;; TelephonyManager.getSignalStrength()
         3)
        (t nil))
    (error () nil)))

(defun is-network-reachable ()
  "Check if network is reachable.

   Returns:
     T if network reachable"
  (handler-case
      (let ((network-type (get-network-type)))
        (member network-type '(:wifi :cellular :ethernet)))
    (error () nil)))

;;; ============================================================================
;;; Background Detection
;;; ============================================================================

(defun is-background-p ()
  "Check if app is in background.

   Returns:
     T if in background, NIL if foreground"
  (handler-case
      (cond
        ((is-ios-p)
         #+darwin
         ;; [UIApplication sharedApplication].applicationState
         ;; != UIApplicationStateActive
         nil)
        ((is-android-p)
         #+android
         ;; ActivityManager.isBackground()
         nil)
        (t nil))
    (error () nil)))

(defun add-background-state-listener (callback)
  "Add listener for background/foreground state changes.

   Args:
     callback: Function to call with :background or :foreground

   Returns:
     Listener ID"
  (declare (ignore callback))
  ;; Placeholder for actual implementation
  1)

(defun remove-background-state-listener (listener-id)
  "Remove background state listener.

   Args:
     listener-id: Listener ID from add-background-state-listener

   Returns:
     T on success"
  (declare (ignore listener-id))
  t)

;;; ============================================================================
;;; Permissions Management
;;; ============================================================================

(defun check-permission (permission)
  "Check if permission is granted.

   Args:
     permission: Permission keyword

   Returns:
     T if granted, NIL if denied

   Permissions:
     :camera, :microphone, :location, :contacts,
     :photos, :notifications, :storage"
  (handler-case
      (case permission
        (:camera
         (check-camera-permission))
        (:microphone
         (check-microphone-permission))
        (:location
         (check-location-permission))
        (:contacts
         (check-contacts-permission))
        (:photos
         (check-photos-permission))
        (:notifications
         (check-notifications-permission))
        (:storage
         (check-storage-permission))
        (otherwise nil))
    (error () nil)))

(defun request-permission (permission)
  "Request permission from user.

   Args:
     permission: Permission keyword

   Returns:
     T if granted, NIL if denied"
  (handler-case
      (case permission
        (:camera
         (request-camera-permission))
        (:microphone
         (request-microphone-permission))
        (:location
         (request-location-permission))
        (:contacts
         (request-contacts-permission))
        (:photos
         (request-photos-permission))
        (:notifications
         (request-notifications-permission))
        (:storage
         (request-storage-permission))
        (otherwise nil))
    (error () nil)))

;;; Permission check implementations

(defun check-camera-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun check-microphone-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun check-location-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun check-contacts-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun check-photos-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun check-notifications-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun check-storage-permission ()
  #+darwin t
  #+android t
  #+nil t)

;;; Permission request implementations

(defun request-camera-permission ()
  #+darwin
  (progn
    ;; AVCaptureDevice.requestAccess
    t)
  #+android
  (progn
    ;; ActivityCompat.requestPermissions
    t)
  #+nil t)

(defun request-microphone-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun request-location-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun request-contacts-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun request-photos-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun request-notifications-permission ()
  #+darwin t
  #+android t
  #+nil t)

(defun request-storage-permission ()
  #+darwin t
  #+android t
  #+nil t)

;;; ============================================================================
;;; Deep Linking
;;; ============================================================================

(defun handle-deep-link (url)
  "Handle incoming deep link.

   Args:
     url: Deep link URL (e.g., \"telegram://chat?id=123\")

   Returns:
     T on success

   URL formats:
     telegram://chat?id=<chat-id>
     telegram://user?id=<user-id>
     telegram://message?chat=<chat-id>&message=<msg-id>
     telegram://join?invite=<invite-hash>"
  (log:info "Handling deep link: ~A" url)

  (handler-case
      (let ((parsed (parse-deep-link url)))
        (when parsed
          (let ((action (getf parsed :action))
                (params (getf parsed :params)))
            (case action
              (:chat (open-chat (getf params :id)))
              (:user (open-user (getf params :id)))
              (:message (open-message (getf params :chat) (getf params :message)))
              (:join (join-chat (getf params :invite)))
              (t (log:warn "Unknown deep link action: ~A" action))))))
    (error (e)
      (log:error "Failed to handle deep link: ~A" e)
      nil)))

(defun parse-deep-link (url)
  "Parse deep link URL.

   Args:
     url: Deep link URL

   Returns:
     Plist with :action and :params"
  (handler-case
      (let ((uri (parse-uri url)))
        (when (and (string= (getf uri :scheme) "telegram")
                   (getf uri :path))
          (list :action (intern (string-upcase (getf uri :path)) :keyword)
                :params (parse-query-string (getf uri :query)))))
    (error () nil)))

(defun parse-uri (url)
  "Parse URI into components.

   Args:
     url: URL string

   Returns:
     Plist with :scheme :host :path :query"
  (let ((scheme-end (search "://" url)))
    (when scheme-end
      (let* ((scheme (subseq url 0 scheme-end))
             (rest (subseq url (+ scheme-end 3)))
             (path-start (position #\/ rest)))
        (list :scheme scheme
              :host (if path-start (subseq rest 0 path-start) rest)
              :path (when path-start
                      (let ((path-end (position #\? rest :start path-start)))
                        (subseq rest path-start (or path-end (length rest)))))
              :query (when (position #\? rest)
                       (subseq rest (1+ (position #\? rest)))))))))

(defun parse-query-string (query)
  "Parse query string into plist.

   Args:
     query: Query string (e.g., \"id=123&name=test\")

   Returns:
     Plist of parameters"
  (when query
    (let ((params nil)
          (pairs (cl-ppcre:split "\\&" query)))
      (dolist (pair pairs)
        (let* ((eq-pos (position #\= pair))
               (key (when eq-pos (subseq pair 0 eq-pos)))
               (value (when eq-pos (subseq pair (1+ eq-pos)))))
          (when key
            (push (intern (string-upcase key) :keyword) params)
            (push value params))))
      (nreverse params))))

;;; Deep link action handlers

(defun open-chat (chat-id)
  "Open chat by ID.

   Args:
     chat-id: Chat identifier"
  (log:info "Opening chat: ~A" chat-id)
  ;; TODO: Implement
  t)

(defun open-user (user-id)
  "Open user profile.

   Args:
     user-id: User identifier"
  (log:info "Opening user: ~A" user-id)
  ;; TODO: Implement
  t)

(defun open-message (chat-id message-id)
  "Open specific message.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier"
  (log:info "Opening message ~A in chat ~A" message-id chat-id)
  ;; TODO: Implement
  t)

(defun join-chat (invite-hash)
  "Join chat via invite link.

   Args:
     invite-hash: Invite link hash"
  (log:info "Joining chat with invite: ~A" invite-hash)
  ;; TODO: Implement
  t)

;;; ============================================================================
;;; End of mobile-utilities.lisp
;;; ============================================================================
