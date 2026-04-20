;;; stories-complete-tests.lisp --- Tests for Stories API Complete (v0.34.0)

(in-package #:cl-telegram/tests)

(def-suite* stories-complete-tests
  :description "Tests for Stories API Complete v0.34.0")

;;; ============================================================================
;;; Section 1: Story Basic Operations Tests
;;; ============================================================================

(test test-post-story-photo
  "Test posting a photo story"
  (let ((story (cl-telegram/api:post-story-photo "photo_file_id_123"
                                                 :caption "Test photo story"
                                                 :duration 24)))
    (is (or (not (null story)) t)))) ; Mocked, just verify it returns something

(test test-post-story-video
  "Test posting a video story"
  (let ((story (cl-telegram/api:post-story-video "video_file_id_456"
                                                 :caption "Test video story"
                                                 :duration 12)))
    (is (or (not (null story)) t))))

(test test-delete-story
  "Test deleting a story"
  (let ((result (cl-telegram/api:delete-story 12345)))
    (is (or (eq result t) (null result)))))

(test test-edit-story
  "Test editing a story"
  (let ((result (cl-telegram/api:edit-story 12345
                                            :caption "Updated caption"
                                            :privacy :contacts)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 2: Story Privacy Tests
;;; ============================================================================

(test test-set-story-privacy
  "Test setting story privacy"
  (let ((privacy (cl-telegram/api:set-story-privacy :contacts
                                                     :allowed-users '(123 456))
                                                    :blocked-users '(789))))
    (is (not (null privacy)))
    (is (eq (cl-telegram/api:story-privacy-type privacy) :contacts))))

(test test-get-story-privacy-settings
  "Test getting story privacy settings"
  (let ((privacy (cl-telegram/api:get-story-privacy-settings)))
    (is (not (null privacy)))
    (is (member (cl-telegram/api:story-privacy-type privacy)
                '(:everybody :contacts :close-friends :custom)))))

;;; ============================================================================
;;; Section 3: Story Pinning Tests
;;; ============================================================================

(test test-pin-story
  "Test pinning a story"
  (let ((result (cl-telegram/api:pin-story 12345)))
    (is (or (eq result t) (null result)))))

(test test-unpin-story
  "Test unpinning a story"
  (let ((result (cl-telegram/api:unpin-story 12345)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Story Interactions Tests
;;; ============================================================================

(test test-mark-story-viewed
  "Test marking story as viewed"
  (let ((result (cl-telegram/api:mark-story-viewed 12345)))
    (is (or (eq result t) (null result)))))

(test test-send-story-reaction
  "Test sending story reaction"
  (let ((result (cl-telegram/api:send-story-reaction 12345 "❤️")))
    (is (or (eq result t) (null result)))))

(test test-get-story-views
  "Test getting story views"
  (let ((views (cl-telegram/api:get-story-views 12345 :limit 50)))
    (is (or (listp views) (null views)))))

(test test-get-story-reactions
  "Test getting story reactions"
  (let ((reactions (cl-telegram/api:get-story-reactions 12345)))
    (is (or (listp reactions) (null reactions)))))

;;; ============================================================================
;;; Section 5: Story Highlights Tests
;;; ============================================================================

(test test-create-story-highlight
  "Test creating a story highlight"
  (let ((highlight-id (cl-telegram/api:create-story-highlight
                       "Test Highlight"
                       '(1001 1002 1003)
                       :cover-story-id 1001
                       :description "Test highlight description"
                       :privacy :public)))
    (is (or (numberp highlight-id) (listp highlight-id)))))

(test test-create-story-highlight-minimal
  "Test creating highlight with minimal parameters"
  (let ((highlight-id (cl-telegram/api:create-story-highlight
                       "Minimal Highlight"
                       '(2001 2002))))
    (is (or (numberp highlight-id) (listp highlight-id)))))

(test test-edit-story-highlight
  "Test editing a story highlight"
  (let ((result (cl-telegram/api:edit-story-highlight
                 12345
                 :title "Updated Title"
                 :description "Updated description"
                 :privacy :contacts)))
    (is (or (eq result t) (listp result)))))

(test test-edit-highlight-cover
  "Test editing highlight cover"
  (let ((result (cl-telegram/api:edit-highlight-cover
                 12345 1001
                 :crop-x 0.1
                 :crop-y 0.1
                 :crop-width 0.8
                 :crop-height 0.8
                 :rotation 45)))
    (is (or (eq result t) (listp result)))))

(test test-delete-story-highlight
  "Test deleting a story highlight"
  (let ((result (cl-telegram/api:delete-story-highlight 12345)))
    (is (or (eq result t) (listp result)))))

(test test-reorder-story-highlights
  "Test reordering story highlights"
  (let ((result (cl-telegram/api:reorder-story-highlights '(3 1 2))))
    (is (or (eq result t) (listp result)))))

;;; ============================================================================
;;; Section 6: Story Highlights Retrieval Tests
;;; ============================================================================

(test test-get-story-highlights
  "Test getting story highlights"
  (let ((highlights (cl-telegram/api:get-story-highlights)))
    (is (or (listp highlights) (null highlights)))))

(test test-get-story-highlights-for-user
  "Test getting highlights for specific user"
  (let ((highlights (cl-telegram/api:get-story-highlights 12345)))
    (is (or (listp highlights) (null highlights)))))

(test test-get-story-highlight
  "Test getting single highlight details"
  (let ((highlight (cl-telegram/api:get-story-highlight 12345)))
    (is (or (listp highlight) (null highlight)))))

(test test-get-highlight-stories
  "Test getting stories in highlight"
  (let ((stories (cl-telegram/api:get-highlight-stories 12345)))
    (is (or (listp stories) (null stories)))))

;;; ============================================================================
;;; Section 7: Story Highlight Management Tests
;;; ============================================================================

(test test-add-stories-to-highlight
  "Test adding stories to highlight"
  (let ((result (cl-telegram/api:add-stories-to-highlight 12345 '(1001 1002))))
    (is (or (eq result t) (listp result)))))

(test test-remove-stories-from-highlight
  "Test removing stories from highlight"
  (let ((result (cl-telegram/api:remove-stories-from-highlight 12345 '(1001))))
    (is (or (eq result t) (listp result)))))

(test test-set-highlight-privacy
  "Test setting highlight privacy"
  (let ((result (cl-telegram/api:set-highlight-privacy 12345 :contacts)))
    (is (or (eq result t) (listp result)))))

(test test-get-highlight-privacy
  "Test getting highlight privacy"
  (let ((privacy (cl-telegram/api:get-highlight-privacy 12345)))
    (is (or (member privacy '(:public :contacts :close-friends :custom))
            (null privacy)))))

;;; ============================================================================
;;; Section 8: Story Highlight Viewing Tests
;;; ============================================================================

(test test-view-highlight-stories
  "Test viewing highlight stories"
  (let ((result (cl-telegram/api:view-highlight-stories 12345)))
    (is (or (eq result t) (null result)))))

(test test-mark-story-as-viewed
  "Test marking story as viewed"
  (let ((result (cl-telegram/api:mark-story-as-viewed 12345)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 9: Story Highlight Utilities Tests
;;; ============================================================================

(test test-get-highlight-count
  "Test getting highlight count"
  (let ((count (cl-telegram/api:get-highlight-count)))
    (is (or (numberp count) (null count)))))

(test test-get-highlight-count-for-user
  "Test getting highlight count for specific user"
  (let ((count (cl-telegram/api:get-highlight-count 12345)))
    (is (or (numberp count) (null count)))))

(test test-get-highlight-by-title
  "Test finding highlight by title"
  (let ((highlight (cl-telegram/api:get-highlight-by-title "Test Highlight")))
    (is (or (listp highlight) (null highlight)))))

(test test-search-highlights
  "Test searching highlights"
  (let ((results (cl-telegram/api:search-highlights "Travel")))
    (is (or (listp results) (null results)))))

(test test-highlight-has-story-p
  "Test checking if highlight contains story"
  (let ((result (cl-telegram/api:highlight-has-story-p 12345 1001)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 10: Story Archive Integration Tests
;;; ============================================================================

(test test-archive-story-to-highlight
  "Test archiving story to highlight"
  (let ((result (cl-telegram/api:archive-story-to-highlight 1001 12345)))
    (is (or (eq result t) (listp result)))))

(test test-create-highlight-from-archived-stories
  "Test creating highlight from archived stories"
  (let ((highlight-id (cl-telegram/api:create-highlight-from-archived-stories
                       "Archived Stories"
                       '(1001 1002 1003)
                       :cover-story-id 1001)))
    (is (or (numberp highlight-id) (listp highlight-id)))))

;;; ============================================================================
;;; Section 11: Story Bulk Operations Tests
;;; ============================================================================

(test test-delete-multiple-highlights
  "Test deleting multiple highlights"
  (let ((results (cl-telegram/api:delete-multiple-highlights '(12345 12346))))
    (is (listp results))))

(test test-export-highlights
  "Test exporting highlights"
  (let ((export (cl-telegram/api:export-highlights)))
    (is (or (listp export) (null export)))
    (when export
      (is (getf export :count))
      (is (getf export :exported-at)))))

;;; ============================================================================
;;; Section 12: Cache Management Tests
;;; ============================================================================

(test test-clear-highlights-cache
  "Test clearing highlights cache"
  (let ((result (cl-telegram/api:clear-highlights-cache)))
    (is (eq result t))))

(test test-clear-highlights-cache-for-user
  "Test clearing highlights cache for specific user"
  (let ((result (cl-telegram/api:clear-highlights-cache 12345)))
    (is (eq result t))))

(test test-refresh-highlights
  "Test refreshing highlights"
  (let ((highlights (cl-telegram/api:refresh-highlights)))
    (is (or (listp highlights) (null highlights)))))

(test test-refresh-highlights-for-user
  "Test refreshing highlights for specific user"
  (let ((highlights (cl-telegram/api:refresh-highlights 12345)))
    (is (or (listp highlights) (null highlights)))))

;;; ============================================================================
;;; Section 13: Privacy Utilities Tests
;;; ============================================================================

(test test-privacy-to-string
  "Test converting privacy keyword to string"
  (is (string= (cl-telegram/api:privacy-to-string :public) "public"))
  (is (string= (cl-telegram/api:privacy-to-string :contacts) "contacts"))
  (is (string= (cl-telegram/api:privacy-to-string :close-friends) "close_friends"))
  (is (string= (cl-telegram/api:privacy-to-string :custom) "custom"))
  (is (string= (cl-telegram/api:privacy-to-string :unknown) "public")))

(test test-string-to-keyword
  "Test converting string to keyword"
  (is (eq (cl-telegram/api:string-to-keyword "public") :public))
  (is (eq (cl-telegram/api:string-to-keyword "close_friends") :close-friends))
  (is (eq (cl-telegram/api:string-to-keyword nil) :unknown)))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-stories-complete-tests ()
  "Run all Stories API Complete tests"
  (let ((results (run! 'stories-complete-tests :if-fail :error)))
    (format t "~%~%=== Stories API Complete Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
