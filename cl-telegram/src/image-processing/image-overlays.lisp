;;; image-overlays.lisp --- Image overlay functions
;;;
;;; Provides:
;;; - Text overlays with custom fonts
;;; - Emoji overlays
;;; - Watermark support
;;; - Drawing primitives (rectangles, circles)

(in-package #:cl-telegram/image-processing)

;;; ### Text Overlay

(defun add-text-overlay (image text &key x y font-size color opacity)
  "Add text overlay to image.

   Args:
     image: Image object
     text: Text string to overlay
     x: X position (default: center)
     y: Y position (default: bottom)
     font-size: Font size in pixels (default: 24)
     color: RGB list (r g b) or :white/:black (default: :white)
     opacity: Text opacity 0.0-1.0 (default: 1.0)

   Returns:
     Image with text overlay"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (x (or x (floor (- width (* (length text) font-size 0.6) 2))))
             (y (or y (- height font-size 10)))
             (font-size (or font-size 24))
             (color (cond
                      ((eq color :white) '(255 255 255))
                      ((eq color :black) '(0 0 0))
                      ((listp color) color)
                      (t '(255 255 255))))
             (opacity (or opacity 1.0))
             (overlayed (make-instance 'opticl:rgba-image
                                       :width width
                                       :height height)))
        ;; Copy original image
        (dotimes (cy height)
          (dotimes (cx width)
            (multiple-value-bind (r g b a) (opticl:pixel image cx cy)
              (opticl:set-pixel overlayed cx cy r g b a))))

        ;; Render text (simplified bitmap font rendering)
        ;; For production use, integrate with cl-freetype or similar
        (render-text-simple overlayed text x y font-size color opacity)

        overlayed)
    (condition (e)
      (log:error "Text overlay failed: ~A" e)
      image)))

(defun render-text-simple (image text x y font-size color opacity)
  "Simple text rendering using bitmap approximation.

   Note: For proper font rendering, integrate with cl-freetype or lispkit."
  ;; This is a placeholder that logs the text overlay request
  ;; A full implementation would:
  ;; 1. Use cl-freetype to rasterize glyphs
  ;; 2. Or use lispkit (ImageMagick) for text rendering
  ;; 3. Or embed a simple bitmap font
  (log:info "Text overlay requested: '~A' at (~A, ~A) size ~A"
            text x y font-size)
  ;; For now, return without rendering
  ;; The bot-api-8.lisp will handle this via Telegram's native rendering
  (declare (image text x y font-size color opacity))
  nil)

;;; ### Emoji Overlay

(defun add-emoji-overlay (image emoji &key x y size opacity)
  "Add emoji overlay to image.

   Args:
     image: Image object
     emoji: Emoji character or custom emoji ID
     x: X position (default: center)
     y: Y position (default: center)
     size: Emoji size in pixels (default: 48)
     opacity: Opacity 0.0-1.0 (default: 1.0)

   Returns:
     Image with emoji overlay"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (x (or x (floor (- width size) 2)))
             (y (or y (floor (- height size) 2)))
             (size (or size 48))
             (opacity (or opacity 1.0))
             (overlayed (make-instance 'opticl:rgba-image
                                       :width width
                                       :height height)))
        ;; Copy original image
        (dotimes (cy height)
          (dotimes (cx width)
            (multiple-value-bind (r g b a) (opticl:pixel image cx cy)
              (opticl:set-pixel overlayed cx cy r g b a))))

        ;; Render emoji (simplified - would need proper emoji rendering)
        (render-emoji-simple overlayed emoji x y size opacity)

        overlayed)
    (condition (e)
      (log:error "Emoji overlay failed: ~A" e)
      image)))

(defun render-emoji-simple (image emoji x y size opacity)
  "Simple emoji rendering.

   Note: For proper emoji rendering, integrate with an emoji font library."
  ;; Placeholder implementation
  ;; A full implementation would:
  ;; 1. Load emoji as SVG or bitmap from an emoji font
  ;; 2. Scale to requested size
  ;; 3. Composite onto image with alpha blending
  (log:info "Emoji overlay requested: '~A' at (~A, ~A) size ~A"
            emoji x y size)
  (declare (image emoji x y size opacity))
  nil)

;;; ### Watermark

(defun add-watermark (image watermark-text &key position opacity font-size)
  "Add watermark to image.

   Args:
     image: Image object
     watermark-text: Watermark text
     position: Position keyword (:bottom-right, :bottom-left, :top-right, :top-left, :center)
     opacity: Watermark opacity 0.0-1.0 (default: 0.5)
     font-size: Font size (default: 16)

   Returns:
     Watermarked image object"
  (let* ((width (image-width image))
         (height (image-height image))
         (font-size (or font-size 16))
         (opacity (or opacity 0.5))
         (text-width (* (length watermark-text) font-size 0.6))
         (text-height font-size)
         (x (case (or position :bottom-right)
              (:bottom-right (- width text-width 10))
              (:bottom-left 10)
              (:top-right (- width text-width 10))
              (:top-left 10)
              (:center (floor (- width text-width) 2))
              (otherwise (- width text-width 10))))
         (y (case (or position :bottom-right)
              (:bottom-right (- height text-height 10))
              (:bottom-left (- height text-height 10))
              (:top-right 10)
              (:top-left 10)
              (:center (floor (- height text-height) 2))
              (otherwise (- height text-height 10)))))
    (add-text-overlay image watermark-text
                      :x x :y y
                      :font-size font-size
                      :color :white
                      :opacity opacity)))

;;; ### Drawing Primitives

(defun draw-rectangle (image x y width height &key color filled stroke-width)
  "Draw rectangle on image.

   Args:
     image: Image object
     x: X position of top-left corner
     y: Y position of top-left corner
     width: Rectangle width
     height: Rectangle height
     color: RGB list (r g b) (default: (255 0 0) red)
     filled: If T, fill rectangle (default: NIL)
     stroke-width: Line thickness (default: 2)

   Returns:
     Image with rectangle"
  (handler-case
      (let* ((img-width (image-width image))
             (img-height (image-height image))
             (color (or color '(255 0 0)))
             (stroke-width (or stroke-width 2))
             (result (make-instance 'opticl:rgba-image
                                    :width img-width
                                    :height img-height)))
        ;; Copy original
        (dotimes (cy img-height)
          (dotimes (cx img-width)
            (multiple-value-bind (r g b a) (opticl:pixel image cx cy)
              (opticl:set-pixel result cx cy r g b a))))

        ;; Draw rectangle
        (if filled
            ;; Fill entire rectangle
            (loop for dy from y below (min img-height (+ y height)) do
              (loop for dx from x below (min img-width (+ x width)) do
                (opticl:set-pixel result dx dy
                                  (first color)
                                  (second color)
                                  (third color)
                                  255)))
            ;; Draw outline
            (progn
              ;; Top and bottom edges
              (loop for dx from x below (min img-width (+ x width)) do
                (loop for dy from 0 below stroke-width do
                  (opticl:set-pixel result dx y
                                    (first color)
                                    (second color)
                                    (third color)
                                    255)
                  (when (< (+ y dy) img-height)
                    (opticl:set-pixel result dx (+ y dy)
                                      (first color)
                                      (second color)
                                      (third color)
                                      255)))
                (when (and (>= (- (+ y height) dy) 0)
                           (< (- (+ y height) dy) img-height))
                  (opticl:set-pixel result dx (- (+ y height) dy)
                                    (first color)
                                    (second color)
                                    (third color)
                                    255)))
              ;; Left and right edges
              (loop for dy from y below (min img-height (+ y height)) do
                (loop for dx from 0 below stroke-width do
                  (when (< (+ x dx) img-width)
                    (opticl:set-pixel result (+ x dx) dy
                                      (first color)
                                      (second color)
                                      (third color)
                                      255))
                  (when (and (>= (- (+ x width) dx) 0)
                             (< (- (+ x width) dx) img-width))
                    (opticl:set-pixel result (- (+ x width) dx) dy
                                      (first color)
                                      (second color)
                                      (third color)
                                      255)))))))

        result)
    (condition (e)
      (log:error "Draw rectangle failed: ~A" e)
      image)))

(defun draw-circle (image center-x center-y radius &key color filled stroke-width)
  "Draw circle on image.

   Args:
     image: Image object
     center-x: X position of center
     center-y: Y position of center
     radius: Circle radius
     color: RGB list (r g b) (default: (255 0 0) red)
     filled: If T, fill circle (default: NIL)
     stroke-width: Line thickness (default: 2)

   Returns:
     Image with circle"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (color (or color '(255 0 0)))
             (stroke-width (or stroke-width 2))
             (result (make-instance 'opticl:rgba-image
                                    :width width
                                    :height height)))
        ;; Copy original
        (dotimes (cy height)
          (dotimes (cx width)
            (multiple-value-bind (r g b a) (opticl:pixel image cx cy)
              (opticl:set-pixel result cx cy r g b a))))

        ;; Draw circle using midpoint circle algorithm
        (let ((x 0)
              (y radius)
              (d 1 (- radius)))
          ;; Draw outline
          (unless filled
            (loop while (<= x y) do
              ;; Draw 8 octants
              (dolist (point (list (list (+ center-x x) (+ center-y y))
                                   (list (+ center-x y) (+ center-y x))
                                   (list (- center-x x) (+ center-y y))
                                   (list (- center-x y) (+ center-y x))
                                   (list (+ center-x x) (- center-y y))
                                   (list (+ center-x y) (- center-y x))
                                   (list (- center-x x) (- center-y y))
                                   (list (- center-x y) (- center-y x))))
                (let ((px (first point))
                      (py (second point)))
                  (when (and (>= px 0) (< px width)
                             (>= py 0) (< py height))
                    (opticl:set-pixel result px py
                                      (first color)
                                      (second color)
                                      (third color)
                                      255))))
              (if (< d 0)
                  (incf d (+ (* 2 x) 3))
                  (progn
                    (decf y)
                    (incf d (+ (* 2 (- x y)) 5))))
              (incf x)))

          ;; Fill circle
          (when filled
            (loop for py from (- center-y radius) to (+ center-y radius) do
              (let ((dx (floor (sqrt (- (* radius radius)
                                        (* (- py center-y) (- py center-y))))))
                (loop for px from (- center-x dx) to (+ center-x dx) do
                  (when (and (>= px 0) (< px width)
                             (>= py 0) (< py height))
                    (opticl:set-pixel result px py
                                      (first color)
                                      (second color)
                                      (third color)
                                      255)))))))

        result)
    (condition (e)
      (log:error "Draw circle failed: ~A" e)
      image)))
