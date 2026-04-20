;;; image-filters.lisp --- Image filters using Opticl
;;;
;;; Provides:
;;; - Basic filters: blur, sharpen, grayscale, sepia
;;; - Adjustment filters: brightness, contrast, saturation
;;; - Artistic filters: vignette, noise, pixelate
;;; - Instagram-style filters: Clarendon, Ginger, Moon, Nashville, etc.

(in-package #:cl-telegram/image-processing)

;;; ### Basic Filters

(defun apply-grayscale (image)
  "Convert image to grayscale.

   Args:
     image: Image object

   Returns:
     Grayscale image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (gray (make-instance 'opticl:rgba-image
                                  :width width
                                  :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              ;; Luminosity method: weighted average for human perception
              (let ((gray (floor (+ (* 0.299 r) (* 0.587 g) (* 0.114 b)))))
                (opticl:set-pixel gray x y gray gray gray a)))))
        gray)
    (condition (e)
      (log:error "Grayscale filter failed: ~A" e)
      image)))

(defun apply-sepia (image &key (intensity 1.0))
  "Apply sepia tone effect.

   Args:
     image: Image object
     intensity: Effect intensity (0.0-1.0, default: 1.0)

   Returns:
     Sepia-toned image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (sepia-img (make-instance 'opticl:rgba-image
                                       :width width
                                       :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              ;; Sepia transformation matrix
              (let* ((tr (floor (+ (* r 0.393) (* g 0.769) (* b 0.189))))
                     (tg (floor (+ (* r 0.349) (* g 0.686) (* b 0.168))))
                     (tb (floor (+ (* r 0.272) (* g 0.534) (* b 0.131))))
                     ;; Blend with original based on intensity
                     (r (min 255 (floor (+ (* tr intensity) (* r (- 1.0 intensity))))))
                     (g (min 255 (floor (+ (* tg intensity) (* g (- 1.0 intensity))))))
                     (b (min 255 (floor (+ (* tb intensity) (* b (- 1.0 intensity)))))))
                (opticl:set-pixel sepia-img x y r g b a)))))
        sepia-img)
    (condition (e)
      (log:error "Sepia filter failed: ~A" e)
      image)))

(defun apply-brightness (image adjustment)
  "Adjust image brightness.

   Args:
     image: Image object
     adjustment: Brightness adjustment (-255 to 255, positive = brighter)

   Returns:
     Brightness-adjusted image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (adjusted (make-instance 'opticl:rgba-image
                                      :width width
                                      :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              (let ((r (min 255 (max 0 (+ r adjustment))))
                    (g (min 255 (max 0 (+ g adjustment))))
                    (b (min 255 (max 0 (+ b adjustment)))))
                (opticl:set-pixel adjusted x y r g b a)))))
        adjusted)
    (condition (e)
      (log:error "Brightness adjustment failed: ~A" e)
      image)))

(defun apply-contrast (image adjustment)
  "Adjust image contrast.

   Args:
     image: Image object
     adjustment: Contrast adjustment (-128 to 128, positive = more contrast)

   Returns:
     Contrast-adjusted image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (adjusted (make-instance 'opticl:rgba-image
                                      :width width
                                      :height height))
             ;; Contrast formula: factor = (259 * (contrast + 255)) / (255 * (259 - contrast))
             (factor (/ (* 259.0 (+ adjustment 255.0))
                        (* 255.0 (- 259.0 adjustment)))))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              (let ((r (min 255 (max 0 (floor (+ (* factor (- r 128)) 128)))))
                    (g (min 255 (max 0 (floor (+ (* factor (- g 128)) 128)))))
                    (b (min 255 (max 0 (floor (+ (* factor (- b 128)) 128))))))
                (opticl:set-pixel adjusted x y r g b a)))))
        adjusted)
    (condition (e)
      (log:error "Contrast adjustment failed: ~A" e)
      image)))

(defun apply-saturation (image adjustment)
  "Adjust image saturation.

   Args:
     image: Image object
     adjustment: Saturation adjustment (-100 to 100, positive = more saturated)

   Returns:
     Saturation-adjusted image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (adjusted (make-instance 'opticl:rgba-image
                                      :width width
                                      :height height))
             (factor (/ (+ 100.0 adjustment) 100.0)))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              ;; Convert to luminance
              (let* ((gray (floor (+ (* 0.299 r) (* 0.587 g) (* 0.114 b))))
                     ;; Blend between gray and original based on factor
                     (r (min 255 (max 0 (floor (+ (* factor (- r gray)) gray)))))
                     (g (min 255 (max 0 (floor (+ (* factor (- g gray)) gray)))))
                     (b (min 255 (max 0 (floor (+ (* factor (- b gray)) gray))))))
                (opticl:set-pixel adjusted x y r g b a)))))
        adjusted)
    (condition (e)
      (log:error "Saturation adjustment failed: ~A" e)
      image)))

;;; ### Blur Filter

(defun apply-blur (image &key (radius 2))
  "Apply Gaussian blur effect.

   Args:
     image: Image object
     radius: Blur radius (default: 2)

   Returns:
     Blurred image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (blurred (make-instance 'opticl:rgba-image
                                     :width width
                                     :height height)))
        ;; Simple box blur for performance
        (dotimes (y height)
          (dotimes (x width)
            (let ((sum-r 0) (sum-g 0) (sum-b 0) (sum-a 0) (count 0))
              ;; Sample neighborhood
              (loop for dy from (- radius) to radius do
                (loop for dx from (- radius) to radius do
                  (let ((nx (+ x dx))
                        (ny (+ y dy)))
                    (when (and (>= nx 0) (< nx width)
                               (>= ny 0) (< ny height))
                      (multiple-value-bind (r g b a) (opticl:pixel image nx ny)
                        (incf sum-r r)
                        (incf sum-g g)
                        (incf sum-b b)
                        (incf sum-a a)
                        (incf count))))))
              (let ((avg-r (floor sum-r count))
                    (avg-g (floor sum-g count))
                    (avg-b (floor sum-b count))
                    (avg-a (floor sum-a count)))
                (opticl:set-pixel blurred x y avg-r avg-g avg-b avg-a)))))
        blurred)
    (condition (e)
      (log:error "Blur filter failed: ~A" e)
      image)))

;;; ### Sharpen Filter

(defun apply-sharpen (image &key (amount 1.5))
  "Apply sharpening effect.

   Args:
     image: Image object
     amount: Sharpening amount (default: 1.5)

   Returns:
     Sharpened image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (sharpened (make-instance 'opticl:rgba-image
                                       :width width
                                       :height height)))
        ;; Simple Laplacian sharpening
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (cr cg cb ca) (opticl:pixel image x y)
              (let ((r (float cr)) (g (float cg)) (b (float cb)))
                ;; Sample neighbors for edge detection
                (when (and (> x 0) (< x (1- width))
                           (> y 0) (< y (1- height)))
                  (multiple-value-bind (tl t tr)
                      (let ((sum-r 0) (sum-g 0) (sum-b 0))
                        (loop for dy from -1 to 1 do
                          (loop for dx from -1 to 1 do
                            (unless (and (= dx 0) (= dy 0))
                              (multiple-value-bind (r g b)
                                  (opticl:pixel image (+ x dx) (+ y dy))
                                (incf sum-r r)
                                (incf sum-g g)
                                (incf sum-b b)))))
                        (values (floor sum-r 8) (floor sum-g 8) (floor sum-b 8))))
                    ;; Subtract blurred version from original
                    (setf r (min 255 (max 0 (floor (+ r (* amount (- r tl))))))
                          g (min 255 (max 0 (floor (+ g (* amount (- g tg))))))
                          b (min 255 (max 0 (floor (+ b (* amount (- b tb)))))))))
                (opticl:set-pixel sharpened x y
                                  (min 255 (max 0 (floor r)))
                                  (min 255 (max 0 (floor g)))
                                  (min 255 (max 0 (floor b)))
                                  ca)))))
        sharpened)
    (condition (e)
      (log:error "Sharpen filter failed: ~A" e)
      image)))

;;; ### Vignette Filter

(defun apply-vignette (image &key (darkness 0.5) (radius 0.7))
  "Apply vignette effect (darkened edges).

   Args:
     image: Image object
     darkness: Vignette darkness (0.0-1.0, default: 0.5)
     radius: Vignette radius (0.0-1.0, default: 0.7)

   Returns:
     Image with vignette effect"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (center-x (/ width 2.0))
             (center-y (/ height 2.0))
             (max-radius (min center-x center-y))
             (vignetted (make-instance 'opticl:rgba-image
                                       :width width
                                       :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              (let* ((dx (/ (- x center-x) max-radius))
                     (dy (/ (- y center-y) max-radius))
                     (dist (sqrt (+ (* dx dx) (* dy dy))))
                     ;; Calculate vignette factor (1.0 at center, decreases toward edges)
                     (factor (if (<= dist radius)
                                 1.0
                                 (- 1.0 (* (- dist radius)
                                           (/ darkness (- 1.0 radius))))))
                     (factor (max 0.0 (min 1.0 factor))))
                (let ((r (floor (* r factor)))
                      (g (floor (* g factor)))
                      (b (floor (* b factor))))
                  (opticl:set-pixel vignetted x y r g b a))))))
        vignetted)
    (condition (e)
      (log:error "Vignette filter failed: ~A" e)
      image)))

;;; ### Noise Filter

(defun apply-noise (image &key (amount 10))
  "Apply noise/grain effect.

   Args:
     image: Image object
     amount: Noise amount (0-100, default: 10)

   Returns:
     Image with noise effect"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (noisy (make-instance 'opticl:rgba-image
                                   :width width
                                   :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              (let ((noise (lambda () (- (random (* 2 amount)) amount))))
                (let ((r (min 255 (max 0 (+ r (funcall noise)))))
                      (g (min 255 (max 0 (+ g (funcall noise)))))
                      (b (min 255 (max 0 (+ b (funcall noise))))))
                  (opticl:set-pixel noisy x y r g b a))))))
        noisy)
    (condition (e)
      (log:error "Noise filter failed: ~A" e)
      image)))

;;; ### Pixelate Filter

(defun apply-pixelate (image &key (pixel-size 8))
  "Apply pixelate/mosaic effect.

   Args:
     image: Image object
     pixel-size: Size of each pixel block (default: 8)

   Returns:
     Pixelated image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (pixelated (make-instance 'opticl:rgba-image
                                       :width width
                                       :height height)))
        ;; Process in blocks
        (loop for y from 0 below height by pixel-size do
          (loop for x from 0 below width by pixel-size do
            ;; Calculate average color for this block
            (let ((sum-r 0) (sum-g 0) (sum-b 0) (sum-a 0) (count 0))
              (loop for dy from 0 below pixel-size do
                (loop for dx from 0 below pixel-size do
                  (let ((nx (+ x dx))
                        (ny (+ y dy)))
                    (when (and (< nx width) (< ny height))
                      (multiple-value-bind (r g b a) (opticl:pixel image nx ny)
                        (incf sum-r r)
                        (incf sum-g g)
                        (incf sum-b b)
                        (incf sum-a a)
                        (incf count))))))
              ;; Fill block with average color
              (when (> count 0)
                (let ((avg-r (floor sum-r count))
                      (avg-g (floor sum-g count))
                      (avg-b (floor sum-b count))
                      (avg-a (floor sum-a count)))
                  (loop for dy from 0 below pixel-size do
                    (loop for dx from 0 below pixel-size do
                      (let ((nx (+ x dx))
                            (ny (+ y dy)))
                        (when (and (< nx width) (< ny height))
                          (opticl:set-pixel pixelated nx ny avg-r avg-g avg-b avg-a))))))))))
        pixelated)
    (condition (e)
      (log:error "Pixelate filter failed: ~A" e)
      image)))

;;; ### Warmth Filter

(defun apply-warmth (image &key (warmth 20))
  "Apply warmth/coolness adjustment.

   Args:
     image: Image object
     warmth: Warmth adjustment (-50 to 50, positive = warmer, negative = cooler)

   Returns:
     Warmth-adjusted image object"
  (handler-case
      (let* ((width (image-width image))
             (height (image-height image))
             (warmed (make-instance 'opticl:rgba-image
                                    :width width
                                    :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (multiple-value-bind (r g b a) (opticl:pixel image x y)
              (let ((r (min 255 (max 0 (+ r warmth))))
                    (b (min 255 (max 0 (- b (floor warmth 2))))))
                (opticl:set-pixel warmed x y r g b a)))))
        warmed)
    (condition (e)
      (log:error "Warmth filter failed: ~A" e)
      image)))
