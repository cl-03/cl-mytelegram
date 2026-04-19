# Real-time Notifications Guide

## Overview

cl-telegram v0.14.0+ includes a comprehensive real-time notification system with:

- **WebSocket Client** for persistent server connections
- **Desktop Notifications** for new messages and events
- **Cross-platform support** (Windows, macOS, Linux)
- **Quiet hours** and notification management
- **Notification history** tracking

## Table of Contents

1. [WebSocket Client](#websocket-client)
2. [Desktop Notifications](#desktop-notifications)
3. [Notification Settings](#notification-settings)
4. [Integration with Update Handler](#integration-with-update-handler)
5. [Examples](#examples)

---

## WebSocket Client

### Enable Real-time Updates

```lisp
(use-package :cl-telegram/api)

;; Enable WebSocket connection for real-time updates
(enable-realtime-updates
 :server-url "wss://telegram.org/ws"
 :on-notification (lambda (type data)
                    (format t "Notification: ~A - ~A~%" type data)))
```

### WebSocket Client Creation

```lisp
(use-package :cl-telegram/network)

;; Create WebSocket client
(let ((client (make-websocket-client
               "wss://telegram.org/ws"
               :on-message (lambda (client message)
                             (format t "Received: ~A~%" message))
               :on-connect (lambda (client)
                             (format t "Connected!~%"))
               :on-error (lambda (client error)
                             (format t "Error: ~A~%" error))
               :on-close (lambda (client code reason)
                             (format t "Closed: ~A - ~A~%" code reason)))))
  ;; Connect
  (connect-websocket client)

  ;; Send message
  (send-websocket-message client "Hello, Server!" :type :text)

  ;; Get stats
  (let ((stats (websocket-stats client)))
    (format t "Connected: ~A~%" (getf stats :connected))
    (format t "Messages: ~A~%" (getf stats :messages-received))))
```

### Close Connection

```lisp
;; Disable real-time updates
(disable-realtime-updates)
```

---

## Desktop Notifications

### Initialize Notification System

```lisp
(use-package :cl-telegram/api)

;; Initialize notification manager
(initialize-notifications)
```

### Send Notification

```lisp
;; Basic notification
(send-notification "New Message" "Hello from Telegram!")

;; With type and options
(send-notification "Incoming Call" "John is calling..."
                   :type :call
                   :icon "/path/to/icon.png"
                   :sound-p t
                   :badge-p t)

;; Mention notification
(send-notification "You were mentioned" "Alice mentioned you in Group"
                   :type :mention)
```

### Notification Types

| Type | Description | Sound |
|------|-------------|-------|
| `:message` | New text message | message.wav |
| `:call` | Incoming call | call.wav |
| `:mention` | You were mentioned | mention.wav |
| `:reaction` | Reaction to your message | reaction.wav |
| `:system` | System notification | default.wav |

---

## Notification Settings

### Quiet Hours

```lisp
;; Set quiet hours (10 PM to 7 AM)
(set-quiet-hours 22 7)

;; Disable quiet hours
(disable-quiet-hours)
```

### Enable/Disable Notifications

```lisp
;; Get manager
(let ((mgr cl-telegram/api:*notification-manager*))
  ;; Disable all notifications
  (setf (notif-enabled-p mgr) nil)

  ;; Disable sound only
  (setf (notif-sound-enabled-p mgr) nil)

  ;; Disable badge updates
  (setf (notif-badge-enabled-p mgr) nil))
```

### Notification History

```lisp
;; Get recent notifications
(let ((history (get-notification-history :limit 50)))
  (dolist (entry history)
    (format t "~A: ~A - ~A~%"
            (getf entry :type)
            (getf entry :title)
            (getf entry :message))))

;; Get notifications by type
(let ((mentions (get-notification-history :type :mention)))
  (format t "You have ~A mention notifications~%" (length mentions)))

;; Clear history
(clear-notification-history)
```

### Notification Preview

```lisp
;; Test notification with preview
(show-notification-preview :message)
(show-notification-preview :call)
(show-notification-preview :mention)
```

---

## Integration with Update Handler

### Setup Automatic Notifications

```lisp
;; Setup notification handlers for update events
(setup-notification-handlers)

;; This registers handlers for:
;; - :update-new-message - New message notifications
;; - :update-new-call - Call notifications
;; - :update-message-mention - Mention notifications
;; - :update-message-reaction - Reaction notifications
```

### Custom Notification Handler

```lisp
(register-update-handler :update-new-message
  (lambda (update)
    (let* ((message (getf update :message))
           (from (getf message :from))
           (chat-id (getf message :chat-id))
           (text (getf message :text)))
      ;; Only notify for non-self messages
      (unless (eq (getf from :id) *my-user-id*)
        (send-notification
         (format nil "Message from ~A" (getf from :first-name))
         (or text "[non-text message]")
         :type :message)))))
```

---

## Platform-Specific Notes

### Windows

- Uses PowerShell toast notifications
- Sound played via Media.SoundPlayer
- Badge updates require UWP app

### macOS

- Uses `osascript` for native notifications
- Sound played via `afplay`
- Dock badge updates supported

### Linux

- Uses `notify-send` for notifications
- Sound played via `paplay` (PulseAudio)
- Dock badge requires D-Bus integration

---

## Complete Example

```lisp
;; Load system
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Initialize notifications
(initialize-notifications)

;; Setup quiet hours (optional)
(set-quiet-hours 23 7)  ; 11 PM to 7 AM

;; Connect to WebSocket for real-time updates
(enable-realtime-updates
 :server-url "wss://telegram.org/ws"
 :on-notification (lambda (type data)
                    (format t "Real-time update: ~A~%" type)))

;; Setup automatic notification handlers
(setup-notification-handlers)

;; Register custom handler for important chats
(register-update-handler :update-new-message
  (lambda (update)
    (let* ((message (getf update :message))
           (chat-id (getf message :chat-id)))
      ;; High priority for specific chats
      (when (member chat-id *important-chat-ids*)
        (send-notification
         "Important Message"
         (getf message :text)
         :type :message
         :sound-p t)))))

;; Your application continues...
(format t "Notifications enabled!~%")
```

---

## Troubleshooting

### Notifications Not Showing

1. Check if notifications are enabled:
   ```lisp
   (notif-enabled-p cl-telegram/api:*notification-manager*)
   ```

2. Check quiet hours:
   ```lisp
   (in-quiet-hours-p cl-telegram/api:*notification-manager*)
   ```

3. Test with fallback:
   ```lisp
   (send-fallback-notification "Test" "Test message")
   ```

### WebSocket Not Connecting

1. Check server URL format:
   - Secure: `wss://server.com/path`
   - Non-secure: `ws://server.com/path`

2. Check network connectivity:
   ```lisp
   (let ((client (make-websocket-client "ws://localhost:8080")))
     (connect-websocket client :timeout 10))
   ```

3. View stats:
   ```lisp
   (websocket-stats cl-telegram/network:*websocket-update-handler*)
   ```

### Sound Not Playing

1. Check sound setting:
   ```lisp
   (notif-sound-enabled-p cl-telegram/api:*notification-manager*)
   ```

2. Verify sound files exist in application directory

---

## API Reference

### WebSocket Functions

| Function | Description |
|----------|-------------|
| `make-websocket-client` | Create WebSocket client |
| `connect-websocket` | Connect to server |
| `close-websocket` | Close connection |
| `send-websocket-message` | Send message |
| `websocket-stats` | Get statistics |
| `enable-realtime-updates` | Enable push notifications |
| `disable-realtime-updates` | Disable push notifications |

### Notification Functions

| Function | Description |
|----------|-------------|
| `initialize-notifications` | Initialize notification system |
| `send-notification` | Send desktop notification |
| `set-quiet-hours` | Set quiet hours |
| `disable-quiet-hours` | Disable quiet hours |
| `get-notification-history` | Get notification history |
| `clear-notification-history` | Clear history |
| `show-notification-preview` | Show test notification |
| `setup-notification-handlers` | Setup update handlers |

---

**Version:** v0.14.0  
**Last Updated:** April 2026
