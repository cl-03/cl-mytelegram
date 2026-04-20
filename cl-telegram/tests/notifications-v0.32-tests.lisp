;;; notifications-v0.32-tests.lisp --- Tests for notifications v0.32.0 enhancements

(in-package #:cl-telegram/tests)

(def-suite* notifications-v0.32-tests
  :description "Tests for notifications v0.32.0 enhancements")

;;; ============================================================================
;;; Section 1: Silent Mode Tests
;;; ============================================================================

(test test-enable-silent-mode
  "Test enabling silent mode"
  (let ((result (cl-telegram/api:enable-silent-mode :duration-minutes 60)))
    (is (eq result t))))

(test test-disable-silent-mode
  "Test disabling silent mode"
  (cl-telegram/api:enable-silent-mode)
  (let ((result (cl-telegram/api:disable-silent-mode)))
    (is (eq result t))))

(test test-get-silent-mode-status
  "Test getting silent mode status"
  (cl-telegram/api:enable-silent-mode :duration-minutes 30)
  (let ((status (cl-telegram/api:get-silent-mode-status)))
    (is (listp status))
    (is (getf status :enabled))
    (is (getf status :until))
    (is (getf status :remaining-seconds))))

(test test-is-silent-mode-active-p
  "Test checking if silent mode is active"
  (cl-telegram/api:enable-silent-mode :duration-minutes 60)
  (let ((active (cl-telegram/api:is-silent-mode-active-p)))
    (is (eq active t))))

;;; ============================================================================
;;; Section 2: Peer Notification Settings Tests
;;; ============================================================================

(test test-get-peer-notify-settings
  "Test getting peer notification settings"
  (let ((settings (cl-telegram/api:get-peer-notify-settings 123456)))
    (is (or (null settings) (listp settings)))))

(test test-set-peer-notify-settings
  "Test setting peer notification settings"
  (let ((result (cl-telegram/api:set-peer-notify-settings 123456
                                                           :mute-until (+ (get-universal-time) 3600)
                                                           :show-preview nil
                                                           :sound-enabled nil)))
    (is (eq result t))))

(test test-is-peer-muted-p
  "Test checking if peer is muted"
  (cl-telegram/api:set-peer-notify-settings 123456 :mute-until (+ (get-universal-time) 3600))
  (let ((muted (cl-telegram/api:is-peer-muted-p 123456)))
    (is (eq muted t))))

;;; ============================================================================
;;; Section 3: Global Notification Settings Tests
;;; ============================================================================

(test test-get-notify-settings
  "Test getting notification settings"
  (let ((settings (cl-telegram/api:get-notify-settings :scope :global)))
    (is (or (null settings) (listp settings)))))

(test test-update-notify-settings
  "Test updating notification settings"
  (let ((result (cl-telegram/api:update-notify-settings :global
                                                         :show-preview nil
                                                         :sound-enabled nil
                                                         :priority :high)))
    (is (eq result t))))

(test test-reset-notify-settings
  "Test resetting notification settings"
  (cl-telegram/api:update-notify-settings :global :show-preview nil)
  (let ((result (cl-telegram/api:reset-notify-settings :scope :global)))
    (is (eq result t))))

(test test-get-global-notify-settings
  "Test getting global notification settings"
  (let ((settings (cl-telegram/api:get-global-notify-settings)))
    (is (or (null settings) (listp settings)))))

(test test-set-global-notify-settings
  "Test setting global notification settings"
  (let ((result (cl-telegram/api:set-global-notify-settings nil)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Notification Stats Tests
;;; ============================================================================

(test test-get-notification-stats
  "Test getting notification statistics"
  (let ((stats (cl-telegram/api:get-notification-stats)))
    (is (listp stats))
    (is (getf stats :total-peers))
    (is (getf stats :muted-peers))
    (is (getf stats :silent-mode-active))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-notifications-v0.32-tests ()
  "Run all notifications v0.32.0 tests"
  (let ((results (run! 'notifications-v0.32-tests :if-fail :error)))
    (format t "~%~%=== Notifications v0.32.0 Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
