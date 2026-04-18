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
   #:get-media-count))
