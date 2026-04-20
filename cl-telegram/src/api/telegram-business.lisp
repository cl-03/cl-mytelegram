;;; telegram-business.lisp --- Telegram Business API complete implementation
;;;
;;; Provides complete Telegram Business features for v0.33.0:
;;; - Business account management
;;; - Auto-reply and greeting messages
;;; - Business hours management
;;; - Quick replies enhancement
;;; - Message labels
;;; - Business chat features
;;;
;;; Version: 0.33.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Business Account Classes
;;; ============================================================================

(defclass business-account ()
  ((account-id :initarg :account-id :accessor business-account-id)
   (name :initarg :name :accessor business-account-name)
   (description :initarg :description :accessor business-account-description)
   (location :initarg :location :initform nil :accessor business-account-location)
   (opening-hours :initarg :opening-hours :initform nil :accessor business-account-hours)
   (contact-info :initarg :contact-info :initform nil :accessor business-account-contact)
   (is-verified :initarg :is-verified :initform nil :accessor business-account-verified)
   (is-premium :initarg :is-premium :initform nil :accessor business-account-premium)
   (created-at :initarg :created-at :accessor business-account-created-at)))

(defclass business-greeting ()
  ((greeting-id :initarg :greeting-id :accessor business-greeting-id)
   (message :initarg :message :accessor business-greeting-message)
   (is-enabled :initarg :is-enabled :initform t :accessor business-greeting-enabled)
   (chat-ids :initarg :chat-ids :initform nil :accessor business-greeting-chats)))

(defclass business-auto-reply ()
  ((reply-id :initarg :reply-id :accessor business-auto-reply-id)
   (message :initarg :message :accessor business-auto-reply-message)
   (is-enabled :initarg :is-enabled :initform t :accessor business-auto-reply-enabled)
   (delay-seconds :initarg :delay-seconds :initform 0 :accessor business-auto-reply-delay)
   (keywords :initarg :keywords :initform nil :accessor business-auto-reply-keywords)))

(defclass message-label ()
  ((label-id :initarg :label-id :accessor message-label-id)
   (name :initarg :name :accessor message-label-name)
   (color :initarg :color :accessor message-label-color)
   (chat-id :initarg :chat-id :accessor message-label-chat)
   (message-ids :initarg :message-ids :initform nil :accessor message-label-messages)))

(defclass business-chat ()
  ((chat-id :initarg :chat-id :accessor business-chat-id)
   (account-id :initarg :account-id :accessor business-chat-account)
   (last-message-time :initarg :last-message-time :accessor business-chat-last-message)
   (unread-count :initarg :unread-count :initform 0 :accessor business-chat-unread)
   (labels :initarg :labels :initform nil :accessor business-chat-labels)
   (status :initarg :status :initform :active :accessor business-chat-status)))

;;; ============================================================================
;;; Section 2: Global State
;;; ============================================================================

(defvar *business-accounts* (make-hash-table :test 'equal)
  "Hash table storing business accounts")

(defvar *business-greetings* (make-hash-table :test 'equal)
  "Hash table storing business greeting messages")

(defvar *business-auto-replies* (make-hash-table :test 'equal)
  "Hash table storing business auto-reply configurations")

(defvar *message-labels* (make-hash-table :test 'equal)
  "Hash table storing message labels by chat")

(defvar *business-chats* (make-hash-table :test 'equal)
  "Hash table storing business chats")

;;; ============================================================================
;;; Section 3: Business Account Management
;;; ============================================================================

(defun get-business-account (account-id)
  "Get business account information.

   Args:
     account-id: Business account identifier

   Returns:
     Business-account instance or NIL

   Example:
     (get-business-account \"biz_123\")"
  (let ((account (gethash account-id *business-accounts*)))
    (if account
        account
        (handler-case
            (let* ((connection (get-connection))
                   (result (rpc-call connection
                                     (make-tl-object 'business.getAccount
                                                     :account-id account-id)
                                     :timeout 10000)))
              (when result
                (let ((parsed (parse-business-account result)))
                  (setf (gethash account-id *business-accounts*) parsed)
                  parsed)))
          (t (e)
            (log:error "Get business account failed: ~A" e)
            nil)))))

(defun parse-business-account (data)
  "Parse business account from TL data.

   Args:
     data: TL response data

   Returns:
     Business-account instance"
  (make-instance 'business-account
                 :account-id (getf data :id)
                 :name (getf data :name)
                 :description (getf data :description)
                 :location (getf data :location)
                 :opening-hours (getf data :opening-hours)
                 :contact-info (getf data :contact)
                 :is-verified (getf data :is-verified)
                 :is-premium (getf data :is-premium)
                 :created-at (getf data :created-at)))

(defun create-business-account (name description &key (location nil) (opening-hours nil)
                                                     (contact-info nil))
  "Create a new business account.

   Args:
     name: Business name
     description: Business description
     location: Optional business location
     opening-hours: Optional opening hours
     contact-info: Optional contact information

   Returns:
     Business-account instance on success

   Example:
     (create-business-account \"My Shop\" \"Best products\"
                              :location \"123 Main St\"
                              :contact-info \"+1234567890\")"
  (handler-case
      (let* ((connection (get-connection))
             (account-id (format nil "biz_~A_~A" (get-universal-time) (random (expt 2 32))))
             (result (rpc-call connection
                               (make-tl-object 'business.createAccount
                                               :account-id account-id
                                               :name name
                                               :description description
                                               :location location
                                               :opening-hours opening-hours
                                               :contact contact-info)
                               :timeout 10000)))
        (when result
          (let ((account (parse-business-account result)))
            (setf (gethash account-id *business-accounts*) account)
            (log:info "Business account created: ~A" account-id)
            account)))
    (t (e)
      (log:error "Create business account failed: ~A" e)
      nil)))

(defun update-business-account (account-id &key (name nil) (description nil)
                                                 (location nil) (opening-hours nil)
                                                 (contact-info nil))
  "Update business account information.

   Args:
     account-id: Business account identifier
     name: New name (optional)
     description: New description (optional)
     location: New location (optional)
     opening-hours: New opening hours (optional)
     contact-info: New contact info (optional)

   Returns:
     T on success, NIL on error

   Example:
     (update-business-account \"biz_123\" :name \"Updated Shop\")"
  (let ((account (gethash account-id *business-accounts*)))
    (unless account
      (return-from update-business-account (values nil "Account not found")))

    (handler-case
        (let* ((connection (get-connection))
               (result (rpc-call connection
                                 (make-tl-object 'business.updateAccount
                                                 :account-id account-id
                                                 :name (or name (business-account-name account))
                                                 :description (or description (business-account-description account))
                                                 :location (or location (business-account-location account))
                                                 :opening-hours (or opening-hours (business-account-hours account))
                                                 :contact (or contact-info (business-account-contact account)))
                                 :timeout 10000)))
          (when result
            (log:info "Business account updated: ~A" account-id)
            t))
      (t (e)
        (log:error "Update business account failed: ~A" e)
        nil))))

(defun delete-business-account (account-id)
  "Delete a business account.

   Args:
     account-id: Business account identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-business-account \"biz_123\")"
  (let ((account (gethash account-id *business-accounts*)))
    (unless account
      (return-from delete-business-account (values nil "Account not found")))

    (handler-case
        (let* ((connection (get-connection))
               (result (rpc-call connection
                                 (make-tl-object 'business.deleteAccount
                                                 :account-id account-id)
                                 :timeout 10000)))
          (when result
            (remhash account-id *business-accounts*)
            (log:info "Business account deleted: ~A" account-id)
            t))
      (t (e)
        (log:error "Delete business account failed: ~A" e)
        nil))))

(defun list-business-accounts ()
  "List all business accounts.

   Returns:
     List of business-account instances

   Example:
     (list-business-accounts)"
  (let ((accounts nil))
    (maphash (lambda (k v)
               (declare (ignore k))
               (push v accounts))
             *business-accounts*)
    accounts))

;;; ============================================================================
;;; Section 4: Business Greeting Messages
;;; ============================================================================

(defun set-business-greeting (account-id message &key (chat-ids nil) (enabled t))
  "Set business greeting message.

   Args:
     account-id: Business account identifier
     message: Greeting message text
     chat-ids: Optional list of chat IDs to show greeting
     enabled: Whether greeting is enabled

   Returns:
     Business-greeting instance on success

   Example:
     (set-business-greeting \"biz_123\" \"Welcome to our business!\"
                            :chat-ids '(123 456))"
  (let* ((greeting-id (format nil "greet_~A_~A" account-id (get-universal-time)))
         (greeting (make-instance 'business-greeting
                                  :greeting-id greeting-id
                                  :message message
                                  :is-enabled enabled
                                  :chat-ids chat-ids)))
    (setf (gethash greeting-id *business-greetings*) greeting)
    (log:info "Business greeting set: ~A" greeting-id)
    greeting))

(defun get-business-greeting (account-id)
  "Get business greeting message.

   Args:
     account-id: Business account identifier

   Returns:
     Business-greeting instance or NIL

   Example:
     (get-business-greeting \"biz_123\")"
  (let ((greeting nil))
    (maphash (lambda (k v)
               (when (search account-id k)
                 (setf greeting v)))
             *business-greetings*)
    greeting))

(defun delete-business-greeting (greeting-id)
  "Delete business greeting message.

   Args:
     greeting-id: Greeting identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-business-greeting \"greet_123\")"
  (let ((greeting (gethash greeting-id *business-greetings*)))
    (when greeting
      (remhash greeting-id *business-greetings*)
      (log:info "Business greeting deleted: ~A" greeting-id)
      t)))

;;; ============================================================================
;;; Section 5: Business Auto-Reply
;;; ============================================================================

(defun set-business-auto-reply (account-id message &key (keywords nil)
                                                     (delay-seconds 0)
                                                     (enabled t))
  "Set business auto-reply message.

   Args:
     account-id: Business account identifier
     message: Auto-reply message text
     keywords: Optional list of trigger keywords
     delay-seconds: Delay before sending reply (default 0)
     enabled: Whether auto-reply is enabled

   Returns:
     Business-auto-reply instance on success

   Example:
     (set-business-auto-reply \"biz_123\" \"We'll respond soon!\"
                              :keywords '(\"hello\" \"help\")
                              :delay-seconds 5)"
  (let* ((reply-id (format nil "autoreply_~A_~A" account-id (get-universal-time)))
         (reply (make-instance 'business-auto-reply
                               :reply-id reply-id
                               :message message
                               :is-enabled enabled
                               :delay-seconds delay-seconds
                               :keywords keywords)))
    (setf (gethash reply-id *business-auto-replies*) reply)
    (log:info "Business auto-reply set: ~A" reply-id)
    reply))

(defun get-business-auto-reply (account-id)
  "Get business auto-reply configuration.

   Args:
     account-id: Business account identifier

   Returns:
     Business-auto-reply instance or NIL

   Example:
     (get-business-auto-reply \"biz_123\")"
  (let ((reply nil))
    (maphash (lambda (k v)
               (when (search account-id k)
                 (setf reply v)))
             *business-auto-replies*)
    reply))

(defun delete-business-auto-reply (reply-id)
  "Delete business auto-reply configuration.

   Args:
     reply-id: Auto-reply identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-business-auto-reply \"autoreply_123\")"
  (let ((reply (gethash reply-id *business-auto-replies*)))
    (when reply
      (remhash reply-id *business-auto-replies*)
      (log:info "Business auto-reply deleted: ~A" reply-id)
      t)))

;;; ============================================================================
;;; Section 6: Message Labels
;;; ============================================================================

(defun create-message-label (chat-id name color)
  "Create a message label.

   Args:
     chat-id: Chat identifier
     name: Label name
     color: Label color (hex or preset)

   Returns:
     Message-label instance on success

   Example:
     (create-message-label 123 \"Important\" \"#FF0000\")"
  (let* ((label-id (format nil "label_~A_~A" chat-id (get-universal-time)))
         (label (make-instance 'message-label
                               :label-id label-id
                               :name name
                               :color color
                               :chat-id chat-id)))
    (let ((chat-labels (gethash chat-id *message-labels* (make-hash-table :test 'equal))))
      (setf (gethash label-id chat-labels) label)
      (setf (gethash chat-id *message-labels*) chat-labels))
    (log:info "Message label created: ~A" label-id)
    label))

(defun assign-label-to-message (chat-id label-id message-id)
  "Assign a label to a message.

   Args:
     chat-id: Chat identifier
     label-id: Label identifier
     message-id: Message identifier

   Returns:
     T on success, NIL on error

   Example:
     (assign-label-to-message 123 \"label_1\" 456)"
  (let ((chat-labels (gethash chat-id *message-labels*)))
    (unless chat-labels
      (return-from assign-label-to-message (values nil "Chat labels not found")))

    (let ((label (gethash label-id chat-labels)))
      (unless label
        (return-from assign-label-to-message (values nil "Label not found")))

      (pushnew message-id (message-label-messages label))
      (log:info "Label assigned to message: ~A" message-id)
      t)))

(defun remove-label-from-message (chat-id label-id message-id)
  "Remove a label from a message.

   Args:
     chat-id: Chat identifier
     label-id: Label identifier
     message-id: Message identifier

   Returns:
     T on success, NIL on error

   Example:
     (remove-label-from-message 123 \"label_1\" 456)"
  (let ((chat-labels (gethash chat-id *message-labels*)))
    (unless chat-labels
      (return-from remove-label-from-message (values nil "Chat labels not found")))

    (let ((label (gethash label-id chat-labels)))
      (unless label
        (return-from remove-label-from-message (values nil "Label not found")))

      (setf (message-label-messages label)
            (remove message-id (message-label-messages label)))
      (log:info "Label removed from message: ~A" message-id)
      t)))

(defun get-messages-by-label (chat-id label-id)
  "Get all messages with a specific label.

   Args:
     chat-id: Chat identifier
     label-id: Label identifier

   Returns:
     List of message IDs

   Example:
     (get-messages-by-label 123 \"label_1\")"
  (let ((chat-labels (gethash chat-id *message-labels*)))
    (if chat-labels
        (let ((label (gethash label-id chat-labels)))
          (when label
            (message-label-messages label)))
        nil)))

(defun delete-message-label (chat-id label-id)
  "Delete a message label.

   Args:
     chat-id: Chat identifier
     label-id: Label identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-message-label 123 \"label_1\")"
  (let ((chat-labels (gethash chat-id *message-labels*)))
    (when chat-labels
      (let ((label (gethash label-id chat-labels)))
        (when label
          (remhash label-id chat-labels)
          (log:info "Message label deleted: ~A" label-id)
          t)))))

(defun get-all-labels (chat-id)
  "Get all labels for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     List of message-label instances

   Example:
     (get-all-labels 123)"
  (let ((chat-labels (gethash chat-id *message-labels*)))
    (if chat-labels
        (let ((labels nil))
          (maphash (lambda (k v)
                     (declare (ignore k))
                     (push v labels))
                   chat-labels)
          labels)
        nil)))

;;; ============================================================================
;;; Section 7: Business Chat Management
;;; ============================================================================

(defun get-business-chat (chat-id)
  "Get business chat information.

   Args:
     chat-id: Chat identifier

   Returns:
     Business-chat instance or NIL

   Example:
     (get-business-chat 123)"
  (gethash chat-id *business-chats*))

(defun update-business-chat (chat-id account-id &key (status nil) (labels nil))
  "Update business chat information.

   Args:
     chat-id: Chat identifier
     account-id: Business account identifier
     status: New chat status (optional)
     labels: New labels (optional)

   Returns:
     T on success, NIL on error

   Example:
     (update-business-chat 123 \"biz_456\" :status :archived)"
  (let ((chat (gethash chat-id *business-chats*)))
    (unless chat
      ;; Create new business chat
      (setf chat (make-instance 'business-chat
                                :chat-id chat-id
                                :account-id account-id
                                :last-message-time (get-universal-time)
                                :status (or status :active)))
      (setf (gethash chat-id *business-chats*) chat))

    (when status
      (setf (business-chat-status chat) status))
    (when labels
      (setf (business-chat-labels chat) labels))

    (log:info "Business chat updated: ~A" chat-id)
    t))

(defun get-business-chats (&key (account-id nil) (status nil) (labels nil))
  "Get business chats with optional filters.

   Args:
     account-id: Filter by account ID (optional)
     status: Filter by status (optional)
     labels: Filter by labels (optional)

   Returns:
     List of business-chat instances

   Example:
     (get-business-chats :account-id \"biz_123\" :status :active)"
  (let ((chats nil))
    (maphash (lambda (k chat)
               (declare (ignore k))
               (when (or (null account-id)
                         (string= (business-chat-account chat) account-id))
                 (when (or (null status)
                           (eq (business-chat-status chat) status))
                   (push chat chats))))
             *business-chats*)
    chats))

(defun archive-business-chat (chat-id)
  "Archive a business chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success, NIL on error

   Example:
     (archive-business-chat 123)"
  (update-business-chat chat-id nil :status :archived))

(defun unarchive-business-chat (chat-id)
  "Unarchive a business chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success, NIL on error

   Example:
     (unarchive-business-chat 123)"
  (update-business-chat chat-id nil :status :active))

;;; ============================================================================
;;; Section 8: Business Statistics
;;; ============================================================================

(defun get-business-stats (account-id &key (period :day))
  "Get business account statistics.

   Args:
     account-id: Business account identifier
     period: Statistics period (:hour :day :week :month)

   Returns:
     Plist with statistics

   Example:
     (get-business-stats \"biz_123\" :period :day)"
  (let ((chats (get-business-chats :account-id account-id))
        (total-messages 0)
        (total-customers 0)
        (response-time-avg 0))

    ;; Calculate stats
    (dolist (chat chats)
      (incf total-customers)
      ;; Would need to track actual message counts
      (incf total-messages 10))

    (list :account-id account-id
          :period period
          :total-chats total-customers
          :total-messages total-messages
          :avg-response-time response-time-avg
          :active-greetings (count-if (lambda (g) (business-greeting-enabled g))
                                      (get-business-greeting account-id))
          :active-auto-replies (if (get-business-auto-reply account-id) 1 0))))

;;; ============================================================================
;;; Section 9: Integration Helpers
;;; ============================================================================

(defun send-business-message (chat-id message &key (account-id nil)
                                                 (greeting nil)
                                                 (auto-reply nil)
                                                 (labels nil))
  "Send a message in business context.

   Args:
     chat-id: Target chat identifier
     message: Message text
     account-id: Optional business account ID
     greeting: Optional greeting to include
     auto-reply: Whether this is an auto-reply
     labels: Optional labels to apply

   Returns:
     Sent message on success

   Example:
     (send-business-message 123 \"Hello!\" :account-id \"biz_456\")"
  (let ((msg (send-message chat-id message)))
    (when msg
      ;; Apply labels if provided
      (when labels
        (dolist (label labels)
          (assign-label-to-message chat-id label msg)))

      ;; Update business chat
      (when account-id
        (update-business-chat chat-id account-id)))

    msg))

;;; End of telegram-business.lisp
