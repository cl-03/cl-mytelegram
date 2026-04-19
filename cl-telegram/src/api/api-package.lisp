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
   ;; Group/Channel Administration
   #:get-chat-administrators
   #:set-chat-administrator
   #:ban-chat-member
   #:unban-chat-member
   #:create-chat-invite-link
   #:get-chat-invite-link
   #:revoke-chat-invite-link
   #:get-chat-invite-link-members
   ;; Channel-Specific
   #:get-channel-members
   #:get-channel-full-info
   #:set-channel-description
   #:set-channel-username
   #:delete-channel
   #:export-channel-invite-link
   #:join-channel
   #:leave-channel

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
   #:clear-all-cache

   ;; VoIP / Calls
   #:make-call-manager
   #:*call-manager*
   #:init-voip
   #:close-voip
   #:make-call-protocol
   #:create-call
   #:accept-call
   #:decline-call
   #:end-call
   #:toggle-call-mute
   #:toggle-call-video
   #:get-call
   #:list-active-calls
   #:get-call-stats
   ;; Group Calls
   #:create-group-call
   #:join-group-call
   #:leave-group-call
   #:toggle-group-call-mute
   #:toggle-group-call-video
   #:get-group-call-participants
   #:get-group-call
   #:list-active-group-calls
   #:get-group-call-stats
   ;; WebRTC
   #:generate-webrtc-offer
   #:generate-webrtc-answer
   #:handle-ice-candidate
   ;; WebRTC FFI
   #:*webrtc-manager*
   #:*webrtc-initialized*
   #:init-webrtc
   #:shutdown-webrtc
   #:create-webrtc-peer-connection
   #:close-webrtc-peer-connection
   #:create-webrtc-media-stream
   #:close-webrtc-media-stream
   #:create-webrtc-offer
   #:create-webrtc-answer
   #:set-webrtc-remote-description
   #:add-webrtc-ice-candidate
   #:create-webrtc-data-channel
   #:send-webrtc-data
   #:close-webrtc-data-channel
   #:get-webrtc-state
   #:get-webrtc-signaling-state
   #:start-webrtc-call
   #:accept-webrtc-call
   #:add-webrtc-candidate-to-call
   #:webrtc-stats
   #:test-webrtc-connection
   #:get-pending-ice-candidates

   ;; Performance Optimizations
   #:get-cached-messages-optimized
   #:get-cached-chat-optimized
   #:start-connection-pool-cleaner
   #:stop-connection-pool-cleaner
   #:get-connection-from-pool-optimized
   #:cache-message-in-memory
   #:get-cached-messages-in-memory
   #:clear-message-cache
   #:batch-get-cached-users
   #:batch-cache-messages
   #:with-performance-monitoring
   #:record-performance-metric
   #:get-performance-stats
   #:reset-performance-stats
   #:optimize-database

   ;; Stickers & Emoji
   #:sticker
   #:sticker-set
   #:emoji-pack
   #:sticker-file-id
   #:sticker-file-unique-id
   #:sticker-width
   #:sticker-height
   #:sticker-is-animated
   #:sticker-is-video
   #:sticker-thumbnail
   #:sticker-emoji
   #:sticker-set-name
   #:sticker-set-title
   #:sticker-set-stickers
   #:sticker-set-emoji-representation
   #:emoji-pack-id
   #:emoji-pack-title
   #:emoji-pack-emoji-list
   #:emoji-pack-is-installed
   #:*sticker-cache*
   #:*emoji-packs*
   #:*favorite-stickers*
   #:get-sticker-set
   #:search-sticker-sets
   #:get-all-sticker-sets
   #:install-sticker-set
   #:uninstall-sticker-set
   #:add-sticker-to-set
   #:remove-sticker-from-set
   #:upload-sticker
   #:create-new-sticker-set
   #:get-favorite-stickers
   #:add-favorite-sticker
   #:remove-favorite-sticker
   #:get-emoji-packs
   #:install-emoji-pack
   #:uninstall-emoji-pack
   #:get-installed-emoji-packs
   #:send-sticker
   #:get-sticker-from-message
   #:send-custom-emoji
   #:get-custom-emoji
   #:search-stickers
   #:get-trending-stickers
   #:render-sticker-picker
   #:render-emoji-picker
   #:sticker-dimension-string
   #:sticker-type-string
   #:clear-sticker-cache

   ;; Channels & Broadcast
   #:channel
   #:channel-post
   #:message-reaction
   #:channel-id
   #:channel-title
   #:channel-description
   #:channel-username
   #:channel-photo
   #:channel-member-count
   #:channel-is-broadcast
   #:channel-is-megagroup
   #:channel-is-admin
   #:channel-is-owner
   #:channel-can-post-messages
   #:channel-can-edit-messages
   #:channel-can-delete-messages
   #:channel-linked-chat-id
   #:channel-post-id
   #:channel-post-channel-id
   #:channel-post-text
   #:channel-post-media
   #:channel-post-date
   #:channel-post-views
   #:channel-post-forwards
   #:channel-post-reactions
   #:channel-post-comments-count
   #:channel-post-is-pinned
   #:message-reaction-id
   #:message-reaction-message-id
   #:message-reaction-chat-id
   #:message-reaction-emoji
   #:message-reaction-count
   #:message-reaction-is-selected
   #:message-reaction-recent-reactors
   #:*channel-cache*
   #:*available-reactions*
   #:*recent-reactions*
   #:get-channel
   #:get-my-channels
   #:create-channel
   #:delete-channel
   #:set-channel-info
   #:set-channel-photo
   #:delete-channel-photo
   #:get-channel-administrators
   #:add-channel-administrator
   #:remove-channel-administrator
   #:ban-channel-user
   #:unban-channel-user
   #:get-channel-banned-users
   #:export-channel-invite-link
   #:revoke-channel-invite-link
   #:create-channel-invite-link
   #:get-channel-invite-link-info
   #:broadcast-to-channel
   #:edit-channel-message
   #:delete-channel-message
   #:pin-channel-message
   #:unpin-channel-message
   #:get-channel-stats
   #:get-channel-post-stats
   #:get-channel-members
   #:get-message-reactions
   #:send-message-reaction
   #:remove-message-reaction
   #:get-recent-reactors
   #:set-available-reactions
   #:get-channel-post
   #:get-channel-posts
   #:get-pinned-messages
   #:get-post-comments
   #:send-comment
   #:render-channel-list
   #:render-broadcast-panel
   #:render-reaction-panel
   #:render-channel-stats
   #:channel-type-string
   #:clear-channel-cache
   #:clear-reaction-cache

   ;; Inline Bots & Keyboards
   #:inline-query
   #:inline-result
   #:chosen-inline-result
   #:inline-keyboard-button
   #:inline-keyboard-markup
   #:callback-query
   #:reply-keyboard-button
   #:reply-keyboard-markup
   #:reply-keyboard-remove
   #:force-reply
   #:web-app-info
   #:web-app-data
   #:inline-query-id
   #:inline-query-from
   #:inline-query-query
   #:inline-query-offset
   #:inline-query-chat-type
   #:inline-query-location
   #:inline-result-id
   #:inline-result-type
   #:inline-result-title
   #:inline-result-description
   #:inline-result-message-text
   #:inline-result-input-message-content
   #:inline-result-reply-markup
   #:chosen-result-id
   #:chosen-result-from
   #:chosen-result-location
   #:chosen-inline-message-id
   #:chosen-result-query
   #:inline-button-text
   #:inline-button-url
   #:inline-button-callback-data
   #:inline-button-switch-inline
   #:inline-button-switch-bot
   #:inline-button-web-app
   #:inline-keyboard-keyboard
   #:inline-keyboard-resize
   #:inline-keyboard-one-time
   #:inline-keyboard-selective
   #:callback-query-id
   #:callback-query-from
   #:callback-query-message
   #:callback-query-inline-message-id
   #:callback-query-chat-instance
   #:callback-query-data
   #:callback-query-game-short-name
   #:reply-button-text
   #:reply-button-request-user
   #:reply-button-request-chat
   #:reply-button-request-contact
   #:reply-button-request-location
   #:reply-button-request-poll
   #:reply-button-web-app
   #:reply-keyboard-keyboard
   #:reply-keyboard-resize
   #:reply-keyboard-one-time
   #:reply-keyboard-persistent
   #:reply-keyboard-selective
   #:reply-keyboard-placeholder
   #:reply-keyboard-remove-p
   #:reply-keyboard-remove-selective
   #:force-reply-p
   #:force-reply-selective
   #:force-reply-placeholder
   #:web-app-url
   #:web-app-button-text
   #:web-app-start-param
   #:web-app-query-id
   #:web-app-chat-type
   #:web-app-chat-instance
   #:*inline-bot-handlers*
   #:*callback-query-handlers*
   #:*command-handlers*
   #:*inline-bot-token*
   #:register-inline-bot-handler
   #:unregister-inline-bot-handler
   #:dispatch-inline-query
   #:dispatch-callback-query
   #:answer-inline-query
   #:answer-callback-query
   #:make-inline-result-article
   #:make-inline-result-photo
   #:make-inline-result-gif
   #:make-inline-result-sticker
   #:make-inline-result-video
   #:make-inline-result-audio
   #:make-inline-result-voice
   #:make-inline-result-location
   #:make-inline-result-venue
   #:make-inline-result-contact
   #:make-inline-result-game
   #:make-inline-keyboard-button
   #:make-inline-keyboard
   #:make-reply-keyboard-button
   #:make-reply-keyboard
   #:make-reply-keyboard-remove
   #:make-force-reply
   #:make-web-app-button
   #:send-web-app-data
   #:process-inline-update
   #:parse-inline-query
   #:parse-callback-query
   #:render-inline-keyboard
   #:render-reply-keyboard
   #:show-inline-results
   #:keyboard-button-p
   #:clear-keyboard-cache
   #:get-inline-bot-token
   #:set-inline-bot-token))
