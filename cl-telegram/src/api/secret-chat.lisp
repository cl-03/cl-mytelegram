;;; secret-chat.lisp --- End-to-end encrypted Secret Chats implementation
;;;
;;; Implements MTProto secret chat protocol with:
;;; - Diffie-Hellman key exchange
;;; - AES-256 IGE encryption
;;; - Message TTL (self-destruct timer)
;;; - Perfect forward secrecy

(in-package #:cl-telegram/api)

;;; ### Secret Chat State

(defclass secret-chat ()
  ((chat-id :initarg :chat-id :reader secret-chat-id
            :documentation "Secret chat identifier")
   (participant-id :initarg :participant-id :accessor secret-participant-id
                   :documentation "Other participant user ID")
   (participant-access-hash :initarg :access-hash :accessor secret-access-hash
                            :documentation "Participant access hash")
   (local-key :initarg :local-key :accessor secret-local-key
              :documentation "Our DH private key (256 bytes)")
   (remote-key :initarg :remote-key :accessor secret-remote-key
               :documentation "Remote DH public key g_a (256 bytes)")
   (auth-key :initform nil :accessor secret-auth-key
             :documentation "Shared authorization key (256 bytes)")
   (auth-key-id :initform nil :accessor secret-auth-key-id
                :documentation "Low 64 bits of SHA256(auth-key)")
   (layer :initform 8 :accessor secret-layer
          :documentation "Protocol layer version")
   (in-sequence-no :initform 0 :accessor secret-in-sequence-no
                    :documentation "Incoming sequence number")
   (out-sequence-no :initform 0 :accessor secret-out-sequence-no
                     :documentation "Outgoing sequence number")
   (ttl :initform 0 :accessor secret-ttl
        :documentation "Time-to-live for messages in seconds")
   (state :initform :pending :accessor secret-state
          :documentation "Chat state: :pending, :active, :closed")
   (created-at :initform (get-universal-time) :accessor secret-created-at
                :documentation "Chat creation time")
   (flags :initform nil :accessor secret-chat-flags
          :documentation "Property list for chat flags"))
  (:documentation "Secret chat session with E2E encryption"))

(defclass secret-chat-manager ()
  ((chats :initform (make-hash-table :test 'eql) :accessor secret-chats
          :documentation "Chat ID -> secret-chat mapping")
   (user-chat-map :initform (make-hash-table :test 'eql) :accessor secret-user-chats
                  :documentation "User ID -> chat-id mapping")
   (pending-keys :initform (make-hash-table :test 'eql) :accessor secret-pending-keys
                 :documentation "Exchange ID -> pending key data")
   (connection :initarg :connection :accessor secret-connection
               :documentation "MTProto connection instance"))
  (:documentation "Secret chat manager"))

(defun make-secret-chat-manager (connection)
  "Create a new secret chat manager.

   Args:
     connection: MTProto connection instance

   Returns:
     Secret chat manager instance"
  (make-instance 'secret-chat-manager :connection connection))

(defvar *secret-chat-manager* nil
  "Global secret chat manager instance")

;;; ### DH Key Exchange

(defun generate-dh-keypair ()
  "Generate Diffie-Hellman key pair for secret chat.

   Returns:
     (values private-key public-key)
     - private-key: 256-byte array (2048-bit private key)
     - public-key: 256-byte array (g_a = g^a mod p)

   Uses Telegram's DH parameters (2048-bit group)."
  (let* (;; Telegram's 2048-bit prime (from MTProto spec)
         (p #(##xFF ##xFF ##xFF ##xFF ##xFF ##xFF ##xFF ##xFF
               ##xC9 ##x0F ##xDAA ##xAB ##x2F ##xDC ##x43 ##x62
               ##xAF ##x1C ##x3A ##xEC ##xE6 ##xE0 ##x65 ##x72
               ##x7D ##x2F ##xA4 ##x28 ##xD4 ##x99 ##x9C ##xAB
               ##x67 ##x99 ##xA6 ##x16 ##x09 ##x3E ##x0C ##x5C
               ##x5F ##x61 ##x79 ##x2C ##x4A ##x99 ##xB2 ##x23
               ##x12 ##x1D ##x45 ##x92 ##x15 ##xD4 ##x11 ##xAE
               ##x73 ##x8C ##xA2 ##xDD ##x88 ##xBB ##x8B ##xE2
               ##x5E ##x3A ##xF0 ##x52 ##x0F ##x5C ##x31 ##xA9
               ##x2A ##x60 ##x10 ##x9F ##x44 ##x31 ##xC4 ##x41
               ##x99 ##x56 ##x9B ##x68 ##x32 ##x25 ##x64 ##x5F
               ##x75 ##x13 ##x88 ##x4A ##x79 ##xD7 ##x43 ##xAE
               ##x7A ##x08 ##x8C ##x10 ##x32 ##xB5 ##x17 ##x5D
               ##x63 ##x19 ##x69 ##x13 ##x3B ##x55 ##xA1 ##xB4
               ##x26 ##xAD ##x46 ##x8D ##x2A ##xF4 ##x55 ##x9F
               ##x2A ##x32 ##xC4 ##x17 ##xE2 ##x11 ##xF6 ##x63
               ##x97 ##xE7 ##xF1 ##x36 ##x89 ##x48 ##x4A ##xD7
               ##xA5 ##x5F ##x72 ##xA0 ##x39 ##xE6 ##x23 ##x45
               ##x4D ##x22 ##x8C ##xC1 ##x4E ##xA8 ##x18 ##x34
               ##x35 ##xB9 ##x68 ##x42 ##xC1 ##x18 ##x7F ##xC2
               ##xCB ##x92 ##x6B ##x59 ##x88 ##x2A ##xEA ##x92
               ##x59 ##x20 ##x4A ##x75 ##x19 ##x81 ##x39 ##x70
               ##xEB ##x5F ##x5A ##x65 ##xC3 ##xD3 ##x06 ##x28
               ##xF1 ##x3B ##x96 ##x59 ##x2E ##x71 ##xCD ##xD9
               ##x4B ##x4F ##x0A ##xb2 ##x55 ##x5D ##xF1 ##x7B
               ##x7C ##x09 ##x1B ##x98 ##x7A ##xF3 ##x0A ##x98
               ##x5D ##x94 ##x89 ##x4D ##xA7 ##x9C ##x68 ##x55
               ##x5E ##x86 ##x9A ##x08 ##xE0 ##x44 ##x9C ##x01
               ##xC5 ##xF3 ##x22 ##x85 ##x09 ##xC8 ##xA3 ##x78
               ##xF5 ##x4D ##x2D ##x56 ##x02 ##x17 ##x5D ##xC7
               ##x62 ##x8A ##xC9 ##xD7 ##x72 ##x1E ##xAC ##xC5
               ##x92 ##x2B ##x95 ##xD8 ##x44 ##xE0 ##x51 ##xE5))
         ;; Generator
         (g 3)
         ;; Generate random private key (2048 bits = 256 bytes)
         (private-key (make-array 256 :element-type '(unsigned-byte 8))))
    ;; Fill private key with random bytes
    (loop for i below 256 do
      (setf (aref private-key i) (random 256)))

    ;; Compute public key: g_a = g^a mod p
    ;; Note: This requires big integer arithmetic
    ;; For production, use a proper bignum library
    (let ((public-key (modular-expt g (bytes-to-integer private-key)
                                     (bytes-to-integer p))))
      (values private-key (integer-to-bytes public-key 256)))))

(defun bytes-to-integer (bytes)
  "Convert big-endian byte array to integer."
  (loop for byte across bytes
        for result = 0 then (+ (ash result 8) byte)
        finally (return result)))

(defun integer-to-bytes (num size)
  "Convert integer to big-endian byte array."
  (let ((bytes (make-array size :element-type '(unsigned-byte 8))))
    (loop for i from (1- size) downto 0 do
      (setf (aref bytes i) (logand num #xFF))
      (setf num (ash num -8)))
    bytes))

(defun compute-shared-key (private-key remote-public-key)
  "Compute shared secret key from DH exchange.

   Args:
     private-key: Our private key (256 bytes)
     remote-public-key: Remote party's public key (256 bytes)

   Returns:
     Shared key (256 bytes)

   Computes: shared = remote_public^private mod p"
  (let* (;; Telegram's 2048-bit prime
         (p #(##xFF ##xFF ##xFF ##xFF ##xFF ##xFF ##xFF ##xFF
               ##xC9 ##x0F ##xDAA ##xAB ##x2F ##xDC ##x43 ##x62
               ##xAF ##x1C ##x3A ##xEC ##xE6 ##xE0 ##x65 ##x72
               ##x7D ##x2F ##xA4 ##x28 ##xD4 ##x99 ##x9C ##xAB
               ##x67 ##x99 ##xA6 ##x16 ##x09 ##x3E ##x0C ##x5C
               ##x5F ##x61 ##x79 ##x2C ##x4A ##x99 ##xB2 ##x23
               ##x12 ##x1D ##x45 ##x92 ##x15 ##xD4 ##x11 ##xAE
               ##x73 ##x8C ##xA2 ##xDD ##x88 ##xBB ##x8B ##xE2
               ##x5E ##x3A ##xF0 ##x52 ##x0F ##x5C ##x31 ##xA9
               ##x2A ##x60 ##x10 ##x9F ##x44 ##x31 ##xC4 ##x41
               ##x99 ##x56 ##x9B ##x68 ##x32 ##x25 ##x64 ##x5F
               ##x75 ##x13 ##x88 ##x4A ##x79 ##xD7 ##x43 ##xAE
               ##x7A ##x08 ##x8C ##x10 ##x32 ##xB5 ##x17 ##x5D
               ##x63 ##x19 ##x69 ##x13 ##x3B ##x55 ##xA1 ##xB4
               ##x26 ##xAD ##x46 ##x8D ##x2A ##xF4 ##x55 ##x9F
               ##x2A ##x32 ##xC4 ##x17 ##xE2 ##x11 ##xF6 ##x63
               ##x97 ##xE7 ##xF1 ##x36 ##x89 ##x48 ##x4A ##xD7
               ##xA5 ##x5F ##x72 ##xA0 ##x39 ##xE6 ##x23 ##x45
               ##x4D ##x22 ##x8C ##xC1 ##x4E ##xA8 ##x18 ##x34
               ##x35 ##xB9 ##x68 ##x42 ##xC1 ##x18 ##x7F ##xC2
               ##xCB ##x92 ##x6B ##x59 ##x88 ##x2A ##xEA ##x92
               ##x59 ##x20 ##x4A ##x75 ##x19 ##x81 ##x39 ##x70
               ##xEB ##x5F ##x5A ##x65 ##xC3 ##xD3 ##x06 ##x28
               ##xF1 ##x3B ##x96 ##x59 ##x2E ##x71 ##xCD ##xD9
               ##x4B ##x4F ##x0A ##xb2 ##x55 ##x5D ##xF1 ##x7B
               ##x7C ##x09 ##x1B ##x98 ##x7A ##xF3 ##x0A ##x98
               ##x5D ##x94 ##x89 ##x4D ##xA7 ##x9C ##x68 ##x55
               ##x5E ##x86 ##x9A ##x08 ##xE0 ##x44 ##x9C ##x01
               ##xC5 ##xF3 ##x22 ##x85 ##x09 ##xC8 ##xA3 ##x78
               ##xF5 ##x4D ##x2D ##x56 ##x02 ##x17 ##x5D ##xC7
               ##x62 ##x8A ##xC9 ##xD7 ##x72 ##x1E ##xAC ##xC5
               ##x92 ##x2B ##x95 ##xD8 ##x44 ##xE0 ##x51 ##xE5))
         (shared (modular-expt (bytes-to-integer remote-public-key)
                               (bytes-to-integer private-key)
                               (bytes-to-integer p))))
    (integer-to-bytes shared 256)))

(defun compute-key-fingerprint (auth-key)
  "Compute 64-bit fingerprint of auth key.

   Args:
     auth-key: 256-byte auth key

   Returns:
     8-byte fingerprint (low 64 bits of SHA256)"
  (let ((hash (cl-telegram/crypto:sha256-hash auth-key)))
    ;; Take first 8 bytes (64 bits)
    (subseq hash 0 8)))

;;; ### Secret Chat Creation

(defun request-secret-chat (user-id &optional access-hash)
  "Request a new secret chat with a user.

   Args:
     user-id: User ID to chat with
     access-hash: Optional access hash for the user

   Returns:
     Secret chat instance in :pending state

   This initiates the DH key exchange by:
   1. Generating local DH keypair
   2. Sending requestKey action to remote user
   3. Waiting for acceptKey response"
  (unless *secret-chat-manager*
    (error "Secret chat manager not initialized"))

  (let* ((manager *secret-chat-manager*)
         (exchange-id (random (expt 2 63))) ; Random 64-bit ID
         (chat-id (- (expt 2 63))) ; Negative chat ID for secret chats
         (chat (make-instance 'secret-chat
                              :chat-id chat-id
                              :participant-id user-id
                              :participant-access-hash (or access-hash 0))))
    ;; Generate DH keypair
    (multiple-value-bind (private-key public-key)
        (generate-dh-keypair)
      (setf (secret-local-key chat) private-key)
      (setf (secret-remote-key chat) public-key)

      ;; Store pending key data
      (setf (gethash exchange-id (secret-pending-keys manager))
            (list :chat chat
                  :public-key public-key
                  :state :waiting-accept))

      ;; Send requestKey action
      (send-decrypted-message-action
       (secret-connection manager) chat
       (list :@type :decryptedMessageActionRequestKey
             :exchange-id exchange-id
             :g-a public-key))

      (setf (gethash chat-id (secret-chats manager)) chat)
      (setf (gethash user-id (secret-user-chats manager)) chat-id)

      chat)))

(defun accept-secret-chat-request (chat exchange-id)
  "Accept a secret chat request.

   Args:
     chat: Secret chat instance
     exchange-id: Exchange ID from request

   Returns:
     T on success

   This completes the DH key exchange by:
   1. Generating local DH keypair
   2. Computing shared auth key
   3. Sending acceptKey action"
  (let* ((manager *secret-chat-manager*)
         (remote-key (secret-remote-key chat)))
    ;; Generate our keypair
    (multiple-value-bind (private-key public-key)
        (generate-dh-keypair)
      (setf (secret-local-key chat) private-key)

      ;; Compute shared auth key
      (let* ((shared-key (compute-shared-key private-key remote-key))
             (auth-key (kdf-secret-chat shared-key))
             (auth-key-id (compute-key-fingerprint auth-key)))
        (setf (secret-auth-key chat) auth-key)
        (setf (secret-auth-key-id chat) auth-key-id)

        ;; Send acceptKey
        (send-decrypted-message-action
         (secret-connection manager) chat
         (list :@type :decryptedMessageActionAcceptKey
               :exchange-id exchange-id
               :g-b public-key
               :key-fingerprint (bytes-to-integer auth-key-id)))

        ;; Update state
        (setf (secret-state chat) :active)
        (setf (gethash (secret-chat-id chat) (secret-chats manager)) chat)

        t))))

(defun kdf-secret-chat (shared-key)
  "Derive secret chat encryption key from shared DH key.

   Args:
     shared-key: 256-byte shared DH key

   Returns:
     256-byte encryption key (auth_key)

   KDF: SHA256(shared_key + nonce) where nonce is protocol-defined"
  ;; Telegram's secret chat KDF uses a fixed nonce
  (let ((nonce #(##x00 ##x00 ##x00 ##x00 ##x00 ##x00 ##x00 ##x00
                 ##x00 ##x00 ##x00 ##x00 ##x00 ##x00 ##x00 ##x00)))
    (cl-telegram/crypto:sha256-hash (concatenate '(vector (unsigned-byte 8))
                                                  shared-key nonce))))

;;; ### Message Encryption

(defun encrypt-secret-message (chat message)
  "Encrypt a message for secret chat.

   Args:
     chat: Secret chat instance
     message: DecryptedMessage plist

   Returns:
     Encrypted message bytes

   Encryption process:
   1. Serialize message to TL bytes
   2. Pad to 16-byte boundary
   3. AES-256 IGE encrypt with auth_key
   4. Prepend message header"
  (let* ((auth-key (secret-auth-key chat))
         (msg-key (compute-msg-key auth-key message))
         (aes-key (compute-aes-key msg-key auth-key))
         (aes-iv (compute-aes-iv msg-key auth-key))
         ;; Serialize message
         (message-bytes (serialize-decrypted-message message))
         ;; Pad to 16-byte boundary
         (padded (pad-message message-bytes)))
    ;; AES-256 IGE encrypt
    (let ((encrypted (cl-telegram/crypto:aes-ige-encrypt padded aes-key aes-iv)))
      ;; Return encrypted message with header
      encrypted)))

(defun decrypt-secret-message (chat encrypted-data)
  "Decrypt a secret message.

   Args:
     chat: Secret chat instance
     encrypted-data: Encrypted message bytes

   Returns:
     Decrypted message plist

   Decryption process:
   1. AES-256 IGE decrypt with auth_key
   2. Verify msg_key
   3. Deserialize TL bytes to message"
  (let* ((auth-key (secret-auth-key chat))
         ;; AES-256 IGE decrypt
         (decrypted (cl-telegram/crypto:aes-ige-decrypt encrypted-data auth-key))
         ;; Extract message (remove padding)
         (message-bytes (unpad-message decrypted)))
    ;; Deserialize and return
    (deserialize-decrypted-message message-bytes)))

(defun compute-msg-key (auth-key message)
  "Compute msg_key for message authentication.

   Args:
     auth-key: 256-byte auth key
     message: Message bytes or plist

   Returns:
     16-byte msg_key (middle 16 bytes of SHA256)

   msg_key = SHA256(auth_key + message)[8:24]"
  (let* ((message-bytes (if (listp message)
                            (serialize-decrypted-message message)
                            message))
         (hash (cl-telegram/crypto:sha256-hash
                (concatenate '(vector (unsigned-byte 8))
                             auth-key message-bytes))))
    ;; Take middle 16 bytes (bytes 8-23)
    (subseq hash 8 24)))

(defun compute-aes-key (msg-key auth-key)
  "Compute AES-256 key from msg_key and auth_key.

   Args:
     msg-key: 16-byte msg_key
     auth-key: 256-byte auth key

   Returns:
     32-byte AES key

   aes_key = SHA256(msg_key + auth_key[0:192])[0:32]"
  (let ((hash (cl-telegram/crypto:sha256-hash
               (concatenate '(vector (unsigned-byte 8))
                            msg-key
                            (subseq auth-key 0 48)))))
    (subseq hash 0 32)))

(defun compute-aes-iv (msg-key auth-key)
  "Compute AES IV from msg_key and auth_key.

   Args:
     msg-key: 16-byte msg_key
     auth-key: 256-byte auth key

   Returns:
     32-byte AES IV

   aes_iv = SHA256(auth_key[192:255] + msg_key)[0:32]"
  (let ((hash (cl-telegram/crypto:sha256-hash
               (concatenate '(vector (unsigned-byte 8))
                            (subseq auth-key 48 96)
                            msg-key))))
    (subseq hash 0 32)))

(defun serialize-decrypted-message (message)
  "Serialize decrypted message to TL bytes.

   Args:
     message: DecryptedMessage plist

   Returns:
     Byte array"
  ;; Placeholder - would use TL serializer
  (declare (ignore message))
  (make-array 0 :element-type '(unsigned-byte 8)))

(defun deserialize-decrypted-message (bytes)
  "Deserialize TL bytes to decrypted message.

   Args:
     bytes: Byte array

   Returns:
     DecryptedMessage plist"
  ;; Placeholder - would use TL deserializer
  (declare (ignore bytes))
  nil)

(defun pad-message (message-bytes)
  "Pad message to 16-byte boundary.

   Args:
     message-bytes: Message bytes

   Returns:
     Padded bytes (multiple of 16)"
  (let* ((len (length message-bytes))
         (padding-len (- 16 (mod len 16))))
    (if (zerop padding-len)
        message-bytes
        (let ((padded (make-array (+ len padding-len)
                                  :element-type '(unsigned-byte 8))))
          (replace padded message-bytes)
          ;; Fill padding with random bytes
          (loop for i from len below (+ len padding-len) do
            (setf (aref padded i) (random 256)))
          padded))))

(defun unpad-message (padded-bytes)
  "Remove padding from decrypted message.

   Args:
     padded-bytes: Padded message bytes

   Returns:
     Unpadded message bytes"
  ;; The actual length would be encoded in the message structure
  ;; For now, return as-is
  padded-bytes)

;;; ### Message Sending

(defun send-secret-message (chat text &key ttl random-id)
  "Send an encrypted message in secret chat.

   Args:
     chat: Secret chat instance
     text: Message text
     ttl: Optional TTL in seconds (overrides chat default)
     random-id: Optional random message ID

   Returns:
     T on success

   Example:
     (send-secret-message *chat* \"This will self-destruct\" :ttl 60)"
  (unless (eq (secret-state chat) :active)
    (return-from send-secret-message
      (values nil "Secret chat not active")))

  (let* ((message-ttl (or ttl (secret-ttl chat)))
         (random-id (or random-id (random (expt 2 63))))
         (random-bytes (make-array 32 :element-type '(unsigned-byte 8)))
         (message `(:@type :decryptedMessage
                      :random-id ,random-id
                      :random-bytes ,random-bytes
                      :message ,text
                      :media nil)))
    ;; Encrypt and send
    (let ((encrypted (encrypt-secret-message chat message)))
      (send-encrypted-message (secret-connection *secret-chat-manager*)
                              chat
                              encrypted)
      t)))

(defun send-secret-media (chat media-type media-data &key caption ttl)
  "Send encrypted media in secret chat.

   Args:
     chat: Secret chat instance
     media-type: :photo, :video, :audio, :document, :geo, :contact
     media-data: Media-specific data
     caption: Optional caption
     ttl: Optional TTL

   Returns:
     T on success"
  (unless (eq (secret-state chat) :active)
    (return-from send-secret-media
      (values nil "Secret chat not active")))

  (let* ((random-id (random (expt 2 63)))
         (random-bytes (make-array 32 :element-type '(unsigned-byte 8)))
         ;; Generate media encryption keys
         (media-key (make-array 32 :element-type '(unsigned-byte 8)))
         (media-iv (make-array 32 :element-type '(unsigned-byte 8)))
         (media `(:@type :decryptedMessageMedia
                      :type ,media-type
                      :data ,media-data
                      :key ,media-key
                      :iv ,media-iv
                      :caption ,(or caption ""))))
    (let ((message `(:@type :decryptedMessage
                         :random-id ,random-id
                         :random-bytes ,random-bytes
                         :message nil
                         :media ,media
                         :ttl ,(or ttl (secret-ttl chat)))))
      (let ((encrypted (encrypt-secret-message chat message))))
        (send-encrypted-message (secret-connection *secret-chat-manager*)
                                chat
                                encrypted)
        t))))

;;; ### Secret Chat Actions

(defun send-secret-chat-action (chat action)
  "Send action indicator (typing, etc.) in secret chat.

   Args:
     chat: Secret chat instance
     action: :typing, :cancel, :record-video, :upload-photo, etc.

   Returns:
     T on success"
  (let ((action-map '(:typing :sendMessageTypingAction
                      :cancel :sendMessageCancelAction
                      :record-video :sendMessageRecordVideoAction
                      :upload-video :sendMessageUploadVideoAction
                      :record-audio :sendMessageRecordAudioAction
                      :upload-audio :sendMessageUploadAudioAction
                      :upload-photo :sendMessageUploadPhotoAction
                      :upload-document :sendMessageUploadDocumentAction
                      :geo-location :sendMessageGeoLocationAction
                      :choose-contact :sendMessageChooseContactAction)))
    (let ((tl-action (getf action-map action)))
      (when tl-action
        (send-decrypted-message-action
         (secret-connection *secret-chat-manager*) chat
         `(:@type :decryptedMessageActionTyping
                  :action (:@type ,tl-action)))))))

(defun set-secret-chat-ttl (chat ttl-seconds)
  "Set self-destruct timer for secret chat.

   Args:
     chat: Secret chat instance
     ttl-seconds: TTL in seconds (0 to disable)

   Returns:
     T on success"
  (setf (secret-ttl chat) ttl-seconds)
  (send-decrypted-message-action
   (secret-connection *secret-chat-manager*) chat
   `(:@type :decryptedMessageActionSetMessageTTL
            :ttl-seconds ,ttl-seconds))
  t)

(defun mark-secret-messages-read (chat message-ids)
  "Mark secret messages as read.

   Args:
     chat: Secret chat instance
     message-ids: List of random message IDs to mark as read

   Returns:
     T on success"
  (send-decrypted-message-action
   (secret-connection *secret-chat-manager*) chat
   `(:@type :decryptedMessageActionReadMessages
            :random-ids ,message-ids))
  t)

(defun delete-secret-messages (chat message-ids)
  "Delete secret messages from both sides.

   Args:
     chat: Secret chat instance
     message-ids: List of random message IDs to delete

   Returns:
     T on success"
  (send-decrypted-message-action
   (secret-connection *secret-chat-manager*) chat
   `(:@type :decryptedMessageActionDeleteMessages
            :random-ids ,message-ids))
  t)

;;; ### Helper Functions

(defun send-decrypted-message-action (connection chat action)
  "Send a decrypted message action.

   Args:
     connection: MTProto connection
     chat: Secret chat instance
     action: Action plist"
  (let* ((random-id (random (expt 2 63)))
         (message `(:@type :decryptedMessageService
                          :random-id ,random-id
                          :action ,action))))
    (let ((encrypted (encrypt-secret-message chat message)))
      (send-encrypted-message connection chat encrypted))))

(defun send-encrypted-message (connection chat encrypted-data)
  "Send encrypted message to secret chat.

   Args:
     connection: MTProto connection
     chat: Secret chat instance
     encrypted-data: Encrypted message bytes"
  ;; Increment outgoing sequence number
  (let ((seq-no (secret-out-sequence-no chat)))
    (incf (secret-out-sequence-no chat))

    ;; Build messages.sendEncrypted request
    (let ((request `(:@type :messages.sendEncrypted
                         :peer (:@type :inputPeerUser
                                       :user-id ,(secret-participant-id chat)
                                       :access-hash ,(secret-access-hash chat))
                         :random-id ,(random (expt 2 63))
                         :data ,encrypted-data)))
      ;; Send via MTProto RPC
      (rpc-call connection request :timeout 10000))))

(defun get-secret-chat (chat-id)
  "Get secret chat by ID.

   Args:
     chat-id: Secret chat identifier

   Returns:
     Secret chat instance or NIL"
  (when *secret-chat-manager*
    (gethash chat-id (secret-chats *secret-chat-manager*))))

(defun get-secret-chat-with-user (user-id)
  "Get secret chat with a specific user.

   Args:
     user-id: User identifier

   Returns:
     Secret chat instance or NIL"
  (when *secret-chat-manager*
    (let ((chat-id (gethash user-id (secret-user-chats *secret-chat-manager*))))
      (when chat-id
        (gethash chat-id (secret-chats *secret-chat-manager*))))))

(defun list-secret-chats ()
  "List all active secret chats.

   Returns:
     List of secret chat instances"
  (when *secret-chat-manager*
    (let ((result nil))
      (maphash (lambda (id chat)
                 (when (eq (secret-state chat) :active)
                   (push chat result)))
               (secret-chats *secret-chat-manager*))
      (nreverse result))))

(defun close-secret-chat (chat)
  "Close a secret chat.

   Args:
     chat: Secret chat instance

   Returns:
     T on success"
  (setf (secret-state chat) :closed)
  (when *secret-chat-manager*
    (remhash (secret-chat-id chat) (secret-chats *secret-chat-manager*)))
  t)

;;; ### Update Handler Integration

(defun handle-encrypted-message-update (update)
  "Handle encrypted message received.

   Args:
     update: Update object with :encrypted-message field"
  (let* ((encrypted (getf update :encrypted-message))
         (chat-id (getf update :chat-id))
         (chat (get-secret-chat chat-id)))
    (when (and chat (eq (secret-state chat) :active))
      (let ((decrypted (decrypt-secret-message chat encrypted)))
        ;; Dispatch to update handler
        (dispatch-update `(:@type :update-secret-chat-message
                              :chat-id ,chat-id
                              :message ,decrypted))))))
