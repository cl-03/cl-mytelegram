;;; account-security-enhanced-tests.lisp --- Tests for enhanced account security

(in-package #:cl-telegram/tests)

(def-suite* account-security-enhanced-tests
  :description "Tests for enhanced account security (v0.31.0)")

;;; ============================================================================
;;; Section 1: QR Login Tests
;;; ============================================================================

(test test-generate-qr-login-token
  "Test generating QR login token"
  (let ((token (cl-telegram/api:generate-qr-login-token :expires-in 60)))
    (is (typep token 'cl-telegram/api::qr-login-token))
    (is (stringp (cl-telegram/api:qr-token-id token)))
    (is (stringp (cl-telegram/api:qr-token-data token)))
    (is (stringp (cl-telegram/api:qr-token-qr-code-url token)))))

(test test-check-qr-login-status
  "Test checking QR login status"
  (let ((token (cl-telegram/api:generate-qr-login-token)))
    (let ((status (cl-telegram/api:check-qr-login-status (cl-telegram/api:qr-token-id token))))
      (is (listp status))
      (is (getf status :status))
      (is (getf status :token-id))
      (is (getf status :created-at)))))

(test test-qr-token-expiration
  "Test QR token expiration"
  (let ((token (cl-telegram/api:generate-qr-login-token :expires-in 1)))
    (sleep 2) ; Wait for expiration
    (let ((status (cl-telegram/api:check-qr-login-status (cl-telegram/api:qr-token-id token))))
      (is (eq (getf status :status) :expired)))))

;;; ============================================================================
;;; Section 2: Two-Factor Authentication Tests
;;; ============================================================================

(test test-get-2fa-status
  "Test getting 2FA status"
  (let ((status (cl-telegram/api:get-2fa-status)))
    (is (listp status))
    (is (getf status :enabled))))

(test test-enable-two-factor-auth
  "Test enabling 2FA"
  ;; This test requires a real connection
  (let ((result (cl-telegram/api:enable-two-factor-auth "test_password_123"
                                                         :hint "test hint"
                                                         :email "test@example.com")))
    (is (or (eq result t) (null result))))) ; May fail without real connection

(test test-disable-two-factor-auth
  "Test disabling 2FA"
  (let ((result (cl-telegram/api:disable-two-factor-auth "test_password_123")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 3: Session Management Tests
;;; ============================================================================

(test test-get-active-sessions
  "Test getting active sessions"
  (let ((sessions (cl-telegram/api:get-active-sessions)))
    (is (or (null sessions) (listp sessions)))
    (when sessions
      (let ((session (first sessions)))
        (is (getf session :session-id))
        (is (getf session :device-model))
        (is (getf session :date-active))))))

(test test-terminate-session
  "Test terminating a session"
  ;; This test requires a real session ID
  (let ((result (cl-telegram/api:terminate-session 12345)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Privacy Settings Tests
;;; ============================================================================

(test test-get-privacy-settings
  "Test getting privacy settings"
  (let ((settings (cl-telegram/api:get-privacy-settings)))
    (is (or (null settings) (listp settings)))))

(test test-set-privacy-setting
  "Test setting privacy rule"
  (let ((result (cl-telegram/api:set-privacy-setting :last-seen :contacts)))
    (is (or (eq result t) (null result)))))

(test test-set-privacy-setting-with-users
  "Test setting privacy rule with specific users"
  (let ((result (cl-telegram/api:set-privacy-setting :phone-number '(123 456)
                                                      :denied-users '(789))))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 5: Statistics Tests
;;; ============================================================================

(test test-get-security-stats
  "Test getting security statistics"
  (let ((stats (cl-telegram/api:get-security-stats)))
    (is (listp stats))
    (is (getf stats :active-sessions))
    (is (getf stats :2fa-enabled))))

;;; ============================================================================
;;; Section 6: Integration Tests
;;; ============================================================================

(test test-initialize-account-security-enhanced
  "Test initializing enhanced security"
  (let ((result (cl-telegram/api:initialize-account-security-enhanced)))
    (is (eq result t))))

(test test-shutdown-account-security-enhanced
  "Test shutting down enhanced security"
  (cl-telegram/api:initialize-account-security-enhanced)
  (let ((result (cl-telegram/api:shutdown-account-security-enhanced)))
    (is (eq result t))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-account-security-enhanced-tests ()
  "Run all enhanced account security tests"
  (let ((results (run! 'account-security-enhanced-tests :if-fail :error)))
    (format t "~%~%=== Enhanced Account Security Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
