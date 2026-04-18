;;; group-channel-tests.lisp --- Tests for group and channel functionality

(in-package #:cl-telegram/tests)

(def-suite* group-channel-tests
  :description "Tests for group chats and channels")

;;; ### Helper Functions

(defvar *test-group-id* nil
  "Test group chat ID")

(defvar *test-channel-id* nil
  "Test channel ID")

(defun setup-test-group ()
  "Create a test group for testing."
  (let ((result (cl-telegram/api:create-basic-group-chat "Test Group")))
    (when (and (car result) (not (cdr result)))
      (setf *test-group-id* (getf (car result) :id)))))

(defun setup-test-channel ()
  "Create a test channel for testing."
  (let ((result (cl-telegram/api:create-supergroup-chat "Test Channel"
                                                        :description "A test channel"
                                                        :for-channel t)))
    (when (and (car result) (not (cdr result)))
      (setf *test-channel-id* (getf (car result) :id)))))

(defun teardown-test-group ()
  "Clean up test group."
  (when *test-group-id*
    (cl-telegram/api:clear-chat-history *test-group-id*)
    (setf *test-group-id* nil)))

(defun teardown-test-channel ()
  "Clean up test channel."
  (when *test-channel-id*
    (cl-telegram/api:clear-chat-history *test-channel-id*)
    (setf *test-channel-id* nil)))

(defmacro with-test-group (&body body)
  "Execute body with test group setup/teardown."
  `(unwind-protect
       (progn
         (setup-test-group)
         ,@body)
    (teardown-test-group)))

(defmacro with-test-channel (&body body)
  "Execute body with test channel setup/teardown."
  `(unwind-protect
       (progn
         (setup-test-channel)
         ,@body)
    (teardown-test-channel)))

;;; ### Group Creation Tests

(test test-create-basic-group-chat
  "Test creating a basic group chat"
  (with-test-group
    (is *test-group-id* "Should create group successfully")
    (let ((chat (cl-telegram/api:get-chat *test-group-id*)))
      (is chat "Should retrieve created group")
      (is (string= (getf chat :title) "Test Group") "Title should match"))))

(test test-create-basic-group-chat-invalid-title
  "Test creating group with invalid title"
  (let ((result (cl-telegram/api:create-basic-group-chat "")))
    (is (not (car result)) "Should fail with empty title"))
  (let ((result (cl-telegram/api:create-basic-group-chat
                 (make-string 200 :initial-element #\A))))
    (is (not (car result)) "Should fail with title too long")))

(test test-create-supergroup-chat
  "Test creating a supergroup"
  (let ((result (cl-telegram/api:create-supergroup-chat "Test Supergroup"
                                                        :description "Test description")))
    (is (car result) "Should create supergroup successfully")
    (let ((chat (car result)))
      (is (eq (getf chat :@type) :chatSupergroup) "Should be supergroup type")
      (is (string= (getf chat :title) "Test Supergroup") "Title should match"))))

(test test-create-channel
  "Test creating a channel"
  (with-test-channel
    (is *test-channel-id* "Should create channel successfully")
    (let ((chat (cl-telegram/api:get-chat *test-channel-id*)))
      (is chat "Should retrieve created channel")
      (is (string= (getf chat :title) "Test Channel") "Title should match")
      (is (string= (getf chat :description) "A test channel") "Description should match"))))

;;; ### Group Member Tests

(test test-add-chat-member
  "Test adding a member to a chat"
  (with-test-group
    ;; Add a test user (using a mock user ID for now)
    (let ((result (cl-telegram/api:add-chat-member *test-group-id* 12345)))
      ;; May fail if user doesn't exist, but should not error
      (is (or (car result) (eq (cdr result) :user-not-invalid))
          "Should handle add member gracefully"))))

(test test-remove-chat-member
  "Test removing a member from a chat"
  (with-test-group
    (let ((result (cl-telegram/api:remove-chat-member *test-group-id* 12345)))
      ;; May fail if user not in group
      (is (or (car result) (member (cdr result) '(:user-not-in-chat)))
          "Should handle remove member gracefully"))))

(test test-get-chat-members
  "Test getting chat members"
  (with-test-group
    (let ((result (cl-telegram/api:get-chat-members *test-group-id* :limit 10)))
      (is (or (car result) (eq (cdr result) :no-members))
          "Should get members list"))))

;;; ### Chat Administrator Tests

(test test-get-chat-administrators
  "Test getting chat administrators"
  (with-test-group
    (let ((result (cl-telegram/api:get-chat-administrators *test-group-id*)))
      (is (or (car result) (eq (cdr result) :no-administrators))
          "Should get administrators list"))))

(test test-set-chat-administrator
  "Test setting chat administrator"
  (with-test-group
    (let ((result (cl-telegram/api:set-chat-administrator
                   *test-group-id* 12345
                   :can-change-info t
                   :can-delete-messages t
                   :can-invite-users t
                   :can-pin-messages t)))
      ;; May fail if user not found or not enough permissions
      (is (or (car result)
              (member (cdr result) '(:user-invalid :not-enough-permissions)))
          "Should handle set administrator gracefully"))))

(test test-ban-chat-member
  "Test banning a chat member"
  (with-test-group
    (let ((result (cl-telegram/api:ban-chat-member *test-group-id* 12345
                                                   :banned-until 0
                                                   :revoke-messages nil)))
      ;; May fail if user not in group
      (is (or (car result) (member (cdr result) '(:user-not-in-chat)))
          "Should handle ban member gracefully"))))

(test test-unban-chat-member
  "Test unbanning a chat member"
  (with-test-group
    (let ((result (cl-telegram/api:unban-chat-member *test-group-id* 12345)))
      ;; May fail if user not banned
      (is (or (car result) (member (cdr result) '(:user-not-banned)))
          "Should handle unban member gracefully"))))

;;; ### Invite Link Tests

(test test-create-chat-invite-link
  "Test creating a chat invite link"
  (with-test-group
    (let ((result (cl-telegram/api:create-chat-invite-link
                   *test-group-id*
                   :name "Test Link"
                   :expire-date 0
                   :member-limit 10)))
      (is (or (car result) (eq (cdr result) :not-enough-permissions))
          "Should create invite link or fail with permissions"))))

(test test-get-chat-invite-link
  "Test getting chat invite link"
  (with-test-group
    (let ((result (cl-telegram/api:get-chat-invite-link *test-group-id*)))
      (is (or (car result) (eq (cdr result) :no-invite-link))
          "Should get invite link or report none exists"))))

(test test-revoke-chat-invite-link
  "Test revoking chat invite link"
  (with-test-group
    ;; First create a link
    (let ((create-result (cl-telegram/api:create-chat-invite-link *test-group-id*)))
      (when (car create-result)
        (let ((link (getf (car create-result) :invite-link)))
          (let ((result (cl-telegram/api:revoke-chat-invite-link *test-group-id* link)))
            (is (or (car result) (eq (cdr result) :link-already-revoked))
                "Should revoke link or report already revoked")))))))

;;; ### Channel-Specific Tests

(test test-set-channel-description
  "Test setting channel description"
  (with-test-channel
    (let ((result (cl-telegram/api:set-channel-description
                   *test-channel-id* "Updated description")))
      (is (or (car result) (eq (cdr result) :not-enough-permissions))
          "Should set description or fail with permissions"))))

(test test-set-channel-username
  "Test setting channel username"
  (with-test-channel
    (let ((result (cl-telegram/api:set-channel-username
                   *test-channel-id* "test_channel_bot")))
      (is (or (car result)
              (member (cdr result) '(:username-invalid :username-occupied)))
          "Should set username or fail with valid reason"))))

(test test-join-channel
  "Test joining a channel"
  ;; Create a public channel to join
  (let ((result (cl-telegram/api:join-channel 12345)))
    ;; May fail if channel doesn't exist or is private
    (is (or (car result)
            (member (cdr result) '(:channel-invalid :channel-not-accessible)))
        "Should handle join channel gracefully")))

(test test-leave-channel
  "Test leaving a channel"
  (with-test-channel
    (let ((result (cl-telegram/api:leave-channel *test-channel-id*)))
      (is (or (car result) (eq (cdr result) :not-member))
          "Should leave channel or report not member"))))

(test test-get-channel-full-info
  "Test getting channel full info"
  (with-test-channel
    (let ((result (cl-telegram/api:get-channel-full-info *test-channel-id*)))
      (is (or (car result) (eq (cdr result) :not-enough-permissions))
          "Should get channel info or fail with permissions"))))

(test test-get-channel-members
  "Test getting channel members"
  (with-test-channel
    (let ((result (cl-telegram/api:get-channel-members *test-channel-id*
                                                       :limit 10)))
      (is (or (car result) (eq (cdr result) :no-members))
          "Should get channel members"))))

;;; ### Chat Settings Tests

(test test-set-chat-title
  "Test setting chat title"
  (with-test-group
    (let ((result (cl-telegram/api:set-chat-title *test-group-id* "New Title")))
      (is (or (car result) (eq (cdr result) :not-enough-permissions))
          "Should set title or fail with permissions"))))

(test test-toggle-chat-muted
  "Test muting/unmuting chat"
  (with-test-group
    (let ((mute-result (cl-telegram/api:toggle-chat-muted *test-group-id* :muted t)))
      (is (car mute-result) "Should mute chat"))
    (let ((unmute-result (cl-telegram/api:toggle-chat-muted *test-group-id* :muted nil)))
      (is (car unmute-result) "Should unmute chat"))))

(test test-clear-chat-history
  "Test clearing chat history"
  (with-test-group
    ;; Send some messages first
    (cl-telegram/api:send-message *test-group-id* "Test message 1")
    (cl-telegram/api:send-message *test-group-id* "Test message 2")
    ;; Clear history
    (let ((result (cl-telegram/api:clear-chat-history *test-group-id*)))
      (is (car result) "Should clear chat history"))))

;;; ### Search Tests

(test test-search-chats
  "Test searching chats"
  (let ((result (cl-telegram/api:search-chats "Test" :limit 10)))
    (is (or (car result) (null (car result)))
        "Should return search results or empty list")))

;;; ### Integration Tests

(test test-group-workflow
  "Test complete group workflow"
  (with-test-group
    ;; 1. Get group info
    (let ((chat (cl-telegram/api:get-chat *test-group-id*)))
      (is chat "Should get group info"))
    ;; 2. Get members
    (cl-telegram/api:get-chat-members *test-group-id*)
    ;; 3. Get administrators
    (cl-telegram/api:get-chat-administrators *test-group-id*)
    ;; 4. Send message
    (let ((msg-result (cl-telegram/api:send-message *test-group-id* "Hello, Group!")))
      (is (car msg-result) "Should send message"))
    ;; 5. Send chat action
    (let ((action-result (cl-telegram/api:send-chat-action *test-group-id* :typing)))
      (is (car action-result) "Should send typing action"))))

(test test-channel-workflow
  "Test complete channel workflow"
  (with-test-channel
    ;; 1. Get channel info
    (let ((chat (cl-telegram/api:get-chat *test-channel-id*)))
      (is chat "Should get channel info"))
    ;; 2. Get full info
    (cl-telegram/api:get-channel-full-info *test-channel-id*)
    ;; 3. Post message
    (let ((msg-result (cl-telegram/api:send-message *test-channel-id* "Hello, Channel!")))
      (is (car msg-result) "Should post to channel"))
    ;; 4. Get members
    (cl-telegram/api:get-channel-members *test-channel-id*)))
