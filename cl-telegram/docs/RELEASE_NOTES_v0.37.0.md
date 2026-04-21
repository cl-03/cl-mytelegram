# Release Notes v0.37.0

**Release Date:** 2026-04-21  
**Version:** 0.37.0  
**Commits:** 3 (5413503, 5808b4b, 0060ca3)

---

## Overview

v0.37.0 实现了三个核心增强功能模块，显著提升了 cl-telegram 在消息调度、文件管理和账号安全方面的能力：

1. **Scheduled Messages & Drafts** - 定时消息和草稿管理
2. **File Management Enhanced** - 文件传输与进度追踪
3. **Account Security v2** - 账号安全与隐私管理

---

## New Features

### 1. Scheduled Messages & Drafts (`scheduled-messages.lisp`)

#### Core Classes
- `scheduled-message` - 定时消息对象
- `message-draft` - 草稿消息对象

#### New Functions

**Scheduled Messages:**
```lisp
(send-scheduled-message chat-id text send-date &key media reply-markup parse-mode message-thread-id)
(get-scheduled-messages chat-id)
(delete-scheduled-message chat-id schedule-id)
(edit-scheduled-message chat-id schedule-id new-text &key media reply-markup)
(get-scheduled-message chat-id schedule-id)
(list-scheduled-messages chat-id)
(count-scheduled-messages chat-id)
(delete-all-scheduled-messages chat-id)
(send-scheduled-messages-now chat-id)
(send-pending-scheduled-messages)
```

**Message Drafts:**
```lisp
(save-message-draft chat-id text &key message-thread-id entities)
(get-message-drafts chat-id)
(get-message-draft chat-id)
(delete-message-draft chat-id)
(delete-all-message-drafts)
(cleanup-expired-drafts)
```

**Utilities:**
```lisp
(clear-scheduled-message-cache)
(clear-draft-cache)
(initialize-scheduled-messages)
(shutdown-scheduled-messages)
```

#### Example Usage
```lisp
;; Schedule a message for tomorrow
(send-scheduled-message -1001234567890 "Reminder: Meeting at 3PM"
                        (+ (get-universal-time) 86400)
                        :parse-mode "html")

;; Save a draft
(save-message-draft -1001234567890 "Working on this message...")

;; Send all pending scheduled messages
(send-pending-scheduled-messages)
```

---

### 2. File Management Enhanced (`file-management-v2.lisp`)

#### Core Classes
- `file-transfer` - Base transfer class
- `file-download` - Download transfer with DC info
- `file-upload` - Upload transfer with chunking support

#### New Functions

**Download:**
```lisp
(download-file file-id output-path &key dc-id access-hash part-size use-cdn)
(get-file-download-stream file-id &key start end)
(cancel-file-download transfer-id)
```

**Upload:**
```lisp
(upload-file file-path &key file-name mime-type chat-id)
(upload-file-part file-id part-data part-number &key total-parts)
(upload-big-file-part file-id part-data part-number &key file-name file-type)
(get-file-upload-stream file-name file-size &key mime-type)
(cancel-file-upload transfer-id)
```

**Progress & Monitoring:**
```lisp
(get-file-progress transfer-id)
(get-active-downloads)
(get-active-uploads)
(count-active-transfers)
(clear-completed-transfers)
(detect-mime-type file-path)
```

#### Example Usage
```lisp
;; Download a file with progress tracking
(let ((dl (download-file "AgAD1234" "/tmp/file.jpg" :use-cdn t)))
  (when dl
    (loop for progress = (get-file-progress (file-transfer-id dl))
          until (or (null progress)
                    (eq (getf progress :status) :completed))
          do (sleep 1)
          finally (format t "Download complete: ~A~%" progress))))

;; Upload a large file with chunking
(upload-file "/path/to/large-video.mp4"
             :mime-type "video/mp4"
             :chat-id -1001234567890)
```

---

### 3. Account Security v2 (`account-security-v2.lisp`)

#### Core Classes
- `privacy-setting` - Privacy setting with rules
- `authorization` - Active session info
- `two-factor-auth` - 2FA status

#### New Functions

**Privacy Settings:**
```lisp
(get-privacy-settings &key force-refresh)
(set-privacy-settings key rules &key users)
(get-privacy-setting key &key force-refresh)
(reset-privacy-settings key)
(clear-privacy-settings-cache)
(get-cached-privacy-setting key)
```

**Authorization Management:**
```lisp
(get-authorizations &key force-refresh)
(terminate-authorization hash)
(terminate-all-authorizations &key keep-current)
(clear-authorizations-cache)
```

**Two-Factor Authentication:**
```lisp
(get-two-factor-status)
(enable-two-factor password &key hint email)
(disable-two-factor password)
(change-two-factor-password current-password new-password &key hint)
(get-two-factor-recovery-code password)
(send-two-factor-recovery-email)
```

**Lifecycle:**
```lisp
(initialize-account-security-v2)
(shutdown-account-security-v2)
```

#### Example Usage
```lisp
;; Set privacy: last_seen visible to contacts only
(set-privacy-settings "last_seen" '(:allow-contacts :disallow-users)
                      :users '(123 456))

;; Review active sessions and terminate suspicious ones
(let ((auths (get-authorizations :force-refresh t)))
  (dolist (auth auths)
    (unless (authorization-current auth)
      (format t "Session: ~A on ~A (~A)~%"
              (authorization-app-name auth)
              (authorization-ip auth)
              (authorization-date-active auth))
      ;; Terminate if suspicious
      (terminate-authorization (authorization-hash auth)))))

;; Enable 2FA
(enable-two-factor "SecurePass123"
                   :hint "My favorite color"
                   :email "recovery@example.com")
```

---

## Files Changed

### New Files (6)
- `src/api/scheduled-messages.lisp` (~650 lines)
- `src/api/file-management-v2.lisp` (~550 lines)
- `src/api/account-security-v2.lisp` (~500 lines)
- `tests/scheduled-messages-tests.lisp` (~280 lines)
- `tests/file-management-v2-tests.lisp` (~250 lines)
- `tests/account-security-v2-tests.lisp` (~250 lines)

### Modified Files (6)
- `cl-telegram.asd` - Added 3 new modules and test files
- `src/api/api-package.lisp` - Added 68 new exports
- `README.md` - Updated feature list
- `docs/V0.37.0_DEVELOPMENT_PLAN.md` - Development plan
- `docs/GAP_ANALYSIS.md` - Gap analysis reference
- `docs/API_REFERENCE_v0.18.0.md` - API reference update

---

## Test Coverage

### Scheduled Messages Tests (35+ tests)
- Class creation tests
- Scheduled message CRUD operations
- Draft management operations
- Progress monitoring
- Integration workflows

### File Management Tests (20+ tests)
- Download/upload class creation
- File transfer operations
- MIME type detection
- Progress tracking
- Cancellation workflows

### Account Security Tests (30+ tests)
- Privacy setting management
- Authorization lifecycle
- Two-factor authentication flows
- Cache management
- Integration scenarios

**Total: 85+ test cases**

---

## API Coverage Progress

| API Category | Official API | Implemented | Coverage |
|--------------|--------------|-------------|----------|
| Messages | 45 | 42 | 93% |
| Media & Files | 28 | 26 | 93% |
| Privacy & Security | 18 | 18 | 100% |
| Bot API 9.x | 65 | 58 | 89% |
| Payment/Stars | 22 | 20 | 91% |
| Stories | 25 | 22 | 88% |

**Overall Coverage: 91%**

---

## Breaking Changes

None. All new features are additive.

---

## Dependencies

No new external dependencies added. Uses existing:
- `cl-log` for logging
- `jonathan` for JSON serialization
- `cl-base64` for encoding
- `bordeaux-threads` for concurrency

---

## Known Issues

1. **Stream-based transfers** - `get-file-download-stream` and `get-file-upload-stream` are currently placeholders (return NIL). Full implementation requires transport layer integration.

2. **QR Code Login** - The `*qr-login-state*` variable is defined but QR login flow is not yet implemented.

3. **Progress Callbacks** - File transfer progress is tracked but no callback mechanism for UI updates. Consider adding in v0.38.0.

---

## Migration Guide

No migration required. All features are opt-in:

1. **Scheduled Messages**: Call `initialize-scheduled-messages` on startup
2. **File Management**: Call `initialize-file-management-v2` on startup
3. **Account Security**: Call `initialize-account-security-v2` on startup

---

## Next Steps (v0.38.0)

Based on gap analysis, remaining high-priority features:

1. **Bot API 9.9** - Waiting for official release
2. **Inline Mode Enhancements** - Switch inline button, bot menu button
3. **Stickers Management** - Full sticker set CRUD
4. **Payment Flow Completion** - Shipping and delivery tracking
5. **Stream Transfers** - Complete stream-based file transfers
6. **QR Login Implementation** - Full QR code authentication flow

---

## Contributors

- Primary development: cl-telegram core team
- Code review: Automated security and quality checks

---

## Checksums

```
SHA256 (cl-telegram-v0.37.0.tar.gz): TBD
```

---

*For detailed API documentation, see `docs/API_REFERENCE_v0.18.0.md`*  
*For development planning, see `docs/V0.37.0_DEVELOPMENT_PLAN.md`*
