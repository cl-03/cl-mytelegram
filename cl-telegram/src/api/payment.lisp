;;; payment.lisp --- Payment system and Telegram Stars support
;;; Part of v0.20.0 - Payment and Business Features

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Payment Classes
;;; ======================================================================

(defclass labeled-price ()
  ((label :initarg :label :accessor labeled-price-label
          :initform "" :documentation "Portion label")
   (amount :initarg :amount :accessor labeled-price-amount
           :initform 0 :documentation "Price in smallest currency units")))

(defclass invoice ()
  ((title :initarg :title :accessor invoice-title
          :initform "" :documentation "Product name, 1-32 chars")
   (description :initarg :description :accessor invoice-description
                :initform "" :documentation "Product description, 1-255 chars")
   (payload :initarg :payload :accessor invoice-payload
            :initform "" :documentation "Bot-defined payload, 1-128 bytes")
   (provider-token :initarg :provider-token :accessor invoice-provider-token
                   :initform nil :documentation "Payment provider token")
   (currency :initarg :currency :accessor invoice-currency
             :initform "USD" :documentation "Three-letter ISO 4217 currency code")
   (prices :initarg :prices :accessor invoice-prices
           :initform nil :documentation "List of labeled-price objects")
   (subscription-period :initarg :subscription-period :accessor invoice-subscription-period
                        :initform nil :documentation "Subscription period in seconds")
   (max-tip-amount :initarg :max-tip-amount :accessor invoice-max-tip-amount
                   :initform nil :documentation "Max tip amount in smallest units")
   (suggested-tip-amounts :initarg :suggested-tip-amounts :accessor invoice-suggested-tip-amounts
                          :initform nil :documentation "List of suggested tip amounts")
   (provider-data :initarg :provider-data :accessor invoice-provider-data
                  :initform nil :documentation "JSON provider data")
   (photo-url :initarg :photo-url :accessor invoice-photo-url
              :initform nil :documentation "URL of product photo")
   (photo-size :initarg :photo-size :accessor invoice-photo-size
               :initform nil :documentation "Photo size in bytes")
   (photo-width :initarg :photo-width :accessor invoice-photo-width
                :initform nil :documentation "Photo width")
   (photo-height :initarg :photo-height :accessor invoice-photo-height
                 :initform nil :documentation "Photo height")
   (need-name :initarg :need-name :accessor invoice-need-name
              :initform nil :documentation "Require user full name")
   (need-phone-number :initarg :need-phone-number :accessor invoice-need-phone-number
                      :initform nil :documentation "Require user phone number")
   (need-email :initarg :need-email :accessor invoice-need-email
               :initform nil :documentation "Require user email")
   (need-shipping-address :initarg :need-shipping-address :accessor invoice-need-shipping-address
                          :initform nil :documentation "Require shipping address")
   (send-phone-number-to-provider :initarg :send-phone-number-to-provider
                                  :accessor invoice-send-phone-number-to-provider
                                  :initform nil :documentation "Send phone to provider")
   (send-email-to-provider :initarg :send-email-to-provider :accessor invoice-send-email-to-provider
                           :initform nil :documentation "Send email to provider")
   (is-flexible :initarg :is-flexible :accessor invoice-is-flexible
                :initform nil :documentation "Price depends on shipping method")))

(defclass star-transaction ()
  ((id :initarg :id :accessor star-transaction-id
       :initform "" :documentation "Transaction ID")
   (amount :initarg :amount :accessor star-transaction-amount
           :initform 0 :documentation "Amount of Telegram Stars")
   (date :initarg :date :accessor star-transaction-date
         :initform 0 :documentation "Transaction date as Unix time")
   (source :initarg :source :accessor star-transaction-source
           :initform nil :documentation "Transaction source (user, business, etc.)")
   (type :initarg :type :accessor star-transaction-type
         :initform nil :documentation "Transaction type")))

(defclass star-balance ()
  ((amount :initarg :amount :accessor star-balance-amount
           :initform 0 :documentation "Current Star balance")))

;;; ======================================================================
;;; Invoice Creation
;;; ======================================================================

(defun make-labeled-price (label amount)
  "Create a labeled-price object for invoice pricing"
  (make-instance 'labeled-price :label label :amount amount))

(defun make-invoice (&key title description payload provider-token currency
                       prices subscription-period max-tip-amount
                       suggested-tip-amounts provider-data photo-url
                       photo-size photo-width photo-height
                       need-name need-phone-number need-email
                       need-shipping-address send-phone-number-to-provider
                       send-email-to-provider is-flexible)
  "Create an invoice object for payment"
  (make-instance 'invoice
                 :title title
                 :description description
                 :payload payload
                 :provider-token provider-token
                 :currency currency
                 :prices prices
                 :subscription-period subscription-period
                 :max-tip-amount max-tip-amount
                 :suggested-tip-amounts suggested-tip-amounts
                 :provider-data provider-data
                 :photo-url photo-url
                 :photo-size photo-size
                 :photo-width photo-width
                 :photo-height photo-height
                 :need-name need-name
                 :need-phone-number need-phone-number
                 :need-email need-email
                 :need-shipping-address need-shipping-address
                 :send-phone-number-to-provider send-phone-number-to-provider
                 :send-email-to-provider send-email-to-provider
                 :is-flexible is-flexible))

(defun send-invoice (chat-id invoice &key message-thread-id direct-messages-topic-id
                                      start-parameter disable-notification
                                      protect-content allow-paid-broadcast
                                      message-effect-id reply-to-message-id
                                      reply-markup)
  "Send an invoice to a specific chat.

   CHAT-ID: Unique identifier for target chat or channel username
   INVOICE: Invoice object created with MAKE-INVOICE
   MESSAGE-THREAD-ID: Optional thread ID for supergroups
   DIRECT-MESSAGES-TOPIC-ID: Optional direct messages topic ID
   START-PARAMETER: Optional deep-linking parameter
   DISABLE-NOTIFICATION: Send silently if T
   PROTECT-CONTENT: Protect from forwarding if T
   ALLOW-PAID-BROADCAST: Allow paid broadcast if T
   MESSAGE-EFFECT-ID: Optional message effect ID
   REPLY-TO-MESSAGE-ID: Optional message to reply to
   REPLY-MARKUP: Optional keyboard or inline keyboard

   Returns the sent Message object on success, or NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (prices-json (loop for price in (invoice-prices invoice)
                                collect `(:label ,(labeled-price-label price)
                                         :amount ,(labeled-price-amount price))))
             (params `(("chat_id" . ,chat-id)
                       ("title" . ,(invoice-title invoice))
                       ("description" . ,(invoice-description invoice))
                       ("payload" . ,(invoice-payload invoice))
                       ("currency" . ,(invoice-currency invoice))
                       ("prices" . ,(json:encode-to-string prices-json)))))
        ;; Add optional parameters
        (when (invoice-provider-token invoice)
          (push (cons "provider_token" (invoice-provider-token invoice)) params))
        (when message-thread-id
          (push (cons "message_thread_id" message-thread-id) params))
        (when direct-messages-topic-id
          (push (cons "direct_messages_topic_id" direct-messages-topic-id) params))
        (when (invoice-subscription-period invoice)
          (push (cons "subscription_period" (invoice-subscription-period invoice)) params))
        (when (invoice-max-tip-amount invoice)
          (push (cons "max_tip_amount" (invoice-max-tip-amount invoice)) params))
        (when (invoice-suggested-tip-amounts invoice)
          (push (cons "suggested_tip_amounts"
                      (json:encode-to-string (invoice-suggested-tip-amounts invoice))) params))
        (when (invoice-provider-data invoice)
          (push (cons "provider_data" (invoice-provider-data invoice)) params))
        (when (invoice-photo-url invoice)
          (push (cons "photo_url" (invoice-photo-url invoice)) params))
        (when (invoice-photo-size invoice)
          (push (cons "photo_size" (invoice-photo-size invoice)) params))
        (when (invoice-photo-width invoice)
          (push (cons "photo_width" (invoice-photo-width invoice)) params))
        (when (invoice-photo-height invoice)
          (push (cons "photo_height" (invoice-photo-height invoice)) params))
        (when (invoice-need-name invoice)
          (push (cons "need_name" "true") params))
        (when (invoice-need-phone-number invoice)
          (push (cons "need_phone_number" "true") params))
        (when (invoice-need-email invoice)
          (push (cons "need_email" "true") params))
        (when (invoice-need-shipping-address invoice)
          (push (cons "need_shipping_address" "true") params))
        (when (invoice-send-phone-number-to-provider invoice)
          (push (cons "send_phone_number_to_provider" "true") params))
        (when (invoice-send-email-to-provider invoice)
          (push (cons "send_email_to_provider" "true") params))
        (when (invoice-is-flexible invoice)
          (push (cons "is_flexible" "true") params))
        (when start-parameter
          (push (cons "start_parameter" start-parameter) params))
        (when disable-notification
          (push (cons "disable_notification" "true") params))
        (when protect-content
          (push (cons "protect_content" "true") params))
        (when allow-paid-broadcast
          (push (cons "allow_paid_broadcast" "true") params))
        (when message-effect-id
          (push (cons "message_effect_id" message-effect-id) params))
        (when reply-to-message-id
          (push (cons "reply_to_message_id" reply-to-message-id) params))
        (when reply-markup
          (push (cons "reply_markup" (json:encode-to-string reply-markup)) params))

        ;; Make API call
        (let ((result (make-api-call connection "sendInvoice" params)))
          (if result
              (progn
                (log-message :info "Invoice sent successfully to chat ~A" chat-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error sending invoice: ~A" (princ-to-string e))
      nil)))

(defun create-invoice-link (invoice &key business-connection-id start-parameter)
  "Create a link for an invoice that users can open to pay.

   INVOICE: Invoice object created with MAKE-INVOICE
   BUSINESS-CONNECTION-ID: Optional business connection ID
   START-PARAMETER: Optional deep-linking parameter

   Returns the invoice link as a string on success, or NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (prices-json (loop for price in (invoice-prices invoice)
                                collect `(:label ,(labeled-price-label price)
                                         :amount ,(labeled-price-amount price))))
             (params `(("title" . ,(invoice-title invoice))
                       ("description" . ,(invoice-description invoice))
                       ("payload" . ,(invoice-payload invoice))
                       ("currency" . ,(invoice-currency invoice))
                       ("prices" . ,(json:encode-to-string prices-json)))))
        ;; Add optional parameters
        (when (invoice-provider-token invoice)
          (push (cons "provider_token" (invoice-provider-token invoice)) params))
        (when business-connection-id
          (push (cons "business_connection_id" business-connection-id) params))
        (when start-parameter
          (push (cons "start_parameter" start-parameter) params))
        (when (invoice-subscription-period invoice)
          (push (cons "subscription_period" (invoice-subscription-period invoice)) params))
        (when (invoice-max-tip-amount invoice)
          (push (cons "max_tip_amount" (invoice-max-tip-amount invoice)) params))
        (when (invoice-suggested-tip-amounts invoice)
          (push (cons "suggested_tip_amounts"
                      (json:encode-to-string (invoice-suggested-tip-amounts invoice))) params))
        (when (invoice-provider-data invoice)
          (push (cons "provider_data" (invoice-provider-data invoice)) params))
        (when (invoice-photo-url invoice)
          (push (cons "photo_url" (invoice-photo-url invoice)) params))
        (when (invoice-photo-size invoice)
          (push (cons "photo_size" (invoice-photo-size invoice)) params))
        (when (invoice-photo-width invoice)
          (push (cons "photo_width" (invoice-photo-width invoice)) params))
        (when (invoice-photo-height invoice)
          (push (cons "photo_height" (invoice-photo-height invoice)) params))
        (when (invoice-need-name invoice)
          (push (cons "need_name" "true") params))
        (when (invoice-need-phone-number invoice)
          (push (cons "need_phone_number" "true") params))
        (when (invoice-need-email invoice)
          (push (cons "need_email" "true") params))
        (when (invoice-need-shipping-address invoice)
          (push (cons "need_shipping_address" "true") params))
        (when (invoice-send-phone-number-to-provider invoice)
          (push (cons "send_phone_number_to_provider" "true") params))
        (when (invoice-send-email-to-provider invoice)
          (push (cons "send_email_to_provider" "true") params))
        (when (invoice-is-flexible invoice)
          (push (cons "is_flexible" "true") params))

        ;; Make API call
        (let ((result (make-api-call connection "createInvoiceLink" params)))
          (if result
              (progn
                (log-message :info "Invoice link created successfully")
                result)
              nil)))
    (error (e)
      (log-message :error "Error creating invoice link: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Telegram Stars Functions
;;; ======================================================================

(defun refund-star-payment (user-id telegram-payment-charge-id)
  "Refund a successful payment made in Telegram Stars.

   USER-ID: Identifier of the user whose payment will be refunded
   TELEGRAM-PAYMENT-CHARGE-ID: Telegram payment identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_id" . ,user-id)
                       ("telegram_payment_charge_id" . ,telegram-payment-charge-id))))
        (let ((result (make-api-call connection "refundStarPayment" params)))
          (if result
              (progn
                (log-message :info "Star payment refunded successfully for user ~A" user-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error refunding star payment: ~A" (princ-to-string e))
      nil)))

(defun gift-premium-subscription (user-id month-count star-count &key text text-parse-mode text-entities)
  "Gift a Telegram Premium subscription to a user paid in Telegram Stars.

   USER-ID: Unique identifier of the target user
   MONTH-COUNT: Number of months (3, 6, or 12)
   STAR-COUNT: Number of Telegram Stars to pay
   TEXT: Optional text shown with service message
   TEXT-PARSE-MODE: Optional parse mode (HTML, Markdown, etc.)
   TEXT-ENTITIES: Optional list of message entities

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_id" . ,user-id)
                       ("month_count" . ,month-count)
                       ("star_count" . ,star-count))))
        ;; Add optional parameters
        (when text
          (push (cons "text" text) params))
        (when text-parse-mode
          (push (cons "text_parse_mode" text-parse-mode) params))
        (when text-entities
          (push (cons "text_entities" (json:encode-to-string text-entities)) params))

        (let ((result (make-api-call connection "giftPremiumSubscription" params)))
          (if result
              (progn
                (log-message :info "Premium subscription gifted to user ~A (~A months)" user-id month-count)
                t)
              nil)))
    (error (e)
      (log-message :error "Error gifting premium subscription: ~A" (princ-to-string e))
      nil)))

(defun get-business-account-star-balance (business-connection-id)
  "Get the current Telegram Star balance of a managed business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection

   Returns star-balance object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id))))
        (let ((result (make-api-call connection "getBusinessAccountStarBalance" params)))
          (if result
              (make-instance 'star-balance
                             :amount (or (gethash "amount" result) 0))
              nil)))
    (error (e)
      (log-message :error "Error getting star balance: ~A" (princ-to-string e))
      nil)))

(defun transfer-business-account-stars (business-connection-id star-count)
  "Transfer Telegram Stars from business account balance to bot balance.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection
   STAR-COUNT: Number of Telegram Stars to transfer (1-10000)

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id)
                       ("star_count" . ,star-count))))
        (let ((result (make-api-call connection "transferBusinessAccountStars" params)))
          (if result
              (progn
                (log-message :info "Transferred ~A stars from business account ~A"
                             star-count business-connection-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error transferring stars: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Payment Helpers
;;; ======================================================================

(defun create-subscription-invoice (title description payload currency monthly-price
                                    &key months provider-token photo-url)
  "Create an invoice for a recurring subscription.

   TITLE: Product name
   DESCRIPTION: Product description
   PAYLOAD: Invoice payload
   CURRENCY: Three-letter ISO currency code
   MONTHLY-PRICE: Price per month in smallest currency units
   MONTHS: Number of months (default 1)
   PROVIDER-TOKEN: Optional payment provider token
   PHOTO-URL: Optional product photo URL

   Returns an invoice object configured for subscription billing."
  (let* ((total-price (* monthly-price (or months 1)))
         (subscription-period (* months 30 24 60 60)) ; Approximate seconds
         (prices (list (make-labeled-price
                        (format nil "~A month~A subscription" months (if (> months 1) "s" ""))
                        total-price))))
    (make-invoice :title title
                  :description description
                  :payload payload
                  :provider-token provider-token
                  :currency currency
                  :prices prices
                  :subscription-period subscription-period
                  :photo-url photo-url)))

(defun create-star-invoice (title description star-count &key payload photo-url)
  "Create an invoice for Telegram Stars purchase.

   TITLE: Product name
   DESCRIPTION: Product description
   STAR-COUNT: Number of Telegram Stars
   PAYLOAD: Optional invoice payload
   PHOTO-URL: Optional product photo URL

   Returns an invoice object for stars purchase."
  (let ((prices (list (make-labeled-price "Telegram Stars" star-count))))
    (make-invoice :title title
                  :description description
                  :payload (or payload "stars_purchase")
                  :currency "XTR" ; Telegram Stars currency code
                  :prices prices
                  :photo-url photo-url)))

;;; ======================================================================
;;; Global State
;;; ======================================================================

(defvar *supported-currencies*
  '("USD" "EUR" "GBP" "RUB" "CNY" "JPY" "INR" "BRL" "TRY" "KRW" "XTR")
  "List of supported currency codes including XTR for Telegram Stars")

(defvar *max-tip-presets*
  '(100 500 1000 5000 10000)
  "Default tip amount presets in smallest currency units")
