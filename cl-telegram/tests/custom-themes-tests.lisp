;;; custom-themes-tests.lisp --- Tests for custom themes functionality

(in-package #:cl-telegram/tests)

(defsuite* custom-themes-suite ())

;;; ============================================================================
;;; Test Utilities
;;; ============================================================================

(defmacro with-theme-manager ((&optional) &body body)
  "Execute body with theme manager initialized."
  `(progn
     (setf cl-telegram/api::*theme-manager* nil)
     (cl-telegram/api:init-theme-manager)
     (unwind-protect
          (progn ,@body)
       (setf cl-telegram/api::*theme-manager* nil))))

;;; ============================================================================
;;; Theme Class Tests
;;; ============================================================================

(deftest test-theme-creation ()
  "Test creating a theme instance."
  (let ((theme (make-instance 'cl-telegram/api:theme
                              :name "test-theme"
                              :base-theme :default)))
    (is (typep theme 'cl-telegram/api:theme))
    (is (string= (cl-telegram/api:theme-name theme) "test-theme"))
    (is (eq (cl-telegram/api:theme-base-theme theme) :default))
    (is (typep (cl-telegram/api:theme-colors theme) 'hash-table))
    (is (cl-telegram/api:theme-is-custom theme))))

(deftest test-theme-print-object ()
  "Test theme print representation."
  (let ((theme (make-instance 'cl-telegram/api:theme
                              :name "custom"
                              :base-theme :dark)))
    (let ((output (with-output-to-string (s)
                    (print-object theme s))))
      (is (search "custom" output :test #'char-equal))
      (is (search "dark" output :test #'char-equal)))))

;;; ============================================================================
;;; Chat Background Class Tests
;;; ============================================================================

(deftest test-chat-background-creation ()
  "Test creating a chat-background instance."
  (let ((bg (make-instance 'cl-telegram/api:chat-background
                           :chat-id 123456
                           :type :color
                           :value "#FF5500"
                           :blur 10
                           :darken 0.3
                           :opacity 0.8)))
    (is (typep bg 'cl-telegram/api:chat-background))
    (is (= (cl-telegram/api:bg-chat-id bg) 123456))
    (is (eq (cl-telegram/api:bg-type bg) :color))
    (is (string= (cl-telegram/api:bg-value bg) "#FF5500"))
    (is (= (cl-telegram/api:bg-blur bg) 10))
    (is (= (cl-telegram/api:bg-darken bg) 0.3))
    (is (= (cl-telegram/api:bg-opacity bg) 0.8))))

;;; ============================================================================
;;; Theme Manager Tests
;;; ============================================================================

(deftest test-theme-manager-initialization ()
  "Test theme manager initialization."
  (with-theme-manager ()
    (let ((manager (cl-telegram/api:get-theme-manager)))
      (is (typep manager 'cl-telegram/api:theme-manager))
      (is (typep (cl-telegram/api:manager-themes manager) 'hash-table))
      (is (typep (cl-telegram/api:manager-chat-backgrounds manager) 'hash-table))
      (is (eq (cl-telegram/api:manager-active-theme manager) :default))
      (is (eq (cl-telegram/api:manager-font-size manager) :normal))
      (is (eq (cl-telegram/api:manager-app-icon manager) :default)))))

(deftest test-theme-manager-auto-init ()
  "Test theme manager auto-initialization."
  (setf cl-telegram/api::*theme-manager* nil)
  (let ((manager (cl-telegram/api:get-theme-manager)))
    (is (typep manager 'cl-telegram/api:theme-manager))
    (is (not (null cl-telegram/api::*theme-manager*)))))

(deftest test-create-default-themes ()
  "Test default themes creation."
  (with-theme-manager ()
    (let ((manager (cl-telegram/api:get-theme-manager)))
      (is (>= (hash-table-count (cl-telegram/api:manager-themes manager)) 6))
      (is (not (null (cl-telegram/api:get-theme "default"))))
      (is (not (null (cl-telegram/api:get-theme "dark"))))
      (is (not (null (cl-telegram/api:get-theme "midnight"))))
      (is (not (null (cl-telegram/api:get-theme "ocean"))))
      (is (not (null (cl-telegram/api:get-theme "forest"))))
      (is (not (null (cl-telegram/api:get-theme "sunset")))))))

;;; ============================================================================
;;; Theme Management Tests
;;; ============================================================================

(deftest test-create-theme ()
  "Test creating a new theme."
  (with-theme-manager ()
    (multiple-value-bind (theme err) (cl-telegram/api:create-theme "my-theme" :base-theme :dark)
      (is (not (null theme)))
      (is (null err))
      (is (string= (cl-telegram/api:theme-name theme) "my-theme"))
      (is (eq (cl-telegram/api:theme-base-theme theme) :dark)))))

(deftest test-create-theme-duplicate ()
  "Test creating duplicate theme."
  (with-theme-manager ()
    (cl-telegram/api:create-theme "duplicate" :base-theme :default)
    (multiple-value-bind (theme err) (cl-telegram/api:create-theme "duplicate" :base-theme :dark)
      (is (null theme))
      (is (eq err :theme-exists)))))

(deftest test-delete-theme ()
  "Test deleting a theme."
  (with-theme-manager ()
    (cl-telegram/api:create-theme "to-delete" :base-theme :default)
    (multiple-value-bind (success err) (cl-telegram/api:delete-theme "to-delete")
      (is (not (null success)))
      (is (null err)))
    (is (null (cl-telegram/api:get-theme "to-delete")))))

(deftest test-delete-theme-default ()
  "Test deleting default theme (should fail)."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:delete-theme "default")
      (is (null success))
      (is (eq err :cannot-delete)))))

(deftest test-delete-theme-not-found ()
  "Test deleting non-existent theme."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:delete-theme "nonexistent")
      (is (null success))
      (is (eq err :not-found)))))

(deftest test-get-theme ()
  "Test getting a theme."
  (with-theme-manager ()
    (let ((theme (cl-telegram/api:get-theme "default")))
      (is (not (null theme)))
      (is (string= (cl-telegram/api:theme-name theme) "default")))))

(deftest test-list-themes ()
  "Test listing all themes."
  (with-theme-manager ()
    (let ((names (cl-telegram/api:list-themes)))
      (is (listp names))
      (is (>= (length names) 6))
      (is (member "default" names :test #'string=))
      (is (member "dark" names :test #'string=)))))

;;; ============================================================================
;;; Theme Colors Tests
;;; ============================================================================

(deftest test-set-theme-color ()
  "Test setting theme color."
  (with-theme-manager ()
    (let ((result (cl-telegram/api:set-theme-color "default" :primary "#FF0000")))
      (is (not (null result)))
      (let ((colors (cl-telegram/api:get-theme-colors "default")))
        (is (not (null colors)))
        (let ((primary (assoc :primary colors)))
          (is (not (null primary)))
          (is (string= (cdr primary) "#FF0000")))))))

(deftest test-set-theme-color-invalid-format ()
  "Test setting theme color with invalid format."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:set-theme-color "default" :primary "invalid")
      (is (null success))
      (is (eq err :invalid-format)))
    (multiple-value-bind (success err) (cl-telegram/api:set-theme-color "default" :primary "#GGGGGG")
      (is (null success))
      (is (eq err :invalid-format)))))

(deftest test-set-theme-color-not-found ()
  "Test setting color for non-existent theme."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:set-theme-color "nonexistent" :primary "#FF0000")
      (is (null success))
      (is (eq err :not-found)))))

(deftest test-get-theme-colors ()
  "Test getting all theme colors."
  (with-theme-manager ()
    (let ((colors (cl-telegram/api:get-theme-colors "dark")))
      (is (listp colors))
      (is (not (null colors))))))

(deftest test-get-theme-colors-not-found ()
  "Test getting colors for non-existent theme."
  (with-theme-manager ()
    (let ((colors (cl-telegram/api:get-theme-colors "nonexistent")))
      (is (null colors)))))

(deftest test-apply-theme ()
  "Test applying a theme."
  (with-theme-manager ()
    (let ((result (cl-telegram/api:apply-theme "dark")))
      (is (not (null result)))
      (is (eq (cl-telegram/api:manager-active-theme (cl-telegram/api:get-theme-manager)) 'dark)))))

(deftest test-apply-theme-not-found ()
  "Test applying non-existent theme."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:apply-theme "nonexistent")
      (is (null success))
      (is (eq err :not-found)))))

;;; ============================================================================
;;; Chat Background Tests
;;; ============================================================================

(deftest test-set-chat-background ()
  "Test setting chat background."
  (with-theme-manager ()
    (let ((result (cl-telegram/api:set-chat-background 123456 "#FF5500" :blur 10 :darken 0.2 :opacity 0.9)))
      (is (not (null result)))
      (let ((bg (cl-telegram/api:get-chat-background 123456)))
        (is (not (null bg)))
        (is (= (cl-telegram/api:bg-chat-id bg) 123456))
        (is (string= (cl-telegram/api:bg-value bg) "#FF5500"))
        (is (= (cl-telegram/api:bg-blur bg) 10))
        (is (= (cl-telegram/api:bg-darken bg) 0.2))
        (is (= (cl-telegram/api:bg-opacity bg) 0.9))))))

(deftest test-set-chat-background-image ()
  "Test setting chat background with image."
  (with-theme-manager ()
    (let ((result (cl-telegram/api:set-chat-background 123456 "path/to/image.jpg")))
      (is (not (null result)))
      (let ((bg (cl-telegram/api:get-chat-background 123456)))
        (is (eq (cl-telegram/api:bg-type bg) :image))))))

(deftest test-get-chat-background ()
  "Test getting chat background."
  (with-theme-manager ()
    (is (null (cl-telegram/api:get-chat-background 999999)))))

(deftest test-reset-chat-background ()
  "Test resetting chat background."
  (with-theme-manager ()
    (cl-telegram/api:set-chat-background 123456 "#FF5500")
    (let ((result (cl-telegram/api:reset-chat-background 123456)))
      (is (not (null result)))
      (is (null (cl-telegram/api:get-chat-background 123456))))))

;;; ============================================================================
;;; Font and Icon Settings Tests
;;; ============================================================================

(deftest test-set-font-size ()
  "Test setting font size."
  (with-theme-manager ()
    (is (cl-telegram/api:set-font-size :large))
    (is (eq (cl-telegram/api:manager-font-size (cl-telegram/api:get-theme-manager)) :large))
    (is (cl-telegram/api:set-font-size :xl))
    (is (eq (cl-telegram/api:manager-font-size (cl-telegram/api:get-theme-manager)) :xl))))

(deftest test-set-font-size-invalid ()
  "Test setting invalid font size."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:set-font-size :huge)
      (is (null success))
      (is (eq err :invalid-size)))))

(deftest test-set-app-icon ()
  "Test setting app icon."
  (with-theme-manager ()
    (is (cl-telegram/api:set-app-icon "custom-icon"))
    (is (string= (cl-telegram/api:manager-app-icon (cl-telegram/api:get-theme-manager)) "custom-icon"))))

;;; ============================================================================
;;; Theme Import/Export Tests
;;; ============================================================================

(deftest test-export-theme ()
  "Test exporting theme to file."
  (with-theme-manager ()
    (let* ((test-path (merge-pathnames "test-theme-export.json" (uiop:temporary-directory)))
           (result (cl-telegram/api:export-theme "default" test-path)))
      (is (not (null result)))
      (is (probe-file test-path))
      ;; Clean up
      (when (probe-file test-path)
        (delete-file test-path)))))

(deftest test-export-theme-not-found ()
  "Test exporting non-existent theme."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:export-theme "nonexistent" "/tmp/test.json")
      (is (null success))
      (is (eq err :not-found)))))

(deftest test-import-theme ()
  "Test importing theme from file."
  (with-theme-manager ()
    ;; First export a theme
    (let* ((test-path (merge-pathnames "test-theme-import.json" (uiop:temporary-directory)))
           (export-result (cl-telegram/api:export-theme "dark" test-path)))
      (is (not (null export-result)))
      ;; Delete the theme
      (cl-telegram/api:delete-theme "dark")
      ;; Import it back
      (multiple-value-bind (theme err) (cl-telegram/api:import-theme test-path)
        (is (not (null theme)))
        (is (null err)))
      ;; Clean up
      (when (probe-file test-path)
        (delete-file test-path)))))

(deftest test-import-theme-not-found ()
  "Test importing non-existent file."
  (with-theme-manager ()
    (multiple-value-bind (success err) (cl-telegram/api:import-theme "/nonexistent/path.json")
      (is (null success))
      (is (eq err :not-found)))))

;;; ============================================================================
;;; Theme Presets Tests
;;; ============================================================================

(deftest test-get-theme-presets ()
  "Test getting theme presets."
  (let ((presets (cl-telegram/api:get-theme-presets)))
    (is (listp presets))
    (is (>= (length presets) 6))
    (is (member "default" presets :test #'string=))
    (is (member "dark" presets :test #'string=))
    (is (member "midnight" presets :test #'string=))))

(deftest test-apply-theme-preset ()
  "Test applying theme preset."
  (with-theme-manager ()
    (is (cl-telegram/api:apply-theme-preset "ocean"))
    (is (eq (cl-telegram/api:manager-active-theme (cl-telegram/api:get-theme-manager)) 'ocean))))

;;; ============================================================================
;;; Cache Management Tests
;;; ============================================================================

(deftest test-clear-theme-cache ()
  "Test clearing theme cache."
  (with-theme-manager ()
    (let ((manager (cl-telegram/api:get-theme-manager)))
      ;; Add background to cache
      (setf (gethash 123456 (cl-telegram/api:manager-chat-backgrounds manager)) "test")
      (is (not (null (gethash 123456 (cl-telegram/api:manager-chat-backgrounds manager)))))
      ;; Clear cache
      (is (cl-telegram/api:clear-theme-cache))
      (is (null (gethash 123456 (cl-telegram/api:manager-chat-backgrounds manager)))))))

(deftest test-get-theme-stats ()
  "Test getting theme statistics."
  (with-theme-manager ()
    (let ((stats (cl-telegram/api:get-theme-stats)))
      (is (listp stats))
      (is (getf stats :themes-count))
      (is (getf stats :active-theme))
      (is (getf stats :font-size))
      (is (getf stats :app-icon)))))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(deftest test-full-theme-lifecycle ()
  "Test full theme lifecycle: create, modify, apply, export, delete."
  (with-theme-manager ()
    ;; Create
    (multiple-value-bind (theme err) (cl-telegram/api:create-theme "lifecycle-test" :base-theme :default)
      (is (not (null theme)))
      (is (null err)))

    ;; Modify
    (is (cl-telegram/api:set-theme-color "lifecycle-test" :background "#112233"))
    (is (cl-telegram/api:set-theme-color "lifecycle-test" :text "#AABBCC"))

    ;; Apply
    (is (cl-telegram/api:apply-theme "lifecycle-test"))
    (is (eq (cl-telegram/api:manager-active-theme (cl-telegram/api:get-theme-manager)) 'lifecycle-test))

    ;; Export
    (let* ((test-path (merge-pathnames "lifecycle-test.json" (uiop:temporary-directory)))
           (result (cl-telegram/api:export-theme "lifecycle-test" test-path)))
      (is (not (null result)))
      (when (probe-file test-path)
        (delete-file test-path)))

    ;; Delete
    (multiple-value-bind (success err) (cl-telegram/api:delete-theme "lifecycle-test")
      (is (not (null success)))
      (is (null err)))

    ;; Verify deleted
    (is (null (cl-telegram/api:get-theme "lifecycle-test")))))

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-all-custom-themes-tests ()
  "Run all custom themes tests."
  (run! 'custom-themes-suite))
