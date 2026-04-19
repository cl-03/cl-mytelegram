# E2E Encryption Guide

## Overview

cl-telegram v0.14.0+ includes enhanced end-to-end (E2E) encryption for Secret Chats with:

- **Complete DH Key Exchange** - 2048-bit Diffie-Hellman with validation
- **Encrypted Media** - Photos, videos, and documents with separate keys
- **Message TTL** - Self-destructing messages
- **Key Verification** - Fingerprint comparison for man-in-the-middle detection
- **Anti-Screenshot** - Platform-dependent screenshot detection
- **Forwarding Prevention** - Messages cannot be forwarded

## Table of Contents

1. [Creating Secret Chats](#creating-secret-chats)
2. [Key Verification](#key-verification)
3. [Encrypted Media](#encrypted-media)
4. [Message TTL](#message-ttl)
5. [Security Features](#security-features)
6. [API Reference](#api-reference)

---

## Creating Secret Chats

### Initiate Secret Chat

```lisp
(use-package :cl-telegram/api)

;; Create new secret chat with user
(multiple-value-bind (chat error)
    (create-new-secret-chat 123456789 :access-hash 987654321)
  (if chat
      (progn
        (format t "Secret chat created: ~A~%" (secret-chat-id chat))
        (format t "Waiting for acceptance...~%"))
      (format t "Failed: ~A~%" error)))
```

### Accept Secret Chat

```lisp
;; Accept incoming secret chat request
(multiple-value-bind (success error)
    (accept-secret-chat chat-id)
  (if success
      (format t "Secret chat accepted and ready!~%")
      (format t "Failed: ~A~%" error)))
```

### List Secret Chats

```lisp
;; Get all active secret chats
(let ((chats (list-secret-chats)))
  (dolist (chat chats)
    (format t "Chat ~A with user ~A~%"
            (secret-chat-id chat)
            (secret-participant-id chat))))

;; Get secret chat with specific user
(let ((chat (get-secret-chat-with-user 123456789)))
  (when chat
    (format t "Found secret chat: ~A~%" (secret-chat-id chat))))
```

---

## Key Verification

### Get Visual Fingerprint

```lisp
;; Get fingerprint as hex string for comparison
(let ((fingerprint (get-key-fingerprint-visual chat-id)))
  (format t "Key fingerprint: ~A~%" fingerprint)
  ;; Example output: "AB12 CD34 EF56 7890"
  )
```

### Verify Fingerprint

```lisp
;; Verify fingerprint matches (after comparing with other party)
(let ((expected-fingerprint #.(bytes-to-integer #(171 18 205 52 239 86 120 144))))
  (if (verify-key-fingerprint chat-id expected-fingerprint)
      (format t "Keys verified - secure channel confirmed!~%")
      (format t "WARNING: Fingerprint mismatch - possible MITM attack!~%")))
```

### Manual Verification Process

1. Both users call `get-key-fingerprint-visual`
2. Compare fingerprints verbally or via secure channel
3. If matching, keys are verified
4. If mismatch, hang up and retry (possible MITM)

---

## Encrypted Media

### Send Encrypted Photo

```lisp
;; Send photo with optional caption and TTL
(send-encrypted-photo chat-id "/path/to/photo.jpg"
                      :caption "Secret photo"
                      :ttl 60) ; Self-destruct after 60 seconds

;; Handle result
(multiple-value-bind (success error)
    (send-encrypted-photo chat-id "/path/to/photo.jpg")
  (if success
      (format t "Photo sent successfully!~%")
      (format t "Failed: ~A~%" error)))
```

### Send Encrypted Video

```lisp
;; Send video with caption and TTL
(send-encrypted-video chat-id "/path/to/video.mp4"
                      :caption "Secret video"
                      :ttl 300 ; 5 minutes
                      :duration 120) ; Video duration in seconds
```

### Send Encrypted Document

```lisp
;; Send any file as encrypted document
(send-encrypted-document chat-id "/path/to/document.pdf"
                         :caption "Confidential"
                         :ttl 3600) ; 1 hour
```

### Media Encryption Details

Each media file is encrypted with:
- **Random AES-256 key** - Unique per media
- **Random IV** - 32-byte initialization vector
- **Separate thumbnail encryption** - Thumbnail has its own key/IV
- **Keys sent via secure channel** - Encrypted with chat auth_key

---

## Message TTL

### Set Default TTL

```lisp
;; Set TTL for all messages in chat
(set-message-ttl chat-id 60) ; Messages self-destruct after 60 seconds

;; Disable TTL
(set-message-ttl chat-id 0) ; Messages don't auto-destruct
```

### Schedule Individual Message Destruction

```lisp
;; Schedule specific message to self-destruct
(schedule-message-self-destruct message-random-id chat-id 30)
```

### TTL Behavior

- Timer starts when message is **viewed** by recipient
- Message is deleted from **both** devices
- Media files are securely erased
- Cannot be recovered after destruction

---

## Security Features

### Anti-Screenshot

```lisp
;; Enable screenshot detection (notify mode)
(enable-anti-screenshot chat-id :mode :notify)

;; Enable screenshot blocking (attempt to prevent)
(enable-anti-screenshot chat-id :mode :block)

;; Detect screenshot attempt
(when (detect-screenshot-attempt chat-id)
  (format t "WARNING: Screenshot detected!~%")
  ;; Optionally notify other party or delete chat
  )
```

**Platform Support:**

| Platform | Detection | Blocking |
|----------|-----------|----------|
| Windows | Limited | No |
| macOS | Partial | No |
| Linux | Varies | No |
| iOS | Full | Yes |
| Android | Full | Yes |

### Prevent Forwarding

```lisp
;; Mark messages as non-forwardable
(prevent-message-forwarding chat-id '(message-id-1 message-id-2))
```

**Note:** Secret chat messages are inherently non-forwardable by protocol design. This is defense-in-depth.

### Clear Chat History

```lisp
;; Clear all messages in secret chat (both sides)
(clear-secret-chat-history chat-id)
```

### Get Chat Statistics

```lisp
;; Get secret chat stats
(let ((stats (get-secret-chat-stats chat-id)))
  (format t "State: ~A~%" (getf stats :state))
  (format t "Created: ~A~%" (getf stats :created-at))
  (format t "TTL: ~A seconds~%" (getf stats :ttl))
  (format t "Messages sent: ~A~%" (getf stats :messages-sent))
  (format t "Messages received: ~A~%" (getf stats :messages-received)))
```

---

## Cleanup and Maintenance

### Cleanup Expired Chats

```lisp
;; Remove closed chats older than 24 hours
(let ((count (cleanup-expired-secret-chats)))
  (format t "Cleaned up ~A expired secret chats~%" count))
```

### Close Secret Chat

```lisp
;; Close a secret chat
(let ((chat (get-secret-chat chat-id)))
  (when chat
    (close-secret-chat chat)
    (format t "Secret chat closed~%")))
```

---

## Complete Example

```lisp
;; Load system
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Initialize secret chat manager
(defun init-secret-chats ()
  (let ((manager (make-secret-chat-manager *auth-connection*)))
    (setf *secret-chat-manager* manager)))

;; Create and verify secret chat
(defun secure-chat-with-user (user-id access-hash)
  (format t "Creating secret chat...~%")
  (multiple-value-bind (chat error)
      (create-new-secret-chat user-id :access-hash access-hash)
    (if chat
        (progn
          (format t "Chat created. Waiting for acceptance...~%")
          ;; Wait for acceptKey...
          (format t "Chat accepted!~%")
          
          ;; Verify keys
          (let ((fingerprint (get-key-fingerprint-visual (secret-chat-id chat))))
            (format t "Key fingerprint: ~A~%" fingerprint)
            (format t "Please verify this matches the other party's fingerprint~%"))
          
          chat)
        (progn
          (format t "Failed: ~A~%" error)
          nil)))))

;; Send encrypted message with media
(defun send-secure-message (chat-id text &optional photo-path)
  ;; Send text
  (send-secret-message (get-secret-chat chat-id) text :ttl 60)
  
  ;; Send photo if provided
  (when photo-path
    (send-encrypted-photo chat-id photo-path
                          :caption text
                          :ttl 60)))

;; Usage
(init-secret-chats)
(let ((chat (secure-chat-with-user 123456789 987654321)))
  (when chat
    (send-secure-message (secret-chat-id chat) "Hello securely!")
    (send-encrypted-photo (secret-chat-id chat) "/tmp/secret.jpg"
                          :caption "Secret photo"
                          :ttl 60)))
```

---

## Security Considerations

### Best Practices

1. **Always verify fingerprints** - Prevents MITM attacks
2. **Use short TTLs** - Minimize exposure window
3. **Enable anti-screenshot** - Extra layer of protection
4. **Close unused chats** - Reduce attack surface

### Limitations

- Screenshot detection is platform-dependent
- Media thumbnails are lower resolution than originals
- Large files may take time to encrypt/decrypt
- TTL starts on view, not send

### What Secret Chats Protect Against

- Server-side eavesdropping
- Man-in-the-middle attacks (with verification)
- Message interception
- Unauthorized forwarding

### What Secret Chats Don't Protect Against

- Physical device access
- Screen recording (if not detected)
- Network traffic analysis (metadata still visible)
- Compromised client device

---

## API Reference

### Chat Creation

| Function | Description |
|----------|-------------|
| `create-new-secret-chat` | Create new E2E encrypted chat |
| `accept-secret-chat` | Accept incoming chat request |
| `get-secret-chat` | Get chat by ID |
| `get-secret-chat-with-user` | Get chat with specific user |
| `list-secret-chats` | List all active chats |
| `close-secret-chat` | Close a chat |

### Key Verification

| Function | Description |
|----------|-------------|
| `verify-key-fingerprint` | Verify key fingerprint |
| `get-key-fingerprint-visual` | Get visual fingerprint string |

### Encrypted Media

| Function | Description |
|----------|-------------|
| `send-encrypted-photo` | Send encrypted photo |
| `send-encrypted-video` | Send encrypted video |
| `send-encrypted-document` | Send encrypted file |

### TTL & Self-Destruct

| Function | Description |
|----------|-------------|
| `set-message-ttl` | Set default TTL for chat |
| `schedule-message-self-destruct` | Schedule message deletion |
| `clear-secret-chat-history` | Clear all messages |

### Security

| Function | Description |
|----------|-------------|
| `detect-screenshot-attempt` | Detect screenshot |
| `prevent-message-forwarding` | Prevent forwarding |
| `enable-anti-screenshot` | Enable protection |

### Utilities

| Function | Description |
|----------|-------------|
| `get-secret-chat-stats` | Get chat statistics |
| `cleanup-expired-secret-chats` | Remove old chats |

---

**Version:** v0.14.0  
**Last Updated:** April 2026
