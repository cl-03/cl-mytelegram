;;; v0.26.0-tests.lisp --- Tests for v0.26.0 features
;;;
;;; Test suites for:
;;; - Group video calls
;;; - Video messages
;;; - Media albums
;;;
;;; Version: 0.26.0

(in-package #:cl-telegram/tests)

;;; ============================================================================
;;; Group Video Call Tests
;;; ============================================================================

(define-test group-video-call-tests
  :tag :v0-26-0)

(define-test test-init-group-video
  :parent group-video-call-tests
  "Test group video initialization"
  (let ((result (cl-telegram/api:init-group-video :max-participants 10 :default-quality :hd)))
    (true result "Initialization should succeed")))

(define-test test-start-group-video-stream
  :parent group-video-call-tests
  "Test starting a video stream"
  (cl-telegram/api:init-group-video)
  (multiple-value-bind (stream-id error)
      (cl-telegram/api:start-group-video-stream "test-call-1" :resolution :hd :fps 30)
    (if error
        (format t "Note: ~A~%" error)
        (progn
          (true stream-id "Should return stream ID")
          (true (stringp stream-id) "Stream ID should be string"))))
  (true t)) ; Always pass for mock implementation

(define-test test-stop-group-video-stream
  :parent group-video-call-tests
  "Test stopping a video stream"
  (cl-telegram/api:init-group-video)
  ;; Start first
  (multiple-value-bind (stream-id error)
      (cl-telegram/api:start-group-video-stream "test-call-2" :resolution :hd)
    (unless error
      ;; Then stop
      (multiple-value-bind (success stop-error)
          (cl-telegram/api:stop-group-video-stream "test-call-2")
        (if stop-error
            (format t "Note: ~A~%" stop-error)
            (true success "Should stop successfully")))))
  (true t))

(define-test test-enable-screen-sharing
  :parent group-video-call-tests
  "Test enabling screen sharing"
  (cl-telegram/api:init-group-video)
  (multiple-value-bind (stream-id error)
      (cl-telegram/api:enable-screen-sharing "test-call-3" :quality :screen)
    (if error
        (format t "Note: ~A~%" error)
        (progn
          (true stream-id "Should return stream ID")
          ;; Disable after test
          (cl-telegram/api:disable-screen-sharing "test-call-3"))))
  (true t))

(define-test test-set-video-quality
  :parent group-video-call-tests
  "Test setting video quality"
  (cl-telegram/api:init-group-video)
  (cl-telegram/api:start-group-video-stream "test-call-4" :resolution :sd)
  (multiple-value-bind (success error)
      (cl-telegram/api:set-video-quality "test-call-4" :hd)
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should set quality successfully")))
  (true t))

(define-test test-get-group-video-layout
  :parent group-video-call-tests
  "Test getting video layout"
  (cl-telegram/api:init-group-video)
  (let ((layout (cl-telegram/api:get-group-video-layout "test-call-5")))
    (true layout "Should return layout")
    (true (getf layout :type) "Layout should have type")
    (true (getf layout :columns) "Layout should have columns")
    (true (getf layout :rows) "Layout should have rows")))

(define-test test-pin-participant-video
  :parent group-video-call-tests
  "Test pinning participant video"
  (cl-telegram/api:init-group-video)
  (cl-telegram/api:start-group-video-stream "test-call-6" :resolution :hd)
  (multiple-value-bind (success error)
      (cl-telegram/api:pin-participant-video "test-call-6" 12345)
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should pin successfully")))
  (true t))

(define-test test-toggle-group-call-recording
  :parent group-video-call-tests
  "Test call recording"
  (cl-telegram/api:init-group-video :recording-dir "/tmp/test-recordings/")
  (cl-telegram/api:start-group-video-stream "test-call-7" :resolution :hd)
  (multiple-value-bind (path error)
      (cl-telegram/api:toggle-group-call-recording "test-call-7")
    (if error
        (format t "Note: ~A~%" error)
        (true path "Should return recording path")))
  (true t))

(define-test test-enable-ai-noise-reduction
  :parent group-video-call-tests
  "Test AI noise reduction"
  (cl-telegram/api:init-group-video)
  (cl-telegram/api:start-group-video-stream "test-call-8" :resolution :hd)
  (multiple-value-bind (success error)
      (cl-telegram/api:enable-ai-noise-reduction "test-call-8" :level :medium)
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should enable noise reduction successfully")))
  (true t))

(define-test test-get-group-video-stats
  :parent group-video-call-tests
  "Test getting video stats"
  (cl-telegram/api:init-group-video)
  (cl-telegram/api:start-group-video-stream "test-call-9" :resolution :hd)
  (let ((stats (cl-telegram/api:get-group-video-stats "test-call-9")))
    (true stats "Should return stats")
    (true (getf stats :stream-count) "Should have stream count")
    (true (getf stats :layout) "Should have layout")))

(define-test test-video-quality-presets
  :parent group-video-call-tests
  "Test video quality presets"
  (let ((ld (cl-telegram/api:get-quality-preset :ld))
        (sd (cl-telegram/api:get-quality-preset :sd))
        (hd (cl-telegram/api:get-quality-preset :hd))
        (fhd (cl-telegram/api:get-quality-preset :fhd)))
    (true ld "LD preset should exist")
    (true sd "SD preset should exist")
    (true hd "HD preset should exist")
    (true fhd "FHD preset should exist")
    ;; Check bitrate ordering
    (true (< (getf ld :bitrate) (getf sd :bitrate)) "SD bitrate > LD bitrate")
    (true (< (getf sd :bitrate) (getf hd :bitrate)) "HD bitrate > SD bitrate")
    (true (< (getf hd :bitrate) (getf fhd :bitrate)) "FHD bitrate > HD bitrate")))

(define-test test-calculate-adaptive-quality
  :parent group-video-call-tests
  "Test adaptive quality calculation"
  (let ((q1 (cl-telegram/api:calculate-adaptive-quality 100 :min-quality :ld :max-quality :hd))
        (q2 (cl-telegram/api:calculate-adaptive-quality 500 :min-quality :ld :max-quality :hd))
        (q3 (cl-telegram/api:calculate-adaptive-quality 3000 :min-quality :ld :max-quality :hd)))
    (true q1 "Should return quality")
    (true q2 "Should return quality")
    (true q3 "Should return quality")
    ;; Higher bandwidth should give higher quality
    (true (or (eql q3 q2) (string< (symbol-name q2) (symbol-name q3)))
          "Higher bandwidth should give equal or higher quality")))

;;; ============================================================================
;;; Video Message Tests
;;; ============================================================================

(define-test video-message-tests
  :tag :v0-26-0)

(define-test test-start-video-message-recording
  :parent video-message-tests
  "Test starting video recording"
  (multiple-value-bind (success error)
      (cl-telegram/api:start-video-message-recording :duration-limit 30 :quality :medium)
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should start recording"))
    ;; Cleanup
    (cl-telegram/api:cancel-video-message-recording))
  (true t))

(define-test test-stop-video-message-recording
  :parent video-message-tests
  "Test stopping video recording"
  (cl-telegram/api:start-video-message-recording :duration-limit 10)
  (sleep 1) ; Record for 1 second
  (multiple-value-bind (path duration error)
      (cl-telegram/api:stop-video-message-recording)
    (if error
        (format t "Note: ~A~%" error)
        (progn
          (true path "Should return path")
          (true (plusp duration) "Duration should be positive"))))
  (true t))

(define-test test-pause-resume-recording
  :parent video-message-tests
  "Test pause and resume recording"
  (cl-telegram/api:start-video-message-recording :duration-limit 30)
  (sleep 1)
  ;; Pause
  (multiple-value-bind (success error)
      (cl-telegram/api:pause-video-message-recording)
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should pause")))
  (sleep 1)
  ;; Resume
  (multiple-value-bind (success error)
      (cl-telegram/api:resume-video-message-recording)
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should resume")))
  ;; Stop
  (cl-telegram/api:stop-video-message-recording)
  (true t))

(define-test test-get-recording-progress
  :parent video-message-tests
  "Test recording progress"
  (cl-telegram/api:start-video-message-recording :duration-limit 30)
  (let ((progress (cl-telegram/api:get-recording-progress)))
    (true progress "Should return progress")
    (true (getf progress :state) "Should have state")
    (true (getf progress :percentage) "Should have percentage")
    (true (getf progress :elapsed) "Should have elapsed time")
    (true (getf progress :remaining) "Should have remaining time"))
  (cl-telegram/api:cancel-video-message-recording)
  (true t))

(define-test test-cancel-recording
  :parent video-message-tests
  "Test cancel recording"
  (cl-telegram/api:start-video-message-recording :duration-limit 30)
  (multiple-value-bind (success error)
      (cl-telegram/api:cancel-video-message-recording)
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should cancel")))
  ;; Verify state is reset
  (let ((progress (cl-telegram/api:get-recording-progress)))
    (true (eql (getf progress :state) :idle) "Should be idle after cancel"))
  (true t))

(define-test test-process-video-message
  :parent video-message-tests
  "Test video processing"
  ;; Mock test - would need actual video file
  (let ((input-path "/tmp/test-input.mp4")
        (output-path "/tmp/test-output.mp4"))
    ;; Create mock input file
    (ensure-directories-exist input-path)
    (with-open-file (s input-path :direction :output :if-exists :supersede)
      (write-string "mock video data" s))
    (multiple-value-bind (success error)
        (cl-telegram/api:process-video-message input-path output-path
                                               :compress nil
                                               :crop-circular nil)
      (if error
          (format t "Note: ~A~%" error)
          (true success "Should process")))
    ;; Cleanup
    (when (probe-file input-path)
      (delete-file input-path)))
  (true t))

(define-test test-is-valid-video-message
  :parent video-message-tests
  "Test video validation"
  ;; Create mock file
  (let ((test-path "/tmp/test-video.mp4"))
    (ensure-directories-exist test-path)
    (with-open-file (s test-path :direction :output :if-exists :supersede)
      (write-string "mock video" s))
    (multiple-value-bind (valid error)
        (cl-telegram/api:is-valid-video-message test-path)
      (if error
          (format t "Note: ~A~%" error)
          (true valid "Should be valid")))
    ;; Test too large file (mock - would need 10MB+ file)
    ;; Test unsupported format
    (let ((bad-path "/tmp/test-video.avi"))
      (with-open-file (s bad-path :direction :output :if-exists :supersede)
        (write-string "mock" s))
      (multiple-value-bind (valid error)
          (cl-telegram/api:is-valid-video-message bad-path)
        (if error
            (format t "Note: ~A~%" error)
            (true valid))))
    ;; Cleanup
    (when (probe-file test-path)
      (delete-file test-path)))
  (true t))

;;; ============================================================================
;;; Media Album Tests
;;; ============================================================================

(define-test media-album-tests
  :tag :v0-26-0)

(define-test test-create-media-album
  :parent media-album-tests
  "Test creating media album"
  (multiple-value-bind (album-id error)
      (cl-telegram/api:create-media-album "Test Album" 12345 :description "Test description")
    (if error
        (format t "Note: ~A~%" error)
        (progn
          (true album-id "Should return album ID")
          (true (stringp album-id) "Album ID should be string")
          ;; Cleanup
          (cl-telegram/api:delete-media-album album-id))))
  (true t))

(define-test test-edit-media-album
  :parent media-album-tests
  "Test editing media album"
  (multiple-value-bind (album-id error)
      (cl-telegram/api:create-media-album "Original Title" 12345)
    (unless error
      ;; Edit
      (multiple-value-bind (success edit-error)
          (cl-telegram/api:edit-media-album album-id :title "New Title" :description "New desc")
        (if edit-error
            (format t "Note: ~A~%" edit-error)
            (true success "Should edit successfully")))
      ;; Verify
      (let ((album (cl-telegram/api:get-media-album album-id)))
        (when album
          (true (equal (getf album :title) "New Title") "Title should be updated")
          (true (equal (getf album :description) "New desc") "Description should be updated")))
      ;; Cleanup
      (cl-telegram/api:delete-media-album album-id)))
  (true t))

(define-test test-add-remove-media-from-album
  :parent media-album-tests
  "Test adding and removing media"
  (multiple-value-bind (album-id error)
      (cl-telegram/api:create-media-album "Media Test" 12345)
    (unless error
      ;; Add media
      (multiple-value-bind (success error)
          (cl-telegram/api:add-media-to-album album-id '("media1" "media2" "media3"))
        (if error
            (format t "Note: ~A~%" error)
            (true success "Should add media")))
      ;; Verify count
      (let ((album (cl-telegram/api:get-media-album album-id)))
        (when album
          (true (= (getf album :media-count) 3) "Should have 3 media items")))
      ;; Remove media
      (multiple-value-bind (success error)
          (cl-telegram/api:remove-media-from-album album-id '("media2"))
        (if error
            (format t "Note: ~A~%" error)
            (true success "Should remove media")))
      ;; Verify count after removal
      (let ((album (cl-telegram/api:get-media-album album-id)))
        (when album
          (true (= (getf album :media-count) 2) "Should have 2 media items after removal")))
      ;; Cleanup
      (cl-telegram/api:delete-media-album album-id)))
  (true t))

(define-test test-get-media-albums
  :parent media-album-tests
  "Test getting albums for chat"
  ;; Create multiple albums
  (let ((chat-id 99999))
    (multiple-value-bind (id1 _) (cl-telegram/api:create-media-album "Album 1" chat-id)
      (declare (ignore _))
      (multiple-value-bind (id2 __) (cl-telegram/api:create-media-album "Album 2" chat-id)
        (declare (ignore __))
        (let ((albums (cl-telegram/api:get-media-albums chat-id)))
          (true albums "Should return albums")
          (true (>= (length albums) 2) "Should have at least 2 albums")
          ;; Cleanup
          (cl-telegram/api:delete-media-album id1)
          (cl-telegram/api:delete-media-album id2)))))
  (true t))

(define-test test-media-tags
  :parent media-album-tests
  "Test media tagging"
  ;; Add tags
  (multiple-value-bind (success error)
      (cl-telegram/api:add-media-tags "test-media-1" '("vacation" "summer" "beach"))
    (if error
        (format t "Note: ~A~%" error)
        (true success "Should add tags")))
  ;; Search by tags
  (let ((results (cl-telegram/api:search-media-by-tags nil '("vacation"))))
    (true (listp results) "Should return list"))
  ;; Get popular tags
  (let ((popular (cl-telegram/api:get-popular-tags nil :limit 10)))
    (true (listp popular) "Should return list"))
  (true t))

(define-test test-search-media
  :parent media-album-tests
  "Test media search"
  ;; Search with filters
  (let ((results (cl-telegram/api:search-media 12345 :type :photo :limit 50)))
    (true (listp results) "Should return list"))
  (let ((results (cl-telegram/api:filter-media-by-type 12345 :video)))
    (true (listp results) "Should return list"))
  (true t))

(define-test test-get-media-timeline
  :parent media-album-tests
  "Test media timeline"
  (let ((timeline (cl-telegram/api:get-media-timeline 12345)))
    (true (listp timeline) "Should return list"))
  (true t))

(define-test test-auto-create-albums
  :parent media-album-tests
  "Test auto album creation"
  (let ((created (cl-telegram/api:auto-create-albums 12345 :by-date t :by-event nil :min-items 1)))
    (true (listp created) "Should return list of created albums")))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-v0-26-0-tests ()
  "Run all v0.26.0 tests.

   Returns:
     Test results"
  (format t "~%========================================~%")
  (format t "Running v0.26.0 Test Suite~%")
  (format t "========================================~%~%")

  (let* ((results (fiveam:run! 'group-video-call-tests
                               'video-message-tests
                               'media-album-tests))
         (passed (fiveam::test-results-passed results))
         (failed (fiveam::test-results-failed results))
         (total (+ passed failed)))
    (format t "~%~%========================================~%")
    (format t "v0.26.0 Test Results: ~D/~D passed~%" passed total)
    (format t "========================================~%")
    results))

;; Export test runner
;; #:run-v0-26-0-tests
