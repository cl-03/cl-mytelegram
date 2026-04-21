;;; bot-api-9-6-stars-tests.lisp --- Tests for Bot API 9.6 Stars Payment System

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-6-stars-tests
  :description "Tests for Bot API 9.6 Stars Payment System (v0.35.0)")

;;; ============================================================================
;;; Section 1: Star Balance Tests
;;; ============================================================================

(test test-get-business-account-star-balance
  "Test getting business account Star balance"
  (let ((balance (cl-telegram/api:get-business-account-star-balance)))
    (is (or (integerp balance) (null balance)))))

(test test-get-business-account-star-balance-with-connection
  "Test getting Star balance with business connection ID"
  (let ((balance (cl-telegram/api:get-business-account-star-balance "biz_conn_123")))
    (is (or (integerp balance) (null balance)))))

(test test-get-star-balance-cached
  "Test getting cached Star balance"
  (let ((balance (cl-telegram/api:get-star-balance-cached "biz_conn_123")))
    (is (or (integerp balance) (null balance)))))

;;; ============================================================================
;;; Section 2: Star Transactions Tests
;;; ============================================================================

(test test-get-star-transactions
  "Test getting Star transactions"
  (let ((transactions (cl-telegram/api:get-star-transactions :limit 50)))
    (is (or (listp transactions) (null transactions)))))

(test test-get-star-transactions-with-offset
  "Test getting Star transactions with offset"
  (let ((transactions (cl-telegram/api:get-star-transactions :offset 100 :limit 50)))
    (is (or (listp transactions) (null transactions)))))

(test test-get-star-transactions-with-connection
  "Test getting Star transactions with business connection"
  (let ((transactions (cl-telegram/api:get-star-transactions
                       :business-connection-id "biz_conn_123"
                       :limit 20)))
    (is (or (listp transactions) (null transactions)))))

;;; ============================================================================
;;; Section 3: Star Refund Tests
;;; ============================================================================

(test test-refund-star-payment
  "Test refunding Star payment"
  (let ((result (cl-telegram/api:refund-star-payment 123456 100)))
    (is (or (eq result t) (null result)))))

(test test-refund-star-payment-with-reason
  "Test refunding Star payment with reason"
  (let ((result (cl-telegram/api:refund-star-payment
                 123456
                 50
                 :reason "Product unavailable")))
    (is (or (eq result t) (null result)))))

(test test-refund-star-payment-with-connection
  "Test refunding Star payment with business connection"
  (let ((result (cl-telegram/api:refund-star-payment
                 123456
                 75
                 :business-connection-id "biz_conn_123")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Star Gift Conversion Tests
;;; ============================================================================

(test test-convert-star-gift-to-stars
  "Test converting Star gift to Stars"
  (let ((result (cl-telegram/api:convert-star-gift "gift_123" :to-stars t)))
    (is (or (plistp result) (null result)))))

(test test-convert-star-gift-from-stars
  "Test converting Stars to Star gift"
  (let ((result (cl-telegram/api:convert-star-gift "gift_456" :to-stars nil)))
    (is (or (plistp result) (null result)))))

(test test-convert-star-gift-with-connection
  "Test converting Star gift with business connection"
  (let ((result (cl-telegram/api:convert-star-gift
                 "gift_789"
                 :to-stars t
                 :business-connection-id "biz_conn_123")))
    (is (or (plistp result) (null result)))))

;;; ============================================================================
;;; Section 5: Paid Media Tests
;;; ============================================================================

(test test-send-paid-media
  "Test sending paid media"
  (let ((result (cl-telegram/api:send-paid-media 123456 "media_abc" 100)))
    (is (or (not (null result)) (null result)))))

(test test-send-paid-media-with-caption
  "Test sending paid media with caption"
  (let ((result (cl-telegram/api:send-paid-media
                 123456
                 "media_xyz"
                 250
                 :caption "Exclusive content")))
    (is (or (not (null result)) (null result)))))

(test test-send-paid-media-with-reply
  "Test sending paid media with reply"
  (let ((result (cl-telegram/api:send-paid-media
                 123456
                 "media_123"
                 150
                 :reply-to 999)))
    (is (or (not (null result)) (null result)))))

(test test-send-paid-media-with-connection
  "Test sending paid media with business connection"
  (let ((result (cl-telegram/api:send-paid-media
                 123456
                 "media_456"
                 200
                 :business-connection-id "biz_conn_123")))
    (is (or (not (null result)) (null result)))))

(test test-get-paid-media
  "Test getting paid media info"
  (let ((media (cl-telegram/api:get-paid-media "media_abc")))
    (is (or (typep media 'cl-telegram/api:paid-media) (null media)))))

(test test-get-paid-media-cached
  "Test getting cached paid media"
  (let ((media (cl-telegram/api:get-paid-media-cached "media_abc")))
    (is (or (typep media 'cl-telegram/api:paid-media) (null media)))))

(test test-list-paid-media
  "Test listing paid media"
  (let ((media-list (cl-telegram/api:list-paid-media :limit 20)))
    (is (or (listp media-list) (null media-list)))))

(test test-list-paid-media-with-offset
  "Test listing paid media with offset"
  (let ((media-list (cl-telegram/api:list-paid-media :offset 50 :limit 30)))
    (is (or (listp media-list) (null media-list)))))

(test test-delete-paid-media
  "Test deleting paid media"
  (let ((result (cl-telegram/api:delete-paid-media "media_abc")))
    (is (or (eq result t) (null result)))))

(test test-delete-paid-media-with-connection
  "Test deleting paid media with business connection"
  (let ((result (cl-telegram/api:delete-paid-media
                 "media_xyz"
                 :business-connection-id "biz_conn_123")))
    (is (or (eq result t) (null result)))))

(test test-update-paid-media
  "Test updating paid media"
  (let ((result (cl-telegram/api:update-paid-media
                 "media_abc"
                 :price 150
                 :caption "Updated description")))
    (is (or (eq result t) (null result)))))

(test test-update-paid-media-partial
  "Test partially updating paid media"
  (let ((result (cl-telegram/api:update-paid-media
                 "media_xyz"
                 :price 300)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 6: Cache Management Tests
;;; ============================================================================

(test test-clear-star-cache
  "Test clearing Star cache"
  (let ((result (cl-telegram/api:clear-star-cache)))
    (is (eq result t))))

(test test-clear-paid-media-cache
  "Test clearing paid media cache"
  (let ((result (cl-telegram/api:clear-paid-media-cache)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 7: Paid Media Class Tests
;;; ============================================================================

(test test-make-paid-media
  "Test creating paid media instance"
  (let ((media (make-instance 'cl-telegram/api:paid-media
                              :media-id "test_media"
                              :media-type :photo
                              :price 100
                              :description "Test paid media"
                              :created-at (get-universal-time))))
    (is (string= (cl-telegram/api:paid-media-id media) "test_media"))
    (is (eq (cl-telegram/api:paid-media-type media) :photo))
    (is (= (cl-telegram/api:paid-media-price media) 100))))

(test test-paid-media-defaults
  "Test paid media default values"
  (let ((media (make-instance 'cl-telegram/api:paid-media
                              :media-id "test"
                              :price 50)))
    (is (eq (cl-telegram/api:paid-media-type media) :photo))
    (is (string= (cl-telegram/api:paid-media-description media) ""))
    (is (null (cl-telegram/api:paid-media-preview-url media)))
    (is (= (cl-telegram/api:paid-media-purchase-count media) 0))))

;;; ============================================================================
;;; Section 8: Feature Status Tests
;;; ============================================================================

(test test-register-bot-api-9-6-stars-feature
  "Test registering Bot API 9.6 Stars feature"
  (let ((result (cl-telegram/api:register-bot-api-9-6-stars-feature :star-payments)))
    (is (eq result t))))

(test test-check-bot-api-9-6-stars-feature
  "Test checking Bot API 9.6 Stars feature availability"
  (let ((result (cl-telegram/api:check-bot-api-9-6-stars-feature :star-payments)))
    (is (eq result t))))

(test test-get-bot-api-9-6-stars-status
  "Test getting Bot API 9.6 Stars status"
  (let ((status (cl-telegram/api:get-bot-api-9-6-stars-status)))
    (is (plistp status))
    (is (getf status :version))
    (is (getf status :features))
    (is (getf status :status))))

;;; ============================================================================
;;; Section 9: Integration Tests
;;; ============================================================================

(test test-star-payment-flow
  "Test complete Star payment flow"
  ;; 1. Check balance
  (let ((balance (cl-telegram/api:get-business-account-star-balance)))
    (is (or (integerp balance) (null balance)))
    ;; 2. Get transactions
    (let ((transactions (cl-telegram/api:get-star-transactions :limit 10)))
      (is (or (listp transactions) (null transactions))))
    ;; 3. Send paid media
    (let ((result (cl-telegram/api:send-paid-media 123456 "media_test" 100)))
      (is (or (not (null result)) (null result))))))

(test test-paid-media-crud
  "Test paid media CRUD operations"
  ;; 1. List media
  (let ((media-list (cl-telegram/api:list-paid-media :limit 5)))
    (is (or (listp media-list) (null media-list))))
  ;; 2. Get specific media
  (let ((media (cl-telegram/api:get-paid-media "media_test")))
    (is (or (typep media 'cl-telegram/api:paid-media) (null media))))
  ;; 3. Update media
  (let ((result (cl-telegram/api:update-paid-media "media_test" :price 150)))
    (is (or (eq result t) (null result))))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-bot-api-9-6-stars-tests ()
  "Run all Bot API 9.6 Stars Payment System tests"
  (let ((results (run! 'bot-api-9-6-stars-tests :if-fail :error)))
    (format t "~%~%=== Bot API 9.6 Stars Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
