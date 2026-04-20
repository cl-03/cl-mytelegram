;; image-processing.asd - ASDF system definition for image processing

(asdf:defsystem #:cl-telegram/image-processing
  :description "Image processing utilities using Opticl"
  :author "cl-telegram team"
  :license "Boost Software License 1.0"
  :version "0.1.0"
  :depends-on (:opticl
               :cl-log
               :trivial-2d-array)
  :pathname "src/image-processing/"
  :serial t
  :components ((:file "image-processing-package")
               (:file "image-operations")
               (:file "image-filters")
               (:file "image-overlays")
               (:file "instagram-filters")))

;; Test system
(asdf:defsystem #:cl-telegram/image-processing-tests
  :description "Tests for cl-telegram/image-processing"
  :depends-on (:cl-telegram/image-processing :fiveam)
  :pathname "tests/"
  :serial t
  :components ((:file "image-processing-tests")))
