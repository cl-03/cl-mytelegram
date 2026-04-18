;;; database.lisp --- Local cache database for messages, chats, and users
;;;
;;; Provides persistent local storage using SQLite for:
;;; - Message history caching
;;; - Chat/user profile caching
;;; - Auth key storage (encrypted)
;;; - Session data

(in-package #:cl-telegram/api)

;;; ### Database Connection

(defvar *db-connection* nil
  "Global SQLite database connection")

(defvar *db-path* nil
  "Path to database file")

(defun init-database (&key (data-dir (user-data-dir))
                        (db-name "cl-telegram.db"))
  "Initialize the local database.

   Args:
     data-dir: Directory to store database (default: user data dir)
     db-name: Database file name (default: cl-telegram.db)

   Returns:
     T on success

   Creates tables if they don't exist:
   - users: User profile cache
   - chats: Chat info cache
   - messages: Message history
   - secret_chats: E2E chat keys
   - sessions: Auth session data"
  (let ((db-path (merge-pathnames db-name (ensure-directories-exist data-dir))))
    (setf *db-path* db-path)

    ;; Connect to SQLite
    (let ((conn (dbi:connect :sqlite3 :database-name (namestring db-path))))
      (setf *db-connection* conn)

      ;; Create tables
      (create-tables conn)
      t)))

(defun user-data-dir ()
  "Get user data directory for storing database.

   Returns:
     Pathname to user data directory

   Platform-specific:
   - Windows: %APPDATA%/cl-telegram
   - macOS: ~/Library/Application Support/cl-telegram
   - Linux: ~/.local/share/cl-telegram"
  (let ((home (uiop:os-home-directory)))
    (cond
      ((eq (uiop:os-type) :windows)
       (let ((appdata (uiop:getenv "APPDATA")))
         (when appdata
           (merge-pathnames "cl-telegram/" appdata))))
      ((eq (uiop:os-type) :macos)
       (merge-pathnames "Library/Application Support/cl-telegram/" home))
      (t ; Linux/Unix
       (merge-pathnames ".local/share/cl-telegram/" home)))))

(defun create-tables (conn)
  "Create database tables if they don't exist.

   Args:
     conn: Database connection"
  ;; Users table
  (dbi:execute-query
   conn
   "CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY,
      first_name TEXT,
      last_name TEXT,
      username TEXT,
      phone TEXT,
      status TEXT,
      status_expires INTEGER,
      photo_file_id TEXT,
      bio TEXT,
      is_bot BOOLEAN,
      is_contact BOOLEAN,
      is_blocked BOOLEAN,
      access_hash INTEGER,
      cached_at INTEGER
    )")

  ;; Chats table
  (dbi:execute-query
   conn
   "CREATE TABLE IF NOT EXISTS chats (
      id INTEGER PRIMARY KEY,
      type TEXT,
      title TEXT,
      first_name TEXT,
      username TEXT,
      photo_file_id TEXT,
      last_message_id INTEGER,
      last_message_text TEXT,
      last_message_date INTEGER,
      unread_count INTEGER,
      is_pinned BOOLEAN,
      is_muted BOOLEAN,
      access_hash INTEGER,
      cached_at INTEGER
    )")

  ;; Messages table
  (dbi:execute-query
   conn
   "CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER,
      chat_id INTEGER,
      from_user_id INTEGER,
      from_chat_id INTEGER,
      date INTEGER,
      text TEXT,
      media_type TEXT,
      media_file_id TEXT,
      media_caption TEXT,
      reply_to_message_id INTEGER,
      forward_from_user_id INTEGER,
      forward_from_chat_id INTEGER,
      forward_date INTEGER,
      is_edited BOOLEAN,
      edit_date INTEGER,
      has_media BOOLEAN,
      raw_data TEXT,
      created_at INTEGER,
      UNIQUE(message_id, chat_id)
    )")

  ;; Indexes for messages
  (dbi:execute-query
   conn
   "CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id)")

  (dbi:execute-query
   conn
   "CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date)")

  (dbi:execute-query
   conn
   "CREATE INDEX IF NOT EXISTS idx_messages_chat_date ON messages(chat_id, date)")

  ;; Secret chats table (stores E2E keys)
  (dbi:execute-query
   conn
   "CREATE TABLE IF NOT EXISTS secret_chats (
      id INTEGER PRIMARY KEY,
      participant_id INTEGER,
      local_key BLOB,
      remote_key BLOB,
      auth_key BLOB,
      auth_key_id INTEGER,
      layer INTEGER,
      in_sequence_no INTEGER,
      out_sequence_no INTEGER,
      ttl INTEGER,
      state TEXT,
      created_at INTEGER,
      encrypted_key_data BLOB
    )")

  ;; Sessions table
  (dbi:execute-query
   conn
   "CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT UNIQUE,
      dc_id INTEGER,
      auth_key BLOB,
      server_salt BLOB,
      user_id INTEGER,
      is_current BOOLEAN,
      created_at INTEGER,
      expires_at INTEGER
    )")

  ;; Settings table
  (dbi:execute-query
   conn
   "CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT,
      updated_at INTEGER
    )")

  ;; File cache table
  (dbi:execute-query
   conn
   "CREATE TABLE IF NOT EXISTS file_cache (
      file_id TEXT PRIMARY KEY,
      file_type TEXT,
      file_path TEXT,
      file_size INTEGER,
      mime_type TEXT,
      thumb_file_id TEXT,
      cached_at INTEGER
    )")

  ;; Create indexes
  (dbi:execute-query
   conn
   "CREATE INDEX IF NOT EXISTS idx_chats_last_message ON chats(last_message_date DESC)")

  (dbi:execute-query
   conn
   "CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)")

  (dbi:execute-query
   conn
   "CREATE INDEX IF NOT EXISTS idx_sessions_current ON sessions(is_current)"))

(defun close-database ()
  "Close the database connection.

   Returns:
     T on success"
  (when *db-connection*
    (dbi:disconnect *db-connection*)
    (setf *db-connection* nil))
  t)

;;; ### User Cache Operations

(defun cache-user (user)
  "Cache a user object.

   Args:
     user: User plist from API

   Returns:
     T on success"
  (when (and *db-connection* user)
    (dbi:execute-query
     *db-connection*
     "INSERT OR REPLACE INTO users
      (id, first_name, last_name, username, phone, status, status_expires,
       photo_file_id, bio, is_bot, is_contact, is_blocked, access_hash, cached_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
     (list (getf user :id)
           (getf user :first-name)
           (getf user :last-name)
           (getf user :username)
           (getf user :phone)
           (when (getf user :status)
             (string (getf (getf user :status) :@type)))
           (when (getf user :status)
             (getf (getf user :status) :expires))
           (getf user :photo-file-id)
           (getf user :bio)
           (getf user :is-bot)
           (getf user :is-contact)
           (getf user :is-blocked)
           (getf user :access-hash)
           (get-universal-time)))
    t))

(defun get-cached-user (user-id)
  "Get cached user by ID.

   Args:
     user-id: User identifier

   Returns:
     User plist or NIL if not cached"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT * FROM users WHERE id = ?"
                   (list user-id))))
      (when result
        (row-to-plist result :user)))))

(defun search-cached-users (query &limit (limit 50))
  "Search cached users by name or username.

   Args:
     query: Search query string
     limit: Maximum results (default: 50)

   Returns:
     List of user plists"
  (when *db-connection*
    (let ((results (dbi:fetch-all
                    *db-connection*
                    "SELECT * FROM users
                     WHERE (first_name LIKE ? OR last_name LIKE ? OR username LIKE ?)
                     ORDER BY first_name
                     LIMIT ?"
                    (list (format nil "%~A%" query)
                          (format nil "%~A%" query)
                          (format nil "%~A%" query)
                          limit))))
      (mapcar (lambda (row) (row-to-plist row :user)) results))))

;;; ### Chat Cache Operations

(defun cache-chat (chat)
  "Cache a chat object.

   Args:
     chat: Chat plist from API

   Returns:
     T on success"
  (when (and *db-connection* chat)
    (dbi:execute-query
     *db-connection*
     "INSERT OR REPLACE INTO chats
      (id, type, title, first_name, username, photo_file_id,
       last_message_id, last_message_text, last_message_date,
       unread_count, is_pinned, is_muted, access_hash, cached_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
     (list (getf chat :id)
           (when (getf chat :type)
             (string (getf (getf chat :type) :@type)))
           (getf chat :title)
           (getf chat :first-name)
           (getf chat :username)
           (getf chat :photo-file-id)
           (getf chat :last-message-id)
           (getf chat :last-message-text)
           (getf chat :last-message-date)
           (getf chat :unread-count)
           (getf chat :is-pinned)
           (getf chat :is-muted)
           (getf chat :access-hash)
           (get-universal-time)))
    t))

(defun get-cached-chat (chat-id)
  "Get cached chat by ID.

   Args:
     chat-id: Chat identifier

   Returns:
     Chat plist or NIL if not cached"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT * FROM chats WHERE id = ?"
                   (list chat-id))))
      (when result
        (row-to-plist result :chat)))))

(defun list-cached-chats (&key (limit 100) (offset 0))
  "List cached chats ordered by last message.

   Args:
     limit: Maximum results (default: 100)
     offset: Offset for pagination

   Returns:
     List of chat plists"
  (when *db-connection*
    (let ((results (dbi:fetch-all
                    *db-connection*
                    "SELECT * FROM chats
                     ORDER BY last_message_date DESC
                     LIMIT ? OFFSET ?"
                    (list limit offset))))
      (mapcar (lambda (row) (row-to-plist row :chat)) results))))

;;; ### Message Cache Operations

(defun cache-message (message)
  "Cache a message object.

   Args:
     message: Message plist from API

   Returns:
     T on success"
  (when (and *db-connection* message)
    (let* ((from (getf message :from))
           (media (getf message :media))
           (reply-to (getf message :reply-to))
           (forward-from (getf message :forward-from)))
      (dbi:execute-query
       *db-connection*
       "INSERT OR REPLACE INTO messages
        (message_id, chat_id, from_user_id, from_chat_id, date,
         text, media_type, media_file_id, media_caption,
         reply_to_message_id, forward_from_user_id, forward_from_chat_id,
         forward_date, is_edited, edit_date, has_media, raw_data, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
       (list (getf message :id)
             (getf message :chat-id)
             (getf from :id)
             (getf from :chat-id)
             (getf message :date)
             (getf message :text)
             (when media (string (getf media :@type)))
             (getf media :file-id)
             (getf message :caption)
             (getf reply-to :message-id)
             (getf forward-from :user-id)
             (getf forward-from :chat-id)
             (getf forward-from :date)
             (getf message :is-edited)
             (getf message :edit-date)
             (if media t nil)
             (jonathan:to-json message)
             (get-universal-time))))
    t))

(defun cache-messages (messages)
  "Cache multiple messages.

   Args:
     messages: List of message plists

   Returns:
     Number of messages cached"
  (let ((count 0))
    (dolist (msg messages count)
      (when (cache-message msg)
        (incf count)))))

(defun get-cached-messages (chat-id &key (limit 50) (offset 0) (before-date nil))
  "Get cached messages for a chat.

   Args:
     chat-id: Chat identifier
     limit: Maximum results (default: 50)
     offset: Offset for pagination
     before-date: Only messages before this date

   Returns:
     List of message plists, newest first"
  (when *db-connection*
    (let* ((query
            (if before-date
                "SELECT * FROM messages
                 WHERE chat_id = ? AND date < ?
                 ORDER BY date DESC
                 LIMIT ? OFFSET ?"
                "SELECT * FROM messages
                 WHERE chat_id = ?
                 ORDER BY date DESC
                 LIMIT ? OFFSET ?"))
           (params
            (if before-date
                (list chat-id before-date limit offset)
                (list chat-id limit offset)))
           (results (dbi:fetch-all *db-connection* query params)))
      (mapcar (lambda (row) (row-to-plist row :message)) results))))

(defun get-cached-message (chat-id message-id)
  "Get a specific cached message.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier

   Returns:
     Message plist or NIL"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT * FROM messages
                    WHERE chat_id = ? AND message_id = ?"
                   (list chat-id message-id))))
      (when result
        (row-to-plist result :message)))))

(defun search-cached-messages (chat-id query &key (limit 50))
  "Search cached messages by text content.

   Args:
     chat-id: Chat identifier
     query: Search query string
     limit: Maximum results

   Returns:
     List of message plists"
  (when *db-connection*
    (let ((results (dbi:fetch-all
                    *db-connection*
                    "SELECT * FROM messages
                     WHERE chat_id = ? AND text LIKE ?
                     ORDER BY date DESC
                     LIMIT ?"
                    (list chat-id (format nil "%~A%" query) limit))))
      (mapcar (lambda (row) (row-to-plist row :message)) results))))

(defun delete-cached-message (chat-id message-id)
  "Delete a cached message.

   Args:
     chat-id: Chat identifier
     message-id: Message identifier

   Returns:
     T on success"
  (when *db-connection*
    (dbi:execute-query
     *db-connection*
     "DELETE FROM messages WHERE chat_id = ? AND message_id = ?"
     (list chat-id message-id))
    t))

(defun clear-chat-cache (chat-id)
  "Clear all cached messages for a chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success"
  (when *db-connection*
    (dbi:execute-query
     *db-connection*
     "DELETE FROM messages WHERE chat_id = ?"
     (list chat-id))
    t))

;;; ### Secret Chat Storage

(defun cache-secret-chat (chat)
  "Cache secret chat with encryption keys.

   Args:
     chat: Secret chat instance

   Returns:
     T on success"
  (when (and *db-connection* chat)
    (dbi:execute-query
     *db-connection*
     "INSERT OR REPLACE INTO secret_chats
      (id, participant_id, local_key, remote_key, auth_key, auth_key_id,
       layer, in_sequence_no, out_sequence_no, ttl, state, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
     (list (cl-telegram/api::secret-chat-id chat)
           (cl-telegram/api::secret-participant-id chat)
           (cl-telegram/api::secret-local-key chat)
           (cl-telegram/api::secret-remote-key chat)
           (cl-telegram/api::secret-auth-key chat)
           (cl-telegram/api::secret-auth-key-id chat)
           (cl-telegram/api::secret-layer chat)
           (cl-telegram/api::secret-in-sequence-no chat)
           (cl-telegram/api::secret-out-sequence-no chat)
           (cl-telegram/api::secret-ttl chat)
           (string (cl-telegram/api::secret-state chat))
           (cl-telegram/api::secret-created-at chat)))
    t))

(defun get-cached-secret-chat (chat-id)
  "Get cached secret chat by ID.

   Args:
     chat-id: Secret chat identifier

   Returns:
     Secret chat instance or NIL"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT * FROM secret_chats WHERE id = ?"
                   (list chat-id))))
      (when result
        (let ((chat (make-instance 'cl-telegram/api::secret-chat
                                   :chat-id (getf result :id)
                                   :participant-id (getf result :participant-id))))
          (setf (cl-telegram/api::secret-local-key chat) (getf result :local-key))
          (setf (cl-telegram/api::secret-remote-key chat) (getf result :remote-key))
          (setf (cl-telegram/api::secret-auth-key chat) (getf result :auth-key))
          (setf (cl-telegram/api::secret-auth-key-id chat) (getf result :auth-key-id))
          (setf (cl-telegram/api::secret-layer chat) (getf result :layer))
          (setf (cl-telegram/api::secret-in-sequence-no chat) (getf result :in-sequence-no))
          (setf (cl-telegram/api::secret-out-sequence-no chat) (getf result :out-sequence-no))
          (setf (cl-telegram/api::secret-ttl chat) (getf result :ttl))
          (setf (cl-telegram/api::secret-state chat)
                (intern (string-upcase (getf result :state)) :keyword))
          (setf (cl-telegram/api::secret-created-at chat) (getf result :created-at))
          chat)))))

;;; ### Session Storage

(defun cache-session (session-id dc-id auth-key server-salt &optional user-id)
  "Cache authentication session.

   Args:
     session-id: Session identifier
     dc-id: Datacenter ID
     auth-key: 256-byte auth key
     server-salt: 8-byte server salt
     user-id: Optional user ID

   Returns:
     T on success"
  (when *db-connection*
    ;; Clear current session flag
    (dbi:execute-query
     *db-connection*
     "UPDATE sessions SET is_current = 0")

    ;; Insert new session
    (dbi:execute-query
     *db-connection*
     "INSERT INTO sessions
      (session_id, dc_id, auth_key, server_salt, user_id, is_current, created_at, expires_at)
      VALUES (?, ?, ?, ?, ?, 1, ?, ?)"
     (list session-id
           dc-id
           auth-key
           server-salt
           user-id
           (get-universal-time)
           (+ (get-universal-time) (* 365 24 60 60)))) ; 1 year
    t))

(defun get-current-session ()
  "Get current cached session.

   Returns:
     Session plist or NIL"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT * FROM sessions WHERE is_current = 1")))
      (when result
        result))))

(defun get-cached-auth-key (session-id)
  "Get cached auth key for session.

   Args:
     session-id: Session identifier

   Returns:
     Auth key bytes or NIL"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT auth_key FROM sessions WHERE session_id = ?"
                   (list session-id))))
      (when result
        (getf result :auth-key)))))

;;; ### File Cache

(defun cache-file-info (file-id file-type file-path file-size &key mime-type thumb-file-id)
  "Cache file metadata.

   Args:
     file-id: File identifier
     file-type: :photo, :document, :audio, :video, etc.
     file-path: Local file path
     file-size: File size in bytes
     mime-type: MIME type
     thumb-file-id: Thumbnail file ID

   Returns:
     T on success"
  (when *db-connection*
    (dbi:execute-query
     *db-connection*
     "INSERT OR REPLACE INTO file_cache
      (file_id, file_type, file_path, file_size, mime_type, thumb_file_id, cached_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)"
     (list file-id
           (string file-type)
           file-path
           file-size
           mime-type
           thumb-file-id
           (get-universal-time)))
    t))

(defun get-cached-file-path (file-id)
  "Get cached file path.

   Args:
     file-id: File identifier

   Returns:
     File path string or NIL"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT file_path FROM file_cache WHERE file_id = ?"
                   (list file-id))))
      (when result
        (getf result :file-path)))))

;;; ### Settings Storage

(defun set-setting (key value)
  "Store a setting.

   Args:
     key: Setting key
     value: Setting value (will be JSON encoded)

   Returns:
     T on success"
  (when *db-connection*
    (dbi:execute-query
     *db-connection*
     "INSERT OR REPLACE INTO settings (key, value, updated_at)
      VALUES (?, ?, ?)"
     (list (string key)
           (jonathan:to-json value)
           (get-universal-time)))
    t))

(defun get-setting (key &optional default)
  "Get a stored setting.

   Args:
     key: Setting key
     default: Default value if not found

   Returns:
     Setting value or default"
  (when *db-connection*
    (let ((result (dbi:fetch-one
                   *db-connection*
                   "SELECT value FROM settings WHERE key = ?"
                   (list (string key)))))
      (if result
          (jonathan:from-json (getf result :value))
          default))))

;;; ### Utility Functions

(defun row-to-plist (row &optional type)
  "Convert database row to plist.

   Args:
     row: Database row result
     type: Optional type keyword to add

   Returns:
     Property list"
  (let ((result nil))
    (maphash (lambda (key value)
               (when value
                 (push (keywordify-db-key key) result)
                 (push value result)))
             row)
    (when type
      (push :@type result)
      (push type result))
    (nreverse result)))

(defun keywordify-db-key (key)
  "Convert database column name to keyword.

   Args:
     key: Column name string

   Returns:
     Keyword symbol"
  (intern (string-upcase (substitute-if #\- #\_ key)) :keyword))

;;; ### Database Statistics

(defun get-database-stats ()
  "Get database statistics.

   Returns:
     Plist with :users, :chats, :messages, :secret-chats counts"
  (when *db-connection*
    (let ((users (dbi:fetch-one *db-connection* "SELECT COUNT(*) as count FROM users"))
          (chats (dbi:fetch-one *db-connection* "SELECT COUNT(*) as count FROM chats"))
          (messages (dbi:fetch-one *db-connection* "SELECT COUNT(*) as count FROM messages"))
          (secret (dbi:fetch-one *db-connection* "SELECT COUNT(*) as count FROM secret_chats")))
      (list :users (getf users :count)
            :chats (getf chats :count)
            :messages (getf messages :count)
            :secret-chats (getf secret :count)))))

(defun vacuum-database ()
  "Vacuum the database to reclaim space.

   Returns:
     T on success"
  (when *db-connection*
    (dbi:execute-query *db-connection* "VACUUM")
    t))

(defun clear-all-cache ()
  "Clear all cached data.

   Returns:
     T on success"
  (when *db-connection*
    (dbi:execute-query *db-connection* "DELETE FROM messages")
    (dbi:execute-query *db-connection* "DELETE FROM users")
    (dbi:execute-query *db-connection* "DELETE FROM chats")
    (dbi:execute-query *db-connection* "DELETE FROM file_cache")
    ;; Keep sessions and secret_chats
    t))
