;;; search-discovery-tests.lisp --- Tests for search and discovery features
;;;
;;; Tests for chat search, message search, member search,
;;; and search filters

(in-package #:cl-telegram/tests)

;;; ### Search Filter Tests

(deftest test-make-search-filter
  "Test search filter creation"
  (let ((filter (cl-telegram/api:make-search-filter :photo)))
    (is (typep filter 'cl-telegram/api::search-filter))
    (is (eq (cl-telegram/api:search-filter-type filter) :photo))))

(deftest test-search-filter-types
  "Test all search filter types"
  (let ((filter-types
         '(:empty :photo :video :audio :document :animation
           :voice-note :video-note :photo-and-video :url
           :poll :mention :unread-mention :unread-reaction
           :unread-poll-vote :chat-photo :pinned :failed-to-send)))
    (dolist (type filter-types)
      (let ((filter (cl-telegram/api:make-search-filter type)))
        (is (eq (cl-telegram/api:search-filter-type filter) type))))))

(deftest test-filter-to-tl-object
  "Test filter conversion to TL object"
  (let ((filter (cl-telegram/api:make-search-filter :photo)))
    (let ((tl-obj (cl-telegram/api::filter-to-tl-object filter)))
      (is (listp tl-obj))
      (is (eq (getf tl-obj :@type) :searchMessagesFilterPhoto)))))

;;; ### Chat Search Tests

(deftest test-search-public-chats-signature
  "Test search-public-chats function exists"
  (is (fboundp 'cl-telegram/api:search-public-chats)))

(deftest test-search-chats-signature
  "Test search-chats function exists"
  (is (fboundp 'cl-telegram/api:search-chats)))

(deftest test-search-chats-on-server-signature
  "Test search-chats-on-server function exists"
  (is (fboundp 'cl-telegram/api:search-chats-on-server)))

(deftest test-search-recently-found-chats-signature
  "Test search-recently-found-chats function exists"
  (is (fboundp 'cl-telegram/api:search-recently-found-chats)))

;;; ### Message Search Tests

(deftest test-search-messages-signature
  "Test search-messages function exists"
  (is (fboundp 'cl-telegram/api:search-messages)))

(deftest test-search-chat-messages-signature
  "Test search-chat-messages function exists"
  (is (fboundp 'cl-telegram/api:search-chat-messages)))

(deftest test-search-secret-messages-signature
  "Test search-secret-messages function exists"
  (is (fboundp 'cl-telegram/api:search-secret-messages)))

;;; ### Member Search Tests

(deftest test-search-chat-members-signature
  "Test search-chat-members function exists"
  (is (fboundp 'cl-telegram/api:search-chat-members)))

;;; ### Search Helper Tests

(deftest test-get-search-query-suggestions-signature
  "Test get-search-query-suggestions function exists"
  (is (fboundp 'cl-telegram/api:get-search-query-suggestions)))

(deftest test-clear-search-history-signature
  "Test clear-search-history function exists"
  (is (fboundp 'cl-telegram/api:clear-search-history)))

(deftest test-get-search-history-signature
  "Test get-search-history function exists"
  (is (fboundp 'cl-telegram/api:get-search-history)))

;;; ### Global Search Tests

(deftest test-global-search-signature
  "Test global-search function exists"
  (is (fboundp 'cl-telegram/api:global-search)))

;;; ### Search Cache Tests

(deftest test-search-cache-operations
  "Test search cache operations"
  ;; Test caching
  (cl-telegram/api::cache-search-result "test-key" "test-result" :ttl 60)
  (let ((cached (cl-telegram/api::get-cached-search "test-key")))
    (is (string= cached "test-result")))
  ;; Test cache expiration
  (cl-telegram/api::cache-search-result "expire-key" "expire-result" :ttl 0)
  (sleep 1)
  (let ((cached (cl-telegram/api::get-cached-search "expire-key")))
    (is (null cached))))

;;; ### Integration Tests

(deftest test-search-api-existence
  "Test that all search API functions exist"
  (is (fboundp 'cl-telegram/api:make-search-filter))
  (is (fboundp 'cl-telegram/api:search-public-chats))
  (is (fboundp 'cl-telegram/api:search-public-chats-multi))
  (is (fboundp 'cl-telegram/api:search-chats))
  (is (fboundp 'cl-telegram/api:search-chats-on-server))
  (is (fboundp 'cl-telegram/api:search-recently-found-chats))
  (is (fboundp 'cl-telegram/api:search-messages))
  (is (fboundp 'cl-telegram/api:search-chat-messages))
  (is (fboundp 'cl-telegram/api:search-secret-messages))
  (is (fboundp 'cl-telegram/api:search-chat-members))
  (is (fboundp 'cl-telegram/api:get-search-query-suggestions))
  (is (fboundp 'cl-telegram/api:clear-search-history))
  (is (fboundp 'cl-telegram/api:global-search)))

;;; ### Test Runner

(defun run-search-discovery-tests ()
  "Run all search and discovery tests.

   Returns:
     T if all tests pass"
  (format t "~%Running Search and Discovery Tests...~%")
  (let ((results (list
                  (fiveam:run! 'test-make-search-filter)
                  (fiveam:run! 'test-search-filter-types)
                  (fiveam:run! 'test-filter-to-tl-object)
                  (fiveam:run! 'test-search-public-chats-signature)
                  (fiveam:run! 'test-search-chats-signature)
                  (fiveam:run! 'test-search-chats-on-server-signature)
                  (fiveam:run! 'test-search-recently-found-chats-signature)
                  (fiveam:run! 'test-search-messages-signature)
                  (fiveam:run! 'test-search-chat-messages-signature)
                  (fiveam:run! 'test-search-secret-messages-signature)
                  (fiveam:run! 'test-search-chat-members-signature)
                  (fiveam:run! 'test-get-search-query-suggestions-signature)
                  (fiveam:run! 'test-clear-search-history-signature)
                  (fiveam:run! 'test-get-search-history-signature)
                  (fiveam:run! 'test-global-search-signature)
                  (fiveam:run! 'test-search-cache-operations)
                  (fiveam:run! 'test-search-api-existence))))
    (if (every #'identity results)
        (progn
          (format t "All tests passed!~%")
          t)
        (progn
          (format t "Some tests failed!~%")
          nil))))
