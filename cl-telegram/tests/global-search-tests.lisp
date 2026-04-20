;;; global-search-tests.lisp --- Tests for global search functionality

(in-package #:cl-telegram/tests)

(defsuite* global-search-suite ())

;;; ============================================================================
;;; Test Utilities
;;; ============================================================================

(defmacro with-search-manager ((&optional) &body body)
  "Execute body with search manager initialized."
  `(progn
     (setf cl-telegram/api::*search-manager* nil)
     (cl-telegram/api:init-search-manager)
     (unwind-protect
          (progn ,@body)
       (setf cl-telegram/api::*search-manager* nil))))

(defmacro with-search-filters ((&rest args) &body body)
  "Execute body with search filters."
  `(let ((filters (make-instance 'cl-telegram/api:search-filters ,@args)))
     ,@body))

;;; ============================================================================
;;; Search Result Class Tests
;;; ============================================================================

(deftest test-search-result-creation ()
  "Test creating a search-result instance."
  (let ((result (make-instance 'cl-telegram/api:search-result
                               :message '(:id 1 :text "Hello")
                               :chat-id 123456
                               :chat-title "Test Chat")))
    (is (typep result 'cl-telegram/api:search-result))
    (is (= (cl-telegram/api:search-chat-id result) 123456))
    (is (string= (cl-telegram/api:search-chat-title result) "Test Chat"))
    (is (= (cl-telegram/api:search-score result) 0))))

(deftest test-search-filters-creation ()
  "Test creating search filters."
  (with-search-filters ((:sender-id 100 :date-from 1700000000 :date-to 1700100000))
    (is (typep filters 'cl-telegram/api:search-filters))
    (is (= (cl-telegram/api:filter-sender-id filters) 100))
    (is (= (cl-telegram/api:filter-date-from filters) 1700000000))
    (is (= (cl-telegram/api:filter-date-to filters) 1700100000))))

;;; ============================================================================
;;; Search Manager Tests
;;; ============================================================================

(deftest test-search-manager-initialization ()
  "Test search manager initialization."
  (with-search-manager ()
    (let ((manager (cl-telegram/api:get-search-manager)))
      (is (typep manager 'cl-telegram/api:search-manager))
      (is (typep (cl-telegram/api:search-manager-cache manager) 'hash-table))
      (is (typep (cl-telegram/api:search-manager-history manager) 'list)))))

(deftest test-get-search-manager ()
  "Test get-search-manager auto-initialization."
  (setf cl-telegram/api::*search-manager* nil)
  (let ((manager (cl-telegram/api:get-search-manager)))
    (is (typep manager 'cl-telegram/api:search-manager))
    (is (not (null cl-telegram/api::*search-manager*)))))

;;; ============================================================================
;;; Search Functions Tests
;;; ============================================================================

(deftest test-format-search-results ()
  "Test search results formatting."
  (let* ((results (list (make-instance 'cl-telegram/api:search-result
                                       :message '(:id 1 :text "Hello world")
                                       :chat-id 123456
                                       :chat-title "Test Chat"
                                       :score 150
                                       :match-text "Hello world"
                                       :match-position 0)))
         (formatted (cl-telegram/api:format-search-results results)))
    (is (listp formatted))
    (is (= (length formatted) 1))
    (is (getf (first formatted) :chat_id))
    (is (getf (first formatted) :score))))

(deftest test-highlight-search-result ()
  "Test search result highlighting."
  (let ((text "Hello world, hello again"))
    (is (string= (cl-telegram/api:highlight-search-result text "hello")
                 "**Hello** world, hello again"))
    (is (string= (cl-telegram/api:highlight-search-result text "world")
                 "Hello **world**, hello again"))))

(deftest test-highlight-search-result-max-length ()
  "Test highlighting with max length truncation."
  (let ((text "This is a very long text that should be truncated"))
    (is (<= (length (cl-telegram/api:highlight-search-result text "long" :max-length 30)) 30))))

;;; ============================================================================
;;; Search by Sender Tests
;;; ============================================================================

(deftest test-search-messages-by-sender ()
  "Test searching messages by sender ID."
  (with-search-manager ()
    ;; Mock messages for testing
    (let ((messages (cl-telegram/api:search-messages-by-sender 100 :limit 10)))
      (is (listp messages))
      ;; Returns empty list when no messages exist
      (is (null messages)))))

;;; ============================================================================
;;; Search by Date Range Tests
;;; ============================================================================

(deftest test-search-messages-by-date-range ()
  "Test searching messages by date range."
  (with-search-manager ()
    (let ((messages (cl-telegram/api:search-messages-by-date-range
                     1700000000 1700100000 :limit 10)))
      (is (listp messages))
      (is (null messages)))))

;;; ============================================================================
;;; Search by Media Type Tests
;;; ============================================================================

(deftest test-search-messages-by-media-type ()
  "Test searching messages by media type."
  (with-search-manager ()
    (let ((messages (cl-telegram/api:search-messages-by-media-type :photo :limit 10)))
      (is (listp messages))
      (is (null messages)))))

;;; ============================================================================
;;; Search Suggestions Tests
;;; ============================================================================

(deftest test-get-search-suggestions ()
  "Test search suggestions."
  (with-search-manager ()
    (let ((suggestions (cl-telegram/api:get-search-suggestions "hel" :limit 5)))
      (is (listp suggestions))
      (is (null suggestions)))))

;;; ============================================================================
;;; Cache Management Tests
;;; ============================================================================

(deftest test-get-search-cache-stats ()
  "Test search cache statistics."
  (with-search-manager ()
    (let ((stats (cl-telegram/api:get-search-cache-stats)))
      (is (listp stats))
      (is (getf stats :cache_size))
      (is (getf stats :cache_hits))
      (is (getf stats :cache_misses)))))

(deftest test-clear-search-cache ()
  "Test clearing search cache."
  (with-search-manager ()
    (let ((manager (cl-telegram/api:get-search-manager)))
      ;; Add something to cache
      (setf (gethash "test" (cl-telegram/api:search-manager-cache manager)) 'result)
      (is (not (null (gethash "test" (cl-telegram/api:search-manager-cache manager)))))
      ;; Clear cache
      (cl-telegram/api:clear-search-cache)
      (is (null (gethash "test" (cl-telegram/api:search-manager-cache manager)))))))

(deftest test-set-search-cache-ttl ()
  "Test setting search cache TTL."
  (with-search-manager ()
    (is (cl-telegram/api:set-search-cache-ttl 600))
    (let ((manager (cl-telegram/api:get-search-manager)))
      (is (= (cl-telegram/api:search-manager-ttl manager) 600)))))

;;; ============================================================================
;;; Search History Tests
;;; ============================================================================

(deftest test-get-search-history ()
  "Test getting search history."
  (with-search-manager ()
    (let ((history (cl-telegram/api:get-search-history)))
      (is (listp history))
      (is (null history)))))

(deftest test-clear-search-history ()
  "Test clearing search history."
  (with-search-manager ()
    (let ((manager (cl-telegram/api:get-search-manager)))
      ;; Add to history
      (setf (cl-telegram/api:search-manager-history manager) '("query1" "query2"))
      (is (= (length (cl-telegram/api:get-search-history)) 2))
      ;; Clear history
      (cl-telegram/api:clear-search-history)
      (is (null (cl-telegram/api:get-search-history))))))

;;; ============================================================================
;;; In-Chat Search Tests
;;; ============================================================================

(deftest test-search-in-chat ()
  "Test searching within a specific chat."
  (with-search-manager ()
    (let ((results (cl-telegram/api:search-in-chat 123456 "hello" :limit 10)))
      (is (listp results))
      (is (null results)))))

;;; ============================================================================
;;; Relevance Score Tests
;;; ============================================================================

(deftest test-calculate-relevance-score ()
  "Test relevance score calculation."
  (let ((score1 (cl-telegram/api::calculate-relevance-score "hello" "Hello world" 0))
        (score2 (cl-telegram/api::calculate-relevance-score "hello" "Hello world" 10)))
    (is (> score1 score2))  ; Earlier match should have higher score
    (is (>= score1 100))
    (is (>= score2 100))))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(deftest test-global-search-empty-query ()
  "Test global search with empty query."
  (with-search-manager ()
    (let ((results (cl-telegram/api:global-search-messages "")))
      (is (listp results))
      (is (null results)))))

(deftest test-global-search-with-filters ()
  "Test global search with various filters."
  (with-search-manager ()
    (let ((results (cl-telegram/api:global-search-messages "test"
                                                           :sender-id 100
                                                           :date-from 1700000000
                                                           :date-to 1700100000
                                                           :chat-ids '(123456 789012)
                                                           :media-type :photo
                                                           :has-media t
                                                           :limit 20
                                                           :use-cache t)))
      (is (listp results))
      (is (null results)))))

(deftest test-search-without-cache ()
  "Test search with cache disabled."
  (with-search-manager ()
    (let ((results (cl-telegram/api:global-search-messages "test" :use-cache nil)))
      (is (listp results)))))

;;; ============================================================================
;;; Error Handling Tests
;;; ============================================================================

(deftest test-search-with-invalid-chat-id ()
  "Test search with invalid chat ID."
  (with-search-manager ()
    (let ((results (cl-telegram/api:search-in-chat -1 "test")))
      (is (listp results)))))

(deftest test-search-with-negative-limit ()
  "Test search with negative limit."
  (with-search-manager ()
    (let ((results (cl-telegram/api:global-search-messages "test" :limit -10)))
      (is (listp results))
      (is (<= (length results) 50)))))  ; Should default to 50

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-all-global-search-tests ()
  "Run all global search tests."
  (run! 'chat-backup-suite))
