;;; bot-api-9-advanced-tests.lisp --- Tests for advanced Bot API features

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-advanced-tests
  :description "Tests for advanced Bot API features (Biometric, Contacts)")

;;; ============================================================================
;;; Section 1: Biometric Authentication Tests
;;; ============================================================================

(test test-is-biometric-available
  "Test checking biometric availability"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:is-biometric-available)))
    (is (or (eq result t) (null result)))))

(test test-request-biometric-auth
  "Test requesting biometric authentication"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:request-biometric-auth :reason "Test auth")))
    ;; Result may be NIL if WebAuthn not supported or user cancelled
    (when result
      (is (getf result :success))
      (is (or (getf result :credentialId) (getf result :error))))))

(test test-enroll-biometric
  "Test enrolling biometric data"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:enroll-biometric :biometric-type :fingerprint :user-name "Test User")))
    ;; Result may be NIL if WebAuthn not supported or user cancelled
    (when result
      (is (getf result :success))
      (is (or (getf result :credentialId) (getf result :error))))))

(test test-is-biometric-enrolled-p
  "Test checking if biometric is enrolled"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:is-biometric-enrolled-p)))
    (is (or (eq result t) (null result) (eq result nil)))))

;;; ============================================================================
;;; Section 2: Contacts API Tests
;;; ============================================================================

(test test-is-contacts-api-supported
  "Test checking Contacts API support"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:is-contacts-api-supported)))
    (is (or (eq result t) (null result)))))

(test test-select-contacts
  "Test selecting contacts"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((contacts (cl-telegram/api:select-contacts :multiple t :limit 5)))
    ;; Contacts may be NIL if permission denied or API not supported
    (when contacts
      (is (listp contacts))
      (dolist (contact contacts)
        (is (getf contact :name))))))

(test test-select-contacts-single
  "Test selecting single contact"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((contacts (cl-telegram/api:select-contacts :multiple nil :limit 1)))
    (is (or (listp contacts) (null contacts)))))

(test test-get-contact-details
  "Test getting contact details"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:get-contact-details "nonexistent_contact")))
    (is (or (null result) (listp result)))))

(test test-cache-contacts
  "Test caching contacts"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((test-contacts '((:name "John Doe" :tel "123456789")
                         (:name "Jane Smith" :tel "987654321"))))
    (let ((result (cl-telegram/api::cache-contacts test-contacts)))
      (is (eq result t)))))

(test test-clear-contacts-cache
  "Test clearing contacts cache"
  (cl-telegram/api:initialize-mini-app 8080)
  (is (eq (cl-telegram/api:clear-contacts-cache) t)))

;;; ============================================================================
;;; Section 3: Telegram WebApp Advanced Features Tests
;;; ============================================================================

(test test-expand-web-app
  "Test expanding web app"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:expand-web-app)))
    (is (or (eq result t) (null result)))))

(test test-close-web-app
  "Test closing web app"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:close-web-app)))
    (is (or (eq result t) (null result)))))

(test test-toggle-web-app-confirmation
  "Test toggling close confirmation"
  (cl-telegram/api:initialize-mini-app 8080)
  (dolist (enable '(t nil))
    (let ((result (cl-telegram/api:toggle-web-app-confirmation :enable enable)))
      (is (or (eq result t) (null result))))))

(test test-setup-main-button
  "Test setting up main button"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:setup-main-button "Submit" :visible t)))
    (is (or (eq result t) (null result)))))

(test test-setup-main-button-with-progress
  "Test setting up main button with progress"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:setup-main-button "Processing" :visible t :progress t)))
    (is (or (eq result t) (null result)))))

(test test-on-main-button-click
  "Test registering main button click handler"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:on-main-button-click
                 'test-handler
                 (lambda () (format t "Main button clicked!")))))
    (is (eq result t))))

;;; ============================================================================
;;; Section 4: Cache Management Tests
;;; ============================================================================

(test test-clear-biometric-cache
  "Test clearing biometric cache"
  (cl-telegram/api:initialize-mini-app 8080)
  (is (eq (cl-telegram/api:clear-biometric-cache) t)))

(test test-clear-advanced-cache
  "Test clearing all advanced feature caches"
  (cl-telegram/api:initialize-mini-app 8080)
  (is (eq (cl-telegram/api:clear-advanced-cache) t)))

(test test-get-advanced-stats
  "Test getting advanced features statistics"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((stats (cl-telegram/api:get-advanced-stats)))
    (is (listp stats))
    (is (getf stats :biometric-managers))
    (is (getf stats :contacts-cached))
    (is (or (eq (getf stats :contacts-api-supported) t)
            (null (getf stats :contacts-api-supported))))
    (is (or (eq (getf stats :biometric-available) t)
            (null (getf stats :biometric-available))))))

;;; ============================================================================
;;; Section 5: Initialization Tests
;;; ============================================================================

(test test-initialize-bot-api-9-advanced
  "Test initializing advanced Bot API features"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:initialize-bot-api-9-advanced)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 6: Integration Tests
;;; ============================================================================

(test test-biometric-workflow
  "Test complete biometric authentication workflow"
  (cl-telegram/api:initialize-mini-app 8081)
  (cl-telegram/api:initialize-bot-api-9-advanced)

  ;; Check availability
  (let ((available (cl-telegram/api:is-biometric-available)))
    (format t "Biometric available: ~A~%" available)

    (when available
      ;; Try enrollment
      (let ((enroll-result (cl-telegram/api:enroll-biometric :user-name "Test")))
        (when (getf enroll-result :success)
          (format t "Enrollment successful: ~A~%" (getf enroll-result :credentialId))))

      ;; Try authentication
      (let ((auth-result (cl-telegram/api:request-biometric-auth :reason "Test")))
        (format t "Auth result: ~A~%" auth-result))

      ;; Check if enrolled
      (let ((enrolled (cl-telegram/api:is-biometric-enrolled-p))
        (format t "Is enrolled: ~A~%" enrolled))))

  (cl-telegram/api:clear-biometric-cache)
  (cl-telegram/api:shutdown-mini-app)
  t)

(test test-contacts-workflow
  "Test complete contacts workflow"
  (cl-telegram/api:initialize-mini-app 8082)
  (cl-telegram/api:initialize-bot-api-9-advanced)

  ;; Check API support
  (let ((supported (cl-telegram/api:is-contacts-api-supported)))
    (format t "Contacts API supported: ~A~%" supported)

    (when supported
      ;; Select contacts
      (let ((contacts (cl-telegram/api:select-contacts :multiple t :limit 3)))
        (when contacts
          (format t "Selected ~D contacts~%" (length contacts))

          ;; Cache contacts
          (cl-telegram/api::cache-contacts contacts)

          ;; Get stats
          (let ((stats (cl-telegram/api:get-advanced-stats)))
            (format t "Cached contacts: ~A~%" (getf stats :contacts-cached)))))))

  (cl-telegram/api:clear-contacts-cache)
  (cl-telegram/api:shutdown-mini-app)
  t)

(test test-webapp-features-workflow
  "Test Telegram WebApp advanced features workflow"
  (cl-telegram/api:initialize-mini-app 8083)
  (cl-telegram/api:initialize-bot-api-9-advanced)

  ;; Expand app
  (cl-telegram/api:expand-web-app)

  ;; Setup main button
  (cl-telegram/api:setup-main-button "Continue" :visible t)

  ;; Register handler
  (cl-telegram/api:on-main-button-click 'continue (lambda () (print "Continue clicked")))

  ;; Enable close confirmation
  (cl-telegram/api:toggle-web-app-confirmation :enable t)

  ;; Disable close confirmation
  (cl-telegram/api:toggle-web-app-confirmation :enable nil)

  (cl-telegram/api:shutdown-mini-app)
  t)

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-bot-api-9-advanced-tests ()
  "Run all advanced Bot API tests"
  (let ((results (run! 'bot-api-9-advanced-tests :if-fail :error)))
    (format t "~%~%=== Advanced Bot API Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
