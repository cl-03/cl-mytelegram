;;; business.lisp --- Business account features and management
;;; Part of v0.20.0 - Payment and Business Features

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Business Classes
;;; ======================================================================

(defclass business-connection ()
  ((id :initarg :id :accessor business-connection-id
       :initform "" :documentation "Unique identifier of the business connection")
   (user :initarg :user :accessor business-connection-user
         :initform nil :documentation "Business account user object")
   (user-chat-id :initarg :user-chat-id :accessor business-connection-user-chat-id
                 :initform 0 :documentation "Private chat ID with business account user")
   (date :initarg :date :accessor business-connection-date
         :initform 0 :documentation "Connection establishment date (Unix time)")
   (rights :initarg :rights :accessor business-connection-rights
           :initform nil :documentation "Business bot rights object")
   (is-enabled :initarg :is-enabled :accessor business-connection-is-enabled
               :initform t :documentation "True if connection is active")))

(defclass business-location ()
  ((address :initarg :address :accessor business-location-address
            :initform "" :documentation "Business address string")
   (location :initarg :location :accessor business-location-location
             :initform nil :documentation "Location object with coordinates")))

(defclass business-opening-hours ()
  ((time-zone-name :initarg :time-zone-name :accessor business-opening-hours-time-zone
                   :initform "UTC" :documentation "Time zone name")
   (opening-hours :initarg :opening-hours :accessor business-opening-hours-intervals
                  :initform nil :documentation "List of opening hour intervals")))

(defclass business-opening-hours-interval ()
  ((opening-minute :initarg :opening-minute :accessor business-interval-opening-minute
                   :initform 0 :documentation "Opening minute in week (0-10080)")
   (closing-minute :initarg :closing-minute :accessor business-interval-closing-minute
                   :initform 0 :documentation "Closing minute in week (0-10080)")))

(defclass business-bot-rights ()
  ((can-send-messages :initarg :can-send-messages :accessor business-bot-can-send-messages
                      :initform t :documentation "Can send messages")
   (can-send-media :initarg :can-send-media :accessor business-bot-can-send-media
                   :initform t :documentation "Can send media")
   (can-send-polls :initarg :can-send-polls :accessor business-bot-can-send-polls
                   :initform t :documentation "Can send polls")
   (can-send-other-messages :initarg :can-send-other-messages :accessor business-bot-can-send-other-messages
                            :initform t :documentation "Can send other messages")
   (can-add-web-page-previews :initarg :can-add-web-page-previews :accessor business-bot-can-add-previews
                              :initform t :documentation "Can add web page previews")
   (can-change-business-info :initarg :can-change-business-info :accessor business-bot-can-change-info
                             :initform nil :documentation "Can change business info")
   (can-transfer-stars :initarg :can-transfer-stars :accessor business-bot-can-transfer-stars
                       :initform nil :documentation "Can transfer Telegram Stars")))

(defclass quick-reply ()
  ((text :initarg :text :accessor quick-reply-text
         :initform "" :documentation "Button text, 1-64 chars")
   (type :initarg :type :accessor quick-reply-type
         :initform :text :documentation "Button type: :text, :phone, :email, :location")))

;;; ======================================================================
;;; Business Connection Management
;;; ======================================================================

(defun get-business-connection (connection-id)
  "Get information about a business connection.

   CONNECTION-ID: Unique identifier of the business connection

   Returns business-connection object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,connection-id))))
        (let ((result (make-api-call connection "getBusinessConnection" params)))
          (if result
              (parse-business-connection result)
              nil)))
    (error (e)
      (log-message :error "Error getting business connection: ~A" (princ-to-string e))
      nil)))

(defun parse-business-connection (data)
  "Parse business connection data from API response."
  (make-instance 'business-connection
                 :id (gethash "id" data "")
                 :user (gethash "user" data nil)
                 :user-chat-id (gethash "user_chat_id" data 0)
                 :date (gethash "date" data 0)
                 :rights (parse-business-bot-rights (gethash "rights" data nil))
                 :is-enabled (gethash "is_enabled" data t)))

(defun parse-business-bot-rights (data)
  "Parse business bot rights from API response."
  (if data
      (make-instance 'business-bot-rights
                     :can-send-messages (gethash "can_send_messages" data t)
                     :can-send-media (gethash "can_send_media" data t)
                     :can-send-polls (gethash "can_send_polls" data t)
                     :can-send-other-messages (gethash "can_send_other_messages" data t)
                     :can-add-web-page-previews (gethash "can_add_web_page_previews" data t)
                     :can-change-business-info (gethash "can_change_business_info" data nil)
                     :can-transfer-stars (gethash "can_transfer_stars" data nil))
      nil))

(defun list-business-connections ()
  "List all active business connections for the bot.

   Returns a list of business-connection objects."
  (handler-case
      (let ((connection (get-current-connection)))
        ;; This would typically be tracked locally or via a dedicated API
        ;; For now, return connections from local state
        (get-all-business-connections))
    (error (e)
      (log-message :error "Error listing business connections: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Business Profile Management
;;; ======================================================================

(defun set-business-location (business-connection-id address &key latitude longitude)
  "Set the location of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection
   ADDRESS: Business address string
   LATITUDE: Optional latitude coordinate
   LONGITUDE: Optional longitude coordinate

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id)
                       ("address" . ,address))))
        (when (and latitude longitude)
          (push (cons "location" (json:encode-to-string `(("latitude" ,latitude)
                                                          ("longitude" ,longitude)))) params))

        (let ((result (make-api-call connection "setBusinessLocation" params)))
          (if result
              (progn
                (log-message :info "Business location set to ~A" address)
                t)
              nil)))
    (error (e)
      (log-message :error "Error setting business location: ~A" (princ-to-string e))
      nil)))

(defun get-business-location (business-connection-id)
  "Get the location of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection

   Returns business-location object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id))))
        (let ((result (make-api-call connection "getBusinessLocation" params)))
          (if result
              (parse-business-location result)
              nil)))
    (error (e)
      (log-message :error "Error getting business location: ~A" (princ-to-string e))
      nil)))

(defun parse-business-location (data)
  "Parse business location from API response."
  (make-instance 'business-location
                 :address (gethash "address" data "")
                 :location (gethash "location" data nil)))

(defun delete-business-location (business-connection-id)
  "Delete the location of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id))))
        (let ((result (make-api-call connection "deleteBusinessLocation" params)))
          (if result
              (progn
                (log-message :info "Business location deleted")
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting business location: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Business Opening Hours
;;; ======================================================================

(defun make-opening-hours-interval (opening-minute closing-minute)
  "Create an opening hours interval.

   OPENING-MINUTE: Minute in week when business opens (0-10080)
   CLOSING-MINUTE: Minute in week when business closes (0-10080)

   Returns business-opening-hours-interval object."
  (make-instance 'business-opening-hours-interval
                 :opening-minute opening-minute
                 :closing-minute closing-minute))

(defun make-opening-hours-from-times (time-zone &rest day-schedules)
  "Create opening hours from day schedules.

   TIME-ZONE: Time zone name (e.g., \"America/New_York\")
   DAY-SCHEDULES: List of (day opening-hour closing-hour) tuples
                  Day: 0=Monday, 6=Sunday
                  Hours: 0-23

   Example: (make-opening-hours-from-times \"UTC\" '(0 9 17) '(1 9 17))
            Creates Mon-Fri 9am-5pm schedule

   Returns business-opening-hours object."
  (let ((intervals
         (loop for (day open close) in day-schedules
               when (and day open close)
               collect (make-opening-hours-interval
                        (+ (* day 24 60) (* open 60))
                        (+ (* day 24 60) (* close 60))))))
    (make-instance 'business-opening-hours
                   :time-zone-name time-zone
                   :opening-hours intervals)))

(defun set-business-opening-hours (business-connection-id opening-hours)
  "Set the opening hours of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection
   OPENING-HOURS: business-opening-hours object

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (hours-json (loop for interval in (business-opening-hours-intervals opening-hours)
                               collect `(:opening_minute ,(business-interval-opening-minute interval)
                                        :closing_minute ,(business-interval-closing-minute interval))))
             (params `(("business_connection_id" . ,business-connection-id)
                       ("time_zone_name" . ,(business-opening-hours-time-zone opening-hours))
                       ("opening_hours" . ,(json:encode-to-string hours-json)))))
        (let ((result (make-api-call connection "setBusinessOpeningHours" params)))
          (if result
              (progn
                (log-message :info "Business opening hours set for ~A" business-connection-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error setting business opening hours: ~A" (princ-to-string e))
      nil)))

(defun get-business-opening-hours (business-connection-id)
  "Get the opening hours of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection

   Returns business-opening-hours object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id))))
        (let ((result (make-api-call connection "getBusinessOpeningHours" params)))
          (if result
              (parse-business-opening-hours result)
              nil)))
    (error (e)
      (log-message :error "Error getting business opening hours: ~A" (princ-to-string e))
      nil)))

(defun parse-business-opening-hours (data)
  "Parse business opening hours from API response."
  (let ((intervals
         (loop for interval-data across (or (gethash "opening_hours" data) (make-array 0))
               collect (make-opening-hours-interval
                        (gethash "opening_minute" interval-data 0)
                        (gethash "closing_minute" interval-data 0)))))
    (make-instance 'business-opening-hours
                   :time-zone-name (gethash "time_zone_name" data "UTC")
                   :opening-hours intervals)))

(defun delete-business-opening-hours (business-connection-id)
  "Delete the opening hours of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id))))
        (let ((result (make-api-call connection "deleteBusinessOpeningHours" params)))
          (if result
              (progn
                (log-message :info "Business opening hours deleted")
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting business opening hours: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Quick Replies
;;; ======================================================================

(defun make-quick-reply (text &key (type :text))
  "Create a quick reply button.

   TEXT: Button text, 1-64 characters
   TYPE: Button type: :text, :phone, :email, or :location

   Returns quick-reply object."
  (make-instance 'quick-reply
                 :text text
                 :type type))

(defun send-message-with-quick-replies (chat-id message quick-replies &key business-connection-id
                                                                                reply-to-message-id
                                                                                disable-notification)
  "Send a message with quick reply buttons.

   CHAT-ID: Unique identifier for target chat
   MESSAGE: Message text
   QUICK-REPLIES: List of quick-reply objects
   BUSINESS-CONNECTION-ID: Optional business connection ID
   REPLY-TO-MESSAGE-ID: Optional message to reply to
   DISABLE-NOTIFICATION: Send silently if T

   Returns the sent Message object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (keyboard (loop for reply in quick-replies
                             collect `((:text ,(quick-reply-text reply)
                                       :request_contact ,(eq (quick-reply-type reply) :phone)
                                       :request_location ,(eq (quick-reply-type reply) :location)
                                       :request_contact ,(eq (quick-reply-type reply) :email)))))
             (reply-markup `(:keyboard ,keyboard :one_time_keyboard t :resize_keyboard t))
             (params `(("chat_id" . ,chat-id)
                       ("text" . ,message)
                       ("reply_markup" . ,(json:encode-to-string reply-markup)))))
        (when business-connection-id
          (push (cons "business_connection_id" business-connection-id) params))
        (when reply-to-message-id
          (push (cons "reply_to_message_id" reply-to-message-id) params))
        (when disable-notification
          (push (cons "disable_notification" "true") params))

        (let ((result (make-api-call connection "sendMessage" params)))
          (if result
              (progn
                (log-message :info "Message with quick replies sent to ~A" chat-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error sending message with quick replies: ~A" (princ-to-string e))
      nil)))

(defun send-business-message (business-connection-id chat-id message &key reply-to-message-id
                                                                      business-connection-message-id
                                                                      disable-notification
                                                                      protect-content
                                                                      reply-markup)
  "Send a message on behalf of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection
   CHAT-ID: Unique identifier for target chat
   MESSAGE: Message text
   REPLY-TO-MESSAGE-ID: Optional message to reply to
   BUSINESS-CONNECTION-MESSAGE-ID: Optional business connection message ID
   DISABLE-NOTIFICATION: Send silently if T
   PROTECT-CONTENT: Protect content from forwarding if T
   REPLY-MARKUP: Optional keyboard markup

   Returns the sent Message object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id)
                       ("chat_id" . ,chat-id)
                       ("text" . ,message))))
        (when reply-to-message-id
          (push (cons "reply_to_message_id" reply-to-message-id) params))
        (when business-connection-message-id
          (push (cons "business_connection_message_id" business-connection-message-id) params))
        (when disable-notification
          (push (cons "disable_notification" "true") params))
        (when protect-content
          (push (cons "protect_content" "true") params))
        (when reply-markup
          (push (cons "reply_markup" (json:encode-to-string reply-markup)) params))

        (let ((result (make-api-call connection "sendMessage" params)))
          (if result
              (progn
                (log-message :info "Business message sent via connection ~A" business-connection-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error sending business message: ~A" (princ-to-string e))
      nil)))

(defun edit-business-message (business-connection-id chat-id message-id new-text &key reply-markup)
  "Edit a message sent on behalf of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection
   CHAT-ID: Unique identifier for target chat
   MESSAGE-ID: ID of the message to edit
   NEW-TEXT: New text for the message
   REPLY-MARKUP: Optional new keyboard markup

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id)
                       ("chat_id" . ,chat-id)
                       ("message_id" . ,message-id)
                       ("text" . ,new-text))))
        (when reply-markup
          (push (cons "reply_markup" (json:encode-to-string reply-markup)) params))

        (let ((result (make-api-call connection "editMessageText" params)))
          (if result
              (progn
                (log-message :info "Business message ~A edited" message-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error editing business message: ~A" (princ-to-string e))
      nil)))

(defun delete-business-message (business-connection-id chat-id message-id)
  "Delete a message sent on behalf of a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection
   CHAT-ID: Unique identifier for target chat
   MESSAGE-ID: ID of the message to delete

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id)
                       ("chat_id" . ,chat-id)
                       ("message_id" . ,message-id))))
        (let ((result (make-api-call connection "deleteMessage" params)))
          (if result
              (progn
                (log-message :info "Business message ~A deleted" message-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting business message: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Business Chat Links
;;; ======================================================================

(defun create-business-chat-link (business-connection-id &key name username photo)
  "Create a t.me link for a business account.

   BUSINESS-CONNECTION-ID: Unique identifier of the business connection
   NAME: Optional display name for the link
   USERNAME: Optional custom username for the link
   PHOTO: Optional photo URL

   Returns the created link as a string on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("business_connection_id" . ,business-connection-id))))
        (when name
          (push (cons "name" name) params))
        (when username
          (push (cons "username" username) params))
        (when photo
          (push (cons "photo" photo) params))

        (let ((result (make-api-call connection "createBusinessChatLink" params)))
          (if result
              (progn
                (log-message :info "Business chat link created")
                result)
              nil)))
    (error (e)
      (log-message :error "Error creating business chat link: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Global State
;;; ======================================================================

(defvar *business-connections-cache* (make-hash-table :test 'equal)
  "Cache of business connections by connection ID")

(defvar *quick-reply-types* '(:text :phone :email :location)
  "Supported quick reply button types")
