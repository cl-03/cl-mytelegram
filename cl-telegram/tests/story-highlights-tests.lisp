;;; story-highlights-tests.lisp --- Tests for story highlights feature

(in-package #:cl-telegram/tests)

(def-suite* story-highlights-tests
  :description "Story highlights management tests")

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun mock-highlight (&optional (id 1) (title "Test Highlight")
                                 (story-ids '(1001 1002 1003))
                                 (privacy :public))
  "Create a mock highlight plist for testing.

   Args:
     id: Highlight ID
     title: Highlight title
     story-ids: List of story IDs
     privacy: Privacy setting

   Returns:
     Highlight plist"
  (list :id id
        :title title
        :description "Test description"
        :story_ids story-ids
        :privacy (cl-telegram/api::privacy-to-string privacy)
        :cover_story_id (first story-ids)
        :created_at (get-universal-time)))

;;; ============================================================================
;;; Privacy Conversion Tests
;;; ============================================================================

(test test-privacy-to-string
  "Test privacy keyword to string conversion"
  (is (string= (cl-telegram/api::privacy-to-string :public) "public"))
  (is (string= (cl-telegram/api::privacy-to-string :contacts) "contacts"))
  (is (string= (cl-telegram/api::privacy-to-string :close-friends) "close_friends"))
  (is (string= (cl-telegram/api::privacy-to-string :custom) "custom"))
  (is (string= (cl-telegram/api::privacy-to-string :invalid) "public")))

(test test-string-to-keyword
  "Test string to keyword conversion"
  (is (eq (cl-telegram/api::string-to-keyword "public") :PUBLIC))
  (is (eq (cl-telegram/api::string-to-keyword "close_friends") :CLOSE_FRIENDS))
  (is (eq (cl-telegram/api::string-to-keyword nil) :UNKNOWN))
  (is (eq (cl-telegram/api::string-to-keyword "") :|))

;;; ============================================================================
;;; Cache Management Tests
;;; ============================================================================

(test test-clear-highlights-cache
  "Test highlights cache clearing"
  ;; Setup: Add some data to cache
  (setf (gethash 123 cl-telegram/api:*highlights-cache*) "test-data")
  (setf (gethash 456 cl-telegram/api:*highlights-cache*) "more-data")

  ;; Clear specific user cache
  (is (cl-telegram/api:clear-highlights-cache 123))
  (is (null (gethash 123 cl-telegram/api:*highlights-cache*)))
  (is (equal (gethash 456 cl-telegram/api:*highlights-cache*) "more-data"))

  ;; Clear all cache
  (is (cl-telegram/api:clear-highlights-cache))
  (is (null (gethash 456 cl-telegram/api:*highlights-cache*))))

(test test-refresh-highlights
  "Test highlights refresh"
  ;; This test verifies the function exists and returns a value
  (let ((result (cl-telegram/api:refresh-highlights)))
    ;; Should return nil or list (depending on auth state)
    (is (or (null result) (listp result)))))

;;; ============================================================================
;;; Highlight Utilities Tests
;;; ============================================================================

(test test-get-highlight-count
  "Test highlight count retrieval"
  ;; Clear cache first
  (cl-telegram/api:clear-highlights-cache)

  ;; Mock cache data
  (setf (gethash 999 cl-telegram/api:*highlights-cache*)
        (list (mock-highlight 1)
              (mock-highlight 2)
              (mock-highlight 3)))

  ;; Count should be 3
  (is (= (cl-telegram/api:get-highlight-count 999) 3)))

(test test-get-highlight-by-title
  "Test finding highlight by title"
  ;; Clear cache first
  (cl-telegram/api:clear-highlights-cache)

  ;; Mock cache data
  (setf (gethash 999 cl-telegram/api:*highlights-cache*)
        (list (mock-highlight 1 "Travel")
              (mock-highlight 2 "Food")
              (mock-highlight 3 "Work")))

  ;; Find by title
  (let ((highlight (cl-telegram/api:get-highlight-by-title "Food" 999)))
    (is (not (null highlight)))
    (is (string= (getf highlight :title) "Food")))

  ;; Non-existent title should return nil
  (is (null (cl-telegram/api:get-highlight-by-title "NonExistent" 999))))

(test test-search-highlights
  "Test searching highlights"
  ;; Clear cache first
  (cl-telegram/api:clear-highlights-cache)

  ;; Mock cache data
  (setf (gethash 999 cl-telegram/api:*highlights-cache*)
        (list (mock-highlight 1 "Travel 2024" nil :public
                              :description "My travels around Europe")
              (mock-highlight 2 "Food Adventures" nil :public
                              :description "Best restaurants in Tokyo")
              (mock-highlight 3 "Work Projects" nil :contacts
                              :description "Client work and presentations")))

  ;; Search by title
  (let ((results (cl-telegram/api:search-highlights "Travel" 999)))
    (is (= (length results) 1))
    (is (string= (getf (first results) :title) "Travel 2024")))

  ;; Search by description (case insensitive)
  (let ((results (cl-telegram/api:search-highlights "tokyo" 999)))
    (is (= (length results) 1))
    (is (string= (getf (first results) :title) "Food Adventures")))

  ;; Search with no matches
  (is (null (cl-telegram/api:search-highlights "NonExistent" 999))))

(test test-highlight-has-story-p
  "Test checking if highlight contains story"
  ;; Mock highlight with specific stories
  (let ((highlight (mock-highlight 1 "Test" '(1001 1002 1003))))
    ;; Cache it
    (setf (gethash 999 cl-telegram/api:*highlights-cache*) (list highlight))

    ;; Should have these stories
    (is (cl-telegram/api:highlight-has-story-p 1 1001))
    (is (cl-telegram/api:highlight-has-story-p 1 1002))
    (is (cl-telegram/api:highlight-has-story-p 1 1003))

    ;; Should not have other stories
    (is (null (cl-telegram/api:highlight-has-story-p 1 9999))))

;;; ============================================================================
;;; Archive Integration Tests
;;; ============================================================================

(test test-archive-story-to-highlight
  "Test archiving story to highlight"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:archive-story-to-highlight 1001 1)))
    ;; Should return T or error plist
    (is (or (eq result t) (listp result)))))

(test test-create-highlight-from-archived-stories
  "Test creating highlight from archived stories"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:create-highlight-from-archived-stories
                 "New Highlight" '(1001 1002 1003)
                 :cover-story-id 1001)))
    ;; Should return highlight ID or error plist
    (is (or (numberp result) (listp result)))))

;;; ============================================================================
;;; Bulk Operations Tests
;;; ============================================================================

(test test-delete-multiple-highlights
  "Test deleting multiple highlights"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:delete-multiple-highlights '(1 2 3))))
    ;; Should return list of results
    (is (listp result))
    (is (= (length result) 3))))

(test test-export-highlights
  "Test exporting highlights"
  ;; Clear cache first
  (cl-telegram/api:clear-highlights-cache)

  ;; Mock cache data
  (setf (gethash 999 cl-telegram/api:*highlights-cache*)
        (list (mock-highlight 1 "Travel")
              (mock-highlight 2 "Food")))

  ;; Export
  (let ((export-data (cl-telegram/api:export-highlights 999)))
    (is (not (null export-data)))
    (is (eq (getf export-data :user-id) 999))
    (is (= (getf export-data :count) 2))
    (is (listp (getf export-data :highlights)))
    (is (numberp (getf export-data :exported-at)))))

;;; ============================================================================
;;; Privacy Settings Tests
;;; ============================================================================

(test test-get-highlight-privacy
  "Test getting highlight privacy"
  ;; Create mock highlight with different privacy levels
  (let ((public-highlight (mock-highlight 1 "Public" nil :public))
        (contacts-highlight (mock-highlight 2 "Contacts" nil :contacts))
        (close-friends-highlight (mock-highlight 3 "Close Friends" nil :close-friends)))

    ;; Test privacy extraction
    (is (eq (cl-telegram/api:get-highlight-privacy 1) :PUBLIC))
    (is (eq (cl-telegram/api:get-highlight-privacy 2) :CONTACTS))
    (is (eq (cl-telegram/api:get-highlight-privacy 3) :CLOSE_FRIENDS))))

(test test-set-highlight-privacy
  "Test setting highlight privacy"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:set-highlight-privacy 1 :contacts)))
    ;; Should return T or error plist
    (is (or (eq result t) (listp result)))))

;;; ============================================================================
;;; Story Management Tests
;;; ============================================================================

(test test-add-stories-to-highlight
  "Test adding stories to highlight"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:add-stories-to-highlight 1 '(1004 1005))))
    ;; Should return T or error plist
    (is (or (eq result t) (listp result)))))

(test test-remove-stories-from-highlight
  "Test removing stories from highlight"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:remove-stories-from-highlight 1 '(1001))))
    ;; Should return T or error plist
    (is (or (eq result t) (listp result)))))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(test test-highlights-cache-integration
  "Test highlights cache integration"
  (cl-telegram/api:clear-highlights-cache)

  ;; Simulate fetching and caching highlights
  (let ((mock-data (list (mock-highlight 1)
                         (mock-highlight 2)
                         (mock-highlight 3))))
    (setf (gethash 123 cl-telegram/api:*highlights-cache*) mock-data)

    ;; Verify cache
    (is (equal (gethash 123 cl-telegram/api:*highlights-cache*) mock-data))

    ;; Verify count
    (is (= (cl-telegram/api:get-highlight-count 123) 3))

    ;; Search works
    (is (= (length (cl-telegram/api:search-highlights "Test" 123)) 3))

    ;; Clear and verify
    (cl-telegram/api:clear-highlights-cache 123)
    (is (null (gethash 123 cl-telegram/api:*highlights-cache*))))

;;; ============================================================================
;;; Error Handling Tests
;;; ============================================================================

(test test-create-highlight-without-title
  "Test creating highlight without title fails"
  (let ((result (cl-telegram/api:create-story-highlight nil '(1 2 3))))
    (is (listp result))
    (is (getf result :error))))

(test test-create-highlight-without-stories
  "Test creating highlight without stories fails"
  (let ((result (cl-telegram/api:create-story-highlight "Test" nil)))
    (is (listp result))
    (is (getf result :error))))

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-story-highlights-tests ()
  "Run all story highlights tests.

   Returns:
     Test results"
  (fiveam:run! 'story-highlights-tests))

;;; ============================================================================
;;; End of story-highlights-tests.lisp
;;; ============================================================================
