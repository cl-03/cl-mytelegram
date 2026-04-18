;;; api-package.lisp --- Package definition for API layer

(defpackage #:cl-telegram/api
  (:nicknames #:cl-tg/api)
  (:use #:cl)
  (:export
   ;; Authentication State
   #:*auth-state*
   #:*auth-phone-number*
   #:*auth-code-info*
   #:*auth-connection*
   #:*auth-session-id*

   ;; Authentication API
   #:set-authentication-phone-number
   #:request-authentication-code
   #:check-authentication-code
   #:set-authentication-password
   #:register-user
   #:get-authentication-state

   ;; Session Management
   #:get-auth-session
   #:reset-auth-session
   #:authorized-p
   #:needs-phone-p
   #:needs-code-p
   #:needs-password-p
   #:needs-registration-p
   #:ensure-auth-connection
   #:close-auth-connection

   ;; TDLib Compatibility
   #:|setTdlibParameters|
   #:|setAuthenticationPhoneNumber|
   #:|requestAuthenticationCode|
   #:|checkAuthenticationCode|
   #:|checkAuthenticationPassword|
   #:|registerUser|

   ;; Demo
   #:demo-auth-flow

   ;; Messages API
   #:send-message
   #:get-messages
   #:delete-messages
   #:forward-messages
   #:edit-message
   #:get-message-history
   #:search-messages
   #:send-reaction
   #:send-file
   #:download-file
   #:send-photo
   #:send-document
   #:send-audio
   #:send-video
   #:*upload-part-size*
   #:*max-file-size*

   ;; Chats API
   #:get-chats
   #:get-chat
   #:create-private-chat
   #:get-chat-history
   #:create-basic-group-chat
   #:create-supergroup-chat
   #:get-chat-members
   #:add-chat-member
   #:remove-chat-member
   #:send-chat-action
   #:set-chat-title
   #:toggle-chat-muted
   #:clear-chat-history
   #:search-chats

   ;; Users API
   #:get-users
   #:get-user
   #:get-me
   #:search-users
   #:get-user-profile-photos
   #:get-user-full-info
   #:get-user-status
   #:get-contacts
   #:add-contact
   #:delete-contacts
   #:block-user
   #:unblock-user
   #:get-blocked-users
   #:set-bio

   ;; Updates
   #:set-update-handler
   #:remove-update-handler
   #:start-update-loop
   #:stop-update-loop

   ;; Update Handler
   #:make-update-handler
   #:update-handler
   #:register-update-handler
   #:unregister-update-handler
   #:clear-update-handlers
   #:dispatch-update
   #:process-update-object
   #:update-stats
   #:with-update-handler

   ;; Bot API - Configuration
   #:make-bot
   #:bot-config
   #:make-bot-config
   #:bot-config-token
   #:bot-config-api-url
   #:bot-config-timeout
   #:bot-config-use-test-environment

   ;; Bot API - Core
   #:bot-request
   #:get-me
   #:get-my-name
   #:get-my-description
   #:get-my-short-description

   ;; Bot API - Sending Messages
   #:bot-send-message
   #:bot-send-photo
   #:bot-send-document
   #:bot-send-sticker
   #:bot-send-location
   #:bot-send-chat-action
   #:bot-edit-message-text
   #:bot-delete-message

   ;; Bot API - Updates
   #:get-updates
   #:set-webhook
   #:delete-webhook
   #:get-webhook-info

   ;; Bot API - Chat Management
   #:bot-get-chat
   #:bot-get-chat-member
   #:bot-get-chat-administrators
   #:bot-ban-chat-member
   #:bot-unban-chat-member
   #:bot-restrict-chat-member

   ;; Bot API - Handlers
   #:make-bot-handler
   #:bot-handler
   #:defcommand
   #:register-command
   #:unregister-command
   #:register-message-handler
   #:process-update
   #:start-polling
   #:stop-polling
   #:setup-basic-commands
   #:register-inline-handler
   #:answer-inline-query

   ;; Secret Chats (E2E Encryption)
   #:make-secret-chat-manager
   #:*secret-chat-manager*
   #:secret-chat
   #:secret-chat-manager
   #:request-secret-chat
   #:accept-secret-chat-request
   #:get-secret-chat
   #:get-secret-chat-with-user
   #:list-secret-chats
   #:close-secret-chat
   #:send-secret-message
   #:send-secret-media
   #:send-secret-chat-action
   #:set-secret-chat-ttl
   #:mark-secret-messages-read
   #:delete-secret-messages
   #:handle-encrypted-message-update

   ;; Local Database Cache
   #:init-database
   #:close-database
   #:cache-user
   #:get-cached-user
   #:search-cached-users
   #:cache-chat
   #:get-cached-chat
   #:list-cached-chats
   #:cache-message
   #:cache-messages
   #:get-cached-messages
   #:get-cached-message
   #:search-cached-messages
   #:delete-cached-message
   #:clear-chat-cache
   #:cache-secret-chat
   #:get-cached-secret-chat
   #:cache-session
   #:get-current-session
   #:get-cached-auth-key
   #:cache-file-info
   #:get-cached-file-path
   #:set-setting
   #:get-setting
   #:get-database-stats
   #:vacuum-database
   #:clear-all-cache))
