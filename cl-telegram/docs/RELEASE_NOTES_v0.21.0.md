# Release Notes - cl-telegram v0.21.0

**Release Date**: 2026-04-20  
**Version**: 0.21.0  
**Focus**: User Experience Enhancements

---

## Overview

v0.21.0 introduces comprehensive user experience enhancements focusing on chat organization, visual customization, and advanced channel management. This release adds support for chat folders, custom emoji, message effects, wallpapers, themes, forum topics, channel statistics, and sponsored messages.

**Total New Functions**: 50+  
**Test Coverage**: 70+ test cases  
**New Files**: 3 API modules, 1 test module

---

## New Features

### 1. Chat Folder Management (`chat-folders.lisp`)

Organize chats into custom folders with intelligent filtering and archive support.

#### Classes

- **`chat-folder`** - Chat folder definition
  - Properties: `id`, `title`, `icon`, `chat-list`, `filters`, `is-shared`
  
- **`chat-folder-filter`** - Filter criteria for folders
  - Properties: `type`, `values`, `exclude-muted`, `exclude-archived`, `exclude-read`
  
- **`archive-info`** - Archive metadata
  - Properties: `chat-id`, `archived-at`, `folder-id`

#### Functions

**Folder CRUD**:
```lisp
(make-chat-folder title &key icon chat-list filters is-shared)
  => chat-folder object

(create-chat-folder folder &key account-id)
  => Created folder ID on success

(edit-chat-folder folder &key title icon chat-list filters account-id)
  => T on success

(delete-chat-folder folder-id &key account-id)
  => T on success

(get-chat-folders (&key include-archived account-id))
  => List of chat-folder objects

(reorder-chat-folders folder-ids &key account-id)
  => T on success (folder-ids is ordered list)
```

**Archive Management**:
```lisp
(archive-chat chat-id &key account-id)
  => T on success

(unarchive-chat chat-id &key account-id)
  => T on success

(get-archived-chats (&key offset limit account-id))
  => List of archived chats

(get-archive-info chat-id &key account-id)
  => archive-info object or NIL
```

**Chat Assignment**:
```lisp
(add-chat-to-folder folder-id chat-id &key account-id)
  => T on success

(remove-chat-from-folder folder-id chat-id &key account-id)
  => T on success

(get-folder-chats folder-id &key account-id)
  => List of chats in folder
```

**Sharing**:
```lisp
(share-chat-folder folder-id &key account-id)
  => Share URL string on success

(import-chat-folder url &key account-id)
  => T on success
```

#### Filter Types

Supported filter types for `chat-folder-filter`:
- `:contact` - Filter by contact chats
- `:non-contact` - Filter by non-contact chats
- `:group` - Filter by group chats
- `:channel` - Filter by channel chats
- `:bot` - Filter by bot chats
- `:unread` - Filter by unread chats
- `:muted` - Filter by muted chats
- `:pinned` - Filter by pinned chats
- `:archived` - Filter by archived chats

---

### 2. Emoji and Customization (`emoji-customization.lisp`)

Custom emoji, message effects, wallpapers, and themes for personalized chat experience.

#### Classes

- **`custom-emoji`** - Custom emoji definition
  - Properties: `id`, `emoji`, `file-id`, `file-unique-id`, `needs-premium`, `is-animated`, `is-video`

- **`emoji-category`** - Emoji category grouping
  - Properties: `name`, `emoji-list`, `is-premium`

- **`message-effect`** - Message effect definition
  - Properties: `id`, `effect-type`, `animation`, `emoji`

- **`chat-wallpaper`** - Chat wallpaper definition
  - Properties: `id`, `type`, `document`, `dark-theme-dimensions`, `light-theme-dimensions`

- **`chat-theme`** - Chat theme definition
  - Properties: `name`, `colors`, `wallpaper`, `is-premium`

#### Functions

**Custom Emoji**:
```lisp
(get-custom-emoji-stickers custom-emoji-ids)
  => List of sticker objects

(get-emoji-categories &key include-premium)
  => List of emoji-category objects

(search-custom-emoji query &key limit category)
  => List of custom-emoji objects

(get-premium-emojis &key category)
  => List of premium custom-emoji objects
```

**Message Effects**:
```lisp
(get-available-message-effects &key chat-type)
  => List of message-effect objects

(send-message-with-effect chat-id text &key message-effect-id reply-markup 
                                           disable-notification protect-content)
  => Message object on success

(send-dice chat-id &key emoji message-thread-id disable-notification)
  => Message object on success
  
  Supported emoji: 🎲 🎯 🏀 ⚽ 🎳 🎰
```

**Wallpapers**:
```lisp
(get-wallpapers &key include-premium)
  => List of chat-wallpaper objects

(set-chat-wallpaper chat-id wallpaper &key is-dark-theme account-id)
  => T on success

(upload-wallpaper file-path &key file-name)
  => chat-wallpaper object on success
```

**Themes**:
```lisp
(get-chat-themes &key include-premium)
  => List of chat-theme objects

(set-chat-theme chat-id theme &key account-id)
  => T on success

(get-premium-themes)
  => List of premium chat-theme objects
```

**Star Reactions & Giveaways**:
```lisp
(send-star-reaction chat-id message-id star-count &key is-anonymous)
  => T on success (star-count: 1-1000)

(create-giveaway chat-id prize-description &key winner-count duration 
                                          subscription-months only-new-members countries)
  => Giveaway object on success
```

#### Wallpaper Types

- `:solid` - Solid color background
- `:gradient` - Gradient background
- `:image` - Custom image upload
- `:pattern` - Repeating pattern

---

### 3. Channel Advanced Features (`channel-advanced.lisp`)

Forum topics, channel statistics, and sponsored messages for advanced channel management.

#### Classes

- **`forum-topic`** - Forum topic definition
  - Properties: `id`, `name`, `icon-color`, `icon-custom-emoji-id`, `is-closed`, `is-pinned`

- **`channel-statistics`** - Channel analytics
  - Properties: `channel-id`, `member-count`, `total-views`, `total-shares`, 
                `growth-data`, `language-distribution`, `period`

- **`message-statistics`** - Individual message analytics
  - Properties: `message-id`, `views`, `forwards`, `reactions`, `hourly-data`

- **`reaction-statistics`** - Reaction breakdown
  - Properties: `reaction-type`, `count`, `recent-reactors`

- **`sponsored-message`** - Sponsored message definition
  - Properties: `id`, `content`, `sponsor`, `start-date`, `end-date`, `impressions`

#### Functions

**Forum Topic Management**:
```lisp
(create-forum-topic chat-id name &key icon-color icon-custom-emoji-id)
  => forum-topic object on success

(get-forum-topics chat-id &key offset limit)
  => List of forum-topic objects

(edit-forum-topic chat-id message-thread-id &key name icon-color 
                                                   icon-custom-emoji-id)
  => T on success

(close-forum-topic chat-id message-thread-id)
  => T on success

(reopen-forum-topic chat-id message-thread-id)
  => T on success

(delete-forum-topic chat-id message-thread-id)
  => T on success

(pin-forum-topic chat-id message-thread-id)
  => T on success

(unpin-forum-topic chat-id message-thread-id)
  => T on success
```

**Channel Statistics**:
```lisp
(get-channel-statistics channel-id &key start-date end-date granular)
  => channel-statistics object on success
  
  Parameters:
  - start-date/end-date: ISO 8601 format strings
  - granular: T for hourly breakdown

(get-message-statistics channel-id message-id)
  => message-statistics object on success

(get-reaction-statistics channel-id message-id)
  => List of reaction-statistics objects
```

**Sponsored Messages**:
```lisp
(get-sponsored-messages channel-id)
  => List of sponsored-message objects

(report-sponsored-message channel-id message-id reason)
  => T on success
  
  Reasons: :inappropriate, :spam, :scam, :fake
```

#### Statistics Data Format

**Growth Data** (in `channel-statistics`):
```lisp
'((:date . "2026-04-20")
  (:gained . 150)
  (:left . 23)
  (:net-growth . 127))
```

**Hourly Data** (in `message-statistics`):
```lisp
'((:hour . 0) (:views . 120) (:forwards . 5))
'((:hour . 1) (:views . 89) (:forwards . 2))
...
```

---

## Global State

New global variables for caching:

```lisp
;; Chat folders
(defvar *chat-folder-cache* (make-hash-table :test 'equal))
(defvar *archive-cache* (make-hash-table :test 'equal))

;; Emoji and customization
(defvar *custom-emoji-cache* (make-hash-table :test 'equal))
(defvar *wallpaper-cache* nil)
(defvar *theme-cache* nil)
(defvar *available-message-effects* nil)
(defvar *default-dice-emojis* '("🎲" "🎯" "🏀" "⚽" "🎳" "🎰"))

;; Channel advanced
(defvar *forum-topic-cache* (make-hash-table :test 'equal))
(defvar *channel-statistics-cache* (make-hash-table :test 'equal))
(defvar *sponsored-message-cache* (make-hash-table :test 'equal))
```

---

## Testing

Comprehensive test suite in `tests/v0.21.0-tests.lisp`:

### Test Coverage

| Category | Test Cases | Coverage |
|----------|------------|----------|
| Chat Folders | 25 | ✅ |
| Emoji & Customization | 20 | ✅ |
| Channel Advanced | 25 | ✅ |
| **Total** | **70+** | **✅** |

### Test Categories

1. **Class Instantiation Tests** - Verify all CLOS classes create correctly
2. **Mock API Tests** - Test API call construction and parameter handling
3. **Edge Case Tests** - Empty inputs, max lengths, boundary values
4. **Global State Tests** - Cache initialization and management
5. **Integration Tests** - Multi-step workflows

### Example Test

```lisp
(test test-make-chat-folder
  "Test chat-folder class instantiation"
  (let ((folder (make-chat-folder "Work" 
                                  :icon "📁"
                                  :chat-list :main
                                  :filters (list (make-chat-folder-filter :contact))
                                  :is-shared nil)))
    (is equal (chat-folder-title folder) "Work")
    (is equal (chat-folder-icon folder) "📁")
    (is equal (chat-folder-chat-list folder) :main)
    (is false (chat-folder-is-shared folder))))
```

---

## Usage Examples

### Chat Folder Setup

```lisp
;; Create a work folder with contact filter
(let ((work-folder (make-chat-folder "Work"
                                     :icon "💼"
                                     :filters (list 
                                                (make-chat-folder-filter :contact)))))
  (create-chat-folder work-folder)
  ;; Add specific chats
  (add-chat-to-folder (chat-folder-id work-folder) -1001234567890)
  (add-chat-to-folder (chat-folder-id work-folder) -1009876543210))
```

### Custom Emoji Message

```lisp
;; Send message with custom emoji effect
(let ((effects (get-available-message-effects))
      (emoji (first (get-premium-emojis))))
  (when (and effects emoji)
    (send-message-with-effect chat-id "Celebrating! 🎉"
                              :message-effect-id (message-effect-id (first effects)))))
```

### Forum Topic Creation

```lisp
;; Create a forum topic for project discussion
(let ((topic (create-forum-topic -1001234567890 "Project Alpha Discussion"
                                 :icon-color "#FF5733"
                                 :icon-custom-emoji-id "12345678")))
  (when topic
    (format t "Created topic: ~A~%" (forum-topic-name topic))))
```

### Channel Analytics

```lisp
;; Get channel statistics for last 7 days
(let* ((end-date (format-timestring nil (get-universal-time) :format :iso-8601))
       (start-date (format-timestring nil (- (get-universal-time) (* 7 86400)) 
                                      :format :iso-8601))
       (stats (get-channel-statistics -1001234567890 
                                      :start-date start-date
                                      :end-date end-date
                                      :granular t)))
  (when stats
    (format t "Members: ~A~%" (channel-statistics-member-count stats))
    (format t "Total Views: ~A~%" (channel-statistics-total-views stats))))
```

---

## API Compatibility

All functions in v0.21.0 are compatible with:
- Telegram Bot API 7.0+
- Telegram Premium subscription (for premium features)
- Backward compatible with v0.20.0

---

## Migration Notes

### No Breaking Changes

v0.21.0 is fully backward compatible with v0.20.0. All existing code continues to work without modification.

### New Dependencies

No new external dependencies required. All features use existing MTProto and Bot API infrastructure.

### Premium Features

The following features require Telegram Premium subscription:
- Premium custom emoji
- Premium chat themes
- Premium wallpapers
- Star reactions (sending)
- Some message effects

---

## Performance Considerations

### Caching

All new features implement local caching:
- Chat folders cached after first fetch
- Emoji and themes cached to reduce API calls
- Statistics cached with automatic invalidation

### Rate Limits

Be aware of API rate limits when:
- Creating multiple forum topics rapidly
- Fetching statistics with granular data
- Uploading custom wallpapers

Recommended delays:
- 1 second between folder operations
- 2 seconds between statistics requests
- 5 seconds between wallpaper uploads

---

## Known Limitations

1. **Forum Topics**: Only available in supergroups with `is_forum = true`
2. **Sponsored Messages**: Only displayed in channels with 1000+ subscribers
3. **Statistics**: Historical data limited to 90 days
4. **Custom Emoji**: Requires file download for animation rendering
5. **Chat Folders**: Maximum 20 folders per account (Telegram limit)

---

## Security Notes

- Chat folder share links should be treated as sensitive
- Statistics data may contain user information - handle appropriately
- Sponsored message reporting requires valid reason codes
- Star transactions are immutable - verify before sending

---

## Next Steps (v0.22.0)

Planned features for v0.22.0:
- Notification system enhancements
- Contact management improvements
- Utility functions and helpers
- Documentation improvements

---

## Contributors

Developed as part of the cl-telegram project - a pure Common Lisp Telegram client implementation using MTProto 2.0.

For issues and contributions: https://github.com/cl-mytelegram/cl-telegram
