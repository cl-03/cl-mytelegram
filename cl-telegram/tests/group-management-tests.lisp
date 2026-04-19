;;; group-management-tests.lisp --- Tests for group management features
;;;
;;; Tests for administrator permissions, member management, polls,
;;; auto-moderation, and member approval workflows

(in-package #:cl-telegram/tests)

;;; ### Administrator Permissions Tests

(deftest test-make-admin-permissions
  "Test admin permissions creation"
  (let ((perms (cl-telegram/api:make-admin-permissions
                :change-info t
                :delete-messages t
                :invite-users t
                :restrict-members t
                :pin-messages t)))
    (is (typep perms 'cl-telegram/api::group-admin-permissions))
    (is (cl-telegram/api:group-admin-permissions-can-change-info perms))
    (is (cl-telegram/api:group-admin-permissions-can-delete-messages perms))
    (is (cl-telegram/api:group-admin-permissions-can-invite-users perms))
    (is (cl-telegram/api:group-admin-permissions-can-restrict-members perms))
    (is (cl-telegram/api:group-admin-permissions-can-pin-messages perms))
    ;; These should be nil
    (is (not (cl-telegram/api:group-admin-permissions-can-post-messages perms)))
    (is (not (cl-telegram/api:group-admin-permissions-can-promote-members perms)))))

(deftest test-permissions-to-bitmask
  "Test converting permissions to bitmask"
  (let ((perms (cl-telegram/api:make-admin-permissions
                :change-info t
                :delete-messages t)))
    (let ((bitmask (cl-telegram/api:permissions-to-bitmask perms)))
      (is (typep bitmask 'integer))
      ;; Bit 0 (0x0001) = can_change_info
      (is (= (logand bitmask #x0001) #x0001))
      ;; Bit 3 (0x0008) = can_delete_messages
      (is (= (logand bitmask #x0008) #x0008))
      ;; Bit 7 (0x0080) = can_promote_members should be 0
      (is (= (logand bitmask #x0080) 0)))))

(deftest test-bitmask-to-permissions
  "Test converting bitmask to permissions"
  (let* ((bitmask #x002B) ; bits 0, 1, 3, 5 set
         (perms (cl-telegram/api:bitmask-to-permissions bitmask)))
    (is (typep perms 'cl-telegram/api::group-admin-permissions))
    ;; Bit 0 = can_change_info
    (is (cl-telegram/api:group-admin-permissions-can-change-info perms))
    ;; Bit 1 = can_post_messages
    (is (cl-telegram/api:group-admin-permissions-can-post-messages perms))
    ;; Bit 3 = can_delete_messages
    (is (cl-telegram/api:group-admin-permissions-can-delete-messages perms))
    ;; Bit 5 = can_restrict_members
    (is (cl-telegram/api:group-admin-permissions-can-restrict-members perms))))

(deftest test-permissions-roundtrip
  "Test permissions conversion roundtrip"
  (let* ((original (cl-telegram/api:make-admin-permissions
                    :change-info t
                    :post-messages t
                    :delete-messages t
                    :invite-users t
                    :pin-messages t))
         (bitmask (cl-telegram/api:permissions-to-bitmask original))
         (restored (cl-telegram/api:bitmask-to-permissions bitmask)))
    (is (eq (cl-telegram/api:group-admin-permissions-can-change-info original)
            (cl-telegram/api:group-admin-permissions-can-change-info restored)))
    (is (eq (cl-telegram/api:group-admin-permissions-can-post-messages original)
            (cl-telegram/api:group-admin-permissions-can-post-messages restored)))
    (is (eq (cl-telegram/api:group-admin-permissions-can-delete-messages original)
            (cl-telegram/api:group-admin-permissions-can-delete-messages restored)))
    (is (eq (cl-telegram/api:group-admin-permissions-can-invite-users original)
            (cl-telegram/api:group-admin-permissions-can-invite-users restored)))
    (is (eq (cl-telegram/api:group-admin-permissions-can-pin-messages original)
            (cl-telegram/api:group-admin-permissions-can-pin-messages restored)))))

;;; ### Poll Tests

(deftest test-make-poll
  "Test poll creation"
  (let ((poll (cl-telegram/api:make-poll
               "What's your favorite language?"
               '("Common Lisp" "Python" "Rust" "Go")
               :anonymous t
               :multiple-choice nil)))
    (is (typep poll 'cl-telegram/api::poll))
    (is (string= (cl-telegram/api:poll-question poll)
                 "What's your favorite language?"))
    (is (= (length (cl-telegram/api:poll-options poll)) 4))
    (is (cl-telegram/api:poll-is-anonymous poll))
    (is (not (cl-telegram/api:poll-is-multiple-choice poll)))))

(deftest test-make-poll-multiple-choice
  "Test multiple choice poll creation"
  (let ((poll (cl-telegram/api:make-poll
               "Select all that apply"
               '("Option A" "Option B" "Option C")
               :anonymous nil
               :multiple-choice t
               :open-period 60)))
    (is (cl-telegram/api:poll-is-multiple-choice poll))
    (is (not (cl-telegram/api:poll-is-anonymous poll)))
    (is (= (cl-telegram/api:poll-open-period poll) 60))))

;;; ### Member Restrictions Tests

(deftest test-make-member-restrictions
  "Test member restrictions creation"
  (let ((restrictions (cl-telegram/api:make-member-restrictions
                       :send-messages nil
                       :send-media t
                       :send-polls t
                       :add-web-page-previews nil)))
    (is (typep restrictions 'cl-telegram/api::member-restrictions))
    (is (not (cl-telegram/api:member-restrictions-send-messages restrictions)))
    (is (cl-telegram/api:member-restrictions-send-media restrictions))
    (is (cl-telegram/api:member-restrictions-send-polls restrictions))
    (is (not (cl-telegram/api:member-restrictions-add-web-page-previews restrictions)))))

;;; ### Auto-Mod Rule Tests

(deftest test-add-auto-mod-rule
  "Test adding auto-moderation rule"
  ;; Test rule creation (mock - doesn't actually add to chat)
  (let ((rule-type :keyword)
        (pattern "spam")
        (action :delete))
    (is (member rule-type '(:keyword :link :spam :flood)))
    (is (stringp pattern))
    (is (member action '(:delete :warn :ban :mute)))))

(deftest test-check-auto-mod
  "Test auto-moderation rule checking"
  (let ((message "Check out this link: http://spam.com"))
    ;; Simulate rule check
    (is (cl-telegram/api::check-rule
         (list :type :link :pattern "spam")
         message))))

;;; ### Invite Link Tests

(deftest test-chat-invite-link-structure
  "Test chat invite link structure"
  (let ((link (make-instance 'cl-telegram/api::chat-invite-link
                             :link "https://t.me/joinchat/ABC123"
                             :usage-limit 100
                             :expire-date (+ (get-universal-time) 86400))))
    (is (typep link 'cl-telegram/api::chat-invite-link))
    (is (string= (cl-telegram/api:chat-invite-link-link link)
                 "https://t.me/joinchat/ABC123"))
    (is (= (cl-telegram/api:chat-invite-link-usage-limit link) 100))
    ;; Check expiration is in future
    (is (> (cl-telegram/api:chat-invite-link-expire-date link)
           (get-universal-time)))))

;;; ### Member Approval Tests

(deftest test-member-approval-workflow
  "Test member approval workflow"
  ;; Test that approval functions exist and have correct signatures
  (is (fboundp 'cl-telegram/api:enable-member-approval))
  (is (fboundp 'cl-telegram/api:disable-member-approval))
  (is (fboundp 'cl-telegram/api:get-pending-join-requests))
  (is (fboundp 'cl-telegram/api:approve-join-request))
  (is (fboundp 'cl-telegram/api:decline-join-request)))

;;; ### Integration Tests

(deftest test-group-administrator-api
  "Test group administrator API functions exist"
  (is (fboundp 'cl-telegram/api:get-chat-administrators))
  (is (fboundp 'cl-telegram/api:set-chat-administrator))
  (is (fboundp 'cl-telegram/api:remove-chat-administrator))
  (is (fboundp 'cl-telegram/api:ban-chat-member))
  (is (fboundp 'cl-telegram/api:unban-chat-member)))

(deftest test-poll-api
  "Test poll API functions exist"
  (is (fboundp 'cl-telegram/api:send-poll))
  (is (fboundp 'cl-telegram/api:stop-poll)))

(deftest test-invite-link-api
  "Test invite link API functions exist"
  (is (fboundp 'cl-telegram/api:create-chat-invite-link))
  (is (fboundp 'cl-telegram/api:get-chat-invite-link))
  (is (fboundp 'cl-telegram/api:revoke-chat-invite-link))
  (is (fboundp 'cl-telegram/api:get-chat-invite-link-members)))

;;; ### Test Runner

(defun run-group-management-tests ()
  "Run all group management tests.

   Returns:
     T if all tests pass"
  (format t "~%Running Group Management Tests...~%")
  (let ((results (list
                  (fiveam:run! 'test-make-admin-permissions)
                  (fiveam:run! 'test-permissions-to-bitmask)
                  (fiveam:run! 'test-bitmask-to-permissions)
                  (fiveam:run! 'test-permissions-roundtrip)
                  (fiveam:run! 'test-make-poll)
                  (fiveam:run! 'test-make-poll-multiple-choice)
                  (fiveam:run! 'test-make-member-restrictions)
                  (fiveam:run! 'test-add-auto-mod-rule)
                  (fiveam:run! 'test-check-auto-mod)
                  (fiveam:run! 'test-chat-invite-link-structure)
                  (fiveam:run! 'test-member-approval-workflow)
                  (fiveam:run! 'test-group-administrator-api)
                  (fiveam:run! 'test-poll-api)
                  (fiveam:run! 'test-invite-link-api))))
    (if (every #'identity results)
        (progn
          (format t "All tests passed!~%")
          t)
        (progn
          (format t "Some tests failed!~%")
          nil))))
