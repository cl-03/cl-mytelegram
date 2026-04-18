;;; serializer.lisp --- TL serialization for MTProto 2.0

(in-package #:cl-telegram/tl)

;;; ### Low-level serialization primitives

(defun serialize-int32 (value)
  "Serialize a 32-bit integer (little-endian)."
  (let ((bytes (make-array 4 :element-type '(unsigned-byte 8))))
    (setf (aref bytes 0) (logand value #xFF)
          (aref bytes 1) (logand (ash value -8) #xFF)
          (aref bytes 2) (logand (ash value -16) #xFF)
          (aref bytes 3) (logand (ash value -24) #xFF))
    bytes))

(defun serialize-int64 (value)
  "Serialize a 64-bit integer (little-endian)."
  (let ((bytes (make-array 8 :element-type '(unsigned-byte 8))))
    (loop for i from 0 below 8 do
      (setf (aref bytes i) (logand (ash value (* i -8)) #xFF)))
    bytes))

(defun serialize-int128 (bytes)
  "Serialize a 128-bit integer from 16-byte array (little-endian)."
  (assert (= (length bytes) 16))
  (copy-seq bytes))

(defun serialize-int256 (bytes)
  "Serialize a 256-bit integer from 32-byte array (little-endian)."
  (assert (= (length bytes) 256))
  (copy-seq bytes))

(defun serialize-bytes (data)
  "Serialize a byte array with length prefix.

   TL bytes format:
   - If length <= 253: 1-byte length + data + padding
   - If length > 253: 1-byte (0xfe) + 3-byte length + data + padding
   - Padding: 0-3 zero bytes to make total length divisible by 4"
  (let* ((len (length data))
         (output
          (if (<= len 253)
              ;; Short form: 1-byte length
              (let ((total-len (+ 1 len (mod (- 4 (mod (+ 1 len) 4)) 4))))
                (let ((bytes (make-array total-len :element-type '(unsigned-byte 8))))
                  (setf (aref bytes 0) len)
                  (replace bytes data :start1 1)
                  bytes))
              ;; Long form: 0xfe + 3-byte length
              (let* ((prefix-len 4)
                     (padding (mod (- 4 (mod (+ prefix-len len) 4)) 4))
                     (total-len (+ prefix-len len padding))
                     (bytes (make-array total-len :element-type '(unsigned-byte 8))))
                (setf (aref bytes 0) #xfe)
                (setf (aref bytes 1) (logand len #xFF))
                (setf (aref bytes 2) (logand (ash len -8) #xFF))
                (setf (aref bytes 3) (logand (ash len -16) #xFF))
                (replace bytes data :start1 4)
                bytes))))
    output))

(defun serialize-string (string)
  "Serialize a UTF-8 string with length prefix."
  (serialize-bytes (cl-babel:string-to-octets string :encoding :utf-8)))

(defun serialize-bool (value)
  "Serialize a boolean value.

   true  = #x997275bc (boolTrue)
   false = #xbc799731 (boolFalse)"
  (if value
      (serialize-int32 #x997275bc)
      (serialize-int32 #xbc799731)))

(defun serialize-vector (elements serializer-fn)
  "Serialize a vector of elements.

   Format: 4-byte length + serialized elements"
  (let* ((len (length elements))
         (serialized-elements (mapcar serializer-fn elements))
         (data-len (reduce #'+ serialized-elements :key #'length))
         (total-len (+ 4 data-len))
         (bytes (make-array total-len :element-type '(unsigned-byte 8))))
    (replace bytes (serialize-int32 len) :start2 0)
    (loop with offset = 4
          for elem in serialized-elements do
            (replace bytes elem :start1 offset)
            (incf offset (length elem)))
    bytes))

;;; ### Main serialization function

(defun tl-serialize (object)
  "Serialize a TL object to bytes.

   Args:
     object: TL object (struct or tl-object instance)

   Returns:
     Byte array containing serialized data"
  (cond
    ;; Handle primitive types
    ((typep object '(signed-byte 32))
     (serialize-int32 object))
    ((typep object '(signed-byte 64))
     (serialize-int64 object))
    ((typep object '(simple-array (unsigned-byte 8) (*)))
     (serialize-bytes object))
    ((stringp object)
     (serialize-string object))
    ((booleanp object)
     (serialize-bool object))
    ((vectorp object)
     (serialize-vector object #'tl-serialize))

    ;; Handle TL structs
    ((typep object 'respq)
     (serialize-respq object))
    ((typep object 'server-dh-params-ok)
     (serialize-server-dh-params object))
    ((typep object 'server-dh-inner-data)
     (serialize-server-dh-inner-data object))
    ((typep object 'dh-gen-ok)
     (serialize-dh-gen-ok object))
    ((typep object 'client-dh-inner-data)
     (serialize-client-dh-inner-data object))
    ((typep object 'p-q-inner-data)
     (serialize-p-q-inner-data object))
    ((typep object 'rpc-error)
     (serialize-rpc-error object))
    ((typep object 'td-error)
     (serialize-td-error object))
    ((typep object 'td-ok)
     (serialize-td-ok object))

    (t
     (error "Cannot serialize unknown type: ~S" object))))

;;; ### Struct-specific serializers

(defun serialize-respq (obj)
  "Serialize resPQ object."
  (let* ((constructor (serialize-int32 +constructor-id-respq+))
         (nonce (serialize-int128 (respq-nonce obj)))
         (server-nonce (serialize-int128 (respq-server-nonce obj)))
         (pq (serialize-bytes (respq-pq obj)))
         (fingerprints (serialize-vector (respq-fingerprints obj)
                                         #'serialize-int64))
         (total-len (+ (length constructor) (length nonce) (length server-nonce)
                       (length pq) (length fingerprints))))
    (concatenate '(simple-array (unsigned-byte 8))
                 constructor nonce server-nonce pq fingerprints)))

(defun serialize-p-q-inner-data (obj)
  "Serialize p_q_inner_data object."
  (let* ((constructor (serialize-int32 +constructor-id-p-q-inner-data+))
         (pq (serialize-bytes (pqi-pq obj)))
         (p (serialize-bytes (pqi-p obj)))
         (q (serialize-bytes (pqi-q obj)))
         (nonce (serialize-int128 (pqi-nonce obj)))
         (server-nonce (serialize-int128 (pqi-server-nonce obj)))
         (new-nonce (serialize-int256 (pqi-new-nonce obj)))
         (dc (serialize-int32 (pqi-dc obj))))
    (concatenate '(simple-array (unsigned-byte 8))
                 constructor pq p q nonce server-nonce new-nonce dc)))

(defun serialize-client-dh-inner-data (obj)
  "Serialize client_DH_inner_data object."
  (let* ((constructor (serialize-int32 +constructor-id-client-dh-inner-data+))
         (nonce (serialize-int128 (cdhi-nonce obj)))
         (server-nonce (serialize-int128 (cdhi-server-nonce obj)))
         (retry-id (serialize-int64 (cdhi-retry-id obj)))
         (g-b (serialize-bytes (cdhi-g-b obj))))
    (concatenate '(simple-array (unsigned-byte 8))
                 constructor nonce server-nonce retry-id g-b)))

(defun serialize-td-ok (obj)
  "Serialize ok object."
  (serialize-int32 +constructor-id-td-ok+))

(defun serialize-td-error (obj)
  "Serialize error object."
  (let ((constructor (serialize-int32 +constructor-id-td-error+))
        (code (serialize-int32 (td-error-code obj)))
        (message (serialize-string (td-error-message obj))))
    (concatenate '(simple-array (unsigned-byte 8))
                 constructor code message)))

;;; ### Convenience function

(defun tl-serialize-to-bytes (object)
  "Serialize TL object to bytes (alias for tl-serialize)."
  (tl-serialize object))
