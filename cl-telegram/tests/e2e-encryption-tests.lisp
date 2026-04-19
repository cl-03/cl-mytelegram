;;; e2e-encryption-tests.lisp --- Tests for E2E encryption enhancements
;;;
;;; Tests for secret chat key exchange, encrypted media,
;;; TTL, and security features

(in-package #:cl-telegram/tests)

;;; ### DH Key Exchange Tests

(deftest test-generate-dh-keypair-enhanced
  "Test enhanced DH keypair generation"
  (multiple-value-bind (private-key public-key)
      (cl-telegram/api:generate-dh-keypair-enhanced)
    ;; Check key sizes
    (is (= (length private-key) 256))
    (is (= (length public-key) 256))
    ;; Private key should be odd
    (is (= (logand (aref private-key 0) 1) 1))
    ;; Keys should not be all zeros
    (is (not (every #'zerop private-key)))
    (is (not (every #'zerop public-key)))))

(deftest test-telegram-dh-prime
  "Test Telegram DH prime retrieval"
  (let ((prime (cl-telegram/api:get-telegram-dh-prime)))
    (is (typep prime 'integer))
    ;; Prime should be 2048 bits
    (is (>= prime (expt 2 2047)))
    (is (< prime (expt 2 2048)))))

(deftest test-compute-shared-key-enhanced
  "Test shared key computation"
  (multiple-value-bind (private-key public-key)
      (cl-telegram/api:generate-dh-keypair-enhanced)
    (multiple-value-bind (private-key-2 public-key-2)
        (cl-telegram/api:generate-dh-keypair-enhanced)
      ;; Both parties should compute same shared key
      (let* ((shared-1 (cl-telegram/api:compute-shared-key-enhanced
                        private-key public-key-2))
             (shared-2 (cl-telegram/api:compute-shared-key-enhanced
                        private-key-2 public-key)))
        (is (equalp shared-1 shared-2))
        (is (= (length shared-1) 256))))))

;;; ### KDF Tests

(deftest test-kdf-secret-chat-enhanced
  "Test enhanced KDF"
  (let ((shared-key (make-array 256 :element-type '(unsigned-byte 8)
                                :initial-element 42)))
    (let ((auth-key (cl-telegram/api:kdf-secret-chat-enhanced shared-key)))
      (is (= (length auth-key) 256))
      ;; KDF should be deterministic
      (let ((auth-key-2 (cl-telegram/api:kdf-secret-chat-enhanced shared-key)))
        (is (equalp auth-key auth-key-2))))))

;;; ### Key Fingerprint Tests

(deftest test-compute-key-fingerprint
  "Test key fingerprint computation"
  (let ((auth-key (make-array 256 :element-type '(unsigned-byte 8)
                              :initial-element 1)))
    (let ((fingerprint (cl-telegram/api::compute-key-fingerprint auth-key)))
      (is (= (length fingerprint) 8))
      ;; Fingerprint should be unique for different keys
      (let ((auth-key-2 (make-array 256 :element-type '(unsigned-byte 8)
                                    :initial-element 2)))
        (let ((fingerprint-2 (cl-telegram/api::compute-key-fingerprint auth-key-2)))
          (is (not (equalp fingerprint fingerprint-2))))))))

(deftest test-verify-key-fingerprint
  "Test key fingerprint verification"
  (let ((auth-key (make-array 256 :element-type '(unsigned-byte 8)
                              :initial-element 1)))
    (let ((fingerprint (cl-telegram/api::compute-key-fingerprint auth-key)))
      ;; Self verification should pass
      (is (cl-telegram/api::verify-key-fingerprint-match auth-key fingerprint)))))

(defun verify-key-fingerprint-match (auth-key expected-fingerprint)
  "Helper to verify fingerprint matches"
  (let ((computed (cl-telegram/api::compute-key-fingerprint auth-key)))
    (equalp computed expected-fingerprint)))

;;; ### Encrypted Media Tests

(deftest test-encrypt-media-data
  "Test media encryption"
  (let* ((data (make-array 1024 :element-type '(unsigned-byte 8)
                           :initial-element 65))
         (key (cl-telegram/api:generate-cryptographically-safe-bytes 32))
         (iv (cl-telegram/api:generate-cryptographically-safe-bytes 32)))
    (let ((encrypted (cl-telegram/api:encrypt-media-data data key iv)))
      (is (= (length encrypted) (length data)))
      ;; Encrypted data should be different from plaintext
      (is (not (equalp data encrypted)))
      ;; Decryption should recover original
      (let ((decrypted (cl-telegram/api:decrypt-media-data encrypted key iv)))
        (is (equalp data decrypted))))))

(deftest test-generate-cryptographically-safe-bytes
  "Test cryptographic random byte generation"
  (let ((bytes-1 (cl-telegram/api:generate-cryptographically-safe-bytes 32))
        (bytes-2 (cl-telegram/api:generate-cryptographically-safe-bytes 32)))
    (is (= (length bytes-1) 32))
    (is (= (length bytes-2) 32))
    ;; Two generations should be different
    (is (not (equalp bytes-1 bytes-2)))))

(deftest test-guess-mime-type
  "Test MIME type guessing"
  (is (string= (cl-telegram/api:guess-mime-type "photo.jpg") "image/jpeg"))
  (is (string= (cl-telegram/api:guess-mime-type "image.png") "image/png"))
  (is (string= (cl-telegram/api:guess-mime-type "video.mp4") "video/mp4"))
  (is (string= (cl-telegram/api:guess-mime-type "document.pdf") "application/pdf"))
  (is (string= (cl-telegram/api:guess-mime-type "unknown.xyz") "application/octet-stream")))

;;; ### Message TTL Tests

(deftest test-schedule-message-self-destruct
  "Test message self-destruct scheduling"
  ;; This test verifies the function exists and has correct signature
  (is (fboundp 'cl-telegram/api:schedule-message-self-destruct)))

;;; ### Security Enhancement Tests

(deftest test-prevent-message-forwarding
  "Test message forwarding prevention"
  ;; Secret chat messages are inherently non-forwardable
  (let ((result (cl-telegram/api:prevent-message-forwarding 123 '(1 2 3))))
    (is (eq result t))))

(deftest test-cleanup-expired-secret-chats
  "Test expired chat cleanup"
  (is (fboundp 'cl-telegram/api:cleanup-expired-secret-chats)))

(deftest test-clear-secret-chat-history
  "Test chat history clearing"
  (is (fboundp 'cl-telegram/api:clear-secret-chat-history)))

;;; ### Integration Tests

(deftest test-e2e-encryption-api-existence
  "Test that all E2E encryption API functions exist"
  (is (fboundp 'cl-telegram/api:create-new-secret-chat))
  (is (fboundp 'cl-telegram/api:accept-secret-chat))
  (is (fboundp 'cl-telegram/api:verify-key-fingerprint))
  (is (fboundp 'cl-telegram/api:get-key-fingerprint-visual))
  (is (fboundp 'cl-telegram/api:send-encrypted-photo))
  (is (fboundp 'cl-telegram/api:send-encrypted-video))
  (is (fboundp 'cl-telegram/api:send-encrypted-document))
  (is (fboundp 'cl-telegram/api:set-message-ttl))
  (is (fboundp 'cl-telegram/api:get-secret-chat-stats)))

;;; ### Test Runner

(defun run-e2e-encryption-tests ()
  "Run all E2E encryption tests.

   Returns:
     T if all tests pass"
  (format t "~%Running E2E Encryption Tests...~%")
  (let ((results (list
                  (fiveam:run! 'test-generate-dh-keypair-enhanced)
                  (fiveam:run! 'test-telegram-dh-prime)
                  (fiveam:run! 'test-compute-shared-key-enhanced)
                  (fiveam:run! 'test-kdf-secret-chat-enhanced)
                  (fiveam:run! 'test-compute-key-fingerprint)
                  (fiveam:run! 'test-verify-key-fingerprint)
                  (fiveam:run! 'test-encrypt-media-data)
                  (fiveam:run! 'test-generate-cryptographically-safe-bytes)
                  (fiveam:run! 'test-guess-mime-type)
                  (fiveam:run! 'test-schedule-message-self-destruct)
                  (fiveam:run! 'test-prevent-message-forwarding)
                  (fiveam:run! 'test-cleanup-expired-secret-chats)
                  (fiveam:run! 'test-clear-secret-chat-history)
                  (fiveam:run! 'test-e2e-encryption-api-existence))))
    (if (every #'identity results)
        (progn
          (format t "All tests passed!~%")
          t)
        (progn
          (format t "Some tests failed!~%")
          nil))))
