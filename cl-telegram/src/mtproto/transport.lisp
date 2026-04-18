;;; transport.lisp --- MTProto transport layer

(in-package #:cl-telegram/mtproto)

;;; MTProto Transport Packet Format:
;; +----------------+----------------+----------------+
;; |  auth_key_id   |    msg_key     |  encrypted_data |
;; |   8 bytes      |   16 bytes     |  variable       |
;; +----------------+----------------+----------------+

(defun make-transport-packet (auth-key-id msg-key encrypted-data)
  "Create a complete MTProto transport packet.

   Args:
     auth-key-id: 8-byte authorization key identifier
     msg-key: 16-byte message key
     encrypted-data: Encrypted message data

   Returns:
     Complete transport packet bytes"
  (concatenate '(simple-array (unsigned-byte 8))
               auth-key-id
               msg-key
               encrypted-data))

(defun parse-transport-packet (packet)
  "Parse a transport packet.

   Args:
     packet: Complete transport packet bytes

   Returns:
     (values auth-key-id msg-key encrypted-data)"
  (assert (>= (length packet) 24) () "Packet too short")
  (let ((auth-key-id (subseq packet 0 8))
        (msg-key (subseq packet 8 24))
        (encrypted-data (subseq packet 24)))
    (values auth-key-id msg-key encrypted-data)))

(defun compute-message-length (encrypted-length)
  "Compute total transport packet length.

   Args:
     encrypted-length: Length of encrypted message data

   Returns:
     Total packet length (header + data)"
  (+ 8  ; auth_key_id
     16 ; msg_key
     encrypted-length))

;;; ### TCP Connection helpers

(defun compute-padding (length)
  "Compute padding needed for 4-byte alignment.

   MTProto requires messages to be padded to 4-byte boundaries."
  (mod (- 4 (mod length 4)) 4))

(defun pad-message (message)
  "Pad message to 4-byte boundary."
  (let ((padding (compute-padding (length message))))
    (if (zerop padding)
        message
        (let ((padded (make-array (+ (length message) padding)
                                  :element-type '(unsigned-byte 8))))
          (replace padded message)
          padded))))

;;; ### Protocol version negotiation

(defun make-http-wait (max-delay wait-after max-wait)
  "Create http_wait configuration for connection.

   Args:
     max-delay: Maximum delay before sending (ms)
     wait-after: Wait after receiving (ms)
     max-wait: Maximum wait time (ms)

   Returns:
     Serialized http_wait object"
  (let ((constructor #x9299359f))  ; http_wait
    (concatenate '(simple-array (unsigned-byte 8))
                 (cl-telegram/tl:serialize-int32 constructor)
                 (cl-telegram/tl:serialize-int32 max-delay)
                 (cl-telegram/tl:serialize-int32 wait-after)
                 (cl-telegram/tl:serialize-int32 max-wait))))
