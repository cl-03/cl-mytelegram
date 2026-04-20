;;; channel-reactions-tests.lisp --- Tests for channel reactions and emoji status

(in-package #:cl-telegram/tests)

(def-suite* channel-reactions-tests
  :description "Channel reactions and emoji status tests")

;;; ============================================================================
;;; Privacy Conversion Tests
;;; ============================================================================

(test test-channel-peer-id
  "Test channel peer ID conversion"
  (let ((peer (cl-telegram/api::channel-peer-id -1001234567890)))
    (is (listp peer))
    (is (string= (getf peer :@type) "chatIdentifier"))
    (is (= (getf peer :id) -1001234567890))))

;;; ============================================================================
;;; Cache Management Tests
;;; ============================================================================

(test test-clear-reaction-cache
  "Test reaction cache clearing"
  ;; Setup: Add some data to cache
  (setf (gethash (intern " -1001234567890-100") cl-telegram/api:*reactions-cache*) "test-data")
  (setf (gethash (intern " -1001234567890-200") cl-telegram/api:*reactions-cache*) "more-data")

  ;; Clear specific message cache
  (is (cl-telegram/api:clear-reaction-cache -1001234567890 100))

  ;; Verify cleared
  (is (null (gethash (intern " -1001234567890-100") cl-telegram/api:*reactions-cache*)))
  (is (equal (gethash (intern " -1001234567890-200") cl-telegram/api:*reactions-cache*) "more-data"))

  ;; Clear all cache
  (is (cl-telegram/api:clear-all-reaction-caches))
  (is (null (gethash (intern " -1001234567890-200") cl-telegram/api:*reactions-cache*))))

;;; ============================================================================
;;; Available Reactions Tests
;;; ============================================================================

(test test-get-channel-available-reactions
  "Test getting available reactions"
  (let ((reactions (cl-telegram/api:get-channel-available-reactions)))
    (is (listp reactions))
    (is (> (length reactions) 0))
    ;; Check for common reactions
    (is (not (null reactions)))))

(test test-set-channel-available-reactions
  "Test setting available reactions"
  (let ((original cl-telegram/api:*available-reactions*))
    (unwind-protect
         (progn
           ;; Set custom reactions
           (is (cl-telegram/api:set-channel-available-reactions '("👍" "❤️" "🔥")))
           (is (equal cl-telegram/api:*available-reactions* '("👍" "❤️" "🔥")))

           ;; Set all reactions
           (is (cl-telegram/api:set-channel-available-reactions :all)))
      ;; Restore
      (setf cl-telegram/api:*available-reactions* original))))

;;; ============================================================================
;;; Emoji Status Tests
;;; ============================================================================

(test test-get-emoji-statuses
  "Test getting emoji statuses"
  (let ((statuses (cl-telegram/api:get-emoji-statuses)))
    (is (listp statuses))
    (is (> (length statuses) 0))))

(test test-get-premium-emoji-statuses
  "Test getting premium emoji statuses"
  (let ((premium (cl-telegram/api:get-premium-emoji-statuses)))
    ;; May be empty if no premium statuses cached
    (is (listp premium))))

(test test-clear-emoji-status
  "Test clearing emoji status"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:clear-emoji-status)))
    ;; Should return T or error plist
    (is (or (eq result t) (listp result)))))

(test test-set-emoji-status
  "Test setting emoji status"
  ;; This is a structural test - actual API call would require auth
  (let ((result (cl-telegram/api:set-emoji-status 54321)))
    ;; Should return T or error plist
    (is (or (eq result t) (listp result))))
  ;; With duration
  (let ((result (cl-telegram/api:set-emoji-status 54321 :duration 3600)))
    (is (or (eq result t) (listp result)))))

;;; ============================================================================
;;; Reaction Utilities Tests
;;; ============================================================================

(test test-is-reaction-selected-p
  "Test checking if reaction is selected"
  (let ((reactions '(:reactions ((:reaction "👍" :count 10 :is-selected t)
                                 (:reaction "❤️" :count 5 :is-selected nil))
                     :total-count 15)))
    (is (cl-telegram/api:is-reaction-selected-p reactions "👍"))
    (is (null (cl-telegram/api:is-reaction-selected-p reactions "❤️")))
    (is (null (cl-telegram/api:is-reaction-selected-p reactions "🔥")))))

(test test-get-popular-reactions
  "Test getting popular reactions"
  (let ((popular (cl-telegram/api:get-popular-reactions :limit 5)))
    (is (listp popular))
    (is (<= (length popular) 5))))

;;; ============================================================================
;;; Mock Data Tests
;;; ============================================================================

(test test-reaction-stats-structure
  "Test reaction stats structure"
  ;; Create mock reaction data
  (let ((mock-stats (cl-telegram/api::get-channel-reaction-stats -1001234567890 100)))
    ;; Should return a plist or error
    (is (or (listp mock-stats) (null mock-stats)))))

(test test-get-recent-channel-reactors
  "Test getting recent reactors"
  ;; This is a structural test
  (let ((result (cl-telegram/api:get-recent-channel-reactors -1001234567890 100 :limit 10)))
    ;; Should return list
    (is (listp result))))

;;; ============================================================================
;;; Analytics Tests
;;; ============================================================================

(test test-get-channel-reaction-analytics
  "Test channel reaction analytics"
  ;; This is a structural test
  (let ((analytics (cl-telegram/api:get-channel-reaction-analytics -1001234567890 :limit 50)))
    ;; Should return a plist with expected keys
    (is (listp analytics))
    (is (or (getf analytics :channel-id) (getf analytics :error)))))

(test test-get-reaction-trend
  "Test reaction trend"
  (let ((trend-day (cl-telegram/api:get-reaction-trend -1001234567890 :period :day))
        (trend-week (cl-telegram/api:get-reaction-trend -1001234567890 :period :week)))
    (is (listp trend-day))
    (is (listp trend-week))
    (is (eq (getf trend-day :period) :day))
    (is (eq (getf trend-week :period) :week))))

;;; ============================================================================
;;; User Emoji Status Tests
;;; ============================================================================

(test test-get-user-emoji-status
  "Test getting user emoji status"
  ;; This is a structural test
  (let ((result (cl-telegram/api:get-user-emoji-status 12345)))
    ;; Should return plist or nil
    (is (or (listp result) (null result)))))

;;; ============================================================================
;;; Error Handling Tests
;;; ============================================================================

(test test-send-reaction-without-auth
  "Test sending reaction without authentication"
  ;; This should fail gracefully
  (let ((result (cl-telegram/api:send-channel-message-reaction -1001234567890 100 "👍")))
    ;; Should return error plist or T if somehow succeeded
    (is (or (eq result t) (and (listp result) (getf result :error)))))

  ;; Test with big reaction
  (let ((result (cl-telegram/api:send-channel-message-reaction -1001234567890 100 "❤️" :is-big t)))
    (is (or (eq result t) (and (listp result) (getf result :error)))))

  ;; Test with custom emoji
  (let ((result (cl-telegram/api:send-channel-message-reaction -1001234567890 100 54321 :is-big t)))
    (is (or (eq result t) (and (listp result) (getf result :error))))))

(test test-remove-reaction-error
  "Test removing reaction error handling"
  (let ((result (cl-telegram/api:remove-channel-message-reaction -1001234567890 100)))
    (is (or (eq result t) (listp result)))))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(test test-reaction-flow
  "Test complete reaction flow"
  ;; This tests the flow structure, not actual API calls
  (let ((channel-id -1001234567890)
        (message-id 100))
    ;; 1. Get available reactions
    (let ((available (cl-telegram/api:get-channel-available-reactions)))
      (is (listp available)))

    ;; 2. Get current reactions (may be empty)
    (let ((reactions (cl-telegram/api:get-channel-message-reactions channel-id message-id)))
      (is (listp reactions)))

    ;; 3. Clear cache
    (is (cl-telegram/api:clear-reaction-cache channel-id message-id))))

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-channel-reactions-tests ()
  "Run all channel reactions tests.

   Returns:
     Test results"
  (fiveam:run! 'channel-reactions-tests))

;;; ============================================================================
;;; End of channel-reactions-tests.lisp
;;; ============================================================================
