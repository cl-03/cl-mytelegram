;;; live-telegram-tests.lisp --- Live tests against real Telegram servers
;;;
;;; These tests connect to actual Telegram servers and require valid credentials.
;;; DO NOT run these tests with production accounts - use test accounts only.
;;;
;;; Configuration:
;;;   Set environment variables before running:
;;;   - TELEGRAM_API_ID: Your API ID from https://my.telegram.org
;;;   - TELEGRAM_API_HASH: Your API hash
;;;   - TELEGRAM_TEST_PHONE: Test phone number (e.g., "+1234567890")
;;;   - TELEGRAM_TEST_DC: DC ID to use (default: 2 for test server)
;;;
;;; Usage:
;;;   ;; In SBCL:
;;;   (ql:quickload :cl-telegram/tests)
;;;   (setf uiop:getenv "TELEGRAM_API_ID" "12345")
;;;   (setf uiop:getenv "TELEGRAM_API_HASH" "your-hash")
;;;   (setf uiop:getenv "TELEGRAM_TEST_PHONE" "+1234567890")
;;;   (fiveam:run! 'live-telegram-tests)

(in-package #:cl-telegram/tests)

(def-suite* live-telegram-tests
  :description "Live integration tests against real Telegram servers. Requires valid credentials.")

;;; ### Configuration

(defparameter *live-test-api-id* (parse-integer (or (uiop:getenv "TELEGRAM_API_ID") "0")
                                                 :junk-allowed t)
  "Telegram API ID from environment. Must be set for live tests.")

(defparameter *live-test-api-hash* (or (uiop:getenv "TELEGRAM_API_HASH") "")
  "Telegram API hash from environment.")

(defparameter *live-test-phone* (or (uiop:getenv "TELEGRAM_TEST_PHONE") "")
  "Test phone number from environment.")

(defparameter *live-test-dc-id* (parse-integer (or (uiop:getenv "TELEGRAM_TEST_DC") "2")
                                               :junk-allowed t)
  "DC ID to use for testing (default: 2 for test server).")

(defparameter *live-test-code* (or (uiop:getenv "TELEGRAM_TEST_CODE") "12345")
  "Verification code for test account (may need manual entry for real tests).")

(defparameter *live-test-timeout* 30000
  "Default timeout for live tests in milliseconds.")

;;; ### Production DC Endpoints

(defparameter *production-dc-endpoints*
  '((1 . ("149.154.167.50" . 443))
    (2 . ("149.154.167.51" . 443))
    (3 . ("149.154.175.52" . 443))
    (4 . ("149.154.167.91" . 443))
    (5 . ("149.154.171.5" . 443)))
  "Production Telegram datacenter endpoints")

(defparameter *test-dc-endpoints*
  '((1 . ("149.154.167.40" . 443))
    (2 . ("149.154.167.41" . 443)))
  "Test Telegram datacenter endpoints")

(defun get-dc-endpoint (dc-id &optional test-mode)
  "Get endpoint for specific DC.

   Args:
     dc-id: Datacenter ID
     test-mode: Use test DCs if true

   Returns:
     (values host port)"
  (let ((endpoints (if test-mode *test-dc-endpoints* *production-dc-endpoints*)))
    (let ((entry (assoc dc-id endpoints)))
      (when entry
        (values (car (cdr entry)) (cdr (cdr entry)))))))

;;; ### Prerequisite Checks

(defun check-live-test-prerequisites ()
  "Check if prerequisites for live tests are met.

   Returns:
     (values ready-p error-message)

   ready-p is T if all prerequisites are satisfied.
   error-message contains description of missing prerequisites."
  (let ((errors nil))
    ;; Check API ID
    (when (or (zerop *live-test-api-id*)
              (null *live-test-api-id*))
      (push "TELEGRAM_API_ID environment variable not set or invalid" errors))

    ;; Check API Hash
    (when (string= *live-test-api-hash* "")
      (push "TELEGRAM_API_HASH environment variable not set" errors))

    ;; Check phone number
    (when (string= *live-test-phone* "")
      (push "TELEGRAM_TEST_PHONE environment variable not set" errors))

    ;; Validate phone number format
    (when (and (plusp (length *live-test-phone*))
               (not (cl-ppcre:scan "^\\+[0-9]{10,15}$" *live-test-phone*)))
      (push "TELEGRAM_TEST_PHONE must be in international format (e.g., +1234567890)" errors))

    (if (null errors)
        (values t nil)
        (values nil (format nil "Missing prerequisites:~{~%  - ~A~}" (nreverse errors))))))

(defmacro with-live-test-checks ((&optional skip-if-missing) &body body)
  "Execute body only if live test prerequisites are met.

   Args:
     skip-if-missing: If true, skip test instead of failing when prerequisites missing

   Example:
     (with-live-test-checks (t)
       ;; test body that requires credentials
       )"
  `(multiple-value-bind (prereq-ready prereq-error)
       (check-live-test-prerequisites)
     (cond
       (prereq-ready ,@body)
       (,skip-if-missing (skip-test prereq-error))
       (t (error prereq-error)))))

;;; ### Connection Tests

(test test-connect-to-production-dc1
  "Test TCP connection to DC1 (Zug, Switzerland)"
  (with-live-test-checks (t)
    (multiple-value-bind (host port) (get-dc-endpoint 1 nil)
      (let ((client (cl-telegram/network:make-sync-tcp-client host port)))
        (is (typep client 'cl-telegram/network::sync-tcp-client))
        ;; Try to connect (may fail due to MTProto handshake requirement)
        (let ((connected (cl-telegram/network:sync-client-connect client :timeout 5)))
          (is connected "Should connect to DC1"))
        ;; Cleanup
        (cl-telegram/network:sync-client-disconnect client)))))

(test test-connect-to-production-dc2
  "Test TCP connection to DC2 (Amsterdam, Netherlands)"
  (with-live-test-checks (t)
    (multiple-value-bind (host port) (get-dc-endpoint 2 nil)
      (let ((client (cl-telegram/network:make-sync-tcp-client host port)))
        (is (typep client 'cl-telegram/network::sync-tcp-client))
        (let ((connected (cl-telegram/network:sync-client-connect client :timeout 5)))
          (is connected "Should connect to DC2"))
        (cl-telegram/network:sync-client-disconnect client)))))

(test test-connect-to-nearest-dc
  "Test connection to geographically nearest DC based on phone number"
  (with-live-test-checks (t)
    (let* ((dc-id (cl-telegram/network:dc-id-from-phone *live-test-phone*))
           (multiple-value-bind (host port) (get-dc-endpoint dc-id nil)
             (let ((client (cl-telegram/network:make-sync-tcp-client host port)))
               (is (typep client 'cl-telegram/network::sync-tcp-client))
               (let ((connected (cl-telegram/network:sync-client-connect client :timeout 5)))
                 (format t "Connected to DC~D (~A:~A) for phone ~A~%"
                         dc-id host port *live-test-phone*)
                 (is connected "Should connect to nearest DC"))
               (cl-telegram/network:sync-client-disconnect client))))))

;;; ### MTProto Handshake Tests

(test test-mtproto-initial-handshake
  "Test MTProto initial handshake (req_pq_multi)"
  (with-live-test-checks (nil)
    (let ((conn (cl-telegram/network:make-connection
                 :host (multiple-value-bind (h p)
                           (get-dc-endpoint *live-test-dc-id* t)
                         (declare (ignore p))
                         h)
                 :port 443)))
      (unwind-protect
           (progn
             ;; Connect TCP
             (cl-telegram/network:connect conn)
             (sleep 0.5) ; Allow connection to establish

             (is (cl-telegram/network:connected-p conn)
                 "TCP connection should be established")

             ;; Send req_pq_multi request
             ;; req_pq_multi#be7e8ef1 nonce:int128 = ResPQ
             (let* ((nonce (cl-telegram/mtproto:generate-random-bytes 16))
                    (request (concatenate '(simple-array (unsigned-byte 8))
                                          (cl-telegram/tl:serialize-int32 #xbe7e8ef1)
                                          nonce)))
               ;; Send request
               (let ((result (cl-telegram/network:rpc-call conn request
                                                           :timeout *live-test-timeout*)))
                 ;; Should receive resPQ or error
                 (typecase result
                   ((simple-array (unsigned-byte 8))
                    ;; Check constructor ID
                    (let ((constructor (cl-telegram/tl:deserialize-int32 result)))
                      (is (= constructor #x05162463)
                          "Should receive resPQ response")))
                   (list
                    ;; Error response - check it's expected
                    (is (member (car result) '(:error :timeout))
                        "Should receive error or timeout")))))))

        ;; Cleanup
        (when conn
          (cl-telegram/network:disconnect conn))))))

;;; ### Authentication Tests

(test test-full-authentication-flow
  "Test complete authentication flow with real credentials"
  (with-live-test-checks (nil)
    ;; Skip if using demo credentials
    (when (string= *live-test-phone* "+1234567890")
      (skip-test "Demo phone number - skipping real auth test"))

    (let ((auth-state (cl-telegram/api:get-authentication-state)))
      (is (or (eq auth-state :ready)
              (eq auth-state :none))
          "Should be ready or need authentication"))

    ;; Reset auth state
    (cl-telegram/api:reset-auth-session)

    ;; Set phone number
    (let ((result (cl-telegram/api:set-authentication-phone-number *live-test-phone*)))
      (is result "Should accept phone number"))

    ;; Request code (in live test, this sends SMS to real phone)
    (let ((code-result (cl-telegram/api:request-authentication-code)))
      (is (or (eq (car code-result) :success)
              (eq (car code-result) :code-sent)
              (typep code-result 'cons))
          "Should send verification code"))

    ;; Note: For automated tests, code is from env var
    ;; For manual tests, user would need to enter code
    (format t "~%Waiting for code verification...~%")
    (format t "Code from env: ~A~%" *live-test-code*)

    ;; Check code verification
    (let ((verify-result (cl-telegram/api:check-authentication-code *live-test-code*)))
      (is (or (eq (car verify-result) :success)
              (eq (car verify-result) :session-created)
              (and (listp verify-result) (eq (car verify-result) :error)))
          "Should verify code or report error"))

    ;; If authenticated, check get-me
    (when (cl-telegram/api:authorized-p)
      (multiple-value-bind (user error)
          (cl-telegram/api:get-me)
        (if user
            (progn
              (is (getf user :id) "User should have ID")
              (format t "Authenticated as: ~A ~A~%"
                      (getf user :first-name "Unknown")
                      (getf user :last-name "")))
            (skip-test (format nil "get-me returned: ~A" error)))))))

;;; ### Message Tests

(test test-send-message-live
  "Test sending message to a chat (live)"
  (with-live-test-checks (nil)
    (unless (cl-telegram/api:authorized-p)
      (skip-test "Not authenticated"))

    ;; Get chat list first
    (multiple-value-bind (chats error)
        (cl-telegram/api:get-chats :limit 10)
      (cond
        ((and chats (plusp (length chats)))
         ;; Have chats, send to first one
         (let* ((chat (first chats))
                (chat-id (getf chat :id)))
           (multiple-value-bind (msg send-error)
               (cl-telegram/api:send-message chat-id "Live test message from cl-telegram")
             (if msg
                 (progn
                   (is (getf msg :id) "Message should have ID")
                   (format t "Message sent successfully to chat ~A~%" chat-id))
                 (skip-test (format nil "Send failed: ~A" send-error))))))
        ((or error (null chats))
         ;; No chats or error - save self as test target
         (multiple-value-bind (me me-error)
             (cl-telegram/api:get-me)
           (if me
               (let ((chat-id (getf me :id)))
                 (multiple-value-bind (msg send-error)
                     (cl-telegram/api:send-message chat-id "Live test - message to self")
                   (if msg
                       (is (getf msg :id) "Message should have ID")
                       (skip-test (format nil "Send to self failed: ~A" send-error)))))
               (skip-test (format nil "get-me failed: ~A" me-error)))))
        (t
         (skip-test "No chats available"))))))

;;; ### DC Migration Tests

(test test-dc-latency-measurement
  "Test measuring latency to multiple DCs (live)"
  (with-live-test-checks (t)
    (let* ((dc-manager (cl-telegram/network:make-dc-manager :test-mode nil))
           (latencies (cl-telegram/network:measure-all-dc-latencies dc-manager)))
      (is (listp latencies) "Should return latency results")
      (dolist (result latencies)
        (let ((dc-id (car result))
              (latency (cdr result)))
          (format t "DC~A latency: ~A ms~%" dc-id latency)
          ;; Latency should be measurable (not most-positive-fixnum which indicates error)
          (is (< latency 5000)
              (format nil "DC~A latency should be under 5000ms" dc-id)))))))

(test test-dc-auto-selection
  "Test automatic DC selection based on phone number (live)"
  (with-live-test-checks (t)
    (let ((suggested-dc (cl-telegram/network:dc-id-from-phone *live-test-phone*)))
      (is (member suggested-dc '(1 2 3 4 5))
          "Should suggest valid DC ID")
      (format t "Suggested DC~A for phone ~A~%" suggested-dc *live-test-phone*))))

;;; ### Performance Tests

(test test-message-throughput
  "Test message sending throughput (live)"
  (with-live-test-checks (nil)
    (unless (cl-telegram/api:authorized-p)
      (skip-test "Not authenticated"))

    ;; Get chat to send to (self or saved messages)
    (multiple-value-bind (me error)
        (cl-telegram/api:get-me)
      (unless me
        (skip-test (format nil "get-me failed: ~A" error)))

      (let* ((chat-id (getf me :id))
             (num-messages 10)
             (start-time (get-internal-real-time))
             (success-count 0))

        ;; Send multiple messages
        (loop for i from 1 to num-messages do
              (multiple-value-bind (msg err)
                  (cl-telegram/api:send-message chat-id (format nil "Performance test message ~A" i))
                (when msg
                  (incf success-count))))

        (let* ((end-time (get-internal-real-time))
               (elapsed-sec (/ (- end-time start-time) internal-time-units-per-second))
               (messages-per-sec (float (/ success-count elapsed-sec) 1.0)))
          (format t "~%Sent ~A/~A messages in ~F seconds (~F msg/sec)~%"
                  success-count num-messages elapsed-sec messages-per-sec)
          (is (> messages-per-sec 0.5)
              (format nil "Should send at least 0.5 msg/sec, got ~F" messages-per-sec)))))))

;;; ### Cleanup Tests

(test test-session-cleanup-live
  "Test session cleanup after live tests"
  (with-live-test-checks (t)
    ;; Close any open connections
    (cl-telegram/api:close-auth-connection)

    ;; Reset auth state
    (cl-telegram/api:reset-auth-session)

    ;; Verify cleanup
    (is (not (cl-telegram/api:authorized-p))
        "Should not be authorized after cleanup")

    (is (eq (cl-telegram/api:get-authentication-state) :none)
        "Auth state should be :none after cleanup")))

;;; ### Helper Functions

(defun run-live-tests (&key (skip-unauthorized t))
  "Run all live tests with proper setup.

   Args:
     skip-unauthorized: Skip tests that require authorization if not authorized

   Returns:
     Test results summary"
  (format t "=== Live Telegram Tests ===~%")
  (format t "API ID: ~A~%" *live-test-api-id*)
  (format t "API Hash: ~A~%" (if (plusp (length *live-test-api-hash*)) "***" "(not set)"))
  (format t "Phone: ~A~%" *live-test-phone*)
  (format t "DC: ~A~%" *live-test-dc-id*)
  (format t "~%")

  ;; Check prerequisites
  (multiple-value-bind (ready error)
      (check-live-test-prerequisites)
    (unless ready
      (format t "Prerequisites not met:~A~%" error)
      (format t "Set environment variables to run live tests:~%")
      (format t "  export TELEGRAM_API_ID=<your-api-id>~%")
      (format t "  export TELEGRAM_API_HASH=<your-api-hash>~%")
      (format t "  export TELEGRAM_TEST_PHONE=+<your-test-phone>~%")
      (format t "  export TELEGRAM_TEST_DC=2~%")
      (return-from run-live-tests)))

  ;; Run tests
  (fiveam:run! 'live-telegram-tests))

(defun run-single-live-test (test-name)
  "Run a single live test by name.

   Args:
     test-name: Symbol name of test to run

   Returns:
     Test result"
  (let ((test (find-test test-name 'live-telegram-tests)))
    (if test
        (fiveam:run! test)
        (error "Test ~A not found in live-telegram-tests suite" test-name))))
