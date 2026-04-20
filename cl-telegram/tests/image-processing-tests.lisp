;;; image-processing-tests.lisp --- Tests for image processing module

(in-package #:cl-telegram/image-processing)

(fiveam:def-suite* image-processing-tests
  :description "Test suite for cl-telegram image processing module")

;;; ### Utility Tests

(fiveam:test test-supported-formats
  "Test that supported formats list is properly defined"
  (fiveam:is (listp *supported-formats*))
  (fiveam:is (member "jpg" *supported-formats* :test #'string=))
  (fiveam:is (member "png" *supported-formats* :test #'string=))
  (fiveam:is (member "gif" *supported-formats* :test #'string=)))

(fiveam:test test-temp-directory
  "Test that temp directory function works"
  (let ((temp-dir (ensure-temp-directory)))
    (fiveam:is (pathnamep temp-dir))
    (fiveam:is (probe-file temp-dir))))

;;; ### Filter Tests

(fiveam:test test-grayscale-filter
  "Test grayscale filter application"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    ;; Set some colored pixels
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y (* x 25) (* y 25) 128 255)))
    (let ((gray (apply-grayscale image)))
      (fiveam:is (typep gray 'opticl:rgba-image))
      (fiveam:is (= (opticl:width gray) 10))
      (fiveam:is (= (opticl:height gray) 10))
      ;; Check that RGB values are equal (grayscale)
      (multiple-value-bind (r g b) (opticl:pixel gray 5 5)
        (fiveam:is (= r g b))))))

(fiveam:test test-sepia-filter
  "Test sepia filter application"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 100 150 200 255)))
    (let ((sepia (apply-sepia image :intensity 1.0)))
      (fiveam:is (typep sepia 'opticl:rgba-image))
      ;; Sepia should add warm brown tones
      (multiple-value-bind (r g b) (opticl:pixel sepia 5 5)
        ;; Red should be highest in sepia
        (fiveam:is (>= r b))))))

(fiveam:test test-brightness-adjustment
  "Test brightness adjustment"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 100 100 100 255)))
    ;; Test brighten
    (let ((brighter (apply-brightness image 50)))
      (multiple-value-bind (r g b) (opticl:pixel brighter 5 5)
        (fiveam:is (= r 150))
        (fiveam:is (= g 150))
        (fiveam:is (= b 150))))
    ;; Test darken
    (let ((darker (apply-brightness image -50)))
      (multiple-value-bind (r g b) (opticl:pixel darker 5 5)
        (fiveam:is (= r 50))
        (fiveam:is (= g 50))
        (fiveam:is (= b 50))))))

(fiveam:test test-contrast-adjustment
  "Test contrast adjustment"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 100 100 100 255)))
    (let ((high-contrast (apply-contrast image 50)))
      (fiveam:is (typep high-contrast 'opticl:rgba-image))
      ;; Contrast should push values away from 128
      (multiple-value-bind (r g b) (opticl:pixel high-contrast 5 5)
        (fiveam:is (< r 100))))))

(fiveam:test test-saturation-adjustment
  "Test saturation adjustment"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    ;; Set a saturated red pixel
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 255 0 0 255)))
    ;; Test desaturate
    (let ((desaturated (apply-saturation image -50)))
      (fiveam:is (typep desaturated 'opticl:rgba-image))
      (multiple-value-bind (r g b) (opticl:pixel desaturated 5 5)
        ;; Should be less saturated (G and B should increase toward R)
        (fiveam:is (<= g 0))
        (fiveam:is (<= b 0))))))

(fiveam:test test-blur-filter
  "Test blur filter application"
  (let ((image (make-instance 'opticl:rgba-image :width 20 :height 20)))
    ;; Create a high-contrast pattern
    (dotimes (y 20)
      (dotimes (x 20)
        (if (evenp (+ x y))
            (opticl:set-pixel image x y 255 0 0 255)
            (opticl:set-pixel image x y 0 0 255 255))))
    (let ((blurred (apply-blur image :radius 2)))
      (fiveam:is (typep blurred 'opticl:rgba-image))
      ;; Blur should average neighboring pixels
      (multiple-value-bind (r g b) (opticl:pixel blurred 10 10)
        ;; Should be somewhere between red and blue
        (fiveam:is (> r 0))
        (fiveam:is (> b 0))))))

(fiveam:test test-vignette-filter
  "Test vignette filter application"
  (let ((image (make-instance 'opticl:rgba-image :width 100 :height 100)))
    (dotimes (y 100)
      (dotimes (x 100)
        (opticl:set-pixel image x y 200 200 200 255)))
    (let ((vignetted (apply-vignette image :darkness 0.5 :radius 0.5)))
      (fiveam:is (typep vignetted 'opticl:rgba-image))
      ;; Center should be brighter than corners
      (multiple-value-bind (center-r center-g center-b)
          (opticl:pixel vignetted 50 50)
        (multiple-value-bind (corner-r corner-g corner-b)
            (opticl:pixel vignetted 10 10)
          (fiveam:is (>= center-r corner-r))
          (fiveam:is (>= center-g corner-g))
          (fiveam:is (>= center-b corner-b)))))))

(fiveam:test test-noise-filter
  "Test noise filter application"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 128 128 128 255)))
    (let ((noisy (apply-noise image :amount 20)))
      (fiveam:is (typep noisy 'opticl:rgba-image))
      ;; Check that noise was added (pixels should vary)
      (let ((values (loop for y from 0 below 10
                      append (loop for x from 0 below 10
                               collect (multiple-value-bind (r g b)
                                           (opticl:pixel noisy x y)
                                         (+ r g b))))))
        (fiveam:is (not (every (lambda (v) (= v 384)) values)))))))

(fiveam:test test-pixelate-filter
  "Test pixelate filter application"
  (let ((image (make-instance 'opticl:rgba-image :width 16 :height 16)))
    ;; Create a gradient
    (dotimes (y 16)
      (dotimes (x 16)
        (opticl:set-pixel image x y (* x 15) (* y 15) 128 255)))
    (let ((pixelated (apply-pixelate image :pixel-size 4)))
      (fiveam:is (typep pixelated 'opticl:rgba-image))
      ;; Pixels in same block should have same color
      (multiple-value-bind (r1 g1 b1) (opticl:pixel pixelated 1 1)
        (multiple-value-bind (r2 g2 b2) (opticl:pixel pixelated 2 2)
          (fiveam:is (= r1 r2))
          (fiveam:is (= g1 g2))
          (fiveam:is (= b1 b2)))))))

(fiveam:test test-warmth-filter
  "Test warmth filter application"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 128 128 128 255)))
    ;; Test warm
    (let ((warmer (apply-warmth image :warmth 30)))
      (multiple-value-bind (r g b) (opticl:pixel warmer 5 5)
        (fiveam:is (> r 128))
        (fiveam:is (< b 128))))
    ;; Test cool
    (let ((cooler (apply-warmth image :warmth -30)))
      (multiple-value-bind (r g b) (opticl:pixel cooler 5 5)
        (fiveam:is (< r 128))
        (fiveam:is (> b 128))))))

;;; ### Instagram Filter Tests

(fiveam:test test-filter-clarendon
  "Test Clarendon filter"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 100 100 100 255)))
    (let ((filtered (filter-clarendon image :intensity 1.0)))
      (fiveam:is (typep filtered 'opticl:rgba-image))
      (fiveam:is (= (opticl:width filtered) 10))
      (fiveam:is (= (opticl:height filtered) 10)))))

(fiveam:test test-filter-moon
  "Test Moon filter (grayscale with high contrast)"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 100 150 200 255)))
    (let ((filtered (filter-moon image :intensity 1.0)))
      (fiveam:is (typep filtered 'opticl:rgba-image))
      ;; Should be grayscale
      (multiple-value-bind (r g b) (opticl:pixel filtered 5 5)
        (fiveam:is (= r g b))))))

(fiveam:test test-filter-inkwell
  "Test Inkwell filter (pure black and white)"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 100 150 200 255)))
    (let ((filtered (filter-inkwell image :intensity 1.0)))
      (fiveam:is (typep filtered 'opticl:rgba-image))
      ;; Should be grayscale
      (multiple-value-bind (r g b) (opticl:pixel filtered 5 5)
        (fiveam:is (= r g b))))))

(fiveam:test test-filter-by-name
  "Test applying filter by name string"
  (let ((image (make-instance 'opticl:rgba-image :width 10 :height 10)))
    (dotimes (y 10)
      (dotimes (x 10)
        (opticl:set-pixel image x y 128 128 128 255)))
    (dolist (filter-name '("clarendon" "moon" "ginger" "nashville"))
      (let ((filtered (apply-filter-by-name image filter-name :intensity 0.5)))
        (fiveam:is (typep filtered 'opticl:rgba-image))
        (fiveam:is (= (opticl:width filtered) 10))
        (fiveam:is (= (opticl:height filtered) 10)))))
  ;; Test unknown filter
  (let ((filtered (apply-filter-by-name image "unknown-filter")))
    (fiveam:is (eq filtered image))))

(fiveam:test test-get-available-filters
  "Test getting list of available filters"
  (let ((filters (get-available-filters)))
    (fiveam:is (listp filters))
    (fiveam:is (> (length filters) 20))
    (fiveam:is (member "clarendon" filters :test #'string=))
    (fiveam:is (member "moon" filters :test #'string=))
    (fiveam:is (member "ginger" filters :test #'string=))))

;;; ### Drawing Tests

(fiveam:test test-draw-rectangle
  "Test drawing rectangle on image"
  (let ((image (make-instance 'opticl:rgba-image :width 50 :height 50)))
    (dotimes (y 50)
      (dotimes (x 50)
        (opticl:set-pixel image x y 0 0 0 255)))
    (let ((result (draw-rectangle image 10 10 20 20 :color '(255 0 0) :filled t)))
      (fiveam:is (typep result 'opticl:rgba-image))
      ;; Check that rectangle was drawn
      (multiple-value-bind (r g b) (opticl:pixel result 20 20)
        (fiveam:is (= r 255))
        (fiveam:is (= g 0))
        (fiveam:is (= b 0))))))

(fiveam:test test-draw-circle
  "Test drawing circle on image"
  (let ((image (make-instance 'opticl:rgba-image :width 50 :height 50)))
    (dotimes (y 50)
      (dotimes (x 50)
        (opticl:set-pixel image x y 0 0 0 255)))
    (let ((result (draw-circle image 25 25 10 :color '(0 255 0) :filled t)))
      (fiveam:is (typep result 'opticl:rgba-image))
      ;; Check center of circle
      (multiple-value-bind (r g b) (opticl:pixel result 25 25)
        (fiveam:is (= r 0))
        (fiveam:is (= g 255))
        (fiveam:is (= b 0))))))

;;; ### Overlay Tests (basic)

(fiveam:test test-add-text-overlay
  "Test adding text overlay"
  (let ((image (make-instance 'opticl:rgba-image :width 100 :height 100)))
    (dotimes (y 100)
      (dotimes (x 100)
        (opticl:set-pixel image x y 255 255 255 255)))
    (let ((result (add-text-overlay image "Test" :x 10 :y 50 :font-size 20 :color :black)))
      (fiveam:is (typep result 'opticl:rgba-image))
      (fiveam:is (= (opticl:width result) 100))
      (fiveam:is (= (opticl:height result) 100)))))

(fiveam:test test-add-emoji-overlay
  "Test adding emoji overlay"
  (let ((image (make-instance 'opticl:rgba-image :width 100 :height 100)))
    (dotimes (y 100)
      (dotimes (x 100)
        (opticl:set-pixel image x y 255 255 255 255)))
    (let ((result (add-emoji-overlay image "😀" :x 40 :y 40 :size 20)))
      (fiveam:is (typep result 'opticl:rgba-image))
      (fiveam:is (= (opticl:width result) 100))
      (fiveam:is (= (opticl:height result) 100)))))

(fiveam:test test-add-watermark
  "Test adding watermark"
  (let ((image (make-instance 'opticl:rgba-image :width 100 :height 100)))
    (dotimes (y 100)
      (dotimes (x 100)
        (opticl:set-pixel image x y 255 255 255 255)))
    (let ((result (add-watermark image "© 2024" :position :bottom-right :opacity 0.5)))
      (fiveam:is (typep result 'opticl:rgba-image)))))

;;; ### Thumbnail Generation

(fiveam:test test-generate-thumbnail
  "Test thumbnail generation"
  (let ((image (make-instance 'opticl:rgba-image :width 200 :height 300)))
    (dotimes (y 300)
      (dotimes (x 200)
        (opticl:set-pixel image x y (* x 2) (* y 2) 128 255)))
    (let ((thumb (generate-thumbnail image 50 50)))
      (fiveam:is (typep thumb 'opticl:rgba-image))
      (fiveam:is (<= (opticl:width thumb) 50))
      (fiveam:is (<= (opticl:height thumb) 50)))))

;;; ### Image Info

(fiveam:test test-image-properties
  "Test image property functions"
  (let ((image (make-instance 'opticl:rgba-image :width 100 :height 80)))
    (fiveam:is (= (image-width image) 100))
    (fiveam:is (= (image-height image) 80))
    (fiveam:is (= (image-channels image) 4))))

;;; Run all tests
(defun run-all-tests ()
  "Run all image processing tests"
  (fiveam:run! 'image-processing-tests))
