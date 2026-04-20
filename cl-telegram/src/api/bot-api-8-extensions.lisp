;;; bot-api-8-extensions.lisp --- Bot API 8.1-8.3 extensions
;;;
;;; Provides support for Bot API updates released in 2025:
;;; - Bot API 8.1: Business features enhancements
;;; - Bot API 8.2: User/Chat verification, Star upgrades
;;; - Bot API 8.3: Paid gifts, Video covers, Service message reactions
;;;
;;; Reference: https://core.telegram.org/bots/api-changelog

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Verification Features (Bot API 8.2)
;;; ============================================================================

;;; ### Verification Result Types

(defclass verification-result ()
  ((success :initarg :success :initform nil :reader verification-success)
   (description :initarg :description :initform nil :reader verification-description)
   (verification-id :initarg :verification-id :initform nil :reader verification-id)
   (verification-date :initarg :verification-date :initform nil :reader verification-date)
   (verified-by :initarg :verified-by :initform nil :reader verification-verified-by)))

;;; ### Verification API

(defun verify-user (user-id &key custom-description)
  "Verify a user (add verification badge).

   Args:
     user-id: User identifier to verify
     custom-description: Optional custom verification description

   Returns:
     Verification-result object or NIL on error

   Note:
     Requires organization admin privileges

   Example:
     (verify-user 123456 :custom-description \"Official account\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'admin.verifyUser
                                      :user-id user-id
                                      :reason (or custom-description ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (make-instance 'verification-result
                           :success t
                           :description custom-description
                           :verification-id (getf result :id)
                           :verification-date (getf result :date)
                           :verified-by (getf result :admin-id)))))
    (t (e)
      (log:error "Exception in verify-user: ~A" e)
      (make-instance 'verification-result :success nil :description (princ-to-string e)))))

(defun verify-chat (chat-id &key custom-description)
  "Verify a chat/channel (add verification badge).

   Args:
     chat-id: Chat identifier to verify
     custom-description: Optional custom verification description

   Returns:
     Verification-result object or NIL on error

   Note:
     Requires organization admin privileges

   Example:
     (verify-chat -1001234567890 :custom-description \"Verified channel\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'admin.verifyChat
                                      :chat-id chat-id
                                      :reason (or custom-description ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (make-instance 'verification-result
                           :success t
                           :description custom-description
                           :verification-id (getf result :id)
                           :verification-date (getf result :date)
                           :verified-by (getf result :admin-id)))))
    (t (e)
      (log:error "Exception in verify-chat: ~A" e)
      (make-instance 'verification-result :success nil :description (princ-to-string e)))))

(defun remove-user-verification (user-id)
  "Remove verification from a user.

   Args:
     user-id: User identifier

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'admin.removeUserVerification
                                      :user-id user-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log:error "Exception in remove-user-verification: ~A" e)
      nil)))

(defun remove-chat-verification (chat-id)
  "Remove verification from a chat/channel.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'admin.removeChatVerification
                                      :chat-id chat-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log:error "Exception in remove-chat-verification: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 2: Gift Features (Bot API 8.3)
;;; ============================================================================

;;; ### Gift Types

(defclass gift ()
  ((id :initarg :id :reader gift-id)
   (name :initarg :name :reader gift-name)
   (description :initarg :description :reader gift-description)
   (upgrade-star-count :initarg :upgrade-star-count :initform 0 :reader gift-upgrade-star-count)
   (total-count :initarg :total-count :initform 0 :reader gift-total-count)
   (owner-count :initarg :owner-count :initform 0 :reader gift-owner-count)
   (icon :initarg :icon :initform nil :reader gift-icon)
   (is-limited :initarg :is-limited :initform nil :reader gift-is-limited)
   (is-exclusive :initarg :is-exclusive :initform nil :reader gift-is-exclusive)))

(defclass gifts ()
  ((gifts :initarg :gifts :initform nil :reader gifts-list)
   (total-count :initarg :total-count :initform 0 :reader gifts-total-count)))

(defclass transaction-partner-chat ()
  ((chat :initarg :chat :reader transaction-partner-chat-chat)
   (amount :initarg :amount :reader transaction-partner-chat-amount)
   (transaction-id :initarg :transaction-id :initform nil :reader transaction-partner-chat-transaction-id)
   (date :initarg :date :initform nil :reader transaction-partner-chat-date)))

;;; ### Global State

(defvar *available-gifts-cache* nil
  "Cache for available gifts")
(defvar *gifts-cache-ttl* 3600
  "Gift cache TTL in seconds (default: 1 hour)")
(defvar *gifts-last-fetch* nil
  "Timestamp of last gifts fetch")

;;; ### Gift API

(defun get-available-gifts (&optional force-refresh)
  "Get list of available gifts.

   Args:
     force-refresh: Force refresh from server (default: NIL, uses cache)

   Returns:
     Gifts object or NIL on error

   Example:
     (let ((gifts (get-available-gifts)))
       (when gifts
         (dolist (gift (gifts-list gifts))
           (format t \"Gift: ~A, Upgrade: ~A stars~%\"
                   (gift-name gift)
                   (gift-upgrade-star-count gift)))))"
  (let ((now (get-universal-time)))
    (when (and *available-gifts-cache*
               *gifts-last-fetch*
               (not force-refresh)
               (< (- now *gifts-last-fetch*) *gifts-cache-ttl*))
      (return-from get-available-gifts *available-gifts-cache*))))

  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'gifts.getAvailableGifts)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (let* ((gift-list (getf result :gifts))
                   (gifts-objs
                     (mapcar (lambda (g)
                               (make-instance 'gift
                                              :id (getf g :id)
                                              :name (getf g :name)
                                              :description (getf g :description)
                                              :upgrade-star-count (getf g :upgrade-star-count 0)
                                              :total-count (getf g :total-count 0)
                                              :owner-count (getf g :owner-count 0)
                                              :icon (getf g :icon)
                                              :is-limited (eq (getf g :is-limited) :bool-true)
                                              :is-exclusive (eq (getf g :is-exclusive) :bool-true)))
                             gift-list)))
              (setf *available-gifts-cache*
                    (make-instance 'gifts
                                   :gifts gifts-objs
                                   :total-count (length gifts-objs)))
              (setf *gifts-last-fetch* now)
              *available-gifts-cache*))))
    (t (e)
      (log:error "Exception in get-available-gifts: ~A" e)
      *available-gifts-cache*)))

(defun send-gift (target-id &key user-id chat-id gift-id text pay-for-upgrade)
  "Send a gift to a user or chat.

   Args:
     target-id: User ID or Chat ID (use user-id or chat-id parameter instead)
     user-id: User ID to send gift to (optional, use target-id if not specified)
     chat-id: Chat ID to send gift to (Bot API 8.3+, optional)
     gift-id: Gift identifier from get-available-gifts
     text: Optional message text to include with gift
     pay-for-upgrade: Whether to pay for upgrade (default: NIL)

   Returns:
     T on success, NIL on error

   Example:
     ;; Send gift to user
     (send-gift nil :user-id 123456 :gift-id \"gift_1\" :text \"Congratulations!\")

     ;; Send paid gift to channel (Bot API 8.3+)
     (send-gift nil :chat-id -1001234567890 :gift-id \"gift_premium\"
                :text \"From the team\" :pay-for-upgrade t)"
  (let ((actual-target (or user-id chat-id target-id)))
    (when (and (null actual-target) (null chat-id))
      (log:error "send-gift: Either user-id or chat-id must be specified")
      (return-from send-gift nil)))

  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'gifts.sendGift
                                      :gift-id gift-id
                                      :user-id (or user-id target-id)
                                      :text (or text "")
                                      :pay-for-upgrade (if pay-for-upgrade :bool-true :bool-false))))
        ;; Bot API 8.3: Add chat_id parameter for channel gifts
        (when chat-id
          (setf (slot-value request 'chat-id) chat-id))

        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log:error "Exception in send-gift: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 3: Video Enhancements (Bot API 8.3)
;;; ============================================================================

;;; ### Video Cover Type

(defclass video-cover ()
  ((media-id :initarg :media-id :reader video-cover-media-id)
   (media-type :initarg :media-type :initform :photo :reader video-cover-media-type)
   (timestamp :initarg :timestamp :initform 0 :reader video-cover-timestamp)
   (file-id :initarg :file-id :initform nil :reader video-cover-file-id)))

;;; ### Enhanced Video API

(defun send-video (chat-id video &key cover start-timestamp caption parse-mode duration width height
                   supports-streaming has-spoiler reply-to-message-id reply-markup)
  "Send video with enhanced options (Bot API 8.3+).

   Args:
     chat-id: Chat identifier
     video: Video file ID or file path
     cover: Video cover image (file ID or path) - Bot API 8.3+
     start-timestamp: Video start timestamp in seconds - Bot API 8.3+
     caption: Video caption
     parse-mode: Parse mode (:html, :markdown, :markdown-v2)
     duration: Video duration in seconds
     width: Video width
     height: Video height
     supports-streaming: Whether video supports streaming
     has-spoiler: Whether video has spoiler animation
     reply-to-message-id: Message ID to reply to
     reply-markup: Reply keyboard markup

   Returns:
     Message object or NIL on error

   Example:
     (send-video chat-id \"video.mp4\"
                 :cover \"cover.jpg\"
                 :start-timestamp 30
                 :caption \"Check out this video!\")"
  (handler-case
      (let* ((connection (get-connection))
             (input-media (make-tl-object 'inputMediaVideo
                                          :media (if (stringp video) video (format nil "attach://~A" video))
                                          :caption (or caption "")
                                          :parse-mode (case parse-mode
                                                          (:html :message-parser-html)
                                                          (:markdown :message-parser-markdown)
                                                          (:markdown-v2 :message-parser-markdown-v2)
                                                          (otherwise nil))
                                          :duration (or duration 0)
                                          :width (or width 0)
                                          :height (or height 0)
                                          :supports-streaming (if supports-streaming :bool-true :bool-false)
                                          :has-spoiler (if has-spoiler :bool-true :bool-false))))
        ;; Bot API 8.3: Add cover and start_timestamp
        (when cover
          (setf (slot-value input-media 'cover) cover))
        (when start-timestamp
          (setf (slot-value input-media 'start-timestamp) start-timestamp))

        (let ((request (make-tl-object 'messages.sendMedia
                                       :peer (make-peer-by-chat-id chat-id)
                                       :media (list input-media)
                                       :reply-to-msg-id (or reply-to-message-id 0)
                                       :reply-markup reply-markup)))
          (rpc-handler-case (rpc-call connection request :timeout 30000)
            (t (result)
              result))))
    (t (e)
      (log:error "Exception in send-video: ~A" e)
      nil)))

(defun forward-message-with-timestamp (chat-id from-chat-id message-id &key video-start-timestamp)
  "Forward a message with video timestamp modification (Bot API 8.3+).

   Args:
     chat-id: Destination chat identifier
     from-chat-id: Source chat identifier
     message-id: Message identifier to forward
     video-start-timestamp: Video start timestamp for video messages

   Returns:
     Message object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.forwardMessages
                                      :from-peer (make-peer-by-chat-id from-chat-id)
                                      :id (list message-id)
                                      :to-peer (make-peer-by-chat-id chat-id))))
        ;; Bot API 8.3: Add video_start_timestamp
        (when video-start-timestamp
          (setf (slot-value request 'video-start-timestamp) video-start-timestamp))

        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            result)))
    (t (e)
      (log:error "Exception in forward-message-with-timestamp: ~A" e)
      nil)))

(defun copy-message-with-timestamp (chat-id from-chat-id message-id &key video-start-timestamp caption)
  "Copy a message with video timestamp modification (Bot API 8.3+).

   Args:
     chat-id: Destination chat identifier
     from-chat-id: Source chat identifier
     message-id: Message identifier to copy
     video-start-timestamp: Video start timestamp for video messages
     caption: Optional new caption

   Returns:
     MessageId object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.copyMessage
                                      :from-peer (make-peer-by-chat-id from-chat-id)
                                      :msg-id message-id
                                      :to-peer (make-peer-by-chat-id chat-id))))
        (when video-start-timestamp
          (setf (slot-value request 'video-start-timestamp) video-start-timestamp))
        (when caption
          (setf (slot-value request 'message) caption))

        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            result)))
    (t (e)
      (log:error "Exception in copy-message-with-timestamp: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: Business Features (Bot API 8.1)
;;; ============================================================================

;;; ### Business Types

(defclass business-connection ()
  ((id :initarg :id :reader business-connection-id)
   (user :initarg :user :reader business-connection-user)
   (user-chat-id :initarg :user-chat-id :reader business-connection-user-chat-id)
   (user-username :initarg :user-username :initform nil :reader business-connection-user-username)
   (date :initarg :date :reader business-connection-date)
   (can-reply :initarg :can-reply :reader business-connection-can-reply)
   (is-enabled :initarg :is-enabled :reader business-connection-is-enabled)
   (has-main-username :initarg :has-main-username :initform nil :reader business-connection-has-main-username)))

(defclass business-intro ()
  ((title :initarg :title :reader business-intro-title)
   (message :initarg :message :reader business-intro-message)
   (sticker-id :initarg :sticker-id :initform nil :reader business-intro-sticker-id)))

(defclass business-location ()
  ((address :initarg :address :reader business-location-address)
   (latitude :initarg :latitude :reader business-location-latitude)
   (longitude :initarg :longitude :reader business-location-longitude)
   (name :initarg :name :initform nil :reader business-location-name)))

(defclass business-opening-hours ()
  ((schedule :initarg :schedule :reader business-opening-hours-schedule)
   (timezone :initarg :timezone :initform nil :reader business-opening-hours-timezone)
   (opening-hours-intervals :initarg :intervals :initform nil :reader business-opening-hours-intervals)))

(defclass business-opening-hours-interval ()
  ((start-minute :initarg :start-minute :reader business-interval-start-minute)
   (end-minute :initarg :end-minute :reader business-interval-end-minute)))

;;; ### Business API

(defvar *business-connections-cache* (make-hash-table :test 'equal)
  "Cache for business connections")

(defun get-business-connection (business-connection-id &optional force-refresh)
  "Get business connection information.

   Args:
     business-connection-id: Business connection identifier
     force-refresh: Force refresh from server (default: NIL)

   Returns:
     Business-connection object or NIL on error"
  (unless force-refresh
    (let ((cached (gethash business-connection-id *business-connections-cache*)))
      (when cached
        (return-from get-business-connection cached))))

  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'business.getBusinessConnection
                                      :business-connection-id business-connection-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (let ((conn (make-instance 'business-connection
                                       :id (getf result :id)
                                       :user (getf result :user)
                                       :user-chat-id (getf result :user-chat-id)
                                       :user-username (getf result :user-username)
                                       :date (getf result :date)
                                       :can-reply (eq (getf result :can-reply) :bool-true)
                                       :is-enabled (eq (getf result :is-enabled) :bool-true)
                                       :has-main-username (eq (getf result :has-main-username) :bool-true))))
              (setf (gethash business-connection-id *business-connections-cache*) conn)
              conn))))
    (t (e)
      (log:error "Exception in get-business-connection: ~A" e)
      nil)))

(defun get-business-intro (user-id)
  "Get user's business intro.

   Args:
     user-id: User identifier

   Returns:
     Business-intro object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'business.getBusinessIntro
                                      :user-id user-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (make-instance 'business-intro
                           :title (getf result :title)
                           :message (getf result :message)
                           :sticker-id (getf result :sticker-id)))))
    (t (e)
      (log:error "Exception in get-business-intro: ~A" e)
      nil)))

(defun get-business-location (user-id)
  "Get user's business location.

   Args:
     user-id: User identifier

   Returns:
     Business-location object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'business.getBusinessLocation
                                      :user-id user-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (make-instance 'business-location
                           :address (getf result :address)
                           :latitude (getf result :latitude)
                           :longitude (getf result :longitude)
                           :name (getf result :name)))))
    (t (e)
      (log:error "Exception in get-business-location: ~A" e)
      nil)))

(defun get-business-opening-hours (user-id)
  "Get user's business opening hours.

   Args:
     user-id: User identifier

   Returns:
     Business-opening-hours object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'business.getBusinessOpeningHours
                                      :user-id user-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (let ((intervals
                   (mapcar (lambda (i)
                             (make-instance 'business-opening-hours-interval
                                            :start-minute (getf i :start-minute)
                                            :end-minute (getf i :end-minute)))
                           (getf result :intervals))))
              (make-instance 'business-opening-hours
                             :schedule (getf result :schedule)
                             :timezone (getf result :timezone)
                             :intervals intervals)))))
    (t (e)
      (log:error "Exception in get-business-opening-hours: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 5: Service Message Reactions (Bot API 8.3)
;;; ============================================================================

(defun send-service-message-reaction (chat-id message-id reaction &key is-big)
  "Send a reaction to a service message.

   Args:
     chat-id: Chat identifier
     message-id: Service message identifier
     reaction: Reaction-type object or emoji string
     is-big: If T, send a big animation (default: NIL)

   Returns:
     T on success, NIL on error

   Note:
     Bot API 8.3+ allows reactions on most service message types

   Example:
     (send-service-message-reaction chat-id service-msg-id \"👍\")"
  ;; Reuse the existing send-message-reaction function
  ;; The server now accepts reactions on service messages
  (send-message-reaction chat-id message-id reaction :is-big is-big))

;;; ============================================================================
;;; Section 6: Helper Functions
;;; ============================================================================

(defun clear-business-connection-cache ()
  "Clear business connection cache.

   Returns:
     T"
  (clr-hash *business-connections-cache*)
  T)

(defun clear-gifts-cache ()
  "Clear gifts cache.

   Returns:
     T"
  (setf *available-gifts-cache* nil
        *gifts-last-fetch* nil)
  T)

(defun business-connection-cached-p (business-connection-id)
  "Check if business connection is cached.

   Args:
     business-connection-id: Business connection identifier

   Returns:
     T if cached, NIL otherwise"
  (gethash business-connection-id *business-connections-cache*))

;;; ============================================================================
;;; Section 7: Export Functions
;;; ============================================================================

;; The following functions are automatically exported via api-package.lisp:
;; - verify-user
;; - verify-chat
;; - remove-user-verification
;; - remove-chat-verification
;; - get-available-gifts
;; - send-gift
;; - send-video (enhanced)
;; - forward-message-with-timestamp
;; - copy-message-with-timestamp
;; - get-business-connection
;; - get-business-intro
;; - get-business-location
;; - get-business-opening-hours
;; - send-service-message-reaction
