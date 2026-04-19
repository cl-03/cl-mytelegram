;;; integration-telegram-tests.lisp --- Integration tests with real Telegram servers
;;;
;;; Tests that connect to actual Telegram infrastructure.
;;; Requires valid API credentials and phone number.
;;;
;;; Setup:
;;; 1. Copy .env.example to .env
;;; 2. Set TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_TEST_PHONE
;;; 3. Load tests: (asdf:load-system :cl-telegram/tests)
;;; 4. Run: (cl-telegram/tests:run-live-tests)

(in-package #:cl-telegram/tests)

(def-suite* integration-telegram-tests
  :description "Integration tests with real Telegram servers")

;;; ### Test Configuration

(defvar *integration-test-config*
  '(:api-id nil
    :api-hash nil
    :phone nil
    :test-chat-id nil)
  "Configuration for integration tests")

(defvar *integration-auth-session* nil
  "Authentication session for integration tests")

(defvar *skip-interactive-tests* t
  "Skip tests that require user interaction")

(defun load-integration-config ()
  "Load integration test configuration from environment.

   Returns:
     Config plist or NIL if not configured"
  (let ((api-id (uiop:getenv "TELEGRAM_API_ID"))
        (api-hash (uiop:getenv "TELEGRAM_API_HASH"))
        (phone (uiop:getenv "TELEGRAM_TEST_PHONE"))
        (test-chat-id (uiop:getenv "TELEGRAM_TEST_CHAT_ID")))
    (when (and api-id api-hash phone)
      (setf *integration-test-config*
            (list :api-id (parse-integer api-id)
                  :api-hash api-hash
                  :phone phone
                  :test-chat-id (when test-chat-id
                                  (parse-integer test-chat-id)))))))

(defun ensure-configured ()
  "Ensure integration tests are configured.

   Returns:
     T if configured, signals error otherwise"
  (load-integration-config)
  (unless (getf *integration-test-config* :api-id)
    (error "Integration tests not configured. Set TELEGRAM_API_ID, TELEGRAM_API_HASH, and TELEGRAM_TEST_PHONE environment variables."))
  t)

(defun ensure-authenticated ()
  "Ensure authenticated for integration tests.

   Returns:
     T if authenticated, signals error otherwise"
  (ensure-configured)

  (unless *integration-auth-session*
    ;; Initialize auth session
    (cl-telegram/api:reset-auth-session)

    ;; Set phone number
    (cl-telegram/api:set-authentication-phone-number
     (getf *integration-test-config* :phone))

    ;; Check if we need to authenticate
    (unless (cl-telegram/api:authorized-p)
      (if *skip-interactive-tests*
          (error "Not authenticated. Set *skip-interactive-tests* to NIL to run interactive auth.")
          (progn
            ;; Request code
            (cl-telegram/api:request-authentication-code)
            (format t "Enter code sent to ~A: " (getf *integration-test-config* :phone))
            (let ((code (read-line)))
              (cl-telegram/api:check-authentication-code code)
              (unless (cl-telegram/api:authorized-p)
                (error "Authentication failed"))))))

  (setf *integration-auth-session* t)
  t)

;;; ### Connection Tests

(test test-connect-to-datacenter
  "Test connection to Telegram datacenter"
  (let ((dc-manager (cl-telegram/api:make-dc-manager :test-mode nil)))
    (is dc-manager "Should create DC manager")

    ;; Measure latency to DC 1 (fastest for most regions)
    (let ((latency (cl-telegram/api:measure-dc-latency dc-manager 1)))
      (is latency "Should measure latency")
      (is (> latency 0) "Latency should be positive")
      (is (< latency 5000) "Latency should be reasonable (< 5s)"))))

(test test-connect-to-all-datacenters
  "Test connection to all Telegram datacenters"
  (let ((dc-manager (cl-telegram/api:make-dc-manager :test-mode nil)))
    (is dc-manager "Should create DC manager")

    ;; Test DCs 1-5
    (loop for dc-id from 1 to 5
          for latency = (cl-telegram/api:measure-dc-latency dc-manager dc-id)
          do (progn
               (format t "DC ~A latency: ~Ams~%" dc-id latency)
               (is latency "Should measure latency for DC ~A" dc-id)
               (is (> latency 0) "Latency should be positive")))))

(test test-measure-all-dc-latencies
  "Test measuring all DC latencies at once"
  (let ((dc-manager (cl-telegram/api:make-dc-manager :test-mode nil)))
    (cl-telegram/api:measure-all-dc-latencies dc-manager)

    ;; Check that latencies were measured
    (let ((latencies (cl-telegram/api::dc-manager-latencies dc-manager)))
      (is (> (hash-table-count latencies) 0) "Should have latency measurements"))))

;;; ### Authentication Tests (Non-Interactive)

(test test-auth-session-initialization
  "Test auth session initialization"
  (ensure-configured)

  (cl-telegram/api:reset-auth-session)
  (is (not (cl-telegram/api:authorized-p)) "Should not be authorized initially")

  ;; Set phone number
  (cl-telegram/api:set-authentication-phone-number
   (getf *integration-test-config* :phone))

  ;; Should be ready for code request
  (is (cl-telegram/api::auth-session-phone-number cl-telegram/api::*auth-session*)
      "Phone number should be set"))

(test test-request-auth-code
  "Test requesting authentication code"
  (ensure-configured)

  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number
   (getf *integration-test-config* :phone))

  ;; Request code (won't verify, just check no error)
  (handler-case
      (progn
        (cl-telegram/api:request-authentication-code)
        (pass "Should request auth code without error"))
    (error (e)
      (fail "Should not error when requesting code: ~A" e))))

;;; ### User API Tests

(test test-get-me
  "Test getting current user info"
  (ensure-authenticated)

  (let ((user (cl-telegram/api:get-me)))
    (is user "Should get current user")
    (is (getf user :id) "Should have user ID")
    (is (getf user :first-name) "Should have first name")
    (is (or (getf user :is-bot)
            (getf user :is-user))
        "Should be bot or user")))

(test test-get-me-cached
  "Test getting cached current user info"
  (ensure-authenticated)

  ;; First call caches
  (cl-telegram/api:get-me)

  ;; Second call should use cache
  (let ((cached-user (cl-telegram/api:get-cached-user
                      cl-telegram/api::*auth-user-id*)))
    (is cached-user "Should have cached user")
    (is (= (getf cached-user :id) cl-telegram/api::*auth-user-id*)
        "Cached user ID should match")))

;;; ### Chat API Tests

(test test-get-chats
  "Test getting chat list"
  (ensure-authenticated)

  (let ((chats (cl-telegram/api:get-chats :limit 20)))
    (is chats "Should get chat list")
    (is (listp chats) "Should return list")
    ;; Note: May be empty for new accounts
    (format t "Got ~A chats~%" (length chats))))

(test test-get-chat
  "Test getting single chat"
  (ensure-authenticated)

  (let ((chats (cl-telegram/api:get-chats :limit 5)))
    (when chats
      (let* ((first-chat (car chats))
             (chat-id (getf first-chat :id))
             (chat (cl-telegram/api:get-chat chat-id)))
        (is chat "Should get chat")
        (is (= (getf chat :id) chat-id) "Chat ID should match")))))

(test test-search-chats
  "Test searching chats"
  (ensure-authenticated)

  (let ((chats (cl-telegram/api:search-chats "" :limit 10)))
    (is chats "Should search chats")
    (is (<= (length chats) 10) "Should respect limit")))

;;; ### Message API Tests

(test test-send-message
  "Test sending a message"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      (let* ((text (format nil "Test message at ~A" (get-universal-time)))
             (result (cl-telegram/api:send-message test-chat-id text)))
        (is result "Should send message")
        (is (getf result :id) "Should have message ID")
        (is (string= (getf result :text) text) "Text should match")))))

(test test-get-messages
  "Test getting messages"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      (let ((messages (cl-telegram/api:get-messages test-chat-id :limit 10)))
        (is messages "Should get messages")
        (is (listp messages) "Should return list")
        (format t "Got ~A messages~%" (length messages))))))

(test test-edit-message
  "Test editing a message"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      ;; Send message first
      (let* ((original-text "Original text")
             (edit-text "Edited text")
             (sent (cl-telegram/api:send-message test-chat-id original-text)))
        (when sent
          (let* ((msg-id (getf sent :id))
                 (edited (cl-telegram/api:edit-message test-chat-id msg-id edit-text)))
            (is edited "Should edit message")
            (is (string= (getf edited :text) edit-text) "Text should be edited")))))))

(test test-delete-messages
  "Test deleting messages"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      ;; Send message first
      (let* ((sent (cl-telegram/api:send-message test-chat-id "Message to delete")))
        (when sent
          (let* ((msg-id (getf sent :id))
                 (result (cl-telegram/api:delete-messages test-chat-id (list msg-id))))
            (is result "Should delete messages")))))))

;;; ### File Transfer Tests

(test test-download-file
  "Test downloading a file"
  (ensure-authenticated)

  ;; This test requires a chat with media
  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      ;; Get messages with media
      (let ((messages (cl-telegram/api:get-messages test-chat-id :limit 50)))
        (let ((media-msg (find-if (lambda (m) (getf m :media)) messages)))
          (when media-msg
            (let* ((media (getf media-msg :media))
                   (file-id (getf media :file-id))
                   (temp-path (merge-pathnames
                               "test-download.tmp"
                               (uiop:temporary-directory))))
              (when file-id
                (let ((result (cl-telegram/api:download-file file-id temp-path)))
                  (is result "Should download file")
                  (is (probe-file temp-path) "File should exist")
                  ;; Cleanup
                  (ignore-errors (delete-file temp-path)))))))))))

;;; ### Group Chat Tests

(test test-get-chat-members
  "Test getting group chat members"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      (let ((members (cl-telegram/api:get-chat-members test-chat-id :limit 10)))
        ;; May fail if not a group
        (format t "Got ~A members (or error if not group)~%"
                (if members (length members) 0))))))

;;; ### Bot API Tests

(test test-bot-api-me
  "Test Bot API getMe equivalent"
  ;; Only runs if bot token is configured
  (let ((bot-token (uiop:getenv "TELEGRAM_BOT_TOKEN")))
    (when bot-token
      (let ((result (cl-telegram/api:|getMe|))
        (is result "Should get bot info")
        (is (getf result :id) "Should have bot ID")
        (is (getf result :is-bot) "Should be bot")))))

;;; ### Stress Tests

(test test-rapid-requests
  "Test handling rapid API requests"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      ;; Send 10 messages rapidly
      (let ((results
             (loop for i from 1 to 10
                   collect (cl-telegram/api:send-message
                            test-chat-id
                            (format nil "Rapid message ~A" i)))))
        (is (= (length results) 10) "Should send 10 messages")
        (is (every #'identity results) "All should succeed"))

      ;; Cleanup - delete all messages
      (sleep 1) ; Wait for messages to be processed
      (let ((messages (cl-telegram/api:get-messages test-chat-id :limit 10)))
        (when messages
          (let ((msg-ids (mapcar #'(lambda (m) (getf m :id)) messages)))
            (cl-telegram/api:delete-messages test-chat-id msg-ids)))))))

(test test-concurrent-requests
  "Test handling concurrent API requests"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id))
        (errors nil)
        (successes 0))
    (when test-chat-id
      ;; Spawn concurrent requests
      (let ((threads
             (loop for i from 1 to 5
                   collect
                   (bordeaux-threads:make-thread
                    (lambda ()
                      (handler-case
                          (progn
                            (cl-telegram/api:send-message
                             test-chat-id
                             (format nil "Concurrent message ~A" i))
                            (incf successes))
                        (error (e)
                          (push e errors))))))))
        ;; Wait for all threads
        (dolist (thread threads)
          (bordeaux-threads:join-thread thread)))

      (format t "Successes: ~A, Errors: ~A~%" successes (length errors))
      (is (> successes 0) "Some should succeed"))))

;;; ### Connection Resilience Tests

(test test-reconnect-after-disconnect
  "Test reconnection after disconnect"
  (ensure-authenticated)

  ;; Reset connection
  (cl-telegram/api:reset-connection)

  ;; Should auto-reconnect
  (let ((user (cl-telegram/api:get-me)))
    (is user "Should reconnect and get user")))

(test test-auto-reconnect
  "Test automatic reconnection"
  (ensure-authenticated)

  ;; Simulate network issue by closing connection
  (cl-telegram/api:reset-connection)

  ;; Wait for auto-reconnect
  (sleep 2)

  ;; Should be reconnected
  (let ((user (cl-telegram/api:get-me)))
    (is user "Should auto-reconnect and get user")))

;;; ### Cache Tests

(test test-message-caching
  "Test message caching"
  (ensure-authenticated)

  (let ((test-chat-id (getf *integration-test-config* :test-chat-id)))
    (when test-chat-id
      ;; Get messages (should cache)
      (cl-telegram/api:get-messages test-chat-id :limit 10)

      ;; Get cached messages
      (let ((cached (cl-telegram/api:get-cached-messages test-chat-id :limit 10)))
        (is cached "Should have cached messages")
        (format t "Cached ~A messages~%" (length cached))))))

(test test-user-caching
  "Test user caching"
  (ensure-authenticated)

  (let ((me (cl-telegram/api:get-me)))
    (when me
      (let ((user-id (getf me :id)))
        ;; Get from cache
        (let ((cached (cl-telegram/api:get-cached-user user-id)))
          (is cached "Should have cached user")
          (is (= (getf cached :id) user-id) "User ID should match"))))))

;;; ### Helper Functions

(defun run-integration-tests (&key interactive)
  "Run all integration tests.

   Args:
     interactive: If T, prompt for auth code if needed

   Returns:
     Test results"
  (setf *skip-interactive-tests* (not interactive))

  (format t "~%=== Running Integration Tests ===~%~%")

  (load-integration-config)
  (unless (getf *integration-test-config* :api-id)
    (format t "WARNING: Integration tests not configured~%")
    (format t "Set TELEGRAM_API_ID, TELEGRAM_API_HASH, TELEGRAM_TEST_PHONE~%~%")
    (return-from run-integration-tests nil))

  (fiveam:run! 'integration-telegram-tests))

(defun run-single-integration-test (test-name &key interactive)
  "Run a single integration test.

   Args:
     test-name: Test symbol or string
     interactive: If T, prompt for auth code

   Returns:
     Test result"
  (setf *skip-interactive-tests* (not interactive))
  (load-integration-config)
  (fiveam:run! test-name))
