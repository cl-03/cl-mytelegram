;;; mobile-package.lisp --- Package definition for cl-telegram mobile integration
;;;
;;; Mobile platform integration:
;;; - iOS: CFFI bindings for UIKit/CoreTelephony
;;; - Android: JNI bindings for Android SDK
;;; - Cross-platform: Network status, push notifications, background tasks

(in-package #:cl-telegram)

(defpackage #:cl-telegram/mobile
  (:use #:cl)
  (:export
   ;; Mobile platform detection
   #:mobile-platform-p
   #:ios-p
   #:android-p
   #:get-platform-info

   ;; iOS integration
   #:ios-init
   #:ios-cleanup
   #:ios-register-push-notification
   #:ios-handle-background-task
   #:ios-get-device-info
   #:ios-network-status

   ;; Android integration
   #:android-init
   #:android-cleanup
   #:android-register-push-notification
   #:android-handle-background-task
   #:android-get-device-info
   #:android-network-status

   ;; Push notifications
   #:register-push-notification
   #:unregister-push-notification
   #:handle-push-notification
   #:send-local-notification

   ;; Network status
   #:get-network-status
   #:network-reachable-p
   #:is-wifi-connection
   #:is-cellular-connection

   ;; Background tasks
   #:begin-background-task
   #:end-background-task
   #:schedule-background-task

   ;; Device capabilities
   #:device-has-camera-p
   #:device-has-microphone-p
   #:device-supports-video-p
   #:get-device-memory
   #:get-storage-info

   ;; File system
   #:get-app-data-directory
   #:get-cache-directory
   #:get-temp-directory
   #:save-to-photo-library
   #:load-from-photo-library

   ;; Clipboard
   #:copy-to-clipboard
   #:get-from-clipboard

   ;; Biometrics
   #:authenticate-with-biometrics
   #:biometrics-available-p

   ;; Deep linking
   #:handle-deep-link
   #:register-deep-link-scheme))

(in-package #:cl-telegram/mobile)
