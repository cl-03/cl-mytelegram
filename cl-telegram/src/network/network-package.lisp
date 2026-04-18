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
   #:rpc-handler-case

   ;; Proxy
   #:proxy-config
   #:make-proxy-config
   #:proxy-config-type
   #:proxy-config-host
   #:proxy-config-port
   #:proxy-config-username
   #:proxy-config-password
   #:proxy-config-use-dns
   #:proxy-config-timeout
   #:*global-proxy-config*
   #:configure-proxy
   #:reset-proxy-config
   #:proxy-enabled-p
   #:connect-through-proxy
   #:async-connect-through-proxy
   #:detect-system-proxy
   #:use-system-proxy
   #:get-proxy-info
   #:with-proxy-connection

   ;; CDN / DC Manager
   #:dc-manager
   #:make-dc-manager
   #:get-dc-connection
   #:get-current-connection
   #:select-best-dc
   #:switch-dc
   #:measure-dc-latency
   #:measure-all-dc-latencies
   #:get-dc-info
   #:dc-manager-stats
   #:migrate-to-dc
   #:export-auth
   #:import-auth
   #:dc-id-from-phone

   ;; CDN Config
   #:cdn-config
   #:make-cdn-config
   #:*cdn-config*
   #:configure-cdn
   #:cdn-config-enabled
   #:cdn-config-base-url
   #:cdn-config-fallback-dcs
   #:cdn-config-max-concurrent-downloads
   #:cdn-config-chunk-size

   ;; Message Queue
   #:message-queue
   #:make-message-queue
   #:enqueue-message
   #:dequeue-message
   #:queue-length
   #:queue-stats
   #:process-queue
   #:*global-message-queue*
   #:init-global-queue
   #:enqueue-rpc-request))
