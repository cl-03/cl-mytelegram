;;; drafts-scheduled.lisp --- Draft messages and scheduled messages
;;;
;;; Provides support for:
;;; - Draft message management (save, get, clear)
;;; - Scheduled messages (send, get, delete)
;;; - Message TTL (time-to-live) settings

(in-package #:cl-telegram/api)

;;; ### Draft Message Types

(defclass draft-message ()
  ((peer :initarg :peer :reader draft-peer)
   (message :initarg :message :reader draft-message)
   (entities :initarg :entities :initform nil :reader draft-entities)
   (date :initarg :date :reader draft-date)
   (reply-to :initarg :reply-to :initform nil :reader draft-reply-to)))

;;; ### Global State

(defvar *draft-cache* (make-hash-table :test 'equal)
  "Cache for draft messages")

(defvar *scheduled-messages* (make-hash-table :test 'equal)
  "Scheduled messages by chat ID")

(defvar *default-ttl* 0
  "Default message TTL in seconds (0 = no TTL)")

;;; ============================================================================
;;; ### Draft Messages
;;; ============================================================================

(defun save-draft (chat-id message &key (entities nil) (reply-to nil))
  "Save a draft message for a chat.

   Args:
     chat-id: Chat identifier
     message: Draft message text
     entities: Optional message entities (formatting)
     reply-to: Optional message ID to reply to

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.saveDraft
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :message message
                                      :entities (or entities nil)
                                      :reply-to (when reply-to
                                                  (make-tl-object 'inputMessageReplyToMessage
                                                                  :id reply-to)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            ;; Cache the draft
            (setf (gethash chat-id *draft-cache*)
                  (make-instance 'draft-message
                                 :peer chat-id
                                 :message message
                                 :entities entities
                                 :reply-to reply-to
                                 :date (get-universal-time)))
            t)
          (t (c)
            (log-error "Save draft failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in save-draft: ~A" c)
      nil)))

(defun get-drafts ()
  "Get all draft messages.

   Returns:
     List of draft-message objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getAllDrafts)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (let ((drafts (getf result :drafts)))
              ;; Also return cached drafts
              (append drafts
                      (loop for peer being the hash-keys of *draft-cache*
                            collect (gethash peer *draft-cache*)))))
          (t (c)
            (log-error "Get drafts failed: ~A" c)
            ;; Return cached drafts as fallback
            (loop for peer being the hash-keys of *draft-cache*
                  collect (gethash peer *draft-cache*)))))
    (t (c)
      (log-error "Unexpected error in get-drafts: ~A" c)
      nil)))

(defun get-all-drafts ()
  "Get all draft messages with hash synchronization.

   Returns:
     Plist with :drafts and :hash"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getAllDrafts)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (list :drafts (getf result :drafts)
                  :hash (getf result :hash)))
          (t (c)
            (log-error "Get all drafts failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in get-all-drafts: ~A" c)
      nil)))

(defun get-draft (chat-id)
  "Get draft message for a specific chat.

   Args:
     chat-id: Chat identifier

   Returns:
     Draft-message object or NIL"
  ;; First check cache
  (let ((cached (gethash chat-id *draft-cache*)))
    (if cached
        cached
        ;; Try to fetch from server
        (handler-case
            (let* ((connection (get-connection))
                   (request (make-tl-object 'messages.getDraft
                                            :peer (make-tl-object 'inputPeerUser :user-id chat-id))))
              (rpc-handler-case (rpc-call connection request :timeout 10000)
                (:no-error (result)
                  (when (and result (getf result :draft))
                    (make-instance 'draft-message
                                   :peer chat-id
                                   :message (getf (getf result :draft) :message)
                                   :entities (getf (getf result :draft) :entities)
                                   :reply-to (getf (getf result :draft) :reply-to)
                                   :date (get-universal-time))))
                (t (c)
                  (log-error "Get draft failed: ~A" c)
                  nil)))
          (t (c)
            (log-error "Unexpected error in get-draft: ~A" c)
            nil)))))

(defun delete-draft (chat-id)
  "Delete a draft message for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.saveDraft
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :message "")))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            ;; Remove from cache
            (remhash chat-id *draft-cache*)
            t)
          (t (c)
            (log-error "Delete draft failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in delete-draft: ~A" c)
      nil)))

(defun clear-all-drafts ()
  "Clear all draft messages.

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.clearAllDrafts)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            ;; Clear cache
            (clrhash *draft-cache*)
            t)
          (t (c)
            (log-error "Clear all drafts failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in clear-all-drafts: ~A" c)
      nil)))

;;; ============================================================================
;;; ### Scheduled Messages
;;; ============================================================================

(defun send-scheduled-message (chat-id message &key (send-date nil) (media nil) (reply-to nil))
  "Schedule a message to be sent at a specific time.

   Args:
     chat-id: Chat identifier
     message: Message text
     send-date: Universal time to send the message (default: 1 hour from now)
     media: Optional media attachment
     reply-to: Optional message ID to reply to

   Returns:
     Scheduled message ID or NIL on error"
  (let ((scheduled-time (or send-date (+ (get-universal-time) 3600)))) ; Default 1 hour
    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'messages.sendScheduledMessage
                                        :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                        :message message
                                        :schedule-date scheduled-time
                                        :reply-to (when reply-to
                                                    (make-tl-object 'inputMessageReplyToMessage
                                                                    :id reply-to))
                                        :media (or media (make-tl-object 'inputMediaEmpty)))))
          (rpc-handler-case (rpc-call connection request :timeout 10000)
            (:no-error (result)
              (let ((msg-id (getf result :id)))
                ;; Store in local cache
                (push (list :id msg-id
                            :chat-id chat-id
                            :message message
                            :send-date scheduled-time
                            :media media)
                      (gethash chat-id *scheduled-messages*))
                msg-id))
            (t (c)
              (log-error "Send scheduled message failed: ~A" c)
              nil)))
      (t (c)
        (log-error "Unexpected error in send-scheduled-message: ~A" c)
        nil))))

(defun send-scheduled-media (chat-id media &key (send-date nil) (caption nil) (reply-to nil))
  "Schedule a media message to be sent at a specific time.

   Args:
     chat-id: Chat identifier
     media: Media object (from upload-media)
     send-date: Universal time to send the message
     caption: Optional caption
     reply-to: Optional message ID to reply to

   Returns:
     Scheduled message ID or NIL on error"
  (let ((scheduled-time (or send-date (+ (get-universal-time) 3600))))
    (send-scheduled-message chat-id
                            (or caption "")
                            :send-date scheduled-time
                            :media media
                            :reply-to reply-to)))

(defun get-scheduled-messages (chat-id)
  "Get scheduled messages for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     List of scheduled message plists"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getScheduledMessages
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (let ((messages (getf result :messages)))
              ;; Also return cached scheduled messages
              (append messages
                      (gethash chat-id *scheduled-messages*))))
          (t (c)
            (log-error "Get scheduled messages failed: ~A" c)
            ;; Return cached messages as fallback
            (gethash chat-id *scheduled-messages*))))
    (t (c)
      (log-error "Unexpected error in get-scheduled-messages: ~A" c)
      nil)))

(defun get-all-scheduled-messages ()
  "Get all scheduled messages across all chats.

   Returns:
     List of scheduled message plists"
  (let ((all-messages nil))
    (loop for chat-id being the hash-keys of *scheduled-messages*
          do (let ((msgs (get-scheduled-messages chat-id)))
               (when msgs
                 (setf all-messages (append all-messages msgs)))))
    all-messages))

(defun delete-scheduled-message (chat-id message-id)
  "Delete a scheduled message.

   Args:
     chat-id: Chat identifier
     message-id: Scheduled message ID

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.deleteScheduledMessages
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :id (list message-id))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            ;; Remove from cache
            (setf (gethash chat-id *scheduled-messages*)
                  (delete message-id (gethash chat-id *scheduled-messages*)
                          :key #'getf))
            t)
          (t (c)
            (log-error "Delete scheduled message failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in delete-scheduled-message: ~A" c)
      nil)))

(defun delete-all-scheduled-messages (chat-id)
  "Delete all scheduled messages for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.deleteScheduledMessages
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :id (mapcar #'getf (gethash chat-id *scheduled-messages*)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            ;; Clear cache
            (remhash chat-id *scheduled-messages*)
            t)
          (t (c)
            (log-error "Delete all scheduled messages failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in delete-all-scheduled-messages: ~A" c)
      nil)))

(defun send-scheduled-messages-now (chat-id message-ids)
  "Send scheduled messages immediately.

   Args:
     chat-id: Chat identifier
     message-ids: List of scheduled message IDs to send

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendScheduledMessages
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :id message-ids)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            ;; Remove from cache
            (dolist (msg-id message-ids)
              (setf (gethash chat-id *scheduled-messages*)
                    (delete msg-id (gethash chat-id *scheduled-messages*)
                            :key #'getf)))
            t)
          (t (c)
            (log-error "Send scheduled messages now failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in send-scheduled-messages-now: ~A" c)
      nil)))

;;; ============================================================================
;;; ### Message TTL
;;; ============================================================================

(defun set-default-message-ttl (ttl-seconds)
  "Set default TTL for messages in secret chats.

   Args:
     ttl-seconds: Time-to-live in seconds (0 to disable)

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.setDefaultHistoryTTL
                                      :period ttl-seconds)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (setf *default-ttl* ttl-seconds)
            t)
          (t (c)
            (log-error "Set default TTL failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in set-default-message-ttl: ~A" c)
      nil)))

(defun get-default-message-ttl ()
  "Get default message TTL.

   Returns:
     TTL in seconds"
  *default-ttl*)

(defun set-chat-ttl (chat-id ttl-seconds)
  "Set TTL for a specific chat.

   Args:
     chat-id: Chat identifier
     ttl-seconds: Time-to-live in seconds

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.setHistoryTTL
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :period ttl-seconds)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            t)
          (t (c)
            (log-error "Set chat TTL failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in set-chat-ttl: ~A" c)
      nil)))

;;; ============================================================================
;;; ### Multimedia Messages (Album)
;;; ============================================================================

(defun send-multi-media (chat-id media-list &key (caption nil) (reply-to nil) (schedule-date nil))
  "Send multiple media files as an album.

   Args:
     chat-id: Chat identifier
     media-list: List of media objects (from upload-media)
     caption: Optional caption for the album
     reply-to: Optional message ID to reply to
     schedule-date: Optional schedule date for scheduled sending

   Returns:
     List of sent message objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMultiMedia
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                                      :multi-media media-list
                                      :reply-to (when reply-to
                                                  (make-tl-object 'inputMessageReplyToMessage
                                                                  :id reply-to))
                                      :schedule-date schedule-date)))
        (rpc-handler-case (rpc-call connection request :timeout 30000)
          (:no-error (result)
            (getf result :messages))
          (t (c)
            (log-error "Send multi-media failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in send-multi-media: ~A" c)
      nil)))

(defun send-photo-album (chat-id photo-paths &key (caption nil) (reply-to nil))
  "Send a photo album.

   Args:
     chat-id: Chat identifier
     photo-paths: List of photo file paths
     caption: Optional caption (applied to first photo)
     reply-to: Optional message ID to reply to

   Returns:
     List of sent message objects"
  (let ((media-list nil))
    ;; Upload all photos
    (dolist (path photo-paths)
      (let ((media (upload-media path :media-type :photo :caption (when (eq path (car photo-paths)) caption))))
        (when media
          (push media media-list))))

    (when media-list
      (send-multi-media chat-id (nreverse media-list) :reply-to reply-to))))

(defun send-video-album (chat-id video-paths &key (caption nil) (reply-to nil))
  "Send a video album.

   Args:
     chat-id: Chat identifier
     video-paths: List of video file paths
     caption: Optional caption (applied to first video)
     reply-to: Optional message ID to reply to

   Returns:
     List of sent message objects"
  (let ((media-list nil))
    ;; Upload all videos
    (dolist (path video-paths)
      (let ((media (upload-media path :media-type :video :caption (when (eq path (car video-paths)) caption))))
        (when media
          (push media media-list))))

    (when media-list
      (send-multi-media chat-id (nreverse media-list) :reply-to reply-to))))

;;; ============================================================================
;;; ### Copy Message
;;; ============================================================================

(defun copy-message (from-chat-id message-id to-chat-id &key (caption nil) (remove-caption nil))
  "Copy a message from one chat to another.

   Args:
     from-chat-id: Source chat ID
     message-id: Message ID to copy
     to-chat-id: Destination chat ID
     caption: Optional new caption (for media messages)
     remove-caption: If true, remove caption from copied message

   Returns:
     Copied message object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.copyMessage
                                      :from-peer (make-tl-object 'inputPeerUser :user-id from-chat-id)
                                      :id (list message-id)
                                      :to-peer (make-tl-object 'inputPeerUser :user-id to-chat-id)
                                      :remove-caption remove-caption
                                      :caption (or caption ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (getf result :message))
          (t (c)
            (log-error "Copy message failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in copy-message: ~A" c)
      nil)))

;;; Export symbols
(export '(;; Draft Messages
          draft-message
          save-draft
          get-drafts
          get-all-drafts
          get-draft
          delete-draft
          clear-all-drafts

          ;; Scheduled Messages
          send-scheduled-message
          send-scheduled-media
          get-scheduled-messages
          get-all-scheduled-messages
          delete-scheduled-message
          delete-all-scheduled-messages
          send-scheduled-messages-now

          ;; Message TTL
          set-default-message-ttl
          get-default-message-ttl
          set-chat-ttl

          ;; Multimedia
          send-multi-media
          send-photo-album
          send-video-album

          ;; Copy Message
          copy-message

          ;; Global State
          *draft-cache*
          *scheduled-messages*
          *default-ttl*))
