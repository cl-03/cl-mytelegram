;;; ui-tests.lisp --- Tests for UI layer

(in-package #:cl-telegram/tests)

(def-suite* ui-tests
  :description "Tests for UI layer")

;;; ### CLI Client tests

(test cli-client-creation
  "Test CLI client creation"
  (let ((client (make-instance 'cl-telegram/ui::cli-client)))
    (is (typep client 'cl-telegram/ui::cli-client))
    (is (member (cl-telegram/ui::cli-auth-state client)
                '(:wait-tdlib-parameters :wait-phone-number :wait-code
                  :wait-password :wait-registration :ready)))))

(test cli-input
  "Test CLI input reading"
  (let ((input "test message"))
    (is (string= input (cl-telegram/ui::cli-read-input)))))

(test cli-display-message
  "Test CLI message display"
  ;; Just verify it doesn't error
  (is (cl-telegram/ui::cli-display-message "Hello, World!"))))

(test cli-display-chat-list
  "Test CLI chat list display"
  (let ((chats '((:id 1 :name "Alice" :last_message "Hi")
                 (:id 2 :name "Bob" :last_message "Hello"))))
    ;; Just verify it doesn't error
    (is (cl-telegram/ui::cli-display-chat-list chats))))

(test cli-command-processing
  "Test CLI command processing"
  ;; Test /help command
  (is (cl-telegram/ui::cli-process-command "/help"))
  ;; Test /chats command
  (is (cl-telegram/ui::cli-process-command "/chats"))
  ;; Test /me command
  (is (cl-telegram/ui::cli-process-command "/me"))
  ;; Test /quit command
  (is (cl-telegram/ui::cli-process-command "/quit"))
  ;; Test empty command
  (is (cl-telegram/ui::cli-process-command "")))

(test cli-send-message
  "Test CLI message sending"
  ;; Just verify it doesn't error
  (is (cl-telegram/ui::cli-send-message "Test message")))

(test cli-string-prefix-p
  "Test string prefix predicate"
  (is (cl-telegram/ui::string-prefix-p "/send hello" "/send"))
  (is (not (cl-telegram/ui::string-prefix-p "/send" "/quit")))
  (is (cl-telegram/ui::string-prefix-p "hello" "h"))
  (is (not (cl-telegram/ui::string-prefix-p "hi" "hello"))))

;;; ### UI State tests

(test ui-state-variables
  "Test UI state variables"
  (is (or (null cl-telegram/ui::*cli-client*)
          (typep cl-telegram/ui::*cli-client* 'cl-telegram/ui::cli-client)))
  (is (listp cl-telegram/ui::*cli-chats*))
  (is (typep cl-telegram/ui::*cli-messages* 'hash-table)))

(defun run-ui-tests ()
  "Run all UI tests"
  (run! 'ui-tests))
