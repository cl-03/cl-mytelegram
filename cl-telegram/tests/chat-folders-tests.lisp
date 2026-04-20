;;; chat-folders-tests.lisp --- Tests for chat folders v0.32.0 enhancements

(in-package #:cl-telegram/tests)

(def-suite* chat-folders-v0.32-tests
  :description "Tests for chat folders v0.32.0 enhancements")

;;; ============================================================================
;;; Section 1: Pinned Chats Tests
;;; ============================================================================

(test test-pin-chat
  "Test pinning a chat"
  (let ((result (cl-telegram/api:pin-chat 123456 :position 1)))
    (is (eq result t))))

(test test-unpin-chat
  "Test unpinning a chat"
  (cl-telegram/api:pin-chat 123456)
  (let ((result (cl-telegram/api:unpin-chat 123456)))
    (is (eq result t))))

(test test-get-pinned-chats
  "Test getting pinned chats"
  (cl-telegram/api:pin-chat 111 :position 0)
  (cl-telegram/api:pin-chat 222 :position 1)
  (cl-telegram/api:pin-chat 333 :position 2)
  (let ((pinned (cl-telegram/api:get-pinned-chats)))
    (is (listp pinned))
    (is (>= (length pinned) 3))))

;;; ============================================================================
;;; Section 2: Unread Marks Tests
;;; ============================================================================

(test test-set-unread-mark
  "Test setting unread mark"
  (let ((result (cl-telegram/api:set-unread-mark 123456 5 :last-message-id 999)))
    (is (eq result t))))

(test test-clear-unread-mark
  "Test clearing unread mark"
  (cl-telegram/api:set-unread-mark 123456 5)
  (let ((result (cl-telegram/api:clear-unread-mark 123456)))
    (is (eq result t))))

(test test-get-unread-marks
  "Test getting unread marks"
  (cl-telegram/api:set-unread-mark 111 3)
  (cl-telegram/api:set-unread-mark 222 5)
  (let ((marks (cl-telegram/api:get-unread-marks)))
    (is (listp marks))
    (is (>= (length marks) 2))))

;;; ============================================================================
;;; Section 3: Chat Folder Stats Tests
;;; ============================================================================

(test test-get-chat-folder-stats
  "Test getting chat folder statistics"
  (let ((stats (cl-telegram/api:get-chat-folder-stats)))
    (is (listp stats))
    (is (getf stats :total-folders))
    (is (getf stats :total-chats))
    (is (getf stats :total-pinned))
    (is (getf stats :total-unread))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-chat-folders-v0.32-tests ()
  "Run all chat folders v0.32.0 tests"
  (let ((results (run! 'chat-folders-v0.32-tests :if-fail :error)))
    (format t "~%~%=== Chat Folders v0.32.0 Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
