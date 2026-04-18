;;; sha256.lisp --- SHA-256 hash function wrapper for MTProto 2.0

(in-package #:cl-telegram/crypto)

(defun sha256 (data)
  "Compute SHA-256 hash of data.

   Args:
     data: Byte array or string to hash

   Returns:
     32-byte array containing the hash"
  (let ((input (if (stringp data)
                   (cl-babel:string-to-octets data :encoding :utf-8)
                   data)))
    (ironclad:digest-sequence :sha256 input)))

(defun sha256-hmac (key data)
  "Compute HMAC-SHA256 of data using key.

   Args:
     key: Secret key (byte array)
     data: Data to authenticate (byte array)

   Returns:
     32-byte array containing the HMAC"
  (let ((key (if (stringp key)
                 (cl-babel:string-to-octets key :encoding :utf-8)
                 key))
        (data (if (stringp data)
                  (cl-babel:string-to-octets data :encoding :utf-8)
                  data)))
    (ironclad:make-hmac key :sha256)
    (ironclad:hmac-sign (ironclad:make-hmac key :sha256) data)))
