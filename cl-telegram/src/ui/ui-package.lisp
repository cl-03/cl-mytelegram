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
   #:clog-ui-update-message))
