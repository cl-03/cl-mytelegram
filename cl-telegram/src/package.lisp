;;; package.lisp --- Main package definition for cl-telegram

(defpackage #:cl-telegram
  (:nicknames #:cl-tg #:telegram)
  (:use #:cl)
  ;; Export main API functions
  (:export
   ;; Version
   #:*cl-telegram-version*

   ;; Main client
   #:make-telegram-client
   #:telegram-client
   #:client-connect
   #:client-disconnect
   #:client-send
   #:client-receive

   ;; Authentication API
   #:auth-send-code
   #:auth-check-code
   #:auth-sign-in
   #:auth-sign-up
   #:auth-log-out

   ;; Messages API
   #:send-message
   #:get-messages
   #:delete-messages
   #:forward-messages

   ;; Chats API
   #:get-chats
   #:get-chat
   #:create-private-chat

   ;; Users API
   #:get-users
   #:get-user

   ;; Callbacks
   #:set-update-handler
   #:remove-update-handler))
