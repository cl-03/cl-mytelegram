;;; chat-backgrounds-tests.lisp --- Tests for Chat Backgrounds v0.33.0

(in-package #:cl-telegram/tests)

(def-suite* chat-backgrounds-tests
  :description "Tests for Chat Backgrounds v0.33.0")

;;; ============================================================================
;;; Section 1: Background Pattern Tests
;;; ============================================================================

(test test-create-background-pattern
  "Test creating a background pattern"
  (let ((pattern (cl-telegram/api:create-background-pattern "Test Pattern" :gradient
                                                            :colors '("#FF0000" "#00FF00")
                                                            :gradient-angle 45)))
    (is (not (null pattern)))
    (is (string= (cl-telegram/api:bg-pattern-name pattern) "Test Pattern"))
    (is (eq (cl-telegram/api:bg-pattern-type pattern) :gradient))))

(test test-create-gradient-background
  "Test creating a gradient background"
  (let ((pattern (cl-telegram/api:create-gradient-background "Ocean Gradient" "#0066CC" "#00CC66" :angle 90)))
    (is (not (null pattern)))
    (is (string= (cl-telegram/api:bg-pattern-name pattern) "Ocean Gradient"))
    (is (= (cl-telegram/api:bg-pattern-gradient-angle pattern) 90))))

(test test-create-solid-background
  "Test creating a solid background"
  (let ((pattern (cl-telegram/api:create-solid-background "Dark Gray" "#1a1a1a")))
    (is (not (null pattern)))
    (is (string= (cl-telegram/api:bg-pattern-name pattern) "Dark Gray"))
    (is (eq (cl-telegram/api:bg-pattern-type pattern) :solid))))

(test test-create-pattern-background
  "Test creating a pattern background"
  (let ((pattern (cl-telegram/api:create-pattern-background "Striped" '("#FF0000" "#FFFFFF")
                                                            :pattern-type :stripes)))
    (is (not (null pattern)))
    (is (string= (cl-telegram/api:bg-pattern-name pattern) "Striped"))
    (is (eq (cl-telegram/api:bg-pattern-type pattern) :pattern))))

(test test-get-background-pattern
  "Test getting a background pattern"
  (let ((pattern (cl-telegram/api:create-background-pattern "Test" :solid)))
    (let ((pattern-id (cl-telegram/api:bg-pattern-id pattern)))
      (let ((retrieved (cl-telegram/api:get-background-pattern pattern-id)))
        (is (not (null retrieved)))
        (is (string= (cl-telegram/api:bg-pattern-id retrieved) pattern-id))))))

(test test-list-background-patterns
  "Test listing background patterns"
  (cl-telegram/api:create-background-pattern "Pattern1" :solid)
  (cl-telegram/api:create-background-pattern "Pattern2" :gradient)
  (let ((patterns (cl-telegram/api:list-background-patterns)))
    (is (listp patterns))
    (is (>= (length patterns) 2))))

(test test-delete-background-pattern
  "Test deleting a background pattern"
  (let ((pattern (cl-telegram/api:create-background-pattern "ToDelete" :solid)))
    (let ((pattern-id (cl-telegram/api:bg-pattern-id pattern)))
      (let ((result (cl-telegram/api:delete-background-pattern pattern-id)))
        (is (eq result t))))))

;;; ============================================================================
;;; Section 2: Chat Background Tests
;;; ============================================================================

(test test-set-chat-background
  "Test setting chat background"
  (let ((pattern (cl-telegram/api:create-background-pattern "TestBG" :solid)))
    (let ((pattern-id (cl-telegram/api:bg-pattern-id pattern)))
      (let ((result (cl-telegram/api:set-chat-background 123 pattern-id)))
        (is (eq result t))))))

(test test-get-chat-background
  "Test getting chat background"
  (let ((pattern (cl-telegram/api:create-background-pattern "TestBG2" :solid)))
    (let ((pattern-id (cl-telegram/api:bg-pattern-id pattern)))
      (cl-telegram/api:set-chat-background 123 pattern-id)
      (let ((bg (cl-telegram/api:get-chat-background 123)))
        (is (not (null bg)))
        (is (eq (cl-telegram/api:bg-chat-id bg) 123))))))

(test test-remove-chat-background
  "Test removing chat background"
  (let ((pattern (cl-telegram/api:create-background-pattern "TestBG3" :solid)))
    (let ((pattern-id (cl-telegram/api:bg-pattern-id pattern)))
      (cl-telegram/api:set-chat-background 123 pattern-id)
      (let ((result (cl-telegram/api:remove-chat-background 123)))
        (is (eq result t))))))

(test test-get-all-chat-backgrounds
  "Test getting all chat backgrounds"
  (let ((pattern1 (cl-telegram/api:create-background-pattern "BG1" :solid)))
    (let ((pattern2 (cl-telegram/api:create-background-pattern "BG2" :gradient)))
      (let ((pid1 (cl-telegram/api:bg-pattern-id pattern1)))
        (let ((pid2 (cl-telegram/api:bg-pattern-id pattern2)))
          (cl-telegram/api:set-chat-background 111 pid1)
          (cl-telegram/api:set-chat-background 222 pid2)
          (let ((backgrounds (cl-telegram/api:get-all-chat-backgrounds)))
            (is (listp backgrounds))
            (is (>= (length backgrounds) 2))))))))

(test test-set-chat-background-custom-settings
  "Test setting chat background with custom settings"
  (let ((pattern (cl-telegram/api:create-background-pattern "CustomBG" :gradient)))
    (let ((pattern-id (cl-telegram/api:bg-pattern-id pattern)))
      (let ((result (cl-telegram/api:set-chat-background 123 pattern-id
                                                         :custom-settings '(:opacity 0.8 :blur 10))))
        (is (eq result t))
        (let ((bg (cl-telegram/api:get-chat-background 123)))
          (is (= (cl-telegram/api:bg-opacity bg) 0.8))
          (is (= (cl-telegram/api:bg-blur bg) 10)))))))

;;; ============================================================================
;;; Section 3: Background Preview Tests
;;; ============================================================================

(test test-preview-background
  "Test previewing background"
  (let ((pattern (cl-telegram/api:create-background-pattern "PreviewBG" :gradient)))
    (let ((pattern-id (cl-telegram/api:bg-pattern-id pattern)))
      (let ((preview (cl-telegram/api:preview-background pattern-id :width 400 :height 300)))
        (is (not (null preview)))
        (is (getf preview :type))
        (is (getf preview :colors))
        (is (= (getf preview :width) 400))
        (is (= (getf preview :height) 300))))))

;;; ============================================================================
;;; Section 4: Statistics Tests
;;; ============================================================================

(test test-get-background-stats
  "Test getting background statistics"
  (cl-telegram/api:create-background-pattern "StatBG1" :solid)
  (cl-telegram/api:create-background-pattern "StatBG2" :gradient)
  (let ((stats (cl-telegram/api:get-background-stats)))
    (is (listp stats))
    (is (getf stats :pattern-count))
    (is (getf stats :chat-backgrounds))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-chat-backgrounds-tests ()
  "Run all Chat Backgrounds tests"
  (let ((results (run! 'chat-backgrounds-tests :if-fail :error)))
    (format t "~%~%=== Chat Backgrounds Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
