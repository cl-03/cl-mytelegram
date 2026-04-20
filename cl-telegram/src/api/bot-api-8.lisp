;;; bot-api-8.lisp --- Bot API 8.0 new features support
;;;
;;; Provides support for Bot API 8.0 features released November 2024:
;;; - Message reactions with all emoji types
;;; - Emoji status management
;;; - Advanced media editing
;;; - Story highlights management
;;; - Message translation
;;;
;;; Reference: https://core.telegram.org/bots/api-changelog

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Message Reactions (Bot API 8.0)
;;; ============================================================================

;;; ### Reaction Types

(defclass reaction-type ()
  ((type :initarg :type :reader reaction-type-type)
   (emoji :initarg :emoji :initform nil :reader reaction-type-emoji)
   (custom-emoji-id :initarg :custom-emoji-id :initform nil :reader reaction-type-custom-emoji-id)))

(defclass reaction-count ()
  ((reaction :initarg :reaction :reader reaction-count-reaction)
   (count :initarg :count :reader reaction-count-count)
   (is-selected :initarg :is-selected :initform nil :reader reaction-count-is-selected)))

(defclass message-reaction-update ()
  ((chat-id :initarg :chat-id :reader message-reaction-chat-id)
   (message-id :initarg :message-id :reader message-reaction-message-id)
   (date :initarg :date :reader message-reaction-date)
   (old-reaction :initarg :old-reaction :reader message-reaction-old-reaction)
   (new-reaction :initarg :new-reaction :reader message-reaction-new-reaction)))

;;; ### Global State

(defvar *available-reaction-types* nil
  "List of available reaction types (emoji and custom emoji)")

(defvar *reaction-update-handlers* (make-hash-table :test 'equal)
  "Handlers for message reaction updates")

;;; ### Reaction Type Constructors

(defun make-reaction-type-emoji (emoji)
  "Create an emoji reaction type.

   Args:
     emoji: Emoji character or string (e.g., \"👍\", \"❤️\")

   Returns:
     Reaction-type object"
  (make-instance 'reaction-type
                 :type :emoji
                 :emoji emoji))

(defun make-reaction-type-custom-emoji (custom-emoji-id)
  "Create a custom emoji reaction type.

   Args:
     custom-emoji-id: Custom emoji file ID

   Returns:
     Reaction-type object"
  (make-instance 'reaction-type
                 :type :custom-emoji
                 :custom-emoji-id custom-emoji-id))

(defun make-reaction-type-star ()
  "Create a star reaction type (premium feature).

   Returns:
     Reaction-type object"
  (make-instance 'reaction-type
                 :type :star))

;;; ### Message Reactions API

(defun send-message-reaction (chat-id message-id reaction &key is-big)
  "Send a reaction to a message.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier
     reaction: Reaction-type object or emoji string
     is-big: If T, send a big animation (default: NIL)

   Returns:
     T on success, NIL on error

   Example:
     (send-message-reaction 123 456 \"👍\")
     (send-message-reaction 123 456 (make-reaction-type-emoji \"❤️\"))
     (send-message-reaction 123 456 (make-reaction-type-custom-emoji \" sticker_id \"))"
  (handler-case
      (let* ((connection (get-connection))
             (reaction-obj (if (stringp reaction)
                               (make-reaction-type-emoji reaction)
                               reaction))
             (reaction-tl (reaction-to-tl reaction-obj))
             (request (make-tl-object 'messages.sendReaction
                                      :peer (make-peer-by-chat-id chat-id)
                                      :msg-id message-id
                                      :reaction (list reaction-tl)
                                      :big (if is-big :bool-true :bool-false))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to send reaction: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in send-message-reaction: ~A" e)
      nil)))

(defun get-message-reactions (chat-id message-id)
  "Get reactions for a message with detailed breakdown.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier

   Returns:
     List of reaction-count objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getMessageReactions
                                      :peer (make-peer-by-chat-id chat-id)
                                      :msg-id message-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to get message reactions: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in get-message-reactions: ~A" e)
      nil)))

(defun remove-message-reaction (chat-id message-id &optional reaction)
  "Remove a reaction from a message.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier
     reaction: Specific reaction to remove (removes all if NIL)

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendReaction
                                      :peer (make-peer-by-chat-id chat-id)
                                      :msg-id message-id
                                      :reaction nil
                                      :big :bool-false)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to remove reaction: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in remove-message-reaction: ~A" e)
      nil)))

(defun get-available-reactions ()
  "Get list of available reactions for the current user.

   Returns:
     List of reaction-type objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getAvailableReactions)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to get available reactions: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in get-available-reactions: ~A" e)
      nil)))

;;; ### Reaction Update Handlers

(defun on-message-reaction (handler-fn &optional chat-id)
  "Register a handler for message reaction updates.

   Args:
     handler-fn: Function to call when reaction changes
                 (receives: chat-id message-id old-reaction new-reaction)
     chat-id: Optional specific chat to monitor (NIL for all)

   Returns:
     Handler ID for unregistering

   Example:
     (on-message-reaction (lambda (chat-id msg-id old new)
                            (format t \"Reaction changed in ~A: ~A -> ~A~%\"
                                    chat-id old new)))"
  (let ((handler-id (format nil "~A-~A" (or chat-id "all") (gensym))))
    (setf (gethash handler-id *reaction-update-handlers*)
          (list :fn handler-fn :chat-id chat-id))
    handler-id))

(defun unregister-reaction-handler (handler-id)
  "Unregister a reaction update handler.

   Args:
     handler-id: Handler ID from on-message-reaction

   Returns:
     T if handler was found and removed, NIL otherwise"
  (if (gethash handler-id *reaction-update-handlers*)
      (progn
        (remhash handler-id *reaction-update-handlers*)
        T)
      NIL))

(defun process-reaction-update (update)
  "Process an incoming reaction update.

   Args:
     update: Message-reaction-update object"
  (maphash (lambda (id handler-info)
             (let ((chat-id (getf handler-info :chat-id))
                   (fn (getf handler-info :fn)))
               (when (or (null chat-id)
                         (equal chat-id (message-reaction-chat-id update)))
                 (funcall fn
                          (message-reaction-chat-id update)
                          (message-reaction-message-id update)
                          (message-reaction-old-reaction update)
                          (message-reaction-new-reaction update)))))
           *reaction-update-handlers*))

;;; ### Helper Functions

(defun reaction-to-tl (reaction-type)
  "Convert reaction-type to TL object.

   Args:
     reaction-type: Reaction-type object

   Returns:
     TL object for API request"
  (case (reaction-type-type reaction-type)
    (:emoji
     (make-tl-object 'reactionEmoji :emoticon (reaction-type-emoji reaction-type)))
    (:custom-emoji
     (make-tl-object 'reactionCustomEmoji
                     :document-id (reaction-type-custom-emoji-id reaction-type)))
    (:star
     (make-tl-object 'reactionStar))
    (otherwise
     (error "Unknown reaction type: ~A" (reaction-type-type reaction-type)))))

(defun parse-reaction-from-tl (tl-object)
  "Parse reaction from TL object.

   Args:
     tl-object: TL reaction object

   Returns:
     Reaction-type object"
  (cond
    ((tl-type-p tl-object 'reactionEmoji)
     (make-reaction-type-emoji (getf tl-object :emoticon)))
    ((tl-type-p tl-object 'reactionCustomEmoji)
     (make-reaction-type-custom-emoji (getf tl-object :document-id)))
    ((tl-type-p tl-object 'reactionStar)
     (make-reaction-type-star))
    (t
     (error "Unknown reaction TL type"))))

;;; ============================================================================
;;; Section 2: Emoji Status (Bot API 8.0)
;;; ============================================================================

;;; ### Emoji Status Types

(defclass emoji-status ()
  ((document-id :initarg :document-id :reader emoji-status-document-id)
   (emoji :initarg :emoji :initform nil :reader emoji-status-emoji)
   (is-premium :initarg :is-premium :initform nil :reader emoji-status-is-premium)
   (is-active :initarg :is-active :initform nil :reader emoji-status-is-active)))

;;; ### Global State

(defvar *user-emoji-status* nil
  "Current user's emoji status")

(defvar *available-emoji-statuses* nil
  "Available emoji statuses for the current user")

;;; ### Emoji Status API

(defun set-emoji-status (status &key duration-seconds)
  "Set user's emoji status.

   Args:
     status: Emoji string or custom emoji ID
     duration-seconds: Optional duration in seconds (for temporary status)

   Returns:
     T on success, NIL on error

   Example:
     (set-emoji-status \"🔥\")
     (set-emoji-status \"custom_emoji_id\" :duration-seconds 3600)"
  (handler-case
      (let* ((connection (get-connection))
             (is-custom (and (stringp status)
                             (or (search "custom" status)
                                 (not (find-if #'alpha-char-p status)))))
             (request (make-tl-object 'account.updateEmojiStatus
                                      :emoji-status
                                      (if is-custom
                                          (make-tl-object 'emojiStatusDocumentId
                                                          :document-id (parse-integer status :junk-allowed T))
                                          (make-tl-object 'emojiStatusUnicode
                                                          :emoticon status)))))
        (when duration-seconds
          (setf (slot-value request 'until-date)
                (+ (get-universal-time) duration-seconds)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to set emoji status: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in set-emoji-status: ~A" e)
      nil)))

(defun clear-emoji-status ()
  "Clear user's emoji status.

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.removeEmojiStatus)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to clear emoji status: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in clear-emoji-status: ~A" e)
      nil)))

(defun get-emoji-statuses (&optional include-premium)
  "Get available emoji statuses.

   Args:
     include-premium: Include premium-only statuses (default: NIL)

   Returns:
     List of emoji-status objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'emoji.getAvailableEmojiStatuses
                                      :include-premium (if include-premium :bool-true :bool-false))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to get emoji statuses: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in get-emoji-statuses: ~A" e)
      nil)))

(defun get-user-emoji-status (user-id)
  "Get a user's current emoji status.

   Args:
     user-id: User identifier

   Returns:
     Emoji-status object or NIL"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'users.getUserEmojiStatus
                                      :user-id user-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to get user emoji status: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in get-user-emoji-status: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 3: Advanced Media Editing (Bot API 8.0)
;;; ============================================================================

;;; ### Media Edit Types

(defclass media-edit-options ()
  ((crop-rectangle :initarg :crop-rectangle :initform nil :reader media-edit-crop)
   (rotation-angle :initarg :rotation-angle :initform nil :reader media-edit-rotation)
   (filter-type :initarg :filter-type :initform nil :reader media-edit-filter)
   (overlay-text :initarg :overlay-text :initform nil :reader media-edit-overlay-text)
   (overlay-emoji :initarg :overlay-emoji :initform nil :reader media-edit-overlay-emoji)
   (caption :initarg :caption :initform nil :reader media-edit-caption)
   (parse-mode :initarg :parse-mode :initform nil :reader media-edit-parse-mode)))

;;; ### Media Filters

(defparameter +available-media-filters+
  '("none" "clarendon" "ginger" "moon" "nashville" "perpetua" "x-pro-ii"
    "aden" "reyes" "junо" "slumber" "crema" "ludwig" "inkwell" "haze"
    "brightness" "contrast" "saturation" "warmth" "vignette" "blur"
    "sharpen" "noise" "pixelate" "vintage" "drama" "grayscale" "sepia"])

;;; ### Advanced Media Editing API

(defun edit-message-media-advanced (chat-id message-id media-file &key options)
  "Edit message media with advanced options.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier
     media-file: New media file (file ID or path)
     options: Media-edit-options object

   Returns:
     Updated message object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (input-media (make-tl-object 'inputMediaPhoto
                                          :media (if (stringp media-file)
                                                     media-file
                                                     (format nil "attach://~A" media-file))))
             (request (make-tl-object 'messages.editMessage
                                      :peer (make-peer-by-chat-id chat-id)
                                      :id message-id
                                      :media input-media)))
        (when options
          (when (media-edit-caption options)
            (setf (slot-value request 'message) (media-edit-caption options)))
          (when (media-edit-parse-mode options)
            (setf (slot-value request 'parse-mode) (media-edit-parse-mode options))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to edit message media: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in edit-message-media-advanced: ~A" e)
      nil)))

(defun crop-media (media-file &key x y width height)
  "Crop media file.

   Args:
     media-file: Media file path or ID
     x: X coordinate of crop origin
     y: Y coordinate of crop origin
     width: Width of crop area
     height: Height of crop area

   Returns:
     Cropped media file path or NIL on error"
  (handler-case
      (let* ((image (cl-telegram/image-processing:load-image media-file)))
        (if image
            (let* ((cropped (cl-telegram/image-processing:crop-image image x y width height))
                   (output-path (format nil "~A.cropped~A"
                                        (namestring (pathname media-file))
                                        (pathname-type media-file))))
              (cl-telegram/image-processing:save-image cropped output-path)
              output-path)
            (progn
              (log:error "Failed to load image: ~A" media-file)
              nil))))
    (t (e)
      (log:error "Exception in crop-media: ~A" e)
      nil)))

(defun rotate-media (media-file &key angle)
  "Rotate media file.

   Args:
     media-file: Media file path or ID
     angle: Rotation angle in degrees (90, 180, 270)

   Returns:
     Rotated media file path or NIL on error"
  (handler-case
      (let* ((image (cl-telegram/image-processing:load-image media-file)))
        (if image
            (let* ((rotated (cl-telegram/image-processing:rotate-image image angle))
                   (output-path (format nil "~A.rotated~A"
                                        (namestring (pathname media-file))
                                        (pathname-type media-file))))
              (cl-telegram/image-processing:save-image rotated output-path)
              output-path)
            (progn
              (log:error "Failed to load image: ~A" media-file)
              nil))))
    (t (e)
      (log:error "Exception in rotate-media: ~A" e)
      nil)))

(defun apply-media-filter (media-file filter-type &key (intensity 1.0))
  "Apply filter to media.

   Args:
     media-file: Media file path or ID
     filter-type: Filter name from +available-media-filters+
     intensity: Filter intensity (0.0-1.0, default: 1.0)

   Returns:
     Filtered media file path or NIL on error"
  (handler-case
      (let* ((image (cl-telegram/image-processing:load-image media-file)))
        (if image
            (let* ((filtered (cl-telegram/image-processing:apply-filter-by-name
                              image filter-type :intensity intensity))
                   (output-path (format nil "~A.~A~A"
                                        (namestring (pathname media-file))
                                        filter-type
                                        (pathname-type media-file))))
              (cl-telegram/image-processing:save-image filtered output-path)
              output-path)
            (progn
              (log:error "Failed to load image: ~A" media-file)
              nil))))
    (t (e)
      (log:error "Exception in apply-media-filter: ~A" e)
      nil)))

(defun add-text-overlay (media-file text &key (position :center) (font-size 24) (color :white) background)
  "Add text overlay to media.

   Args:
     media-file: Media file path or ID
     text: Text to overlay
     position: Position keyword (:top-left, :top-right, :bottom-left, :bottom-right, :center)
     font-size: Font size in pixels
     color: Text color (hex string or keyword)
     background: Optional background color

   Returns:
     Media file with overlay or NIL on error"
  (handler-case
      (let* ((image (cl-telegram/image-processing:load-image media-file)))
        (if image
            (let* ((overlayed (cl-telegram/image-processing:add-text-overlay
                               image text
                               :position position
                               :font-size font-size
                               :color color
                               :opacity 1.0))
                   (output-path (format nil "~A.text~A"
                                        (namestring (pathname media-file))
                                        (pathname-type media-file))))
              (cl-telegram/image-processing:save-image overlayed output-path)
              output-path)
            (progn
              (log:error "Failed to load image: ~A" media-file)
              nil))))
    (t (e)
      (log:error "Exception in add-text-overlay: ~A" e)
      nil)))

(defun add-emoji-sticker (media-file emoji-id &key (position :center) (size 48) (opacity 1.0))
  "Add emoji sticker overlay to media.

   Args:
     media-file: Media file path or ID
     emoji-id: Custom emoji ID or standard emoji character
     position: Position as (x y) coordinates or keyword
     size: Sticker size in pixels
     opacity: Opacity (0.0-1.0)

   Returns:
     Media file with sticker or NIL on error"
  (handler-case
      (let* ((image (cl-telegram/image-processing:load-image media-file)))
        (if image
            (let* ((overlayed (cl-telegram/image-processing:add-emoji-overlay
                               image emoji-id
                               :position position
                               :size size
                               :opacity opacity))
                   (output-path (format nil "~A.emoji~A"
                                        (namestring (pathname media-file))
                                        (pathname-type media-file))))
              (cl-telegram/image-processing:save-image overlayed output-path)
              output-path)
            (progn
              (log:error "Failed to load image: ~A" media-file)
              nil))))
    (t (e)
      (log:error "Exception in add-emoji-sticker: ~A" e)
      nil)))

(defun edit-message-caption (chat-id message-id caption &key parse-mode entities)
  "Edit message caption.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier
     caption: New caption text
     parse-mode: Parse mode (:markdown, :html, :markdown-v2)
     entities: Message entities for formatting

   Returns:
     Updated message or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.editMessage
                                      :peer (make-peer-by-chat-id chat-id)
                                      :id message-id
                                      :message caption
                                      :parse-mode (case parse-mode
                                                      (:markdown :message-parser-markdown)
                                                      (:markdown-v2 :message-parser-markdown-v2)
                                                      (:html :message-parser-html)
                                                      (otherwise nil)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to edit caption: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in edit-message-caption: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: Story Highlights Management (Bot API 8.0)
;;; ============================================================================

;;; ### Highlight Types

(defclass story-highlight ()
  ((id :initarg :id :reader story-highlight-id)
   (title :initarg :title :reader story-highlight-title)
   (cover-media :initarg :cover-media :reader story-highlight-cover)
   (stories :initarg :stories :initform nil :reader story-highlight-stories)
   (date-created :initarg :date-created :reader story-highlight-date-created)
   (is-hidden :initarg :is-hidden :initform nil :reader story-highlight-is-hidden)
   (privacy-type :initarg :privacy-type :initform :public :reader story-highlight-privacy)))

(defclass highlight-cover ()
  ((media-id :initarg :media-id :reader highlight-cover-media-id)
   (crop-area :initarg :crop-area :initform nil :reader highlight-cover-crop)
   (filter :initarg :filter :initform nil :reader highlight-cover-filter)))

;;; ### Global State

(defvar *highlights-cache* (make-hash-table :test 'equal)
  "Cache for story highlights")

(defvar *highlight-covers-cache* (make-hash-table :test 'equal)
  "Cache for highlight cover media")

;;; ### Story Highlights API

(defun create-highlight (title &key cover-media story-ids privacy)
  "Create a new story highlight.

   Args:
     title: Highlight title
     cover-media: Cover media file ID or highlight-cover object
     story-ids: List of initial story IDs
     privacy: Privacy setting (:public, :contacts, :close-friends, :custom)

   Returns:
     Story-highlight object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.createHighlight
                                      :title title
                                      :cover (if (stringp cover-media)
                                                 (make-tl-object 'inputMediaPhoto :media cover-media)
                                                 cover-media)
                                      :story-ids (or story-ids nil))))
        (when privacy
          (setf (slot-value request 'privacy)
                (privacy-to-tl privacy)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to create highlight: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in create-highlight: ~A" e)
      nil)))

(defun edit-highlight (highlight-id &key title cover-media story-ids)
  "Edit a story highlight.

   Args:
     highlight-id: Highlight identifier
     title: New title (optional)
     cover-media: New cover media (optional)
     story-ids: New list of story IDs (optional)

   Returns:
     Updated highlight or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.editHighlight
                                      :highlight-id highlight-id)))
        (when title
          (setf (slot-value request 'title) title))
        (when cover-media
          (setf (slot-value request 'cover) cover-media))
        (when story-ids
          (setf (slot-value request 'story-ids) story-ids))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to edit highlight: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in edit-highlight: ~A" e)
      nil)))

(defun edit-highlight-cover (highlight-id cover-media &key crop-area filter)
  "Edit highlight cover media.

   Args:
     highlight-id: Highlight identifier
     cover-media: New cover media
     crop-area: Crop rectangle (x y width height)
     filter: Filter to apply

   Returns:
     Updated highlight or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (cover (make-tl-object 'inputMediaPhoto :media cover-media)))
        (when crop-area
          (setf (slot-value cover 'crop) crop-area))
        (when filter
          (setf (slot-value cover 'filter) filter))
        (edit-highlight highlight-id :cover cover))
    (t (e)
      (log:error "Exception in edit-highlight-cover: ~A" e)
      nil)))

(defun reorder-highlights (highlight-ids)
  "Reorder story highlights.

   Args:
     highlight-ids: List of highlight IDs in new order

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.reorderHighlights
                                      :ids highlight-ids)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to reorder highlights: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in reorder-highlights: ~A" e)
      nil)))

(defun get-highlights (&optional user-id)
  "Get story highlights.

   Args:
     user-id: User ID (NIL for current user)

   Returns:
     List of story-highlight objects"
  (let ((cache-key (or user-id "self")))
    (let ((cached (gethash cache-key *highlights-cache*)))
      (when cached
        (return-from get-highlights cached))))
  (handler-case
      (let* ((connection (get-connection))
             (request (if user-id
                          (make-tl-object 'stories.getUserHighlights
                                          :user-id user-id)
                          (make-tl-object 'stories.getHighlights))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to get highlights: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in get-highlights: ~A" e)
      nil)))

(defun delete-highlight (highlight-id)
  "Delete a story highlight.

   Args:
     highlight-id: Highlight identifier

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.deleteHighlight
                                      :highlight-id highlight-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to delete highlight: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in delete-highlight: ~A" e)
      nil)))

(defun set-highlight-privacy (highlight-id privacy-type)
  "Set highlight privacy settings.

   Args:
     highlight-id: Highlight identifier
     privacy-type: Privacy keyword (:public, :contacts, :close-friends, :custom)

   Returns:
     T on success, NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.editHighlight
                                      :highlight-id highlight-id
                                      :privacy (privacy-to-tl privacy-type))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (e)
            (log:error "Failed to set highlight privacy: ~A" e)
            nil)))
    (t (e)
      (log:error "Exception in set-highlight-privacy: ~A" e)
      nil)))

(defun add-stories-to-highlight (highlight-id story-ids)
  "Add stories to an existing highlight.

   Args:
     highlight-id: Highlight identifier
     story-ids: List of story IDs to add

   Returns:
     Updated highlight or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (current (gethash highlight-id *highlights-cache*))
             (existing-stories (when current (story-highlight-stories current)))
             (all-stories (remove-duplicates (append existing-stories story-ids))))
        (edit-highlight highlight-id :story-ids all-stories))
    (t (e)
      (log:error "Exception in add-stories-to-highlight: ~A" e)
      nil)))

(defun remove-highlight (highlight-id)
  "Remove a highlight (alias for delete-highlight).

   Args:
     highlight-id: Highlight identifier

   Returns:
     T on success, NIL on error"
  (delete-highlight highlight-id))

;;; ============================================================================
;;; Section 5: Message Translation (Bot API 8.0)
;;; ============================================================================

;;; ### Translation Types

(defclass translation-result ()
  ((original-text :initarg :original-text :reader translation-original-text)
   (translated-text :initarg :translated-text :reader translation-translated-text)
   (source-language :initarg :source-language :reader translation-source-language)
   (target-language :initarg :target-language :reader translation-target-language)
   (was-auto-detected :initarg :was-auto-detected :initform nil :reader translation-auto-detected)))

;;; ### Supported Languages

(defparameter +supported-translation-languages+
  '(("af" . "Afrikaans") ("ar" . "Arabic") ("az" . "Azerbaijani") ("be" . "Belarusian")
    ("bg" . "Bulgarian") ("bn" . "Bengali") ("ca" . "Catalan") ("cs" . "Czech")
    ("cy" . "Welsh") ("da" . "Danish") ("de" . "German") ("el" . "Greek")
    ("en" . "English") ("es" . "Spanish") ("et" . "Estonian") ("eu" . "Basque")
    ("fa" . "Persian") ("fi" . "Finnish") ("fr" . "French") ("ga" . "Irish")
    ("gl" . "Galician") ("gu" . "Gujarati") ("he" . "Hebrew") ("hi" . "Hindi")
    ("hr" . "Croatian") ("hu" . "Hungarian") ("hy" . "Armenian") ("id" . "Indonesian")
    ("is" . "Icelandic") ("it" . "Italian") ("ja" . "Japanese") ("ka" . "Georgian")
    ("kk" . "Kazakh") ("kn" . "Kannada") ("ko" . "Korean") ("lt" . "Lithuanian")
    ("lv" . "Latvian") ("mk" . "Macedonian") ("ml" . "Malayalam") ("mr" . "Marathi")
    ("ms" . "Malay") ("mt" . "Maltese") ("ne" . "Nepali") ("nl" . "Dutch")
    ("no" . "Norwegian") ("pa" . "Punjabi") ("pl" . "Polish") ("pt" . "Portuguese")
    ("ro" . "Romanian") ("ru" . "Russian") ("sk" . "Slovak") ("sl" . "Slovenian")
    ("sq" . "Albanian") ("sr" . "Serbian") ("sv" . "Swedish") ("sw" . "Swahili")
    ("ta" . "Tamil") ("te" . "Telugu") ("th" . "Thai") ("tl" . "Tagalog")
    ("tr" . "Turkish") ("uk" . "Ukrainian") ("ur" . "Urdu") ("uz" . "Uzbek")
    ("vi" . "Vietnamese") ("zh" . "Chinese") ("zh-cn" . "Chinese (Simplified)")
    ("zh-tw" . "Chinese (Traditional)")))

;;; ### Global State

(defvar *translation-cache* (make-hash-table :test 'equal)
  "Cache for translations")

(defvar *chat-language-preferences* (make-hash-table :test 'equal)
  "Language preferences per chat")

(defvar *translation-history* nil
  "Recent translation history")

;;; ### Translation API

(defun translate-message (chat-id message-id &key target-language)
  "Translate a message text.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier
     target-language: Target language code (default: user's language setting)

   Returns:
     Translation-result object or NIL on error

   Example:
     (translate-message 123 456 :target-language \"en\")"
  (let ((cache-key (format nil "~A-~A-~A" chat-id message-id target-language)))
    (let ((cached (gethash cache-key *translation-cache*)))
      (when cached
        (return-from translate-message cached))))
  (handler-case
      (let* ((connection (get-connection))
             (msg (get-cached-message chat-id message-id))
             (text (when msg (getf msg :text))))
        (unless text
          (return-from translate-message nil))
        (let* ((lang (or target-language
                         (gethash chat-id *chat-language-preferences*)
                         "en"))
               (request (make-tl-object 'messages.translateText
                                        :peer (make-peer-by-chat-id chat-id)
                                        :id (list message-id)
                                        :to-lang lang)))
          (rpc-handler-case (rpc-call connection request :timeout 10000)
            (t (result)
              (let* ((translations (getf result :translations))
                     (translated (first translations))
                     (result-obj (make-instance 'translation-result
                                                :original-text text
                                                :translated-text (or translated text)
                                                :source-language (getf result :source-lang "auto")
                                                :target-language lang
                                                :was-auto-detected (getf result :auto-detected))))
                (setf (gethash cache-key *translation-cache*) result-obj)
                (push result-obj *translation-history*)
                (when (> (length *translation-history*) 100)
                  (setf *translation-history* (subseq *translation-history* 0 100)))
                result-obj)))))
    (t (e)
      (log:error "Exception in translate-message: ~A" e)
      nil)))

(defun translate-text (text &key from-language to-language)
  "Translate arbitrary text.

   Args:
     text: Text to translate
     from-language: Source language code (NIL for auto-detect)
     to-language: Target language code (default: user's language)

   Returns:
     Translation-result object or NIL on error"
  (let ((cache-key (format nil "~A-~A-~A" text from-language to-language)))
    (let ((cached (gethash cache-key *translation-cache*)))
      (when cached
        (return-from translate-text cached))))
  (handler-case
      (let* ((connection (get-connection))
             (target (or to-language "en"))
             (request (make-tl-object 'messages.translateText
                                      :text text
                                      :from-lang (or from-language "")
                                      :to-lang target)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (result)
            (let* ((translated (getf result :translated-text))
                   (result-obj (make-instance 'translation-result
                                              :original-text text
                                              :translated-text (or translated text)
                                              :source-language (getf result :source-lang "auto")
                                              :target-language target
                                              :was-auto-detected (null from-language))))
              (setf (gethash cache-key *translation-cache*) result-obj)
              result-obj))))
    (t (e)
      (log:error "Exception in translate-text: ~A" e)
      nil)))

(defun set-chat-language (chat-id language-code)
  "Set language preference for a chat.

   Args:
     chat-id: Chat identifier
     language-code: Language code (e.g., \"en\", \"ru\", \"zh\")

   Returns:
     T on success, NIL on error"
  (setf (gethash chat-id *chat-language-preferences*) language-code)
  T)

(defun get-supported-languages ()
  "Get list of supported translation languages.

   Returns:
     List of (code . name) cons cells"
  +supported-translation-languages+)

(defun clear-translation-cache ()
  "Clear the translation cache.

   Returns:
     T"
  (clr-hash *translation-cache*)
  T)

(defun get-translation-history (&optional limit)
  "Get recent translation history.

   Args:
     limit: Maximum number of results (default: 20)

   Returns:
     List of translation-result objects"
  (subseq *translation-history* 0 (min (or limit 20) (length *translation-history*))))

;;; ### Auto-Translation

(defvar *auto-translation-chats* (make-hash-table :test 'equal)
  "Chats with auto-translation enabled")

(defun enable-auto-translation (chat-id &key target-language)
  "Enable automatic message translation for a chat.

   Args:
     chat-id: Chat identifier
     target-language: Target language (default: user's language)

   Returns:
     T on success"
  (setf (gethash chat-id *auto-translation-chats*)
        (or target-language "en"))
  T)

(defun disable-auto-translation (chat-id)
  "Disable auto-translation for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success"
  (remhash chat-id *auto-translation-chats*)
  T)

(defun auto-translation-enabled-p (chat-id)
  "Check if auto-translation is enabled for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T if enabled, NIL otherwise"
  (gethash chat-id *auto-translation-chats*))

;;; ============================================================================
;;; Section 6: Helper Functions
;;; ============================================================================

(defun make-peer-by-chat-id (chat-id)
  "Create input peer object from chat ID.

   Args:
     chat-id: Chat identifier

   Returns:
     TL input peer object"
  (cond
    ((< chat-id 0)
     ;; Group or channel
     (make-tl-object 'inputPeerChannel
                     :channel-id (abs chat-id)
                     :access-hash 0))
    (t
     ;; User
     (make-tl-object 'inputPeerUser
                     :user-id chat-id
                     :access-hash 0))))

(defun privacy-to-tl (privacy-type)
  "Convert privacy keyword to TL object.

   Args:
     privacy-type: Privacy keyword

   Returns:
     TL privacy object"
  (case privacy-type
    (:public
     (make-tl-object 'privacyValueAllUsers))
    (:contacts
     (make-tl-object 'privacyValueContacts))
    (:close-friends
     (make-tl-object 'privacyValueCloseFriends))
    (:custom
     (make-tl-object 'privacyValueSelectedUsers
                     :user-ids nil))
    (otherwise
     (make-tl-object 'privacyValueAllUsers))))

(defun parse-highlight-from-tl (tl-object)
  "Parse highlight from TL object.

   Args:
     tl-object: TL highlight object

   Returns:
     Story-highlight object"
  (make-instance 'story-highlight
                 :id (getf tl-object :id)
                 :title (getf tl-object :title)
                 :cover-media (getf tl-object :cover)
                 :stories (getf tl-object :stories)
                 :date-created (getf tl-object :date-created)
                 :is-hidden (eq (getf tl-object :is-hidden) :bool-true)
                 :privacy-type (getf tl-object :privacy-type)))

;;; ============================================================================
;;; Section 7: Export Functions
;;; ============================================================================

;; Export all Bot API 8.0 functions
;; These are automatically available via cl-telegram/api package
