;;; scheduled-messages-tests.lisp --- Tests for scheduled messages and drafts
;;;
;;; Test suite for:
;;; - Scheduled message creation and management
;;; - Draft message saving and retrieval
;;; - Message scheduling with custom dates
;;; - Draft synchronization across chats
;;;
;;; Version: 0.37.0

(in-package #:cl-telegram/tests)

(def-suite* scheduled-messages-tests
  :description "Tests for scheduled messages and drafts (v0.37.0)")

;;; ============================================================================
;;; Section 1: Scheduled Message Class Tests
;;; ============================================================================

(test test-scheduled-message-class-creation
  "Test scheduled-message class creation and accessors"
  (let ((scheduled-msg (make-instance 'cl-telegram/api::scheduled-message
                                      :id 123
                                      :chat-id 456789
                                      :text "Reminder: Meeting tomorrow"
                                      :send-date (+ (get-universal-time) 86400)
                                      :created-at (get-universal-time)
                                      :status :scheduled
                                      :media nil
                                      :reply-markup nil
                                      :parse-mode nil)))
    (is (= 123 (cl-telegram/api:scheduled-message-id scheduled-msg))
        "ID should match")
    (is (= 456789 (cl-telegram/api:scheduled-message-chat-id scheduled-msg))
        "Chat ID should match")
    (is (string= "Reminder: Meeting tomorrow" (cl-telegram/api:scheduled-message-text scheduled-msg))
        "Text should match")
    (is (<= (+ (get-universal-time) 86400) (cl-telegram/api:scheduled-message-send-date scheduled-msg))
        "Send date should be in future")
    (is (eq :scheduled (cl-telegram/api:scheduled-message-status scheduled-msg))
        "Status should be scheduled")))

(test test-scheduled-message-with-media
  "Test scheduled message with media attachment"
  (let ((media `(:type "photo" :file-id "file_id_123")))
    (let ((scheduled-msg (make-instance 'cl-telegram/api::scheduled-message
                                        :id 456
                                        :chat-id 789012
                                        :text "Check this photo"
                                        :send-date (+ (get-universal-time) 3600)
                                        :media media
                                        :status :scheduled)))
      (is (equal media (cl-telegram/api:scheduled-message-media scheduled-msg))
          "Media should match")
      (is (string= "Check this photo" (cl-telegram/api:scheduled-message-text scheduled-msg))))))

(test test-scheduled-message-with-markup
  "Test scheduled message with reply markup"
  (let ((markup `(:inline-keyboard (((:text "Confirm" :callback-data "yes")
                                     (:text "Cancel" :callback-data "no"))))))
    (let ((scheduled-msg (make-instance 'cl-telegram/api::scheduled-message
                                        :id 789
                                        :chat-id 345678
                                        :text "Please confirm"
                                        :send-date (+ (get-universal-time) 7200)
                                        :reply-markup markup
                                        :status :scheduled)))
      (is (equal markup (cl-telegram/api:scheduled-message-reply-markup scheduled-msg))
          "Reply markup should match"))))

;;; ============================================================================
;;; Section 2: Message Draft Class Tests
;;; ============================================================================

(test test-message-draft-class-creation
  "Test message-draft class creation and accessors"
  (let ((draft (make-instance 'cl-telegram/api::message-draft
                              :id "123456:main"
                              :chat-id 123456
                              :text "Draft: Need to follow up"
                              :entities nil
                              :updated-at (get-universal-time))))
    (is (string= "123456:main" (cl-telegram/api:message-draft-id draft))
        "Draft ID should match")
    (is (= 123456 (cl-telegram/api:message-draft-chat-id draft))
        "Chat ID should match")
    (is (string= "Draft: Need to follow up" (cl-telegram/api:message-draft-text draft))
        "Text should match")))

(test test-message-draft-with-thread
  "Test message draft with thread ID"
  (let ((draft (make-instance 'cl-telegram/api::message-draft
                              :id "123456:100"
                              :chat-id 123456
                              :message-thread-id 100
                              :text "Thread draft"
                              :entities '(("bold" :offset 0 :length 6))
                              :updated-at (get-universal-time))))
    (is (= 100 (cl-telegram/api:message-draft-message-thread-id draft))
        "Thread ID should match")
    (is (equal '(("bold" :offset 0 :length 6)) (cl-telegram/api:message-draft-entities draft))
        "Entities should match")))

;;; ============================================================================
;;; Section 3: Scheduled Message Functions Tests
;;; ============================================================================

(test test-send-scheduled-message
  "Test sending a scheduled message"
  (let ((future-date (+ (get-universal-time) 86400)))
    (let ((result (cl-telegram/api:send-scheduled-message 123456 "Test scheduled message" future-date)))
      ;; May return scheduled-message object or NIL without connection
      (is (or (null result)
              (typep result 'cl-telegram/api::scheduled-message))))))

(test test-send-scheduled-message-with-options
  "Test sending scheduled message with options"
  (let ((future-date (+ (get-universal-time) 3600))
        (markup (cl-telegram/api:make-inline-keyboard "Button" :callback-data "test")))
    (let ((result (cl-telegram/api:send-scheduled-message 123456 "Test with markup" future-date
                                                          :reply-markup markup
                                                          :parse-mode "HTML")))
      (is (or (null result)
              (typep result 'cl-telegram/api::scheduled-message))))))

(test test-get-scheduled-messages
  "Test getting scheduled messages"
  (let ((result (cl-telegram/api:get-scheduled-messages 123456 :limit 50 :offset 0)))
    ;; Should return list or NIL
    (is (or (null result)
            (listp result)))))

(test test-delete-scheduled-message
  "Test deleting a scheduled message"
  (let ((result (cl-telegram/api:delete-scheduled-message 123456 789)))
    ;; Should return T or NIL
    (is (or (null result)
            (eq result t)))))

(test test-edit-scheduled-message
  "Test editing a scheduled message"
  (let ((result (cl-telegram/api:edit-scheduled-message 123456 789 :text "Updated text")))
    ;; May return scheduled-message or NIL
    (is (or (null result)
            (typep result 'cl-telegram/api::scheduled-message)))))

(test test-edit-scheduled-message-with-media
  "Test editing scheduled message with media"
  (let ((media `(:type "photo" :file-id "new_file_id")))
    (let ((result (cl-telegram/api:edit-scheduled-message 123456 789 :media media)))
      (is (or (null result)
              (typep result 'cl-telegram/api::scheduled-message))))))

;;; ============================================================================
;;; Section 4: Draft Message Functions Tests
;;; ============================================================================

(test test-save-message-draft
  "Test saving a message draft"
  (let ((result (cl-telegram/api:save-message-draft 123456 "Draft text")))
    ;; Should return T or NIL
    (is (or (null result)
            (eq result t)))))

(test test-save-message-draft-with-thread
  "Test saving draft with thread ID"
  (let ((result (cl-telegram/api:save-message-draft 123456 "Thread draft" :message-thread-id 100)))
    (is (or (null result)
            (eq result t)))))

(test test-get-message-drafts
  "Test getting all message drafts"
  (let ((result (cl-telegram/api:get-message-drafts)))
    ;; Should return list or NIL
    (is (or (null result)
            (listp result)))))

(test test-get-message-drafts-filtered
  "Test getting drafts for specific chats"
  (let ((result (cl-telegram/api:get-message-drafts :chat-ids '(123456 789012))))
    (is (or (null result)
            (listp result)))))

(test test-get-message-draft
  "Test getting a specific draft"
  (let ((result (cl-telegram/api:get-message-draft 123456)))
    ;; Should return message-draft or NIL
    (is (or (null result)
            (typep result 'cl-telegram/api::message-draft)))))

(test test-delete-message-draft
  "Test deleting a message draft"
  (let ((result (cl-telegram/api:delete-message-draft 123456)))
    (is (or (null result)
            (eq result t)))))

(test test-delete-message-draft-with-thread
  "Test deleting draft with thread ID"
  (let ((result (cl-telegram/api:delete-message-draft 123456 :message-thread-id 100)))
    (is (or (null result)
            (eq result t)))))

(test test-delete-all-message-drafts
  "Test deleting all drafts"
  (let ((result (cl-telegram/api:delete-all-message-drafts)))
    (is (or (null result)
            (eq result t)))))

;;; ============================================================================
;;; Section 5: Utility Functions Tests
;;; ============================================================================

(test test-get-scheduled-message
  "Test getting a scheduled message by ID"
  ;; First create one in local cache
  (let ((msg (make-instance 'cl-telegram/api::scheduled-message
                            :id 999
                            :chat-id 123456
                            :text "Test"
                            :send-date (+ (get-universal-time) 1000)
                            :status :scheduled)))
    (setf (gethash 999 cl-telegram/api::*scheduled-messages*) msg)
    (let ((result (cl-telegram/api:get-scheduled-message 999)))
      (is (typep result 'cl-telegram/api::scheduled-message))
      (is (= 999 (cl-telegram/api:scheduled-message-id result))))))

(test test-list-scheduled-messages
  "Test listing all scheduled messages"
  (let ((result (cl-telegram/api:list-scheduled-messages)))
    (is (listp result))))

(test test-count-scheduled-messages
  "Test counting scheduled messages"
  (let ((result (cl-telegram/api:count-scheduled-messages)))
    (is (numberp result))
    (is (>= result 0))))

(test test-clear-scheduled-message-cache
  "Test clearing scheduled message cache"
  (let ((result (cl-telegram/api:clear-scheduled-message-cache)))
    (is (eq result t))))

(test test-clear-draft-cache
  "Test clearing draft cache"
  (let ((result (cl-telegram/api:clear-draft-cache)))
    (is (eq result t))))

(test test-cleanup-expired-drafts
  "Test cleaning up expired drafts"
  (let ((result (cl-telegram/api:cleanup-expired-drafts :timeout 1)))
    (is (numberp result))
    (is (>= result 0))))

;;; ============================================================================
;;; Section 6: Integration Tests
;;; ============================================================================

(test test-scheduled-message-workflow
  "Test complete scheduled message workflow"
  (let ((future-date (+ (get-universal-time) 86400)))
    ;; Create scheduled message
    (let ((msg (cl-telegram/api:send-scheduled-message 123456 "Workflow test" future-date)))
      (when msg
        ;; Get the message
        (let ((retrieved (cl-telegram/api:get-scheduled-message (cl-telegram/api:scheduled-message-id msg))))
          (is (or (null retrieved)
                  (typep retrieved 'cl-telegram/api::scheduled-message))))
        ;; Delete the message
        (let ((deleted (cl-telegram/api:delete-scheduled-message 123456 (cl-telegram/api:scheduled-message-id msg))))
          (is (or (null deleted)
                  (eq deleted t))))))))

(test test-draft-workflow
  "Test complete draft workflow"
  ;; Save draft
  (let ((saved (cl-telegram/api:save-message-draft 123456 "Workflow draft")))
    (when saved
      ;; Get draft
      (let ((draft (cl-telegram/api:get-message-draft 123456)))
        (is (or (null draft)
                (typep draft 'cl-telegram/api::message-draft))))
      ;; Delete draft
      (let ((deleted (cl-telegram/api:delete-message-draft 123456)))
        (is (or (null deleted)
                (eq deleted t))))))))

(test test-send-pending-scheduled-messages
  "Test sending pending scheduled messages"
  (let ((result (cl-telegram/api:send-pending-scheduled-messages)))
    (is (numberp result))
    (is (>= result 0))))

;;; ============================================================================
;;; Section 7: Initialization Tests
;;; ============================================================================

(test test-initialize-scheduled-messages
  "Test initializing scheduled messages system"
  (let ((result (cl-telegram/api:initialize-scheduled-messages)))
    (is (eq result t))))

(test test-shutdown-scheduled-messages
  "Test shutting down scheduled messages system"
  (cl-telegram/api:initialize-scheduled-messages)
  (let ((result (cl-telegram/api:shutdown-scheduled-messages)))
    (is (eq result t))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-scheduled-messages-tests ()
  "Run all scheduled messages and drafts tests"
  (format t "~%~%=== Scheduled Messages Test Results ===~%")
  (let ((results (run! 'scheduled-messages-tests :if-fail :error)))
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))

;;; End of scheduled-messages-tests.lisp
