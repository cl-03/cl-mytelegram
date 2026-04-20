;;; emoji-renderer.lisp --- Emoji rendering for image overlays
;;;
;;; Provides emoji rendering capabilities using system emoji fonts or Twemoji images.
;;; Supports both Unicode emoji and Telegram custom emoji.
;;;
;;; Requirements:
;;;   - cl-cairo2 (Quicklisp: (ql:quickload "cl-cairo2"))
;;;   - System Cairo library with color font support
;;;   - Noto Color Emoji or Twemoji fonts

(defpackage #:cl-telegram/emoji-renderer
  (:nicknames #:cl-tg/emoji)
  (:use #:cl)
  (:export
   ;; Initialization
   #:init-emoji-renderer
   #:shutdown-emoji-renderer
   #:*emoji-initialized-p*

   ;; Emoji rendering
   #:render-emoji
   #:render-emoji-to-image
   #:add-emoji-overlay
   #:render-emoji-sequence

   ;; Custom emoji (Telegram)
   #:render-custom-emoji
   #:get-custom-emoji-image
   #:download-custom-emoji
   #:cache-custom-emoji

   ;; Emoji utilities
   #:get-emoji-image
   #:get-available-emoji-fonts
   #:emoji-to-image
   #:measure-emoji

   ;; Emoji cache
   #:clear-emoji-cache
   #:preload-common-emoji

   ;; Configuration
   #:*default-emoji-size*
   #:*emoji-cache-size*
   #:*twemoji-path*
   #:*use-twemoji-p*))

(in-package #:cl-telegram/emoji-renderer)

;;; ============================================================================
;;; Global State
;;; ============================================================================

(defvar *emoji-initialized-p* nil
  "Whether emoji renderer has been initialized")

(defvar *cairo-surface* nil
  "Cairo image surface for emoji rendering")

(defvar *emoji-font-name* nil
  "Name of emoji font in use")

(defvar *emoji-cache* (make-hash-table :test 'equal)
  "Cache for rendered emoji images")

(defvar *custom-emoji-cache* (make-hash-table :test 'equal)
  "Cache for Telegram custom emoji")

(defvar *default-emoji-size* 48
  "Default emoji size in pixels")

(defvar *emoji-cache-size* 500
  "Maximum number of cached emoji")

(defvar *twemoji-path* nil
  "Path to Twemoji image directory")

(defvar *use-twemoji-p* nil
  "Whether to use Twemoji images instead of font")

(defvar *common-emoji*
  '("😀" "😁" "😂" "🤣" "😃" "😄" "😅" "😆" "😉" "😊"
    "😋" "😎" "😍" "😘" "🥰" "😗" "😙" "😚" "🙂" "🤗"
    "🤩" "🤔" "🤨" "😐" "😑" "😶" "🙄" "😏" "😣" "😥"
    "😮" "🤐" "😯" "😪" "😫" "😴" "😌" "😛" "😜" "😝"
    "🤤" "😒" "😓" "😔" "😕" "🙃" "🤑" "😲" "☹️" "🙁"
    "😖" "😞" "😟" "😤" "😢" "😭" "😦" "😧" "😨" "😩"
    "🤯" "😬" "😰" "😱" "🥵" "🥶" "😳" "🤪" "😵" "😡"
    "😠" "🤬" "😷" "🤒" "🤕" "🤢" "🤮" "🤧" "😇" "🤠"
    "🥳" "🥴" "🥺" "🤥" "🤫" "🤭" "🧐" "🤓" "😈" "👿"
    "👍" "👎" "👊" "✊" "🤛" "🤜" "🤞" "✌️" "🤟" "🤘"
    "👌" "👈" "👉" "👆" "👇" "☝️" "✋" "🤚" "🖐" "🖖"
    "👋" "🤙" "💪" "🖕" "✍️" "🙏" "💍" "💄" "💋" "👄"
    "❤️" "💛" "💚" "💙" "💜" "🖤" "💔" "❣️" "💕" "💞"
    "💓" "💗" "💖" "💘" "💝" "🔥" "✨" "🌟" "⭐" "🎉"
    "🎊" "🎈" "🎁" "🎀" "🎂" "🎄" "🎃" "🎅" "🎆" "🎇")
  "Common emoji for preloading")

;;; ============================================================================
;;; Initialization
;;; ============================================================================

(defun init-emoji-renderer (&key use-twemoji twemoji-path emoji-font)
  "Initialize emoji renderer.

   Args:
     use-twemoji: Use Twemoji images instead of font (default: NIL)
     twemoji-path: Path to Twemoji image directory
     emoji-font: Specific emoji font name to use

   Returns:
     T on success, NIL on error"
  (handler-case
      (progn
        (when *emoji-initialized-p*
          (return-from init-emoji-renderer t))

        (cond
          ((and use-twemoji twemoji-path)
           ;; Use Twemoji images
           (setf *use-twemoji-p* t
                 *twemoji-path* twemoji-path))
          (t
           ;; Try to use system emoji font
           (setf *emoji-font-name* (or emoji-font
                                       (find-emoji-font)))
           (when *emoji-font-name*
             (setf *emoji-initialized-p* t))))

        (when (or *emoji-font-name* *use-twemoji-p*)
          (setf *emoji-initialized-p* t)
          t))
    (condition (e)
      (log:error "Failed to initialize emoji renderer: ~A" e)
      nil)))

(defun shutdown-emoji-renderer ()
  "Shutdown emoji renderer and clear caches.

   Returns:
     T"
  (when *cairo-surface*
    ;; Cleanup Cairo surface if created
    (setf *cairo-surface* nil))
  (clr-hash *emoji-cache*)
  (clr-hash *custom-emoji-cache*)
  (setf *emoji-initialized-p* nil)
  t)

(defun find-emoji-font ()
  "Find available emoji font on system.

   Returns:
     Font name string or NIL"
  (let ((emoji-fonts '("Noto Color Emoji"
                       "Apple Color Emoji"
                       "Segoe UI Emoji"
                       "Segoe UI Symbol"
                       "Twemoji"
                       "EmojiOne"
                       "JoyPixels")))
    (dolist (font-name emoji-fonts)
      (when (font-available-p font-name)
        (return-from find-emoji-font font-name))))
  nil)

(defun font-available-p (font-name)
  "Check if font is available on system.

   Args:
     font-name: Font name string

   Returns:
     T if available, NIL otherwise"
  ;; This is a simplified check - actual implementation would query fontconfig
  ;; On Windows, check C:/Windows/Fonts
  ;; On macOS, check /System/Library/Fonts
  ;; On Linux, check /usr/share/fonts
  (let ((font-dirs (list #P"C:/Windows/Fonts/"
                         #P"/System/Library/Fonts/"
                         #P"/usr/share/fonts/"
                         #P"~/.fonts/")))
    (dolist (dir font-dirs)
      (when (probe-file dir)
        (let ((font-file (find-font-file dir font-name)))
          (when font-file
            (return-from font-available-p t))))))
  nil)

(defun find-font-file (dir font-name)
  "Find font file by name in directory.

   Args:
     dir: Directory pathname
     font-name: Font name

   Returns:
     Font file path or NIL"
  (let ((extensions '("ttf" "ttc" "otf")))
    (dolist (ext extensions)
      (let ((path (merge-pathnames (make-pathname :name (remove #\Space font-name)
                                                  :type ext)
                                   dir)))
        (when (probe-file path)
          (return-from find-font-file path))))))

;;; ============================================================================
;;; Emoji Rendering
;;; ============================================================================

(defun render-emoji-to-image (emoji &key (size *default-emoji-size*))
  "Render emoji to image surface.

   Args:
     emoji: Emoji character or string
     size: Size in pixels

   Returns:
     Opticl image object or NIL"
  (check-cache emoji size))

  (cond
    (*use-twemoji-p*
     ;; Use Twemoji images
     (load-twemoji emoji size))
    (*emoji-font-name*
     ;; Use system emoji font with Cairo
     (render-emoji-with-cairo emoji size))
    (t
     ;; Fallback: placeholder
     (create-emoji-placeholder emoji size))))

(defun render-emoji (emoji &key (size *default-emoji-size*))
  "Render emoji and return image data.

   Args:
     emoji: Emoji character or string
     size: Size in pixels

   Returns:
     Image object or NIL"
  (render-emoji-to-image emoji :size size))

(defun render-emoji-with-cairo (emoji size)
  "Render emoji using Cairo and system emoji font.

   Args:
     emoji: Emoji character/string
     size: Size in pixels

   Returns:
     Opticl image object"
  (handler-case
      (let* ((surface (cairo:image-surface-create :argb32 size size))
             (cr (cairo:create surface)))
        ;; Clear surface
        (cairo:set-source-rgb cr 0 0 0)
        (cairo:paint cr)

        ;; Set font and render emoji
        (cairo:select-font-face cr *emoji-font-name* :font-slant-normal :font-weight-normal)
        (cairo:set-font-size cr (* size 0.8))
        (cairo:move-to cr 0 size)
        (cairo:set-source-rgb cr 1 1 1)
        (cairo:show-text cr (string emoji))

        ;; Convert to Opticl image
        (let ((image (cairo-surface-to-opticl surface size size)))
          (cairo:surface-destroy surface)
          (cairo:destroy cr)
          ;; Cache result
          (setf (gethash (format nil "~A-~A" emoji size) *emoji-cache*) image)
          image))
    (condition (e)
      (log:error "Cairo emoji rendering failed: ~A" e)
      (create-emoji-placeholder emoji size))))

(defun render-emoji-sequence (emoji-list &key (size *default-emoji-size*) (spacing 5))
  "Render sequence of emoji horizontally.

   Args:
     emoji-list: List of emoji characters
     size: Size in pixels
     spacing: Spacing between emoji

   Returns:
     Opticl image object"
  (let* ((total-width (+ (* (length emoji-list) size)
                         (* (1- (length emoji-list)) spacing)))
         (image (make-instance 'opticl:rgba-image
                               :width total-width
                               :height size)))
    (loop for emoji in emoji-list
          for x from 0 by (+ size spacing)
          do (let ((emoji-img (render-emoji-to-image emoji :size size)))
               (when emoji-img
                 (composite-image image emoji-img x 0))))
    image))

(defun create-emoji-placeholder (emoji size)
  "Create placeholder emoji image when rendering fails.

   Args:
     emoji: Emoji character
     size: Size in pixels

   Returns:
     Opticl image object"
  (let ((image (make-instance 'opticl:rgba-image :width size :height size)))
    ;; Fill with background color
    (dotimes (y size)
      (dotimes (x size)
        (opticl:set-pixel image x y 240 240 240 255)))
    ;; Draw emoji character as text (fallback)
    (log:info "Emoji placeholder created: ~A at ~Ax~A" emoji size size)
    image))

;;; ============================================================================
;;; Twemoji Support
;;; ============================================================================

(defun load-twemoji (emoji size)
  "Load Twemoji image for emoji.

   Args:
     emoji: Emoji character
     size: Desired size

   Returns:
     Opticl image object or NIL"
  (unless *twemoji-path*
    (return-from load-twemoji nil))

  (let ((emoji-code (emoji-to-codepoint emoji))
        (image-path (format nil "~A/~A.png" *twemoji-path* (emoji-to-codepoint emoji))))
    (when (probe-file image-path)
      (let ((image (opticl:read-png-file image-path)))
        (when image
          ;; Resize if needed
          (if (= (image-width image) size)
              image
              (scale-image image size size)))))))

(defun emoji-to-codepoint (emoji)
  "Convert emoji to Unicode codepoint string.

   Args:
     emoji: Emoji character

   Returns:
     Codepoint string (e.g., \"1f600\")"
  (format nil "~{~2,'0x~}" (mapcar #'char-code (coerce emoji 'list))))

;;; ============================================================================
;;; Custom Emoji (Telegram)
;;; ============================================================================

(defun render-custom-emoji (emoji-id &key (size *default-emoji-size*))
  "Render Telegram custom emoji.

   Args:
     emoji-id: Custom emoji file ID
     size: Size in pixels

   Returns:
     Opticl image object or NIL"
  ;; Check cache first
  (let ((cached (gethash (format nil "~A-~A" emoji-id size) *custom-emoji-cache*)))
    (when cached
      (return-from render-custom-emoji cached)))

  ;; Download and render
  (let ((image (get-custom-emoji-image emoji-id size)))
    (when image
      (setf (gethash (format nil "~A-~A" emoji-id size) *custom-emoji-cache*) image)
      image)))

(defun get-custom-emoji-image (emoji-id &optional size)
  "Get custom emoji image from Telegram.

   Args:
     emoji-id: Custom emoji file ID
     size: Optional size

   Returns:
     Opticl image object or NIL"
  (handler-case
      ;; In production, this would call Telegram API to download custom emoji
      ;; For now, return NIL as placeholder
      (progn
        (log:info "Custom emoji requested: ~A" emoji-id)
        ;; TODO: Implement Telegram API call to download custom emoji sticker
        nil)
    (condition (e)
      (log:error "Failed to get custom emoji: ~A" e)
      nil)))

(defun download-custom-emoji (emoji-id file-path)
  "Download custom emoji from Telegram.

   Args:
     emoji-id: Custom emoji file ID
     file-path: Local file path to save

   Returns:
     File path or NIL"
  ;; TODO: Implement using Telegram Bot API getFile
  (declare (ignore emoji-id file-path))
  nil)

(defun cache-custom-emoji (emoji-id)
  "Cache custom emoji for offline use.

   Args:
     emoji-id: Custom emoji file ID

   Returns:
     T on success, NIL on error"
  (let ((image (get-custom-emoji-image emoji-id)))
    (when image
      (setf (gethash emoji-id *custom-emoji-cache*) image)
      t)))

;;; ============================================================================
;;; Image Overlay Integration
;;; ============================================================================

(defun add-emoji-overlay (image emoji &key x y size opacity)
  "Add emoji overlay to image.

   Args:
     image: Opticl image object
     emoji: Emoji character or custom emoji ID
     x: X position (default: center)
     y: Y position (default: center)
     size: Size in pixels
     opacity: Opacity 0.0-1.0

   Returns:
     Modified image object"
  (handler-case
      (let* ((x (or x (floor (- (opticl:width image) (or size *default-emoji-size*)) 2)))
             (y (or y (floor (- (opticl:height image) (or size *default-emoji-size*)) 2)))
             (size (or size *default-emoji-size*))
             (emoji-img (if (custom-emoji-id-p emoji)
                            (render-custom-emoji emoji :size size)
                            (render-emoji-to-image emoji :size size))))
        (when emoji-img
          ;; Apply opacity if needed
          (when (and opacity (< opacity 1.0))
            (apply-opacity emoji-img opacity))
          ;; Composite onto target image
          (composite-image image emoji-img x y))
        image)
    (condition (e)
      (log:error "Emoji overlay failed: ~A" e)
      ;; Fallback: log and return original
      (log:info "Emoji overlay (placeholder): ~A at (~A, ~A)" emoji x y)
      image)))

(defun custom-emoji-id-p (emoji)
  "Check if string is a custom emoji ID.

   Args:
     emoji: String to check

   Returns:
     T if custom emoji ID, NIL otherwise"
  (and (stringp emoji)
       (or (search "custom" emoji)
           (search "emoji" emoji)
           (every #'alphanumericp emoji))))

(defun composite-image (target source x y &key opacity)
  "Composite source image onto target.

   Args:
     target: Target image
     source: Source image
     x: X position
     y: Y position
     opacity: Opacity 0.0-1.0

   Returns:
     Target image"
  (let* ((src-width (opticl:width source))
         (src-height (opticl:height source))
         (opacity (or opacity 1.0)))
    (dotimes (sy src-height)
      (dotimes (sx src-width)
        (let* ((tx (+ x sx))
               (ty (+ y sy))
               (src-pixel (multiple-value-list (opticl:pixel source sx sy)))
               (src-alpha (/ (fourth src-pixel) 255.0)))
          (when (and (>= tx 0) (< tx (opticl:width target))
                     (>= ty 0) (< ty (opticl:height target)))
            (let* ((dst-pixel (multiple-value-list (opticl:pixel target tx ty)))
                   (alpha (* src-alpha opacity))
                   (inv-alpha (- 1 alpha)))
              (opticl:set-pixel target tx ty
                                (floor (+ (* (first src-pixel) alpha) (* (first dst-pixel) inv-alpha)))
                                (floor (+ (* (second src-pixel) alpha) (* (second dst-pixel) inv-alpha)))
                                (floor (+ (* (third src-pixel) alpha) (* (third dst-pixel) inv-alpha)))
                                (min 255 (floor (+ (* (fourth src-pixel) alpha) (* (fourth dst-pixel) inv-alpha))))))))))
    target))

(defun apply-opacity (image opacity)
  "Apply opacity to image.

   Args:
     image: Image object
     opacity: Opacity 0.0-1.0

   Returns:
     Modified image"
  (let ((factor (* opacity 255)))
    (dotimes (y (opticl:height image))
      (dotimes (x (opticl:width image))
        (multiple-value-bind (r g b a) (opticl:pixel image x y)
          (opticl:set-pixel image x y r g b (floor (* a factor)))))))
  image)

;;; ============================================================================
;;; Utilities
;;; ============================================================================

(defun measure-emoji (emoji)
  "Measure emoji dimensions.

   Args:
     emoji: Emoji character

   Returns:
     Values: width, height"
  (values *default-emoji-size* *default-emoji-size*))

(defun get-emoji-image (emoji &key size)
  "Get emoji image (alias for render-emoji-to-image).

   Args:
     emoji: Emoji character
     size: Size in pixels

   Returns:
     Opticl image object"
  (render-emoji-to-image emoji :size size))

(defun get-available-emoji-fonts ()
  "Get list of available emoji fonts.

   Returns:
     List of font names"
  (let ((fonts nil))
    (dolist (font-name '("Noto Color Emoji"
                         "Apple Color Emoji"
                         "Segoe UI Emoji"
                         "Twemoji"))
      (when (font-available-p font-name)
        (push font-name fonts)))
    fonts))

(defun clear-emoji-cache ()
  "Clear emoji cache.

   Returns:
     T"
  (clr-hash *emoji-cache*)
  clr-hash *custom-emoji-cache*)
  t)

(defun preload-common-emoji (&key (size *default-emoji-size*))
  "Preload common emoji into cache.

   Args:
     size: Size to preload

   Returns:
     Number of emoji preloaded"
  (let ((count 0))
    (dolist (emoji *common-emoji*)
      (let ((img (render-emoji-to-image emoji :size size)))
        (when img
          (incf count))))
    count))

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun cairo-surface-to-opticl (surface width height)
  "Convert Cairo surface to Opticl image.

   Args:
     surface: Cairo image surface
     width: Surface width
     height: Surface height

   Returns:
     Opticl image object"
  (let ((image (make-instance 'opticl:rgba-image :width width :height height)))
    ;; Copy pixel data from Cairo to Opticl
    (let ((data (cairo:image-surface-get-data surface))
          (stride (cairo:image-surface-get-stride surface)))
      (dotimes (y height)
        (dotimes (x width)
          (let* ((offset (+ (* y stride) (* x 4)))
                 (b (aref data offset))
                 (g (aref data (1+ offset)))
                 (r (aref data (+ 2 offset)))
                 (a (aref data (+ 3 offset))))
            (opticl:set-pixel image x y r g b a)))))
    image))

(defun scale-image (image new-width new-height)
  "Scale image to new size.

   Args:
     image: Opticl image
     new-width: New width
     new-height: New height

   Returns:
     Scaled image"
  ;; Simple nearest-neighbor scaling
  (let* ((old-width (opticl:width image))
         (old-height (opticl:height image))
         (scaled (make-instance 'opticl:rgba-image
                                :width new-width
                                :height new-height))
         (x-scale (/ old-width new-width))
         (y-scale (/ old-height new-height)))
    (dotimes (y new-height)
      (dotimes (x new-width)
        (let* ((src-x (floor (* x x-scale)))
               (src-y (floor (* y y-scale))))
          (multiple-value-bind (r g b a) (opticl:pixel image src-x src-y)
            (opticl:set-pixel scaled x y r g b a)))))
    scaled))

(defun image-width (image)
  "Get image width."
  (opticl:width image))

(defun image-height (image)
  "Get image height."
  (opticl:height image))

;;; ============================================================================
;;; Hook for integration
;;; ============================================================================

;; Auto-initialize when package is loaded
(pushnew 'init-emoji-renderer *init-hooks*)
