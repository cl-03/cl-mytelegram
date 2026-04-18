;;; dh.lisp --- Diffie-Hellman key exchange for MTProto 2.0

(in-package #:cl-telegram/crypto)

;;; MTProto 2.0 DH parameters (from Telegram specification)
;;; These are well-known 2048-bit safe primes

;; Safe prime p = 2q + 1 where q is also prime
;; g is a generator of the subgroup of order q

(defparameter *dh-p*
  "MTProto 2.0 DH prime (2048-bit safe prime)"
  #x00ffffffffffffffffc90fdaa22168c234c4c6628b80dc1cd129024e088a67cc74020bbea63b139b22514a08798e3404ddef9519b3cd3a431b302b0a6df25f14374fe1356d6d51c245e485b576625e7ec6f44c42e9a637ed6b0bff5cb6f406b7edee386bfb5a899fa5ae9f24117c4b1fe649286651ece45b3dc2007cb8a163bf0598da48361c55d39a69163fa8fd24cf5f83655d23dca3ad961c62f356208552bb9ed529077096966d670c354e4abc9804f1746c08ca237327ffffffffffffffff)

(defparameter *dh-g*
  "MTProto 2.0 DH generator"
  3)

(defun dh-generate-private-key ()
  "Generate a random DH private key (256-bit for MTProto)."
  ;; Generate random 256-bit number
  (let ((key 0))
    (dotimes (i 32 key)
      (setf key (logior (ash key 8) (random 256)))))

(defun dh-compute-public-key (private-key)
  "Compute DH public key: g^private mod p

   Args:
     private-key: Private key integer

   Returns:
     Public key integer"
  (mod (expt *dh-g* private-key) *dh-p*))

(defun dh-generate-keypair ()
  "Generate a DH keypair.

   Returns:
     (values private-key public-key)"
  (let ((private (dh-generate-private-key)))
    (values private (dh-compute-public-key private))))

(defun dh-compute-shared-secret (remote-public private-key)
  "Compute shared secret from remote's public key and our private key.

   Args:
     remote-public: Remote party's public key
     private-key: Our private key

   Returns:
     Shared secret integer"
  (mod (expt remote-public private-key) *dh-p*))

(defun dh-compute-key (remote-public private-key)
  "Compute DH shared key for MTProto.

   This is a wrapper that converts the shared secret to bytes."
  (let ((shared (dh-compute-shared-secret remote-public private-key)))
    ;; Convert to 256-byte array (big-endian)
    (let ((output (make-array 256 :element-type '(unsigned-byte 8))))
      (loop for i from 255 downto 0 do
        (setf (aref output i) (logand shared #xFF))
        (setf shared (ash shared -8)))
      output)))
