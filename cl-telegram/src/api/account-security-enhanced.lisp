;;; account-security-enhanced.lisp --- Enhanced account security for v0.31.0
;;;
;;; Provides support for:
;;; - QR code login
;;; - Two-factor authentication (2FA)
;;; - Session management
;;; - Privacy settings
;;;
;;; Version: 0.31.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: QR Code Login
;;; ============================================================================

(defclass qr-login-token ()
  ((token-id :initarg :token-id :accessor qr-token-id)
   (token-data :initarg :token-data :accessor qr-token-data)
   (qr-code-url :initarg :qr-code-url :accessor qr-token-qr-code-url)
   (status :initarg :status :initform :pending :accessor qr-token-status)
   (created-at :initarg :created-at :accessor qr-token-created-at)
   (expires-at :initarg :expires-at :accessor qr-token-expires-at)
   (authorized-user-id :initarg :authorized-user-id :initform nil :accessor qr-token-authorized-user-id)))

(defvar *qr-login-tokens* (make-hash-table :test 'equal)
  "Hash table storing QR login tokens")

(defun generate-qr-login-token (&key (expires-in 60))
  "Generate a QR code login token.

   Args:
     expires-in: Token validity in seconds (default: 60)

   Returns:
     Qr-login-token instance with QR code data

   Example:
     (generate-qr-login-token :expires-in 60)"
  (handler-case
      (let* ((token-id (format nil "qr_~A_~A" (get-universal-time) (random (expt 2 32))))
             (now (get-universal-time))
             ;; Generate token data (in real implementation, this would call Telegram API)
             (token-data (format nil "tg://login?token=~A" (ironclad:byte-array-to-hex-string
                                                           (ironclad:make-random-sequence 32))))
             (token (make-instance 'qr-login-token
                                   :token-id token-id
                                   :token-data token-data
                                   :qr-code-url (format nil "https://api.telegram.org/qr?data=~A" token-data)
                                   :created-at now
                                   :expires-at (+ now expires-in))))
        (setf (gethash token-id *qr-login-tokens*) token)
        (log:info "QR login token generated: ~A" token-id)
        token))
    (t (e)
      (log:error "Generate QR login token failed: ~A" e)
      nil)))

(defun get-qr-code-image (token-id &key (size 256))
  "Get QR code image for a login token.

   Args:
     token-id: Token identifier
     size: QR code image size in pixels (default: 256)

   Returns:
     QR code image data (PNG bytes)

   Example:
     (get-qr-code-image \"qr_123\" :size 512)"
  (let ((token (gethash token-id *qr-login-tokens*)))
    (unless token
      (return-from get-qr-code-image nil))

    ;; In a real implementation, this would generate a QR code image
    ;; For now, return the token data for QR generation
    (list :token-data (qr-token-data token)
          :qr-url (qr-token-qr-code-url token)
          :size size)))

(defun check-qr-login-status (token-id)
  "Check QR code login status.

   Args:
     token-id: Token identifier

   Returns:
     Plist with status information

   Example:
     (check-qr-login-status \"qr_123\")"
  (let ((token (gethash token-id *qr-login-tokens*)))
    (unless token
      (return-from check-qr-login-status (list :status :invalid :error "Token not found")))

    ;; Check expiration
    (when (and (eq (qr-token-status token) :pending)
               (>= (get-universal-time) (qr-token-expires-at token)))
      (setf (qr-token-status token) :expired))

    (list :status (qr-token-status token)
          :token-id token-id
          :authorized-user-id (qr-token-authorized-user-id token)
          :created-at (qr-token-created-at token)
          :expires-at (qr-token-expires-at token))))

(defun import-qr-login-token (token-data)
  "Import and authorize using a QR login token.

   Args:
     token-data: Token data from QR code scan

   Returns:
     T on success, NIL with error on failure

   Example:
     (import-qr-login-token \"tg://login?token=...\")"
  (handler-case
      (let* ((connection (get-connection))
             ;; Extract token from URL
             (token (when (search "token=" token-data)
                     (subseq token-data (+ (search "token=" token-data) 6))))
             (request (make-tl-object 'auth.importLoginToken
                                      :token token)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when (and result (getf result :authorization))
            ;; Update token status if found in our table
            (maphash (lambda (k v)
                       (when (equal (qr-token-data v) token-data)
                         (setf (qr-token-status v) :authorized
                               (qr-token-authorized-user-id v) (getf result :user-id))))
                     *qr-login-tokens*)
            t)))
    (t (e)
      (log:error "Import QR login token failed: ~A" e)
      nil)))

(defun accept-qr-login-token (token-id)
  "Accept a QR login token (called when user scans QR code).

   Args:
     token-id: Token identifier

   Returns:
     T on success

   Example:
     (accept-qr-login-token \"qr_123\")"
  (let ((token (gethash token-id *qr-login-tokens*)))
    (unless token
      (return-from accept-qr-login-token (values nil "Token not found")))

    ;; Check expiration
    (when (>= (get-universal-time) (qr-token-expires-at token))
      (setf (qr-token-status token) :expired)
      (return-from accept-qr-login-token (values nil "Token expired")))

    (handler-case
        (let* ((connection (get-connection))
               (request (make-tl-object 'auth.acceptLoginToken
                                        :token (qr-token-data token))))
          (let ((result (rpc-call connection request :timeout 10000)))
            (when (and result (getf result :user))
              (setf (qr-token-status token) :authorized
                    (qr-token-authorized-user-id token) (getf (getf result :user) :id))
              (log:info "QR login token accepted: ~A (user=~D)" token-id (qr-token-authorized-user-id token))
              t)))
      (t (e)
        (log:error "Accept QR login token failed: ~A" e)
        (values nil e)))))

;;; ============================================================================
;;; Section 2: Two-Factor Authentication
;;; ============================================================================

(defclass two-factor-auth-info ()
  ((has-password :initarg :has-password :initform nil :accessor 2fa-has-password)
   (password-hint :initarg :password-hint :initform nil :accessor 2fa-password-hint)
   (email-recovery :initarg :email-recovery :initform nil :accessor 2fa-email-recovery)
   (enabled-at :initarg :enabled-at :initform nil :accessor 2fa-enabled-at)))

(defvar *2fa-info* nil
  "Cached 2FA info for current user")

(defun get-2fa-status ()
  "Get two-factor authentication status for current user.

   Returns:
     Plist with 2FA status

   Example:
     (get-2fa-status)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.getPassword)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when result
            (let ((has-password (getf result :has-password nil)))
              (setf *2fa-info* (make-instance 'two-factor-auth-info
                                              :has-password has-password
                                              :password-hint (getf result :hint nil)
                                              :email-recovery (getf result :email-recovery nil)
                                              :enabled-at (when has-password (get-universal-time))))
              (list :enabled has-password
                    :has-hint (and (getf result :hint nil) t)
                    :has-email-recovery (and (getf result :email-recovery nil) t))))))
    (t (e)
      (log:error "Get 2FA status failed: ~A" e)
      (list :enabled nil :error (format nil "~A" e)))))

(defun enable-two-factor-auth (password &key (hint nil) (email nil))
  "Enable two-factor authentication.

   Args:
     password: Password string
     hint: Optional password hint
     email: Optional recovery email

   Returns:
     T on success, NIL with error on failure

   Example:
     (enable-two-factor-auth \"mypassword\" :hint \"pet name\" :email \"user@example.com\")"
  (handler-case
      (let* ((connection (get-connection))
             ;; Generate password hash and salt
             (salt (ironclad:make-random-sequence 32))
             (password-hash (ironclad:digest-sequence :sha-256
                                                      (concatenate 'simple-string password
                                                                   (ironclad:byte-array-to-hex-string salt))))
             (request (make-tl-object 'account.updatePasswordSettings
                                      :new-settings (make-tl-object 'account.passwordInputSettings
                                                                    :new-salt salt
                                                                    :new-password-hash password-hash
                                                                    :hint (or hint "")
                                                                    :email (or email "")))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when result
            (setf *2fa-info* (make-instance 'two-factor-auth-info
                                            :has-password t
                                            :password-hint hint
                                            :email-recovery email
                                            :enabled-at (get-universal-time)))
            (log:info "2FA enabled for user")
            t)))
    (t (e)
      (log:error "Enable 2FA failed: ~A" e)
      (values nil e))))

(defun disable-two-factor-auth (password)
  "Disable two-factor authentication.

   Args:
     password: Current password

   Returns:
     T on success, NIL with error on failure

   Example:
     (disable-two-factor-auth \"mypassword\")"
  (handler-case
      (let* ((connection (get-connection))
             ;; Get current password info first
             (pw-info (rpc-call connection (make-tl-object 'account.getPassword) :timeout 10000))
             (salt (getf pw-info :current-salt))
             (password-hash (ironclad:digest-sequence :sha-256
                                                      (concatenate 'simple-string password
                                                                   (ironclad:byte-array-to-hex-string salt))))
             (request (make-tl-object 'account.updatePasswordSettings
                                      :new-settings (make-tl-object 'account.passwordInputSettings
                                                                    :new-salt (ironclad:make-random-sequence 32)
                                                                    :new-password-hash #()
                                                                    :current-password-hash password-hash
                                                                    :hint ""
                                                                    :email ""))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when result
            (setf *2fa-info* nil)
            (log:info "2FA disabled for user")
            t)))
    (t (e)
      (log:error "Disable 2FA failed: ~A" e)
      (values nil e))))

(defun change-two-factor-password (old-password new-password &key (hint nil))
  "Change two-factor authentication password.

   Args:
     old-password: Current password
     new-password: New password
     hint: Optional new password hint

   Returns:
     T on success, NIL with error on failure

   Example:
     (change-two-factor-password \"oldpass\" \"newpass\" :hint \"new hint\")"
  (handler-case
      (let* ((connection (get-connection))
             ;; Get current password info
             (pw-info (rpc-call connection (make-tl-object 'account.getPassword) :timeout 10000))
             (salt (getf pw-info :current-salt))
             (old-hash (ironcland:digest-sequence :sha-256
                                                  (concatenate 'simple-string old-password
                                                               (ironclad:byte-array-to-hex-string salt))))
             (new-salt (ironclad:make-random-sequence 32))
             (new-hash (ironclad:digest-sequence :sha-256
                                                 (concatenate 'simple-string new-password
                                                              (ironclad:byte-array-to-hex-string new-salt))))
             (request (make-tl-object 'account.updatePasswordSettings
                                      :new-settings (make-tl-object 'account.passwordInputSettings
                                                                    :new-salt new-salt
                                                                    :new-password-hash new-hash
                                                                    :current-password-hash old-hash
                                                                    :hint (or hint "")))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when result
            (log:info "2FA password changed")
            t)))
    (t (e)
      (log:error "Change 2FA password failed: ~A" e)
      (values nil e))))

(defun verify-two-factor-auth (password)
  "Verify two-factor authentication password (for login).

   Args:
     password: Password to verify

   Returns:
     T on success, NIL on failure

   Example:
     (verify-two-factor-auth \"mypassword\")"
  (handler-case
      (let* ((connection (get-connection))
             (pw-info (rpc-call connection (make-tl-object 'account.getPassword) :timeout 10000))
             (salt (getf pw-info :current-salt))
             (password-hash (ironclad:digest-sequence :sha-256
                                                      (concatenate 'simple-string password
                                                                   (ironclad:byte-array-to-hex-string salt))))
             (request (make-tl-object 'auth.checkPassword
                                      :password (make-tl-object 'input-check-password-srp
                                                                :a (getf pw-info :srp-a)
                                                                :b (getf pw-info :srp-b)
                                                                :server-public-key-id1 (getf pw-info :server-public-key-id1)
                                                                :server-public-key-id2 (getf pw-info :server-public-key-id2)
                                                                :password-hash password-hash))))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when (and result (getf result :authorization))
            t)))
    (t (e)
      (log:error "Verify 2FA failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 3: Session Management
;;; ============================================================================

(defclass auth-session ()
  ((session-id :initarg :session-id :accessor auth-session-id)
   (device-model :initarg :device-model :accessor auth-session-device-model)
   (platform :initarg :platform :accessor auth-session-platform)
   (system-version :initarg :system-version :accessor auth-session-system-version)
   (app-name :initarg :app-name :accessor auth-session-app-name)
   (date-created :initarg :date-created :accessor auth-session-date-created)
   (date-active :initarg :date-active :accessor auth-session-date-active)
   (ip-address :initarg :ip-address :accessor auth-session-ip-address)
   (country :initarg :country :accessor auth-session-country)
   (region :initarg :region :accessor auth-session-region)
   (official-app :initarg :official-app :initform t :accessor auth-session-official-app)
   (current-p :initarg :current-p :initform nil :accessor auth-session-current-p)))

(defun get-active-sessions ()
  "Get list of active sessions for current user.

   Returns:
     List of session plists

   Example:
     (get-active-sessions)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.getAuthorizations)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when (and result (getf result :authorizations))
            (mapcar (lambda (auth)
                      (list :session-id (getf auth :hash)
                            :device-model (getf auth :device-model "Unknown")
                            :platform (getf auth :platform "Unknown")
                            :system-version (getf auth :system-version "Unknown")
                            :app-name (getf auth :app-name "Unknown")
                            :date-created (getf auth :date-created)
                            :date-active (getf auth :date-active)
                            :ip-address (getf auth :ip "Unknown")
                            :country (getf auth :country "Unknown")
                            :region (getf auth :region "Unknown")
                            :official-app (getf auth :official-app t)
                            :current-p (getf auth :current-p nil)))
                    (getf result :authorizations)))))
    (t (e)
      (log:error "Get active sessions failed: ~A" e)
      nil)))

(defun terminate-session (session-id)
  "Terminate a specific session.

   Args:
     session-id: Session identifier (hash)

   Returns:
     T on success, NIL on failure

   Example:
     (terminate-session 123456789)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.resetAuthorization
                                      :hash session-id)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when result
            (log:info "Session terminated: ~A" session-id)
            t)))
    (t (e)
      (log:error "Terminate session failed: ~A" e)
      nil)))

(defun terminate-all-sessions (&key (keep-current t))
  "Terminate all sessions.

   Args:
     keep-current: Whether to keep current session (default: T)

   Returns:
     T on success, NIL on failure

   Example:
     (terminate-all-sessions :keep-current t)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.resetAuthorizations)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when result
            (log:info "All sessions terminated")
            t)))
    (t (e)
      (log:error "Terminate all sessions failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 4: Privacy Settings
;;; ============================================================================

(defclass privacy-setting ()
  ((key :initarg :key :accessor privacy-setting-key)
   (rules :initarg :rules :accessor privacy-setting-rules)
   (users-allowed :initarg :users-allowed :initform nil :accessor privacy-setting-users-allowed)
   (users-denied :initarg :users-denied :initform nil :accessor privacy-setting-users-denied)))

(defun get-privacy-settings ()
  "Get all privacy settings.

   Returns:
     Plist with privacy settings

   Example:
     (get-privacy-settings)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.getPrivacySettings)))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when (and result (getf result :settings))
            (let ((settings nil))
              (dolist (setting (getf result :settings))
                (let ((key (getf setting :key)))
                  (setf settings (plist-put settings key (getf setting :rules)))))
              settings)))
    (t (e)
      (log:error "Get privacy settings failed: ~A" e)
      nil)))

(defun set-privacy-setting (rule-type allowed-users &key (denied-users nil))
  "Set privacy rule for a specific type.

   Args:
     rule-type: Type of privacy rule
                (:phone-number, :last-seen, :profile-photo,
                 :forward-messages, :calls, :invite-links,
                 :voice-messages, :find-by-phone)
     allowed-users: List of user IDs to allow, or :all, :contacts, :close-friends
     denied-users: Optional list of user IDs to deny

   Returns:
     T on success, NIL on failure

   Example:
     (set-privacy-setting :last-seen :contacts)
     (set-privacy-setting :phone-number '(123 456) :denied-users '(789))"
  (handler-case
      (let* ((connection (get-connection))
             ;; Build privacy rules
             (rules (cond
                      ((eq allowed-users :all)
                       '(:privacy-rule-allow-all))
                      ((eq allowed-users :contacts)
                       '(:privacy-rule-allow-contacts))
                      ((eq allowed-users :close-friends)
                       '(:privacy-rule-allow-close-friends))
                      (t
                       ;; Specific users
                       (append '(:privacy-rule-allow-users)
                               (mapcar (lambda (uid) (make-tl-object 'input-user :user-id uid))
                                       allowed-users)))))
             ;; Add deny rules if specified
             (rules (if denied-users
                       (append rules
                               '(:privacy-rule-deny-users)
                               (mapcar (lambda (uid) (make-tl-object 'input-user :user-id uid))
                                       denied-users))
                       rules)))
        (let ((request (make-tl-object 'account.setPrivacy
                                       :key (case rule-type
                                              (:phone-number :privacy-key-phone-number)
                                              (:last-seen :privacy-key-last-seen)
                                              (:profile-photo :privacy-key-profile-photo)
                                              (:forward-messages :privacy-key-forwards)
                                              (:calls :privacy-key-phone-call)
                                              (:invite-links :privacy-key-chat-invite)
                                              (:voice-messages :privacy-key-voice-messages)
                                              (:find-by-phone :privacy-key-added-by-phone)
                                              (otherwise rule-type))
                                       :rules rules)))
          (let ((result (rpc-call connection request :timeout 10000)))
            (when result
              (log:info "Privacy setting updated: ~A" rule-type)
              t)))))
    (t (e)
      (log:error "Set privacy setting failed: ~A" e)
      nil)))

(defun get-privacy-visibility (user-id)
  "Get what a specific user can see about current user.

   Args:
     user-id: User ID to check

   Returns:
     Plist with visibility information

   Example:
     (get-privacy-visibility 123456)"
  ;; This would require checking all privacy settings against the user
  ;; For now, return a simplified version
  (let ((settings (get-privacy-settings)))
    (when settings
      (list :user-id user-id
            :can-see-phone (getf settings :privacy-key-phone-number)
            :can-see-last-seen (getf settings :privacy-key-last-seen)
            :can-see-profile-photo (getf settings :privacy-key-profile-photo)
            :can-forward-messages (getf settings :privacy-key-forwards)
            :can-call (getf settings :privacy-key-phone-call)))))

;;; ============================================================================
;;; Section 5: Phone Number Management
;;; ============================================================================

(defun get-current-phone-number ()
  "Get current account phone number.

   Returns:
     Phone number string or NIL

   Example:
     (get-current-phone-number)"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'users.getUsers
                                      :id (list (make-tl-object 'input-user-self)))))
        (let ((result (rpc-call connection request :timeout 10000)))
          (when (and result (getf result :users))
            (let ((user (first (getf result :users))))
              (getf user :phone nil)))))
    (t (e)
      (log:error "Get phone number failed: ~A" e)
      nil)))

(defun change-phone-number (new-phone-number)
  "Change account phone number.

   Args:
     new-phone-number: New phone number in international format

   Returns:
     T on success, NIL with error on failure

   Example:
     (change-phone-number \"+1234567890\")"
  (handler-case
      (let* ((connection (get-connection))
             ;; Step 1: Request code
             (request1 (make-tl-object 'account.sendChangePhoneCode
                                       :phone-number new-phone-number
                                       :settings (make-tl-object 'code-settings
                                                                 :allow-app-hash t
                                                                 :current-password nil)))
             (result1 (rpc-call connection request1 :timeout 30000)))
        (when result1
          ;; Step 2: User would enter code here
          ;; For implementation, we'd need to wait for user input
          (log:info "Phone change code sent to ~A" new-phone-number)
          ;; Return phone change session info
          (list :phone-change-session (getf result1 :phone-code-hash)
                :message "Please enter the code sent to your phone"))))
    (t (e)
      (log:error "Change phone number failed: ~A" e)
      nil)))

(defun confirm-phone-number (phone-code-hash code)
  "Confirm phone number change with verification code.

   Args:
     phone-code-hash: Hash from change-phone-number
     code: Verification code received via SMS

   Returns:
     T on success

   Example:
     (confirm-phone-number \"hash\" \"12345\")"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'account.changePhone
                                      :phone-number code
                                      :phone-code-hash phone-code-hash)))
        (let ((result (rpc-call connection request :timeout 30000)))
          (when (and result (getf result :user))
            (log:info "Phone number changed successfully")
            t)))
    (t (e)
      (log:error "Confirm phone number failed: ~A" e)
      nil)))

;;; ============================================================================
;;; Section 6: Statistics
;;; ============================================================================

(defun get-security-stats ()
  "Get account security statistics.

   Returns:
     Plist with security statistics

   Example:
     (get-security-stats)"
  (let ((sessions (get-active-sessions))
        (2fa-status (get-2fa-status)))
    (list :active-sessions (length (or sessions nil))
          :2fa-enabled (getf 2fa-status :enabled nil)
          :official-apps (count-if (lambda (s) (getf s :official-app)) sessions)
          :unknown-devices (count-if (lambda (s) (equal (getf s :device-model) "Unknown")) sessions))))

;;; ============================================================================
;;; Section 7: Initialization
;;; ============================================================================

(defun initialize-account-security-enhanced ()
  "Initialize enhanced account security features.

   Returns:
     T on success"
  (handler-case
      (progn
        ;; Load current 2FA status
        (get-2fa-status)
        (log:info "Enhanced account security initialized")
        t)
    (t (e)
      (log:error "Failed to initialize account security: ~A" e)
      nil)))

(defun shutdown-account-security-enhanced ()
  "Shutdown enhanced account security.

   Returns:
     T on success"
  (handler-case
      (progn
        ;; Clear sensitive data
        (setf *2fa-info* nil)
        (clrhash *qr-login-tokens*)
        (log:info "Enhanced account security shutdown complete")
        t)
    (t (e)
      (log:error "Failed to shutdown account security: ~A" e)
      nil)))

;;; Export symbols
(export '(;; QR Login
          qr-login-token
          generate-qr-login-token
          get-qr-code-image
          check-qr-login-status
          import-qr-login-token
          accept-qr-login-token

          ;; 2FA
          two-factor-auth-info
          get-2fa-status
          enable-two-factor-auth
          disable-two-factor-auth
          change-two-factor-password
          verify-two-factor-auth

          ;; Sessions
          auth-session
          get-active-sessions
          terminate-session
          terminate-all-sessions

          ;; Privacy
          privacy-setting
          get-privacy-settings
          set-privacy-setting
          get-privacy-visibility

          ;; Phone
          get-current-phone-number
          change-phone-number
          confirm-phone-number

          ;; Statistics
          get-security-stats

          ;; Initialization
          initialize-account-security-enhanced
          shutdown-account-security-enhanced

          ;; State
          *qr-login-tokens*
          *2fa-info*))
