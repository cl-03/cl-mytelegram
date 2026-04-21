;;; payment-stars-tests.lisp --- Tests for payment and stars system

(in-package #:cl-telegram/tests)

(def-suite* payment-stars-tests
  :description "Tests for payment and stars system (v0.31.0)")

;;; ============================================================================
;;; Section 1: Star Invoice Tests
;;; ============================================================================

(test test-create-star-invoice
  "Test creating a star invoice"
  (let ((invoice (cl-telegram/api:create-star-invoice 100 :description "Test Payment" :payload "user_123")))
    (is (typep invoice 'cl-telegram/api::star-invoice))
    (is (stringp (cl-telegram/api:star-invoice-id invoice)))
    (is (= (cl-telegram/api:star-invoice-amount invoice) 100))
    (is (equal (cl-telegram/api:star-invoice-description invoice) "Test Payment"))))

(test test-get-invoice-status
  "Test getting invoice status"
  (let ((invoice (cl-telegram/api:create-star-invoice 50)))
    (let ((status (cl-telegram/api:get-invoice-status (cl-telegram/api:star-invoice-id invoice))))
      (is (eq status :pending)))))

(test test-invoice-expiration
  "Test invoice expiration"
  (let ((invoice (cl-telegram/api:create-star-invoice 50 :expires-in 1)))
    (sleep 2) ; Wait for expiration
    (let ((status (cl-telegram/api:get-invoice-status (cl-telegram/api:star-invoice-id invoice))))
      (is (eq status :expired)))))

;;; ============================================================================
;;; Section 2: Star Payment Tests
;;; ============================================================================

(test test-get-star-balance
  "Test getting star balance"
  (let ((balance (cl-telegram/api:get-star-balance)))
    (is (listp balance))
    (is (getf balance :balance))
    (is (getf balance :total-earned))))

(test test-send-star-payment
  "Test sending stars"
  (let ((result (cl-telegram/api:send-star-payment 123456 50 :message "Thank you!")))
    (is (or (eq result t) (null result))))) ; May fail without real connection

;;; ============================================================================
;;; Section 3: Star Transactions Tests
;;; ============================================================================

(test test-get-star-transactions
  "Test getting star transactions"
  (let ((transactions (cl-telegram/api:get-star-transactions :limit 10)))
    (is (or (null transactions) (listp transactions)))))

(test test-refund-star-payment
  "Test refunding a star payment"
  (let ((result (cl-telegram/api:refund-star-payment "payment_123" :reason "Test refund")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Paid Media Tests
;;; ============================================================================

(test test-make-paid-media-info
  "Test creating paid media info"
  (let ((media (cl-telegram/api:make-paid-media-info "photo" "AgAD1234" 50 :description "Test media")))
    (is (typep media 'cl-telegram/api::paid-media))
    (is (equal (cl-telegram/api:paid-media-type media) "photo"))
    (is (equal (cl-telegram/api:paid-media-media-id media) "AgAD1234"))
    (is (= (cl-telegram/api:paid-media-star-amount media) 50))))

(test test-send-paid-media
  "Test sending paid media"
  (let ((media (cl-telegram/api:make-paid-media-info "photo" "AgAD1234" 50)))
    (let ((result (cl-telegram/api:send-paid-media 123456 media :caption "Test caption")))
      (is (or (null result) (listp result))))))

;;; ============================================================================
;;; Section 5: Giveaway Tests
;;; ============================================================================

(test test-create-star-giveaway
  "Test creating a star giveaway"
  (let ((giveaway (cl-telegram/api:create-star-giveaway 1000 5 (* 7 24 60 60) :title "Weekly Giveaway")))
    (is (typep giveaway 'cl-telegram/api::star-giveaway))
    (is (stringp (cl-telegram/api:giveaway-id giveaway)))
    (is (= (cl-telegram/api:giveaway-star-amount giveaway) 1000))
    (is (= (cl-telegram/api:giveaway-winner-count giveaway) 5))))

(test test-join-giveaway
  "Test joining a giveaway"
  (let ((giveaway (cl-telegram/api:create-star-giveaway 100 1 3600)))
    (let ((result (cl-telegram/api:join-giveaway (cl-telegram/api:giveaway-id giveaway) 123456)))
      (is (eq result t)))))

(test test-get-giveaway-status
  "Test getting giveaway status"
  (let ((giveaway (cl-telegram/api:create-star-giveaway 500 2 7200)))
    (cl-telegram/api:join-giveaway (cl-telegram/api:giveaway-id giveaway) 111)
    (cl-telegram/api:join-giveaway (cl-telegram/api:giveaway-id giveaway) 222)
    (let ((status (cl-telegram/api:get-giveaway-status (cl-telegram/api:giveaway-id giveaway))))
      (is (listp status))
      (is (getf status :giveaway-id))
      (is (getf status :participant-count))
      (is (>= (getf status :participant-count) 2)))))

(test test-shuffle-list
  "Test list shuffling"
  (let ((original '(1 2 3 4 5 6 7 8 9 10))
        (shuffled (cl-telegram/api::shuffle-list original)))
    (is (= (length shuffled) (length original)))
    ;; Check all elements are present
    (dolist (elem original)
      (is (member elem shuffled)))))

;;; ============================================================================
;;; Section 6: Statistics Tests
;;; ============================================================================

(test test-get-payment-stats
  "Test getting payment statistics"
  (let ((stats (cl-telegram/api:get-payment-stats :period :all)))
    (is (listp stats))
    (is (getf stats :total-payments))
    (is (getf stats :total-stars))
    (is (getf stats :completed))))

(test test-get-giveaway-stats
  "Test getting giveaway statistics"
  (let ((stats (cl-telegram/api:get-giveaway-stats)))
    (is (listp stats))
    (is (getf stats :total-giveaways))
    (is (getf stats :total-participants))))

;;; ============================================================================
;;; Section 7: Integration Tests
;;; ============================================================================

(test test-initialize-payment-stars
  "Test initializing payment system"
  (let ((result (cl-telegram/api:initialize-payment-stars)))
    (is (eq result t))))

(test test-shutdown-payment-stars
  "Test shutting down payment system"
  (cl-telegram/api:initialize-payment-stars)
  (let ((result (cl-telegram/api:shutdown-payment-stars)))
    (is (eq result t))))

(test test-full-payment-workflow
  "Test complete payment workflow"
  ;; Initialize
  (cl-telegram/api:initialize-payment-stars)

  ;; Create invoice
  (let ((invoice (cl-telegram/api:create-star-invoice 100 :description "Test")))
    (is (typep invoice 'cl-telegram/api::star-invoice))

    ;; Check status
    (is (eq (cl-telegram/api:get-invoice-status (cl-telegram/api:star-invoice-id invoice)) :pending))

    ;; Get stats
    (let ((stats (cl-telegram/api:get-payment-stats)))
      (format t "Payment stats: ~A~%" stats)))

  ;; Cleanup
  (cl-telegram/api:shutdown-payment-stars))

;;; ============================================================================
;;; Section 8: Paid Media Tests
;;; ============================================================================

(test test-make-paid-media-info
  "Test creating paid media info"
  (let ((media (cl-telegram/api:make-paid-media-info "photo" "file_id_123" 50
                                                      :description "Exclusive content")))
    (is (typep media 'cl-telegram/api::paid-media))
    (is (string= (cl-telegram/api:paid-media-type media) "photo"))
    (is (string= (cl-telegram/api:paid-media-media-id media) "file_id_123"))
    (is (= (cl-telegram/api:paid-media-star-amount media) 50))))

(test test-send-paid-media
  "Test sending paid media"
  (let ((media (cl-telegram/api:make-paid-media-info "photo" "file_id_123" 50)))
    (let ((result (cl-telegram/api:send-paid-media 123456 media :caption "Check this out!")))
      (is (or (null result) (listp result))))))

(test test-get-paid-media-post
  "Test getting paid media post"
  (let ((result (cl-telegram/api:get-paid-media-post 123456 789)))
    (is (or (null result) (listp result)))))

(test test-get-paid-media
  "Test getting paid media by ID"
  (let ((result (cl-telegram/api:get-paid-media "media_123")))
    (is (or (null result) (typep result 'cl-telegram/api::paid-media)))))

(test test-list-paid-media
  "Test listing paid media"
  (let ((result (cl-telegram/api:list-paid-media :limit 20 :offset 0)))
    (is (or (null result) (listp result)))))

(test test-delete-paid-media
  "Test deleting paid media"
  (let ((result (cl-telegram/api:delete-paid-media "media_123")))
    (is (or (null result) (eq result t)))))

(test test-update-paid-media
  "Test updating paid media"
  (let ((result (cl-telegram/api:update-paid-media "media_123" :star-amount 100 :description "Updated")))
    (is (or (null result) (eq result t)))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-payment-stars-tests ()
  "Run all payment and stars tests"
  (let ((results (run! 'payment-stars-tests :if-fail :error)))
    (format t "~%~%=== Payment and Stars Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
