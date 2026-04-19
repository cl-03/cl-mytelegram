# cl-telegram Documentation

Welcome to the cl-telegram documentation hub. This directory contains comprehensive documentation for all features of the cl-telegram Telegram client library.

## 📚 Documentation Index

### Core Documentation

| Document | Description |
|----------|-------------|
| [API_REFERENCE.md](./API_REFERENCE.md) | Complete API reference with all functions |
| [MTProto_2_0.md](./MTProto_2_0.md) | MTProto 2.0 protocol implementation details |
| [NETWORK_LAYER.md](./NETWORK_LAYER.md) | Network layer architecture and connection management |
| [WEBRTC_SETUP.md](./WEBRTC_SETUP.md) | WebRTC setup guide for voice/video calls |
| [PERFORMANCE.md](./PERFORMANCE.md) | Performance optimization guide (v0.13.0) |

### New Features (v0.13.0)

| Document | Description |
|----------|-------------|
| [PERFORMANCE.md](./PERFORMANCE.md) | Object pooling, large file upload, thumbnail caching, batch ops |

### New Features (v0.12.0)

| Document | Description |
|----------|-------------|
| [STORIES.md](./STORIES.md) | Telegram Stories API - posting, viewing, highlights |
| [PREMIUM.md](./PREMIUM.md) | Telegram Premium features and limits |
| [INLINE_MODE_2025.md](./INLINE_MODE_2025.md) | Enhanced inline bots with 2025 features |

---

## 🚀 Quick Start

### 1. Authentication

```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Set phone number
(set-authentication-phone-number "+1234567890")

;; Request code
(request-authentication-code)

;; Verify code
(check-authentication-code "12345")
```

### 2. Send Message

```lisp
(send-message 123456 "Hello, World!")
```

### 3. Get Chats

```lisp
(get-chats :limit 50)
```

### 4. Post Story

```lisp
(post-story-photo photo-id
                  :caption "Check this out!"
                  :privacy :contacts)
```

### 5. Check Premium

```lisp
(if (check-premium-status)
    (format t "Premium active! ⭐")
    (format t "Free account"))
```

---

## 📖 Feature Categories

### Authentication & Users

- **Authentication**: Phone verification, 2FA, session management
- **Users**: Get user info, contacts, block/unblock, profile photos
- **Privacy**: Privacy settings, blocked users list

**See:** [API_REFERENCE.md](./API_REFERENCE.md#authentication-api)

### Messages & Chats

- **Messages**: Send, edit, delete, forward, search
- **Chats**: Get chat list, chat history, members management
- **Media**: Send photos, documents, voice messages, videos
- **Reactions**: Send emoji reactions to messages

**See:** [API_REFERENCE.md](./API_REFERENCE.md#messages-api)

### Stories (v0.12.0)

- **Posting**: Photo/video stories with captions
- **Privacy**: Everybody/contacts/close-friends/custom
- **Highlights**: Permanent story collections
- **Interactions**: Views, reactions, replies, forwards
- **UI**: Stories bar, full-screen viewer

**See:** [STORIES.md](./STORIES.md)

### Premium Features (v0.12.0)

- **File Uploads**: 4GB limit (vs 2GB free)
- **Stickers & Reactions**: Premium-exclusive content
- **Customization**: Profile colors, chat themes, emoji statuses
- **Voice**: Unlimited transcription
- **Limits**: Doubled channel/folder/pinned chat limits

**See:** [PREMIUM.md](./PREMIUM.md)

### Inline Bots (v0.12.0)

- **Visual Effects**: Fireworks, sparkles, hearts, stars, balloons
- **Business**: Business integration, paid media
- **WebApp**: Enhanced WebApp buttons and types
- **New Types**: Story results, giveaway results
- **Spoilers**: Media with spoiler overlay

**See:** [INLINE_MODE_2025.md](./INLINE_MODE_2025.md)

### Voice & Video Calls

- **VoIP**: Individual and group calls
- **WebRTC**: CFFI bindings for audio/video streaming
- **Media**: Audio/video message recording and playback

**See:** [WEBRTC_SETUP.md](./WEBRTC_SETUP.md)

### Network & Protocol

- **MTProto**: Authentication, encryption, transport
- **Connections**: TCP client, connection pool, auto-reconnect
- **Proxy**: SOCKS5 and HTTP proxy support
- **Multi-DC**: Datacenter selection and migration

**See:** [NETWORK_LAYER.md](./NETWORK_LAYER.md), [MTProto_2_0.md](./MTProto_2_0.md)

---

## 🎯 Common Use Cases

### Bot Development

```lisp
;; Create bot
(register-inline-bot-handler token
                              #'handle-inline-query
                              :callback-handler #'handle-callback)

;; Send message with inline keyboard
(send-message chat-id "Choose option:"
              :reply-markup (make-inline-keyboard
                              (list (list (make-inline-button "Option 1" "data1")
                                         (make-inline-button "Option 2" "data2")))))
```

### Media Handling

```lisp
;; Send photo
(send-photo chat-id photo-file-id :caption "Nice!")

;; Send document
(send-document chat-id doc-file-id)

;; Send voice message
(send-voice-message chat-id voice-file-id)
```

### Group Management

```lisp
;; Get administrators
(get-chat-administrators chat-id)

;; Ban member
(ban-chat-member chat-id user-id :duration 3600)

;; Create invite link
(create-chat-invite-link chat-id :name "VIP Access")
```

### Stories Workflow

```lisp
;; Post story
(let ((story (post-story-photo photo-id :caption "New!")))
  ;; Monitor views
  (let ((views (get-story-views (story-id story))))
    (format t "Story viewed by ~A users" (length views))))

;; Create highlight
(create-highlight "Travel 2025"
                  :cover-media cover-photo
                  :story-ids '(1 2 3 4 5))
```

### Premium Features

```lisp
;; Check upload capability
(if (can-upload-file-p (* 3 1024 1024 1024))
    (send-video chat-id large-file)
    (format t "File too large for free account"))

;; Use premium sticker
(when (can-use-premium-sticker-p "premium-pack")
  (send-sticker chat-id "premium-sticker"))
```

---

## 📦 Version History

### v0.13.0 (Current)

**New Features:**
- ✅ Object pooling for reduced GC pressure
- ✅ Large file upload up to 4GB (Premium)
- ✅ Thumbnail caching with LRU eviction
- ✅ Batch operations with minimal consing
- ✅ Fast string operations
- ✅ Connection pool monitoring
- ✅ CLOG UI enhancements (theme switching, premium badge)
- ✅ Bot API 2025 extended features (visual effects, business, paid media, WebApp)

### v0.12.0

**New Features:**
- ✅ Stories support with highlights and expiration
- ✅ Premium features integration
- ✅ Inline bots 2025 enhancements
- ✅ Visual effects on messages
- ✅ Business features (Bot API 9.0+)
- ✅ Paid media support

### v0.11.0

- Voice messages with waveform visualization
- Performance optimizations v2
- Thread-safe caching
- Reduced GC pressure

### v0.10.0

- Stickers & emoji packs
- Channel broadcast
- Message reactions
- Inline bots & keyboards
- Message threads & replies

### v0.9.0

- CLOG GUI client
- Media viewer
- Group admin features
- WebRTC calls foundation

---

## 🔧 Development Resources

### Testing

```lisp
;; Load test system
(asdf:load-system :cl-telegram/tests)

;; Run all tests
(cl-telegram/tests:run-all-tests)

;; Run specific suite
(fiveam:run! 'cl-telegram/tests::crypto-tests)
```

### Debugging

Enable debug logging:

```lisp
(setf *debug-mode* t)
(setf *log-level* :debug)
```

### Performance Monitoring

```lisp
;; Get connection pool stats
(get-connection-pool-stats)

;; Get performance stats
(get-performance-stats)

;; Get database stats
(get-database-stats)
```

---

## 📞 Support

### Getting Help

- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Check the docs in this directory
- **Examples**: See `tests/` directory for usage examples

### Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests
4. Implement feature
5. Run test suite
6. Submit pull request

---

## 📋 Quick Reference

### Packages

| Package | Nickname | Purpose |
|---------|----------|---------|
| `cl-telegram` | `cl-tg` | Main package |
| `cl-telegram/api` | `cl-tg/api` | API functions |
| `cl-telegram/mtproto` | `cl-tg/mtproto` | Protocol layer |
| `cl-telegram/crypto` | `cl-tg/crypto` | Cryptography |
| `cl-telegram/network` | `cl-tg/network` | Network layer |
| `cl-telegram/ui` | `cl-tg/ui` | UI components |

### Error Handling

```lisp
(handler-case
    (send-message chat-id "Hello")
  (telegram-error (e)
    (format t "Telegram error: ~A~%" (telegram-error-message e)))
  (error (e)
    (format t "Unexpected error: ~A~%" e)))
```

### Constants

```lisp
*max-file-size*         ; Maximum file size (2GB/4GB premium)
*upload-part-size*      ; Upload chunk size
*auth-state*            ; Current auth state
*auth-connection*       ; Current connection
```

---

## 🔗 External Resources

- [Telegram API Documentation](https://core.telegram.org/api)
- [MTProto 2.0 Specification](https://core.telegram.org/mtproto)
- [Bot API Documentation](https://core.telegram.org/bots/api)
- [TDLib API Reference](https://core.telegram.org/tdlib/docs/)

---

**Last Updated:** April 2026  
**Version:** v0.13.0
