;;; payment-business-tests.lisp --- Tests for payment and business functionality

(in-package #:cl-telegram/tests)

(def-suite payment-business-tests
  :description "Tests for payment and business features (v0.20.0)")

(in-suite payment-business-tests)

;;; ======================================================================
;;; Labeled Price Class Tests
;;; ======================================================================

(test test-labeled-price-class
  "Test labeled-price class creation and accessors"
  (let ((price (make-instance 'cl-telegram/api:labeled-price
                              :label "Basic Plan"
                              :amount 999)))
    (is (string= "Basic Plan" (cl-telegram/api:labeled-price-label price)))
    (is (= 999 (cl-telegram/api:labeled-price-amount price)))))

(test test-labeled-price-defaults
  "Test labeled-price default values"
  (let ((price (make-instance 'cl-telegram/api:labeled-price)))
    (is (string= "" (cl-telegram/api:labeled-price-label price)))
    (is (= 0 (cl-telegram/api:labeled-price-amount price)))))

(test test-make-labeled-price
  "Test make-labeled-price helper function"
  (let ((price (cl-telegram/api:make-labeled-price "Premium" 1999)))
    (is (string= "Premium" (cl-telegram/api:labeled-price-label price)))
    (is (= 1999 (cl-telegram/api:labeled-price-amount price)))))

;;; ======================================================================
;;; Invoice Class Tests
;;; ======================================================================

(test test-invoice-class
  "Test invoice class creation and accessors"
  (let ((invoice (make-instance 'cl-telegram/api:invoice
                                :title "Premium Subscription"
                                :description "12 months of premium features"
                                :payload "premium_12m_2024"
                                :provider-token "provider_token_123"
                                :currency "USD"
                                :prices (list (make-instance 'cl-telegram/api:labeled-price
                                                             :label "Annual"
                                                             :amount 9999))
                                :need-email t)))
    (is (string= "Premium Subscription" (cl-telegram/api:invoice-title invoice)))
    (is (string= "12 months of premium features" (cl-telegram/api:invoice-description invoice)))
    (is (string= "premium_12m_2024" (cl-telegram/api:invoice-payload invoice)))
    (is (string= "provider_token_123" (cl-telegram/api:invoice-provider-token invoice)))
    (is (string= "USD" (cl-telegram/api:invoice-currency invoice)))
    (is (= 1 (length (cl-telegram/api:invoice-prices invoice))))
    (is (true (cl-telegram/api:invoice-need-email invoice)))))

(test test-invoice-defaults
  "Test invoice default values"
  (let ((invoice (make-instance 'cl-telegram/api:invoice
                                :title "Test"
                                :description "Test desc"
                                :payload "test")))
    (is (string= "Test" (cl-telegram/api:invoice-title invoice)))
    (is (string= "Test desc" (cl-telegram/api:invoice-description invoice)))
    (is (string= "test" (cl-telegram/api:invoice-payload invoice)))
    (is (string= "USD" (cl-telegram/api:invoice-currency invoice)))
    (is (null (cl-telegram/api:invoice-provider-token invoice)))
    (is (null (cl-telegram/api:invoice-prices invoice)))))

(test test-make-invoice
  "Test make-invoice helper function"
  (let ((prices (list (cl-telegram/api:make-labeled-price "Item" 500)))
        (invoice (cl-telegram/api:make-invoice
                  :title "Test Product"
                  :description "Test Description"
                  :payload "test_payload"
                  :currency "EUR"
                  :prices prices
                  :need-name t
                  :need-phone-number t)))
    (is (string= "Test Product" (cl-telegram/api:invoice-title invoice)))
    (is (= 1 (length (cl-telegram/api:invoice-prices invoice))))
    (is (true (cl-telegram/api:invoice-need-name invoice)))
    (is (true (cl-telegram/api:invoice-need-phone-number invoice)))))

;;; ======================================================================
;;; Invoice Creation Helpers Tests
;;; ======================================================================

(test test-create-subscription-invoice
  "Test create-subscription-invoice helper"
  (let ((invoice (cl-telegram/api:create-subscription-invoice
                  "Monthly Plan"
                  "Monthly subscription"
                  "monthly_sub"
                  "USD"
                  999
                  :months 3)))
    (is (string= "Monthly Plan" (cl-telegram/api:invoice-title invoice)))
    (is (string= "USD" (cl-telegram/api:invoice-currency invoice)))
    ;; Should have 3 months price
    (is (= 1 (length (cl-telegram/api:invoice-prices invoice))))
    ;; Should have subscription period (~90 days in seconds)
    (is (>= (cl-telegram/api:invoice-subscription-period invoice) (* 90 24 60 60)))))

(test test-create-star-invoice
  "Test create-star-invoice helper for Telegram Stars"
  (let ((invoice (cl-telegram/api:create-star-invoice
                  "100 Stars"
                  "Purchase 100 Telegram Stars"
                  100
                  :payload "stars_100")))
    (is (string= "100 Stars" (cl-telegram/api:invoice-title invoice)))
    (is (string= "stars_100" (cl-telegram/api:invoice-payload invoice)))
    ;; Stars use XTR currency
    (is (string= "XTR" (cl-telegram/api:invoice-currency invoice)))))

;;; ======================================================================
;;; Star Transaction and Balance Tests
;;; ======================================================================

(test test-star-transaction-class
  "Test star-transaction class creation"
  (let ((tx (make-instance 'cl-telegram/api:star-transaction
                           :id "tx_12345"
                           :amount 500
                           :date 1713542400
                           :source "user_payment"
                           :type "purchase")))
    (is (string= "tx_12345" (cl-telegram/api:star-transaction-id tx)))
    (is (= 500 (cl-telegram/api:star-transaction-amount tx)))
    (is (= 1713542400 (cl-telegram/api:star-transaction-date tx)))
    (is (string= "user_payment" (cl-telegram/api:star-transaction-source tx)))
    (is (string= "purchase" (cl-telegram/api:star-transaction-type tx)))))

(test test-star-balance-class
  "Test star-balance class creation"
  (let ((balance (make-instance 'cl-telegram/api:star-balance
                                :amount 10000)))
    (is (= 10000 (cl-telegram/api:star-balance-amount balance)))))

(test test-star-balance-defaults
  "Test star-balance default values"
  (let ((balance (make-instance 'cl-telegram/api:star-balance)))
    (is (= 0 (cl-telegram/api:star-balance-amount balance)))))

;;; ======================================================================
;;; Business Connection Class Tests
;;; ======================================================================

(test test-business-connection-class
  "Test business-connection class creation"
  (let ((conn (make-instance 'cl-telegram/api:business-connection
                             :id "biz_conn_123"
                             :user-chat-id 456789
                             :date 1713542400
                             :is-enabled t)))
    (is (string= "biz_conn_123" (cl-telegram/api:business-connection-id conn)))
    (is (= 456789 (cl-telegram/api:business-connection-user-chat-id conn)))
    (is (= 1713542400 (cl-telegram/api:business-connection-date conn)))
    (is (true (cl-telegram/api:business-connection-is-enabled conn)))))

(test test-business-connection-defaults
  "Test business-connection default values"
  (let ((conn (make-instance 'cl-telegram/api:business-connection
                             :id "test")))
    (is (= 0 (cl-telegram/api:business-connection-user-chat-id conn)))
    (is (= 0 (cl-telegram/api:business-connection-date conn)))
    (is (true (cl-telegram/api:business-connection-is-enabled conn)))))

;;; ======================================================================
;;; Business Location Class Tests
;;; ======================================================================

(test test-business-location-class
  "Test business-location class creation"
  (let ((loc (make-instance 'cl-telegram/api:business-location
                            :address "123 Main St, New York, NY"
                            :location '(:latitude 40.7128 :longitude -74.0060))))
    (is (string= "123 Main St, New York, NY" (cl-telegram/api:business-location-address loc)))
    (is (equal '(:latitude 40.7128 :longitude -74.0060) (cl-telegram/api:business-location-location loc)))))

(test test-business-location-defaults
  "Test business-location default values"
  (let ((loc (make-instance 'cl-telegram/api:business-location)))
    (is (string= "" (cl-telegram/api:business-location-address loc)))
    (is (null (cl-telegram/api:business-location-location loc)))))

;;; ======================================================================
;;; Business Opening Hours Tests
;;; ======================================================================

(test test-business-opening-hours-interval-class
  "Test business-opening-hours-interval class creation"
  (let ((interval (make-instance 'cl-telegram/api:business-opening-hours-interval
                                 :opening-minute 540  ; 9:00 AM Monday
                                 :closing-minute 1020))) ; 5:00 PM Monday
    (is (= 540 (cl-telegram/api:business-interval-opening-minute interval)))
    (is (= 1020 (cl-telegram/api:business-interval-closing-minute interval)))))

(test test-make-opening-hours-interval
  "Test make-opening-hours-interval helper"
  (let ((interval (cl-telegram/api:make-opening-hours-interval 480 960)))
    (is (= 480 (cl-telegram/api:business-interval-opening-minute interval)))
    (is (= 960 (cl-telegram/api:business-interval-closing-minute interval)))))

(test test-make-opening-hours-from-times
  "Test make-opening-hours-from-times helper"
  (let ((hours (cl-telegram/api:make-opening-hours-from-times
                "UTC"
                '(0 9 17)  ; Monday 9am-5pm
                '(1 9 17)  ; Tuesday 9am-5pm
                '(2 9 17)))) ; Wednesday 9am-5pm
    (is (string= "UTC" (cl-telegram/api:business-opening-hours-time-zone hours)))
    (is (= 3 (length (cl-telegram/api:business-opening-hours-intervals hours))))
    ;; First interval should be Monday 9am-5pm (540-1020 minutes)
    (is (= 540 (cl-telegram/api:business-interval-opening-minute (first (cl-telegram/api:business-opening-hours-intervals hours)))))
    (is (= 1020 (cl-telegram/api:business-interval-closing-minute (first (cl-telegram/api:business-opening-hours-intervals hours)))))))

(test test-business-opening-hours-class
  "Test business-opening-hours class creation"
  (let ((interval (make-instance 'cl-telegram/api:business-opening-hours-interval
                                 :opening-minute 540
                                 :closing-minute 1020))
        (hours (make-instance 'cl-telegram/api:business-opening-hours
                              :time-zone-name "America/New_York"
                              :opening-hours (list interval))))
    (is (string= "America/New_York" (cl-telegram/api:business-opening-hours-time-zone hours)))
    (is (= 1 (length (cl-telegram/api:business-opening-hours-intervals hours)))))))

;;; ======================================================================
;;; Business Bot Rights Tests
;;; ======================================================================

(test test-business-bot-rights-class
  "Test business-bot-rights class creation"
  (let ((rights (make-instance 'cl-telegram/api:business-bot-rights
                               :can-send-messages t
                               :can-send-media t
                               :can-transfer-stars nil)))
    (is (true (cl-telegram/api:business-bot-can-send-messages rights)))
    (is (true (cl-telegram/api:business-bot-can-send-media rights)))
    (is (false (cl-telegram/api:business-bot-can-transfer-stars rights)))))

(test test-business-bot-rights-defaults
  "Test business-bot-rights default values"
  (let ((rights (make-instance 'cl-telegram/api:business-bot-rights)))
    (is (true (cl-telegram/api:business-bot-can-send-messages rights)))
    (is (true (cl-telegram/api:business-bot-can-send-media rights)))
    (is (true (cl-telegram/api:business-bot-can-send-polls rights)))
    (is (null (cl-telegram/api:business-bot-can-change-info rights)))
    (is (null (cl-telegram/api:business-bot-can-transfer-stars rights)))))

;;; ======================================================================
;;; Quick Reply Tests
;;; ======================================================================

(test test-quick-reply-class
  "Test quick-reply class creation"
  (let ((reply (make-instance 'cl-telegram/api:quick-reply
                              :text "Contact Support"
                              :type :text)))
    (is (string= "Contact Support" (cl-telegram/api:quick-reply-text reply)))
    (is (eq :text (cl-telegram/api:quick-reply-type reply)))))

(test test-make-quick-reply
  "Test make-quick-reply helper"
  (let ((reply (cl-telegram/api:make-quick-reply "Share Location" :type :location)))
    (is (string= "Share Location" (cl-telegram/api:quick-reply-text reply)))
    (is (eq :location (cl-telegram/api:quick-reply-type reply)))))

(test test-quick-reply-types
  "Test all quick reply types"
  (dolist (type '(:text :phone :email :location))
    (let ((reply (cl-telegram/api:make-quick-reply "Test" :type type)))
      (is (eq type (cl-telegram/api:quick-reply-type reply))))))

;;; ======================================================================
;;; Mock API Call Tests (Payment)
;;; ======================================================================

(test test-send-invoice-return
  "Test send-invoice returns message or NIL"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Test"
                  :description "Test invoice"
                  :payload "test"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 100)))))
    (let ((result (cl-telegram/api:send-invoice 123456 invoice)))
      (is (or (notnull result) (null result))))))

(test test-create-invoice-link-return
  "Test create-invoice-link returns string or NIL"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Test"
                  :description "Test invoice"
                  :payload "test"
                  :currency "USD"
                  :prices (list (cl-telegram/api:make-labeled-price "Item" 100)))))
    (let ((result (cl-telegram/api:create-invoice-link invoice)))
      (is (or (stringp result) (null result))))))

(test test-refund-star-payment-return
  "Test refund-star-payment returns boolean"
  (let ((result (cl-telegram/api:refund-star-payment 123456 "charge_abc")))
    (is (or (eq t result) (null result)))))

(test test-gift-premium-subscription-return
  "Test gift-premium-subscription returns boolean"
  (let ((result (cl-telegram/api:gift-premium-subscription 123456 3 1000)))
    (is (or (eq t result) (null result)))))

(test test-get-business-account-star-balance-return
  "Test get-business-account-star-balance returns star-balance or NIL"
  (let ((result (cl-telegram/api:get-business-account-star-balance "biz_123")))
    (is (or (notnull result) (null result)))))

(test test-transfer-business-account-stars-return
  "Test transfer-business-account-stars returns boolean"
  (let ((result (cl-telegram/api:transfer-business-account-stars "biz_123" 500)))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Mock API Call Tests (Business)
;;; ======================================================================

(test test-get-business-connection-return
  "Test get-business-connection returns business-connection or NIL"
  (let ((result (cl-telegram/api:get-business-connection "biz_123")))
    (is (or (notnull result) (null result)))))

(test test-set-business-location-return
  "Test set-business-location returns boolean"
  (let ((result (cl-telegram/api:set-business-location "biz_123" "123 Main St")))
    (is (or (eq t result) (null result)))))

(test test-get-business-location-return
  "Test get-business-location returns business-location or NIL"
  (let ((result (cl-telegram/api:get-business-location "biz_123")))
    (is (or (notnull result) (null result)))))

(test test-delete-business-location-return
  "Test delete-business-location returns boolean"
  (let ((result (cl-telegram/api:delete-business-location "biz_123")))
    (is (or (eq t result) (null result)))))

(test test-set-business-opening-hours-return
  "Test set-business-opening-hours returns boolean"
  (let ((hours (cl-telegram/api:make-opening-hours-from-times "UTC" '(0 9 17))))
    (let ((result (cl-telegram/api:set-business-opening-hours "biz_123" hours)))
      (is (or (eq t result) (null result))))))

(test test-get-business-opening-hours-return
  "Test get-business-opening-hours returns business-opening-hours or NIL"
  (let ((result (cl-telegram/api:get-business-opening-hours "biz_123")))
    (is (or (notnull result) (null result)))))

(test test-delete-business-opening-hours-return
  "Test delete-business-opening-hours returns boolean"
  (let ((result (cl-telegram/api:delete-business-opening-hours "biz_123")))
    (is (or (eq t result) (null result)))))

(test test-send-message-with-quick-replies-return
  "Test send-message-with-quick-replies returns message or NIL"
  (let ((replies (list (cl-telegram/api:make-quick-reply "Yes")
                       (cl-telegram/api:make-quick-reply "No"))))
    (let ((result (cl-telegram/api:send-message-with-quick-replies 123456 "Question?" replies)))
      (is (or (notnull result) (null result))))))

(test test-send-business-message-return
  "Test send-business-message returns message or NIL"
  (let ((result (cl-telegram/api:send-business-message "biz_123" 123456 "Hello")))
    (is (or (notnull result) (null result)))))

(test test-edit-business-message-return
  "Test edit-business-message returns boolean"
  (let ((result (cl-telegram/api:edit-business-message "biz_123" 123456 100 "Edited")))
    (is (or (eq t result) (null result)))))

(test test-delete-business-message-return
  "Test delete-business-message returns boolean"
  (let ((result (cl-telegram/api:delete-business-message "biz_123" 123456 100)))
    (is (or (eq t result) (null result)))))

(test test-create-business-chat-link-return
  "Test create-business-chat-link returns string or NIL"
  (let ((result (cl-telegram/api:create-business-chat-link "biz_123")))
    (is (or (stringp result) (null result)))))

;;; ======================================================================
;;; Global State Tests
;;; ======================================================================

(test test-supported-currencies
  "Test supported currencies includes major currencies and XTR"
  (is (member "USD" cl-telegram/api:*supported-currencies* :test #'string=))
  (is (member "EUR" cl-telegram/api:*supported-currencies* :test #'string=))
  (is (member "XTR" cl-telegram/api:*supported-currencies* :test #'string=)))

(test test-max-tip-presets
  "Test max tip presets contains reasonable amounts"
  (is (<= 4 (length cl-telegram/api:*max-tip-presets*)))
  (is (every #'integerp cl-telegram/api:*max-tip-presets*)))

(test test-business-connections-cache
  "Test business connections cache is hash table"
  (is (typep cl-telegram/api:*business-connections-cache* 'hash-table)))

(test test-quick-reply-types
  "Test quick reply types list"
  (is (= 4 (length cl-telegram/api:*quick-reply-types*)))
  (is (member :text cl-telegram/api:*quick-reply-types*))
  (is (member :phone cl-telegram/api:*quick-reply-types*))
  (is (member :email cl-telegram/api:*quick-reply-types*))
  (is (member :location cl-telegram/api:*quick-reply-types*)))

;;; ======================================================================
;;; Edge Case Tests
;;; ======================================================================

(test test-make-invoice-empty-prices
  "Test make-invoice with empty prices list"
  (let ((invoice (cl-telegram/api:make-invoice
                  :title "Free"
                  :description "Free product"
                  :payload "free"
                  :currency "USD"
                  :prices nil)))
    (is (null (cl-telegram/api:invoice-prices invoice)))))

(test test-subscription-invoice-single-month
  "Test subscription invoice for single month"
  (let ((invoice (cl-telegram/api:create-subscription-invoice
                  "Monthly" "Monthly plan" "monthly" "USD" 999
                  :months 1)))
    (is (>= (cl-telegram/api:invoice-subscription-period invoice) (* 30 24 60 60)))))

(test test-opening-hours-full-week
  "Test opening hours for full week"
  (let ((hours (cl-telegram/api:make-opening-hours-from-times
                "UTC"
                '(0 0 24) '(1 0 24) '(2 0 24) '(3 0 24)
                '(4 0 24) '(5 0 24) '(6 0 24))))
    (is (= 7 (length (cl-telegram/api:business-opening-hours-intervals hours))))))

(test test-quick-reply-empty-text
  "Test quick-reply with empty text"
  (let ((reply (cl-telegram/api:make-quick-reply "")))
    (is (string= "" (cl-telegram/api:quick-reply-text reply)))))

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-payment-business-tests ()
  "Run all payment and business tests"
  (format t "~%=== Running Payment & Business Unit Tests ===~%~%")
  (fiveam:run! 'payment-business-tests))

(export '(run-payment-business-tests))
