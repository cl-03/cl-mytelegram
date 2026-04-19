# Group Management Guide

## Overview

cl-telegram v0.14.0+ includes comprehensive group and channel management features:

- **Administrator Permissions** - Fine-grained control with bitmask encoding
- **Member Management** - Ban, unban, restrict members with duration support
- **Invite Links** - Create, revoke, and track invite links with limits
- **Polls & Voting** - Anonymous and multiple-choice polls
- **Auto-Moderation** - Configurable rules engine
- **Member Approval** - Review and approve join requests
- **Group Statistics** - Activity tracking and admin logs

## Table of Contents

1. [Administrator Permissions](#administrator-permissions)
2. [Member Management](#member-management)
3. [Invite Links](#invite-links)
4. [Polls and Voting](#polls-and-voting)
5. [Auto-Moderation](#auto-moderation)
6. [Member Approval](#member-approval)
7. [Group Statistics](#group-statistics)

---

## Administrator Permissions

### Create Admin Permissions

```lisp
(use-package :cl-telegram/api)

;; Create permissions with specific rights
(let ((perms (make-admin-permissions
              :change-info t
              :delete-messages t
              :invite-users t
              :restrict-members t
              :pin-messages t)))
  ;; Use permissions...
  )

;; All available options
(make-admin-permissions
 :change-info          ; Can change chat info (title, photo, etc.)
 :post-messages        ; Can post messages (channels)
 :edit-messages        ; Can edit any messages
 :delete-messages      ; Can delete any messages
 :invite-users         ; Can invite new users
 :restrict-members     ; Can restrict/ban members
 :pin-messages         ; Can pin/unpin messages
 :promote-members      ; Can add new administrators
 :manage-voice-chats   ; Can manage voice chats
 :manage-topics)       ; Can manage forum topics
```

### Permission Bitmask

```lisp
;; Convert permissions to bitmask for API
(let ((perms (make-admin-permissions :delete-messages t :invite-users t)))
  (permissions-to-bitmask perms)) ; => 24

;; Convert bitmask back to permissions
(let ((bitmask 24)
      (perms (bitmask-to-permissions bitmask)))
  (group-admin-permissions-can-delete-messages perms)) ; => T
```

### Set Administrator

```lisp
;; Grant admin rights
(set-chat-administrator
 chat-id
 user-id
 (make-admin-permissions
  :delete-messages t
  :invite-users t
  :restrict-members t)
 :custom-title "Moderator") ; Optional custom title

;; Remove admin rights
(remove-chat-administrator chat-id user-id)

;; Get list of administrators
(let ((admins (get-chat-administrators chat-id)))
  (dolist (admin admins)
    (format t "Admin: ~A~%" (getf admin :user-id))))
```

---

## Member Management

### Ban/Unban Members

```lisp
;; Ban user permanently
(ban-chat-member chat-id user-id)

;; Ban user for specific duration (in seconds)
(ban-chat-member chat-id user-id :duration 3600) ; 1 hour

;; Ban until specific date (Unix timestamp)
(ban-chat-member chat-id user-id :until-date 1713542400)

;; Unban user
(unban-chat-member chat-id user-id)
```

### Restrict Members

```lisp
;; Create restrictions
(let ((restrictions (make-member-restrictions
                     :send-messages nil      ; Cannot send messages
                     :send-media t           ; Can send media
                     :send-polls t           ; Can send polls
                     :add-web-page-previews nil))) ; No link previews
  ;; Apply restrictions
  (restrict-chat-member chat-id user-id restrictions))

;; All restriction options
(make-member-restrictions
 :send-messages          ; Can send text messages
 :send-media             ; Can send photos/videos
 :send-polls             ; Can send polls
 :send-other-messages    ; Can send other message types
 :add-web-page-previews  ; Can add link previews
 :change-chat-info       ; Can change chat info
 :invite-users           ; Can invite users
 :pin-messages)          ; Can pin messages
```

---

## Invite Links

### Create Invite Link

```lisp
;; Basic invite link
(let ((result (create-chat-invite-link chat-id)))
  (format t "Invite link: ~A~%" (getf result :link)))

;; With usage limit
(create-chat-invite-link chat-id :usage-limit 100)

;; With expiration (seconds from now)
(create-chat-invite-link chat-id :expire-seconds 86400) ; 24 hours

;; With custom name
(create-chat-invite-link chat-id :name "VIP Group Link")
```

### Manage Invite Links

```lisp
;; Get existing invite link
(let ((link (get-chat-invite-link chat-id)))
  (when link
    (format t "Current link: ~A~%" link)))

;; Revoke invite link
(revoke-chat-invite-link chat-id link)

;; Get link members
(let ((members (get-chat-invite-link-members chat-id link :limit 50)))
  (format t "~A users joined via this link~%" (length members)))
```

---

## Polls and Voting

### Create Poll

```lisp
;; Simple anonymous poll
(let ((poll (make-poll
             "What's your favorite language?"
             '("Common Lisp" "Python" "Rust" "Go")
             :anonymous t)))
  (send-poll chat-id poll))

;; Non-anonymous poll
(let ((poll (make-poll
             "Team selection"
             '("Team Alpha" "Team Beta" "Team Gamma")
             :anonymous nil)))
  (send-poll chat-id poll))

;; Multiple choice poll
(let ((poll (make-poll
             "Select your interests"
             '("AI/ML" "Web Dev" "Systems" "Data Science")
             :multiple-choice t)))
  (send-poll chat-id poll))

;; Poll with time limit (seconds)
(let ((poll (make-poll
             "Quick vote"
             '("Yes" "No" "Maybe")
             :open-period 300))) ; 5 minutes
  (send-poll chat-id poll))
```

### Stop Poll

```lisp
;; Stop poll manually
(stop-poll chat-id message-id)
```

---

## Auto-Moderation

### Add Moderation Rules

```lisp
;; Keyword filter
(add-auto-mod-rule
 chat-id
 :keyword           ; Rule type
 "spam"             ; Pattern to match
 :delete)           ; Action: delete/warn/ban/mute

;; Link filter
(add-auto-mod-rule
 chat-id
 :link
 "http://spam.com"
 :ban
 :exceptions '(123 456)) ; User IDs exempt from rule

;; Spam detection (flood control)
(add-auto-mod-rule
 chat-id
 :spam
 "flood"
 :mute)

;; Flood detection
(add-auto-mod-rule
 chat-id
 :flood
 "rapid"
 :warn)
```

### Manage Rules

```lisp
;; Get all rules for a chat
(let ((rules (get-auto-mod-rules chat-id)))
  (dolist (rule rules)
    (format t "Rule: ~A -> ~A~%"
            (getf rule :type)
            (getf rule :action))))

;; Remove rule by index
(remove-auto-mod-rule chat-id 2)
```

### Rule Types

| Type | Description | Actions |
|------|-------------|---------|
| `:keyword` | Match specific text | delete, warn, ban, mute |
| `:link` | Match URLs | delete, warn, ban |
| `:spam` | Detect spam patterns | delete, mute, ban |
| `:flood` | Detect rapid messages | warn, mute |

---

## Member Approval

### Enable/Disable Approval Mode

```lisp
;; Enable member approval (require admin approval for new members)
(enable-member-approval chat-id)

;; Disable member approval
(disable-member-approval chat-id)
```

### Review Join Requests

```lisp
;; Get pending join requests
(let ((requests (get-pending-join-requests chat-id)))
  (dolist (req requests)
    (format t "User ~A wants to join~%" (getf req :user-id))))

;; Approve join request
(approve-join-request chat-id user-id)

;; Decline join request
(decline-join-request chat-id user-id)
```

---

## Group Statistics

### Get Group Stats

```lisp
;; Get statistics for date range
(let ((stats (get-group-statistics
              chat-id
              :start-date 1711929600  ; Unix timestamp
              :end-date 1712016000)))
  (format t "New members: ~A~%" (getf stats :new-members))
  (format t "Active members: ~A~%" (getf stats :active-members))
  (format t "Messages sent: ~A~%" (getf stats :messages-sent)))
```

### Get Admin Log

```lisp
;; Get admin action log
(let ((log (get-group-admin-log
            chat-id
            :limit 50
            :event-types '(:ban :unban :add-admin :remove-admin))))
  (dolist (entry log)
    (format t "~A: ~A by ~A~%"
            (getf entry :date)
            (getf entry :action)
            (getf entry :admin-id))))
```

---

## Complete Example

```lisp
;; Load system
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Setup group administration
(defun setup-group-administration (chat-id)
  "Configure group with auto-moderation and admin team"
  
  ;; Add auto-mod rules
  (add-auto-mod-rule chat-id :keyword "spam" :delete)
  (add-auto-mod-rule chat-id :link "http://bad-site.com" :ban)
  (add-auto-mod-rule chat-id :flood "rapid" :warn)
  
  ;; Enable member approval
  (enable-member-approval chat-id)
  
  ;; Create invite link with limit
  (let ((link (create-chat-invite-link chat-id
                                       :usage-limit 50
                                       :expire-seconds 86400)))
    (format t "Invite link: ~A~%" link))
  
  ;; Send welcome poll
  (let ((poll (make-poll
               "Welcome! What brings you here?"
               '("Learning" "Community" "Projects" "Other")
               :anonymous nil)))
    (send-poll chat-id poll))
  
  (format t "Group setup complete!~%"))
```

---

## API Reference

### Administrator Functions

| Function | Description |
|----------|-------------|
| `make-admin-permissions` | Create permissions struct |
| `permissions-to-bitmask` | Convert to API bitmask |
| `bitmask-to-permissions` | Convert from bitmask |
| `get-chat-administrators` | Get admin list |
| `set-chat-administrator` | Add administrator |
| `remove-chat-administrator` | Remove administrator |

### Member Management

| Function | Description |
|----------|-------------|
| `ban-chat-member` | Ban user |
| `unban-chat-member` | Unban user |
| `restrict-chat-member` | Apply restrictions |
| `make-member-restrictions` | Create restrictions |

### Invite Links

| Function | Description |
|----------|-------------|
| `create-chat-invite-link` | Create invite link |
| `get-chat-invite-link` | Get current link |
| `revoke-chat-invite-link` | Revoke link |
| `get-chat-invite-link-members` | Get members who joined via link |

### Polls

| Function | Description |
|----------|-------------|
| `make-poll` | Create poll |
| `send-poll` | Send poll to chat |
| `stop-poll` | Stop active poll |

### Auto-Moderation

| Function | Description |
|----------|-------------|
| `add-auto-mod-rule` | Add moderation rule |
| `remove-auto-mod-rule` | Remove rule |
| `get-auto-mod-rules` | Get all rules |
| `check-auto-mod` | Check message against rules |

### Member Approval

| Function | Description |
|----------|-------------|
| `enable-member-approval` | Enable approval mode |
| `disable-member-approval` | Disable approval |
| `get-pending-join-requests` | Get pending requests |
| `approve-join-request` | Approve request |
| `decline-join-request` | Decline request |

### Statistics

| Function | Description |
|----------|-------------|
| `get-group-statistics` | Get activity stats |
| `get-group-admin-log` | Get admin action log |

---

**Version:** v0.14.0  
**Last Updated:** April 2026
