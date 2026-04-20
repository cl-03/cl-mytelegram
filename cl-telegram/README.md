# cl-telegram

A pure Common Lisp Telegram client implementation using MTProto 2.0 protocol.

## Status

**Release v0.33.0** - Telegram Business API, Chat Backgrounds, Bot API 9.8 Support.

**Next: v0.34.0** - Bot API 9.9+ tracking (Planned)

---

## What's New in v0.33.0

### Telegram Business API

Complete business account management system:

- **Business Accounts** - Create, configure, and manage business profiles
- **Business Greeting** - Automated welcome messages for customers
- **Auto-Reply** - Keyword-based automatic responses with delay control
- **Message Labels** - Tag and organize messages (VIP, Important, etc.)
- **Business Chats** - Manage customer conversations with status tracking
- **Statistics** - Business performance analytics and insights

### Chat Backgrounds Enhanced

Customizable chat backgrounds:

- **Gradient Backgrounds** - Multi-color gradients with angle control
- **Solid Backgrounds** - Single color backgrounds
- **Pattern Backgrounds** - Custom patterns (stripes, dots, etc.)
- **Per-Chat Settings** - Individual background per chat
- **Custom Settings** - Opacity, blur, and other effects
- **Preview & Stats** - Background preview and usage statistics

### Bot API 9.8 Support

Latest Bot API features:

- **Managed Bots** - Create and manage bots programmatically
- **Business Connections** - Link bots to business accounts
- **Enhanced Polls 2.0** - Full poll support with descriptions, timing, quiz mode
- **DateTime Entities** - Parse and format datetime in messages
- **Member Tags Enhanced** - Advanced tagging with color customization

### Code Statistics v0.33.0

- **New Source Files**: 3 (~1,550 lines)
- **New Test Files**: 3 (~560 lines)
- **New API Functions**: 79+
- **Total Coverage**: ~95%+ Bot API coverage

---

## What's New in v0.32.0

### Message Streaming & Enhanced Messaging

Complete streaming message support and advanced messaging features:

- **Streaming Messages** - Character-by-character streaming responses (sendMessageDraft)
- **Stream Sessions** - Thread-safe session management with locks
- **Scheduled Messages** - Create, get, delete scheduled messages
- **Draft Management** - Save, get, delete, clear drafts per chat
- **Multi-Media Albums** - Send photo/video albums in single message
- **Message Copy** - Copy messages between chats with attribution

### Bot API 9.5-9.6 Features

Latest Bot API capabilities:

- **Prepared Keyboard Buttons** - Pre-saved buttons for Mini Apps user/chat selection
- **Member Tags** - Tag management for group members (VIP, Admin, etc.)
- **Enhanced Polls 2.0** - Advanced polls with description, media, quiz mode
- **DateTime Entity** - Formatted date/time display in messages
- **Managed Bots** - Bot managers can create/control child bots

### Chat Folders Enhanced

Better chat organization:

- **Pinned Chats** - Pin chats to top with custom ordering
- **Unread Marks** - Track and manage unread counts
- **Mark as Read** - Bulk mark chats as read
- **Folder Statistics** - View folder stats (chats, pinned, unread)

### Notifications v2.0

Advanced notification management:

- **Silent Mode** - Do Not Disturb with duration control
- **Global Settings** - System-wide notification preferences
- **Peer Settings** - Per-chat notification customization
- **Mute/Unmute** - Temporarily or permanently mute chats
- **Statistics** - Notification usage analytics

### Code Statistics v0.32.0

- **New Source Files**: 6 (~1,600 lines)
- **New Test Files**: 4 (~400 lines)
- **New API Functions**: 100+
- **Total Coverage**: ~93% Bot API coverage

---

## What's New in v0.31.0

### Chat Folders Management

Complete chat folder organization:

- **Create Folders** - Custom folders with included/excluded chats
- **Filter Management** - Configure chat filters (unread, muted, pinned, etc.)
- **Folder Ordering** - Custom sort order for chats within folders
- **Privacy Settings** - Control folder visibility

### Notifications System

Advanced notification controls:

- **Notification Settings** - Get, update, reset notification preferences
- **Scope-Based** - Separate settings for private, groups, channels
- **Preview Control** - Show/hide message preview
- **Sound Settings** - Enable/disable notification sounds
- **Priority Levels** - High, normal, low priority notifications

---

## What's New in v0.30.0

### Bot API 9.7 - Device Access via Mini Apps

Complete device integration through CLOG:

- **Location API** - Request and track device geolocation
- **File Picker** - Browser-based file selection and upload
- **Notification API** - Browser push notifications
- **Camera/Microphone** - Media device access (v0.29.0)
- **Theme Sync** - Telegram WebApp theme integration

---

## What's New in v0.29.0

### Mini App CLOG Integration (Bot API 9.6)

Complete working implementation of Mini App device access using CLOG Web UI:

#### Device Access
- **Camera Access** - Request and use device camera via browser getUserMedia API
- **Microphone Access** - Request and use device microphone
- **Photo Capture** - Capture photos with configurable quality (low/medium/high)
- **Video Capture** - Record videos with MediaRecorder API
- **Media Streams** - Get and release media streams with proper cleanup
- **Permission Management** - Query and track device permissions
- **Feature Detection** - Check device support for camera, microphone, location, contacts

#### Theme Integration
- **Client Sync** - Automatically sync with Telegram WebApp theme
- **Apply Theme** - Apply theme parameters to CLOG window
- **Theme Events** - Handle theme change events
- **Custom Themes** - Override with custom theme parameters

#### Mini App UI
- **Buttons** - Create styled buttons with click handlers
- **Alerts** - Show alert dialogs to users
- **Stats** - Monitor connection and resource usage

### Code Example

```lisp
;; Initialize Mini App server
(cl-telegram/api:initialize-mini-app 8080)

;; Request camera access
(when (cl-telegram/api:request-camera-access)
  ;; Capture a photo
  (let ((photo (cl-telegram/api:capture-photo :quality :high)))
    (when photo
      (format t "Captured photo: ~D bytes~%" (length photo)))))

;; Sync theme
(let ((theme (cl-telegram/api:sync-with-client-theme)))
  (format t "Dark mode: ~A~%" (cl-telegram/api:mini-app-is-dark theme)))

;; Cleanup
(cl-telegram/api:shutdown-mini-app)
```

---

## What's New in v0.28.0

### Auto-Delete Messages

Telegram-style self-destructing messages:

- **Per-Message Timers** - Set timers from 1 second to 1 week
- **Per-Chat Default Timers** - Auto-delete for all messages in a chat
- **Silent Deletion** - Delete without notification
- **Background Monitor** - Automatic cleanup thread
- **Integration** - Send messages with auto-delete built-in

### Chat Backup & Export

Complete chat history management:

- **Export** - JSON/HTML formats with media support
- **Import** - Restore from backup files
- **Incremental Backup** - Only backup changes since last backup
- **Encryption** - Password-protected backups
- **Compression** - Save disk space with zlib compression

### Global Search

Cross-chat message search:

- **Global Search** - Search across all chats simultaneously
- **Advanced Filters** - By sender, date range, media type, chat
- **Search Suggestions** - Smart autocomplete
- **Highlighting** - See match context in results

### Media Library

Unified media and file management:

- **Browse All Media** - Photos, videos, documents, audio
- **Search Files** - Find files by name
- **Batch Operations** - Download/delete multiple files
- **Statistics** - Storage usage breakdown

### Custom Themes

Deep UI customization:

- **Theme Editor** - Create and edit custom themes
- **Per-Chat Backgrounds** - Unique background per chat
- **Font Sizes** - Adjustable text sizes
- **Custom Icons** - Replace app icon
- **Built-in Themes** - 6 pre-designed themes

---

## What's New in v0.26.0

### Group Video Calls (10+ Participants)

Complete multi-participant video calling system:

- **Multi-Participant Video** - Support for 10+ simultaneous video streams
- **Screen Sharing** - Full screen or window capture with quality presets
- **Video Quality Control** - Adaptive quality (LD/SD/HD/FHD) based on bandwidth
- **Video Layouts** - Grid, speaker, and spotlight layouts with pinning
- **Call Recording** - Record calls with automatic storage management
- **AI Noise Reduction** - Configurable noise suppression levels

### Video Messages

Telegram-style circular video messages:

- **Recording** - Start/stop/pause/resume with progress tracking
- **Processing** - Auto crop to circle, compress, generate thumbnails
- **Send/Receive** - Full sending and receiving support
- **Playback** - Integrated video message playback

### Smart Media Albums

Intelligent media organization:

- **Album Management** - Create, edit, delete, reorder albums
- **Auto-Create** - Automatically group media by date or events
- **Tag System** - Add tags, search by tags, popular tags
- **Search & Filter** - Multi-criteria search with type/date/tag filters
- **Export** - Export albums or all media to local directory

---

## What's New in v0.25.0

### Message Translation (60+ Languages)

Complete message translation system:

- **60+ Languages** - Chinese, Japanese, Russian, German, French, Spanish, and more
- **Auto-Translation** - Real-time incoming message translation
- **Per-Chat Language** - Set different target languages per chat
- **Translation Cache** - LRU cache for performance (1000 entries)
- **API Support** - DeepL, Google Translate, LibreTranslate
- **Format Preservation** - Preserves message entities and formatting

### Story Highlights Management

Complete story highlights system:

- **Create Highlights** - With custom covers and descriptions
- **Edit & Reorder** - Full CRUD operations
- **Privacy Controls** - Public, Contacts, Close Friends, Custom
- **Story Management** - Add/remove stories from highlights
- **Search & Export** - Find and backup highlights

### Channel Reactions & Emoji Status

Advanced engagement features:

- **Message Reactions** - Emoji and custom emoji reactions
- **Big Reactions** - Animated reactions for Premium users
- **Reaction Stats** - Detailed breakdown and analytics
- **Emoji Status** - Set custom emoji status with duration
- **Premium Statuses** - Exclusive emoji for Premium users

### Advanced Media Editing

Professional-grade editing:

- **AI Enhancement** - Auto-enhance, denoise, sharpen, upscale
- **Color Adjustments** - Brightness, contrast, saturation, tone mapping
- **Pro Filters** - Cinematic, vintage, teal-orange, vignette
- **Batch Processing** - Process multiple images
- **Watermarking** - Text and logo overlays
- **Format Conversion** - PNG, JPEG, WebP, BMP
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

- **Total Files**: 150+ (80+ source, 40+ tests, 30+ docs)
- **Total Lines**: ~55,000+ lines of Common Lisp code
- **Test Coverage**: 880+ tests (~93% coverage)
- **API Functions**: 800+ exported functions
- **Bot API Version**: 9.7+ (April 2026)
- **Bot API Coverage**: ~93%

## Recent Activity (v0.24.0)

### New Modules

**Web UI Module** (2,500+ lines)
- Standalone web server with Hunchentoot
- WebSocket real-time updates
- Media gallery with lightbox
- Settings panel
- PWA with Service Worker

**Image Processing Module** (1,900+ lines)
- Full-featured image processing using Opticl library
- 33 Instagram-style filters
- Basic operations: crop, resize, rotate, flip
- Advanced filters: blur, sharpen, vignette, pixelate
- Drawing primitives: rectangles, circles
- Overlays: text, emoji, watermarks
- Emoji rendering and font management

**Mobile Platform Support** (1,100+ lines)
- iOS integration with APNs push notifications
- Android integration with FCM push notifications
- Background service support
- Platform-specific URL handling

### New Documentation

- `docs/RELEASE_NOTES_v0.24.0.md` - v0.24.0 complete release notes
- `docs/IMAGE_PROCESSING_API.md` - Complete image processing API reference
- `docs/PERFORMANCE_OPTIMIZATIONS_V3.md` - Performance optimization guide
- `docs/EXAMPLES_BOT_API_8.md` - Bot API 8.0 usage examples
- `docs/BOT_API_UPDATES_8.1-8.3.md` - Bot API 8.1-8.3 updates

---

## Code Statistics

| Category | Files | Lines |
|----------|-------|-------|
| Crypto Layer | 6 | ~800 |
| TL Layer | 5 | ~600 |
| MTProto Layer | 6 | ~500 |
| Network Layer | 7 | ~700 |
| API Layer | 60+ | ~28,000 |
| UI Layer | 7 | ~3,500 |
| Image Processing | 7 | ~1,900 |
| Mobile Layer | 4 | ~1,100 |
| Tests | 40+ | ~13,000 |
| **Total** | **150+** | **~50,100** |

## Test Coverage

**Total Tests**: 880+
**Coverage**: ~93%

**Test Suites**:
- Crypto Layer Tests (25 tests)
- TL Serialization Tests (20 tests)
- MTProto Protocol Tests (30 tests)
- Network Layer Tests (35 tests)
- API Layer Tests (80 tests)
- Bot API Tests (60 tests)
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
- **Bot API 9.5 Tests (15 tests)**
- **Message Enhanced Tests (18 tests)**
- **Chat Folders Tests (10 tests)**
- **Notifications Tests (12 tests)**
- Integration Tests (30 tests)

## Documentation

- `docs/MTProto_2_0.md` - MTProto protocol specification
- `docs/API_REFERENCE.md` - Complete API reference
- `docs/BOT_API_COVERAGE_ANALYSIS.md` - Bot API coverage analysis (NEW v0.32.0)
- `docs/V0.32.0_DEVELOPMENT_PLAN.md` - v0.32.0 development plan
- `docs/V0.33.0_DEVELOPMENT_PLAN.md` - v0.33.0 development plan (NEW)
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

### Web UI (NEW in v0.24.0)

```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/ui)

;; Start web server on default port (8080)
(run-web-server)

;; Start on custom port
(run-web-server :port 3000)

;; Enable real-time push notifications
(enable-realtime-push)

;; Open in default browser
(open-web-ui-in-browser)

;; Stop server
(stop-web-server)
```

**Features:**
- Progressive Web App (PWA) - installable on any device
- Real-time message updates via WebSocket
- Media gallery with lightbox viewer
- Settings panel with account, privacy, and appearance options
- Responsive design for mobile, tablet, and desktop

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
