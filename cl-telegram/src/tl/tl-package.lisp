;;; tl-package.lisp --- Package definition for TL serialization layer

(defpackage #:cl-telegram/tl
  (:nicknames #:cl-tg/tl)
  (:use #:cl)
  (:export
   ;; TL Types
   #:make-tl-int32
   #:make-tl-int64
   #:make-tl-int128
   #:make-tl-int256
   #:make-tl-bytes
   #:make-tl-string
   #:make-tl-bool
   #:make-tl-vector

   ;; Serialization
   #:tl-serialize
   #:tl-serialize-to-bytes

   ;; Deserialization
   #:tl-deserialize
   #:tl-deserialize-from-bytes

   ;; TL Objects
   #:tl-object
   #:tl-constructor
   #:tl-fields

   ;; MTProto specific types
   #:respq
   #:server-dh-params
   #:client-dh-inner-data
   #:dh-gen-ok
   #:rpc-error

   ;; Constructor IDs
   #:constructor-id-respq
   #:constructor-id-server-dh-params-ok
   #:constructor-id-dh-gen-ok
   #:constructor-id-rpc-error))
