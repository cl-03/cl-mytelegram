# Release Notes - cl-telegram v0.27.0

**Release Date:** 2026-07-31

**Version:** 0.27.0

## Overview

cl-telegram v0.27.0 introduces chat management enhancements and advanced search capabilities. This release focuses on improving user experience with auto-delete messages, chat backup/export, global search, media library, and custom themes.

## 🎉 Major Features

### 1. Auto-Delete Messages

Telegram-style self-destructing messages with configurable timers:

- **Per-Message Timers** (`auto-delete-messages.lisp`)
  - `set-message-timer` - Set auto-delete timer for a message (1s to 1 week)
  - `cancel-message-timer` - Cancel timer before deletion
  - `get-message-timer-remaining` - Get remaining time before deletion
  - Support for silent deletion (no notification)

- **Per-Chat Default Timers**
  - `set-chat-default-timer` - Set default timer for all messages in a chat
  - `get-chat-default-timer` - Get chat's default timer
  - `clear-chat-default-timer` - Clear default timer

- **Background Monitor**
  - `start-auto-delete-monitor` - Start background cleanup thread
  - `stop-auto-delete-monitor` - Stop monitor thread
  - `get-auto-delete-stats` - Get statistics
  - Automatic cleanup at configurable intervals

- **Integration**
  - `send-message-with-auto-delete` - Send message with timer
  - `list-active-timers` - List all active timers
  - `cleanup-expired-timers` - Manual cleanup

**Example:**
```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Set auto-delete timer for a message (5 minutes)
(set-message-timer chat-id message-id 300)

;; Set default timer for a chat (1 hour)
(set-chat-default-timer chat-id 3600)

;; Send message with auto-delete
(send-message-with-auto-delete chat-id "Secret message"
                               :timer-seconds 60
                               :silent t)

;; Start background monitor
(start-auto-delete-monitor :cleanup-interval 30)

;; Get remaining time
(get-message-timer-remaining chat-id message-id)
;; => 45 (seconds remaining)

;; Cancel timer
(cancel-message-timer chat-id message-id)
```

### 2. Chat Backup & Export

Complete chat history export and import functionality:

- **Export** (`chat-backup.lisp`)
  - `export-chat-history` - Export single chat to JSON/HTML
  - `export-all-chats` - Export all chats to directory
  - `create-incremental-backup` - Incremental backup since last
  - Options: include media, date range, compression, encryption

- **Import**
  - `import-chat-history` - Import from backup file
  - `restore-from-backup` - Restore chat from backup
  - Support for merge or replace modes

- **Utilities**
  - `get-backup-info` - Get backup metadata
  - `encrypt-backup` - Encrypt backup with password
  - `decrypt-backup` - Decrypt backup

**Example:**
```lisp
;; Export chat to JSON
(export-chat-history chat-id "~/backups/chat-123.json"
                     :format :json
                     :include-media t
                     :compress t)

;; Export all chats
(export-all-chats "~/backups/all-chats/"
                  :format :html
                  :include-media nil)

;; Import chat history
(import-chat-history "~/backups/chat-123.json" :merge t)

;; Encrypted backup
(export-chat-history chat-id "~/secure/chat.enc"
                     :encrypt t
                     :password "secret")
```

### 3. Global Search

Cross-chat message search:

- **Core Search** (`global-search.lisp`)
  - `global-search-messages` - Search across all chats
  - `search-in-chat` - Search within specific chat
  - Support for multiple filters

- **Filters**
  - `filter-by-sender` - Filter by sender ID
  - `filter-by-date-range` - Filter by date range
  - `filter-by-media-type` - Filter by media type
  - Search by: text, sender, date, media type, chat

- **Features**
  - `get-search-suggestions` - Get search suggestions
  - Highlighted search results
  - Relevance scoring

**Example:**
```lisp
;; Global search
(let ((results (global-search-messages "meeting notes"
                                       :limit 50
                                       :date-from start-date
                                       :date-to end-date)))
  (dolist (result results)
    (format t "~A: ~A~%"
            (result-chat-title result)
            (result-text result))))

;; Search by sender
(global-search-messages "project"
                        :sender-id sender-id
                        :limit 20)

;; Search for media
(global-search-messages ""
                        :media-type :photo
                        :chat-id specific-chat))
```

### 4. Media Library

Unified media and file management:

- **Browse** (`media-library.lisp`)
  - `get-all-media` - Get all media across chats
  - `get-all-photos` - Get all photos
  - `get-all-videos` - Get all videos
  - `get-all-documents` - Get all documents
  - `get-all-audio` - Get all audio files
  - `get-all-files` - Get all files

- **Search & Filter**
  - `search-files` - Search files by name
  - `filter-media-by-chat` - Filter by chat source
  - `sort-media-by-date` - Sort by date
  - `group-media-by-month` - Group by month

- **Batch Operations**
  - `download-media-batch` - Download multiple files
  - `delete-media-batch` - Delete from cache
  - `get-media-statistics` - Get usage stats

**Example:**
```lisp
;; Get all photos
(let ((photos (get-all-photos :limit 100)))
  (dolist (photo photos)
    (format t "~A (~D bytes)~%"
            (item-file-name photo)
            (item-file-size photo))))

;; Search files
(let ((docs (search-files "report" :type :document)))
  (dolist (doc docs)
    (format t "~A~%" (item-file-name doc))))

;; Download batch
(download-media-batch media-ids "~/downloads/")

;; Get statistics
(get-media-statistics)
;; => (:total-photos 1250 :total-videos 89 :total-size 1234567890)
```

### 5. Custom Themes

Deep UI customization:

- **Theme Management** (`custom-themes.lisp`)
  - `create-theme` - Create new theme
  - `apply-theme` - Apply theme to UI
  - `export-theme` - Export theme to file
  - `import-theme` - Import theme from file
  - `delete-theme` - Delete custom theme

- **Color Customization**
  - `set-theme-color` - Set theme color
  - `get-theme-colors` - Get all theme colors

- **Background**
  - `set-chat-background` - Set per-chat background
  - `get-chat-background` - Get chat background
  - `reset-chat-background` - Reset to default

- **Font & Icons**
  - `set-font-size` - Set font size
  - `set-app-icon` - Set custom app icon

**Example:**
```lisp
;; Create custom theme
(create-theme "My Dark Theme" :base :dark)
(set-theme-color "My Dark Theme" :background "#1a1a2e")
(set-theme-color "My Dark Theme" :text "#eee")
(apply-theme "My Dark Theme")

;; Set chat background
(set-chat-background chat-id "~/backgrounds/custom.jpg"
                     :blur t
                     :darken 0.3)

;; Export theme
(export-theme "My Dark Theme" "~/themes/my-dark.theme")
```

## 📦 New Files

### API Layer
```
src/api/
├── auto-delete-messages.lisp    # Auto-delete messages (~350 lines)
├── chat-backup.lisp             # Chat backup/export (~600 lines)
├── global-search.lisp           # Global search (~500 lines)
├── media-library.lisp           # Media library (~550 lines)
└── custom-themes.lisp           # Custom themes (~450 lines)
```

### UI Layer
```
src/ui/
└── theme-editor.lisp            # Theme editor UI (~300 lines)
```

### Tests
```
tests/
├── auto-delete-tests.lisp       # Auto-delete tests (25+ tests)
├── chat-backup-tests.lisp       # Backup tests (20+ tests)
├── global-search-tests.lisp     # Search tests (15+ tests)
├── media-library-tests.lisp     # Media library tests (20+ tests)
└── custom-themes-tests.lisp     # Theme tests (15+ tests)
```

## 🔧 API Changes

### New Exports (api-package.lisp)

```lisp
;; Auto-Delete Messages (v0.27.0)
#:set-message-timer
#:cancel-message-timer
#:get-message-timer-remaining
#:set-chat-default-timer
#:get-chat-default-timer
#:clear-chat-default-timer
#:start-auto-delete-monitor
#:stop-auto-delete-monitor
#:get-auto-delete-stats
#:send-message-with-auto-delete
#:list-active-timers
#:cleanup-expired-timers

;; Chat Backup (v0.27.0)
#:export-chat-history
#:export-all-chats
#:import-chat-history
#:create-incremental-backup
#:get-backup-info

;; Global Search (v0.27.0)
#:global-search-messages
#:search-in-chat
#:get-search-suggestions

;; Media Library (v0.27.0)
#:get-all-media
#:get-all-photos
#:get-all-videos
#:get-all-documents
#:search-files
#:download-media-batch

;; Custom Themes (v0.27.0)
#:create-theme
#:apply-theme
#:set-chat-background
#:export-theme
```

## 🧪 Tests

New test suites:

- `auto-delete-tests.lisp` - 25+ tests for timer management
- `chat-backup-tests.lisp` - 20+ tests for backup/export
- `global-search-tests.lisp` - 15+ tests for search
- `media-library-tests.lisp` - 20+ tests for media management
- `custom-themes-tests.lisp` - 15+ tests for theming

## 📚 Documentation

- `docs/RELEASE_NOTES_v0.27.0.md` (this file)
- `docs/V0.27.0_DEVELOPMENT_PLAN.md` - Development plan
- `docs/EXAMPLES_V0.27.0.md` - Usage examples (coming soon)

## ⚠️ Breaking Changes

None. This release is backwards compatible with v0.26.0.

## 🐛 Bug Fixes

- Fixed package declaration for bordeaux-threads usage
- Corrected parenthesis balance in auto-delete-messages.lisp

## 🔜 Coming Next (v0.28.0)

- Bot WebApp support
- Channel topic management
- Premium features expansion
- Sponsored messages

## 📊 Statistics

- **Total Lines of Code:** ~57,000+
- **New Files:** 9+
- **New API Functions:** 95+
- **Test Coverage:** 95+ new tests
- **Auto-Delete Timer Range:** 1 second to 1 week
- **Backup Formats:** JSON, HTML
- **Built-in Themes:** 6 (default, dark, midnight, ocean, forest, sunset, minimal)

## 📝 License

Boost Software License 1.0

---

**Full changelog available at:** `git log v0.26.0..v0.27.0`
