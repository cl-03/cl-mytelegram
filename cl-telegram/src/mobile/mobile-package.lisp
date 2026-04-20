;;; mobile-package.lisp --- Mobile platform integration package
;;;
;;; Provides iOS and Android integration for cl-telegram:
;;; - iOS: Push notifications, Widgets, Share Extension, Siri Shortcuts
;;; - Android: Background services, Desktop mode, Split screen, Notification channels
;;;
;;; Requirements:
;;;   - iOS: Apple Developer account, Xcode
;;;   - Android: Android SDK, Gradle

(defpackage #:cl-telegram/mobile
  (:nicknames #:cl-tg/mobile)
  (:use #:cl)
  (:export
   ;; Mobile initialization
   #:init-mobile
   #:shutdown-mobile
   #:*mobile-initialized-p*

   ;; Platform detection
   #:platform-type
   #:platform-version
   #:is-ios-p
   #:is-android-p
   #:is-mobile-p

   ;; Push notifications (iOS/Android)
   #:register-push-notifications
   #:unregister-push-notifications
   #:handle-push-notification
   #:get-push-token
   #:send-push-notification

   ;; Background services (Android)
   #:start-background-service
   #:stop-background-service
   #:is-background-service-running-p

   ;; Widgets (iOS)
   #:register-widget
   #:update-widget
   #:reload-widget

   ;; Share Extension (iOS)
   #:handle-share-extension-item
   #:get-shared-content

   ;; Siri Shortcuts (iOS)
   #:register-siri-shortcut
   #:invoke-siri-shortcut

   ;; Android specific
   #:create-notification-channel
   #:set-desktop-mode
   #:enable-split-screen

   ;; Cross-platform utilities
   #:get-device-info
   #:get-network-type
   #:is-background-p
   #:is-low-power-mode-p))

(in-package #:cl-telegram/mobile)

;;; ============================================================================
;;; Global State
;;; ============================================================================

(defvar *mobile-initialized-p* nil
  "Whether mobile integration has been initialized")

(defvar *platform-type* nil
  "Current platform: :ios, :android, :desktop, :unknown")

(defvar *platform-version* nil
  "Platform version string")

(defvar *push-token* nil
  "FCM/APNs push token")

(defvar *background-service-pid* nil
  "Background service process ID")

(defvar *widget-registry* (make-hash-table :test 'equal)
  "Registered widgets")

(defvar *siri-shortcuts* (make-hash-table :test 'equal)
  "Registered Siri shortcuts")

;;; ============================================================================
;;; Platform Detection
;;; ============================================================================

(defun detect-platform ()
  "Detect current platform.

   Returns:
     :ios, :android, :desktop, or :unknown"
  (cond
    ;; iOS detection
    ((probe-file "/var/mobile/") :ios)
    ;; Android detection
    ((probe-file "/system/bin/") :android)
    ;; Desktop fallback
    (t :desktop)))

(defun platform-type ()
  "Get current platform type.

   Returns:
     :ios, :android, :desktop, or :unknown"
  (or *platform-type*
      (setf *platform-type* (detect-platform))))

(defun platform-version ()
  "Get platform version string.

   Returns:
     Version string or NIL"
  (or *platform-version*
      #+darwin
      (handler-case
          (with-output-to-string (out)
            (uiop:run-program '("sw_vers" "-productVersion") :output out))
        (error () nil))
      #+linux
      (handler-case
          (with-output-to-string (out)
            (uiop:run-program '("getprop" "ro.build.version.release") :output out))
        (error () nil))
      nil))

(defun is-ios-p ()
  "Check if running on iOS.

   Returns:
     T if iOS, NIL otherwise"
  (eq (platform-type) :ios))

(defun is-android-p ()
  "Check if running on Android.

   Returns:
     T if Android, NIL otherwise"
  (eq (platform-type) :android))

(defun is-mobile-p ()
  "Check if running on mobile platform.

   Returns:
     T if iOS or Android, NIL otherwise"
  (member (platform-type) '(:ios :android)))

;;; ============================================================================
;;; Initialization
;;; ============================================================================

(defun init-mobile (&key apns-config fcm-config)
  "Initialize mobile platform integration.

   Args:
     apns-config: Apple Push Notification Service config (iOS)
     fcm-config: Firebase Cloud Messaging config (Android)

   Returns:
     T on success, NIL on error"
  (log:info "Initializing mobile platform: ~A" (platform-type))

  (case (platform-type)
    (:ios (init-ios apns-config))
    (:android (init-android fcm-config))
    (t (log:warn "Mobile integration not available on ~A" (platform-type))))

  (setf *mobile-initialized-p* t)
  t)

(defun shutdown-mobile ()
  "Shutdown mobile platform integration.

   Returns:
     T on success"
  (log:info "Shutting down mobile platform")

  ;; Stop background services
  (when *background-service-pid*
    (stop-background-service))

  ;; Unregister push notifications
  (unregister-push-notifications)

  (setf *mobile-initialized-p* nil)
  t)

;;; ============================================================================
;;; iOS Initialization
;;; ============================================================================

(defun init-ios (apns-config)
  "Initialize iOS integration.

   Args:
     apns-config: APNs configuration plist

   Returns:
     T on success"
  (log:info "Initializing iOS integration")

  ;; Register for push notifications
  (when apns-config
    (register-push-notifications :apns apns-config))

  ;; Register widgets
  (init-ios-widgets)

  ;; Register Siri shortcuts
  (init-siri-shortcuts)

  t)

(defun init-ios-widgets ()
  "Initialize iOS widget extension.

   Returns:
     T on success"
  (log:info "Initializing iOS widgets")
  ;; Widget registration happens via handle-widget-registration
  t)

(defun init-siri-shortcuts ()
  "Initialize Siri shortcuts.

   Returns:
     T on success"
  (log:info "Initializing Siri shortcuts")
  ;; Register default shortcuts
  t)

;;; ============================================================================
;;; Android Initialization
;;; ============================================================================

(defun init-android (fcm-config)
  "Initialize Android integration.

   Args:
     fcm-config: Firebase Cloud Messaging configuration plist

   Returns:
     T on success"
  (log:info "Initializing Android integration")

  ;; Create notification channels (Android 8.0+)
  (create-default-notification-channels)

  ;; Register for push notifications
  (when fcm-config
    (register-push-notifications :fcm fcm-config))

  t)

(defun create-default-notification-channels ()
  "Create default Android notification channels.

   Returns:
     T on success"
  (log:info "Creating Android notification channels")

  ;; Messages channel
  (create-notification-channel
   :id "messages"
   :name "Messages"
   :description "New message notifications"
   :importance :high
   :show-badge t)

  ;; Calls channel
  (create-notification-channel
   :id "calls"
   :name "Calls"
   :description "Voice and video call notifications"
   :importance :high
   :vibration-pattern t)

  ;; Mentions channel
  (create-notification-channel
   :id "mentions"
   :name "Mentions"
   :description "When you're mentioned in a group"
   :importance :default)

  ;; Silent channel
  (create-notification-channel
   :id "silent"
   :name "Silent"
   :description "Silent notifications"
   :importance :low)

  t)

;;; ============================================================================
;;; End of mobile-package.lisp
;;; ============================================================================
