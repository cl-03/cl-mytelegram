;;; account-security.lisp --- Account security and management
;;;
;;; Provides support for:
;;; - QR code login (export/import/accept login token)
;;; - Privacy settings management
;;; - Session/authorization management
;;; - Phone number management

(in-package #:cl-telegram/api)

;;; ### QR Code Login Types

(defclass login-token ()
  ((token :initarg :token :reader login-token-token)
   (expires :initarg :expires :reader login-token-expires)
   (is-accepted :initform nil :accessor login-token-is-accepted)))

(defclass authorization-session ()
  ((id :initarg :id :reader auth-session-id)
   (api-id :initarg :api-id :reader auth-session-api-id)
   (api-hash :initarg :api-hash :reader auth-session-api-hash)
   (device-model :initarg :device-model :reader auth-session-device)
   (platform :initarg :platform :reader auth-session-platform)
   (system-version :initarg :system-version :reader auth-session-system)
   (date-created :initarg :date-created :reader auth-session-date)
   (ip-address :initarg :ip-address :reader auth-session-ip)
   (country :initarg :country :reader auth-session-country)
   (is-official :initarg :is-official :reader auth-session-official-p)
   (is-password-pending :initarg :is-password-pending :reader auth-session-password-pending-p)))

;;; ### Global State

(defvar *login-token* nil
  "Current login token for QR authentication")

(defvar *qr-login-state* :idle
  "QR login state: :idle, :exported, :accepted, :expired")

(defvar *privacy-rules-cache* (make-hash-table :test 'equal)
  "Cached privacy settings")

;;; ============================================================================
;;; ### QR Code Login
;;; ============================================================================

(defun export-login-token ()
  "Export a login token for QR code authentication.

   The token should be encoded in base64url and displayed as:
   tg://login?token=base64encodedtoken

   Returns:
     Login-token object or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'auth.exportLoginToken)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (let ((token (make-instance 'login-token
                                        :token (getf result :token)
                                        :expires (getf result :expires))))
              (setf *login-token* token
                    *qr-login-state* :exported)
              token))
          (t (c)
            (log-error "Export login token failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in export-login-token: ~A" c)
      nil)))

(defun import-login-token (token)
  "Import a login token from QR code.

   Args:
     token: Login token string from QR code

   Returns:
     Authorization info plist or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'auth.importLoginToken
                                      :token token)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (let ((peer-type (getf result :@type)))
              (cond
                ((eq peer-type :auth.authorization)
                 ;; Token already accepted, user logged in
                 (setf *qr-login-state* :accepted)
                 (list :status :accepted
                       :user (getf result :user)))
                ((eq peer-type :auth.loginToken)
                 ;; Token valid, waiting for acceptance
                 (list :status :waiting
                       :token (getf result :token)
                       :expires (getf result :expires)))
                (t
                 (list :status :unknown :result result)))))
          (t (c)
            (log-error "Import login token failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in import-login-token: ~A" c)
      nil)))

(defun accept-login-token (token)
  "Accept a login token (complete QR login).

   Args:
     token: Login token to accept

   Returns:
     Authorization object on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'auth.acceptLoginToken
                                      :token token)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (setf *qr-login-state* :accepted)
            result)
          (t (c)
            (log-error "Accept login token failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in accept-login-token: ~A" c)
      nil)))

(defun generate-qr-code-url (token)
  "Generate QR code URL from login token.

   Args:
     token: Login token string

   Returns:
     QR code URL (tg://login?token=...)""
  (let ((encoded (base64-encode token)))
    (format nil "tg://login?token=~A" encoded)))

(defun parse-qr-code-url (url)
  "Parse QR code URL to extract token.

   Args:
     url: QR code URL

   Returns:
     Token string or NIL"
  (when (and url (search "tg://login?token=" url))
    (let ((token-part (subseq url (+ (search "token=" url) 6))))
      (base64-decode token-part))))

;;; ============================================================================
;;; ### Privacy Settings
;;; ============================================================================

(defclass privacy-rule ()
  ((type :initarg :type :reader privacy-rule-type)
   (user-ids :initarg :user-ids :initform nil :reader privacy-rule-users)
   (chat-ids :initarg :chat-ids :initform nil :reader privacy-rule-chats)))

(defun get-privacy-settings (&key (privacy-key nil))
  "Get privacy settings.

   Args:
     privacy-key: Optional specific privacy key
                  (:phone-number, :last-seen, :profile-photo,
                   :forwards, :calls, :groups-channels, :invite-links)

   Returns:
     List of privacy-rule objects"
  (handler-case
      (let* ((connection (get-connection))
             (key (cond
                    ((null privacy-key) 'privacyKeyStatus)
                    ((eq privacy-key :phone-number) 'privacyKeyPhoneNumber)
                    ((eq privacy-key :last-seen) 'privacyKeyLastSeen)
                    ((eq privacy-key :profile-photo) 'privacyKeyProfilePhoto)
                    ((eq privacy-key :forwards) 'privacyKeyForwards)
                    ((eq privacy-key :calls) 'privacyKeyPhoneCall)
                    ((eq privacy-key :groups-channels) 'privacyKeyChatInvite)
                    ((eq privacy-key :invite-links) 'privacyKeyInviteLink)
                    (t 'privacyKeyStatus)))
             (request (make-tl-object 'account.getPrivacy
                                      :key (make-tl-object key))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (let ((rules (getf result :rules)))
              ;; Cache the rules
              (setf (gethash (symbol-name key) *privacy-rules-cache*) rules)
              rules))
          (t (c)
            (log-error "Get privacy settings failed: ~A" c)
            ;; Return cached rules if available
            (gethash (symbol-name key) *privacy-rules-cache*))))
    (t (c)
      (log-error "Unexpected error in get-privacy-settings: ~A" c)
      nil)))

(defun set-privacy-settings (privacy-key rules)
  "Set privacy settings.

   Args:
     privacy-key: Privacy key (see get-privacy-settings)
     rules: List of privacy rule plists
            Example: '((:type :allow-all)
                       (:type :deny-users :user-ids (123 456))
                       (:type :allow-users :user-ids (789)))

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (key (cond
                    ((eq privacy-key :phone-number) 'privacyKeyPhoneNumber)
                    ((eq privacy-key :last-seen) 'privacyKeyLastSeen)
                    ((eq privacy-key :profile-photo) 'privacyKeyProfilePhoto)
                    ((eq privacy-key :forwards) 'privacyKeyForwards)
                    ((eq privacy-key :calls) 'privacyKeyPhoneCall)
                    ((eq privacy-key :groups-channels) 'privacyKeyChatInvite)
                    ((eq privacy-key :invite-links) 'privacyKeyInviteLink)
                    (t 'privacyKeyStatus)))
             (tl-rules (mapcar (lambda (rule)
                                 (let ((type (getf rule :type)))
                                   (cond
                                     ((eq type :allow-all)
                                      (make-tl-object 'privacyValueAllowAll))
                                     ((eq type :deny-all)
                                      (make-tl-object 'privacyValueDisallowAll))
                                     ((eq type :allow-users)
                                      (make-tl-object 'privacyValueAllowUsers
                                                      :user-ids (getf rule :user-ids)))
                                     ((eq type :deny-users)
                                      (make-tl-object 'privacyValueDisallowUsers
                                                      :user-ids (getf rule :user-ids)))
                                     ((eq type :allow-contacts)
                                      (make-tl-object 'privacyValueAllowContacts))
                                     ((eq type :deny-contacts)
                                      (make-tl-object 'privacyValueDisallowContacts))
                                     (t
                                      (make-tl-object 'privacyValueAllowAll)))))
                               rules))
             (request (make-tl-object 'account.setPrivacy
                                      :key (make-tl-object key)
                                      :rules tl-rules)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            ;; Update cache
            (setf (gethash (symbol-name key) *privacy-rules-cache*) rules)
            t)
          (t (c)
            (log-error "Set privacy settings failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in set-privacy-settings: ~A" c)
      nil)))

(defun reset-privacy-settings (privacy-key)
  "Reset privacy settings to default.

   Args:
     privacy-key: Privacy key to reset

   Returns:
     T on success"
  (set-privacy-settings privacy-key '((:type :allow-all))))

;;; ============================================================================
;;; ### Session Management
;;; ============================================================================

(defun get-authorizations ()
  "Get list of active authorizations (sessions).

   Returns:
     List of authorization-session objects"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.getAuthorizations)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (let ((authorizations (getf result :authorizations)))
              (mapcar (lambda (auth)
                        (make-instance 'authorization-session
                                       :id (getf auth :hash)
                                       :api-id (getf auth :api-id)
                                       :api-hash (getf auth :api-hash)
                                       :device-model (getf auth :device-model)
                                       :platform (getf auth :platform)
                                       :system-version (getf auth :system-version)
                                       :date-created (getf auth :date-created)
                                       :ip-address (getf auth :ip)
                                       :country (getf auth :country)
                                       :is-official (getf auth :official)
                                       :is-password-pending (getf auth :password-pending)))
                      authorizations)))
          (t (c)
            (log-error "Get authorizations failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in get-authorizations: ~A" c)
      nil)))

(defun reset-authorization (session-id)
  "Revoke a specific authorization (session).

   Args:
     session-id: Session hash/ID to revoke

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.resetAuthorization
                                      :hash session-id)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            t)
          (t (c)
            (log-error "Reset authorization failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in reset-authorization: ~A" c)
      nil)))

(defun reset-authorization-all ()
  "Revoke all authorizations except current session.

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.resetAuthorizations)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            t)
          (t (c)
            (log-error "Reset all authorizations failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in reset-authorization-all: ~A" c)
      nil)))

;;; ============================================================================
;;; ### Phone Number Management
;;; ============================================================================

(defun change-phone-number (new-phone-number)
  "Change account phone number.

   Args:
     new-phone-number: New phone number string

   Returns:
     Values: (success error-message)"
  (handler-case
      (let* ((connection (get-connection))
             ;; Step 1: Send code to new number
             (request1 (make-tl-object 'account.sendConfirmPhoneCode
                                       :phone-number new-phone-number))
             (result1 (rpc-call connection request1 :timeout 10000)))

        (unless (getf result1 :phone-code-hash)
          (return-from change-phone-number
            (values nil "Failed to send confirmation code")))

        ;; In real implementation, wait for user to enter code
        ;; Step 2: Confirm with code
        (let ((code "USER_PROVIDED_CODE") ; Placeholder
              (request2 (make-tl-object 'account.confirmPhone
                                        :phone-number new-phone-number
                                        :phone-code-hash (getf result1 :phone-code-hash)
                                        :phone-code code)))
          (rpc-handler-case (rpc-call connection request2 :timeout 10000)
            (:no-error (result)
              (values t "Phone number changed successfully"))
            (t (c)
              (values nil (format nil "Confirmation failed: ~A" c))))))
    (t (c)
      (values nil (format nil "Change phone number failed: ~A" c)))))

(defun send-confirm-phone-code (phone-number)
  "Send confirmation code for phone number change.

   Args:
     phone-number: Phone number to verify

   Returns:
     Phone code hash or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.sendConfirmPhoneCode
                                      :phone-number phone-number)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (getf result :phone-code-hash))
          (t (c)
            (log-error "Send confirm code failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in send-confirm-phone-code: ~A" c)
      nil)))

(defun confirm-phone (phone-number phone-code-hash phone-code)
  "Confirm phone number change with code.

   Args:
     phone-number: Phone number
     phone-code-hash: Hash from send-confirm-phone-code
     phone-code: User-provided verification code

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.confirmPhone
                                      :phone-number phone-number
                                      :phone-code-hash phone-code-hash
                                      :phone-code phone-code)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            t)
          (t (c)
            (log-error "Confirm phone failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in confirm-phone: ~A" c)
      nil)))

;;; ============================================================================
;;; ### Takeout (Account Export)
;;; ============================================================================

(defun takeout-init (&key (contacts t) (message-users t) (message-chats t)
                        (message-megagroups t) (message-pcs t) (files t)
                        (file-max-size nil))
  "Initialize takeout session for account data export.

   Args:
     contacts: Include contacts
     message-users: Include private chat messages
     message-chats: Include group messages
     message-megagroups: Include supergroup/channel messages
     message-pcs: Include private channel messages
     files: Include files
     file-max-size: Maximum file size to include

   Returns:
     Takeout session ID or NIL on error"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.initTakeout
                                      :contacts contacts
                                      :message-users message-users
                                      :message-chats message-chats
                                      :message-megagroups message-megagroups
                                      :message-pcs message-pcs
                                      :files files
                                      :file-max-size (or file-max-size 0))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            (getf result :id))
          (t (c)
            (log-error "Takeout init failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in takeout-init: ~A" c)
      nil)))

(defun finish-takeout-session (session-id &key (success t))
  "Finish takeout session.

   Args:
     session-id: Takeout session ID
     success: Whether export was successful

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.finishTakeoutSession
                                      :id session-id
                                      :success success)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:no-error (result)
            t)
          (t (c)
            (log-error "Finish takeout session failed: ~A" c)
            nil)))
    (t (c)
      (log-error "Unexpected error in finish-takeout-session: ~A" c)
      nil)))

;;; ============================================================================
;;; ### Utilities
;;; ============================================================================

(defun base64-encode (string)
  "Encode string to base64url."
  (let ((encoded (ironclad:byte-array-to-base64-string
                  (babel:string-to-octets string :encoding :utf-8))))
    ;; Convert to URL-safe base64
    (substitute #\- #\+ (substitute #\_ #\/ encoded))))

(defun base64-decode (string)
  "Decode base64url string."
  (let ((normalized (substitute #\+ #\- (substitute #\/ #\_ string))))
    (babel:octets-to-string (ironclad:base64-string-to-byte-array normalized)
                            :encoding :utf-8)))

;;; Export symbols
(export '(;; QR Code Login
          login-token
          export-login-token
          import-login-token
          accept-login-token
          generate-qr-code-url
          parse-qr-code-url

          ;; Privacy Settings
          privacy-rule
          get-privacy-settings
          set-privacy-settings
          reset-privacy-settings

          ;; Session Management
          authorization-session
          get-authorizations
          reset-authorization
          reset-authorization-all

          ;; Phone Management
          change-phone-number
          send-confirm-phone-code
          confirm-phone

          ;; Takeout
          takeout-init
          finish-takeout-session

          ;; Utilities
          base64-encode
          base64-decode

          ;; Global State
          *login-token*
          *qr-login-state*
          *privacy-rules-cache*))
