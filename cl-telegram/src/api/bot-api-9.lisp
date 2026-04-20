;;; bot-api-9.lisp --- Bot API 9.4-9.6 new features support
;;;
;;; Provides support for Bot API 9.x features released in 2026:
;;; - Bot API 9.4: Custom emoji messages, enhanced message content
;;; - Bot API 9.5: DateTime MessageEntity, managed bots
;;; - Bot API 9.6: Mini App device access, theme integration
;;;
;;; Reference: https://core.telegram.org/bots/api-changelog
;;; Version: 0.28.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Custom Emoji Messages (Bot API 9.4)
;;; ============================================================================

;;; ### Custom Emoji Sticker Class

(defclass custom-emoji-sticker ()
  ((sticker-id :initarg :sticker-id :reader custom-emoji-sticker-id)
   (emoji :initarg :emoji :reader custom-emoji-emoji)
   (animation :initarg :animation :reader custom-emoji-animation)
   (thumbnail :initarg :thumbnail :initform nil :reader custom-emoji-thumbnail)
   (width :initarg :width :initform nil :reader custom-emoji-width)
   (height :initarg :height :initform nil :reader custom-emoji-height)
   (file-size :initarg :file-size :initform nil :reader custom-emoji-file-size)))

(defmethod print-object ((sticker custom-emoji-sticker) stream)
  (print-unreadable-object (sticker stream :type t)
    (format stream "~A" (custom-emoji-emoji sticker))))

;;; ### Custom Emoji Pack Class

(defclass custom-emoji-pack ()
  ((pack-id :initarg :pack-id :reader emoji-pack-id)
   (title :initarg :title :reader emoji-pack-title)
   (emojis :initarg :emojis :initform nil :reader emoji-pack-emojis)
   (is-official :initform nil :initarg :is-official :reader emoji-pack-is-official)
   (owner-id :initform nil :initarg :owner-id :reader emoji-pack-owner-id)
   (sticker-count :initform 0 :initarg :sticker-count :reader emoji-pack-sticker-count)))

(defmethod print-object ((pack custom-emoji-pack) stream)
  (print-unreadable-object (pack stream :type t)
    (format stream "~A (~D stickers)" (emoji-pack-title pack) (emoji-pack-sticker-count pack))))

;;; ### Global State

(defvar *custom-emoji-cache* (make-hash-table :test 'equal)
  "Cache for custom emoji stickers")

(defvar *emoji-pack-cache* (make-hash-table :test 'equal)
  "Cache for emoji packs")

;;; ============================================================================
;;; Section 2: Custom Emoji API
;;; ============================================================================

(defun get-custom-emoji-sticker (emoji-id)
  "Get a custom emoji sticker by ID.

   Args:
     emoji-id: Custom emoji file identifier

   Returns:
     Custom-emoji-sticker object or NIL on error

   Example:
     (get-custom-emoji-sticker \"AgADAgAT...\" )"
  (or (gethash emoji-id *custom-emoji-cache*)
      (handler-case
          (let* ((connection (get-connection))
                 (result (rpc-call connection (make-tl-object 'messages.getCustomEmojiDocuments
                                                              :document-id emoji-id)
                                   :timeout 5000)))
            (when result
              (let ((sticker (parse-custom-emoji-sticker result)))
                (setf (gethash emoji-id *custom-emoji-cache*) sticker)
                sticker)))
        (t (e)
          (log:error "Exception in get-custom-emoji-sticker: ~A" e)
          nil))))

(defun parse-custom-emoji-sticker (data)
  "Parse custom emoji sticker from TL data.

   Args:
     data: TL response data

   Returns:
     Custom-emoji-sticker object"
  (make-instance 'custom-emoji-sticker
                 :sticker-id (getf data :id)
                 :emoji (getf data :emoji)
                 :animation (getf data :animation)
                 :thumbnail (getf data :thumbnail)
                 :width (getf data :w)
                 :height (getf data :h)
                 :file-size (getf data :size)))

(defun send-custom-emoji-message (chat-id emoji-id &key reply-to-message-id disable-notification)
  "Send a message containing only a custom emoji.

   Args:
     chat-id: Chat identifier
     emoji-id: Custom emoji file identifier
     reply-to-message-id: Optional message ID to reply to
     disable-notification: If T, send silently

   Returns:
     Message object or NIL on error

   Example:
     (send-custom-emoji-message 123456 \"AgADAgAT...\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMessage
                                      :peer (make-peer-chat :chat-id chat-id)
                                      :message ""
                                      :entities (list (make-tl-object 'messageEntityCustomEmoji
                                                                      :offset 0
                                                                      :length 1
                                                                      :document-id emoji-id))
                                      :reply-to-msg-id reply-to-message-id
                                      :silent (if disable-notification t nil))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (parse-message result))))
    (t (e)
      (log:error "Exception in send-custom-emoji-message: ~A" e)
      nil)))

(defun get-custom-emoji-pack (pack-id)
  "Get information about a custom emoji pack.

   Args:
     pack-id: Emoji pack identifier

   Returns:
     Custom-emoji-pack object or NIL on error

   Example:
     (get-custom-emoji-pack \"57635243927555072\")"
  (or (gethash pack-id *emoji-pack-cache*)
      (handler-case
          (let* ((connection (get-connection))
                 (result (rpc-call connection (make-tl-object 'stickers.getStickerSet
                                                              :stickerset (make-stickerset-input :id pack-id))
                                   :timeout 5000)))
            (when result
              (let ((pack (parse-custom-emoji-pack result)))
                (setf (gethash pack-id *emoji-pack-cache*) pack)
                pack)))
        (t (e)
          (log:error "Exception in get-custom-emoji-pack: ~A" e)
          nil))))

(defun parse-custom-emoji-pack (data)
  "Parse custom emoji pack from TL data.

   Args:
     data: TL response data

   Returns:
     Custom-emoji-pack object"
  (make-instance 'custom-emoji-pack
                 :pack-id (getf data :id)
                 :title (getf data :title)
                 :emojis (mapcar (lambda (s) (getf s :document-id))
                                 (getf data :documents))
                 :is-official (getf data :official)
                 :owner-id (getf data :admin-id)
                 :sticker-count (length (getf data :documents))))

(defun list-custom-emoji-packs ()
  "List all custom emoji packs available to the user.

   Returns:
     List of custom-emoji-pack objects

   Example:
     (list-custom-emoji-packs)"
  (handler-case
      (let* ((connection (get-connection))
             (result (rpc-call connection (make-tl-object 'stickers.getAllStickers)
                               :timeout 5000)))
        (when result
          (let ((packs '()))
            (dolist (pack-data (getf result :sets))
              (when (getf pack-data :type) ; Only emoji packs
                (let ((pack (parse-custom-emoji-pack pack-data)))
                  (push pack packs))))
            (nreverse packs))))
    (t (e)
      (log:error "Exception in list-custom-emoji-packs: ~A" e)
      nil)))

(defun add-custom-emoji-to-pack (pack-id emoji-id &key emoji-character)
  "Add a custom emoji to an existing pack.

   Args:
     pack-id: Emoji pack identifier
     emoji-id: Custom emoji file identifier to add
     emoji-character: Optional emoji character to associate

   Returns:
     T on success, NIL on error

   Example:
     (add-custom-emoji-to-pack \"57635243927555072\" \"AgADAgAT...\" :emoji-character \"😄\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.addStickerToSet
                                      :stickerset (make-stickerset-input :id pack-id)
                                      :sticker (make-input-sticker-set-item
                                                :document-id emoji-id
                                                :emoji (or emoji-character "")))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (when (getf result :success)
              (remhash pack-id *emoji-pack-cache*) ; Invalidate cache
              t))))
    (t (e)
      (log:error "Exception in add-custom-emoji-to-pack: ~A" e)
      nil)))

(defun delete-custom-emoji (pack-id emoji-id)
  "Remove a custom emoji from a pack.

   Args:
     pack-id: Emoji pack identifier
     emoji-id: Custom emoji file identifier to remove

   Returns:
     T on success, NIL on error

   Example:
     (delete-custom-emoji \"57635243927555072\" \"AgADAgAT...\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.removeStickerFromSet
                                      :stickerset (make-stickerset-input :id pack-id)
                                      :document-id emoji-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (when (getf result :success)
              (remhash pack-id *emoji-pack-cache*) ; Invalidate cache
              t))))
    (t (e)
      (log:error "Exception in delete-custom-emoji: ~A" e)
      nil)))

(defun create-custom-emoji-pack (title &key emojis is-official)
  "Create a new custom emoji pack.

   Args:
     title: Pack title
     emojis: List of custom emoji file IDs
     is-official: If T, create as official pack

   Returns:
     Custom-emoji-pack object or NIL on error

   Example:
     (create-custom-emoji-pack \"My Custom Emojis\" :emojis '(\"AgAD1...\" \"AgAD2...\"))"
  (handler-case
      (let* ((connection (get-connection))
             (short-name (format nil "pack_~A" (get-universal-time)))
             (request (make-tl-object 'stickers.createStickerSet
                                      :user-id (make-user-input :user-id (get-my-user-id))
                                      :title title
                                      :short-name short-name
                                      :stickers (mapcar (lambda (id)
                                                          (make-input-sticker-set-item
                                                           :document-id id
                                                           :emoji ""))
                                                        emojis))))
        (rpc-handler-case (rpc-call connection request :timeout 15000)
          (t (result)
            (let ((pack (parse-custom-emoji-pack result)))
              (setf (gethash (emoji-pack-id pack) *emoji-pack-cache*) pack)
              pack))))
    (t (e)
      (log:error "Exception in create-custom-emoji-pack: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 3: Enhanced Message Content (Bot API 9.4)
;;; ============================================================================

;;; ### Interactive Content Types

(defclass interactive-content ()
  ((content-type :initarg :content-type :reader interactive-content-type)
   (message-id :initarg :message-id :reader interactive-message-id)
   (chat-id :initarg :chat-id :reader interactive-chat-id)
   (data :initarg :data :reader interactive-data)))

;;; ### Interactive Poll Types

(defclass interactive-poll (interactive-content)
  ((question :initarg :question :reader poll-question)
   (options :initarg :options :reader poll-options)
   (total-voters :initarg :total-voters :initform 0 :reader poll-total-voters)
   (is-anonymous :initform t :initarg :is-anonymous :reader poll-is-anonymous)
   (allows-multiple :initform nil :initarg :allows-multiple :reader poll-allows-multiple)))

(defclass quiz-poll (interactive-poll)
  ((correct-option :initarg :correct-option :reader quiz-correct-option)
   (explanation :initform nil :initarg :explanation :reader quiz-explanation)))

;;; ### Enhanced Message Content API

(defun get-enhanced-message-content (chat-id message-id)
  "Get enhanced message content including interactive elements.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier

   Returns:
     Interactive-content object or NIL on error

   Example:
     (get-enhanced-message-content 123456 789)"
  (handler-case
      (let* ((connection (get-connection))
             (result (rpc-call connection (make-tl-object 'messages.getMessages
                                                          :id (list message-id))
                               :timeout 5000)))
        (when result
          (let ((messages (getf result :messages)))
            (when (and messages (> (length messages) 0))
              (parse-interactive-content (first messages) chat-id message-id)))))
    (t (e)
      (log:error "Exception in get-enhanced-message-content: ~A" e)
      nil)))

(defun parse-interactive-content (message-data chat-id message-id)
  "Parse interactive content from message data.

   Args:
     message-data: Message TL data
     chat-id: Chat identifier
     message-id: Message identifier

   Returns:
     Interactive-content object"
  (let ((media (getf message-data :media)))
    (cond
      ((eq (getf media :type) :poll)
       (make-instance 'interactive-poll
                      :content-type :poll
                      :message-id message-id
                      :chat-id chat-id
                      :data media))
      (t (make-instance 'interactive-content
                        :content-type :message
                        :message-id message-id
                        :chat-id chat-id
                        :data message-data)))))

(defun create-interactive-poll (chat-id question options &key is-anonymous allows-multiple)
  "Create an interactive poll.

   Args:
     chat-id: Chat identifier
     question: Poll question
     options: List of option strings
     is-anonymous: If T, hide voter identities (default: T)
     allows-multiple: If T, allow multiple selections (default: NIL)

   Returns:
     Message object or NIL on error

   Example:
     (create-interactive-poll 123456 \"Favorite color?\" '(\"Red\" \"Blue\" \"Green\")
                              :allows-multiple nil)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMedia
                                      :peer (make-peer-chat :chat-id chat-id)
                                      :media (make-tl-object 'messageMediaPoll
                                                             :poll (make-poll-object
                                                                    :question question
                                                                    :answers (mapcar (lambda (opt)
                                                                                       (make-poll-answer
                                                                                        :text opt))
                                                                                     options))
                                                                    :closed nil
                                                                    :multiple (if allows-multiple t nil)
                                                                    :quiz nil))
                                      :silent nil
                                      :background nil)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (parse-message result))))
    (t (e)
      (log:error "Exception in create-interactive-poll: ~A" e)
      nil)))

(defun create-quiz-mode (chat-id question options correct-option &key explanation)
  "Create a quiz-mode poll.

   Args:
     chat-id: Chat identifier
     question: Quiz question
     options: List of option strings
     correct-option: Index of correct option (0-based)
     explanation: Optional explanation shown after answering

   Returns:
     Message object or NIL on error

   Example:
     (create-quiz-mode 123456 \"What is Lisp?\" '(\"Snake\" \"Programming Language\" \"Lizard\") 1
                       :explanation \"Lisp is a family of programming languages...\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMedia
                                      :peer (make-peer-chat :chat-id chat-id)
                                      :media (make-tl-object 'messageMediaPoll
                                                             :poll (make-poll-object
                                                                    :question question
                                                                    :answers (mapcar (lambda (opt)
                                                                                       (make-poll-answer
                                                                                        :text opt))
                                                                                     options))
                                                                    :closed nil
                                                                    :multiple nil
                                                                    :quiz t)
                                                             :correct-answers (list correct-option)
                                                             :explanation (or explanation ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (parse-message result))))
    (t (e)
      (log:error "Exception in create-quiz-mode: ~A" e)
      nil)))

(defun get-poll-results (chat-id message-id)
  "Get poll results.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier (poll message)

   Returns:
     Poll results plist or NIL on error

   Example:
     (get-poll-results 123456 789)"
  (handler-case
      (let* ((connection (get-connection))
             (result (rpc-call connection (make-tl-object 'messages.getPollResults
                                                          :peer (make-peer-chat :chat-id chat-id)
                                                          :msg-id message-id)
                               :timeout 5000)))
        (when result
          (list :total-voters (getf result :results :total)
                :options (mapcar (lambda (opt)
                                   (list :text (getf opt :text)
                                         :votes (getf opt :voters)))
                                 (getf result :results :options)))))
    (t (e)
      (log:error "Exception in get-poll-results: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: Animated Emoji (Bot API 9.4)
;;; ============================================================================

(defun send-animated-emoji (chat-id emoji &key reply-to-message-id)
  "Send an animated emoji.

   Args:
     chat-id: Chat identifier
     emoji: Emoji character (supports: 🎯 🎲 🎰 🎳 ⚽ 🏀)
     reply-to-message-id: Optional message ID to reply to

   Returns:
     Message object or NIL on error

   Example:
     (send-animated-emoji 123456 \"🎯\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMessage
                                      :peer (make-peer-chat :chat-id chat-id)
                                      :message emoji
                                      :entities (list (make-tl-object 'messageEntityEmoji
                                                                      :offset 0
                                                                      :length (length emoji)))
                                      :reply-to-msg-id reply-to-message-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (parse-message result))))
    (t (e)
      (log:error "Exception in send-animated-emoji: ~A" e)
      nil)))

(defun get-available-emoji ()
  "Get list of available animated emoji.

   Returns:
     List of emoji strings

   Example:
     (get-available-emoji)"
  '("🎯" "🎲" "🎰" "🎳" "⚽" "🏀" "🎭" "🎨" "🎬" "🎮" "🎪" "🎢" "🎡" "🎠"))

(defun get-emoji-status ()
  "Get current emoji status.

   Returns:
     Emoji status string or NIL

   Example:
     (get-emoji-status)"
  (let ((status (getf (get-user-status (get-my-user-id)) :emoji-status)))
    status))

(defun set-emoji-status (emoji &key text)
  "Set emoji status.

   Args:
     emoji: Emoji character for status
     text: Optional status text

   Returns:
     T on success, NIL on error

   Example:
     (set-emoji-status \"😎\" :text \"Feeling good\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.updateEmojiStatus
                                      :emoji-document-id emoji
                                      :status-text (or text ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (when (getf result :success)
              t))))
    (t (e)
      (log:error "Exception in set-emoji-status: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 5: Cache Management
;;; ============================================================================

(defun clear-custom-emoji-cache ()
  "Clear custom emoji cache.

   Returns:
     T

   Example:
     (clear-custom-emoji-cache)"
  (clrhash *custom-emoji-cache*)
  (clrhash *emoji-pack-cache*)
  t)

(defun get-custom-emoji-cache-stats ()
  "Get cache statistics.

   Returns:
     Plist with cache stats

   Example:
     (get-custom-emoji-cache-stats)"
  (list :emoji-cache-size (hash-table-count *custom-emoji-cache*)
        :pack-cache-size (hash-table-count *emoji-pack-cache*)))

;;; ============================================================================
;;; Section 6: DateTime MessageEntity (Bot API 9.5)
;;; ============================================================================

;;; ### DateTime Entity Class

(defclass datetime-entity ()
  ((datetime :initarg :datetime :reader datetime-value)
   (timezone :initform nil :initarg :timezone :reader datetime-timezone)
   (format :initform :iso8601 :initarg :format :reader datetime-format)
   (display-text :initarg :display-text :reader datetime-display-text)))

(defmethod print-object ((dt datetime-entity) stream)
  (print-unreadable-object (dt stream :type t)
    (format stream "~A" (datetime-display-text dt))))

;;; ### DateTime Entity API

(defun make-datetime-entity (datetime &key timezone (format :iso8601) display-text)
  "Create a datetime message entity.

   Args:
     datetime: Universal time or timestamp
     timezone: Optional timezone (e.g., \"UTC\", \"America/New_York\")
     format: Output format keyword (:iso8601, :rfc2822, :custom)
     display-text: Optional custom display text

   Returns:
     Datetime-entity object

   Example:
     (make-datetime-entity (get-universal-time) :timezone \"UTC\")
     (make-datetime-entity 1700000000 :display-text \"Meeting at 3PM\")"
  (let* ((display (or display-text
                      (case format
                        (:iso8601 (format-time-string "~Y-~M-~DT~h:~m:~sZ" datetime))
                        (:rfc2822 (format-time-string "~D ~b ~Y ~h:~m:~s ~z" datetime))
                        (otherwise (princ-to-string datetime)))))
         (entity (make-instance 'datetime-entity
                                :datetime datetime
                                :timezone timezone
                                :format format
                                :display-text display)))
    entity))

(defun parse-datetime-entity (text &optional start end)
  "Parse datetime from message text.

   Args:
     text: Message text containing datetime
     start: Start position of entity
     end: End position of entity

   Returns:
     Datetime-entity object or NIL

   Example:
     (parse-datetime-entity \"Meeting at 2024-01-15T15:00:00Z\" 12 32)"
  (handler-case
      (let* ((substring (subseq text start end))
             (datetime (parse-time-string substring)))
        (when datetime
          (make-datetime-entity datetime :display-text substring)))
    (t (e)
      (log:error "Exception in parse-datetime-entity: ~A" e)
      nil)))

(defun format-datetime-display (datetime-entity &key format timezone)
  "Format datetime entity for display.

   Args:
     datetime-entity: Datetime-entity object
     format: Output format (:iso8601, :rfc2822, :human, :relative)
     timezone: Optional timezone to convert to

   Returns:
     Formatted datetime string

   Example:
     (format-datetime-display entity :format :human :timezone \"Asia/Shanghai\")"
  (let* ((dt (datetime-value datetime-entity))
         (fmt (or format (datetime-format datetime-entity)))
         (tz (or timezone (datetime-timezone datetime-entity))))
    (case fmt
      (:iso8601 (format-time-string "~Y-~M-~DT~h:~m:~s" dt))
      (:rfc2822 (format-time-string "~D ~b ~Y ~h:~m:~s ~z" dt))
      (:human (format-time-string "~M/~D/~Y ~h:~m ~P" dt))
      (:relative (format-relative-time dt))
      (otherwise (datetime-display-text datetime-entity)))))

(defun get-timezone-aware-datetime (datetime timezone)
  "Get timezone-aware datetime.

   Args:
     datetime: Universal time
     timezone: Target timezone string

   Returns:
     Datetime in the specified timezone

   Example:
     (get-timezone-aware-datetime (get-universal-time) \"America/New_York\")"
  ;; Note: Full timezone conversion would require a timezone library
  ;; This is a placeholder that returns the datetime with timezone info
  (make-datetime-entity datetime :timezone timezone))

(defun convert-datetime-timezone (datetime-entity target-timezone)
  "Convert datetime to different timezone.

   Args:
     datetime-entity: Datetime-entity object
     target-timezone: Target timezone string

   Returns:
     New datetime-entity with converted timezone

   Example:
     (convert-datetime-timezone entity \"Europe/London\")"
  (make-datetime-entity (datetime-value datetime-entity)
                        :timezone target-timezone
                        :format (datetime-format datetime-entity)))

;;; ============================================================================
;;; Section 7: Managed Bots (Bot API 9.5)
;;; ============================================================================

;;; ### Managed Bot Classes

(defclass managed-bot-info ()
  ((bot-id :initarg :bot-id :reader managed-bot-id)
   (organization-id :initarg :organization-id :reader managed-org-id)
   (status :initform :active :initarg :status :reader managed-bot-status)
   (token-last-changed :initarg :token-last-changed :reader managed-token-date)
   (name :initform nil :initarg :name :reader managed-bot-name)
   (username :initform nil :initarg :username :reader managed-bot-username)))

(defclass token-change-notification ()
  ((bot-id :initarg :bot-id :reader token-change-bot-id)
   (change-type :initarg :change-type :reader token-change-type)
   (changed-at :initarg :changed-at :reader token-change-date)
   (changed-by :initarg :changed-by :reader token-change-by)
   (reason :initform nil :initarg :reason :reader token-change-reason)))

;;; ### Global State

(defvar *managed-bots-cache* (make-hash-table :test 'equal)
  "Cache for managed bot information")

(defvar *token-change-handlers* (make-hash-table :test 'equal)
  "Handlers for token change notifications")

;;; ### Managed Bots API

(defun register-managed-bot (bot-token &key organization-id name username)
  "Register a bot as a managed bot under an organization.

   Args:
     bot-token: Bot API token
     organization-id: Organization identifier
     name: Optional bot name
     username: Optional bot username

   Returns:
     Managed-bot-info object or NIL on error

   Example:
     (register-managed-bot \"123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11\"
                           :organization-id \"org_123\"
                           :name \"Support Bot\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.registerManagedBot
                                      :token bot-token
                                      :organization-id organization-id
                                      :name (or name "")
                                      :username (or username ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (let ((bot-info (make-instance 'managed-bot-info
                                           :bot-id (getf result :bot-id)
                                           :organization-id organization-id
                                           :status :active
                                           :token-last-changed (get-universal-time)
                                           :name name
                                           :username username)))
              (setf (gethash (managed-bot-id bot-info) *managed-bots-cache*) bot-info)
              bot-info))))
    (t (e)
      (log:error "Exception in register-managed-bot: ~A" e)
      nil)))

(defun get-bot-management-status (bot-id)
  "Get management status for a bot.

   Args:
     bot-id: Bot identifier

   Returns:
     Managed-bot-info object or NIL

   Example:
     (get-bot-management-status \"bot_123456\")"
  (or (gethash bot-id *managed-bots-cache*)
      (handler-case
          (let* ((connection (get-connection))
                 (result (rpc-call connection (make-tl-object 'bots.getManagedBot
                                                              :bot-id bot-id)
                                   :timeout 5000)))
            (when result
              (let ((bot-info (parse-managed-bot-info result)))
                (setf (gethash bot-id *managed-bots-cache*) bot-info)
                bot-info)))
        (t (e)
          (log:error "Exception in get-bot-management-status: ~A" e)
          nil))))

(defun parse-managed-bot-info (data)
  "Parse managed bot info from TL data.

   Args:
     data: TL response data

   Returns:
     Managed-bot-info object"
  (make-instance 'managed-bot-info
                 :bot-id (getf data :bot-id)
                 :organization-id (getf data :org-id)
                 :status (or (getf data :status) :active)
                 :token-last-changed (getf data :token-changed-date)
                 :name (getf data :name)
                 :username (getf data :username)))

(defun update-bot-credentials (bot-id new-token &key reason)
  "Update bot credentials (token).

   Args:
     bot-id: Bot identifier
     new-token: New API token
     reason: Optional reason for change

   Returns:
     T on success, NIL on error

   Example:
     (update-bot-credentials \"bot_123\" \"new-token-here\" :reason \"Security rotation\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.updateManagedBotToken
                                      :bot-id bot-id
                                      :new-token new-token
                                      :reason (or reason ""))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (when (getf result :success)
              ;; Update cache
              (when (gethash bot-id *managed-bots-cache*)
                (setf (slot-value (gethash bot-id *managed-bots-cache*) 'managed-token-date)
                      (get-universal-time)))
              t))))
    (t (e)
      (log:error "Exception in update-bot-credentials: ~A" e)
      nil)))

(defun handle-token-change-notification (notification-data)
  "Handle a token change notification.

   Args:
     notification-data: Token change notification plist

   Returns:
     T if handled, NIL otherwise

   Example:
     (handle-token-change-notification '(:bot-id \"bot_123\" :change-type :rotated :changed-at 1700000000))"
  (let* ((bot-id (getf notification-data :bot-id))
         (notification (make-instance 'token-change-notification
                                      :bot-id bot-id
                                      :change-type (getf notification-data :change-type)
                                      :changed-at (getf notification-data :changed-at)
                                      :changed-by (getf notification-data :changed-by))))
    ;; Call registered handlers
    (maphash (lambda (handler-id handler-fn)
               (declare (ignore handler-id))
               (funcall handler-fn notification))
             *token-change-handlers*)
    t))

(defun get-token-change-history (bot-id &key limit)
  "Get token change history for a bot.

   Args:
     bot-id: Bot identifier
     limit: Maximum number of entries to return (default: 50)

   Returns:
     List of token-change-notification objects

   Example:
     (get-token-change-history \"bot_123\" :limit 20)"
  (handler-case
      (let* ((connection (get-connection))
             (result (rpc-call connection (make-tl-object 'bots.getTokenChangeHistory
                                                          :bot-id bot-id
                                                          :limit (or limit 50))
                               :timeout 5000)))
        (when result
          (mapcar (lambda (item)
                    (make-instance 'token-change-notification
                                   :bot-id bot-id
                                   :change-type (getf item :type)
                                   :changed-at (getf item :date)
                                   :changed-by (getf item :admin-id)))
                  (getf result :changes))))
    (t (e)
      (log:error "Exception in get-token-change-history: ~A" e)
      nil)))

(defun get-managed-bot-info (bot-id)
  "Get detailed information about a managed bot.

   Args:
     bot-id: Bot identifier

   Returns:
     Managed-bot-info object or NIL

   Example:
     (get-managed-bot-info \"bot_123456\")"
  (get-bot-management-status bot-id))

(defun unregister-managed-bot (bot-id)
  "Unregister a bot from managed status.

   Args:
     bot-id: Bot identifier

   Returns:
     T on success, NIL on error

   Example:
     (unregister-managed-bot \"bot_123456\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'bots.unregisterManagedBot
                                      :bot-id bot-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (when (getf result :success)
              (remhash bot-id *managed-bots-cache*)
              t))))
    (t (e)
      (log:error "Exception in unregister-managed-bot: ~A" e)
      nil)))

(defun register-token-change-handler (handler-id handler-fn)
  "Register a handler for token change notifications.

   Args:
     handler-id: Unique handler identifier
     handler-fn: Function to call on notification

   Returns:
     T

   Example:
     (register-token-change-handler 'my-handler
                                    (lambda (notif) (format t \"Token changed: ~A~\" notif)))"
  (setf (gethash handler-id *token-change-handlers*) handler-fn)
  t)

(defun unregister-token-change-handler (handler-id)
  "Unregister a token change handler.

   Args:
     handler-id: Handler identifier

   Returns:
     T

   Example:
     (unregister-token-change-handler 'my-handler)"
  (remhash handler-id *token-change-handlers*)
  t)

;;; ============================================================================
;;; Section 8: Mini App Device Access (Bot API 9.6)
;;; ============================================================================

;;; ### Device Access API

(defun request-camera-access ()
  "Request camera access for Mini App.

   Returns:
     T if granted, NIL if denied

   Example:
     (request-camera-access)"
  ;; This requires CLOG/Web integration
  ;; Placeholder implementation
  (log:info "Camera access requested")
  t)

(defun request-microphone-access ()
  "Request microphone access for Mini App.

   Returns:
     T if granted, NIL if denied

   Example:
     (request-microphone-access)"
  ;; This requires CLOG/Web integration
  (log:info "Microphone access requested")
  t)

(defun capture-photo (&key quality)
  "Capture a photo using device camera.

   Args:
     quality: Image quality (:low, :medium, :high)

   Returns:
     Image data or NIL on error

   Example:
     (capture-photo :quality :high)"
  ;; This requires CLOG/Web integration with getUserMedia
  (log:info "Photo capture requested (quality: ~A)" quality)
  nil)

(defun capture-video (&key duration quality)
  "Capture a video using device camera.

   Args:
     duration: Maximum recording duration in seconds
     quality: Video quality (:low, :medium, :high)

   Returns:
     Video data or NIL on error

   Example:
     (capture-video :duration 30 :quality :high)"
  ;; This requires CLOG/Web integration
  (log:info "Video capture requested (duration: ~As, quality: ~A)" duration quality)
  nil)

(defun get-media-stream (&key video audio)
  "Get access to media stream.

   Args:
     video: If T, include video track
     audio: If T, include audio track

   Returns:
     Stream identifier or NIL

   Example:
     (get-media-stream :video t :audio t)"
  ;; This requires CLOG/Web integration with MediaStream API
  (log:info "Media stream requested (video: ~A, audio: ~A)" video audio)
  nil)

(defun release-media-stream (stream-id)
  "Release a media stream.

   Args:
     stream-id: Stream identifier to release

   Returns:
     T on success

   Example:
     (release-media-stream \"stream_123\")"
  (log:info "Media stream ~A released" stream-id)
  t)

(defun get-device-permissions ()
  "Get current device permissions.

   Returns:
     Plist with permission status

   Example:
     (get-device-permissions)"
  (list :camera :prompt
        :microphone :prompt
        :location :denied))

(defun check-device-support (feature)
  "Check if device supports a feature.

   Args:
     feature: Feature keyword (:camera, :microphone, :location, :contacts)

   Returns:
     T if supported, NIL otherwise

   Example:
     (check-device-support :camera)"
  (case feature
    (:camera t)
    (:microphone t)
    (:location nil)
    (:contacts nil)
    (otherwise nil)))

;;; ============================================================================
;;; Section 9: Mini App Theme Integration (Bot API 9.6)
;;; ============================================================================

;;; ### Mini App Theme Class

(defclass mini-app-theme ()
  ((bg-color :initform "#ffffff" :initarg :bg-color :reader mini-app-bg-color)
   (text-color :initform "#000000" :initarg :text-color :reader mini-app-text-color)
   (hint-color :initform "#999999" :initarg :hint-color :reader mini-app-hint-color)
   (link-color :initform "#2481cc" :initarg :link-color :reader mini-app-link-color)
   (button-color :initform "#2481cc" :initarg :button-color :reader mini-app-button-color)
   (secondary-bg-color :initform "#f4f4f5" :initarg :secondary-bg-color :reader mini-app-secondary-bg)
   (header-bg-color :initform "#ffffff" :initarg :header-bg-color :reader mini-app-header-bg)
   (is-dark :initform nil :initarg :is-dark :reader mini-app-is-dark)))

(defmethod print-object ((theme mini-app-theme) stream)
  (print-unreadable-object (theme stream :type t)
    (format stream "~A theme" (if (mini-app-is-dark theme) "dark" "light"))))

;;; ### Global State

(defvar *mini-app-theme* nil
  "Current Mini App theme")

(defvar *theme-change-handlers* (make-hash-table :test 'equal)
  "Handlers for theme change notifications")

;;; ### Mini App Theme API

(defun get-mini-app-theme ()
  "Get current Mini App theme.

   Returns:
     Mini-app-theme object

   Example:
     (get-mini-app-theme)"
  (or *mini-app-theme*
      (make-instance 'mini-app-theme)))

(defun sync-with-client-theme (&optional client-theme-data)
  "Sync Mini App theme with client theme.

   Args:
     client-theme-data: Optional theme data from client

   Returns:
     Mini-app-theme object

   Example:
     (sync-with-client-theme)"
  (let ((theme (if client-theme-data
                   (parse-mini-app-theme client-theme-data)
                   (make-instance 'mini-app-theme))))
    (setf *mini-app-theme* theme)
    theme))

(defun parse-mini-app-theme (data)
  "Parse Mini App theme from data.

   Args:
     data: Theme data plist

   Returns:
     Mini-app-theme object"
  (make-instance 'mini-app-theme
                 :bg-color (getf data :bg_color "#ffffff")
                 :text-color (getf data :text_color "#000000")
                 :hint-color (getf data :hint_color "#999999")
                 :link-color (getf data :link_color "#2481cc")
                 :button-color (getf data :button_color "#2481cc")
                 :secondary-bg-color (getf data :secondary_bg_color "#f4f4f5")
                 :header-bg-color (getf data :header_bg_color "#ffffff")
                 :is-dark (getf data :is_dark nil)))

(defun apply-theme-parameters (&key bg-color text-color button-color)
  "Apply custom theme parameters.

   Args:
     bg-color: Background color hex string
     text-color: Text color hex string
     button-color: Button color hex string

   Returns:
     T

   Example:
     (apply-theme-parameters :bg-color \"#1a1a1a\" :text-color \"#ffffff\"))"
  (when (and *mini-app-theme* bg-color)
    (setf (slot-value *mini-app-theme* 'bg-color) bg-color))
  (when (and *mini-app-theme* text-color)
    (setf (slot-value *mini-app-theme* 'text-color) text-color))
  (when (and *mini-app-theme* button-color)
    (setf (slot-value *mini-app-theme* 'button-color) button-color))
  t)

(defun on-theme-change (handler-id handler-fn)
  "Register handler for theme change events.

   Args:
     handler-id: Unique handler identifier
     handler-fn: Function to call on theme change

   Returns:
     T

   Example:
     (on-theme-change 'ui-update (lambda (theme) (update-ui theme)))"
  (setf (gethash handler-id *theme-change-handlers*) handler-fn)
  t)

(defun get-theme-parameters ()
  "Get current theme parameters.

   Returns:
     Plist with theme parameters

   Example:
     (get-theme-parameters)"
  (let ((theme (get-mini-app-theme)))
    (list :bg-color (mini-app-bg-color theme)
          :text-color (mini-app-text-color theme)
          :hint-color (mini-app-hint-color theme)
          :link-color (mini-app-link-color theme)
          :button-color (mini-app-button-color theme)
          :secondary-bg-color (mini-app-secondary-bg theme)
          :header-bg-color (mini-app-header-bg theme)
          :is-dark (mini-app-is-dark theme))))

(defun set-theme-override (theme-preset)
  "Set theme override using preset.

   Args:
     theme-preset: Preset keyword (:dark, :light, :auto)

   Returns:
     T

   Example:
     (set-theme-override :dark)"
  (let ((theme (make-instance 'mini-app-theme
                              :is-dark (eq theme-preset :dark)
                              :bg-color (if (eq theme-preset :dark) "#1a1a1a" "#ffffff")
                              :text-color (if (eq theme-preset :dark) "#ffffff" "#000000"))))
    (setf *mini-app-theme* theme)
    t))
