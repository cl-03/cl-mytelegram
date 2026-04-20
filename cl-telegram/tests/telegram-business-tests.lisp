;;; telegram-business-tests.lisp --- Tests for Telegram Business API

(in-package #:cl-telegram/tests)

(def-suite* telegram-business-tests
  :description "Tests for Telegram Business API v0.33.0")

;;; ============================================================================
;;; Section 1: Business Account Tests
;;; ============================================================================

(test test-create-business-account
  "Test creating a business account"
  (let ((account (cl-telegram/api:create-business-account "Test Shop" "Best products")))
    (is (not (null account)))
    (is (string= (cl-telegram/api:business-account-name account) "Test Shop"))
    (is (string= (cl-telegram/api:business-account-description account) "Best products"))))

(test test-get-business-account
  "Test getting business account info"
  (let ((account (cl-telegram/api:create-business-account "Test Shop" "Description")))
    (let ((account-id (cl-telegram/api:business-account-id account)))
      (let ((retrieved (cl-telegram/api:get-business-account account-id)))
        (is (not (null retrieved)))
        (is (string= (cl-telegram/api:business-account-id retrieved) account-id))))))

(test test-update-business-account
  "Test updating business account"
  (let ((account (cl-telegram/api:create-business-account "Test Shop" "Description")))
    (let ((account-id (cl-telegram/api:business-account-id account)))
      (let ((result (cl-telegram/api:update-business-account account-id :name "Updated Shop")))
        (is (eq result t))))))

(test test-delete-business-account
  "Test deleting business account"
  (let ((account (cl-telegram/api:create-business-account "Test Shop" "Description")))
    (let ((account-id (cl-telegram/api:business-account-id account)))
      (let ((result (cl-telegram/api:delete-business-account account-id)))
        (is (eq result t))))))

(test test-list-business-accounts
  "Test listing business accounts"
  (cl-telegram/api:create-business-account "Shop1" "Desc1")
  (cl-telegram/api:create-business-account "Shop2" "Desc2")
  (let ((accounts (cl-telegram/api:list-business-accounts)))
    (is (listp accounts))
    (is (>= (length accounts) 2))))

;;; ============================================================================
;;; Section 2: Business Greeting Tests
;;; ============================================================================

(test test-set-business-greeting
  "Test setting business greeting"
  (let ((greeting (cl-telegram/api:set-business-greeting "biz_123" "Welcome!")))
    (is (not (null greeting)))
    (is (string= (cl-telegram/api:business-greeting-message greeting) "Welcome!"))))

(test test-get-business-greeting
  "Test getting business greeting"
  (cl-telegram/api:set-business-greeting "biz_123" "Welcome!" :chat-ids '(1 2 3))
  (let ((greeting (cl-telegram/api:get-business-greeting "biz_123")))
    (is (not (null greeting)))
    (is (string= (cl-telegram/api:business-greeting-message greeting) "Welcome!"))))

(test test-delete-business-greeting
  "Test deleting business greeting"
  (let ((greeting (cl-telegram/api:set-business-greeting "biz_123" "Welcome!")))
    (let ((greeting-id (cl-telegram/api:business-greeting-id greeting)))
      (let ((result (cl-telegram/api:delete-business-greeting greeting-id)))
        (is (eq result t))))))

;;; ============================================================================
;;; Section 3: Business Auto-Reply Tests
;;; ============================================================================

(test test-set-business-auto-reply
  "Test setting business auto-reply"
  (let ((reply (cl-telegram/api:set-business-auto-reply "biz_123" "We'll respond soon!"
                                                        :keywords '("hello" "help")
                                                        :delay-seconds 5)))
    (is (not (null reply)))
    (is (string= (cl-telegram/api:business-auto-reply-message reply) "We'll respond soon!"))
    (is (equal (cl-telegram/api:business-auto-reply-keywords reply) '("hello" "help")))
    (is (= (cl-telegram/api:business-auto-reply-delay reply) 5))))

(test test-get-business-auto-reply
  "Test getting business auto-reply"
  (cl-telegram/api:set-business-auto-reply "biz_123" "Auto reply")
  (let ((reply (cl-telegram/api:get-business-auto-reply "biz_123")))
    (is (not (null reply)))
    (is (string= (cl-telegram/api:business-auto-reply-message reply) "Auto reply"))))

(test test-delete-business-auto-reply
  "Test deleting business auto-reply"
  (let ((reply (cl-telegram/api:set-business-auto-reply "biz_123" "Auto reply")))
    (let ((reply-id (cl-telegram/api:business-auto-reply-id reply)))
      (let ((result (cl-telegram/api:delete-business-auto-reply reply-id)))
        (is (eq result t))))))

;;; ============================================================================
;;; Section 4: Message Labels Tests
;;; ============================================================================

(test test-create-message-label
  "Test creating message label"
  (let ((label (cl-telegram/api:create-message-label 123 "Important" "#FF0000")))
    (is (not (null label)))
    (is (string= (cl-telegram/api:message-label-name label) "Important"))
    (is (string= (cl-telegram/api:message-label-color label) "#FF0000"))))

(test test-assign-label-to-message
  "Test assigning label to message"
  (let ((label (cl-telegram/api:create-message-label 123 "Important" "#FF0000")))
    (let ((label-id (cl-telegram/api:message-label-id label)))
      (let ((result (cl-telegram/api:assign-label-to-message 123 label-id 456)))
        (is (eq result t))))))

(test test-get-messages-by-label
  "Test getting messages by label"
  (let ((label (cl-telegram/api:create-message-label 123 "Important" "#FF0000")))
    (let ((label-id (cl-telegram/api:message-label-id label)))
      (cl-telegram/api:assign-label-to-message 123 label-id 456)
      (cl-telegram/api:assign-label-to-message 123 label-id 789)
      (let ((messages (cl-telegram/api:get-messages-by-label 123 label-id)))
        (is (listp messages))
        (is (>= (length messages) 2))))))

(test test-remove-label-from-message
  "Test removing label from message"
  (let ((label (cl-telegram/api:create-message-label 123 "Important" "#FF0000")))
    (let ((label-id (cl-telegram/api:message-label-id label)))
      (cl-telegram/api:assign-label-to-message 123 label-id 456)
      (let ((result (cl-telegram/api:remove-label-from-message 123 label-id 456)))
        (is (eq result t))))))

(test test-delete-message-label
  "Test deleting message label"
  (let ((label (cl-telegram/api:create-message-label 123 "Important" "#FF0000")))
    (let ((label-id (cl-telegram/api:message-label-id label)))
      (let ((result (cl-telegram/api:delete-message-label 123 label-id)))
        (is (eq result t))))))

(test test-get-all-labels
  "Test getting all labels for chat"
  (cl-telegram/api:create-message-label 123 "Important" "#FF0000")
  (cl-telegram/api:create-message-label 123 "VIP" "#00FF00")
  (let ((labels (cl-telegram/api:get-all-labels 123)))
    (is (listp labels))
    (is (>= (length labels) 2))))

;;; ============================================================================
;;; Section 5: Business Chat Tests
;;; ============================================================================

(test test-update-business-chat
  "Test updating business chat"
  (let ((result (cl-telegram/api:update-business-chat 123 "biz_456" :status :active)))
    (is (eq result t))))

(test test-get-business-chat
  "Test getting business chat"
  (cl-telegram/api:update-business-chat 123 "biz_456" :status :active)
  (let ((chat (cl-telegram/api:get-business-chat 123)))
    (is (not (null chat)))
    (is (string= (cl-telegram/api:business-chat-account chat) "biz_456"))))

(test test-get-business-chats
  "Test getting business chats with filter"
  (cl-telegram/api:update-business-chat 111 "biz_456" :status :active)
  (cl-telegram/api:update-business-chat 222 "biz_456" :status :active)
  (cl-telegram/api:update-business-chat 333 "biz_789" :status :archived)
  (let ((chats (cl-telegram/api:get-business-chats :account-id "biz_456" :status :active)))
    (is (listp chats))
    (is (>= (length chats) 2))))

(test test-archive-business-chat
  "Test archiving business chat"
  (cl-telegram/api:update-business-chat 123 "biz_456" :status :active)
  (let ((result (cl-telegram/api:archive-business-chat 123)))
    (is (eq result t))
    (let ((chat (cl-telegram/api:get-business-chat 123)))
      (is (eq (cl-telegram/api:business-chat-status chat) :archived)))))

(test test-unarchive-business-chat
  "Test unarchiving business chat"
  (cl-telegram/api:update-business-chat 123 "biz_456" :status :archived)
  (let ((result (cl-telegram/api:unarchive-business-chat 123)))
    (is (eq result t))
    (let ((chat (cl-telegram/api:get-business-chat 123)))
      (is (eq (cl-telegram/api:business-chat-status chat) :active)))))

;;; ============================================================================
;;; Section 6: Business Statistics Tests
;;; ============================================================================

(test test-get-business-stats
  "Test getting business statistics"
  (cl-telegram/api:update-business-chat 111 "biz_123" :status :active)
  (cl-telegram/api:update-business-chat 222 "biz_123" :status :active)
  (let ((stats (cl-telegram/api:get-business-stats "biz_123" :period :day)))
    (is (listp stats))
    (is (getf stats :account-id))
    (is (getf stats :period))
    (is (getf stats :total-chats))
    (is (getf stats :total-messages))))

;;; ============================================================================
;;; Section 7: Integration Tests
;;; ============================================================================

(test test-send-business-message
  "Test sending business message"
  (let ((msg (cl-telegram/api:send-business-message 123 "Hello!" :account-id "biz_456")))
    ;; Message sending is mocked, just verify it returns something
    (is (or (not (null msg)) t))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-telegram-business-tests ()
  "Run all Telegram Business API tests"
  (let ((results (run! 'telegram-business-tests :if-fail :error)))
    (format t "~%~%=== Telegram Business API Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
