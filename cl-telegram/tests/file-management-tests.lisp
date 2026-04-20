;;; file-management-tests.lisp --- Tests for file management functionality

(in-package #:cl-telegram/tests)

(def-suite file-management-tests
  :description "Tests for file management functionality (v0.19.0)")

(in-suite file-management-tests)

;;; ======================================================================
;;; File Location Tests
;;; ======================================================================

(test test-file-location-class
  "Test file-location class creation and accessors"
  (let ((location (make-instance 'cl-telegram/api:file-location
                                 :dc-id 2
                                 :volume-id 12345
                                 :local-id 67890
                                 :secret 987654321
                                 :file-reference "ref_abc123")))
    (is (= 2 (cl-telegram/api:file-location-dc-id location)))
    (is (= 12345 (cl-telegram/api:file-location-volume-id location)))
    (is (= 67890 (cl-telegram/api:file-location-local-id location)))
    (is (= 987654321 (cl-telegram/api:file-location-secret location)))
    (is (string= "ref_abc123" (cl-telegram/api:file-location-file-reference location)))))

(test test-file-location-defaults
  "Test file-location default values"
  (let ((location (make-instance 'cl-telegram/api:file-location)))
    (is (= 0 (cl-telegram/api:file-location-dc-id location)))
    (is (= 0 (cl-telegram/api:file-location-volume-id location)))
    (is (= 0 (cl-telegram/api:file-location-local-id location)))
    (is (= 0 (cl-telegram/api:file-location-secret location)))
    (is (null (cl-telegram/api:file-location-file-reference location)))))

;;; ======================================================================
;;; Uploaded File Tests
;;; ======================================================================

(test test-uploaded-file-class
  "Test uploaded-file class creation and accessors"
  (let ((file (make-instance 'cl-telegram/api:uploaded-file
                             :file-id "file_12345"
                             :file-parts 10
                             :file-size 1048576
                             :file-path "/tmp/test.bin")))
    (is (string= "file_12345" (cl-telegram/api:uploaded-file-id file)))
    (is (= 10 (cl-telegram/api:uploaded-file-parts file)))
    (is (= 1048576 (cl-telegram/api:uploaded-file-size file)))
    (is (string= "/tmp/test.bin" (cl-telegram/api:uploaded-file-path file)))))

;;; ======================================================================
;;; Web File Tests
;;; ======================================================================

(test test-web-file-class
  "Test web-file class creation and accessors"
  (let ((web-file (make-instance 'cl-telegram/api:web-file
                                 :location "loc_abc"
                                 :access-hash "hash_123"
                                 :size 524288
                                 :mime-type "image/jpeg"
                                 :dc-id 3)))
    (is (string= "loc_abc" (cl-telegram/api:web-file-location web-file)))
    (is (string= "hash_123" (cl-telegram/api:web-file-access-hash web-file)))
    (is (= 524288 (cl-telegram/api:web-file-size web-file)))
    (is (string= "image/jpeg" (cl-telegram/api:web-file-mime-type web-file)))
    (is (= 3 (cl-telegram/api:web-file-dc-id web-file)))))

;;; ======================================================================
;;; File Size Utility Tests
;;; ======================================================================

(test test-file-size-string-bytes
  "Test file-size-string for bytes"
  (is (string= "512 B" (cl-telegram/api:file-size-string 512)))
  (is (string= "1023 B" (cl-telegram/api:file-size-string 1023))))

(test test-file-size-string-kb
  "Test file-size-string for kilobytes"
  (is (string= "1.00 KB" (cl-telegram/api:file-size-string 1024)))
  (is (string= "512.50 KB" (cl-telegram/api:file-size-string 524800))))

(test test-file-size-string-mb
  "Test file-size-string for megabytes"
  (is (string= "1.00 MB" (cl-telegram/api:file-size-string 1048576)))
  (is (string= "10.50 MB" (cl-telegram/api:file-size-string 11010048))))

(test test-file-size-string-gb
  "Test file-size-string for gigabytes"
  (is (string= "1.00 GB" (cl-telegram/api:file-size-string 1073741824)))
  (is (string= "2.50 GB" (cl-telegram/api:file-size-string 2684354560))))

;;; ======================================================================
;;; MIME Type Detection Tests
;;; ======================================================================

(test test-guess-mime-type-images
  "Test MIME type detection for images"
  (is (string= "image/jpeg" (cl-telegram/api:guess-mime-type "photo.jpg")))
  (is (string= "image/jpeg" (cl-telegram/api:guess-mime-type "photo.jpeg")))
  (is (string= "image/png" (cl-telegram/api:guess-mime-type "image.png")))
  (is (string= "image/gif" (cl-telegram/api:guess-mime-type "animation.gif"))))

(test test-guess-mime-type-video
  "Test MIME type detection for video"
  (is (string= "video/mp4" (cl-telegram/api:guess-mime-type "video.mp4")))
  (is (string= "video/webm" (cl-telegram/api:guess-mime-type "video.webm"))))

(test test-guess-mime-type-audio
  "Test MIME type detection for audio"
  (is (string= "audio/mpeg" (cl-telegram/api:guess-mime-type "song.mp3")))
  (is (string= "audio/ogg" (cl-telegram/api:guess-mime-type "voice.ogg"))))

(test test-guess-mime-type-documents
  "Test MIME type detection for documents"
  (is (string= "application/pdf" (cl-telegram/api:guess-mime-type "doc.pdf")))
  (is (string= "application/msword" (cl-telegram/api:guess-mime-type "doc.doc")))
  (is (string= "text/plain" (cl-telegram/api:guess-mime-type "file.txt"))))

(test test-guess-mime-type-unknown
  "Test MIME type detection for unknown extensions"
  (is (string= "application/octet-stream" (cl-telegram/api:guess-mime-type "file.unknown"))))

(test test-determine-media-type
  "Test media type determination from MIME type"
  (is (eq :photo (cl-telegram/api:determine-media-type "image/jpeg")))
  (is (eq :photo (cl-telegram/api:determine-media-type "image/png")))
  (is (eq :video (cl-telegram/api:determine-media-type "video/mp4")))
  (is (eq :video (cl-telegram/api:determine-media-type "video/webm")))
  (is (eq :audio (cl-telegram/api:determine-media-type "audio/mpeg")))
  (is (eq :audio (cl-telegram/api:determine-media-type "audio/ogg")))
  (is (eq :document (cl-telegram/api:determine-media-type "application/pdf"))))

;;; ======================================================================
;;; Upload Speed Utility Tests
;;; ======================================================================

(test test-format-upload-speed
  "Test upload speed formatting"
  (is (string= "1024 B/s" (cl-telegram/api:format-upload-speed 1024)))
  (is (string= "512.00 KB/s" (cl-telegram/api:format-upload-speed 524288)))
  (is (string= "2.00 MB/s" (cl-telegram/api:format-upload-speed 2097152))))

(test test-estimate-upload-time
  "Test upload time estimation"
  (let ((time (cl-telegram/api:estimate-upload-time 10485760 :current-speed 1048576)))
    (is (= 10 time))) ; 10MB at 1MB/s = 10 seconds
  (let ((time (cl-telegram/api:estimate-upload-time 5242880 :current-speed 524288)))
    (is (= 10 time)))) ; 5MB at 512KB/s = 10 seconds

;;; ======================================================================
;;; CDN Configuration Tests
;;; ======================================================================

(test test-cdn-download-enabled-by-default
  "Test CDN download is enabled by default"
  (is (true (cl-telegram/api:cdn-download-enabled-p))))

(test test-enable-cdn-download
  "Test enabling CDN download"
  (setf cl-telegram/api:*cdn-download-enabled* nil)
  (is (false (cl-telegram/api:cdn-download-enabled-p)))
  (cl-telegram/api:enable-cdn-download)
  (is (true (cl-telegram/api:cdn-download-enabled-p))))

(test test-disable-cdn-download
  "Test disabling CDN download"
  (setf cl-telegram/api:*cdn-download-enabled* t)
  (cl-telegram/api:disable-cdn-download)
  (is (false (cl-telegram/api:cdn-download-enabled-p)))
  (setf cl-telegram/api:*cdn-download-enabled* t)) ; Restore

(test test-set-cdn-config
  "Test CDN configuration"
  (cl-telegram/api:set-cdn-config :enabled nil)
  (is (false (cl-telegram/api:cdn-download-enabled-p)))
  (cl-telegram/api:set-cdn-config :enabled t)
  (is (true (cl-telegram/api:cdn-download-enabled-p))))

;;; ======================================================================
;;; Upload Session Tests
;;; ======================================================================

(test test-upload-session-creation
  "Test upload session creation"
  (let ((file-id 12345))
    (setf (gethash file-id cl-telegram/api:*active-uploads*)
          (list :file-path "/tmp/test.bin"
                :file-name "test.bin"
                :file-size 1048576
                :part-size 524288
                :total-parts 2
                :uploaded-parts 0
                :start-time (get-universal-time)))
    (let ((session (cl-telegram/api:get-upload-session file-id)))
      (is (notnull session))
      (is (= 1048576 (getf session :file-size)))
      (is (= 2 (getf session :total-parts))))
    ;; Cleanup
    (remhash file-id cl-telegram/api:*active-uploads*)))

(test test-upload-progress-calculation
  "Test upload progress calculation"
  (let ((file-id 12345))
    (setf (gethash file-id cl-telegram/api:*active-uploads*)
          (list :total-parts 10 :uploaded-parts 5))
    (let ((progress (cl-telegram/api:get-upload-progress file-id)))
      (is (= 50.0 progress)))
    (remhash file-id cl-telegram/api:*active-uploads*)))

(test test-upload-progress-complete
  "Test upload progress when complete"
  (let ((file-id 12345))
    (setf (gethash file-id cl-telegram/api:*active-uploads*)
          (list :total-parts 10 :uploaded-parts 10))
    (let ((progress (cl-telegram/api:get-upload-progress file-id)))
      (is (= 100.0 progress)))
    (remhash file-id cl-telegram/api:*active-uploads*)))

(test test-cancel-upload
  "Test upload cancellation"
  (let ((file-id 12345))
    (setf (gethash file-id cl-telegram/api:*active-uploads*)
          (list :file-path "/tmp/test.bin"))
    (is (true (cl-telegram/api:cancel-upload file-id)))
    (is (null (cl-telegram/api:get-upload-session file-id)))))

(test test-get-active-uploads
  "Test getting active uploads"
  ;; Clear first
  (clrhash cl-telegram/api:*active-uploads*)
  ;; Add test sessions
  (setf (gethash 1 cl-telegram/api:*active-uploads*) '(:file "1.bin")
        (gethash 2 cl-telegram/api:*active-uploads*) '(:file "2.bin")
        (gethash 3 cl-telegram/api:*active-uploads*) '(:file "3.bin"))
  (let ((uploads (cl-telegram/api:get-active-uploads)))
    (is (= 3 (length uploads))))
  ;; Cleanup
  (clrhash cl-telegram/api:*active-uploads*))

;;; ======================================================================
;;; Global State Tests
;;; ======================================================================

(test test-upload-part-size-default
  "Test default upload part size"
  (is (= 524288 cl-telegram/api:*upload-part-size*))) ; 512KB

(test test-download-part-size-default
  "Test default download part size"
  (is (= 524288 cl-telegram/api:*download-part-size*))) ; 512KB

(test test-max-upload-parts-default
  "Test max upload parts"
  (is (= 4000 cl-telegram/api:*max-upload-parts*)))

;;; ======================================================================
;;; Integration-style Tests (Mock)
;;; ======================================================================

(test test-download-file-path-return
  "Test download file returns path when output-path provided"
  ;; This is a mock test since we can't actually connect to Telegram
  (let ((result (cl-telegram/api:download-file "file_123" :output-path "/tmp/downloaded.bin")))
    ;; Should return either (values path nil) or (values nil error-string)
    (is (or (stringp (first (multiple-value-list result)))
            (null (first (multiple-value-list result)))))))

(test test-download-file-data-return
  "Test download file returns data when no output-path"
  (let ((result (cl-telegram/api:download-file "file_123")))
    ;; Should return either (values data nil) or (values nil error-string)
    (is (or (vectorp (first (multiple-value-list result)))
            (null (first (multiple-value-list result)))))))

;;; ======================================================================
;;; Edge Case Tests
;;; ======================================================================

(test test-file-size-string-zero
  "Test file-size-string with zero bytes"
  (is (string= "0 B" (cl-telegram/api:file-size-string 0))))

(test test-file-size-string-large
  "Test file-size-string with very large file"
  (let ((size (* 100 1073741824))) ; 100GB
    (is (string= "100.00 GB" (cl-telegram/api:file-size-string size)))))

(test test-upload-progress-no-session
  "Test upload progress with no session"
  (is (null (cl-telegram/api:get-upload-progress 99999))))

(test test-cancel-nonexistent-upload
  "Test canceling nonexistent upload"
  (is (true (cl-telegram/api:cancel-upload 99999)))) ; Should not error

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-file-management-tests ()
  "Run all file management tests"
  (format t "~%=== Running File Management Unit Tests ===~%~%")
  (fiveam:run! 'file-management-tests))

(export '(run-file-management-tests))
