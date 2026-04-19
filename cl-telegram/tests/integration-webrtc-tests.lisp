;;; integration-webrtc-tests.lisp --- Integration tests for WebRTC functionality
;;;
;;; Tests for WebRTC peer-to-peer audio/video communication.
;;; These tests require libwebrtc to be installed.

(in-package #:cl-telegram/tests)

(def-suite* integration-webrtc-tests
  :description "Integration tests for WebRTC functionality")

;;; ### Test Fixtures

(defvar *test-webrtc-manager* nil
  "Test WebRTC manager instance")

(defvar *test-peer-connection* nil
  "Test peer connection handle")

(defun setup-webrtc-test ()
  "Setup WebRTC test environment.

   Returns:
     T on success"
  (format t "~%Setting up WebRTC test environment...~%")

  ;; Initialize WebRTC
  (let ((result (cl-telegram/api:init-webrtc)))
    (if result
        (progn
          (setf *test-webrtc-manager* cl-telegram/api::*webrtc-manager*)
          (format t "WebRTC initialized~%")
          t)
        (progn
          (format t "WebRTC initialization failed - skipping tests~%")
          nil))))

(defun teardown-webrtc-test ()
  "Teardown WebRTC test environment.

   Returns:
     T on success"
  (format t "~%Tearing down WebRTC test environment...~%")

  ;; Close peer connection
  (when *test-peer-connection*
    (cl-telegram/api:close-webrtc-peer-connection)
    (setf *test-peer-connection* nil))

  ;; Shutdown WebRTC
  (cl-telegram/api:shutdown-webrtc)
  (setf *test-webrtc-manager* nil)
  (format t "WebRTC shutdown~%")
  t)

(defmacro with-webrtc-test (&body body)
  "Execute body with WebRTC test setup and teardown.

   Usage:
     (with-webrtc-test
       (test-some-webrtc-feature))"
  `(unwind-protect
       (progn
         (when (setup-webrtc-test)
           ,@body))
    (teardown-webrtc-test)))

;;; ### Initialization Tests

(test test-webrtc-init
  "Test WebRTC initialization"
  (with-webrtc-test
    (is cl-telegram/api::*webrtc-manager* "WebRTC manager should be created")
    (is (typep cl-telegram/api::*webrtc-manager* 'cl-telegram/api::webrtc-manager)
        "Should be webrtc-manager instance")
    (is cl-telegram/api::*webrtc-initialized* "WebRTC should be initialized")))

(test test-webrtc-stun-servers
  "Test STUN server configuration"
  (with-webrtc-test
    (let ((servers (cl-telegram/api::webrtc-stun-servers *test-webrtc-manager*)))
      (is servers "STUN servers should be configured")
      (is (>= (length servers) 1) "Should have at least one STUN server")
      (is (find "stun:stun.l.google.com:19302" servers :test #'string=)
          "Should have Google STUN server"))))

;;; ### Peer Connection Tests

(test test-webrtc-create-peer-connection
  "Test creating WebRTC peer connection"
  (with-webrtc-test
    (let ((result (cl-telegram/api:create-webrtc-peer-connection)))
      (is result "Should create peer connection")
      (setf *test-peer-connection* result))))

(test test-webrtc-create-peer-connection-with-turn
  "Test creating peer connection with TURN server"
  (with-webrtc-test
    ;; Note: This test requires actual TURN server
    (let ((result (cl-telegram/api:create-webrtc-peer-connection
                   :use-turn t
                   :turn-uri "turn:turn.example.com:3478"
                   :turn-username "test"
                   :turn-credential "secret")))
      ;; May fail without real TURN server, but should not crash
      (format t "TURN connection result: ~A~%" result))))

(test test-webrtc-close-peer-connection
  "Test closing peer connection"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((result (cl-telegram/api:close-webrtc-peer-connection)))
      (is result "Should close peer connection")
      (is (null (cl-telegram/api::webrtc-peer-connection *test-webrtc-manager*))
          "Peer connection should be nil"))))

;;; ### Media Stream Tests

(test test-webrtc-create-media-stream-audio
  "Test creating audio media stream"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((result (cl-telegram/api:create-webrtc-media-stream :audio t :video nil)))
      (is result "Should create audio stream")
      (is (cl-telegram/api::webrtc-local-stream *test-webrtc-manager*)
          "Local stream should be created"))))

(test test-webrtc-create-media-stream-video
  "Test creating video media stream"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((result (cl-telegram/api:create-webrtc-media-stream :audio t :video t)))
      (is result "Should create video stream")
      (is (cl-telegram/api::webrtc-local-stream *test-webrtc-manager*)
          "Local stream should be created"))))

(test test-webrtc-create-media-stream-custom-settings
  "Test creating media stream with custom settings"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((result (cl-telegram/api:create-webrtc-media-stream
                   :audio t
                   :video t
                   :video-width 1280
                   :video-height 720
                   :video-fps 30
                   :video-bitrate 1000000)))
      (is result "Should create media stream with custom settings"))))

(test test-webrtc-close-media-stream
  "Test closing media stream"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-media-stream :audio t :video nil)
    (let ((result (cl-telegram/api:close-webrtc-media-stream)))
      (is result "Should close media stream")
      (is (null (cl-telegram/api::webrtc-local-stream *test-webrtc-manager*))
          "Local stream should be nil"))))

;;; ### SDP Offer/Answer Tests

(test test-webrtc-create-offer
  "Test creating SDP offer"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-media-stream :audio t)
    (multiple-value-bind (sdp offer error)
        (cl-telegram/api:create-webrtc-offer)
      (is (null error) "Should not have error")
      (is sdp "Should generate SDP")
      (is (stringp sdp) "SDP should be string")
      (is (search "v=0" sdp) "Should contain SDP version")
      (is (search "m=audio" sdp) "Should contain audio media"))))

(test test-webrtc-create-answer
  "Test creating SDP answer"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-media-stream :audio t)
    ;; Create offer first
    (multiple-value-bind (offer-sdp nil nil)
        (cl-telegram/api:create-webrtc-offer)
      (when offer-sdp
        ;; Create answer from offer
        (multiple-value-bind (answer-sdp answer error)
            (cl-telegram/api:create-webrtc-answer offer-sdp)
          (is (null error) "Should not have error")
          (is answer-sdp "Should generate SDP answer")
          (is (stringp answer-sdp) "Answer should be string"))))))

(test test-webrtc-set-remote-description
  "Test setting remote description"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-media-stream :audio t)
    (multiple-value-bind (offer-sdp nil nil)
        (cl-telegram/api:create-webrtc-offer)
      (when offer-sdp
        ;; Create second peer connection to simulate remote
        (cl-telegram/api:create-webrtc-peer-connection)
        (multiple-value-bind (success error)
            (cl-telegram/api:set-webrtc-remote-description offer-sdp :type :offer)
          (is success "Should set remote description"))))))

;;; ### ICE Candidate Tests

(test test-webrtc-get-pending-ice-candidates
  "Test getting pending ICE candidates"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((candidates (cl-telegram/api:get-pending-ice-candidates)))
      (is (listp candidates) "Should return list"))))

(test test-webrtc-add-ice-candidate
  "Test adding ICE candidate"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((candidate "candidate:1 1 UDP 1 192.168.1.1 5000 typ host"))
      (multiple-value-bind (success error)
          (cl-telegram/api:add-webrtc-ice-candidate candidate "0" 0)
        ;; May fail without real connection, but should not crash
        (format t "ICE candidate result: ~A ~A~%" success error)))))

;;; ### Data Channel Tests

(test test-webrtc-create-data-channel
  "Test creating data channel"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (multiple-value-bind (channel-id error)
        (cl-telegram/api:create-webrtc-data-channel "test-channel")
      (is (null error) "Should not have error")
      (is channel-id "Should return channel ID")
      (is (string= channel-id "test-channel") "Channel ID should match label"))))

(test test-webrtc-send-data
  "Test sending data over data channel"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-data-channel "test-channel")
    (let ((data #(1 2 3 4 5)))
      (multiple-value-bind (success error)
          (cl-telegram/api:send-webrtc-data "test-channel" data)
        ;; May fail without connected peer, but should not crash
        (format t "Send data result: ~A ~A~%" success error)))))

(test test-webrtc-close-data-channel
  "Test closing data channel"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-data-channel "test-channel")
    (multiple-value-bind (success error)
        (cl-telegram/api:close-webrtc-data-channel "test-channel")
      (is success "Should close data channel"))))

;;; ### State Management Tests

(test test-webrtc-get-state
  "Test getting connection state"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((state (cl-telegram/api:get-webrtc-state)))
      (is (member state '(:new :connecting :connected :disconnected :failed :closed))
          "State should be valid keyword"))))

(test test-webrtc-get-signaling-state
  "Test getting signaling state"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (let ((state (cl-telegram/api:get-webrtc-signaling-state)))
      (is (member state '(:stable :have-local-offer :have-remote-offer
                                  :have-local-pranswer :have-remote-pranswer))
          "Signaling state should be valid keyword"))))

;;; ### Integration Tests

(test test-webrtc-full-call-flow
  "Test complete WebRTC call flow"
  (with-webrtc-test
    ;; Create peer connection
    (cl-telegram/api:create-webrtc-peer-connection)

    ;; Create media stream
    (cl-telegram/api:create-webrtc-media-stream :audio t :video nil)

    ;; Create SDP offer
    (multiple-value-bind (offer-sdp nil error)
        (cl-telegram/api:create-webrtc-offer)
      (is (null error) "Should create offer")

      (when offer-sdp
        ;; Simulate remote peer receiving offer and creating answer
        (cl-telegram/api:create-webrtc-peer-connection)
        (cl-telegram/api:create-webrtc-media-stream :audio t)

        ;; Set remote description
        (cl-telegram/api:set-webrtc-remote-description offer-sdp :type :offer)

        ;; Create answer
        (multiple-value-bind (answer-sdp nil answer-error)
            (cl-telegram/api:create-webrtc-answer offer-sdp)
          (is (null answer-error) "Should create answer")

          (when answer-sdp
            ;; Get stats
            (let ((stats (cl-telegram/api:webrtc-stats)))
              (is (getf stats :state) "Should have state")
              (format t "Call stats: ~A~%" stats))))))))

(test test-webrtc-stats
  "Test WebRTC statistics"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-media-stream :audio t)
    (let ((stats (cl-telegram/api:webrtc-stats)))
      (is (getf stats :state) "Should have state")
      (is (getf stats :signaling-state) "Should have signaling state")
      (is (getf stats :has-local-stream) "Should have local stream status")
      (is (getf stats :pending-ice-candidates) "Should have ICE candidates count")
      (is (getf stats :data-channels) "Should have data channels count"))))

(test test-webrtc-test-connection
  "Test WebRTC connection test utility"
  (with-webrtc-test
    (let ((result (cl-telegram/api:test-webrtc-connection)))
      (is (getf result :success) "Test should pass")
      (format t "Test result: ~A~%" result))))

;;; ### Call Integration Tests

(test test-webrtc-start-call
  "Test starting WebRTC call"
  (with-webrtc-test
    ;; Mock call setup
    (let ((mock-call-id 12345))
      (multiple-value-bind (sdp error)
          (cl-telegram/api:start-webrtc-call mock-call-id :is-video nil)
        (is sdp "Should generate SDP")
        (is (stringp sdp) "SDP should be string")
        (is (search "v=0" sdp) "Should contain SDP version")))))

(test test-webrtc-accept-call
  "Test accepting WebRTC call"
  (with-webrtc-test
    ;; Create offer first
    (cl-telegram/api:create-webrtc-peer-connection)
    (cl-telegram/api:create-webrtc-media-stream :audio t)
    (multiple-value-bind (offer-sdp nil nil)
        (cl-telegram/api:create-webrtc-offer)
      (when offer-sdp
        ;; Accept call with offer
        (multiple-value-bind (answer-sdp error)
            (cl-telegram/api:accept-webrtc-call 12345 offer-sdp)
          (is answer-sdp "Should generate SDP answer")
          (is (stringp answer-sdp) "Answer should be string"))))))

(test test-webrtc-add-candidate-to-call
  "Test adding ICE candidate to call"
  (with-webrtc-test
    (cl-telegram/api:create-webrtc-peer-connection)
    (multiple-value-bind (success error)
        (cl-telegram/api:add-webrtc-candidate-to-call
         12345
         "candidate:1 1 UDP 1 192.168.1.1 5000 typ host"
         "0"
         0)
      ;; May fail without real connection
      (format t "Add candidate result: ~A ~A~%" success error))))
