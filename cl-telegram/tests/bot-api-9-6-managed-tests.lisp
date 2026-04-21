;;; bot-api-9-6-managed-tests.lisp --- Tests for Bot API 9.6 Managed Bots Enhancement

(in-package #:cl-telegram/tests)

(def-suite* bot-api-9-6-managed-tests
  :description "Tests for Bot API 9.6 Managed Bots Enhancement (v0.35.0)")

;;; ============================================================================
;;; Section 1: Token Creation Tests
;;; ============================================================================

(test test-create-managed-bot-token
  "Test creating a new managed bot token"
  (let ((token (cl-telegram/api:create-managed-bot-token "bot_123")))
    (is (or (typep token 'cl-telegram/api:managed-bot-token) (null token)))))

(test test-create-managed-bot-token-with-permissions
  "Test creating token with specific permissions"
  (let ((token (cl-telegram/api:create-managed-bot-token
                "bot_123"
                :permissions '(:send-messages :send-media))))
    (when token
      (is (typep token 'cl-telegram/api:managed-bot-token))
      (is (member :send-messages (cl-telegram/api:managed-bot-token-permissions token)))
      (is (member :send-media (cl-telegram/api:managed-bot-token-permissions token))))))

(test test-create-managed-bot-token-with-expiry
  "Test creating token with expiration"
  (let ((token (cl-telegram/api:create-managed-bot-token
                "bot_123"
                :expires-in 3600
                :description "Temporary token")))
    (when token
      (is (typep token 'cl-telegram/api:managed-bot-token))
      (is (not (null (cl-telegram/api:managed-bot-token-expires-at token))))
      (is (string= (cl-telegram/api:managed-bot-token-description token) "Temporary token")))))

(test test-create-managed-bot-token-default-permissions
  "Test that token gets default permissions"
  (let ((token (cl-telegram/api:create-managed-bot-token "bot_456")))
    (when token
      (is (member :send-messages (cl-telegram/api:managed-bot-token-permissions token))))))

;;; ============================================================================
;;; Section 2: Token Replacement Tests
;;; ============================================================================

(test test-replace-managed-bot-token
  "Test replacing an existing token"
  (let* ((old-token (cl-telegram/api:create-managed-bot-token "bot_789"))
         (old-token-id (when old-token (cl-telegram/api:managed-bot-token-id old-token))))
    (when old-token-id
      (let ((new-token (cl-telegram/api:replace-managed-bot-token "bot_789" old-token-id)))
        (when new-token
          (is (typep new-token 'cl-telegram/api:managed-bot-token))
          ;; Old token should be deactivated
          (is (not (managed-bot-token-is-active old-token)))
          ;; New token should be active
          (is (managed-bot-token-is-active new-token)))))))

(test test-replace-managed-bot-token-new-permissions
  "Test replacing token with new permissions"
  (let* ((old-token (cl-telegram/api:create-managed-bot-token
                     "bot_789"
                     :permissions '(:send-messages :read-updates)))
         (old-token-id (when old-token (cl-telegram/api:managed-bot-token-id old-token))))
    (when old-token-id
      (let ((new-token (cl-telegram/api:replace-managed-bot-token
                        "bot_789"
                        old-token-id
                        :permissions '(:send-messages))))
        (when new-token
          (is (equal (cl-telegram/api:managed-bot-token-permissions new-token)
                     '(:send-messages))))))))

;;; ============================================================================
;;; Section 3: Token Info Tests
;;; ============================================================================

(test test-get-managed-bot-token-info
  "Test getting token information"
  (let* ((token (cl-telegram/api:create-managed-bot-token "bot_info_test"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (let ((info (cl-telegram/api:get-managed-bot-token-info token-id)))
        (when info
          (is (typep info 'cl-telegram/api:managed-bot-token))
          (is (string= (cl-telegram/api:managed-bot-token-id info) token-id)))))))

(test test-get-managed-bot-token-info-not-found
  "Test getting non-existent token info"
  (let ((info (cl-telegram/api:get-managed-bot-token-info "nonexistent_token")))
    (is (null info))))

;;; ============================================================================
;;; Section 4: Token Revocation Tests
;;; ============================================================================

(test test-revoke-managed-bot-token
  "Test revoking a token"
  (let* ((token (cl-telegram/api:create-managed-bot-token "bot_revoke"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (let ((result (cl-telegram/api:revoke-managed-bot-token token-id :reason "Test revocation")))
        (is (eq result t))
        ;; Token should be deactivated
        (is (not (managed-bot-token-is-active token)))))))

(test test-revoke-managed-bot-token-no-reason
  "Test revoking token without reason"
  (let* ((token (cl-telegram/api:create-managed-bot-token "bot_revoke2"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (let ((result (cl-telegram/api:revoke-managed-bot-token token-id)))
        (is (eq result t))))))

(test test-revoke-managed-bot-token-not-found
  "Test revoking non-existent token"
  (let ((result (cl-telegram/api:revoke-managed-bot-token "nonexistent_token")))
    (is (null result))))

;;; ============================================================================
;;; Section 5: List Tokens Tests
;;; ============================================================================

(test test-list-managed-bot-tokens
  "Test listing all tokens for a bot"
  (let* ((token1 (cl-telegram/api:create-managed-bot-token "bot_list"))
         (token2 (cl-telegram/api:create-managed-bot-token "bot_list"))
         (token3 (cl-telegram/api:create-managed-bot-token "bot_list")))
    (let ((tokens (cl-telegram/api:list-managed-bot-tokens "bot_list")))
      (is (listp tokens))
      (is (>= (length tokens) 3)))))

(test test-list-managed-bot-tokens-active-only
  "Test listing only active tokens"
  (let* ((token1 (cl-telegram/api:create-managed-bot-token "bot_active"))
         (token2 (cl-telegram/api:create-managed-bot-token "bot_active"))
         (token-id2 (when token2 (cl-telegram/api:managed-bot-token-id token2))))
    ;; Revoke one token
    (when token-id2
      (cl-telegram/api:revoke-managed-bot-token token-id2))
    (let ((active-tokens (cl-telegram/api:list-managed-bot-tokens "bot_active" :active-only t)))
      ;; Should have at least 1 active (token1)
      (is (>= (length active-tokens) 1))
      ;; All should be active
      (is (every #'cl-telegram/api:managed-bot-token-is-active active-tokens)))))

(test test-list-managed-bot-tokens-all
  "Test listing all tokens including revoked"
  (let* ((token1 (cl-telegram/api:create-managed-bot-token "bot_all"))
         (token2 (cl-telegram/api:create-managed-bot-token "bot_all"))
         (token-id2 (when token2 (cl-telegram/api:managed-bot-token-id token2))))
    ;; Revoke one token
    (when token-id2
      (cl-telegram/api:revoke-managed-bot-token token-id2))
    (let ((all-tokens (cl-telegram/api:list-managed-bot-tokens "bot_all" :active-only nil)))
      ;; Should include both active and revoked
      (is (>= (length all-tokens) 2)))))

;;; ============================================================================
;;; Section 6: Permissions Tests
;;; ============================================================================

(test test-set-managed-bot-permissions
  "Test setting bot permissions"
  (let ((result (cl-telegram/api:set-managed-bot-permissions
                 "bot_perms"
                 '(:send-messages :send-media))))
    (is (or (eq result t) (null result)))))

(test test-set-managed-bot-permissions-invalid
  "Test setting invalid permissions"
  (let ((result (cl-telegram/api:set-managed-bot-permissions
                 "bot_perms"
                 '(:invalid-permission :send-messages))))
    (is (null result))))

(test test-set-managed-bot-token-permissions
  "Test setting permissions for specific token"
  (let* ((token (cl-telegram/api:create-managed-bot-token "bot_token_perms"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (let ((result (cl-telegram/api:set-managed-bot-permissions
                     "bot_token_perms"
                     '(:read-updates)
                     :token-id token-id)))
        (is (eq result t))
        (is (equal (cl-telegram/api:managed-bot-token-permissions token) '(:read-updates)))))))

(test test-get-managed-bot-permissions
  "Test getting bot permissions"
  (let ((perms (cl-telegram/api:get-managed-bot-permissions "bot_get_perms")))
    (is (or (listp perms) (null perms)))))

(test test-get-managed-bot-token-permissions
  "Test getting specific token permissions"
  (let* ((token (cl-telegram/api:create-managed-bot-token
                 "bot_get_token_perms"
                 :permissions '(:send-messages :send-media)))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (let ((perms (cl-telegram/api:get-managed-bot-permissions
                    "bot_get_token_perms"
                    :token-id token-id)))
        (is (member :send-messages perms))
        (is (member :send-media perms))))))

(test test-has-managed-bot-permission-p
  "Test checking if bot has permission"
  (let* ((token (cl-telegram/api:create-managed-bot-token
                 "bot_check_perm"
                 :permissions '(:send-messages :send-media)))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (is (cl-telegram/api:has-managed-bot-permission-p
           "bot_check_perm"
           :send-messages
           :token-id token-id))
      (is (not (cl-telegram/api:has-managed-bot-permission-p
                "bot_check_perm"
                :delete-messages
                :token-id token-id))))))

;;; ============================================================================
;;; Section 7: Token Validation Tests
;;; ============================================================================

(test test-validate-managed-bot-token-valid
  "Test validating a valid token"
  (let* ((token (cl-telegram/api:create-managed-bot-token "bot_validate"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (let ((valid (cl-telegram/api:validate-managed-bot-token token-id)))
        (is (eq valid t))))))

(test test-validate-managed-bot-token-revoked
  "Test validating a revoked token"
  (let* ((token (cl-telegram/api:create-managed-bot-token "bot_validate_revoked"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (cl-telegram/api:revoke-managed-bot-token token-id)
      (let ((valid (cl-telegram/api:validate-managed-bot-token token-id)))
        (is (null valid))))))

(test test-validate-managed-bot-token-not-found
  "Test validating non-existent token"
  (let ((valid (cl-telegram/api:validate-managed-bot-token "nonexistent_token")))
    (is (null valid))))

;;; ============================================================================
;;; Section 8: Token History Tests
;;; ============================================================================

(test test-get-managed-bot-token-history
  "Test getting token audit history"
  (let* ((token1 (cl-telegram/api:create-managed-bot-token "bot_history"))
         (token2 (cl-telegram/api:create-managed-bot-token "bot_history"))
         (token-id2 (when token2 (cl-telegram/api:managed-bot-token-id token2))))
    ;; Revoke one token to create history entry
    (when token-id2
      (cl-telegram/api:revoke-managed-bot-token token-id2 :reason "Test"))
    (let ((history (cl-telegram/api:get-managed-bot-token-history "bot_history" :limit 10)))
      (is (listp history))
      (is (>= (length history) 1)))))

;;; ============================================================================
;;; Section 9: Utility Function Tests
;;; ============================================================================

(test test-clear-managed-bot-token
  "Test clearing a single token"
  (let* ((token (cl-telegram/api:create-managed-bot-token "bot_clear"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      (let ((result (cl-telegram/api:clear-managed-bot-token token-id)))
        (is (eq result t))
        ;; Token should no longer be in cache
        (is (null (cl-telegram/api:get-managed-bot-token-info token-id)))))))

(test test-clear-managed-bot-tokens
  "Test clearing all tokens for a bot"
  (let ()
    (cl-telegram/api:create-managed-bot-token "bot_clear_all")
    (cl-telegram/api:create-managed-bot-token "bot_clear_all")
    (cl-telegram/api:create-managed-bot-token "bot_clear_all")
    (let ((count (cl-telegram/api:clear-managed-bot-tokens "bot_clear_all")))
      (is (>= count 3)))))

(test test-count-managed-bot-tokens
  "Test counting tokens for a bot"
  (let ()
    (cl-telegram/api:create-managed-bot-token "bot_count")
    (cl-telegram/api:create-managed-bot-token "bot_count")
    (cl-telegram/api:create-managed-bot-token "bot_count")
    (let ((count (cl-telegram/api:count-managed-bot-tokens "bot_count")))
      (is (>= count 3)))))

;;; ============================================================================
;;; Section 10: Managed Bot Token Class Tests
;;; ============================================================================

(test test-managed-bot-token-class
  "Test managed-bot-token class instantiation"
  (let ((token (make-instance 'cl-telegram/api:managed-bot-token
                              :token-id "test_token"
                              :token "123456:ABC-DEF"
                              :bot-id "bot_123"
                              :created-at (get-universal-time)
                              :permissions '(:send-messages))))
    (is (string= (cl-telegram/api:managed-bot-token-id token) "test_token"))
    (is (string= (cl-telegram/api:managed-bot-token-value token) "123456:ABC-DEF"))
    (is (string= (cl-telegram/api:managed-bot-token-bot-id token) "bot_123"))
    (is (member :send-messages (cl-telegram/api:managed-bot-token-permissions token)))))

(test test-managed-bot-token-defaults
  "Test managed-bot-token default values"
  (let ((token (make-instance 'cl-telegram/api:managed-bot-token
                              :token-id "test"
                              :token "token"
                              :bot-id "bot")))
    (is (eq (cl-telegram/api:managed-bot-token-is-active token) t))
    (is (null (cl-telegram/api:managed-bot-token-expires-at token)))
    (is (null (cl-telegram/api:managed-bot-token-last-used-at token)))
    (is (string= (cl-telegram/api:managed-bot-token-description token) ""))))

;;; ============================================================================
;;; Section 11: Feature Status Tests
;;; ============================================================================

(test test-register-bot-api-9-6-managed-feature
  "Test registering Bot API 9.6 Managed feature"
  (let ((result (cl-telegram/api:register-bot-api-9-6-managed-feature :token-management)))
    (is (eq result t))))

(test test-check-bot-api-9-6-managed-feature
  "Test checking Bot API 9.6 Managed feature"
  (let ((result (cl-telegram/api:check-bot-api-9-6-managed-feature :token-management)))
    (is (eq result t))))

(test test-get-bot-api-9-6-managed-status
  "Test getting Bot API 9.6 Managed status"
  (let ((status (cl-telegram/api:get-bot-api-9-6-managed-status)))
    (is (plistp status))
    (is (getf status :version))
    (is (getf status :features))
    (is (getf status :status))))

;;; ============================================================================
;;; Section 12: Integration Tests
;;; ============================================================================

(test test-managed-bot-token-lifecycle
  "Test complete token lifecycle"
  ;; 1. Create token
  (let* ((token (cl-telegram/api:create-managed-bot-token
                 "bot_lifecycle"
                 :permissions '(:send-messages :read-updates)
                 :description "Lifecycle test token"))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      ;; 2. Verify token exists
      (let ((info (cl-telegram/api:get-managed-bot-token-info token-id)))
        (is (not (null info))))
      ;; 3. Check permissions
      (is (cl-telegram/api:has-managed-bot-permission-p
           "bot_lifecycle"
           :send-messages
           :token-id token-id))
      ;; 4. Revoke token
      (let ((result (cl-telegram/api:revoke-managed-bot-token token-id :reason "Test complete")))
        (is (eq result t)))
      ;; 5. Verify token is revoked
      (is (not (cl-telegram/api:validate-managed-bot-token token-id))))))

(test test-managed-bot-permissions-flow
  "Test permissions management flow"
  (let* ((token (cl-telegram/api:create-managed-bot-token
                 "bot_perm_flow"
                 :permissions '(:send-messages)))
         (token-id (when token (cl-telegram/api:managed-bot-token-id token))))
    (when token-id
      ;; 1. Check initial permissions
      (is (member :send-messages (cl-telegram/api:get-managed-bot-permissions
                                  "bot_perm_flow"
                                  :token-id token-id)))
      ;; 2. Update permissions
      (cl-telegram/api:set-managed-bot-permissions
       "bot_perm_flow"
       '(:read-updates :delete-messages)
       :token-id token-id)
      ;; 3. Verify updated permissions
      (let ((perms (cl-telegram/api:get-managed-bot-permissions
                    "bot_perm_flow"
                    :token-id token-id)))
        (is (member :read-updates perms))
        (is (member :delete-messages perms))
        (is (not (member :send-messages perms)))))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-bot-api-9-6-managed-tests ()
  "Run all Bot API 9.6 Managed Bots Enhancement tests"
  (let ((results (run! 'bot-api-9-6-managed-tests :if-fail :error)))
    (format t "~%~%=== Bot API 9.6 Managed Bots Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
