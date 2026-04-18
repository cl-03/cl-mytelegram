;;; aes-ige.lisp --- AES-256 IGE mode implementation for MTProto 2.0
;;;
;;; MTProto 2.0 uses AES-256 in IGE (Infinite Garble Extension) mode,
;;; which is not directly supported by ironclad. This file implements
;;; IGE mode on top of ironclad's AES block cipher.

(in-package #:cl-telegram/crypto)

;; MTProto uses 16-byte (128-bit) blocks for AES
(defconstant +aes-block-size+ 16)

;;; ### Low-level byte utilities

(deftype byte-array ()
  "(simple-array (unsigned-byte 8) (*))")

(defun bytes-to-uint128 (bytes)
  "Convert a 16-byte array to a 128-bit integer (big-endian)."
  (assert (= (length bytes) 16))
  (loop for i from 0 below 16
        for byte = (aref bytes i)
        accumulate (ash byte (* 8 (- 15 i))) into result
        finally (return result)))

(defun uint128-to-bytes (num)
  "Convert a 128-bit integer to a 16-byte array (big-endian)."
  (let ((bytes (make-array 16 :element-type '(unsigned-byte 8))))
    (loop for i from 15 downto 0 do
      (setf (aref bytes i) (logand num #xFF))
      (setf num (ash num -8)))
    bytes))

(defun uint256-to-bytes (num)
  "Convert a 256-bit integer to a 32-byte array (big-endian)."
  (let ((bytes (make-array 32 :element-type '(unsigned-byte 8))))
    (loop for i from 31 downto 0 do
      (setf (aref bytes i) (logand num #xFF))
      (setf num (ash num -8)))
    bytes))

(defun xor-bytes (a b)
  "XOR two byte arrays of equal length."
  (assert (= (length a) (length b)))
  (let ((result (make-array (length a) :element-type '(unsigned-byte 8))))
    (loop for i below (length a) do
      (setf (aref result i) (logxor (aref a i) (aref b i))))
    result))

;;; ### AES-256 IGE implementation

;; IGE Mode:
;; C[i] = AES(P[i] XOR C[i-1], K) XOR P[i-1]
;; P[i] = AES^-1(C[i] XOR P[i-1], K) XOR C[i-1]
;;
;; Where P[-1] = IV1 and C[-1] = IV2 (two 16-byte IVs)

(defun make-aes-ige-key (key-material)
  "Create an AES-256 IGE key from 32-byte key material.
   Returns a cipher object ready for encryption/decryption."
  (assert (= (length key-material) 32) () "AES-256 requires 32-byte key")
  (ironclad:make-cipher :aes :key key-material :mode :ecb))

(defun aes-block-encrypt (cipher block)
  "Encrypt a single 16-byte block using AES-256."
  (assert (= (length block) 16))
  (let ((output (make-array 16 :element-type '(unsigned-byte 8))))
    (ironclad:encrypt-in-place cipher block output)
    output))

(defun aes-block-decrypt (cipher block)
  "Decrypt a single 16-byte block using AES-256."
  (assert (= (length block) 16))
  (let ((output (make-array 16 :element-type '(unsigned-byte 8))))
    (ironclad:decrypt-in-place cipher block output)
    output))

(defun aes-ige-encrypt (plaintext key iv1 iv2)
  "Encrypt plaintext using AES-256 IGE mode.

   Args:
     plaintext: Byte array to encrypt (must be multiple of 16 bytes)
     key: AES-256 cipher object
     iv1: First 16-byte IV (P[-1])
     iv2: Second 16-byte IV (C[-1])

   Returns:
     Encrypted byte array

   Note: MTProto 2.0 requires plaintext to be padded to 16-byte boundary."
  (assert (= 0 (mod (length plaintext) 16)) () "Plaintext must be multiple of 16 bytes")
  (assert (= (length iv1) 16) () "IV1 must be 16 bytes")
  (assert (= (length iv2) 16) () "IV2 must be 16 bytes")

  (let* ((num-blocks (/ (length plaintext) 16))
         (ciphertext (make-array (length plaintext) :element-type '(unsigned-byte 8)))
         (prev-plain iv1)
         (prev-cipher iv2))
    (loop for i below num-blocks do
      (let* ((offset (* i 16))
             (plain-block (subseq plaintext offset (+ offset 16)))
             ;; XOR with previous ciphertext (or IV2 for first block)
             (xored (xor-bytes plain-block prev-cipher))
             ;; AES encrypt
             (encrypted (aes-block-encrypt cipher xored))
             ;; XOR with previous plaintext (or IV1 for first block)
             (cipher-block (xor-bytes encrypted prev-plain)))
        ;; Store result
        (replace ciphertext cipher-block :start1 offset)
        ;; Update previous blocks
        (setf prev-plain plain-block)
        (setf prev-cipher cipher-block)))
    ciphertext))

(defun aes-ige-decrypt (ciphertext key iv1 iv2)
  "Decrypt ciphertext using AES-256 IGE mode.

   Args:
     ciphertext: Byte array to decrypt (must be multiple of 16 bytes)
     key: AES-256 cipher object
     iv1: First 16-byte IV (P[-1])
     iv2: Second 16-byte IV (C[-1])

   Returns:
     Decrypted byte array"
  (assert (= 0 (mod (length ciphertext) 16)) () "Ciphertext must be multiple of 16 bytes")
  (assert (= (length iv1) 16) () "IV1 must be 16 bytes")
  (assert (= (length iv2) 16) () "IV2 must be 16 bytes")

  (let* ((num-blocks (/ (length ciphertext) 16))
         (plaintext (make-array (length ciphertext) :element-type '(unsigned-byte 8)))
         (prev-plain iv1)
         (prev-cipher iv2))
    (loop for i below num-blocks do
      (let* ((offset (* i 16))
             (cipher-block (subseq ciphertext offset (+ offset 16)))
             ;; XOR with previous plaintext (or IV1 for first block)
             (xored (xor-bytes cipher-block prev-plain))
             ;; AES decrypt
             (decrypted (aes-block-decrypt cipher xored))
             ;; XOR with previous ciphertext (or IV2 for first block)
             (plain-block (xor-bytes decrypted prev-cipher)))
        ;; Store result
        (replace plaintext plain-block :start1 offset)
        ;; Update previous blocks
        (setf prev-plain plain-block)
        (setf prev-cipher cipher-block)))
    plaintext))

;;; ### MTProto-specific padding

(defun mtproto-pad (data)
  "Pad data to 16-byte boundary using MTProto padding scheme.
   Adds 1-16 bytes of random padding, with first byte indicating
   padding length minus 1."
  (let* ((remainder (mod (length data) 16))
         (padding-len (- 16 remainder))
         (padding (make-array padding-len :element-type '(unsigned-byte 8))))
    ;; First byte is padding length - 1
    (setf (aref padding 0) (1- padding-len))
    ;; Rest is random
    (loop for i from 1 below padding-len do
      (setf (aref padding i) (random 256)))
    (concatenate '(simple-array (unsigned-byte 8)) data padding)))

(defun mtproto-unpad (data)
  "Remove MTProto padding from data."
  (assert (> (length data) 0))
  (let ((padding-len (1+ (aref data (1- (length data))))))
    (subseq data 0 (- (length data) padding-len))))
