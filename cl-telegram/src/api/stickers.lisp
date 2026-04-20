;;; stickers.lisp --- Sticker and emoji pack management
;;;
;;; Provides support for:
;;; - Sticker set management (create, add, remove)
;;; - Emoji pack management
;;; - Sticker search and browsing
;;; - Custom emoji support

(in-package #:cl-telegram/api)

;;; ### Sticker Types

(defclass sticker ()
  ((file-id :initarg :file-id :reader sticker-file-id)
   (file-unique-id :initarg :file-unique-id :reader sticker-file-unique-id)
   (width :initarg :width :reader sticker-width)
   (height :initarg :height :reader sticker-height)
   (is-animated :initarg :is-animated :reader sticker-is-animated)
   (is-video :initarg :is-video :reader sticker-is-video)
   (thumbnail :initarg :thumbnail :reader sticker-thumbnail)
   (emoji :initarg :emoji :reader sticker-emoji)
   (set-name :initarg :set-name :reader sticker-set-name)))

(defclass sticker-set ()
  ((name :initarg :name :reader sticker-set-name)
   (title :initarg :title :reader sticker-set-title)
   (is-animated :initarg :is-animated :reader sticker-set-is-animated)
   (is-video :initarg :is-video :reader sticker-set-is-video)
   (stickers :initarg :stickers :reader sticker-set-stickers)
   (thumbnail :initarg :thumbnail :reader sticker-set-thumbnail)
   (emoji-representation :initarg :emoji-representation :reader sticker-set-emoji-representation)))

(defclass emoji-pack ()
  ((id :initarg :id :reader emoji-pack-id)
   (title :initarg :title :reader emoji-pack-title)
   (emoji-list :initarg :emoji-list :reader emoji-pack-emoji-list)
   (is-installed :initform nil :accessor emoji-pack-is-installed)))

;;; ### Global State

(defvar *sticker-cache* (make-hash-table :test 'equal)
  "Cache for sticker sets")

(defvar *emoji-packs* nil
  "List of available emoji packs")

(defvar *favorite-stickers* nil
  "List of favorite sticker file-ids")

;;; ### Sticker Set Management

(defun get-sticker-set (set-name)
  "Get a sticker set by name.

   Args:
     set-name: Name of the sticker set

   Returns:
     Sticker-set object or NIL"
  ;; Check cache first
  (let ((cached (gethash set-name *sticker-cache*)))
    (when cached
      (return-from get-sticker-set cached))))

(defun search-sticker-sets (query &key (limit 20))
  "Search for sticker sets.

   Args:
     query: Search query string
     limit: Maximum results to return

   Returns:
     List of sticker-set objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.searchStickerSets
                                      :q query
                                      :limit limit)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Search sticker sets failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Search sticker sets timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((sets (getf result :sets)))
              (mapcar (lambda (set-data)
                        (make-instance 'sticker-set
                                       :name (getf set-data :name)
                                       :title (getf set-data :title)
                                       :is-animated (getf set-data :is-animated)
                                       :is-video (getf set-data :is-video)
                                       :stickers (getf set-data :stickers)))
                      sets)))))
    (t (e)
      (log-error "Unexpected error in search-sticker-sets: ~a" e)
      nil)))

(defun get-all-sticker-sets ()
  "Get all installed sticker sets.

   Returns:
     List of sticker-set objects"
  (loop for set being the hash-values of *sticker-cache*
        collect set))

(defun install-sticker-set (set-name)
  "Install a sticker set.

   Args:
     set-name: Name of the sticker set

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.installStickerSet
                                      :stickerset (make-tl-object 'inputStickerSetShortName
                                                                  :short-name set-name))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Install sticker set failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Install sticker set timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            ;; Invalidate cache and refetch
            (remhash set-name *sticker-cache*)
            t)))
    (t (e)
      (log-error "Unexpected error in install-sticker-set: ~a" e)
      nil)))

(defun uninstall-sticker-set (set-name)
  "Uninstall a sticker set.

   Args:
     set-name: Name of the sticker set

   Returns:
     T on success, NIL on failure"
  (remhash set-name *sticker-cache*)
  t)

(defun add-sticker-to-set (set-name sticker file-id emoji)
  "Add a sticker to a set.

   Args:
     set-name: Name of the sticker set
     sticker: Sticker object
     file-id: File ID of the sticker
     emoji: Emoji associated with sticker

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.addStickerToSet
                                      :stickerset (make-tl-object 'inputStickerSetShortName
                                                                  :short-name set-name)
                                      :sticker (make-tl-object 'inputStickerSetItem
                                                               :file-id file-id
                                                               :emoji emoji))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Add sticker to set failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Add sticker to set timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            ;; Invalidate cache
            (remhash set-name *sticker-cache*)
            t)))
    (t (e)
      (log-error "Unexpected error in add-sticker-to-set: ~a" e)
      nil)))

(defun remove-sticker-from-set (set-name sticker-file-id)
  "Remove a sticker from a set.

   Args:
     set-name: Name of the sticker set
     sticker-file-id: File ID of sticker to remove

   Returns:
     T on success, NIL on failure"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.removeStickerFromSet
                                      :stickerset (make-tl-object 'inputStickerSetShortName
                                                                  :short-name set-name)
                                      :sticker sticker-file-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Remove sticker from set failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Remove sticker from set timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            ;; Invalidate cache
            (remhash set-name *sticker-cache*)
            t)))
    (t (e)
      (log-error "Unexpected error in remove-sticker-from-set: ~a" e)
      nil)))

;;; ### Sticker Upload

(defun upload-sticker (file-path &key (user-id nil))
  "Upload a new sticker file.

   Args:
     file-path: Path to sticker file (PNG, WEBP, or TGS for animated)
     user-id: User ID who owns the sticker

   Returns:
     File-id on success, NIL on failure

   Requirements:
     - Static stickers: PNG or WEBP, 512x512, < 64KB
     - Animated stickers: TGS (Lottie), 512x512, < 64KB
     - Video stickers: WEBM, 512x512, < 64KB, < 3s"
  (handler-case
      (let* ((connection (get-connection))
             (file-data (alexandria:read-file-into-byte-vector file-path))
             (file-type (cond
                          ((search ".tgs" file-path :test #'char-equal) :animated)
                          ((search ".webm" file-path :test #'char-equal) :video)
                          (t :static))))
        ;; Validate file size
        (when (> (length file-data) (* 64 1024))
          (error "Sticker file too large. Maximum 64KB, got ~aKB"
                 (truncate (length file-data) 1024)))
        ;; Upload file
        (let ((request (make-tl-object 'messages.uploadMedia
                                       :peer (make-tl-object 'inputPeerUser
                                                             :user-id (or user-id (get-my-user-id))
                                                             :access-hash 0)
                                       :media (make-tl-object 'inputMediaUploadedDocument
                                                              :file file-data
                                                              :mime-type (case file-type
                                                                           (:animated "application/x-tgs")
                                                                           (:video "video/webm")
                                                                           (t "image/webp"))
                                                              :attributes nil))))
          (rpc-handler-case (rpc-call connection request :timeout 30000)
            (upload-error (e)
              (log-error "Upload sticker failed: ~a" e)
              nil)
            (timeout-error (e)
              (log-error "Upload sticker timeout: ~a" e)
              nil)
            (:no-error (result)
              (getf result :file-id)))))
    (t (e)
      (log-error "Unexpected error in upload-sticker: ~a" e)
      nil)))

(defun create-new-sticker-set (user-id name title &key (is-animated nil) (is-video nil))
  "Create a new sticker set.

   Args:
     user-id: User ID who owns the set
     name: Set name (must be unique, 1-64 chars, a-z, 0-9, underscore)
     title: Set title (1-64 chars)
     is-animated: Whether this is an animated sticker set
     is-video: Whether this is a video sticker set

   Returns:
     T on success, error on failure

   Note: User must be verified to create sticker sets"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.createNewStickerSet
                                      :user-id user-id
                                      :name name
                                      :title title
                                      :flags (cond
                                               (is-video 2)
                                               (is-animated 1)
                                               (t 0)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Create sticker set failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Create sticker set timeout: ~a" e)
            nil)
          (:no-error (result)
            (declare (ignore result))
            t)))
    (t (e)
      (log-error "Unexpected error in create-new-sticker-set: ~a" e)
      nil)))

;;; ### Favorite Stickers

(defun get-favorite-stickers ()
  "Get list of favorite stickers.

   Returns:
     List of sticker file-ids"
  *favorite-stickers*)

(defun add-favorite-sticker (file-id)
  "Add a sticker to favorites.

   Args:
     file-id: Sticker file ID

   Returns:
     T on success"
  (pushnew file-id *favorite-stickers* :test #'string=)
  t)

(defun remove-favorite-sticker (file-id)
  "Remove a sticker from favorites.

   Args:
     file-id: Sticker file ID

   Returns:
     T on success"
  (setf *favorite-stickers*
        (remove file-id *favorite-stickers* :test #'string=))
  t)

;;; ### Emoji Management

(defun get-emoji-packs ()
  "Get all available emoji packs.

   Returns:
     List of emoji-pack objects"
  (or *emoji-packs*
      ;; Default emoji packs
      (setf *emoji-packs*
            (list (make-instance 'emoji-pack
                                 :id "default"
                                 :title "Default"
                                 :emoji-list '("😀" "😁" "😂" "🤣" "😃" "😄" "😅" "😆"
                                               "😉" "😊" "😋" "😎" "😍" "😘" "🥰" "😗"
                                               "😇" "🤗" "🤩" "🤔" "🤨" "😐" "😑" "😶"
                                               "🙄" "😏" "😣" "😥" "😮" "🤐" "😯" "😪"
                                               "😫" "😴" "😌" "😛" "😜" "😝" "🤤" "😒"
                                               "😓" "😔" "😕" "🙃" "🤑" "😲" "☹️" "🙁"
                                               "😖" "😞" "😟" "😤" "😢" "😭" "😦" "😧"
                                               "😨" "😩" "🤯" "😬" "😰" "😱" "🥵" "🥶"
                                               "😳" "🤪" "😵" "😡" "😠" "🤬" "😷" "🤒"
                                               "🤕" "🤢" "🤮" "🤧" "😇" "🤠" "🥳" "🥴"
                                               "🥺" "🤥" "🤫" "🤭" "🧐" "🤓" "😈" "👿"
                                               "👹" "👺" "💀" "👻" "👽" "🤖" "💩" "😺"
                                               "😸" "😹" "😻" "😼" "😽" "🙀" "😿" "😾"))
                  (make-instance 'emoji-pack
                                 :id "hearts"
                                 :title "Hearts"
                                 :emoji-list '("❤️" "🧡" "💛" "💚" "💙" "💜" "🖤" "💔"
                                               "❣️" "💕" "💞" "💓" "💗" "💖" "💘" "💝"
                                               "💟" "☮️" "✝️" "☪️" "🕉️" "☸️" "✡️" "🔯"
                                               "🕎" "☯️" "☦️" "🛐" "⛎" "♈" "♉" "♊"
                                               "♋" "♌" "♍" "♎" "♏" "♐" "♑" "♒" "♓"
                                               "🆔" "⚛️"))
                  (make-instance 'emoji-pack
                                 :id "animals"
                                 :title "Animals"
                                 :emoji-list '("🐶" "🐱" "🐭" "🐹" "🐰" "🦊" "🐻" "🐼"
                                               "🐨" "🐯" "🦁" "🐮" "🐷" "🐸" "🐵" "🐔"
                                               "🐧" "🐦" "🐤" "🐣" "🐥" "🦆" "🦅" "🦉"
                                               "🦇" "🐺" "🐗" "🐴" "🦄" "🐝" "🐛" "🦋"
                                               "🐌" "🐞" "🐜" "🦟" "🦗" "🕷" "🕸" "🐢"
                                               "🐍" "🦎" "🦖" "🦕" "🐙" "🦑" "🦐" "🦞"
                                               "🦀" "🐡" "🐠" "🐟" "🐬" "🐳" "🐋" "🦈"
                                               "🐊" "🐅" "🐆" "🦓" "🦍" "🦧" "🐘" "🦛"
                                               "🦏" "🐪" "🐫" "🦒" "🦘" "🐃" "🐄" "🐂"
                                               "🐎" "🐖" "🐏" "🐑" "🦙" "🐐" "🦌" "🐕"
                                               "🐩" "🦮" "🐈" "🐓" "🦃" "🦚" "🦜" "🦢"
                                               "🦩" "🕊" "🐇" "🦝" "🦨" "🦡" "🦦" "🦥"
                                               "🐁" "🐀" "🐿" "🦔"))))))

(defun install-emoji-pack (pack-id)
  "Install an emoji pack.

   Args:
     pack-id: Emoji pack ID

   Returns:
     T on success"
  (let ((pack (find pack-id *emoji-packs* :key #'emoji-pack-id :test #'string=)))
    (when pack
      (setf (emoji-pack-is-installed pack) t)
      t)))

(defun uninstall-emoji-pack (pack-id)
  "Uninstall an emoji pack.

   Args:
     pack-id: Emoji pack ID

   Returns:
     T on success"
  (let ((pack (find pack-id *emoji-packs* :key #'emoji-pack-id :test #'string=)))
    (when pack
      (setf (emoji-pack-is-installed pack) nil)
      t)))

(defun get-installed-emoji-packs ()
  "Get all installed emoji packs.

   Returns:
     List of installed emoji-pack objects"
  (remove-if-not #'emoji-pack-is-installed (get-emoji-packs)))

;;; ### Sticker in Messages

(defun send-sticker (chat-id file-id &key (reply-to nil))
  "Send a sticker in a chat.

   Args:
     chat-id: Chat ID to send to
     file-id: Sticker file ID
     reply-to: Message ID to reply to

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.sendMedia
                                      :peer (make-tl-object 'inputPeerUser :user-id chat-id :access-hash 0)
                                      :media (make-tl-object 'inputMediaDocument
                                                             :id (list file-id))
                                      :reply-to (when reply-to
                                                  (make-tl-object 'inputMessageReplyTo
                                                                  :reply-to-msg-id reply-to))
                                      :message ""
                                      :random-id (random (expt 2 63)))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Send sticker failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Send sticker timeout: ~a" e)
            nil)
          (:no-error (result)
            (parse-message-from-tl result))))
    (t (e)
      (log-error "Unexpected error in send-sticker: ~a" e)
      nil)))

(defun get-sticker-from-message (message)
  "Extract sticker from a message.

   Args:
     message: Message object

   Returns:
     Sticker object or NIL"
  (let ((sticker-data (getf message :sticker)))
    (when sticker-data
      (make-instance 'sticker
                     :file-id (getf sticker-data :file-id)
                     :file-unique-id (getf sticker-data :file-unique-id)
                     :width (getf sticker-data :width)
                     :height (getf sticker-data :height)
                     :is-animated (getf sticker-data :is-animated)
                     :is-video (getf sticker-data :is-video)
                     :emoji (getf sticker-data :emoji)
                     :set-name (getf sticker-data :set-name)))))

;;; ### Custom Emoji

(defun get-custom-emoji (emoji-id)
  "Get custom emoji by ID.

   Args:
     emoji-id: Custom emoji ID

   Returns:
     File ID of the custom emoji sticker"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'messages.getCustomEmojiDocuments
                                      :document-id (list emoji-id))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (emoji-error (e)
            (log-error "Get custom emoji failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Get custom emoji timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((docs (getf result :documents)))
              (when (and docs (> (length docs) 0))
                (getf (first docs) :file-id)))))
    (t (e)
      (log-error "Unexpected error in get-custom-emoji: ~a" e)
      nil)))

(defun send-custom-emoji (chat-id emoji-id &key (reply-to nil))
  "Send a custom emoji in a chat.

   Args:
     chat-id: Chat ID to send to
     emoji-id: Custom emoji ID
     reply-to: Message ID to reply to

   Returns:
     Message object on success"
  (let ((file-id (get-custom-emoji emoji-id)))
    (when file-id
      (send-sticker chat-id file-id :reply-to reply-to))))

;;; ### Sticker Search

(defun search-stickers (query &key (limit 20))
  "Search for stickers by emoji or keyword.

   Args:
     query: Search query
     limit: Maximum results

   Returns:
     List of sticker objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.searchStickers
                                      :q query
                                      :limit limit)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Search stickers failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Search stickers timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((stickers (getf result :stickers)))
              (mapcar (lambda (sticker-data)
                        (make-instance 'sticker
                                       :file-id (getf sticker-data :file-id)
                                       :file-unique-id (getf sticker-data :file-unique-id)
                                       :width (getf sticker-data :width)
                                       :height (getf sticker-data :height)
                                       :is-animated (getf sticker-data :is-animated)
                                       :is-video (getf sticker-data :is-video)
                                       :emoji (getf sticker-data :emoji)
                                       :set-name (getf sticker-data :set-name)))
                      stickers)))))
    (t (e)
      (log-error "Unexpected error in search-stickers: ~a" e)
      nil)))

(defun get-trending-stickers (&key (limit 10))
  "Get trending stickers.

   Args:
     limit: Maximum results

   Returns:
     List of sticker objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stickers.getSuggestedStickers
                                      :limit limit)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (sticker-error (e)
            (log-error "Get trending stickers failed: ~a" e)
            nil)
          (timeout-error (e)
            (log-error "Get trending stickers timeout: ~a" e)
            nil)
          (:no-error (result)
            (let ((stickers (getf result :stickers)))
              (mapcar (lambda (sticker-data)
                        (make-instance 'sticker
                                       :file-id (getf sticker-data :file-id)
                                       :file-unique-id (getf sticker-data :file-unique-id)
                                       :width (getf sticker-data :width)
                                       :height (getf sticker-data :height)
                                       :is-animated (getf sticker-data :is-animated)
                                       :is-video (getf sticker-data :is-video)
                                       :emoji (getf sticker-data :emoji)
                                       :set-name (getf sticker-data :set-name)))
                      stickers)))))
    (t (e)
      (log-error "Unexpected error in get-trending-stickers: ~a" e)
      nil)))

;;; ### CLOG UI Integration

(defun render-sticker-picker (win container &key (on-select nil))
  "Render sticker picker UI.

   Args:
     win: CLOG window object
     container: Container element
     on-select: Callback function when sticker selected"
  (declare (ignorable win on-select))
  ;; Get all sticker sets
  (let ((sets (get-all-sticker-sets)))
    (if (null sets)
        (clog:append! container
                      (clog:create-element win "div" :class "empty-state"
                        (clog:create-element win "p" :text "No sticker sets installed")))
        ;; Render sticker sets
        (dolist (set sets)
          (let ((set-container (clog:create-element win "div" :class "sticker-set")))
            (clog:append! set-container
                          (clog:create-element win "div" :class "sticker-set-title"
                                               :text (sticker-set-title set))
                          (clog:create-element win "div" :class "sticker-grid"
                                               :style "display: grid; grid-template-columns: repeat(5, 1fr); gap: 5px;"))
            ;; Render stickers
            (dolist (sticker (sticker-set-stickers set))
              (let ((sticker-el (clog:create-element win "div"
                                                     :class "sticker-item"
                                                     :style "cursor: pointer; padding: 5px;")))
                ;; Render sticker thumbnail
                (let ((img-el (clog:create-element win "img"
                                                   :style "width: 64px; height: 64px; object-fit: contain;"
                                                   :alt (or (sticker-emoji sticker) "sticker"))))
                  ;; Set image source if file-id available
                  (when (sticker-file-id sticker)
                    (setf (clog:attr img-el "src")
                          (format nil "/sticker/~A" (sticker-file-id sticker))))
                  (clog:append! sticker-el img-el))
                (when on-select
                  (clog:on sticker-el :click
                           (lambda (ev)
                             (declare (ignore ev))
                             (funcall on-select sticker))))
                (clog:append! (clog:query-selector set-container ".sticker-grid") sticker-el)))
            (clog:append! container set-container))))))

(defun render-emoji-picker (win container &key (on-select nil))
  "Render emoji picker UI.

   Args:
     win: CLOG window object
     container: Container element
     on-select: Callback function when emoji selected"
  (let ((packs (get-installed-emoji-packs)))
    ;; Pack tabs
    (let ((tabs (clog:create-element win "div" :class "emoji-tabs"
                                     :style "display: flex; gap: 10px; margin-bottom: 10px;")))
      (dolist (pack packs)
        (let ((tab (clog:create-element win "button"
                                        :class "emoji-tab"
                                        :style "padding: 5px 10px; cursor: pointer;"
                                        :text (emoji-pack-title pack))))
          (clog:on tab :click
                   (lambda (ev)
                     (declare (ignore ev))
                     ;; Show selected pack
                     (let ((grid (clog:get-element-by-id win (format nil "emoji-grid-~A" (emoji-pack-id pack)))))
                       (when grid
                         (setf (clog:style grid "display") "grid"))
                       (dolist (other-pack packs)
                         (when (not (string= (emoji-pack-id other-pack) (emoji-pack-id pack)))
                           (let ((other-grid (clog:get-element-by-id win (format nil "emoji-grid-~A" (emoji-pack-id other-pack)))))
                             (when other-grid
                               (setf (clog:style other-grid "display") "none")))))))
          (clog:append! tabs tab)))
      (clog:append! container tabs))

    ;; Emoji grids
    (dolist (pack packs)
      (let ((grid (clog:create-element win "div"
                                       :id (format nil "emoji-grid-~A" (emoji-pack-id pack))
                                       :class "emoji-grid"
                                       :style (if (eq pack (car packs)) "display: grid;" "display: none;")
                                       :onclick (format nil "grid-template-columns: repeat(~A, 1fr); gap: 5px;"
                                                        (if (<= (length (emoji-pack-emoji-list pack)) 30) 10 8))))
        (dolist (emoji (emoji-pack-emoji-list pack))
          (let ((emoji-el (clog:create-element win "span"
                                               :class "emoji-item"
                                               :style "font-size: 24px; cursor: pointer; padding: 5px; text-align: center;")))
            (setf (clog:text emoji-el) emoji)
            (when on-select
              (clog:on emoji-el :click
                       (lambda (ev)
                         (declare (ignore ev))
                         (funcall on-select emoji))))
            (clog:append! grid emoji-el)))
        (clog:append! container grid)))))

;;; ### Utilities

(defun sticker-dimension-string (sticker)
  "Get sticker dimension as string.

   Args:
     sticker: Sticker object

   Returns:
     Dimension string like '512x512'"
  (format nil "~Ax~A" (sticker-width sticker) (sticker-height sticker)))

(defun sticker-type-string (sticker)
  "Get sticker type as string.

   Args:
     sticker: Sticker object

   Returns:
     Type string (static/animated/video)"
  (cond
    ((sticker-is-animated sticker) "animated")
    ((sticker-is-video sticker) "video")
    (t "static")))

(defun clear-sticker-cache ()
  "Clear all sticker cache.

   Returns:
     T on success"
  (clrhash *sticker-cache*)
  t)
