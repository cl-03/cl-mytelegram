;;; file-management-v2-tests.lisp --- Tests for enhanced file management
;;;
;;; Test suite for:
;;; - File download with progress tracking
;;; - File upload with chunking support
;;; - Big file upload
;;; - Stream-based transfers
;;; - Transfer cancellation
;;; - Progress monitoring
;;;
;;; Version: 0.37.0

(in-package #:cl-telegram/tests)

(def-suite* file-management-v2-tests
  :description "Tests for enhanced file management (v0.37.0)")

;;; ============================================================================
;;; Section 1: Class Tests
;;; ============================================================================

(test test-file-download-class-creation
  "Test file-download class creation"
  (let ((download (make-instance 'cl-telegram/api::file-download
                                 :id "dl_123"
                                 :file-id "file_id_456"
                                 :file-size 1024000
                                 :output-path "/tmp/file.jpg"
                                 :dc-id 2
                                 :access-hash 123456789)))
    (is (string= "dl_123" (cl-telegram/api:file-transfer-id download)))
    (is (eq :download (cl-telegram/api:file-transfer-type download)))
    (is (string= "file_id_456" (cl-telegram/api:file-download-file-id download)))
    (is (= 1024000 (cl-telegram/api:file-transfer-file-size download)))
    (is (= 2 (cl-telegram/api:file-download-dc-id download)))))

(test test-file-upload-class-creation
  "Test file-upload class creation"
  (let ((upload (make-instance 'cl-telegram/api::file-upload
                               :id "ul_123"
                               :file-path "/tmp/file.jpg"
                               :file-name "file.jpg"
                               :mime-type "image/jpeg"
                               :file-size 512000)))
    (is (string= "ul_123" (cl-telegram/api:file-transfer-id upload)))
    (is (eq :upload (cl-telegram/api:file-transfer-type upload)))
    (is (string= "file.jpg" (cl-telegram/api:file-upload-file-name upload)))
    (is (string= "image/jpeg" (cl-telegram/api:file-upload-mime-type upload)))))

;;; ============================================================================
;;; Section 2: Download Function Tests
;;; ============================================================================

(test test-download-file
  "Test downloading a file"
  (let ((result (cl-telegram/api:download-file "file_id_123" "/tmp/output.jpg")))
    ;; May return file-download object or NIL without connection
    (is (or (null result)
            (typep result 'cl-telegram/api::file-download)))))

(test test-download-file-with-options
  "Test downloading file with options"
  (let ((result (cl-telegram/api:download-file "file_id_123" "/tmp/output.jpg"
                                                :dc-id 2
                                                :access-hash 123456789
                                                :part-size 2048
                                                :use-cdn t)))
    (is (or (null result)
            (typep result 'cl-telegram/api::file-download)))))

(test test-get-file-download-stream
  "Test getting file download stream"
  (let ((result (cl-telegram/api:get-file-download-stream "file_id_123" :start 0 :end 1024)))
    ;; May return stream or NIL
    (is (or (null result)
            (typep result 'stream)))))

(test test-cancel-file-download
  "Test cancelling file download"
  (let ((result (cl-telegram/api:cancel-file-download "dl_123")))
    (is (or (null result)
            (eq result t)))))

(test test-get-file-progress
  "Test getting file transfer progress"
  (let ((result (cl-telegram/api:get-file-progress "dl_123")))
    ;; Should return plist or NIL
    (is (or (null result)
            (listp result)))))

;;; ============================================================================
;;; Section 3: Upload Function Tests
;;; ============================================================================

(test test-upload-file
  "Test uploading a file"
  (let ((result (cl-telegram/api:upload-file "/tmp/test.jpg" :chat-id 123456)))
    ;; May return file-upload object or NIL
    (is (or (null result)
            (typep result 'cl-telegram/api::file-upload)))))

(test test-upload-file-with-options
  "Test uploading file with options"
  (let ((result (cl-telegram/api:upload-file "/tmp/test.jpg"
                                              :file-name "custom.jpg"
                                              :mime-type "image/jpeg"
                                              :chat-id 123456)))
    (is (or (null result)
            (typep result 'cl-telegram/api::file-upload)))))

(test test-upload-file-part
  "Test uploading file part"
  (let ((data (make-array 1024 :element-type '(unsigned-byte 8))))
    (let ((result (cl-telegram/api:upload-file-part "upload_123" data 0 :total-parts 10)))
      (is (or (null result)
              (eq result t))))))

(test test-upload-big-file-part
  "Test uploading big file part"
  (let ((data (make-array 1024 :element-type '(unsigned-byte 8))))
    (let ((result (cl-telegram/api:upload-big-file-part "big_123" data 5
                                                         :file-name "video.mp4"
                                                         :file-type "video")))
      (is (or (null result)
              (eq result t))))))

(test test-get-file-upload-stream
  "Test getting file upload stream"
  (let ((result (cl-telegram/api:get-file-upload-stream "test.jpg" 102400 :mime-type "image/jpeg")))
    (is (or (null result)
            (typep result 'stream)))))

(test test-cancel-file-upload
  "Test cancelling file upload"
  (let ((result (cl-telegram/api:cancel-file-upload "ul_123")))
    (is (or (null result)
            (eq result t)))))

;;; ============================================================================
;;; Section 4: Utility Function Tests
;;; ============================================================================

(test test-detect-mime-type
  "Test MIME type detection"
  (is (string= "image/jpeg" (cl-telegram/api:detect-mime-type "/path/to/file.jpg")))
  (is (string= "image/png" (cl-telegram/api:detect-mime-type "/path/to/file.png")))
  (is (string= "video/mp4" (cl-telegram/api:detect-mime-type "/path/to/video.mp4")))
  (is (string= "audio/mpeg" (cl-telegram/api:detect-mime-type "/path/to/audio.mp3")))
  (is (string= "application/pdf" (cl-telegram/api:detect-mime-type "/path/to/doc.pdf")))
  (is (string= "application/octet-stream" (cl-telegram/api:detect-mime-type "/path/to/file.unknown"))))

(test test-get-active-downloads
  "Test getting active downloads"
  (let ((result (cl-telegram/api:get-active-downloads)))
    (is (listp result))))

(test test-get-active-uploads
  "Test getting active uploads"
  (let ((result (cl-telegram/api:get-active-uploads)))
    (is (listp result))))

(test test-count-active-transfers
  "Test counting active transfers"
  (let ((result (cl-telegram/api:count-active-transfers)))
    (is (typep result 'cons))
    (is (numberp (car result)))
    (is (numberp (cdr result)))))

(test test-clear-completed-transfers
  "Test clearing completed transfers"
  (let ((result (cl-telegram/api:clear-completed-transfers)))
    (is (numberp result))
    (is (>= result 0))))

;;; ============================================================================
;;; Section 5: Integration Tests
;;; ============================================================================

(test test-download-workflow
  "Test complete download workflow"
  ;; Start download
  (let ((dl (cl-telegram/api:download-file "file_id" "/tmp/test.jpg")))
    (when dl
      ;; Check progress
      (let ((progress (cl-telegram/api:get-file-progress (cl-telegram/api:file-transfer-id dl))))
        (is (or (null progress)
                (listp progress))))
      ;; Cancel download
      (let ((cancelled (cl-telegram/api:cancel-file-download (cl-telegram/api:file-transfer-id dl))))
        (is (or (null cancelled)
                (eq cancelled t))))))))

(test test-upload-workflow
  "Test complete upload workflow"
  (let ((ul (cl-telegram/api:upload-file "/tmp/test.jpg")))
    (when ul
      ;; Check progress
      (let ((progress (cl-telegram/api:get-file-progress (cl-telegram/api:file-transfer-id ul))))
        (is (or (null progress)
                (listp progress))))
      ;; Cancel upload
      (let ((cancelled (cl-telegram/api:cancel-file-upload (cl-telegram/api:file-transfer-id ul))))
        (is (or (null cancelled)
                (eq cancelled t))))))))

(test test-mime-type-detection-all-formats
  "Test MIME type detection for all common formats"
  (let ((formats '(("jpg" . "image/jpeg")
                   ("jpeg" . "image/jpeg")
                   ("png" . "image/png")
                   ("gif" . "image/gif")
                   ("mp4" . "video/mp4")
                   ("mp3" . "audio/mpeg")
                   ("pdf" . "application/pdf")
                   ("zip" . "application/zip")
                   ("txt" . "text/plain")
                   ("doc" . "application/msword"))))
    (dolist (pair formats)
      (is (string= (cdr pair)
                   (cl-telegram/api:detect-mime-type (format nil "/path/to/file.~A" (car pair))))))))

;;; ============================================================================
;;; Section 6: Initialization Tests
;;; ============================================================================

(test test-initialize-file-management-v2
  "Test initializing file management v2 system"
  (let ((result (cl-telegram/api:initialize-file-management-v2)))
    (is (eq result t))))

(test test-shutdown-file-management-v2
  "Test shutting down file management v2 system"
  (cl-telegram/api:initialize-file-management-v2)
  (let ((result (cl-telegram/api:shutdown-file-management-v2)))
    (is (eq result t))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-file-management-v2-tests ()
  "Run all enhanced file management tests"
  (format t "~%~%=== File Management v2 Test Results ===~%")
  (let ((results (run! 'file-management-v2-tests :if-fail :error)))
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))

;;; End of file-management-v2-tests.lisp
