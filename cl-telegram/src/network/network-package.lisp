;;; network-package.lisp --- Package definition for network layer

(defpackage #:cl-telegram/network
  (:nicknames #:cl-tg/network)
  (:use #:cl)
  (:export
   ;; TCP Client (Async)
   #:make-tcp-client
   #:tcp-client
   #:client-connect
   #:client-disconnect
   #:client-send
   #:client-send-sync
   #:client-receive
   #:client-connected-p
   #:client-start-receive
   #:client-reconnect
   #:client-reset

   ;; TCP Client (Sync)
   #:make-sync-tcp-client
   #:sync-tcp-client
   #:sync-client-connect
   #:sync-client-disconnect
   #:sync-client-send
   #:sync-client-receive
   #:sync-client-receive-available
   #:sync-client-connected-p

   ;; Connection
   #:make-connection
   #:connection
   #:connect
   #:disconnect
   #:connected-p
   #:reconnect
   #:conn-session-id
   #:conn-seqno
   #:conn-last-msg-id
   #:conn-server-salt
   #:conn-auth-key
   #:conn-auth-key-id
   #:conn-tcp-client
   #:conn-pending-requests
   #:conn-event-handlers
   #:connection-send
   #:connection-send-rpc
   #:generate-msg-id

   ;; RPC
   #:rpc-call
   #:rpc-call-async
   #:rpc-call-with-retry
   #:rpc-batch
   #:wait-for-response
   #:build-rpc-request

   ;; RPC Helpers
   #:send-ping
   #:send-ping-delay-disconnect
   #:get-future-salts

   ;; Events
   #:set-event-handler
   #:remove-event-handler
   #:notify-event-handlers

   ;; Macros
   #:with-rpc-call
   #:rpc-handler-case))
