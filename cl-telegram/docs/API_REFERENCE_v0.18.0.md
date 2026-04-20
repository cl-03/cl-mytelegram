# API Reference - v0.18.0

## Inline Bots 2025 API

### Visual Effects

#### `make-visual-effect`
```lisp
(make-visual-effect &key (type :fireworks) (duration 3.0) (intensity 1.0))
```

Create a visual effect for inline results.

**Parameters:**
- `type` - Effect type: `:fireworks`, `:sparkles`, `:hearts`, `:stars`, `:balloons`
- `duration` - Effect duration in seconds (default: 3.0)
- `intensity` - Effect intensity 0.0-1.0 (default: 1.0)

**Returns:** Property list with effect configuration

**Example:**
```lisp
(let ((effect (make-visual-effect :type :fireworks :duration 5.0)))
  (add-visual-effects-to-result result effect))
```

---

#### `add-visual-effects-to-result`
```lisp
(add-visual-effects-to-result inline-result &rest effects)
```

Add visual effects to an inline query result.

**Parameters:**
- `inline-result` - Inline result object
- `effects` - One or more visual effect objects

**Returns:** Modified inline result

---

#### `make-inline-result-with-spoiler`
```lisp
(make-inline-result-with-spoiler id title &key (type "article") (url nil))
```

Create an inline result with spoiler effect (content hidden until tapped).

**Parameters:**
- `id` - Unique result identifier
- `title` - Result title
- `type` - Result type (default: "article")
- `url` - Optional URL for the result

**Returns:** Inline result plist with spoiler effect

---

### Business Features

#### `get-business-connection`
```lisp
(get-business-connection user-id)
```

Get business connection information for a user.

**Parameters:**
- `user-id` - User identifier or business ID

**Returns:** Business connection plist with:
- `:id` - Connection ID
- `:user` - Associated user
- `:is-enabled` - Whether connection is active
- `:location` - Business location (if set)
- `:hours` - Business hours (if set)

---

#### `send-business-message`
```lisp
send-business-message(user-id, text, &key signature, reply-to, media)
```

Send a business message with optional signature.

**Parameters:**
- `user-id` - Recipient user ID
- `text` - Message text
- `signature` - Business signature (e.g., "Support Team")
- `reply-to` - Message ID to reply to
- `media` - Optional media attachment

**Returns:** Sent message object

---

#### `set-inline-bot-business-hours`
```lisp
(set-inline-bot-business-hours bot-id hours)
```

Set business hours for an inline bot.

**Parameters:**
- `bot-id` - Bot identifier
- `hours` - List of daily schedules:
  ```lisp
  '((:open "09:00" :close "17:00")  ; Monday
    (:open "09:00" :close "17:00")  ; Tuesday
    ...)
  ```

**Returns:** T on success

---

### Paid Media

#### `make-paid-media-info`
```lisp
(make-paid-media-info &key type media-id price-amount price-currency description)
```

Create paid media information.

**Parameters:**
- `type` - Media type: "photo", "video"
- `media-id` - File ID of the media
- `price-amount` - Price in smallest currency units (e.g., cents)
- `price-currency` - Currency code (e.g., "USD", "EUR")
- `description` - Optional media description

**Returns:** Paid media info plist

**Example:**
```lisp
(let ((media (make-paid-media-info
              :type "photo"
              :media-id "AgAD1234"
              :price-amount 100
              :price-currency "USD")))
  (send-paid-media chat-id media))
```

---

#### `send-paid-media`
```lisp
(send-paid-media chat-id media-info &key caption reply-markup)
```

Send paid media to a chat.

**Parameters:**
- `chat-id` - Target chat ID
- `media-info` - Paid media info from `make-paid-media-info`
- `caption` - Optional caption
- `reply-markup` - Optional reply keyboard

**Returns:** Sent message object

---

### WebApp Integration

#### `validate-web-app-init-data`
```lisp
(validate-web-app-init-data init-data)
```

Validate WebApp initialization data using HMAC-SHA256.

**Parameters:**
- `init-data` - Property list with WebApp data:
  - `:query-id` - Query identifier
  - `:auth-hash` - Authentication hash
  - `:user-id` - User ID
  - `:first-name` - User's first name

**Returns:** T if valid, NIL otherwise

**Security:** Uses HMAC-SHA256 to verify data integrity and authenticity.

---

#### `answer-web-app-query`
```lisp
(answer-web-app-query query-id inline-result)
```

Answer a WebApp inline query.

**Parameters:**
- `query-id` - WebApp query ID
- `inline-result` - Result to return

**Returns:** T on success

---

### Bot Analytics

#### `get-inline-bot-analytics`
```lisp
(get-inline-bot-analytics bot-token &key start-date end-date metrics)
```

Get analytics data for an inline bot.

**Parameters:**
- `bot-token` - Bot API token
- `start-date` - Start date (default: 7 days ago)
- `end-date` - End date (default: today)
- `metrics` - List of metrics to fetch

**Returns:** Analytics plist with:
- `:query-count` - Number of queries
- `:result-clicks` - Result click-throughs
- `:unique-users` - Unique user count
- `:top-queries` - Most common queries

---

#### `get-user-chat-boosts`
```lisp
(get-user-chat-boosts user-id)
```

Get chat boosts given by a user.

**Parameters:**
- `user-id` - User identifier

**Returns:** List of boost objects with chat and level information

---

## Premium Features API

### Status Detection

#### `check-premium-status`
```lisp
(check-premium-status)
```

Check if current user has Telegram Premium (uses cache).

**Returns:** T if premium, NIL otherwise

**Cache:** Results cached for 1 hour (`*premium-cache-ttl*`)

---

#### `refresh-premium-status`
```lisp
(refresh-premium-status)
```

Refresh premium status from server.

**Returns:** T if premium, NIL otherwise

---

#### `get-premium-status-from-server`
```lisp
(get-premium-status-from-server)
```

Get premium status directly from Telegram servers.

**Returns:** Plist with:
- `:is-premium` - Premium status
- `:expiration-date` - Subscription expiration
- `:subscription-type` - :monthly, :yearly, etc.
- `:can-send-large-files` - 4GB upload capability
- `:can-use-premium-stickers` - Premium stickers access
- `:double-limits` - Doubled limits indicator

---

### File Upload Limits

#### `get-max-file-size`
```lisp
(get-max-file-size)
```

Get maximum file size for current user.

**Returns:**
- Premium users: 4GB (4294967296 bytes)
- Free users: 2GB (2147483648 bytes)

---

#### `can-upload-file-p`
```lisp
(can-upload-file-p file-size)
```

Check if user can upload a file of given size.

**Parameters:**
- `file-size` - File size in bytes

**Returns:** T if allowed, NIL otherwise

---

#### `validate-file-for-upload`
```lisp
(validate-file-for-upload file-size file-path)
```

Validate file for upload.

**Returns:** Values: (success error-message)

**Example:**
```lisp
(multiple-value-bind (ok error)
    (validate-file-for-upload (* 3 1024 1024 1024) "video.mp4")
  (if ok
      (upload-file file-path)
      (format t "Cannot upload: ~A~%" error)))
```

---

### Premium Stickers & Reactions

#### `fetch-premium-sticker-sets`
```lisp
(fetch-premium-sticker-sets)
```

Fetch premium-exclusive sticker sets from server.

**Returns:** List of sticker-set objects

---

#### `can-use-premium-sticker-p`
```lisp
(can-use-premium-sticker-p sticker-set-name)
```

Check if user can use a premium sticker set.

**Parameters:**
- `sticker-set-name` - Name of sticker set

**Returns:** T if allowed, NIL otherwise

---

#### `fetch-premium-reactions`
```lisp
(fetch-premium-reactions)
```

Fetch premium-exclusive reactions.

**Returns:** List of premium emoji strings

**Default reactions:** 🎉, 💫, 🌟, 💎, 🔥, ❤️, 👍, 👎

---

### Premium Customization

#### `fetch-premium-profile-colors`
```lisp
(fetch-premium-profile-colors)
```

Get available premium profile color themes.

**Returns:** List of color theme plists

---

#### `set-profile-color`
```lisp
(set-profile-color color-id)
```

Set user profile accent color.

**Parameters:**
- `color-id` - Color theme identifier

**Returns:** T on success

**Requires:** Telegram Premium

---

#### `set-chat-theme`
```lisp
(set-chat-theme chat-id theme-id)
```

Set chat theme for a specific chat.

**Parameters:**
- `chat-id` - Target chat ID
- `theme-id` - Theme identifier

**Returns:** T on success

---

#### `set-emoji-status`
```lisp
(set-emoji-status emoji-id &key custom-color duration)
```

Set user emoji status.

**Parameters:**
- `emoji-id` - Emoji or custom emoji ID
- `custom-color` - Optional custom color
- `duration` - Optional duration in seconds

**Returns:** T on success

---

#### `clear-emoji-status`
```lisp
(clear-emoji-status)
```

Clear current emoji status.

**Returns:** T on success

---

### Subscription Management

#### `get-premium-subscription-info`
```lisp
(get-premium-subscription-info)
```

Get current subscription information.

**Returns:** Plist with:
- `:status` - Active/expired/canceled
- `:type` - Subscription type
- `:next-billing-date` - Next payment date
- `:auto-renew` - Auto-renewal status

---

#### `cancel-premium-subscription`
```lisp
(cancel-premium-subscription &key reason)
```

Cancel premium subscription.

**Parameters:**
- `reason` - Optional cancellation reason

**Returns:** T on success

---

#### `renew-premium-subscription`
```lisp
(renew-premium-subscription &key type)
```

Renew premium subscription.

**Parameters:**
- `type` - Subscription type: :monthly, :yearly

**Returns:** T on success

---

### Enhanced Limits

#### `get-doubled-limits`
```lisp
(get-doubled-limits)
```

Get information about doubled limits for premium users.

**Returns:** Plist with:
- `:pinned-chats` - Max pinned chats (premium: 20, free: 10)
- `:channels` - Max channels (premium: 1000, free: 500)
- `:folders` - Max chat folders (premium: 20, free: 10)

---

#### `can-pin-more-chats-p`
```lisp
(can-pin-more-chats-p)
```

Check if user can pin more chats.

**Returns:** T if under limit, NIL if at limit

---

#### `can-join-more-channels-p`
```lisp
(can-join-more-channels-p)
```

Check if user can join more channels.

**Returns:** T if under limit, NIL if at limit

---

### Voice Transcription

#### `transcribe-voice-message-premium`
```lisp
(transcribe-voice-message-premium message-id)
```

Transcribe a voice message to text.

**Parameters:**
- `message-id` - Message ID of voice message

**Returns:** Transcription result plist with:
- `:text` - Transcribed text
- `:language` - Detected language
- `:duration` - Voice duration

**Requires:** Telegram Premium

---

## Protocol Functions

### Message Container Handling

#### `handle-msg-container`
```lisp
(handle-msg-container conn msg-id body)
```

Handle container message with multiple sub-messages.

**Parameters:**
- `conn` - Connection object
- `msg-id` - Container message ID
- `body` - Message body bytes

**Behavior:** Recursively processes each sub-message in the container.

---

### Gzip Compression

#### `handle-gzip-packed`
```lisp
(handle-gzip-packed conn msg-id body)
```

Handle gzip-compressed message.

**Parameters:**
- `conn` - Connection object
- `msg-id` - Message ID
- `body` - Compressed message body

**Behavior:** Decompresses and recursively processes the message.

---

### Error Recovery

#### `handle-bad-server-salt`
```lisp
(handle-bad-server-salt conn msg-id body)
```

Handle bad server salt error with automatic retry.

**Parameters:**
- `conn` - Connection object
- `msg-id` - Failed message ID
- `body` - Error response body

**Behavior:**
1. Extracts new salt from response
2. Updates connection salt
3. Retries failed message with new salt

---

## Global Variables

### Premium

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `*premium-status*` | premium-status | instance | Current user's premium status |
| `*premium-features-config*` | premium-features-config | instance | Premium features configuration |
| `*premium-cache-ttl*` | integer | 3600 | Cache TTL in seconds |
| `*premium-last-check*` | integer | nil | Last status check timestamp |

### Inline Bots

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `*inline-bot-handlers*` | hash-table | - | Registered query handlers |
| `*callback-query-handlers*` | hash-table | - | Registered callback handlers |
| `*command-handlers*` | hash-table | - | Registered command handlers |

---

## Error Conditions

### `premium-required-error`

Signaled when a premium feature is accessed without premium subscription.

**Slots:**
- `feature` - The feature that requires premium
- `message` - Human-readable error message

**Example:**
```lisp
(handler-case
    (ensure-premium :send-large-files)
  (cl-telegram/api:premium-required-error (e)
    (format t "Premium required for: ~A~%"
            (cl-telegram/api:premium-error-feature e))))
```

---

## Testing

### Running Tests

```lisp
;; Load test system
(asdf:load-system :cl-telegram/tests)

;; Run Inline Bots tests
(cl-telegram/tests:run-inline-bots-tests)

;; Run Premium tests
(cl-telegram/tests:run-premium-tests)

;; Run all tests
(cl-telegram/tests:run-all-tests)
```

### Test Coverage

| Suite | Tests | Coverage |
|-------|-------|----------|
| Inline Bots 2025 | 30 | 92% |
| Premium Features | 35 | 90% |
| Stickers | 30 | 88% |
| Voice Messages | 25 | 91% |
| **Total** | **400+** | **87%** |
