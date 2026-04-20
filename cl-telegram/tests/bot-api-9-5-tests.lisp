;;; bot-api-9-5-tests.lisp --- Tests for Bot API 9.5-9.6 features (v0.32.0)

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-5-tests
  :description "Tests for Bot API 9.5-9.6 features (v0.32.0)")

;;; ============================================================================
;;; Section 1: Prepared Keyboard Button Tests
;;; ============================================================================

(test test-save-prepared-keyboard-button
  "Test saving a prepared keyboard button"
  (let ((button (cl-telegram/api:save-prepared-keyboard-button "Select User" :request-users t :max-quantity 3)))
    (is (typep button 'cl-telegram/api::prepared-keyboard-button))
    (is (stringp (cl-telegram/api:prepared-button-id button)))
    (is (equal (cl-telegram/api:prepared-button-text button) "Select User"))
    (is (eq (cl-telegram/api:prepared-button-request-users button) t))))

(test test-get-prepared-keyboard-button
  "Test getting a prepared keyboard button"
  (let ((button (cl-telegram/api:save-prepared-keyboard-button "Test Button")))
    (let ((retrieved (cl-telegram/api:get-prepared-keyboard-button (cl-telegram/api:prepared-button-id button))))
      (is (typep retrieved 'cl-telegram/api::prepared-keyboard-button))
      (is (equal (cl-telegram/api:prepared-button-id retrieved) (cl-telegram/api:prepared-button-id button))))))

(test test-delete-prepared-keyboard-button
  "Test deleting a prepared keyboard button"
  (let ((button (cl-telegram/api:save-prepared-keyboard-button "Temp Button")))
    (let ((result (cl-telegram/api:delete-prepared-keyboard-button (cl-telegram/api:prepared-button-id button))))
      (is (eq result t))
      (is (null (cl-telegram/api:get-prepared-keyboard-button (cl-telegram/api:prepared-button-id button)))))))

(test test-list-prepared-keyboard-buttons
  "Test listing prepared keyboard buttons"
  ;; Clear existing
  (let ((buttons (cl-telegram/api:list-prepared-keyboard-buttons)))
    (dolist (btn buttons)
      (cl-telegram/api:delete-prepared-keyboard-button (cl-telegram/api:prepared-button-id btn))))

  ;; Create new
  (cl-telegram/api:save-prepared-keyboard-button "Button 1")
  (cl-telegram/api:save-prepared-keyboard-button "Button 2")

  (let ((buttons (cl-telegram/api:list-prepared-keyboard-buttons)))
    (is (>= (length buttons) 2))))

;;; ============================================================================
;;; Section 2: Member Tag Tests
;;; ============================================================================

(test test-create-member-tag
  "Test creating a member tag"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "VIP" :color "gold")))
    (is (typep tag 'cl-telegram/api::member-tag))
    (is (stringp (cl-telegram/api:member-tag-id tag)))
    (is (equal (cl-telegram/api:member-tag-name tag) "VIP"))
    (is (equal (cl-telegram/api:member-tag-color tag) "gold"))
    (is (equal (cl-telegram/api:member-tag-chat-id tag) 123456))))

(test test-assign-member-tag
  "Test assigning a member tag to a user"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "VIP")))
    (let ((result (cl-telegram/api:assign-member-tag 123456 (cl-telegram/api:member-tag-id tag) 789)))
      (is (eq result t))
      (is (member 789 (cl-telegram/api:member-tag-user-ids tag))))))

(test test-remove-member-tag
  "Test removing a member tag from a user"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "VIP")))
    (cl-telegram/api:assign-member-tag 123456 (cl-telegram/api:member-tag-id tag) 789)
    (let ((result (cl-telegram/api:remove-member-tag 123456 (cl-telegram/api:member-tag-id tag) 789)))
      (is (eq result t))
      (is (not (member 789 (cl-telegram/api:member-tag-user-ids tag)))))))

(test test-get-member-tags
  "Test getting member tags for a chat"
  (let ((chat-id 123456))
    (cl-telegram/api:create-member-tag chat-id "Tag1")
    (cl-telegram/api:create-member-tag chat-id "Tag2")
    (let ((tags (cl-telegram/api:get-member-tags chat-id)))
      (is (>= (length tags) 2)))))

(test test-get-user-member-tags
  "Test getting tags assigned to a user"
  (let ((chat-id 123456)
        (user-id 789))
    (let ((tag1 (cl-telegram/api:create-member-tag chat-id "Tag1"))
          (tag2 (cl-telegram/api:create-member-tag chat-id "Tag2")))
      (cl-telegram/api:assign-member-tag chat-id (cl-telegram/api:member-tag-id tag1) user-id)
      (let ((user-tags (cl-telegram/api:get-user-member-tags chat-id user-id)))
        (is (>= (length user-tags) 1))
        (is (some (lambda (t) (equal (cl-telegram/api:member-tag-name t) "Tag1")) user-tags))))))

(test test-delete-member-tag
  "Test deleting a member tag"
  (let ((tag (cl-telegram/api:create-member-tag 123456 "ToDelete")))
    (let ((result (cl-telegram/api:delete-member-tag 123456 (cl-telegram/api:member-tag-id tag))))
      (is (eq result t))
      (is (null (cl-telegram/api:get-member-tags 123456)))))

;;; ============================================================================
;;; Section 3: Enhanced Polls (Polls 2.0) Tests
;;; ============================================================================

(test test-create-poll-v2
  "Test creating a v2 poll"
  (let ((poll (cl-telegram/api:create-poll-v2 "Favorite color?" '("Red" "Green" "Blue")
                                               :description "Vote for your favorite"
                                               :is-anonymous nil)))
    (is (typep poll 'cl-telegram/api::poll-v2))
    (is (stringp (cl-telegram/api:poll-v2-id poll)))
    (is (equal (cl-telegram/api:poll-v2-question poll) "Favorite color?"))
    (is (equal (cl-telegram/api:poll-v2-options poll) '("Red" "Green" "Blue")))
    (is (equal (cl-telegram/api:poll-v2-description poll) "Vote for your favorite"))
    (is (eq (cl-telegram/api:poll-v2-is-anonymous poll) nil))))

(test test-create-quiz-poll
  "Test creating a quiz poll"
  (let ((poll (cl-telegram/api:create-poll-v2 "What is 2+2?" '("3" "4" "5")
                                               :type :quiz
                                               :correct-option-id 1
                                               :explanation "2+2 equals 4")))
    (is (eq (cl-telegram/api:poll-v2-type poll) :quiz))
    (is (equal (cl-telegram/api:poll-v2-correct-option-id poll) 1))
    (is (equal (cl-telegram/api:poll-v2-explanation poll) "2+2 equals 4"))))

(test test-get-poll-v2
  "Test getting a v2 poll"
  (let ((poll (cl-telegram/api:create-poll-v2 "Test Poll" '("A" "B"))))
    (let ((retrieved (cl-telegram/api:get-poll-v2 (cl-telegram/api:poll-v2-id poll))))
      (is (typep retrieved 'cl-telegram/api::poll-v2))
      (is (equal (cl-telegram/api:poll-v2-id retrieved) (cl-telegram/api:poll-v2-id poll))))))

(test test-get-poll-v2-results
  "Test getting poll results"
  (let ((poll (cl-telegram/api:create-poll-v2 "Results Poll" '("X" "Y"))))
    (let ((results (cl-telegram/api:get-poll-v2-results (cl-telegram/api:poll-v2-id poll))))
      (is (listp results))
      (is (getf results :poll-id))
      (is (getf results :question))
      (is (getf results :options)))))

;;; ============================================================================
;;; Section 4: DateTime Entity Tests
;;; ============================================================================

(test test-parse-datetime-entity
  "Test parsing a datetime entity"
  (let ((entity (cl-telegram/api:parse-datetime-entity "Meeting at 2025-03-15 14:30")))
    (is (typep entity 'cl-telegram/api::datetime-entity))
    (is (stringp (cl-telegram/api:datetime-entity-id entity)))
    (is (numberp (cl-telegram/api:datetime-entity-datetime entity)))))

(test test-create-datetime-entity
  "Test creating a datetime entity"
  (let ((entity (cl-telegram/api:create-datetime-entity "Tomorrow at 3pm" (get-universal-time)
                                                         :timezone "UTC")))
    (is (typep entity 'cl-telegram/api::datetime-entity))
    (is (equal (cl-telegram/api:datetime-entity-timezone entity) "UTC"))))

(test test-format-datetime-entity
  "Test formatting a datetime entity"
  (let ((entity (cl-telegram/api:create-datetime-entity "Test" (encode-universal-time 0 30 14 15 3 2025 0))))
    (let ((formatted (cl-telegram/api:format-datetime-entity entity :format "yyyy-mm-dd hh:mm")))
      (is (stringp formatted))
      (is (search "2025" formatted))
      (is (search "03" formatted))
      (is (search "15" formatted)))))

;;; ============================================================================
;;; Section 5: Statistics Tests
;;; ============================================================================

(test test-get-bot-api-stats
  "Test getting Bot API statistics"
  (let ((stats (cl-telegram/api:get-bot-api-stats)))
    (is (listp stats))
    (is (getf stats :prepared-buttons))
    (is (getf stats :member-tags))
    (is (getf stats :polls-v2))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-bot-api-9-5-tests ()
  "Run all Bot API 9.5-9.6 tests"
  (let ((results (run! 'bot-api-9-5-tests :if-fail :error)))
    (format t "~%~%=== Bot API 9.5-9.6 Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
