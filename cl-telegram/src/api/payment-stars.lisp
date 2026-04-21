;;; payment-stars.lisp --- Telegram Stars payment system for v0.31.0
;;;
;;; Provides support for:
;;; - Star invoice creation and management
;;; - Star payment processing
;;; - Refund handling
;;; - Paid media support
;;; - Star Giveaway functionality
;;;
;;; Version: 0.31.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Star Invoice Management
;;; ============================================================================

(defclass star-invoice ()
  ((invoice-id :initarg :invoice-id :accessor star-invoice-id)
   (amount :initarg :amount :accessor star-invoice-amount)
   (description :initarg :description :accessor star-invoice-description)
   (payload :initarg :payload :accessor star-invoice-payload)
   (provider-token :initarg :provider-token :initform nil :accessor star-invoice-provider-token)
   (created-at :initarg :created-at :accessor star-invoice-created-at)
   (expires-at :initarg :expires-at :accessor star-invoice-expires-at)
   (status :initarg :status :initform :pending :accessor star-invoice-status)
   (paid-at :initarg :paid-at :initform nil :accessor star-invoice-paid-at)
   (payment-id :initarg :payment-id :initform nil :accessor star-invoice-payment-id)))

(defvar *star-invoices* (make-hash-table :test 'equal)
  "Hash table storing created star invoices")

(defun create-star-invoice (amount &key (description nil) (payload nil) (provider-token nil) (expires-in 3600))
  "Create a Telegram Stars invoice.

   Args:
     amount: Amount in Stars (integer)
     description: Optional invoice description
     payload: Optional bot-defined payload (max 128 bytes)
     provider-token: Optional payment provider token
     expires-in: Invoice validity in seconds (default: 1 hour)

   Returns:
     Star-invoice instance

   Example:
     (create-star-invoice 100 :description \"Premium Feature\" :payload \"user_123\")"
  (let* ((invoice-id (format nil "invoice_~A_~A" (get-universal-time) (random (expt 2 32))))
         (now (get-universal-time))
         (invoice (make-instance 'star-invoice
                                 :invoice-id invoice-id
                                 :amount amount
                                 :description (or description "")
                                 :payload (or payload "")
                                 :provider-token provider-token
                                 :created-at now
                                 :expires-at (+ now expires-in))))
    (setf (gethash invoice-id *star-invoices*) invoice)
    (log:info "Star invoice created: ~A (amount=~D stars)" invoice-id amount)
    invoice))

(defun send-star-invoice (chat-id invoice-id &key (message-text nil) (reply-markup nil))
  "Send a star invoice to a chat.

   Args:
     chat-id: Target chat identifier
     invoice-id: Invoice identifier from create-star-invoice
     message-text: Optional message text
     reply-markup: Optional reply keyboard

   Returns:
     Sent message object on success

   Example:
     (send-star-invoice chat-id \"invoice_123\" :message-text \"Purchase Premium\")"
  (let ((invoice (gethash invoice-id *star-invoices*)))
    (unless invoice
      (return-from send-star-invoice (values nil "Invoice not found")))

    ;; Check if invoice is still valid
    (when (>= (get-universal-time) (star-invoice-expires-at invoice))
      (setf (star-invoice-status invoice) :expired)
      (return-from send-star-invoice (values nil "Invoice expired")))

    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'messages.sendInvoice
                                        :peer (make-peer-chat-id chat-id)
                                        :invoice (make-tl-object 'invoice
                                                                 :title (or message-text "Payment")
                                                                 :description (star-invoice-description invoice)
                                                                 :provider-token (or (star-invoice-provider-token invoice) "")
                                                                 :start-parameter "star_payment"
                                                                 :currency "XTR"
                                                                 :prices (list (make-tl-object 'labeled-price
                                                                                               :label "Telegram Stars"
                                                                                               :amount (star-invoice-amount invoice))))
                                        :reply-markup reply-markup)))
          (let ((result (rpc-call connection request :timeout 30000)))
            (when (and result (getf result :id))
              result)))
      (t (e)
        (log:error "Send star invoice failed: ~A" e)
        (values nil e)))))

(defun get-invoice-status (invoice-id)
  "Get status of a star invoice.

   Args:
     invoice-id: Invoice identifier

   Returns:
     Invoice status keyword

   Example:
     (get-invoice-status \"invoice_123\")"
  (let ((invoice (gethash invoice-id *star-invoices*)))
    (unless invoice
      (return-from get-invoice-status :not-found))

    ;; Check expiration
    (when (and (eq (star-invoice-status invoice) :pending)
               (>= (get-universal-time) (star-invoice-expires-at invoice)))
      (setf (star-invoice-status invoice) :expired))

    (star-invoice-status invoice)))

;;; ============================================================================
;;; Section 2: Star Payment Processing
;;; ============================================================================

(defclass star-payment ()
  ((payment-id :initarg :payment-id :accessor star-payment-id)
   (invoice-id :initarg :invoice-id :accessor star-payment-invoice-id)
   (user-id :initarg :user-id :accessor star-payment-user-id)
   (chat-id :initarg :chat-id :accessor star-payment-chat-id)
   (amount :initarg :amount :accessor star-payment-amount)
   (status :initarg :status :accessor star-payment-status)
   (created-at :initarg :created-at :accessor star-payment-created-at)
   (transaction-id :initarg :transaction-id :accessor star-payment-transaction-id)
   (refund-id :initarg :refund-id :initform nil :accessor star-payment-refund-id)))

(defvar *star-payments* (make-hash-table :test 'equal)
  "Hash table storing star payments")

(defun process-star-payment (invoice-id user-id chat-id)
  "Process a star payment.

   Args:
     invoice-id: Invoice identifier
     user-id: Payer user identifier
     chat-id: Chat where payment was made

   Returns:
     Star-payment instance on success

   Example:
     (process-star-payment \"invoice_123\" user-id chat-id)"
  (let ((invoice (gethash invoice-id *star-invoices*)))
    (unless invoice
      (return-from process-star-payment (values nil "Invoice not found")))

    ;; Check invoice status
    (case (star-invoice-status invoice)
      (:paid (return-from process-star-payment (values nil "Already paid")))
      (:expired (return-from process-star-payment (values nil "Invoice expired")))
      (:refunded (return-from process-star-payment (values nil "Invoice refunded"))))

    (let* ((payment-id (format nil "payment_~A_~A" (get-universal-time) (random (expt 2 32))))
           (payment (make-instance 'star-payment
                                   :payment-id payment-id
                                   :invoice-id invoice-id
                                   :user-id user-id
                                   :chat-id chat-id
                                   :amount (star-invoice-amount invoice)
                                   :status :completed
                                   :created-at (get-universal-time)
                                   :transaction-id (format nil "tx_~A" (get-universal-time)))))

      ;; Update invoice status
      (setf (star-invoice-status invoice) :paid
            (star-invoice-paid-at invoice) (get-universal-time)
            (star-invoice-payment-id invoice) payment-id)

      ;; Store payment
      (setf (gethash payment-id *star-payments*) payment)

      (log:info "Star payment processed: ~A (amount=~D, user=~D)" payment-id (star-invoice-amount invoice) user-id)
      payment)))

(defun get-star-balance (&key (user-id nil))
  "Get Telegram Stars balance.

   Args:
     user-id: Optional user ID (defaults to current user)

   Returns:
     Plist with balance information

   Example:
     (get-star-balance)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'payments.getStarsBalance' :user-id (or user-id nil))))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when result
            (list :balance (getf result :balance 0)
                  :pending (getf result :pending 0)
                  :total-earned (getf result :total-earned 0)
                  :total-spent (getf result :total-spent 0)))))
    (t (e)
      (log:error "Get star balance failed: ~A" e)
      ;; Return mock data for development
      (list :balance 0 :pending 0 :total-earned 0 :total-spent 0)))))

(defun send-star-payment (user-id amount &key (message nil) (chat-id nil))
  "Send stars to a user.

   Args:
     user-id: Recipient user ID
     amount: Amount in stars
     message: Optional message to include
     chat-id: Optional chat ID for context

   Returns:
     T on success

   Example:
     (send-star-payment 123456 50 :message \"Thank you!\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'payments.sendStars
                                      :user-id (make-tl-object 'input-user :user-id user-id)
                                      :amount amount
                                      :message (or message ""))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when result t)))
    (t (e)
      (log:error "Send star payment failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 3: Star Transactions
;;; ============================================================================

(defun get-star-transactions (&key (limit 50) (offset 0))
  "Get star transaction history.

   Args:
     limit: Maximum number of transactions (default: 50)
     offset: Offset for pagination (default: 0)

   Returns:
     List of transaction plists

   Example:
     (get-star-transactions :limit 100 :offset 0)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'payments.getStarsTransactions
                                      :limit limit
                                      :offset offset)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when (and result (getf result :transactions))
            (mapcar (lambda (tx)
                      (list :id (getf tx :id)
                            :amount (getf tx :amount)
                            :type (getf tx :type)
                            :date (getf tx :date)
                            :peer (getf tx :peer)
                            :description (getf tx :description)))
                    (getf result :transactions)))))
    (t (e)
      (log:error "Get star transactions failed: ~A" e)
      nil)))

(defun refund-star-payment (payment-id &key (reason nil))
  "Refund a star payment.

   Args:
     payment-id: Payment identifier
     reason: Optional refund reason

   Returns:
     T on success, NIL with error message on failure

   Example:
     (refund-star-payment \"payment_123\" :reason \"User requested refund\")"
  (let ((payment (gethash payment-id *star-payments*)))
    (unless payment
      (return-from refund-star-payment (values nil "Payment not found")))

    ;; Check payment status
    (unless (eq (star-payment-status payment) :completed)
      (return-from refund-star-payment (values nil "Payment not completed")))

    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'payments.refundStarsCharge
                                        :charge-id (star-payment-transaction-id payment)
                                        :reason (or reason ""))))
          (let ((result (rpc-call connection request :timeout 30000)))
            (when result
              ;; Update payment status
              (setf (star-payment-status payment) :refunded
                    (star-payment-refund-id payment) (format nil "refund_~A" (get-universal-time)))
              (log:info "Star payment refunded: ~A (reason=~A)" payment-id reason)
              t)))
      (t (e)
        (log:error "Refund star payment failed: ~A" e)
        (values nil e)))))

;;; ============================================================================
;;; Section 4: Paid Media Support
;;; ============================================================================

(defclass paid-media ()
  ((type :initarg :type :accessor paid-media-type)
   (media-id :initarg :media-id :accessor paid-media-media-id)
   (preview-media-id :initarg :preview-media-id :initform nil :accessor paid-media-preview-media-id)
   (star-amount :initarg :star-amount :accessor paid-media-star-amount)
   (description :initarg :description :accessor paid-media-description)))

(defun make-paid-media-info (type media-id star-amount &key (description nil) (preview-media-id nil))
  "Create paid media information.

   Args:
     type: Media type (\"photo\", \"video\")
     media-id: File ID of the media
     star-amount: Price in stars
     description: Optional media description
     preview-media-id: Optional preview/thumbnail media ID

   Returns:
     Paid-media instance

   Example:
     (make-paid-media-info \"photo\" \"AgAD1234\" 50 :description \"Exclusive content\")"
  (make-instance 'paid-media
                 :type type
                 :media-id media-id
                 :star-amount star-amount
                 :description (or description "")
                 :preview-media-id preview-media-id))

(defun send-paid-media (chat-id paid-media-info &key (caption nil) (reply-markup nil))
  "Send paid media to a chat.

   Args:
     chat-id: Target chat ID
     paid-media-info: Paid-media instance from make-paid-media-info
     caption: Optional caption
     reply-markup: Optional reply keyboard

   Returns:
     Sent message object

   Example:
     (send-paid-media chat-id media-info :caption \"Check this out!\")"
  (handler-case
      (let* ((connection (get-connection))
             (media (if (typep paid-media-info 'paid-media)
                       paid-media-info
                       (return-from send-paid-media (values nil "Invalid paid-media-info"))))
             (request (make-tl-object 'messages.sendMedia
                                      :peer (make-peer-chat-id chat-id)
                                      :media (make-tl-object 'inputMediaPaidMedia
                                                             :star-amount (paid-media-star-amount media)
                                                             :paid-media (list (make-tl-object 'inputPaidMediaPhoto
                                                                                               :media (paid-media-media-id media))))
                                      :message (or caption (paid-media-description media))
                                      :reply-markup reply-markup)))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when (and result (getf result :id))
            result)))
    (t (e)
      (log:error "Send paid media failed: ~A" e)
      (values nil e))))

(defun get-paid-media-post (chat-id message-id)
  "Get paid media post details.

   Args:
     chat-id: Chat ID where post was sent
     message-id: Message ID of the paid media post

   Returns:
     Plist with post details

   Example:
     (get-paid-media-post chat-id message-id)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'channels.getMessages
                                      :channel (make-peer-chat-id chat-id)
                                      :id (list message-id))))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when (and result (getf result :messages))
            (let ((message (first (getf result :messages))))
              (when message
                (list :message-id (getf message :id)
                      :date (getf message :date)
                      :media (getf message :media)
                      :views (getf message :views 0)
                      :forwards (getf message :forwards 0)))))))
    (t (e)
      (log:error "Get paid media post failed: ~A" e)
      nil)))

(defun get-paid-media (media-id)
  "Get paid media information by ID.

   Args:
     media-id: Paid media identifier

   Returns:
     Paid-media instance or NIL

   Example:
     (get-paid-media \"media_123\")"
  (declare (ignore media-id))
  ;; Placeholder - implement based on your storage mechanism
  (log:info "Get paid media: ~A" media-id)
  nil)

(defun list-paid-media (&key (limit 50) (offset 0))
  "List all paid media posts.

   Args:
     limit: Maximum number of results (default: 50)
     offset: Offset for pagination (default: 0)

   Returns:
     List of paid-media plists

   Example:
     (list-paid-media :limit 20)"
  (declare (ignore limit offset))
  ;; Placeholder - implement based on your storage mechanism
  (log:info "List paid media (limit=~D, offset=~D)" limit offset)
  nil)

(defun delete-paid-media (media-id)
  "Delete a paid media post.

   Args:
     media-id: Paid media identifier

   Returns:
     T on success, NIL on failure

   Example:
     (delete-paid-media \"media_123\")"
  (declare (ignore media-id))
  ;; Placeholder - implement based on your storage mechanism
  (log:info "Delete paid media: ~A" media-id)
  nil)

(defun update-paid-media (media-id &key (star-amount nil) (description nil))
  "Update paid media information.

   Args:
     media-id: Paid media identifier
     star-amount: New star amount (optional)
     description: New description (optional)

   Returns:
     T on success, NIL on failure

   Example:
     (update-paid-media \"media_123\" :star-amount 100)"
  (declare (ignore media-id star-amount description))
  ;; Placeholder - implement based on your storage mechanism
  (log:info "Update paid media: ~A (star=~A, desc=~A)" media-id star-amount description)
  nil)

;;; ============================================================================
;;; Section 5: Star Giveaway
;;; ============================================================================

(defclass star-giveaway ()
  ((giveaway-id :initarg :giveaway-id :accessor giveaway-id)
   (star-amount :initarg :star-amount :accessor giveaway-star-amount)
   (winner-count :initarg :winner-count :accessor giveaway-winner-count)
   (duration :initarg :duration :accessor giveaway-duration)
   (chat-id :initarg :chat-id :accessor giveaway-chat-id)
   (creator-id :initarg :creator-id :accessor giveaway-creator-id)
   (status :initarg :status :initform :active :accessor giveaway-status)
   (participants :initarg :participants :initform (make-hash-table :test 'equal) :accessor giveaway-participants)
   (winners :initarg :winners :initform nil :accessor giveaway-winners)
   (created-at :initarg :created-at :accessor giveaway-created-at)
   (ends-at :initarg :ends-at :accessor giveaway-ends-at)))

(defvar *star-giveaways* (make-hash-table :test 'equal)
  "Hash table storing star giveaways")

(defun create-star-giveaway (star-amount winner-count duration &key (chat-id nil) (title nil) (description nil))
  "Create a star giveaway.

   Args:
     star-amount: Total stars to give away
     winner-count: Number of winners
     duration: Giveaway duration in seconds
     chat-id: Optional chat ID (for channel giveaways)
     title: Optional giveaway title
     description: Optional description

   Returns:
     Star-giveaway instance

   Example:
     (create-star-giveaway 1000 5 (* 7 24 60 60) :title \"Weekly Giveaway\")"
  (let* ((giveaway-id (format nil "giveaway_~A_~A" (get-universal-time) (random (expt 2 32))))
         (now (get-universal-time))
         (giveaway (make-instance 'star-giveaway
                                  :giveaway-id giveaway-id
                                  :star-amount star-amount
                                  :winner-count winner-count
                                  :duration duration
                                  :chat-id chat-id
                                  :creator-id (get-current-user-id)
                                  :created-at now
                                  :ends-at (+ now duration))))
    (setf (gethash giveaway-id *star-giveaways*) giveaway)
    (log:info "Star giveaway created: ~A (stars=~D, winners=~D, duration=~D days)"
              giveaway-id star-amount winner-count (/ duration 86400))
    giveaway))

(defun join-giveaway (giveaway-id user-id)
  "Join a star giveaway.

   Args:
     giveaway-id: Giveaway identifier
     user-id: User ID joining the giveaway

   Returns:
     T on success

   Example:
     (join-giveaway \"giveaway_123\" user-id)"
  (let ((giveaway (gethash giveaway-id *star-giveaways*)))
    (unless giveaway
      (return-from join-giveaway (values nil "Giveaway not found")))

    ;; Check if giveaway is still active
    (unless (eq (giveaway-status giveaway) :active)
      (return-from join-giveaway (values nil "Giveaway is not active")))

    ;; Check if giveaway has ended
    (when (>= (get-universal-time) (giveaway-ends-at giveaway))
      (setf (giveaway-status giveaway) :ended)
      (return-from join-giveaway (values nil "Giveaway has ended")))

    ;; Add participant
    (setf (gethash user-id (giveaway-participants giveaway)) t)
    (log:info "User ~D joined giveaway ~A" user-id giveaway-id)
    t))

(defun select-giveaway-winners (giveaway-id)
  "Select random winners for a giveaway.

   Args:
     giveaway-id: Giveaway identifier

   Returns:
     List of winner user IDs

   Example:
     (select-giveaway-winners \"giveaway_123\")"
  (let ((giveaway (gethash giveaway-id *star-giveaways*)))
    (unless giveaway
      (return-from select-giveaway-winners (values nil "Giveaway not found")))

    ;; Check if giveaway has ended
    (when (and (eq (giveaway-status giveaway) :active)
               (< (get-universal-time) (giveaway-ends-at giveaway)))
      (return-from select-giveaway-winners (values nil "Giveaway has not ended yet")))

    ;; Collect participants
    (let ((participants (loop for user-id being the hash-keys of (giveaway-participants giveaway)
                              collect user-id)))
      (when (null participants)
        (return-from select-giveaway-winners (values nil "No participants")))

      ;; Shuffle and select winners
      (setf participants (shuffle-list participants))
      (let ((winners (subseq participants 0 (min (giveaway-winner-count giveaway) (length participants)))))
        (setf (giveaway-winners giveaway) winners
              (giveaway-status giveaway) :completed)

        ;; Distribute stars to winners
        (let ((stars-per-winner (floor (giveaway-star-amount giveaway) (length winners))))
          (dolist (winner-id winners)
            (send-star-payment winner-id stars-per-winner :message (format nil "You won ~D stars in giveaway!" stars-per-winner))))

        (log:info "Giveaway ~A completed: ~D winners selected" giveaway-id (length winners))
        winners)))))

;; Helper function
(defun shuffle-list (list)
  "Randomly shuffle a list using Fisher-Yates algorithm.

   Args:
     list: List to shuffle

   Returns:
     Shuffled list"
  (let* ((array (coerce list 'vector))
         (n (length array)))
    (loop for i from (- n 1) downto 1
          do (let ((j (random (1+ i))))
               (rotatef (aref array i) (aref array j))))
    (coerce array 'list)))

(defun get-giveaway-status (giveaway-id)
  "Get giveaway status and statistics.

   Args:
     giveaway-id: Giveaway identifier

   Returns:
     Plist with giveaway information

   Example:
     (get-giveaway-status \"giveaway_123\")"
  (let ((giveaway (gethash giveaway-id *star-giveaways*)))
    (unless giveaway
      (return-from get-giveaway-status nil))

    (let ((participants (loop for _ being the hash-keys of (giveaway-participants giveaway)
                              counting _ into count
                              finally (return count))))
      (list :giveaway-id giveaway-id
            :star-amount (giveaway-star-amount giveaway)
            :winner-count (giveaway-winner-count giveaway)
            :participant-count participants
            :status (giveaway-status giveaway)
            :created-at (giveaway-created-at giveaway)
            :ends-at (giveaway-ends-at giveaway)
            :winners (giveaway-winners giveaway)))))

;;; ============================================================================
;;; Section 6: Convert Star Gift
;;; ============================================================================

(defun convert-star-gift (gift-id &key (to-currency nil))
  "Convert a received star gift to balance.

   Args:
     gift-id: Gift identifier
     to-currency: Optional target currency (default: keep as stars)

   Returns:
     T on success

   Example:
     (convert-star-gift \"gift_123\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'payments.convertStarGift
                                      :gift-id gift-id)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when result t)))
    (t (e)
      (log:error "Convert star gift failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 7: Statistics and Management
;;; ============================================================================

(defun get-payment-stats (&key (period :all))
  "Get payment statistics.

   Args:
     period: Time period (:day, :week, :month, :all)

   Returns:
     Plist with payment statistics

   Example:
     (get-payment-stats :period :week)"
  (let ((total-payments 0)
        (total-stars 0)
        (completed 0)
        (refunded 0)
        (pending 0))

    (maphash (lambda (k v)
               (declare (ignore k))
               (incf total-payments)
               (incf total-stars (star-payment-amount v))
               (case (star-payment-status v)
                 (:completed (incf completed))
                 (:refunded (incf refunded))
                 (t (incf pending))))
             *star-payments*)

    (list :total-payments total-payments
          :total-stars total-stars
          :completed completed
          :refunded refunded
          :pending pending
          :period period)))

(defun get-giveaway-stats ()
  "Get giveaway statistics.

   Returns:
     Plist with giveaway statistics

   Example:
     (get-giveaway-stats)"
  (let ((total-giveaways 0)
        (active 0)
        (completed 0)
        (ended 0)
        (total-participants 0)
        (total-stars 0))

    (maphash (lambda (k v)
               (declare (ignore k))
               (incf total-giveaways)
               (incf total-stars (giveaway-star-amount v))
               (let ((participants (loop for _ being the hash-keys of (giveaway-participants v)
                                         counting _ into count
                                         finally (return count))))
                 (incf total-participants participants))
               (case (giveaway-status v)
                 (:active (incf active))
                 (:completed (incf completed))
                 (:ended (incf ended))))
             *star-giveaways*)

    (list :total-giveaways total-giveaways
          :active active
          :completed completed
          :ended ended
          :total-participants total-participants
          :total-stars-distributed total-stars)))

;;; ============================================================================
;;; Section 8: Initialization
;;; ============================================================================

(defun initialize-payment-stars ()
  "Initialize payment and stars system.

   Returns:
     T on success"
  (handler-case
      (progn
        (log:info "Payment and stars system initialized")
        t)
    (t (e)
      (log:error "Failed to initialize payment system: ~A" e)
      nil)))

(defun shutdown-payment-stars ()
  "Shutdown payment and stars system.

   Returns:
     T on success"
  (handler-case
      (progn
        ;; Clear temporary data if needed
        (log:info "Payment and stars system shutdown complete")
        t)
    (t (e)
      (log:error "Failed to shutdown payment system: ~A" e)
      nil)))

;;; Export symbols
(export '(;; Invoice
          star-invoice
          create-star-invoice
          send-star-invoice
          get-invoice-status

          ;; Payment
          star-payment
          process-star-payment
          get-star-balance
          send-star-payment

          ;; Transactions
          get-star-transactions
          refund-star-payment

          ;; Paid Media
          paid-media
          make-paid-media-info
          send-paid-media
          get-paid-media-post

          ;; Giveaway
          star-giveaway
          create-star-giveaway
          join-giveaway
          select-giveaway-winners
          get-giveaway-status

          ;; Star Gift
          convert-star-gift

          ;; Statistics
          get-payment-stats
          get-giveaway-stats

          ;; Initialization
          initialize-payment-stars
          shutdown-payment-stars

          ;; State
          *star-invoices*
          *star-payments*
          *star-giveaways*))
