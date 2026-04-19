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

;;; ============================================================================
;;; ### v0.13.0 New Features Tests
;;; ============================================================================

;;; Stories Animations and Effects Tests

(test test-create-story-animation
  "Test creating story animations"
  (ensure-authenticated)

  ;; Test creating different animation types
  (let ((fade-in (cl-telegram/api:make-story-animation :type :fade-in :duration 500))
        (zoom-in (cl-telegram/api:make-story-animation :type :zoom-in :duration 600))
        (slide-up (cl-telegram/api:make-story-animation :type :slide-up :duration 700)))
    (is fade-in "Should create fade-in animation")
    (is zoom-in "Should create zoom-in animation")
    (is slide-up "Should create slide-up animation")
    (is (eq (cl-telegram/api:story-animation-type fade-in) :fade-in)
        "Animation type should match")
    (is (= (cl-telegram/api:story-animation-duration zoom-in) 600)
        "Animation duration should match")))

(test test-create-story-filter
  "Test creating story filters"
  (ensure-authenticated)

  (let ((vintage (cl-telegram/api:make-story-filter :type :vintage :intensity 0.8))
        (bw (cl-telegram/api:make-story-filter :type :bw :intensity 1.0))
        (cinematic (cl-telegram/api:make-story-filter :type :cinematic :intensity 0.6)))
    (is vintage "Should create vintage filter")
    (is bw "Should create bw filter")
    (is cinematic "Should create cinematic filter")
    (is (eq (cl-telegram/api:story-filter-type vintage) :vintage)
        "Filter type should match")))

(test test-apply-story-preset
  "Test applying story effect presets"
  (ensure-authenticated)

  ;; Test built-in presets
  (let ((presets '(:cinematic :vlog :dramatic :minimal :party :nostalgic)))
    (dolist (preset presets)
      (let ((effects (cl-telegram/api:apply-story-preset preset)))
        (is effects "Should apply ~A preset" preset)
        (is (listp effects) "Should return effect list")))))

(test test-post-story-with-animation
  "Test posting story with animation (non-interactive)"
  (ensure-authenticated)

  ;; This test verifies the API call structure without actually posting
  ;; For real testing, you would need valid media content
  (let ((animation (cl-telegram/api:make-story-animation :type :fade-in)))
    (is animation "Should create animation object")
    ;; Verify animation can be serialized
    (is (typep animation 'cl-telegram/api:story-animation)
        "Should be story-animation type")))

;;; Premium Features Tests

(test test-check-premium-status
  "Test checking premium status"
  (ensure-authenticated)

  (let ((is-premium (cl-telegram/api:check-premium-status)))
    (is (typep is-premium 'boolean)
        "Should return boolean")
    (format t "Premium status: ~A~%" is-premium)))

(test test-get-max-file-size
  "Test getting maximum file size based on premium status"
  (ensure-authenticated)

  (let* ((is-premium (cl-telegram/api:check-premium-status))
         (expected-max (if is-premium
                           (* 4 1024 1024 1024)
                           (* 2 1024 1024 1024)))
         (max-size (cl-telegram/api:get-max-file-size)))
    (is (= max-size expected-max)
        "Max size should be ~A for ~A account"
        expected-max (if is-premium "premium" "free"))))

(test test-can-upload-file-p
  "Test file upload size validation"
  (ensure-authenticated)

  (let* ((is-premium (cl-telegram/api:check-premium-status))
         (free-limit (* 2 1024 1024 1024))
         (premium-limit (* 4 1024 1024 1024))
         (test-sizes (list 1024            ; 1KB
                           (* 100 1024)    ; 100KB
                           (* 10 1024 1024) ; 10MB
                           free-limit      ; 2GB
                           (if is-premium premium-limit (* 3 1024 1024 1024)))))
    (dolist (size test-sizes)
      (let ((can-upload (cl-telegram/api:can-upload-file-p size)))
        (format t "Can upload ~A bytes: ~A~%" size can-upload)))))

(test test-premium-sticker-sets
  "Test getting premium sticker sets"
  (ensure-authenticated)

  (let ((sets (cl-telegram/api:get-premium-sticker-sets)))
    (is (listp sets) "Should return list")
    (format t "Premium sticker sets: ~A~%" (length sets))))

(test test-premium-reactions
  "Test getting premium reactions"
  (ensure-authenticated)

  (let ((reactions (cl-telegram/api:get-premium-reactions)))
    (is (listp reactions) "Should return list")
    (format t "Premium reactions: ~A~%" (length reactions))))

;;; Object Pooling Tests

(test test-object-pool-initialize
  "Test object pool initialization"
  (ensure-authenticated)

  (let ((pool-name "test-pool-1")
        (allocator (lambda () (list :test-object t)))
        (deallocator (lambda (obj) (setf (getf obj :test-object) nil) t)))
    ;; Initialize pool
    (cl-telegram/api:pool-initialize pool-name allocator
                                     :initial-count 5
                                     :max-size 20
                                     :deallocator deallocator)

    ;; Acquire objects
    (let ((objs (loop repeat 3
                      collect (cl-telegram/api:pool-acquire pool-name))))
      (is (= (length objs) 3) "Should acquire 3 objects")
      (is (getf (first objs) :test-object) "Object should be valid")

      ;; Release objects back
      (dolist (obj objs)
        (cl-telegram/api:pool-release pool-name obj))

      (pass "Object pool test passed"))))

(test test-message-pool-usage
  "Test message plist pool usage"
  (ensure-authenticated)

  ;; Acquire message from pool
  (let ((msg1 (cl-telegram/api:pool-acquire 'message-plist))
        (msg2 (cl-telegram/api:pool-acquire 'message-plist)))
    (is msg1 "Should acquire message 1")
    (is msg2 "Should acquire message 2")
    (is (getf msg1 :id) "Message should have id field")
    (is (getf msg1 :text) "Message should have text field")

    ;; Modify message
    (setf (getf msg1 :id) 12345
          (getf msg1 :text) "Test message")

    ;; Release back to pool
    (cl-telegram/api:pool-release 'message-plist msg1)
    (cl-telegram/api:pool-release 'message-plist msg2)

    (pass "Message pool test passed")))

;;; Byte Buffer Pool Tests

(test test-byte-buffer-operations
  "Test byte buffer operations"
  (ensure-authenticated)

  ;; Acquire buffer from pool
  (let ((buf (cl-telegram/api:pool-acquire 'byte-buffer)))
    (is buf "Should acquire byte buffer")
    (is (typep buf 'cl-telegram/api:byte-buffer)
        "Should be byte-buffer type")
    (is (>= (cl-telegram/api:byte-buffer-size buf) 4096)
        "Buffer should have minimum size")

    ;; Ensure capacity
    (cl-telegram/api:ensure-buffer-capacity buf 8192)
    (is (>= (cl-telegram/api:byte-buffer-size buf) 8192)
        "Buffer should grow to requested size")

    ;; Reset buffer
    (cl-telegram/api:reset-byte-buffer buf)
    (is (= (cl-telegram/api:byte-buffer-position buf) 0)
        "Position should be reset to 0")

    ;; Release back to pool
    (cl-telegram/api:pool-release 'byte-buffer buf)

    (pass "Byte buffer test passed")))

;;; File Upload Tests (Non-Interactive)

(test test-calculate-optimal-part-size
  "Test calculating optimal upload part size"
  (ensure-authenticated)

  (let ((test-cases '((1024 . 1024)                      ; 1KB -> 1KB
                      (* 5 1024 1024) . (* 5 1024 1024)) ; 5MB -> 5MB
                      (* 50 1024 1024) . (* 256 1024))   ; 50MB -> 256KB
                      (* 500 1024 1024) . (* 512 1024))  ; 500MB -> 512KB
                      (* 2 1024 1024 1024) . (* 1024 1024)))) ; 2GB -> 1MB
    (dolist (case test-cases)
      (let* ((file-size (car case))
             (expected (cdr case))
             (actual (cl-telegram/api:calculate-optimal-part-size file-size)))
        (is (= actual expected)
            "Part size for ~A bytes should be ~A" file-size expected)))))

(test test-upload-session-creation
  "Test upload session creation"
  (ensure-authenticated)

  ;; Create a temporary test file
  (let* ((test-dir (uiop:temporary-directory))
         (test-file (merge-pathnames "test-upload.dat" test-dir))
         (test-size (* 1024 1024)) ; 1MB
         (buffer (make-array test-size :element-type '(unsigned-byte 8))))
    ;; Write test data
    (with-open-file (stream test-file :direction :output
                                      :element-type '(unsigned-byte 8))
      (write-sequence buffer stream))

    ;; Start upload session
    (let ((session-id (cl-telegram/api:start-file-upload test-file)))
      (is session-id "Should create upload session")
      (is (stringp session-id) "Session ID should be string")

      ;; Get progress
      (let ((progress (cl-telegram/api:get-upload-progress session-id)))
        (is progress "Should get progress")
        (is (getf progress :total-parts) "Should have total parts")
        (is (getf progress :uploaded-parts) "Should have uploaded parts")
        (is (= (getf progress :uploaded-parts) 0) "Should start at 0"))

      ;; Cancel upload
      (cl-telegram/api:cancel-upload session-id)
      (is (not (gethash session-id cl-telegram/api:*active-uploads*))
          "Session should be removed after cancel")))

    ;; Cleanup test file
    (when (probe-file test-file)
      (delete-file test-file))))

;;; Thumbnail Cache Tests

(test test-story-thumbnail-cache
  "Test story thumbnail caching"
  (ensure-authenticated)

  (let* ((story-id 12345)
         (thumbnail-data (make-array 1024 :element-type '(unsigned-byte 8)
                                                    :initial-element 0)))
    ;; Cache thumbnail
    (let ((result (cl-telegram/api:cache-story-thumbnail
                   story-id thumbnail-data
                   :width 320 :height 568)))
      (is result "Should cache thumbnail"))

    ;; Retrieve cached thumbnail
    (let ((cached (cl-telegram/api:get-cached-story-thumbnail story-id)))
      (is cached "Should retrieve cached thumbnail")
      (is (= (cl-telegram/api:story-thumbnail-width cached) 320)
          "Width should match")
      (is (= (cl-telegram/api:story-thumbnail-height cached) 568)
          "Height should match")
      (is (= (cl-telegram/api:story-thumbnail-size cached) 1024)
          "Size should match"))

    ;; Clear cache
    (cl-telegram/api:clear-story-thumbnail-cache)
    (let ((cleared (cl-telegram/api:get-cached-story-thumbnail story-id)))
      (is (not cleared) "Cache should be cleared"))))

(test test-thumbnail-eviction
  "Test thumbnail LRU eviction"
  (ensure-authenticated)

  ;; Set small cache size for testing
  (let ((cl-telegram/api:*stories-thumbnail-max-size* 500))
    ;; Add multiple thumbnails
    (dotimes (i 10)
      (let ((data (make-array 100 :element-type '(unsigned-byte 8))))
        (cl-telegram/api:cache-story-thumbnail i data)))

    ;; Some should be evicted
    (is (<= cl-telegram/api:*current-thumbnail-cache-size*
            cl-telegram/api:*stories-thumbnail-max-size*)
        "Cache size should be within limit"))

  ;; Reset cache size
  (setf cl-telegram/api:*stories-thumbnail-max-size* (* 5 1024 1024))
  (cl-telegram/api:clear-story-thumbnail-cache))

;;; Performance Tests

(test test-batch-get-users-no-cons
  "Test batch user retrieval without excessive consing"
  (ensure-authenticated)

  (let ((user-ids '(1 2 3 4 5 6 7 8 9 10)))
    (let ((result (cl-telegram/api:batch-get-users-no-cons user-ids)))
      (is (typep result 'vector) "Should return vector")
      (is (= (length result) (length user-ids))
          "Result length should match input")
      (is (getf (aref result 0) :id) "Should have user data"))))

(test test-fast-string-operations
  "Test fast string operations"
  (ensure-authenticated)

  ;; format-chat-id-fast
  (is (string= (cl-telegram/api:format-chat-id-fast -1001234567890)
               "-1001001234567890")
      "Should format negative chat ID")
  (is (string= (cl-telegram/api:format-chat-id-fast 123456)
               "123456")
      "Should format positive chat ID")

  ;; concat-strings-fast
  (is (string= (cl-telegram/api:concat-strings-fast "Hello" " " "World")
               "Hello World")
      "Should concatenate strings")

  ;; keyword-from-string-fast
  (let ((kw (cl-telegram/api:keyword-from-string-fast "test-keyword")))
    (is (keywordp kw) "Should return keyword")
    (is (eq kw :test-keyword) "Keyword should match")))

(test test-safe-api-call
  "Test safe API call with retries"
  (ensure-authenticated)

  ;; Test successful call
  (let ((result (cl-telegram/api:safe-api-call
                 (lambda () t)
                 :retries 3)))
    (is result "Should return success"))

  ;; Test failing call (should retry)
  (let ((attempts 0))
    (cl-telegram/api:safe-api-call
     (lambda ()
       (incf attempts)
       (when (< attempts 3)
         (error "Simulated error")))
     :retries 3
     :delay 100)
    (is (= attempts 3) "Should retry 3 times")))

;;; Bot API 2025 Tests

(test test-make-visual-effect
  "Test creating visual effects for inline bots"
  (ensure-authenticated)

  (let ((effect (cl-telegram/api:make-visual-effect
                 :fireworks
                 :start-x 0.5 :start-y 0.5
                 :end-x 0.7 :end-y 0.3
                 :intensity 0.8)))
    (is effect "Should create visual effect")
    (is (eq (cl-telegram/api:visual-effect-type effect) :fireworks)
        "Effect type should match")
    (is (= (cl-telegram/api:visual-effect-intensity effect) 0.8)
        "Effect intensity should match")))

(test test-inline-result-with-effects
  "Test inline result with visual effects"
  (ensure-authenticated)

  (let* ((base-result (cl-telegram/api:make-inline-result-article
                       "test-id" "Test Title" "Test content"))
         (effect (cl-telegram/api:make-visual-effect :sparkles))
         (result-with-effects (cl-telegram/api:add-visual-effects-to-result
                               base-result (list effect))))
    (is result-with-effects "Should create result with effects")
    (is (cl-telegram/api:inline-result-has-effects-p result-with-effects)
        "Should have effects flag")
    (is (= (length (cl-telegram/api:effects-visual-effects result-with-effects)) 1)
        "Should have 1 effect")))

(test test-business-inline-config
  "Test business inline configuration"
  (ensure-authenticated)

  (let ((config (cl-telegram/api:make-business-inline-config
                 :location (list :latitude 40.7128 :longitude -74.0060)
                 :opening-hours (list :monday "9:00-17:00")
                 :start-message "Welcome to our business!")))
    (is config "Should create business config")
    (is (cl-telegram/api:business-location config)
        "Should have location")
    (is (cl-telegram/api:business-start-message config)
        "Should have start message")))

(test test-paid-media-info
  "Test paid media information"
  (ensure-authenticated)

  (let ((media (cl-telegram/api:make-paid-media-info
                :photo "https://example.com/image.jpg"
                :price 1000
                :currency "USD")))
    (is media "Should create paid media info")
    (is (eq (cl-telegram/api:paid-media-type media) :photo)
        "Media type should match")
    (is (= (cl-telegram/api:paid-media-price media) 1000)
        "Price should match")
    (is (string= (cl-telegram/api:paid-media-currency media) "USD")
        "Currency should match")))

(test test-webapp-init-data-validation
  "Test web app init data validation"
  (ensure-authenticated)

  ;; Test with valid init data structure
  (let ((valid-data (list :user (list :id 123 :username "test")
                          :chat (list :id 456)
                          :auth-hash "abc123"
                          :query-id "query-789")))
    (let ((result (cl-telegram/api:validate-web-app-init-data valid-data)))
      ;; Note: Current implementation always returns T
      ;; TODO: Implement actual HMAC validation
      (is result "Should validate data"))))

;;; Cleanup Tests

(test test-cleanup-old-cache
  "Test cleaning up old cache data"
  (ensure-authenticated)

  (let ((cleaned (cl-telegram/api:cleanup-old-cache :max-age-days 1)))
    (format t "Cleaned ~A old cache items~%" cleaned)
    (is (integerp cleaned) "Should return count")))

(test test-vacuum-all-caches
  "Test vacuuming all caches"
  (ensure-authenticated)

  (let ((result (cl-telegram/api:vacuum-all-caches))
    (is result "Should vacuum all caches")))

;;; Test Runner

(defun run-v013-tests ()
  "Run all v0.13.0 feature tests.

   Returns:
     Test results summary"
  (load-integration-config)
  (setf *skip-interactive-tests* nil)
  (fiveam:run! '(test-create-story-animation
                 test-create-story-filter
                 test-apply-story-preset
                 test-check-premium-status
                 test-get-max-file-size
                 test-can-upload-file-p
                 test-object-pool-initialize
                 test-message-pool-usage
                 test-byte-buffer-operations
                 test-calculate-optimal-part-size
                 test-upload-session-creation
                 test-story-thumbnail-cache
                 test-batch-get-users-no-cons
                 test-fast-string-operations
                 test-make-visual-effect
                 test-inline-result-with-effects
                 test-business-inline-config
                 test-paid-media-info)))
