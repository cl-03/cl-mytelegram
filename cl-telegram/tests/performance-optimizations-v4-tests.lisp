;;; performance-optimizations-v4-tests.lisp --- Tests for performance optimizations v4

(in-package #:cl-telegram/tests)

(def-suite* performance-optimizations-v4-tests
  :description "Tests for performance optimizations v4 (Connection Pool, Batching, Incremental)")

;;; ============================================================================
;;; Section 1: Connection Pool Tests
;;; ============================================================================

(test test-make-connection-pool
  "Test creating a connection pool"
  (let ((pool (cl-telegram/api:make-connection-pool :size 20 :min-idle 3 :max-idle 10)))
    (is (typep pool 'cl-telegram/api::connection-pool))
    (is (= (cl-telegram/api::pool-size pool) 20))
    (is (= (cl-telegram/api::pool-min-idle pool) 3))
    (is (= (cl-telegram/api::pool-max-idle pool) 10))))

(test test-initialize-connection-pool
  "Test initializing a named connection pool"
  (let ((result (cl-telegram/api:initialize-connection-pool "test-pool" :size 15)))
    (is (eq result t))
    (is (cl-telegram/api:get-pool "test-pool"))))

(test test-get-pool
  "Test getting a pool by ID"
  (cl-telegram/api:initialize-connection-pool "test-pool-2" :size 10)
  (let ((pool (cl-telegram/api:get-pool "test-pool-2")))
    (is (typep pool 'cl-telegram/api::connection-pool))
    (is (= (cl-telegram/api::pool-size pool) 10))))

(test test-get-pool-nonexistent
  "Test getting a nonexistent pool"
  (let ((pool (cl-telegram/api:get-pool "nonexistent-pool")))
    (is (null pool))))

(test test-get-pool-stats
  "Test getting pool statistics"
  (cl-telegram/api:initialize-connection-pool "stats-pool" :size 10)
  (let ((stats (cl-telegram/api:get-pool-stats "stats-pool")))
    (is (listp stats))
    (is (getf stats :pool-id))
    (is (getf stats :size))
    (is (getf stats :max-size))
    (is (getf stats :idle))
    (is (getf stats :in-use))
    (is (getf stats :total-created))))

(test test-close-pool
  "Test closing a pool"
  (cl-telegram/api:initialize-connection-pool "close-pool" :size 5)
  (is (cl-telegram/api:get-pool "close-pool"))
  (is (eq (cl-telegram/api:close-pool "close-pool") t))
  (is (null (cl-telegram/api:get-pool "close-pool"))))

;;; ============================================================================
;;; Section 2: Request Batching Tests
;;; ============================================================================

(test test-batch-rpc-call
  "Test batch RPC call"
  ;; Note: This test requires a real connection
  (let ((connection (cl-telegram/api::get-connection)))
    (when connection
      (let ((requests (list (list :test :request :1)
                            (list :test :request :2)
                            (list :test :request :3)))
            (results (cl-telegram/api:batch-rpc-call connection requests :timeout 5000)))
        (is (listp results))
        (is (= (length results) 3))))))

(test test-enqueue-batch-request
  "Test enqueueing a batch request"
  (let ((result (cl-telegram/api:enqueue-batch-request
                 (cl-telegram/api::get-connection)
                 '(:test :request)
                 (lambda (r) (print r))
                 :timeout-ms 100)))
    (is (eq result t))))

(test test-flush-batch-queue
  "Test flushing a batch queue"
  (let ((queue-key "test-queue"))
    ;; Create a batch
    (setf (gethash queue-key cl-telegram/api::*batch-queue*)
          (make-instance 'cl-telegram/api::batch-request))
    (let ((result (cl-telegram/api:flush-batch-queue queue-key)))
      (is (or (eq result t) (null result)))
      (is (null (gethash queue-key cl-telegram/api::*batch-queue*))))))

(test test-start-batch-processor
  "Test starting a batch processor"
  (let ((result (cl-telegram/api:start-batch-processor "test-processor" :interval-ms 50)))
    (is (eq result t))
    (is (gethash "test-processor" cl-telegram/api::*batch-processors*)))
  ;; Cleanup
  (cl-telegram/api:stop-batch-processor "test-processor"))

(test test-stop-batch-processor
  "Test stopping a batch processor"
  (cl-telegram/api:start-batch-processor "stop-processor" :interval-ms 50)
  (is (gethash "stop-processor" cl-telegram/api::*batch-processors*))
  (cl-telegram/api:stop-batch-processor "stop-processor")
  (is (null (gethash "stop-processor" cl-telegram/api::*batch-processors*))))

;;; ============================================================================
;;; Section 3: Defer Execution Tests
;;; ============================================================================

(test test-defer-execution
  "Test deferring execution"
  (let ((task-id (cl-telegram/api:defer-execution
                  (lambda () (print "Deferred task"))
                  :delay-ms 100)))
    (is (stringp task-id))
    (is (gethash task-id cl-telegram/api::*deferred-tasks*))))

(test test-cancel-deferred-execution
  "Test canceling deferred execution"
  (let ((task-id (cl-telegram/api:defer-execution
                  (lambda () (print "Deferred task"))
                  :delay-ms 1000)))
    (is (gethash task-id cl-telegram/api::*deferred-tasks*))
    (cl-telegram/api:cancel-deferred-execution task-id)
    (is (null (gethash task-id cl-telegram/api::*deferred-tasks*)))))

;;; ============================================================================
;;; Section 4: Incremental Updates Tests
;;; ============================================================================

(test test-get-incremental-updates
  "Test getting incremental updates"
  (let ((updates (cl-telegram/api:get-incremental-updates :messages 12345 :limit 100)))
    (is (listp updates))))

(test test-apply-incremental-update
  "Test applying an incremental update"
  (let ((result (cl-telegram/api:apply-incremental-update :messages '(:test :data))))
    (is (eq result t))))

(test test-sync-incremental
  "Test incremental synchronization"
  (let ((result (cl-telegram/api:sync-incremental
                 :messages
                 (lambda (updates) (format t "Got ~D updates~%" (length updates)))
                 :poll-interval 1000)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 5: Statistics and Monitoring Tests
;;; ============================================================================

(test test-get-performance-stats
  "Test getting performance statistics"
  (let ((stats (cl-telegram/api:get-performance-stats)))
    (is (listp stats))
    (is (getf stats :connection-pools))
    (is (getf stats :pending-batches))
    (is (getf stats :deferred-tasks))
    (is (getf stats :batch-processors))))

(test test-clear-performance-cache
  "Test clearing performance cache"
  (is (eq (cl-telegram/api:clear-performance-cache) t)))

;;; ============================================================================
;;; Section 6: Initialization Tests
;;; ============================================================================

(test test-initialize-performance-optimizations-v4
  "Test initializing performance optimizations v4"
  (let ((result (cl-telegram/api:initialize-performance-optimizations-v4)))
    (is (eq result t))
    (is (gethash "default" cl-telegram/api::*batch-processors*))))

(test test-shutdown-performance-optimizations-v4
  "Test shutting down performance optimizations v4"
  (cl-telegram/api:initialize-performance-optimizations-v4)
  (let ((result (cl-telegram/api:shutdown-performance-optimizations-v4)))
    (is (eq result t))
    (is (= (hash-table-count cl-telegram/api::*batch-processors*) 0))))

;;; ============================================================================
;;; Section 7: Integration Tests
;;; ============================================================================

(test test-connection-pool-workflow
  "Test complete connection pool workflow"
  ;; Initialize pool
  (cl-telegram/api:initialize-connection-pool "integration-pool" :size 5 :min-idle 1)

  ;; Get stats
  (let ((stats (cl-telegram/api:get-pool-stats "integration-pool")))
    (format t "Pool stats: ~A~%" stats))

  ;; Close pool
  (cl-telegram/api:close-pool "integration-pool")
  (is (null (cl-telegram/api:get-pool "integration-pool"))))

(test test-batch-processor-workflow
  "Test batch processor workflow"
  ;; Start processor
  (cl-telegram/api:start-batch-processor "workflow-processor" :interval-ms 100)

  ;; Enqueue requests
  (dotimes (i 5)
    (cl-telegram/api:enqueue-batch-request
     (cl-telegram/api::get-connection)
     `(:request ,i)
     (lambda (result) (format t "Result ~A: ~A~%" i result))))

  ;; Wait for processing
  (sleep 0.5)

  ;; Stop processor
  (cl-telegram/api:stop-batch-processor "workflow-processor"))

(test test-performance-optimizations-full-workflow
  "Test complete performance optimizations workflow"
  ;; Initialize
  (cl-telegram/api:initialize-performance-optimizations-v4)

  ;; Create connection pool
  (cl-telegram/api:initialize-connection-pool "main-pool" :size 10)

  ;; Get stats
  (let ((stats (cl-telegram/api:get-performance-stats)))
    (format t "Performance stats: ~A~%" stats))

  ;; Cleanup
  (cl-telegram/api:shutdown-performance-optimizations-v4)
  (cl-telegram/api:clear-performance-cache))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-performance-optimizations-v4-tests ()
  "Run all performance optimizations v4 tests"
  (let ((results (run! 'performance-optimizations-v4-tests :if-fail :error)))
    (format t "~%~%=== Performance Optimizations v4 Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
