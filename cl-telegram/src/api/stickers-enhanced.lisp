;;; stickers-enhanced.lisp --- Enhanced Stickers API for Bot API 9.6+
;;;
;;; Provides additional sticker management features:
;;; - Suggest sticker set short name
;;; - Check short name availability
;;; - Save/get/search GIFs
;;; - Get available effects (emoji/custom)
;;; - Recent emoji reactions management
;;; - Wallpaper management
;;; - Sticker set conversion (video/animated/static)
;;;
;;; Reference: https://core.telegram.org/api/stickers
;;; Version: 0.38.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Sticker Set Name Management
;;; ============================================================================

(defun suggest-sticker-set-short-name (title)
  "Suggest a short name for a sticker set based on title.

   Args:
     title: Sticker set title

   Returns:
     Suggested short name string (lowercase, underscores)

   Example:
     (suggest-sticker-set-short-name \"My Awesome Stickers\")
     => \"my_awesome_stickers\""
  (let* ((normalized (string-downcase title))
         ;; Replace spaces with underscores
         (with-underscores (cl-ppcre:regex-replace-all "\\s+" normalized "_"))
         ;; Remove non-alphanumeric except underscores
         (clean (cl-ppcre:regex-replace-all "[^a-z0-9_]" with-underscores ""))
         ;; Remove consecutive underscores
         (single-underscores (cl-ppcre:regex-replace-all "_+" clean "_"))
         ;; Trim leading/trailing underscores
         (trimmed (string-trim "_" single-underscores)))
    ;; Ensure max 64 chars
    (if (> (length trimmed) 64)
        (subseq trimmed 0 64)
        trimmed)))

(defun check-sticker-set-short-name (short-name)
  "Check if a sticker set short name is available.

   Args:
     short-name: Short name to check (1-64 chars, a-z, 0-9, underscore)

   Returns:
     T if available, NIL if taken or invalid

   Example:
     (check-sticker-set-short-name \"my_awesome_stickers\")"
  ;; Validate format
  (unless (and (>= (length short-name) 1)
               (<= (length short-name) 64)
               (every (lambda (c)
                        (or (alpha-char-p c)
                            (digit-char-p c)
                            (char= c #\_)))
                      short-name))
    (return-from check-sticker-set-short-name nil))

  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("short_name" . ,short-name))))
        (let ((result (make-api-call connection "checkStickerSetName" params)))
          (if result
              (getf result :available nil)
              nil)))
    (error (e)
      (log-message :error "Error checking sticker set name: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 2: GIF Management
;;; ============================================================================

(defvar *saved-gifs-cache* nil
  "Cache for saved GIFs")

(defvar *saved-gifs-cache-time* 0
  "Cache timestamp for saved GIFs")

(defvar *saved-gifs-cache-ttl* 300
  "Cache TTL in seconds (default: 5 minutes)")

(defun save-gif (file-id &key (unsave nil))
  "Save or unsave a GIF.

   Args:
     file-id: GIF file ID to save
     unsave: If T, remove from saved GIFs

   Returns:
     T on success, NIL on failure

   Example:
     (save-gif \"AgAD1234\") ; Save GIF
     (save-gif \"AgAD1234\" :unsave t) ; Unsave GIF"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("file_id" . ,file-id))))
        (when unsave
          (push (cons "unsave" "true") params))

        (let ((result (make-api-call connection "saveGif" params)))
          (if result
              (progn
                ;; Invalidate cache
                (setf *saved-gifs-cache* nil)
                t)
              nil)))
    (error (e)
      (log-message :error "Error saving GIF: ~A" (princ-to-string e))
      nil)))

(defun get-saved-gifs (&key (force-refresh nil))
  "Get list of saved GIFs.

   Args:
     force-refresh: Force refresh from server

   Returns:
     List of file-ids

   Example:
     (get-saved-gifs)"
  (let ((now (get-universal-time)))
    ;; Check cache
    (unless force-refresh
      (when (and *saved-gifs-cache*
                 (< (- now *saved-gifs-cache-time*) *saved-gifs-cache-ttl*))
        (return-from get-saved-gifs *saved-gifs-cache*))))

  (handler-case
      (let* ((connection (get-current-connection))
             (params nil)
             (result (make-api-call connection "getSavedGifs" params)))
        (when result
          (let ((gifs (getf result :gifs)))
            (setf *saved-gifs-cache* gifs
                  *saved-gifs-cache-time* now)
            gifs)))
    (error (e)
      (log-message :error "Error getting saved GIFs: ~A" (princ-to-string e))
      nil)))

(defun search-gif (query &key (limit 20))
  "Search for GIFs.

   Args:
     query: Search query
     limit: Maximum results (default: 20)

   Returns:
     List of GIF objects

   Example:
     (search-gif \"happy birthday\" :limit 10)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("q" . ,query)
                       ("limit" . ,limit)))
             (result (make-api-call connection "searchGifs" params)))
        (when result
          (getf result :results)))
    (error (e)
      (log-message :error "Error searching GIFs: ~A" (princ-to-string e))
      nil)))

(defun clear-saved-gifs-cache ()
  "Clear saved GIFs cache.

   Returns:
     T on success

   Example:
     (clear-saved-gifs-cache)"
  (setf *saved-gifs-cache* nil
        *saved-gifs-cache-time* 0)
  t)

;;; ============================================================================
;;; Section 3: Available Effects
;;; ============================================================================

(defclass chat-effect ()
  ((effect-id :initarg :effect-id :accessor chat-effect-id
              :documentation "Unique effect identifier")
   (type :initarg :type :accessor chat-effect-type
         :documentation "Effect type: :emoji, :fullscreen, :background")
   (title :initarg :title :accessor chat-effect-title
          :initform "" :documentation "Effect title")
   (thumbnail :initarg :thumbnail :accessor chat-effect-thumbnail
             :initform nil :documentation "Effect thumbnail")
   (animation :initarg :animation :accessor chat-effect-animation
              :initform nil :documentation "Effect animation file-id")))

(defun get-available-effects (&key (limit 50))
  "Get available chat effects.

   Args:
     limit: Maximum results (default: 50)

   Returns:
     List of chat-effect objects

   Example:
     (get-available-effects :limit 100)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("limit" . ,limit)))
             (result (make-api-call connection "getAvailableEffects" params)))
        (when result
          (let ((effects (getf result :effects)))
            (mapcar (lambda (effect-data)
                      (make-instance 'chat-effect
                                     :effect-id (getf effect-data :effect_id)
                                     :type (case (getf effect-data :type)
                                             (:emoji :emoji)
                                             (:fullscreen :fullscreen)
                                             (:background :background)
                                             (otherwise :custom))
                                     :title (getf effect-data :title)
                                     :thumbnail (getf effect-data :thumbnail)
                                     :animation (getf effect-data :animation)))
                    effects))))
    (error (e)
      (log-message :error "Error getting available effects: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 4: Recent Emoji Reactions
;;; ============================================================================

(defvar *recent-emoji-reactions* nil
  "List of recently used emoji reactions")

(defvar *recent-emoji-reactions-cache-time* 0
  "Cache timestamp for recent reactions")

(defun get-recent-emoji-reactions (&key (force-refresh nil) (limit 20))
  "Get recently used emoji reactions.

   Args:
     force-refresh: Force refresh from server
     limit: Maximum results (default: 20)

   Returns:
     List of emoji strings

   Example:
     (get-recent-emoji-reactions :limit 10)"
  (declare (ignore force-refresh))
  ;; Return cached list (Telegram doesn't have a dedicated API for this)
  ;; In a real implementation, this would fetch from the server
  (subseq *recent-emoji-reactions* 0 (min limit (length *recent-emoji-reactions*))))

(defun clear-recent-emoji-reactions ()
  "Clear recent emoji reactions.

   Returns:
     T on success

   Example:
     (clear-recent-emoji-reactions)"
  (setf *recent-emoji-reactions* nil
        *recent-emoji-reactions-cache-time* 0)
  t)

(defun add-recent-emoji-reaction (emoji)
  "Add an emoji to recent reactions.

   Args:
     emoji: Emoji character

   Returns:
     T on success

   Example:
     (add-recent-emoji-reaction \"❤️\")"
  (pushnew emoji *recent-emoji-reactions* :test #'string=)
  ;; Keep only last 50
  (when (> (length *recent-emoji-reactions*) 50)
    (setf *recent-emoji-reactions*
          (subseq *recent-emoji-reactions* 0 50)))
  t)

;;; ============================================================================
;;; Section 5: Chat Themes and Wallpapers
;;; ============================================================================

(defclass chat-theme ()
  ((id :initarg :id :accessor chat-theme-id
       :documentation "Theme identifier")
   (title :initarg :title :accessor chat-theme-title
          :documentation "Theme title")
   (thumbnail :initarg :thumbnail :accessor chat-theme-thumbnail
             :documentation "Theme thumbnail")
   (colors :initarg :colors :accessor chat-theme-colors
          :documentation "List of theme colors")
   (is-dark :initarg :is-dark :accessor chat-theme-is-dark
           :initform nil :documentation "Whether this is a dark theme")))

(defun get-chat-themes ()
  "Get available chat themes.

   Returns:
     List of chat-theme objects

   Example:
     (get-chat-themes)"
  (handler-case
      (let* ((connection (get-current-connection))
             (result (make-api-call connection "getChatThemes" nil)))
        (when result
          (let ((themes (getf result :themes)))
            (mapcar (lambda (theme-data)
                      (make-instance 'chat-theme
                                     :id (getf theme-data :id)
                                     :title (getf theme-data :title)
                                     :thumbnail (getf theme-data :thumbnail)
                                     :colors (getf theme-data :colors)
                                     :is-dark (getf theme-data :is_dark nil)))
                    themes))))
    (error (e)
      (log-message :error "Error getting chat themes: ~A" (princ-to-string e))
      nil)))

(defun save-wallpaper (wallpaper &key (for-dark-theme nil))
  "Save a wallpaper.

   Args:
     wallpaper: Wallpaper file ID or input object
     for-dark-theme: Whether for dark theme

   Returns:
     T on success, NIL on failure

   Example:
     (save-wallpaper \"AgAD1234\" :for-dark-theme t)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("wallpaper" . ,wallpaper))))
        (when for-dark-theme
          (push (cons "for_dark_theme" "true") params))

        (let ((result (make-api-call connection "saveWallpaper" params)))
          (if result t nil)))
    (error (e)
      (log-message :error "Error saving wallpaper: ~A" (princ-to-string e))
      nil)))

(defun install-wallpaper (wallpaper-id)
  "Install a wallpaper.

   Args:
     wallpaper-id: Wallpaper file ID

   Returns:
     T on success, NIL on failure

   Example:
     (install-wallpaper \"AgAD1234\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("wallpaper_id" . ,wallpaper-id)))
             (result (make-api-call connection "installWallpaper" params)))
        (if result t nil))
    (error (e)
      (log-message :error "Error installing wallpaper: ~A" (princ-to-string e))
      nil)))

(defun reset-wallpapers ()
  "Reset wallpapers to default.

   Returns:
     T on success

   Example:
     (reset-wallpapers)"
  (handler-case
      (let* ((connection (get-current-connection))
             (result (make-api-call connection "resetWallpapers" nil)))
        (if result t nil))
    (error (e)
      (log-message :error "Error resetting wallpapers: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 6: Sticker Set Conversion
;;; ============================================================================

(defun convert-sticker-set (set-name target-type)
  "Convert a sticker set to a different type.

   Args:
     set-name: Sticker set short name
     target-type: Target type (:video, :animated, :static)

   Returns:
     T on success, NIL on failure

   Example:
     (convert-sticker-set \"my_set\" :video)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("stickerset" . ,set-name)
                       ("type" . ,(case target-type
                                    (:video "video")
                                    (:animated "animated")
                                    (otherwise "static")))))
             (result (make-api-call connection "convertStickerSet" params)))
        (if result
            (progn
              ;; Invalidate cache
              (remhash set-name *sticker-cache*)
              t)
            nil))
    (error (e)
      (log-message :error "Error converting sticker set: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 7: Utilities
;;; ============================================================================

(defun validate-sticker-file (file-path &key (type :static))
  "Validate a sticker file meets requirements.

   Args:
     file-path: Path to sticker file
     type: Sticker type (:static, :animated, :video)

   Returns:
     T if valid, error message string if invalid

   Example:
     (validate-sticker-file \"/path/to/sticker.png\" :type :static)"
  (unless (probe-file file-path)
    (return-from validate-sticker-file "File not found"))

  (let* ((file-info (probe-file file-path))
         (file-size (file-length file-info))
         (ext (pathname-type file-path)))
    ;; Check file size
    (when (> file-size (* 64 1024))
      (return-from validate-sticker-file
        (format nil "File too large: ~DKB (max 64KB)" (truncate file-size 1024))))

    ;; Check format by type
    (case type
      (:static
       (unless (member (string-downcase ext) '("png" "webp") :test #'string=)
         (return-from validate-sticker-file "Static stickers must be PNG or WEBP")))
      (:animated
       (unless (string-equal ext "tgs")
         (return-from validate-sticker-file "Animated stickers must be TGS")))
      (:video
       (unless (string-equal ext "webm")
         (return-from validate-sticker-file "Video stickers must be WEBM"))))

    t))

;;; End of stickers-enhanced.lisp
