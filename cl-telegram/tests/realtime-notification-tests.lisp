;;; realtime-notification-tests.lisp --- Tests for real-time notifications
;;;
;;; Tests for WebSocket client and desktop notification system

(in-package #:cl-telegram/tests)

;;; ### WebSocket Client Tests

(deftest test-websocket-client-creation
  "Test WebSocket client creation"
  (let ((client (cl-telegram/network:make-websocket-client
                 "ws://localhost:8080"
                 :on-message (lambda (c m) (declare (ignore c m)))
                 :on-connect (lambda (c) (declare (ignore c)))
                 :on-error (lambda (c e) (declare (ignore c e)))
                 :on-close (lambda (c code reason) (declare (ignore c code reason))))))
    (is (typep client 'cl-telegram/network::websocket-client))
    (is (string= (cl-telegram/network:ws-url client) "ws://localhost:8080"))
    (is (not (cl-telegram/network:ws-connected-p client)))
    (is (= (cl-telegram/network:ws-message-count client) 0))))

(deftest test-parse-websocket-url
  "Test WebSocket URL parsing"
  (let* ((url "wss://telegram.org/ws")
         (parsed (cl-telegram/network::parse-websocket-url url)))
    (is (string= (getf parsed :host) "telegram.org"))
    (is (= (getf parsed :port) 443))
    (is (string= (getf parsed :path) "/ws"))
    (is (eq (getf parsed :secure) t)))
  ;; Test non-secure URL
  (let* ((url "ws://localhost:8080/chat")
         (parsed (cl-telegram/network::parse-websocket-url url)))
    (is (string= (getf parsed :host) "localhost"))
    (is (= (getf parsed :port) 8080))
    (is (string= (getf parsed :path) "/chat"))
    (is (eq (getf parsed :secure) nil))))

(deftest test-websocket-frame-creation
  "Test WebSocket frame creation"
  (let* ((data (babel:string-to-octets "Hello, WebSocket!"))
         (frame (cl-telegram/network::create-websocket-frame data #x01 :mask nil)))
    ;; Check frame structure
    (is (>= (length frame) (+ 2 (length data))))
    ;; First byte should have FIN bit set + text opcode
    (is (= (logand (aref frame 0) #x80) #x80))  ; FIN bit
    (is (= (logand (aref frame 0) #x0F) #x01)))  ; Text opcode
  ;; Test masked frame
  (let* ((data (babel:string-to-octets "Test"))
         (frame (cl-telegram/network::create-websocket-frame data #x02 :mask t)))
    ;; Masked frame should have 4 extra bytes for mask key
    (is (= (length frame) (+ 2 4 (length data))))
    ;; Second byte should have mask bit set
    (is (= (logand (aref frame 1) #x80) #x80))))

(deftest test-websocket-stats
  "Test WebSocket statistics"
  (let ((client (cl-telegram/network:make-websocket-client "ws://localhost")))
    (let ((stats (cl-telegram/network:websocket-stats client)))
      (is (getf stats :connected))
      (is (getf stats :messages-received))
      (is (getf stats :reconnect-count))
      (is (getf stats :url)))))

;;; ### Desktop Notification Tests

(deftest test-notification-manager-creation
  "Test notification manager creation"
  (let ((mgr (cl-telegram/api:make-notification-manager)))
    (is (typep mgr 'cl-telegram/api::notification-manager))
    (is (member (cl-telegram/api::notif-platform mgr)
                '(:windows :macos :linux :unknown)))
    (is (cl-telegram/api::notif-enabled-p mgr))
    (is (cl-telegram/api::notif-sound-enabled-p mgr))
    (is (cl-telegram/api::notif-badge-enabled-p mgr))))

(deftest test-quiet-hours
  "Test quiet hours functionality"
  (let ((mgr (cl-telegram/api:make-notification-manager)))
    ;; Initially no quiet hours
    (is (not (cl-telegram/api::in-quiet-hours-p mgr)))
    ;; Set quiet hours
    (setf (cl-telegram/api::notif-quiet-start mgr) 22)
    (setf (cl-telegram/api::notif-quiet-end mgr) 8)
    ;; Quiet hours are set (actual check depends on current time)
    (is (= (cl-telegram/api::notif-quiet-start mgr) 22))
    (is (= (cl-telegram/api::notif-quiet-end mgr) 8))))

(deftest test-notification-history
  "Test notification history"
  (let ((mgr (cl-telegram/api:make-notification-manager)))
    ;; Add notifications to history
    (cl-telegram/api::add-to-notification-history
     "Test 1" "Message 1" :message)
    (cl-telegram/api::add-to-notification-history
     "Test 2" "Message 2" :mention)
    (cl-telegram/api::add-to-notification-history
     "Test 3" "Message 3" :message)

    ;; Get all history
    (let ((history (cl-telegram/api:get-notification-history :limit 10)))
      (is (= (length history) 3))
      ;; Most recent first
      (is (string= (getf (first history) :title) "Test 3")))

    ;; Filter by type
    (let ((history (cl-telegram/api:get-notification-history
                    :limit 10 :type :message)))
      (is (= (length history) 2)))

    ;; Clear history
    (cl-telegram/api:clear-notification-history)
    (is (= (length (cl-telegram/api:get-notification-history)) 0))))

(deftest test-platform-detection
  "Test platform detection"
  (let ((platform (cl-telegram/api::detect-platform)))
    (is (member platform '(:windows :macos :linux :unknown)))))

(deftest test-send-notification-fallback
  "Test fallback notification (terminal)"
  ;; Fallback notification should always succeed
  (let ((result (cl-telegram/api::send-fallback-notification
                 "Test Title" "Test Message")))
    (is (eq result t))))

(deftest test-notification-settings
  "Test notification settings functions"
  (cl-telegram/api:initialize-notifications)
  (let ((mgr cl-telegram/api:*notification-manager*))
    (is (typep mgr 'cl-telegram/api::notification-manager))
    ;; Enable/disable
    (setf (cl-telegram/api::notif-enabled-p mgr) nil)
    (is (not (cl-telegram/api::notif-enabled-p mgr)))
    (setf (cl-telegram/api::notif-enabled-p mgr) t)
    (is (cl-telegram/api::notif-enabled-p mgr))))

;;; ### Integration Tests

(deftest test-enable-realtime-updates
  "Test enabling real-time updates (mock)"
  ;; This test doesn't connect to actual server
  (let ((client (cl-telegram/network:make-websocket-client
                 "ws://localhost:9999")))
    ;; Client is created but not connected
    (is (not (cl-telegram/network:ws-connected-p client)))
    ;; Stats should show initial state
    (let ((stats (cl-telegram/network:websocket-stats client)))
      (is (not (getf stats :connected)))
      (is (= (getf stats :reconnect-count) 0)))))

(deftest test-notification-handler-registration
  "Test notification handler registration with update handler"
  ;; Create update handler
  (let ((handler (cl-telegram/api:make-update-handler nil)))
    (cl-telegram/api:set-update-handler handler)
    ;; Setup notification handlers
    (let ((result (cl-telegram/api:setup-notification-handlers)))
      (is (eq result t)))
    ;; Cleanup
    (cl-telegram/api:remove-update-handler)))

;;; ### Test Runner

(defun run-realtime-notification-tests ()
  "Run all real-time notification tests.

   Returns:
     T if all tests pass"
  (format t "~%Running Real-time Notification Tests...~%")
  (let ((results (list
                  (fiveam:run! 'test-websocket-client-creation)
                  (fiveam:run! 'test-parse-websocket-url)
                  (fiveam:run! 'test-websocket-frame-creation)
                  (fiveam:run! 'test-websocket-stats)
                  (fiveam:run! 'test-notification-manager-creation)
                  (fiveam:run! 'test-quiet-hours)
                  (fiveam:run! 'test-notification-history)
                  (fiveam:run! 'test-platform-detection)
                  (fiveam:run! 'test-send-notification-fallback)
                  (fiveam:run! 'test-notification-settings)
                  (fiveam:run! 'test-enable-realtime-updates)
                  (fiveam:run! 'test-notification-handler-registration))))
    (if (every #'identity results)
        (progn
          (format t "All tests passed!~%")
          t)
        (progn
          (format t "Some tests failed!~%")
          nil))))
