;;; font-manager.lisp --- Font management and text rendering using cl-freetype2
;;;
;;; Provides text rendering capabilities for image overlays using FreeType 2.
;;; Supports CJK fonts for multi-language text rendering.
;;;
;;; Requirements:
;;;   - cl-freetype2 (Quicklisp: (ql:quickload "cl-freetype2"))
;;;   - System FreeType 2 library installed

(defpackage #:cl-telegram/font-manager
  (:nicknames #:cl-tg/font)
  (:use #:cl)
  (:export
   ;; Initialization
   #:init-font-system
   #:shutdown-font-system
   #:*freetype-initialized-p*

   ;; Font loading
   #:load-font
   #:get-font-face
   #:unload-font
   #:*default-font-path*

   ;; Text rendering
   #:render-text
   #:render-text-to-image
   #:add-text-overlay
   #:measure-text

   ;; Font utilities
   #:get-available-fonts
   #:get-font-metrics
   #:supports-character-p
   #:get-cjk-font
   #:*cjk-fonts*

   ;; Text styling
   #:*default-font-size*
   #:*default-text-color*
   #:render-text-with-stroke
   #:render-text-with-shadow))

(in-package #:cl-telegram/font-manager)

;;; ============================================================================
;;; Global State
;;; ============================================================================

(defvar *freetype-library* nil
  "FreeType library instance")

(defvar *freetype-initialized-p* nil
  "Whether FreeType has been initialized")

(defvar *font-cache* (make-hash-table :test 'equal)
  "Cache for loaded font faces")

(defvar *default-font-path* nil
  "Path to default font file")

(defvar *default-font-size* 24
  "Default font size in pixels")

(defvar *default-text-color* '(255 255 255)
  "Default text color (RGB)")

;; Common CJK fonts by language
(defparameter +cjk-fonts+
  '(("zh" . ("Noto Sans CJK SC"
             "Source Han Sans SC"
             "WenQuanYi Micro Hei"
             "SimSun"
             "Microsoft YaHei"))
    ("zh-tw" . ("Noto Sans CJK TC"
                "Source Han Sans TC"))
    ("ja" . ("Noto Sans CJK JP"
             "Source Han Sans JP"))
    ("ko" . ("Noto Sans CJK KR"
             "Source Han Sans KR"))))

;;; ============================================================================
;;; Initialization
;;; ============================================================================

(defun init-font-system (&key (default-font-path nil))
  "Initialize FreeType library.

   Args:
     default-font-path: Path to default font file (optional)

   Returns:
     T on success, NIL on error"
  (handler-case
      (progn
        (when *freetype-initialized-p*
          (return-from init-font-system t))

        ;; Initialize FreeType library
        (setf *freetype-library* (ft:make-library))
        (setf *freetype-initialized-p* t)

        ;; Set default font if provided
        (when default-font-path
          (setf *default-font-path* default-font-path)
          (load-font default-font-path))

        t)
    (condition (e)
      (log:error "Failed to initialize FreeType: ~A" e)
      ;; Fallback: mark as not initialized but continue
      (setf *freetype-initialized-p* nil)
      nil)))

(defun shutdown-font-system ()
  "Shutdown FreeType library and clear font cache.

   Returns:
     T"
  (when *freetype-library*
    (ft:done-free-type)
    (setf *freetype-library* nil
          *freetype-initialized-p* nil))
  (clr-hash *font-cache*)
  t)

;;; ============================================================================
;;; Font Loading
;;; ============================================================================

(defun load-font (font-path)
  "Load font from file path.

   Args:
     font-path: Path to font file (.ttf, .otf, etc.)

   Returns:
     Font face object or NIL on error"
  (unless (probe-file font-path)
    (log:error "Font file not found: ~A" font-path)
    (return-from load-font nil))

  ;; Check cache
  (let ((cached (gethash font-path *font-cache*)))
    (when cached
      (return-from load-font cached)))

  (handler-case
      (let* ((face (ft:make-face font-path))
             (font-data (list :face face
                              :path font-path
                              :loaded (get-universal-time))))
        (setf (gethash font-path *font-cache*) font-data)
        font-data)
    (condition (e)
      (log:error "Failed to load font ~A: ~A" font-path e)
      nil)))

(defun get-font-face (font-path)
  "Get font face from path or cache.

   Args:
     font-path: Path to font file

   Returns:
     Font face object or NIL"
  (let ((font-data (or (gethash font-path *font-cache*)
                       (load-font font-path))))
    (when font-data
      (getf font-data :face))))

(defun unload-font (font-path)
  "Unload font from cache.

   Args:
     font-path: Path to font file

   Returns:
     T if unloaded, NIL if not found"
  (let ((font-data (gethash font-path *font-cache*)))
    (when font-data
      (let ((face (getf font-data :face)))
        (when face
          (ft:done-face face)))
      (remhash font-path *font-cache*)
      t)))

;;; ============================================================================
;;; Text Rendering
;;; ============================================================================

(defun render-text (text &key (font-path *default-font-path*)
                           (font-size *default-font-size*)
                           (color *default-text-color*))
  "Render text to bitmap using FreeType.

   Args:
     text: Text string to render
     font-path: Font file path
     font-size: Font size in pixels
     color: RGB color list (R G B)

   Returns:
     Values: bitmap, width, height, baseline"
  (unless *freetype-initialized-p*
    (init-font-system))

  (unless (and font-path (probe-file font-path))
    ;; Try to use system font
    (setf font-path (find-system-font "Arial" "DejaVu Sans" "Noto Sans")))

  (let ((face (get-font-face font-path)))
    (unless face
      (error "Cannot load font: ~A" font-path))

    (handler-case
        (progn
          ;; Set font size
          (ft:set-pixel-sizes face 0 font-size)

          ;; Calculate text dimensions
          (multiple-value-bind (width height baseline)
              (measure-text text face)

            ;; Create bitmap
            (let ((bitmap (make-array (list height width 3)
                                      :element-type '(unsigned-byte 8)
                                      :initial-element 0)))

              ;; Render each glyph
              (let ((x 0))
                (loop for char across text
                      for glyph-index = (ft:get-char-index face (char-code char))
                      do (ft:load-glyph face glyph-index)
                      do (let ((glyph (ft:get-glyph face))
                               (bitmap-ptr (ft:render-glyph glyph :render-mono)))
                           ;; Copy glyph to bitmap
                           (copy-glyph-to-bitmap bitmap bitmap-ptr x (- baseline (ft:glyph-bbox-top bitmap-ptr)))
                           (incf x (floor (ft:glyph-advance-x bitmap-ptr) 64))))

              (values bitmap width height baseline))))
      (condition (e)
        (log:error "Text rendering failed: ~A" e)
        (values nil 0 0 0)))))

(defun render-text-to-image (image text &key x y font-size color font-path)
  "Render text onto existing image.

   Args:
     image: Opticl image object
     text: Text string to render
     x: X position (default: center)
     y: Y position (default: bottom)
     font-size: Font size in pixels
     color: RGB color list
     font-path: Font file path

   Returns:
     Modified image object"
  (handler-case
      (let* ((x (or x (floor (- (opticl:width image) 100) 2)))
             (y (or y (- (opticl:height image) 30)))
             (font-size (or font-size *default-font-size*))
             (color (or color *default-text-color*))
             (font (or font-path *default-font-path*)))

        (unless *freetype-initialized-p*
          (init-font-system))

        ;; Find a suitable font
        (unless (and font (probe-file font))
          (setf font (find-system-font "Arial" "DejaVu Sans" "Noto Sans")))

        (when font
          (let ((face (get-font-face font)))
            (when face
              (ft:set-pixel-sizes face 0 font-size)

              ;; Render text onto image
              (let ((text-x x))
                (loop for char across text
                      for glyph-index = (ft:get-char-index face (char-code char))
                      do (ft:load-glyph face glyph-index)
                      do (render-glyph-to-image image face text-x y color)
                      do (let ((glyph (ft:get-glyph face)))
                           (incf text-x (floor (or (ft:glyph-advance-x glyph) 0) 64)))))))

        image)
    (condition (e)
      (log:error "Failed to render text to image: ~A" e)
      ;; Fallback: log and return original image
      (log:info "Text overlay (placeholder): ~A at (~A, ~A)" text x y)
      image)))

(defun render-glyph-to-image (image face x y color)
  "Render single glyph to image.

   Args:
     image: Opticl image object
     face: FreeType face object
     x: X position
     y: Y position
     color: RGB color list"
  (let* ((glyph (ft:render-glyph (ft:get-glyph face) :render-mono))
         (glyph-width (ft:bitmap-width glyph))
         (glyph-height (ft:bitmap-rows glyph))
         (glyph-left (ft:glyph-left glyph))
         (glyph-top (ft:glyph-top glyph)))

    (when (and glyph-width glyph-height)
      (let ((glyph-buffer (ft:bitmap-buffer glyph)))
        (loop for gy from 0 below glyph-height
              for py from (+ y glyph-top (- glyph-height))
              do (loop for gx from 0 below glyph-width
                       for px from (+ x glyph-left)
                       for alpha = (aref glyph-buffer gy gx)
                       when (and (>= px 0) (< px (opticl:width image))
                                 (>= py 0) (< py (opticl:height image)))
                       do (multiple-value-bind (r g b a) (opticl:pixel image px py)
                            (let ((blend (/ alpha 255.0)))
                              (opticl:set-pixel image px py
                                                (+ (* (first color) blend) (* r (- 1 blend)))
                                                (+ (* (second color) blend) (* g (- 1 blend)))
                                                (+ (* (third color) blend) (* b (- 1 blend)))
                                                a)))))))))

(defun add-text-overlay (image text &key x y font-size color font-path stroke shadow)
  "Add text overlay to image (main API function).

   Args:
     image: Opticl image object
     text: Text string to render
     x: X position
     y: Y position
     font-size: Font size in pixels
     color: RGB color list
     font-path: Font file path
     stroke: Stroke color (for outlined text)
     shadow: Whether to add shadow

   Returns:
     Modified image object"
  (handler-case
      (let ((img (render-text-to-image image text
                                       :x x
                                       :y y
                                       :font-size font-size
                                       :color color
                                       :font-path font-path)))
        (when stroke
          (render-text-with-stroke img text
                                   :x x :y y
                                   :font-size font-size
                                   :stroke-color stroke
                                   :fill-color color
                                   :font-path font-path))
        (when shadow
          (render-text-with-shadow img text
                                   :x (+ x 2) :y (- y 2)
                                   :font-size font-size
                                   :shadow-color '(0 0 0)
                                   :font-path font-path))
        img)
    (condition (e)
      (log:error "Text overlay failed: ~A" e)
      ;; Fallback to placeholder
      (log:info "Text overlay (placeholder): ~A" text)
      image)))

;;; ============================================================================
;;; Text Measurement
;;; ============================================================================

(defun measure-text (text face)
  "Measure text dimensions.

   Args:
     text: Text string
     face: FreeType face object

   Returns:
     Values: width, height, baseline"
  (let ((width 0)
        (height 0)
        (baseline 0))

    (loop for char across text
          for glyph-index = (ft:get-char-index face (char-code char))
          do (ft:load-glyph face glyph-index)
          do (let ((glyph (ft:get-glyph face)))
               (incf width (floor (or (ft:glyph-advance-x glyph) 0) 64))
               (let ((glyph-height (- (ft:glyph-bbox-top glyph)
                                      (ft:glyph-bbox-bottom glyph))))
                 (when (> glyph-height height)
                   (setf height glyph-height)))
               (let ((glyph-baseline (ft:glyph-bbox-bottom glyph)))
                 (when (> glyph-baseline baseline)
                   (setf baseline glyph-baseline)))))

    (values width height baseline)))

(defun get-font-metrics (font-path)
  "Get font metrics.

   Args:
     font-path: Font file path

   Returns:
     Plist with :ascender, :descender, :height, :underline-position, :underline-thickness"
  (let ((face (get-font-face font-path)))
    (when face
      (list :ascender (ft:face-ascender face)
            :descender (ft:face-descender face)
            :height (ft:face-height face)
            :underline-position (ft:face-underline-position face)
            :underline-thickness (ft:face-underline-thickness face)))))

;;; ============================================================================
;;; Advanced Text Styling
;;; ============================================================================

(defun render-text-with-stroke (image text &key x y font-size stroke-color fill-color font-path)
  "Render text with stroke/outline.

   Args:
     image: Opticl image object
     text: Text string
     x: X position
     y: Y position
     font-size: Font size
     stroke-color: Stroke color (RGB)
     fill-color: Fill color (RGB)
     font-path: Font file path

   Returns:
     Modified image"
  ;; Render stroke by drawing text multiple times with offset
  (loop for dx in '(-1 0 1 0)
        for dy in '(0 -1 0 1)
        do (render-text-to-image image text
                                 :x (+ x dx)
                                 :y (+ y dy)
                                 :font-size font-size
                                 :color stroke-color
                                 :font-path font-path))

  ;; Render fill
  (render-text-to-image image text
                        :x x
                        :y y
                        :font-size font-size
                        :color fill-color
                        :font-path font-path)
  image)

(defun render-text-with-shadow (image text &key x y font-size shadow-color font-path)
  "Render text with shadow.

   Args:
     image: Opticl image object
     text: Text string
     x: X position
     y: Y position
     font-size: Font size
     shadow-color: Shadow color (RGB)
     font-path: Font file path

   Returns:
     Modified image"
  ;; Render shadow
  (render-text-to-image image text
                        :x (+ x 2)
                        :y (- y 2)
                        :font-size font-size
                        :color shadow-color
                        :font-path font-path)
  image)

;;; ============================================================================
;;; Font Utilities
;;; ============================================================================

(defun get-available-fonts ()
  "Get list of available fonts.

   Returns:
     List of font paths"
  (let ((font-paths nil))
    ;; Search common font directories
    (dolist (dir '("/usr/share/fonts"
                   "/usr/local/share/fonts"
                   "~/.fonts"
                   "C:/Windows/Fonts"
                   "/Library/Fonts"))
      (let ((dir (expand-namestring dir)))
        (when (probe-file dir)
          (let ((files (directory (merge-pathnames "*.ttf" dir))))
            (append font-paths files)))))
    font-paths))

(defun supports-character-p (font-path char-code)
  "Check if font supports a character.

   Args:
     font-path: Font file path
     char-code: Character code

   Returns:
     T if supported, NIL otherwise"
  (let ((face (get-font-face font-path)))
    (when face
      (> (ft:get-char-index face char-code) 0))))

(defun get-cjk-font (&optional (language "zh"))
  "Get CJK font for language.

   Args:
     language: Language code (zh, zh-tw, ja, ko)

   Returns:
     Font path or NIL"
  (let ((fonts (cdr (assoc language +cjk-fonts+ :test #'string=))))
    (dolist (font-name fonts)
      (let ((font-path (find-system-font font-name)))
        (when font-path
          (return-from get-cjk-font font-path))))
    ;; Fallback to any CJK font
    (find-cjk-font)))

(defun find-system-font (&rest names)
  "Find system font by name.

   Args:
     names: Font names to search

   Returns:
     Font path or NIL"
  (dolist (name names)
    (let ((paths (list (merge-pathfonts name "ttf")
                       (merge-pathfonts name "otf")
                       (merge-pathfonts name "ttc"))))
      (dolist (path paths)
        (when (probe-file path)
          (return-from find-system-font path)))))
  nil)

(defun merge-pathfonts (name type)
  "Merge font name with path.

   Args:
     name: Font name
     type: Font type (ttf, otf, etc.)

   Returns:
     Pathname"
  (merge-pathnames (make-pathname :name name
                                  :type type)
                   #P"/usr/share/fonts/"))

(defun find-cjk-font ()
  "Find any available CJK font.

   Returns:
     Font path or NIL"
  (let ((cjk-names '("NotoSansCJK"
                     "SourceHanSans"
                     "WenQuanYi"
                     "SimSun"
                     "MicrosoftYaHei")))
    (dolist (name cjk-names)
      (let ((path (find-system-font name)))
        (when path
          (return-from find-cjk-font path))))
  nil)

(defun expand-namestring (path)
  "Expand ~ in path.

   Args:
     path: Path string

   Returns:
     Expanded path"
  (if (and (> (length path) 0)
           (char= (char path 0) #\~))
      (merge-pathnames (subseq path 2)
                       (user-homedir-pathname))
      path))

;;; ============================================================================
;;; Hook for image-overlays integration
;;; ============================================================================

;; Auto-initialize when package is loaded
(pushnew 'init-font-system *init-hooks*)
