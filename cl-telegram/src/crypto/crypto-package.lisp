;;; crypto-package.lisp --- Package definition for crypto layer

(defpackage #:cl-telegram/crypto
  (:nicknames #:cl-tg/crypto)
  (:use #:cl)
  (:export
   ;; AES-256 IGE
   #:aes-ige-encrypt
   #:aes-ige-decrypt
   #:make-aes-ige-key

   ;; SHA-256
   #:sha256
   #:sha256-hmac

   ;; RSA
   #:rsa-verify
   #:rsa-encrypt
   #:make-rsa-public-key
   #:make-rsa-private-key

   ;; Diffie-Hellman
   #:dh-compute-key
   #:dh-generate-keypair
   #:*dh-p*
   #:*dh-g*

   ;; KDF
   #:kdf-auth-key
   #:kdf-msg-key
   #:kdf-temp-auth-key

   ;; Utilities
   #:xor-bytes
   #:bytes-to-hex
   #:hex-to-bytes))
