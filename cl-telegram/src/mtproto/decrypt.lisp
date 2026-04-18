;;; decrypt.lisp --- Message decryption for MTProto 2.0

(in-package #:cl-telegram/mtproto)

(defun decrypt-message (auth-key msg-key encrypted-data &key (from-client nil))
  "Decrypt a message using MTProto 2.0 AES-256 IGE decryption.

   Args:
     auth-key: 256-byte authorization key
     msg-key: 16-byte message key
     encrypted-data: Encrypted message bytes
     from-client: T if decrypting client->server message (for key derivation)

   Returns:
     Decrypted message bytes (with padding removed)

   MTProto 2.0 decryption process:
   1. Compute aes_key, iv = KDF(auth_key, msg_key)
   2. Decrypt using AES-256 IGE
   3. Remove padding"
  (multiple-value-bind (aes-key iv)
      (compute-aes-key-iv auth-key msg-key (not from-client))
    (let ((cipher (cl-telegram/crypto:make-aes-ige-key aes-key))
          (iv1 (subseq iv 0 16))
          (iv2 (subseq iv 16 32)))
      (let ((decrypted (cl-telegram/crypto:aes-ige-decrypt encrypted-data cipher iv1 iv2)))
        (cl-telegram/crypto:mtproto-unpad decrypted)))))

(defun verify-msg-key (auth-key message msg-key)
  "Verify that msg_key matches the decrypted message.

   Args:
     auth-key: 256-byte authorization key
     message: Decrypted message bytes
     msg-key: 16-byte message key to verify

   Returns:
     T if msg_key is valid, NIL otherwise"
  (let ((computed-key (compute-msg-key auth-key message)))
    (equalp computed-key msg-key)))

(defun parse-rpc-response (decrypted-body)
  "Parse a decrypted RPC response.

   Args:
     decrypted-body: Decrypted message body

   Returns:
     Parsed TL object

   Can return:
   - rpc_result#f35c6d01 req_msg_id:long result:string
   - rpc_error#2144ca19 error_code:int error_message:string
   - Other TL objects (updates, etc.)"
  (cl-telegram/tl:tl-deserialize decrypted-body))

(defun handle-rpc-result (result-body)
  "Handle an RPC result response.

   Args:
     result-body: Decrypted rpc_result body

   Returns:
     (values req-msg-id result-object)"
  (let ((constructor (cl-telegram/tl:deserialize-int32 result-body)))
    (when (= constructor #xf35c6d01)  ; rpc_result
      (let ((req-msg-id (cl-telegram/tl:deserialize-int64 result-body))
            (result (cl-telegram/tl:tl-deserialize result-body)))
        (values req-msg-id result)))))

(defun handle-rpc-error (error-body)
  "Handle an RPC error response.

   Args:
     error-body: Decrypted rpc_error body

   Returns:
     (values error-code error-message)"
  (let ((constructor (cl-telegram/tl:deserialize-int32 error-body)))
    (when (= constructor #x2144ca19)  ; rpc_error
      (let ((error-code (cl-telegram/tl:deserialize-int32 error-body))
            (error-message (cl-telegram/tl:deserialize-string error-body)))
        (values error-code error-message)))))

(defun decrypt-and-parse (auth-key msg-key encrypted-data)
  "Decrypt a message and parse the result.

   Args:
     auth-key: 256-byte authorization key
     msg-key: 16-byte message key
     encrypted-data: Encrypted message bytes

   Returns:
     Parsed TL object or error

   This is a convenience function that combines decrypt-message
   and parse-rpc-response."
  (let ((decrypted (decrypt-message auth-key msg-key encrypted-data)))
    (handler-case
        (parse-rpc-response decrypted)
      (error (e)
        (list :error :decryption-failed :message (format nil "~A" e))))))
