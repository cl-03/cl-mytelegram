;;; payment-enhanced.lisp --- Enhanced Payment API for complete payment flow
;;;
;;; Provides support for complete payment processing:
;;; - Payment form retrieval and handling
;;; - Payment form submission
;;; - Invoice retrieval
;;; - Shipping query handling
;;; - Pre-checkout query handling
;;; - Payment verification
;;; - Refund processing (Stars and regular)
;;;
;;; Reference: https://core.telegram.org/api/payments
;;; Version: 0.38.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Payment Form Classes
;;; ============================================================================

(defclass payment-form ()
  ((form-id :initarg :form-id :accessor payment-form-id
            :documentation "Payment form identifier")
   (invoice :initarg :invoice :accessor payment-form-invoice
            :documentation "Invoice object")
   (provider-id :initarg :provider-id :accessor payment-form-provider-id
                :documentation "Payment provider ID")
   (url :initarg :url :accessor payment-form-url
        :documentation "Payment URL")
   (native-provider :initarg :native-provider :accessor payment-form-native-provider
                    :documentation "Native provider data")
   (can-save-credentials :initarg :can-save-credentials :accessor payment-form-can-save-credentials
                         :documentation "Whether credentials can be saved")
   (need-user-information :initarg :need-user-information :accessor payment-form-need-user-info
                          :documentation "Whether user info is needed")
   (need-shipping-address :initarg :need-shipping-address :accessor payment-form-need-shipping
                          :documentation "Whether shipping address is needed")))

(defclass shipping-option ()
  ((id :initarg :id :accessor shipping-option-id
       :documentation "Unique option identifier")
   (title :initarg :title :accessor shipping-option-title
          :documentation "Option title, 1-32 chars")
   (prices :initarg :prices :accessor shipping-option-prices
           :documentation "List of labeled-price for shipping cost")))

(defclass shipping-query ()
  ((id :initarg :id :accessor shipping-query-id
       :documentation "Unique query identifier")
   (from :initarg :from :accessor shipping-query-from
         :documentation "User who sent the query")
   (invoice-payload :initarg :invoice-payload :accessor shipping-query-payload
                    :documentation "Invoice payload")
   (shipping-address :initarg :shipping-address :accessor shipping-query-address
                     :documentation "Shipping address")))

(defclass pre-checkout-query ()
  ((id :initarg :id :accessor pre-checkout-query-id
       :documentation "Unique query identifier")
   (from :initarg :from :accessor pre-checkout-query-from
         :documentation "User who sent the query")
   (currency :initarg :currency :accessor pre-checkout-query-currency
             :documentation "Three-letter ISO 4217 currency code")
   (total-amount :initarg :total-amount :accessor pre-checkout-query-total-amount
                 :documentation "Total price in smallest units")
   (invoice-payload :initarg :invoice-payload :accessor pre-checkout-query-payload
                    :documentation "Invoice payload")
   (shipping-option-id :initarg :shipping-option-id :accessor pre-checkout-query-shipping-option
                       :documentation "Shipping option ID")
   (order-info :initarg :order-info :accessor pre-checkout-query-order-info
               :documentation "User order information")))

(defclass order-info ()
  ((name :initarg :name :accessor order-info-name
         :documentation "User name")
   (phone-number :initarg :phone-number :accessor order-info-phone
                 :documentation "User phone number")
   (email :initarg :email :accessor order-info-email
          :documentation "User email")
   (shipping-address :initarg :shipping-address :accessor order-info-shipping
                     :documentation "Shipping address")))

;;; ============================================================================
;;; Section 2: Payment Form Retrieval
;;; ============================================================================

(defvar *payment-forms-cache* (make-hash-table :test 'equal)
  "Cache for payment forms")

(defvar *payment-forms-cache-time* (make-hash-table :test 'equal)
  "Cache timestamps for payment forms")

(defvar *payment-forms-cache-ttl* 300
  "Cache TTL in seconds (default: 5 minutes)")

(defun get-payment-form (invoice-payload &key (force-refresh nil))
  "Get payment form for processing.

   Args:
     invoice-payload: Bot-defined invoice payload
     force-refresh: Force refresh from server

   Returns:
     Payment-form object on success, NIL on failure

   Example:
     (get-payment-form \"product_123_payload\")"
  (let ((now (get-universal-time)))
    ;; Check cache
    (unless force-refresh
      (let* ((cached (gethash invoice-payload *payment-forms-cache*))
             (cached-time (gethash invoice-payload *payment-forms-cache-time*)))
        (when (and cached cached-time
                   (< (- now cached-time) *payment-forms-cache-ttl*))
          (return-from get-payment-form cached)))))

  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("invoice_payload" . ,invoice-payload)))
             (result (make-api-call connection "getPaymentForm" params)))
        (when result
          (let* ((form (make-instance 'payment-form
                                      :form-id (getf result :form_id)
                                      :invoice (getf result :invoice)
                                      :provider-id (getf result :provider_id)
                                      :url (getf result :url)
                                      :native-provider (getf result :native_provider)
                                      :can-save-credentials (getf result :can_save_credentials)
                                      :need-user-info (getf result :need_user_information)
                                      :need-shipping (getf result :need_shipping_address))))
            ;; Update cache
            (setf (gethash invoice-payload *payment-forms-cache*) form
                  (gethash invoice-payload *payment-forms-cache-time*) now)
            form)))
    (error (e)
      (log-message :error "Error getting payment form: ~A" (princ-to-string e))
      nil)))

(defun clear-payment-form-cache (&key (invoice-payload nil))
  "Clear payment form cache.

   Args:
     invoice-payload: Specific payload to clear, or NIL for all

   Returns:
     T on success

   Example:
     (clear-payment-form-cache :invoice-payload \"product_123\")"
  (if invoice-payload
      (progn
        (remhash invoice-payload *payment-forms-cache*)
        (remhash invoice-payload *payment-forms-cache-time*))
      (progn
        (clrhash *payment-forms-cache*)
        (clrhash *payment-forms-cache-time*)))
  t)

;;; ============================================================================
;;; Section 3: Payment Form Submission
;;; ============================================================================

(defun send-payment-form (form-id invoice-payload provider-data &key
                          (name nil) (phone nil) (email nil)
                          (shipping-address nil) (credentials-save-allowed nil))
  "Send payment form to complete payment.

   Args:
     form-id: Payment form ID
     invoice-payload: Bot-defined invoice payload
     provider-data: Payment provider data (JSON string)
     name: User full name (optional)
     phone: User phone number (optional)
     email: User email (optional)
     shipping-address: Shipping address (optional)
     credentials-save-allowed: Whether to save credentials

   Returns:
     T on success, error message on failure

   Example:
     (send-payment-form \"form_123\" \"product_123\" \"{\\\"token\\\": \\\"xxx\\\"}\"
                        :name \"John Doe\"
                        :email \"john@example.com\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("form_id" . ,form-id)
                       ("invoice_payload" . ,invoice-payload)
                       ("provider_data" . ,provider-data))))
        (when name
          (push (cons "name" name) params))
        (when phone
          (push (cons "phone_number" phone) params))
        (when email
          (push (cons "email" email) params))
        (when shipping-address
          (push (cons "shipping_address" shipping-address) params))
        (when credentials-save-allowed
          (push (cons "allow_credentials_save" (if credentials-save-allowed "true" "false")) params))

        (let ((result (make-api-call connection "sendPaymentForm" params)))
          (if result
              (progn
                ;; Clear cache
                (clear-payment-form-cache :invoice-payload invoice-payload)
                (log-message :info "Payment form submitted successfully")
                t)
              nil)))
    (error (e)
      (log-message :error "Error sending payment form: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 4: Invoice Retrieval
;;; ============================================================================

(defun get-invoice (chat-id message-id)
  "Get invoice information from a message.

   Args:
     chat-id: Chat ID where invoice was sent
     message-id: Message ID containing the invoice

   Returns:
     Invoice object on success, NIL on failure

   Example:
     (get-invoice -1001234567890 12345)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_id" . ,message-id)))
             (result (make-api-call connection "getInvoice" params)))
        (when result
          (make-instance 'invoice
                         :title (getf result :title)
                         :description (getf result :description)
                         :payload (getf result :payload)
                         :currency (getf result :currency)
                         :prices (getf result :prices)
                         :total-amount (getf result :total_amount))))
    (error (e)
      (log-message :error "Error getting invoice: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 5: Shipping Query Handling
;;; ============================================================================

(defun answer-shipping-query (query-id ok &key (shipping-options nil) (error-message nil))
  "Answer shipping query.

   Args:
     query-id: Shipping query ID
     ok: Whether shipping is allowed (T or NIL)
     shipping-options: List of shipping-option objects (if ok is T)
     error-message: Error message (if ok is NIL)

   Returns:
     T on success, NIL on failure

   Example:
     (answer-shipping-query \"query_123\" t
                            :shipping-options
                            (list (make-instance 'shipping-option
                                                 :id \"standard\"
                                                 :title \"Standard Shipping\"
                                                 :prices (list (make-labeled-price \"Shipping\" 500)))))"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("shipping_query_id" . ,query-id)
                       ("ok" . ,(if ok "true" "false")))))
        (when (and ok shipping-options)
          (let ((options-json (mapcar (lambda (opt)
                                        (list :id (shipping-option-id opt)
                                              :title (shipping-option-title opt)
                                              :prices (mapcar (lambda (p)
                                                                (list :label (labeled-price-label p)
                                                                      :amount (labeled-price-amount p)))
                                                              (shipping-option-prices opt))))
                                      shipping-options)))
            (push (cons "shipping_options" (json:encode-to-string options-json)) params)))
        (when (and (not ok) error-message)
          (push (cons "error_message" error-message) params))

        (let ((result (make-api-call connection "answerShippingQuery" params)))
          (if result t nil)))
    (error (e)
      (log-message :error "Error answering shipping query: ~A" (princ-to-string e))
      nil)))

(defun get-shipping-query (query-id)
  "Get shipping query by ID.

   Args:
     query-id: Shipping query ID

   Returns:
     Shipping-query object or NIL

   Example:
     (get-shipping-query \"query_123\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("query_id" . ,query-id)))
             (result (make-api-call connection "getShippingQuery" params)))
        (when result
          (make-instance 'shipping-query
                         :id (getf result :id)
                         :from (getf result :from)
                         :payload (getf result :invoice_payload)
                         :address (getf result :shipping_address))))
    (error (e)
      (log-message :error "Error getting shipping query: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 6: Pre-Checkout Query Handling
;;; ============================================================================

(defun answer-pre-checkout-query (query-id ok &key (error-message nil))
  "Answer pre-checkout query.

   Args:
     query-id: Pre-checkout query ID
     ok: Whether checkout is allowed (T or NIL)
     error-message: Error message (if ok is NIL, 0-255 chars)

   Returns:
     T on success, NIL on failure

   Example:
     (answer-pre-checkout-query \"query_123\" t)
     (answer-pre-checkout-query \"query_456\" nil :error-message \"Out of stock\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("pre_checkout_query_id" . ,query-id)
                       ("ok" . ,(if ok "true" "false")))))
        (when (and (not ok) error-message)
          (push (cons "error_message" error-message) params))

        (let ((result (make-api-call connection "answerPreCheckoutQuery" params)))
          (if result t nil)))
    (error (e)
      (log-message :error "Error answering pre-checkout query: ~A" (princ-to-string e))
      nil)))

(defun get-pre-checkout-query (query-id)
  "Get pre-checkout query by ID.

   Args:
     query-id: Pre-checkout query ID

   Returns:
     Pre-checkout-query object or NIL

   Example:
     (get-pre-checkout-query \"query_123\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("query_id" . ,query-id)))
             (result (make-api-call connection "getPreCheckoutQuery" params)))
        (when result
          (make-instance 'pre-checkout-query
                         :id (getf result :id)
                         :from (getf result :from)
                         :currency (getf result :currency)
                         :total-amount (getf result :total_amount)
                         :payload (getf result :invoice_payload)
                         :shipping-option (getf result :shipping_option_id)
                         :order-info (getf result :order_info))))
    (error (e)
      (log-message :error "Error getting pre-checkout query: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 7: Regular Payment Refund
;;; ============================================================================

(defun refund-payment (user-id provider-payment-charge-id &key (amount nil) (currency nil))
  "Refund a payment.

   Args:
     user-id: User ID
     provider-payment-charge-id: Provider payment charge ID
     amount: Refund amount (optional, defaults to full amount)
     currency: Currency code (required if amount specified)

   Returns:
     T on success, NIL on failure

   Example:
     (refund-payment 123456 \"charge_abc\") ; Full refund
     (refund-payment 123456 \"charge_abc\" :amount 1000 :currency \"USD\") ; Partial refund"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_id" . ,user-id)
                       ("provider_payment_charge_id" . ,provider-payment-charge-id))))
        (when amount
          (push (cons "amount" amount) params))
        (when currency
          (push (cons "currency" currency) params))

        (let ((result (make-api-call connection "refundPayment" params)))
          (if result
              (progn
                (log-message :info "Payment refunded for user ~A" user-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error refunding payment: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 8: Payment Verification
;;; ============================================================================

(defun verify-payment (invoice-payload payment-id)
  "Verify payment status.

   Args:
     invoice-payload: Bot-defined invoice payload
     payment-id: Payment identifier

   Returns:
     Plist with payment status (:status :amount :currency :date) or NIL

   Example:
     (verify-payment \"product_123\" \"payment_abc\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("invoice_payload" . ,invoice-payload)
                       ("payment_id" . ,payment-id)))
             (result (make-api-call connection "verifyPayment" params)))
        (when result
          (list :status (getf result :status)
                :amount (getf result :amount)
                :currency (getf result :currency)
                :date (getf result :date))))
    (error (e)
      (log-message :error "Error verifying payment: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 9: Shipping Address Utilities
;;; ============================================================================

(defun make-shipping-address (country-code state city street-line1 street-line2 post-code)
  "Create a shipping address.

   Args:
     country-code: Two-letter country code (ISO 3166-1 alpha-2)
     state: State or region
     city: City name
     street-line1: First line of street address
     street-line2: Second line of street address (optional)
     post-code: Address post code

   Returns:
     Plist representing shipping address

   Example:
     (make-shipping-address \"US\" \"CA\" \"San Francisco\" \"123 Market St\" \"Apt 4B\" \"94102\")"
  (list :country_code country-code
        :state state
        :city city
        :street_line1 street-line1
        :street_line2 street-line2
        :post_code post-code))

(defun parse-shipping-address (address-data)
  "Parse shipping address from API response.

   Args:
     address-data: Plist from API response

   Returns:
     Shipping address plist"
  (list :country-code (getf address-data :country_code)
        :state (getf address-data :state)
        :city (getf address-data :city)
        :street-line1 (getf address-data :street_line1)
        :street-line2 (getf address-data :street_line2)
        :post-code (getf address-data :post_code)))

;;; ============================================================================
;;; Section 10: Order Info Utilities
;;; ============================================================================

(defun make-order-info (&key (name nil) (phone nil) (email nil) (shipping-address nil))
  "Create order information.

   Args:
     name: User name (optional)
     phone: Phone number (optional)
     email: Email address (optional)
     shipping-address: Shipping address plist (optional)

   Returns:
     Order-info object

   Example:
     (make-order-info :name \"John Doe\"
                      :email \"john@example.com\"
                      :shipping-address (make-shipping-address \"US\" \"CA\" \"SF\" \"123 Main St\" nil \"94102\"))"
  (make-instance 'order-info
                 :name name
                 :phone-number phone
                 :email email
                 :shipping-address shipping-address))

;;; End of payment-enhanced.lisp
