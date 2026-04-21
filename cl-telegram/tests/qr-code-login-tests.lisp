;;; qr-code-login-tests.lisp --- Tests for QR code login

(in-package #:cl-telegram/tests)

(def-suite* qr-code-login-tests
  :description "Tests for QR code login (v0.39.0)")

;;; ============================================================================
;;; Section 1: QR Login State Class Tests
;;; ============================================================================

(test test-qr-login-state-creation
  "Test creating a qr-login-state object"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_123"
                              :url "tg://login?token=abc")))
    (is (string= (cl-telegram/api:qr-login-token state) "test_token_123"))
    (is (string= (cl-telegram/api:qr-login-url state) "tg://login?token=abc"))
    (is (eq (cl-telegram/api:qr-login-status state) :pending))))

(test test-qr-login-state-status-transitions
  "Test QR login state status transitions"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_2")))
    ;; Initial status
    (is (eq (cl-telegram/api:qr-login-status state) :pending))
    ;; Update to scanned
    (setf (cl-telegram/api:qr-login-status state) :scanned)
    (is (eq (cl-telegram/api:qr-login-status state) :scanned))
    ;; Update to authenticated
    (setf (cl-telegram/api:qr-login-status state) :authenticated)
    (is (eq (cl-telegram/api:qr-login-status state) :authenticated))))

(test test-qr-login-state-with-user-info
  "Test QR login state with authenticated user info"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_3"
                              :status :authenticated
                              :authenticated-user '(:id 123456 :first-name "Test" :username "testuser"))))
    (is (eq (cl-telegram/api:qr-login-status state) :authenticated))
    (let ((user (cl-telegram/api:qr-login-authenticated-user state)))
      (is (= (getf user :id) 123456))
      (is (string= (getf user :first-name) "Test")))))

;;; ============================================================================
;;; Section 2: QR Token Generation Tests
;;; ============================================================================

(test test-generate-qr-login-token-function-exists
  "Test that generate-qr-login-token function exists"
  (is (fboundp 'cl-telegram/api:generate-qr-login-token)))

(test test-get-qr-login-token-url
  "Test getting QR login token URL"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_4"
                              :url "tg://login?token=xyz")))
    (setf (gethash "test_token_4" cl-telegram/api::*qr-login-states*) state)
    (let ((url (cl-telegram/api:get-qr-login-token-url "test_token_4")))
      (is (string= url "tg://login?token=xyz")))
    ;; Cleanup
    (remhash "test_token_4" cl-telegram/api::*qr-login-states*)))

;;; ============================================================================
;;; Section 3: QR Code Rendering Tests
;;; ============================================================================

(test test-render-qr-code-as-text
  "Test rendering QR code as ASCII text"
  (let ((result (cl-telegram/api:render-qr-code-as-text "tg://login?token=test")))
    (is (stringp result))
    (is (search "QR Code for URL" result))))

(test test-render-qr-code-as-image
  "Test rendering QR code as PNG image"
  (let* ((test-path "/tmp/qr_test_placeholder.png")
         (result (cl-telegram/api:render-qr-code-as-image "tg://login?token=test" test-path)))
    (is (eq result t))
    ;; File should be created (placeholder in tests)
    (is (probe-file test-path))
    ;; Cleanup
    (when (probe-file test-path)
      (delete-file test-path))))

(test test-render-qr-code-as-svg
  "Test rendering QR code as SVG"
  (let ((result (cl-telegram/api:render-qr-code-as-svg "tg://login?token=test")))
    (is (stringp result))
    (is (search "<svg" result))
    (is (search "</svg>" result))))

(test test-generate-qr-modules
  "Test generating QR modules"
  (let ((modules (cl-telegram/api::generate-qr-modules "tg://login?token=test")))
    (is (arrayp modules))
    (is (equal (array-dimensions modules) '(21 21)))))

(test test-generate-svg-from-modules
  "Test generating SVG from modules"
  (let ((modules (cl-telegram/api::generate-qr-modules "test"))
        (svg (cl-telegram/api::generate-svg-from-modules
              (cl-telegram/api::generate-qr-modules "test") 300)))
    (is (stringp svg))
    (is (search "<svg" svg))
    (is (search "<rect" svg)))) ; Should have rectangles for modules

;;; ============================================================================
;;; Section 4: QR Login Status Polling Tests
;;; ============================================================================

(test test-poll-qr-login-status-no-state
  "Test polling QR login status with non-existent token"
  (let ((result (cl-telegram/api:poll-qr-login-status "nonexistent_token")))
    (is (null result))))

(test test-poll-qr-login-status-with-state
  "Test polling QR login status with existing state"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_5"
                              :status :pending)))
    (setf (gethash "test_token_5" cl-telegram/api::*qr-login-states*) state)
    ;; This would call the API, but we just verify the function handles it
    (let ((result (cl-telegram/api:poll-qr-login-status "test_token_5")))
      (is (typep result 'cl-telegram/api::qr-login-state)))
    ;; Cleanup
    (remhash "test_token_5" cl-telegram/api::*qr-login-states*)))

(test test-wait-for-qr-login-timeout
  "Test wait-for-qr-login with immediate timeout"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_6"
                              :status :pending)))
    (setf (gethash "test_token_6" cl-telegram/api::*qr-login-states*) state)
    ;; With very short timeout, should timeout
    (let ((result (cl-telegram/api:wait-for-qr-login "test_token_6" :timeout 0.1 :poll-interval 0.05)))
      (is (member (cl-telegram/api:qr-login-status result) '(:expired :failed :pending))))
    ;; Cleanup
    (remhash "test_token_6" cl-telegram/api::*qr-login-states*)))

;;; ============================================================================
;;; Section 5: QR Login Utilities Tests
;;; ============================================================================

(test test-get-qr-login-state
  "Test retrieving QR login state by token"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_7")))
    (setf (gethash "test_token_7" cl-telegram/api::*qr-login-states*) state)
    (is (eq (cl-telegram/api:get-qr-login-state "test_token_7") state))
    ;; Cleanup
    (remhash "test_token_7" cl-telegram/api::*qr-login-states*)))

(test test-cancel-qr-login
  "Test cancelling QR login"
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "test_token_8"
                              :status :pending)))
    (setf (gethash "test_token_8" cl-telegram/api::*qr-login-states*) state)
    (is (cl-telegram/api:cancel-qr-login "test_token_8" :reason "Test cancel"))
    (is (eq (cl-telegram/api:qr-login-status state) :failed))
    (is (string= (cl-telegram/api:qr-login-error state) "Test cancel"))
    ;; Should be removed from states
    (is (null (gethash "test_token_8" cl-telegram/api::*qr-login-states*)))))

(test test-cleanup-expired-qr-tokens
  "Test cleaning up expired QR tokens"
  (let* ((state1 (make-instance 'cl-telegram/api::qr-login-state
                                :token "test_token_9"
                                :status :expired))
         (state2 (make-instance 'cl-telegram/api::qr-login-state
                                :token "test_token_10"
                                :status :pending)))
    (setf (gethash "test_token_9" cl-telegram/api::*qr-login-states*) state1
          (gethash "test_token_10" cl-telegram/api::*qr-login-states*) state2)
    (let ((count (cl-telegram/api:cleanup-expired-qr-tokens)))
      (is (>= count 1)))
    ;; Expired token should be removed
    (is (null (gethash "test_token_9" cl-telegram/api::*qr-login-states*)))
    ;; Cleanup
    (remhash "test_token_10" cl-telegram/api::*qr-login-states*)))

;;; ============================================================================
;;; Section 6: QR Code Display Helper Tests
;;; ============================================================================

(test test-print-qr-code-to-terminal
  "Test printing QR code to terminal"
  (let ((result (cl-telegram/api:print-qr-code-to-terminal "tg://login?token=test")))
    (is (eq result t))))

(test test-save-qr-code-to-file-png
  "Test saving QR code to PNG file"
  (let* ((test-path "/tmp/qr_save_test.png")
         (result (cl-telegram/api:save-qr-code-to-file "tg://login?token=test" test-path :format :png)))
    (is (eq result t))
    (is (probe-file test-path))
    ;; Cleanup
    (when (probe-file test-path)
      (delete-file test-path))))

(test test-save-qr-code-to-file-svg
  "Test saving QR code to SVG file"
  (let* ((test-path "/tmp/qr_save_test.svg")
         (result (cl-telegram/api:save-qr-code-to-file "tg://login?token=test" test-path :format :svg)))
    (is (eq result t))
    (is (probe-file test-path))
    ;; Cleanup
    (when (probe-file test-path)
      (delete-file test-path))))

(test test-save-qr-code-to-file-text
  "Test saving QR code to text file"
  (let* ((test-path "/tmp/qr_save_test.txt")
         (result (cl-telegram/api:save-qr-code-to-file "tg://login?token=test" test-path :format :text)))
    (is (eq result t))
    (is (probe-file test-path))
    ;; Cleanup
    (when (probe-file test-path)
      (delete-file test-path))))

;;; ============================================================================
;;; Section 7: Constants and State Tests
;;; ============================================================================

(test test-qr-login-poll-interval
  "Test QR login poll interval default"
  (is (numberp cl-telegram/api::*qr-login-poll-interval*))
  (is (> cl-telegram/api::*qr-login-poll-interval* 0)))

(test test-qr-login-timeout
  "Test QR login timeout default"
  (is (numberp cl-telegram/api::*qr-login-timeout*))
  (is (> cl-telegram/api::*qr-login-timeout* 60))) ; Should be at least 60 seconds

(test test-qr-login-states-hash-table
  "Test QR login states hash table"
  (is (typep cl-telegram/api::*qr-login-states* 'hash-table)))

;;; ============================================================================
;;; Section 8: Integration Tests
;;; ============================================================================

(test test-qr-login-complete-flow
  "Test complete QR login flow (mocked)"
  ;; 1. Generate token
  (let ((state (make-instance 'cl-telegram/api::qr-login-state
                              :token "flow_test_token"
                              :url "tg://login?token=flow_test"
                              :status :pending)))
    (setf (gethash "flow_test_token" cl-telegram/api::*qr-login-states*) state)

    ;; 2. Get URL
    (let ((url (cl-telegram/api:get-qr-login-token-url "flow_test_token")))
      (is (string= url "tg://login?token=flow_test")))

    ;; 3. Simulate scan
    (setf (cl-telegram/api:qr-login-status state) :scanned)
    (is (eq (cl-telegram/api:qr-login-status state) :scanned))

    ;; 4. Simulate authentication
    (setf (cl-telegram/api:qr-login-status state) :authenticated
          (cl-telegram/api:qr-login-authenticated-user state) '(:id 999 :first-name "Flow"))
    (is (eq (cl-telegram/api:qr-login-status state) :authenticated))
    (is (= (getf (cl-telegram/api:qr-login-authenticated-user state) :id) 999))

    ;; Cleanup
    (remhash "flow_test_token" cl-telegram/api::*qr-login-states*)))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-qr-code-login-tests ()
  "Run all QR code login tests"
  (let ((results (run! 'qr-code-login-tests :if-fail :error)))
    (format t "~%~%=== QR Code Login Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
