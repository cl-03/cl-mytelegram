;;; tl-tests.lisp --- Tests for TL serialization

(in-package #:cl-telegram/tests)

(def-suite* tl-tests
  :description "Tests for TL serialization layer")

;;; ### Primitive serialization tests

(test serialize-int32-roundtrip
  "Test int32 serialization roundtrip"
  (let ((value 123456789))
    (let ((serialized (cl-telegram/tl:serialize-int32 value)))
      (is (= (length serialized) 4))
      (let ((deserialized (cl-telegram/tl:deserialize-int32 serialized 0)))
        (is (= deserialized value))))))

(test serialize-int32-negative
  "Test negative int32 serialization"
  (let ((value -100))
    (let ((serialized (cl-telegram/tl:serialize-int32 value)))
      (is (= (length serialized) 4))
      (let ((deserialized (cl-telegram/tl:deserialize-int32 serialized 0)))
        (is (= deserialized value))))))

(test serialize-int64-roundtrip
  "Test int64 serialization roundtrip"
  (let ((value 9223372036854775807))  ; Max int64
    (let ((serialized (cl-telegram/tl:serialize-int64 value)))
      (is (= (length serialized) 8))
      (let ((deserialized (cl-telegram/tl:deserialize-int64 serialized 0)))
        (is (= deserialized value))))))

(test serialize-bytes-short
  "Test short byte array serialization (< 254 bytes)"
  (let ((data #(1 2 3 4 5 6 7 8)))
    (let ((serialized (cl-telegram/tl:serialize-bytes data)))
      ;; Length byte + data + padding
      (is (>= (length serialized) 9))
      (is (= 0 (mod (length serialized) 4)))
      (let ((deserialized (cl-telegram/tl:deserialize-bytes serialized 0)))
        (is (equalp deserialized data))))))

(test serialize-string
  "Test string serialization"
  (let ((string "Hello, Telegram!"))
    (let ((serialized (cl-telegram/tl:serialize-string string)))
      (is (> (length serialized) 0))
      (is (= 0 (mod (length serialized) 4)))
      (let ((deserialized (cl-telegram/tl:deserialize-string serialized 0)))
        (is (string= deserialized string))))))

(test serialize-bool
  "Test boolean serialization"
  (let ((true-serialized (cl-telegram/tl:serialize-bool t))
        (false-serialized (cl-telegram/tl:serialize-bool nil)))
    (is (not (equalp true-serialized false-serialized)))
    ;; Check constructor IDs
    (is (= (cl-telegram/tl:deserialize-int32 true-serialized 0) #x997275bc))
    (is (= (cl-telegram/tl:deserialize-int32 false-serialized 0) #xbc799731))))

(test serialize-vector
  "Test vector serialization"
  (let ((vector #(1 2 3 4 5)))
    (let ((serialized (cl-telegram/tl:serialize-vector vector #'cl-telegram/tl:serialize-int32)))
      ;; Length (4) + elements (5*4) = 24
      (is (= (length serialized) 24))
      (let ((deserialized (cl-telegram/tl:deserialize-vector serialized #'cl-telegram/tl:deserialize-int32)))
        (is (equalp (coerce deserialized 'vector) vector))))))

;;; ### TL object tests

(test serialize-respq-roundtrip
  "Test resPQ serialization roundtrip"
  (let* ((nonce (make-array 16 :initial-element 1))
         (server-nonce (make-array 16 :initial-element 2))
         (pq #(1 2 3 4 5))
         (fingerprints (vector #x1234567890ABCDEF #xFEDCBA0987654321))
         (respq (cl-telegram/tl:make-respq
                 :nonce nonce
                 :server-nonce server-nonce
                 :pq pq
                 :fingerprints fingerprints)))
    (let ((serialized (cl-telegram/tl:tl-serialize respq)))
      (is (> (length serialized) 0))
      (let ((deserialized (cl-telegram/tl:tl-deserialize serialized 0)))
        (is (typep deserialized 'cl-telegram/tl:respq))
        (is (equalp (cl-telegram/tl:respq-nonce deserialized) nonce))
        (is (equalp (cl-telegram/tl:respq-server-nonce deserialized) server-nonce))
        (is (equalp (cl-telegram/tl:respq-pq deserialized) pq))))))

(test serialize-td-ok
  "Test ok serialization"
  (let ((ok (make-instance 'cl-telegram/tl:td-ok)))
    (let ((serialized (cl-telegram/tl:tl-serialize ok)))
      (is (= (length serialized) 4))
      (is (= (cl-telegram/tl:deserialize-int32 serialized 0)
             cl-telegram/tl:+constructor-id-td-ok+)))))

(test serialize-td-error
  "Test error serialization"
  (let ((error (cl-telegram/tl:make-td-error
                :code 404
                :message "Not found")))
    (let ((serialized (cl-telegram/tl:tl-serialize error)))
      (is (> (length serialized) 8))
      (let ((deserialized (cl-telegram/tl:tl-deserialize serialized 0)))
        (is (typep deserialized 'cl-telegram/tl:td-error))
        (is (= (cl-telegram/tl:td-error-code deserialized) 404))
        (is (string= (cl-telegram/tl:td-error-message deserialized) "Not found"))))))

(defun run-tl-tests ()
  "Run all TL tests"
  (run! 'tl-tests))
