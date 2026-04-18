;;; mtproto-package.lisp --- Package definition for MTProto protocol layer

(defpackage #:cl-telegram/mtproto
  (:nicknames #:cl-tg/mtproto)
  (:use #:cl)
  (:export
   ;; Authentication
   #:make-auth-state
   #:auth-state
   #:auth-state-status
   #:auth-state-nonce
   #:auth-state-server-nonce
   #:auth-state-dh-private
   #:auth-state-server-dh-inner

   ;; Auth functions
   #:auth-init
   #:auth-send-pq-request
   #:auth-handle-respq
   #:auth-send-dh-request
   #:auth-handle-server-dh
   #:auth-send-client-dh
   #:auth-handle-dh-response
   #:auth-complete-p

   ;; Encryption/Decryption
   #:encrypt-message
   #:decrypt-message
   #:make-message-header

   ;; Transport
   #:make-transport-packet
   #:parse-transport-packet
   #:compute-message-length

   ;; Constants
   #:*default-dc-id*
   #:*api-id*
   #:*api-hash*
   #:*telegram-server-key))
