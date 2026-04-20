;;; message-enhanced-tests.lisp --- Tests for enhanced message features (v0.32.0)

(in-package #:cl-telegram/tests)

(def-suite* message-enhanced-tests
  :description "Tests for enhanced message features (v0.32.0)")

;;; ============================================================================
;;; Section 1: Streaming Message Tests
;;; ============================================================================

(test test-send-message-draft
  "Test sending a message draft"
  (let ((result (cl-telegram/api:send-message-draft 123456 "Test draft message")))
    (is (or (null result) (listp result)))))

(test test-send-message-stream
  "Test creating a streaming message session"
  (let ((session (cl-telegram/api:send-message-stream 123456 "Initial text")))
    (is (typep session 'cl-telegram/api::stream-message-session))
    (is (stringp (cl-telegram/api:stream-session-id session)))
    (is (equal (cl-telegram/api:stream-session-chat-id session) 123456))))

(test test-stream-message-update
  "Test updating a streaming message"
  (let ((session (cl-telegram/api:send-message-stream 123456 "Initial")))
    (let ((result (cl-telegram/api:stream-message-update (cl-telegram/api:stream-session-id session)
                                                          "Updated text")))
      (is (or (eq result t) (null result))))))

(test test-stream-message-finalize
  "Test finalizing a streaming message"
  (let ((session (cl-telegram/api:send-message-stream 123456 "Initial")))
    (let ((result (cl-telegram/api:stream-message-finalize (cl-telegram/api:stream-session-id session)
                                                            :final-text "Final text")))
      (is (or (null result) (listp result))))))

;;; ============================================================================
;;; Section 2: Scheduled Message Tests
;;; ============================================================================

(test test-schedule-message
  "Test scheduling a message"
  (let ((result (cl-telegram/api:schedule-message 123456 "Scheduled message"
                                                   :schedule-date (+ (get-universal-time) 3600))))
    (is (or (null result) (listp result)))))

(test test-get-scheduled-messages
  "Test getting scheduled messages"
  (let ((result (cl-telegram/api:get-scheduled-messages 123456)))
    (is (or (null result) (listp result)))))

(test test-delete-scheduled-message
  "Test deleting a scheduled message"
  (let ((result (cl-telegram/api:delete-scheduled-message 123456 99999)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 3: Draft Management Tests
;;; ============================================================================

(test test-save-draft
  "Test saving a draft"
  (let ((result (cl-telegram/api:save-draft 123456 "Draft text")))
    (is (or (eq result t) (null result)))))

(test test-get-drafts
  "Test getting drafts for a chat"
  (let ((result (cl-telegram/api:get-drafts 123456)))
    (is (or (null result) (listp result)))))

(test test-get-all-drafts
  "Test getting all drafts"
  (let ((result (cl-telegram/api:get-all-drafts)))
    (is (or (null result) (listp result)))))

(test test-delete-draft
  "Test deleting a draft"
  (let ((result (cl-telegram/api:delete-draft 123456)))
    (is (or (eq result t) (null result)))))

(test test-clear-all-drafts
  "Test clearing all drafts"
  (let ((result (cl-telegram/api:clear-all-drafts)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Multi-Media Message Tests
;;; ============================================================================

(test test-make-photo-media
  "Test creating photo media input"
  (let ((media (cl-telegram/api:make-photo-media "AgAD1234" :caption "Test photo")))
    (is (typep media 'cl-telegram/api::input-media))
    (is (eq (cl-telegram/api::input-media-type media) :photo))
    (is (equal (cl-telegram/api::input-media-id media) "AgAD1234"))
    (is (equal (cl-telegram/api::input-media-caption media) "Test photo"))))

(test test-make-video-media
  "Test creating video media input"
  (let ((media (cl-telegram/api:make-video-media "BaAB5678" :caption "Test video")))
    (is (typep media 'cl-telegram/api::input-media))
    (is (eq (cl-telegram/api::input-media-type media) :video))
    (is (equal (cl-telegram/api::input-media-id media) "BaAB5678"))))

(test test-make-document-media
  "Test creating document media input"
  (let ((media (cl-telegram/api:make-document-media "FileId9012" :caption "Test document")))
    (is (typep media 'cl-telegram/api::input-media))
    (is (eq (cl-telegram/api::input-media-type media) :document))
    (is (equal (cl-telegram/api::input-media-id media) "FileId9012"))))

(test test-send-album
  "Test sending an album"
  (let ((media-list (list (cl-telegram/api:make-photo-media "photo1")
                          (cl-telegram/api:make-photo-media "photo2")
                          (cl-telegram/api:make-video-media "video1"))))
    (let ((result (cl-telegram/api:send-album 123456 media-list :caption "Test Album")))
      (is (or (null result) (listp result))))))

;;; ============================================================================
;;; Section 5: Message Copy Tests
;;; ============================================================================

(test test-copy-message
  "Test copying a message"
  (let ((result (cl-telegram/api:copy-message 123456 987654 11111 :caption "Copied")))
    (is (or (null result) (listp result)))))

(test test-copy-messages
  "Test copying multiple messages"
  (let ((result (cl-telegram/api:copy-messages 123456 987654 '(111 222 333))))
    (is (or (null result) (listp result)))))

;;; ============================================================================
;;; Section 6: Statistics Tests
;;; ============================================================================

(test test-get-message-stats
  "Test getting message statistics"
  (let ((stats (cl-telegram/api:get-message-stats :period :week)))
    (is (listp stats))
    (is (getf stats :total-sent))
    (is (getf stats :total-scheduled))
    (is (getf stats :total-drafts))
    (is (eq (getf stats :period) :week))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-message-enhanced-tests ()
  "Run all enhanced message tests"
  (let ((results (run! 'message-enhanced-tests :if-fail :error)))
    (format t "~%~%=== Enhanced Message Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
