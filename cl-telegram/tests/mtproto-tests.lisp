;;; mtproto-tests.lisp --- Tests for MTProto protocol

(in-package #:cl-telegram/tests)

(def-suite* mtproto-tests
  :description "Tests for MTProto protocol layer")

;;; ### Auth tests

(test auth-state-initialization
  "Test auth state initialization"
  (let ((state (cl-telegram/mtproto:make-auth-state)))
    (is (typep state 'cl-telegram/mtproto:auth-state))
    (is (eq (cl-telegram/mtproto:auth-status state) :wait-tdlib-params))))

(test generate-nonce
  "Test nonce generation"
  (let ((nonce1 (cl-telegram/mtproto:generate-nonce 16))
        (nonce2 (cl-telegram/mtproto:generate-nonce 16)))
    (is (= (length nonce1) 16))
    (is (= (length nonce2) 16))
    ;; Nonces should be different (random)
    (is (not (equalp nonce1 nonce2)))))

(test generate-nonce-sizes
  "Test nonce generation with different sizes"
  (let ((nonce-16 (cl-telegram/mtproto:generate-nonce 16))
        (nonce-32 (cl-telegram/mtproto:generate-nonce 32)))
    (is (= (length nonce-16) 16))
    (is (= (length nonce-32) 32))))

;;; ### Encryption tests

(test encrypt-decrypt-roundtrip
  "Test message encryption/decryption roundtrip"
  (let ((auth-key (make-array 256 :initial-element 0))
        (message (make-array 32 :initial-element 65)))
    (multiple-value-bind (encrypted msg-key)
        (cl-telegram/mtproto:encrypt-message auth-key message :from-client t)
      (let ((decrypted (cl-telegram/mtproto:decrypt-message auth-key msg-key encrypted :from-client nil)))
        (is (equalp message decrypted))))))

(test encrypt-different-msg-key
  "Test that different messages produce different msg_keys"
  (let ((auth-key (make-array 256 :initial-element 0))
        (msg1 (make-array 32 :initial-element 65))
        (msg2 (make-array 32 :initial-element 66)))
    (multiple-value-bind (enc1 key1)
        (cl-telegram/mtproto:encrypt-message auth-key msg1 :from-client t)
      (multiple-value-bind (enc2 key2)
          (cl-telegram/mtproto:encrypt-message auth-key msg2 :from-client t)
        (is (not (equalp key1 key2)))
        (is (not (equalp enc1 enc2)))))))

;;; ### Transport tests

(test make-transport-packet
  "Test transport packet creation"
  (let ((auth-key-id (make-array 8 :initial-element 1))
        (msg-key (make-array 16 :initial-element 2))
        (encrypted-data (make-array 32 :initial-element 3)))
    (let ((packet (cl-telegram/mtproto:make-transport-packet auth-key-id msg-key encrypted-data)))
      (is (= (length packet) 56))  ; 8 + 16 + 32
      (multiple-value-bind (parsed-key-id parsed-key parsed-data)
          (cl-telegram/mtproto:parse-transport-packet packet)
        (is (equalp parsed-key-id auth-key-id))
        (is (equalp parsed-key msg-key))
        (is (equalp parsed-data encrypted-data))))))

(test compute-message-length
  "Test message length computation"
  (is (= (cl-telegram/mtproto:compute-message-length 100) 124))  ; 8 + 16 + 100
  (is (= (cl-telegram/mtproto:compute-message-length 0) 24)))    ; 8 + 16 + 0

;;; ### Integration test

(test full-auth-flow-placeholder
  "Placeholder for full auth flow test (requires network)"
  ;; This test would require actual network connection to Telegram servers
  ;; For now, just verify the auth functions exist
  (let ((state (cl-telegram/mtproto:make-auth-state)))
    (is (functionp #'cl-telegram/mtproto:auth-init))
    (is (functionp #'cl-telegram/mtproto:auth-send-pq-request))
    (is (functionp #'cl-telegram/mtproto:auth-handle-respq))
    (is (functionp #'cl-telegram/mtproto:auth-complete-p))))

(defun run-mtproto-tests ()
  "Run all MTProto tests"
  (run! 'mtproto-tests))

(defun run-network-tests ()
  "Run all network tests"
  (run! 'network-tests))

(defun run-api-tests ()
  "Run all API tests"
  (run! 'api-tests))

(defun run-ui-tests ()
  "Run all UI tests"
  (run! 'ui-tests))

(defun run-all-tests ()
  "Run all test suites"
  (run-crypto-tests)
  (run-tl-tests)
  (run-mtproto-tests)
  (run-network-tests)
  (run-api-tests)
  (run-ui-tests)
  (format t "~%~%All tests completed!~%"))
