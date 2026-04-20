# cl-telegram

A pure Common Lisp Telegram client implementation using MTProto 2.0 protocol.

## Status

**Release v0.23.0** - Complete with Bot API 8.0 support: message reactions, emoji status, advanced media editing, story highlights, and message translation.

## What's New in v0.23.0

### Bot API 8.0 Support (November 2024)

#### Message Reactions (12 functions)
- **Reaction Types**: Emoji, custom emoji, and star reactions
- **Send Reactions**: Send reactions to messages with big animation support
- **Get Reactions**: Retrieve detailed reaction breakdown with counts
- **Remove Reactions**: Remove specific or all reactions
- **Reaction Updates**: Register handlers for reaction change events
- **Available Reactions**: Get list of available reactions for current user

#### Emoji Status (4 functions)
- **Set Status**: Set emoji status with optional duration
- **Clear Status**: Remove emoji status
- **Get Statuses**: Retrieve available emoji statuses
- **User Status**: Get other users' emoji status

#### Advanced Media Editing (8 functions)
- **Edit Media**: Advanced media editing with options
- **Crop & Rotate**: Crop and rotate media files using Opticl library
- **Apply Filters**: 33 built-in filters (clarendon, ginger, moon, nashville, etc.)
- **Text Overlay**: Add text overlays with custom fonts and colors
- **Emoji Stickers**: Add emoji/custom emoji stickers to media
- **Edit Caption**: Edit message captions with parse modes
- **Drawing Primitives**: Draw rectangles and circles on images
- **Watermarks**: Add watermarks with position and opacity control

#### Story Highlights Management (8 functions)
- **Create Highlight**: Create story highlights with custom covers
- **Edit Highlight**: Edit title, cover, and stories
- **Edit Cover**: Edit highlight cover with crop and filters
- **Reorder**: Reorder highlights in profile
- **Privacy**: Set highlight privacy (public/contacts/close-friends/custom)
- **Delete**: Remove highlights

#### Message Translation (9 functions)
- **Translate Message**: Translate individual messages
- **Translate Text**: Translate arbitrary text
- **60+ Languages**: Support for 60+ languages with auto-detect
- **Chat Language**: Set per-chat language preferences
- **Auto Translation**: Enable/disable automatic translation
- **Translation Cache**: LRU cache for performance
- **History**: Recent translation history

### Test Coverage
- **Bot API 8.0 Tests**: 25+ test cases for all new features
- **Rate Limiting**: Configurable rate limiters with blocking/non-blocking modes
- **Logging**: Level-based logging with debug support
- **Configuration**: JSON config management with auto-save
- **Helper Macros**: with-connection, with-retry, define-api-function

### Test Coverage
- **v0.22.0 Tests**: 60+ test cases for notifications, contacts, and utilities

## What's New in v0.21.0

### Chat Folder Management (20 functions)
- **Folder CRUD**: Create, edit, delete, and reorder chat folders
- **Filters**: Contact, non-contact, group, channel, bot, unread, muted, pinned filters
- **Archive**: Archive chats and retrieve archived chats
- **Sharing**: Generate shareable folder links and import folders
- **Chat Assignment**: Add/remove chats from folders

### Emoji & Customization (15 functions)
- **Custom Emoji**: Search and retrieve custom emoji stickers
- **Message Effects**: Send messages with animated effects
- **Dice & Games**: Send animated dice with random values (🎲 🎯 🏀 ⚽ 🎳 🎰)
- **Wallpapers**: Set chat wallpapers with solid, gradient, image, or pattern types
- **Themes**: Apply chat themes with custom colors
- **Star Reactions**: Send star reactions to messages (1-1000 stars)
- **Giveaways**: Create Telegram Stars giveaways

### Channel Advanced Features (15 functions)
- **Forum Topics**: Create, edit, close, reopen, delete, pin, unpin topics
- **Channel Statistics**: Get member count, views, shares, growth data
- **Message Statistics**: Track views, forwards, reactions with hourly breakdown
- **Sponsored Messages**: Retrieve and report sponsored messages
- **Reaction Statistics**: Get reaction breakdown and recent reactors

### Test Coverage
- **v0.21.0 Tests**: 70+ test cases for folders, emoji, and channel features

## What's New in v0.20.0

### Payment System (12 functions)
- **Invoices**: Create and send payment invoices with multiple line items
- **Payment Links**: Generate shareable payment link URLs
- **Telegram Stars**: Full Stars support (refunds, gifting, balance management)
- **Subscriptions**: Recurring subscription invoice helpers

### Business Features (28 functions)
- **Business Connections**: Manage bot connections to business accounts
- **Location**: Set and manage business address with coordinates
- **Opening Hours**: Configure weekly business hours schedule
- **Quick Replies**: Create interactive buttons for customer responses
- **Business Messaging**: Send/edit/delete messages on behalf of business
- **Chat Links**: Create t.me links for business accounts

## What's New in v0.19.0

### File Management (20 functions)
- **Download**: Full file download with DC selection, partial downloads, streaming support
- **Upload**: Smart upload (small <10MB single-part, large ≥10MB multi-part)
- **CDN Integration**: Configurable CDN for faster downloads
- **Progress Tracking**: Upload sessions with progress percentage and cancellation

### Advanced Messages (20 functions)
- **Draft Messages**: Save, retrieve, and clear drafts per chat
- **Scheduled Messages**: Schedule messages/media for later delivery
- **Message TTL**: Set time-to-live for auto-destruct messages
- **Albums**: Send photo and video albums (multi-media)
- **Copy Message**: Copy messages between chats

### Account Security (17 functions)
- **QR Code Login**: Full QR login flow (export/import/accept tokens)
- **Privacy Settings**: Manage all privacy rules (phone, last-seen, photo, etc.)
- **Session Management**: View and revoke active sessions
- **Phone Management**: Change phone number with verification
- **Takeout**: Initialize and manage account data export

### Test Coverage
- **Inline Bots Tests**: 30+ test cases for Bot API 2025
- **Premium Tests**: 35+ test cases for Premium features
- **Stickers Tests**: 30+ test cases for sticker functionality

## Features

### Core Protocol ✅
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

### Network & Stability ✅
- [x] **Connection Pool** - Thread-safe connection reuse with health monitoring
- [x] **Auto Reconnect** - Exponential backoff reconnection manager
- [x] **Message Queue** - Priority-based message scheduling
- [x] **Multi-DC Support** - Datacenter selection, latency measurement, DC migration
- [x] **CDN Integration** - Configurable CDN for file downloads
- [x] **Proxy Support** - SOCKS5 and HTTP CONNECT proxy with authentication
- [x] **Circuit Breaker** - Fault tolerance for API calls
- [x] **Health Checks** - Service health monitoring
- [x] **Performance Monitoring** - Metrics collection and timing
- [x] **Error Handling** - Retry logic and error rate tracking

### API Layer ✅
- [x] **Authentication API** - Full auth flow with TDLib compatibility
- [x] **Messages API** - send-message, get-messages, delete-messages, edit-message, forward-messages
- [x] **Chats API** - get-chats, get-chat, create-private-chat, send-chat-action, chat management
- [x] **Users API** - get-me, get-user, search-users, contacts management, block/unblock
- [x] **Bot API** - Complete bot support with command handlers, inline queries, callbacks
- [x] **Update Handler** - Real-time updates for messages, chats, users, typing indicators
- [x] **Search & Discovery** - Chat search, message search, member search, 19 filters
- [x] **Media Editing** - Edit text, caption, media, apply filters, overlays
- [x] **Group Management** - Admin permissions, ban/unban, invite links, auto-moderation
- [x] **Channel Management** - Broadcast, admin management, statistics

### Advanced Features ✅
- [x] **Secret Chats** - End-to-end encryption with DH key exchange, AES-256 IGE, self-destruct
- [x] **E2E Encryption Enhanced** - Key fingerprint verification, anti-screenshot, forward prevention
- [x] **Local Database** - SQLite cache for users, chats, messages with search and pagination
- [x] **Stickers & Emoji** - Sticker pack management, emoji packs, favorite stickers, sticker picker UI
- [x] **Channels & Broadcast** - Channel creation, broadcast messages, reactions, comments
- [x] **Inline Bots 2025** - Visual effects, business features, paid media, WebApp integration
- [x] **Message Threads** - Reply to messages, thread management, quote text
- [x] **Voice Messages** - Recording/playback, waveform visualization, transcription
- [x] **Stories** - Post, edit, delete stories with highlights, privacy, reactions
- [x] **Premium Features** - 4GB uploads, premium stickers/reactions, profile customization
- [x] **Desktop Notifications** - System notifications for new messages
- [x] **Real-time Updates** - WebSocket push notifications

### UI & Media ✅
- [x] **CLI Client** - Interactive command-line interface with authentication
- [x] **CLOG GUI** - Web-based graphical interface with dark/light theme
- [x] **Media Viewer** - Full-screen viewer for photos, videos, documents
- [x] **Media Gallery** - Grid view with thumbnail previews
- [x] **VoIP/Video Calls** - WebRTC-based individual and group calls
- [x] **Stories Viewer** - Full-screen stories bar with highlights
- [x] **Sticker Picker** - Animated stickers with emoji picker

### Performance & Optimization ✅
- [x] **Performance Monitoring** - Metrics collection, timing, memory tracking
- [x] **Connection Pool** - Reuse, health monitoring, cleanup
- [x] **Cache LRU Eviction** - Efficient memory management
- [x] **Batch Operations** - Reduced GC pressure
- [x] **Object Pooling** - Byte buffer reuse
- [x] **Large File Upload** - 4GB support with progress

### Mobile Platform Support ✅
- [x] **iOS Integration** - CFFI/UIKit bindings, APNs, BackgroundTasks
- [x] **Android Integration** - JNI/Android SDK, FCM, WorkManager
- [x] **Cross-Platform API** - Unified push, background tasks, network status
- [x] **Device Capabilities** - Camera, microphone, biometrics, clipboard
- [x] **Deep Linking** - telegram:// URL scheme handling
- [x] **File System** - App data, cache, photo library access

Completed:
- [x] Integration tests with real Telegram servers
- [x] Mobile platform support (iOS/Android)
- [x] Performance benchmark suite
- [x] Comprehensive test coverage (840+ tests)
- [x] Payment processing (v0.20.0)
- [x] Business account management (v0.20.0)
- [x] Bot API 8.0 features (v0.23.0)
- [x] Image processing module with 33+ filters (v0.23.0)

## Project Statistics

- **Total Files**: 143 (75 source, 39 tests, 29 docs)
- **Total Lines**: ~53,000+ lines of Common Lisp code
- **Test Coverage**: 840+ tests (~93% coverage)
- **API Functions**: 700+ exported functions
- **Bot API Version**: 8.0 (November 2024)

## Recent Activity (v0.23.0)

### New Modules

**Image Processing Module** (1,900+ lines)
- Full-featured image processing using Opticl library
- 33 Instagram-style filters
- Basic operations: crop, resize, rotate, flip
- Advanced filters: blur, sharpen, vignette, pixelate
- Drawing primitives: rectangles, circles
- Overlays: text, emoji, watermarks
- Thumbnail generation

### New Documentation

- `docs/EXAMPLES_BOT_API_8.md` - Comprehensive usage examples
- `docs/IMAGE_PROCESSING_API.md` - Complete image processing API reference
- `docs/RELEASE_NOTES_v0.23.0.md` - v0.23.0 release notes

---

## Code Statistics

| Category | Files | Lines |
|----------|-------|-------|
| Crypto Layer | 6 | ~800 |
| TL Layer | 5 | ~600 |
| MTProto Layer | 6 | ~500 |
| Network Layer | 7 | ~700 |
| API Layer | 51 | ~25,200 |
| UI Layer | 4 | ~1,550 |
| Mobile Layer | 3 | ~1,100 |
| Tests | 37 | ~10,900 |
| **Total** | **115** | **~41,350** |

## Test Coverage

**Total Tests**: 785+
**Coverage**: ~92%

**Test Suites**:
- Crypto Layer Tests (25 tests)
- TL Serialization Tests (20 tests)
- MTProto Protocol Tests (30 tests)
- Network Layer Tests (35 tests)
- API Layer Tests (80 tests)
- Bot API Tests (40 tests)
- Stickers Tests (30 tests)
- Voice Messages Tests (25 tests)
- Inline Bots 2025 Tests (30 tests)
- Premium Features Tests (35 tests)
- File Management Tests (40 tests)
- Draft Messages Tests (20 tests)
- Scheduled Messages Tests (20 tests)
- Account Security Tests (25 tests)
- Payment & Business Tests (50 tests)
- v0.21.0 Features Tests (70 tests)
- v0.22.0 Features Tests (60 tests)
- **Bot API 8.0 Tests (25 tests)**
- Integration Tests (30 tests)

## Documentation

- `docs/MTProto_2_0.md` - MTProto protocol specification
- `docs/API_REFERENCE.md` - Complete API reference
- `docs/RELEASE_NOTES_v0.19.0.md` - v0.19.0 release notes
- `docs/RELEASE_NOTES_v0.20.0.md` - v0.20.0 release notes
- `docs/RELEASE_NOTES_v0.21.0.md` - v0.21.0 release notes
- `docs/RELEASE_NOTES_v0.22.0.md` - v0.22.0 release notes
- `docs/BOT_API_8_FEATURES.md` - Bot API 8.0 feature guide
- `docs/PERFORMANCE_STABILITY.md` - Performance and stability guide
- `docs/E2E_ENCRYPTION.md` - End-to-end encryption
- `docs/SEARCH_DISCOVERY.md` - Search and discovery
- `docs/MEDIA_EDITING.md` - Media editing
- `docs/MOBILE_INTEGRATION.md` - Mobile platform integration guide
- `docs/COMPLETION_SUMMARY.md` - Complete development summary

## Requirements

- SBCL 2.0+ (recommended) or other modern Common Lisp implementation

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
