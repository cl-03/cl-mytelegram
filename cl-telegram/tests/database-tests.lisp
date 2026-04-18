;;; database-tests.lisp --- Tests for local cache database

(in-package #:cl-telegram/tests)

(def-suite* database-tests
  :description "Tests for local cache database")

;;; ### Helper Functions

(defvar *test-db-path* nil
  "Path to test database file")

(defun setup-test-database ()
  "Set up a test database in memory.

   Returns:
     T on success"
  ;; Use in-memory SQLite for tests
  (setf *test-db-path* ":memory:")
  (setf cl-telegram/api::*db-connection*
        (dbi:connect :sqlite3 :database-name *test-db-path*))
  (cl-telegram/api::create-tables cl-telegram/api::*db-connection*)
  t)

(defun teardown-test-database ()
  "Tear down test database.

   Returns:
     T on success"
  (when cl-telegram/api::*db-connection*
    (dbi:disconnect cl-telegram/api::*db-connection*)
    (setf cl-telegram/api::*db-connection* nil))
  (setf *test-db-path* nil)
  t)

(defmacro with-test-database (&body body)
  "Execute body with test database setup/teardown."
  `(unwind-protect
       (progn
         (setup-test-database)
         ,@body)
    (teardown-test-database)))

;;; ### Database Initialization Tests

(test test-init-database
  "Test database initialization"
  (with-test-database
    (is cl-telegram/api::*db-connection* "Connection should be established")
    (is (string= *test-db-path* ":memory:") "Should use in-memory database")))

;;; ### User Cache Tests

(test test-cache-user
  "Test caching a user"
  (with-test-database
    (let ((user '(:id 123
                  :first-name "John"
                  :last-name "Doe"
                  :username "johndoe"
                  :phone "+1234567890"
                  :is-bot nil
                  :is-contact t
                  :access-hash 999888)))
      (is (cl-telegram/api:cache-user user) "Should cache user successfully")

      ;; Retrieve cached user
      (let ((cached (cl-telegram/api:get-cached-user 123)))
        (is cached "Should retrieve cached user")
        (is (= (getf cached :id) 123) "User ID should match")
        (is (string= (getf cached :first-name) "John") "First name should match")
        (is (string= (getf cached :username) "johndoe") "Username should match")))))

(test test-get-cached-user-not-found
  "Test getting non-existent user"
  (with-test-database
    (let ((cached (cl-telegram/api:get-cached-user 999)))
      (is (null cached) "Should return NIL for non-existent user"))))

(test test-search-cached-users
  "Test searching cached users"
  (with-test-database
    ;; Cache multiple users
    (cl-telegram/api:cache-user '(:id 1 :first-name "Alice" :username "alice"))
    (cl-telegram/api:cache-user '(:id 2 :first-name "Bob" :username "bob"))
    (cl-telegram/api:cache-user '(:id 3 :first-name "Charlie" :username "charlie"))
    (cl-telegram/api:cache-user '(:id 4 :first-name "Alex" :username "alex"))

    ;; Search by first name
    (let ((results (cl-telegram/api:search-cached-users "Al")))
      (is (>= (length results) 2) "Should find Alice and Alex")
      (is (member "Alice" (mapcar #'(lambda (u) (getf u :first-name)) results)
                  :test #'string=)
          "Should include Alice")
      (is (member "Alex" (mapcar #'(lambda (u) (getf u :first-name)) results)
                  :test #'string=)
          "Should include Alex"))

    ;; Search by username
    (let ((results (cl-telegram/api:search-cached-users "bob")))
      (is (= (length results) 1) "Should find only Bob")
      (is (string= (getf (car results) :username) "bob")))))

;;; ### Chat Cache Tests

(test test-cache-chat
  "Test caching a chat"
  (with-test-database
    (let ((chat '(:id 456
                  :type (:@type :chat-type-private)
                  :title "Test Chat"
                  :username "testchat"
                  :unread-count 5
                  :is-pinned t
                  :access-hash 777666)))
      (is (cl-telegram/api:cache-chat chat) "Should cache chat")

      ;; Retrieve
      (let ((cached (cl-telegram/api:get-cached-chat 456)))
        (is cached "Should retrieve cached chat")
        (is (= (getf cached :id) 456) "Chat ID should match")
        (is (string= (getf cached :title) "Test Chat") "Title should match")
        (is (= (getf cached :unread-count) 5) "Unread count should match")))))

(test test-list-cached-chats
  "Test listing cached chats"
  (with-test-database
    ;; Cache chats with different last message dates
    (cl-telegram/api:cache-chat '(:id 1 :title "Chat 1" :last-message-date 100))
    (cl-telegram/api:cache-chat '(:id 2 :title "Chat 2" :last-message-date 300))
    (cl-telegram/api:cache-chat '(:id 3 :title "Chat 3" :last-message-date 200))

    (let ((chats (cl-telegram/api:list-cached-chats :limit 10)))
      (is (= (length chats) 3) "Should return all chats")
      ;; Should be ordered by last message date descending
      (is (= (getf (car chats) :id) 2) "Chat 2 should be first (date 300)")
      (is (= (getf (cadr chats) :id) 3) "Chat 3 should be second (date 200)"))))

;;; ### Message Cache Tests

(test test-cache-message
  "Test caching a message"
  (with-test-database
    (let ((message '(:id 789
                     :chat-id 123
                     :from (:id 456 :first-name "Sender")
                     :date 1609459200
                     :text "Hello, World!"
                     :media nil
                     :reply-to nil
                     :forward-from nil)))
      (is (cl-telegram/api:cache-message message) "Should cache message")

      ;; Retrieve
      (let ((cached (cl-telegram/api:get-cached-message 123 789)))
        (is cached "Should retrieve cached message")
        (is (= (getf cached :id) 789) "Message ID should match")
        (is (string= (getf cached :text) "Hello, World!") "Text should match")
        (is (= (getf cached :chat-id) 123) "Chat ID should match")))))

(test test-get-cached-messages
  "Test getting multiple messages"
  (with-test-database
    ;; Cache messages with different dates
    (cl-telegram/api:cache-message '(:id 1 :chat-id 100 :from (:id 1) :date 100 :text "First"))
    (cl-telegram/api:cache-message '(:id 2 :chat-id 100 :from (:id 1) :date 200 :text "Second"))
    (cl-telegram/api:cache-message '(:id 3 :chat-id 100 :from (:id 1) :date 300 :text "Third"))
    (cl-telegram/api:cache-message '(:id 4 :chat-id 200 :from (:id 1) :date 400 :text "Other chat"))

    ;; Get messages for chat 100
    (let ((messages (cl-telegram/api:get-cached-messages 100 :limit 10)))
      (is (= (length messages) 3) "Should return 3 messages")
      ;; Should be ordered by date descending
      (is (= (getf (car messages) :id) 3) "Third should be first")
      (is (= (getf (cadr messages) :id) 2) "Second should be second")
      (is (= (getf (caddr messages) :id) 1) "First should be third"))

    ;; Test pagination
    (let ((messages (cl-telegram/api:get-cached-messages 100 :limit 2 :offset 0)))
      (is (= (length messages) 2) "Should return 2 messages with limit"))

    ;; Test before-date filter
    (let ((messages (cl-telegram/api:get-cached-messages 100 :before-date 250)))
      (is (= (length messages) 2) "Should return messages before date 250"))))

(test test-search-cached-messages
  "Test searching cached messages"
  (with-test-database
    (cl-telegram/api:cache-message '(:id 1 :chat-id 100 :from (:id 1) :date 100 :text "Hello world"))
    (cl-telegram/api:cache-message '(:id 2 :chat-id 100 :from (:id 1) :date 200 :text "Goodbye world"))
    (cl-telegram/api:cache-message '(:id 3 :chat-id 100 :from (:id 1) :date 300 :text "Hello again"))

    ;; Search for "Hello"
    (let ((results (cl-telegram/api:search-cached-messages 100 "Hello")))
      (is (= (length results) 2) "Should find 2 messages with Hello")
      (is (member "Hello world" (mapcar #'(lambda (m) (getf m :text)) results)
                  :test #'string=)
          "Should include 'Hello world'")
      (is (member "Hello again" (mapcar #'(lambda (m) (getf m :text)) results)
                  :test #'string=)
          "Should include 'Hello again'"))))

(test test-delete-cached-message
  "Test deleting a cached message"
  (with-test-database
    (cl-telegram/api:cache-message '(:id 999 :chat-id 100 :from (:id 1) :date 100 :text "To delete"))

    ;; Delete
    (is (cl-telegram/api:delete-cached-message 100 999) "Should delete message")

    ;; Verify deletion
    (let ((cached (cl-telegram/api:get-cached-message 100 999)))
      (is (null cached) "Message should be deleted"))))

(test test-clear-chat-cache
  "Test clearing all messages for a chat"
  (with-test-database
    (cl-telegram/api:cache-message '(:id 1 :chat-id 100 :from (:id 1) :date 100 :text "Msg 1"))
    (cl-telegram/api:cache-message '(:id 2 :chat-id 100 :from (:id 1) :date 200 :text "Msg 2"))
    (cl-telegram/api:cache-message '(:id 3 :chat-id 200 :from (:id 1) :date 300 :text "Other chat"))

    ;; Clear chat 100
    (is (cl-telegram/api:clear-chat-cache 100) "Should clear chat cache")

    ;; Verify
    (let ((messages-100 (cl-telegram/api:get-cached-messages 100))
          (messages-200 (cl-telegram/api:get-cached-messages 200)))
      (is (= (length messages-100) 0) "Chat 100 should be empty")
      (is (= (length messages-200) 1) "Chat 200 should still have messages"))))

;;; ### Session Storage Tests

(test test-cache-session
  "Test caching authentication session"
  (with-test-database
    (let ((auth-key (make-array 256 :element-type '(unsigned-byte 8) :initial-element #x42))
          (server-salt (make-array 8 :element-type '(unsigned-byte 8) :initial-element #x55)))
      (is (cl-telegram/api:cache-session "session-123" 1 auth-key server-salt 456)
          "Should cache session")

      ;; Get current session
      (let ((session (cl-telegram/api:get-current-session)))
        (is session "Should retrieve current session")
        (is (string= (getf session :session-id) "session-123") "Session ID should match")
        (is (= (getf session :dc-id) 1) "DC ID should match")
        (is (= (getf session :user-id) 456) "User ID should match")
        (is (equalp (getf session :auth-key) auth-key) "Auth key should match")))))

(test test-get-cached-auth-key
  "Test getting cached auth key"
  (with-test-database
    (let ((auth-key (make-array 256 :element-type '(unsigned-byte 8) :initial-element #x99)))
      (cl-telegram/api:cache-session "session-456" 2 auth-key
                                     (make-array 8 :element-type '(unsigned-byte 8)))

      (let ((cached-key (cl-telegram/api:get-cached-auth-key "session-456")))
        (is (equalp cached-key auth-key) "Auth key should match")))))

;;; ### Settings Storage Tests

(test test-set-setting
  "Test storing settings"
  (with-test-database
    (is (cl-telegram/api:set-setting :theme "dark") "Should store string setting")
    (is (cl-telegram/api:set-setting :notifications t) "Should store boolean setting")
    (is (cl-telegram/api:set-setting :volume 75) "Should store number setting")
    (is (cl-telegram/api:set-setting :favorites '(1 2 3)) "Should store list setting")

    ;; Retrieve
    (is (string= (cl-telegram/api:get-setting :theme) "dark") "Should retrieve string")
    (is (cl-telegram/api:get-setting :notifications) "Should retrieve boolean true")
    (is (= (cl-telegram/api:get-setting :volume) 75) "Should retrieve number")
    (is (equal (cl-telegram/api:get-setting :favorites) '(1 2 3)) "Should retrieve list")
    (is (eq (cl-telegram/api:get-setting :nonexistent :default) :default)
        "Should return default for missing setting")))

;;; ### File Cache Tests

(test test-cache-file-info
  "Test caching file metadata"
  (with-test-database
    (is (cl-telegram/api:cache-file-info "file-123" :photo "/tmp/photo.jpg" 102400
                                          :mime-type "image/jpeg"
                                          :thumb-file-id "thumb-456")
        "Should cache file info")

    ;; Retrieve
    (let ((path (cl-telegram/api:get-cached-file-path "file-123")))
      (is (string= path "/tmp/photo.jpg") "File path should match"))))

;;; ### Database Statistics Tests

(test test-get-database-stats
  "Test database statistics"
  (with-test-database
    ;; Add some data
    (cl-telegram/api:cache-user '(:id 1 :first-name "User1"))
    (cl-telegram/api:cache-user '(:id 2 :first-name "User2"))
    (cl-telegram/api:cache-chat '(:id 100 :title "Chat1"))
    (cl-telegram/api:cache-message '(:id 1 :chat-id 100 :from (:id 1) :date 100 :text "Msg"))
    (cl-telegram/api:cache-message '(:id 2 :chat-id 100 :from (:id 1) :date 200 :text "Msg"))

    (let ((stats (cl-telegram/api:get-database-stats)))
      (is (= (getf stats :users) 2) "Should have 2 users")
      (is (= (getf stats :chats) 1) "Should have 1 chat")
      (is (= (getf stats :messages) 2) "Should have 2 messages"))))

(test test-clear-all-cache
  "Test clearing all cache"
  (with-test-database
    ;; Add data
    (cl-telegram/api:cache-user '(:id 1 :first-name "User"))
    (cl-telegram/api:cache-chat '(:id 100 :title "Chat"))
    (cl-telegram/api:cache-message '(:id 1 :chat-id 100 :from (:id 1) :date 100 :text "Msg"))
    (cl-telegram/api:cache-file-info "file-1" :photo "/tmp/f.jpg" 100)

    ;; Clear
    (is (cl-telegram/api:clear-all-cache) "Should clear cache")

    ;; Verify cleared (sessions and secret_chats should remain)
    (let ((stats (cl-telegram/api:get-database-stats)))
      (is (= (getf stats :users) 0) "Users should be cleared")
      (is (= (getf stats :chats) 0) "Chats should be cleared")
      (is (= (getf stats :messages) 0) "Messages should be cleared"))))
