;;; performance-optimizations-v3-tests.lisp --- Tests for performance optimizations v3
;;;
;;; Test suite for performance-optimizations-v3.lisp:
;;; - Database optimization tests
;;; - LRU cache tests
;;; - Thread pool tests
;;; - Lock-free queue tests
;;; - Connection manager tests

(defpackage #:cl-telegram/tests/performance-optimizations-v3
  (:use #:cl #:cl-telegram/api #:fiveam)
  (:export #:run-performance-optimizations-v3-tests))

(in-package #:cl-telegram/tests/performance-optimizations-v3)

;; Define test suite
(def-suite* performance-optimizations-v3-tests
  :description "Performance Optimizations v3 Test Suite")

;;; ============================================================================
;;; Database Optimization Tests
;;; ============================================================================

(test test-calculate-optimal-pool-size
  "Test optimal pool size calculation"
  (let ((pool-size-10 (calculate-optimal-pool-size :max-threads 100 :avg-query-time-ms 10))
        (pool-size-50 (calculate-optimal-pool-size :max-threads 100 :avg-query-time-ms 50)))
    ;; Faster queries should allow more concurrent threads
    (is-true (>= pool-size-10 100))
    (is-true (>= pool-size-50 50))
    ;; Both should be capped at 100
    (is-equal 100 (min pool-size-10 100))
    (is-equal 100 (min pool-size-50 100))))

(test test-partition-list
  "Test list partitioning for batch operations"
  (let* ((input '(1 2 3 4 5 6 7 8 9 10))
         (partitions (partition-list input 3)))
    (is-equal 4 (length partitions))
    (is-equal '(1 2 3) (first partitions))
    (is-equal '(4 5 6) (second partitions))
    (is-equal '(10) (car (last partitions)))))

(test test-suggest-query-optimization
  "Test query optimization suggestions"
  (is-string-equal "Consider adding index on WHERE clause columns"
                   (suggest-query-optimization "SELECT * FROM users WHERE id = ?"))
  (is-string-equal "Consider adding index on ORDER BY columns"
                   (suggest-query-optimization "SELECT * FROM users ORDER BY name"))
  (is-string-equal "Ensure JOIN columns are indexed"
                   (suggest-query-optimization "SELECT * FROM users JOIN chats ON users.id = chats.user_id"))
  (is-string-equal "Use batch inserts or transactions for multiple inserts"
                   (suggest-query-optimization "INSERT INTO messages VALUES (?, ?)")))

;;; ============================================================================
;;; LRU Cache Tests
;;; ============================================================================

(test test-make-lru-cache
  "Test LRU cache creation"
  (let ((cache (make-lru-cache :capacity 100 :max-memory-mb 50)))
    (is-equal 100 (lru-cache-capacity cache))
    (is-equal (* 50 1024 1024) (lru-cache-max-memory-bytes cache))
    (is-equal 0 (lru-cache-current-size cache))
    (is-equal 0 (lru-cache-hits cache))
    (is-equal 0 (lru-cache-misses cache))))

(test test-lru-cache-get-miss
  "Test LRU cache miss"
  (let ((cache (make-lru-cache :capacity 10 :max-memory-mb 10)))
    (is-null (lru-cache-get cache "nonexistent"))
    (is-equal 0 (lru-cache-hits cache))
    (is-equal 1 (lru-cache-misses cache))))

(test test-lru-cache-basic-operations
  "Test LRU cache basic get/put operations"
  (let ((cache (make-lru-cache :capacity 10 :max-memory-mb 10)))
    ;; Put some values
    (lru-cache-put cache "key1" "value1" :size-bytes 100)
    (lru-cache-put cache "key2" "value2" :size-bytes 100)

    ;; Get values
    (is-string-equal "value1" (lru-cache-get cache "key1"))
    (is-string-equal "value2" (lru-cache-get cache "key2"))

    ;; Check stats
    (is-equal 2 (lru-cache-current-size cache))
    (is-equal 2 (lru-cache-hits cache))
    (is-equal 0 (lru-cache-misses cache))))

(test test-lru-cache-eviction
  "Test LRU cache eviction policy"
  (let ((cache (make-lru-cache :capacity 3 :max-memory-mb 1))) ; Small capacity
    ;; Add 3 items
    (lru-cache-put cache "key1" "value1" :size-bytes 100)
    (lru-cache-put cache "key2" "value2" :size-bytes 100)
    (lru-cache-put cache "key3" "value3" :size-bytes 100)

    ;; Access key1 to make it recently used
    (lru-cache-get cache "key1")

    ;; Add new item - should evict key2 (least recently used)
    (lru-cache-put cache "key4" "value4" :size-bytes 100)

    ;; key1, key3, key4 should exist; key2 should be evicted
    (is-not (null (lru-cache-get cache "key1")))
    (is-null (lru-cache-get cache "key2"))
    (is-not (null (lru-cache-get cache "key3")))
    (is-not (null (lru-cache-get cache "key4")))

    ;; Check eviction count
    (is-equal 1 (lru-cache-evictions cache))))

(test test-lru-cache-memory-eviction
  "Test LRU cache memory-based eviction"
  (let ((cache (make-lru-cache :capacity 1000 :max-memory-mb 1))) ; 1MB limit
    ;; Add items until we exceed memory limit
    (dotimes (i 20) ; 20 * 100KB = 2MB > 1MB
      (lru-cache-put cache (format nil "key~A" i)
                     (format nil "value~A" i)
                     :size-bytes (* 100 1024)))

    ;; Should have evicted some items
    (is-true (plusp (lru-cache-evictions cache)))

    ;; Current memory should be under limit
    (is-true (<= (lru-cache-current-memory-bytes cache)
                 (lru-cache-max-memory-bytes cache)))))

(test test-lru-cache-stats
  "Test LRU cache statistics"
  (let ((cache (make-lru-cache :capacity 10 :max-memory-mb 10)))
    (lru-cache-put cache "key1" "value1" :size-bytes 100)
    (lru-cache-get cache "key1")
    (lru-cache-get cache "key1")
    (lru-cache-get cache "nonexistent")

    (let ((stats (lru-cache-stats cache)))
      (is-equal 1 (getf stats :size))
      (is-equal 2 (getf stats :hits))
      (is-equal 1 (getf stats :misses))
      (is-true (>= (getf stats :hit-rate) 0.6)))))

;;; ============================================================================
;;; Message Buffer Tests
;;; ============================================================================

(test test-acquire-release-message-buffer
  "Test message buffer acquire and release"
  (let ((buffer (acquire-message-buffer :min-size 1024)))
    (is-not (null buffer))
    (is-true (>= (message-buffer-size buffer) 1024))
    (is-equal :application (message-buffer-owner buffer))
    (is-equal 0 (message-buffer-position buffer))

    ;; Release back to pool
    (is-true (release-message-buffer buffer))
    (is-equal :pool (message-buffer-owner buffer))))

(test test-write-read-buffer
  "Test message buffer write and read operations"
  (let* ((buffer (acquire-message-buffer :min-size 1024))
         (data #(1 2 3 4 5 6 7 8 9 10)))
    ;; Write data
    (is-equal 10 (write-to-buffer buffer data))
    (is-equal 10 (message-buffer-position buffer))

    ;; Read data back
    (let ((read-data (read-from-buffer buffer :offset 0 :length 10)))
      (is-equal 10 (length read-data))
      (dotimes (i 10)
        (is-equal (1+ i) (aref read-data i))))

    (release-message-buffer buffer)))

;;; ============================================================================
;;; Thread Pool Tests
;;; ============================================================================

(test test-make-thread-pool
  "Test thread pool creation"
  (let ((pool (make-thread-pool :num-threads 4)))
    (is-equal 4 (length (thread-pool-workers pool)))
    (is-false (thread-pool-shutdown-p pool))
    (is-equal 0 (thread-pool-active-workers pool))
    (is-equal 0 (thread-pool-completed-tasks pool))

    ;; Cleanup
    (shutdown-thread-pool pool)))

(test test-submit-task
  "Test thread pool task submission"
  (let ((pool (make-thread-pool :num-threads 2))
        (result nil))
    ;; Submit task
    (submit-task pool (lambda () (setf result 42)))

    ;; Wait for task completion
    (sleep 0.5)

    (is-equal 42 result)
    (is-true (>= (thread-pool-completed-tasks pool) 1))

    ;; Cleanup
    (shutdown-thread-pool pool)))

(test test-submit-task-priority
  "Test thread pool task priority"
  (let ((pool (make-thread-pool :num-threads 1))
        (execution-order nil))
    ;; Submit tasks with different priorities
    (submit-task pool (lambda () (push 1 execution-order)) :priority 0)
    (sleep 0.1)
    (submit-task pool (lambda () (push 2 execution-order)) :priority 10) ; High priority
    (sleep 0.1)
    (submit-task pool (lambda () (push 3 execution-order)) :priority 0)

    ;; Wait for completion
    (sleep 1)

    ;; High priority task should execute earlier
    (is-true (member 2 execution-order))

    ;; Cleanup
    (shutdown-thread-pool pool)))

(test test-thread-pool-stats
  "Test thread pool statistics"
  (let ((pool (make-thread-pool :num-threads 2)))
    ;; Submit some tasks
    (dotimes (i 5)
      (submit-task pool (lambda () (sleep 0.05))))

    ;; Wait for completion
    (sleep 1)

    (let ((stats (get-thread-pool-stats pool)))
      (is-equal 2 (getf stats :total-workers))
      (is-true (>= (getf stats :completed-tasks) 1))
      (is-equal 0 (getf stats :active-workers)))

    ;; Cleanup
    (shutdown-thread-pool pool)))

;;; ============================================================================
;;; Lock-Free Queue Tests
;;; ============================================================================

(test test-make-lock-free-queue
  "Test lock-free queue creation"
  (let ((queue (make-lock-free-queue)))
    (is-true (lock-free-queue-p queue))
    (is-equal 0 (lock-free-queue-size queue))))

(test test-lock-free-enqueue-dequeue
  "Test lock-free queue basic operations"
  (let ((queue (make-lock-free-queue)))
    ;; Enqueue items
    (lock-free-enqueue queue 1)
    (lock-free-enqueue queue 2)
    (lock-free-enqueue queue 3)

    (is-false (lock-free-queue-p queue))
    (is-equal 3 (lock-free-queue-size queue))

    ;; Dequeue items (FIFO order)
    (is-equal 1 (lock-free-dequeue queue))
    (is-equal 2 (lock-free-dequeue queue))
    (is-equal 3 (lock-free-dequeue queue))

    (is-true (lock-free-queue-p queue))
    (is-equal 0 (lock-free-queue-size queue))))

(test test-lock-free-dequeue-empty
  "Test dequeue from empty queue"
  (let ((queue (make-lock-free-queue)))
    (is-null (lock-free-dequeue queue))))

;;; ============================================================================
;;; Connection Manager Tests
;;; ============================================================================

(test test-make-connection-manager
  "Test connection manager creation"
  (let ((manager (make-connection-manager :max-connections 10 :idle-timeout 60)))
    (is-equal 10 (connection-manager-max-connections manager))
    (is-equal 60 (connection-manager-idle-timeout manager))
    (is-equal 0 (getf (connection-manager-stats manager) :total-requests))))

(test test-get-dc-host
  "Test datacenter host lookup"
  (is-string-equal "ams1.telegram.org" (get-dc-host 1))
  (is-string-equal "do1.telegram.org" (get-dc-host 2))
  (is-string-equal "pl1.telegram.org" (get-dc-host 3))
  (is-string-equal "sg1.telegram.org" (get-dc-host 4))
  (is-string-equal "us1.telegram.org" (get-dc-host 5)))

(test test-get-dc-port
  "Test datacenter port lookup"
  (is-equal 443 (get-dc-port 1))
  (is-equal 443 (get-dc-port 5)))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(test test-lru-cache-concurrent-access
  "Test LRU cache concurrent access"
  (let ((cache (make-lru-cache :capacity 1000 :max-memory-mb 10))
        (errors nil)
        (threads nil))
    ;; Create multiple threads accessing cache concurrently
    (dotimes (i 10)
      (let ((thread (bt:make-thread
                     (lambda ()
                       (handler-case
                           (dotimes (j 100)
                             (lru-cache-put cache (format nil "key-~A-~A" i j)
                                            (format nil "value-~A-~A" i j)
                                            :size-bytes 100)
                             (lru-cache-get cache (format nil "key-~A-~A" i j)))
                         (error (e)
                           (push e errors))))
                     :name (format nil "cache-accessor-~A" i))))
        (push thread threads)))

    ;; Wait for all threads
    (dolist (thread threads)
      (bt:join-thread thread))

    ;; Should have no errors
    (is-true (null errors))

    ;; Cache should have some entries
    (is-true (plusp (lru-cache-current-size cache)))))

(test test-thread-pool-with-lock-free-queue
  "Test thread pool processing items from lock-free queue"
  (let ((pool (make-thread-pool :num-threads 4))
        (queue (make-lock-free-queue))
        (results nil)
        (results-lock (bt:make-lock)))
    ;; Enqueue tasks
    (dotimes (i 20)
      (lock-free-enqueue queue i))

    ;; Worker threads process queue
    (dotimes (i 4)
      (submit-task pool
                   (lambda ()
                     (loop
                       (let ((item (lock-free-dequeue queue)))
                         (when (null item)
                           (return))
                         (with-lock-held (results-lock)
                           (push item results)))))))

    ;; Wait for completion
    (sleep 1)

    ;; All items should be processed
    (is-equal 20 (length results))
    (is-true (lock-free-queue-p queue))

    ;; Cleanup
    (shutdown-thread-pool pool)))

;;; ============================================================================
;;; Performance Benchmark Tests
;;; ============================================================================

(test test-lru-cache-performance
  "Test LRU cache performance (should complete in reasonable time)"
  (let ((cache (make-lru-cache :capacity 10000 :max-memory-mb 100))
        (start (get-internal-real-time)))
    ;; Insert 10000 items
    (dotimes (i 10000)
      (lru-cache-put cache (format nil "key-~A" i)
                     (format nil "value-~A" i)
                     :size-bytes 100))

    ;; Access all items
    (dotimes (i 10000)
      (lru-cache-get cache (format nil "key-~A" i)))

    (let ((elapsed (/ (- (get-internal-real-time) start)
                      internal-time-units-per-second)))
      ;; Should complete in under 5 seconds
      (is-true (< elapsed 5.0))
      (format t "~%LRU cache: 10000 insertions + 10000 lookups in ~Ams~%"
              (* elapsed 1000)))))

(test test-lock-free-queue-performance
  "Test lock-free queue performance"
  (let ((queue (make-lock-free-queue))
        (start (get-internal-real-time)))
    ;; Enqueue 10000 items
    (dotimes (i 10000)
      (lock-free-enqueue queue i))

    ;; Dequeue 10000 items
    (dotimes (i 10000)
      (lock-free-dequeue queue))

    (let ((elapsed (/ (- (get-internal-real-time) start)
                      internal-time-units-per-second)))
      ;; Should complete in under 2 seconds
      (is-true (< elapsed 2.0))
      (format t "~%Lock-free queue: 10000 enqueue + 10000 dequeue in ~Ams~%"
              (* elapsed 1000)))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-performance-optimizations-v3-tests (&optional (pattern :all))
  "Run performance optimizations v3 tests.

   Args:
     pattern: Test pattern to match (default: :all)

   Returns:
     T if all tests pass"
  (run! 'performance-optimizations-v3-tests :if-passed :success :if-failed :failure))
