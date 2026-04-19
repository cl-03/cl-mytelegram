# Telegram Stories API Documentation

## Overview

The Stories API provides complete support for Telegram Stories, including posting, viewing, highlights, privacy settings, and story interactions. Stories are ephemeral content that expire after 24 hours by default.

## Table of Contents

- [Stories Types](#stories-types)
- [Story Management](#story-management)
- [Story Privacy](#story-privacy)
- [Story Interactions](#story-interactions)
- [Highlights](#highlights)
- [Stories UI](#stories-ui)
- [Examples](#examples)

---

## Stories Types

### Story

```lisp
(defclass story ()
  ((id :initarg :id :reader story-id)
   (owner :initarg :owner :reader story-owner)
   (date :initarg :date :reader story-date)
   (expiration-date :initarg :expiration-date :reader story-expiration-date)
   (media :initarg :media :reader story-media)
   (caption :initarg :caption :reader story-caption)
   (is-pinned :initarg :is-pinned :reader story-is-pinned)
   (privacy :initarg :privacy :reader story-privacy)
   (can-reply :initarg :can-reply :reader story-can-reply)
   (can-reshare :initarg :can-reshare :reader story-can-reshare)
   (views-count :initarg :views-count :reader story-views-count)
   (reactions :initarg :reactions :reader story-reactions)
   (is-viewed :initarg :is-viewed :reader story-is-viewed)
   (is-forwarded :initarg :is-forwarded :reader story-is-forwarded)))
```

**Properties:**
- `story-id` - Unique story identifier
- `story-owner` - User or channel ID who posted the story
- `story-date` - Unix timestamp when story was posted
- `story-expiration-date` - Unix timestamp when story expires
- `story-media` - Media object (photo, video)
- `story-caption` - Optional caption text
- `story-is-pinned` - Whether story is pinned to profile
- `story-privacy` - Privacy settings object
- `story-can-reply` - Whether viewers can reply
- `story-can-reshare` - Whether viewers can reshare
- `story-views-count` - Number of views
- `story-reactions` - List of reactions
- `story-is-viewed` - Whether current user has viewed
- `story-is-forwarded` - Whether story was forwarded

### Story Highlight

```lisp
(defclass story-highlight ()
  ((id :initarg :id :reader highlight-id)
   (title :initarg :title :reader highlight-title)
   (cover-media :initarg :cover-media :reader highlight-cover-media)
   (stories :initarg :stories :reader highlight-stories)
   (date-created :initarg :date-created :reader highlight-date-created)))
```

**Properties:**
- `highlight-id` - Unique highlight identifier
- `highlight-title` - Display title
- `highlight-cover-media` - Cover image/video
- `highlight-stories` - List of stories in highlight
- `highlight-date-created` - Creation timestamp

### Story Privacy

```lisp
(defclass story-privacy ()
  ((type :initarg :type :reader story-privacy-type)
   (allowed-users :initarg :allowed-users :reader story-privacy-allowed)
   (blocked-users :initarg :blocked-users :reader story-privacy-blocked)
   (is-dark :initarg :is-dark :reader story-privacy-is-dark)))
```

**Privacy Types:**
- `:everybody` - Visible to everyone
- `:contacts` - Visible to contacts only
- `:close-friends` - Visible to close friends only
- `:custom` - Custom privacy rules

---

## Story Management

### Posting Stories

#### `post-story`

```lisp
(post-story media &key caption privacy can-reply can-reshare is-pinned)
```

**Parameters:**
- `media` - Media object (photo/video)
- `caption` - Optional caption text
- `privacy` - Privacy setting (default: `:everybody`)
- `can-reply` - Allow replies (default: `t`)
- `can-reshare` - Allow resharing (default: `t`)
- `is-pinned` - Pin to profile (default: `nil`)

**Example:**
```lisp
;; Post a photo story
(post-story my-photo
            :caption "Beautiful sunset!"
            :privacy :contacts
            :is-pinned t)
```

#### `post-story-photo`

```lisp
(post-story-photo photo-file-id &key caption duration)
```

**Parameters:**
- `photo-file-id` - File ID of uploaded photo
- `caption` - Optional caption
- `duration` - Story duration in hours (default: 24)

**Example:**
```lisp
(post-story-photo "AgAD1234..."
                  :caption "New profile pic!"
                  :duration 24)
```

#### `post-story-video`

```lisp
(post-story-video video-file-id &key caption duration)
```

**Parameters:**
- `video-file-id` - File ID of uploaded video
- `caption` - Optional caption
- `duration` - Story duration in hours (default: 24)

### Retrieving Stories

#### `get-stories`

```lisp
(get-stories owner-id &key limit)
```

**Parameters:**
- `owner-id` - User or channel ID
- `limit` - Maximum stories to return (default: 10)

**Example:**
```lisp
(get-stories 123456 :limit 20)
```

#### `get-all-stories`

```lisp
(get-all-stories &key limit)
```

**Parameters:**
- `limit` - Maximum total stories (default: 100)

**Example:**
```lisp
(get-all-stories :limit 50)
```

#### `get-unviewed-stories`

```lisp
(get-unviewed-stories)
```

Returns all unviewed stories from contacts.

#### `get-story-by-id`

```lisp
(get-story-by-id owner-id story-id)
```

**Example:**
```lisp
(get-story-by-id 123456 789012)
```

### Managing Stories

#### `delete-story`

```lisp
(delete-story story-id)
```

Deletes a story permanently.

#### `edit-story`

```lisp
(edit-story story-id &key caption privacy)
```

**Parameters:**
- `story-id` - Story identifier
- `caption` - New caption (optional)
- `privacy` - New privacy setting (optional)

#### `pin-story` / `unpin-story`

```lisp
(pin-story story-id)
(unpin-story story-id)
```

Pin or unpin story to profile.

#### `set-story-privacy`

```lisp
(set-story-privacy privacy-type &key allowed-users blocked-users)
```

**Parameters:**
- `privacy-type` - Privacy type keyword
- `allowed-users` - List of user IDs (for custom privacy)
- `blocked-users` - List of user IDs to exclude

**Example:**
```lisp
;; Set to close friends only
(set-story-privacy :close-friends)

;; Custom privacy - specific users
(set-story-privacy :custom
                   :allowed-users '(111 222 333))
```

---

## Story Interactions

### `mark-story-viewed`

```lisp
(mark-story-viewed story-id)
```

Mark a story as viewed.

### `send-story-reaction`

```lisp
(send-story-reaction story-id emoji)
```

**Parameters:**
- `story-id` - Story identifier
- `emoji` - Reaction emoji

**Example:**
```lisp
(send-story-reaction 789012 "🔥")
```

### `get-story-views`

```lisp
(get-story-views story-id &key limit)
```

Get list of users who viewed the story.

### `get-story-reactions`

```lisp
(get-story-reactions story-id)
```

Get all reactions on a story.

### `forward-story`

```lisp
(forward-story story-id to-chat-id)
```

Forward story to another chat.

### `reply-to-story`

```lisp
(reply-to-story story-id text &key media)
```

Send a reply to a story.

---

## Highlights

### `create-highlight`

```lisp
(create-highlight title &key cover-media story-ids)
```

**Parameters:**
- `title` - Highlight title
- `cover-media` - Cover image/video
- `story-ids` - List of story IDs to include

**Example:**
```lisp
(create-highlight "Travel 2025"
                  :cover-media travel-photo
                  :story-ids '(1 2 3 4 5))
```

### `get-highlights`

```lisp
(get-highlights &key owner-id)
```

Get all highlights for a user.

### `get-highlight`

```lisp
(get-highlight highlight-id)
```

Get specific highlight details.

### `edit-highlight`

```lisp
(edit-highlight highlight-id &key title cover-media)
```

### `add-stories-to-highlight`

```lisp
(add-stories-to-highlight highlight-id story-ids)
```

### `remove-highlight`

```lisp
(remove-highlight highlight-id)
```

Delete highlight permanently.

---

## Stories UI

### Stories Bar

```lisp
(render-stories-bar win container on-click)
```

Renders horizontal stories bar at top of chat UI.

**Parameters:**
- `win` - CLOG window
- `container` - Parent container
- `on-click` - Callback when story clicked

### Stories Viewer

```lisp
(render-stories-viewer win container story on-next on-prev on-close on-react)
```

Full-screen stories viewer with navigation.

**Parameters:**
- `win` - CLOG window
- `container` - Parent container
- `story` - Current story object
- `on-next` - Next story callback
- `on-prev` - Previous story callback
- `on-close` - Close viewer callback
- `on-react` - Send reaction callback

### Highlights List

```lisp
(render-highlights-list win container &key on-click)
```

Renders highlights grid view.

---

## Utilities

### `story-is-expired-p`

```lisp
(story-is-expired-p story)
```

Check if story has expired.

### `story-time-remaining`

```lisp
(story-time-remaining story)
```

Get seconds until story expires.

### `format-story-time`

```lisp
(format-story-time seconds)
```

Format time as human-readable string.

### `cleanup-expired-stories`

```lisp
(cleanup-expired-stories)
```

Automatically remove expired stories from cache.

---

## Examples

### Complete Story Flow

```lisp
;; Post a story
(let ((story (post-story-photo photo-id
                               :caption "Check this out!"
                               :privacy :contacts)))
  ;; Mark as viewed
  (mark-story-viewed (story-id story))
  
  ;; Send reaction
  (send-story-reaction (story-id story) "❤️")
  
  ;; Get views
  (let ((views (get-story-views (story-id story))))
    (format t "Story has ~A views~%" (length views))))
```

### Create Highlight

```lisp
;; Create highlight from existing stories
(create-highlight "Best Moments"
                  :cover-media cover-photo
                  :story-ids '(1 2 3 4 5))

;; Add more stories later
(add-stories-to-highlight highlight-id '(6 7 8))
```

### Stories UI Integration

```lisp
;; Add stories bar to main window
(render-stories-bar *main-window* *sidebar*
                    (lambda (story)
                      (render-stories-viewer *main-window*
                                             *content-area*
                                             story
                                             #'view-next-story
                                             #'view-previous-story
                                             #'close-stories-viewer
                                             #'send-story-reaction)))
```

---

## See Also

- [Premium Features](PREMIUM.md) - Premium story features
- [CLOG UI Guide](CLOG_UI.md) - GUI integration
- [Media Handling](MEDIA.md) - Photo/video upload
