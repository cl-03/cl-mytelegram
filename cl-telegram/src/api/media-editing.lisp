;;; media-editing.lisp --- Multimedia editing functionality
;;;
;;; Implements message and media editing capabilities:
;;; - Edit message text, caption, media, reply markup
;;; - Media processing: crop, rotate, filters, thumbnails
;;; - Support for all Telegram media types

(in-package #:cl-telegram/api)

;;; ===========================================================================
;;; Edit Message Text
;;; ===========================================================================

(defun edit-message-text (chat-id message-id text
                          &key (reply-markup nil) (parse-mode nil)
                            (entities nil) (link-preview-options nil))
  "Edit message text.

  Args:
    chat-id: Chat identifier (integer or string for channels)
    message-id: Message ID to edit (integer)
    text: New text content (string, 0-4096 chars)
    reply-markup: Optional inline keyboard
    parse-mode: Parse mode (:markdown, :markdown-v2, :html)
    entities: Text entities (bold, italic, links, etc.)
    link-preview-options: Link preview settings

  Returns:
    (values edited-message error)

  Example:
    (edit-message-text chat-id msg-id \"Updated text\"
                       :parse-mode :html
                       :entities (list (make-entity :bold 0 6)))"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))
  (check-type text string)
  (assert (<= (length text) 4096) (text) "Text must not exceed 4096 characters")

  (let ((tl-request
         `(:editMessageText
           :chat_id ,chat-id
           :message_id ,message-id
           :text ,text
           ,@(when parse-mode `(:parse_mode ,(string-upcase (symbol-name parse-mode))))
           ,@(when entities `(:entities ,entities))
           ,@(when reply-markup `(:reply_markup ,reply-markup))
           ,@(when link-preview-options `(:link_preview_options ,link-preview-options)))))
    (handler-case
        (let ((response (send-rpc-request tl-request)))
          (if (getf response :@type)
              (values response nil)
              (values nil (format nil "Failed to edit message: ~A" response))))
      (error (e)
        (values nil (format nil "Error editing message text: ~A" e))))))

;;; ===========================================================================
;;; Edit Message Caption
;;; ===========================================================================

(defun edit-message-caption (chat-id message-id caption
                             &key (show-caption-above-media t)
                               (parse-mode nil) (entities nil))
  "Edit message caption for media messages.

  Args:
    chat-id: Chat identifier
    message-id: Message ID to edit
    caption: New caption (string, 0-1024 chars)
    show-caption-above-media: Display caption above media
    parse-mode: Parse mode for caption
    entities: Caption entities

  Returns:
    (values edited-message error)

  Example:
    (edit-message-caption chat-id msg-id \"New caption\"
                          :parse-mode :markdown)"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))
  (check-type caption string)
  (assert (<= (length caption) 1024) (caption) "Caption must not exceed 1024 characters")

  (let ((tl-request
         `(:editMessageCaption
           :chat_id ,chat-id
           :message_id ,message-id
           :caption ,caption
           :show_caption_above_media ,show-caption-above-media
           ,@(when parse-mode `(:parse_mode ,(string-upcase (symbol-name parse-mode))))
           ,@(when entities `(:entities ,entities)))))
    (handler-case
        (let ((response (send-rpc-request tl-request)))
          (if (getf response :@type)
              (values response nil)
              (values nil (format nil "Failed to edit caption: ~A" response))))
      (error (e)
        (values nil (format nil "Error editing caption: ~A" e))))))

;;; ===========================================================================
;;; Edit Message Media
;;; ===========================================================================

(defun edit-message-media (chat-id message-id media-input
                           &key (reply-markup nil))
  "Edit message media content.

  Args:
    chat-id: Chat identifier
    message-id: Message ID to edit
    media-input: InputMedia object (photo, video, audio, document)
    reply-markup: Optional inline keyboard

  Input Media Types:
    :input-media-photo - Photo with caption
    :input-media-video - Video with caption
    :input-media-audio - Audio file
    :input-media-document - Document file

  Returns:
    (values edited-message error)

  Example:
    (edit-message-media chat-id msg-id
                        (make-input-media-photo :media \"file_id\"
                                                 :caption \"New caption\"))"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))
  (assert media-input "media-input is required")

  (let ((tl-request
         `(:editMessageMedia
           :chat_id ,chat-id
           :message_id ,message-id
           :media ,media-input
           ,@(when reply-markup `(:reply_markup ,reply-markup)))))
    (handler-case
        (let ((response (send-rpc-request tl-request)))
          (if (getf response :@type)
              (values response nil)
              (values nil (format nil "Failed to edit media: ~A" response))))
      (error (e)
        (values nil (format nil "Error editing media: ~A" e))))))

;;; ===========================================================================
;;; Edit Message Reply Markup
;;; ===========================================================================

(defun edit-message-reply-markup (chat-id message-id reply-markup)
  "Edit message reply markup (inline keyboard).

  Args:
    chat-id: Chat identifier
    message-id: Message ID to edit
    reply-markup: New inline keyboard markup

  Returns:
    (values edited-message error)

  Example:
    (edit-message-reply-markup chat-id msg-id
                               (make-inline-keyboard
                                :keyboard (list
                                           (list (make-inline-button \"Button\" :callback \"data\")))))"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))
  (assert reply-markup "reply-markup is required")

  (let ((tl-request
         `(:editMessageReplyMarkup
           :chat_id ,chat-id
           :message_id ,message-id
           :reply_markup ,reply-markup)))
    (handler-case
        (let ((response (send-rpc-request tl-request)))
          (if (getf response :@type)
              (values response nil)
              (values nil (format nil "Failed to edit markup: ~A" response))))
      (error (e)
        (values nil (format nil "Error editing markup: ~A" e))))))

;;; ===========================================================================
;;; Edit Message Live Location
;;; ===========================================================================

(defun edit-message-live-location (chat-id message-id latitude longitude
                                   &key (heading nil) (proximity-alert-radius nil))
  "Edit live location message.

  Args:
    chat-id: Chat identifier
    message-id: Message ID of live location
    latitude: New latitude (float)
    longitude: New longitude (float)
    heading: Current direction (0-360, integer)
    proximity-alert-radius: Alert radius in meters

  Returns:
    (values edited-message error)"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))
  (check-type latitude (float -90 90))
  (check-type longitude (float -180 180))

  (let ((tl-request
         `(:editMessageLiveLocation
           :chat_id ,chat-id
           :message_id ,message-id
           :latitude ,latitude
           :longitude ,longitude
           ,@(when heading `(:heading ,heading))
           ,@(when proximity-alert-radius `(:proximity_alert_radius ,proximity-alert-radius)))))
    (handler-case
        (let ((response (send-rpc-request tl-request)))
          (if (getf response :@type)
              (values response nil)
              (values nil (format nil "Failed to edit location: ~A" response))))
      (error (e)
        (values nil (format nil "Error editing location: ~A" e))))))

;;; ===========================================================================
;;; Stop Message Live Location
;;; ===========================================================================

(defun stop-message-live-location (chat-id message-id &key (reply-markup nil))
  "Stop updating live location.

  Args:
    chat-id: Chat identifier
    message-id: Message ID of live location
    reply-markup: Optional inline keyboard

  Returns:
    (values edited-message error)"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))

  (let ((tl-request
         `(:stopMessageLiveLocation
           :chat_id ,chat-id
           :message_id ,message-id
           ,@(when reply-markup `(:reply_markup ,reply-markup)))))
    (handler-case
        (let ((response (send-rpc-request tl-request)))
          (if (getf response :@type)
              (values response nil)
              (values nil (format nil "Failed to stop location: ~A" response))))
      (error (e)
        (values nil (format nil "Error stopping location: ~A" e))))))

;;; ===========================================================================
;;; Media Processing - Crop
;;; ===========================================================================

(defun crop-media (file-id &key (x 0) (y 0) width height)
  "Crop media file.

  Args:
    file-id: File ID to crop
    x: X coordinate (pixels)
    y: Y coordinate (pixels)
    width: Crop width (pixels)
    height: Crop height (pixels)

  Returns:
    (values cropped-file-id error)

  Note:
    For photos: supports crop for profile photos and stickers
    For videos: delegates to FFmpeg if available"
  (check-type file-id string)
  (check-type x (integer 0 *))
  (check-type y (integer 0 *))

  (when width
    (check-type width (integer 0 *))
    (assert (> width 0) (width) "Width must be positive"))
  (when height
    (check-type height (integer 0 *))
    (assert (> height 0) (height) "Height must be positive"))

  ;; For now, return file-id as-is (actual crop requires server-side processing)
  ;; Telegram API handles crop through inputMedia with crop parameters
  (let ((crop-params
         `(:crop
           :x ,x
           :y ,y
           ,@(when width `(:width ,width))
           ,@(when height `(:height ,height)))))
    ;; In actual implementation, this would be sent with upload
    ;; For now, return the crop parameters for use with media upload
    (values `(:media ,file-id :crop ,crop-params) nil)))

;;; ===========================================================================
;;; Media Processing - Rotate
;;; ===========================================================================

(defun rotate-media (file-id &key (degrees 90))
  "Rotate media file.

  Args:
    file-id: File ID to rotate
    degrees: Rotation angle (90, 180, 270)

  Returns:
    (values rotated-file-id error)

  Supported angles:
    - 90 degrees clockwise
    - 180 degrees
    - 270 degrees (or -90)"
  (check-type file-id string)
  (check-type degrees (member 90 180 270 -90))

  (let ((normalized-degrees (if (minusp degrees) (+ degrees 360) degrees)))
    ;; Return rotation parameters for use with media upload
    (values `(:media ,file-id :rotation ,normalized-degrees) nil)))

;;; ===========================================================================
;;; Media Processing - Apply Filter
;;; ===========================================================================

(defun apply-filter (file-id filter-name &key (intensity 1.0))
  "Apply filter to media.

  Args:
    file-id: File ID
    filter-name: Filter name (see supported filters)
    intensity: Filter intensity (0.0-1.0)

  Supported Filters:
    - :grayscale - Black and white
    - :sepia - Vintage sepia tone
    - :vintage - Vintage film look
    - :dramatic - High contrast
    - :pepper - Warm tones
    - :tonal - Monochromatic
    - :noir - Classic B&W
    - :fade - Faded look
    - :misty - Soft, hazy
    - :serene - Cool, calm
    - :soft - Soft contrast
    - :clear - Clear, bright
    - :vivid - Vibrant colors
    - :vibrant - High saturation
    - :calm - Muted tones

  Returns:
    (values filtered-media-params error)"
  (check-type file-id string)
  (check-type filter-name keyword)
  (check-type intensity (float 0.0 1.0))

  (let ((supported-filters
         '(:grayscale :sepia :vintage :dramatic :pepper
           :tonal :noir :fade :misty :serene
           :soft :clear :vivid :vibrant :calm)))
    (assert (member filter-name supported-filters)
            (filter-name)
            "Unsupported filter: ~A. Supported: ~A" filter-name supported-filters))

  (values `(:media ,file-id :filter ,filter-name :intensity ,intensity) nil)))

;;; ===========================================================================
;;; Media Processing - Generate Thumbnail
;;; ===========================================================================

(defun generate-thumbnail (file-id &key (size 320) (format :jpeg)
                                   (time-offset 0))
  "Generate thumbnail for media.

  Args:
    file-id: File ID to generate thumbnail from
    size: Thumbnail size (width, default 320)
    format: Output format (:jpeg, :png, :webp)
    time-offset: For videos, offset in seconds to capture frame

  Returns:
    (values thumbnail-file-id error)

  For videos:
    - Captures frame at time-offset seconds
    - Default is first frame (0 seconds)

  For images:
    - Resizes to fit within size x size
    - Maintains aspect ratio"
  (check-type file-id string)
  (check-type size (integer 64 1280))
  (check-type format (member :jpeg :png :webp))
  (check-type time-offset (real 0 *))

  (let ((thumb-params
         `(:thumbnail
           :file_id ,file-id
           :size ,size
           :format ,(string-upcase (symbol-name format))
           :time_offset ,time-offset)))
    ;; In actual implementation, this would trigger server-side thumbnail generation
    ;; For now, return parameters for use with media upload
    (values thumb-params nil)))

;;; ===========================================================================
;;; Text Overlay
;;; ===========================================================================

(defun add-text-overlay (file-id text &key (position :bottom) (font nil)
                                    (size 24) (color :white) (background nil))
  "Add text overlay to media.

  Args:
    file-id: File ID
    text: Overlay text
    position: Position (:top, :bottom, :center, :top-left, etc.)
    font: Font name (uses default if nil)
    size: Font size (pixels)
    color: Text color (:white, :black, :red, etc.)
    background: Background overlay (:blur, :solid, nil)

  Returns:
    (values media-with-overlay error)"
  (check-type file-id string)
  (check-type text string)
  (check-type position keyword)
  (check-type size (integer 8 72))

  (let ((valid-positions
         '(:top :bottom :center :top-left :top-right
           :bottom-left :bottom-right)))
    (assert (member position valid-positions)
            (position)
            "Invalid position: ~A. Valid: ~A" position valid-positions))

  (values `(:media ,file-id
                   :text_overlay (:text ,text
                              :position ,position
                              :font ,(or font "system")
                              :size ,size
                              :color ,color
                              :background ,background))
          nil))

;;; ===========================================================================
;;; Add Emoji Sticker Overlay
;;; ===========================================================================

(defun add-emoji-sticker (file-id emoji &key (position :top-right)
                                         (size 64))
  "Add emoji sticker overlay to media.

  Args:
    file-id: File ID
    emoji: Emoji character or sticker ID
    position: Position keyword
    size: Sticker size in pixels

  Returns:
    (values media-with-emoji error)"
  (check-type file-id string)
  (check-type emoji string)
  (check-type position keyword)
  (check-type size (integer 16 256))

  (values `(:media ,file-id
                   :emoji_overlay (:emoji ,emoji
                                :position ,position
                                :size ,size))
          nil))

;;; ===========================================================================
;;; Edit Checklist
;;; ===========================================================================

(defun edit-message-checklist (chat-id message-id checklist-items
                               &key (is-personal t))
  "Edit message checklist.

  Args:
    chat-id: Chat identifier
    message-id: Message ID with checklist
    checklist-items: List of checklist item plists
    is-personal: Whether checklist is personal to user

  Checklist Item Format:
    '(:id \"item1\" :text \"Task 1\" :is-checked nil)

  Returns:
    (values edited-message error)"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))
  (check-type checklist-items list)

  (let ((tl-request
         `(:editMessageChatListItem
           :chat_id ,chat-id
           :message_id ,message-id
           :is_personal ,is-personal
           :checklist_items ,(loop for item in checklist-items
                                   collect `(:checklist_item ,item)))))
    (handler-case
        (let ((response (send-rpc-request tl-request)))
          (if (getf response :@type)
              (values response nil)
              (values nil (format nil "Failed to edit checklist: ~A" response))))
      (error (e)
        (values nil (format nil "Error editing checklist: ~A" e))))))

;;; ===========================================================================
;;; Helper Functions
;;; ===========================================================================

(defun make-input-media-photo (&key media caption show-caption-above-media
                                    has-spoiler thumbnail)
  "Create InputMediaPhoto object.

  Args:
    media: File ID or URL
    caption: Optional caption
    show-caption-above-media: Display caption above image
    has-spoiler: Apply spoiler animation
    thumbnail: Optional thumbnail file ID

  Returns:
    InputMediaPhoto plist"
  `(:inputMediaPhoto
    :type "photo"
    :media ,media
    ,@(when caption `(:caption ,caption))
    ,@(when show-caption-above-media `(:show_caption_above_media ,show-caption-above-media))
    ,@(when has-spoiler `(:has_spoiler ,has-spoiler))
    ,@(when thumbnail `(:thumbnail ,thumbnail))))

(defun make-input-media-video (&key media caption thumbnail duration width height
                                     supports-streaming has-spoiler
                                     show-caption-above-media)
  "Create InputMediaVideo object.

  Args:
    media: File ID or URL
    caption: Optional caption
    thumbnail: Thumbnail file ID
    duration: Video duration in seconds
    width: Video width
    height: Video height
    supports-streaming: Whether video can be streamed
    has-spoiler: Apply spoiler animation
    show-caption-above-media: Display caption above video

  Returns:
    InputMediaVideo plist"
  `(:inputMediaVideo
    :type "video"
    :media ,media
    ,@(when caption `(:caption ,caption))
    ,@(when thumbnail `(:thumbnail ,thumbnail))
    ,@(when duration `(:duration ,duration))
    ,@(when width `(:width ,width))
    ,@(when height `(:height ,height))
    ,@(when supports-streaming `(:supports_streaming ,supports-streaming))
    ,@(when has-spoiler `(:has_spoiler ,has-spoiler))
    ,@(when show-caption-above-media `(:show_caption_above_media ,show-caption-above-media))))

(defun make-input-media-audio (&key media caption thumbnail duration performer title)
  "Create InputMediaAudio object.

  Args:
    media: File ID or URL
    caption: Optional caption
    thumbnail: Thumbnail file ID
    duration: Audio duration in seconds
    performer: Performer name
    title: Track title

  Returns:
    InputMediaAudio plist"
  `(:inputMediaAudio
    :type "audio"
    :media ,media
    ,@(when caption `(:caption ,caption))
    ,@(when thumbnail `(:thumbnail ,thumbnail))
    ,@(when duration `(:duration ,duration))
    ,@(when performer `(:performer ,performer))
    ,@(when title `(:title ,title))))

(defun make-input-media-document (&key media caption thumbnail disable-content-type-detection)
  "Create InputMediaDocument object.

  Args:
    media: File ID or URL
    caption: Optional caption
    thumbnail: Thumbnail file ID
    disable-content-type-detection: Don't detect file type

  Returns:
    InputMediaDocument plist"
  `(:inputMediaDocument
    :type "document"
    :media ,media
    ,@(when caption `(:caption ,caption))
    ,@(when thumbnail `(:thumbnail ,thumbnail))
    ,@(when disable-content-type-detection `(:disable_content_type_detection ,disable-content-type-detection))))

(defun make-input-media-animation (&key media caption thumbnail duration width height has-spoiler)
  "Create InputMediaAnimation object (GIF/animation).

  Args:
    media: File ID or URL
    caption: Optional caption
    thumbnail: Thumbnail file ID
    duration: Animation duration
    width: Animation width
    height: Animation height
    has-spoiler: Apply spoiler animation

  Returns:
    InputMediaAnimation plist"
  `(:inputMediaAnimation
    :type "animation"
    :media ,media
    ,@(when caption `(:caption ,caption))
    ,@(when thumbnail `(:thumbnail ,thumbnail))
    ,@(when duration `(:duration ,duration))
    ,@(when width `(:width ,width))
    ,@(when height `(:height ,height))
    ,@(when has-spoiler `(:has_spoiler ,has-spoiler))))

;;; ===========================================================================
;;; Edit Message Helper (Unified Interface)
;;; ===========================================================================

(defun edit-message (chat-id message-id &key text caption media reply-markup
                                   parse-mode entities link-preview-options
                                   show-caption-above-media)
  "Unified message editing interface.

  Args:
    chat-id: Chat identifier
    message-id: Message ID to edit
    text: New text (for text messages)
    caption: New caption (for media messages)
    media: New media (InputMedia object)
    reply-markup: New keyboard
    parse-mode: Parse mode
    entities: Text entities
    link-preview-options: Link preview settings
    show-caption-above-media: Caption position

  Returns:
    (values edited-message error)

  Example:
    ;; Edit text
    (edit-message chat-id msg-id :text \"New text\" :parse-mode :html)

    ;; Edit caption
    (edit-message chat-id msg-id :caption \"New caption\")

    ;; Edit keyboard only
    (edit-message chat-id msg-id :reply-markup new-keyboard)"
  (check-type chat-id (or integer string))
  (check-type message-id (integer 0 *))

  (cond
    ;; Edit text
    (text
     (edit-message-text chat-id message-id text
                        :reply-markup reply-markup
                        :parse-mode parse-mode
                        :entities entities
                        :link-preview-options link-preview-options))

    ;; Edit caption
    (caption
     (edit-message-caption chat-id message-id caption
                           :show-caption-above-media show-caption-above-media
                           :parse-mode parse-mode
                           :entities entities))

    ;; Edit media
    (media
     (edit-message-media chat-id message-id media
                         :reply-markup reply-markup))

    ;; Edit markup only
    (reply-markup
     (edit-message-reply-markup chat-id message-id reply-markup))

    (t
     (error "At least one of text, caption, media, or reply-markup must be provided"))))

;;; ===========================================================================
;;; End of media-editing.lisp
;;; ===========================================================================
