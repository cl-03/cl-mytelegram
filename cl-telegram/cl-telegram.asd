;; cl-telegram.asd - ASDF system definition for cl-telegram
;; A pure Common Lisp Telegram client implementation

(asdf:defsystem #:cl-telegram
  :description "A pure Common Lisp Telegram client implementation using MTProto 2.0"
  :author "Your Name <your.email@example.com>"
  :license "Boost Software License 1.0"
  :version "0.1.0"
  :depends-on (:cl-async
               :usocket
               :dexador
               :ironclad
               :bordeaux-threads
               :cl-babel
               :cl-base64
               :trivial-gray-streams)
  :serial t
  :pathname "src/"
  :components ((:file "package")

               ;; Crypto layer
               (:module "crypto"
                :serial t
                :components ((:file "crypto-package")
                             (:file "aes-ige")
                             (:file "sha256")
                             (:file "rsa")
                             (:file "dh")
                             (:file "kdf"))))

               ;; TL Serialization layer
               (:module "tl"
                :serial t
                :components ((:file "tl-package")
                             (:file "types")
                             (:file "serializer")
                             (:file "deserializer"))))

               ;; MTProto Protocol layer
               (:module "mtproto"
                :serial t
                :components ((:file "mtproto-package")
                             (:file "constants")
                             (:file "auth")
                             (:file "encrypt")
                             (:file "decrypt")
                             (:file "transport"))))

               ;; Network layer
               (:module "network"
                :serial t
                :components ((:file "network-package")
                             (:file "tcp-client")
                             (:file "connection")
                             (:file "rpc")
                             (:file "proxy")
                             (:file "cdn"))))

               ;; API layer
               (:module "api"
                :serial t
                :components ((:file "api-package")
                             (:file "auth-api")
                             (:file "messages-api")
                             (:file "chats-api")
                             (:file "users-api"))))

               ;; UI layer
               (:module "ui"
                :serial t
                :components ((:file "ui-package")
                             (:file "cli-client")
                             (:file "clog-ui")))))

;; Test system
(asdf:defsystem #:cl-telegram/tests
  :description "Tests for cl-telegram"
  :depends-on (:cl-telegram :fiveam)
  :pathname "tests/"
  :components ((:file "package")
               (:file "crypto-tests")
               (:file "tl-tests")
               (:file "mtproto-tests")
               (:file "network-tests")
               (:file "proxy-tests")
               (:file "api-tests")
               (:file "ui-tests")
               (:file "integration-tests")))

;; Documentation system
(asdf:defsystem #:cl-telegram/docs
  :description "Documentation for cl-telegram"
  :depends-on (:cl-telegram)
  :pathname "docs/"
  :components ((:file "MTProto_2_0")
               (:file "API_REFERENCE")))
