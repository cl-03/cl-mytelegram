;;; voip-tests.lisp --- Tests for VoIP and call functionality

(in-package #:cl-telegram/tests)

(def-suite* voip-tests
  :description "Tests for VoIP and call functionality")

;;; ### Helper Functions

(defvar *test-call-id* nil
  "Test call ID")

(defvar *test-group-call-id* nil
  "Test group call ID")

(defun teardown-test-calls ()
  "Clean up all test calls."
  (when *call-manager*
    ;; End all active calls
    (maphash (lambda (id call)
               (declare (ignore id))
               (cl-telegram/api:end-call call))
             (cl-telegram/api::call-manager-calls *call-manager*))
    ;; Leave all group calls
    (maphash (lambda (id group-call)
               (declare (ignore id))
               (cl-telegram/api:leave-group-call group-call))
             (cl-telegram/api::call-manager-group-calls *call-manager*)))
  (setf *test-call-id* nil)
  (setf *test-group-call-id* nil))

(defmacro with-test-calls (&body body)
  "Execute body with test calls cleanup."
  `(unwind-protect
       (progn ,@body)
    (teardown-test-calls)))

;;; ### Initialization Tests

(test test-init-voip
  "Test VoIP initialization"
  (with-test-calls
    (let ((result (cl-telegram/api:init-voip)))
      (is result "Should initialize VoIP")
      (is cl-telegram/api::*call-manager* "Call manager should be created")
      (is (typep cl-telegram/api::*call-manager* 'cl-telegram/api::call-manager)
          "Should be call-manager instance"))))

(test test-close-voip
  "Test VoIP shutdown"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((result (cl-telegram/api:close-voip)))
      (is result "Should close VoIP")
      (is (null cl-telegram/api::*call-manager*)
          "Call manager should be nil"))))

;;; ### Call Protocol Tests

(test test-make-call-protocol
  "Test call protocol creation"
  (let ((protocol (cl-telegram/api:make-call-protocol)))
    (is protocol "Should create protocol")
    (is (getf protocol :udp-p2p) "UDP P2P should be enabled by default")
    (is (getf protocol :udp-reflector) "UDP reflector should be enabled")
    (is (= (getf protocol :min-layer) 65) "Min layer should be 65")
    (is (= (getf protocol :max-layer) 104) "Max layer should be 104")))

(test test-make-call-protocol-custom
  "Test custom call protocol creation"
  (let ((protocol (cl-telegram/api:make-call-protocol
                   :udp-p2p nil
                   :udp-reflector t
                   :min-layer 70
                   :max-layer 110)))
    (is (not (getf protocol :udp-p2p)) "UDP P2P should be disabled")
    (is (getf protocol :udp-reflector) "UDP reflector should be enabled")
    (is (= (getf protocol :min-layer) 70) "Min layer should be 70")
    (is (= (getf protocol :max-layer) 110) "Max layer should be 110")))

;;; ### Call Manager Tests

(test test-make-call-manager
  "Test call manager creation"
  (let ((manager (cl-telegram/api:make-call-manager)))
    (is manager "Should create call manager")
    (is (typep manager 'cl-telegram/api::call-manager)
        "Should be call-manager instance")
    (is (typep (cl-telegram/api::call-manager-calls manager) 'hash-table)
        "Calls should be hash table")
    (is (typep (cl-telegram/api::call-manager-group-calls manager) 'hash-table)
        "Group calls should be hash table")))

;;; ### Individual Call Tests

(test test-create-call-not-authorized
  "Test call creation without authorization"
  ;; Ensure not authorized
  (cl-telegram/api:reset-auth-session)
  (multiple-value-bind (call error)
      (cl-telegram/api:create-call 12345)
    (is (null call) "Should not create call")
    (is (eq error :not-authorized) "Should return not-authorized error")))

(test test-get-call
  "Test getting call by ID"
  (with-test-calls
    (cl-telegram/api:init-voip)
    ;; Create a mock call
    (let ((call (make-instance 'cl-telegram/api::call
                               :call-id 999
                               :peer-user-id 12345
                               :state :active)))
      (setf (gethash 999 (cl-telegram/api::call-manager-calls
                          cl-telegram/api::*call-manager*))
            call)
      (let ((retrieved (cl-telegram/api:get-call 999)))
        (is retrieved "Should retrieve call")
        (is (= (cl-telegram/api::call-id retrieved) 999) "Call ID should match")
        (is (= (cl-telegram/api::call-peer-user-id retrieved) 12345)
            "Peer user ID should match")))))

(test test-list-active-calls
  "Test listing active calls"
  (with-test-calls
    (cl-telegram/api:init-voip)
    ;; Initially empty
    (let ((calls (cl-telegram/api:list-active-calls)))
      (is (null calls) "Should be empty initially"))
    ;; Add mock calls
    (let ((call1 (make-instance 'cl-telegram/api::call
                                :call-id 1
                                :peer-user-id 111))
          (call2 (make-instance 'cl-telegram/api::call
                                :call-id 2
                                :peer-user-id 222)))
      (setf (gethash 1 (cl-telegram/api::call-manager-calls
                        cl-telegram/api::*call-manager*))
            call1)
      (setf (gethash 2 (cl-telegram/api::call-manager-calls
                        cl-telegram/api::*call-manager*))
            call2)
      (let ((calls (cl-telegram/api:list-active-calls)))
        (is (= (length calls) 2) "Should have 2 calls")))))

(test test-toggle-call-mute
  "Test toggling call mute"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((call (make-instance 'cl-telegram/api::call
                               :call-id 1
                               :peer-user-id 123
                               :is-muted nil)))
      (setf (gethash 1 (cl-telegram/api::call-manager-calls
                        cl-telegram/api::*call-manager*))
            call)
      ;; Mute
      (let ((result (cl-telegram/api:toggle-call-mute 1 :muted t)))
        (is result "Should mute call")
        (is (cl-telegram/api::call-is-muted call) "Should be muted"))
      ;; Unmute
      (let ((result (cl-telegram/api:toggle-call-mute 1 :muted nil)))
        (is result "Should unmute call")
        (is (not (cl-telegram/api::call-is-muted call)) "Should not be muted")))))

(test test-toggle-call-video
  "Test toggling call video"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((call (make-instance 'cl-telegram/api::call
                               :call-id 1
                               :peer-user-id 123
                               :is-video-enabled nil)))
      (setf (gethash 1 (cl-telegram/api::call-manager-calls
                        cl-telegram/api::*call-manager*))
            call)
      ;; Enable video
      (let ((result (cl-telegram/api:toggle-call-video 1 :enabled t)))
        (is result "Should enable video")
        (is (cl-telegram/api::call-is-video-enabled call) "Video should be enabled"))
      ;; Disable video
      (let ((result (cl-telegram/api:toggle-call-video 1 :enabled nil)))
        (is result "Should disable video")
        (is (not (cl-telegram/api::call-is-video-enabled call))
            "Video should be disabled")))))

(test test-get-call-stats
  "Test getting call statistics"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((call (make-instance 'cl-telegram/api::call
                               :call-id 1
                               :peer-user-id 123
                               :state :active
                               :is-video t
                               :is-muted nil
                               :is-video-enabled t
                               :duration 120)))
      (setf (gethash 1 (cl-telegram/api::call-manager-calls
                        cl-telegram/api::*call-manager*))
            call)
      (let ((stats (cl-telegram/api:get-call-stats 1)))
        (is stats "Should return stats")
        (is (= (getf stats :call-id) 1) "Call ID should match")
        (is (eq (getf stats :state) :active) "State should match")
        (is (getf stats :is-video) "Should be video call")
        (is (= (getf stats :duration) 120) "Duration should match")))))

;;; ### Group Call Tests

(test test-get-group-call-not-found
  "Test getting non-existent group call"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((group-call (cl-telegram/api:get-group-call 999)))
      (is (null group-call) "Should return NIL for non-existent call"))))

(test test-list-active-group-calls
  "Test listing active group calls"
  (with-test-calls
    (cl-telegram/api:init-voip)
    ;; Initially empty
    (let ((calls (cl-telegram/api:list-active-group-calls)))
      (is (null calls) "Should be empty initially"))
    ;; Add mock group call
    (let ((group-call (make-instance 'cl-telegram/api::group-call
                                     :group-call-id 1
                                     :title "Test Call"
                                     :is-video-chat t)))
      (setf (gethash 1 (cl-telegram/api::call-manager-group-calls
                        cl-telegram/api::*call-manager*))
            group-call)
      (let ((calls (cl-telegram/api:list-active-group-calls)))
        (is (= (length calls) 1) "Should have 1 group call")))))

(test test-toggle-group-call-mute
  "Test toggling group call mute"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((group-call (make-instance 'cl-telegram/api::group-call
                                     :group-call-id 1
                                     :title "Test"
                                     :is-speaking t)))
      (setf (gethash 1 (cl-telegram/api::call-manager-group-calls
                        cl-telegram/api::*call-manager*))
            group-call)
      ;; Mute
      (let ((result (cl-telegram/api:toggle-group-call-mute 1 :muted t)))
        (is result "Should mute")
        (is (not (cl-telegram/api::group-call-is-speaking group-call))
            "Should not be speaking")))))

(test test-toggle-group-call-video
  "Test toggling group call video"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((group-call (make-instance 'cl-telegram/api::group-call
                                     :group-call-id 1
                                     :title "Test"
                                     :is-my-video-enabled nil)))
      (setf (gethash 1 (cl-telegram/api::call-manager-group-calls
                        cl-telegram/api::*call-manager*))
            group-call)
      ;; Enable video
      (let ((result (cl-telegram/api:toggle-group-call-video 1 :enabled t)))
        (is result "Should enable video")
        (is (cl-telegram/api::group-call-is-my-video-enabled group-call)
            "Video should be enabled")))))

(test test-get-group-call-stats
  "Test getting group call statistics"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((group-call (make-instance 'cl-telegram/api::group-call
                                     :group-call-id 1
                                     :title "Test Call"
                                     :is-video-chat t
                                     :is-active t
                                     :participant-count 5
                                     :duration 300
                                     :is-joined t)))
      (setf (gethash 1 (cl-telegram/api::call-manager-group-calls
                        cl-telegram/api::*call-manager*))
            group-call)
      (let ((stats (cl-telegram/api:get-group-call-stats 1)))
        (is stats "Should return stats")
        (is (= (getf stats :group-call-id) 1) "Group call ID should match")
        (is (getf stats :is-active) "Should be active")
        (is (= (getf stats :participant-count) 5) "Participant count should match")
        (is (getf stats :is-video-chat) "Should be video chat")
        (is (= (getf stats :duration) 300) "Duration should match")))))

;;; ### WebRTC Signaling Tests

(test test-generate-webrtc-offer
  "Test WebRTC offer generation"
  (let ((offer (cl-telegram/api:generate-webrtc-offer)))
    (is offer "Should generate offer")
    (is (stringp offer) "Should be string")
    (is (search "v=0" offer) "Should contain SDP version")
    (is (search "m=audio" offer) "Should contain audio media")))

(test test-generate-webrtc-answer
  "Test WebRTC answer generation"
  (let ((offer (cl-telegram/api:generate-webrtc-offer))
        (answer (cl-telegram/api:generate-webrtc-answer
                 (cl-telegram/api:generate-webrtc-offer))))
    (is answer "Should generate answer")
    (is (stringp answer) "Should be string")
    (is (search "v=0" answer) "Should contain SDP version")))

(test test-handle-ice-candidate
  "Test ICE candidate handling"
  (let ((candidate "candidate:1 1 UDP 1 192.168.1.1 5000 typ host"))
    (let ((result (cl-telegram/api:handle-ice-candidate candidate)))
      (is result "Should handle ICE candidate"))))

;;; ### Call Lifecycle Tests

(test test-call-lifecycle
  "Test complete call lifecycle"
  (with-test-calls
    (cl-telegram/api:init-voip)
    ;; Create mock call
    (let ((call (make-instance 'cl-telegram/api::call
                               :call-id 1
                               :peer-user-id 123
                               :state :pending
                               :is-video nil)))
      (setf (gethash 1 (cl-telegram/api::call-manager-calls
                        cl-telegram/api::*call-manager*))
            call)
      ;; Accept call
      (setf (cl-telegram/api::call-state call) :active)
      (setf (cl-telegram/api::call-start-date call) (get-universal-time))
      (is (eq (cl-telegram/api::call-state call) :active) "Should be active")
      ;; Toggle mute
      (cl-telegram/api:toggle-call-mute 1 :muted t)
      (is (cl-telegram/api::call-is-muted call) "Should be muted")
      ;; End call
      (setf (cl-telegram/api::call-state call) :ended)
      (setf (cl-telegram/api::call-end-date call) (get-universal-time))
      (setf (cl-telegram/api::call-duration call)
            (- (cl-telegram/api::call-end-date call)
               (cl-telegram/api::call-start-date call)))
      (is (eq (cl-telegram/api::call-state call) :ended) "Should be ended")
      (is (> (cl-telegram/api::call-duration call) 0) "Duration should be positive"))))

(test test-group-call-lifecycle
  "Test complete group call lifecycle"
  (with-test-calls
    (cl-telegram/api:init-voip)
    ;; Create mock group call
    (let ((group-call (make-instance 'cl-telegram/api::group-call
                                     :group-call-id 1
                                     :title "Test Group Call"
                                     :is-video-chat t
                                     :is-active t)))
      (setf (gethash 1 (cl-telegram/api::call-manager-group-calls
                        cl-telegram/api::*call-manager*))
            group-call)
      ;; Join call
      (setf (cl-telegram/api::group-call-is-joined group-call) t)
      (is (cl-telegram/api::group-call-is-joined group-call) "Should be joined")
      ;; Enable video
      (cl-telegram/api:toggle-group-call-video 1 :enabled t)
      (is (cl-telegram/api::group-call-is-my-video-enabled group-call)
          "Video should be enabled")
      ;; Leave call
      (setf (cl-telegram/api::group-call-is-joined group-call) nil)
      (is (not (cl-telegram/api::group-call-is-joined group-call))
          "Should not be joined"))))

;;; ### Update Handler Tests

(test test-handle-group-call-update
  "Test group call update handling"
  (with-test-calls
    (cl-telegram/api:init-voip)
    (let ((group-call (make-instance 'cl-telegram/api::group-call
                                     :group-call-id 1
                                     :title "Old Title"
                                     :participant-count 0)))
      (setf (gethash 1 (cl-telegram/api::call-manager-group-calls
                        cl-telegram/api::*call-manager*))
            group-call)
      ;; Simulate update
      (let ((update '(:group-call (:id 1 :is-active t :participant-count 5
                                        :title "New Title"))))
        (let ((result (cl-telegram/api::handle-group-call-update update)))
          (is result "Should handle update")
          (is (cl-telegram/api::group-call-is-active group-call)
              "Should be active")
          (is (= (cl-telegram/api::group-call-participant-count group-call) 5)
              "Participant count should update")
          (is (string= (cl-telegram/api::group-call-title group-call) "New Title")
              "Title should update"))))))

(test test-handle-group-call-participant-update
  "Test group call participant update handling"
  (let ((update '(:group-call-id 1 :participant
                  (:participant-id (:user-id 123) :is-speaking t))))
    (let ((result (cl-telegram/api::handle-group-call-participant-update update)))
      (is result "Should handle participant update"))))

(test test-handle-group-call-message-update
  "Test group call message update handling"
  (let ((update '(:group-call-id 1 :message
                  (:message-id 100 :sender-id (:user-id 123)
                   :date 1609459200 :text "Hello"))))
    (let ((result (cl-telegram/api::handle-group-call-message-update update)))
      (is result "Should handle message update"))))
