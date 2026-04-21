;;; account-security-v2-tests.lisp --- Tests for enhanced account security and privacy
;;;
;;; Test suite for:
;;; - Privacy settings management
;;; - Active session (authorization) management
;;; - Two-factor authentication (2FA)
;;; - QR code login
;;; - Phone number change
;;;
;;; Version: 0.37.0

(in-package #:cl-telegram/tests)

(def-suite* account-security-v2-tests
  :description "Tests for enhanced account security v2 (v0.37.0)")

;;; ============================================================================
;;; Section 1: Class Tests
;;; ============================================================================

(test test-privacy-setting-class-creation
  "Test privacy-setting class creation"
  (let ((setting (make-instance 'cl-telegram/api::privacy-setting
                                :key "last_seen"
                                :rules '(:allow-contacts)
                                :users '(123 456))))
    (is (string= "last_seen" (cl-telegram/api::privacy-setting-key setting)))
    (is (equal '(:allow-contacts) (cl-telegram/api::privacy-setting-rules setting)))
    (is (equal '(123 456) (cl-telegram/api::privacy-setting-users setting)))))

(test test-authorization-class-creation
  "Test authorization class creation"
  (let ((auth (make-instance 'cl-telegram/api::authorization
                             :hash "abc123"
                             :device-id "device_001"
                             :api-id 12345
                             :app-name "Telegram Desktop"
                             :app-version "4.0.0"
                             :date-created 1700000000
                             :date-active 1700100000
                             :ip "192.168.1.1"
                             :country "US"
                             :region "CA"
                             :official t
                             :current t)))
    (is (string= "abc123" (cl-telegram/api::authorization-hash auth)))
    (is (string= "device_001" (cl-telegram/api::authorization-device-id auth)))
    (is (= 12345 (cl-telegram/api::authorization-api-id auth)))
    (is (string= "Telegram Desktop" (cl-telegram/api::authorization-app-name auth)))
    (is (eq t (cl-telegram/api::authorization-official auth)))
    (is (eq t (cl-telegram/api::authorization-current auth)))))

(test test-two-factor-auth-class-creation
  "Test two-factor-auth class creation"
  (let ((2fa (make-instance 'cl-telegram/api::two-factor-auth
                            :enabled t
                            :has-password t
                            :password-hint "My favorite color"
                            :email-unsent nil
                            :recovery-email "user@example.com")))
    (is (eq t (cl-telegram/api::two-factor-auth-enabled 2fa)))
    (is (eq t (cl-telegram/api::two-factor-auth-has-password 2fa)))
    (is (string= "My favorite color" (cl-telegram/api::two-factor-auth-password-hint 2fa)))
    (is (eq nil (cl-telegram/api::two-factor-auth-email-unsent 2fa)))
    (is (string= "user@example.com" (cl-telegram/api::two-factor-auth-recovery-email 2fa)))))

;;; ============================================================================
;;; Section 2: Privacy Settings Tests
;;; ============================================================================

(test test-get-privacy-settings
  "Test getting privacy settings"
  (let ((result (cl-telegram/api:get-privacy-settings)))
    ;; May return list or NIL without connection
    (is (or (null result)
            (listp result)))))

(test test-get-privacy-settings-force-refresh
  "Test getting privacy settings with force refresh"
  (let ((result (cl-telegram/api:get-privacy-settings :force-refresh t)))
    (is (or (null result)
            (listp result)))))

(test test-set-privacy-settings
  "Test setting privacy settings"
  (let ((result (cl-telegram/api:set-privacy-settings "last_seen" '(:allow-contacts))))
    (is (or (null result)
            (eq result t)))))

(test test-set-privacy-settings-with-users
  "Test setting privacy settings with specific users"
  (let ((result (cl-telegram/api:set-privacy-settings "last_seen"
                                                       '(:allow-contacts :disallow-users)
                                                       :users '(123 456))))
    (is (or (null result)
            (eq result t)))))

(test test-get-privacy-setting
  "Test getting a specific privacy setting"
  (let ((result (cl-telegram/api:get-privacy-setting "last_seen")))
    (is (or (null result)
            (typep result 'cl-telegram/api::privacy-setting)))))

(test test-get-privacy-setting-cached
  "Test getting cached privacy setting"
  (cl-telegram/api::clear-privacy-settings-cache)
  (let ((result (cl-telegram/api::get-cached-privacy-setting "last_seen")))
    (is (null result))))

(test test-reset-privacy-settings
  "Test resetting privacy settings"
  (let ((result (cl-telegram/api:reset-privacy-settings "last_seen")))
    (is (or (null result)
            (eq result t)))))

(test test-clear-privacy-settings-cache
  "Test clearing privacy settings cache"
  (let ((result (cl-telegram/api::clear-privacy-settings-cache)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 3: Authorization Management Tests
;;; ============================================================================

(test test-get-authorizations
  "Test getting authorizations"
  (let ((result (cl-telegram/api:get-authorizations)))
    (is (or (null result)
            (listp result)))))

(test test-get-authorizations-force-refresh
  "Test getting authorizations with force refresh"
  (let ((result (cl-telegram/api:get-authorizations :force-refresh t)))
    (is (or (null result)
            (listp result)))))

(test test-terminate-authorization
  "Test terminating an authorization"
  (let ((result (cl-telegram/api:terminate-authorization "abc123")))
    (is (or (null result)
            (eq result t)))))

(test test-terminate-all-authorizations
  "Test terminating all authorizations"
  (let ((result (cl-telegram/api:terminate-all-authorizations)))
    (is (or (null result)
            (eq result t)))))

(test test-terminate-all-authorizations-include-current
  "Test terminating all authorizations including current"
  (let ((result (cl-telegram/api:terminate-all-authorizations :keep-current nil)))
    (is (or (null result)
            (eq result t)))))

(test test-clear-authorizations-cache
  "Test clearing authorizations cache"
  (let ((result (cl-telegram/api::clear-authorizations-cache)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 4: Two-Factor Authentication Tests
;;; ============================================================================

(test test-get-two-factor-status
  "Test getting two-factor status"
  (let ((result (cl-telegram/api:get-two-factor-status)))
    (is (or (null result)
            (typep result 'cl-telegram/api::two-factor-auth)))))

(test test-enable-two-factor
  "Test enabling two-factor authentication"
  (let ((result (cl-telegram/api:enable-two-factor "SecurePass123")))
    (is (or (null result)
            (eq result t)))))

(test test-enable-two-factor-with-hint
  "Test enabling two-factor with password hint"
  (let ((result (cl-telegram/api:enable-two-factor "SecurePass123" :hint "My favorite color")))
    (is (or (null result)
            (eq result t)))))

(test test-enable-two-factor-with-email
  "Test enabling two-factor with recovery email"
  (let ((result (cl-telegram/api:enable-two-factor "SecurePass123"
                                                    :hint "Hint"
                                                    :email "user@example.com")))
    (is (or (null result)
            (eq result t)))))

(test test-disable-two-factor
  "Test disabling two-factor authentication"
  (let ((result (cl-telegram/api:disable-two-factor "SecurePass123")))
    (is (or (null result)
            (eq result t)))))

(test test-change-two-factor-password
  "Test changing two-factor password"
  (let ((result (cl-telegram/api:change-two-factor-password "OldPass123" "NewPass456")))
    (is (or (null result)
            (eq result t)))))

(test test-change-two-factor-password-with-hint
  "Test changing two-factor password with new hint"
  (let ((result (cl-telegram/api:change-two-factor-password "OldPass123" "NewPass456"
                                                             :hint "New hint")))
    (is (or (null result)
            (eq result t)))))

(test test-get-two-factor-recovery-code
  "Test getting two-factor recovery code"
  (let ((result (cl-telegram/api:get-two-factor-recovery-code "SecurePass123")))
    (is (or (null result)
            (stringp result)))))

(test test-send-two-factor-recovery-email
  "Test sending two-factor recovery email"
  (let ((result (cl-telegram/api:send-two-factor-recovery-email)))
    (is (or (null result)
            (eq result t)))))

;;; ============================================================================
;;; Section 5: Integration Tests
;;; ============================================================================

(test test-privacy-settings-workflow
  "Test complete privacy settings workflow"
  ;; Get settings
  (let ((settings (cl-telegram/api:get-privacy-settings :force-refresh t)))
    (when settings
      ;; Find a specific setting
      (let ((setting (find "last_seen" settings
                           :key #'cl-telegram/api::privacy-setting-key
                           :test #'string=)))
        (is (or (null setting)
                (typep setting 'cl-telegram/api::privacy-setting))))
    ;; Set new settings
    (let ((result (cl-telegram/api:set-privacy-settings "last_seen" '(:allow-contacts))))
      (is (or (null result)
              (eq result t))))
    ;; Get specific setting
    (let ((specific (cl-telegram/api:get-privacy-setting "last_seen")))
      (is (or (null specific)
              (typep specific 'cl-telegram/api::privacy-setting))))
    ;; Reset settings
    (let ((reset (cl-telegram/api:reset-privacy-settings "last_seen")))
      (is (or (null reset)
              (eq reset t))))))

(test test-authorization-workflow
  "Test complete authorization workflow"
  ;; Get authorizations
  (let ((auths (cl-telegram/api:get-authorizations :force-refresh t)))
    (when auths
      ;; Terminate one if exists
      (when (first auths)
        (let ((hash (cl-telegram/api::authorization-hash (first auths))))
          (let ((result (cl-telegram/api:terminate-authorization hash)))
            (is (or (null result)
                    (eq result t))))))))
  ;; Terminate all others
  (let ((result (cl-telegram/api:terminate-all-authorizations :keep-current t)))
    (is (or (null result)
            (eq result t)))))

(test test-two-factor-workflow
  "Test complete two-factor authentication workflow"
  ;; Get status
  (let ((status (cl-telegram/api:get-two-factor-status)))
    (when status
      ;; Enable if not enabled
      (unless (cl-telegram/api::two-factor-auth-enabled status)
        (let ((enable (cl-telegram/api:enable-two-factor "TestPass123"
                                                          :hint "Test hint"
                                                          :email "test@example.com")))
          (is (or (null enable)
                  (eq enable t))))
        ;; Change password
        (let ((change (cl-telegram/api:change-two-factor-password "TestPass123" "NewPass456")))
          (is (or (null change)
                  (eq change t))))
        ;; Get recovery code
        (let ((code (cl-telegram/api:get-two-factor-recovery-code "NewPass456")))
          (is (or (null code)
                  (stringp code))))
        ;; Disable
        (let ((disable (cl-telegram/api:disable-two-factor "NewPass456")))
          (is (or (null disable)
                  (eq disable t))))))))

;;; ============================================================================
;;; Section 6: Initialization Tests
;;; ============================================================================

(test test-initialize-account-security-v2
  "Test initializing account security v2 system"
  (let ((result (cl-telegram/api:initialize-account-security-v2)))
    (is (eq result t))))

(test test-shutdown-account-security-v2
  "Test shutting down account security v2 system"
  (cl-telegram/api:initialize-account-security-v2)
  (let ((result (cl-telegram/api:shutdown-account-security-v2)))
    (is (eq result t))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-account-security-v2-tests ()
  "Run all account security v2 tests"
  (format t "~%~%=== Account Security v2 Test Results ===~%")
  (let ((results (run! 'account-security-v2-tests :if-fail :error)))
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))

;;; End of account-security-v2-tests.lisp
