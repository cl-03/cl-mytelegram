# Release Notes - cl-telegram v0.22.0

**Release Date**: 2026-04-20  
**Version**: 0.22.0  
**Focus**: Notification System, Contact Management, and Utility Functions

---

## Overview

v0.22.0 introduces comprehensive notification management, enhanced contact handling, and essential utility functions for building production-ready Telegram applications. This release adds notification settings, per-chat notification control, vCard import/export, contact synchronization, blocked user management, rate limiting, configuration management, and logging utilities.

**Total New Functions**: 80+  
**Test Coverage**: 50+ test cases  
**New Files**: 3 API modules, 1 test module

---

## New Features

### 1. Notification System (`notifications.lisp`)

Complete notification management with settings, per-chat control, and desktop notifications.

#### Classes

- **`notification-settings`** - Global notification settings
  - Properties: `show-preview`, `show-sender`, `show-message-count`, `sound-enabled`, `vibration-enabled`, `popup-enabled`, `light-enabled`, `sound-path`, `priority`

- **`chat-notification-settings`** - Per-chat notification settings
  - Properties: `chat-id`, `use-default`, `settings`, `mute-until`

- **`notification`** - Notification object
  - Properties: `id`, `type`, `chat-id`, `message-id`, `title`, `message`, `timestamp`, `is-read`, `data`

- **`notification-center`** - Notification center
  - Properties: `notifications`, `unread-count`, `max-size`, `auto-clear-read`

#### Functions

**Global Settings**:
```lisp
(initialize-notification-settings)
  => notification-settings object

(get-notification-settings)
  => Current global notification settings

(update-notification-settings &key show-preview show-sender sound-enabled 
                                               vibration-enabled popup-enabled
                                               light-enabled sound-path priority)
  => Updated notification-settings object

(set-custom-notification-sound sound-path)
  => T on success (sound file must exist)
```

**Per-Chat Settings**:
```lisp
(get-chat-notification-settings chat-id)
  => chat-notification-settings object

(set-chat-notification-settings chat-id settings &key mute-duration)
  => T on success
  mute-duration: seconds (NIL = forever)

(mute-chat chat-id &key duration)
  => T on success
  duration: seconds (NIL = permanent)

(unmute-chat chat-id)
  => T on success

(chat-muted-p chat-id)
  => T if muted, NIL otherwise
```

**Notification Center**:
```lisp
(initialize-notification-center)
  => notification-center object

(add-notification &key type chat-id message-id title message data)
  => notification object
  type: :message, :mention, :reaction, :system

(get-notifications &key limit unread-only type)
  => List of notification objects

(mark-notification-read notification-id)
  => T on success

(mark-all-notifications-read)
  => Number of notifications marked read

(clear-notifications &key read-only type)
  => Number of cleared notifications
```

**Desktop Notifications**:
```lisp
(show-desktop-notification notification)
  => T on success (auto-detects Linux/macOS/Windows)
```

**Hooks**:
```lisp
(register-notification-hook hook-function)
  => T on success
  hook-function: takes notification object as argument

(unregister-notification-hook hook-function)
  => T on success
```

**Server Sync**:
```lisp
(get-server-notification-settings &key account-id)
  => notification-settings object

(set-server-notification-settings settings &key account-id)
  => T on success

(export-notification-settings)
  => JSON string

(import-notification-settings json-string)
  => T on success
```

#### Notification Priorities

- `:low` - Low priority, minimal interruption
- `:default` - Standard notification behavior
- `:high` - Critical notifications, maximum visibility

---

### 2. Contact Management Enhanced (`contacts-enhanced.lisp`)

vCard support, contact synchronization, suggestions, and blocked user management.

#### Classes

- **`contact-vcard`** - vCard contact representation
  - Properties: `version`, `formatted-name`, `first-name`, `last-name`, `phone-numbers`, `emails`, `organization`, `title`, `note`, `photo`

- **`contact-suggestion`** - Contact suggestion
  - Properties: `user-id`, `reason`, `mutual-contacts`, `mutual-groups`

- **`contact-import-result`** - Import operation result
  - Properties: `imported`, `updated`, `skipped`, `errors`

- **`blocked-user`** - Blocked user record
  - Properties: `user-id`, `blocked-at`, `reason`

#### Functions

**vCard Export/Import**:
```lisp
(make-vcard-from-user user)
  => contact-vcard object

(export-contact-vcard user-id &key file-path)
  => vCard string on success

(parse-vcard vcard-string)
  => contact-vcard object or NIL

(import-contact-vcard vcard-string &key add-to-contacts)
  => contact-vcard object

(export-all-contacts &key file-path)
  => Number of contacts exported
```

**Contact Management**:
```lisp
(import-contacts contacts-list)
  => contact-import-result object
  contacts-list: list of (phone . name) cons cells

(delete-contacts user-ids)
  => T on success
  user-ids: list of user IDs

(get-contacts-status &key force-refresh)
  => plist (:contact-count n :sync-pending bool :last-sync timestamp)

(sync-contacts &key contacts-list force-upload)
  => contact-import-result object

(get-contact-sync-status)
  => plist (:sync-pending bool :cache-size n :last-sync timestamp)
```

**Contact Suggestions**:
```lisp
(get-contact-suggestions &key limit)
  => List of contact-suggestion objects

(dismiss-contact-suggestion user-id)
  => T on success
```

**Blocked Users**:
```lisp
(get-blocked-users)
  => List of blocked-user objects

(block-user user-id &key reason duration)
  => T on success
  reason: optional block reason
  duration: seconds (NIL = permanent)

(unblock-user user-id)
  => T on success

(user-blocked-p user-id)
  => T if blocked, NIL otherwise
```

**Contact Sharing**:
```lisp
(share-contact user-id chat-id &key message)
  => Message object on success

(request-contact chat-id &key text)
  => Message object on success
```

**Nearby Users**:
```lisp
(get-nearby-users &key latitude longitude distance)
  => List of user objects

(toggle-nearby-users enabled-p)
  => T on success
```

#### vCard Format

Standard RFC 6350 vCard 3.0 format:
```
BEGIN:VCARD
VERSION:3.0
FN:John Doe
N:Doe;John;;;
TEL:+1234567890
EMAIL:john@example.com
ORG:Acme Corp
TITLE:Developer
END:VCARD
```

---

### 3. Utility Functions (`utilities.lisp`)

Essential helper functions for message formatting, date/time, mentions, rate limiting, logging, and configuration.

#### Message Formatting

```lisp
(format-message-text text &key bold italic underline strikethrough 
                          code pre language link url mention)
  => Formatted text string
  
  ;; Examples:
  (format-message-text "Hello" :bold t)           ; "**Hello**"
  (format-message-text "World" :italic t)         ; "_World_"
  (format-message-text "Code" :code t)            ; "`Code`"
  (format-message-text "Block" :pre t)            ; "```Block```"
  (format-message-text "Py" :pre t :language "python")

(parse-message-entities text entities)
  => Formatted text with entities applied

(strip-markdown text)
  => Plain text string

(escape-markdown text)
  => Escaped text string

(truncate-text text max-length &key suffix)
  => Truncated text string
```

#### Date/Time Helpers

```lisp
(format-relative-time timestamp)
  => "just now", "5 minutes ago", "2 hours ago", etc.

(format-datetime timestamp &key format timezone)
  => Formatted datetime string
  format: :iso-8601, :date, :time, :human

(parse-datetime string)
  => Universal time or NIL

(time-to-minutes hours minutes)
  => Minutes since midnight (0-1439)

(minutes-to-time minutes)
  => (hours minutes) list
```

#### Mention & Link Helpers

```lisp
(make-mention user-id &key text)
  => "[text](tg://user?id=123456789)"

(parse-mention text)
  => User ID or NIL

(extract-mentions text)
  => List of user IDs

(make-chat-link chat-id)
  => "https://t.me/c/1234567890/-1234567890"

(parse-chat-link url)
  => Chat ID or plist with :username
```

#### Rate Limiting

```lisp
(make-rate-limiter &key max-requests window-seconds)
  => rate-limiter object

(rate-limit-try limiter)
  => T if allowed, NIL if rate limited

(rate-limit-wait limiter)
  => T when ready (blocks until allowed)

(rate-limit-status limiter)
  => plist (:current-requests n :max-requests n :remaining n :reset-in s)
```

#### Logging

```lisp
(set-log-level level)
  => Previous level
  level: :debug, :info, :warning, :error

(log-message level format-string &rest args)
  => NIL

(enable-debug-logging)
  => Previous level

(disable-debug-logging)
  => Previous level

(with-logging level format-string &body body)
  => Result of body (macro)

(debug-time &body body)
  => Result of body, prints execution time (macro)
```

#### Configuration Management

```lisp
(make-config-manager &key file-path auto-save)
  => config-manager object

(get-config manager key &optional default)
  => Configuration value

(set-config manager key value)
  => T on success (auto-saves if enabled)

(load-config manager file-path)
  => T on success

(save-config manager &optional file-path)
  => T on success

(delete-config manager key)
  => T if key existed and was deleted
```

#### Helper Macros

```lisp
(with-connection (conn) &body body)
  => Result of body, ensures connection is returned to pool

(with-retry (&key max-retries delay on-error) &body body)
  => Result of body or NIL after all retries fail

(define-api-function name args &body body)
  => Function definition with standard error handling (macro)
```

---

## Global State

New global variables:

```lisp
;; Notifications
(defvar *notification-settings* nil)
(defvar *chat-notification-settings* (make-hash-table :test 'equal))
(defvar *notification-center* nil)
(defvar *notification-queue* (make-instance 'message-queue))
(defvar *notification-hooks* nil)

;; Contacts
(defvar *contact-cache* (make-hash-table :test 'equal))
(defvar *contact-sync-pending* nil)
(defvar *blocked-users-cache* nil)
(defvar *contact-suggestions-cache* nil)

;; Utilities
(defparameter *log-level* :info)
(defparameter *log-output* *standard-output*)
(defparameter *log-prefix* "[cl-telegram]")
```

---

## Testing

Comprehensive test suite in `tests/v0.22.0-tests.lisp`:

### Test Coverage

| Category | Test Cases | Coverage |
|----------|------------|----------|
| Notification System | 20 | ✅ |
| Contact Management | 15 | ✅ |
| Utility Functions | 20 | ✅ |
| Integration | 5 | ✅ |
| **Total** | **60+** | **✅** |

### Test Categories

1. **Class Instantiation Tests** - All CLOS classes
2. **Function Tests** - Individual function behavior
3. **Edge Case Tests** - Empty inputs, boundary values
4. **Integration Tests** - Multi-function workflows
5. **Global State Tests** - State initialization and management

---

## Usage Examples

### Notification Setup

```lisp
;; Initialize notification system
(initialize-notification-settings)
(initialize-notification-center)

;; Configure global settings
(update-notification-settings :sound-enabled t
                              :popup-enabled t
                              :priority :high)

;; Mute a noisy chat for 1 hour
(mute-chat -1001234567890 :duration 3600)

;; Add custom notification hook
(register-notification-hook
 (lambda (notif)
   (format t "New notification: ~A~%" (notification-title notif))))

;; Add a notification
(add-notification :type :mention
                  :chat-id -1001234567890
                  :message-id 123
                  :title "New Mention"
                  :message "You were mentioned")

;; Get unread notifications
(let ((unread (get-notifications :unread-only t :limit 10)))
  (dolist (n unread)
    (format t "~A: ~A~%" (notification-title n) (notification-message n))))
```

### Contact Management

```lisp
;; Export a contact to vCard
(let ((vcard (export-contact-vcard user-id :file-path "/tmp/contact.vcf")))
  (when vcard
    (format t "Exported: ~A~%" vcard)))

;; Import contacts from vCard
(with-open-file (in "/tmp/contacts.vcf")
  (let ((content (make-string (file-length in))))
    (read-sequence content in)
    (import-contact-vcard content :add-to-contacts t)))

;; Block a spam user
(block-user 987654321 :reason "Spam messages"))

;; Get blocked users
(dolist (blocked (get-blocked-users))
  (format t "Blocked: ~A (reason: ~A)~%" 
          (blocked-user-user-id blocked)
          (blocked-user-reason blocked)))

;; Sync contacts with server
(let ((result (sync-contacts :force-upload t)))
  (format t "Imported: ~A, Updated: ~A, Skipped: ~A~%"
          (contact-import-result-imported result)
          (contact-import-result-updated result)
          (contact-import-result-skipped result)))
```

### Utility Functions

```lisp
;; Format message with multiple styles
(format-message-text "Important" :bold t :italic t)
; => "***Important***"

;; Create a mention
(make-mention 123456789 :text "John Doe")
; => "[John Doe](tg://user?id=123456789)"

;; Format relative time
(format-relative-time (- (get-universal-time) 3600))
; => "1 hour ago"

;; Rate-limited API calls
(let ((limiter (make-rate-limiter :max-requests 30 :window-seconds 60)))
  (dotimes (i 100)
    (rate-limit-wait limiter)
    (make-api-call ...)))

;; Configuration management
(let ((config (make-config-manager :file-path "config.json")))
  (set-config config "api_id" 12345)
  (set-config config "api_hash" "your_hash")
  (let ((api-id (get-config config "api_id")))
    ...))

;; Logging with levels
(enable-debug-logging)
(log-message :debug "Debug info: ~A" some-data)
(log-message :error "Error occurred: ~A" error)
```

---

## API Compatibility

All functions in v0.22.0 are compatible with:
- Telegram Bot API 7.0+
- Telegram TDLib API
- Backward compatible with v0.21.0

---

## Migration Notes

### No Breaking Changes

v0.22.0 is fully backward compatible with v0.21.0. All existing code continues to work without modification.

### New Dependencies

No new external dependencies required. Utilities use existing libraries:
- `cl-ppcre` for regex operations (already included)
- `jonathan` for JSON (already included)

### Desktop Notification Support

Desktop notifications auto-detect platform:
- **Linux**: Uses `notify-send`
- **macOS**: Uses `osascript display notification`
- **Windows**: Uses PowerShell `MessageBox`

Ensure system notifications are enabled for full functionality.

---

## Performance Considerations

### Notification Center

- Notifications are stored in memory with configurable max size (default: 100)
- Auto-trimming prevents memory growth
- Hooks are called synchronously - keep hook functions fast

### Contact Cache

- Contacts are cached in a hash table for fast lookup
- Cache is cleared when contacts are deleted
- Sync operations update cache automatically

### Rate Limiting

- Rate limiters track requests in memory
- Old requests are automatically pruned
- Use `rate-limit-wait` for blocking behavior or `rate-limit-try` for non-blocking

### Logging

- Logging is synchronous and writes to `*log-output*`
- Debug level is more verbose - use `:info` for production
- Consider async logging for high-throughput applications

---

## Known Limitations

1. **Desktop Notifications**: Requires system notification daemon
2. **vCard Export**: Photo export not yet supported
3. **Nearby Users**: Requires precise location coordinates
4. **Contact Suggestions**: Requires server-side support
5. **Configuration**: JSON format only (no TOML/YAML yet)
6. **Rate Limiting**: In-memory only (no distributed rate limiting)

---

## Security Notes

- **Blocked Users**: Block list is cached locally - sync with server on startup
- **Contact Import**: Validate phone numbers before importing
- **Configuration**: Do not store sensitive data in config files without encryption
- **Notifications**: Hook functions run in the caller's thread - handle errors appropriately
- **vCard Export**: Be cautious with contact privacy - export only necessary information

---

## Next Steps (v0.23.0)

Planned features for v0.23.0:
- Bot API 8.0 support
- Channel reactions and emoji status
- Advanced media editing
- Story highlights management
- Translation features

---

## Contributors

Developed as part of the cl-telegram project - a pure Common Lisp Telegram client implementation using MTProto 2.0.

For issues and contributions: https://github.com/cl-mytelegram/cl-telegram
