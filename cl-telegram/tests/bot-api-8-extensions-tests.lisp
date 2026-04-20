;;; bot-api-8-extensions-tests.lisp --- Tests for Bot API 8.1-8.3 extensions

(defpackage #:cl-telegram/tests/bot-api-8-extensions
  (:use #:cl #:fiveam #:cl-telegram/api)
  (:export #:run-bot-api-8-extensions-tests))

(in-package #:cl-telegram/tests/bot-api-8-extensions)

;; ============================================================================
;; Verification Features Tests (Bot API 8.2)
;; ============================================================================

(def-suite* bot-api-8-extensions-tests
  :description "Tests for Bot API 8.1-8.3 extension features")

(def-suite* verification-tests
  :description "Tests for verification features (Bot API 8.2)"
  :in bot-api-8-extensions-tests)

(test verification-result-class
  "Test verification-result class creation and accessors"
  (let ((result (make-instance 'verification-result
                               :success t
                               :description "Official account"
                               :verification-id "v123"
                               :verification-date 1234567890
                               :verified-by 100)))
    (is-true (verification-success result))
    (is-equal "Official account" (verification-description result))
    (is-equal "v123" (verification-id result))
    (is-equal 1234567890 (verification-date result))
    (is-equal 100 (verification-verified-by result))))

(test verify-user-function
  "Test verify-user function"
  ;; Note: This test requires actual connection and permissions
  ;; In production, this would be an integration test
  (is-true (fboundp 'verify-user))
  (is-true (fboundp 'verify-chat)))

(test verify-chat-function
  "Test verify-chat function"
  (is-true (fboundp 'verify-chat)))

(test remove-verification-functions
  "Test remove verification functions"
  (is-true (fboundp 'remove-user-verification))
  (is-true (fboundp 'remove-chat-verification)))

;; ============================================================================
;; Gift Features Tests (Bot API 8.3)
;; ============================================================================

(def-suite* gift-tests
  :description "Tests for gift features (Bot API 8.3)"
  :in bot-api-8-extensions-tests)

(test gift-class
  "Test gift class creation and accessors"
  (let ((gift (make-instance 'gift
                             :id "gift_1"
                             :name "Test Gift"
                             :description "A test gift"
                             :upgrade-star-count 100
                             :total-count 1000
                             :owner-count 50
                             :icon "file_id_123"
                             :is-limited nil
                             :is-exclusive t)))
    (is-equal "gift_1" (gift-id gift))
    (is-equal "Test Gift" (gift-name gift))
    (is-equal "A test gift" (gift-description gift))
    (is-equal 100 (gift-upgrade-star-count gift))
    (is-equal 1000 (gift-total-count gift))
    (is-equal 50 (gift-owner-count gift))
    (is-equal "file_id_123" (gift-icon gift))
    (is-false (gift-is-limited gift))
    (is-true (gift-is-exclusive gift))))

(test gifts-class
  "Test gifts class"
  (let* ((gift1 (make-instance 'gift :id "g1" :name "Gift 1"))
         (gift2 (make-instance 'gift :id "g2" :name "Gift 2"))
         (gifts (make-instance 'gifts
                               :gifts (list gift1 gift2)
                               :total-count 2)))
    (is-equal 2 (length (gifts-list gifts)))
    (is-equal 2 (gifts-total-count gifts))
    (is-equal "g1" (gift-id (first (gifts-list gifts))))))

(test transaction-partner-chat-class
  "Test transaction-partner-chat class"
  (let ((transaction (make-instance 'transaction-partner-chat
                                    :chat (make-instance 'chat :id -1001234567890)
                                    :amount 500
                                    :transaction-id "tx123"
                                    :date 1234567890)))
    (is-true (transaction-partner-chat-chat transaction))
    (is-equal 500 (transaction-partner-chat-amount transaction))
    (is-equal "tx123" (transaction-partner-chat-transaction-id transaction))
    (is-equal 1234567890 (transaction-partner-chat-date transaction))))

(test get-available-gifts-function
  "Test get-available-gifts function"
  (is-true (fboundp 'get-available-gifts))
  (is-true (fboundp 'clear-gifts-cache)))

(test send-gift-function
  "Test send-gift function"
  (is-true (fboundp 'send-gift))
  ;; Test function signature
  (is-true (function-lambda-list 'send-gift)))

(test gift-cache-variables
  "Test gift cache variables"
  (is-true (boundp '*available-gifts-cache*))
  (is-true (boundp '*gifts-cache-ttl*))
  (is-true (boundp '*gifts-last-fetch*)))

;; ============================================================================
;; Video Enhancements Tests (Bot API 8.3)
;; ============================================================================

(def-suite* video-enhancements-tests
  :description "Tests for video enhancements (Bot API 8.3)"
  :in bot-api-8-extensions-tests)

(test video-cover-class
  "Test video-cover class"
  (let ((cover (make-instance 'video-cover
                              :media-id "media123"
                              :media-type :photo
                              :timestamp 30
                              :file-id "file456")))
    (is-equal "media123" (video-cover-media-id cover))
    (is-equal :photo (video-cover-media-type cover))
    (is-equal 30 (video-cover-timestamp cover))
    (is-equal "file456" (video-cover-file-id cover))))

(test send-video-enhanced
  "Test enhanced send-video function"
  (is-true (fboundp 'send-video))
  ;; Check that send-video accepts new parameters
  (let ((lambda-list (function-lambda-list 'send-video)))
    (is-true (find 'cover lambda-list :key #'car))
    (is-true (find 'start-timestamp lambda-list :key #'car))))

(test forward-message-with-timestamp
  "Test forward-message-with-timestamp function"
  (is-true (fboundp 'forward-message-with-timestamp))
  (is-true (find 'video-start-timestamp
                 (function-lambda-list 'forward-message-with-timestamp)
                 :key #'car)))

(test copy-message-with-timestamp
  "Test copy-message-with-timestamp function"
  (is-true (fboundp 'copy-message-with-timestamp)))

;; ============================================================================
;; Business Features Tests (Bot API 8.1)
;; ============================================================================

(def-suite* business-features-tests
  :description "Tests for business features (Bot API 8.1)"
  :in bot-api-8-extensions-tests)

(test business-connection-class
  "Test business-connection class"
  (let ((conn (make-instance 'business-connection
                             :id "bc123"
                             :user (make-instance 'user :id 100)
                             :user-chat-id 100
                             :user-username "testuser"
                             :date 1234567890
                             :can-reply t
                             :is-enabled t
                             :has-main-username nil)))
    (is-equal "bc123" (business-connection-id conn))
    (is-equal 100 (business-connection-user-chat-id conn))
    (is-equal "testuser" (business-connection-user-username conn))
    (is-true (business-connection-can-reply conn))
    (is-true (business-connection-is-enabled conn))))

(test business-intro-class
  "Test business-intro class"
  (let ((intro (make-instance 'business-intro
                              :title "My Business"
                              :message "Welcome to our store!"
                              :sticker-id "sticker123")))
    (is-equal "My Business" (business-intro-title intro))
    (is-equal "Welcome to our store!" (business-intro-message intro))
    (is-equal "sticker123" (business-intro-sticker-id intro))))

(test business-location-class
  "Test business-location class"
  (let ((loc (make-instance 'business-location
                            :address "123 Main St"
                            :latitude 51.5074
                            :longitude -0.1278
                            :name "London Office")))
    (is-equal "123 Main St" (business-location-address loc))
    (is-equal 51.5074 (business-location-latitude loc))
    (is-equal -0.1278 (business-location-longitude loc))
    (is-equal "London Office" (business-location-name loc))))

(test business-opening-hours-class
  "Test business-opening-hours class"
  (let* ((interval1 (make-instance 'business-opening-hours-interval
                                   :start-minute 540  ; 9:00 AM
                                   :end-minute 1020)) ; 5:00 PM
         (hours (make-instance 'business-opening-hours
                               :schedule "Mon-Fri"
                               :timezone "UTC"
                               :intervals (list interval1))))
    (is-equal "Mon-Fri" (business-opening-hours-schedule hours))
    (is-equal "UTC" (business-opening-hours-timezone hours))
    (is-equal 1 (length (business-opening-hours-intervals hours)))
    (is-equal 540 (business-interval-start-minute (first (business-opening-hours-intervals hours))))))

(test business-api-functions
  "Test business API functions"
  (is-true (fboundp 'get-business-connection))
  (is-true (fboundp 'get-business-intro))
  (is-true (fboundp 'get-business-location))
  (is-true (fboundp 'get-business-opening-hours))
  (is-true (fboundp 'clear-business-connection-cache))
  (is-true (fboundp 'business-connection-cached-p)))

(test business-connection-cache
  "Test business connection cache"
  (is-true (boundp '*business-connections-cache*))
  (is-type 'hash-table (symbol-value '*business-connections-cache*)))

;; ============================================================================
;; Service Message Reactions Tests (Bot API 8.3)
;; ============================================================================

(def-suite* service-message-reactions-tests
  :description "Tests for service message reactions (Bot API 8.3)"
  :in bot-api-8-extensions-tests)

(test send-service-message-reaction
  "Test send-service-message-reaction function"
  (is-true (fboundp 'send-service-message-reaction))
  ;; Should accept same parameters as send-message-reaction
  (is-true (find 'is-big
                 (function-lambda-list 'send-service-message-reaction)
                 :key #'car)))

;; ============================================================================
;; Integration Tests
;; ============================================================================

(def-suite* bot-api-8-integration-tests
  :description "Integration tests for Bot API 8.1-8.3"
  :in bot-api-8-extensions-tests)

(test cache-management
  "Test cache management functions"
  ;; Business connection cache
  (setf (gethash "test_bc" *business-connections-cache*)
        (make-instance 'business-connection
                       :id "test_bc"
                       :user nil
                       :user-chat-id 100
                       :date 0
                       :can-reply nil
                       :is-enabled nil
                       :has-main-username nil))
  (is-true (business-connection-cached-p "test_bc"))
  (clear-business-connection-cache)
  (is-false (business-connection-cached-p "test_bc"))

  ;; Gifts cache
  (setf *available-gifts-cache* (make-instance 'gifts))
  (setf *gifts-last-fetch* (get-universal-time))
  (is-true *available-gifts-cache*)
  (clear-gifts-cache)
  (is-null *available-gifts-cache*))

(defun run-bot-api-8-extensions-tests ()
  "Run all Bot API 8.1-8.3 extension tests"
  (run! 'bot-api-8-extensions-tests))
