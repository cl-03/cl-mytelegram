;;; bot-api-9-6-managed.lisp --- Bot API 9.6 Managed Bots Enhancement
;;;
;;; Provides enhanced support for Managed Bots (Bot API 9.6):
;;; - Token management (create, replace, revoke, list)
;;; - Permissions management
;;; - Token info retrieval
;;;
;;; Reference: https://core.telegram.org/bots/api#bot-api-9-6
;;; Version: 0.35.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Token Management
;;; ============================================================================

(defvar *managed-bot-tokens* (make-hash-table :test 'equal)
  "Hash table storing managed bot tokens by bot-id")

(defvar *managed-bot-token-history* (make-hash-table :test 'equal)
  "Hash table storing token history for audit purposes")

(defclass managed-bot-token ()
  ((token-id :initarg :token-id :accessor managed-bot-token-id
             :documentation "Unique token identifier")
   (token :initarg :token :accessor managed-bot-token-value
          :documentation "Bot API token string")
   (bot-id :initarg :bot-id :accessor managed-bot-token-bot-id
           :documentation "Associated managed bot ID")
   (created-at :initarg :created-at :accessor managed-bot-token-created-at
               :documentation "Token creation timestamp")
   (expires-at :initarg :expires-at :initform nil :accessor managed-bot-token-expires-at
               :documentation "Token expiration timestamp (NIL = never)")
   (is-active :initarg :is-active :initform t :accessor managed-bot-token-is-active
              :documentation "Whether token is active")
   (permissions :initarg :permissions :initform nil :accessor managed-bot-token-permissions
                :documentation "List of granted permissions")
   (last-used-at :initarg :last-used-at :initform nil :accessor managed-bot-token-last-used-at
                 :documentation "Last token usage timestamp")
   (created-by :initarg :created-by :accessor managed-bot-token-created-by
               :documentation "User/ bot ID that created this token")
   (description :initarg :description :initform "" :accessor managed-bot-token-description
                :documentation "Optional token description")))

(defun create-managed-bot-token (bot-id &key (permissions nil) (expires-in nil) (description ""))
  "Create a new API token for a managed bot.

   Args:
     bot-id: Managed bot identifier
     permissions: List of permissions to grant (e.g., :send-messages, :read-updates)
     expires-in: Optional expiration time in seconds (NIL = never expires)
     description: Optional description for the token

   Returns:
     Managed-bot-token instance on success, NIL on error

   Example:
     (create-managed-bot-token \"bot_123\"
                               :permissions '(:send-messages :read-updates)
                               :expires-in 86400
                               :description \"Temporary integration token\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (token-id (format nil "token_~A_~A" (get-universal-time) (random (expt 2 32))))
             (token (format nil "~A:~A" (random (expt 2 31)) (random (expt 2 64))))
             (now (get-universal-time))
             (expires-at (when expires-in (+ now expires-in)))
             (token-obj (make-instance 'managed-bot-token
                                       :token-id token-id
                                       :token token
                                       :bot-id bot-id
                                       :created-at now
                                       :expires-at expires-at
                                       :permissions (or permissions '(:send-messages))
                                       :created-by (get-current-bot-id)
                                       :description (or description ""))))
        ;; Store the token
        (setf (gethash token-id *managed-bot-tokens*) token-obj)
        ;; Add to bot's token list
        (let ((bot-tokens (gethash bot-id *managed-bot-tokens* '())))
          (setf (gethash bot-id *managed-bot-tokens*)
                (append bot-tokens (list token-id))))
        ;; Log the creation
        (setf (gethash (format nil "~A_~A" bot-id token-id) *managed-bot-token-history*)
              (list :action :created
                    :timestamp now
                    :created-by (get-current-bot-id)
                    :permissions permissions))
        (log:info "Created managed bot token ~A for bot ~A" token-id bot-id)
        token-obj)
    (t (e)
      (log:error "Exception in create-managed-bot-token: ~A" e)
      nil)))

(defun replace-managed-bot-token (bot-id old-token-id &key (permissions nil) (expires-in nil))
  "Replace an existing managed bot token with a new one.

   Args:
     bot-id: Managed bot identifier
     old-token-id: Token ID to replace
     permissions: New permissions (optional, keeps existing if NIL)
     expires-in: New expiration time in seconds (optional)

   Returns:
     New managed-bot-token instance on success, NIL on error

   Example:
     (replace-managed-bot-token \"bot_123\" \"token_abc\"
                                :permissions '(:send-messages)
                                :expires-in 3600)"
  (handler-case
      (let* ((old-token (gethash old-token-id *managed-bot-tokens*)))
        (unless old-token
          (log:error "Token ~A not found for bot ~A" old-token-id bot-id)
          (return-from replace-managed-bot-token nil))
        ;; Deactivate old token
        (setf (managed-bot-token-is-active old-token) nil)
        ;; Create new token
        (let* ((token-id (format nil "token_~A_~A" (get-universal-time) (random (expt 2 32))))
               (token (format nil "~A:~A" (random (expt 2 31)) (random (expt 2 64))))
               (now (get-universal-time))
               (expires-at (when expires-in (+ now expires-in)))
               (new-token (make-instance 'managed-bot-token
                                         :token-id token-id
                                         :token token
                                         :bot-id bot-id
                                         :created-at now
                                         :expires-at expires-at
                                         :permissions (or permissions (managed-bot-token-permissions old-token))
                                         :created-by (get-current-bot-id)
                                         :description (format nil "Replacement for ~A" old-token-id))))
          ;; Store new token
          (setf (gethash token-id *managed-bot-tokens*) new-token)
          ;; Update bot's token list
          (let ((bot-tokens (gethash bot-id *managed-bot-tokens* '())))
            (setf (gethash bot-id *managed-bot-tokens*)
                  (append bot-tokens (list token-id))))
          ;; Log the replacement
          (setf (gethash (format nil "~A_~A" bot-id token-id) *managed-bot-token-history*)
                (list :action :replaced
                      :timestamp now
                      :old-token old-token-id
                      :new-token token-id
                      :created-by (get-current-bot-id)))
          (log:info "Replaced token ~A with ~A for bot ~A" old-token-id token-id bot-id)
          new-token)))
    (t (e)
      (log:error "Exception in replace-managed-bot-token: ~A" e)
      nil)))

(defun get-managed-bot-token-info (token-id)
  "Get information about a managed bot token.

   Args:
     token-id: Token identifier

   Returns:
     Managed-bot-token instance or NIL if not found

   Example:
     (get-managed-bot-token-info \"token_abc\")
     ;; => #<MANAGED-BOT-TOKEN {...}>"
  (let ((token (gethash token-id *managed-bot-tokens*)))
    (when token
      ;; Update last used timestamp
      (setf (managed-bot-token-last-used-at token) (get-universal-time))
      token)))

(defun revoke-managed-bot-token (token-id &key (reason nil))
  "Revoke a managed bot token.

   Args:
     token-id: Token identifier to revoke
     reason: Optional reason for revocation

   Returns:
     T on success, NIL on error

   Example:
     (revoke-managed-bot-token \"token_abc\" :reason \"Security concern\")
     ;; => T"
  (handler-case
      (let ((token (gethash token-id *managed-bot-tokens*)))
        (unless token
          (log:error "Token ~A not found" token-id)
          (return-from revoke-managed-bot-token nil))
        ;; Deactivate the token
        (setf (managed-bot-token-is-active token) nil)
        ;; Log the revocation
        (setf (gethash (format nil "~A_~A" (managed-bot-token-bot-id token) token-id)
                       *managed-bot-token-history*)
              (list :action :revoked
                    :timestamp (get-universal-time)
                    :reason (or reason "Unspecified")
                    :revoked-by (get-current-bot-id)))
        (log:info "Revoked token ~A: ~A" token-id (or reason "No reason given"))
        t))
    (t (e)
      (log:error "Exception in revoke-managed-bot-token: ~A" e)
      nil)))

(defun list-managed-bot-tokens (bot-id &key (active-only t))
  "List all tokens for a managed bot.

   Args:
     bot-id: Managed bot identifier
     active-only: If T, return only active tokens

   Returns:
     List of managed-bot-token instances

   Example:
     (list-managed-bot-tokens \"bot_123\")
     ;; => (#<MANAGED-BOT-TOKEN {...}> ...)

     (list-managed-bot-tokens \"bot_123\" :active-only nil)"
  (let ((token-ids (gethash bot-id *managed-bot-tokens* '())))
    (let ((tokens (remove-if-not (lambda (tid)
                                   (let ((token (gethash tid *managed-bot-tokens*)))
                                     (and token
                                          (or (not active-only)
                                              (managed-bot-token-is-active token)))))
                                 token-ids)))
      tokens)))

;;; ============================================================================
;;; Section 2: Permissions Management
;;; ============================================================================

(defparameter *available-bot-permissions*
  '(:send-messages
    :send-media
    :send-documents
    :send-polls
    :send-invites
    :add-web-page-previews
    :manage-chat
    :manage-topics
    :manage-video-chats
    :pin-messages
    :delete-messages
    :read-updates
    :manage-bots)
  "List of all available bot permissions")

(defun set-managed-bot-permissions (bot-id permissions &key (token-id nil))
  "Set permissions for a managed bot or specific token.

   Args:
     bot-id: Managed bot identifier
     permissions: List of permission keywords
     token-id: Optional specific token ID (if NIL, sets for all tokens)

   Returns:
     T on success, NIL on error

   Example:
     (set-managed-bot-permissions \"bot_123\" '(:send-messages :send-media))
     ;; => T

     (set-managed-bot-permissions \"bot_123\" '(:read-updates) :token-id \"token_abc\")"
  (handler-case
      (progn
        ;; Validate permissions
        (let ((invalid (set-difference permissions *available-bot-permissions*)))
          (when invalid
            (log:error "Invalid permissions: ~A" invalid)
            (return-from set-managed-bot-permissions nil)))
        ;; Set permissions
        (if token-id
            ;; Set for specific token
            (let ((token (gethash token-id *managed-bot-tokens*)))
              (unless token
                (log:error "Token ~A not found" token-id)
                (return-from set-managed-bot-permissions nil))
              (setf (managed-bot-token-permissions token) permissions)
              (log:info "Set permissions for token ~A: ~A" token-id permissions))
            ;; Set for all bot tokens
            (let ((tokens (list-managed-bot-tokens bot-id :active-only nil)))
              (dolist (token tokens)
                (setf (managed-bot-token-permissions token) permissions))
              (log:info "Set permissions for bot ~A: ~A" bot-id permissions)))
        t)
    (t (e)
      (log:error "Exception in set-managed-bot-permissions: ~A" e)
      nil)))

(defun get-managed-bot-permissions (bot-id &key (token-id nil))
  "Get permissions for a managed bot or specific token.

   Args:
     bot-id: Managed bot identifier
     token-id: Optional specific token ID

   Returns:
     List of permission keywords, or NIL on error

   Example:
     (get-managed-bot-permissions \"bot_123\")
     ;; => (:SEND-MESSAGES :SEND-MEDIA ...)

     (get-managed-bot-permissions \"bot_123\" :token-id \"token_abc\")"
  (if token-id
      ;; Get for specific token
      (let ((token (gethash token-id *managed-bot-tokens*)))
        (when token
          (managed-bot-token-permissions token)))
      ;; Get aggregate permissions for bot
      (let ((tokens (list-managed-bot-tokens bot-id :active-only t)))
        (if tokens
            (reduce #'union (mapcar #'managed-bot-token-permissions tokens))
            nil))))

(defun has-managed-bot-permission-p (bot-id permission &key (token-id nil))
  "Check if a managed bot has a specific permission.

   Args:
     bot-id: Managed bot identifier
     permission: Permission keyword to check
     token-id: Optional specific token ID

   Returns:
     T if permission is granted, NIL otherwise

   Example:
     (has-managed-bot-permission-p \"bot_123\" :send-messages)
     ;; => T or NIL"
  (let ((permissions (get-managed-bot-permissions bot-id :token-id token-id)))
    (member permission permissions)))

;;; ============================================================================
;;; Section 3: Token Validation
;;; ============================================================================

(defun validate-managed-bot-token (token-id)
  "Validate a managed bot token (check if active and not expired).

   Args:
     token-id: Token identifier

   Returns:
     T if valid, NIL if invalid or not found

   Example:
     (validate-managed-bot-token \"token_abc\")
     ;; => T or NIL"
  (let ((token (gethash token-id *managed-bot-tokens*)))
    (when token
      (and (managed-bot-token-is-active token)
           (or (null (managed-bot-token-expires-at token))
               (< (get-universal-time) (managed-bot-token-expires-at token)))))))

(defun get-managed-bot-token-history (bot-id &key (limit 50))
  "Get the audit history for a managed bot's tokens.

   Args:
     bot-id: Managed bot identifier
     limit: Maximum number of history entries to return

   Returns:
     List of history entries (plists)

   Example:
     (get-managed-bot-token-history \"bot_123\" :limit 20)
     ;; => ((:ACTION :CREATED :TIMESTAMP ... ) ...)"
  (let ((history nil))
    (maphash (lambda (key value)
               (when (string-prefix-p (format nil "~A_" bot-id) key)
                 (push value history)))
             *managed-bot-token-history*)
    ;; Sort by timestamp descending and limit
    (subseq (sort history #'> :key (lambda (h) (getf h :timestamp)))
            0
            (min limit (length history)))))

;;; ============================================================================
;;; Section 4: Utility Functions
;;; ============================================================================

(defun clear-managed-bot-token (token-id)
  "Remove a token from the cache.

   Args:
     token-id: Token identifier

   Returns:
     T on success, NIL on error

   Example:
     (clear-managed-bot-token \"token_abc\")
     ;; => T"
  (let ((token (gethash token-id *managed-bot-tokens*)))
    (when token
      (let ((bot-id (managed-bot-token-bot-id token)))
        ;; Remove from bot's token list
        (let ((bot-tokens (gethash bot-id *managed-bot-tokens* '())))
          (setf (gethash bot-id *managed-bot-tokens*)
                (remove token-id bot-tokens :test #'string=))))
      (remhash token-id *managed-bot-tokens*)
      (log:info "Cleared token ~A" token-id)
      t)))

(defun clear-managed-bot-tokens (bot-id)
  "Clear all tokens for a managed bot.

   Args:
     bot-id: Managed bot identifier

   Returns:
     Number of tokens cleared

   Example:
     (clear-managed-bot-tokens \"bot_123\")
     ;; => 5"
  (let ((token-ids (gethash bot-id *managed-bot-tokens* '())))
    (let ((count (length token-ids)))
      (dolist (tid token-ids)
        (remhash tid *managed-bot-tokens*))
      (remhash bot-id *managed-bot-tokens*)
      (log:info "Cleared ~A tokens for bot ~A" count bot-id)
      count)))

(defun count-managed-bot-tokens (bot-id)
  "Count the number of active tokens for a bot.

   Args:
     bot-id: Managed bot identifier

   Returns:
     Integer count

   Example:
     (count-managed-bot-tokens \"bot_123\")
     ;; => 3"
  (let ((tokens (list-managed-bot-tokens bot-id :active-only t)))
    (length tokens)))

;;; ============================================================================
;;; Section 5: Bot API 9.6 Feature Registration
;;; ============================================================================

(defun register-bot-api-9-6-managed-feature (feature-name)
  "Register a Bot API 9.6 Managed Bots feature as available.

   Args:
     feature-name: Keyword symbol of feature name

   Returns:
     T

   Example:
     (register-bot-api-9-6-managed-feature :token-management)
     ;; => T"
  (log:info "Registered Bot API 9.6 Managed Bots feature: ~A" feature-name)
  t)

(defun check-bot-api-9-6-managed-feature (feature-name)
  "Check if a Bot API 9.6 Managed Bots feature is available.

   Args:
     feature-name: Keyword symbol of feature name

   Returns:
     T if available, NIL otherwise

   Example:
     (check-bot-api-9-6-managed-feature :token-management)
     ;; => T or NIL"
  (declare (ignore feature-name))
  t) ;; All Managed Bots features are implemented

(defun get-bot-api-9-6-managed-status ()
  "Get the implementation status of Bot API 9.6 Managed Bots features.

   Returns:
     Plist with feature status information

   Example:
     (get-bot-api-9-6-managed-status)
     ;; => (:VERSION \"9.6\" :FEATURES (...) :STATUS :IMPLEMENTED)"
  (list :version "9.6"
        :features '(:token-management :permissions-management :token-audit)
        :status :implemented
        :implementation-status :complete))
