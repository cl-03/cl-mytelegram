;;; file-management-enhanced-tests.lisp --- Tests for enhanced file management

(in-package #:cl-telegram/tests)

(def-suite* file-management-enhanced-tests
  :description "Tests for enhanced file management (v0.31.0)")

;;; ============================================================================
;;; Section 1: Upload Session Tests
;;; ============================================================================

(test test-make-upload-session
  "Test creating an upload session"
  (let ((session (cl-telegram/api:make-upload-session "/tmp/testfile.bin" :chunk-size 1048576)))
    (is (typep session 'cl-telegram/api::upload-session))
    (is (stringp (cl-telegram/api:upload-session-file-id session)))
    (is (= (cl-telegram/api:upload-session-part-size session) 1048576))
    (is (= (cl-telegram/api:upload-session-uploaded-parts session) 0))))

(test test-get-upload-status
  "Test getting upload status"
  (let ((session (cl-telegram/api:make-upload-session "/tmp/testfile.bin")))
    (let ((status (cl-telegram/api:get-upload-status (cl-telegram/api:upload-session-file-id session))))
      (is (listp status))
      (is (getf status :session-id))
      (is (getf status :file-name))
      (is (getf status :progress))))
  ;; Cleanup
  (cl-telegram/api:cancel-upload-session (cl-telegram/api:upload-session-file-id session)))

(test test-cancel-upload-session
  "Test cancelling an upload session"
  (let ((session (cl-telegram/api:make-upload-session "/tmp/testfile.bin")))
    (is (cl-telegram/api:get-upload-status (cl-telegram/api:upload-session-file-id session)))
    (is (eq (cl-telegram/api:cancel-upload-session (cl-telegram/api:upload-session-file-id session)) t))
    (is (null (cl-telegram/api:get-upload-status (cl-telegram/api:upload-session-file-id session))))))

;;; ============================================================================
;;; Section 2: Download Session Tests
;;; ============================================================================

(test test-make-download-session
  "Test creating a download session"
  (let ((session (cl-telegram/api:make-download-session "test_file_id" "/tmp/download.bin")))
    (is (typep session 'cl-telegram/api::download-session))
    (is (stringp (cl-telegram/api:download-session-file-id session)))
    (is (equal (cl-telegram/api:download-session-output-path session) "/tmp/download.bin")))
  ;; Note: Actual download would require a real file ID
  )

(test test-pause-resume-download
  "Test pausing and resuming a download"
  (let ((session (cl-telegram/api:make-download-session "test_file_id" "/tmp/download.bin")))
    (is (eq (cl-telegram/api:pause-download (cl-telegram/api:download-session-file-id session)) t))
    (is (eq (cl-telegram/api:resume-download (cl-telegram/api:download-session-file-id session)) t)))
  ;; Cleanup
  (remhash (cl-telegram/api:download-session-file-id session) cl-telegram/api::*download-sessions*))

;;; ============================================================================
;;; Section 3: Media Metadata Tests
;;; ============================================================================

(test test-get-media-metadata
  "Test getting media metadata"
  ;; This test requires a real file ID, so we just check the function exists
  (is (functionp #'cl-telegram/api:get-media-metadata)))

(test test-get-file-info
  "Test getting file info"
  ;; This test requires a real file ID
  (is (functionp #'cl-telegram/api:get-file-info)))

;;; ============================================================================
;;; Section 4: File Cache Tests
;;; ============================================================================

(test test-initialize-file-cache
  "Test initializing file cache"
  (let ((cache (cl-telegram/api:initialize-file-cache :cache-dir "/tmp/tg-test-cache"
                                                       :max-size (* 10 1024 1024))))
    (is (typep cache 'cl-telegram/api::file-cache))
    (is (equal (cl-telegram/api:file-cache-dir cache) "/tmp/tg-test-cache/"))
    (is (= (cl-telegram/api:file-cache-max-size cache) (* 10 1024 1024)))))

(test test-get-file-cache-stats
  "Test getting cache statistics"
  (cl-telegram/api:initialize-file-cache :cache-dir "/tmp/tg-test-cache2")
  (let ((stats (cl-telegram/api:get-file-cache-stats)))
    (is (listp stats))
    (is (getf stats :entry-count))
    (is (getf stats :total-size))
    (is (getf stats :max-size))))

(test test-clear-file-cache
  "Test clearing file cache"
  (cl-telegram/api:initialize-file-cache :cache-dir "/tmp/tg-test-cache3")
  (let ((result (cl-telegram/api:clear-file-cache)))
    (is (numberp result))))

;;; ============================================================================
;;; Section 5: Statistics Tests
;;; ============================================================================

(test test-get-active-uploads-stats
  "Test getting upload statistics"
  (let ((stats (cl-telegram/api:get-active-uploads-stats)))
    (is (listp stats))
    (is (getf stats :active-count))
    (is (getf stats :pending-count))
    (is (getf stats :completed-count))
    (is (getf stats :failed-count))))

(test test-get-active-downloads-stats
  "Test getting download statistics"
  (let ((stats (cl-telegram/api:get-active-downloads-stats)))
    (is (listp stats))
    (is (getf stats :active-count))
    (is (getf stats :downloading-count))
    (is (getf stats :paused-count))))

(test test-get-performance-file-stats
  "Test getting comprehensive file stats"
  (let ((stats (cl-telegram/api:get-performance-file-stats)))
    (is (listp stats))
    (is (getf stats :uploads))
    (is (getf stats :downloads))
    (is (getf stats :cache))))

;;; ============================================================================
;;; Section 6: Maintenance Tests
;;; ============================================================================

(test test-cleanup-stale-sessions
  "Test cleaning up stale sessions"
  (let ((cleaned (cl-telegram/api:cleanup-stale-sessions :max-age 3600)))
    (is (numberp cleaned))))

;;; ============================================================================
;;; Section 7: Initialization Tests
;;; ============================================================================

(test test-initialize-file-management-enhanced
  "Test initializing enhanced file management"
  (let ((result (cl-telegram/api:initialize-file-management-enhanced
                 :cache-dir "/tmp/tg-test-full-cache")))
    (is (eq result t))))

(test test-shutdown-file-management-enhanced
  "Test shutting down enhanced file management"
  (cl-telegram/api:initialize-file-management-enhanced)
  (let ((result (cl-telegram/api:shutdown-file-management-enhanced)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 8: Integration Tests
;;; ============================================================================

(test test-upload-session-workflow
  "Test complete upload session workflow"
  ;; Create a test file
  (let ((test-file "/tmp/test_upload.bin"))
    (with-open-file (stream test-file :direction :output
                                     :element-type '(unsigned-byte 8)
                                     :if-exists :supersede)
      (dotimes (i 1024)
        (write-byte (mod i 256) stream)))

    ;; Create session
    (let ((session (cl-telegram/api:make-upload-session test-file :chunk-size 256)))
      (is (typep session 'cl-telegram/api::upload-session))

      ;; Check status
      (let ((status (cl-telegram/api:get-upload-status (cl-telegram/api:upload-session-file-id session))))
        (format t "Upload status: ~A~%" status))

      ;; Cancel (we can't actually upload without a connection)
      (cl-telegram/api:cancel-upload-session (cl-telegram/api:upload-session-file-id session)))

    ;; Cleanup
    (uiop:delete-file-if-exists test-file)))

(test test-full-file-management-workflow
  "Test complete file management workflow"
  ;; Initialize
  (cl-telegram/api:initialize-file-management-enhanced :cache-dir "/tmp/tg-workflow-cache")

  ;; Check stats
  (let ((stats (cl-telegram/api:get-performance-file-stats)))
    (format t "File management stats: ~A~%" stats))

  ;; Cleanup
  (cl-telegram/api:shutdown-file-management-enhanced))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-file-management-enhanced-tests ()
  "Run all enhanced file management tests"
  (let ((results (run! 'file-management-enhanced-tests :if-fail :error)))
    (format t "~%~%=== Enhanced File Management Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
