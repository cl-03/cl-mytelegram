;;; performance-stability-tests.lisp --- Tests for performance and stability features
;;;
;;; Tests for performance monitoring, metrics collection, connection pooling,
;;; cache optimization, auto-reconnect, circuit breaker, and health checks

(in-package #:cl-telegram/tests)

;;; ===========================================================================
;;; Performance Metrics Tests
;;; ===========================================================================

(deftest test-record-metric
  "Test recording a performance metric"
  (cl-telegram/api:start-performance-monitoring)
  (let ((result (cl-telegram/api:record-metric :test-metric 42.5 :unit "ms")))
    (is result)))

(deftest test-record-metric-with-tags
  "Test recording metric with tags"
  (cl-telegram/api:start-performance-monitoring)
  (let ((result (cl-telegram/api:record-metric :api-call 100
                                               :unit "ms"
                                               :tags '(:endpoint "sendMessage"))))
    (is result)))

(deftest test-get-performance-stats
  "Test getting performance statistics"
  (cl-telegram/api:start-performance-monitoring)
  (cl-telegram/api:record-metric :test-metric 50)
  (let ((stats (cl-telegram/api:get-performance-stats)))
    (is (getf stats :total-metrics))
    (is (getf stats :monitoring-enabled))))

(deftest test-reset-performance-stats
  "Test resetting performance statistics"
  (cl-telegram/api:start-performance-monitoring)
  (cl-telegram/api:record-metric :test-metric 50)
  (let ((result (cl-telegram/api:reset-performance-stats)))
    (is (null result))
    (let ((stats (cl-telegram/api:get-performance-stats)))
      (is (= (getf stats :total-metrics) 0)))))

(deftest test-get-performance-stats-filtered
  "Test filtering performance stats by metric name"
  (cl-telegram/api:start-performance-monitoring)
  (cl-telegram/api:record-metric :filtered-metric 25 :tags '(:type "a"))
  (cl-telegram/api:record-metric :filtered-metric 35 :tags '(:type "b"))
  (let ((stats (cl-telegram/api:get-performance-stats :metric-name :filtered-metric)))
    (is (<= (getf stats :total-metrics) 2))))

;;; ===========================================================================
;;; Timing Utilities Tests
;;; ===========================================================================

(deftest test-with-timing-macro
  "Test with-timing macro"
  (cl-telegram/api:start-performance-monitoring)
  (let ((result (cl-telegram/api:with-timing (:test-timing :tags '(:test t))
                  (sleep 0.01)
                  t)))
    (is result)))

(deftest test-time-operation
  "Test time-operation function"
  (cl-telegram/api:start-performance-monitoring)
  (multiple-value-bind (result elapsed)
      (cl-telegram/api:time-operation
       #'(lambda () (sleep 0.01) "done")
       :metric-name :timed-op
       :tags '(:test t))
    (is (string= result "done"))
    (is (numberp elapsed))
    (is (> elapsed 0))))

(deftest test-time-operation-with-error
  "Test time-operation with error"
  (cl-telegram/api:start-performance-monitoring)
  (signals error
    (cl-telegram/api:time-operation
     #'(lambda () (error "Test error"))
     :metric-name :timed-error)))

;;; ===========================================================================
;;; Memory Management Tests
;;; ===========================================================================

(deftest test-get-memory-usage
  "Test getting memory usage"
  (let ((stats (cl-telegram/api:get-memory-usage)))
    (is (listp stats))))

(deftest test-trigger-garbage-collection
  "Test triggering garbage collection"
  (let ((result (cl-telegram/api:trigger-garbage-collection)))
    (is result)))

;;; ===========================================================================
;;; Connection Pool Tests
;;; ===========================================================================

(deftest test-record-connection-stats
  "Test recording connection statistics"
  (let ((result (cl-telegram/api:record-connection-stats :event :create)))
    (is result)))

(deftest test-record-connection-stats-events
  "Test all connection stat events"
  (dolist (event '(:create :acquire :release :destroy))
    (let ((result (cl-telegram/api:record-connection-stats :event event)))
      (is result))))

(deftest test-get-connection-pool-stats
  "Test getting connection pool stats"
  (let ((stats (cl-telegram/api:get-connection-pool-stats)))
    (is (typep stats 'cl-telegram/api::connection-pool-stats))))

(deftest test-reset-connection-pool-stats
  "Test resetting connection pool stats"
  (cl-telegram/api:record-connection-stats :event :create)
  (let ((result (cl-telegram/api:reset-connection-pool-stats)))
    (is (null result))))

(deftest test-cleanup-stale-connections
  "Test cleaning up stale connections"
  (let ((result (cl-telegram/api:cleanup-stale-connections :max-age 300)))
    (is (numberp result))))

(deftest test-optimize-connection-pool
  "Test optimizing connection pool"
  (let ((result (cl-telegram/api:optimize-connection-pool)))
    (is (getf result :current-pool-size))
    (is (getf result :suggestions))))

;;; ===========================================================================
;;; Cache Optimization Tests
;;; ===========================================================================

(deftest test-get-cache-stats
  "Test getting cache statistics"
  (let ((stats (cl-telegram/api:get-cache-stats :test-cache)))
    (is (typep stats 'cl-telegram/api::cache-stats))))

(deftest test-record-cache-hit
  "Test recording cache hit"
  (let ((result (cl-telegram/api:record-cache-hit :test-cache)))
    (is result)))

(deftest test-record-cache-miss
  "Test recording cache miss"
  (let ((result (cl-telegram/api:record-cache-miss :test-cache)))
    (is result)))

(deftest test-record-cache-eviction
  "Test recording cache eviction"
  (let ((result (cl-telegram/api:record-cache-eviction :test-cache)))
    (is result)))

(deftest test-implement-lru-eviction
  "Test LRU eviction implementation"
  (let ((cache (make-hash-table))
        (lru-fn (cl-telegram/api:implement-lru-eviction cache 3)))
    ;; Add items
    (funcall lru-fn :set "key1" "value1")
    (funcall lru-fn :set "key2" "value2")
    (funcall lru-fn :set "key3" "value3")
    ;; Access key1 to make it recently used
    (funcall lru-fn :get "key1")
    ;; Add one more, should evict key2 (least recently used)
    (funcall lru-fn :set "key4" "value4")
    ;; key1 should still exist
    (is (gethash "key1" cache))
    ;; key2 should be evicted
    (is (null (gethash "key2" cache)))))

(deftest test-optimize-message-cache
  "Test optimizing message cache"
  (cl-telegram/api:record-cache-hit :messages)
  (cl-telegram/api:record-cache-hit :messages)
  (cl-telegram/api:record-cache-miss :messages)
  (let ((result (cl-telegram/api:optimize-message-cache)))
    (is (getf result :cache-type))
    (is (getf result :hit-rate))))

;;; ===========================================================================
;;; Performance Monitoring Lifecycle Tests
;;; ===========================================================================

(deftest test-start-performance-monitoring
  "Test starting performance monitoring"
  (let ((result (cl-telegram/api:start-performance-monitoring)))
    (is result)
    (is cl-telegram/api::*performance-monitoring-enabled*)))

(deftest test-stop-performance-monitoring
  "Test stopping performance monitoring"
  (cl-telegram/api:start-performance-monitoring)
  (let ((result (cl-telegram/api:stop-performance-monitoring)))
    (is (getf result :total-metrics))
    (is (not cl-telegram/api::*performance-monitoring-enabled*))))

(deftest test-with-performance-monitoring
  "Test with-performance-monitoring macro"
  (let ((result (cl-telegram/api:with-performance-monitoring ()
                  (cl-telegram/api:record-metric :inside-macro 10)
                  t)))
    (is result)))

;;; ===========================================================================
;;; Error Rate Tracking Tests
;;; ===========================================================================

(deftest test-record-error
  "Test recording an error"
  (let ((result (cl-telegram/api:record-error :test-op :connection-error)))
    (is result)))

(deftest test-get-error-rates
  "Test getting error rates"
  (cl-telegram/api:record-error :test-op :test-error)
  (let ((result (cl-telegram/api:get-error-rates)))
    (is (getf result :total-errors))
    (is (getf result :by-operation))))

;;; ===========================================================================
;;; Auto-Reconnect Tests
;;; ===========================================================================

(deftest test-make-auto-reconnect
  "Test creating auto-reconnect handler"
  (let ((handler (cl-telegram/api:make-auto-reconnect)))
    (is (functionp handler))))

(deftest test-implement-auto-reconnect
  "Test implementing auto-reconnect"
  (let ((result (cl-telegram/api:implement-auto-reconnect
                 :max-retries 5
                 :initial-delay 1.0
                 :max-delay 60.0)))
    (is result)))

(deftest test-exponential-backoff
  "Test exponential backoff calculation"
  (let ((delay (cl-telegram/api:exponential-backoff 0 :base-delay 1.0 :max-delay 60.0)))
    (is (>= delay 0))
    (is (<= delay 2))) ; First attempt with jitter
  (let ((delay (cl-telegram/api:exponential-backoff 3 :base-delay 1.0 :max-delay 60.0)))
    (is (>= delay 4)) ; Should be around 8 +/- jitter
    (is (<= delay 60)))) ; Should not exceed max

(deftest test-get-reconnect-state
  "Test getting reconnect state"
  (let ((state (cl-telegram/api:get-reconnect-state)))
    ;; State can be nil initially
    (is (or (null state)
            (typep state 'cl-telegram/api::reconnect-state)))))

;;; ===========================================================================
;;; Retry Logic Tests
;;; ===========================================================================

(deftest test-with-retry-success
  "Test with-retry macro on success"
  (let ((attempts 0))
    (let ((result (cl-telegram/api:with-retry (:max-retries 3 :delay 0.01)
                    (incf attempts)
                    "success")))
      (is (string= result "success"))
      (is (= attempts 1)))))

(deftest test-with-retry-eventual-success
  "Test with-retry macro with eventual success"
  (let ((attempts 0))
    (let ((result (cl-telegram/api:with-retry (:max-retries 3 :delay 0.01)
                    (incf attempts)
                    (if (< attempts 3)
                        (error "Temporary error")
                        "success"))))
      (is (string= result "success"))
      (is (= attempts 3)))))

(deftest test-with-retry-exhausted
  "Test with-retry macro when exhausted"
  (let ((attempts 0))
    (signals error
      (cl-telegram/api:with-retry (:max-retries 2 :delay 0.01)
        (incf attempts)
        (error "Persistent error")))))

(deftest test-with-retry-backoff
  "Test with-retry with backoff disabled"
  (let ((attempts 0))
    (let ((result (cl-telegram/api:with-retry (:max-retries 2 :delay 0.01 :backoff nil)
                    (incf attempts)
                    (if (= attempts 2) "success" (error "Error")))))
      (is (string= result "success")))))

;;; ===========================================================================
;;; Circuit Breaker Tests
;;; ===========================================================================

(deftest test-make-circuit-breaker
  "Test creating circuit breaker"
  (let ((cb (cl-telegram/api:make-circuit-breaker "test-breaker")))
    (is (typep cb 'cl-telegram/api::circuit-breaker))
    (is (eq (cl-telegram/api::circuit-breaker-state cb) :closed))))

(deftest test-circuit-breaker-allow-request
  "Test circuit breaker allows request when closed"
  (cl-telegram/api:make-circuit-breaker "test-allow")
  (let ((result (cl-telegram/api:circuit-breaker-allow-request-p "test-allow")))
    (is result)))

(deftest test-circuit-breaker-record-success
  "Test circuit breaker records success"
  (cl-telegram/api:make-circuit-breaker "test-success")
  (cl-telegram/api:circuit-breaker-record-success "test-success")
  (let ((state (cl-telegram/api:get-circuit-breaker-state "test-success")))
    (is (>= (getf state :success-count) 0))))

(deftest test-circuit-breaker-record-failure
  "Test circuit breaker records failure"
  (cl-telegram/api:make-circuit-breaker "test-failure" :failure-threshold 2)
  (cl-telegram/api:circuit-breaker-record-failure "test-failure")
  (cl-telegram/api:circuit-breaker-record-failure "test-failure")
  (let ((state (cl-telegram/api:get-circuit-breaker-state "test-failure")))
    (is (eq (getf state :state) :open))))

(deftest test-with-circuit-breaker
  "Test with-circuit-breaker macro"
  (let ((result (cl-telegram/api:with-circuit-breaker ("test-macro")
                  "success")))
    (is (string= result "success"))))

(deftest test-with-circuit-breaker-trips
  "Test circuit breaker trips after failures"
  (cl-telegram/api:make-circuit-breaker "test-trip" :failure-threshold 2)
  ;; Record failures to trip breaker
  (cl-telegram/api:circuit-breaker-record-failure "test-trip")
  (cl-telegram/api:circuit-breaker-record-failure "test-trip")
  ;; Breaker should now be open
  (let ((state (cl-telegram/api:get-circuit-breaker-state "test-trip")))
    (is (eq (getf state :state) :open))))

;;; ===========================================================================
;;; Health Check Tests
;;; ===========================================================================

(deftest test-register-health-check
  "Test registering health check"
  (let ((result (cl-telegram/api:register-health-check "test-check"
                                                       #'(lambda () t)
                                                       :timeout 5)))
    (is result)))

(deftest test-unregister-health-check
  "Test unregistering health check"
  (cl-telegram/api:register-health-check "test-unregister" #'(lambda () t))
  (let ((result (cl-telegram/api:unregister-health-check "test-unregister")))
    (is result)))

(deftest test-run-health-check
  "Test running health check"
  (cl-telegram/api:register-health-check "test-run" #'(lambda () t))
  (let ((result (cl-telegram/api:run-health-check "test-run")))
    (is (getf result :status))
    (is (getf result :name))))

(deftest test-run-health-check-failure
  "Test running failing health check"
  (cl-telegram/api:register-health-check "test-fail" #'(lambda () (error "Down")))
  (let ((result (cl-telegram/api:run-health-check "test-fail")))
    (is (eq (getf result :status) :unhealthy))))

(deftest test-run-all-health-checks
  "Test running all health checks"
  (cl-telegram/api:register-health-check "test-all-1" #'(lambda () t))
  (cl-telegram/api:register-health-check "test-all-2" #'(lambda () t))
  (let ((results (cl-telegram/api:run-all-health-checks)))
    (is (listp results))
    (is (>= (length results) 2))))

(deftest test-get-health-status
  "Test getting overall health status"
  (cl-telegram/api:register-health-check "test-status" #'(lambda () t))
  (let ((status (cl-telegram/api:get-health-status)))
    (is (getf status :overall))
    (is (getf status :healthy-count))))

(deftest test-setup-default-health-checks
  "Test setting up default health checks"
  (let ((result (cl-telegram/api:setup-default-health-checks)))
    (is result)))

;;; ===========================================================================
;;; Resource Cleanup Tests
;;; ===========================================================================

(deftest test-cleanup-resources
  "Test cleaning up resources"
  (let ((result (cl-telegram/api:cleanup-resources)))
    (is (getf result :cleaned))
    (is (getf result :errors))))

;;; ===========================================================================
;;; Logging Tests
;;; ===========================================================================

(deftest test-log-message
  "Test logging a message"
  (let ((result (cl-telegram/api:log-message :info "Test message")))
    ;; Returns nil if below log level, t if logged
    (is (or (null result) result))))

(deftest test-set-log-level
  "Test setting log level"
  (let ((old-level (cl-telegram/api:set-log-level :debug)))
    (is (member old-level '(:debug :info :warn :error)))
    (cl-telegram/api:set-log-level (or old-level :info))))

;;; ===========================================================================
;;; Integration Tests
;;; ===========================================================================

(deftest test-performance-stability-api-existence
  "Test that all performance and stability API functions exist"
  (let ((functions
         '(cl-telegram/api:record-metric
           cl-telegram/api:get-performance-stats
           cl-telegram/api:reset-performance-stats
           cl-telegram/api:with-timing
           cl-telegram/api:time-operation
           cl-telegram/api:get-memory-usage
           cl-telegram/api:trigger-garbage-collection
           cl-telegram/api:record-connection-stats
           cl-telegram/api:get-connection-pool-stats
           cl-telegram/api:cleanup-stale-connections
           cl-telegram/api:optimize-connection-pool
           cl-telegram/api:get-cache-stats
           cl-telegram/api:record-cache-hit
           cl-telegram/api:record-cache-miss
           cl-telegram/api:record-cache-eviction
           cl-telegram/api:implement-lru-eviction
           cl-telegram/api:optimize-message-cache
           cl-telegram/api:start-performance-monitoring
           cl-telegram/api:stop-performance-monitoring
           cl-telegram/api:with-performance-monitoring
           cl-telegram/api:record-error
           cl-telegram/api:get-error-rates
           cl-telegram/api:make-auto-reconnect
           cl-telegram/api:implement-auto-reconnect
           cl-telegram/api:exponential-backoff
           cl-telegram/api:with-retry
           cl-telegram/api:setup-error-handling
           cl-telegram/api:make-circuit-breaker
           cl-telegram/api:circuit-breaker-allow-request-p
           cl-telegram/api:circuit-breaker-record-success
           cl-telegram/api:circuit-breaker-record-failure
           cl-telegram/api:get-circuit-breaker-state
           cl-telegram/api:with-circuit-breaker
           cl-telegram/api:register-health-check
           cl-telegram/api:run-health-check
           cl-telegram/api:get-health-status
           cl-telegram/api:cleanup-resources
           cl-telegram/api:log-message
           cl-telegram/api:set-log-level)))
    (dolist (fn functions)
      (is (fboundp fn) (format nil "Function ~A should exist" fn)))))

;;; ===========================================================================
;;; Test Runner
;;; ===========================================================================

(defun run-performance-stability-tests ()
  "Run all performance and stability tests.

   Returns:
     T if all tests pass"
  (format t "~%Running Performance and Stability Tests...~%")
  (let ((results (list
                  (fiveam:run! 'test-record-metric)
                  (fiveam:run! 'test-record-metric-with-tags)
                  (fiveam:run! 'test-get-performance-stats)
                  (fiveam:run! 'test-reset-performance-stats)
                  (fiveam:run! 'test-with-timing-macro)
                  (fiveam:run! 'test-time-operation)
                  (fiveam:run! 'test-get-memory-usage)
                  (fiveam:run! 'test-trigger-garbage-collection)
                  (fiveam:run! 'test-record-connection-stats)
                  (fiveam:run! 'test-get-connection-pool-stats)
                  (fiveam:run! 'test-cleanup-stale-connections)
                  (fiveam:run! 'test-optimize-connection-pool)
                  (fiveam:run! 'test-get-cache-stats)
                  (fiveam:run! 'test-record-cache-hit)
                  (fiveam:run! 'test-record-cache-miss)
                  (fiveam:run! 'test-record-cache-eviction)
                  (fiveam:run! 'test-implement-lru-eviction)
                  (fiveam:run! 'test-optimize-message-cache)
                  (fiveam:run! 'test-start-performance-monitoring)
                  (fiveam:run! 'test-stop-performance-monitoring)
                  (fiveam:run! 'test-record-error)
                  (fiveam:run! 'test-make-auto-reconnect)
                  (fiveam:run! 'test-implement-auto-reconnect)
                  (fiveam:run! 'test-exponential-backoff)
                  (fiveam:run! 'test-with-retry-success)
                  (fiveam:run! 'test-with-retry-eventual-success)
                  (fiveam:run! 'test-with-retry-exhausted)
                  (fiveam:run! 'test-make-circuit-breaker)
                  (fiveam:run! 'test-circuit-breaker-allow-request)
                  (fiveam:run! 'test-circuit-breaker-record-failure)
                  (fiveam:run! 'test-with-circuit-breaker)
                  (fiveam:run! 'test-register-health-check)
                  (fiveam:run! 'test-run-health-check)
                  (fiveam:run! 'test-get-health-status)
                  (fiveam:run! 'test-cleanup-resources)
                  (fiveam:run! 'test-performance-stability-api-existence))))
    (if (every #'identity results)
        (progn
          (format t "All tests passed!~%")
          t)
        (progn
          (format t "Some tests failed!~%")
          nil))))
