# Performance Optimization Guide

## Overview

This guide covers performance optimizations in cl-telegram v0.13.0+, including object pooling, efficient batch operations, and caching strategies.

## Table of Contents

1. [Object Pooling](#object-pooling)
2. [Large File Upload](#large-file-upload)
3. [Thumbnail Caching](#thumbnail-caching)
4. [Batch Operations](#batch-operations)
5. [String Optimization](#string-optimization)
6. [Connection Pool Monitoring](#connection-pool-monitoring)
7. [Error Handling](#error-handling)

---

## Object Pooling

Reduce GC pressure by reusing objects instead of creating new ones.

### Message Plist Pool

Pre-allocated pool of message plists for hot paths:

```lisp
;; Acquire message from pool
(let ((msg (cl-telegram/api:pool-acquire 'message-plist)))
  ;; Use message
  (setf (getf msg :id) 12345
        (getf msg :text) "Hello")
  
  ;; Process message
  (process-message msg)
  
  ;; Release back to pool
  (cl-telegram/api:pool-release 'message-plist msg))
```

### Byte Buffer Pool

Reusable byte buffers for network operations:

```lisp
;; Acquire buffer (4KB default)
(let ((buf (cl-telegram/api:pool-acquire 'byte-buffer)))
  ;; Ensure capacity
  (cl-telegram/api:ensure-buffer-capacity buf 8192)
  
  ;; Use buffer
  (write-data-to-buffer buf data)
  
  ;; Reset position for reuse
  (cl-telegram/api:reset-byte-buffer buf)
  
  ;; Release back to pool
  (cl-telegram/api:pool-release 'byte-buffer buf))
```

### Custom Object Pools

Create your own object pools:

```lisp
;; Define allocator and deallocator
(defun make-my-object ()
  (list :type 'my-object :data nil :created (get-universal-time)))

(defun reset-my-object (obj)
  (setf (getf obj :data) nil)
  t) ;; Return T to indicate successful reset

;; Initialize pool
(cl-telegram/api:pool-initialize
 'my-object-pool
 #'make-my-object
 :initial-count 20
 :max-size 100
 :deallocator #'reset-my-object)

;; Use pool
(let ((obj (cl-telegram/api:pool-acquire 'my-object-pool)))
  ;; Use object
  (process-object obj)
  ;; Release
  (cl-telegram/api:pool-release 'my-object-pool obj))
```

---

## Large File Upload

Optimized upload for files up to 4GB (Premium) or 2GB (Free).

### Upload Configuration

```lisp
;; Check upload limit
(let ((is-premium (cl-telegram/api:check-premium-status))
      (max-size (cl-telegram/api:get-max-file-size)))
  (format t "Max upload: ~A bytes (~A)~%"
          max-size
          (if is-premium "Premium 4GB" "Free 2GB")))
```

### Start Upload Session

```lisp
;; Start upload (automatically calculates optimal part size)
(let ((session-id (cl-telegram/api:start-file-upload "/path/to/large-file.zip")))
  (when session-id
    (format t "Upload started: ~A~%" session-id)))
```

### Upload Parts

```lisp
;; Upload parts sequentially
(let ((session-id (cl-telegram/api:start-file-upload "/path/to/file.dat")))
  (loop
    for part-index from 0
    for progress = (cl-telegram/api:get-upload-progress session-id)
    while (< (getf progress :uploaded-parts)
             (getf progress :total-parts))
    do (progn
         (cl-telegram/api:upload-file-part session-id part-index)
         (format t "Progress: ~A%~%" (getf progress :percent)))))
```

### Progress Tracking

```lisp
;; Get upload progress
(let ((progress (cl-telegram/api:get-upload-progress session-id)))
  (format t "Uploaded: ~A/~A parts (~A%)~%"
          (getf progress :uploaded-parts)
          (getf progress :total-parts)
          (getf progress :percent))
  (format t "Speed: ~A KB/s~%"
          (/ (getf progress :bytes-per-second) 1024)))
```

### Pause/Resume/Cancel

```lisp
;; Pause upload
(cl-telegram/api:pause-upload session-id)

;; Resume upload
(cl-telegram/api:resume-upload session-id)

;; Cancel upload (removes session)
(cl-telegram/api:cancel-upload session-id)
```

---

## Thumbnail Caching

LRU cache for story thumbnails (5MB default limit).

### Cache Thumbnails

```lisp
;; Cache thumbnail data
(cl-telegram/api:cache-story-thumbnail
 story-id
 thumbnail-data
 :width 320
 :height 568
 :mime-type "image/jpeg")
```

### Retrieve Cached Thumbnails

```lisp
;; Get cached thumbnail (updates access time for LRU)
(let ((thumb (cl-telegram/api:get-cached-story-thumbnail story-id)))
  (when thumb
    (let ((data (cl-telegram/api:story-thumbnail-data thumb))
          (width (cl-telegram/api:story-thumbnail-width thumb))
          (height (cl-telegram/api:story-thumbnail-height thumb)))
      ;; Use thumbnail data
      )))
```

### Preload Thumbnails

```lisp
;; Preload thumbnails for multiple stories
(cl-telegram/api:preload-stories-thumbnails
 '(123 456 789 101112))
```

### Cache Management

```lisp
;; Clear entire cache
(cl-telegram/api:clear-story-thumbnail-cache)

;; Automatic eviction (called when cache exceeds limit)
(cl-telegram/api:evict-oldest-thumbnails)
```

---

## Batch Operations

Efficient batch operations with minimal consing.

### Batch Get Users

```lisp
;; Returns vector instead of list (less consing)
(let ((users (cl-telegram/api:batch-get-users-no-cons
              '(123 456 789 101112))))
  ;; Access by index
  (loop for i from 0 below (length users)
        for user across users
        do (format t "User ~A: ~A~%"
                   i
                   (getf user :first-name))))
```

### Batch Insert Messages

```lisp
;; Batch insert with minimal consing
(let ((messages (vector
                 (list :id 1 :text "Hello" :date 1000)
                 (list :id 2 :text "World" :date 1001)
                 (list :id 3 :text "Test" :date 1002))))
  (cl-telegram/api:batch-insert-messages-no-cons
   chat-id
   messages))
```

---

## String Optimization

Fast string operations for hot paths.

### Format Chat ID

```lisp
;; Fast formatting (inline-friendly)
(cl-telegram/api:format-chat-id-fast -1001234567890)
;; => "-1001001234567890"

(cl-telegram/api:format-chat-id-fast 123456)
;; => "123456"
```

### Concatenate Strings

```lisp
;; Efficient concatenation (single allocation)
(cl-telegram/api:concat-strings-fast
 "Hello" " " "World" "!" " " "Test")
;; => "Hello World! Test"
```

### Keyword from String

```lisp
;; Fast keyword creation (uses cache for common keywords)
(cl-telegram/api:keyword-from-string-fast "test")
;; => :TEST
```

---

## Connection Pool Monitoring

Real-time connection statistics.

### Get Stats

```lisp
;; Get current stats
(let ((stats (cl-telegram/api:get-connection-pool-stats)))
  (format t "Total connections: ~A~%"
          (getf stats :total-connections))
  (format t "Healthy: ~A~%"
          (getf stats :healthy-connections))
  (format t "Avg latency: ~Ams~%"
          (getf stats :avg-latency))
  (format t "Total requests: ~A~%"
          (getf stats :total-requests)))
```

### Record Stats

```lisp
;; Record connection creation
(cl-telegram/api:record-connection-stats :created t)

;; Record request with latency
(cl-telegram/api:record-connection-stats
 :request t
 :latency 45.2) ;; ms

;; Record connection destruction
(cl-telegram/api:record-connection-stats :destroyed t)
```

### Reset Stats

```lisp
;; Reset all statistics
(cl-telegram/api:reset-connection-pool-stats)
```

---

## Error Handling

Robust error handling with retries.

### Safe API Call

```lisp
;; Call with automatic retries
(cl-telegram/api:safe-api-call
 (lambda ()
   (cl-telegram/api:send-message chat-id "Hello"))
 :retries 3
 :delay 1000) ;; ms between retries
```

### Time Operations

```lisp
;; Measure execution time
(cl-telegram/api:time-operation
 "send-message"
 (lambda ()
   (cl-telegram/api:send-message chat-id "Hello")))
;; => [PERF] send-message: 23.5ms
```

### Error Conditions

```lisp
;; Handle specific error types
(handler-case
    (cl-telegram/api:send-message chat-id "Hello")
  (cl-telegram/api:telegram-auth-error (e)
    (format t "Auth error: ~A~%"
            (cl-telegram/api:telegram-error-message e)))
  (cl-telegram/api:telegram-network-error (e)
    (format t "Network error: ~A~%"
            (cl-telegram/api:telegram-error-message e)))
  (cl-telegram/api:telegram-database-error (e)
    (format t "Database error: ~A~%"
            (cl-telegram/api:telegram-error-message e)))
  (cl-telegram/api:telegram-error (e)
    (format t "General error: ~A~%"
            (cl-telegram/api:telegram-error-message e))))
```

---

## Cache Cleanup

### Automatic Cleanup

```lisp
;; Clean old cache items (default: 7 days)
(cl-telegram/api:cleanup-old-cache :max-age-days 7)
```

### Vacuum All Caches

```lisp
;; Run full cache and database optimization
(cl-telegram/api:vacuum-all-caches)
```

This performs:
- Database VACUUM and ANALYZE
- Thumbnail eviction
- Completed upload cleanup

---

## Performance Monitoring

### Memory Usage

```lisp
;; Get current memory usage
(let ((mem (cl-telegram/api:get-memory-usage)))
  (format t "Dynamic: ~A~%" (getf mem :dynamic-usage))
  (format t "Static: ~A~%" (getf mem :static-usage))
  (format t "Read-only: ~A~%" (getf mem :read-only-usage)))
```

### Performance Counters

```lisp
;; Record custom metric
(cl-telegram/api:record-performance-metric
 "custom-operation"
 0.025) ;; seconds

;; Get all stats
(let ((stats (cl-telegram/api:get-performance-stats)))
  (dolist (stat stats)
    (format t "~A: count=~A avg=~Ams min=~Ams max=~Ams~%"
            (first stat)
            (getf (second stat) :count)
            (getf (second stat) :avg)
            (getf (second stat) :min)
            (getf (second stat) :max))))

;; Reset stats
(cl-telegram/api:reset-performance-stats)
```

---

## Best Practices

### 1. Use Object Pools in Hot Paths

```lisp
;; Good: Reuse objects
(loop for msg-data in messages
      do (let ((msg (pool-acquire 'message-plist)))
           (setf (getf msg :text) msg-data)
           (process msg)
           (pool-release 'message-plist msg)))

;; Bad: Create new objects each time
(loop for msg-data in messages
      do (let ((msg (list :id (random 1000) :text msg-data)))
           (process msg)))
```

### 2. Batch Database Operations

```lisp
;; Good: Single batch insert
(cl-telegram/api:batch-insert-messages-no-cons
 chat-id
 messages-vector)

;; Bad: N individual inserts
(loop for msg in messages
      do (insert-message chat-id msg))
```

### 3. Cache Expensive Operations

```lisp
;; Good: Cache and check first
(let ((cached (get-cached-story-thumbnail story-id)))
  (if cached
      (use-thumbnail cached)
      (let ((thumb (download-thumbnail story-id)))
        (cache-story-thumbnail story-id thumb)
        (use-thumbnail thumb))))

;; Bad: Always download
(let ((thumb (download-thumbnail story-id)))
  (use-thumbnail thumb))
```

### 4. Monitor and Tune

```lisp
;; Regularly check stats
(defun monitor-performance ()
  (let ((stats (get-connection-pool-stats)))
    (when (> (getf stats :unhealthy-connections)
             (getf stats :healthy-connections))
      (format t "Warning: More unhealthy than healthy connections!~%"))
    (when (> (getf stats :avg-latency) 1000)
      (format t "Warning: High average latency!~%"))))
```

---

## Troubleshooting

### High GC Pressure

**Symptoms:** Frequent GC pauses, high CPU usage

**Solutions:**
1. Increase object pool sizes
2. Use `batch-get-users-no-cons` instead of individual calls
3. Pre-allocate vectors for known-size collections

### Memory Leaks

**Symptoms:** Growing memory usage over time

**Solutions:**
1. Ensure all pool-acquired objects are released
2. Call `cleanup-old-cache` periodically
3. Check for unclosed upload sessions

### Slow Uploads

**Symptoms:** Upload speeds below expected

**Solutions:**
1. Check part size with `calculate-optimal-part-size`
2. Ensure stable network connection
3. Use pause/resume for large files

### Cache Thrashing

**Symptoms:** Low cache hit rate

**Solutions:**
1. Increase `*stories-thumbnail-max-size*`
2. Use `preload-stories-thumbnails` for known access patterns
3. Implement custom eviction policy

---

**Last Updated:** April 2026  
**Version:** v0.13.0
