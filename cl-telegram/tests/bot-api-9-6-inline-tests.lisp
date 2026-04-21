;;; bot-api-9-6-inline-tests.lisp --- Tests for Bot API 9.6+ Inline Mode Enhancements
;;;
;;; Test suite for:
;;; - SwitchInlineQueryChosenChat support
;;; - MenuButton types (commands, bot_apps, default)
;;; - InlineQueryResultsButton
;;; - KeyboardButtonRequestManagedBot
;;; - Enhanced inline keyboard buttons
;;;
;;; Version: 0.38.0

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-6-inline-tests
  :description "Tests for Bot API 9.6+ Inline Mode enhancements")

;;; ============================================================================
;;; Section 1: SwitchInlineQueryChosenChat Tests
;;; ============================================================================

(test test-switch-inline-query-chosen-chat-creation
  "Test SwitchInlineQueryChosenChat class creation"
  (let ((chosen-chat (make-instance 'cl-telegram/api::switch-inline-query-chosen-chat
                                    :query "Share this"
                                    :allow-user-chats t
                                    :allow-bot-chats nil
                                    :allow-group-chats t
                                    :allow-channel-chats nil)))
    (is (string= "Share this" (cl-telegram/api::switch-inline-query-chosen-chat-query chosen-chat)))
    (is (eq t (cl-telegram/api::switch-inline-query-allow-users chosen-chat)))
    (is (eq nil (cl-telegram/api::switch-inline-query-allow-bots chosen-chat)))
    (is (eq t (cl-telegram/api::switch-inline-query-allow-groups chosen-chat)))
    (is (eq nil (cl-telegram/api::switch-inline-query-allow-channels chosen-chat)))))

(test test-make-switch-inline-query-chosen-chat
  "Test make-switch-inline-query-chosen-chat function"
  (let ((chosen-chat (cl-telegram/api:make-switch-inline-query-chosen-chat
                       :query "Check this out"
                       :allow-user-chats t
                       :allow-group-chats t
                       :allow-channel-chats t)))
    (is (string= "Check this out" (cl-telegram/api::switch-inline-query-chosen-chat-query chosen-chat)))
    (is (eq t (cl-telegram/api::switch-inline-query-allow-users chosen-chat)))
    (is (eq t (cl-telegram/api::switch-inline-query-allow-groups chosen-chat)))
    (is (eq t (cl-telegram/api::switch-inline-query-allow-channels chosen-chat)))))

(test test-make-switch-inline-query-chosen-chat-defaults
  "Test make-switch-inline-query-chosen-chat with default values"
  (let ((chosen-chat (cl-telegram/api:make-switch-inline-query-chosen-chat)))
    (is (eq nil (cl-telegram/api::switch-inline-query-chosen-chat-query chosen-chat)))
    (is (eq t (cl-telegram/api::switch-inline-query-allow-users chosen-chat)))
    (is (eq nil (cl-telegram/api::switch-inline-query-allow-bots chosen-chat)))
    (is (eq nil (cl-telegram/api::switch-inline-query-allow-groups chosen-chat)))
    (is (eq nil (cl-telegram/api::switch-inline-query-allow-channels chosen-chat)))))

;;; ============================================================================
;;; Section 2: Enhanced Inline Keyboard Button Tests
;;; ============================================================================

(test test-make-inline-keyboard-button-enhanced
  "Test make-inline-keyboard-button-enhanced function"
  (let ((chosen-chat (cl-telegram/api:make-switch-inline-query-chosen-chat
                       :query "Share"
                       :allow-group-chats t))
        (button (cl-telegram/api:make-inline-keyboard-button-enhanced
                  "Share in Group"
                  :switch-inline-query-chosen-chat chosen-chat)))
    (is (string= "Share in Group" (cl-telegram/api::inline-button-text button)))
    (is (typep (cl-telegram/api::switch-inline-query-chosen-chat button)
               'cl-telegram/api::switch-inline-query-chosen-chat))))

(test test-inline-keyboard-button-with-switch-chat
  "Test inline-keyboard-button-with-switch-chat function"
  (let ((button (cl-telegram/api:inline-keyboard-button-with-switch-chat
                  "Share in Chat"
                  "Check this out"
                  :allow-groups t
                  :allow-channels t)))
    (is (string= "Share in Chat" (cl-telegram/api::inline-button-text button)))
    (let ((chosen-chat (cl-telegram/api::switch-inline-query-chosen-chat button)))
      (is (typep chosen-chat 'cl-telegram/api::switch-inline-query-chosen-chat))
      (is (string= "Check this out" (cl-telegram/api::switch-inline-query-chosen-chat-query chosen-chat)))
      (is (eq t (cl-telegram/api::switch-inline-query-allow-groups chosen-chat)))
      (is (eq t (cl-telegram/api::switch-inline-query-allow-channels chosen-chat))))))

;;; ============================================================================
;;; Section 3: InlineQueryResultsButton Tests
;;; ============================================================================

(test test-inline-query-results-button-creation
  "Test InlineQueryResultsButton class creation"
  (let ((button (make-instance 'cl-telegram/api::inline-query-results-button
                               :text "Launch App"
                               :start-parameter "app_launch")))
    (is (string= "Launch App" (cl-telegram/api::inline-query-results-button-text button)))
    (is (string= "app_launch" (cl-telegram/api::inline-query-results-button-start-param button)))))

(test test-make-inline-query-results-button
  "Test make-inline-query-results-button function"
  (let ((button (cl-telegram/api:make-inline-query-results-button
                  "Open Web App"
                  :start-parameter "open_app")))
    (is (string= "Open Web App" (cl-telegram/api::inline-query-results-button-text button)))
    (is (string= "open_app" (cl-telegram/api::inline-query-results-button-start-param button)))))

(test test-make-inline-query-results-button-with-web-app
  "Test make-inline-query-results-button with web app"
  (let ((web-app (list :url "https://example.com"))
        (button (cl-telegram/api:make-inline-query-results-button
                  "Launch"
                  :web-app (list :url "https://example.com")
                  :start-parameter "launch")))
    (is (string= "Launch" (cl-telegram/api::inline-query-results-button-text button)))
    (is (equal web-app (cl-telegram/api::inline-query-results-button-web-app button)))))

;;; ============================================================================
;;; Section 4: MenuButton Tests
;;; ============================================================================

(test test-menu-button-default-creation
  "Test MenuButton default type creation"
  (let ((button (cl-telegram/api:make-menu-button-default)))
    (is (eq :default (cl-telegram/api::menu-button-type button)))
    (is (eq nil (cl-telegram/api::menu-button-text button)))
    (is (eq nil (cl-telegram/api::menu-button-web-app button)))))

(test test-menu-button-commands-creation
  "Test MenuButton commands type creation"
  (let ((button (cl-telegram/api:make-menu-button-commands)))
    (is (eq :commands (cl-telegram/api::menu-button-type button)))
    (is (eq nil (cl-telegram/api::menu-button-text button)))
    (is (eq nil (cl-telegram/api::menu-button-web-app button)))))

(test test-menu-button-web-app-creation
  "Test MenuButton web_app type creation"
  (let ((web-app (list :url "https://app.example.com"))
        (button (cl-telegram/api:make-menu-button-web-app "Open App" web-app)))
    (is (eq :web_app (cl-telegram/api::menu-button-type button)))
    (is (string= "Open App" (cl-telegram/api::menu-button-text button)))
    (is (equal web-app (cl-telegram/api::menu-button-web-app button)))))

;;; ============================================================================
;;; Section 5: KeyboardButtonRequestManagedBot Tests
;;; ============================================================================

(test test-keyboard-button-request-managed-bot-creation
  "Test KeyboardButtonRequestManagedBot class creation"
  (let ((request (make-instance 'cl-telegram/api::keyboard-button-request-managed-bot
                                :request-id 12345
                                :user-is-bot nil
                                :user-is-premium t
                                :request-name t
                                :request-username t)))
    (is (= 12345 (cl-telegram/api::keyboard-button-request-managed-bot-id request)))
    (is (eq nil (cl-telegram/api::keyboard-button-request-managed-bot-is-bot request)))
    (is (eq t (cl-telegram/api::keyboard-button-request-managed-bot-is-premium request)))
    (is (eq t (cl-telegram/api::keyboard-button-request-managed-bot-name request)))
    (is (eq t (cl-telegram/api::keyboard-button-request-managed-bot-username request)))))

(test test-make-keyboard-button-request-managed-bot
  "Test make-keyboard-button-request-managed-bot function"
  (let ((request (cl-telegram/api:make-keyboard-button-request-managed-bot
                   67890
                   :request-username t
                   :request-name t)))
    (is (= 67890 (cl-telegram/api::keyboard-button-request-managed-bot-id request)))
    (is (eq nil (cl-telegram/api::keyboard-button-request-managed-bot-is-bot request)))
    (is (eq nil (cl-telegram/api::keyboard-button-request-managed-bot-is-premium request)))
    (is (eq t (cl-telegram/api::keyboard-button-request-managed-bot-name request)))
    (is (eq t (cl-telegram/api::keyboard-button-request-managed-bot-username request)))))

(test test-make-keyboard-button-request-managed-bot-with-all-options
  "Test make-keyboard-button-request-managed-bot with all options"
  (let ((request (cl-telegram/api:make-keyboard-button-request-managed-bot
                   11111
                   :user-is-bot t
                   :user-is-premium t
                   :request-name t
                   :request-username t)))
    (is (= 11111 (cl-telegram/api::keyboard-button-request-managed-bot-id request)))
    (is (eq t (cl-telegram/api::keyboard-button-request-managed-bot-is-bot request)))
    (is (eq t (cl-telegram/api::keyboard-button-request-managed-bot-is-premium request)))))

;;; ============================================================================
;;; Section 6: API Method Tests (Without Connection)
;;; ============================================================================

(test test-set-chat-menu-button-no-connection
  "Test set-chat-menu-button without connection (should return NIL)"
  (let ((result (cl-telegram/api:set-chat-menu-button
                  :chat-id -1001234567890
                  :menu-button (cl-telegram/api:make-menu-button-commands))))
    (is (or (null result)
            (eq result t)))))

(test test-get-chat-menu-button-no-connection
  "Test get-chat-menu-button without connection (should return NIL)"
  (let ((result (cl-telegram/api:get-chat-menu-button :chat-id -1001234567890)))
    (is (or (null result)
            (typep result 'cl-telegram/api::menu-button)))))

(test test-answer-inline-query-enhanced-no-connection
  "Test answer-inline-query-enhanced without connection"
  (let ((result (cl-telegram/api:answer-inline-query-enhanced
                  "query_123"
                  (list (cl-telegram/api:make-inline-result-article
                          "1" "Title" nil))
                  :button (cl-telegram/api:make-inline-query-results-button
                            "Button"
                            :start-parameter "test"))))
    (is (or (null result)
            (eq result t)))))

;;; ============================================================================
;;; Section 7: Serialization Tests
;;; ============================================================================

(test test-serialize-switch-inline-query-chosen-chat
  "Test serialize-switch-inline-query-chosen-chat function"
  (let ((chosen-chat (cl-telegram/api:make-switch-inline-query-chosen-chat
                       :query "Test query"
                       :allow-user-chats t
                       :allow-bot-chats nil
                       :allow-group-chats t
                       :allow-channel-chats nil))
        (serialized (cl-telegram/api:serialize-switch-inline-query-chosen-chat
                      (cl-telegram/api:make-switch-inline-query-chosen-chat
                        :query "Test query"
                        :allow-user-chats t
                        :allow-bot-chats nil
                        :allow-group-chats t
                        :allow-channel-chats nil))))
    (is (listp serialized))
    (is (string= "Test query" (getf serialized :query)))
    (is (eq t (getf serialized :allow_user_chats)))
    (is (eq nil (getf serialized :allow_bot_chats)))
    (is (eq t (getf serialized :allow_group_chats)))
    (is (eq nil (getf serialized :allow_channel_chats)))))

;;; ============================================================================
;;; Section 8: Integration Tests
;;; ============================================================================

(test test-inline-keyboard-with-switch-chat-integration
  "Test complete inline keyboard with switch chat integration"
  (let* ((button1 (cl-telegram/api:inline-keyboard-button-with-switch-chat
                    "Share in Group"
                    "Check this"
                    :allow-groups t
                    :allow-channels nil))
         (button2 (cl-telegram/api:inline-keyboard-button-with-switch-chat
                    "Share in Channel"
                    "Share post"
                    :allow-groups nil
                    :allow-channels t))
         (keyboard (cl-telegram/api:make-inline-keyboard (list button1 button2))))
    (is (typep keyboard 'cl-telegram/api::inline-keyboard-markup))
    (is (= 2 (length (cl-telegram/api::inline-keyboard-keyboard keyboard))))))

(test test-menu-button-workflow
  "Test menu button workflow"
  ;; Create different menu button types
  (let ((default (cl-telegram/api:make-menu-button-default))
        (commands (cl-telegram/api:make-menu-button-commands))
        (web-app (cl-telegram/api:make-menu-button-web-app
                   "Open"
                   (list :url "https://example.com"))))
    ;; Test default
    (is (eq :default (cl-telegram/api::menu-button-type default)))
    ;; Test commands
    (is (eq :commands (cl-telegram/api::menu-button-type commands)))
    ;; Test web_app
    (is (eq :web_app (cl-telegram/api::menu-button-type web-app)))
    (is (string= "Open" (cl-telegram/api::menu-button-text web-app)))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-bot-api-9-6-inline-tests ()
  "Run all Bot API 9.6+ Inline Mode enhancement tests"
  (format t "~%~%=== Bot API 9.6+ Inline Tests Results ===~%")
  (let ((results (run! 'bot-api-9-6-inline-tests :if-fail :error)))
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))

;;; End of bot-api-9-6-inline-tests.lisp
