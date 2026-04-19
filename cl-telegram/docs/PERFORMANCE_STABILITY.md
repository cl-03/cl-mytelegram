# Performance and Stability Guide

## Overview

cl-telegram v0.16.0+ includes comprehensive performance monitoring and stability features:

- **Performance Monitoring** - Metrics collection, timing, memory tracking
- **Connection Pool** - Pool management, optimization, cleanup
- **Cache Optimization** - LRU eviction, hit/miss tracking
- **Auto-Reconnect** - Exponential backoff, configurable retries
- **Circuit Breaker** - Fault tolerance, failure isolation
- **Health Checks** - Service health monitoring
- **Error Handling** - Retry logic, error rate tracking
- **Logging** - Configurable log levels

## Table of Contents

1. [Performance Monitoring](#performance-monitoring)
2. [Connection Pool](#connection-pool)
3. [Cache Optimization](#cache-optimization)
4. [Auto-Reconnect](#auto-reconnect)
5. [Circuit Breaker](#circuit-breaker)
6. [Health Checks](#health-checks)
7. [Error Handling](#error-handling)
8. [Logging](#logging)

---

## Performance Monitoring

### Start Monitoring

```lisp
(use-package :cl-telegram/api)

;; Start performance monitoring
(start-performance-monitoring :max-history 1000 :max-pool-size 50)

;; Monitoring is now active
```

### Record Metrics

```lisp
;; Record a simple metric
(record-metric :api-call-latency 45.2)

;; Record with unit
(record-metric :cache-size 1024 :unit "bytes")

;; Record with tags
(record-metric :api-call 100
               :unit "ms"
               :tags '(:endpoint "sendMessage" :status "success"))

;; Record error
(record-error :api-call :connection-error)
```

### Get Statistics

```lisp
;; Get all performance stats
(let ((stats (get-performance-stats)))
  (format t "Total metrics: ~A~%" (getf stats :total-metrics))
  (format t "Monitoring enabled: ~A~%" (getf stats :monitoring-enabled))
  (format t "Duration: ~A seconds~%" (getf stats :monitoring-duration)))

;; Filter by metric name
(let ((stats (get-performance-stats :metric-name :api-call-latency)))
  (dolist (metric (getf stats :metrics))
    (format t "Metric: ~A = ~A ~A~%"
            (getf metric :name)
            (getf metric :value)
            (getf metric :unit))))

;; Filter by tags
(let ((stats (get-performance-stats :tags '(:endpoint "sendMessage"))))
  ;; Get only sendMessage endpoint metrics
  ))
```

### Reset Statistics

```lisp
;; Reset all performance stats
(reset-performance-stats)
```

### Timing Utilities

```lisp
;; Time a block of code
(with-timing (:db-query :tags '(:table "messages"))
  (query-database "SELECT * FROM messages"))

;; Time an operation function
(multiple-value-bind (result elapsed-ms)
    (time-operation #'(lambda () (expensive-operation))
                    :metric-name :expensive-op)
  (format t "Result: ~A, Time: ~Ams~%" result elapsed-ms))

;; With performance monitoring enabled
(with-performance-monitoring ()
  (expensive-operation))
```

### Memory Management

```lisp
;; Get memory usage
(let ((stats (get-memory-usage)))
  (format t "Memory stats: ~A~%" stats))

;; Trigger garbage collection
(trigger-garbage-collection)
```

---

## Connection Pool

### Record Connection Stats

```lisp
;; Record connection events
(record-connection-stats :event :create)
(record-connection-stats :event :acquire :wait-time 50.5)
(record-connection-stats :event :release)
(record-connection-stats :event :destroy)
```

### Get Pool Statistics

```lisp
;; Get current pool stats
(let ((stats (get-connection-pool-stats)))
  (format t "Total: ~A~%" (connection-pool-stats-total-connections stats))
  (format t "Active: ~A~%" (connection-pool-stats-active-connections stats))
  (format t "Idle: ~A~%" (connection-pool-stats-idle-connections stats))
  (format t "Peak: ~A~%" (connection-pool-stats-peak-connections stats))
  (format t "Avg Wait: ~Ams~%" (connection-pool-stats-average-wait-time stats)))
```

### Optimize Pool

```lisp
;; Get optimization suggestions
(let ((result (optimize-connection-pool)))
  (format t "Current size: ~A~%" (getf result :current-pool-size))
  (format t "Suggestions: ~A~%" (getf result :suggestions)))
```

### Cleanup Stale Connections

```lisp
;; Clean up connections older than 5 minutes
(cleanup-stale-connections :max-age 300)
```

---

## Cache Optimization

### Record Cache Stats

```lisp
;; Record cache operations
(record-cache-hit :messages)
(record-cache-miss :messages)
(record-cache-eviction :messages)
```

### Get Cache Statistics

```lisp
;; Get stats for specific cache
(let ((stats (get-cache-stats :messages)))
  (format t "Hits: ~A~%" (cache-stats-hits stats))
  (format t "Misses: ~A~%" (cache-stats-misses stats))
  (format t "Hit rate: ~A~%"
          (/ (cache-stats-hits stats)
             (+ (cache-stats-hits stats) (cache-stats-misses stats)))))
```

### Implement LRU Eviction

```lisp
;; Create cache with LRU eviction
(let ((cache (make-hash-table))
      (lru-fn (implement-lru-eviction cache 100))) ; Max 100 items
  ;; Use the function for cache access
  (funcall lru-fn :set "key1" "value1")
  (funcall lru-fn :set "key2" "value2")
  
  ;; Get value
  (let ((value (funcall lru-fn :get "key1")))
    (format t "Value: ~A~%" value)))
```

### Optimize Message Cache

```lisp
;; Get message cache optimization suggestions
(let ((result (optimize-message-cache)))
  (format t "Hit rate: ~A~%" (getf result :hit-rate))
  (format t "Recommendation: ~A~%" (getf result :recommendation)))
```

---

## Auto-Reconnect

### Configure Auto-Reconnect

```lisp
;; Set up auto-reconnect with custom parameters
(implement-auto-reconnect
 :max-retries 5
 :initial-delay 1.0
 :max-delay 60.0)
```

### Create Reconnect Handler

```lisp
;; Create auto-reconnect handler
(let ((reconnect (make-auto-reconnect)))
  (handler-bind ((network-error reconnect))
    (connect-to-telegram)))
```

### Exponential Backoff

```lisp
;; Calculate backoff delay
(let ((delay (exponential-backoff 3    ; attempt number
                                  :base-delay 1.0
                                  :max-delay 60.0
                                  :multiplier 2.0
                                  :jitter 0.1)))
  (format t "Wait ~A seconds before retry~%" delay))
```

### Get Reconnect State

```lisp
;; Get current reconnection state
(let ((state (get-reconnect-state)))
  (when state
    (format t "Attempt: ~A~%" (reconnect-state-attempt state))
    (format t "Connected: ~A~%" (reconnect-state-connected state))))
```

---

## Retry Logic

### With-Retry Macro

```lisp
;; Retry with defaults (3 attempts, 1s delay)
(with-retry ()
  (call-external-api))

;; Retry with custom settings
(with-retry (:max-retries 5 :delay 0.5 :backoff t)
  (call-telegram-api))

;; Retry without backoff
(with-retry (:max-retries 3 :delay 1.0 :backoff nil)
  (send-message chat-id text))

;; Retry on specific error type
(with-retry (:max-retries 5 :condition 'connection-error)
  (establish-connection))
```

### Setup Error Handling

```lisp
;; Set up global error handling callbacks
(setup-error-handling
 :on-error #'(lambda (condition)
               (format t "Error: ~A~%" condition))
 :on-retry #'(lambda (attempt)
               (format t "Retry attempt: ~A~%" attempt))
 :on-success #'(lambda ()
                 (format t "Operation succeeded~%")))
```

---

## Circuit Breaker

### Create Circuit Breaker

```lisp
;; Create circuit breaker for an operation
(make-circuit-breaker "telegram-api"
                      :failure-threshold 5
                      :success-threshold 2
                      :timeout 30)
```

### With-Circuit-Breaker Macro

```lisp
;; Execute with circuit breaker protection
(with-circuit-breaker ("telegram-api" :failure-threshold 3)
  (call-telegram-api))
```

### Manual Control

```lisp
;; Check if request allowed
(when (circuit-breaker-allow-request-p "telegram-api")
  (call-telegram-api))

;; Record success
(circuit-breaker-record-success "telegram-api")

;; Record failure
(circuit-breaker-record-failure "telegram-api")

;; Get state
(let ((state (get-circuit-breaker-state "telegram-api")))
  (format t "State: ~A~%" (getf state :state))
  (format t "Failures: ~A~%" (getf state :failure-count)))
```

### Circuit Breaker States

| State | Description |
|-------|-------------|
| `:closed` | Normal operation, requests allowed |
| `:open` | Circuit tripped, requests blocked |
| `:half-open` | Testing, single request allowed |

---

## Health Checks

### Register Health Check

```lisp
;; Register a health check
(register-health-check
 "database"
 #'(lambda ()
     (handler-case
         (progn
           (query-database "SELECT 1")
           t)
       (error () nil)))
 :timeout 5)
```

### Run Health Checks

```lisp
;; Run specific health check
(let ((result (run-health-check "database")))
  (format t "Status: ~A~%" (getf result :status))
  (format t "Failures: ~A~%" (getf result :consecutive-failures)))

;; Run all health checks
(let ((results (run-all-health-checks)))
  (dolist (result results)
    (format t "~A: ~A~%"
            (getf result :name)
            (getf result :status))))

;; Get overall health status
(let ((status (get-health-status)))
  (format t "Overall: ~A~%" (getf status :overall))
  (format t "Healthy: ~A~%" (getf status :healthy-count))
  (format t "Unhealthy: ~A~%" (getf status :unhealthy-count)))
```

### Setup Default Health Checks

```lisp
;; Set up default health checks
(setup-default-health-checks)
```

### Unregister Health Check

```lisp
;; Unregister a health check
(unregister-health-check "database")
```

---

## Logging

### Log Messages

```lisp
;; Log at different levels
(log-message :debug "Debug information: ~A" data)
(log-message :info "Operation completed")
(log-message :warn "Warning: deprecated API")
(log-message :error "Error: ~A" error)
```

### Set Log Level

```lisp
;; Set global log level
(set-log-level :debug)   ; All messages
(set-log-level :info)    ; Info and above
(set-log-level :warn)    ; Warnings and errors
(set-log-level :error)   ; Errors only
```

---

## Complete Example

```lisp
;; Load system
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Example: Robust API call with all stability features
(defun robust-api-call ()
  "Make API call with full stability stack"
  
  ;; Start monitoring
  (start-performance-monitoring)
  
  ;; Set up health checks
  (setup-default-health-checks)
  
  ;; Set up circuit breaker
  (make-circuit-breaker "telegram-api" :failure-threshold 3)
  
  ;; Main operation loop
  (loop
   do
   (handler-case
       (progn
         ;; Check circuit breaker
         (unless (circuit-breaker-allow-request-p "telegram-api")
           (error "Circuit breaker open"))
         
         ;; Make API call with retry
         (with-retry (:max-retries 3 :delay 1.0 :backoff t)
           (with-timing (:api-call :tags '(:operation "send"))
             (send-message chat-id text)))
         
         ;; Record success
         (circuit-breaker-record-success "telegram-api")
         (record-metric :api-success 1))
       
     (error (e)
       ;; Record failure
       (circuit-breaker-record-failure "telegram-api")
       (record-error :api-call (type-of e))
       (log-message :error "API call failed: ~A" e)
       
       ;; Check health
       (let ((health (get-health-status)))
         (when (eq (getf health :overall) :degraded)
           (log-message :warn "System health degraded"))))
   
   ;; Check connection
   (unless connected-p
     (implement-auto-reconnect :max-retries 5)
     (reconnect-with-backoff *reconnect-state* *reconnect-config*))
   
   ;; Periodic cleanup
   (when (zerop (mod *operation-count* 100))
     (cleanup-stale-connections :max-age 300)
     (optimize-message-cache))))

;; Example: Get comprehensive stats
(defun get-system-stats ()
  "Get comprehensive system statistics"
  `(:performance ,(get-performance-stats)
    :connection ,(get-connection-pool-stats)
    :cache ,(optimize-message-cache)
    :health ,(get-health-status)
    :errors ,(get-error-rates)
    :circuit-breakers
    ,(loop for name being the hash-keys of *circuit-breakers*
           using (hash-value cb)
           collect (get-circuit-breaker-state name))))
```

---

## API Reference

### Performance Monitoring

| Function | Description |
|----------|-------------|
| `start-performance-monitoring` | Start monitoring |
| `stop-performance-monitoring` | Stop monitoring |
| `record-metric` | Record a metric |
| `get-performance-stats` | Get statistics |
| `reset-performance-stats` | Reset stats |
| `with-timing` | Time a block |
| `time-operation` | Time a function |
| `get-memory-usage` | Get memory stats |
| `trigger-garbage-collection` | Trigger GC |

### Connection Pool

| Function | Description |
|----------|-------------|
| `record-connection-stats` | Record connection event |
| `get-connection-pool-stats` | Get pool stats |
| `cleanup-stale-connections` | Clean stale connections |
| `optimize-connection-pool` | Get optimization suggestions |

### Cache

| Function | Description |
|----------|-------------|
| `get-cache-stats` | Get cache stats |
| `record-cache-hit/miss/eviction` | Record cache events |
| `implement-lru-eviction` | LRU eviction |
| `optimize-message-cache` | Cache optimization |

### Stability

| Function | Description |
|----------|-------------|
| `implement-auto-reconnect` | Configure reconnection |
| `make-auto-reconnect` | Create handler |
| `exponential-backoff` | Calculate delay |
| `with-retry` | Retry macro |
| `make-circuit-breaker` | Create breaker |
| `with-circuit-breaker` | Protected execution |
| `register-health-check` | Register check |
| `run-health-check` | Run check |
| `get-health-status` | Overall health |

---

## Best Practices

1. **Start monitoring early** - Call `start-performance-monitoring` at application startup
2. **Use meaningful metric names** - Prefix with component (e.g., `:api-call`, `:cache-hit`)
3. **Tag metrics appropriately** - Add context with tags for filtering
4. **Set appropriate thresholds** - Tune circuit breaker thresholds based on usage patterns
5. **Monitor health regularly** - Run health checks every 30-60 seconds
6. **Clean up periodically** - Run cleanup every 100 operations or 5 minutes
7. **Use exponential backoff** - Always use backoff for retries to prevent cascading failures
8. **Log at appropriate levels** - Use debug for verbose, info for normal, warn for issues, error for failures

---

**Version:** v0.16.0  
**Last Updated:** April 2026
