;;; account-security-v2.lisp --- Enhanced account security and privacy management
;;;
;;; Provides support for:
;;; - Privacy settings management
;;; - Active session (authorization) management
;;; - Two-factor authentication (2FA)
;;; - QR code login
;;; - Phone number change
;;;
;;; Version: 0.37.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Classes and Global State
;;; ============================================================================

(defclass privacy-setting ()
  ((key :initarg :key :accessor privacy-setting-key
        :initform "" :documentation "Privacy setting key")
   (rules :initarg :rules :accessor privacy-setting-rules
          :initform nil :documentation "List of privacy rules")
   (users :initarg :users :accessor privacy-setting-users
          :initform nil :documentation "List of specific user IDs")))

(defclass authorization ()
  ((hash :initarg :hash :accessor authorization-hash
         :initform "" :documentation "Authorization hash")
   (device-id :initarg :device-id :accessor authorization-device-id
              :initform "" :documentation "Device identifier")
   (api-id :initarg :api-id :accessor authorization-api-id
           :initform 0 :documentation "API ID")
   (app-name :initarg :app-name :accessor authorization-app-name
             :initform "" :documentation "Application name")
   (app-version :initarg :app-version :accessor authorization-app-version
                :initform "" :documentation "Application version")
   (date-created :initarg :date-created :accessor authorization-date-created
                 :initform 0 :documentation "Creation timestamp")
   (date-active :initarg :date-active :accessor authorization-date-active
                :initform 0 :documentation "Last active timestamp")
   (ip :initarg :ip :accessor authorization-ip
       :initform "" :documentation "IP address")
   (country :initarg :country :accessor authorization-country
            :initform "" :documentation "Country")
   (region :initarg :region :accessor authorization-region
           :initform "" :documentation "Region")
   (official :initarg :official :accessor authorization-official
             :initform t :documentation "Whether official app")
   (current :initarg :current :accessor authorization-current
            :initform nil :documentation "Whether current session")))

(defclass two-factor-auth ()
  ((enabled :initarg :enabled :accessor two-factor-auth-enabled
            :initform nil :documentation "Whether 2FA is enabled")
   (has-password :initarg :has-password :accessor two-factor-auth-has-password
                 :initform nil :documentation "Whether password is set")
   (password-hint :initarg :password-hint :accessor two-factor-auth-password-hint
                  :initform nil :documentation "Password hint")
   (email-unsent :initarg :email-unsent :accessor two-factor-auth-email-unsent
                 :initform nil :documentation "Whether email is unsent")
   (recovery-email :initarg :recovery-email :accessor two-factor-auth-recovery-email
                   :initform nil :documentation "Recovery email pattern")))

(defvar *privacy-settings-cache* (make-hash-table :test 'equal)
  "Cache for privacy settings")

(defvar *authorizations-cache* nil
  "Cache for authorization list")

(defvar *qr-login-state* nil
  "State for QR code login")

(defvar *cache-expiry-time* 300
  "Cache expiry time in seconds (default: 5 minutes)")

;;; ============================================================================
;;; Section 2: Privacy Settings Functions
;;; ============================================================================

(defun get-privacy-settings (&key (force-refresh nil))
  "Get privacy settings.

   Args:
     force-refresh: Force refresh from server (default: nil)

   Returns:
     List of privacy-setting objects on success, NIL on failure

   Example:
     (get-privacy-settings)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        (when force-refresh
          (push (cons "force_refresh" "true") params))

        (let ((result (make-api-call connection "getPrivacySettings" params)))
          (if result
              (let ((settings (getf result :settings)))
                (mapcar (lambda (setting-data)
                          (make-instance 'privacy-setting
                                         :key (getf setting-data :key)
                                         :rules (getf setting-data :rules)
                                         :users (getf setting-data :users)))
                        settings))
              nil)))
    (error (e)
      (log-message :error "Error getting privacy settings: ~A" (princ-to-string e))
      nil)))

(defun set-privacy-settings (key rules &key (users nil))
  "Set privacy settings.

   Args:
     key: Privacy setting key (e.g., "phone_number", "last_seen", "profile_photo")
     rules: List of privacy rules (:allow-all, :allow-contacts, :allow-premium,
                                  :allow-users, :disallow-all, :disallow-contacts,
                                  :disallow-premium, :disallow-users)
     users: Optional list of specific user IDs for allow-users/disallow-users

   Returns:
     T on success, NIL on failure

   Example:
     (set-privacy-settings "last_seen" '(:allow-contacts :disallow-users) :users '(123 456))"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("key" . ,key)
                       ("rules" . ,(json:encode-to-string rules)))))
        (when users
          (push (cons "users" (json:encode-to-string users)) params))

        (let ((result (make-api-call connection "setPrivacySettings" params)))
          (if result
              (progn
                ;; Update cache
                (let ((setting (make-instance 'privacy-setting
                                              :key key
                                              :rules rules
                                              :users users)))
                  (setf (gethash key *privacy-settings-cache*) setting))
                (log-message :info "Privacy setting '~A' updated" key)
                t)
              nil)))
    (error (e)
      (log-message :error "Error setting privacy settings: ~A" (princ-to-string e))
      nil)))

(defun get-privacy-setting (key &key (force-refresh nil))
  "Get a specific privacy setting.

   Args:
     key: Privacy setting key
     force-refresh: Force refresh from server

   Returns:
     Privacy-setting object or NIL

   Example:
     (get-privacy-setting "last_seen")"
  (unless force-refresh
    (let ((cached (gethash key *privacy-settings-cache*)))
      (when cached
        (return-from get-privacy-setting cached))))

  (let ((settings (get-privacy-settings :force-refresh t)))
    (when settings
      (let ((setting (find key settings :key #'privacy-setting-key :test #'string=)))
        (when setting
          (setf (gethash key *privacy-settings-cache*) setting)
          setting)))))

(defun reset-privacy-settings (key)
  "Reset privacy setting to default.

   Args:
     key: Privacy setting key

   Returns:
     T on success, NIL on failure

   Example:
     (reset-privacy-settings "last_seen")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("key" . ,key))))
        (let ((result (make-api-call connection "resetPrivacySettings" params)))
          (if result
              (progn
                (remhash key *privacy-settings-cache*)
                (log-message :info "Privacy setting '~A' reset" key)
                t)
              nil)))
    (error (e)
      (log-message :error "Error resetting privacy settings: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 3: Authorization Management
;;; ============================================================================

(defun get-authorizations (&key (force-refresh nil))
  "Get list of active authorizations (sessions).

   Args:
     force-refresh: Force refresh from server (default: nil)

   Returns:
     List of authorization objects on success, NIL on failure

   Example:
     (get-authorizations)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        (when force-refresh
          (push (cons "force_refresh" "true") params))

        (let ((result (make-api-call connection "getAuthorizations" params)))
          (if result
              (let ((auths (getf result :authorizations)))
                (mapcar (lambda (auth-data)
                          (make-instance 'authorization
                                         :hash (getf auth-data :hash)
                                         :device-id (getf auth-data :device_id)
                                         :api-id (getf auth-data :api_id)
                                         :app-name (getf auth-data :app_name)
                                         :app-version (getf auth-data :app_version)
                                         :date-created (getf auth-data :date_created)
                                         :date-active (getf auth-data :date_active)
                                         :ip (getf auth-data :ip)
                                         :country (getf auth-data :country)
                                         :region (getf auth-data :region)
                                         :official (getf auth-data :official t)
                                         :current (getf auth-data :current nil)))
                        auths))
              nil)))
    (error (e)
      (log-message :error "Error getting authorizations: ~A" (princ-to-string e))
      nil)))

(defun terminate-authorization (hash)
  "Terminate a specific authorization (session).

   Args:
     hash: Authorization hash from get-authorizations

   Returns:
     T on success, NIL on failure

   Example:
     (terminate-authorization "abc123")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("hash" . ,hash))))
        (let ((result (make-api-call connection "terminateAuthorization" params)))
          (if result
              (progn
                (log-message :info "Authorization ~A terminated" hash)
                t)
              nil)))
    (error (e)
      (log-message :error "Error terminating authorization: ~A" (princ-to-string e))
      nil)))

(defun terminate-all-authorizations (&key (keep-current t))
  "Terminate all authorizations except current session.

   Args:
     keep-current: Keep current session (default: t)

   Returns:
     T on success, NIL on failure

   Example:
     (terminate-all-authorizations)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        (unless keep-current
          (push (cons "terminate_current" "true") params))

        (let ((result (make-api-call connection "terminateAllAuthorizations" params)))
          (if result
              (progn
                (log-message :info "All authorizations terminated")
                t)
              nil)))
    (error (e)
      (log-message :error "Error terminating all authorizations: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 4: Two-Factor Authentication
;;; ============================================================================

(defun get-two-factor-status ()
  "Get two-factor authentication status.

   Returns:
     Two-factor-auth object on success, NIL on failure

   Example:
     (get-two-factor-status)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil)
             (result (make-api-call connection "getTwoFactorStatus" params)))
        (if result
            (make-instance 'two-factor-auth
                           :enabled (getf result :enabled nil)
                           :has-password (getf result :has_password nil)
                           :password-hint (getf result :password_hint nil)
                           :email-unsent (getf result :email_unsent nil)
                           :recovery-email (getf result :recovery_email nil))
            nil))
    (error (e)
      (log-message :error "Error getting two-factor status: ~A" (princ-to-string e))
      nil)))

(defun enable-two-factor (password &key (hint nil) (email nil))
  "Enable two-factor authentication.

   Args:
     password: Password string (min 6 characters)
     hint: Optional password hint
     email: Optional recovery email

   Returns:
     T on success, NIL on failure

   Example:
     (enable-two-factor "SecurePass123" :hint \"My favorite color\" :email \"user@example.com\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("password" . ,password))))
        (when hint
          (push (cons "hint" hint) params))
        (when email
          (push (cons "email" email) params))

        (let ((result (make-api-call connection "enableTwoFactor" params)))
          (if result
              (progn
                (log-message :info "Two-factor authentication enabled")
                t)
              nil)))
    (error (e)
      (log-message :error "Error enabling two-factor authentication: ~A" (princ-to-string e))
      nil)))

(defun disable-two-factor (password)
  "Disable two-factor authentication.

   Args:
     password: Current password

   Returns:
     T on success, NIL on failure

   Example:
     (disable-two-factor "SecurePass123")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("password" . ,password))))
        (let ((result (make-api-call connection "disableTwoFactor" params)))
          (if result
              (progn
                (log-message :info "Two-factor authentication disabled")
                t)
              nil)))
    (error (e)
      (log-message :error "Error disabling two-factor authentication: ~A" (princ-to-string e))
      nil)))

(defun change-two-factor-password (current-password new-password &key (hint nil))
  "Change two-factor authentication password.

   Args:
     current-password: Current password
     new-password: New password (min 6 characters)
     hint: Optional new password hint

   Returns:
     T on success, NIL on failure

   Example:
     (change-two-factor-password "OldPass123" "NewPass456" :hint \"New hint\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("current_password" . ,current-password)
                       ("new_password" . ,new-password))))
        (when hint
          (push (cons "hint" hint) params))

        (let ((result (make-api-call connection "changeTwoFactorPassword" params)))
          (if result
              (progn
                (log-message :info "Two-factor password changed")
                t)
              nil)))
    (error (e)
      (log-message :error "Error changing two-factor password: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 5: Additional Security Functions
;;; ============================================================================

(defun get-two-factor-recovery-code (password)
  "Get two-factor recovery code.

   Args:
     password: Current password

   Returns:
     Recovery code string on success, NIL on failure

   Example:
     (get-two-factor-recovery-code \"SecurePass123\")"
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("password" . ,password)))
             (result (make-api-call connection "getTwoFactorRecoveryCode" params)))
        (if result
            (getf result :recovery_code)
            nil))
    (error (e)
      (log-message :error "Error getting recovery code: ~A" (princ-to-string e))
      nil)))

(defun send-two-factor-recovery-email ()
  "Send two-factor recovery code to email.

   Returns:
     T on success, NIL on failure

   Example:
     (send-two-factor-recovery-email)"
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil)
             (result (make-api-call connection "sendTwoFactorRecoveryEmail" params)))
        (if result
            (progn
              (log-message :info "Recovery code sent to email")
              t)
            nil))
    (error (e)
      (log-message :error "Error sending recovery email: ~A" (princ-to-string e))
      nil)))

;;; ============================================================================
;;; Section 6: Utilities and Cache Management
;;; ============================================================================

(defun clear-privacy-settings-cache ()
  "Clear privacy settings cache.

   Returns:
     T on success

   Example:
     (clear-privacy-settings-cache)"
  (clrhash *privacy-settings-cache*)
  t)

(defun clear-authorizations-cache ()
  "Clear authorizations cache.

   Returns:
     T on success

   Example:
     (clear-authorizations-cache)"
  (setf *authorizations-cache* nil)
  t)

(defun get-cached-privacy-setting (key)
  "Get cached privacy setting.

   Args:
     key: Privacy setting key

   Returns:
     Privacy-setting object or NIL

   Example:
     (get-cached-privacy-setting \"last_seen\")"
  (gethash key *privacy-settings-cache*))

;;; ============================================================================
;;; Section 7: Initialization
;;; ============================================================================

(defun initialize-account-security-v2 ()
  "Initialize account security v2 system.

   Returns:
     T on success

   Example:
     (initialize-account-security-v2)"
  (handler-case
      (progn
        (log-message :info "Account security v2 system initialized")
        t)
    (error (e)
      (log-message :error "Failed to initialize account security v2: ~A" e)
      nil)))

(defun shutdown-account-security-v2 ()
  "Shutdown account security v2 system.

   Returns:
     T on success

   Example:
     (shutdown-account-security-v2)"
  (handler-case
      (progn
        (clear-privacy-settings-cache)
        (clear-authorizations-cache)
        (log-message :info "Account security v2 system shutdown complete")
        t)
    (error (e)
      (log-message :error "Failed to shutdown account security v2: ~A" e)
      nil)))

;;; End of account-security-v2.lisp
