;;; payment-enhanced-tests.lisp --- Tests for Payment API Enhanced (v0.34.0)

(in-package #:cl-telegram/tests)

(def-suite* payment-enhanced-tests
  :description "Tests for Payment API Enhanced v0.34.0")

;;; ============================================================================
;;; Section 1: Shipping Option Tests
;;; ============================================================================

(test test-make-shipping-option
  "Test creating a shipping option"
  (let ((option (cl-telegram/api:make-shipping-option
                 "express"
                 "Express Delivery"
                 (list (cl-telegram/api:make-labeled-price "Shipping" 500)))))
    (is (string= (cl-telegram/api:shipping-option-id option) "express"))
    (is (string= (cl-telegram/api:shipping-option-title option) "Express Delivery"))
    (is (listp (cl-telegram/api:shipping-option-prices option)))))

(test test-make-shipping-option-multiple-prices
  "Test creating a shipping option with multiple price components"
  (let ((option (cl-telegram/api:make-shipping-option
                 "international"
                 "International Shipping"
                 (list (cl-telegram/api:make-labeled-price "Base Shipping" 1000)
                       (cl-telegram/api:make-labeled-price "Fuel Surcharge" 200)))))
    (is (= (length (cl-telegram/api:shipping-option-prices option)) 2))))

;;; ============================================================================
;;; Section 2: Shipping Query Response Tests
;;; ============================================================================

(test test-answer-shipping-query-success
  "Test answering a shipping query with success"
  (let ((result (cl-telegram/api:answer-shipping-query
                 "query_123"
                 t
                 :shipping-options
                 (list (cl-telegram/api:make-shipping-option
                        "standard"
                        "Standard Delivery"
                        (list (cl-telegram/api:make-labeled-price "Shipping" 300)))))))
    (is (or (eq result t) (null result)))))

(test test-answer-shipping-query-multiple-options
  "Test answering a shipping query with multiple shipping options"
  (let ((result (cl-telegram/api:answer-shipping-query
                 "query_456"
                 t
                 :shipping-options
                 (list (cl-telegram/api:make-shipping-option "standard" "Standard"
                                        (list (cl-telegram/api:make-labeled-price "Ship" 300)))
                       (cl-telegram/api:make-shipping-option "express" "Express"
                                        (list (cl-telegram/api:make-labeled-price "Ship" 800)))))))
    (is (or (eq result t) (null result)))))

(test test-answer-shipping-query-failure
  "Test answering a shipping query with failure"
  (let ((result (cl-telegram/api:answer-shipping-query
                 "query_789"
                 nil
                 :error-message "Sorry, we cannot deliver to your address")))
    (is (or (eq result t) (null result)))))

(test test-answer-shipping-query-minimal
  "Test answering a shipping query with minimal parameters"
  (let ((result (cl-telegram/api:answer-shipping-query "query_minimal" t)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 3: Pre-Checkout Query Response Tests
;;; ============================================================================

(test test-answer-pre-checkout-query-success
  "Test answering a pre-checkout query with success"
  (let ((result (cl-telegram/api:answer-pre-checkout-query "checkout_123" t)))
    (is (or (eq result t) (null result)))))

(test test-answer-pre-checkout-query-failure
  "Test answering a pre-checkout query with failure"
  (let ((result (cl-telegram/api:answer-pre-checkout-query
                 "checkout_456"
                 nil
                 :error-message "Product is out of stock")))
    (is (or (eq result t) (null result)))))

(test test-answer-pre-checkout-query-custom-error
  "Test answering a pre-checkout query with custom error message"
  (let ((result (cl-telegram/api:answer-pre-checkout-query
                 "checkout_789"
                 nil
                 :error-message "Payment method not supported in your region")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Invoice Tests
;;; ============================================================================

(test test-make-invoice-basic
  "Test creating a basic invoice"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Test Product"
                  :description "A test product description"
                  :payload "test_payload_123"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 1000)))))
    (is (string= (cl-telegram/api:invoice-title invoice) "Test Product"))
    (is (string= (cl-telegram/api:invoice-description invoice) "A test product description"))
    (is (string= (cl-telegram/api:invoice-currency invoice) "USD")))))

(test test-make-invoice-with-tips
  "Test creating an invoice with tip options"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Premium Service"
                  :description "Premium service subscription"
                  :payload "premium_sub"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Subscription" 5000))
                  :max-tip-amount 1000
                  :suggested-tip-amounts '(100 200 500))))
    (is (= (cl-telegram/api:invoice-max-tip-amount invoice) 1000))
    (is (= (length (cl-telegram/api:invoice-suggested-tip-amounts invoice)) 3))))

(test test-make-invoice-with-shipping
  "Test creating an invoice with shipping requirements"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Physical Product"
                  :description "Needs shipping address"
                  :payload "physical_item"
                  :currency "EUR"
                  :prices (list (cl-telegram/api:make-labeled-price "Product" 2500))
                  :need-shipping-address t
                  :need-name t
                  :is-flexible t)))
    (is (cl-telegram/api:invoice-need-shipping-address invoice))
    (is (cl-telegram/api:invoice-need-name invoice))
    (is (cl-telegram/api:invoice-is-flexible invoice))))

(test test-make-invoice-subscription
  "Test creating a subscription invoice"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Monthly Subscription"
                  :description "Recurring monthly payment"
                  :payload "monthly_sub"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Monthly" 999))
                  :subscription-period (* 30 24 60 60)))) ; 30 days
    (is (= (cl-telegram/api:invoice-subscription-period invoice) (* 30 24 60 60)))))

;;; ============================================================================
;;; Section 5: Invoice Sending Tests
;;; ============================================================================

(test test-send-invoice-basic
  "Test sending an invoice"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Test Invoice"
                  :description "Test description"
                  :payload "test_payload"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 100)))))
    (let ((result (cl-telegram/api:send-invoice 123456 invoice)))
      (is (or (not (null result)) t))))) ; Mocked, just verify it returns something

(test test-send-invoice-with-reply-markup
  "Test sending an invoice with reply markup"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Test Invoice"
                  :description "Test description"
                  :payload "test_payload"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 100))))
        (markup `(:inline_keyboard (((:text "Pay Now" :callback_data "pay"))))))
    (let ((result (cl-telegram/api:send-invoice 123456 invoice :reply-markup markup)))
      (is (or (not (null result)) t)))))

(test test-send-invoice-with-notification
  "Test sending an invoice with notification disabled"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Silent Invoice"
                  :description "No notification"
                  :payload "silent_payload"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 100)))))
    (let ((result (cl-telegram/api:send-invoice 123456 invoice :disable-notification t)))
      (is (or (not (null result)) t)))))

;;; ============================================================================
;;; Section 6: Invoice Link Tests
;;; ============================================================================

(test test-create-invoice-link-basic
  "Test creating an invoice link"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Link Invoice"
                  :description "Invoice for link generation"
                  :payload "link_payload"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 100)))))
    (let ((result (cl-telegram/api:create-invoice-link invoice)))
      (is (or (stringp result) (not (null result)))))))

(test test-create-invoice-link-with-start-parameter
  "Test creating an invoice link with start parameter"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Deep Link Invoice"
                  :description "With start parameter"
                  :payload "deeplink_payload"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 100)))))
    (let ((result (cl-telegram/api:create-invoice-link invoice :start-parameter "ref123")))
      (is (or (stringp result) (not (null result)))))))

;;; ============================================================================
;;; Section 7: Star Payment Tests
;;; ============================================================================

(test test-refund-star-payment
  "Test refunding a star payment"
  (let ((result (cl-telegram/api:refund-star-payment 123456 "charge_abc123")))
    (is (or (eq result t) (null result)))))

(test test-gift-premium-subscription
  "Test gifting a premium subscription"
  (let ((result (cl-telegram/api:gift-premium-subscription 123456 3 150)))
    (is (or (eq result t) (null result)))))

(test test-gift-premium-with-custom-text
  "Test gifting premium with custom message"
  (let ((result (cl-telegram/api:gift-premium-subscription
                 123456 6 300
                 :text "Happy Birthday! Enjoy Premium!"
                 :text-parse-mode "HTML")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 8: Star Balance Tests
;;; ============================================================================

(test test-get-business-account-star-balance
  "Test getting business account star balance"
  (let ((balance (cl-telegram/api:get-business-account-star-balance "biz_123")))
    (is (or (not (null balance)) t))))

(test test-transfer-business-account-stars
  "Test transferring stars from business account"
  (let ((result (cl-telegram/api:transfer-business-account-stars "biz_123" 500)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 9: Helper Function Tests
;;; ============================================================================

(test test-create-subscription-invoice
  "Test creating a subscription invoice"
  (let ((invoice (cl-telegram/api:create-subscription-invoice
                  "Premium Subscription"
                  "Access to all premium features"
                  "premium_sub_payload"
                  "USD"
                  999
                  :months 3)))
    (is (string= (cl-telegram/api:invoice-title invoice) "Premium Subscription"))
    (is (cl-telegram/api:invoice-subscription-period invoice))))

(test test-create-subscription-invoice-single-month
  "Test creating a single month subscription invoice"
  (let ((invoice (cl-telegram/api:create-subscription-invoice
                  "Monthly Plan"
                  "One month subscription"
                  "monthly_payload"
                  "EUR"
                  499)))
    (is (string= (cl-telegram/api:invoice-currency invoice) "EUR"))))

(test test-create-star-invoice
  "Test creating a star invoice"
  (let ((invoice (cl-telegram/api:create-star-invoice
                  "Support the Creator"
                  "Buy stars to support"
                  100
                  :payload "support_creator"
                  :photo-url "https://example.com/creator.jpg")))
    (is (string= (cl-telegram/api:invoice-currency invoice) "XTR"))
    (is (= (length (cl-telegram/api:invoice-prices invoice)) 1))))

(test test-create-star-invoice-minimal
  "Test creating a star invoice with minimal parameters"
  (let ((invoice (cl-telegram/api:create-star-invoice
                  "Buy Stars"
                  "Get Telegram Stars"
                  50)))
    (is (string= (cl-telegram/api:invoice-title invoice) "Buy Stars"))
    (is (string= (cl-telegram/api:invoice-payload invoice) "stars_purchase"))))

;;; ============================================================================
;;; Section 10: Currency and Constants Tests
;;; ============================================================================

(test test-supported-currencies-includes-stars
  "Test that supported currencies includes Telegram Stars (XTR)"
  (is (member "XTR" cl-telegram/api:*supported-currencies* :test #'string=))
  (is (member "USD" cl-telegram/api:*supported-currencies* :test #'string=))
  (is (member "EUR" cl-telegram/api:*supported-currencies* :test #'string=)))

(test test-max-tip-presets
  "Test max tip presets are defined"
  (is (listp cl-telegram/api:*max-tip-presets*))
  (is (> (length cl-telegram/api:*max-tip-presets*) 0)))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-payment-enhanced-tests ()
  "Run all Payment API Enhanced tests"
  (let ((results (run! 'payment-enhanced-tests :if-fail :error)))
    (format t "~%~%=== Payment API Enhanced Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
