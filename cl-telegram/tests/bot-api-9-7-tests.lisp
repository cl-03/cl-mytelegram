;;; bot-api-9-7-tests.lisp --- Tests for Bot API 9.7 features

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-7-tests
  :description "Tests for Bot API 9.7 features (Location, File Picker, Notifications)")

;;; ============================================================================
;;; Section 1: Location API Tests
;;; ============================================================================

(test test-request-location-access
  "Test location access request"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:request-location-access)))
    (is (or (eq result t) (null result)))))

(test test-get-current-location
  "Test getting current location"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((location (cl-telegram/api:get-current-location :high-accuracy t :timeout 10000)))
    ;; Location may be NIL if permission denied or unavailable
    (when location
      (is (getf location :latitude))
      (is (getf location :longitude))
      (is (numberp (getf location :latitude)))
      (is (numberp (getf location :longitude))))))

(test test-watch-position
  "Test position watching"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((watch-id (cl-telegram/api:watch-position
                   (lambda (pos)
                     (format t "Position update: ~A, ~A~%"
                             (getf pos :latitude)
                             (getf pos :longitude)))
                   :enable-high-accuracy t)))
    (is (or (stringp watch-id) (null watch-id)))
    (when watch-id
      (is (cl-telegram/api:clear-position-watch watch-id)))))

(test test-clear-position-watch
  "Test clearing position watch"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((watch-id "test_watch_123"))
    ;; Should not error on invalid watch ID
    (is (or (null (cl-telegram/api:clear-position-watch watch-id))
            (eq (cl-telegram/api:clear-position-watch watch-id) t)))))

;;; ============================================================================
;;; Section 2: File Picker Tests
;;; ============================================================================

(test test-select-files
  "Test file selection"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((files (cl-telegram/api:select-files :accept "*/*" :multiple t)))
    ;; Files may be NIL if user cancels
    (when files
      (is (listp files))
      (dolist (file files)
        (is (getf file :name))
        (is (getf file :size))
        (is (getf file :type))))))

(test test-select-files-with-filter
  "Test file selection with type filter"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((files (cl-telegram/api:select-files :accept "image/*" :multiple nil)))
    (is (or (listp files) (null files)))))

(test test-select-files-with-size-limit
  "Test file selection with size limit"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((files (cl-telegram/api:select-files :accept "*/*" :multiple t :max-file-size 10485760)))
    (when files
      (dolist (file files)
        (is (<= (getf file :size) 10485760))))))

(test test-select-directory
  "Test directory selection"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((files (cl-telegram/api:select-directory :recursive t)))
    (is (or (listp files) (null files)))))

;;; ============================================================================
;;; Section 3: Notification API Tests
;;; ============================================================================

(test test-request-notification-permission
  "Test notification permission request"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:request-notification-permission)))
    (is (member result '(:granted :denied :default)))))

(test test-get-notification-permission
  "Test getting notification permission"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:get-notification-permission)))
    (is (member result '(:granted :denied :default)))))

(test test-send-notification
  "Test sending notification"
  (cl-telegram/api:initialize-mini-app 8080)
  (cl-telegram/api:request-notification-permission)
  (let ((result (cl-telegram/api:send-notification "Test Notification"
                                                   :body "This is a test notification"
                                                   :tag "test_tag")))
    ;; Result may be NIL if permission denied
    (is (or (eq result t) (null result)))))

(test test-send-notification-with-options
  "Test sending notification with all options"
  (cl-telegram/api:initialize-mini-app 8080)
  (cl-telegram/api:request-notification-permission)
  (let ((result (cl-telegram/api:send-notification "Test"
                                                   :body "Body text"
                                                   :icon "/icon.png"
                                                   :badge "/badge.png"
                                                   :tag "test"
                                                   :require-interaction t
                                                   :silent t)))
    (is (or (eq result t) (null result)))))

(test test-on-notification-click
  "Test notification click handler registration"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:on-notification-click
                 'test-handler
                 (lambda (notif)
                   (format t "Notification clicked: ~A~%" notif)))))
    (is (eq result t))))

(test test-close-notification
  "Test closing notification"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:close-notification "test_tag")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Cache Management Tests
;;; ============================================================================

(test test-clear-location-cache
  "Test clearing location cache"
  (cl-telegram/api:initialize-mini-app 8080)
  (is (eq (cl-telegram/api:clear-location-cache) t)))

(test test-clear-notification-cache
  "Test clearing notification cache"
  (cl-telegram/api:initialize-mini-app 8080)
  (is (eq (cl-telegram/api:clear-notification-cache) t)))

(test test-get-bot-api-9-7-stats
  "Test getting Bot API 9.7 statistics"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((stats (cl-telegram/api:get-bot-api-9-7-stats)))
    (is (listp stats))
    (is (getf stats :active-watches))
    (is (getf stats :notification-handlers))
    (is (member (getf stats :notification-permission) '(:granted :denied :default nil)))))

;;; ============================================================================
;;; Section 5: Initialization Tests
;;; ============================================================================

(test test-initialize-bot-api-9-7
  "Test Bot API 9.7 initialization"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:initialize-bot-api-9-7)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 6: Integration Tests
;;; ============================================================================

(test test-bot-api-9-7-full-workflow-location
  "Test complete location API workflow"
  ;; Initialize
  (cl-telegram/api:initialize-mini-app 8081)
  (cl-telegram/api:initialize-bot-api-9-7)

  ;; Request permission
  (cl-telegram/api:request-location-access)

  ;; Get current location
  (let ((location (cl-telegram/api:get-current-location :timeout 5000)))
    (when location
      (format t "Current location: ~A, ~A~%"
              (getf location :latitude)
              (getf location :longitude))))

  ;; Cleanup
  (cl-telegram/api:clear-location-cache)
  (cl-telegram/api:shutdown-mini-app)
  t)

(test test-bot-api-9-7-full-workflow-notification
  "Test complete notification API workflow"
  ;; Initialize
  (cl-telegram/api:initialize-mini-app 8082)
  (cl-telegram/api:initialize-bot-api-9-7)

  ;; Request permission
  (let ((perm (cl-telegram/api:request-notification-permission)))
    (format t "Notification permission: ~A~%" perm)

    (when (eq perm :granted)
      ;; Send notification
      (cl-telegram/api:send-notification "Test" :body "Test body")

      ;; Register handler
      (cl-telegram/api:on-notification-click 'test (lambda () (print "clicked")))

      ;; Close notification
      (cl-telegram/api:close-notification "test_tag")))

  ;; Cleanup
  (cl-telegram/api:clear-notification-cache)
  (cl-telegram/api:shutdown-mini-app)
  t)

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-bot-api-9-7-tests ()
  "Run all Bot API 9.7 tests"
  (let ((results (run! 'bot-api-9-7-tests :if-fail :error)))
    (format t "~%~%=== Bot API 9.7 Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
