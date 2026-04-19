;;; ui-package.lisp --- Package definition for UI layer

(defpackage #:cl-telegram/ui
  (:nicknames #:cl-tg/ui)
  (:use #:cl)
  (:export
   ;; CLI Client
   #:run-cli-client
   #:cli-read-input
   #:cli-display-message
   #:cli-display-chat-list

   ;; CLOG UI (optional GUI)
   #:make-clog-ui
   #:clog-ui-run
   #:clog-ui-show-chat
   #:clog-ui-update-message
   #:start-clog-ui
   #:stop-clog-ui
   #:show-clog-ui
   #:create-demo-ui

   ;; Media Viewer
   #:media-item
   #:media-viewer
   #:media-file-id
   #:media-file-type
   #:media-file-path
   #:media-file-size
   #:media-mime-type
   #:media-thumbnail
   #:media-caption
   #:media-width
   #:media-height
   #:media-duration
   #:extract-media-from-message
   #:download-media
   #:render-media-thumbnail
   #:render-media-viewer
   #:open-media-viewer
   #:render-media-gallery
   #:find-messages-with-media
   #:get-media-count
   #:open-media-viewer-from-file-id
   #:download-media-from-file-id
   #:download-and-play-video

   ;; Group Chat UI
   #:render-group-members-list
   #:show-group-info-panel
   #:show-group-admin-panel
   #:create-group-invite-link-ui

   ;; Call UI
   #:show-call-panel
   #:show-group-call-panel
   #:render-call-controls
   #:update-call-state

   ;; Premium UI (v0.13.0)
   #:render-premium-badge
   #:render-premium-status-indicator
   #:create-premium-feature-panel
   #:render-chat-header-with-premium

   ;; Stories Viewer Enhancements
   #:render-story-with-animation

   ;; Theme Switching
   #:switch-theme
   #:create-theme-switcher
   #:*current-theme*))
