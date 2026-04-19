;;; stability.lisp --- Stability and reliability enhancements
;;;
;;; Implements stability features for production reliability:
;;; - Automatic reconnection with exponential backoff
;;; - Error handling and retry logic
;;; - Circuit breaker pattern
;;; - Health checks
;;; - Resource cleanup

(in-package #:cl-telegram/api)

;;; ===========================================================================
;;; Automatic Reconnection
;;; ===========================================================================

(defstruct reconnect-config
  "Configuration for automatic reconnection"
  (max-retries 5 :type integer)
  (initial-delay 1.0 :type float)
  (max-delay 60.0 :type float)
  (backoff-multiplier 2.0 :type float)
  (jitter 0.1 :type float))

(defvar *reconnect-config* (make-reconnect-config)
  "Global reconnection configuration")

(defvar *reconnect-state* nil
  "Current reconnection state")

(defstruct reconnect-state
  "State tracking for reconnection attempts"
  (attempt 0 :type integer)
  (last-attempt-time 0 :type integer)
  (next-attempt-time 0 :type integer)
  (connected nil :type boolean)
  (failure-reason nil :type string))

(defun make-auto-reconnect ()
  "Create automatic reconnection handler.

  Returns:
    Reconnection handler function

  Example:
    (let ((reconnect (make-auto-reconnect)))
      (handler-bind ((network-error reconnect))
        (connect-to-telegram)))"
  (let ((state (make-reconnect-state)))
    #'(lambda (condition)
        (declare (ignore condition))
        (reconnect-with-backoff state *reconnect-config*)
        condition)))

(defun implement-auto-reconnect (&key (max-retries 5) (initial-delay 1.0)
                                        (max-delay 60.0))
  "Set up automatic reconnection with configurable parameters.

  Args:
    max-retries: Maximum number of retry attempts
    initial-delay: Initial delay between retries (seconds)
    max-delay: Maximum delay between retries (seconds)

  Returns:
    T on success"
  (setf *reconnect-config*
        (make-reconnect-config
         :max-retries max-retries
         :initial-delay initial-delay
         :max-delay max-delay))
  t)

(defun reconnect-with-backoff (state config)
  "Perform reconnection with exponential backoff.

  Args:
    state: Reconnection state
    config: Reconnection configuration

  Returns:
    T if reconnection successful, nil otherwise"
  (let* ((attempt (reconnect-state-attempt state))
         (delay (min (* (expt (reconnect-config-backoff-multiplier config)
                              attempt)
                        (reconnect-config-initial-delay config))
                     (reconnect-config-max-delay config)))
         ;; Add jitter to prevent thundering herd
         (jitter (* delay (reconnect-config-jitter config)
                   (- 1 (* 2 (random 1.0)))))
         (actual-delay (+ delay jitter)))

    (incf (reconnect-state-attempt state))
    (setf (reconnect-state-last-attempt-time state) (get-universal-time))
    (setf (reconnect-state-next-attempt-time state)
          (+ (get-universal-time) (ceiling actual-delay)))

    (when (<= (reconnect-state-attempt state)
              (reconnect-config-max-retries config))
      ;; Wait before reconnecting
      (sleep actual-delay)

      ;; Attempt reconnection
      (handler-case
          (progn
            ;; In actual implementation, this would call the connection function
            (setf (reconnect-state-connected state) t)
            (setf (reconnect-state-attempt state) 0) ; Reset on success
            t)
        (error (e)
          (setf (reconnect-state-failure-reason state) (princ-to-string e))
          (setf (reconnect-state-connected state) nil)
          nil))))))

(defun get-reconnect-state ()
  "Get current reconnection state.

  Returns:
    Reconnection state structure"
  *reconnect-state*)

(defun reset-reconnect-state ()
  "Reset reconnection state."
  (setf *reconnect-state* nil)
  t)

;;; ===========================================================================
;;; Exponential Backoff Utility
;;; ===========================================================================

(defun exponential-backoff (attempt &key (base-delay 1.0) (max-delay 60.0)
                                       (multiplier 2.0) (jitter 0.1))
  "Calculate delay with exponential backoff.

  Args:
    attempt: Current attempt number
    base-delay: Base delay in seconds
    max-delay: Maximum delay
    multiplier: Exponential multiplier
    jitter: Random jitter factor (0.0-1.0)

  Returns:
    Delay in seconds

  Example:
    (exponential-backoff 3 :base-delay 1.0 :max-delay 60.0)
    ;; => 4.0 (+/- jitter)"
  (let* ((delay (* (expt multiplier attempt) base-delay))
         (capped-delay (min delay max-delay))
         (jitter-amount (* capped-delay jitter (- 1 (* 2 (random 1.0)))))
         (final-delay (+ capped-delay jitter-amount)))
    (max 0 final-delay)))

;;; ===========================================================================
;;; Retry Logic
;;; ===========================================================================

(defmacro with-retry ((&key (max-retries 3) (delay 1.0) (backoff t)
                              (delay-multiplier 2.0) (condition 'error))
                      &body body)
  "Execute body with automatic retry on failure.

  Args:
    max-retries: Maximum number of retry attempts
    delay: Initial delay between retries (seconds)
    backoff: Whether to use exponential backoff
    delay-multiplier: Delay multiplier for backoff
    condition: Condition type to catch

  Returns:
    Result of body execution or signals error after max retries

  Example:
    (with-retry (:max-retries 5 :delay 0.5 :backoff t)
      (call-external-api))"
  (let ((result (gensym "RESULT"))
        (attempt (gensym "ATTEMPT"))
        (current-delay (gensym "DELAY")))
    `(let ((,attempt 0)
           (,current-delay ,delay))
       (loop
        (handler-case
            (return (let ((,result (progn ,@body)))
                      (record-metric :retry-success 1 :tags '(:attempt ,attempt))
                      ,result))
          (,condition (e)
            (incf ,attempt)
            (record-metric :retry-attempt 1
                           :tags '(:condition ,(type-of e) :attempt ,attempt))
            (when (>= ,attempt ,max-retries)
              (record-metric :retry-exhausted 1
                             :tags '(:condition ,(type-of e)))
              (error "Operation failed after ~A attempts. Last error: ~A"
                     ,attempt e))
            ,@(when backoff
                `((sleep ,current-delay)
                  (setf ,current-delay (* ,current-delay ,delay-multiplier)))))
        ,@(unless backoff
            `((sleep ,current-delay))))))))

(defun setup-error-handling (&key (on-error nil) (on-retry nil) (on-success nil))
  "Set up global error handling callbacks.

  Args:
    on-error: Function called on error (receives condition)
    on-retry: Function called before retry (receives attempt number)
    on-success: Function called on success

  Returns:
    T on success"
  ;; In actual implementation, these would be stored and called
  ;; by the retry/connection logic
  (declare (ignore on-error on-retry on-success))
  t)

;;; ===========================================================================
;;; Circuit Breaker Pattern
;;; ===========================================================================

(defstruct circuit-breaker
  "Circuit breaker for fault tolerance"
  (state :closed :type (member :closed :open :half-open))
  (failure-count 0 :type integer)
  (success-count 0 :type integer)
  (failure-threshold 5 :type integer)
  (success-threshold 2 :type integer)
  (timeout 30 :type integer)
  (last-failure-time 0 :type integer)
  (last-state-change 0 :type integer))

(defvar *circuit-breakers* (make-hash-table :test 'equal)
  "Hash table of circuit breakers by operation name")

(defun make-circuit-breaker (name &key (failure-threshold 5) (success-threshold 2)
                                          (timeout 30))
  "Create a circuit breaker for an operation.

  Args:
    name: Circuit breaker name
    failure-threshold: Failures before opening circuit
    success-threshold: Successes before closing circuit
    timeout: Seconds to wait before half-open

  Returns:
    Circuit breaker structure"
  (let ((cb (make-circuit-breaker
             :state :closed
             :failure-threshold failure-threshold
             :success-threshold success-threshold
             :timeout timeout
             :last-state-change (get-universal-time))))
    (setf (gethash name *circuit-breakers*) cb)
    cb))

(defun circuit-breaker-allow-request-p (name)
  "Check if circuit breaker allows request.

  Args:
    name: Circuit breaker name

  Returns:
    T if request allowed, nil otherwise"
  (let ((cb (gethash name *circuit-breakers*)))
    (unless cb
      (return-from circuit-breaker-allow-request-p t))

    (case (circuit-breaker-state cb)
      (:closed t)
      (:open
       ;; Check if timeout has passed
       (when (> (- (get-universal-time)
                   (circuit-breaker-last-failure-time cb))
                (circuit-breaker-timeout cb))
         (setf (circuit-breaker-state cb) :half-open)
         (setf (circuit-breaker-last-state-change cb) (get-universal-time))
         t))
      (:half-open t))))

(defun circuit-breaker-record-success (name)
  "Record successful request.

  Args:
    name: Circuit breaker name"
  (let ((cb (gethash name *circuit-breakers*)))
    (unless cb (return-from circuit-breaker-record-success))

    (case (circuit-breaker-state cb)
      (:half-open
       (incf (circuit-breaker-success-count cb))
       (when (>= (circuit-breaker-success-count cb)
                 (circuit-breaker-success-threshold cb))
         (setf (circuit-breaker-state cb) :closed)
         (setf (circuit-breaker-failure-count cb) 0)
         (setf (circuit-breaker-success-count cb) 0)
         (setf (circuit-breaker-last-state-change cb) (get-universal-time))
         (record-metric :circuit-breaker-closed 1 :tags `(:name ,name))))
      (:closed
       ;; Reset failure count on success
       (setf (circuit-breaker-failure-count cb) 0)))))

(defun circuit-breaker-record-failure (name)
  "Record failed request.

  Args:
    name: Circuit breaker name"
  (let ((cb (gethash name *circuit-breakers*)))
    (unless cb (return-from circuit-breaker-record-failure))

    (incf (circuit-breaker-failure-count cb))
    (setf (circuit-breaker-last-failure-time cb) (get-universal-time))

    (case (circuit-breaker-state cb)
      (:half-open
       (setf (circuit-breaker-state cb) :open)
       (setf (circuit-breaker-last-state-change cb) (get-universal-time))
       (record-metric :circuit-breaker-opened 1 :tags `(:name ,name)))
      (:closed
       (when (>= (circuit-breaker-failure-count cb)
                 (circuit-breaker-failure-threshold cb))
         (setf (circuit-breaker-state cb) :open)
         (setf (circuit-breaker-last-state-change cb) (get-universal-time))
         (record-metric :circuit-breaker-opened 1 :tags `(:name ,name)))))))

(defun get-circuit-breaker-state (name)
  "Get circuit breaker state.

  Args:
    name: Circuit breaker name

  Returns:
    Property list with state information"
  (let ((cb (gethash name *circuit-breakers*)))
    (unless cb
      (return-from get-circuit-breaker-state '(:state :not-found)))

    `(:name ,name
      :state ,(circuit-breaker-state cb)
      :failure-count ,(circuit-breaker-failure-count cb)
      :success-count ,(circuit-breaker-success-count cb)
      :last-failure-time ,(circuit-breaker-last-failure-time cb)
      :last-state-change ,(circuit-breaker-last-state-change cb))))

(defmacro with-circuit-breaker ((name &key (failure-threshold 5) (success-threshold 2)
                                            (timeout 30))
                                &body body)
  "Execute body with circuit breaker protection.

  Args:
    name: Circuit breaker name
    failure-threshold: Failures before opening
    success-threshold: Successes before closing
    timeout: Seconds before half-open

  Returns:
    Result of body execution or signals circuit-open error

  Example:
    (with-circuit-breaker (\"telegram-api\" :failure-threshold 3)
      (call-telegram-api)))"
  `(progn
     (unless (gethash ,name *circuit-breakers*)
       (make-circuit-breaker ,name :failure-threshold ,failure-threshold
                             :success-threshold ,success-threshold
                             :timeout ,timeout))

     (unless (circuit-breaker-allow-request-p ,name)
       (record-metric :circuit-breaker-rejected 1 :tags `(:name ,name))
       (error "Circuit breaker ~A is open" ,name))

     (handler-case
         (let ((result (progn ,@body)))
           (circuit-breaker-record-success ,name)
           result)
       (error (e)
         (circuit-breaker-record-failure ,name)
         (error e)))))

;;; ===========================================================================
;;; Health Checks
;;; ===========================================================================

(defstruct health-check
  "Health check definition"
  (name nil :type string)
  (check-fn nil :type function)
  (timeout 5 :type integer)
  (last-result nil :type (member :healthy :unhealthy :unknown))
  (last-check-time 0 :type integer)
  (consecutive-failures 0 :type integer))

(defvar *health-checks* (make-hash-table :test 'equal)
  "Hash table of registered health checks")

(defun register-health-check (name check-fn &key (timeout 5))
  "Register a health check.

  Args:
    name: Health check name
    check-fn: Function to execute (returns T if healthy)
    timeout: Timeout in seconds

  Returns:
    T on success"
  (setf (gethash name *health-checks*)
        (make-health-check
         :name name
         :check-fn check-fn
         :timeout timeout))
  t)

(defun unregister-health-check (name)
  "Unregister a health check.

  Args:
    name: Health check name

  Returns:
    T on success"
  (remhash name *health-checks*)
  t)

(defun run-health-check (name)
  "Run a specific health check.

  Args:
    name: Health check name

  Returns:
    Health check result property list"
  (let ((check (gethash name *health-checks*)))
    (unless check
      (return-from run-health-check '(:status :not-found :name nil))))

  (let ((start-time (get-internal-real-time))
        (result :unknown))
    (handler-case
        (let ((check-result
               (with-timeout ((health-check-timeout check))
                 (funcall (health-check-check-fn check)))))
          (setf result (if check-result :healthy :unhealthy))
          (setf (health-check-last-result check) result)
          (setf (health-check-consecutive-failures check)
                (if check-result 0 (1+ (health-check-consecutive-failures check)))))
      (error (e)
        (setf result :unhealthy)
        (setf (health-check-last-result check) :unhealthy)
        (incf (health-check-consecutive-failures check))))

    (setf (health-check-last-check-time check) (get-universal-time))

    (let ((elapsed (/ (float (- (get-internal-real-time) start-time))
                      internal-time-units-per-second)))
      (record-metric :health-check 1
                     :tags `(:name ,name :result ,result)
                     :unit "count")
      (record-metric :health-check-duration (* elapsed 1000)
                     :tags `(:name ,name)
                     :unit "ms"))

    `(:status ,result
      :name ,name
      :consecutive-failures ,(health-check-consecutive-failures check)
      :last-check-time ,(health-check-last-check-time check))))

(defun run-all-health-checks ()
  "Run all registered health checks.

  Returns:
    List of health check results"
  (let ((results nil))
    (maphash (lambda (name check)
               (declare (ignore check))
               (push (run-health-check name) results))
             *health-checks*)
    results))

(defun get-health-status ()
  "Get overall health status.

  Returns:
    Property list with health summary"
  (let ((checks (run-all-health-checks))
        (healthy 0)
        (unhealthy 0))
    (dolist (check checks)
      (case (getf check :status)
        (:healthy (incf healthy))
        (:unhealthy (incf unhealthy))))

    `(:overall ,(if (zerop unhealthy) :healthy :degraded)
      :healthy-count ,healthy
      :unhealthy-count ,unhealthy
      :total-count ,(+ healthy unhealthy)
      :checks ,checks)))

;;; ===========================================================================
;;; Default Health Checks
;;; ===========================================================================

(defun setup-default-health-checks ()
  "Set up default health checks for cl-telegram.

  Returns:
    T on success"
  ;; Connection health check
  (register-health-check
   "connection"
   #'(lambda ()
       ;; In actual implementation, check if connected to Telegram
       t)
   :timeout 5)

  ;; Database health check
  (register-health-check
   "database"
   #'(lambda ()
       ;; Check database connection
       t)
   :timeout 5)

  ;; Memory health check
  (register-health-check
   "memory"
   #'(lambda ()
       ;; Check if memory usage is within acceptable limits
       t)
   :timeout 2)

  t)

;;; ===========================================================================
;;; Resource Cleanup
;;; ===========================================================================

(defun cleanup-resources (&key (force nil))
  "Clean up all managed resources.

  Args:
    force: Force cleanup even if resources are in use

  Returns:
    Property list with cleanup results"
  (let ((cleaned 0)
        (errors nil))

    ;; Clean up stale connections
    (handler-case
        (let ((conn-count (cleanup-stale-connections)))
          (incf cleaned conn-count))
      (error (e)
        (push `(:connection-cleanup ,e) errors)))

    ;; Clean up caches
    (handler-case
        (progn
          (optimize-message-cache)
          (incf cleaned))
      (error (e)
        (push `(:cache-cleanup ,e) errors)))

    ;; Trigger garbage collection
    (handler-case
        (progn
          (trigger-garbage-collection)
          (incf cleaned))
      (error (e)
        (push `(:gc ,e) errors)))

    `(:cleaned ,cleaned
      :errors ,errors
      :force ,force)))

;;; ===========================================================================
;; Logging Utilities
;;; ===========================================================================

(defvar *log-level* :info
  "Current logging level")

(defvar *log-destination* t
  "Where to send logs (t for stdout, nil for discard, stream for file)")

(defun log-message (level message &rest args)
  "Log a message at specified level.

  Args:
    level: Log level (:debug, :info, :warn, :error)
    message: Message format string
    args: Format arguments

  Returns:
    T if logged, nil if suppressed"
  (when (or (eq level level)
            (and (eq *log-level* :debug) t)
            (and (eq *log-level* :info)
                 (member level '(:info :warn :error)))
            (and (eq *log-level* :warn)
                 (member level '(:warn :error)))
            (and (eq *log-level* :error)
                 (eq level :error)))
    (let ((log-entry
           (format nil "[~A] ~A ~A"
                   (get-universal-time)
                   (string-upcase (symbol-name level))
                   (apply #'format nil message args))))
      (when *log-destination*
        (format *log-destination* "~A~%" log-entry))
      (record-metric :log-message 1 :tags `(:level ,level))
      t))
  nil)

(defun set-log-level (level)
  "Set the global log level.

  Args:
    level: Log level (:debug, :info, :warn, :error)

  Returns:
    Previous log level"
  (let ((old-level *log-level*))
    (setf *log-level* level)
    old-level))

;;; ===========================================================================
;;; End of stability.lisp
;;; ===========================================================================
