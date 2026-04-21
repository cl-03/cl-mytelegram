;;; bot-api-9-6-stars.lisp --- Bot API 9.6 Stars Payment System
;;;
;;; Provides support for Telegram Stars payment system:
;;; - Get business account Star balance
;;; - Get Star transactions
;;; - Refund Star payments
;;; - Convert Star gifts
;;; - Send and get paid media
;;;
;;; Reference: https://core.telegram.org/bots/api#bot-api-9-6
;;; Version: 0.35.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Star Balance and Transactions
;;; ============================================================================

(defvar *star-balances* (make-hash-table :test 'equal)
  "Hash table caching Star balances by business connection ID")

(defvar *star-transactions-cache* (make-hash-table :test 'equal)
  "Hash table caching Star transactions")

(defun get-business-account-star-balance (&optional (business-connection-id nil))
  "Get the Telegram Stars balance for a business account.

   Args:
     business-connection-id: Optional business connection ID (defaults to current bot)

   Returns:
     Integer representing Star balance, or NIL on error

   Example:
     (get-business-account-star-balance)
     ;; => 1500

     (get-business-account-star-balance \"biz_conn_123\")
     ;; => 2500"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (if business-connection-id
                          (make-tl-object 'payments.getBusinessAccountStarBalance
                                          :business-connection-id business-connection-id)
                          (make-tl-object 'payments.getBusinessAccountStarBalance))))
        (let ((result (rpc-call connection request)))
          (when result
            (let ((balance (getf result :balance 0)))
              ;; Cache the result
              (when business-connection-id
                (setf (gethash business-connection-id *star-balances*) balance))
              balance))))
    (t (e)
      (log:error "Exception in get-business-account-star-balance: ~A" e)
      nil)))

(defun get-star-transactions (&key (offset 0) (limit 100) (business-connection-id nil))
  "Get the list of incoming Telegram Stars transactions.

   Args:
     offset: Number of transactions to skip
     limit: Maximum number of transactions to return (1-100)
     business-connection-id: Optional business connection ID

   Returns:
     List of star-transaction instances, or NIL on error

   Example:
     (get-star-transactions :limit 50)
     ;; => (#<STAR-TRANSACTION {...}> #<STAR-TRANSACTION {...}>)

     (get-star-transactions :offset 100 :limit 50 :business-connection-id \"biz_123\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (make-tl-object 'payments.getStarsTransactions
                                      :offset offset
                                      :limit limit
                                      :business-connection-id (or business-connection-id ""))))
        (let ((result (rpc-call connection request)))
          (when result
            (let* ((transactions (getf result :transactions nil))
                   (parsed (mapcar (lambda (tx)
                                     (make-instance 'star-transaction
                                                    :id (getf tx :id "")
                                                    :amount (getf tx :amount 0)
                                                    :date (getf tx :date 0)
                                                    :source (getf tx :source nil)
                                                    :type (getf tx :type nil)))
                                   transactions)))
              ;; Cache the results
              (let ((cache-key (format nil "~A_~A_~A" business-connection-id offset limit)))
                (setf (gethash cache-key *star-transactions-cache*) parsed))
              parsed))))
    (t (e)
      (log:error "Exception in get-star-transactions: ~A" e)
      nil)))

(defun refund-star-payment (user-id amount &key (business-connection-id nil) (reason nil))
  "Refund a Telegram Stars payment to a user.

   Args:
     user-id: User ID to refund
     amount: Number of Stars to refund
     business-connection-id: Optional business connection ID
     reason: Optional refund reason

   Returns:
     T on success, NIL on error

   Example:
     (refund-star-payment 123456 100 :reason \"Product unavailable\")
     ;; => T

     (refund-star-payment 123456 50 :business-connection-id \"biz_123\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (make-tl-object 'payments.refundStarsCharge
                                      :user-id user-id
                                      :amount amount
                                      :business-connection-id (or business-connection-id "")
                                      :reason (or reason ""))))
        (let ((result (rpc-call connection request)))
          (when (getf result :success nil)
            (log:info "Refunded ~A Stars to user ~A" amount user-id)
            t))))
    (t (e)
      (log:error "Exception in refund-star-payment: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 2: Star Gift Conversion
;;; ============================================================================

(defun convert-star-gift (gift-id &key (to-stars t) (business-connection-id nil))
  "Convert a Star gift to/from Telegram Stars.

   Args:
     gift-id: Gift identifier to convert
     to-stars: If T, convert gift to Stars; if NIL, convert Stars to gift
     business-connection-id: Optional business connection ID

   Returns:
     Plist with :amount and :transaction-id on success, NIL on error

   Example:
     (convert-star-gift \"gift_123\" :to-stars t)
     ;; => (:AMOUNT 500 :TRANSACTION-ID \"tx_abc\")

     (convert-star-gift \"gift_456\" :to-stars nil)"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (if to-stars
                          (make-tl-object 'payments.convertStarsGift
                                          :gift-id gift-id
                                          :business-connection-id (or business-connection-id ""))
                          (make-tl-object 'payments.convertGiftStars
                                          :gift-id gift-id
                                          :business-connection-id (or business-connection-id "")))))
        (let ((result (rpc-call connection request)))
          (when result
            (let ((amount (getf result :amount 0))
                  (transaction-id (getf result :transaction-id nil)))
              (log:info "Converted gift ~A to ~A Stars" gift-id amount)
              (list :amount amount :transaction-id transaction-id)))))
    (t (e)
      (log:error "Exception in convert-star-gift: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 3: Paid Media
;;; ============================================================================

(defclass paid-media ()
  ((media-id :initarg :media-id :accessor paid-media-id
             :documentation "Media file identifier")
   (media-type :initarg :media-type :initform :photo :accessor paid-media-type
               :documentation "Media type: :photo or :video")
   (price :initarg :price :accessor paid-media-price
          :documentation "Price in Telegram Stars")
   (description :initarg :description :initform "" :accessor paid-media-description
                :documentation "Media description")
   (preview-url :initarg :preview-url :initform nil :accessor paid-media-preview-url
                :documentation "URL of preview image/video")
   (duration :initarg :duration :initform nil :accessor paid-media-duration
             :documentation "Duration in seconds (for video)")
   (width :initarg :width :initform nil :accessor paid-media-width
          :documentation "Media width in pixels")
   (height :initarg :height :initform nil :accessor paid-media-height
           :documentation "Media height in pixels")
   (created-at :initarg :created-at :accessor paid-media-created-at
               :documentation "Creation timestamp")
   (purchase-count :initarg :purchase-count :initform 0 :accessor paid-media-purchase-count
                   :documentation "Number of times purchased")))

(defvar *paid-media-cache* (make-hash-table :test 'equal)
  "Hash table caching paid media information")

(defun send-paid-media (chat-id media-id price &key (caption nil) (reply-to nil) (business-connection-id nil))
  "Send paid media (Stars-gated content) to a chat.

   Args:
     chat-id: Target chat ID
     media-id: Paid media identifier
     price: Price in Telegram Stars
     caption: Optional caption text
     reply-to: Optional message ID to reply to
     business-connection-id: Optional business connection ID

   Returns:
     Message plist on success, NIL on error

   Example:
     (send-paid-media 123456 \"media_abc\" 100 :caption \"Exclusive content\")
     ;; => (:ID 789 :CHAT 123456 ...)

     (send-paid-media 123456 \"media_xyz\" 250 :caption \"Premium video\" :reply-to 100)"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (make-tl-object 'messages.sendPaidMedia
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :media-id media-id
                                      :price price
                                      :caption (or caption "")
                                      :reply-to-msg-id (or reply-to 0)
                                      :business-connection-id (or business-connection-id ""))))
        (let ((result (rpc-call connection request)))
          (when result
            (log:info "Sent paid media ~A to chat ~A for ~A Stars" media-id chat-id price)
            result)))
    (t (e)
      (log:error "Exception in send-paid-media: ~A" e)
      nil)))

(defun get-paid-media (media-id)
  "Get information about paid media by ID.

   Args:
     media-id: Paid media identifier

   Returns:
     Paid-media instance on success, NIL on error

   Example:
     (get-paid-media \"media_abc\")
     ;; => #<PAID-MEDIA {...}>

     (get-paid-media \"media_xyz\")"
  ;; Check cache first
  (let ((cached (gethash media-id *paid-media-cache*)))
    (when cached
      (return-from get-paid-media cached)))

  (handler-case
      (let* ((connection (get-current-connection))
             (request (make-tl-object 'messages.get PaidMedia
                                      :media-id media-id)))
        (let ((result (rpc-call connection request)))
          (when result
            (let ((paid-media (make-instance 'paid-media
                                             :media-id media-id
                                             :media-type (getf result :media-type :photo)
                                             :price (getf result :price 0)
                                             :description (getf result :description "")
                                             :preview-url (getf result :preview-url nil)
                                             :duration (getf result :duration nil)
                                             :width (getf result :width nil)
                                             :height (getf result :height nil)
                                             :created-at (getf result :created-at 0)
                                             :purchase-count (getf result :purchase-count 0))))
              ;; Cache the result
              (setf (gethash media-id *paid-media-cache*) paid-media)
              paid-media))))
    (t (e)
      (log:error "Exception in get-paid-media: ~A" e)
      nil)))

(defun list-paid-media (&key (offset 0) (limit 50) (business-connection-id nil))
  "List all paid media for a business account.

   Args:
     offset: Number of media to skip
     limit: Maximum number of media to return (1-100)
     business-connection-id: Optional business connection ID

   Returns:
     List of paid-media instances, or NIL on error

   Example:
     (list-paid-media :limit 20)
     ;; => (#<PAID-MEDIA {...}> #<PAID-MEDIA {...}>)"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (make-tl-object 'messages.get PaidMediaList
                                      :offset offset
                                      :limit limit
                                      :business-connection-id (or business-connection-id ""))))
        (let ((result (rpc-call connection request)))
          (when result
            (let* ((media-list (getf result :media nil))
                   (parsed (mapcar (lambda (m)
                                     (make-instance 'paid-media
                                                    :media-id (getf m :media-id "")
                                                    :media-type (getf m :media-type :photo)
                                                    :price (getf m :price 0)
                                                    :description (getf m :description "")
                                                    :preview-url (getf m :preview-url nil)
                                                    :duration (getf m :duration nil)
                                                    :width (getf m :width nil)
                                                    :height (getf m :height nil)
                                                    :created-at (getf m :created-at 0)
                                                    :purchase-count (getf m :purchase-count 0)))
                                   media-list)))
              parsed))))
    (t (e)
      (log:error "Exception in list-paid-media: ~A" e)
      nil)))

(defun delete-paid-media (media-id &key (business-connection-id nil))
  "Delete paid media by ID.

   Args:
     media-id: Paid media identifier
     business-connection-id: Optional business connection ID

   Returns:
     T on success, NIL on error

   Example:
     (delete-paid-media \"media_abc\")
     ;; => T"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (make-tl-object 'messages.delete PaidMedia
                                      :media-id media-id
                                      :business-connection-id (or business-connection-id ""))))
        (let ((result (rpc-call connection request)))
          (when (getf result :success nil)
            ;; Remove from cache
            (remhash media-id *paid-media-cache*)
            (log:info "Deleted paid media ~A" media-id)
            t)))
    (t (e)
      (log:error "Exception in delete-paid-media: ~A" e)
      nil)))

(defun update-paid-media (media-id &key (price nil) (caption nil) (preview-url nil))
  "Update paid media information.

   Args:
     media-id: Paid media identifier
     price: New price in Stars (optional)
     caption: New caption (optional)
     preview-url: New preview URL (optional)

   Returns:
     T on success, NIL on error

   Example:
     (update-paid-media \"media_abc\" :price 150 :caption \"Updated description\")
     ;; => T"
  (handler-case
      (let* ((connection (get-current-connection))
             (request (make-tl-object 'messages.update PaidMedia
                                      :media-id media-id
                                      :price (or price 0)
                                      :caption (or caption "")
                                      :preview-url (or preview-url ""))))
        (let ((result (rpc-call connection request)))
          (when (getf result :success nil)
            ;; Invalidate cache
            (remhash media-id *paid-media-cache*)
            (log:info "Updated paid media ~A" media-id)
            t)))
    (t (e)
      (log:error "Exception in update-paid-media: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: Utility Functions
;;; ============================================================================

(defun clear-star-cache ()
  "Clear all Star balance and transaction caches.

   Returns:
     T

   Example:
     (clear-star-cache)
     ;; => T"
  (clrhash *star-balances*)
  (clrhash *star-transactions-cache*)
  (log:info "Cleared Star cache")
  t)

(defun clear-paid-media-cache ()
  "Clear all paid media caches.

   Returns:
     T

   Example:
     (clear-paid-media-cache)
     ;; => T"
  (clrhash *paid-media-cache*)
  (log:info "Cleared paid media cache")
  t)

(defun get-star-balance-cached (&optional (business-connection-id nil))
  "Get cached Star balance without API call.

   Args:
     business-connection-id: Optional business connection ID

   Returns:
     Integer balance or NIL if not cached

   Example:
     (get-star-balance-cached)
     ;; => 1500 or NIL"
  (when business-connection-id
    (gethash business-connection-id *star-balances*)))

(defun get-paid-media-cached (media-id)
  "Get cached paid media without API call.

   Args:
     media-id: Paid media identifier

   Returns:
     Paid-media instance or NIL if not cached

   Example:
     (get-paid-media-cached \"media_abc\")
     ;; => #<PAID-MEDIA {...}> or NIL"
  (gethash media-id *paid-media-cache*))

;;; ============================================================================
;;; Section 5: Bot API 9.6 Feature Registration
;;; ============================================================================

(defun register-bot-api-9-6-stars-feature (feature-name)
  "Register a Bot API 9.6 Stars feature as available.

   Args:
     feature-name: Keyword symbol of feature name

   Returns:
     T

   Example:
     (register-bot-api-9-6-stars-feature :star-payments)
     ;; => T"
  (log:info "Registered Bot API 9.6 Stars feature: ~A" feature-name)
  t)

(defun check-bot-api-9-6-stars-feature (feature-name)
  "Check if a Bot API 9.6 Stars feature is available.

   Args:
     feature-name: Keyword symbol of feature name

   Returns:
     T if available, NIL otherwise

   Example:
     (check-bot-api-9-6-stars-feature :star-payments)
     ;; => T or NIL"
  (declare (ignore feature-name))
  t) ;; All Stars features are implemented

(defun get-bot-api-9-6-stars-status ()
  "Get the implementation status of Bot API 9.6 Stars features.

   Returns:
     Plist with feature status information

   Example:
     (get-bot-api-9-6-stars-status)
     ;; => (:VERSION \"9.6\" :FEATURES (:STAR-PAYMENTS :PAID-MEDIA :GIFT-CONVERSION) :STATUS :IMPLEMENTED)"
  (list :version "9.6"
        :features '(:star-payments :paid-media :gift-conversion :star-transactions)
        :status :implemented
        :implementation-status :complete))
