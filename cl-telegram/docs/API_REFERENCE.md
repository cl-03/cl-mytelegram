# cl-telegram API Reference

Complete API documentation for the cl-telegram Telegram client library.

## Table of Contents

1. [Authentication API](#authentication-api)
2. [Messages API](#messages-api)
3. [Chats API](#chats-api)
4. [Users API](#users-api)
5. [Stories API](#stories-api)
6. [Premium Features](#premium-features)
7. [Inline Bots 2025](#inline-bots-2025)
8. [Network Layer](#network-layer)
9. [MTProto Protocol](#mtproto-protocol)
10. [Crypto Primitives](#crypto-primitives)
11. [TL Serialization](#tl-serialization)

---

## New Features (v0.12.0)

### Stories API

Complete Telegram Stories support with posting, viewing, highlights, and privacy controls.

**Key Functions:**
- `post-story`, `post-story-photo`, `post-story-video` - Post stories
- `get-stories`, `get-all-stories`, `get-unviewed-stories` - Retrieve stories
- `mark-story-viewed`, `send-story-reaction` - Interact with stories
- `create-highlight`, `get-highlights` - Manage highlights
- `render-stories-viewer`, `render-stories-bar` - UI components

**Documentation:** [STORIES.md](STORIES.md)

### Premium Features

Telegram Premium integration with enhanced limits and exclusive features.

**Key Functions:**
- `check-premium-status`, `verify-premium-status` - Status checks
- `get-max-file-size`, `can-upload-file-p` - File upload limits
- `get-premium-sticker-sets`, `get-premium-reactions` - Premium content
- `set-profile-color`, `set-chat-theme`, `set-emoji-status` - Customization
- `transcribe-voice-message-premium` - Voice transcription

**Documentation:** [PREMIUM.md](PREMIUM.md)

### Inline Bots 2025

Enhanced inline bot functionality with Bot API 7.4-9.1 features.

**Key Functions:**
- `make-visual-effect`, `add-visual-effects-to-result` - Visual effects
- `make-business-inline-config`, `make-paid-media-info` - Business features
- `make-webapp-inline-button` - WebApp integration
- `make-inline-result-story`, `make-inline-result-giveaway` - New result types
- `answer-inline-query-extended` - Enhanced query responses

**Documentation:** [INLINE_MODE_2025.md](INLINE_MODE_2025.md)

---

## Authentication API

Package: `cl-telegram/api`

### State Management

#### `*auth-state*`
Special variable holding current authentication state.

**Possible Values:**
- `:wait-tdlib-parameters` - Initial state
- `:wait-phone-number` - Waiting for phone number
- `:wait-code` - Phone set, waiting for verification code
- `:wait-password` - 2FA required, waiting for password
- `:ready` - Authenticated

#### `*auth-phone-number*`
Special variable holding the phone number used for authentication.

#### `*auth-connection*`
Special variable holding the current network connection.

#### `get-authentication-state ()`
Get current authentication state.

**Returns:** Keyword representing current state

**Example:**
```lisp
(get-authentication-state) ; => :wait-phone-number
```

#### `authorized-p ()`
Check if user is fully authenticated.

**Returns:** Boolean

#### `needs-phone-p ()`
Check if phone number is needed.

#### `needs-code-p ()`
Check if verification code is needed.

#### `needs-password-p ()`
Check if 2FA password is needed.

### Authentication Functions

#### `set-authentication-phone-number (phone-number)`
Set phone number for authentication.

**Parameters:**
- `phone-number` - Phone number string (e.g., "+1234567890")

**Returns:** `t` on success

**Side Effects:**
- Sets `*auth-phone-number*`
- Changes state to `:wait-code`

**Example:**
```lisp
(set-authentication-phone-number "+1234567890")
```

#### `request-authentication-code ()`
Request verification code to be sent.

**Returns:** `(values result error)`
- `result` - plist with `:code-sent` indicator
- `error` - Error keyword if failed

**Example:**
```lisp
(multiple-value-bind (result error)
    (request-authentication-code)
  (if error
      (format t "Error: ~A~%" error)
      (format t "Code sent!~%")))
```

#### `check-authentication-code (code)`
Verify the authentication code.

**Parameters:**
- `code` - Verification code string

**Returns:** `(values result error)`
- `result` - `(:success)` on success, `(:error message)` on failure
- `error` - Error keyword

**Example:**
```lisp
(multiple-value-bind (result error)
    (check-authentication-code "12345")
  (if (eq (car result) :success)
      (format t "Authenticated!~%")
      (format t "Failed: ~A~%" (cadr result))))
```

#### `set-authentication-password (password)`
Set 2FA password for authentication.

**Parameters:**
- `password` - Password string

**Returns:** `(values result error)`

#### `register-user (first-name last-name &key bio)`
Register a new user account.

**Parameters:**
- `first-name` - User's first name (required)
- `last-name` - User's last name (optional)
- `bio` - User bio text (optional, 0-70 chars)

**Returns:** `(values result error)`

**Example:**
```lisp
(register-user "John" "Doe" :bio "Lisp developer")
```

### Session Management

#### `get-auth-session ()`
Get current authentication session information.

**Returns:** plist with:
- `:state` - Current auth state
- `:phone` - Phone number
- `:code-info` - Code information
- `:user-id` - User ID if authorized

#### `reset-auth-session ()`
Reset authentication session to initial state.

**Example:**
```lisp
(reset-auth-session) ; Back to :wait-tdlib-parameters
```

#### `ensure-auth-connection ()`
Ensure auth connection exists, create if needed.

**Returns:** Connection object

#### `close-auth-connection ()`
Close the auth connection.

**Returns:** `t` on success

### TDLib Compatibility Functions

These functions use TDLib-compatible naming for interoperability.

#### `|setTdlibParameters| (&key parameters)`
Set TDLib parameters.

#### `|setAuthenticationPhoneNumber| (phone-number)`
TDLib-compatible phone number setting.

#### `|requestAuthenticationCode| ()`
TDLib-compatible code request.

#### `|checkAuthenticationCode| (code)`
TDLib-compatible code verification.

#### `|checkAuthenticationPassword| (password)`
TDLib-compatible password verification.

#### `|registerUser| (first-name last-name)`
TDLib-compatible user registration.

### Demo Functions

#### `demo-auth-flow ()`
Run demo authentication flow for testing.

**Returns:** `t` on success

**Example:**
```lisp
(demo-auth-flow) ; Uses demo phone and code "12345"
```

---

## Messages API

Package: `cl-telegram/api`

### Sending Messages

#### `send-message (chat-id text &key parse-mode entities)`
Send a text message to a chat.

**Parameters:**
- `chat-id` - Unique identifier of the chat
- `text` - Message text (1-4096 characters)
- `parse-mode` - Optional parsing mode (`:markdown`, `:html`)
- `entities` - Optional message entities for formatting

**Returns:** `(values message error)`
- `message` - Message object on success
- `error` - Error keyword (`:not-authorized`, `:invalid-message`, `:no-connection`, `:timeout`, `:rpc-error`)

**Example:**
```lisp
(multiple-value-bind (msg err)
    (send-message 123 "Hello, World!")
  (if err
      (format t "Send failed: ~A~%" err)
      (format t "Sent! Message ID: ~A~%" (getf msg :id))))
```

#### `send-chat-action (chat-id action-type)`
Send a chat action (typing indicator).

**Parameters:**
- `chat-id` - Unique identifier of the chat
- `action-type` - One of: `:typing`, `:cancel`, `:record-video`, `:upload-video`, `:record-audio`, `:upload-audio`, `:upload-photo`, `:upload-document`, `:geo`, `:choose-contact`, `:playing-game`

**Returns:** `(values result error)`

**Example:**
```lisp
(send-chat-action 123 :typing)
```

### Retrieving Messages

#### `get-messages (chat-id &key limit offset from-message-id)`
Get message history for a chat.

**Parameters:**
- `chat-id` - Unique identifier of the chat
- `limit` - Number of messages (1-100, default 50)
- `offset` - Number of messages to skip (default 0)
- `from-message-id` - Optional starting message ID

**Returns:** `(values messages error)`
- `messages` - List of message objects

**Example:**
```lisp
(multiple-value-bind (msgs err)
    (get-messages 123 :limit 20)
  (dolist (msg msgs)
    (format t "~A: ~A~%" (getf msg :from-id) (getf msg :text))))
```

#### `get-message-history (chat-id &key limit offset-id)`
Get message history with pagination.

**Returns:** `(values messages has-more)`
- `has-more` - Boolean indicating if more messages exist

#### `search-messages (chat-id query &key limit)`
Search for messages containing text.

**Parameters:**
- `query` - Search query string
- `limit` - Maximum results (default 50)

**Returns:** `(values messages error)`

### Modifying Messages

#### `edit-message (chat-id message-id new-text &key parse-mode)`
Edit a message text.

**Parameters:**
- `chat-id` - Chat ID
- `message-id` - ID of message to edit
- `new-text` - New text (1-4096 characters)

**Returns:** `(values edited-message error)`

**Example:**
```lisp
(edit-message 123 456 "Updated text")
```

#### `delete-messages (chat-id message-ids)`
Delete messages from a chat.

**Parameters:**
- `chat-id` - Chat ID
- `message-ids` - List of message IDs to delete

**Returns:** `(values success error)`

**Example:**
```lisp
(delete-messages 123 '(1 2 3 4 5))
```

#### `forward-messages (from-chat-id to-chat-id message-ids &key as-silent)`
Forward messages from one chat to another.

**Parameters:**
- `from-chat-id` - Source chat ID
- `to-chat-id` - Destination chat ID
- `message-ids` - List of message IDs
- `as-silent` - Send without notification (default nil)

**Returns:** `(values updates error)`

#### `send-reaction (chat-id message-id reaction-type)`
Send a reaction to a message.

**Parameters:**
- `reaction-type` - Type of reaction (`:emoji`, `:custom-emoji`)

**Returns:** `(values success error)`

### TDLib Compatibility

#### `|sendMessage| (chat-id text &key parse-mode entities)`
#### `|getMessages| (chat-id message-ids)`
#### `|deleteMessages| (chat-id message-ids &key revoke)`
#### `|editMessageText| (chat-id message-id text &key parse-mode)`
#### `|forwardMessages| (from-chat-id to-chat-id message-ids &key as-silent)`

---

## Chats API

Package: `cl-telegram/api`

### Chat List

#### `get-chats (&key limit offset folder-id)`
Get list of chats.

**Parameters:**
- `limit` - Number of chats (1-1000, default 100)
- `offset` - Number of chats to skip (default 0)
- `folder-id` - Optional folder ID to filter by

**Returns:** `(values chat-list error)`

**Example:**
```lisp
(multiple-value-bind (chats err)
    (get-chats :limit 50)
  (dolist (chat chats)
    (format t "~A~%" (getf chat :title))))
```

#### `search-chats (query &key limit)`
Search for chats by query.

**Parameters:**
- `query` - Search query string
- `limit` - Maximum results (default 50)

**Returns:** `(values chats error)`

### Single Chat

#### `get-chat (chat-id)`
Get information about a chat.

**Parameters:**
- `chat-id` - Unique identifier of the chat

**Returns:** `(values chat error)`

**Example:**
```lisp
(multiple-value-bind (chat err)
    (get-chat 123)
  (when chat
    (format t "Title: ~A, Type: ~A~%"
            (getf chat :title) (getf chat :type))))
```

#### `create-private-chat (user-id &key force)`
Create or get a private chat with a user.

**Parameters:**
- `user-id` - User ID
- `force` - Always create new chat (default nil)

**Returns:** `(values chat error)`

### Group Chats

#### `create-basic-group-chat (title &key user-ids)`
Create a new basic group chat.

**Parameters:**
- `title` - Group title (1-128 characters)
- `user-ids` - Optional list of initial user IDs

**Returns:** `(values chat error)`

#### `create-supergroup-chat (title &key description for-channel)`
Create a new supergroup or channel.

**Parameters:**
- `title` - Group/channel title (1-256 characters)
- `description` - Group description (optional)
- `for-channel` - Create channel instead of group (default nil)

**Returns:** `(values chat error)`

### Chat Members

#### `get-chat-members (chat-id &key limit offset)`
Get members of a chat.

**Parameters:**
- `limit` - Number of members (1-100, default 100)
- `offset` - Number to skip (default 0)

**Returns:** `(values members error)`

#### `add-chat-member (chat-id user-id &key forward-limit)`
Add a user to a chat.

**Parameters:**
- `forward-limit` - Messages to forward (default 10)

**Returns:** `(values success error)`

#### `remove-chat-member (chat-id user-id)`
Remove a user from a chat.

**Returns:** `(values success error)`

### Chat Settings

#### `set-chat-title (chat-id title)`
Set the title of a chat.

**Returns:** `(values success error)`

#### `toggle-chat-muted (chat-id &key muted)`
Mute or unmute a chat.

**Parameters:**
- `muted` - If true, mute; if false, unmute (default t)

**Returns:** `(values success error)`

#### `clear-chat-history (chat-id &key remove-from-chat-list)`
Clear chat history.

**Parameters:**
- `remove-from-chat-list` - Also remove from list (default nil)

**Returns:** `(values success error)`

### Chat History

#### `get-chat-history (chat-id &key limit from-message-id)`
Get chat message history (alias for `get-messages`).

### TDLib Compatibility

#### `|getChats| (&key folder-id limit offset)`
#### `|getChat| (chat-id)`
#### `|createPrivateChat| (user-id &key force)`
#### `|sendMessage| (chat-id text &key parse-mode)`
#### `|sendChatAction| (chat-id action-type)`

---

## Users API

Package: `cl-telegram/api`

### Current User

#### `get-me ()`
Get information about the current user.

**Returns:** `(values user error)`
- `user` - User object with: `:id`, `:first-name`, `:last-name`, `:username`, `:bio`, `:status`

**Example:**
```lisp
(multiple-value-bind (user err)
    (get-me)
  (when user
    (format t "~A @~A~%"
            (getf user :first-name)
            (getf user :username))))
```

### Get Users

#### `get-user (user-id)`
Get information about a single user.

**Parameters:**
- `user-id` - Unique identifier of the user

**Returns:** `(values user error)`

#### `get-users (user-ids)`
Get information about multiple users.

**Parameters:**
- `user-ids` - List of user IDs

**Returns:** `(values users error)`
- `users` - List of user objects

#### `search-users (query &key limit)`
Search for users by name.

**Parameters:**
- `query` - Search query string
- `limit` - Maximum results (1-100, default 50)

**Returns:** `(values users error)`

### User Profile

#### `get-user-profile-photos (user-id &key offset limit)`
Get user profile photos.

**Parameters:**
- `offset` - Number of photos to skip (default 0)
- `limit` - Maximum photos (1-100, default 100)

**Returns:** `(values photos error)`

#### `get-user-full-info (user-id)`
Get full information about a user.

**Returns:** `(values user-full error)`

#### `get-user-status (user-id)`
Get user online status.

**Returns:** `(values status error)`
- `status` - Status object: `:userStatusOnline`, `:userStatusOffline`, etc.

### Contact Management

#### `get-contacts (&key hash)`
Get contact list.

**Parameters:**
- `hash` - Contact list hash for caching (default 0)

**Returns:** `(values contacts error)`

#### `add-contact (user-id &key first-name last-name phone-number)`
Add a user to contacts.

**Returns:** `(values success error)`

#### `delete-contacts (user-ids)`
Delete users from contacts.

**Parameters:**
- `user-ids` - List of user IDs

**Returns:** `(values success error)`

#### `block-user (user-id)`
Block a user.

**Returns:** `(values success error)`

#### `unblock-user (user-id)`
Unblock a user.

**Returns:** `(values success error)`

#### `get-blocked-users (&key offset limit)`
Get list of blocked users.

**Returns:** `(values blocked-users error)`

### User Settings

#### `set-bio (bio-text)`
Set user bio.

**Parameters:**
- `bio-text` - Bio text (0-70 characters)

**Returns:** `(values success error)`

#### `set-user-profile-photo (photo-file)`
Set user profile photo.

**Parameters:**
- `photo-file` - Input file data

**Returns:** `(values photo error)`

#### `delete-user-profile-photo (photo-id)`
Delete a profile photo.

**Returns:** `(values success error)`

### TDLib Compatibility

#### `|getUsers| (user-ids)`
#### `|getUser| (user-id)`
#### `|getMe| ()`
#### `|searchUsers| (query &key limit)`
#### `|getContacts| (&key hash)`
#### `|createPrivateChat| (user-id)`

---

## Network Layer

Package: `cl-telegram/network`

### TCP Client

#### `make-tcp-client (host port &key on-connect on-data on-error)`
Create an async TCP client.

**Parameters:**
- `host` - Hostname or IP
- `port` - Port number
- `on-connect` - Callback function (client) -> nil
- `on-data` - Callback function (client data) -> nil
- `on-error` - Callback function (client error) -> nil

**Returns:** TCP client object

**Example:**
```lisp
(let ((client (make-tcp-client "149.154.167.51" 443
                               :on-connect (lambda (c) (format t "Connected~%"))
                               :on-data (lambda (c d) (format t "Data: ~A~%" d))
                               :on-error (lambda (c e) (format t "Error: ~A~%" e)))))
  (client-connect client))
```

#### `client-connect (client &key timeout)`
Connect the TCP client.

**Parameters:**
- `timeout` - Connection timeout in ms (default 10000)

**Returns:** `t` on success

#### `client-send (client data)`
Send data through the client.

#### `client-close (client)`
Close the client connection.

### Synchronous TCP Client

#### `make-sync-tcp-client (host port)`
Create a synchronous TCP client.

#### `sync-client-connect (client &key timeout)`
Connect synchronously.

#### `sync-client-send (client data)`
Send data synchronously.

#### `sync-client-receive (client size &key timeout)`
Receive data synchronously.

### Connection Management

#### `make-connection (&key host port session-id)`
Create a connection object.

**Slots:**
- `session-id` - Session identifier
- `seqno` - Message sequence number
- `server-salt` - Server salt for message IDs
- `auth-key` - Authorization key
- `pending-requests` - Hash table of pending RPC requests
- `event-handlers` - List of event handlers

#### `connect (connection &key timeout)`
Establish connection.

#### `rpc-call (connection request &key timeout)`
Make an RPC call.

**Parameters:**
- `request` - TL-serialized request body
- `timeout` - Response timeout in ms (default 30000)

**Returns:** Response object

#### `rpc-call-with-retry (connection request &key max-retries timeout)`
RPC call with automatic retry.

**Parameters:**
- `max-retries` - Maximum retry attempts (default 3)

### RPC Macros

#### `with-rpc-call ((result connection request &key timeout) &body body)`
Execute RPC and bind result.

**Example:**
```lisp
(with-rpc-call (result conn request :timeout 5000)
  (format t "Got result: ~A~%" result))
```

#### `rpc-handler-case (call &rest cases)`
Handle RPC errors with pattern matching.

**Example:**
```lisp
(rpc-handler-case (rpc-call conn request)
  (:ok (result) (format t "Success: ~A~%" result))
  (:timeout () (format t "Timeout~%"))
  (:error (err) (format t "Error: ~A~%" err)))
```

---

## MTProto Protocol

Package: `cl-telegram/mtproto`

### Authentication

#### `make-auth-state ()`
Create authentication state object.

#### `auth-init (state &key api-id api-hash dc-id)`
Initialize authentication.

#### `auth-send-pq-request (state)`
Send req_pq_multi request.

#### `auth-handle-respq (state response)`
Handle resPQ response.

#### `auth-send-dh-request (state)`
Send req_DH_params request.

#### `auth-handle-server-dh (state response)`
Handle server_DH_inner_data.

#### `auth-send-client-dh (state dh-g-a)`
Send set_client_DH_params.

#### `auth-complete-p (state)`
Check if authentication is complete.

### Message Encryption

#### `encrypt-message (auth-key message &key from-client)`
Encrypt a message using MTProto 2.0.

**Returns:** `(values encrypted-data msg-key)`

#### `decrypt-message (auth-key msg-key encrypted-data &key from-client)`
Decrypt a message.

**Returns:** Decrypted message bytes

#### `compute-msg-key (auth-key message-data)`
Compute msg_key for integrity verification.

### Transport Layer

#### `make-transport-packet (auth-key-id msg-key encrypted-data)`
Create transport packet.

**Packet Format:**
```
[auth_key_id:8 bytes][msg_key:16 bytes][encrypted_data:variable]
```

#### `parse-transport-packet (packet)`
Parse transport packet.

**Returns:** `(values auth-key-id msg-key encrypted-data)`

#### `compute-message-length (encrypted-length)`
Compute total message length including headers.

### Message IDs

#### `generate-message-id (&key from-client)`
Generate a new message ID.

**Message ID Format:**
- 64-bit integer
- Bits 0-31: Nanoseconds (even)
- Bits 32-63: Seconds since Unix epoch
- Bit 0: 1 for client, 0 for server

---

## Crypto Primitives

Package: `cl-telegram/crypto`

### AES-256 IGE

#### `make-aes-ige-key (key-material)`
Create AES-256 IGE cipher context.

**Parameters:**
- `key-material` - 32-byte key

**Returns:** Cipher object

#### `aes-ige-encrypt (plaintext cipher iv1 iv2)`
Encrypt using AES-256 IGE mode.

**Parameters:**
- `plaintext` - Data to encrypt (multiple of 16 bytes)
- `cipher` - AES cipher context
- `iv1` - First IV (16 bytes)
- `iv2` - Second IV (16 bytes)

**Returns:** Encrypted data

#### `aes-ige-decrypt (ciphertext cipher iv1 iv2)`
Decrypt using AES-256 IGE mode.

### SHA-256

#### `sha256 (data)`
Compute SHA-256 hash.

**Returns:** 32-byte array

### RSA

#### `make-rsa-public-key (modulus exponent)`
Create RSA public key.

#### `rsa-encrypt (data public-key)`
Encrypt with RSA.

#### `rsa-decrypt (ciphertext private-key)`
Decrypt with RSA.

### Diffie-Hellman

#### `dh-generate-keypair ()`
Generate DH key pair.

**Returns:** `(values private-key public-key)`

#### `dh-compute-secret (private-key other-public)`
Compute shared secret.

**Parameters:**
- `*dh-p*` - MTProto 2048-bit prime
- `*dh-g*` - Generator (3)

### Key Derivation

#### `kdf-msg-key (auth-key msg-data)`
Compute msg_key = SHA256(auth_key + msg_data)[0:16]

#### `compute-aes-key-iv (auth-key msg-key from-client-p)`
Derive AES key and IV from auth_key and msg_key.

**Returns:** `(values aes-key iv)`

---

## TL Serialization

Package: `cl-telegram/tl`

### Type Definitions

#### `define-tl-type (name slots &key constructor-id)`
Define a TL type with serialization support.

**Example:**
```lisp
(define-tl-type respq
  ((nonce :initarg :nonce :accessor respq-nonce)
   (server-nonce :initarg :server-nonce :accessor respq-server-nonce)
   (pq :initarg :pq :accessor respq-pq))
  (:constructor-id #x05162463))
```

### Serialization

#### `tl-serialize (object)`
Serialize a TL object to bytes.

**Returns:** Byte array

#### `serialize-int32 (value)`
Serialize 32-bit integer (little-endian).

#### `serialize-int64 (value)`
Serialize 64-bit integer.

#### `serialize-string (string)`
Serialize length-prefixed string.

#### `serialize-bytes (bytes)`
Serialize length-prefixed bytes.

### Deserialization

#### `tl-deserialize (data &optional offset)`
Deserialize bytes to TL object.

**Returns:** `(values object new-offset)`

#### `deserialize-int32 (data &optional offset)`
Deserialize 32-bit integer.

#### `deserialize-int64 (data &optional offset)`
Deserialize 64-bit integer.

#### `deserialize-string (data &optional offset)`
Deserialize length-prefixed string.

### TL Types

Built-in types:
- `resPQ` - PQ factorization response
- `serverDHInnerData` - DH parameters
- `clientDHInnerData` - Client DH response
- `rpcResult` - RPC result wrapper
- `rpcError` - RPC error response

---

## Error Handling

### Error Types

| Error | Description |
|-------|-------------|
| `:not-authorized` | User not authenticated |
| `:invalid-message` | Invalid message content |
| `:invalid-argument` | Invalid argument provided |
| `:no-connection` | No active network connection |
| `:timeout` | Operation timed out |
| `:rpc-error` | Remote RPC error |
| `:user-not-found` | User does not exist |
| `:chat-not-found` | Chat does not exist |

### Error Handling Pattern

```lisp
(multiple-value-bind (result error)
    (send-message chat-id "Hello")
  (case error
    (:not-authorized (format t "Please login first~%"))
    (:timeout (format t "Request timed out~%"))
    (:rpc-error (format t "Server error~%"))
    (nil (format t "Sent: ~A~%" result))
    (otherwise (format t "Unknown error: ~A~%" error))))
```

---

## Quick Start Example

```lisp
;; Load the system
(asdf:load-system :cl-telegram)

;; Use the API package
(use-package :cl-telegram/api)

;; Run demo authentication
(demo-auth-flow)

;; Get current user
(multiple-value-bind (user err)
    (get-me)
  (if err
      (format t "Error: ~A~%" err)
      (format t "Logged in as: ~A ~A~%"
              (getf user :first-name)
              (getf user :last-name))))

;; Get chats
(multiple-value-bind (chats err)
    (get-chats :limit 10)
  (dolist (chat chats)
    (format t "Chat: ~A~%" (getf chat :title))))

;; Send a message
(multiple-value-bind (msg err)
    (send-message 123 "Hello from Common Lisp!")
  (if err
      (format t "Failed: ~A~%" err)
      (format t "Message sent!~%")))
```

---

## Index

| Function | Package | Description |
|----------|---------|-------------|
| `|checkAuthenticationCode|` | api | Verify authentication code |
| `|checkAuthenticationPassword|` | api | Verify 2FA password |
| `|createPrivateChat|` | api | Create private chat |
| `|getChat|` | api | Get chat information |
| `|getChats|` | api | Get chat list |
| `|getContacts|` | api | Get contact list |
| `|getMe|` | api | Get current user |
| `|getMessages|` | api | Get messages by ID |
| `|getUsers|` | api | Get multiple users |
| `|registerUser|` | api | Register new user |
| `|searchUsers|` | api | Search users |
| `|sendChatAction|` | api | Send typing indicator |
| `|sendMessage|` | api | Send message |
| `|setAuthenticationPhoneNumber|` | api | Set phone number |
| `|setTdlibParameters|` | api | Set TDLib parameters |
| `add-contact` | api | Add user to contacts |
| `authorized-p` | api | Check if authorized |
| `block-user` | api | Block a user |
| `check-authentication-code` | api | Verify auth code |
| `clear-chat-history` | api | Clear chat history |
| `create-basic-group-chat` | api | Create group chat |
| `create-private-chat` | api | Create private chat |
| `create-supergroup-chat` | api | Create supergroup |
| `delete-contacts` | api | Delete contacts |
| `delete-messages` | api | Delete messages |
| `demo-auth-flow` | api | Run demo auth |
| `edit-message` | api | Edit message |
| `ensure-auth-connection` | api | Get/create connection |
| `forward-messages` | api | Forward messages |
| `get-auth-session` | api | Get session info |
| `get-authentication-state` | api | Get auth state |
| `get-blocked-users` | api | Get blocked users |
| `get-chat` | api | Get chat |
| `get-chat-history` | api | Get chat messages |
| `get-chat-members` | api | Get chat members |
| `get-chats` | api | Get chat list |
| `get-contacts` | api | Get contacts |
| `get-me` | api | Get current user |
| `get-message-history` | api | Get paginated messages |
| `get-messages` | api | Get messages |
| `get-user` | api | Get user |
| `get-user-full-info` | api | Get full user info |
| `get-user-profile-photos` | api | Get profile photos |
| `get-user-status` | api | Get user status |
| `get-users` | api | Get multiple users |
| `needs-code-p` | api | Check if code needed |
| `needs-password-p` | api | Check if password needed |
| `needs-phone-p` | api | Check if phone needed |
| `register-user` | api | Register user |
| `request-authentication-code` | api | Request code |
| `reset-auth-session` | api | Reset session |
| `search-chats` | api | Search chats |
| `search-messages` | api | Search messages |
| `search-users` | api | Search users |
| `send-chat-action` | api | Send chat action |
| `send-message` | api | Send message |
| `send-reaction` | api | Send reaction |
| `set-authentication-password` | api | Set 2FA password |
| `set-authentication-phone-number` | api | Set phone number |
| `set-bio` | api | Set user bio |
| `set-chat-title` | api | Set chat title |
| `toggle-chat-muted` | api | Mute/unmute chat |
| `unblock-user` | api | Unblock user |
