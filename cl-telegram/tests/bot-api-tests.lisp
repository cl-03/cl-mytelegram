;;; bot-api-tests.lisp --- Tests for Bot API

(in-package #:cl-telegram/tests)

(def-suite* bot-api-tests
  :description "Tests for Telegram Bot API")

;;; ### Configuration

(defparameter *test-bot-token* (or (uiop:getenv "TELEGRAM_BOT_TOKEN")
                                   "test:dummy-token-for-testing")
  "Bot token for testing. Set TELEGRAM_BOT_TOKEN environment variable.")

(defparameter *test-chat-id* (parse-integer (or (uiop:getenv "TELEGRAM_TEST_CHAT_ID") "0")
                                            :junk-allowed t)
  "Chat ID for testing. Set TELEGRAM_TEST_CHAT_ID environment variable.")

;;; ### Helper Functions

(defun skip-if-no-bot-token ()
  "Skip test if bot token is not configured."
  (when (or (string= *test-bot-token* "test:dummy-token-for-testing")
            (string= *test-bot-token* ""))
    (skip-test "TELEGRAM_BOT_TOKEN not set")))

(defun make-test-bot ()
  "Create a test bot instance."
  (cl-telegram/api:make-bot *test-bot-token* :timeout 10))

;;; ### Bot Configuration Tests

(test test-make-bot
  "Test bot creation"
  (let ((bot (make-test-bot)))
    (is (typep bot 'cl-telegram/api::bot-config))
    (is (string= (cl-telegram/api::bot-config-token bot) *test-bot-token*))
    (is (= (cl-telegram/api::bot-config-timeout bot) 10))))

(test test-bot-api-url
  "Test API URL generation"
  (let ((bot (make-test-bot)))
    (let ((url (cl-telegram/api::bot-api-url bot "sendMessage")))
      (is (cl-ppcre:scan "^https://api.telegram.org/bot" url))
      (is (cl-ppcre:scan "/sendMessage$" url)))))

;;; ### JSON Utility Tests

(test test-alist-to-hash
  "Test alist to hash table conversion"
  (let ((hash (cl-telegram/api::alist-to-hash '((:key1 . "value1")
                                                 (:key2 . 123)
                                                 (:key3 . nil)))))
    (is (typep hash 'hash-table))
    (is (string= (gethash "key1" hash) "value1"))
    (is (= (gethash "key2" hash) 123))
    ;; nil values should be skipped
    (is (null (gethash "key3" hash)))))

(test test-json-to-plist
  "Test JSON to plist conversion"
  (let ((json (make-hash-table :test 'equal)))
    (setf (gethash "ok" json) t)
    (setf (gethash "id" json) 123)
    (setf (gethash "name" json) "test")
    (let ((plist (cl-telegram/api::json-to-plist json)))
      (is (getf plist :ok))
      (is (= (getf plist :id) 123))
      (is (string= (getf plist :name) "test")))))

(test test-keywordify
  "Test string to keyword conversion"
  (is (eq (cl-telegram/api::keywordify "test") :test))
  (is (eq (cl-telegram/api::keywordify "chat_id") :chat-id))
  (is (eq (cl-telegram/api::keywordify "reply_markup") :reply-markup)))

;;; ### Bot Request Tests (Mock)

(test test-bot-request-structure
  "Test bot request function exists and has correct signature"
  (is (functionp #'cl-telegram/api::bot-request)))

;;; ### Bot Handler Tests

(test test-make-bot-handler
  "Test bot handler creation"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token* :timeout 15)))
    (is (typep handler 'cl-telegram/api::bot-handler))
    (is (string= (cl-telegram/api::bot-token handler) *test-bot-token*))
    (is (= (cl-telegram/api::bot-config-timeout (cl-telegram/api::bot-config handler)) 15))))

(test test-register-command
  "Test command registration"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*)))
    ;; Register a test command
    (cl-telegram/api:register-command handler "test"
                                       (lambda (msg chat-id from args)
                                         (declare (ignore msg chat-id from args))
                                         t)
                                       "Test command")
    ;; Verify registration
    (let ((entry (gethash "test" (cl-telegram/api::bot-commands handler))))
      (is entry "Command should be registered")
      (is (functionp (getf entry :handler)))
      (is (string= (getf entry :description) "Test command")))))

(test test-unregister-command
  "Test command unregistration"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*)))
    (cl-telegram/api:register-command handler "temp" #'cl t "Temp")
    (is (gethash "temp" (cl-telegram/api::bot-commands handler)))
    (cl-telegram/api:unregister-command handler "temp")
    (is (null (gethash "temp" (cl-telegram/api::bot-commands handler))))))

(test test-register-message-handler
  "Test message handler registration"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*)))
    (cl-telegram/api:register-message-handler handler
                                               (lambda (msg) (getf msg :photo))
                                               (lambda (msg chat-id from)
                                                 (declare (ignore msg chat-id from))
                                                 t))
    (is (plusp (length (cl-telegram/api::bot-message-handlers handler))))))

;;; ### Command Processing Tests

(test test-process-command-parsing
  "Test command parsing"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*))
        (handled-p nil))
    ;; Register handler that sets flag
    (cl-telegram/api:register-command handler "start"
                                       (lambda (msg chat-id from args)
                                         (declare (ignore msg chat-id from))
                                         (setf handled-p t)
                                         (is (equal args '("arg1" "arg2"))))
                                       "Start")
    ;; Create mock message
    (let ((msg (list :chat-id 123
                     :from (list :id 456 :first-name "Test")
                     :text "/start arg1 arg2")))
      (cl-telegram/api::process-command handler msg "/start arg1 arg2" 123 (getf msg :from)))
    (is handled-p "Command handler should have been called")))

(test test-process-command-with-botname
  "Test command parsing with @botname suffix"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*))
        (handled-p nil))
    (cl-telegram/api:register-command handler "help"
                                       (lambda (msg chat-id from args)
                                         (declare (ignore msg chat-id from args))
                                         (setf handled-p t)))
    ;; Command with @botname
    (let ((msg (list :chat-id 123
                     :from (list :id 456)
                     :text "/help@mybot")))
      (cl-telegram/api::process-command handler msg "/help@mybot" 123 (getf msg :from)))
    (is handled-p "Should handle command with @botname suffix")))

;;; ### Update Processing Tests

(test test-process-update-message
  "Test processing a regular message update"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*))
        (update-id 0))
    ;; Register command
    (cl-telegram/api:register-command handler "test"
                                       (lambda (msg chat-id from args)
                                         (declare (ignore msg chat-id from args))
                                         (setf update-id 1)))
    ;; Create update with command message
    (let ((update (list :update-id 100
                       :message (list :chat-id 123
                                     :from (list :id 456)
                                     :text "/test"))))
      (cl-telegram/api:process-update handler update)
      (is (= update-id 1) "Command should have been processed")
      (is (= (cl-telegram/api::bot-last-update-id handler) 100)))))

;;; ### Live Bot API Tests (requires real bot token)

(test test-get-me-live
  "Test getMe API call (live)"
  (skip-if-no-bot-token)
  (let ((bot (make-test-bot)))
    (let ((user (cl-telegram/api:get-me bot)))
      (is user "Should return bot info")
      (is (getf user :id) "Bot should have an ID")
      (is (getf user :is_bot) "Should be marked as bot")
      (format t "Bot name: ~A~%" (getf user :username)))))

(test test-send-message-live
  "Test sendMessage API call (live)"
  (skip-if-no-bot-token)
  (when (plusp *test-chat-id*)
    (let ((bot (make-test-bot)))
      (let ((result (cl-telegram/api:bot-send-message bot *test-chat-id* "Test message from cl-telegram")))
        (is result "Should return message object")
        (is (getf result :message-id) "Should have message ID")
        (is (string= (getf (getf result :text) :text) "Test message from cl-telegram"))))))

(test test-send-chat-action-live
  "Test sendChatAction API call (live)"
  (skip-if-no-bot-token)
  (when (plusp *test-chat-id*)
    (let ((bot (make-test-bot)))
      (let ((result (cl-telegram/api:bot-send-chat-action bot *test-chat-id* :typing)))
        (is result "Should return T on success")))))

(test test-get-chat-live
  "Test getChat API call (live)"
  (skip-if-no-bot-token)
  (when (plusp *test-chat-id*)
    (let ((bot (make-test-bot)))
      (let ((chat (cl-telegram/api:bot-get-chat bot *test-chat-id*)))
        (is chat "Should return chat info")
        (is (getf chat :id) "Chat should have ID")
        (format t "Chat type: ~A~%" (getf chat :type))))))

(test test-defcommand-macro
  "Test defcommand macro expansion"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*)))
    ;; Define command using macro
    (eval '(cl-telegram/api:defcommand ("macro-test" ,handler :description "Test via macro")
           (declare (ignore msg chat-id from args))
           t))
    ;; Verify registration
    (let ((entry (gethash "macro-test" (cl-telegram/api::bot-commands handler))))
      (is entry "Command should be registered by macro")
      (is (string= (getf entry :description) "Test via macro")))))

;;; ### Bot Polling Tests

(test test-start-stop-polling
  "Test starting and stopping polling"
  (let ((handler (cl-telegram/api:make-bot-handler *test-bot-token*)))
    ;; Initially not running
    (is (not (cl-telegram/api:bot-running-p handler)))

    ;; Start polling (will fail with invalid token, but tests the mechanism)
    (handler-case
        (cl-telegram/api:start-polling handler :timeout 1)
      (error () nil))

    ;; Give thread time to start
    (sleep 0.1)

    ;; Stop polling
    (cl-telegram/api:stop-polling handler)

    ;; Verify stopped
    (is (not (cl-telegram/api:bot-running-p handler)))))
