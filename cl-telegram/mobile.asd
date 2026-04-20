;;; mobile.asd --- Mobile platform integration system definition

(asdf:defsystem #:cl-telegram/mobile
  :description "Mobile platform integration for cl-telegram (iOS/Android)"
  :author "cl-telegram team"
  :license "Boost Software License 1.0"
  :version "0.24.0"
  :depends-on (:cl-telegram
               :cl-log
               :uiop
               :cl-ppcre)
  :serial t
  :pathname "mobile/"
  :components ((:file "mobile-package")
               (:file "mobile-utilities")
               (:file "ios-integration")
               (:file "android-integration")))
