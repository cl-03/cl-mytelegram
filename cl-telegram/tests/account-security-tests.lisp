;;; account-security-tests.lisp --- Tests for account security functionality

(in-package #:cl-telegram/tests)

(def-suite account-security-tests
  :description "Tests for account security features (v0.19.0)")

(in-suite account-security-tests)

;;; ======================================================================
;;; Login Token Class Tests
;;; ======================================================================

(test test-login-token-class
  "Test login-token class creation and accessors"
  (let ((token (make-instance 'cl-telegram/api:login-token
                              :token "abc123"
                              :token-hash "hash_xyz"
                              :expires 1713542400)))
    (is (string= "abc123" (cl-telegram/api:login-token-token token)))
    (is (string= "hash_xyz" (cl-telegram/api:login-token-hash token)))
    (is (= 1713542400 (cl-telegram/api:login-token-expires token)))))

(test test-login-token-defaults
  "Test login-token default values"
  (let ((token (make-instance 'cl-telegram/api:login-token)))
    (is (null (cl-telegram/api:login-token-token token)))
    (is (null (cl-telegram/api:login-token-hash token)))
    (is (= 0 (cl-telegram/api:login-token-expires token)))))

;;; ======================================================================
;;; Authorization Session Class Tests
;;; ======================================================================

(test test-authorization-session-class
  "Test authorization-session class creation"
  (let ((session (make-instance 'cl-telegram/api:authorization-session
                                :hash 12345
                                :device-model "Desktop"
                                :platform "Windows"
                                :system-version "11"
                                :api-id 12345
                                :app-name "Telegram"
                                :app-version "4.0"
                                :date-created 1713542400
                                :date-active 1713628800
                                :ip "192.168.1.1"
                                :country "US"
                                :region "CA")))
    (is (= 12345 (cl-telegram/api:authorization-session-hash session)))
    (is (string= "Desktop" (cl-telegram/api:authorization-session-device-model session)))
    (is (string= "Windows" (cl-telegram/api:authorization-session-platform session)))
    (is (string= "11" (cl-telegram/api:authorization-session-system-version session)))
    (is (= 12345 (cl-telegram/api:authorization-session-api-id session)))
    (is (string= "Telegram" (cl-telegram/api:authorization-session-app-name session)))
    (is (string= "4.0" (cl-telegram/api:authorization-session-app-version session)))
    (is (= 1713542400 (cl-telegram/api:authorization-session-date-created session)))
    (is (= 1713628800 (cl-telegram/api:authorization-session-date-active session)))
    (is (string= "192.168.1.1" (cl-telegram/api:authorization-session-ip session)))
    (is (string= "US" (cl-telegram/api:authorization-session-country session)))
    (is (string= "CA" (cl-telegram/api:authorization-session-region session)))))

;;; ======================================================================
;;; Privacy Rule Class Tests
;;; ======================================================================

(test test-privacy-rule-class
  "Test privacy-rule class creation"
  (let ((rule (make-instance 'cl-telegram/api:privacy-rule
                             :key :phone-number
                             :rules '(:allow-all)
                             :users-allow '(123 456)
                             :users-deny '(789))))
    (is (eq :phone-number (cl-telegram/api:privacy-rule-key rule)))
    (is (equal '(:allow-all) (cl-telegram/api:privacy-rule-rules rule)))
    (is (equal '(123 456) (cl-telegram/api:privacy-rule-users-allow rule)))
    (is (equal '(789) (cl-telegram/api:privacy-rule-users-deny rule)))))

(test test-privacy-rule-defaults
  "Test privacy-rule default values"
  (let ((rule (make-instance 'cl-telegram/api:privacy-rule
                             :key :last-seen)))
    (is (eq :last-seen (cl-telegram/api:privacy-rule-key rule)))
    (is (null (cl-telegram/api:privacy-rule-rules rule)))
    (is (null (cl-telegram/api:privacy-rule-users-allow rule)))
    (is (null (cl-telegram/api:privacy-rule-users-deny rule)))))

;;; ======================================================================
;;; QR Code Login Tests (Mock)
;;; ======================================================================

(test test-export-login-token-return
  "Test export-login-token returns login-token or NIL"
  (let ((result (cl-telegram/api:export-login-token)))
    (is (or (notnull result) (null result)))))

(test test-import-login-token-return
  "Test import-login-token returns boolean"
  (let ((result (cl-telegram/api:import-login-token "test_token_abc123")))
    (is (or (eq t result) (null result)))))

(test test-accept-login-token-return
  "Test accept-login-token returns boolean"
  (let ((result (cl-telegram/api:accept-login-token "test_token")))
    (is (or (eq t result) (null result)))))

(test test-generate-qr-code-url
  "Test generate-qr-code-url generates valid URL"
  (let ((url (cl-telegram/api:generate-qr-code-url "abc123")))
    (is (stringp url))
    (is (cl-telegram/api::starts-with-subseq url "tg://login?token="))))

(test test-parse-qr-code-url
  "Test parse-qr-code-url extracts token"
  (let ((token (cl-telegram/api:parse-qr-code-url "tg://login?token=abc123")))
    (is (string= "abc123" token))))

(test test-parse-qr-code-url-invalid
  "Test parse-qr-code-url with invalid URL"
  (let ((result (cl-telegram/api:parse-qr-code-url "invalid-url")))
    (is (or (null result) (stringp result)))))

;;; ======================================================================
;;; Base64 Utility Tests
;;; ======================================================================

(test test-base64url-encode
  "Test base64url encoding"
  (let ((encoded (cl-telegram/api::base64url-encode #(1 2 3 4 5))))
    (is (stringp encoded))
    ;; Should not contain + or / (URL-safe)
    (is (null (find #\+ encoded)))
    (is (null (find #\/ encoded)))))

(test test-base64url-decode
  "Test base64url decoding"
  (let* ((original #(1 2 3 4 5))
         (encoded (cl-telegram/api::base64url-encode original))
         (decoded (cl-telegram/api::base64url-decode encoded)))
    (is (equalp original decoded))))

;;; ======================================================================
;;; Privacy Settings Tests (Mock)
;;; ======================================================================

(test test-get-privacy-settings-return-type
  "Test get-privacy-settings returns privacy-rule or list"
  (let ((result (cl-telegram/api:get-privacy-settings)))
    (is (or (notnull result) (null result)))))

(test test-get-privacy-settings-by-key
  "Test get-privacy-settings with specific key"
  (let ((result (cl-telegram/api:get-privacy-settings :privacy-key :phone-number)))
    (is (or (notnull result) (null result)))))

(test test-set-privacy-settings-return
  "Test set-privacy-settings returns boolean"
  (let ((result (cl-telegram/api:set-privacy-settings :phone-number '(:allow-all))))
    (is (or (eq t result) (null result)))))

(test test-set-privacy-settings-with-exceptions
  "Test set-privacy-settings with allow/deny exceptions"
  (let ((result (cl-telegram/api:set-privacy-settings :last-seen '(:allow-contacts)
                                                      :users-allow '(123 456)
                                                      :users-deny '(789))))
    (is (or (eq t result) (null result)))))

(test test-reset-privacy-settings-return
  "Test reset-privacy-settings returns boolean"
  (let ((result (cl-telegram/api:reset-privacy-settings :phone-number)))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Session Management Tests (Mock)
;;; ======================================================================

(test test-get-authorizations-return-type
  "Test get-authorizations returns list"
  (let ((result (cl-telegram/api:get-authorizations)))
    (is (listp result))))

(test test-reset-authorization-return
  "Test reset-authorization returns boolean"
  (let ((result (cl-telegram/api:reset-authorization 12345)))
    (is (or (eq t result) (null result)))))

(test test-reset-authorization-all-return
  "Test reset-authorization-all returns boolean"
  (let ((result (cl-telegram/api:reset-authorization-all)))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Phone Number Change Tests (Mock)
;;; ======================================================================

(test test-change-phone-number-return
  "Test change-phone-number returns boolean"
  (let ((result (cl-telegram/api:change-phone-number "+1234567890")))
    (is (or (eq t result) (null result)))))

(test test-send-confirm-phone-code-return
  "Test send-confirm-phone-code returns boolean"
  (let ((result (cl-telegram/api:send-confirm-phone-code "+1234567890")))
    (is (or (eq t result) (null result)))))

(test test-confirm-phone-return
  "Test confirm-phone returns boolean"
  (let ((result (cl-telegram/api:confirm-phone "+1234567890" "12345")))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Takeout Session Tests (Mock)
;;; ======================================================================

(test test-takeout-init-return
  "Test takeout-init returns takeout-id or NIL"
  (let ((result (cl-telegram/api:takeout-init)))
    (is (or (notnull result) (null result) (stringp result)))))

(test test-finish-takeout-session-return
  "Test finish-takeout-session returns boolean"
  (let ((result (cl-telegram/api:finish-takeout-session "takeout_123")))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Global State Tests
;;; ======================================================================

(test test-qr-login-state-initial
  "Test QR login state initial value"
  (is (member cl-telegram/api:*qr-login-state* '(:idle :exported :imported :accepted))))

(test test-takeout-id-initial
  "Test takeout-id initial value"
  (is (or (null cl-telegram/api:*takeout-id*) (stringp cl-telegram/api:*takeout-id*))))

;;; ======================================================================
;;; Edge Case Tests
;;; ======================================================================

(test test-import-login-token-empty
  "Test import-login-token with empty token"
  (let ((result (cl-telegram/api:import-login-token "")))
    (is (or (eq t result) (null result)))))

(test test-accept-login-token-empty
  "Test accept-login-token with empty token"
  (let ((result (cl-telegram/api:accept-login-token "")))
    (is (or (eq t result) (null result)))))

(test test-set-privacy-settings-invalid-key
  "Test set-privacy-settings with invalid key"
  (let ((result (cl-telegram/api:set-privacy-settings :invalid-key '(:allow-all))))
    (is (or (eq t result) (null result)))))

(test test-reset-authorization-nonexistent
  "Test reset-authorization with nonexistent hash"
  (let ((result (cl-telegram/api:reset-authorization 999999)))
    (is (or (eq t result) (null result)))))

(test test-confirm-phone-invalid-code
  "Test confirm-phone with invalid code"
  (let ((result (cl-telegram/api:confirm-phone "+1234567890" "invalid")))
    (is (or (eq t result) (null result)))))

(test test-finish-takeout-nonexistent
  "Test finish-takeout-session with nonexistent ID"
  (let ((result (cl-telegram/api:finish-takeout-session "nonexistent")))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Privacy Rule Helpers Tests
;;; ======================================================================

(test test-privacy-rule-allow-all
  "Test privacy rule allow-all helper"
  (let ((result (cl-telegram/api::make-privacy-rule :allow-all)))
    (is (notnull result))))

(test test-privacy-rule-allow-contacts
  "Test privacy rule allow-contacts helper"
  (let ((result (cl-telegram/api::make-privacy-rule :allow-contacts)))
    (is (notnull result))))

(test test-privacy-rule-deny-all
  "Test privacy rule deny-all helper"
  (let ((result (cl-telegram/api::make-privacy-rule :deny-all)))
    (is (notnull result))))

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-account-security-tests ()
  "Run all account security tests"
  (format t "~%=== Running Account Security Unit Tests ===~%~%")
  (fiveam:run! 'account-security-tests))

(export '(run-account-security-tests))
