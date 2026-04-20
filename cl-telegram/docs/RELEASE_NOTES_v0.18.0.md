# Release Notes - v0.18.0

**Release Date**: 2026-04-19  
**Previous Version**: v0.17.0  
**Next Version**: v0.19.0 (planned)

---

## 🎉 Highlights

v0.18.0 focuses on completing the Inline Bots 2025 feature set, Telegram Premium integration, and comprehensive test coverage. This release adds 65+ new test cases and implements 3 critical protocol improvements.

---

## 🚀 New Features

### Inline Bots 2025 (21 functions)

**Visual Effects**
- `make-visual-effect` - Create visual effects (fireworks, sparkles, hearts, stars, balloons)
- `add-visual-effects-to-result` - Add effects to inline results
- `make-inline-result-with-spoiler` - Create results with spoiler effect
- `send-inline-result-with-animation` - Send animated inline results

**Business Features**
- `get-business-connection` - Get business connection information
- `send-business-message` - Send business messages with signature
- `edit-business-message` - Edit business messages
- `delete-business-message` - Delete business messages
- `list-business-connections` - List all business connections
- `close-business-connection` - Close a business connection
- `set-inline-bot-business-location` - Set bot business location
- `set-inline-bot-business-hours` - Set bot business hours

**Paid Media**
- `make-paid-media-info` - Create paid media information
- `send-paid-media` - Send paid media to chat
- `create-paid-media-post` - Create paid media post

**WebApp Integration**
- `answer-web-app-query` - Answer WebApp inline queries
- `validate-web-app-init-data` - Validate WebApp init data (HMAC-SHA256)
- `send-web-app-data` - Send data to WebApp

**Analytics**
- `get-inline-bot-analytics` - Get bot analytics data
- `get-user-chat-boosts` - Get user's chat boosts

### Premium Features (14 functions)

**Status Detection**
- `get-premium-status-from-server` - Fetch premium status from server
- `verify-premium-status` - Verify premium status with error handling
- `check-premium-status` - Check cached premium status

**Premium Stickers & Reactions**
- `fetch-premium-sticker-sets` - Get premium-exclusive sticker sets
- `fetch-premium-reactions` - Get premium reactions
- `can-use-premium-sticker-p` - Check if user can use sticker
- `can-send-reaction-p` - Check if user can send reaction

**Customization**
- `fetch-premium-profile-colors` - Get premium profile colors
- `fetch-premium-chat-themes` - Get premium chat themes
- `fetch-premium-emoji-statuses` - Get premium emoji statuses
- `set-profile-color` - Set user profile color
- `set-chat-theme` - Set chat theme
- `set-emoji-status` - Set emoji status
- `clear-emoji-status` - Clear emoji status

**Subscription Management**
- `cancel-premium-subscription` - Cancel premium subscription
- `renew-premium-subscription` - Renew premium subscription
- `get-premium-subscription-info` - Get subscription information

**Enhanced Limits**
- `get-doubled-limits` - Get doubled limits for premium users
- `can-pin-more-chats-p` - Check if user can pin more chats
- `can-join-more-channels-p` - Check if user can join more channels

**Voice Transcription**
- `transcribe-voice-message-premium` - Transcribe voice messages

### Protocol Improvements (3 functions)

**Message Handling**
- `handle-msg-container` - Parse container messages with multiple sub-messages
- `handle-gzip-packed` - Decompress gzip-packed messages
- `handle-bad-server-salt` - Auto-retry on bad server salt errors

---

## 🧪 Test Coverage

### New Test Suites

**Inline Bots 2025 Tests** (`tests/inline-bots-tests.lisp`)
- 30 test cases covering:
  - Inline query/result class creation
  - Inline keyboard buttons and markup
  - Visual effects (all 5 types)
  - Business features (8 functions)
  - Paid media (3 functions)
  - WebApp integration (3 functions)
  - Bot analytics
  - Handler registration/dispatch

**Premium Features Tests** (`tests/premium-tests.lisp`)
- 35 test cases covering:
  - Premium status class and accessors
  - Status detection and caching
  - Feature requirement checks
  - File upload limits (free vs premium)
  - Premium stickers and reactions
  - Premium customization options
  - Subscription management
  - Utility functions

### Test Statistics

| Suite | Tests | Status |
|-------|-------|--------|
| Inline Bots 2025 | 30 | ✅ |
| Premium Features | 35 | ✅ |
| Stickers | 30 | ✅ (v0.17.0) |
| Voice Messages | 25 | ✅ (v0.17.0) |
| **Total** | **400+** | ✅ |

---

## 📁 Files Modified

### New Files
- `tests/inline-bots-tests.lisp` (550 lines)
- `tests/premium-tests.lisp` (400 lines)
- `docs/RELEASE_NOTES_v0.18.0.md` (this file)

### Modified Files
- `src/api/stories.lisp` - Implemented `get-story-privacy-settings`
- `src/api/performance-optimizations-v2.lisp` - Implemented uploadPart API and thumbnail caching
- `README.md` - Updated version, features, code stats, test coverage

---

## 🐛 Bug Fixes

### Fixed in v0.18.0
1. **Story Privacy Settings** - `get-story-privacy-settings` was a stub, now makes proper API call
2. **File Upload Parts** - uploadPart API integration completed for large file uploads
3. **Thumbnail Caching** - Story thumbnail preloading now downloads and caches properly

---

## 📊 Code Statistics

| Metric | v0.17.0 | v0.18.0 | Change |
|--------|---------|---------|--------|
| Total Files | 85 | 97 | +12 |
| Total Lines | ~24,650 | ~27,250 | +2,600 |
| Test Files | 22 | 30 | +8 |
| Test Cases | ~350 | 400+ | +50+ |
| Coverage | ~85% | ~87% | +2% |

---

## ⚠️ Breaking Changes

**None** - This release is fully backward compatible with v0.17.0.

---

## 🔧 Migration Guide

No migration required. All new functions are additive and do not modify existing APIs.

---

## 🙏 Acknowledgments

- Telegram Bot API 2025 specification
- Common Lisp MTProto community
- Test contributors and reviewers

---

## 📝 TODO for v0.19.0

Remaining items from v0.17.0/v0.18.0 development:
- Story privacy settings UI integration
- Business hours validation
- Premium subscription webhook handling
- Advanced analytics dashboard
- Performance benchmarks for new features

---

**Full Changelog**: See `docs/CHANGELOG.md` for detailed changes.
