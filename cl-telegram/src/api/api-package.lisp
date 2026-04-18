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
   #:stop-update-loop))
