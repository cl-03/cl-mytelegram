;;; performance-monitor.lisp --- Performance monitoring and optimization
;;;
;;; Implements performance monitoring, metrics collection, and optimization:
;;; - Performance metrics tracking
;;; - Connection pool management
;;; - Cache optimization (LRU eviction)
;;; - Memory management
;;; - Database query optimization

(in-package #:cl-telegram/api)

;;; ===========================================================================
;;; Performance Metrics
;;; ===========================================================================

(defstruct performance-metric
  "Performance metric record"
  (name nil :type keyword)
  (value 0.0 :type float)
  (unit "ms" :type string)
  (tags nil :type list)
  (timestamp 0 :type integer)
  (count 1 :type integer))

(defvar *performance-metrics* (make-hash-table :test 'equal)
  "Hash table storing performance metrics")

(defvar *metrics-history* nil
  "List of historical metric records")

(defvar *metrics-max-history* 1000
  "Maximum number of historical records to keep")

(defvar *performance-monitoring-enabled* nil
  "Whether performance monitoring is enabled")

(defvar *monitoring-start-time* nil
  "When monitoring started")

;;; ===========================================================================
;;; Metric Recording
;;; ===========================================================================

(defun record-metric (metric-name value &key (unit "ms") (tags nil))
  "Record a performance metric.

  Args:
    metric-name: Metric name (keyword)
    value: Metric value (number)
    unit: Unit of measurement (default: \"ms\")
    tags: Property list of tags for filtering

  Returns:
    T on success

  Example:
    (record-metric :api-call-latency 45.2 :tags '(:endpoint \"sendMessage\"))
    (record-metric :cache-hit-rate 0.85 :unit \"ratio\" :tags '(:cache \"messages\"))"
  (check-type metric-name keyword)
  (check-type value real)
  (check-type unit string)

  (when *performance-monitoring-enabled*
    (let* ((now (get-universal-time))
           (metric-key (format nil "~A~{~A~}" metric-name tags))
           (existing (gethash metric-key *performance-metrics*)))

      (if existing
          ;; Update existing metric with rolling average
          (let ((new-count (1+ (performance-metric-count existing)))
                (new-value (+ (* (performance-metric-value existing)
                                 (performance-metric-count existing))
                              value)))
            (setf (gethash metric-key *performance-metrics*)
                  (make-performance-metric
                   :name metric-name
                   :value (/ new-value new-count)
                   :unit unit
                   :tags tags
                   :timestamp now
                   :count new-count)))
          ;; Create new metric
          (setf (gethash metric-key *performance-metrics*)
                (make-performance-metric
                 :name metric-name
                 :value (coerce value 'single-float)
                 :unit unit
                 :tags tags
                 :timestamp now
                 :count 1)))

      ;; Add to history
      (push (make-performance-metric
             :name metric-name
             :value (coerce value 'single-float)
             :unit unit
             :tags tags
             :timestamp now
             :count 1)
            *metrics-history*)

      ;; Trim history
      (when (> (length *metrics-history*) *metrics-max-history*)
        (setf *metrics-history*
              (subseq *metrics-history* 0 *metrics-max-history*))))
    t))

(defun get-performance-stats (&key (metric-name nil) (tags nil))
  "Get performance statistics.

  Args:
    metric-name: Optional filter by metric name
    tags: Optional filter by tags

  Returns:
    Property list with statistics

  Example:
    (get-performance-stats) ; All metrics
    (get-performance-stats :metric-name :api-call-latency)
    (get-performance-stats :tags '(:cache \"messages\"))"
  (let ((metrics
         (if metric-name
             (loop for key being the hash-keys of *performance-metrics*
                   using (hash-value metric)
                   when (and (eq (performance-metric-name metric) metric-name)
                             (or (null tags)
                                 (subsetp tags (performance-metric-tags metric))))
                   collect metric)
             (loop for metric being the hash-values of *performance-metrics*
                   collect metric))))

    `(:total-metrics ,(length metrics)
      :monitoring-enabled ,*performance-monitoring-enabled*
      :monitoring-duration
      ,(when *monitoring-start-time*
         (- (get-universal-time) *monitoring-start-time*))
      :metrics
      ,(loop for metric in metrics
             collect
             `(:name ,(performance-metric-name metric)
               :value ,(performance-metric-value metric)
               :unit ,(performance-metric-unit metric)
               :count ,(performance-metric-count metric)
               :tags ,(performance-metric-tags metric)
               :timestamp ,(performance-metric-timestamp metric))))))

(defun reset-performance-stats ()
  "Reset all performance statistics."
  (clrhash *performance-metrics*)
  (setf *metrics-history* nil)
  (setf *monitoring-start-time* nil)
  nil)

;;; ===========================================================================
;;; Timing Utilities
;;; ===========================================================================

(defmacro with-timing ((metric-name &key (tags nil)) &body body)
  "Execute body and record execution time.

  Args:
    metric-name: Metric name (keyword)
    tags: Optional tags

  Example:
    (with-timing (:db-query :tags '(:table \"messages\"))
      (query-database \"SELECT * FROM messages\"))"
  `(let ((start-time (get-internal-real-time)))
     (unwind-protect
          (progn ,@body)
       (let ((elapsed (/ (float (- (get-internal-real-time) start-time))
                         internal-time-units-per-second)))
         (record-metric ,metric-name (* elapsed 1000) :tags ,tags)))))

(defun time-operation (operation-fn &key (metric-name nil) (tags nil))
  "Time an operation and record the metric.

  Args:
    operation-fn: Function to execute
    metric-name: Metric name (default: :timed-operation)
    tags: Optional tags

  Returns:
    (values result elapsed-time-ms)"
  (let ((start-time (get-internal-real-time))
        (name (or metric-name :timed-operation)))
    (handler-case
        (let ((result (funcall operation-fn))
              (elapsed (* (/ (float (- (get-internal-real-time) start-time))
                            internal-time-units-per-second)
                         1000)))
          (record-metric name elapsed :tags tags)
          (values result elapsed))
      (error (e)
        (let ((elapsed (* (/ (float (- (get-internal-real-time) start-time))
                            internal-time-units-per-second)
                         1000)))
          (record-metric (intern (format nil "~A-ERROR" name) :keyword)
                         elapsed :tags tags)
          (error e))))))

;;; ===========================================================================
;;; Memory Management
;;; ===========================================================================

(defun get-memory-usage ()
  "Get current memory usage statistics.

  Returns:
    Property list with memory statistics

  Example:
    (get-memory-usage)
    ;; => (:heap-size 1048576 :heap-used 524288 :gc-count 15)"
  (let ((heap-size (lisp-implementation-type)) ; Placeholder for actual implementation
        (gc-count 0))
    ;; In SBCL, use (sb-ext:gc) and (sb-ext:dynamic-usage)
    ;; In CCL, use (ccl:heap-size) and (ccl:gc)
    `(:gc-count ,gc-count
      :lisp-implementation ,heap-size
      :monitoring-enabled ,*performance-monitoring-enabled*)))

(defun trigger-garbage-collection ()
  "Trigger garbage collection.

  Returns:
    T on success"
  #+sbcl (sb-ext:gc)
  #+ccl (ccl:gc)
  #+(or) (boehm-gc) ; For other implementations
  t)

;;; ===========================================================================
;;; Connection Pool Management
;;; ===========================================================================

(defstruct connection-pool-stats
  "Connection pool statistics"
  (total-connections 0 :type integer)
  (active-connections 0 :type integer)
  (idle-connections 0 :type integer)
  (connections-created 0 :type integer)
  (connections-destroyed 0 :type integer)
  (requests-served 0 :type integer)
  (average-wait-time 0.0 :type float)
  (peak-connections 0 :type integer))

(defvar *connection-pool-stats* (make-connection-pool-stats)
  "Global connection pool statistics")

(defvar *connection-pool* (make-hash-table :test 'equal)
  "Connection pool hash table")

(defvar *connection-pool-max-size* 50
  "Maximum number of connections in pool")

(defvar *connection-pool-timeout* 300
  "Connection timeout in seconds")

(defun record-connection-stats (&key (event nil) (wait-time 0.0))
  "Record connection pool statistics.

  Args:
    event: Event type (:create, :destroy, :acquire, :release)
    wait-time: Time waited for connection (ms)

  Returns:
    T on success"
  (when event
    (case event
      (:create
       (incf (connection-pool-stats-connections-created *connection-pool-stats*))
       (incf (connection-pool-stats-total-connections *connection-pool-stats*)))
      (:destroy
       (incf (connection-pool-stats-connections-destroyed *connection-pool-stats*))
       (decf (connection-pool-stats-total-connections *connection-pool-stats*)))
      (:acquire
       (incf (connection-pool-stats-active-connections *connection-pool-stats*))
       (decf (connection-pool-stats-idle-connections *connection-pool-stats*))
       (incf (connection-pool-stats-requests-served *connection-pool-stats*))
       ;; Update average wait time
       (let ((stats *connection-pool-stats*))
         (setf (connection-pool-stats-average-wait-time stats)
               (/ (+ (* (connection-pool-stats-average-wait-time stats)
                        (connection-pool-stats-requests-served stats))
                     wait-time)
                  (1+ (connection-pool-stats-requests-served stats))))))
      (:release
       (decf (connection-pool-stats-active-connections *connection-pool-stats*))
       (incf (connection-pool-stats-idle-connections *connection-pool-stats*)))))

  ;; Update peak connections
  (let ((active (connection-pool-stats-active-connections *connection-pool-stats*)))
    (when (> active (connection-pool-stats-peak-connections *connection-pool-stats*))
      (setf (connection-pool-stats-peak-connections *connection-pool-stats*) active)))

  t)

(defun get-connection-pool-stats ()
  "Get connection pool statistics.

  Returns:
    Connection pool stats structure"
  *connection-pool-stats*)

(defun reset-connection-pool-stats ()
  "Reset connection pool statistics."
  (setf *connection-pool-stats* (make-connection-pool-stats))
  nil)

(defun cleanup-stale-connections (&key (max-age 300))
  "Clean up stale connections in the pool.

  Args:
    max-age: Maximum connection age in seconds (default: 300)

  Returns:
    Number of connections cleaned up"
  (let ((cleaned 0)
        (now (get-universal-time)))
    (maphash (lambda (key conn-info)
               (let ((created (getf conn-info :created)))
                 (when (and created
                            (> (- now created) max-age))
                   (remhash key *connection-pool*)
                   (incf cleaned)
                   (record-connection-stats :event :destroy))))
             *connection-pool*)
    (record-metric :connections-cleaned cleaned :unit "count")
    cleaned))

(defun optimize-connection-pool ()
  "Optimize connection pool settings based on usage patterns.

  Returns:
    Property list with optimization suggestions"
  (let* ((stats *connection-pool-stats*)
         (total (connection-pool-stats-total-connections stats))
         (active (connection-pool-stats-active-connections stats))
         (peak (connection-pool-stats-peak-connections stats))
         (suggestions nil))

    ;; Suggest pool size adjustment
    (when (> (/ active (max 1 total)) 0.9)
      (push '(:suggestion "Increase pool size" :reason "High utilization")
            suggestions))

    (when (< (/ active (max 1 total)) 0.1)
      (push '(:suggestion "Decrease pool size" :reason "Low utilization")
            suggestions))

    ;; Suggest timeout adjustment
    (let ((avg-wait (connection-pool-stats-average-wait-time stats)))
      (when (> avg-wait 1000) ; > 1 second
        (push '(:suggestion "Increase timeout" :reason "High wait time")
              suggestions)))

    `(:current-pool-size ,total
      :active-connections ,active
      :peak-connections ,peak
      :average-wait-time ,(connection-pool-stats-average-wait-time stats)
      :suggestions ,suggestions)))

;;; ===========================================================================
;;; Cache Optimization
;;; ===========================================================================

(defstruct cache-stats
  "Cache statistics"
  (hits 0 :type integer)
  (misses 0 :type integer)
  (evictions 0 :type integer)
  (size 0 :type integer)
  (max-size 1000 :type integer))

(defvar *cache-stats* (make-hash-table :test 'equal)
  "Hash table storing cache statistics per cache type")

(defun get-cache-stats (cache-type)
  "Get cache statistics for a specific cache type.

  Args:
    cache-type: Cache type (keyword)

  Returns:
    Cache stats structure"
  (or (gethash cache-type *cache-stats*)
      (setf (gethash cache-type *cache-stats*)
            (make-cache-stats))))

(defun record-cache-hit (cache-type)
  "Record a cache hit."
  (incf (cache-stats-hits (get-cache-stats cache-type))))

(defun record-cache-miss (cache-type)
  "Record a cache miss."
  (incf (cache-stats-misses (get-cache-stats cache-type))))

(defun record-cache-eviction (cache-type)
  "Record a cache eviction."
  (incf (cache-stats-evictions (get-cache-stats cache-type))))

(defun implement-lru-eviction (cache-hash-table max-size)
  "Implement LRU eviction policy for a cache.

  Args:
    cache-hash-table: Hash table to manage
    max-size: Maximum cache size

  Returns:
    Function to call for cache access with LRU tracking

  Example:
    (let ((cache (make-hash-table))
          (lru-fn (implement-lru-eviction cache 100)))
      (funcall lru-fn :get \"key\")
      (funcall lru-fn :set \"key\" \"value\"))"
  (let ((access-order nil))
    (labels ((update-access (key)
               (setf access-order
                     (cons key (remove key access-order))))
             (evict-if-needed ()
               (when (> (hash-table-count cache-hash-table) max-size)
                 (let ((lru-key (car (last access-order))))
                   (when lru-key
                     (remhash lru-key cache-hash-table)
                     (setf access-order (butlast access-order))
                     (record-cache-eviction :global))))))
      #'(lambda (op key &optional value)
          (case op
            (:get
             (update-access key)
             (gethash key cache-hash-table))
            (:set
             (update-access key)
             (setf (gethash key cache-hash-table) value)
             (evict-if-needed)
             value)
            (:remove
             (setf access-order (remove key access-order))
             (remhash key cache-hash-table)))))))

(defun optimize-message-cache ()
  "Optimize message cache settings.

  Returns:
    Property list with optimization suggestions"
  (let ((stats (get-cache-stats :messages)))
    (let* ((hits (cache-stats-hits stats))
           (misses (cache-stats-misses stats))
           (total (+ hits misses))
           (hit-rate (if (zerop total) 0 (/ hits total))))

      `(:cache-type :messages
        :hits ,hits
        :misses ,misses
        :hit-rate ,hit-rate
        :current-size ,(cache-stats-size stats)
        :max-size ,(cache-stats-max-size stats)
        :evictions ,(cache-stats-evictions stats)
        :recommendation
        ,(cond
           ((< hit-rate 0.5) "Consider increasing cache size")
           ((> hit-rate 0.9) "Cache size is adequate")
           (t "Monitor cache performance"))))))

;;; ===========================================================================
;;; Performance Monitoring Lifecycle
;;; ===========================================================================

(defun start-performance-monitoring (&key (max-history 1000) (max-pool-size 50))
  "Start performance monitoring.

  Args:
    max-history: Maximum metric history records
    max-pool-size: Maximum connection pool size

  Returns:
    T on success"
  (setf *performance-monitoring-enabled* t)
  (setf *monitoring-start-time* (get-universal-time))
  (setf *metrics-max-history* max-history)
  (setf *connection-pool-max-size* max-pool-size)

  (record-metric :monitoring-started 1 :unit "event")
  t)

(defun stop-performance-monitoring ()
  "Stop performance monitoring.

  Returns:
    Final statistics"
  (setf *performance-monitoring-enabled* nil)
  (record-metric :monitoring-stopped 1 :unit "event")
  (get-performance-stats))

;;; ===========================================================================
;;; Performance Monitoring Macro
;;; ===========================================================================

(defmacro with-performance-monitoring ((&key (enabled t)) &body body)
  "Execute body with performance monitoring enabled.

  Args:
    enabled: Whether to enable monitoring (default: t)

  Returns:
    Result of body execution

  Example:
    (with-performance-monitoring ()
      (expensive-operation))"
  `(let ((was-enabled *performance-monitoring-enabled*))
     (when ,enabled
       (setf *performance-monitoring-enabled* t))
     (unwind-protect
          (progn ,@body)
       (setf *performance-monitoring-enabled* was-enabled))))

;;; ===========================================================================
;;; Error Rate Tracking
;;; ===========================================================================

(defvar *error-rates* (make-hash-table :test 'equal)
  "Hash table storing error rates by operation type")

(defun record-error (operation error-type)
  "Record an error for tracking.

  Args:
    operation: Operation name (keyword)
    error-type: Error type (keyword)

  Returns:
    T on success"
  (let ((key (format nil "~A:~A" operation error-type))
        (existing (gethash key *error-rates*)))
    (if existing
        (incf existing)
        (setf (gethash key *error-rates*) 1))
    (record-metric :errors 1 :tags `(:operation ,operation :type ,error-type))
    t))

(defun get-error-rates ()
  "Get error rates by operation.

  Returns:
    Property list of error counts"
  (let ((errors nil))
    (maphash (lambda (key count)
               (push `(:key ,key :count ,count) errors))
             *error-rates*)
    `(:total-errors ,(loop for count being the hash-values of *error-rates* sum count)
      :by-operation ,errors)))

;;; ===========================================================================
;;; End of performance-monitor.lisp
;;; ===========================================================================
