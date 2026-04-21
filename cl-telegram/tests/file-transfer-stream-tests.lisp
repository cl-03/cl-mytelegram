;;; file-transfer-stream-tests.lisp --- Tests for streaming file transfer

(in-package #:cl-telegram/tests)

(def-suite* file-transfer-stream-tests
  :description "Tests for streaming file transfer (v0.39.0)")

;;; ============================================================================
;;; Section 1: Transfer Stream Class Tests
;;; ============================================================================

(test test-transfer-stream-creation
  "Test creating a transfer-stream object"
  (let ((stream (make-instance 'cl-telegram/api::transfer-stream
                               :id "test_stream_1"
                               :type :download
                               :file-size 10240)))
    (is (string= (cl-telegram/api:transfer-stream-id stream) "test_stream_1"))
    (is (eq (cl-telegram/api:transfer-stream-type stream) :download))
    (is (= (cl-telegram/api:transfer-stream-file-size stream) 10240))))

(test test-download-stream-creation
  "Test creating a download-stream object"
  (let ((stream (make-instance 'cl-telegram/api::download-stream
                               :id "download_1"
                               :file-id "AgAD1234"
                               :file-size 5120
                               :dc-id 2)))
    (is (string= (cl-telegram/api:transfer-stream-id stream) "download_1"))
    (is (string= (cl-telegram/api:download-stream-dc-id stream) 2))
    (is (typep stream 'cl-telegram/api::download-stream))))

(test test-upload-stream-creation
  "Test creating an upload-stream object"
  (let ((stream (make-instance 'cl-telegram/api::upload-stream
                               :id "upload_1"
                               :file-name "test.txt"
                               :mime-type "text/plain"
                               :file-size 2048)))
    (is (string= (cl-telegram/api:transfer-stream-id stream) "upload_1"))
    (is (string= (cl-telegram/api:upload-stream-file-name stream) "test.txt"))
    (is (string= (cl-telegram/api:upload-stream-mime-type stream) "text/plain"))
    (is (typep stream 'cl-telegram/api::upload-stream))))

;;; ============================================================================
;;; Section 2: Download Stream Tests
;;; ============================================================================

(test test-create-download-stream
  "Test creating a download stream (mocked)"
  ;; This test would require a real connection, so we just verify the function exists
  (is (fboundp 'cl-telegram/api:create-download-stream)))

(test test-download-stream-chunk-size
  "Test download stream chunk size configuration"
  (let ((stream (make-instance 'cl-telegram/api::download-stream
                               :id "download_2"
                               :chunk-size 131072)))
    (is (= (cl-telegram/api:transfer-stream-chunk-size stream) 131072))))

(test test-close-download-stream
  "Test closing a download stream"
  (let ((stream (make-instance 'cl-telegram/api::download-stream
                               :id "download_3"
                               :file-id "test")))
    ;; Manually add to active streams for testing
    (setf (gethash (cl-telegram/api:transfer-stream-id stream)
                   cl-telegram/api::*active-streams*) stream)
    ;; Close should succeed
    (is (cl-telegram/api:close-download-stream stream))
    ;; Should be removed from active streams
    (is (null (gethash "download_3" cl-telegram/api::*active-streams*)))))

;;; ============================================================================
;;; Section 3: Upload Stream Tests
;;; ============================================================================

(test test-create-upload-stream-file-not-found
  "Test creating upload stream with non-existent file"
  (let ((result (cl-telegram/api:create-upload-stream "/nonexistent/file.txt")))
    (is (null result))))

(test test-upload-stream-chunk-size
  "Test upload stream chunk size configuration"
  (let ((stream (make-instance 'cl-telegram/api::upload-stream
                               :id "upload_2"
                               :chunk-size 32768
                               :total-parts 10)))
    (is (= (cl-telegram/api:transfer-stream-chunk-size stream) 32768))
    (is (= (cl-telegram/api:upload-stream-total-parts stream) 10))))

(test test-close-upload-stream
  "Test closing an upload stream"
  (let ((stream (make-instance 'cl-telegram/api::upload-stream
                               :id "upload_3"
                               :file-name "test.txt")))
    (setf (gethash (cl-telegram/api:transfer-stream-id stream)
                   cl-telegram/api::*active-streams*) stream)
    (is (cl-telegram/api:close-upload-stream stream))
    (is (null (gethash "upload_3" cl-telegram/api::*active-streams*)))))

;;; ============================================================================
;;; Section 4: Stream Control Tests
;;; ============================================================================

(test test-cancel-transfer-stream
  "Test cancelling a transfer stream"
  (let ((stream (make-instance 'cl-telegram/api::transfer-stream
                               :id "stream_cancel")))
    (setf (gethash (cl-telegram/api:transfer-stream-id stream)
                   cl-telegram/api::*active-streams*) stream)
    (is (cl-telegram/api:cancel-transfer-stream stream :reason "Test cancel"))
    (is (cl-telegram/api:transfer-stream-cancelled-p stream))
    (is (string= (cl-telegram/api:transfer-stream-error stream) "Test cancel"))))

(test test-pause-resume-transfer-stream
  "Test pausing and resuming a transfer stream"
  (let ((stream (make-instance 'cl-telegram/api::transfer-stream
                               :id "stream_pause")))
    (setf (gethash (cl-telegram/api:transfer-stream-id stream)
                   cl-telegram/api::*active-streams*) stream)
    (is (cl-telegram/api:pause-transfer-stream stream))
    (is (eq (cl-telegram/api:stream-transfer-status stream) :paused))
    (is (cl-telegram/api:resume-transfer-stream stream))
    (is (not (eq (cl-telegram/api:stream-transfer-status stream) :paused)))))

(test test-stream-transfer-status
  "Test stream status reporting"
  (let ((stream (make-instance 'cl-telegram/api::transfer-stream
                               :id "stream_status"
                               :type :download)))
    ;; Initial status
    (is (eq (cl-telegram/api:stream-transfer-status stream) :downloading))
    ;; Completed status
    (setf (cl-telegram/api:transfer-stream-completed-p stream) t)
    (is (eq (cl-telegram/api:stream-transfer-status stream) :completed))))

;;; ============================================================================
;;; Section 5: Stream Utilities Tests
;;; ============================================================================

(test test-get-stream
  "Test retrieving a stream by ID"
  (let ((stream (make-instance 'cl-telegram/api::transfer-stream
                               :id "stream_lookup")))
    (setf (gethash "stream_lookup" cl-telegram/api::*active-streams*) stream)
    (is (eq (cl-telegram/api:get-stream "stream_lookup") stream))
    ;; Cleanup
    (remhash "stream_lookup" cl-telegram/api::*active-streams*)))

(test test-list-active-streams
  "Test listing active streams"
  (let* ((stream1 (make-instance 'cl-telegram/api::transfer-stream :id "stream_list_1"))
         (stream2 (make-instance 'cl-telegram/api::transfer-stream :id "stream_list_2")))
    (setf (gethash "stream_list_1" cl-telegram/api::*active-streams*) stream1
          (gethash "stream_list_2" cl-telegram/api::*active-streams*) stream2)
    (let ((streams (cl-telegram/api:list-active-streams)))
      (is (>= (length streams) 2)))
    ;; Cleanup
    (remhash "stream_list_1" cl-telegram/api::*active-streams*)
    (remhash "stream_list_2" cl-telegram/api::*active-streams*)))

(test test-cleanup-completed-streams
  "Test cleaning up completed streams"
  (let* ((completed (make-instance 'cl-telegram/api::transfer-stream :id "stream_cleanup_1"))
         (active (make-instance 'cl-telegram/api::transfer-stream :id "stream_cleanup_2")))
    (setf (cl-telegram/api:transfer-stream-completed-p completed) t)
    (setf (gethash "stream_cleanup_1" cl-telegram/api::*active-streams*) completed
          (gethash "stream_cleanup_2" cl-telegram/api::*active-streams*) active)
    (let ((count (cl-telegram/api:cleanup-completed-streams)))
      (is (>= count 1)))
    ;; Completed stream should be removed
    (is (null (gethash "stream_cleanup_1" cl-telegram/api::*active-streams*))))

;;; ============================================================================
;;; Section 6: Stream Constants Tests
;;; ============================================================================

(test test-stream-chunk-size-default
  "Test default stream chunk size"
  (is (>= cl-telegram/api::*stream-chunk-size* 1024))
  (is (<= cl-telegram/api::*stream-chunk-size* (* 1024 1024))))

(test test-max-stream-buffer-size
  "Test maximum stream buffer size"
  (is (= cl-telegram/api::*max-stream-buffer-size* (* 10 1024 1024))))

;;; ============================================================================
;;; Section 7: Macro Tests
;;; ============================================================================

(test test-with-download-stream-macro-exists
  "Test that with-download-stream macro exists"
  (is (fboundp 'cl-telegram/api:with-download-stream)))

(test test-with-upload-stream-macro-exists
  "Test that with-upload-stream macro exists"
  (is (fboundp 'cl-telegram/api:with-upload-stream)))

;;; ============================================================================
;;; Section 8: Integration Tests
;;; ============================================================================

(test test-download-stream-type-predicate
  "Test download-stream type predicate"
  (let ((stream (make-instance 'cl-telegram/api::download-stream
                               :id "type_test")))
    (is (typep stream 'cl-telegram/api::download-stream))
    (is (typep stream 'cl-telegram/api::transfer-stream))))

(test test-upload-stream-type-predicate
  "Test upload-stream type predicate"
  (let ((stream (make-instance 'cl-telegram/api::upload-stream
                               :id "type_test_upload")))
    (is (typep stream 'cl-telegram/api::upload-stream))
    (is (typep stream 'cl-telegram/api::transfer-stream))))

(test test-transfer-stream-accessors
  "Test transfer-stream accessor functions"
  (let ((stream (make-instance 'cl-telegram/api::transfer-stream
                               :id "accessor_test"
                               :file-id "test_file_123"
                               :file-path "/tmp/test.bin"
                               :file-size 8192
                               :chunk-size 4096)))
    (is (string= (cl-telegram/api:transfer-stream-id stream) "accessor_test"))
    (is (= (cl-telegram/api:transfer-stream-position stream) 0))
    (is (null (cl-telegram/api:transfer-stream-completed-p stream)))
    (is (null (cl-telegram/api:transfer-stream-cancelled-p stream)))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-file-transfer-stream-tests ()
  "Run all file transfer stream tests"
  (let ((results (run! 'file-transfer-stream-tests :if-fail :error)))
    (format t "~%~%=== File Transfer Stream Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
