;;; benchmark-tests.lisp --- Performance benchmark tests for cl-telegram
;;;
;;; Performance benchmarks:
;;; - Connection establishment latency
;;; - Message throughput
;;; - Encryption/decryption speed
;;; - Database query performance
;;; - Cache performance
;;; - Memory usage under load

(in-package #:cl-telegram/tests)

;;; ===========================================================================
;;; Benchmark Infrastructure
;;; ===========================================================================

(defstruct benchmark-result
  "Benchmark result record"
  (name nil :type string)
  (iterations 0 :type integer)
  (total-time 0.0 :type float)
  (min-time 0.0 :type float)
  (max-time 0.0 :type float)
  (avg-time 0.0 :type float)
  (throughput 0.0 :type float)
  (unit "ms" :type string)
  (timestamp 0 :type integer))

(defvar *benchmark-results* nil
  "List of benchmark results")

(defvar *benchmark-iterations* 100
  "Default number of benchmark iterations")

(defun run-benchmark (name fn &key (iterations *benchmark-iterations*))
  "Run a benchmark and collect statistics.

  Args:
    name: Benchmark name
    fn: Function to benchmark (called with no args)
    iterations: Number of iterations

  Returns:
    benchmark-result structure"
  (let ((times nil)
        (start-time (get-internal-real-time))
        (result nil))

    ;; Warmup
    (funcall fn)

    ;; Run benchmark
    (dotimes (i iterations)
      (let ((iter-start (get-internal-real-time)))
        (funcall fn)
        (let ((iter-time (/ (float (- (get-internal-real-time) iter-start))
                            internal-time-units-per-second)))
          (push (* iter-time 1000) times)))) ; Convert to ms

    ;; Calculate statistics
    (let* ((total-time (/ (float (- (get-internal-real-time) start-time))
                          internal-time-units-per-second))
           (sorted-times (sort times #'<))
           (min-time (first sorted-times))
           (max-time (car (last sorted-times)))
           (avg-time (/ (reduce #'+ times) (length times)))
           (throughput (/ iterations total-time)))

      (setf result (make-benchmark-result
                    :name name
                    :iterations iterations
                    :total-time (* total-time 1000)
                    :min-time min-time
                    :max-time max-time
                    :avg-time avg-time
                    :throughput throughput
                    :unit "ms"
                    :timestamp (get-universal-time)))

      ;; Store result
      (push result *benchmark-results*)

      ;; Print summary
      (format t "~%~A:~%" name)
      (format t "  Iterations: ~A~%" iterations)
      (format t "  Total: ~Ams~%" (round (benchmark-result-total-time result)))
      (format t "  Min: ~Ams~%" (format-nil "~,3F" min-time))
      (format t "  Max: ~Ams~%" (format-nil "~,3F" max-time))
      (format t "  Avg: ~Ams~%" (format-nil "~,3F" avg-time))
      (format t "  Throughput: ~A ops/sec~%" (round throughput))

      result)))

(defun format-nil (format-str &rest args)
  "Format number with specified precision."
  (apply #'format nil format-str args))

(defun get-benchmark-results ()
  "Get all benchmark results."
  *benchmark-results*)

(defun reset-benchmark-results ()
  "Reset benchmark results."
  (setf *benchmark-results* nil)
  t)

(defun print-benchmark-summary ()
  "Print summary of all benchmark results."
  (format t "~%~%========================================~%")
  (format t "BENCHMARK SUMMARY~%")
  (format t "========================================~%")
  (dolist (result (reverse *benchmark-results*))
    (format t "~A:~%" (benchmark-result-name result))
    (format t "  Avg: ~Ams | Throughput: ~A ops/sec~%"
            (format-nil "~,2F" (benchmark-result-avg-time result))
            (round (benchmark-result-throughput result))))
  (format t "========================================~%"))

;;; ===========================================================================
;;; Encryption Benchmarks
;;; ===========================================================================

(defun benchmark-aes-ige-encryption ()
  "Benchmark AES-256 IGE encryption."
  (let* ((key (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0))
         (iv (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0))
         (data (make-array 1024 :element-type '(unsigned-byte 8))))
    (dotimes (i 1024)
      (setf (aref data i) (random 256)))
    (cl-telegram/crypto::aes-ige-encrypt data key iv)))

(defun benchmark-aes-ige-decryption ()
  "Benchmark AES-256 IGE decryption."
  (let* ((key (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0))
         (iv (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0))
         (encrypted (make-array 1024 :element-type '(unsigned-byte 8) :initial-element 0)))
    (cl-telegram/crypto::aes-ige-decrypt encrypted key iv)))

(defun benchmark-sha256 ()
  "Benchmark SHA-256 hashing."
  (let ((data (make-array 1024 :element-type '(unsigned-byte 8))))
    (dotimes (i 1024)
      (setf (aref data i) (random 256)))
    (cl-telegram/crypto::sha256 data)))

(defun benchmark-rsa-encryption ()
  "Benchmark RSA encryption."
  (let* ((pubkey (cl-telegram/crypto::make-rsa-public-key :modulus 100 :exponent 3))
         (data (make-array 100 :element-type '(unsigned-byte 8))))
    (cl-telegram/crypto::rsa-encrypt data pubkey)))

(defun run-encryption-benchmarks (&key (iterations 1000))
  "Run all encryption benchmarks."
  (format t "~%Running Encryption Benchmarks...~%")
  (run-benchmark "AES-256-IGE-Encrypt" #'benchmark-aes-ige-encryption :iterations iterations)
  (run-benchmark "AES-256-IGE-Decrypt" #'benchmark-aes-ige-decryption :iterations iterations)
  (run-benchmark "SHA-256" #'benchmark-sha256 :iterations iterations)
  (run-benchmark "RSA-Encrypt" #'benchmark-rsa-encryption :iterations (min 100 iterations)))

;;; ===========================================================================
;;; TL Serialization Benchmarks
;;; ===========================================================================

(defun benchmark-tl-serialization ()
  "Benchmark TL serialization."
  (let ((obj '(:message :id 12345 :text "Hello" :date ,(get-universal-time))))
    (cl-telegram/tl::serialize-object obj)))

(defun benchmark-tl-deserialization ()
  "Benchmark TL deserialization."
  (let ((data (cl-telegram/tl::serialize-object
               '(:message :id 12345 :text "Hello" :date ,(get-universal-time)))))
    (cl-telegram/tl::deserialize-object data)))

(defun run-tl-benchmarks (&key (iterations 1000))
  "Run all TL serialization benchmarks."
  (format t "~%Running TL Serialization Benchmarks...~%")
  (run-benchmark "TL-Serialize" #'benchmark-tl-serialization :iterations iterations)
  (run-benchmark "TL-Deserialize" #'benchmark-tl-deserialization :iterations iterations))

;;; ===========================================================================
;;; Database Benchmarks
;;; ===========================================================================

(defun benchmark-db-insert ()
  "Benchmark database insert."
  (cl-telegram/api::cache-user :id (random 100000) :name "Test User"))

(defun benchmark-db-select ()
  "Benchmark database select."
  (cl-telegram/api::get-cached-user (random 100000)))

(defun benchmark-db-batch-insert ()
  "Benchmark batch database insert."
  (dotimes (i 100)
    (cl-telegram/api::cache-user :id i :name (format nil "User ~A" i))))

(defun run-database-benchmarks (&key (iterations 1000))
  "Run all database benchmarks."
  (format t "~%Running Database Benchmarks...~%")
  (run-benchmark "DB-Insert" #'benchmark-db-insert :iterations iterations)
  (run-benchmark "DB-Select" #'benchmark-db-select :iterations iterations)
  (run-benchmark "DB-Batch-Insert (100)" #'benchmark-db-batch-insert :iterations (min 10 iterations)))

;;; ===========================================================================
;;; Cache Benchmarks
;;; ===========================================================================

(defun benchmark-cache-hit ()
  "Benchmark cache hit."
  (cl-telegram/api::cache-user :id 1 :name "Test")
  (cl-telegram/api::get-cached-user 1))

(defun benchmark-cache-miss ()
  "Benchmark cache miss."
  (cl-telegram/api::get-cached-user 999999))

(defun benchmark-lru-eviction ()
  "Benchmark LRU eviction."
  (let ((cache (make-hash-table))
        (lru-fn (cl-telegram/api:implement-lru-eviction cache 100)))
    (dotimes (i 150) ; Exceeds max size, triggers eviction
      (funcall lru-fn :set i (format nil "Value ~A" i)))))

(defun run-cache-benchmarks (&key (iterations 1000))
  "Run all cache benchmarks."
  (format t "~%Running Cache Benchmarks...~%")
  (run-benchmark "Cache-Hit" #'benchmark-cache-hit :iterations iterations)
  (run-benchmark "Cache-Miss" #'benchmark-cache-miss :iterations iterations)
  (run-benchmark "LRU-Eviction (150 items)" #'benchmark-lru-eviction :iterations (min 10 iterations)))

;;; ===========================================================================
;;; Connection Benchmarks
;;; ===========================================================================

(defun benchmark-connection-pool-acquire ()
  "Benchmark connection pool acquisition."
  (cl-telegram/api:record-connection-stats :event :acquire :wait-time 0.1))

(defun benchmark-connection-cleanup ()
  "Benchmark connection cleanup."
  (cl-telegram/api:cleanup-stale-connections :max-age 300))

(defun run-connection-benchmarks (&key (iterations 1000))
  "Run all connection benchmarks."
  (format t "~%Running Connection Benchmarks...~%")
  (run-benchmark "Pool-Acquire" #'benchmark-connection-pool-acquire :iterations iterations)
  (run-benchmark "Connection-Cleanup" #'benchmark-connection-cleanup :iterations (min 100 iterations)))

;;; ===========================================================================
;;; Message Processing Benchmarks
;;; ===========================================================================

(defun benchmark-message-serialization ()
  "Benchmark message serialization."
  (let ((msg '(:sendMessage :chat_id 123456 :text "Hello")))
    (cl-telegram/tl::serialize-object msg)))

(defun benchmark-update-processing ()
  "Benchmark update processing."
  (let ((update '(:updateMessage :message_id 1 :text "Test")))
    (cl-telegram/api:dispatch-update update)))

(defun run-message-benchmarks (&key (iterations 1000))
  "Run all message processing benchmarks."
  (format t "~%Running Message Processing Benchmarks...~%")
  (run-benchmark "Message-Serialize" #'benchmark-message-serialization :iterations iterations)
  (run-benchmark "Update-Process" #'benchmark-update-processing :iterations iterations))

;;; ===========================================================================
;;; Stress Tests
;;; ===========================================================================

(defun benchmark-concurrent-cache-access ()
  "Benchmark concurrent cache access."
  (let ((threads 10)
        (operations 100))
    (cl-telegram/api:with-performance-monitoring ()
      (dotimes (i operations)
        (cl-telegram/api:record-cache-hit :test)
        (cl-telegram/api:record-cache-miss :test)))))

(defun benchmark-memory-under-load ()
  "Benchmark memory usage under load."
  (let ((objects nil))
    ;; Create many objects
    (dotimes (i 10000)
      (push (list :id i :name (format nil "Object ~A" i)) objects))
    ;; Force GC
    (cl-telegram/api:trigger-garbage-collection)
    ;; Get memory stats
    (cl-telegram/api:get-memory-usage)))

(defun run-stress-tests ()
  "Run stress tests."
  (format t "~%Running Stress Tests...~%")
  (run-benchmark "Concurrent-Cache (1000 ops)" #'benchmark-concurrent-cache-access :iterations 10)
  (run-benchmark "Memory-Load (10000 objects)" #'benchmark-memory-under-load :iterations 10))

;;; ===========================================================================
;;; Full Benchmark Suite
;;; ===========================================================================

(defun run-all-benchmarks (&key (iterations 1000))
  "Run all benchmarks.

  Args:
    iterations: Number of iterations for each benchmark

  Returns:
    List of benchmark results"
  (format t "~%========================================~%")
  (format t "CL-TELEGRAM PERFORMANCE BENCHMARKS~%")
  (format t "========================================~%")
  (format t "Iterations: ~A~%" iterations)
  (format t "Timestamp: ~A~%" (get-universal-time))

  (reset-benchmark-results)

  ;; Run all benchmark suites
  (run-encryption-benchmarks :iterations iterations)
  (run-tl-benchmarks :iterations iterations)
  (run-database-benchmarks :iterations iterations)
  (run-cache-benchmarks :iterations iterations)
  (run-connection-benchmarks :iterations iterations)
  (run-message-benchmarks :iterations iterations)
  (run-stress-tests)

  ;; Print summary
  (print-benchmark-summary)

  *benchmark-results*)

;;; ===========================================================================
;;; End of benchmark-tests.lisp
;;; ===========================================================================
