;;; bot-api-9-5.lisp --- Bot API 9.5-9.6 extended features for v0.32.0
;;;
;;; Provides support for:
;;; - Prepared keyboard buttons
;;; - Member tags management
;;; - Enhanced polls (Polls 2.0)
;;; - DateTime message entity
;;; - Streaming improvements
;;;
;;; Version: 0.32.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Prepared Keyboard Buttons (Bot API 9.5+)
;;; ============================================================================

(defclass prepared-keyboard-button ()
  ((button-id :initarg :button-id :accessor prepared-button-id)
   (text :initarg :text :accessor prepared-button-text)
   (request-users :initarg :request-users :initform nil :accessor prepared-button-request-users)
   (request-chats :initarg :request-chats :initform nil :accessor prepared-button-request-chats)
   (request-managed-bots :initarg :request-managed-bots :initform nil :accessor prepared-button-request-managed-bots)
   (max-quantity :initarg :max-quantity :initform nil :accessor prepared-button-max-quantity)
   (created-at :initarg :created-at :accessor prepared-button-created-at)
   (status :initarg :status :initform :active :accessor prepared-button-status)))

(defvar *prepared-keyboard-buttons* (make-hash-table :test 'equal)
  "Hash table storing prepared keyboard buttons")

(defun save-prepared-keyboard-button (text &key (request-users nil) (request-chats nil)
                                            (request-managed-bots nil) (max-quantity nil))
  "Save a prepared keyboard button for Mini App use.

   Args:
     text: Button text
     request-users: Whether to request users
     request-chats: Whether to request chats
     request-managed-bots: Whether to request managed bots
     max-quantity: Maximum number of items to request

   Returns:
     Prepared-keyboard-button instance

   Example:
     (save-prepared-keyboard-button \"Select User\" :request-users t :max-quantity 3)"
  (let* ((button-id (format nil "pbtn_~A_~A" (get-universal-time) (random (expt 2 32))))
         (button (make-instance 'prepared-keyboard-button
                                :button-id button-id
                                :text text
                                :request-users request-users
                                :request-chats request-chats
                                :request-managed-bots request-managed-bots
                                :max-quantity max-quantity
                                :created-at (get-universal-time))))
    (setf (gethash button-id *prepared-keyboard-buttons*) button)
    (log:info "Prepared keyboard button saved: ~A" button-id)
    button))

(defun get-prepared-keyboard-button (button-id)
  "Get a prepared keyboard button by ID.

   Args:
     button-id: Button identifier

   Returns:
     Prepared-keyboard-button instance or NIL

   Example:
     (get-prepared-keyboard-button \"pbtn_123\")"
  (let ((button (gethash button-id *prepared-keyboard-buttons*)))
    (when button
      button)))

(defun delete-prepared-keyboard-button (button-id)
  "Delete a prepared keyboard button.

   Args:
     button-id: Button identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-prepared-keyboard-button \"pbtn_123\")"
  (let ((button (gethash button-id *prepared-keyboard-buttons*)))
    (when button
      (remhash button-id *prepared-keyboard-buttons*)
      (log:info "Prepared keyboard button deleted: ~A" button-id)
      t)))

(defun list-prepared-keyboard-buttons ()
  "List all prepared keyboard buttons.

   Returns:
     List of prepared buttons

   Example:
     (list-prepared-keyboard-buttons)"
  (let ((buttons nil))
    (maphash (lambda (k v)
               (declare (ignore k))
               (push v buttons))
             *prepared-keyboard-buttons*)
    buttons))

(defun send-prepared-button-reply (chat-id button-id selected-users &key (selected-chats nil))
  "Send a reply using a prepared keyboard button.

   Args:
     chat-id: Target chat identifier
     button-id: Prepared button identifier
     selected-users: List of selected user IDs
     selected-chats: Optional list of selected chat IDs

   Returns:
     Sent message object on success

   Example:
     (send-prepared-button-reply chat-id \"pbtn_123\" '(111 222))"
  (let ((button (gethash button-id *prepared-keyboard-buttons*)))
    (unless button
      (return-from send-prepared-button-reply (values nil "Button not found")))

    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'messages.sendPreparedButtonReply
                                        :peer (make-peer-chat-id chat-id)
                                        :button-id button-id
                                        :users (mapcar #'(lambda (id) (make-peer-user-id id)) selected-users)
                                        :chats (when selected-chats
                                                 (mapcar #'(lambda (id) (make-peer-chat-id id)) selected-chats)))))
          (let ((result (rpc-call connection request :timeout 30000)))
            (log:info "Prepared button reply sent: ~A" button-id)
            result))
      (t (e)
        (log:error "Send prepared button reply failed: ~A" e)
        (values nil (format nil "Error: ~A" e))))))

;;; ============================================================================
;;; Section 2: Member Tags (Bot API 9.5+)
;;; ============================================================================

(defclass member-tag ()
  ((tag-id :initarg :tag-id :accessor member-tag-id)
   (name :initarg :name :accessor member-tag-name)
   (color :initarg :color :initform "default" :accessor member-tag-color)
   (chat-id :initarg :chat-id :accessor member-tag-chat-id)
   (user-ids :initarg :user-ids :initform nil :accessor member-tag-user-ids)
   (created-at :initarg :created-at :accessor member-tag-created-at)))

(defvar *member-tags* (make-hash-table :test 'equal)
  "Hash table storing member tags by chat")

(defun create-member-tag (chat-id name &key (color "default"))
  "Create a new member tag for a chat.

   Args:
     chat-id: Chat identifier
     name: Tag name
     color: Tag color (default, red, green, blue, etc.)

   Returns:
     Member-tag instance

   Example:
     (create-member-tag chat-id \"VIP\" :color \"gold\")"
  (let* ((tag-id (format nil "tag_~A_~A" chat-id (get-universal-time)))
         (tag (make-instance 'member-tag
                             :tag-id tag-id
                             :name name
                             :color color
                             :chat-id chat-id
                             :created-at (get-universal-time))))
    ;; Store in chat-specific bucket
    (let ((chat-tags (gethash chat-id *member-tags* (make-hash-table :test 'equal))))
      (setf (gethash tag-id chat-tags) tag)
      (setf (gethash chat-id *member-tags*) chat-tags))
    (log:info "Member tag created: ~A for chat ~A" name chat-id)
    tag))

(defun assign-member-tag (chat-id tag-id user-id)
  "Assign a member tag to a user.

   Args:
     chat-id: Chat identifier
     tag-id: Tag identifier
     user-id: User identifier

   Returns:
     T on success, NIL on error

   Example:
     (assign-member-tag chat-id \"tag_123\" 456)"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (unless chat-tags
      (return-from assign-member-tag (values nil "Chat tags not found")))

    (let ((tag (gethash tag-id chat-tags)))
      (unless tag
        (return-from assign-member-tag (values nil "Tag not found")))

      (unless (member user-id (member-tag-user-ids tag))
        (setf (member-tag-user-ids tag) (append (member-tag-user-ids tag) (list user-id))))
      (log:info "Member tag assigned: ~A to user ~A" tag-id user-id)
      t)))

(defun remove-member-tag (chat-id tag-id user-id)
  "Remove a member tag from a user.

   Args:
     chat-id: Chat identifier
     tag-id: Tag identifier
     user-id: User identifier

   Returns:
     T on success, NIL on error

   Example:
     (remove-member-tag chat-id \"tag_123\" 456)"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (unless chat-tags
      (return-from remove-member-tag (values nil "Chat tags not found")))

    (let ((tag (gethash tag-id chat-tags)))
      (unless tag
        (return-from remove-member-tag (values nil "Tag not found")))

      (setf (member-tag-user-ids tag) (remove user-id (member-tag-user-ids tag)))
      (log:info "Member tag removed: ~A from user ~A" tag-id user-id)
      t)))

(defun get-member-tags (chat-id)
  "Get all member tags for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     List of member tags

   Example:
     (get-member-tags chat-id)"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (if chat-tags
        (let ((tags nil))
          (maphash (lambda (k v)
                     (declare (ignore k))
                     (push v tags))
                   chat-tags)
          tags)
        nil)))

(defun get-user-member-tags (chat-id user-id)
  "Get all tags assigned to a user.

   Args:
     chat-id: Chat identifier
     user-id: User identifier

   Returns:
     List of member tags

   Example:
     (get-user-member-tags chat-id 123)"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (if chat-tags
        (let ((tags nil))
          (maphash (lambda (k v)
                     (declare (ignore k))
                     (when (member user-id (member-tag-user-ids v))
                       (push v tags)))
                   chat-tags)
          tags)
        nil)))

(defun delete-member-tag (chat-id tag-id)
  "Delete a member tag.

   Args:
     chat-id: Chat identifier
     tag-id: Tag identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-member-tag chat-id \"tag_123\")"
  (let ((chat-tags (gethash chat-id *member-tags*)))
    (unless chat-tags
      (return-from delete-member-tag (values nil "Chat tags not found")))

    (let ((tag (gethash tag-id chat-tags)))
      (when tag
        (remhash tag-id chat-tags)
        (log:info "Member tag deleted: ~A" tag-id)
        t)))))

;;; ============================================================================
;;; Section 3: Enhanced Polls (Polls 2.0)
;;; ============================================================================

(defclass poll-v2 ()
  ((poll-id :initarg :poll-id :accessor poll-v2-id)
   (question :initarg :question :accessor poll-v2-question)
   (options :initarg :options :accessor poll-v2-options)
   (description :initarg :description :initform nil :accessor poll-v2-description)
   (media :initarg :media :initform nil :accessor poll-v2-media)
   (is-anonymous :initarg :is-anonymous :initform t :accessor poll-v2-is-anonymous)
   (type :initarg :type :initform :regular :accessor poll-v2-type)
   (allows-multiple-answers :initarg :allows-multiple-answers :initform nil :accessor poll-v2-allows-multiple-answers)
   (correct-option-id :initarg :correct-option-id :initform nil :accessor poll-v2-correct-option-id)
   (explanation :initarg :explanation :initform nil :accessor poll-v2-explanation)
   (close-date :initarg :close-date :initform nil :accessor poll-v2-close-date)
   (location :initarg :location :initform nil :accessor poll-v2-location)
   (created-at :initarg :created-at :accessor poll-v2-created-at)))

(defvar *polls-v2* (make-hash-table :test 'equal)
  "Hash table storing v2 polls")

(defun create-poll-v2 (question options &key (description nil) (media nil) (is-anonymous t)
                                  (type :regular) (allows-multiple-answers nil)
                                  (correct-option-id nil) (explanation nil)
                                  (close-date nil) (location nil))
  "Create an enhanced poll (Polls 2.0).

   Args:
     question: Poll question
     options: List of option strings
     description: Optional poll description
     media: Optional media attachments (photos/videos)
     is-anonymous: Whether votes are anonymous
     type: Poll type (:regular, :quiz)
     allows-multiple-answers: Allow multiple selections
     correct-option-id: Correct option for quiz mode
     explanation: Quiz explanation
     close-date: Poll close date (universal time)
     location: Location for location-based polls

   Returns:
     Poll-v2 instance

   Example:
     (create-poll-v2 \"Favorite color?\" '(\"Red\" \"Green\" \"Blue\")
                     :description \"Vote for your favorite\"
                     :is-anonymous nil)"
  (let* ((poll-id (format nil "poll_v2_~A_~A" (get-universal-time) (random (expt 2 32))))
         (poll (make-instance 'poll-v2
                              :poll-id poll-id
                              :question question
                              :options options
                              :description description
                              :media media
                              :is-anonymous is-anonymous
                              :type type
                              :allows-multiple-answers allows-multiple-answers
                              :correct-option-id correct-option-id
                              :explanation explanation
                              :close-date close-date
                              :location location
                              :created-at (get-universal-time))))
    (setf (gethash poll-id *polls-v2*) poll)
    (log:info "Poll v2 created: ~A" poll-id)
    poll))

(defun send-poll-v2 (chat-id poll-id)
  "Send a v2 poll to a chat.

   Args:
     chat-id: Target chat identifier
     poll-id: Poll identifier

   Returns:
     Sent message object on success

   Example:
     (send-poll-v2 chat-id \"poll_v2_123\")"
  (let ((poll (gethash poll-id *polls-v2*)))
    (unless poll
      (return-from send-poll-v2 (values nil "Poll not found")))

    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'messages.sendPoll
                                        :peer (make-peer-chat-id chat-id)
                                        :question (poll-v2-question poll)
                                        :answers (mapcar #'(lambda (opt) (make-tl-object 'poll-answer :text opt))
                                                         (poll-v2-options poll))
                                        :type (if (eq (poll-v2-type poll) :quiz) :quiz :regular)
                                        :correct-answers (when (poll-v2-correct-option-id poll)
                                                           (list (poll-v2-correct-option-id poll)))
                                        :explanation (poll-v2-explanation poll)
                                        :close-date (poll-v2-close-date poll)
                                        :anonymous (poll-v2-is-anonymous poll))))
          (let ((result (rpc-call connection request :timeout 30000)))
            (log:info "Poll v2 sent to ~A: ~A" chat-id poll-id)
            result))
      (t (e)
        (log:error "Send poll v2 failed: ~A" e)
        (values nil (format nil "Error: ~A" e))))))

(defun get-poll-v2 (poll-id)
  "Get a v2 poll by ID.

   Args:
     poll-id: Poll identifier

   Returns:
     Poll-v2 instance or NIL

   Example:
     (get-poll-v2 \"poll_v2_123\")"
  (gethash poll-id *polls-v2*))

(defun close-poll-v2 (chat-id poll-id)
  "Close a v2 poll.

   Args:
     chat-id: Target chat identifier
     poll-id: Poll identifier

   Returns:
     T on success, NIL on error

   Example:
     (close-poll-v2 chat-id \"poll_v2_123\")"
  (let ((poll (gethash poll-id *polls-v2*)))
    (unless poll
      (return-from close-poll-v2 (values nil "Poll not found")))

    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'messages.editMessagePoll
                                        :peer (make-peer-chat-id chat-id)
                                        :id (parse-integer (subseq poll-id 10))
                                        :poll-closed t)))
          (rpc-call connection request :timeout 30000)
          (log:info "Poll v2 closed: ~A" poll-id)
          t)
      (t (e)
        (log:error "Close poll v2 failed: ~A" e)
        nil)))))

(defun get-poll-v2-results (poll-id)
  "Get v2 poll results.

   Args:
     poll-id: Poll identifier

   Returns:
     Plist with poll results

   Example:
     (get-poll-v2-results \"poll_v2_123\")"
  (let ((poll (gethash poll-id *polls-v2*)))
    (unless poll
      (return-from get-poll-v2-results nil))

    (list :poll-id poll-id
          :question (poll-v2-question poll)
          :options (poll-v2-options poll)
          :total-voters 0 ; Would need to track votes
          :is-closed (not (null (poll-v2-close-date poll))))))

;;; ============================================================================
;;; Section 4: DateTime Message Entity (Bot API 9.5+)
;;; ============================================================================

(defclass datetime-entity ()
  ((entity-id :initarg :entity-id :accessor datetime-entity-id)
   (datetime :initarg :datetime :accessor datetime-entity-datetime)
   (timezone :initarg :timezone :initform "UTC" :accessor datetime-entity-timezone)
   (display-format :initarg :display-format :initform "auto" :accessor datetime-entity-display-format)))

(defun parse-datetime-entity (text &key (timezone "UTC"))
  "Parse a datetime from text.

   Args:
     text: Text containing datetime
     timezone: Timezone for parsing

   Returns:
     Datetime-entity instance or NIL

   Example:
     (parse-datetime-entity \"Meeting at 2025-03-15 14:00 UTC\")"
  (handler-case
      ;; Simple datetime parsing (YYYY-MM-DD HH:MM format)
      (let ((datetime-regex "([0-9]{4})-([0-9]{2})-([0-9]{2})\\s+([0-9]{2}):([0-9]{2})"))
        (let ((match (cl-ppcre:scan-to-strings datetime-regex text)))
          (when match
            (destructuring-bind (year month day hour minute)
                (mapcar #'parse-integer (cl-ppcre:register-groups-bind (y mo d h mi)
                                                   datetime-regex text
                                                 (values y mo d h mi))))
              (let* ((entity-id (format nil "dt_~A_~A" (get-universal-time) (random (expt 2 32))))
                     (universal-time (encode-universal-time 0 minute hour day month year 0)))
                (make-instance 'datetime-entity
                               :entity-id entity-id
                               :datetime universal-time
                               :timezone timezone))))))
    (t (e)
      (log:error "Parse datetime entity failed: ~A" e)
      nil)))

(defun create-datetime-entity (text universal-time &key (timezone "UTC") (display-format "auto"))
  "Create a datetime entity.

   Args:
     text: Original datetime text
     universal-time: Parsed universal time
     timezone: Timezone
     display-format: Display format hint

   Returns:
     Datetime-entity instance

   Example:
     (create-datetime-entity \"Tomorrow at 3pm\" (encode-universal-time ...))"
  (let ((entity-id (format nil "dt_~A_~A" (get-universal-time) (random (expt 2 32)))))
    (make-instance 'datetime-entity
                   :entity-id entity-id
                   :datetime universal-time
                   :timezone timezone
                   :display-format display-format)))

(defun format-datetime-entity (entity &key (format "yyyy-mm-dd hh:mm"))
  "Format a datetime entity.

   Args:
     entity: Datetime-entity instance
     format: Format string

   Returns:
     Formatted datetime string

   Example:
     (format-datetime-entity entity :format \"MM/DD/YYYY\")"
  (let ((dt (datetime-entity-datetime entity)))
    (multiple-value-bind (sec min hour day month year dow dst-p tz)
        (decode-universal-time dt)
      (case format
        (("yyyy-mm-dd hh:mm")
         (format nil "~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D" year month day hour min))
        (("mm/dd/yyyy")
         (format nil "~2,'0D/~2,'0D/~4,'0D" month day year))
        (("dd/mm/yyyy")
         (format nil "~2,'0D/~2,'0D/~4,'0D" day month year))
        (otherwise
         (format nil "~A" dt))))))

;;; ============================================================================
;;; Section 5: Statistics
;;; ============================================================================

(defun get-bot-api-stats ()
  "Get Bot API 9.5-9.6 feature usage statistics.

   Returns:
     Plist with statistics

   Example:
     (get-bot-api-stats)"
  (let ((prepared-count 0)
        (tag-count 0)
        (poll-count 0))
    ;; Count prepared buttons
    (maphash (lambda (k v) (declare (ignore k v)) (incf prepared-count))
             *prepared-keyboard-buttons*)

    ;; Count member tags
    (maphash (lambda (chat-id chat-tags)
               (declare (ignore chat-id))
               (maphash (lambda (k v) (declare (ignore k v)) (incf tag-count))
                        chat-tags))
             *member-tags*)

    ;; Count polls
    (maphash (lambda (k v) (declare (ignore k v)) (incf poll-count))
             *polls-v2*)

    (list :prepared-buttons prepared-count
          :member-tags tag-count
          :polls-v2 poll-count)))

;;; End of bot-api-9-5.lisp
