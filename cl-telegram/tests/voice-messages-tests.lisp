;;; voice-messages-tests.lisp --- Tests for voice messages functionality

(in-package #:cl-telegram/tests)

(def-suite voice-messages-tests
  :description "Tests for voice messages functionality")

(in-suite voice-messages-tests)

;;; ### Voice Message Creation Tests

(test voice-message-class
  "Test voice-message class creation and accessors"
  (let ((voice (make-instance 'voice-message
                              :file-id "test-file-id"
                              :duration 30
                              :mime-type "audio/ogg"
                              :file-size 48000
                              :waveform '(100 150 200 180 120))))
    (is (string= "test-file-id" (voice-file-id voice)))
    (is (= 30 (voice-duration voice)))
    (is (string= "audio/ogg" (voice-mime-type voice)))
    (is (= 48000 (voice-file-size voice)))
    (is (equal '(100 150 200 180 120) (voice-waveform voice)))))

(test audio-message-class
  "Test audio-message class creation and accessors"
  (let ((audio (make-instance 'audio-message
                              :file-id "audio-file-id"
                              :duration 180
                              :mime-type "audio/mpeg"
                              :title "Test Song"
                              :performer "Test Artist")))
    (is (string= "audio-file-id" (audio-file-id audio)))
    (is (= 180 (audio-duration audio)))
    (is (string= "Test Song" (audio-title audio)))
    (is (string= "Test Artist" (audio-performer audio)))))

(test video-message-class
  "Test video-message class creation and accessors"
  (let ((video (make-instance 'video-message
                              :file-id "video-file-id"
                              :duration 60
                              :mime-type "video/mp4"
                              :width 640
                              :height 640
                              :has-audio t)))
    (is (string= "video-file-id" (video-file-id video)))
    (is (= 60 (video-duration video)))
    (is (= 640 (video-width video)))
    (is (= 640 (video-height video)))
    (is (true (video-has-audio video)))))

;;; ### Waveform Tests

(test generate-waveform
  "Test waveform generation"
  (let ((audio-data (loop for i from 0 below 1000 collect (sin (/ i 100.0))))
        (waveform (generate-waveform audio-data :width 64 :height 20)))
    (is (listp waveform))
    (is (= 64 (length waveform)))
    (is (every (lambda (v) (and (>= v 0) (<= v 255))) waveform))))

(test render-waveform-svg
  "Test waveform SVG rendering"
  (let ((waveform '(100 150 200 180 120 80 50 100))
        (svg (render-waveform-svg '(100 150 200 180 120) :width 200 :height 40)))
    (is (stringp svg))
    (is (search "<svg" svg))
    (is (search "</svg>" svg))
    (is (search "rect" svg))))

(test decode-encode-waveform
  "Test waveform base64 encoding/decoding"
  (let ((original '(100 150 200 180 120 80 50 100))
        (encoded (encode-waveform-to-base64 '(100 150 200 180 120 80 50 100)))
        (decoded nil))
    (is (stringp encoded))
    (setf decoded (decode-waveform-from-base64 encoded))
    (is (equal original decoded))))

;;; ### Recording State Tests

(test recording-state-class
  "Test recording-state class"
  (let ((state (make-instance 'recording-state)))
    (is (false (recording-is-active state)))
    (is (= 0 (recording-duration state)))
    (is (null (recording-waveform-data state)))))

(test cancel-voice-recording
  "Test voice recording cancellation"
  (setf (recording-is-active *recording-state*) t
        (recording-waveform-data *recording-state*) '(1 2 3)
        (recording-duration *recording-state*) 10)
  (let ((result (cancel-voice-recording)))
    (is (true result))
    (is (false (recording-is-active *recording-state*)))
    (is (null (recording-waveform-data *recording-state*)))
    (is (= 0 (recording-duration *recording-state*)))))

;;; ### Voice Chat Tests

(test voice-chat-class
  "Test voice-chat class creation and accessors"
  (let ((chat (make-instance 'voice-chat
                             :chat-id 12345
                             :is-active t
                             :participants '(1 2 3)
                             :start-date (get-universal-time)
                             :duration 0)))
    (is (= 12345 (voice-chat-chat-id chat)))
    (is (true (voice-chat-is-active chat)))
    (is (= '(1 2 3) (voice-chat-participants chat)))))

(test voice-chat-mute-toggle
  "Test voice chat mute toggle"
  (let ((chat (make-instance 'voice-chat :chat-id 12345 :is-active t)))
    (is (false (voice-chat-is-muted chat)))
    (setf (voice-chat-is-muted chat) t)
    (is (true (voice-chat-is-muted chat)))))

;;; ### Utility Tests

(test voice-message-duration-string
  "Test voice message duration formatting"
  (let ((voice (make-instance 'voice-message :file-id "test" :duration 90)))
    (is (string= "1:30" (voice-message-duration-string voice)))))

(test waveform-to-ascii
  "Test waveform ASCII conversion"
  (let ((ascii (waveform-to-ascii '(100 150 200 250))))
    (is (stringp ascii))))

(test clear-voice-cache
  "Test voice cache clearing"
  (setf (gethash "test-id" *voice-message-cache*) "test-value")
  (let ((result (clear-voice-cache)))
    (is (true result))
    (is (null (gethash "test-id" *voice-message-cache*)))))

;;; ### Integration Tests (require mock connection)

(test send-voice-message-mock
  "Test send-voice-message with mock connection (integration test)"
  ;; This test requires a mock connection setup
  ;; Skipped in unit test mode
  :depends-on '(voice-message-class))

(test record-and-send-voice-mock
  "Test recording and sending voice message (integration test)"
  ;; This test requires audio device mock
  ;; Skipped in unit test mode
  :depends-on '(recording-state-class))

;;; ### Test Runner

(defun run-voice-messages-tests ()
  "Run all voice messages tests"
  (run! 'voice-messages-tests))
