# Release Notes - v0.19.0

**Release Date**: 2026-04-20  
**Previous Version**: v0.18.0  
**Next Version**: v0.20.0 (planned)

---

## 🎉 Highlights

v0.19.0 focuses on completing core Telegram API functionality with comprehensive file management, advanced message features, and account security enhancements. This release adds 65+ new functions across 3 major modules.

---

## 🚀 New Features

### File Management (20 functions)

**Download**
- `download-file` - Download files with automatic part handling
- `download-file-partial` - Download file portions for streaming
- `download-media` - Download media files
- `get-file-location` - Resolve file location from file ID

**Upload**
- `upload-file` - Smart upload (auto-detects small/large)
- `upload-file-small` - Single-part upload for files < 10MB
- `upload-file-large` - Multi-part upload for large files
- `upload-media` - Upload media with type detection

**Web Files**
- `get-web-file` - Retrieve files from URLs

**Session Management**
- `get-upload-session` - Get upload session info
- `cancel-upload` - Cancel active upload
- `get-upload-progress` - Get upload progress percentage
- `get-active-uploads` - List all active uploads

**CDN Integration**
- `enable-cdn-download` - Enable CDN for downloads
- `disable-cdn-download` - Disable CDN
- `cdn-download-enabled-p` - Check CDN status
- `set-cdn-config` - Configure CDN settings

**Utilities**
- `file-size-string` - Human-readable file size
- `format-upload-speed` - Format upload speed
- `estimate-upload-time` - Estimate upload duration
- `determine-media-type` - Auto-detect media type
- `guess-mime-type` - Guess MIME from extension

---

### Advanced Messages (20 functions)

**Draft Messages**
- `save-draft` - Save draft message for a chat
- `get-draft` - Get draft for specific chat
- `get-drafts` - Get all draft messages
- `get-all-drafts` - Get all drafts with hash sync
- `delete-draft` - Delete a draft
- `clear-all-drafts` - Clear all drafts

**Scheduled Messages**
- `send-scheduled-message` - Schedule message for later
- `send-scheduled-media` - Schedule media message
- `get-scheduled-messages` - Get scheduled messages for chat
- `get-all-scheduled-messages` - Get all scheduled messages
- `delete-scheduled-message` - Delete scheduled message
- `delete-all-scheduled-messages` - Clear all scheduled
- `send-scheduled-messages-now` - Send scheduled immediately

**Message TTL**
- `set-default-message-ttl` - Set default TTL
- `get-default-message-ttl` - Get current TTL
- `set-chat-ttl` - Set chat-specific TTL

**Multimedia Albums**
- `send-multi-media` - Send multiple media as album
- `send-photo-album` - Send photo album
- `send-video-album` - Send video album

**Copy Message**
- `copy-message` - Copy message between chats

---

### Account Security (17 functions)

**QR Code Login**
- `export-login-token` - Generate login token for QR
- `import-login-token` - Import token from QR code
- `accept-login-token` - Accept login token (complete login)
- `generate-qr-code-url` - Generate tg://login URL
- `parse-qr-code-url` - Parse QR URL to token

**Privacy Settings**
- `get-privacy-settings` - Get privacy rules
- `set-privacy-settings` - Set privacy rules
- `reset-privacy-settings` - Reset to defaults

**Session Management**
- `get-authorizations` - List active sessions
- `reset-authorization` - Revoke specific session
- `reset-authorization-all` - Revoke all other sessions

**Phone Management**
- `change-phone-number` - Change account phone
- `send-confirm-phone-code` - Send confirmation code
- `confirm-phone` - Confirm phone change

**Takeout (Data Export)**
- `takeout-init` - Initialize takeout session
- `finish-takeout-session` - Complete takeout

---

## 📁 Files Added

### New Modules

| File | Lines | Description |
|------|-------|-------------|
| `src/api/file-management.lisp` | ~650 | File upload/download management |
| `src/api/drafts-scheduled.lisp` | ~550 | Drafts and scheduled messages |
| `src/api/account-security.lisp` | ~500 | Account security and privacy |

### Modified Files

| File | Changes |
|------|---------|
| `src/api/api-package.lisp` | +102 exports |
| `README.md` | Version update, features |

---

## 📊 Code Statistics

| Metric | v0.18.0 | v0.19.0 | Change |
|--------|---------|---------|--------|
| Total Files | 97 | 100 | +3 |
| Total Lines | ~27,250 | ~28,950 | +1,700 |
| New Functions | - | 65+ | +65 |
| API Exports | 700+ | 800+ | +102 |

---

## 🔧 Technical Details

### File Management

**Download Strategy:**
- Automatic DC selection based on file location
- Part-based downloading for large files
- CDN integration for faster downloads
- 512KB default part size (configurable)

**Upload Strategy:**
- Small files (< 10MB): Single-part upload
- Large files (≥ 10MB): Multi-part upload with progress tracking
- Automatic part size optimization
- Session-based upload management

### Draft Messages

- Local caching for offline access
- Server synchronization on request
- Support for reply-to and entities (formatting)

### Scheduled Messages

- Universal time-based scheduling
- Local cache for pending messages
- Support for immediate send override
- Automatic cleanup on send/delete

### QR Login Flow

```
1. Client: export-login-token() → token
2. Display: tg://login?token=<base64url(token)>
3. User scans QR with Telegram app
4. App: accept-login-token(token)
5. Server: Authorization complete
```

### Privacy Settings

Supported privacy keys:
- `:phone-number` - Who can see phone
- `:last-seen` - Online status visibility
- `:profile-photo` - Profile photo access
- `:forwards` - Forwarded messages
- `:calls` - Who can call
- `:groups-channels` - Who can add to groups
- `:invite-links` - Invite link management

---

## ⚠️ Breaking Changes

**None** - This release is fully backward compatible with v0.18.0.

---

## 🔧 Migration Guide

No migration required. All new functions are additive and do not modify existing APIs.

---

## 🧪 Testing

### Test Coverage Goal

- File Management: 25+ tests
- Draft Messages: 15+ tests
- Scheduled Messages: 20+ tests
- Account Security: 20+ tests
- **Total**: 80+ new tests

### Running Tests

```lisp
;; Load test system
(asdf:load-system :cl-telegram/tests)

;; Run v0.19.0 tests (when available)
(cl-telegram/tests:run-file-tests)
(cl-telegram/tests:run-drafts-tests)
(cl-telegram/tests:run-scheduled-tests)
(cl-telegram/tests:run-security-tests)
```

---

## 🙏 Acknowledgments

- Telegram MTProto API specification
- Common Lisp crypto and networking libraries
- Community contributors and testers

---

## 📝 TODO for v0.20.0

Next phase focuses on Business and Payment features:

1. **Payment System** (7-10 days)
   - Invoice creation and management
   - Payment form handling
   - Telegram Stars integration
   - Refund processing

2. **Business Features** (4-5 days)
   - Business chat links
   - Business hours management
   - Business location settings
   - Quick replies

---

**Full Changelog**: See commit history for detailed changes.
