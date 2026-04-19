# Bot Inline Mode 2025 Documentation

## Overview

Enhanced inline bot functionality with support for Bot API 7.4-9.1 features including visual effects, business integration, paid media, and WebApp enhancements.

## Table of Contents

- [Visual Effects](#visual-effects)
- [Business Features](#business-features)
- [Paid Media](#paid-media)
- [WebApp Integration](#webapp-integration)
- [Enhanced Results](#enhanced-results)
- [Examples](#examples)

---

## Visual Effects (Bot API 7.4+)

### Visual Effect Class

```lisp
(defclass inline-result-visual-effect ()
  ((effect-type :initarg :effect-type :reader visual-effect-type)
   (start-coordinate-x :initarg :start-x :reader visual-effect-start-x)
   (start-coordinate-y :initarg :start-y :reader visual-effect-start-y)
   (end-coordinate-x :initarg :end-x :reader visual-effect-end-x)
   (end-coordinate-y :initarg :end-y :reader visual-effect-end-y)
   (intensity :initarg :intensity :reader visual-effect-intensity)))
```

### Available Effects

| Effect | Keyword | Description |
|--------|---------|-------------|
| Fireworks | `:fireworks` | Animated fireworks display |
| Sparkles | `:sparkles` | Sparkling particle effect |
| Hearts | `:hearts` | Floating hearts animation |
| Stars | `:stars` | Twinkling stars |
| Balloons | `:balloons` | Rising balloons |

### Create Visual Effect

```lisp
(make-visual-effect effect-type &key start-x start-y end-x end-y intensity)
```

**Parameters:**
- `effect-type` - Effect keyword
- `start-x` - Start X coordinate (0.0-1.0)
- `start-y` - Start Y coordinate (0.0-1.0)
- `end-x` - End X coordinate (0.0-1.0)
- `end-y` - End Y coordinate (0.0-1.0)
- `intensity` - Effect intensity (0.0-1.0)

**Example:**
```lisp
;; Create fireworks effect
(let ((effect (make-visual-effect :fireworks
                                   :start-x 0.5
                                   :start-y 0.5
                                   :intensity 1.0)))
  ;; Add to inline result
  (add-visual-effects-to-result my-result (list effect)))
```

### Add Effects to Result

```lisp
(add-visual-effects-to-result inline-result visual-effects &key animation-type)
```

**Parameters:**
- `inline-result` - Base inline result
- `visual-effects` - List of visual effects
- `animation-type` - Optional animation type

### Check for Effects

```lisp
(inline-result-has-effects-p result)
```

Returns `T` if result has visual effects.

### Apply Effect to Result

```lisp
(apply-visual-effect-to-result result effect)
```

Add single visual effect to existing result.

---

## Business Features (Bot API 9.0+)

### Business Inline Config

```lisp
(defclass business-inline-config ()
  ((business-location :reader business-location)
   (business-opening-hours :reader business-hours)
   (business-start-message :reader business-start-message)
   (business-can-send-paid-media :accessor business-can-send-paid-media)))
```

### Create Business Config

```lisp
(make-business-inline-config &key location opening-hours start-message)
```

**Parameters:**
- `location` - Business location object
- `opening-hours` - Opening hours object
- `start-message` - Custom greeting message

**Example:**
```lisp
(make-business-inline-config 
  :location (make-location 51.5074 -0.1278)
  :opening-hours "Mon-Fri 9:00-18:00"
  :start-message "Welcome to our business!")
```

### Get Business Connection

```lisp
(get-business-connection business-connection-id)
```

Returns business connection information.

### Get User Chat Boosts

```lisp
(get-user-chat-boosts user-id)
```

Get list of chat boosts for a user.

---

## Paid Media

### Paid Media Info Class

```lisp
(defclass paid-media-info ()
  ((media-type :initarg :media-type :reader paid-media-type)
   (media-url :initarg :media-url :reader paid-media-url)
   (price-amount :initarg :price :reader paid-media-price)
   (price-currency :initarg :currency :reader paid-media-currency)
   (is-paid :accessor paid-media-is-paid)))
```

### Media Types

| Type | Keyword | Description |
|------|---------|-------------|
| Photo | `:photo` | Single photo |
| Video | `:video` | Short video preview |

### Create Paid Media Info

```lisp
(make-paid-media-info media-type media-url price currency)
```

**Parameters:**
- `media-type` - `:photo` or `:video`
- `media-url` - URL of media content
- `price` - Price in smallest currency units
- `currency` - Currency code (USD, EUR, etc.)

**Example:**
```lisp
;; Create $4.99 paid media
(make-paid-media-info :photo 
                       "https://example.com/premium.jpg"
                       499  ; $4.99
                       "USD")
```

### Send Paid Media

```lisp
(send-paid-media chat-id media-info &key caption parse-mode)
```

**Parameters:**
- `chat-id` - Chat identifier
- `media-info` - Paid-media-info object
- `caption` - Optional caption
- `parse-mode` - Parse mode (`:html` or `:markdown`)

**Example:**
```lisp
(let ((paid-media (make-paid-media-info :photo url 999 "USD")))
  (send-paid-media chat-id paid-media
                   :caption "Premium content! ✨"
                   :parse-mode :html))
```

---

## WebApp Integration (Bot API 9.1+)

### WebApp Inline Button

```lisp
(defclass web-app-inline-button ()
  ((text :initarg :text :reader webapp-button-text)
   (web-app-url :initarg :url :reader webapp-button-url)
   (forward-text :initarg :forward-text :reader webapp-forward-text)
   (button-type :initarg :type :reader webapp-button-type)))
```

### Button Types

| Type | Keyword | Use Case |
|------|---------|----------|
| Standard | `:standard` | General WebApp |
| Purchase | `:purchase` | Buy products |
| Book | `:book` | Booking services |
| Vote | `:vote` | Polls/voting |

### Create WebApp Button

```lisp
(make-webapp-inline-button text url &key forward-text button-type)
```

**Parameters:**
- `text` - Button display text
- `url` - WebApp URL
- `forward-text` - Text when forwarding to chat
- `button-type` - Button type keyword

**Example:**
```lisp
(make-webapp-inline-button "Shop Now"
                            "https://shop.example.com"
                            :forward-text "Check out this product!"
                            :button-type :purchase)
```

---

## Inline Query Context

### Context Class

```lisp
(defclass inline-query-context ()
  ((switch-pm-parameter :reader context-switch-pm-param)
   (switch-pm-text :reader context-switch-pm-text)
   (gallery-layout :reader context-gallery-layout)
   (personal-results :reader context-personal-results)))
```

### Create Context

```lisp
(make-inline-query-context &key switch-pm-param switch-pm-text gallery-layout personal)
```

**Parameters:**
- `switch-pm-param` - Parameter for switch to PM button
- `switch-pm-text` - Switch button text
- `gallery-layout` - `:vertical` or `:horizontal`
- `personal` - Whether results are personal

**Example:**
```lisp
(make-inline-query-context 
  :switch-pm-text "Open in chat"
  :switch-pm-param "start"
  :gallery-layout :horizontal
  :personal t)
```

---

## Enhanced Result Types

### Story Inline Result

```lisp
(make-inline-result-story id story-url &key thumbnail-url title description)
```

**Parameters:**
- `id` - Unique result ID
- `story-url` - URL to the story
- `thumbnail-url` - Thumbnail URL
- `title` - Story title
- `description` - Story description

### Giveaway Inline Result

```lisp
(make-inline-result-giveaway chat-ids prize-description 
                              &key winner-count until-date has-public-winners)
```

**Parameters:**
- `chat-ids` - List of chat IDs for giveaway
- `prize-description` - Description of prize
- `winner-count` - Number of winners (default: 1)
- `until-date` - Giveaway end date
- `has-public-winners` - Whether winners are public

**Example:**
```lisp
(make-inline-result-giveaway 
  '(123456 789012)
  "iPhone 15 Pro"
  :winner-count 3
  :until-date (+ (get-universal-time) (* 7 24 60 60))
  :has-public-winners t)
```

### Result with Spoiler

```lisp
(make-inline-result-with-spoiler result-type id &key media-url thumb-url caption spoiler-text)
```

**Parameters:**
- `result-type` - `:photo`, `:video`, `:gif`, `:mpeg4`
- `id` - Unique result ID
- `media-url` - URL of media file
- `thumb-url` - Thumbnail URL
- `caption` - Media caption
- `spoiler-text` - Spoiler text overlay

**Example:**
```lisp
(make-inline-result-with-spoiler :photo "unique-id-123"
                                  :media-url "https://example.com/surprise.jpg"
                                  :caption "Click to reveal!"
                                  :spoiler-text "🎁 Surprise inside!")
```

### Extended Media Result

```lisp
(make-inline-result-extended-media result-type id media-url 
                                    &key width height duration supports-streaming)
```

**Parameters:**
- `result-type` - `:photo`, `:video`, `:gif`
- `id` - Unique result ID
- `media-url` - URL of media
- `width` - Media width in pixels
- `height` - Media height in pixels
- `duration` - Duration in seconds (for video)
- `supports-streaming` - Whether video supports streaming

---

## Enhanced Answer Function

### `answer-inline-query-extended`

```lisp
(answer-inline-query-extended query-id results 
                               &key cache-time is-personal next-offset 
                               switch-pm-text switch-pm-parameter 
                               button-type context)
```

**Parameters:**
- `query-id` - Inline query ID
- `results` - List of inline results (can include visual effects)
- `cache-time` - Cache time in seconds (default: 300)
- `is-personal` - Whether results are personal
- `next-offset` - Offset for pagination
- `switch-pm-text` - Switch to PM button text
- `switch-pm-parameter` - Switch button parameter
- `button-type` - Optional button type
- `context` - Inline query context object

**Example:**
```lisp
(answer-inline-query-extended query-id results
                               :cache-time 600
                               :is-personal t
                               :switch-pm-text "Open in private chat"
                               :switch-pm-parameter "inline"
                               :context (make-inline-query-context 
                                          :gallery-layout :horizontal))
```

---

## Utilities

### Get Enhanced Features

```lisp
(get-enhanced-inline-features)
```

Returns plist of available enhanced features:
- `:visual-effects` - Visual effects support
- `:business-features` - Business integration
- `:paid-media` - Paid media support
- `:webapp-enhanced` - Enhanced WebApp
- `:stories` - Story results
- `:giveaways` - Giveaway results

---

## Complete Examples

### Visual Effects Gallery

```lisp
(defun create-effects-gallery ()
  "Create gallery of inline results with visual effects"
  (let ((effects nil))
    ;; Add fireworks effect
    (push (make-visual-effect :fireworks :intensity 1.0) effects)
    ;; Add sparkles
    (push (make-visual-effect :sparkles :start-x 0.3 :start-y 0.7) effects)
    
    ;; Create results with effects
    (let ((result (make-inline-result-photo "1" "https://example.com/photo.jpg"
                                             "https://example.com/thumb.jpg"
                                             :title "Beautiful Photo")))
      (add-visual-effects-to-result result effects :animation-type :fade-in))))
```

### Business Bot Flow

```lisp
(defun handle-business-inline-query (query)
  "Handle inline query for business bot"
  (let* ((business-config (make-business-inline-config 
                            :location (make-location 51.5074 -0.1278)
                            :opening-hours "9:00-18:00"
                            :start-message "Welcome!"))
         (paid-media (make-paid-media-info :photo "https://example.com/product.jpg"
                                            2999  ; $29.99
                                            "USD"))
         (webapp-btn (make-webapp-inline-button "View Product"
                                                 "https://shop.example.com"
                                                 :button-type :purchase)))
    ;; Return results
    (list :config business-config
          :paid-media paid-media
          :webapp-button webapp-btn)))
```

### Giveaway Bot

```lisp
(defun create-giveaway-inline ()
  "Create giveaway inline results"
  (let ((giveaway (make-inline-result-giveaway 
                    '(111111 222222 333333)
                    "MacBook Pro M3"
                    :winner-count 1
                    :until-date (+ (get-universal-time) (* 14 24 60 60))
                    :has-public-winners t)))
    (answer-inline-query-extended "query-id" (list giveaway)
                                   :switch-pm-text "Join Giveaway"
                                   :switch-pm-parameter "join")))
```

---

## Bot API Version Compatibility

| Feature | Minimum Version |
|---------|-----------------|
| Visual Effects | Bot API 7.4 |
| Business Features | Bot API 9.0 |
| Paid Media | Bot API 9.0 |
| WebApp Enhanced | Bot API 9.1 |
| Story Results | Bot API 9.0 |
| Giveaways | Bot API 9.0 |

---

## See Also

- [Bot API Changelog](https://core.telegram.org/bots/api-changelog)
- [Inline Bots Guide](https://core.telegram.org/bots/inline)
- [WebApp Documentation](https://core.telegram.org/bots/webapps)
- [API Reference](API_REFERENCE.md#inline-bots)
