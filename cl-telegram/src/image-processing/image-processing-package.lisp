;;; image-processing-package.lisp --- Package definition for image processing

(defpackage #:cl-telegram/image-processing
  (:nicknames #:cl-tg/img)
  (:use #:cl)
  (:export
   ;; Core image operations
   #:load-image
   #:save-image
   #:image-width
   #:image-height
   #:image-channels

   ;; Crop and resize
   #:crop-image
   #:resize-image
   #:scale-image

   ;; Rotation
   #:rotate-image
   #:flip-image-horizontal
   #:flip-image-vertical

   ;; Filters
   #:apply-blur
   #:apply-sharpen
   #:apply-grayscale
   #:apply-sepia
   #:apply-brightness
   #:apply-contrast
   #:apply-saturation
   #:apply-vignette
   #:apply-noise
   #:apply-pixelate

   ;; Instagram-style filters
   #:filter-clarendon
   #:filter-ginger
   #:filter-moon
   #:filter-nashville
   #:filter-perpetua
   #:filter-aden
   #:filter-reyes
   #:filter-slumber
   #:filter-crema
   #:filter-ludwig
   #:filter-inkwell
   #:filter-haze
   #:filter-drama

   ;; Overlays
   #:add-text-overlay
   #:add-emoji-overlay
   #:add-watermark
   #:draw-rectangle
   #:draw-circle

   ;; Format conversion
   #:convert-image-format
   #:image-to-jpeg
   #:image-to-png

   ;; Utilities
   #:get-image-info
   #:image-exists-p
   #:validate-image-file
   #:generate-thumbnail
   #:ensure-temp-directory
   #:*temp-directory*
   #:*supported-formats*))
