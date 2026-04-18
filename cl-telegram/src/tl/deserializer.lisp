;;; deserializer.lisp --- TL deserialization for MTProto 2.0

(in-package #:cl-telegram/tl)

(defvar *deserializer-offset* 0
  "Current position in the byte stream during deserialization.")

;;; ### Low-level deserialization primitives

(defun deserialize-int32 (bytes)
  "Deserialize a 32-bit signed integer (little-endian)."
  (let ((b0 (aref bytes *deserializer-offset*))
        (b1 (aref bytes (1+ *deserializer-offset*)))
        (b2 (aref bytes (+ 2 *deserializer-offset*)))
        (b3 (aref bytes (+ 3 *deserializer-offset*))))
    (incf *deserializer-offset* 4)
    ;; Handle sign extension for negative numbers
    (let ((value (logior b0 (ash b1 8) (ash b2 16) (ash b3 24))))
      (if (logbitp 31 value)
          (- value (expt 2 32))
          value))))

(defun deserialize-int64 (bytes)
  "Deserialize a 64-bit signed integer (little-endian)."
  (let ((value 0))
    (loop for i from 0 below 8 do
      (setf value (logior value (ash (aref bytes (+ *deserializer-offset* i)) (* i 8)))))
    (incf *deserializer-offset* 8)
    value))

(defun deserialize-int128 (bytes)
  "Deserialize a 128-bit integer as 16-byte array (little-endian)."
  (let ((result (make-array 16 :element-type '(unsigned-byte 8))))
    (loop for i from 0 below 16 do
      (setf (aref result i) (aref bytes (+ *deserializer-offset* i))))
    (incf *deserializer-offset* 16)
    result))

(defun deserialize-int256 (bytes)
  "Deserialize a 256-bit integer as 32-byte array (little-endian)."
  (let ((result (make-array 32 :element-type '(unsigned-byte 8))))
    (loop for i from 0 below 32 do
      (setf (aref result i) (aref bytes (+ *deserializer-offset* i))))
    (incf *deserializer-offset* 32)
    result))

(defun deserialize-bytes (bytes)
  "Deserialize a length-prefixed byte array.

   TL bytes format:
   - If first byte <= 253: 1-byte length + data + padding
   - If first byte = 0xfe: 1-byte marker + 3-byte length + data + padding"
  (let ((first-byte (aref bytes *deserializer-offset*)))
    (if (<= first-byte 253)
        ;; Short form
        (let ((len first-byte)
              (padding (mod (- 4 (mod (1+ len) 4)) 4)))
          (incf *deserializer-offset* 1)
          (let ((result (make-array len :element-type '(unsigned-byte 8))))
            (loop for i from 0 below len do
              (setf (aref result i) (aref bytes (+ *deserializer-offset* i))))
            (incf *deserializer-offset* (+ len padding))
            result))
        ;; Long form
        (progn
          (incf *deserializer-offset* 1)  ; skip 0xfe marker
          (let* ((len (logior (aref bytes *deserializer-offset*)
                              (ash (aref bytes (1+ *deserializer-offset*)) 8)
                              (ash (aref bytes (+ 2 *deserializer-offset*)) 16)))
                 (padding (mod (- 4 (mod (+ 4 len) 4)) 4)))
            (incf *deserializer-offset* 3)
            (let ((result (make-array len :element-type '(unsigned-byte 8))))
              (loop for i from 0 below len do
                (setf (aref result i) (aref bytes (+ *deserializer-offset* i))))
              (incf *deserializer-offset* (+ len padding))
              result))))))

(defun deserialize-string (bytes)
  "Deserialize a length-prefixed UTF-8 string."
  (cl-babel:octets-to-string (deserialize-bytes bytes) :encoding :utf-8))

(defun deserialize-bool (bytes)
  "Deserialize a boolean value."
  (let ((tag (deserialize-int32 bytes)))
    (cond
      ((= tag #x997275bc) t)   ; boolTrue
      ((= tag #xbc799731) nil) ; boolFalse
      (t (error "Invalid bool tag: #x~8,'0X" tag)))))

(defun deserialize-vector (bytes element-deserializer)
  "Deserialize a vector of elements."
  (let ((len (deserialize-int32 bytes)))
    (loop for i below len
          collect (funcall element-deserializer bytes))))

;;; ### Main deserialization function

(defun tl-deserialize (bytes &optional (offset 0))
  "Deserialize bytes to a TL object.

   Args:
     bytes: Byte array containing serialized TL data
     offset: Starting offset (default 0)

   Returns:
     TL object (struct or primitive value)"
  (let ((*deserializer-offset* offset))
    (let ((constructor-id (deserialize-int32 bytes)))
      (decf *deserializer-offset* 4)  ; Put back offset for type-specific parser
      (cond
        ;; MTProto protocol types
        ((= constructor-id +constructor-id-respq+)
         (deserialize-respq bytes))
        ((= constructor-id +constructor-id-server-dh-params-ok+)
         (deserialize-server-dh-params bytes))
        ((= constructor-id +constructor-id-server-dh-inner-data+)
         (deserialize-server-dh-inner-data bytes))
        ((= constructor-id +constructor-id-dh-gen-ok+)
         (deserialize-dh-gen-ok bytes))
        ((= constructor-id +constructor-id-client-dh-inner-data+)
         (deserialize-client-dh-inner-data bytes))
        ((= constructor-id +constructor-id-p-q-inner-data+)
         (deserialize-p-q-inner-data bytes))
        ((= constructor-id +constructor-id-rpc-error+)
         (deserialize-rpc-error bytes))
        ;; TDLib types
        ((= constructor-id +constructor-id-td-error+)
         (deserialize-td-error bytes))
        ((= constructor-id +constructor-id-td-ok+)
         (make-instance 'td-ok))
        (t
         (error "Unknown constructor ID: #x~8,'0X" constructor-id))))))

;;; ### Struct-specific deserializers

(defun deserialize-respq (bytes)
  "Deserialize resPQ object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-respq+))
    (make-respq
     :nonce (deserialize-int128 bytes)
     :server-nonce (deserialize-int128 bytes)
     :pq (deserialize-bytes bytes)
     :fingerprints (deserialize-vector bytes #'deserialize-int64))))

(defun deserialize-server-dh-params (bytes)
  "Deserialize server_DH_params_ok object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-server-dh-params-ok+))
    (make-server-dh-params-ok
     :nonce (deserialize-int128 bytes)
     :server-nonce (deserialize-int128 bytes)
     :encrypted-answer (deserialize-bytes bytes))))

(defun deserialize-server-dh-inner-data (bytes)
  "Deserialize server_DH_inner_data object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-server-dh-inner-data+))
    (make-server-dh-inner-data
     :nonce (deserialize-int128 bytes)
     :server-nonce (deserialize-int128 bytes)
     :g (deserialize-int32 bytes)
     :dh-prime (deserialize-bytes bytes)
     :g-a (deserialize-bytes bytes)
     :server-time (deserialize-int32 bytes))))

(defun deserialize-dh-gen-ok (bytes)
  "Deserialize dh_gen_ok object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-dh-gen-ok+))
    (make-dh-gen-ok
     :nonce (deserialize-int128 bytes)
     :server-nonce (deserialize-int128 bytes)
     :new-nonce-hash (deserialize-int128 bytes))))

(defun deserialize-client-dh-inner-data (bytes)
  "Deserialize client_DH_inner_data object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-client-dh-inner-data+))
    (make-client-dh-inner-data
     :nonce (deserialize-int128 bytes)
     :server-nonce (deserialize-int128 bytes)
     :retry-id (deserialize-int64 bytes)
     :g-b (deserialize-bytes bytes))))

(defun deserialize-p-q-inner-data (bytes)
  "Deserialize p_q_inner_data object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-p-q-inner-data+))
    (make-p-q-inner-data
     :pq (deserialize-bytes bytes)
     :p (deserialize-bytes bytes)
     :q (deserialize-bytes bytes)
     :nonce (deserialize-int128 bytes)
     :server-nonce (deserialize-int128 bytes)
     :new-nonce (deserialize-int256 bytes)
     :dc (deserialize-int32 bytes))))

(defun deserialize-rpc-error (bytes)
  "Deserialize rpc_error object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-rpc-error+))
    (make-rpc-error
     :error-code (deserialize-int32 bytes)
     :error-message (deserialize-string bytes))))

(defun deserialize-td-error (bytes)
  "Deserialize td_error object."
  (let ((constructor (deserialize-int32 bytes)))
    (assert (= constructor +constructor-id-td-error+))
    (make-td-error
     :code (deserialize-int32 bytes)
     :message (deserialize-string bytes))))

;;; ### Convenience functions

(defun tl-deserialize-from-bytes (bytes &optional (offset 0))
  "Deserialize bytes to TL object (alias for tl-deserialize)."
  (tl-deserialize bytes offset))

(defun deserialize-message (bytes)
  "Deserialize a complete MTProto message including header."
  (let ((auth-key-id (subseq bytes 0 8))
        (msg-key (subseq bytes 8 24))
        (encrypted-data (subseq bytes 24)))
    (list :auth-key-id auth-key-id
          :msg-key msg-key
          :encrypted-data encrypted-data)))
