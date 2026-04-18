;;; crypto-tests.lisp --- Tests for crypto layer

(in-package #:cl-telegram/tests)

(def-suite* crypto-tests
  :description "Tests for the crypto layer")

;;; ### AES-IGE tests

(test aes-ige-encrypt-decrypt
  "Test AES-256 IGE encryption and decryption roundtrip"
  (let* ((key-material (make-array 32 :initial-element 0))
         (iv1 (make-array 16 :initial-element 0))
         (iv2 (make-array 16 :initial-element 1))
         (plaintext (make-array 32 :initial-element 65))  ; "AA" + padding
         (cipher (cl-telegram/crypto:make-aes-ige-key key-material)))
    (multiple-value-bind (encrypted msg-key)
        (cl-telegram/crypto:aes-ige-encrypt plaintext cipher iv1 iv2)
      (declare (ignore msg-key))
      (let ((decrypted (cl-telegram/crypto:aes-ige-decrypt encrypted cipher iv1 iv2)))
        (is (equalp plaintext decrypted))))))

(test aes-ige-different-iv
  "Test that different IVs produce different ciphertexts"
  (let* ((key-material (make-array 32 :initial-element 0))
         (iv1-zeros (make-array 16 :initial-element 0))
         (iv1-ones (make-array 16 :initial-element 255))
         (iv2 (make-array 16 :initial-element 1))
         (plaintext (make-array 32 :initial-element 65))
         (cipher (cl-telegram/crypto:make-aes-ige-key key-material))
         (enc1 (cl-telegram/crypto:aes-ige-encrypt plaintext cipher iv1-zeros iv2))
         (enc2 (cl-telegram/crypto:aes-ige-encrypt plaintext cipher iv1-ones iv2)))
    (is (not (equalp enc1 enc2)))))

(test mtproto-pad-unpad
  "Test MTProto padding roundtrip"
  (let ((original (make-array 30 :initial-element 42)))
    (let ((padded (cl-telegram/crypto:mtproto-pad original)))
      (is (= 0 (mod (length padded) 16)))
      (let ((unpadded (cl-telegram/crypto:mtproto-unpad padded)))
        (is (equalp original unpadded))))))

;;; ### SHA-256 tests

(test sha256-basic
  "Test basic SHA-256 hashing"
  (let ((data (cl-babel:string-to-octets "test" :encoding :utf-8))
        ;; SHA256("test") = 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
        (expected #(159 134 208 129 136 76 125 101 154 47 250 160 197 90 208 21
                      163 191 79 27 43 11 130 44 209 93 108 21 176 240 10 8)))
    (let ((hash (cl-telegram/crypto:sha256 data)))
      (is (equalp hash expected)))))

;;; ### DH tests

(test dh-key-exchange
  "Test Diffie-Hellman key exchange"
  (multiple-value-bind (private-a public-a) (cl-telegram/crypto:dh-generate-keypair)
    (multiple-value-bind (private-b public-b) (cl-telegram/crypto:dh-generate-keypair)
      (let ((shared-a (cl-telegram/crypto:dh-compute-shared-secret public-b private-a))
            (shared-b (cl-telegram/crypto:dh-compute-shared-secret public-a private-b)))
        (is (= shared-a shared-b))))))

;;; ### KDF tests

(test kdf-msg-key
  "Test msg_key derivation"
  (let ((auth-key (make-array 256 :initial-element 0))
        (msg-data (make-array 32 :initial-element 1)))
    (let ((msg-key (cl-telegram/crypto:kdf-msg-key auth-key msg-data)))
      (is (= (length msg-key) 16)))))

(test kdf-aes-key-iv
  "Test AES key and IV derivation"
  (let ((auth-key (make-array 256 :initial-element 0))
        (msg-key (make-array 16 :initial-element 1)))
    (multiple-value-bind (aes-key iv)
        (cl-telegram/crypto:kdf-aes-key-iv auth-key msg-key t)
      (is (= (length aes-key) 32))
      (is (= (length iv) 32)))))

;;; ### Utility tests

(test xor-bytes
  "Test XOR operation"
  (let ((a #(1 2 3 4))
        (b #(5 6 7 8)))
    (let ((result (cl-telegram/crypto:xor-bytes a b)))
      (is (equalp result #(4 4 4 4))))))

(test bytes-to-hex
  "Test byte array to hex conversion"
  (let ((bytes #(255 128 64 32 16 8 4 2 1)))
    (let ((hex (cl-telegram/crypto:bytes-to-hex bytes)))
      (is (stringp hex)))))

(defun run-crypto-tests ()
  "Run all crypto tests"
  (run! 'crypto-tests))
