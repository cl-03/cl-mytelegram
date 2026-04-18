;;; kdf.lisp --- Key Derivation Functions for MTProto 2.0

(in-package #:cl-telegram/crypto)

;;; MTProto 2.0 uses custom KDFs based on SHA-256

(defun kdf-msg-key (auth-key msg-data)
  "Compute msg_key = SHA256(auth_key + msg_data)

   In MTProto 2.0, msg_key depends on both the message content and padding.

   Args:
     auth-key: 256-byte authorization key
     msg-data: Message data including padding (byte array)

   Returns:
     16-byte msg_key"
  (let ((combined (concatenate '(simple-array (unsigned-byte 8))
                               auth-key msg-data)))
    (subseq (sha256 combined) 0 16)))

(defun kdf-aes-key-iv (auth-key msg-key for-client)
  "Derive AES key and IV from auth_key and msg_key.

   Args:
     auth-key: 256-byte authorization key
     msg-key: 16-byte message key
     for-client: T if deriving for client->server, NIL for server->client

   Returns:
     (values aes-key iv) - both 32-byte and 32-byte (16+16 for IGE)"
  (let* ((x (if for-client
                (concatenate '(simple-array (unsigned-byte 8))
                             msg-key (subseq auth-key 0 32))
                (concatenate '(simple-array (unsigned-byte 8))
                             (subseq auth-key 0 32) msg-key)))
         (hash (sha256 x))
         (aes-key (concatenate '(simple-array (unsigned-byte 8))
                               (subseq hash 0 16)
                               (subseq auth-key 32 48)
                               (subseq msg-key 0 16)))
         (iv (concatenate '(simple-array (unsigned-byte 8))
                          (subseq auth-key 48 64)
                          (subseq hash 16 32)
                          (subseq msg-key 0 16))))
    (values aes-key iv)))

(defun kdf-temp-auth-key (perm-auth-key nonce server-salt)
  "Derive temporary authorization key from permanent auth key.

   Args:
     perm-auth-key: 256-byte permanent authorization key
     nonce: 16-byte client nonce
     server-salt: 8-byte server salt

   Returns:
     256-byte temporary auth key"
  (let ((combined (concatenate '(simple-array (unsigned-byte 8))
                               perm-auth-key nonce server-salt)))
    (sha256 combined)))

(defun kdf-auth-key (dh-shared-secret nonce server-nonce)
  "Compute authorization_key from DH shared secret.

   Args:
     dh-shared-secret: DH shared secret (256 bytes)
     nonce: Client nonce (16 bytes)
     server-nonce: Server nonce (16 bytes)

   Returns:
     256-byte authorization key"
  (let ((combined (concatenate '(simple-array (unsigned-byte 8))
                               nonce server-nonce dh-shared-secret)))
    (sha256 combined)))

(defun kdf-new-nonce-hash (new-nonce suffix)
  "Compute new_nonce_hash{1,2,3} for DH key exchange confirmation.

   Args:
     new-nonce: 256-bit new nonce
     suffix: 1-byte suffix (1, 2, or 3)

   Returns:
     128-bit hash"
  (let* ((data (concatenate '(simple-array (unsigned-byte 8))
                            (uint256-to-bytes new-nonce)
                            (vector suffix)))
         (hash (sha256 data)))
    (subseq hash 0 16)))
