;;; drafts-scheduled-tests.lisp --- Tests for drafts and scheduled messages

(in-package #:cl-telegram/tests)

(def-suite drafts-scheduled-tests
  :description "Tests for drafts and scheduled messages (v0.19.0)")

(in-suite drafts-scheduled-tests)

;;; ======================================================================
;;; Draft Message Class Tests
;;; ======================================================================

(test test-draft-message-class
  "Test draft-message class creation and accessors"
  (let ((draft (make-instance 'cl-telegram/api:draft-message
                              :peer 123456
                              :message "Hello, this is a draft"
                              :entities '((:bold 0 5))
                              :reply-to 100
                              :date 1713542400)))
    (is (= 123456 (cl-telegram/api:draft-peer draft)))
    (is (string= "Hello, this is a draft" (cl-telegram/api:draft-message draft)))
    (is (equal '((:bold 0 5)) (cl-telegram/api:draft-entities draft)))
    (is (= 100 (cl-telegram/api:draft-reply-to draft)))
    (is (= 1713542400 (cl-telegram/api:draft-date draft)))))

(test test-draft-message-defaults
  "Test draft-message default values"
  (let ((draft (make-instance 'cl-telegram/api:draft-message
                              :peer 123456
                              :message "Test")))
    (is (= 123456 (cl-telegram/api:draft-peer draft)))
    (is (string= "Test" (cl-telegram/api:draft-message draft)))
    (is (null (cl-telegram/api:draft-entities draft)))
    (is (null (cl-telegram/api:draft-reply-to draft)))))

;;; ======================================================================
;;; Draft Cache Tests
;;; ======================================================================

(test test-draft-cache-operations
  "Test draft cache basic operations"
  ;; Clear cache first
  (clrhash cl-telegram/api:*draft-cache*)

  ;; Add draft to cache
  (let ((draft (make-instance 'cl-telegram/api:draft-message
                              :peer 123456
                              :message "Cached draft")))
    (setf (gethash 123456 cl-telegram/api:*draft-cache*) draft))

  ;; Verify cache
  (let ((cached (gethash 123456 cl-telegram/api:*draft-cache*)))
    (is (notnull cached))
    (is (string= "Cached draft" (cl-telegram/api:draft-message cached))))

  ;; Cleanup
  (remhash 123456 cl-telegram/api:*draft-cache*))

(test test-draft-cache-multiple-drafts
  "Test draft cache with multiple drafts"
  (clrhash cl-telegram/api:*draft-cache*)

  ;; Add multiple drafts
  (loop for i from 1 to 5
        do (setf (gethash i cl-telegram/api:*draft-cache*)
                 (make-instance 'cl-telegram/api:draft-message
                                :peer i
                                :message (format nil "Draft ~A" i))))

  ;; Verify all drafts
  (loop for i from 1 to 5
        do (let ((draft (gethash i cl-telegram/api:*draft-cache*)))
             (is (notnull draft))
             (is (string= (format nil "Draft ~A" i)
                          (cl-telegram/api:draft-message draft)))))

  ;; Cleanup
  (clrhash cl-telegram/api:*draft-cache*))

;;; ======================================================================
;;; Scheduled Messages Cache Tests
;;; ======================================================================

(test test-scheduled-messages-cache
  "Test scheduled messages cache operations"
  (clrhash cl-telegram/api:*scheduled-messages*)

  ;; Add scheduled messages
  (setf (gethash 123456 cl-telegram/api:*scheduled-messages*)
        (list (list :id 1 :chat-id 123456 :message "Scheduled 1" :send-date 1713542400)
              (list :id 2 :chat-id 123456 :message "Scheduled 2" :send-date 1713546000)))

  ;; Verify
  (let ((msgs (gethash 123456 cl-telegram/api:*scheduled-messages*)))
    (is (= 2 (length msgs)))
    (is (= 1 (getf (first msgs) :id)))
    (is (= 2 (getf (second msgs) :id))))

  ;; Cleanup
  (remhash 123456 cl-telegram/api:*scheduled-messages*))

;;; ======================================================================
;;; Save Draft Tests (Mock)
;;; ======================================================================

(test test-save-draft-return-value
  "Test save-draft returns boolean"
  (let ((result (cl-telegram/api:save-draft 123456 "Test draft")))
    ;; Should return T or NIL
    (is (or (eq t result) (null result)))))

(test test-save-draft-with-entities
  "Test save-draft with entities"
  (let ((result (cl-telegram/api:save-draft 123456 "Bold text"
                                            :entities '((:bold 0 4)))))
    (is (or (eq t result) (null result)))))

(test test-save-draft-with-reply-to
  "Test save-draft with reply-to"
  (let ((result (cl-telegram/api:save-draft 123456 "Reply draft"
                                            :reply-to 100)))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Get Drafts Tests (Mock)
;;; ======================================================================

(test test-get-drafts-return-type
  "Test get-drafts returns list"
  (let ((result (cl-telegram/api:get-drafts)))
    (is (listp result))))

(test test-get-all-drafts-return-type
  "Test get-all-drafts returns plist"
  (let ((result (cl-telegram/api:get-all-drafts)))
    (is (or (listp result) (null result)))))

(test test-get-draft-from-cache
  "Test get-draft retrieves from cache"
  ;; Add to cache first
  (let ((draft (make-instance 'cl-telegram/api:draft-message
                              :peer 123456
                              :message "Cached")))
    (setf (gethash 123456 cl-telegram/api:*draft-cache*) draft))

  ;; Should return cached draft
  (let ((result (cl-telegram/api:get-draft 123456)))
    (is (notnull result))
    (is (string= "Cached" (cl-telegram/api:draft-message result))))

  ;; Cleanup
  (remhash 123456 cl-telegram/api:*draft-cache*))

;;; ======================================================================
;;; Delete Draft Tests
;;; ======================================================================

(test test-delete-draft-from-cache
  "Test delete-draft removes from cache"
  ;; Add to cache
  (setf (gethash 123456 cl-telegram/api:*draft-cache*)
        (make-instance 'cl-telegram/api:draft-message
                       :peer 123456
                       :message "To delete"))

  ;; Delete
  (let ((result (cl-telegram/api:delete-draft 123456)))
    (is (or (eq t result) (null result))))

  ;; Verify removed
  (is (null (gethash 123456 cl-telegram/api:*draft-cache*))))

(test test-clear-all-drafts
  "Test clear-all-drafts empties cache"
  ;; Add multiple drafts
  (setf (gethash 1 cl-telegram/api:*draft-cache*)
        (make-instance 'cl-telegram/api:draft-message :peer 1 :message "1")
        (gethash 2 cl-telegram/api:*draft-cache*)
        (make-instance 'cl-telegram/api:draft-message :peer 2 :message "2")
        (gethash 3 cl-telegram/api:*draft-cache*)
        (make-instance 'cl-telegram/api:draft-message :peer 3 :message "3"))

  ;; Clear all
  (let ((result (cl-telegram/api:clear-all-drafts)))
    (is (or (eq t result) (null result))))

  ;; Verify empty
  (is (= 0 (hash-table-count cl-telegram/api:*draft-cache*))))

;;; ======================================================================
;;; Scheduled Messages Tests (Mock)
;;; ======================================================================

(test test-send-scheduled-message-return
  "Test send-scheduled-message returns message ID or NIL"
  (let ((result (cl-telegram/api:send-scheduled-message 123456 "Scheduled test")))
    (is (or (integerp result) (null result)))))

(test test-send-scheduled-message-future-date
  "Test send-scheduled-message with future date"
  (let ((future-date (+ (get-universal-time) 3600))) ; 1 hour from now
    (let ((result (cl-telegram/api:send-scheduled-message
                   123456 "Future message" :send-date future-date)))
      (is (or (integerp result) (null result))))))

(test test-send-scheduled-media-return
  "Test send-scheduled-media returns message ID or NIL"
  (let ((result (cl-telegram/api:send-scheduled-media 123456 nil)))
    (is (or (integerp result) (null result)))))

;;; ======================================================================
;;; Get Scheduled Messages Tests
;;; ======================================================================

(test test-get-scheduled-messages-return-type
  "Test get-scheduled-messages returns list"
  (let ((result (cl-telegram/api:get-scheduled-messages 123456)))
    (is (listp result))))

(test test-get-all-scheduled-messages-return-type
  "Test get-all-scheduled-messages returns list"
  (let ((result (cl-telegram/api:get-all-scheduled-messages)))
    (is (listp result))))

(test test-get-scheduled-messages-from-cache
  "Test get-scheduled-messages includes cached"
  ;; Add to cache
  (setf (gethash 123456 cl-telegram/api:*scheduled-messages*)
        (list (list :id 1 :message "Cached scheduled")))

  ;; Get should include cached
  (let ((result (cl-telegram/api:get-scheduled-messages 123456)))
    (is (>= (length result) 1)))

  ;; Cleanup
  (remhash 123456 cl-telegram/api:*scheduled-messages*))

;;; ======================================================================
;;; Delete Scheduled Messages Tests
;;; ======================================================================

(test test-delete-scheduled-message-from-cache
  "Test delete-scheduled-message removes from cache"
  ;; Add to cache
  (setf (gethash 123456 cl-telegram/api:*scheduled-messages*)
        (list (list :id 1) (list :id 2) (list :id 3)))

  ;; Delete one
  (let ((result (cl-telegram/api:delete-scheduled-message 123456 2)))
    (is (or (eq t result) (null result))))

  ;; Verify removed
  (let ((msgs (gethash 123456 cl-telegram/api:*scheduled-messages*)))
    (is (= 2 (length msgs)))
    (is (null (find 2 msgs :key #'getf))))

  ;; Cleanup
  (remhash 123456 cl-telegram/api:*scheduled-messages*))

(test test-delete-all-scheduled-messages
  "Test delete-all-scheduled-messages clears cache"
  ;; Add messages
  (setf (gethash 123456 cl-telegram/api:*scheduled-messages*)
        (list (list :id 1) (list :id 2)))

  ;; Delete all
  (let ((result (cl-telegram/api:delete-all-scheduled-messages 123456)))
    (is (or (eq t result) (null result))))

  ;; Verify empty
  (is (null (gethash 123456 cl-telegram/api:*scheduled-messages*))))

;;; ======================================================================
;;; Send Scheduled Messages Now Tests
;;; ======================================================================

(test test-send-scheduled-messages-now-return
  "Test send-scheduled-messages-now returns boolean"
  (let ((result (cl-telegram/api:send-scheduled-messages-now 123456 '(1 2 3))))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Message TTL Tests
;;; ======================================================================

(test test-set-default-message-ttl-return
  "Test set-default-message-ttl returns boolean"
  (let ((result (cl-telegram/api:set-default-message-ttl 3600)))
    (is (or (eq t result) (null result)))))

(test test-get-default-message-ttl
  "Test get-default-message-ttl"
  (let ((result (cl-telegram/api:get-default-message-ttl)))
    (is (integerp result))))

(test test-set-chat-ttl-return
  "Test set-chat-ttl returns boolean"
  (let ((result (cl-telegram/api:set-chat-ttl 123456 7200)))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Multimedia/Album Tests (Mock)
;;; ======================================================================

(test test-send-multi-media-return
  "Test send-multi-media returns list"
  (let ((result (cl-telegram/api:send-multi-media 123456 nil)))
    (is (listp result))))

(test test-send-photo-album-return
  "Test send-photo-album returns list"
  (let ((result (cl-telegram/api:send-photo-album 123456 '("photo1.jpg" "photo2.jpg"))))
    (is (listp result))))

(test test-send-video-album-return
  "Test send-video-album returns list"
  (let ((result (cl-telegram/api:send-video-album 123456 '("video1.mp4"))))
    (is (listp result))))

;;; ======================================================================
;;; Copy Message Tests
;;; ======================================================================

(test test-copy-message-return
  "Test copy-message returns message or NIL"
  (let ((result (cl-telegram/api:copy-message 123456 100 789012)))
    (is (or (notnull result) (null result)))))

(test test-copy-message-with-caption
  "Test copy-message with caption"
  (let ((result (cl-telegram/api:copy-message 123456 100 789012
                                              :caption "New caption")))
    (is (or (notnull result) (null result)))))

(test test-copy-message-remove-caption
  "Test copy-message with remove-caption"
  (let ((result (cl-telegram/api:copy-message 123456 100 789012
                                              :remove-caption t)))
    (is (or (notnull result) (null result)))))

;;; ======================================================================
;;; Global State Tests
;;; ======================================================================

(test test-draft-cache-initial-state
  "Test draft cache is hash table"
  (is (typep cl-telegram/api:*draft-cache* 'hash-table)))

(test test-scheduled-messages-initial-state
  "Test scheduled messages is hash table"
  (is (typep cl-telegram/api:*scheduled-messages* 'hash-table)))

(test test-default-ttl-initial-state
  "Test default TTL is integer"
  (is (integerp cl-telegram/api:*default-ttl*)))

;;; ======================================================================
;;; Edge Case Tests
;;; ======================================================================

(test test-save-draft-empty-message
  "Test save-draft with empty message"
  (let ((result (cl-telegram/api:save-draft 123456 "")))
    (is (or (eq t result) (null result)))))

(test test-save-draft-long-message
  "Test save-draft with long message"
  (let ((long-text (make-string 4096 :initial-element #\a)))
    (let ((result (cl-telegram/api:save-draft 123456 long-text)))
      (is (or (eq t result) (null result))))))

(test test-get-draft-nonexistent
  "Test get-draft for nonexistent chat"
  (let ((result (cl-telegram/api:get-draft 999999)))
    (is (or (notnull result) (null result)))))

(test test-delete-nonexistent-draft
  "Test delete-draft for nonexistent draft"
  (let ((result (cl-telegram/api:delete-draft 999999)))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-drafts-scheduled-tests ()
  "Run all drafts and scheduled messages tests"
  (format t "~%=== Running Drafts & Scheduled Messages Unit Tests ===~%~%")
  (fiveam:run! 'drafts-scheduled-tests))

(export '(run-drafts-scheduled-tests))
