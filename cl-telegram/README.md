# cl-telegram

A pure Common Lisp Telegram client implementation using MTProto 2.0 protocol.

## Status

**Beta v0.11.0** - Full features: Encryption, Database, Secret Chats, CLOG GUI, Group Admin, Media Viewer, WebRTC Calls, Stickers, Channels, Inline Bots, Message Threads, Voice Messages, Performance Optimizations.

## Features

Implemented:
- [x] Project structure and ASDF system definition
- [x] AES-256 IGE encryption/decryption (MTProto 2.0 mode)
- [x] SHA-256 hashing
- [x] RSA-2048 encryption and verification
- [x] Diffie-Hellman key exchange with MTProto parameters
- [x] Key derivation functions (KDF) for MTProto
- [x] TL (Type Language) serialization/deserialization
- [x] MTProto protocol type definitions
- [x] MTProto authentication flow
- [x] Message encryption/decryption
- [x] Transport layer protocol
- [x] TCP client (async with cl-async, sync with usocket)
- [x] Connection management with session state
- [x] RPC call handling with retry support
- [x] Event handler system
- [x] **Authentication API** - Full auth flow with TDLib compatibility
- [x] **Messages API** - send-message, get-messages, delete-messages, edit-message, forward-messages
- [x] **Chats API** - get-chats, get-chat, create-private-chat, send-chat-action, chat management
- [x] **Users API** - get-me, get-user, search-users, contacts management, block/unblock
- [x] **CLI Client** - Interactive command-line interface with authentication
- [x] **Connection Pool** - Thread-safe connection reuse with health monitoring
- [x] **Auto Reconnect** - Exponential backoff reconnection manager
- [x] **Message Queue** - Priority-based message scheduling
- [x] **Multi-DC Support** - Datacenter selection, latency measurement, DC migration
- [x] **CDN Integration** - Configurable CDN for file downloads
- [x] **File Transfer** - Send/download photos, documents, audio, video with progress callbacks
- [x] **Proxy Support** - SOCKS5 and HTTP CONNECT proxy with authentication
- [x] **Update Handler** - Real-time updates for messages, chats, users, typing indicators
- [x] **Bot API** - Complete bot support with command handlers, inline queries, callbacks
- [x] **Secret Chats** - End-to-end encryption with DH key exchange, AES-256 IGE, self-destruct
- [x] **Local Database** - SQLite cache for users, chats, messages with search and pagination
- [x] **CLOG GUI** - Web-based graphical interface with dark theme, chat list, message view
- [x] **Group/Channel Admin** - Administrator management, member ban/unban, invite links
- [x] **Media Viewer** - Full-screen viewer for photos, videos, documents, audio files
- [x] **VoIP/Video Calls** - Individual and group call infrastructure, WebRTC signaling
- [x] **WebRTC FFI** - CFFI bindings to libwebrtc for P2P audio/video streaming
- [x] **Group Call UI** - Multi-participant video chat interface
- [x] **Media Gallery** - Grid view for chat media with thumbnail previews
- [x] **Stickers & Emoji** - Sticker pack management, emoji packs, favorite stickers, sticker picker UI
- [x] **Channel Broadcast** - Channel creation, admin management, broadcast messages, scheduling
- [x] **Message Reactions** - Emoji reactions, reaction panel, recent reactors tracking
- [x] **Inline Bots** - Inline query handlers, custom keyboards, callback buttons, web app integration
- [x] **Message Threads** - Reply to messages, thread management, quote text, thread UI
- [x] **Voice Messages** - Voice message recording/playback, waveform visualization, speech-to-text transcription
- [x] **Voice Chats** - Group voice chats with participant management and mute controls
- [x] **Performance Optimizations** - Memory-efficient batch ops, thread-safe caching, reduced GC pressure

In Progress:
- [ ] Integration tests with real Telegram servers

Planned:
- [ ] Stories support
- [ ] Premium features
- [ ] Bots inline mode improvements

## Requirements

- SBCL 2.0+ (recommended) or other modern Common Lisp implementation
- Quicklisp package manager
- libuv (for cl-async)

## Installation

### 1. Install Quicklisp (if not already installed)

```lisp
$ sbcl --load quicklisp-install.lisp
```

### 2. Load dependencies

```lisp
(ql:quickload :cl-async)
(ql:quickload :usocket)
(ql:quickload :dexador)
(ql:quickload :ironclad)
(ql:quickload :bordeaux-threads)
(ql:quickload :cl-babel)
(ql:quickload :cl-base64)
(ql:quickload :trivial-gray-streams)
```

### 3. Load cl-telegram

```lisp
(asdf:load-system :cl-telegram)
```

## Usage

### CLI Client

```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/ui)

;; Run interactive CLI client
(run-cli-client)

;; Run with demo authentication
(run-demo-cli)
```

### Running Tests

```lisp
;; Load test system
(asdf:load-system :cl-telegram/tests)

;; Run all tests
(cl-telegram/tests:run-all-tests)

;; Run specific test suite
(fiveam:run! 'cl-telegram/tests::crypto-tests)
(fiveam:run! 'cl-telegram/tests::integration-tests)

;; Run live tests (requires real credentials)
;; First set environment variables:
;;   export TELEGRAM_API_ID=your_api_id
;;   export TELEGRAM_API_HASH=your_api_hash
;;   export TELEGRAM_TEST_PHONE=+1234567890
(cl-telegram/tests:run-live-tests)
```

Or use the shell script:

```bash
# Copy and configure .env
cp .env.example .env
# Edit .env with your credentials

# Run all live tests
./run-live-tests.sh

# Run specific test
./run-live-tests.sh test-connect-to-dc1
```

### Authentication API

```lisp
(use-package :cl-telegram/api)

;; Set phone number
(set-authentication-phone-number "+1234567890")

;; Request verification code
(request-authentication-code)

;; Verify code (use "12345" for demo)
(check-authentication-code "12345")

;; Check authorization status
(authorized-p)  ; => T if authorized

;; Get current user
(get-me)
```

### Messages API

```lisp
;; Send a message
(send-message 123 "Hello, World!")

;; Get message history
(get-messages 123 :limit 50)

;; Edit a message
(edit-message 123 456 "Edited text")

;; Delete messages
(delete-messages 123 '(1 2 3))

;; Forward messages
(forward-messages 123 456 '(7 8 9))

;; Search messages
(search-messages 123 "search query" :limit 20)
```

### Chats API

```lisp
;; Get chat list
(get-chats :limit 50)

;; Get single chat
(get-chat 123)

;; Create private chat
(create-private-chat 456)

;; Send chat action (typing indicator)
(send-chat-action 123 :typing)

;; Get chat members
(get-chat-members 123 :limit 100)

;; Search chats
(search-chats "alice" :limit 10)
```

### Users API

```lisp
;; Get current user info
(get-me)

;; Get user by ID
(get-user 123)

;; Search users
(search-users "john" :limit 20)

;; Get contacts
(get-contacts)

;; Block/unblock user
(block-user 123)
(unblock-user 123)

;; Get user profile photos
(get-user-profile-photos 123)
```

### Proxy Configuration

```lisp
;; Configure SOCKS5 proxy
(configure-proxy :type :socks5
                 :host "127.0.0.1"
                 :port 1080)

;; Configure HTTP proxy with authentication
(configure-proxy :type :http
                 :host "proxy.example.com"
                 :port 8080
                 :username "user"
                 :password "pass")

;; Auto-detect system proxy from environment
(use-system-proxy)

;; Check proxy status
(get-proxy-info)
;; => (:ENABLED T :TYPE :SOCKS5 :HOST "127.0.0.1" :PORT 1080 ...)

;; Disable proxy
(reset-proxy-config)
```

### Connection Pool

```lisp
;; Get connection from pool (reuses existing)
(let ((conn (get-connection-from-pool "149.154.167.51" 443)))
  ;; Use connection
  (rpc-call conn request)
  ;; Return to pool
  (return-connection-to-pool conn))

;; Pool statistics
(pool-stats)
;; => (:TOTAL 5 :HEALTHY 3 :UNHEALTHY 1 :RECONNECTING 1)

;; Cleanup old connections
(cleanup-pool :max-age 3600 :idle-timeout 300)
```

### Multi-DC Support

```lisp
;; Create DC manager
(let ((dc-mgr (make-dc-manager :test-mode nil)))
  ;; Measure latencies to all DCs
  (measure-all-dc-latencies dc-mgr)
  
  ;; Get best DC connection (auto-selects lowest latency)
  (let ((conn (get-current-connection dc-mgr)))
    ;; Use connection...
    ))

;; Switch to specific DC
(switch-dc dc-mgr 2)  ; Switch to DC 2 (Amsterdam)

;; Migrate session to new DC
(migrate-to-dc dc-mgr 3)  ; Migrate to DC 3 (Singapore)

;; Suggest DC from phone number
(dc-id-from-phone "+31612345678")  ; => 2 (Europe)
(dc-id-from-phone "+12125551234")  ; => 5 (USA)
```

### TDLib Compatibility

```lisp
;; TDLib-compatible function names
(|setTdlibParameters| :parameters '())
(|setAuthenticationPhoneNumber| "+1234567890")
(|checkAuthenticationCode| "12345")
(|sendMessage| 123 "Hello")
(|getChats|)
(|getUser| 123)
```

## Architecture

```
┌─────────────────────────────────────────┐
│          Application Layer              │
│       (CLI Client / CLOG UI)            │
├─────────────────────────────────────────┤
│            API Layer                    │
│    (Auth, Messages, Chats, Users)       │
├─────────────────────────────────────────┤
│         MTProto Protocol                │
│    (Auth, Encrypt, Decrypt, Transport)  │
├─────────────────────────────────────────┤
│          Network Layer                  │
│       (TCP Client, RPC, Conn)           │
├─────────────────────────────────────────┤
│        Crypto Primitives                │
│   (AES-IGE, SHA256, RSA, DH, KDF)       │
└─────────────────────────────────────────┘
```

## Project Structure

```
cl-telegram/
├── cl-telegram.asd          ; ASDF system definition
├── README.md
├── src/
│   ├── package.lisp         ; Main package exports
│   ├── crypto/
│   │   ├── crypto-package.lisp
│   │   ├── aes-ige.lisp     ; AES-256 IGE mode
│   │   ├── sha256.lisp      ; SHA-256 hash
│   │   ├── rsa.lisp         ; RSA encryption
│   │   ├── dh.lisp          ; Diffie-Hellman
│   │   └── kdf.lisp         ; Key derivation
│   ├── tl/
│   │   ├── tl-package.lisp
│   │   ├── types.lisp       ; TL type definitions
│   │   ├── serializer.lisp  ; TL serialization
│   │   └── deserializer.lisp; TL deserialization
│   ├── mtproto/
│   │   ├── auth.lisp        ; Authentication flow
│   │   ├── encrypt.lisp     ; Message encryption
│   │   ├── decrypt.lisp     ; Message decryption
│   │   └── transport.lisp   ; Transport protocol
│   ├── network/
│   │   ├── tcp-client.lisp  ; TCP client
│   │   ├── connection.lisp  ; Connection management
│   │   ├── rpc.lisp         ; RPC calls & message queue
│   │   ├── proxy.lisp       ; SOCKS5/HTTP proxy support
│   │   └── cdn.lisp         ; CDN & datacenter management
│   ├── api/
│   │   ├── auth-api.lisp    ; Authentication API
│   │   ├── messages-api.lisp; Message API
│   │   ├── chats-api.lisp   ; Chat API
│   │   └── users-api.lisp   ; Users API
│   └── ui/
│       └── cli-client.lisp  ; CLI interface
└── tests/
    ├── crypto-tests.lisp
    ├── tl-tests.lisp
    ├── mtproto-tests.lisp
    ├── proxy-tests.lisp
    └── integration-tests.lisp
```

## Protocol References

- [MTProto 2.0 Specification](https://core.telegram.org/mtproto)
- [Detailed Protocol Description](https://core.telegram.org/mtproto/description)
- [TDLib API Documentation](https://core.telegram.org/tdlib/docs/)
- [TL Schema Files](https://github.com/tdlib/td/blob/master/td/generate/scheme/td_api.tl)

## License

Boost Software License 1.0

## Acknowledgments

- Telegram's MTProto 2.0 protocol documentation
- TDLib team for the reference implementation
- Common Lisp community for crypto and networking libraries

## Contributing

This is a learning/experimental project. Contributions welcome!

## Disclaimer

This is an unofficial Telegram client implementation. Use at your own risk.
For production use, consider official Telegram clients or TDLib.
