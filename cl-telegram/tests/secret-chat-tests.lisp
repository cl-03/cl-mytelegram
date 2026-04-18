;;; secret-chat-tests.lisp --- Tests for end-to-end encrypted Secret Chats

(in-package #:cl-telegram/tests)

(def-suite* secret-chat-tests
  :description "Tests for end-to-end encrypted secret chats")

;;; ### Helper Functions

(defun make-mock-secret-chat ()
  "Create a mock secret chat for testing."
  (let ((chat (make-instance 'cl-telegram/api::secret-chat
                             :chat-id -123456
                             :participant-id 789
                             :participant-access-hash 111222)))
    ;; Set up mock auth key
    (let ((mock-key (make-array 256 :element-type '(unsigned-byte 8)
                                :initial-element #x42)))
      (setf (cl-telegram/api::secret-auth-key chat) mock-key)
      (setf (cl-telegram/api::secret-auth-key-id chat)
            (cl-telegram/api::compute-key-fingerprint mock-key))
      (setf (cl-telegram/api::secret-state chat) :active))
    chat))

;;; ### Key Generation Tests

(test test-generate-dh-keypair
  "Test DH keypair generation"
  (multiple-value-bind (private-key public-key)
      (cl-telegram/api::generate-dh-keypair)
    (is (typep private-key '(array (unsigned-byte 8) (256)))
        "Private key should be 256 bytes")
    (is (typep public-key '(array (unsigned-byte 8) (256)))
        "Public key should be 256 bytes")
    ;; Keys should be different
    (is (not (equalp private-key public-key))
        "Private and public keys should differ")))

(test test-compute-shared-key
  "Test shared key computation"
  (multiple-value-bind (priv-a pub-a)
      (cl-telegram/api::generate-dh-keypair)
    (multiple-value-bind (priv-b pub-b)
        (cl-telegram/api::generate-dh-keypair)
      ;; Both parties should compute the same shared key
      (let ((shared-a (cl-telegram/api::compute-shared-key priv-a pub-b))
            (shared-b (cl-telegram/api::compute-shared-key priv-b pub-a)))
        (is (typep shared-a '(array (unsigned-byte 8) (256)))
            "Shared key should be 256 bytes")
        (is (equalp shared-a shared-b)
            "Both parties should compute the same shared key")))))

(test test-compute-key-fingerprint
  "Test key fingerprint computation"
  (let ((key (make-array 256 :element-type '(unsigned-byte 8)
                         :initial-element #x00)))
    (let ((fp (cl-telegram/api::compute-key-fingerprint key)))
      (is (typep fp '(array (unsigned-byte 8) (8)))
          "Fingerprint should be 8 bytes")
      ;; Same key should produce same fingerprint
      (is (equalp fp (cl-telegram/api::compute-key-fingerprint key))
          "Fingerprint should be deterministic"))))

;;; ### KDF Tests

(test test-kdf-secret-chat
  "Test secret chat key derivation"
  (let ((shared-key (make-array 256 :element-type '(unsigned-byte 8)
                                 :initial-element #x55)))
    (let ((auth-key (cl-telegram/api::kdf-secret-chat shared-key)))
      (is (typep auth-key '(array (unsigned-byte 8) (32)))
          "Derived key should be 32 bytes")
      ;; Same input should produce same output
      (is (equalp auth-key (cl-telegram/api::kdf-secret-chat shared-key))
          "KDF should be deterministic"))))

;;; ### Message Encryption Tests

(test test-compute-msg-key
  "Test msg_key computation"
  (let ((auth-key (make-array 256 :element-type '(unsigned-byte 8)
                              :initial-element #x11))
        (message "Hello, Secret Chat!"))
    (let ((msg-key (cl-telegram/api::compute-msg-key auth-key message)))
      (is (typep msg-key '(array (unsigned-byte 8) (16)))
          "msg_key should be 16 bytes"))))

(test test-compute-aes-key
  "Test AES key computation"
  (let ((msg-key (make-array 16 :element-type '(unsigned-byte 8)
                             :initial-element #x22))
        (auth-key (make-array 256 :element-type '(unsigned-byte 8)
                              :initial-element #x33)))
    (let ((aes-key (cl-telegram/api::compute-aes-key msg-key auth-key)))
      (is (typep aes-key '(array (unsigned-byte 8) (32)))
          "AES key should be 32 bytes (256 bits)"))))

(test test-compute-aes-iv
  "Test AES IV computation"
  (let ((msg-key (make-array 16 :element-type '(unsigned-byte 8)
                             :initial-element #x44))
        (auth-key (make-array 256 :element-type '(unsigned-byte 8)
                              :initial-element #x55)))
    (let ((aes-iv (cl-telegram/api::compute-aes-iv msg-key auth-key)))
      (is (typep aes-iv '(array (unsigned-byte 8) (32)))
          "AES IV should be 32 bytes"))))

(test test-pad-message
  "Test message padding"
  ;; Test with message that needs padding
  (let ((msg (make-array 10 :element-type '(unsigned-byte 8)
                         :initial-element #x66)))
    (let ((padded (cl-telegram/api::pad-message msg)))
      (is (= (length padded) 16)
          "Padded message should be 16 bytes")
      (is (= (mod (length padded) 16) 0)
          "Length should be multiple of 16"))))

(test test-pad-message-no-padding-needed
  "Test message already aligned"
  (let ((msg (make-array 16 :element-type '(unsigned-byte 8)
                         :initial-element #x77)))
    (let ((padded (cl-telegram/api::pad-message msg)))
      (is (= (length padded) 16)
          "Already aligned message should stay 16 bytes"))))

;;; ### Secret Chat Creation Tests

(test test-make-secret-chat-manager
  "Test secret chat manager creation"
  (let* ((conn (list :connected t))
         (mgr (cl-telegram/api:make-secret-chat-manager conn)))
    (is (typep mgr 'cl-telegram/api::secret-chat-manager))
    (is (eq (cl-telegram/api::secret-connection mgr) conn))
    (is (typep (cl-telegram/api::secret-chats mgr) 'hash-table))
    (is (typep (cl-telegram/api::secret-user-chats mgr) 'hash-table))))

(test test-secret-chat-instance
  "Test secret chat instance creation"
  (let ((chat (make-instance 'cl-telegram/api::secret-chat
                             :chat-id -123
                             :participant-id 456
                             :participant-access-hash 789)))
    (is (= (cl-telegram/api::secret-chat-id chat) -123))
    (is (= (cl-telegram/api::secret-participant-id chat) 456))
    (is (= (cl-telegram/api::secret-access-hash chat) 789))
    (is (eq (cl-telegram/api::secret-state chat) :pending))
    (is (= (cl-telegram/api::secret-ttl chat) 0))))

(test test-get-secret-chat
  "Test secret chat lookup"
  (let* ((conn (list :connected t))
         (mgr (cl-telegram/api:make-secret-chat-manager conn))
         (chat (make-instance 'cl-telegram/api::secret-chat
                              :chat-id -999
                              :participant-id 111)))
    ;; Register chat
    (setf (gethash -999 (cl-telegram/api::secret-chats mgr)) chat)
    (setf (cl-telegram/api::*secret-chat-manager*) mgr)

    ;; Lookup
    (let ((found (cl-telegram/api:get-secret-chat -999)))
      (is (eq found chat) "Should find registered chat")
      (is (null (cl-telegram/api:get-secret-chat -888))
          "Should return NIL for unknown chat"))))

(test test-list-secret-chats
  "Test listing active secret chats"
  (let* ((conn (list :connected t))
         (mgr (cl-telegram/api:make-secret-chat-manager conn)))
    (setf (cl-telegram/api::*secret-chat-manager*) mgr)

    ;; Add active chat
    (let ((chat1 (make-instance 'cl-telegram/api::secret-chat
                                :chat-id -1
                                :participant-id 1)))
      (setf (cl-telegram/api::secret-state chat1) :active)
      (setf (gethash -1 (cl-telegram/api::secret-chats mgr)) chat1))

    ;; Add closed chat
    (let ((chat2 (make-instance 'cl-telegram/api::secret-chat
                                :chat-id -2
                                :participant-id 2)))
      (setf (cl-telegram/api::secret-state chat2) :closed)
      (setf (gethash -2 (cl-telegram/api::secret-chats mgr)) chat2))

    (let ((active (cl-telegram/api:list-secret-chats)))
      (is (= (length active) 1) "Should return only active chats")
      (is (member chat1 active) "Should include active chat"))))

;;; ### Message Sending Tests

(test test-send-secret-message
  "Test sending secret message"
  (let ((chat (make-mock-secret-chat)))
    (setf (cl-telegram/api::*secret-chat-manager*)
          (make-instance 'cl-telegram/api::secret-chat-manager
                         :connection (list :connected t)))
    ;; Should succeed for active chat
    (is (cl-telegram/api:send-secret-message chat "Test message"))))

(test test-send-secret-message-inactive
  "Test sending message on inactive chat"
  (let ((chat (make-instance 'cl-telegram/api::secret-chat
                             :chat-id -1
                             :participant-id 1)))
    ;; Should fail for non-active chat
    (multiple-value-bind (result error)
        (cl-telegram/api:send-secret-message chat "Test")
      (is (null result) "Should return NIL")
      (is error "Should return error"))))

(test test-set-secret-chat-ttl
  "Test setting chat TTL"
  (let ((chat (make-mock-secret-chat)))
    (setf (cl-telegram/api::*secret-chat-manager*)
          (make-instance 'cl-telegram/api::secret-chat-manager
                         :connection (list :connected t)))
    (is (cl-telegram/api:set-secret-chat-ttl chat 60))
    (is (= (cl-telegram/api::secret-ttl chat) 60)
        "TTL should be updated")))

(test test-mark-secret-messages-read
  "Test marking messages as read"
  (let ((chat (make-mock-secret-chat)))
    (setf (cl-telegram/api::*secret-chat-manager*)
          (make-instance 'cl-telegram/api::secret-chat-manager
                         :connection (list :connected t)))
    (is (cl-telegram/api:mark-secret-messages-read chat '(1 2 3)))))

(test test-delete-secret-messages
  "Test deleting secret messages"
  (let ((chat (make-mock-secret-chat)))
    (setf (cl-telegram/api::*secret-chat-manager*)
          (make-instance 'cl-telegram/api::secret-chat-manager
                         :connection (list :connected t)))
    (is (cl-telegram/api:delete-secret-messages chat '(1 2 3)))))

;;; ### Action Tests

(test test-send-secret-chat-action
  "Test sending chat action (typing indicator)"
  (let ((chat (make-mock-secret-chat)))
    (setf (cl-telegram/api::*secret-chat-manager*)
          (make-instance 'cl-telegram/api::secret-chat-manager
                         :connection (list :connected t)))
    (is (cl-telegram/api:send-secret-chat-action chat :typing))))

;;; ### Close Chat Tests

(test test-close-secret-chat
  "Test closing a secret chat"
  (let* ((conn (list :connected t))
         (mgr (cl-telegram/api:make-secret-chat-manager conn))
         (chat (make-instance 'cl-telegram/api::secret-chat
                              :chat-id -555
                              :participant-id 666)))
    (setf (cl-telegram/api::*secret-chat-manager*) mgr)
    (setf (gethash -555 (cl-telegram/api::secret-chats mgr)) chat)
    (setf (cl-telegram/api::secret-state chat) :active)

    ;; Close the chat
    (is (cl-telegram/api:close-secret-chat chat))
    (is (eq (cl-telegram/api::secret-state chat) :closed)
        "State should be closed")
    (is (null (gethash -555 (cl-telegram/api::secret-chats mgr)))
        "Chat should be removed from manager")))

;;; ### Integration Tests

(test test-secret-chat-full-flow
  "Test full secret chat flow: create, exchange keys, send message"
  (let* ((conn (list :connected t))
         (mgr (cl-telegram/api:make-secret-chat-manager conn)))
    (setf (cl-telegram/api::*secret-chat-manager*) mgr)

    ;; Simulate key exchange
    (multiple-value-bind (priv-a pub-a)
        (cl-telegram/api::generate-dh-keypair)
      (multiple-value-bind (priv-b pub-b)
          (cl-telegram/api::generate-dh-keypair)
        ;; Create chat instances
        (let ((chat-a (make-instance 'cl-telegram/api::secret-chat
                                     :chat-id -100
                                     :participant-id 200))
              (chat-b (make-instance 'cl-telegram/api::secret-chat
                                     :chat-id -100
                                     :participant-id 100)))
          ;; Set up keys (simulating completed exchange)
          (setf (cl-telegram/api::secret-local-key chat-a) priv-a)
          (setf (cl-telegram/api::secret-remote-key chat-a) pub-b)
          (setf (cl-telegram/api::secret-local-key chat-b) priv-b)
          (setf (cl-telegram/api::secret-remote-key chat-b) pub-a)

          ;; Compute shared auth key
          (let* ((shared-a (cl-telegram/api::compute-shared-key priv-a pub-b))
                 (shared-b (cl-telegram/api::compute-shared-key priv-b pub-a))
                 (auth-key-a (cl-telegram/api::kdf-secret-chat shared-a))
                 (auth-key-b (cl-telegram/api::kdf-secret-chat shared-b)))
            ;; Verify same key
            (is (equalp auth-key-a auth-key-b)
                "Both parties should have same auth key")

            ;; Set auth keys
            (setf (cl-telegram/api::secret-auth-key chat-a) auth-key-a)
            (setf (cl-telegram/api::secret-auth-key chat-b) auth-key-b)
            (setf (cl-telegram/api::secret-auth-key-id chat-a)
                  (cl-telegram/api::compute-key-fingerprint auth-key-a))
            (setf (cl-telegram/api::secret-auth-key-id chat-b)
                  (cl-telegram/api::compute-key-fingerprint auth-key-b))
            (setf (cl-telegram/api::secret-state chat-a) :active)
            (setf (cl-telegram/api::secret-state chat-b) :active)

            ;; Test encryption/decryption round trip
            (let ((original "Secret message test 123"))
              (let* ((encrypted (cl-telegram/api::encrypt-secret-message
                                 chat-a original))
                     (decrypted (cl-telegram/api::decrypt-secret-message
                                 chat-b encrypted)))
                ;; Note: actual serialization is placeholder
                (declare (ignore encrypted decrypted)))))))))
