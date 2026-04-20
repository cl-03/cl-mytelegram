;;; custom-themes.lisp --- Custom themes for cl-telegram UI
;;;
;;; Provides deep UI customization:
;;; - Create and manage color themes
;;; - Custom chat backgrounds
;;; - Font size adjustment
;;; - Background patterns and gradients (v0.33.0)
;;;
;;; Version: 0.33.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Theme Classes
;;; ============================================================================

(defclass theme ()
  ((name :initarg :name :reader theme-name)
   (base-theme :initform :default :initarg :base-theme :accessor theme-base-theme)
   (colors :initform (make-hash-table :test 'equal) :accessor theme-colors)
   (created-at :initform (get-universal-time) :accessor theme-created-at)
   (modified-at :initform (get-universal-time) :accessor theme-modified-at)
   (is-custom :initform t :reader theme-is-custom)))

(defmethod print-object ((theme theme) stream)
  (print-unreadable-object (theme stream :type t)
    (format stream "~A (based on ~A)" (theme-name theme) (theme-base-theme theme))))

(defclass chat-background ()
  ((chat-id :initarg :chat-id :accessor bg-chat-id)
   (type :initform :color :initarg :type :accessor bg-type)
   (value :initarg :value :accessor bg-value)
   (blur :initform 0 :initarg :blur :accessor bg-blur)
   (darken :initform 0 :initarg :darken :accessor bg-darken)
   (opacity :initform 1 :initarg :opacity :accessor bg-opacity)))

;;; ============================================================================
;;; Theme Manager
;;; ============================================================================

(defclass theme-manager ()
  ((themes :initform (make-hash-table :test 'equal) :accessor manager-themes)
   (active-theme :initform :default :accessor manager-active-theme)
   (chat-backgrounds :initform (make-hash-table :test 'equal) :accessor manager-chat-backgrounds)
   (font-size :initform :normal :accessor manager-font-size)
   (app-icon :initform :default :accessor manager-app-icon)))

(defvar *theme-manager* nil)

(defun make-theme-manager ()
  "Create a new theme manager instance."
  (make-instance 'theme-manager))

(defun init-theme-manager ()
  "Initialize theme manager subsystem."
  (unless *theme-manager*
    (setf *theme-manager* (make-theme-manager))
    (create-default-themes))
  t)

(defun get-theme-manager ()
  "Get the global theme manager."
  (unless *theme-manager* (init-theme-manager))
  *theme-manager*)

;;; ============================================================================
;;; Default Themes
;;; ============================================================================

(defun create-default-themes ()
  "Create default built-in themes."
  (let ((manager (get-theme-manager)))
    (dolist (theme-data '(("default" :default "#FFFFFF" "#000000" "#0088cc")
                          ("dark" :dark "#1a1a1a" "#FFFFFF" "#0088cc")
                          ("midnight" :dark "#0a0a1a" "#EEEEEE" "#4488ff")
                          ("ocean" :dark "#001a1a" "#CCFFFF" "#00aaaa")
                          ("forest" :dark "#0a1a0a" "#DDFFDD" "#44aa44")
                          ("sunset" :light "#2a1a1a" "#FFDDCC" "#ff8844")))
      (destructuring-bind (name base bg txt primary) theme-data
        (let ((theme (make-instance 'theme :name name :base-theme base)))
          (setf (gethash name (manager-themes manager)) theme)
          (set-theme-color manager name :background bg)
          (set-theme-color manager name :text txt)
          (set-theme-color manager name :primary primary))))
    (format t "Created ~D default themes~%" (hash-table-count (manager-themes manager)))))

;;; ============================================================================
;;; Theme Management
;;; ============================================================================

(defun create-theme (name &key (base-theme :default))
  "Create a new custom theme."
  (let ((manager (get-theme-manager)))
    (when (gethash name (manager-themes manager))
      (return-from create-theme (values nil :theme-exists "Theme already exists")))
    (let ((theme (make-instance 'theme :name name :base-theme base-theme)))
      (setf (gethash name (manager-themes manager)) theme)
      (format t "Created theme '~A'~%" name)
      (values theme nil))))

(defun delete-theme (name)
  "Delete a custom theme."
  (let ((manager (get-theme-manager)))
    (when (member name '("default" "dark" "midnight" "ocean" "forest" "sunset") :test #'string=)
      (return-from delete-theme (values nil :cannot-delete "Cannot delete default themes")))
    (unless (gethash name (manager-themes manager))
      (return-from delete-theme (values nil :not-found "Theme not found")))
    (remhash name (manager-themes manager))
    (format t "Deleted theme '~A'~%" name)
    (values t nil)))

(defun get-theme (name)
  "Get a theme by name."
  (let ((manager (get-theme-manager)))
    (gethash name (manager-themes manager))))

(defun list-themes ()
  "List all available themes."
  (let ((manager (get-theme-manager)) (names '()))
    (maphash (lambda (name theme) (declare (ignore theme)) (push name names))
             (manager-themes manager))
    names))

;;; ============================================================================
;;; Theme Colors
;;; ============================================================================

(defun set-theme-color (theme-name color-key rgb-value)
  "Set a color in the theme."
  (let* ((manager (get-theme-manager))
         (theme (gethash theme-name (manager-themes manager))))
    (unless theme
      (return-from set-theme-color (values nil :not-found "Theme not found")))
    (unless (cl-ppcre:scan "^#[0-9A-Fa-f]{6}$" rgb-value)
      (return-from set-theme-color (values nil :invalid-format "Invalid hex color")))
    (setf (gethash color-key (theme-colors theme)) rgb-value)
    (setf (theme-modified-at theme) (get-universal-time))
    (values t nil)))

(defun get-theme-colors (theme-name)
  "Get all colors from a theme."
  (let* ((manager (get-theme-manager))
         (theme (gethash theme-name (manager-themes manager))))
    (when theme
      (let ((colors '()))
        (maphash (lambda (key value) (push (list key value) colors))
                 (theme-colors theme))
        colors))))

(defun apply-theme (theme-name)
  "Apply a theme to the UI."
  (let ((manager (get-theme-manager)))
    (unless (gethash theme-name (manager-themes manager))
      (return-from apply-theme (values nil :not-found "Theme not found")))
    (setf (manager-active-theme manager) theme-name)
    (format t "Applied theme '~A'~%" theme-name)
    (values t nil)))

;;; ============================================================================
;;; Chat Background
;;; ============================================================================

(defun set-chat-background (chat-id background &key (blur 0) (darken 0) (opacity 1))
  "Set custom background for a chat."
  (let* ((manager (get-theme-manager))
         (bg (make-instance 'chat-background
                            :chat-id chat-id
                            :type (if (cl-ppcre:scan "^#" background) :color :image)
                            :value background
                            :blur blur
                            :darken darken
                            :opacity opacity)))
    (setf (gethash chat-id (manager-chat-backgrounds manager)) bg)
    (format t "Set background for chat ~A~%" chat-id)
    (values t nil)))

(defun get-chat-background (chat-id)
  "Get background for a chat."
  (let ((manager (get-theme-manager)))
    (gethash chat-id (manager-chat-backgrounds manager))))

(defun reset-chat-background (chat-id)
  "Reset chat background to default."
  (let ((manager (get-theme-manager)))
    (remhash chat-id (manager-chat-backgrounds manager))
    (format t "Reset background for chat ~A~%" chat-id)
    (values t nil)))

;;; ============================================================================
;;; Font and Icon Settings
;;; ============================================================================

(defun set-font-size (size-key)
  "Set global font size."
  (let ((manager (get-theme-manager)))
    (unless (member size-key '(:small :normal :large :xl))
      (return-from set-font-size (values nil :invalid-size "Invalid size")))
    (setf (manager-font-size manager) size-key)
    (format t "Set font size to ~A~%" size-key)
    (values t nil)))

(defun set-app-icon (icon-name)
  "Set custom app icon."
  (let ((manager (get-theme-manager)))
    (setf (manager-app-icon manager) icon-name)
    (format t "Set app icon to ~A~%" icon-name)
    (values t nil)))

;;; ============================================================================
;;; Theme Import/Export
;;; ============================================================================

(defun export-theme (theme-name output-path)
  "Export theme to file."
  (let* ((manager (get-theme-manager))
         (theme (gethash theme-name (manager-themes manager))))
    (unless theme
      (return-from export-theme (values nil :not-found "Theme not found")))
    (ensure-directories-exist output-path)
    (let ((data (list :name theme-name
                      :base-theme (theme-base-theme theme)
                      :colors (get-theme-colors theme-name))))
      (with-open-file (out output-path :direction :output :if-exists :supersede)
        (write-string (jonathan:to-json data :pretty t) out)))
    (format t "Exported theme to ~A~%" output-path)
    (values t nil)))

(defun import-theme (file-path)
  "Import theme from file."
  (unless (probe-file file-path)
    (return-from import-theme (values nil :not-found "File not found")))
  (let ((content (with-open-file (in file-path :direction :input)
                   (let ((data (make-string (file-length in))))
                     (read-sequence data in) data))))
    (let ((data (jonathan:json-read content)))
      (let* ((name (getf data :name))
             (base (getf data :base-theme))
             (colors (getf data :colors)))
        (multiple-value-bind (theme err) (create-theme name :base-theme base)
          (when err
            (return-from import-theme (values nil err)))
          (dolist (color-data colors)
            (set-theme-color name (car color-data) (cadr color-data)))
          (format t "Imported theme '~A'~%" name)
          (values theme nil))))))

;;; ============================================================================
;;; Theme Presets
;;; ============================================================================

(defun get-theme-presets ()
  "Get list of available theme presets."
  '("default" "dark" "midnight" "ocean" "forest" "sunset"))

(defun apply-theme-preset (preset-name)
  "Apply a theme preset."
  (apply-theme preset-name))

;;; ============================================================================
;;; Cache Management
;;; ============================================================================

(defun clear-theme-cache ()
  "Clear theme cache."
  (let ((manager (get-theme-manager)))
    (clrhash (manager-chat-backgrounds manager))
    (format t "Cleared theme cache~%")
    t))

(defun get-theme-stats ()
  "Get theme statistics."
  (let ((manager (get-theme-manager)))
    (list :themes-count (hash-table-count (manager-themes manager))
          :active-theme (manager-active-theme manager)
          :font-size (manager-font-size manager)
          :app-icon (manager-app-icon manager))))

;;; ============================================================================
;;; Section: Chat Backgrounds Enhanced (v0.33.0)
;;; ============================================================================

(defclass chat-background-pattern ()
  ((pattern-id :initarg :pattern-id :accessor bg-pattern-id)
   (name :initarg :name :accessor bg-pattern-name)
   (type :initarg :type :initform :solid :accessor bg-pattern-type)
   (colors :initarg :colors :initform nil :accessor bg-pattern-colors)
   (gradient-angle :initarg :gradient-angle :initform 45 :accessor bg-pattern-gradient-angle)
   (blurAmount :initarg :blur-amount :initform 0 :accessor bg-pattern-blur)
   (darkenAmount :initarg :darken-amount :initform 0 :accessor bg-pattern-darken)
   (opacity :initarg :opacity :initform 1 :accessor bg-pattern-opacity)))

(defvar *background-patterns* (make-hash-table :test 'equal)
  "Hash table storing background patterns")

(defvar *chat-backgrounds-enhanced* (make-hash-table :test 'equal)
  "Hash table storing enhanced chat backgrounds")

(defun create-background-pattern (name type &key (colors '("#000000" "#FFFFFF"))
                                       (gradient-angle 45)
                                       (blur 0)
                                       (darken 0)
                                       (opacity 1))
  "Create a custom background pattern.

   Args:
     name: Pattern name
     type: Pattern type (:solid :gradient :image :pattern)
     colors: List of colors for gradient
     gradient-angle: Gradient angle in degrees
     blur: Blur amount (0-100)
     darken: Darken amount (0-100)
     opacity: Opacity (0.0-1.0)

   Returns:
     Chat-background-pattern instance

   Example:
     (create-background-pattern \"Sunset Gradient\" :gradient
                                :colors '(\"#FF6B6B\" \"#FFE66D\")
                                :gradient-angle 45)"
  (let* ((pattern-id (format nil "bgp_~A_~A" name (get-universal-time)))
         (pattern (make-instance 'chat-background-pattern
                                 :pattern-id pattern-id
                                 :name name
                                 :type type
                                 :colors colors
                                 :gradient-angle gradient-angle
                                 :blur-amount blur
                                 :darken-amount darken
                                 :opacity opacity)))
    (setf (gethash pattern-id *background-patterns*) pattern)
    (log:info "Background pattern created: ~A" name)
    pattern))

(defun get-background-pattern (pattern-id)
  "Get a background pattern by ID.

   Args:
     pattern-id: Pattern identifier

   Returns:
     Chat-background-pattern instance or NIL

   Example:
     (get-background-pattern \"bgp_SunsetGradient_123\")"
  (gethash pattern-id *background-patterns*))

(defun list-background-patterns ()
  "List all background patterns.

   Returns:
     List of chat-background-pattern instances

   Example:
     (list-background-patterns)"
  (let ((patterns nil))
    (maphash (lambda (k v)
               (declare (ignore k))
               (push v patterns))
             *background-patterns*)
    patterns))

(defun delete-background-pattern (pattern-id)
  "Delete a background pattern.

   Args:
     pattern-id: Pattern identifier

   Returns:
     T on success, NIL on error

   Example:
     (delete-background-pattern \"bgp_123\")"
  (let ((pattern (gethash pattern-id *background-patterns*)))
    (when pattern
      (remhash pattern-id *background-patterns*)
      (log:info "Background pattern deleted: ~A" pattern-id)
      t)))

(defun set-chat-background (chat-id pattern-id &key (custom-settings nil))
  "Set custom background for a chat.

   Args:
     chat-id: Chat identifier
     pattern-id: Background pattern ID
     custom-settings: Optional custom settings override

   Returns:
     T on success, NIL on error

   Example:
     (set-chat-background 123 \"bgp_SunsetGradient_123\"
                          :custom-settings '(:opacity 0.8 :blur 10))"
  (let ((pattern (gethash pattern-id *background-patterns*)))
    (unless pattern
      (return-from set-chat-background (values nil "Pattern not found")))

    (let ((bg (make-instance 'chat-background
                             :chat-id chat-id
                             :type (bg-pattern-type pattern)
                             :value pattern-id
                             :blur (or (getf custom-settings :blur) (bg-pattern-blur pattern))
                             :darken (or (getf custom-settings :darken) (bg-pattern-darken pattern))
                             :opacity (or (getf custom-settings :opacity) (bg-pattern-opacity pattern)))))
      (setf (gethash chat-id *chat-backgrounds-enhanced*) bg)
      (log:info "Chat background set for chat ~A" chat-id)
      t)))

(defun get-chat-background (chat-id)
  "Get background for a specific chat.

   Args:
     chat-id: Chat identifier

   Returns:
     Chat-background instance or NIL

   Example:
     (get-chat-background 123)"
  (gethash chat-id *chat-backgrounds-enhanced*))

(defun remove-chat-background (chat-id)
  "Remove custom background from a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success, NIL on error

   Example:
     (remove-chat-background 123)"
  (let ((bg (gethash chat-id *chat-backgrounds-enhanced*)))
    (when bg
      (remhash chat-id *chat-backgrounds-enhanced*)
      (log:info "Chat background removed for chat ~A" chat-id)
      t)))

(defun get-all-chat-backgrounds ()
  "Get all chat backgrounds.

   Returns:
     List of chat-background instances

   Example:
     (get-all-chat-backgrounds)"
  (let ((backgrounds nil))
    (maphash (lambda (k v)
               (declare (ignore k))
               (push v backgrounds))
             *chat-backgrounds-enhanced*)
    backgrounds))

(defun create-gradient-background (name start-color end-color &key (angle 45))
  "Create a gradient background pattern.

   Args:
     name: Pattern name
     start-color: Start color (hex)
     end-color: End color (hex)
     angle: Gradient angle in degrees

   Returns:
     Chat-background-pattern instance

   Example:
     (create-gradient-background \"Ocean Gradient\" \"#0066CC\" \"#00CC66\" :angle 90)"
  (create-background-pattern name :gradient
                             :colors (list start-color end-color)
                             :gradient-angle angle))

(defun create-solid-background (name color)
  "Create a solid color background pattern.

   Args:
     name: Pattern name
     color: Background color (hex)

   Returns:
     Chat-background-pattern instance

   Example:
     (create-solid-background \"Dark Gray\" \"#1a1a1a\")"
  (create-background-pattern name :solid :colors (list color)))

(defun create-pattern-background (name colors &key (pattern-type :stripes))
  "Create a pattern background.

   Args:
     name: Pattern name
     colors: List of colors
     pattern-type: Pattern type (:stripes :dots :grid)

   Returns:
     Chat-background-pattern instance

   Example:
     (create-pattern-background \"Striped\" '(\"#FF6B6B\" \"#FFFFFF\")
                                :pattern-type :stripes)"
  (create-background-pattern name :pattern
                             :colors colors
                             :gradient-angle 0))

(defun preview-background (pattern-id &key (width 400) (height 300))
  "Generate a preview of background pattern.

   Args:
     pattern-id: Pattern identifier
     width: Preview width in pixels
     height: Preview height in pixels

   Returns:
     Image data or NIL

   Example:
     (preview-background \"bgp_123\" :width 400 :height 300)"
  (let ((pattern (gethash pattern-id *background-patterns*)))
    (unless pattern
      (return-from preview-background nil))

    ;; Return preview parameters (actual rendering depends on UI)
    (list :type (bg-pattern-type pattern)
          :colors (bg-pattern-colors pattern)
          :angle (bg-pattern-gradient-angle pattern)
          :width width
          :height height)))

(defun get-background-stats ()
  "Get background statistics.

   Returns:
     Plist with statistics

   Example:
     (get-background-stats)"
  (let ((pattern-count 0)
        (bg-count 0))
    (maphash (lambda (k v) (declare (ignore k v)) (incf pattern-count))
             *background-patterns*)
    (maphash (lambda (k v) (declare (ignore k v)) (incf bg-count))
             *chat-backgrounds-enhanced*)
    (list :pattern-count pattern-count
          :chat-backgrounds bg-count
          :most-used-pattern (if (> bg-count 0) "N/A" nil))))

;;; End of custom-themes.lisp
