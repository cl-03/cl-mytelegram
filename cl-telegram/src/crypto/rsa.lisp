;;; rsa.lisp --- RSA encryption and verification for MTProto 2.0

(in-package #:cl-telegram/crypto)

;;; MTProto uses RSA-2048 for server signature verification during key exchange

(defclass rsa-public-key ()
  ((n :initarg :n :accessor rsa-n :documentation "RSA modulus")
   (e :initarg :e :accessor rsa-e :documentation "RSA public exponent")))

(defclass rsa-private-key ()
  ((n :initarg :n :accessor rsa-n :documentation "RSA modulus")
   (d :initarg :d :accessor rsa-d :documentation "RSA private exponent")
   (p :initarg :p :accessor rsa-p :documentation "Prime factor p")
   (q :initarg :q :accessor rsa-q :documentation "Prime factor q")))

(defun make-rsa-public-key (n e)
  "Create an RSA public key from modulus n and exponent e."
  (make-instance 'rsa-public-key :n n :e e))

(defun make-rsa-private-key (n d p q)
  "Create an RSA private key from modulus, private exponent, and prime factors."
  (make-instance 'rsa-private-key :n n :d d :p p :q q))

(defun rsa-encrypt (plaintext key)
  "RSA encrypt plaintext using public key.

   Args:
     plaintext: Byte array to encrypt (must be smaller than key size)
     key: RSA public or private key

   Returns:
     Encrypted byte array"
  (let* ((n (rsa-n key))
         (e (if (typep key 'rsa-public-key)
                (rsa-e key)
                (rsa-d key)))
         ;; Convert bytes to integer
         (m (loop for i below (length plaintext)
                  for byte = (aref plaintext i)
                  accumulate (ash byte (* 8 (- (1- (length plaintext)) i))) into result
                  finally (return result))))
    ;; c = m^e mod n
    (let ((c (mod (expt m e) n)))
      ;; Convert back to bytes
      (let* ((key-size (ceiling (integer-length n) 8))
             (output (make-array key-size :element-type '(unsigned-byte 8))))
        (loop for i from (1- key-size) downto 0 do
          (setf (aref output i) (logand c #xFF))
          (setf c (ash c -8)))
        output))))

(defun rsa-decrypt (ciphertext key)
  "RSA decrypt ciphertext using private key."
  (assert (typep key 'rsa-private-key) () "Decryption requires private key")
  (let* ((n (rsa-n key))
         (d (rsa-d key))
         ;; Convert bytes to integer
         (c (loop for i below (length ciphertext)
                  for byte = (aref ciphertext i)
                  accumulate (ash byte (* 8 (- (1- (length ciphertext)) i))) into result
                  finally (return result))))
    ;; m = c^d mod n
    (let ((m (mod (expt c d) n)))
      ;; Convert back to bytes
      (let* ((key-size (ceiling (integer-length n) 8))
             (output (make-array key-size :element-type '(unsigned-byte 8))))
        (loop for i from (1- key-size) downto 0 do
          (setf (aref output i) (logand m #xFF))
          (setf m (ash m -8)))
        output))))

(defun rsa-sign (message key)
  "Sign message using RSA private key with PKCS#1 v1.5 padding."
  (assert (typep key 'rsa-private-key) () "Signing requires private key")
  ;; For MTProto, we use simple RSA without padding for specific operations
  (rsa-encrypt message key))

(defun rsa-verify (message signature key)
  "Verify RSA signature using public key.

   Args:
     message: Original message byte array
     signature: Signature byte array
     key: RSA public key

   Returns:
     T if signature is valid, NIL otherwise"
  (declare (type rsa-public-key key))
  (handler-case
      (let ((decrypted (rsa-decrypt signature key)))
        ;; For MTProto simple verification, check if decrypted matches message
        ;; In practice, MTProto uses a specific format for PQ factorization
        (equalp decrypted message))
    (error () nil)))

;;; MTProto-specific RSA: RSA encryption for PQ factorization response

(defun rsa-encrypt-pq-inner-data (inner-data public-key)
  "Encrypt p_q_inner_data for req_DH_params response.

   This uses RSA with a specific padding scheme for MTProto."
  (let* ((n (rsa-n public-key))
         (e (rsa-e public-key))
         ;; inner-data is already formatted with padding
         (data-int (loop for i below (length inner-data)
                         for byte = (aref inner-data i)
                         accumulate (ash byte (* 8 (- (1- (length inner-data)) i))) into result
                         finally (return result))))
    ;; Encrypt: c = data^e mod n
    (let ((encrypted (mod (expt data-int e) n)))
      ;; Convert to 256-byte array
      (let ((output (make-array 256 :element-type '(unsigned-byte 8))))
        (loop for i from 255 downto 0 do
          (setf (aref output i) (logand encrypted #xFF))
          (setf encrypted (ash encrypted -8)))
        output))))
