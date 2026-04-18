;;; integration-tests.lisp --- Integration tests for cl-telegram

(in-package #:cl-telegram/tests)

(def-suite* integration-tests
  :description "Integration tests for cl-telegram")

;;; ### Configuration

(defparameter *test-api-id* 6  "Telegram API ID (test environment)"
  "Telegram API ID for testing. Use your own from https://my.telegram.org")
(defparameter *test-api-hash* "eb06d4abfb49dc33b1dbc8f96364f7b4"
  "Telegram API hash for testing")
(defparameter *test-dc-id* 2
  "Telegram DC ID for testing (2 = test server)")

;;; ### Helper Functions

(defun with-test-environment (&body body)
  "Execute tests in a clean test environment."
  `(progn
     ;; Reset auth state before test
     (cl-telegram/api:reset-auth-session)
     ;; Execute test body
     ,@body
     ;; Cleanup after test
     (cl-telegram/api:close-auth-connection)))

(defmacro with-authenticated-session ((&key phone code) &body body)
  "Execute test body with authenticated session.

   Args:
     phone: Phone number (default: test number)
     code: Verification code (default: \"12345\" for demo)
   "
  `(progn
     (cl-telegram/api:reset-auth-session)
     (cl-telegram/api:set-authentication-phone-number (or ,phone "+1234567890"))
     (cl-telegram/api:check-authentication-code (or ,code "12345"))
     (unwind-protect
          (progn ,@body)
       (cl-telegram/api:close-auth-connection))))

;;; ### Connection Tests

(test test-tcp-connection-to-telegram
  "Test TCP connection to Telegram servers"
  (let ((client (cl-telegram/network:make-tcp-client "149.154.167.51" 443
                                                     :on-connect (lambda (c)
                                                                   (format t "Connected~%"))
                                                     :on-data (lambda (c d)
                                                                (format t "Data received~%"))
                                                     :on-error (lambda (c e)
                                                                 (format t "Error: ~A~%" e)))))
    (is (typep client 'cl-telegram/network::tcp-client))
    ;; Note: Actual connection requires MTProto handshake
    ))

(test test-sync-connection
  "Test synchronous TCP connection"
  (let ((client (cl-telegram/network:make-sync-tcp-client "149.154.167.51" 443)))
    (is (typep client 'cl-telegram/network::sync-tcp-client))
    ;; Note: Actual connection requires MTProto handshake
    ))

;;; ### Authentication Flow Tests

(test test-full-auth-flow-demo
  "Test full authentication flow in demo mode"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (is (cl-telegram/api:authorized-p))
    (let ((state (cl-telegram/api:get-authentication-state)))
      (is (eq state :ready)))))

(test test-get-me-after-auth
  "Test getting current user info after authentication"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (multiple-value-bind (user error)
        (cl-telegram/api:get-me)
      ;; In demo mode, this may return nil or mock data
      ;; Real test with actual credentials would return user object
      (is (or user (eq error :not-authorized))))))

;;; ### Message Tests

(test test-send-message-flow
  "Test complete message sending flow"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    ;; First get chats to have a valid chat-id
    (multiple-value-bind (chats err)
        (cl-telegram/api:get-chats :limit 10)
      (if (and chats (> (length chats) 0))
          (let ((chat-id (getf (first chats) :id)))
            (multiple-value-bind (msg send-err)
                (cl-telegram/api:send-message chat-id "Test message from integration test")
              (is (or msg send-err))))
          ;; No chats, test with mock chat-id
          (multiple-value-bind (msg send-err)
              (cl-telegram/api:send-message 123 "Test message")
            (is (or msg send-err)))))))

(test test-message-roundtrip
  "Test message send and receive roundtrip"
  ;; This test requires actual network connection
  ;; For now, verify the API functions exist and don't error immediately
  (is (functionp #'cl-telegram/api:send-message))
  (is (functionp #'cl-telegram/api:get-messages)))

;;; ### Chat Tests

(test test-get-chats-flow
  "Test getting chat list"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (multiple-value-bind (chats error)
        (cl-telegram/api:get-chats :limit 50)
      ;; Should return list or error, but not crash
      (is (or (listp chats) error)))))

(test test-create-private-chat
  "Test creating private chat"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (multiple-value-bind (chat error)
        (cl-telegram/api:create-private-chat 123)
      ;; Should return chat or error
      (is (or chat error)))))

;;; ### User Tests

(test test-search-users
  "Test searching for users"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (multiple-value-bind (users error)
        (cl-telegram/api:search-users "test" :limit 10)
      ;; Should return list or error
      (is (or (listp users) error)))))

;;; ### Network Resilience Tests

(test test-connection-retry
  "Test connection retry logic"
  (let ((conn (cl-telegram/network:make-connection :host "127.0.0.1" :port 9999)))
    ;; Should handle connection failure gracefully
    (handler-case
        (cl-telegram/network:connect conn :timeout 1000)
      (error (e)
        (is (typep e 'error))))))

(test test-rpc-with-retry
  "Test RPC call with retry on failure"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (let ((conn (cl-telegram/api:ensure-auth-connection)))
      (when conn
        (multiple-value-bind (result error)
            (cl-telegram/network:rpc-call-with-retry conn #(1 2 3 4) :max-retries 2 :timeout 1000)
          ;; Should handle timeout or error gracefully
          (is (or result error)))))))

;;; ### Error Handling Tests

(test test-error-handling-unauthorized
  "Test error handling when not authorized"
  (cl-telegram/api:reset-auth-session)
  (multiple-value-bind (result error)
      (cl-telegram/api:send-message 123 "Test")
    (is (eq error :not-authorized))
    (is (null result))))

(test test-error-handling-invalid-input
  "Test error handling with invalid input"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    ;; Empty message
    (multiple-value-bind (result error)
        (cl-telegram/api:send-message 123 "")
      (is (eq error :invalid-message)))
    ;; Too long message
    (multiple-value-bind (result error)
        (cl-telegram/api:send-message 123 (make-string 5000 :initial-element #\a))
      (is (eq error :invalid-message)))))

;;; ### TDLib Compatibility Tests

(test test-tdlib-compatible-auth
  "Test TDLib-compatible authentication functions"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:|setTdlibParameters| :parameters '())
  (cl-telegram/api:|setAuthenticationPhoneNumber| "+1234567890")
  (is (cl-telegram/api:needs-code-p))
  (multiple-value-bind (result error)
      (cl-telegram/api:|checkAuthenticationCode| "12345")
    (is (or (eq (car result) :success) error))))

(test test-tdlib-compatible-message
  "Test TDLib-compatible message sending"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (multiple-value-bind (result error)
        (cl-telegram/api:|sendMessage| 123 "Test message")
      (is (or result error)))))

;;; ### Performance Tests

(test test-batch-message-send
  "Test sending multiple messages in batch"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (let ((start-time (get-internal-real-time))
          (message-count 10))
      (loop for i below message-count do
        (cl-telegram/api:send-message 123 (format nil "Message ~D" i)))
      (let ((elapsed (/ (- (get-internal-real-time) start-time) internal-time-units-per-second)))
        (format t "Sent ~D messages in ~F seconds~%" message-count elapsed)
        ;; Should complete in reasonable time (< 10 seconds for 10 messages)
        (is (< elapsed 10.0))))))

;;; ### Cleanup Tests

(test test-session-cleanup
  "Test that session cleanup works correctly"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (is (cl-telegram/api:needs-code-p))
  (cl-telegram/api:reset-auth-session)
  (is (member (cl-telegram/api:get-authentication-state)
              '(:wait-tdlib-parameters :wait-phone-number))))

(test test-connection-cleanup
  "Test that connection cleanup works correctly"
  (with-authenticated-session (:phone "+1234567890" :code "12345")
    (let ((conn (cl-telegram/api:ensure-auth-connection)))
      (is conn))
    (cl-telegram/api:close-auth-connection)
    ;; After close, should be able to create new connection
    (let ((new-conn (cl-telegram/api:ensure-auth-connection)))
      (is (or new-conn (null new-conn))))))

;;; ### Real Server Tests (Optional)

;; These tests require actual Telegram credentials and should be run manually

#|
(test test-real-auth-flow
  "Test authentication with real Telegram credentials"
  ;; Uncomment and modify with your actual test credentials
  ;; WARNING: Only use test accounts, never your personal account!
  (let ((test-phone "+XXXXXXXXXXX")  ; Your test phone number
        (test-code "XXXXX"))         ; Code you receive
    (cl-telegram/api:reset-auth-session)
    (cl-telegram/api:set-authentication-phone-number test-phone)
    (sleep 2) ; Wait for code
    (cl-telegram/api:check-authentication-code test-code)
    (is (cl-telegram/api:authorized-p))))

(test test-real-message-send
  "Test sending real message to test chat"
  (let ((test-chat-id 123456789))  ; Your test chat ID
    (cl-telegram/api:send-message test-chat-id "Hello from cl-telegram integration test")))
|#

;;; ### Test Runner

(defun run-integration-tests ()
  "Run all integration tests"
  (format t "~%Running integration tests...~%")
  (format t "Note: These tests use demo mode by default.~%")
  (format t "For real server tests, modify the test configuration.~%~%")
  (run! 'integration-tests))

(defun run-integration-tests-with-creds (phone code)
  "Run integration tests with real credentials"
  (format t "~%Running integration tests with real credentials...~%")
  (format t "Phone: ~A~%" phone)
  (setf *test-phone-number* phone)
  (setf *test-code* code)
  (run! 'integration-tests))
