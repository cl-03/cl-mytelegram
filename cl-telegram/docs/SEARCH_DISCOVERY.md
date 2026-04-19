# Search and Discovery Guide

## Overview

cl-telegram v0.14.0+ includes comprehensive search and discovery features:

- **Chat Search** - Find public chats, browse recently found
- **Message Search** - Search messages with 19 filter types
- **Member Search** - Find members in chats
- **Global Search** - Search across all content types
- **Search Cache** - Optimized repeated searches

## Table of Contents

1. [Search Filters](#search-filters)
2. [Chat Search](#chat-search)
3. [Message Search](#message-search)
4. [Member Search](#member-search)
5. [Global Search](#global-search)
6. [Search Cache](#search-cache)

---

## Search Filters

### Available Filter Types

| Filter | Description |
|--------|-------------|
| `:empty` | No filtering (all messages) |
| `:photo` | Photos only |
| `:video` | Videos only |
| `:audio` | Audio files only |
| `:document` | Documents only |
| `:animation` | Animations/GIFs only |
| `:voice-note` | Voice messages only |
| `:video-note` | Video notes only |
| `:photo-and-video` | Photos and videos |
| `:url` | Messages with links |
| `:poll` | Polls only |
| `:mention` | Messages mentioning you |
| `:unread-mention` | Unread mentions |
| `:unread-reaction` | Unread reactions |
| `:unread-poll-vote` | Unread poll votes |
| `:chat-photo` | Chat photo changes |
| `:pinned` | Pinned messages |
| `:failed-to-send` | Failed to send messages |

### Create Search Filter

```lisp
(use-package :cl-telegram/api)

;; Create filter for photos
(let ((filter (make-search-filter :photo)))
  ;; Use in search
  )

;; Create filter with params
(make-search-filter :mention :unread t)
```

---

## Chat Search

### Search Public Chats

```lisp
;; Search single public chat by username
(multiple-value-bind (chats error)
    (search-public-chats "telegram")
  (if error
      (format t "Error: ~A~%" error)
      (dolist (chat chats)
        (format t "Found: ~A~%" (getf chat :title)))))

;; Search multiple public chats
(multiple-value-bind (chats error)
    (search-public-chats-multi "news" :limit 20)
  (when chats
    (format t "Found ~A public chats~%" (length chats))))
```

### Search Local Chats

```lisp
;; Search in local chat cache
(multiple-value-bind (chats error)
    (search-chats "john" :limit 10)
  (when chats
    (format t "Found ~A matching chats~%" (length chats))))
```

### Search on Server

```lisp
;; Search across all accessible chats on server
(multiple-value-bind (chats error)
    (search-chats-on-server "project" :limit 50 :offset 0)
  (when chats
    (format t "Found ~A chats on server~%" (length chats))))
```

### Recently Found Chats

```lisp
;; Search recently found chats
(multiple-value-bind (chats error)
    (search-recently-found-chats "team" :limit 10)
  (when chats
    (format t "Found ~A recent chats~%" (length chats))))
```

---

## Message Search

### Global Message Search

```lisp
;; Search all messages with query
(multiple-value-bind (messages count error)
    (search-messages "hello world" :limit 20)
  (if error
      (format t "Error: ~A~%" error)
      (format t "Found ~A messages~%" count)))

;; Search with filter (photos only)
(multiple-value-bind (messages count error)
    (search-messages "" :filter :photo :limit 50)
  (when messages
    (format t "Found ~A photos~%" count)))

;; Search by date range
(multiple-value-bind (messages count error)
    (search-messages ""
                     :min-date (- (get-universal-time) 86400) ; Last 24h
                     :max-date (get-universal-time)
                     :limit 100)
  (when messages
    (format t "Found ~A recent messages~%" count)))

;; Search with chat type filter
(multiple-value-bind (messages count error)
    (search-messages "announcement"
                     :chat-type-filter :channel
                     :limit 20)
  (when messages
    (format t "Found ~A channel messages~%" count)))
```

### Search Within Chat

```lisp
;; Search messages in specific chat
(multiple-value-bind (messages count error)
    (search-chat-messages 123456 "meeting notes" :limit 20)
  (when messages
    (format t "Found ~A messages in chat~%" count)))

;; Search with filter in chat
(multiple-value-bind (messages count error)
    (search-chat-messages 123456 ""
                          :filter :url
                          :limit 30)
  (when messages
    (format t "Found ~A links in chat~%" count)))

;; Search by sender
(multiple-value-bind (messages count error)
    (search-chat-messages 123456 ""
                          :sender-id 789012
                          :limit 20)
  (when messages
    (format t "Found ~A messages from sender~%" count)))

;; Search from specific message
(multiple-value-bind (messages count error)
    (search-chat-messages 123456 "topic"
                          :from-message-id 1000
                          :limit 50)
  (when messages
    (format t "Found ~A messages after ID 1000~%" count)))
```

### Search Secret Messages

```lisp
;; Search in secret chat (local only)
(multiple-value-bind (messages error)
    (search-secret-messages secret-chat-id "password" :limit 10)
  (if error
      (format t "Error: ~A~%" error)
      (format t "Found ~A messages~%" (length messages))))
```

---

## Member Search

### Search Chat Members

```lisp
;; Search all members
(multiple-value-bind (members error)
    (search-chat-members 123456 "john" :limit 20)
  (when members
    (dolist (member members)
      (format t "Member: ~A~%" (getf member :user-id)))))

;; Search administrators only
(multiple-value-bind (members error)
    (search-chat-members 123456 ""
                         :filter :administrators
                         :limit 10)
  (when members
    (format t "Found ~A admins~%" (length members))))

;; Search restricted members
(multiple-value-bind (members error)
    (search-chat-members 123456 ""
                         :filter :restricted
                         :limit 20)
  (when members
    (format t "Found ~A restricted members~%" (length members))))

;; Search banned members
(multiple-value-bind (members error)
    (search-chat-members 123456 ""
                         :filter :banned
                         :limit 20)
  (when members
    (format t "Found ~A banned members~%" (length members))))
```

### Member Filter Types

| Filter | Description |
|--------|-------------|
| `:all` | All members (default) |
| `:administrators` | Administrators only |
| `:restricted` | Restricted members |
| `:banned` | Banned members |
| `:can-mention` | Members that can be mentioned |

---

## Global Search

### Search Across All Types

```lisp
;; Search chats and users
(let ((results (global-search "telegram"
                              :types '(:chats :users)
                              :limit 10)))
  (when (getf results :chats)
    (format t "Found ~A chats~%" (length (getf results :chats))))
  (when (getf results :users)
    (format t "Found ~A users~%" (length (getf results :users)))))

;; Search all types
(let ((results (global-search "project"
                              :types '(:chats :messages :users)
                              :limit 20)))
  ;; Process results by type
  (getf results :chats)
  (getf results :messages)
  (getf results :users))
```

### Search Types

| Type | Description |
|------|-------------|
| `:chats` | Search chats |
| `:messages` | Search messages |
| `:users` | Search users |
| `:bots` | Search bots |

---

## Search Helpers

### Get Query Suggestions

```lisp
;; Get search suggestions
(let ((suggestions (get-search-query-suggestions "tele" :limit 5)))
  (dolist (suggestion suggestions)
    (format t "Suggestion: ~A~%" suggestion)))
```

### Search History

```lisp
;; Get recent search history
(let ((history (get-search-history :limit 20)))
  (dolist (entry history)
    (format t "Search: ~A~%" (getf entry :query))))

;; Clear search history
(clear-search-history)
```

---

## Search Cache

### Cache Management

```lisp
;; Cache search result
(cache-search-result "my-search-key" search-result :ttl 600)

;; Get cached result
(let ((cached (get-cached-search "my-search-key")))
  (if cached
      (format t "Cache hit: ~A~%" cached)
      (format t "Cache miss~%")))

;; Cache is automatically cleaned on expiration
```

### Cache TTL

| TTL | Use Case |
|-----|----------|
| 60 | Frequently changing data |
| 300 | Standard search results |
| 600 | Static or slow-changing data |
| 3600 | Reference data |

---

## Complete Example

```lisp
;; Load system
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Search workflow
(defun find-chat-and-messages (search-term)
  "Find chats and messages matching search term"
  (format t "Searching for: ~A~%" search-term)
  
  ;; Search chats
  (multiple-value-bind (chats error)
      (search-chats search-term :limit 10)
    (if error
        (format t "Chat search error: ~A~%" error)
        (progn
          (format t "Found ~A chats~%" (length chats))
          (dolist (chat chats)
            (format t "  - ~A~%" (getf chat :title))))))
  
  ;; Search messages with photo filter
  (multiple-value-bind (messages count error)
      (search-messages search-term :filter :photo :limit 20)
    (if error
        (format t "Message search error: ~A~%" error)
        (format t "Found ~A photos~%" count)))
  
  ;; Global search
  (let ((results (global-search search-term
                                :types '(:chats :users :messages)
                                :limit 10)))
    (format t "~%Global Search Results:~%")
    (when (getf results :chats)
      (format t "Chats: ~A~%" (length (getf results :chats))))
    (when (getf results :users)
      (format t "Users: ~A~%" (length (getf results :users))))
    (when (getf results :messages)
      (format t "Messages: ~A~%" (length (getf results :messages))))))

;; Usage
(find-chat-and-messages "telegram")
```

---

## API Reference

### Search Filters

| Function | Description |
|----------|-------------|
| `make-search-filter` | Create search filter |

### Chat Search

| Function | Description |
|----------|-------------|
| `search-public-chats` | Search public chat by username |
| `search-public-chats-multi` | Search multiple public chats |
| `search-chats` | Search local chats |
| `search-chats-on-server` | Search chats on server |
| `search-recently-found-chats` | Search recently found |

### Message Search

| Function | Description |
|----------|-------------|
| `search-messages` | Global message search |
| `search-chat-messages` | Search within chat |
| `search-secret-messages` | Search secret chat messages |

### Member Search

| Function | Description |
|----------|-------------|
| `search-chat-members` | Search chat members |

### Helpers

| Function | Description |
|----------|-------------|
| `get-search-query-suggestions` | Get search suggestions |
| `get-search-history` | Get search history |
| `clear-search-history` | Clear history |
| `global-search` | Search all types |

---

**Version:** v0.14.0  
**Last Updated:** April 2026
