;;; v0.22.0-tests.lisp --- Tests for v0.22.0 features
;;; Notification System, Contact Management, and Utilities

(in-package #:cl-telegram/tests)

;;; ======================================================================
;;; Notification System Tests
;;; ======================================================================

(test test-notification-settings-class
  "Test notification-settings class instantiation"
  (let ((settings (make-instance 'cl-telegram/api:notification-settings
                                 :show-preview t
                                 :show-sender t
                                 :sound-enabled t
                                 :priority :high)))
    (is true (cl-telegram/api:notification-show-preview settings))
    (is true (cl-telegram/api:notification-show-sender settings))
    (is true (cl-telegram/api:notification-sound-enabled settings))
    (is equal (cl-telegram/api:notification-priority settings) :high)))

(test test-chat-notification-settings-class
  "Test chat-notification-settings class instantiation"
  (let ((settings (make-instance 'cl-telegram/api:chat-notification-settings
                                 :chat-id -1001234567890
                                 :use-default nil
                                 :mute-until 9999999999)))
    (is equal (cl-telegram/api:chat-notification-chat-id settings) -1001234567890)
    (is false (cl-telegram/api:chat-notification-use-default settings))
    (is equal (cl-telegram/api:chat-notification-mute-until settings) 9999999999)))

(test test-notification-class
  "Test notification class instantiation"
  (let ((notification (make-instance 'cl-telegram/api:notification
                                     :id 12345
                                     :type :mention
                                     :chat-id -1001234567890
                                     :message-id 456
                                     :title "New Mention"
                                     :message "You were mentioned in a message"
                                     :timestamp (get-universal-time)
                                     :is-read nil)))
    (is equal (cl-telegram/api:notification-id notification) 12345)
    (is equal (cl-telegram/api:notification-type notification) :mention)
    (is false (cl-telegram/api:notification-is-read notification))))

(test test-notification-center-class
  "Test notification-center class instantiation"
  (let ((center (make-instance 'cl-telegram/api:notification-center
                               :max-size 50
                               :auto-clear-read t)))
    (is equal (cl-telegram/api:notification-center-max-size center) 50)
    (is true (cl-telegram/api:notification-center-auto-clear-read center))
    (is equal (cl-telegram/api:notification-center-unread-count center) 0)))

(test test-initialize-notification-settings
  "Test notification settings initialization"
  (let ((settings (cl-telegram/api:initialize-notification-settings)))
    (is-not null settings)
    (is true (cl-telegram/api:notification-show-preview settings))
    (is true (cl-telegram/api:notification-sound-enabled settings))))

(test test-update-notification-settings
  "Test updating notification settings"
  (cl-telegram/api:initialize-notification-settings)
  (let ((settings (cl-telegram/api:update-notification-settings
                   :show-preview nil
                   :sound-enabled nil
                   :priority :high)))
    (is false (cl-telegram/api:notification-show-preview settings))
    (is false (cl-telegram/api:notification-sound-enabled settings))
    (is equal (cl-telegram/api:notification-priority settings) :high)))

(test test-mute-unmute-chat
  "Test muting and unmuting chats"
  (let ((chat-id -1001234567890))
    ;; Mute for 1 hour (3600 seconds)
    (is true (cl-telegram/api:mute-chat chat-id :duration 3600))
    (is true (cl-telegram/api:chat-muted-p chat-id))
    ;; Unmute
    (is true (cl-telegram/api:unmute-chat chat-id))
    (is false (cl-telegram/api:chat-muted-p chat-id))))

(test test-notification-center-operations
  "Test notification center add/get/mark operations"
  (cl-telegram/api:initialize-notification-center)
  ;; Add notification
  (let ((notif (cl-telegram/api:add-notification
                :type :message
                :chat-id -1001234567890
                :message-id 123
                :title "Test Notification"
                :message "This is a test")))
    (is-not null notif)
    (is true (cl-telegram/api:notification-is-read notif)))
  ;; Get notifications
  (let ((notifs (cl-telegram/api:get-notifications :limit 10)))
    (is-not null notifs)
    (is-true (>= (length notifs) 1))))

(test test-rate-limiter-class
  "Test rate-limiter class instantiation"
  (let ((limiter (make-instance 'cl-telegram/api:rate-limiter
                                :max-requests 10
                                :window-seconds 60)))
    (is equal (cl-telegram/api:rate-limiter-max-requests limiter) 10)
    (is equal (cl-telegram/api:rate-limiter-window-seconds limiter) 60)))

(test test-rate-limiter-operations
  "Test rate limiter operations"
  (let ((limiter (cl-telegram/api:make-rate-limiter :max-requests 5 :window-seconds 1)))
    ;; First 5 requests should succeed
    (dotimes (i 5)
      (is true (cl-telegram/api:rate-limit-try limiter)))
    ;; 6th request should fail
    (is false (cl-telegram/api:rate-limit-try limiter))
    ;; Check status
    (let ((status (cl-telegram/api:rate-limit-status limiter)))
      (is equal (getf status :remaining) 0))))

;;; ======================================================================
;;; Contact Management Tests
;;; ======================================================================

(test test-contact-vcard-class
  "Test contact-vcard class instantiation"
  (let ((vcard (make-instance 'cl-telegram/api:contact-vcard
                              :formatted-name "John Doe"
                              :first-name "John"
                              :last-name "Doe"
                              :phone-numbers '("+1234567890")
                              :emails '("john@example.com")
                              :organization "Acme Corp"
                              :title "Developer")))
    (is equal (cl-telegram/api:contact-vcard-formatted-name vcard) "John Doe")
    (is equal (cl-telegram/api:contact-vcard-first-name vcard) "John")
    (is equal (cl-telegram/api:contact-vcard-last-name vcard) "Doe")
    (is equal (length (cl-telegram/api:contact-vcard-phone-numbers vcard)) 1)
    (is equal (cl-telegram/api:contact-vcard-organization vcard) "Acme Corp")))

(test test-contact-suggestion-class
  "Test contact-suggestion class instantiation"
  (let ((suggestion (make-instance 'cl-telegram/api:contact-suggestion
                                   :user-id 123456789
                                   :reason "Mutual contacts"
                                   :mutual-contacts 5
                                   :mutual-groups '("Group1" "Group2"))))
    (is equal (cl-telegram/api:contact-suggestion-user-id suggestion) 123456789)
    (is equal (cl-telegram/api:contact-suggestion-mutual-contacts suggestion) 5)))

(test test-contact-import-result-class
  "Test contact-import-result class instantiation"
  (let ((result (make-instance 'cl-telegram/api:contact-import-result
                               :imported 10
                               :updated 5
                               :skipped 2
                               :errors '("Invalid phone format"))))
    (is equal (cl-telegram/api:contact-import-result-imported result) 10)
    (is equal (cl-telegram/api:contact-import-result-updated result) 5)
    (is equal (cl-telegram/api:contact-import-result-skipped result) 2)))

(test test-blocked-user-class
  "Test blocked-user class instantiation"
  (let ((blocked (make-instance 'cl-telegram/api:blocked-user
                                :user-id 987654321
                                :blocked-at (get-universal-time)
                                :reason "Spam")))
    (is equal (cl-telegram/api:blocked-user-user-id blocked) 987654321)
    (is equal (cl-telegram/api:blocked-user-reason blocked) "Spam")))

(test test-make-vcard-from-user
  "Test vCard creation from user data"
  (let ((user '(("first_name" . "Jane")
                ("last_name" . "Smith")
                ("phone_number" . "+9876543210")
                ("organization" . "Test Corp")
                ("title" . "Manager"))))
    (let ((vcard (cl-telegram/api:make-vcard-from-user user)))
      (is equal (cl-telegram/api:contact-vcard-first-name vcard) "Jane")
      (is equal (cl-telegram/api:contact-vcard-last-name vcard) "Smith")
      (is equal (cl-telegram/api:contact-vcard-organization vcard) "Test Corp"))))

(test test-parse-vcard
  "Test vCard parsing"
  (let ((vcard-string "BEGIN:VCARD
VERSION:3.0
FN:Test User
N:User;Test;;;
TEL:+1234567890
ORG:Test Org
TITLE:Developer
END:VCARD"))
    (let ((vcard (cl-telegram/api:parse-vcard vcard-string)))
      (is-not null vcard)
      (is equal (cl-telegram/api:contact-vcard-formatted-name vcard) "Test User")
      (is equal (cl-telegram/api:contact-vcard-first-name vcard) "Test")
      (is equal (cl-telegram/api:contact-vcard-last-name vcard) "User"))))

(test test-time-to-minutes
  "Test time to minutes conversion"
  (is equal (cl-telegram/api:time-to-minutes 9 30) 570)  ; 9:30 AM = 570 minutes
  (is equal (cl-telegram/api:time-to-minutes 17 45) 1065)) ; 5:45 PM = 1065 minutes

(test test-minutes-to-time
  "Test minutes to time conversion"
  (let ((time (cl-telegram/api:minutes-to-time 570)))
    (is equal (car time) 9)
    (is equal (cadr time) 30))
  (let ((time (cl-telegram/api:minutes-to-time 1065)))
    (is equal (car time) 17)
    (is equal (cadr time) 45)))

;;; ======================================================================
;;; Utility Functions Tests
;;; ======================================================================

(test test-format-message-text
  "Test message text formatting"
  (is equal (cl-telegram/api:format-message-text "Hello" :bold t) "**Hello**")
  (is equal (cl-telegram/api:format-message-text "World" :italic t) "_World_")
  (is equal (cl-telegram/api:format-message-text "Code" :code t) "`Code`")
  (is equal (cl-telegram/api:format-message-text "Block" :pre t) "```Block```")
  (is equal (cl-telegram/api:format-message-text "Python" :pre t :language "python")
            "```python\nBlock```"))

(test test-strip-markdown
  "Test Markdown stripping"
  (is equal (cl-telegram/api:strip-markdown "**bold**") "bold")
  (is equal (cl-telegram/api:strip-markdown "_italic_") "italic")
  (is equal (cl-telegram/api:strip-markdown "`code`") "code")
  (is equal (cl-telegram/api:strip-markdown "[link](url)") "link"))

(test test-truncate-text
  "Test text truncation"
  (is equal (cl-telegram/api:truncate-text "Short" 10) "Short")
  (is equal (cl-telegram/api:truncate-text "This is a long text" 10) "This is a...")
  (is equal (cl-telegram/api:truncate-text "This is a long text" 10 :suffix "!") "This is a!"))

(test test-escape-markdown
  "Test Markdown escaping"
  (is equal (cl-telegram/api:escape-markdown "Hello *World*") "Hello \\*World\\*")
  (is equal (cl-telegram/api:escape-markdown "Test _italic_") "Test \\_italic\\_"))

(test test-format-relative-time
  "Test relative time formatting"
  (is equal (cl-telegram/api:format-relative-time (- (get-universal-time) 30)) "just now")
  (is equal (cl-telegram/api:format-relative-time (- (get-universal-time) 120)) "2 minutes ago")
  (is equal (cl-telegram/api:format-relative-time (- (get-universal-time) 7200)) "2 hours ago"))

(test test-format-datetime
  "Test datetime formatting"
  (let ((ts (get-universal-time)))
    (is-true (cl-ppcre:scan "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$"
                            (cl-telegram/api:format-datetime ts :format :iso-8601)))
    (is-true (cl-ppcre:scan "^\\d{4}-\\d{2}-\\d{2}$"
                            (cl-telegram/api:format-datetime ts :format :date)))))

(test test-make-mention
  "Test mention creation"
  (let ((mention (cl-telegram/api:make-mention 123456789 :text "Test User")))
    (is-true (cl-ppcre:scan "^\\[Test User\\]\\(tg://user\\?id=123456789\\)$" mention))))

(test test-parse-mention
  "Test mention parsing"
  (is equal (cl-telegram/api:parse-mention "[User](tg://user?id=123456789)") 123456789)
  (is null (cl-telegram/api:parse-mention "No mention here")))

(test test-make-chat-link
  "Test chat link creation"
  (let ((link (cl-telegram/api:make-chat-link -1001234567890)))
    (is equal link "https://t.me/c/1001234567890/-1001234567890")))

(test test-config-manager
  "Test configuration manager"
  (let ((config (cl-telegram/api:make-config-manager :auto-save nil)))
    ;; Set values
    (cl-telegram/api:set-config config "api_id" 12345)
    (cl-telegram/api:set-config config "api_hash" "test_hash")
    ;; Get values
    (is equal (cl-telegram/api:get-config config "api_id") 12345)
    (is equal (cl-telegram/api:get-config config "api_hash") "test_hash")
    (is equal (cl-telegram/api:get-config config "missing" "default") "default")
    ;; Delete value
    (cl-telegram/api:delete-config config "api_id")
    (is null (cl-telegram/api:get-config config "api_id"))))

(test test-log-message
  "Test logging function"
  (let ((old-level cl-telegram/api:*log-level*)
        (output (make-string-output-stream)))
    (unwind-protect
        (let ((cl-telegram/api:*log-output* output)
              (cl-telegram/api:*log-level* :debug))
          (cl-telegram/api:log-message :info "Test message")
          (let ((log (get-output-stream-string output)))
            (is-true (search "Test message" log))))
      (setf cl-telegram/api:*log-level* old-level))))

(test test-rate-limiter-with-wait
  "Test rate limiter with wait"
  (let ((limiter (cl-telegram/api:make-rate-limiter :max-requests 3 :window-seconds 1)))
    ;; Exhaust limit
    (dotimes (i 3)
      (is true (cl-telegram/api:rate-limit-try limiter)))
    ;; Wait and retry
    (sleep 1.1)
    (is true (cl-telegram/api:rate-limit-try limiter))))

;;; ======================================================================
;;; Edge Cases and Error Handling
;;; ======================================================================

(test test-empty-vcard-parse
  "Test parsing empty vCard"
  (is null (cl-telegram/api:parse-vcard "")))

(test test-invalid-vcard-parse
  "Test parsing invalid vCard"
  (is null (cl-telegram/api:parse-vcard "This is not a vCard")))

(test test-truncate-empty-text
  "Test truncating empty text"
  (is equal (cl-telegram/api:truncate-text "" 10) ""))

(test test-escape-empty-string
  "Test escaping empty string"
  (is equal (cl-telegram/api:escape-markdown "") ""))

(test test-rate-limiter-zero-requests
  "Test rate limiter with zero max requests"
  (let ((limiter (cl-telegram/api:make-rate-limiter :max-requests 0 :window-seconds 1)))
    (is false (cl-telegram/api:rate-limit-try limiter))))

(test test-config-empty-key
  "Test config with empty key"
  (let ((config (cl-telegram/api:make-config-manager :auto-save nil)))
    (cl-telegram/api:set-config config "" "value")
    (is equal (cl-telegram/api:get-config config "") "value")))

;;; ======================================================================
;;; Integration Tests
;;; ======================================================================

(test test-notification-workflow
  "Test complete notification workflow"
  (cl-telegram/api:initialize-notification-settings)
  (cl-telegram/api:initialize-notification-center)

  ;; Add multiple notifications
  (dotimes (i 5)
    (cl-telegram/api:add-notification
     :type :message
     :chat-id (- -1001234567890 i)
     :message-id (+ 100 i)
     :title (format nil "Notification ~A" i)
     :message (format nil "Message content ~A" i)))

  ;; Get all notifications
  (let ((notifs (cl-telegram/api:get-notifications :limit 10)))
    (is-true (>= (length notifs) 5)))

  ;; Mark all as read
  (is-true (>= (cl-telegram/api:mark-all-notifications-read) 5))

  ;; Get unread only - should be empty
  (let ((unread (cl-telegram/api:get-notifications :unread-only t)))
    (is equal (length unread) 0)))

(test test-contact-workflow
  "Test contact import/export workflow"
  ;; Create test vCard
  (let ((vcard-string "BEGIN:VCARD
VERSION:3.0
FN:Test Contact
N:Contact;Test;;;
TEL:+1234567890
EMAIL:test@example.com
END:VCARD"))
    (let ((vcard (cl-telegram/api:parse-vcard vcard-string)))
      (is-not null vcard)
      ;; Export back
      (let ((exported (cl-telegram/api:export-contact-vcard 123456)))
        ;; Should contain formatted name
        (is-true (search "Test Contact" exported)))))

(test test-utility-functions-integration
  "Test utility functions working together"
  ;; Format a mention with styling
  (let ((formatted (cl-telegram/api:format-message-text "User" :bold t))
        (mention (cl-telegram/api:make-mention 123456789 :text "User")))
    (is equal formatted "**User**")
    (is-true (search "tg://user?id=123456789" mention))))

;;; ======================================================================
;;; Global State Tests
;;; ======================================================================

(test test-notification-global-state
  "Test notification global state initialization"
  (is-not-null cl-telegram/api:*notification-settings*)
  (is-not-null cl-telegram/api:*notification-center*))

(test test-contact-global-state
  "Test contact global state initialization"
  (is-type cl-telegram/api:*contact-cache* 'hash-table)
  (is-true (>= (hash-table-count cl-telegram/api:*contact-cache*) 0)))

(run-tests '(
  ;; Notification tests
  test-notification-settings-class
  test-chat-notification-settings-class
  test-notification-class
  test-notification-center-class
  test-initialize-notification-settings
  test-update-notification-settings
  test-mute-unmute-chat
  test-notification-center-operations
  test-rate-limiter-class
  test-rate-limiter-operations

  ;; Contact tests
  test-contact-vcard-class
  test-contact-suggestion-class
  test-contact-import-result-class
  test-blocked-user-class
  test-make-vcard-from-user
  test-parse-vcard
  test-time-to-minutes
  test-minutes-to-time

  ;; Utility tests
  test-format-message-text
  test-strip-markdown
  test-truncate-text
  test-escape-markdown
  test-format-relative-time
  test-format-datetime
  test-make-mention
  test-parse-mention
  test-make-chat-link
  test-config-manager
  test-log-message
  test-rate-limiter-with-wait

  ;; Edge cases
  test-empty-vcard-parse
  test-invalid-vcard-parse
  test-truncate-empty-text
  test-escape-empty-string
  test-rate-limiter-zero-requests
  test-config-empty-key

  ;; Integration
  test-notification-workflow
  test-contact-workflow
  test-utility-functions-integration

  ;; Global state
  test-notification-global-state
  test-contact-global-state
))
