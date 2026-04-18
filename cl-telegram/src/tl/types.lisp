;;; types.lisp --- TL type definitions for MTProto 2.0

(in-package #:cl-telegram/tl)

;;; ### TL Base Types

;; TL (Type Language) is Telegram's binary serialization format
;; Reference: https://core.telegram.org/mtproto/TL

(defmacro define-tl-type (name fields)
  "Define a TL type with constructor ID and fields."
  `(defstruct ,name
     ,@fields))

;;; ### TL Primitive Types

(deftype tl-int32 () '(signed-byte 32))
(deftype tl-int64 () '(signed-byte 64))
(deftype tl-int128 () '(unsigned-byte 128))
(deftype tl-int256 () '(unsigned-byte 256))
(deftype tl-bytes () '(simple-array (unsigned-byte 8) (*)))
(deftype tl-string () 'string)
(deftype tl-bool () 'boolean)

;;; ### Helper functions for TL primitives

(defun make-tl-int32 (value)
  "Create a 32-bit signed integer."
  (assert (<= -2147483648 value 2147483647))
  value)

(defun make-tl-int64 (value)
  "Create a 64-bit signed integer."
  (assert (<= -9223372036854775808 value 9223372036854775807))
  value)

(defun make-tl-int128 (value)
  "Create a 128-bit unsigned integer (as 16-byte array)."
  (let ((bytes (make-array 16 :element-type '(unsigned-byte 8))))
    (loop for i from 15 downto 0 do
      (setf (aref bytes i) (logand value #xFF))
      (setf value (ash value -8)))
    bytes))

(defun make-tl-int256 (value)
  "Create a 256-bit unsigned integer (as 32-byte array)."
  (let ((bytes (make-array 32 :element-type '(unsigned-byte 8))))
    (loop for i from 31 downto 0 do
      (setf (aref bytes i) (logand value #xFF))
      (setf value (ash value -8)))
    bytes))

(defun make-tl-bytes (data)
  "Create a TL bytes object (length-prefixed byte array)."
  (if (stringp data)
      (cl-babel:string-to-octets data :encoding :utf-8)
      data))

(defun make-tl-string (string)
  "Create a TL string (length-prefixed UTF-8 string)."
  (cl-babel:string-to-octets string :encoding :utf-8))

(defun make-tl-bool (value)
  "Create a TL boolean (0x997275bc for true, 0xbc799731 for false)."
  (if value #x997275bc #xbc799731))

(defun make-tl-vector (elements)
  "Create a TL vector (length-prefixed list of elements)."
  (coerce elements 'vector))

;;; ### TL Object base class

(defclass tl-object ()
  ((constructor :initarg :constructor :accessor tl-constructor
                :documentation "32-bit constructor ID")
   (fields :initarg :fields :initform nil :accessor tl-fields
           :documentation "Plist of field name-value pairs"))
  (:documentation "Base class for all TL objects"))

;;; ### MTProto Protocol Types (from mtproto_api.tl)

;; resPQ#05162463
(define-tl-type respq
  ((nonce :initarg :nonce :accessor respq-nonce)              ; int128
   (server-nonce :initarg :server-nonce :accessor respq-server-nonce) ; int128
   (pq :initarg :pq :accessor respq-pq)                       ; string (byte array)
   (server-public-key-fingerprints :initarg :fingerprints :accessor respq-fingerprints))) ; vector<long>

(defparameter +constructor-id-respq+ #x05162463)

;; server_DH_params_ok#d0e8075c
(define-tl-type server-dh-params-ok
  ((nonce :initarg :nonce :accessor sdh-nonce)
   (server-nonce :initarg :server-nonce :accessor sdh-server-nonce)
   (encrypted-answer :initarg :encrypted-answer :accessor sdh-encrypted-answer)))

(defparameter +constructor-id-server-dh-params-ok+ #xd0e8075c)

;; server_DH_inner_data#b5890dba
(define-tl-type server-dh-inner-data
  ((nonce :initarg :nonce :accessor sdhi-nonce)
   (server-nonce :initarg :server-nonce :accessor sdhi-server-nonce)
   (g :initarg :g :accessor sdhi-g)
   (dh-prime :initarg :dh-prime :accessor sdhi-dh-prime)
   (g-a :initarg :g-a :accessor sdhi-g-a)
   (server-time :initarg :server-time :accessor sdhi-server-time)))

(defparameter +constructor-id-server-dh-inner-data+ #xb5890dba)

;; dh_gen_ok#3bcbf734
(define-tl-type dh-gen-ok
  ((nonce :initarg :nonce :accessor dhg-nonce)
   (server-nonce :initarg :server-nonce :accessor dhg-server-nonce)
   (new-nonce-hash :initarg :new-nonce-hash :accessor dhg-new-nonce-hash)))

(defparameter +constructor-id-dh-gen-ok+ #x3bcbf734)

;; rpc_error#2144ca19
(define-tl-type rpc-error
  ((error-code :initarg :error-code :accessor rpc-error-code)
   (error-message :initarg :error-message :accessor rpc-error-message)))

(defparameter +constructor-id-rpc-error+ #x2144ca19)

;; p_q_inner_data_dc#a9f55f95
(define-tl-type p-q-inner-data
  ((pq :initarg :pq :accessor pqi-pq)
   (p :initarg :p :accessor pqi-p)
   (q :initarg :q :accessor pqi-q)
   (nonce :initarg :nonce :accessor pqi-nonce)
   (server-nonce :initarg :server-nonce :accessor pqi-server-nonce)
   (new-nonce :initarg :new-nonce :accessor pqi-new-nonce)
   (dc :initarg :dc :accessor pqi-dc)))

(defparameter +constructor-id-p-q-inner-data+ #xa9f55f95)

;; client_DH_inner_data#6643b654
(define-tl-type client-dh-inner-data
  ((nonce :initarg :nonce :accessor cdhi-nonce)
   (server-nonce :initarg :server-nonce :accessor cdhi-server-nonce)
   (retry-id :initarg :retry-id :accessor cdhi-retry-id)
   (g-b :initarg :g-b :accessor cdhi-g-b)))

(defparameter +constructor-id-client-dh-inner-data+ #x6643b654)

;;; ### TDLib API Types (from td_api.tl) - Core types

;; error code:int32 message:string = Error
(define-tl-type td-error
  ((code :initarg :code :accessor td-error-code)
   (message :initarg :message :accessor td-error-message)))

(defparameter +constructor-id-td-error+ #xe6211d5c)  ; Computed constructor ID

;; ok = Ok
(define-tl-type td-ok ())

(defparameter +constructor-id-td-ok+ #x9d84f1d8)  ; Computed constructor ID

;; Authorization states
(define-tl-type authorization-state-wait-tdlib-parameters ())
(define-tl-type authorization-state-wait-phone-number ())
(define-tl-type authorization-state-wait-code
  ((code-info :initarg :code-info :accessor asc-code-info)))
(define-tl-type authorization-state-wait-password
  ((password-hint :initarg :password-hint :accessor asp-password-hint)
   (has-recovery-email :initarg :has-recovery-email :accessor asp-has-recovery-email)
   (has-passport-data :initarg :has-passport-data :accessor asp-has-passport-data)
   (recovery-email-pattern :initarg :recovery-email-pattern :accessor asp-recovery-email-pattern)))
(define-tl-type authorization-state-ready ())
(define-tl-type authorization-state-closed ())
