;;; encrypt.lisp --- Message encryption for MTProto 2.0

(in-package #:cl-telegram/mtproto)

(defun compute-msg-key (auth-key message)
  "Compute msg_key = SHA256(auth_key + message)[0:16]

   In MTProto 2.0, the message includes padding."
  (let ((combined (concatenate '(simple-array (unsigned-byte 8))
                               auth-key message)))
    (subseq (cl-telegram/crypto:sha256 combined) 0 16)))

(defun compute-aes-key-iv (auth-key msg-key from-client-p)
  "Compute AES key and IV from auth_key and msg_key.

   Returns: (values aes-key iv)"
  (cl-telegram/crypto:kdf-aes-key-iv auth-key msg-key from-client-p))

(defun encrypt-message (auth-key message &key (from-client t))
  "Encrypt a message using MTProto 2.0 AES-256 IGE encryption.

   Args:
     auth-key: 256-byte authorization key
     message: Message bytes to encrypt (will be padded)
     from-client: T if encrypting client->server message

   Returns:
     (values encrypted-message msg-key)

   MTProto 2.0 encryption process:
   1. Pad message to 16-byte boundary
   2. Compute msg_key = SHA256(auth_key + padded_message)[0:16]
   3. Compute aes_key, iv = KDF(auth_key, msg_key)
   4. Encrypt using AES-256 IGE"
  (let* ((padded (cl-telegram/crypto:mtproto-pad message))
         (msg-key (compute-msg-key auth-key padded))
         (multiple-value-bind (aes-key iv)
             (compute-aes-key-iv auth-key msg-key from-client)
           (let ((cipher (cl-telegram/crypto:make-aes-ige-key aes-key))
                 ;; Split IV into iv1 and iv2 for IGE mode
                 (iv1 (subseq iv 0 16))
                 (iv2 (subseq iv 16 32)))
             (values (cl-telegram/crypto:aes-ige-encrypt padded cipher iv1 iv2)
                     msg-key)))))

(defun make-message-header (auth-key-id msg-key msg-length)
  "Create MTProto message header.

   Args:
     auth-key-id: First 64 bits of SHA256(auth_key)
     msg-key: 128-bit message key
     msg-length: Length of encrypted message

   Returns:
     24-byte header: [auth_key_id:64][msg_key:128]"
  (declare (type (simple-array (unsigned-byte 8) 8) auth-key-id)
           (type (simple-array (unsigned-byte 8) 16) msg-key))
  (concatenate '(simple-array (unsigned-byte 8))
               auth-key-id
               msg-key))

(defun compute-auth-key-id (auth-key)
  "Compute auth_key_id = SHA256(auth_key)[0:8] (little-endian)."
  (let ((hash (cl-telegram/crypto:sha256 auth-key)))
    (subseq hash 0 8)))

(defun generate-msg-id (server-salt session-id)
  "Generate a unique message ID.

   MTProto message ID format:
   - Bits 0-5: ignored (set to 0)
   - Bits 6-61: Unix time in milliseconds + random bits
   - Bits 62-63: message type (01 for client, 10 for server)

   Args:
     server-salt: 8-byte server salt
     session-id: 8-byte client session ID

   Returns:
     64-bit message ID integer"
  (declare (ignore server-salt session-id))  ; Simplified implementation
  ;; Get current time in milliseconds
  (let* ((now (get-universal-time))
         (ms (* now 1000))
         ;; Ensure bits 62-63 = 01 for client messages
         (msg-id (logior (ash ms 3) #b01)))
    msg-id))

(defun make-rpc-request (session-id msg-id request-body)
  "Create an RPC request message.

   Args:
     session-id: 8-byte session ID
     msg-id: 64-bit message ID
     request-body: Serialized TL request

   Returns:
     Complete RPC request message bytes"
  (let* ((seqno 0)  ; First message
         (msg-length (length request-body)))
    (concatenate '(simple-array (unsigned-byte 8))
                 (cl-telegram/tl:serialize-int64 msg-id)
                 (cl-telegram/tl:serialize-int32 seqno)
                 (cl-telegram/tl:serialize-int32 msg-length)
                 request-body)))
