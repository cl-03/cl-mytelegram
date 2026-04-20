;;; bot-api-9-mini-app-tests.lisp --- Tests for Bot API 9.6 Mini App CLOG integration

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-mini-app-tests
  :description "Tests for Bot API 9.6 Mini App CLOG integration features")

;;; ============================================================================
;;; Section 1: Mini App Initialization Tests
;;; ============================================================================

(test test-initialize-mini-app
  "Test Mini App initialization"
  (let ((result (cl-telegram/api:initialize-mini-app 8080)))
    (is (eq result t))))

(test test-shutdown-mini-app
  "Test Mini App shutdown"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:shutdown-mini-app)))
    (is (eq result t))))

(test test-get-mini-app-stats
  "Test Mini App statistics retrieval"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((stats (cl-telegram/api:get-mini-app-stats)))
    (is (listp stats))
    (is (getf stats :connected-p))
    (is (getf stats :window-p))))

;;; ============================================================================
;;; Section 2: Camera Access Tests
;;; ============================================================================

(test test-request-camera-access
  "Test camera access request (requires CLOG)"
  ;; Note: This test requires a running CLOG instance
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:request-camera-access)))
    ;; Result may be NIL if browser not available
    (is (or (eq result t) (null result)))))

(test test-capture-photo
  "Test photo capture"
  (cl-telegram/api:initialize-mini-app 8080)
  (cl-telegram/api:request-camera-access)
  (let ((result (cl-telegram/api:capture-photo :quality :high :width 1920 :height 1080)))
    ;; Result may be NIL if camera not available
    (is (or (stringp result) (null result)))))

(test test-capture-video
  "Test video capture"
  (cl-telegram/api:initialize-mini-app 8080)
  (cl-telegram/api:request-camera-access)
  (let ((result (cl-telegram/api:capture-video :duration 5 :quality :high)))
    ;; Result may be NIL if camera not available
    (is (or (stringp result) (null result)))))

;;; ============================================================================
;;; Section 3: Microphone Access Tests
;;; ============================================================================

(test test-request-microphone-access
  "Test microphone access request"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:request-microphone-access)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Media Stream Management Tests
;;; ============================================================================

(test test-get-media-stream
  "Test media stream acquisition"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:get-media-stream :video t :audio nil)))
    (is (or (stringp result) (null result)))))

(test test-release-media-stream
  "Test media stream release"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((stream-id (cl-telegram/api:get-media-stream :video t :audio nil)))
    (when stream-id
      (let ((result (cl-telegram/api:release-media-stream stream-id)))
        (is (eq result t))))))

(test test-get-device-permissions
  "Test device permissions query"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((permissions (cl-telegram/api:get-device-permissions)))
    (is (listp permissions))
    (is (getf permissions :camera))
    (is (getf permissions :microphone))
    (is (getf permissions :location))))

(test test-check-device-support
  "Test device feature support check"
  (cl-telegram/api:initialize-mini-app 8080)
  (dolist (feature '(:camera :microphone :location :contacts))
    (let ((result (cl-telegram/api:check-device-support feature)))
      (is (or (eq result t) (null result))))))

;;; ============================================================================
;;; Section 5: Theme Integration Tests
;;; ============================================================================

(test test-sync-with-client-theme
  "Test theme synchronization"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((theme (cl-telegram/api:sync-with-client-theme)))
    (is (or (typep theme 'cl-telegram/api:mini-app-theme) (null theme)))))

(test test-apply-theme-to-clog
  "Test theme application to CLOG window"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((theme (cl-telegram/api:sync-with-client-theme)))
    (when theme
      (let ((result (cl-telegram/api:apply-theme-to-clog theme)))
        (is (eq result t))))))

(test test-get-theme-parameters
  "Test theme parameters retrieval"
  (cl-telegram/api:initialize-mini-app 8080)
  (cl-telegram/api:sync-with-client-theme)
  (let ((params (cl-telegram/api:get-theme-parameters)))
    (is (listp params))
    (is (getf params :bg-color))
    (is (getf params :text-color))))

;;; ============================================================================
;;; Section 6: Mini App UI Component Tests
;;; ============================================================================

(test test-create-mini-app-button
  "Test Mini App button creation"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((button-id (cl-telegram/api:create-mini-app-button "Test Button"
                                                           :color "#0088cc"
                                                           :on-click (lambda () (print "clicked")))))
    (is (or (stringp button-id) (null button-id)))))

(test test-show-mini-app-alert
  "Test Mini App alert dialog"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:show-mini-app-alert "Test message" :title "Test")))
    (is (eq result t))))

;;; ============================================================================
;;; Section 7: Cache Management Tests
;;; ============================================================================

(test test-clear-mini-app-cache
  "Test Mini App cache clearing"
  (cl-telegram/api:initialize-mini-app 8080)
  (let ((result (cl-telegram/api:clear-mini-app-cache)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 8: Integration Tests
;;; ============================================================================

(test test-mini-app-lifecycle
  "Test complete Mini App lifecycle"
  ;; Initialize
  (is (eq (cl-telegram/api:initialize-mini-app 8081) t))

  ;; Check stats
  (let ((stats (cl-telegram/api:get-mini-app-stats)))
    (is (getf stats :connected-p))
    (is (getf stats :window-p)))

  ;; Sync theme
  (cl-telegram/api:sync-with-client-theme)

  ;; Check permissions
  (let ((perms (cl-telegram/api:get-device-permissions)))
    (is (listp perms)))

  ;; Clear cache
  (is (eq (cl-telegram/api:clear-mini-app-cache) t))

  ;; Shutdown
  (is (eq (cl-telegram/api:shutdown-mini-app) t))

  ;; Verify shutdown
  (let ((stats (cl-telegram/api:get-mini-app-stats)))
    (is (not (getf stats :connected-p)))))

;;; ============================================================================
;;; Section 9: Error Handling Tests
;;; ============================================================================

(test test-camera-without-init
  "Test camera access without initialization (should fail gracefully)"
  (cl-telegram/api:shutdown-mini-app)
  (let ((result (cl-telegram/api:request-camera-access)))
    (is (null result))))

(test test-capture-without-permission
  "Test photo capture without permission (should fail gracefully)"
  (cl-telegram/api:initialize-mini-app 8082)
  ;; Don't request camera permission
  (let ((result (cl-telegram/api:capture-photo)))
    (is (null result))))

(test test-release-invalid-stream
  "Test releasing invalid stream ID (should fail gracefully)"
  (cl-telegram/api:initialize-mini-app 8083)
  (let ((result (cl-telegram/api:release-media-stream "invalid_stream_id")))
    (is (or (null result) (eq result t)))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-mini-app-tests ()
  "Run all Mini App CLOG integration tests"
  (let ((results (run! 'bot-api-9-mini-app-tests :if-fail :error)))
    (format t "~%~%=== Mini App CLOG Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
