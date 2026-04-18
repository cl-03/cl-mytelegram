# cl-telegram

A pure Common Lisp Telegram client implementation using MTProto 2.0 protocol.

## Status

**Beta** - Core infrastructure complete. API layer implemented with Messages, Chats, and Users APIs. CLI client functional.

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

In Progress:
- [ ] Integration tests with real Telegram servers
- [ ] File/media transfer support
- [ ] Group chat and channel support

Planned:
- [ ] Secret chats (end-to-end encryption)
- [ ] Bot API support
- [ ] GUI client (CLOG-based)

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
│   │   └── rpc.lisp         ; RPC calls
│   ├── api/
│   │   ├── auth-api.lisp    ; Authentication API
│   │   ├── messages-api.lisp; Message API
│   │   └── chats-api.lisp   ; Chat API
│   └── ui/
│       └── cli-client.lisp  ; CLI interface
└── tests/
    ├── crypto-tests.lisp
    ├── tl-tests.lisp
    └── mtproto-tests.lisp
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
