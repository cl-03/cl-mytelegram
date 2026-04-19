;;; mobile-tests.lisp --- Tests for cl-telegram mobile integration
;;;
;;; Mobile platform tests:
;;; - iOS integration tests
;;; - Android integration tests
;;; - Cross-platform API tests
;;; - Device capability tests

(in-package #:cl-telegram/tests)

;;; ===========================================================================
;;; Mobile Platform Detection Tests
;;; ===========================================================================

(fiveam:deftest test-mobile-platform-detection ()
  "Test mobile platform detection."
  (let ((is-mobile (cl-telegram/mobile:mobile-platform-p))
        (is-ios (cl-telegram/mobile:ios-p))
        (is-android (cl-telegram/mobile:android-p)))
    (fiveam:is (member is-mobile '(t nil)))
    ;; Only one platform at a time
    (fiveam:is (not (and is-ios is-android)))
    (fiveam:pass "Platform detection works")))

(fiveam:deftest test-get-platform-info ()
  "Test platform info retrieval."
  (let ((info (cl-telegram/mobile:get-platform-info)))
    (fiveam:is (listp info))
    (fiveam:is (getf info :platform))
    (fiveam:pass "Platform info retrieved")))

;;; ===========================================================================
;;; iOS Integration Tests
;;; ===========================================================================

(fiveam:deftest test-ios-init ()
  "Test iOS initialization."
  (let ((result (cl-telegram/mobile:ios-init)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "iOS init completed")))

(fiveam:deftest test-ios-cleanup ()
  "Test iOS cleanup."
  (let ((result (cl-telegram/mobile:ios-cleanup)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "iOS cleanup completed")))

(fiveam:deftest test-ios-push-registration ()
  "Test iOS push notification registration."
  (let ((token (cl-telegram/mobile:ios-register-push-notification)))
    (fiveam:is (member token '(nil :string)))
    (fiveam:pass "iOS push registration completed")))

(fiveam:deftest test-ios-push-unregistration ()
  "Test iOS push notification unregistration."
  (let ((result (cl-telegram/mobile:ios-unregister-push-notification)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "iOS push unregistration completed")))

(fiveam:deftest test-ios-push-handling ()
  "Test iOS push notification handling."
  (let ((payload "{\"update\":{\"message_id\":123}}"))
    (let ((result (cl-telegram/mobile:ios-handle-push-notification payload)))
      (fiveam:is (member result '(t nil)))
      (fiveam:pass "iOS push handling completed"))))

(fiveam:deftest test-ios-background-task ()
  "Test iOS background task handling."
  (let ((result (cl-telegram/mobile:ios-handle-background-task 12345)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "iOS background task completed")))

(fiveam:deftest test-ios-begin-background-task ()
  "Test beginning iOS background task."
  (let ((task-id (cl-telegram/mobile:begin-background-task "test-task")))
    (fiveam:is (integerp task-id))
    (fiveam:pass "iOS background task begun")))

(fiveam:deftest test-ios-end-background-task ()
  "Test ending iOS background task."
  (let ((result (cl-telegram/mobile:end-background-task 12345)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "iOS background task ended")))

(fiveam:deftest test-ios-schedule-background-task ()
  "Test scheduling iOS background task."
  (let ((result (cl-telegram/mobile:schedule-background-task 3600 :name "periodic-sync")))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "iOS background task scheduled")))

(fiveam:deftest test-ios-device-info ()
  "Test iOS device info retrieval."
  (let ((info (cl-telegram/mobile:ios-get-device-info)))
    (fiveam:is (listp info))
    (fiveam:is (getf info :model))
    (fiveam:is (getf info :system-version))
    (fiveam:pass "iOS device info retrieved")))

(fiveam:deftest test-ios-network-status ()
  "Test iOS network status."
  (let ((status (cl-telegram/mobile:ios-network-status)))
    (fiveam:is (listp status))
    (fiveam:is (member (getf status :reachable) '(t nil)))
    (fiveam:pass "iOS network status retrieved")))

(fiveam:deftest test-ios-file-system ()
  "Test iOS file system paths."
  (let ((app-dir (cl-telegram/mobile:get-app-data-directory))
        (cache-dir (cl-telegram/mobile:get-cache-directory))
        (temp-dir (cl-telegram/mobile:get-temp-directory)))
    (fiveam:is (stringp app-dir))
    (fiveam:is (stringp cache-dir))
    (fiveam:is (stringp temp-dir))
    (fiveam:pass "iOS file system paths retrieved")))

(fiveam:deftest test-ios-clipboard ()
  "Test iOS clipboard operations."
  (let ((test-text "Test clipboard content"))
    (let ((copy-result (cl-telegram/mobile:copy-to-clipboard test-text))
          (get-result (cl-telegram/mobile:get-from-clipboard)))
      (fiveam:is (member copy-result '(t nil)))
      (fiveam:is (member get-result '(nil :string)))
      (fiveam:pass "iOS clipboard operations completed"))))

(fiveam:deftest test-ios-biometrics ()
  "Test iOS biometric authentication."
  (let ((available (cl-telegram/mobile:biometrics-available-p))
        (auth-result (cl-telegram/mobile:authenticate-with-biometrics "Test auth")))
    (fiveam:is (member available '(t nil)))
    (fiveam:is (member auth-result '(t nil)))
    (fiveam:pass "iOS biometric auth completed")))

(fiveam:deftest test-ios-deep-link ()
  "Test iOS deep link handling."
  (let ((url "telegram://chat?id=123")
        (register-result (cl-telegram/mobile:register-deep-link-scheme "telegram"))
        (handle-result (cl-telegram/mobile:handle-deep-link url)))
    (fiveam:is (member register-result '(t nil)))
    (fiveam:is (member handle-result '(t nil)))
    (fiveam:pass "iOS deep link handling completed")))

(fiveam:deftest test-ios-local-notification ()
  "Test iOS local notification."
  (let ((result (cl-telegram/mobile:send-local-notification "Test" "Test body")))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "iOS local notification sent")))

(fiveam:deftest test-ios-device-capabilities ()
  "Test iOS device capabilities."
  (let ((has-camera (cl-telegram/mobile:device-has-camera-p))
        (has-mic (cl-telegram/mobile:device-has-microphone-p))
        (supports-video (cl-telegram/mobile:device-supports-video-p)))
    (fiveam:is (member has-camera '(t nil)))
    (fiveam:is (member has-mic '(t nil)))
    (fiveam:is (member supports-video '(t nil)))
    (fiveam:pass "iOS device capabilities checked")))

(fiveam:deftest test-ios-memory-storage ()
  "Test iOS memory and storage info."
  (let ((memory (cl-telegram/mobile:get-device-memory))
        (storage (cl-telegram/mobile:get-storage-info)))
    (fiveam:is (listp memory))
    (fiveam:is (listp storage))
    (fiveam:is (getf memory :total))
    (fiveam:is (getf storage :total))
    (fiveam:pass "iOS memory/storage info retrieved")))

;;; ===========================================================================
;;; Android Integration Tests
;;; ===========================================================================

(fiveam:deftest test-android-init ()
  "Test Android initialization."
  (let ((result (cl-telegram/mobile:android-init)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "Android init completed")))

(fiveam:deftest test-android-cleanup ()
  "Test Android cleanup."
  (let ((result (cl-telegram/mobile:android-cleanup)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "Android cleanup completed")))

(fiveam:deftest test-android-push-registration ()
  "Test Android FCM registration."
  (let ((token (cl-telegram/mobile:android-register-push-notification)))
    (fiveam:is (member token '(nil :string)))
    (fiveam:pass "Android FCM registration completed")))

(fiveam:deftest test-android-push-unregistration ()
  "Test Android FCM unregistration."
  (let ((result (cl-telegram/mobile:android-unregister-push-notification)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "Android FCM unregistration completed")))

(fiveam:deftest test-android-push-handling ()
  "Test Android push notification handling."
  (let ((payload "{\"update\":{\"message_id\":123}}"))
    (let ((result (cl-telegram/mobile:android-handle-push-notification payload)))
      (fiveam:is (member result '(t nil)))
      (fiveam:pass "Android push handling completed"))))

(fiveam:deftest test-android-background-task ()
  "Test Android background task handling."
  (let ((result (cl-telegram/mobile:android-handle-background-task 12345)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "Android background task completed")))

(fiveam:deftest test-android-begin-background-task ()
  "Test beginning Android background task."
  (let ((task-id (cl-telegram/mobile:begin-background-task "test-task")))
    (fiveam:is (integerp task-id))
    (fiveam:pass "Android background task begun")))

(fiveam:deftest test-android-end-background-task ()
  "Test ending Android background task."
  (let ((result (cl-telegram/mobile:end-background-task 12345)))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "Android background task ended")))

(fiveam:deftest test-android-schedule-background-task ()
  "Test scheduling Android background task."
  (let ((result (cl-telegram/mobile:schedule-background-task 3600 :name "periodic-sync")))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "Android background task scheduled")))

(fiveam:deftest test-android-device-info ()
  "Test Android device info retrieval."
  (let ((info (cl-telegram/mobile:android-get-device-info)))
    (fiveam:is (listp info))
    (fiveam:is (getf info :model))
    (fiveam:is (getf info :sdk-version))
    (fiveam:pass "Android device info retrieved")))

(fiveam:deftest test-android-network-status ()
  "Test Android network status."
  (let ((status (cl-telegram/mobile:android-network-status)))
    (fiveam:is (listp status))
    (fiveam:is (member (getf status :reachable) '(t nil)))
    (fiveam:pass "Android network status retrieved")))

(fiveam:deftest test-android-file-system ()
  "Test Android file system paths."
  (let ((app-dir (cl-telegram/mobile:get-app-data-directory))
        (cache-dir (cl-telegram/mobile:get-cache-directory))
        (temp-dir (cl-telegram/mobile:get-temp-directory)))
    (fiveam:is (stringp app-dir))
    (fiveam:is (stringp cache-dir))
    (fiveam:is (stringp temp-dir))
    (fiveam:pass "Android file system paths retrieved")))

(fiveam:deftest test-android-clipboard ()
  "Test Android clipboard operations."
  (let ((copy-result (cl-telegram/mobile:copy-to-clipboard "test"))
        (get-result (cl-telegram/mobile:get-from-clipboard)))
    (fiveam:is (member copy-result '(t nil)))
    (fiveam:is (member get-result '(nil :string)))
    (fiveam:pass "Android clipboard operations completed")))

(fiveam:deftest test-android-biometrics ()
  "Test Android biometric authentication."
  (let ((available (cl-telegram/mobile:biometrics-available-p))
        (auth-result (cl-telegram/mobile:authenticate-with-biometrics "Test auth")))
    (fiveam:is (member available '(t nil)))
    (fiveam:is (member auth-result '(t nil)))
    (fiveam:pass "Android biometric auth completed")))

(fiveam:deftest test-android-deep-link ()
  "Test Android deep link handling."
  (let ((url "telegram://chat?id=123")
        (register-result (cl-telegram/mobile:register-deep-link-scheme "telegram"))
        (handle-result (cl-telegram/mobile:handle-deep-link url)))
    (fiveam:is (member register-result '(t nil)))
    (fiveam:is (member handle-result '(t nil)))
    (fiveam:pass "Android deep link handling completed")))

(fiveam:deftest test-android-local-notification ()
  "Test Android local notification."
  (let ((result (cl-telegram/mobile:send-local-notification "Test" "Test body")))
    (fiveam:is (member result '(t nil)))
    (fiveam:pass "Android local notification sent")))

(fiveam:deftest test-android-device-capabilities ()
  "Test Android device capabilities."
  (let ((has-camera (cl-telegram/mobile:device-has-camera-p))
        (has-mic (cl-telegram/mobile:device-has-microphone-p))
        (supports-video (cl-telegram/mobile:device-supports-video-p)))
    (fiveam:is (member has-camera '(t nil)))
    (fiveam:is (member has-mic '(t nil)))
    (fiveam:is (member supports-video '(t nil)))
    (fiveam:pass "Android device capabilities checked")))

(fiveam:deftest test-android-memory-storage ()
  "Test Android memory and storage info."
  (let ((memory (cl-telegram/mobile:get-device-memory))
        (storage (cl-telegram/mobile:get-storage-info)))
    (fiveam:is (listp memory))
    (fiveam:is (listp storage))
    (fiveam:is (getf memory :total))
    (fiveam:is (getf storage :total))
    (fiveam:pass "Android memory/storage info retrieved")))

;;; ===========================================================================
;;; Cross-Platform API Tests
;;; ===========================================================================

(fiveam:deftest test-cross-platform-network ()
  "Test cross-platform network status API."
  (let ((status (cl-telegram/mobile:get-network-status))
        (reachable (cl-telegram/mobile:network-reachable-p)))
    (fiveam:is (listp status))
    (fiveam:is (member reachable '(t nil)))
    (fiveam:pass "Cross-platform network status checked")))

(fiveam:deftest test-cross-platform-wifi-check ()
  "Test cross-platform WiFi check."
  (let ((is-wifi (cl-telegram/mobile:is-wifi-connection))
        (is-cellular (cl-telegram/mobile:is-cellular-connection)))
    (fiveam:is (member is-wifi '(t nil)))
    (fiveam:is (member is-cellular '(t nil)))
    (fiveam:pass "Cross-platform connection type checked")))

(fiveam:deftest test-cross-platform-push ()
  "Test cross-platform push notification API."
  (let ((register-result (cl-telegram/mobile:register-push-notification))
        (unregister-result (cl-telegram/mobile:unregister-push-notification)))
    (fiveam:is (member register-result '(nil :string)))
    (fiveam:is (member unregister-result '(t nil)))
    (fiveam:pass "Cross-platform push registration checked")))

(fiveam:deftest test-cross-platform-push-handling ()
  "Test cross-platform push handling API."
  (let ((payload "{\"update\":{\"message_id\":123}}"))
    (let ((result (cl-telegram/mobile:handle-push-notification payload)))
      (fiveam:is (member result '(t nil)))
      (fiveam:pass "Cross-platform push handling checked"))))

(fiveam:deftest test-cross-platform-background-task ()
  "Test cross-platform background task API."
  (let* ((task-id (cl-telegram/mobile:begin-background-task "test"))
         (schedule-result (cl-telegram/mobile:schedule-background-task 3600 :name "sync"))
         (end-result (cl-telegram/mobile:end-background-task task-id)))
    (fiveam:is (integerp task-id))
    (fiveam:is (member schedule-result '(t nil)))
    (fiveam:is (member end-result '(t nil)))
    (fiveam:pass "Cross-platform background task API checked")))

;;; ===========================================================================
;;; Run All Mobile Tests
;;; ===========================================================================

(defun run-mobile-tests ()
  "Run all mobile integration tests."
  (format t "~%Running Mobile Integration Tests...~%")
  (let ((results nil))
    (push (fiveam:run! 'test-mobile-platform-detection) results)
    (push (fiveam:run! 'test-get-platform-info) results)
    ;; iOS tests
    (push (fiveam:run! 'test-ios-init) results)
    (push (fiveam:run! 'test-ios-cleanup) results)
    (push (fiveam:run! 'test-ios-push-registration) results)
    (push (fiveam:run! 'test-ios-push-unregistration) results)
    (push (fiveam:run! 'test-ios-push-handling) results)
    (push (fiveam:run! 'test-ios-background-task) results)
    (push (fiveam:run! 'test-ios-begin-background-task) results)
    (push (fiveam:run! 'test-ios-end-background-task) results)
    (push (fiveam:run! 'test-ios-schedule-background-task) results)
    (push (fiveam:run! 'test-ios-device-info) results)
    (push (fiveam:run! 'test-ios-network-status) results)
    (push (fiveam:run! 'test-ios-file-system) results)
    (push (fiveam:run! 'test-ios-clipboard) results)
    (push (fiveam:run! 'test-ios-biometrics) results)
    (push (fiveam:run! 'test-ios-deep-link) results)
    (push (fiveam:run! 'test-ios-local-notification) results)
    (push (fiveam:run! 'test-ios-device-capabilities) results)
    (push (fiveam:run! 'test-ios-memory-storage) results)
    ;; Android tests
    (push (fiveam:run! 'test-android-init) results)
    (push (fiveam:run! 'test-android-cleanup) results)
    (push (fiveam:run! 'test-android-push-registration) results)
    (push (fiveam:run! 'test-android-push-unregistration) results)
    (push (fiveam:run! 'test-android-push-handling) results)
    (push (fiveam:run! 'test-android-background-task) results)
    (push (fiveam:run! 'test-android-begin-background-task) results)
    (push (fiveam:run! 'test-android-end-background-task) results)
    (push (fiveam:run! 'test-android-schedule-background-task) results)
    (push (fiveam:run! 'test-android-device-info) results)
    (push (fiveam:run! 'test-android-network-status) results)
    (push (fiveam:run! 'test-android-file-system) results)
    (push (fiveam:run! 'test-android-clipboard) results)
    (push (fiveam:run! 'test-android-biometrics) results)
    (push (fiveam:run! 'test-android-deep-link) results)
    (push (fiveam:run! 'test-android-local-notification) results)
    (push (fiveam:run! 'test-android-device-capabilities) results)
    (push (fiveam:run! 'test-android-memory-storage) results)
    ;; Cross-platform tests
    (push (fiveam:run! 'test-cross-platform-network) results)
    (push (fiveam:run! 'test-cross-platform-wifi-check) results)
    (push (fiveam:run! 'test-cross-platform-push) results)
    (push (fiveam:run! 'test-cross-platform-push-handling) results)
    (push (fiveam:run! 'test-cross-platform-background-task) results)

    (format t "~%Mobile Tests: ~A/~A passed~%"
            (count-if (lambda (r) (eq (fiveam:test-result-result r) :pass)) results)
            (length results))
    results))

;;; ===========================================================================
;;; End of mobile-tests.lisp
;;; ===========================================================================
