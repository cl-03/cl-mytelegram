;;; bot-api-9-8-tests.lisp --- Tests for Bot API 9.8 features

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-8-tests
  :description "Tests for Bot API 9.8 features")

;;; ============================================================================
;;; Section 1: Managed Bots Tests
;;; ============================================================================

(test test-create-managed-bot
  "Test creating a managed bot"
  (let ((bot (cl-telegram/api:create-managed-bot "testhelper_bot" "Test Helper Bot"
                                                 :description "A test bot"
                                                 :about "Test bot for unit tests")))
    (is (not (null bot)))
    (is (string= (cl-telegram/api:managed-bot-username bot) "testhelper_bot"))
    (is (string= (cl-telegram/api:managed-bot-name bot) "Test Helper Bot"))
    (is (string= (cl-telegram/api:managed-bot-description bot) "A test bot"))))

(test test-get-managed-bot
  "Test getting a managed bot by ID"
  (let ((bot (cl-telegram/api:create-managed-bot "getbot_bot" "Get Bot")))
    (let ((bot-id (cl-telegram/api:managed-bot-id bot)))
      (let ((retrieved (cl-telegram/api:get-managed-bot bot-id)))
        (is (not (null retrieved)))
        (is (string= (cl-telegram/api:managed-bot-id retrieved) bot-id))))))

(test test-list-managed-bots
  "Test listing managed bots"
  (cl-telegram/api:create-managed-bot "bot1_bot" "Bot 1")
  (cl-telegram/api:create-managed-bot "bot2_bot" "Bot 2")
  (let ((bots (cl-telegram/api:list-managed-bots)))
    (is (listp bots))
    (is (>= (length bots) 2))))

(test test-update-managed-bot
  "Test updating a managed bot"
  (let ((bot (cl-telegram/api:create-managed-bot "updatebot_bot" "Update Bot")))
    (let ((bot-id (cl-telegram/api:managed-bot-id bot)))
      (let ((result (cl-telegram/api:update-managed-bot bot-id
                                                        :bot-name "Updated Bot"
                                                        :description "Updated description")))
        (is (eq result t))
        (let ((updated (cl-telegram/api:get-managed-bot bot-id)))
          (is (string= (cl-telegram/api:managed-bot-name updated) "Updated Bot")))))))

(test test-delete-managed-bot
  "Test deleting a managed bot"
  (let ((bot (cl-telegram/api:create-managed-bot "deletebot_bot" "Delete Bot")))
    (let ((bot-id (cl-telegram/api:managed-bot-id bot)))
      (let ((result (cl-telegram/api:delete-managed-bot bot-id)))
        (is (eq result t))
        (is (null (cl-telegram/api:get-managed-bot bot-id)))))))

(test test-setup-managed-bot
  "Test setting up a managed bot"
  (let ((bot (cl-telegram/api:create-managed-bot "setupbot_bot" "Setup Bot")))
    (let ((bot-id (cl-telegram/api:managed-bot-id bot)))
      (let ((result (cl-telegram/api:setup-managed-bot bot-id
                                                       "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
                                                       "https://example.com/webhook")))
        (is (eq result t))
        (is (eq (cl-telegram/api:get-managed-bot-status bot-id) :active))))))

(test test-get-managed-bot-status
  "Test getting managed bot status"
  (let ((bot (cl-telegram/api:create-managed-bot "statusbot_bot" "Status Bot")))
    (let ((bot-id (cl-telegram/api:managed-bot-id bot)))
      (let ((status (cl-telegram/api:get-managed-bot-status bot-id)))
        (is (eq status :pending))))))

;;; ============================================================================
;;; Section 2: Business Connection Tests
;;; ============================================================================

(test test-create-business-connection
  "Test creating a business connection"
  (let ((connection (cl-telegram/api:create-business-connection "biz_123" "bizbot"
                                                              :permissions '(:send-messages :edit-messages))))
    (is (not (null connection)))
    (is (string= (cl-telegram/api:business-connection-account-id connection) "biz_123"))
    (is (string= (cl-telegram/api:business-connection-bot-username connection) "bizbot"))))

(test test-get-business-connection
  "Test getting a business connection"
  (let ((connection (cl-telegram/api:create-business-connection "biz_456" "bizbot2")))
    (let ((conn-id (cl-telegram/api:business-connection-id connection)))
      (let ((retrieved (cl-telegram/api:get-business-connection conn-id)))
        (is (not (null retrieved)))
        (is (string= (cl-telegram/api:business-connection-id retrieved) conn-id))))))

(test test-list-business-connections
  "Test listing business connections"
  (cl-telegram/api:create-business-connection "biz_789" "bizbot3")
  (cl-telegram/api:create-business-connection "biz_789" "bizbot4")
  (let ((connections (cl-telegram/api:list-business-connections "biz_789")))
    (is (listp connections))
    (is (>= (length connections) 2))))

(test test-update-business-connection
  "Test updating a business connection"
  (let ((connection (cl-telegram/api:create-business-connection "biz_111" "bizbot5")))
    (let ((conn-id (cl-telegram/api:business-connection-id connection)))
      (let ((result (cl-telegram/api:update-business-connection conn-id :is-active nil)))
        (is (eq result t))
        (let ((updated (cl-telegram/api:get-business-connection conn-id)))
          (is (eq (cl-telegram/api:business-connection-is-active updated) nil)))))))

(test test-delete-business-connection
  "Test deleting a business connection"
  (let ((connection (cl-telegram/api:create-business-connection "biz_222" "bizbot6")))
    (let ((conn-id (cl-telegram/api:business-connection-id connection)))
      (let ((result (cl-telegram/api:delete-business-connection conn-id)))
        (is (eq result t))
        (is (null (cl-telegram/api:get-business-connection conn-id)))))))

;;; ============================================================================
;;; Section 3: Enhanced Polls Tests
;;; ============================================================================

(test test-create-enhanced-poll
  "Test creating an enhanced poll"
  (let ((poll (cl-telegram/api:create-enhanced-poll "Favorite color?"
                                                    '("Red" "Green" "Blue")
                                                    :description "Choose your favorite"
                                                    :multiple-choice t)))
    (is (not (null poll)))
    (is (string= (cl-telegram/api:enhanced-poll-question poll) "Favorite color?"))
    (is (string= (cl-telegram/api:enhanced-poll-description poll) "Choose your favorite"))
    (is (eq (cl-telegram/api:enhanced-poll-is-multiple-choice poll) t))))

(test test-get-enhanced-poll
  "Test getting an enhanced poll"
  (let ((poll (cl-telegram/api:create-enhanced-poll "Test Poll?" '("A" "B"))))
    (let ((poll-id (cl-telegram/api:enhanced-poll-id poll)))
      (let ((retrieved (cl-telegram/api:get-enhanced-poll poll-id)))
        (is (not (null retrieved)))
        (is (string= (cl-telegram/api:enhanced-poll-id retrieved) poll-id))))))

(test test-enhanced-poll-defaults
  "Test enhanced poll default values"
  (let ((poll (cl-telegram/api:create-enhanced-poll "Simple Poll?" '("Yes" "No"))))
    (is (eq (cl-telegram/api:enhanced-poll-is-anonymous poll) t))
    (is (eq (cl-telegram/api:enhanced-poll-is-multiple-choice poll) nil))
    (is (= (cl-telegram/api:enhanced-poll-total-votes poll) 0))))

(test test-enhanced-poll-with-quiz-mode
  "Test enhanced poll with quiz mode"
  (let ((poll (cl-telegram/api:create-enhanced-poll "Quiz Question?"
                                                    '("Wrong" "Correct" "Wrong")
                                                    :correct-option 1)))
    (is (= (cl-telegram/api:enhanced-poll-correct-option-id poll) 1))))

(test test-enhanced-poll-with-timing
  "Test enhanced poll with timing"
  (let ((poll (cl-telegram/api:create-enhanced-poll "Timed Poll?"
                                                    '("A" "B")
                                                    :open-period 300
                                                    :close-date (+ (get-universal-time) 3600))))
    (is (= (cl-telegram/api:enhanced-poll-open-period poll) 300))
    (is (not (null (cl-telegram/api:enhanced-poll-close-date poll))))))

;;; ============================================================================
;;; Section 4: DateTime Entity Tests
;;; ============================================================================

(test test-parse-datetime-entity
  "Test parsing datetime entity"
  (let* ((text "Meeting at 2026-04-20T15:00:00Z")
         (result (cl-telegram/api:parse-datetime-entity text 11 20)))
    (is (not (null result)))
    (is (getf result :datetime))
    (is (string= (getf result :display-text) "2026-04-20T15:00:00Z"))
    (is (string= (getf result :timezone) "UTC"))))

(test test-parse-iso-datetime
  "Test parsing ISO datetime string"
  (let ((result (cl-telegram/api:parse-iso-datetime "2026-04-20T15:30:00")))
    (is (not (null result)))
    (is (integerp result))))

(test test-format-timestring-iso
  "Test formatting timestring in ISO format"
  (let* ((time (get-universal-time))
         (result (cl-telegram/api:format-timestring nil time :format :iso)))
    (is (stringp result))
    (is (search "T" result))
    (is (search "Z" result))))

(test test-format-timestring-readable
  "Test formatting timestring in readable format"
  (let* ((time (encode-universal-time 0 0 15 20 4 2026 0))
         (result (cl-telegram/api:format-timestring nil time :format :readable)))
    (is (stringp result))
    (is (search "April" result))
    (is (search "2026" result))))

;;; ============================================================================
;;; Section 5: Member Tags Tests
;;; ============================================================================

(test test-create-member-tag
  "Test creating a member tag"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "VIP" :color "#FFD700")))
    (is (not (null tag)))
    (is (string= (cl-telegram/api:member-tag-name tag) "VIP"))
    (is (string= (cl-telegram/api:member-tag-color tag) "#FFD700"))))

(test test-get-member-tag
  "Test getting a member tag"
  (cl-telegram/api:create-member-tag 123456 "VIP" :color "#FFD700")
  (let ((tag (cl-telegram/api:get-member-tag 123456 "VIP")))
    (is (not (null tag)))
    (is (string= (cl-telegram/api:member-tag-name tag) "VIP"))))

(test test-list-member-tags
  "Test listing member tags"
  (cl-telegram/api:create-member-tag 123456 "VIP" :color "#FFD700")
  (cl-telegram/api:create-member-tag 123456 "MOD" :color "#00FF00")
  (let ((tags (cl-telegram/api:list-member-tags 123456)))
    (is (listp tags))
    (is (>= (length tags) 2))))

(test test-assign-member-tag
  "Test assigning a member tag"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "VIP")))
    (let ((tag-name (cl-telegram/api:member-tag-name tag)))
      (let ((initial-count (cl-telegram/api:member-tag-member-count tag)))
        (cl-telegram/api:assign-member-tag 123456 789 tag-name)
        (let ((updated (cl-telegram/api:get-member-tag 123456 tag-name)))
          (is (= (cl-telegram/api:member-tag-member-count updated) (1+ initial-count)))))))))

(test test-remove-member-tag
  "Test removing a member tag"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "VIP")))
    (let ((tag-name (cl-telegram/api:member-tag-name tag)))
      (cl-telegram/api:assign-member-tag 123456 789 tag-name)
      (let ((result (cl-telegram/api:remove-member-tag 123456 789 tag-name)))
        (is (eq result t))
        (let ((updated (cl-telegram/api:get-member-tag 123456 tag-name)))
          (is (= (cl-telegram/api:member-tag-member-count updated) 0)))))))

(test test-delete-member-tag
  "Test deleting a member tag"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "ToDelete")))
    (let ((tag-name (cl-telegram/api:member-tag-name tag)))
      (let ((result (cl-telegram/api:delete-member-tag 123456 tag-name)))
        (is (eq result t))
        (is (null (cl-telegram/api:get-member-tag 123456 tag-name)))))))

(test test-generate-random-color
  "Test generating random color"
  (let ((color (cl-telegram/api:generate-random-color)))
    (is (stringp color))
    (is (= (length color) 7))
    (is (char= (char color 0) #\#))))

;;; ============================================================================
;;; Section 6: Utility Function Tests
;;; ============================================================================

(test test-get-bot-api-9-8-version
  "Test getting Bot API 9.8 version"
  (let ((version (cl-telegram/api:get-bot-api-9-8-version)))
    (is (string= version "9.8.0"))))

(test test-check-bot-api-9-8-feature
  "Test checking Bot API 9.8 feature support"
  (is (eq (cl-telegram/api:check-bot-api-9-8-feature :managed-bots) t))
  (is (eq (cl-telegram/api:check-bot-api-9-8-feature :business-connections) t))
  (is (eq (cl-telegram/api:check-bot-api-9-8-feature :enhanced-polls) t))
  (is (eq (cl-telegram/api:check-bot-api-9-8-feature :datetime-entities) t))
  (is (eq (cl-telegram/api:check-bot-api-9-8-feature :member-tags) t))
  (is (null (cl-telegram/api:check-bot-api-9-8-feature :nonexistent-feature)))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-bot-api-9-8-tests ()
  "Run all Bot API 9.8 tests"
  (let ((results (run! 'bot-api-9-8-tests :if-fail :error)))
    (format t "~%~%=== Bot API 9.8 Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
