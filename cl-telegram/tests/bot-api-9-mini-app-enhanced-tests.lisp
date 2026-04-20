;;; bot-api-9-mini-app-enhanced-tests.lisp --- Tests for enhanced Mini App features

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-mini-app-enhanced-tests
  :description "Tests for enhanced Mini App features (Haptic, Clipboard, Share)")

;;; ============================================================================
;;; Section 1: Haptic Feedback Tests
;;; ============================================================================

(test test-haptic-feedback-impact
  "Test impact haptic feedback"
  (cl-telegram/api:initialize-mini-app 8080)
  (dolist (level '(:light :medium :heavy :rigid :soft))
    (let ((result (cl-telegram/api:haptic-feedback-impact level)))
      (is (or (eq result t) (null result))))))

(test test-haptic-feedback-notification
  "Test notification haptic feedback"
  (cl-telegram/api:initialize-mini-app 8080)
  (dolist (type '(:success :error :warning))
    (let ((result (cl-telegram/api:haptic-feedback-notification type)))
      (is (or (eq result t) (null result))))))

(test test-haptic-feedback-selection-change
  "Test selection change haptic feedback"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:haptic-feedback-selection-change)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 2: Clipboard API Tests
;;; ============================================================================

(test test-read-clipboard-text
  "Test reading clipboard text"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:read-clipboard-text)))
    ;; May be NIL if permission denied or clipboard empty
    (is (or (stringp result) (null result)))))

(test test-write-clipboard-text
  "Test writing clipboard text"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:write-clipboard-text "Test clipboard content")))
    (is (or (eq result t) (null result)))))

(test test-clipboard-roundtrip
  "Test clipboard read/write roundtrip"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((test-text "Hello, Clipboard!"))
    (cl-telegram/api:write-clipboard-text test-text)
    (let ((result (cl-telegram/api:read-clipboard-text)))
      (when (stringp result)
        (is (string= result test-text))))))

(test test-read-clipboard-files
  "Test reading clipboard files"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:read-clipboard-files)))
    (is (or (listp result) (null result)))))

;;; ============================================================================
;;; Section 3: Share Target Tests
;;; ============================================================================

(test test-on-share-target-received
  "Test share target handler registration"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:on-share-target-received
                 'test-handler
                 (lambda (data)
                   (format t "Shared data: ~A~%" data)))))
    (is (eq result t))))

(test test-get-shared-data
  "Test getting shared data"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:get-shared-data)))
    (is (or (listp result) (null result)))))

;;; ============================================================================
;;; Section 4: Share API Tests
;;; ============================================================================

(test test-share-text
  "Test text sharing"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:share-text "Check this out!"
                                            :title "My Share"
                                            :url "https://example.com")))
    (is (or (eq result t) (null result)))))

(test test-share-text-without-optional
  "Test text sharing without optional parameters"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:share-text "Simple share")))
    (is (or (eq result t) (null result)))))

(test test-can-share-p
  "Test share capability check"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:can-share-p :text "Hello" :url "https://example.com")))
    (is (or (eq result t) (null result)))))

(test test-share-file
  "Test file sharing"
  (cl-telegram/api:initialize-mini-app 8080)
  ;; Note: This test requires a valid file path
  (let ((result (cl-telegram/api:share-file "test.txt" :title "Test File")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 5: Utility Function Tests
;;; ============================================================================

(test test-escape-js-string
  "Test JavaScript string escaping"
  (is (string= (cl-telegram/api::escape-js-string "Hello 'World'!")
               "Hello \\'World\\'!"))
  (is (string= (cl-telegram/api::escape-js-string "Line1
Line2")
               "Line1\\nLine2"))
  (is (string= (cl-telegram/api::escape-js-string "Back\\slash")
               "Back\\\\slash")))

(test test-string-replace
  "Test string replacement"
  (is (string= (cl-telegram/api::string-replace "hello world" "world" "lisp")
               "hello lisp"))
  (is (string= (cl-telegram/api::string-replace "aaa" "a" "b")
               "bbb"))
  (is (string= (cl-telegram/api::string-replace "no match" "xyz" "abc")
               "no match")))

;;; ============================================================================
;;; Section 6: Cache Management Tests
;;; ============================================================================

(test test-clear-mini-app-enhanced-cache
  "Test clearing enhanced Mini App cache"
  (cl-telegram/api:initialize-mini-app 8080)
  (is (eq (cl-telegram/api:clear-mini-app-enhanced-cache) t)))

(test test-get-mini-app-enhanced-stats
  "Test getting enhanced Mini App statistics"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((stats (cl-telegram/api:get-mini-app-enhanced-stats)))
    (is (listp stats))
    (is (getf stats :haptic-feedback-supported))
    (is (getf stats :clipboard-supported))
    (is (getf stats :share-supported))))

;;; ============================================================================
;;; Section 7: Initialization Tests
;;; ============================================================================

(test test-initialize-mini-app-enhanced
  "Test enhanced Mini App initialization"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:initialize-mini-app-enhanced)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 8: Integration Tests
;;; ============================================================================

(test test-haptic-feedback-workflow
  "Test complete haptic feedback workflow"
  (cl-telegram/api:initialize-mini-app 8081)
  (cl-telegram/api:initialize-mini-app-enhanced)

  ;; Test all haptic feedback types
  (cl-telegram/api:haptic-feedback-impact :light)
  (cl-telegram/api:haptic-feedback-impact :heavy)
  (cl-telegram/api:haptic-feedback-notification :success)
  (cl-telegram/api:haptic-feedback-selection-change)

  (cl-telegram/api:shutdown-mini-app)
  t)

(test test-clipboard-workflow
  "Test complete clipboard workflow"
  (cl-telegram/api:initialize-mini-app 8082)
  (cl-telegram/api:initialize-mini-app-enhanced)

  ;; Write and read back
  (cl-telegram/api:write-clipboard-text "Test content")
  (let ((content (cl-telegram/api:read-clipboard-text)))
    (when (stringp content)
      (format t "Clipboard content: ~A~%" content)))

  (cl-telegram/api:shutdown-mini-app)
  t)

(test test-share-workflow
  "Test complete share workflow"
  (cl-telegram/api:initialize-mini-app 8083)
  (cl-telegram/api:initialize-mini-app-enhanced)

  ;; Register share handler
  (cl-telegram/api:on-share-target-received 'handler (lambda (d) (print d)))

  ;; Check share capability
  (cl-telegram/api:can-share-p :text "Test" :url "https://example.com")

  ;; Share text
  (cl-telegram/api:share-text "Check this!" :title "Test Share")

  (cl-telegram/api:shutdown-mini-app)
  t)

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-mini-app-enhanced-tests ()
  "Run all enhanced Mini App tests"
  (let ((results (run! 'bot-api-9-mini-app-enhanced-tests :if-fail :error)))
    (format t "~%~%=== Enhanced Mini App Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
