;; cl-telegram.asd - ASDF system definition for cl-telegram
;; A pure Common Lisp Telegram client implementation

(asdf:defsystem #:cl-telegram
  :description "A pure Common Lisp Telegram client implementation using MTProto 2.0"
  :author "Your Name <your.email@example.com>"
  :license "Boost Software License 1.0"
  :version "0.35.0"
  :depends-on (:cl-async
               :usocket
               :dexador
               :ironclad
               :bordeaux-threads
               :babel
               :cl-base64
               :trivial-gray-streams
               :jonathan
               :cl-ppcre
               :clog
               :dbi
               :opticl
               :cl-log)
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
                             (:file "kdf")))
               ;; TL Serialization layer
               (:module "tl"
                :serial t
                :components ((:file "tl-package")
                             (:file "types")
                             (:file "serializer")
                             (:file "deserializer")))
               ;; MTProto Protocol layer
               (:module "mtproto"
                :serial t
                :components ((:file "mtproto-package")
                             (:file "constants")
                             (:file "auth")
                             (:file "encrypt")
                             (:file "decrypt")
                             (:file "transport")))
               ;; Network layer
               (:module "network"
                :serial t
                :components ((:file "network-package")
                             (:file "tcp-client")
                             (:file "connection")
                             (:file "rpc")
                             (:file "proxy")
                             (:file "cdn")
                             (:file "websocket-client")))
               ;; API layer
               (:module "api"
                :serial t
                :components ((:file "api-package")
                             (:file "auth-api")
                             (:file "messages-api")
                             (:file "chats-api")
                             (:file "users-api")
                             (:file "bot-api")
                             (:file "bot-handlers")
                             (:file "update-handler")
                             (:file "secret-chat")
                             (:file "database")
                             (:file "voip")
                             (:file "webrtc-ffi")
                             (:file "performance-optimizations")
                             (:file "performance-optimizations-v2")
                             (:file "performance-optimizations-v3")
                             (:file "performance-monitor")
                             (:file "stability")
                             (:file "stickers")
                             (:file "channels")
                             (:file "inline-bots")
                             (:file "message-threads")
                             (:file "voice-messages")
                             (:file "stories")
                             (:file "story-highlights")
                             (:file "channel-reactions")
                             (:file "advanced-media-editing")
                             (:file "premium")
                             (:file "optimizations-v2")
                             (:file "desktop-notifications")
                             (:file "group-management")
                             (:file "e2e-encryption")
                             (:file "search-discovery")
                             (:file "media-editing")
                             (:file "payment")
                             (:file "business")
                             (:file "chat-folders")
                             (:file "emoji-customization")
                             (:file "channel-advanced")
                             (:file "notifications")
                             (:file "contacts-enhanced")
                             (:file "utilities")
                             (:file "bot-api-8")
                             (:file "bot-api-8-extensions")
                             (:file "bot-api-9")
                             (:file "bot-api-9-mini-app")
                             (:file "bot-api-9-7")
                             (:file "bot-api-9-mini-app-enhanced")
                             (:file "bot-api-9-advanced")
                             (:file "performance-optimizations-v4")
                             (:file "translation")
                             (:file "group-video-call")
                             (:file "video-messages")
                             (:file "media-albums")
                             (:file "auto-delete-messages")
                             (:file "chat-backup")
                             (:file "global-search")
                             (:file "media-library")
                             (:file "custom-themes")
                             (:file "file-management-enhanced")
                             (:file "payment-stars")
                             (:file "account-security-enhanced")
                             (:file "message-enhanced")
                             (:file "bot-api-9-5")
                             (:file "bot-api-9-8")
                             (:file "telegram-business")))
               ;; UI layer
               (:module "ui"
                :serial t
                :components ((:file "ui-package")
                             (:file "cli-client")
                             (:file "clog-ui")
                             (:file "clog-components")
                             (:file "media-viewer")
                             (:file "media-gallery")
                             (:file "settings-panel")
                             (:file "web-server")))
               ;; Image processing layer
               (:module "image-processing"
                :serial t
                :components ((:file "image-processing-package")
                             (:file "image-operations")
                             (:file "image-filters")
                             (:file "image-overlays")
                             (:file "instagram-filters")))
               ;; Mobile layer
               (:module "mobile"
                :serial t
                :components ((:file "mobile-package")
                             (:file "mobile-utilities")
                             (:file "ios-integration")
                             (:file "android-integration")))))

;; Test system
(asdf:defsystem #:cl-telegram/tests
  :description "Tests for cl-telegram"
  :depends-on (:cl-telegram :fiveam :cl-ppcre :cl-telegram/image-processing)
  :pathname "tests/"
  :components ((:file "package")
               (:file "crypto-tests")
               (:file "tl-tests")
               (:file "mtproto-tests")
               (:file "network-tests")
               (:file "proxy-tests")
               (:file "api-tests")
               (:file "ui-tests")
               (:file "integration-tests")
               (:file "live-telegram-tests")
               (:file "bot-api-tests")
               (:file "update-handler-tests")
               (:file "secret-chat-tests")
               (:file "database-tests")
               (:file "group-channel-tests")
               (:file "voip-tests")
               (:file "integration-webrtc-tests")
               (:file "integration-telegram-tests")
               (:file "stickers-channels-tests")
               (:file "realtime-notification-tests")
               (:file "group-management-tests")
               (:file "e2e-encryption-tests")
               (:file "search-discovery-tests")
               (:file "media-editing-tests")
               (:file "performance-stability-tests")
               (:file "performance-optimizations-v3-tests")
               (:file "mobile-tests")
               (:file "voice-messages-tests")
               (:file "file-management-tests")
               (:file "file-management-enhanced-tests")
               (:file "payment-stars-tests")
               (:file "payment-enhanced-tests")
               (:file "account-security-enhanced-tests")
               (:file "drafts-scheduled-tests")
               (:file "account-security-tests")
               (:file "payment-business-tests")
               (:file "v0.22.0-tests")
               (:file "bot-api-8-tests")
               (:file "bot-api-8-extensions-tests")
               (:file "bot-api-9-tests")
               (:file "bot-api-9-mini-app-tests")
               (:file "bot-api-9-7-tests")
               (:file "bot-api-9-mini-app-enhanced-tests")
               (:file "bot-api-9-advanced-tests")
               (:file "performance-optimizations-v4-tests")
               (:file "image-processing-tests")
               (:file "translation-tests")
               (:file "story-highlights-tests")
               (:file "channel-reactions-tests")
               (:file "v0.26.0-tests")
               (:file "auto-delete-tests")
               (:file "chat-backup-tests")
               (:file "global-search-tests")
               (:file "media-library-tests")
               (:file "custom-themes-tests")
               (:file "message-enhanced-tests")
               (:file "bot-api-9-5-tests")
               (:file "bot-api-9-8-tests")
               (:file "stories-complete-tests")
               (:file "inline-bots-enhanced-tests")
               (:file "stickers-enhanced-tests")
               (:file "chat-folders-tests")
               (:file "notifications-v0.32-tests")
               (:file "telegram-business-tests")
               (:file "chat-backgrounds-tests")
               (:file "bot-api-9-6-stars-tests")
               (:file "bot-api-9-6-managed-tests")))

;; Documentation system
(asdf:defsystem #:cl-telegram/docs
  :description "Documentation for cl-telegram"
  :depends-on (:cl-telegram)
  :pathname "docs/"
  :components ((:file "MTProto_2_0")
               (:file "API_REFERENCE")))
