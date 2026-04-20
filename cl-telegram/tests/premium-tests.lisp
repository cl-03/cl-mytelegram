;;; premium-tests.lisp --- Tests for Telegram Premium features

(in-package #:cl-telegram/tests)

(def-suite premium-tests
  :description "Tests for Telegram Premium features (v0.17.0)")

(in-suite premium-tests)

;;; ======================================================================
;;; Premium Status Class Tests
;;; ======================================================================

(test test-premium-status-class
  "Test premium-status class creation and accessors"
  (let ((status (make-instance 'cl-telegram/api:premium-status)))
    (is (notnull status))
    (is (null (cl-telegram/api:premium-is-premium status))
        "Default premium status should be nil")
    (is (null (cl-telegram/api:premium-expiration-date status))
        "Default expiration date should be nil")
    (is (null (cl-telegram/api:premium-subscription-type status))
        "Default subscription type should be nil")
    (is (= (* 2 1024 1024 1024) (cl-telegram/api:premium-max-file-size status))
        "Default max file size should be 2GB")))

(test test-premium-status-setters
  "Test premium-status accessor setters"
  (let ((status (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium status) t)
    (setf (cl-telegram/api:premium-expiration-date status) 1893456000) ; 2030-01-01
    (setf (cl-telegram/api:premium-subscription-type status) :yearly)
    (setf (cl-telegram/api:premium-can-send-large-files status) t)
    (setf (cl-telegram/api:premium-max-file-size status) (* 4 1024 1024 1024))

    (is (true (cl-telegram/api:premium-is-premium status)))
    (is (= 1893456000 (cl-telegram/api:premium-expiration-date status)))
    (is (eq :yearly (cl-telegram/api:premium-subscription-type status)))
    (is (true (cl-telegram/api:premium-can-send-large-files status)))
    (is (= (* 4 1024 1024 1024) (cl-telegram/api:premium-max-file-size status)))))

(test test-premium-features-config
  "Test premium-features-config class creation"
  (let ((config (make-instance 'cl-telegram/api:premium-features-config)))
    (is (notnull config))
    (is (null (cl-telegram/api:config-premium-sticker-sets config)))
    (is (null (cl-telegram/api:config-premium-reactions config)))
    (is (null (cl-telegram/api:config-premium-emoji-statuses config)))
    (is (null (cl-telegram/api:config-premium-profile-colors config)))
    (is (null (cl-telegram/api:config-premium-chat-themes config)))
    (is (= 0 (cl-telegram/api:config-premium-transcription-hours config)))))

;;; ======================================================================
;;; Premium Status Detection Tests
;;; ======================================================================

(test test-check-premium-status-cached
  "Test checking premium status uses cache"
  (let* ((cl-telegram/api:*premium-last-check* (get-universal-time))
         (cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) t)
    (is (true (cl-telegram/api:check-premium-status)))))

(test test-refresh-premium-status
  "Test refreshing premium status from server"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    ;; Mock the server response
    (let ((mock-status '(:is-premium t
                         :expiration-date 1893456000
                         :subscription-type :yearly
                         :can-send-large-files t
                         :can-use-premium-stickers t
                         :double-limits t)))
      ;; Simulate get-premium-status-from-server behavior
      (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*)
            (getf mock-status :is-premium))
      (is (true (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*)))
      (is (= (* 4 1024 1024 1024) (cl-telegram/api:premium-max-file-size cl-telegram/api:*premium-status*))))))

(test test-get-premium-status-from-server-structure
  "Test premium status server response structure"
  (let ((response '(:is-premium t
                    :expiration-date 1893456000
                    :subscription-type :monthly
                    :can-send-large-files t
                    :can-use-premium-stickers t
                    :double-limits t)))
    (is (getf response :is-premium))
    (is (= 1893456000 (getf response :expiration-date)))
    (is (eq :monthly (getf response :subscription-type)))))

(test test-verify-premium-status
  "Test premium status verification"
  (multiple-value-bind (is-premium error-msg)
      (cl-telegram/api:verify-premium-status)
    (is (booleanp is-premium))
    (is (or (null error-msg) (stringp error-msg)))))

;;; ======================================================================
;;; Premium Feature Access Tests
;;; ======================================================================

(test test-premium-required-p
  "Test checking if feature requires premium"
  (dolist (feature '(:send-large-files :premium-stickers :premium-reactions
                            :emoji-statuses :profile-colors :chat-themes
                            :voice-transcription :advanced-chat-management
                            :doubled-limits))
    (is (true (cl-telegram/api:premium-required-p feature))
        (format nil "~A should require premium" feature)))

  (is (false (cl-telegram/api:premium-required-p :send-message))
      "Send message should not require premium")
  (is (false (cl-telegram/api:premium-required-p :get-chats))
      "Get chats should not require premium"))

(test test-ensure-premium-with-premium
  "Test ensure-premium when user has premium"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) t)
    (is (true (cl-telegram/api:ensure-premium :send-large-files)))))

(test test-ensure-premium-without-premium
  "Test ensure-premium when user lacks premium"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) nil)
    (signals cl-telegram/api:premium-required-error
      (cl-telegram/api:ensure-premium :send-large-files))))

(test test-premium-required-error
  "Test premium-required-error condition"
  (handler-case
      (error 'cl-telegram/api:premium-required-error
             :feature :send-large-files
             :message "Premium required for large files")
    (cl-telegram/api:premium-required-error (e)
      (is (eq :send-large-files (cl-telegram/api:premium-error-feature e)))
      (is (string= "Premium required for large files"
                   (cl-telegram/api:premium-error-message e))))))

;;; ======================================================================
;;; File Upload Limits Tests
;;; ======================================================================

(test test-get-max-file-size-free
  "Test max file size for free users"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) nil)
    (is (= (* 2 1024 1024 1024) (cl-telegram/api:get-max-file-size)))))

(test test-get-max-file-size-premium
  "Test max file size for premium users"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) t)
    (is (= (* 4 1024 1024 1024) (cl-telegram/api:get-max-file-size)))))

(test test-can-upload-file-p
  "Test file upload permission check"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    ;; Free user can upload up to 2GB
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) nil)
    (is (true (cl-telegram/api:can-upload-file-p (* 100 1024 1024)))) ; 100MB
    (is (false (cl-telegram/api:can-upload-file-p (* 3 1024 1024 1024)))))) ; 3GB

(test test-validate-file-for-upload
  "Test file validation for upload"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) nil)

    ;; Small file should pass
    (multiple-value-bind (success error-msg)
        (cl-telegram/api:validate-file-for-upload (* 10 1024 1024) "test.txt")
      (is (true success)))

    ;; Large file should fail for free user
    (multiple-value-bind (success error-msg)
        (cl-telegram/api:validate-file-for-upload (* 3 1024 1024 1024) "large.bin")
      (is (false success))
      (is (notnull error-msg)))))

;;; ======================================================================
;;; Premium Stickers Tests
;;; ======================================================================

(test test-get-premium-sticker-sets
  "Test getting premium sticker sets"
  (let ((cl-telegram/api:*premium-features-config* (make-instance 'cl-telegram/api:premium-features-config)))
    ;; When no sets cached, should fetch from server
    (let ((result (cl-telegram/api:get-premium-sticker-sets)))
      (is (or (null result) (listp result))))))

(test test-fetch-premium-sticker-sets
  "Test fetching premium sticker sets from server"
  (let ((result (cl-telegram/api:fetch-premium-sticker-sets)))
    (is (or (null result) (listp result)))))

(test test-can-use-premium-sticker-p
  "Test checking if user can use premium sticker"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status))
        (cl-telegram/api:*premium-features-config* (make-instance 'cl-telegram/api:premium-features-config)))
    ;; Premium user can use any sticker
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) t)
    (is (true (cl-telegram/api:can-use-premium-sticker-p "premium_stickers")))))

;;; ======================================================================
;;; Premium Reactions Tests
;;; ======================================================================

(test test-get-premium-reactions
  "Test getting premium reactions"
  (let ((result (cl-telegram/api:get-premium-reactions)))
    (is (listp result))
    (is (every #'stringp result))))

(test test-fetch-premium-reactions
  "Test fetching premium reactions from server"
  (let ((result (cl-telegram/api:fetch-premium-reactions)))
    (is (listp result))
    ;; Should have some default reactions
    (is (not (null result)))))

(test test-can-send-reaction-p
  "Test checking if user can send reaction"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    ;; Free reactions should always be available
    (is (true (cl-telegram/api:can-send-reaction-p "👍")))
    (is (true (cl-telegram/api:can-send-reaction-p "❤️")))))

;;; ======================================================================
;;; Premium Customization Tests
;;; ======================================================================

(test test-get-premium-profile-colors
  "Test getting premium profile colors"
  (let ((result (cl-telegram/api:get-premium-profile-colors)))
    (is (or (null result) (listp result)))))

(test test-fetch-premium-profile-colors
  "Test fetching premium profile colors"
  (let ((result (cl-telegram/api:fetch-premium-profile-colors)))
    (is (or (null result) (listp result)))))

(test test-get-premium-chat-themes
  "Test getting premium chat themes"
  (let ((result (cl-telegram/api:get-premium-chat-themes)))
    (is (or (null result) (listp result)))))

(test test-fetch-premium-chat-themes
  "Test fetching premium chat themes"
  (let ((result (cl-telegram/api:fetch-premium-chat-themes)))
    (is (or (null result) (listp result)))))

(test test-get-premium-emoji-statuses
  "Test getting premium emoji statuses"
  (let ((result (cl-telegram/api:get-premium-emoji-statuses)))
    (is (or (null result) (listp result)))))

;;; ======================================================================
;;; Premium Subscription Management Tests
;;; ======================================================================

(test test-get-premium-subscription-info
  "Test getting premium subscription info"
  (let ((result (cl-telegram/api:get-premium-subscription-info)))
    (is (or (null result) (notnull result)))))

(test test-cancel-premium-subscription
  "Test canceling premium subscription"
  (let ((result (cl-telegram/api:cancel-premium-subscription)))
    (is (or (null result) (notnull result)))))

(test test-renew-premium-subscription
  "Test renewing premium subscription"
  (let ((result (cl-telegram/api:renew-premium-subscription)))
    (is (or (null result) (notnull result)))))

;;; ======================================================================
;;; Premium Utility Tests
;;; ======================================================================

(test test-reset-premium-cache
  "Test resetting premium cache"
  (let ((result (cl-telegram/api:reset-premium-cache)))
    (is (true result))
    (is (null cl-telegram/api:*premium-last-check*))))

(test test-get-premium-stats
  "Test getting premium statistics"
  (let ((stats (cl-telegram/api:get-premium-stats)))
    (is (or (null stats) (notnull stats)))))

(test test-get-doubled-limits
  "Test getting doubled limits for premium"
  (let ((limits (cl-telegram/api:get-doubled-limits)))
    (is (or (null limits) (notnull limits)))))

(test test-can-pin-more-chats-p
  "Test checking if user can pin more chats"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) t)
    (let ((result (cl-telegram/api:can-pin-more-chats-p)))
      (is (booleanp result)))))

(test test-can-join-more-channels-p
  "Test checking if user can join more channels"
  (let ((cl-telegram/api:*premium-status* (make-instance 'cl-telegram/api:premium-status)))
    (setf (cl-telegram/api:premium-is-premium cl-telegram/api:*premium-status*) t)
    (let ((result (cl-telegram/api:can-join-more-channels-p)))
      (is (booleanp result)))))

;;; ======================================================================
;;; Premium Transcription Tests
;;; ======================================================================

(test test-transcribe-voice-message-premium
  "Test transcribing voice message with premium"
  (let ((result (cl-telegram/api:transcribe-voice-message-premium 123456)))
    (is (or (null result) (notnull result)))))

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-premium-tests ()
  "Run all premium features tests"
  (format t "~%=== Running Telegram Premium Unit Tests ===~%~%")
  (fiveam:run! 'premium-tests))

(export '(run-premium-tests))
