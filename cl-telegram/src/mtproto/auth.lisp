;;; auth.lisp --- MTProto 2.0 authentication flow

(in-package #:cl-telegram/mtproto)

;;; ### Authentication State Machine

;; Authorization states (matching TDLib):
;; wait_tdlib_params → wait_phone_number → wait_code → wait_password → ready

(defclass auth-state ()
  ((status :initarg :status :initform :wait-tdlib-params
           :accessor auth-status
           :documentation "Current auth state keyword")
   (nonce :initarg :nonce :initform nil :accessor auth-nonce
          :documentation "Current nonce (16 bytes)")
   (server-nonce :initarg :server-nonce :initform nil :accessor auth-server-nonce
                 :documentation "Server nonce (16 bytes)")
   (new-nonce :initarg :new-nonce :initform nil :accessor auth-new-nonce
              :documentation "New nonce for DH exchange (32 bytes)")
   (server-public-key :initarg :server-public-key :initform nil
                      :accessor auth-server-public-key
                      :documentation "Server RSA public key")
   (dh-private-key :initarg :dh-private-key :initform nil
                   :accessor auth-dh-private-key
                   :documentation "Our DH private key")
   (dh-public-key :initarg :dh-public-key :initform nil
                  :accessor auth-dh-public-key
                  :documentation "Server DH public key (g_a)")
   (server-dh-inner :initarg :server-dh-inner :initform nil
                    :accessor auth-server-dh-inner
                    :documentation "Decrypted server DH inner data")
   (auth-key :initarg :auth-key :initform nil :accessor auth-auth-key
             :documentation "Authorization key (256 bytes)")
   (server-salt :initarg :server-salt :initform nil :accessor auth-server-salt
                :documentation "Server salt for message IDs"))
  (:documentation "MTProto authentication state"))

(defun make-auth-state ()
  "Create a new authentication state object."
  (make-instance 'auth-state))

;;; ### Utility functions

(defun generate-nonce (&optional (size 16))
  "Generate a random nonce of specified size."
  (let ((nonce (make-array size :element-type '(unsigned-byte 8))))
    (loop for i below size do
      (setf (aref nonce i) (random 256)))
    nonce))

(defun factorize-pq (pq-bytes)
  "Factorize PQ into P and Q.

   For MTProto, PQ is typically small enough (64-bit) for trial division.
   Returns (values p q) as byte arrays.

   Note: This is a simplified implementation. Production code should use
   a more efficient factorization algorithm."
  (let* ((pq-int (loop for i below (length pq-bytes)
                       for byte = (aref pq-bytes i)
                       accumulate (ash byte (* 8 (- (1- (length pq-bytes)) i))) into result
                       finally (return result)))
         (limit (isqrt pq-int))
         (p nil)
         (q nil))
    ;; Trial division for small factors
    (loop for i from 2 to (min limit 1000000) do
      (when (and (zerop (mod pq-int i))
                 (not p))
        (setf p i)
        (setf q (/ pq-int i))
        (return)))
    (if (and p q)
        (values (integer-to-bytes p) (integer-to-bytes q))
        (error "Failed to factorize PQ"))))

(defun integer-to-bytes (num &optional (size 4))
  "Convert integer to big-endian byte array."
  (let ((bytes (make-array size :element-type '(unsigned-byte 8))))
    (loop for i from (1- size) downto 0 do
      (setf (aref bytes i) (logand num #xFF))
      (setf num (ash num -8)))
    bytes))

;;; ### Authentication Flow

(defun auth-init (state)
  "Initialize authentication state.

   Returns: state ready for phone number submission"
  (setf (auth-status state) :wait-phone-number
        (auth-nonce state) nil
        (auth-server-nonce state) nil
        (auth-new-nonce state) nil)
  state)

(defun auth-send-pq-request (state)
  "Create req_pq_multi request.

   Returns: Serialized TL request bytes"
  (setf (auth-nonce state) (generate-nonce 16))
  ;; req_pq_multi#be7e8ef1 nonce:int128
  (let ((constructor #xbe7e8ef1)
        (nonce (auth-nonce state)))
    (concatenate '(simple-array (unsigned-byte 8))
                 (cl-telegram/tl:serialize-int32 constructor)
                 (cl-telegram/tl:serialize-int128 nonce))))

(defun auth-handle-respq (state respq-bytes)
  "Handle resPQ response.

   Args:
     state: Auth state
     respq-bytes: Serialized resPQ response

   Returns: Serialized req_DH_params request

   Side effects: Updates state with server_nonce and server public key"
  (let* ((respq (cl-telegram/tl:tl-deserialize respq-bytes))
         (server-nonce (cl-telegram/tl:respq-server-nonce respq))
         (pq (cl-telegram/tl:respq-pq respq))
         (fingerprints (cl-telegram/tl:respq-fingerprints respq)))
    ;; Store server nonce
    (setf (auth-server-nonce state) server-nonce)
    ;; Factorize PQ
    (multiple-value-bind (p q) (factorize-pq pq)
      ;; Generate new nonce for DH exchange
      (setf (auth-new-nonce state) (generate-nonce 32))
      ;; Select server public key (use first available for now)
      ;; In production, check fingerprints to select correct key
      (setf (auth-server-public-key state) t)  ; Placeholder
      ;; Create p_q_inner_data
      (let ((inner-data (cl-telegram/tl:make-p-q-inner-data
                         :pq pq :p p :q q
                         :nonce (auth-nonce state)
                         :server-nonce server-nonce
                         :new-nonce (auth-new-nonce state)
                         :dc +default-dc-id+)))
        ;; Serialize and encrypt inner data with server RSA key
        ;; For now, return placeholder
        (declare (inner-data))
        (auth-send-dh-request state p q)))))

(defun auth-send-dh-request (state p q)
  "Create req_DH_params request.

   Args:
     state: Auth state
     p, q: PQ factorization results

   Returns: Serialized req_DH_params request"
  (let* ((constructor #xd712e4be)  ; req_DH_params
         (nonce (auth-nonce state))
         (server-nonce (auth-server-nonce state))
         ;; Create inner data
         (inner-data (cl-telegram/tl:make-p-q-inner-data
                      :pq (cl-telegram/crypto:xor-bytes p q)  ; Placeholder
                      :p p :q q
                      :nonce nonce
                      :server-nonce server-nonce
                      :new-nonce (auth-new-nonce state)
                      :dc +default-dc-id+))
         (encrypted-inner-data (cl-telegram/tl:tl-serialize inner-data)))
    ;; In production: RSA encrypt inner_data with server public key
    (concatenate '(simple-array (unsigned-byte 8))
                 (cl-telegram/tl:serialize-int32 constructor)
                 (cl-telegram/tl:serialize-int128 nonce)
                 (cl-telegram/tl:serialize-int128 server-nonce)
                 (cl-telegram/tl:serialize-bytes p)
                 (cl-telegram/tl:serialize-bytes q)
                 (cl-telegram/tl:serialize-int64 0)  ; public_key_fingerprint
                 (cl-telegram/tl:serialize-bytes encrypted-inner-data))))

(defun auth-handle-server-dh (state server-dh-bytes)
  "Handle server_DH_params response.

   Args:
     state: Auth state
     server-dh-bytes: Serialized server_DH_params response

   Returns: Serialized set_client_DH_params request"
  (let* ((response (cl-telegram/tl:tl-deserialize server-dh-bytes))
         (nonce (cl-telegram/tl:sdh-nonce response))
         (server-nonce (cl-telegram/tl:sdh-server-nonce response))
         (encrypted-answer (cl-telegram/tl:sdh-encrypted-answer response)))
    ;; Verify nonces match
    (assert (equalp nonce (auth-nonce state)))
    (assert (equalp server-nonce (auth-server-nonce state)))
    ;; Decrypt encrypted_answer (requires AES key from DH)
    ;; For now, placeholder
    (setf (auth-server-dh-inner state) encrypted-answer)
    ;; Generate DH keypair and compute shared secret
    (multiple-value-bind (dh-private dh-public) (cl-telegram/crypto:dh-generate-keypair)
      (setf (auth-dh-private-key state) dh-private)
      (setf (auth-dh-public-key state) dh-public))
    ;; Create client_DH_inner_data
    (auth-send-client-dh state)))

(defun auth-send-client-dh (state)
  "Create set_client_DH_params request.

   Returns: Serialized set_client_DH_params request"
  (let* ((constructor #xf5045f1f)  ; set_client_DH_params
         (nonce (auth-nonce state))
         (server-nonce (auth-server-nonce state))
         (g-b (cl-telegram/crypto:dh-compute-public-key (auth-dh-private-key state)))
         (g-b-bytes (cl-telegram/crypto:dh-compute-key g-b (auth-dh-private-key state))))
    (declare (g-b-bytes))  ; Placeholder
    (concatenate '(simple-array (unsigned-byte 8))
                 (cl-telegram/tl:serialize-int32 constructor)
                 (cl-telegram/tl:serialize-int128 nonce)
                 (cl-telegram/tl:serialize-int128 server-nonce)
                 (cl-telegram/tl:serialize-int64 0)  ; retry_id
                 (cl-telegram/tl:serialize-bytes g-b-bytes))))

(defun auth-handle-dh-response (state dh-response-bytes)
  "Handle set_client_DH_params_answer response.

   Args:
     state: Auth state
     dh-response-bytes: Serialized dh_gen_ok response

   Returns: T if auth complete, NIL otherwise

   Side effects: Sets auth-key if successful"
  (let* ((response (cl-telegram/tl:tl-deserialize dh-response-bytes))
         (nonce (cl-telegram/tl:dhg-nonce response))
         (server-nonce (cl-telegram/tl:dhg-server-nonce response))
         (new-nonce-hash (cl-telegram/tl:dhg-new-nonce-hash response)))
    ;; Verify nonces
    (assert (equalp nonce (auth-nonce state)))
    (assert (equalp server-nonce (auth-server-nonce state)))
    ;; Verify new_nonce_hash matches our new_nonce
    ;; Compute auth_key = SHA256(nonce + server_nonce + new_nonce)
    (let* ((combined (concatenate '(simple-array (unsigned-byte 8))
                                  (auth-nonce state)
                                  (auth-server-nonce state)
                                  (auth-new-nonce state)))
           (auth-key (cl-telegram/crypto:sha256 combined)))
      (setf (auth-auth-key state) auth-key)
      (setf (auth-status state) :ready))
    t))

(defun auth-complete-p (state)
  "Check if authentication is complete."
  (eq (auth-status state) :ready))
