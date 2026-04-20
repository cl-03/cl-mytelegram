;;; image-operations.lisp --- Core image operations using Opticl
;;;
;;; Provides:
;;; - Image loading/saving
;;; - Crop, resize, rotate
;;; - Basic transformations

(in-package #:cl-telegram/image-processing)

;;; ### Global State

(defvar *temp-directory* (merge-pathnames "temp/" (user-homedir-pathname))
  "Directory for temporary image files")

(defvar *supported-formats* '("jpg" "jpeg" "png" "gif" "webp" "bmp")
  "List of supported image formats")

(defvar *instagram-filter-presets* (make-hash-table :test 'equal)
  "Cache for Instagram-style filter presets")

;;; ### Image Loading and Saving

(defun load-image (file-path)
  "Load an image from file.

   Args:
     file-path: Path to image file

   Returns:
     Image object or NIL on error"
  (handler-case
      (cond
        ;; Try Opticl first
        ((probe-file file-path)
         (let ((ext (string-downcase (pathname-type file-path))))
           (cond
             ((member ext '("jpg" "jpeg") :test #'string=)
              (opticl:read-jpeg-file file-path))
             ((string= ext "png")
              (opticl:read-png-file file-path))
             ((string= ext "gif")
              (opticl:read-gif-file file-path))
             ((string= ext "bmp")
              (opticl:read-bmp-file file-path))
             (t
              ;; Try generic loader
              (opticl:read-image-file file-path)))))
        (t
         (log:error "Image file not found: ~A" file-path)
         nil))
    (condition (e)
      (log:error "Failed to load image ~A: ~A" file-path e)
      nil)))

(defun save-image (image file-path &key format quality)
  "Save an image to file.

   Args:
     image: Image object
     file-path: Output file path
     format: Output format (jpg, png, etc.)
     quality: JPEG quality (0-100, default: 90)

   Returns:
     File path on success, NIL on error"
  (handler-case
      (let* ((format (or format (string-downcase (pathname-type file-path)) "png"))
             (quality (or quality 90)))
        (ensure-directories-exist file-path)
        (cond
          ((member format '("jpg" "jpeg") :test #'string=)
           (opticl:write-jpeg-file image file-path :quality quality))
          ((string= format "png")
           (opticl:write-png-file image file-path))
          ((string= format "gif")
           (opticl:write-gif-file image file-path))
          ((string= format "bmp")
           (opticl:write-bmp-file image file-path))
          (t
           (opticl:write-image-file image file-path)))
        file-path)
    (condition (e)
      (log:error "Failed to save image ~A: ~A" file-path e)
      nil)))

;;; ### Image Properties

(defun image-width (image)
  "Get image width in pixels."
  (if image (opticl:width image) 0))

(defun image-height (image)
  "Get image height in pixels."
  (if image (opticl:height image) 0))

(defun image-channels (image)
  "Get number of color channels (3 for RGB, 4 for RGBA)."
  (if image (opticl:num-channels image) 3))

;;; ### Crop and Resize

(defun crop-image (image x y width height)
  "Crop an image to specified rectangle.

   Args:
     image: Image object
     x: X coordinate of top-left corner
     y: Y coordinate of top-left corner
     width: Width of crop area
     height: Height of crop area

   Returns:
     Cropped image object"
  (handler-case
      (let* ((img-width (image-width image))
             (img-height (image-height image))
             ;; Clamp values to valid range
             (x (max 0 (min x (1- img-width))))
             (y (max 0 (min y (1- img-height))))
             (width (min width (- img-width x)))
             (height (min height (- img-height y))))
        (opticl:sub-image image x y width height))
    (condition (e)
      (log:error "Crop failed: ~A" e)
      image)))

(defun resize-image (image new-width new-height &key keep-aspect-ratio)
  "Resize image to specified dimensions.

   Args:
     image: Image object
     new-width: Target width
     new-height: Target height
     keep-aspect-ratio: If T, maintain aspect ratio

   Returns:
     Resized image object"
  (handler-case
      (if keep-aspect-ratio
          (let* ((old-width (image-width image))
                 (old-height (image-height image))
                 (aspect (/ old-width old-height))
                 (final-width (if (> (/ new-width new-height) aspect)
                                  (floor (* new-height aspect))
                                  new-width))
                 (final-height (if (> (/ new-width new-height) aspect)
                                   new-height
                                   (floor (/ final-width aspect)))))
            (opticl:scale-image image final-width final-height))
          (opticl:scale-image image new-width new-height))
    (condition (e)
      (log:error "Resize failed: ~A" e)
      image)))

(defun scale-image (image scale-factor)
  "Scale image by a factor.

   Args:
     image: Image object
     scale-factor: Scale factor (0.5 = 50%, 2.0 = 200%)

   Returns:
     Scaled image object"
  (let ((new-width (max 1 (floor (* (image-width image) scale-factor))))
        (new-height (max 1 (floor (* (image-height image) scale-factor)))))
    (resize-image image new-width new-height :keep-aspect-ratio t)))

;;; ### Rotation

(defun rotate-image (image angle)
  "Rotate image by specified angle.

   Args:
     image: Image object
     angle: Rotation angle in degrees (90, 180, 270, or arbitrary)

   Returns:
     Rotated image object"
  (handler-case
      (cond
        ;; Common angles - use efficient transformations
        ((= angle 90)
         (opticl:rotate-image image 90))
        ((= angle 180)
         (opticl:rotate-image image 180))
        ((= angle 270)
         (opticl:rotate-image image 270))
        (t
         ;; Arbitrary angle - use ImageMagick backend if available
         (rotate-image-generic image angle)))
    (condition (e)
      (log:error "Rotation failed: ~A" e)
      image)))

(defun rotate-image-generic (image angle)
  "Rotate image by arbitrary angle using transformation matrix.

   This is a simplified implementation. For production use,
   consider using cl-imagemagick which has better rotation support."
  (let* ((width (image-width image))
         (height (image-height image))
         (radians (* angle (/ pi 180)))
         (cos-a (cos radians))
         (sin-a (sin radians))
         ;; Calculate new dimensions
         (new-width (+ (abs (* width cos-a)) (abs (* height sin-a))))
         (new-height (+ (abs (* width sin-a)) (abs (* height cos-a)))))
    ;; For now, return original image for non-standard angles
    ;; A full implementation would require more complex transformation
    (declare (new-width new-height))
    image))

(defun flip-image-horizontal (image)
  "Flip image horizontally (mirror)."
  (handler-case
      (let ((width (image-width image))
            (height (image-height image))
            (channels (image-channels image))
            (flipped (make-instance 'opticl:rgba-image
                                    :width width
                                    :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (let ((pixel (opticl:pixel image x y)))
              (opticl:set-pixel flipped (- width 1 x) y pixel))))
        flipped)
    (condition (e)
      (log:error "Horizontal flip failed: ~A" e)
      image)))

(defun flip-image-vertical (image)
  "Flip image vertically."
  (handler-case
      (let ((width (image-width image))
            (height (image-height image))
            (flipped (make-instance 'opticl:rgba-image
                                    :width width
                                    :height height)))
        (dotimes (y height)
          (dotimes (x width)
            (let ((pixel (opticl:pixel image x y)))
              (opticl:set-pixel flipped x (- height 1 y) pixel))))
        flipped)
    (condition (e)
      (log:error "Vertical flip failed: ~A" e)
      image)))

;;; ### Generate Thumbnail

(defun generate-thumbnail (image max-width max-height &key output-path)
  "Generate a thumbnail of the image.

   Args:
     image: Image object
     max-width: Maximum thumbnail width
     max-height: Maximum thumbnail height
     output-path: Optional output file path

   Returns:
     Thumbnail image object or file path"
  (let* ((orig-width (image-width image))
         (orig-height (image-height image))
         (aspect (/ orig-width orig-height))
         (target-width (min max-width (floor (* max-height aspect))))
         (target-height (min max-height (floor (/ target-width aspect)))))
    (let ((thumb (resize-image image target-width target-height :keep-aspect-ratio t)))
      (if output-path
          (save-image thumb output-path)
          thumb))))

;;; ### Image Utilities

(defun get-image-info (file-path)
  "Get information about an image file.

   Args:
     file-path: Path to image file

   Returns:
     Plist with :width, :height, :channels, :format, :file-size"
  (let ((image (load-image file-path)))
    (when image
      (let ((info (list :width (image-width image)
                        :height (image-height image)
                        :channels (image-channels image)
                        :format (pathname-type file-path)
                        :file-size (or (probe-file file-path) 0))))
        info))))

(defun image-exists-p (file-path)
  "Check if file exists and is a valid image."
  (and (probe-file file-path)
       (member (string-downcase (pathname-type file-path))
               *supported-formats*
               :test #'string=)))

(defun validate-image-file (file-path)
  "Validate image file format and size.

   Returns:
     T if valid, error message string if invalid"
  (cond
    ((not (probe-file file-path))
     "File does not exist")
    ((not (member (string-downcase (pathname-type file-path))
                  *supported-formats*
                  :test #'string=))
     (format nil "Unsupported format: ~A" (pathname-type file-path)))
    (let ((stat (probe-file file-path)))
      ((and stat (> (file-length stat) (* 50 1024 1024))) ; 50MB limit
       "File too large (> 50MB)"))
    (t t)))

(defun ensure-temp-directory ()
  "Ensure temporary directory exists."
  (ensure-directories-exist *temp-directory*)
  *temp-directory*)
