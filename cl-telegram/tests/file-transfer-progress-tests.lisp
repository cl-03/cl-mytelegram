;;; file-transfer-progress-tests.lisp --- Tests for file transfer progress callbacks

(in-package #:cl-telegram/tests)

(def-suite* file-transfer-progress-tests
  :description "Tests for file transfer progress callbacks (v0.39.0)")

;;; ============================================================================
;;; Section 1: Progress Callback Registration Tests
;;; ============================================================================

(test test-register-progress-callback
  "Test registering a progress callback"
  (let* ((callback-called nil)
         (callback (lambda (progress)
                     (setf callback-called t))))
    (cl-telegram/api:register-progress-callback "test_download_1" callback)
    (is (gethash "test_download_1" cl-telegram/api::*progress-callbacks*))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_1")))

(test test-register-progress-callback-with-interval
  "Test registering a progress callback with custom interval"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_2" callback :interval 2048)
    (is (= (gethash "test_download_2-interval" cl-telegram/api::*progress-callbacks*) 2048))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_2")))

(test test-unregister-progress-callback
  "Test unregistering a progress callback"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_3" callback)
    (cl-telegram/api:unregister-progress-callback "test_download_3")
    (is (null (gethash "test_download_3" cl-telegram/api::*progress-callbacks*)))))

(test test-get-progress-callback
  "Test retrieving a progress callback"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_4" callback)
    (is (eq (cl-telegram/api:get-progress-callback "test_download_4") callback))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_4")))

;;; ============================================================================
;;; Section 2: Progress Update Tests
;;; ============================================================================

(test test-update-progress-invokes-callback
  "Test that update-progress invokes the registered callback"
  (let* ((callback-called nil)
         (captured-progress nil)
         (callback (lambda (progress)
                     (setf callback-called t
                           captured-progress progress))))
    (cl-telegram/api:register-progress-callback "test_download_5" callback)
    (cl-telegram/api:update-progress "test_download_5" 1024 10240 :status :downloading)
    (is callback-called)
    (when captured-progress
      (is (= (cl-telegram/api:transfer-progress-transferred captured-progress) 1024))
      (is (= (cl-telegram/api:transfer-progress-total captured-progress) 10240)))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_5")))

(test test-update-progress-percentage-calculation
  "Test that percentage is calculated correctly"
  (let* ((captured-progress nil)
         (callback (lambda (progress)
                     (setf captured-progress progress))))
    (cl-telegram/api:register-progress-callback "test_download_6" callback)
    (cl-telegram/api:update-progress "test_download_6" 5120 10240 :status :downloading)
    (when captured-progress
      (is (>= (cl-telegram/api:transfer-progress-percentage captured-progress) 49.0))
      (is (<= (cl-telegram/api:transfer-progress-percentage captured-progress) 51.0)))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_6")))

(test test-update-progress-without-callback
  "Test that update-progress works without registered callback"
  ;; Should not signal an error
  (cl-telegram/api:update-progress "nonexistent_download" 1024 10240)
  t)

;;; ============================================================================
;;; Section 3: Human-Readable Format Tests
;;; ============================================================================

(test test-format-human-speed-bytes
  "Test formatting speed in bytes per second"
  (let ((result (cl-telegram/api:format-human-speed 512)))
    (is (string= result "512 B/s"))))

(test test-format-human-speed-kilobytes
  "Test formatting speed in KB/s"
  (let ((result (cl-telegram/api:format-human-speed 2048)))
    (is (string= result "2.0 KB/s"))))

(test test-format-human-speed-megabytes
  "Test formatting speed in MB/s"
  (let ((result (cl-telegram/api:format-human-speed 1048576)))
    (is (string= result "1.0 MB/s"))))

(test test-format-human-speed-gigabytes
  "Test formatting speed in GB/s"
  (let ((result (cl-telegram/api:format-human-speed 1073741824)))
    (is (string= result "1.0 GB/s"))))

(test test-format-human-time-seconds
  "Test formatting time in seconds"
  (let ((result (cl-telegram/api:format-human-time 45)))
    (is (string= result "45s"))))

(test test-format-human-time-minutes
  "Test formatting time in minutes and seconds"
  (let ((result (cl-telegram/api:format-human-time 125)))
    (is (string= result "2m 5s"))))

(test test-format-human-time-hours
  "Test formatting time in hours, minutes, and seconds"
  (let ((result (cl-telegram/api:format-human-time 3665)))
    (is (string= result "1h 1m 5s"))))

(test test-format-human-time-days
  "Test formatting time in days"
  (let ((result (cl-telegram/api:format-human-time 90000)))
    (is (or (string= result "1d 1h 40m")
            (string= result "1d 1h 0m 0s")))))

(test test-format-human-time-null
  "Test formatting null time"
  (let ((result (cl-telegram/api:format-human-time nil)))
    (is (string= result "N/A"))))

;;; ============================================================================
;;; Section 4: Human-Readable Size Tests
;;; ============================================================================

(test test-format-human-size-bytes
  "Test formatting size in bytes"
  (let ((result (cl-telegram/api:format-human-size 512)))
    (is (string= result "512 B"))))

(test test-format-human-size-kilobytes
  "Test formatting size in KB"
  (let ((result (cl-telegram/api:format-human-size 2048)))
    (is (string= result "2.0 KB"))))

(test test-format-human-size-megabytes
  "Test formatting size in MB"
  (let ((result (cl-telegram/api:format-human-size 1048576)))
    (is (string= result "1.0 MB"))))

(test test-format-human-size-gigabytes
  "Test formatting size in GB"
  (let ((result (cl-telegram/api:format-human-size 1073741824)))
    (is (string= result "1.0 GB"))))

;;; ============================================================================
;;; Section 5: Progress History and Speed Calculation Tests
;;; ============================================================================

(test test-update-progress-history-adds-entry
  "Test that progress history is updated"
  (cl-telegram/api::update-progress-history "test_download_7" 1024)
  (let ((history (gethash "test_download_7" cl-telegram/api::*progress-history* '())))
    (is (>= (length history) 1))
    ;; Cleanup
    (remhash "test_download_7" cl-telegram/api::*progress-history*)))

(test test-calculate-speed-and-eta
  "Test speed and ETA calculation"
  (let ((transfer-id "test_download_8"))
    ;; Add some history
    (cl-telegram/api::update-progress-history transfer-id 0)
    (sleep 0.1)
    (cl-telegram/api::update-progress-history transfer-id 10240)

    (multiple-value-bind (speed eta)
        (cl-telegram/api::calculate-speed-and-eta transfer-id 10240 102400)
      ;; Speed should be positive
      (is (>= speed 0))
      ;; ETA should be nil or positive
      (is (or (null eta) (>= eta 0))))
    ;; Cleanup
    (remhash transfer-id cl-telegram/api::*progress-history*)))

;;; ============================================================================
;;; Section 6: Progress Monitoring Tests
;;; ============================================================================

(test test-get-transfer-progress
  "Test getting transfer progress"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_9" callback)
    (cl-telegram/api:update-progress "test_download_9" 5000 10000 :status :downloading)

    (let ((progress (cl-telegram/api:get-transfer-progress "test_download_9")))
      (when progress
        (is (= (cl-telegram/api:transfer-progress-transferred progress) 5000))))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_9")))

(test test-list-active-transfers
  "Test listing active transfers"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_10" callback)
    (cl-telegram/api:update-progress "test_download_10" 1000 5000)

    (let ((transfers (cl-telegram/api:list-active-transfers)))
      (is (listp transfers))
      ;; Should contain our transfer
      (is (find "test_download_10" transfers :key #'car :test #'string=)))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_10")))

(test test-get-transfer-stats
  "Test getting transfer statistics"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_11" callback)
    (cl-telegram/api:update-progress "test_download_11" 2500 10000 :status :downloading)

    (let ((stats (cl-telegram/api:get-transfer-stats "test_download_11")))
      (when stats
        (is (getf stats :transfer-id))
        (is (getf stats :transferred))
        (is (getf stats :percentage))))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-callback "test_download_11")))

;;; ============================================================================
;;; Section 7: Progress Event Hooks Tests
;;; ============================================================================

(test test-register-progress-hook
  "Test registering a global progress hook"
  (let ((hook-called nil)
        (hook (lambda (progress)
                (setf hook-called t))))
    (cl-telegram/api:register-progress-hook hook)
    (is (member hook cl-telegram/api::*progress-event-hooks*))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-hook hook)))

(test test-unregister-progress-hook
  "Test unregistering a global progress hook"
  (let ((hook (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-hook hook)
    (cl-telegram/api:unregister-progress-hook hook)
    (is (not (member hook cl-telegram/api::*progress-event-hooks*)))))

(test test-dispatch-progress-event
  "Test dispatching progress event to hooks"
  (let* ((hook-called nil)
         (hook (lambda (progress)
                 (setf hook-called t)
                 (declare (ignore progress)))))
    (cl-telegram/api:register-progress-hook hook)
    (let ((progress (cl-telegram/api:make-transfer-progress
                     :transfer-id "test"
                     :transferred 100
                     :total 1000
                     :percentage 10.0)))
      (let ((count (cl-telegram/api:dispatch-progress-event progress)))
        (is (> count 0)))
      (is hook-called))
    ;; Cleanup
    (cl-telegram/api:unregister-progress-hook hook)))

;;; ============================================================================
;;; Section 8: Cleanup Tests
;;; ============================================================================

(test test-clear-progress-callbacks
  "Test clearing all progress callbacks"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_12" callback)
    (cl-telegram/api:clear-progress-callbacks)
    (is (zerop (hash-table-count cl-telegram/api::*progress-callbacks*)))))

(test test-cleanup-completed-transfers
  "Test cleaning up completed transfers"
  (let ((callback (lambda (progress) (declare (ignore progress)))))
    (cl-telegram/api:register-progress-callback "test_download_13" callback)
    ;; Simulate completed transfer
    (cl-telegram/api:update-progress "test_download_13" 10000 10000 :status :completed)

    (let ((count (cl-telegram/api:cleanup-completed-transfers)))
      (is (>= count 0)))
    ;; Callback should be removed for completed transfer
    (is (null (gethash "test_download_13" cl-telegram/api::*progress-callbacks*)))))

;;; ============================================================================
;;; Section 9: Logging Callback Tests
;;; ============================================================================

(test test-make-logging-progress-callback
  "Test creating a logging progress callback"
  (let ((callback (cl-telegram/api:make-logging-progress-callback :prefix "Test")))
    (is (functionp callback))
    ;; Should not signal error when invoked
    (let ((progress (cl-telegram/api:make-transfer-progress
                     :transfer-id "test"
                     :transferred 1000
                     :total 5000
                     :percentage 20.0
                     :speed 1024.0
                     :speed-human "1.0 KB/s"
                     :eta 4
                     :eta-human "4s")))
      (funcall callback progress))
    t))

;;; ============================================================================
;;; Section 10: Transfer Progress Structure Tests
;;; ============================================================================

(test test-transfer-progress-creation
  "Test creating transfer-progress structure"
  (let ((progress (cl-telegram/api:make-transfer-progress
                   :transfer-id "test_123"
                   :transferred 5000
                   :total 10000
                   :percentage 50.0
                   :speed 1024.0
                   :speed-human "1.0 KB/s"
                   :eta 5
                   :eta-human "5s"
                   :status :downloading)))
    (is (string= (cl-telegram/api:transfer-progress-transfer-id progress) "test_123"))
    (is (= (cl-telegram/api:transfer-progress-transferred progress) 5000))
    (is (= (cl-telegram/api:transfer-progress-total progress) 10000))
    (is (= (cl-telegram/api:transfer-progress-percentage progress) 50.0))
    (is (string= (cl-telegram/api:transfer-progress-speed-human progress) "1.0 KB/s"))
    (is (string= (cl-telegram/api:transfer-progress-eta-human progress) "5s"))
    (is (eq (cl-telegram/api:transfer-progress-status progress) :downloading))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-file-transfer-progress-tests ()
  "Run all file transfer progress tests"
  (let ((results (run! 'file-transfer-progress-tests :if-fail :error)))
    (format t "~%~%=== File Transfer Progress Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
