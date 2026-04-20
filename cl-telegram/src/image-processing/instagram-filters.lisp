;;; instagram-filters.lisp --- Instagram-style filter presets
;;;
;;; Provides 28+ Instagram-like filters using combinations of basic filters

(in-package #:cl-telegram/image-processing)

;;; ### Instagram Filter Presets

;; Each filter is defined as a function that applies a specific combination
;; of adjustments to create the signature look

(defun filter-clarendon (image &key (intensity 1.0))
  "Apply Clarendon filter - bright, vibrant, slight cool tone.

   Instagram's default-enhancing filter."
  (handler-case
      (let ((step1 (apply-brightness image 15))
            (step2 (apply-contrast step1 10))
            (step3 (apply-saturation step1 (* 15 intensity))))
        (apply-warmth step3 :warmth -5))
    (condition (e)
      (log:error "Clarendon filter failed: ~A" e)
      image)))

(defun filter-ginger (image &key (intensity 1.0))
  "Apply Ginger filter - warm, golden hour glow."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 30 intensity)))
            (step2 (apply-saturation step1 (* 10 intensity)))
            (step3 (apply-contrast step2 5)))
        step3)
    (condition (e)
      (log:error "Ginger filter failed: ~A" e)
      image)))

(defun filter-moon (image &key (intensity 1.0))
  "Apply Moon filter - black and white with high contrast."
  (handler-case
      (let ((gray (apply-grayscale image)))
        (apply-contrast gray (* 25 intensity)))
    (condition (e)
      (log:error "Moon filter failed: ~A" e)
      image)))

(defun filter-nashville (image &key (intensity 1.0))
  "Apply Nashville filter - vintage pink/purple tones."
  (handler-case
      (let ((step1 (apply-sepia image :intensity (* 0.3 intensity)))
            (step2 (apply-warmth step1 :warmth (* 15 intensity)))
            (step3 (apply-vignette step2 :darkness (* 0.3 intensity))))
        step3)
    (condition (e)
      (log:error "Nashville filter failed: ~A" e)
      image)))

(defun filter-perpetua (image &key (intensity 1.0))
  "Apply Perpetua filter - soft, ethereal pastels."
  (handler-case
      (let ((step1 (apply-brightness image 10))
            (step2 (apply-saturation step1 -10))
            (step3 (apply-contrast step2 -5)))
        (apply-warmth step3 :warmth 5))
    (condition (e)
      (log:error "Perpetua filter failed: ~A" e)
      image)))

(defun filter-aden (image &key (intensity 1.0))
  "Apply Aden filter - soft peachy tones with vintage feel."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 20 intensity)))
            (step2 (apply-saturation step1 -15))
            (step3 (apply-brightness step2 5)))
        (apply-vignette step3 :darkness (* 0.2 intensity)))
    (condition (e)
      (log:error "Aden filter failed: ~A" e)
      image)))

(defun filter-reyes (image &key (intensity 1.0))
  "Apply Reyes filter - muted vintage with dusty rose."
  (handler-case
      (let ((step1 (apply-sepia image :intensity (* 0.4 intensity)))
            (step2 (apply-saturation step1 -20))
            (step3 (apply-contrast step2 -10)))
        (apply-vignette step3 :darkness (* 0.3 intensity)))
    (condition (e)
      (log:error "Reyes filter failed: ~A" e)
      image)))

(defun filter-juno (image &key (intensity 1.0))
  "Apply Juno filter - vibrant reds and yellows."
  (handler-case
      (let ((step1 (apply-saturation image (* 20 intensity)))
            (step2 (apply-warmth step1 :warmth (* 15 intensity)))
            (step3 (apply-contrast step2 5)))
        step3)
    (condition (e)
      (log:error "Juno filter failed: ~A" e)
      image)))

(defun filter-slumber (image &key (intensity 1.0))
  "Apply Slumber filter - faded, dreamy vintage."
  (handler-case
      (let ((step1 (apply-brightness image 15))
            (step2 (apply-saturation step1 -25))
            (step3 (apply-warmth step1 :warmth (* 10 intensity))))
        (apply-vignette step3 :darkness (* 0.25 intensity)))
    (condition (e)
      (log:error "Slumber filter failed: ~A" e)
      image)))

(defun filter-crema (image &key (intensity 1.0))
  "Apply Crema filter - creamy, muted tones."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 10 intensity)))
            (step2 (apply-saturation step1 -10))
            (step3 (apply-contrast step2 -5)))
        step3)
    (condition (e)
      (log:error "Crema filter failed: ~A" e)
      image)))

(defun filter-ludwig (image &key (intensity 1.0))
  "Apply Ludwig filter - desaturated with slight fade."
  (handler-case
      (let ((step1 (apply-saturation image -15))
            (step2 (apply-brightness step1 5))
            (step3 (apply-contrast step2 -10)))
        step3)
    (condition (e)
      (log:error "Ludwig filter failed: ~A" e)
      image)))

(defun filter-inkwell (image &key (intensity 1.0))
  "Apply Inkwell filter - pure black and white."
  (declare (intensity))
  (apply-grayscale image))

(defun filter-haze (image &key (intensity 1.0))
  "Apply Haze filter - soft glow, faded highlights."
  (handler-case
      (let ((step1 (apply-brightness image (* 15 intensity)))
            (step2 (apply-saturation step1 -10))
            (step3 (apply-blur image :radius 1)))
        (apply-contrast step3 -5))
    (condition (e)
      (log:error "Haze filter failed: ~A" e)
      image)))

(defun filter-drama (image &key (intensity 1.0))
  "Apply Drama filter - high contrast, saturated."
  (handler-case
      (let ((step1 (apply-contrast image (* 25 intensity)))
            (step2 (apply-saturation step1 (* 15 intensity)))
            (step3 (apply-vignette step2 :darkness (* 0.4 intensity))))
        step3)
    (condition (e)
      (log:error "Drama filter failed: ~A" e)
      image)))

(defun filter-x-pro-ii (image &key (intensity 1.0))
  "Apply X-Pro II filter - vibrant with golden tones."
  (handler-case
      (let ((step1 (apply-contrast image 15))
            (step2 (apply-saturation step1 20))
            (step3 (apply-warmth step2 :warmth 15)))
        (apply-vignette step3 :darkness 0.2))
    (condition (e)
      (log:error "X-Pro II filter failed: ~A" e)
      image)))

(defun filter-sutro (image &key (intensity 1.0))
  "Apply Sutro filter - dark, moody, desaturated."
  (handler-case
      (let ((step1 (apply-saturation image -20))
            (step2 (apply-contrast image 15))
            (step3 (apply-brightness step2 -5)))
        (apply-vignette step3 :darkness (* 0.5 intensity)))
    (condition (e)
      (log:error "Sutro filter failed: ~A" e)
      image)))

(defun filter-toaster (image &key (intensity 1.0))
  "Apply Toaster filter - vintage with orange tint."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 25 intensity)))
            (step2 (apply-saturation step1 10))
            (step3 (apply-vignette step2 :darkness (* 0.3 intensity))))
        (apply-sepia step3 :intensity (* 0.2 intensity)))
    (condition (e)
      (log:error "Toaster filter failed: ~A" e)
      image)))

(defun filter-valencia (image &key (intensity 1.0))
  "Apply Valencia filter - warm, faded vintage."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 20 intensity)))
            (step2 (apply-saturation step1 -10))
            (step3 (apply-sepia step2 :intensity (* 0.15 intensity))))
        (apply-vignette step3 :darkness (* 0.2 intensity)))
    (condition (e)
      (log:error "Valencia filter failed: ~A" e)
      image)))

(defun filter-walden (image &key (intensity 1.0))
  "Apply Walden filter - bright with yellow tint."
  (handler-case
      (let ((step1 (apply-brightness image 15))
            (step2 (apply-warmth step1 :warmth (* 25 intensity)))
            (step3 (apply-saturation step2 -5)))
        step3)
    (condition (e)
      (log:error "Walden filter failed: ~A" e)
      image)))

(defun filter-willow (image &key (intensity 1.0))
  "Apply Willow filter - cool, muted black and white."
  (handler-case
      (let ((gray (apply-grayscale image)))
        (let ((step1 (apply-contrast gray -10))
              (step2 (apply-warmth step1 :warmth -5))
              (step3 (apply-vignette step2 :darkness (* 0.4 intensity))))
          step3))
    (condition (e)
      (log:error "Willow filter failed: ~A" e)
      image)))

(defun filter-rise (image &key (intensity 1.0))
  "Apply Rise filter - soft glow, warm pastels."
  (handler-case
      (let ((step1 (apply-brightness image 10))
            (step2 (apply-warmth step1 :warmth (* 15 intensity)))
            (step3 (apply-saturation step2 5)))
        (apply-vignette step3 :darkness (* 0.15 intensity)))
    (condition (e)
      (log:error "Rise filter failed: ~A" e)
      image)))

(defun filter-brannan (image &key (intensity 1.0))
  "Apply Brannan filter - high contrast, metallic."
  (handler-case
      (let ((step1 (apply-contrast image (* 30 intensity)))
            (step2 (apply-saturation step1 10))
            (step3 (apply-sharpen step2 :amount 1.2)))
        step3)
    (condition (e)
      (log:error "Brannan filter failed: ~A" e)
      image)))

(defun filter-earlybird (image &key (intensity 1.0))
  "Apply Earlybird filter - warm with sepia tint."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 20 intensity)))
            (step2 (apply-sepia step1 :intensity (* 0.25 intensity)))
            (step3 (apply-saturation step2 10)))
        (apply-vignette step3 :darkness (* 0.3 intensity)))
    (condition (e)
      (log:error "Earlybird filter failed: ~A" e)
      image)))

(defun filter-helena (image &key (intensity 1.0))
  "Apply Helena filter - tropical, teal shadows."
  (handler-case
      (let ((step1 (apply-saturation image 15))
            (step2 (apply-warmth step1 :warmth 10))
            (step3 (apply-contrast step2 10)))
        step3)
    (condition (e)
      (log:error "Helena filter failed: ~A" e)
      image)))

(defun filter-gingham (image &key (intensity 1.0))
  "Apply Gingham filter - faded vintage with yellow cast."
  (handler-case
      (let ((step1 (apply-sepia image :intensity (* 0.2 intensity)))
            (step2 (apply-brightness step1 10))
            (step3 (apply-saturation step2 -15)))
        (apply-warmth step3 :warmth (* 10 intensity)))
    (condition (e)
      (log:error "Gingham filter failed: ~A" e)
      image)))

(defun filter-1977 (image &key (intensity 1.0))
  "Apply 1977 filter - reddish vintage."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 30 intensity)))
            (step2 (apply-saturation step1 -10))
            (step3 (apply-sepia step2 :intensity (* 0.15 intensity))))
        step3)
    (condition (e)
      (log:error "1977 filter failed: ~A" e)
      image)))

(defun filter-sierra (image &key (intensity 1.0))
  "Apply Sierra filter - faded, muted tones."
  (handler-case
      (let ((step1 (apply-saturation image -15))
            (step2 (apply-contrast step1 -10))
            (step3 (apply-brightness step2 5)))
        (apply-vignette step3 :darkness (* 0.25 intensity)))
    (condition (e)
      (log:error "Sierra filter failed: ~A" e)
      image)))

(defun filter-kelvin (image &key (intensity 1.0))
  "Apply Kelvin filter - warm, saturated orange."
  (handler-case
      (let ((step1 (apply-warmth image :warmth (* 35 intensity)))
            (step2 (apply-saturation step1 (* 20 intensity)))
            (step3 (apply-contrast step2 5)))
        step3)
    (condition (e)
      (log:error "Kelvin filter failed: ~A" e)
      image)))

(defun filter-stinson (image &key (intensity 1.0))
  "Apply Stinson filter - bright, slightly faded."
  (handler-case
      (let ((step1 (apply-brightness image 10))
            (step2 (apply-warmth step1 :warmth 5))
            (step3 (apply-saturation step2 -5)))
        step3)
    (condition (e)
      (log:error "Stinson filter failed: ~A" e)
      image)))

(defun filter-maven (image &key (intensity 1.0))
  "Apply Maven filter - earthy, sepia tones."
  (handler-case
      (let ((step1 (apply-sepia image :intensity (* 0.3 intensity)))
            (step2 (apply-warmth step1 :warmth (* 15 intensity)))
            (step3 (apply-contrast step2 -5)))
        (apply-vignette step3 :darkness (* 0.2 intensity)))
    (condition (e)
      (log:error "Maven filter failed: ~A" e)
      image)))

(defun filter-ginza (image &key (intensity 1.0))
  "Apply Ginza filter - bright, cool tones."
  (handler-case
      (let ((step1 (apply-brightness image 12))
            (step2 (apply-warmth step1 :warmth -5))
            (step3 (apply-saturation step2 -5)))
        step3)
    (condition (e)
      (log:error "Ginza filter failed: ~A" e)
      image)))

(defun filter-amaro (image &key (intensity 1.0))
  "Apply Amaro filter - light, airy pastels."
  (handler-case
      (let ((step1 (apply-brightness image 15))
            (step2 (apply-saturation step1 -10))
            (step3 (apply-contrast step2 -5)))
        step3)
    (condition (e)
      (log:error "Amaro filter failed: ~A" e)
      image)))

(defun filter-chesterton (image &key (intensity 1.0))
  "Apply Chessington filter - vintage, dramatic."
  (handler-case
      (let ((step1 (apply-sepia image :intensity (* 0.4 intensity)))
            (step2 (apply-contrast step1 (* 20 intensity)))
            (step3 (apply-vignette step2 :darkness (* 0.4 intensity))))
        step3)
    (condition (e)
      (log:error "Chessington filter failed: ~A" e)
      image)))

;;; ### Filter Utility

(defun apply-filter-by-name (image filter-name &key (intensity 1.0))
  "Apply filter by name string.

   Args:
     image: Image object
     filter-name: Filter name string (e.g., \"clarendon\")
     intensity: Filter intensity 0.0-1.0

   Returns:
     Filtered image object"
  (let ((filter-fn (case (intern (string-upcase filter-name) "KEYWORD")
                     (:clarendon #'filter-clarendon)
                     (:ginger #'filter-ginger)
                     (:moon #'filter-moon)
                     (:nashville #'filter-nashville)
                     (:perpetua #'filter-perpetua)
                     (:aden #'filter-aden)
                     (:reyes #'filter-reyes)
                     (:juno #'filter-juno)
                     (:slumber #'filter-slumber)
                     (:crema #'filter-crema)
                     (:ludwig #'filter-ludwig)
                     (:inkwell #'filter-inkwell)
                     (:haze #'filter-haze)
                     (:drama #'filter-drama)
                     (:x-pro-ii #'filter-x-pro-ii)
                     (:sutro #'filter-sutro)
                     (:toaster #'filter-toaster)
                     (:valencia #'filter-valencia)
                     (:walden #'filter-walden)
                     (:willow #'filter-willow)
                     (:rise #'filter-rise)
                     (:brannan #'filter-brannan)
                     (:earlybird #'filter-earlybird)
                     (:helena #'filter-helena)
                     (:gingham #'filter-gingham)
                     (:1977 #'filter-1977)
                     (:sierra #'filter-sierra)
                     (:kelvin #'filter-kelvin)
                     (:stinson #'filter-stinson)
                     (:maven #'filter-maven)
                     (:ginza #'filter-ginza)
                     (:amaro #'filter-amaro)
                     (:chesterton #'filter-chesterton)
                     (otherwise nil))))
    (if filter-fn
        (funcall filter-fn image :intensity intensity)
        (progn
          (log:warn "Unknown filter: ~A" filter-name)
          image))))

(defun get-available-filters ()
  "Get list of available filter names.

   Returns:
     List of filter name strings"
  '("clarendon" "ginger" "moon" "nashville" "perpetua"
    "aden" "reyes" "juno" "slumber" "crema"
    "ludwig" "inkwell" "haze" "drama" "x-pro-ii"
    "sutro" "toaster" "valencia" "walden" "willow"
    "rise" "brannan" "earlybird" "helena" "gingham"
    "1977" "sierra" "kelvin" "stinson" "maven"
    "ginza" "amaro" "chesterton"))
