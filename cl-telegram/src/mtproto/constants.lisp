;;; constants.lisp --- MTProto constants and configuration

(in-package #:cl-telegram/mtproto)

;;; ### API Configuration
;;; Get your own API ID and hash from https://my.telegram.org

(defparameter *api-id* 0
  "Telegram API ID. Replace with your own from https://my.telegram.org")

(defparameter *api-hash* ""
  "Telegram API hash. Replace with your own from https://my.telegram.org")

;;; ### Datacenter Configuration

(defparameter *default-dc-id* 2
  "Default datacenter ID for initial connection")

;; Telegram datacenter endpoints
(defparameter *dc-endpoints*
  '((1 . "149.154.175.53")   ; DC1
    (2 . "149.154.167.51")   ; DC2
    (3 . "149.154.175.100")  ; DC3
    (4 . "149.154.167.91")   ; DC4
    (5 . "149.154.171.5"))   ; DC5
  "Telegram datacenter IP addresses")

(defparameter *dc-port* 443
  "Telegram server port (TCP)")

;;; ### Protocol Constants

(defparameter +mtproto-version+ 51
  "MTProto protocol version (current is 51 for MTProto 2.0)")

(defparameter +layer-version+ 176
  "API layer version (updates with new Telegram features)")

;;; ### Message Types

(defparameter +msg-container+ #x73f1f8dc)
(defparameter +rpc-result+ #xf35c6d01)
(defparameter +rpc-error+ #x2144ca19)
(defparameter +msg-ack+ #x62d6b459)
(defparameter +gzip-packed+ #x3072cfa1)

;;; ### Timeouts

(defparameter +connect-timeout+ 10000
  "Connection timeout in milliseconds")

(defparameter +request-timeout+ 30000
  "Request timeout in milliseconds")

(defparameter +ping-interval+ 60000
  "Ping interval in milliseconds")
