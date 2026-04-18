;;; auth-api.lisp --- Authentication API implementation

(in-package #:cl-telegram/api)

;;; ### Authentication State Management

(defvar *auth-state* :wait-tdlib-parameters
  "Current authentication state keyword.")

(defvar *auth-phone-number* nil
  "Phone number being authenticated.")

(defvar *auth-code-info* nil
  "Information about sent authentication code.")

(defvar *auth-connection* nil
  "Current MTProto connection.")

(defvar *auth-session-id* nil
  "Session ID for authentication.")

;;; ### TDLib Compatible API

(defun set-authentication-phone-number (phone-number)
  "Set phone number for authentication.

   Args:
     phone-number: Phone number string (e.g., "+1234567890")

   Returns:
     T if phone number accepted

   State transition: wait_phone_number → wait_code"
  (assert (stringp phone-number))
  (assert (>= (length phone-number) 8))

  (setf *auth-phone-number* phone-number
        *auth-state* :wait-code)

  ;; In full implementation: send req_pq_multi to Telegram
  (format t "Phone number set: ~A~%" phone-number)
  t)

(defun request-authentication-code (&key phone-number)
  "Request authentication code to be sent.

   Args:
     phone-number: Optional phone number (uses stored if not provided)

   Returns:
     Code info on success, or error list

   This triggers Telegram to send an SMS/call with the verification code."
  (let ((phone (or phone-number *auth-phone-number*)))
    (unless phone
      (return-from request-authentication-code
        (list :error :no-phone "Phone number not set")))

    ;; In full implementation:
    ;; 1. Create connection to Telegram DC
    ;; 2. Send req_pq_multi
    ;; 3. Handle resPQ
    ;; 4. Send req_DH_params
    ;; 5. Complete DH exchange
    ;; 6. Send auth.sendCode

    (setf *auth-code-info* (list :type :sms :length 5 :timeout 120))
    (list :success :code-sent :phone phone)))

(defun check-authentication-code (code)
  "Verify the authentication code.

   Args:
     code: Verification code string or integer

   Returns:
     T on success, error list on failure

   State transitions:
   - wait_code → wait_password (if 2FA enabled)
   - wait_code → ready (if no 2FA)
   - wait_code → wait_registration (new account)"
  (unless (or (stringp code) (integerp code))
    (return-from check-authentication-code
      (list :error :invalid-code "Code must be string or integer")))

  (if (string= code "12345")  ; Demo: accept any code for testing
      (progn
        ;; Check if user has 2FA enabled
        ;; For demo, assume no 2FA
        (setf *auth-state* :ready)
        (list :success :authenticated))
      (list :error :invalid-code "Incorrect verification code")))

(defun set-authentication-password (password)
  "Enter 2FA password.

   Args:
     password: Account password string

   Returns:
     T on success, error list on failure

   State transition: wait_password → ready"
  (unless (stringp password)
    (return-from set-authentication-password
      (list :error :invalid-password "Password must be string")))

  ;; In full implementation: send auth.checkPassword
  (setf *auth-state* :ready)
  (list :success :authenticated))

(defun register-user (first-name last-name &key bio)
  "Register a new user account.

   Args:
     first-name: User's first name
     last-name: User's last name
     bio: Optional bio text

   Returns:
     User info on success, error list on failure

   State transition: wait_registration → ready"
  (unless (and (stringp first-name) (stringp last-name))
    (return-from register-user
      (list :error :invalid-name "Names must be strings")))

  (assert (>= (length first-name) 1) "First name required")
  (assert (>= (length last-name) 1) "Last name required")

  ;; In full implementation: send auth.signUp
  (setf *auth-state* :ready)
  (list :success :registered
        :user (list :first_name first-name
                    :last_name last-name
                    :bio bio)))

(defun get-authentication-state ()
  "Get current authentication state.

   Returns:
     Keyword representing current state:
     - :wait-tdlib-parameters
     - :wait-phone-number
     - :wait-code
     - :wait-password
     - :wait-registration
     - :ready
     - :logging-out
     - :closed"
  *auth-state*)

;;; ### Session Management

(defun get-auth-session ()
  "Get current auth session info.

   Returns:
     Plist with session information"
  (list :state *auth-state*
        :phone *auth-phone-number*
        :code-info *auth-code-info*
        :connection *auth-connection*
        :session-id *auth-session-id*))

(defun reset-auth-session ()
  "Reset authentication session to initial state."
  (setf *auth-state* :wait-tdlib-parameters
        *auth-phone-number* nil
        *auth-code-info* nil
        *auth-connection* nil
        *auth-session-id* nil)
  t)

;;; ### Authorization Helper Functions

(defun authorized-p ()
  "Check if client is authorized (logged in)."
  (eq *auth-state* :ready))

(defun needs-phone-p ()
  "Check if phone number is needed."
  (member *auth-state* '(:wait-tdlib-parameters :wait-phone-number)))

(defun needs-code-p ()
  "Check if verification code is needed."
  (eq *auth-state* :wait-code))

(defun needs-password-p ()
  "Check if 2FA password is needed."
  (eq *auth-state* :wait-password))

(defun needs-registration-p ()
  "Check if new user registration is needed."
  (eq *auth-state* :wait-registration))

;;; ### TDLib Compatibility Layer

;; These functions map to TDLib API methods

(defun |setTdlibParameters| (&key parameters)
  "TDLib compatible: Set TDLib parameters.

   Args:
     parameters: Plist with api_id, api_hash, device_info, etc."
  (declare (ignore parameters))
  ;; For now, just acknowledge
  (setf *auth-state* :wait-phone-number)
  (list :ok t))

(defun |setAuthenticationPhoneNumber| (phone-number &key settings)
  "TDLib compatible: Set authentication phone number.

   Args:
     phone-number: Phone number string
     settings: Optional settings plist"
  (declare (ignore settings))
  (set-authentication-phone-number phone-number))

(defun |requestAuthenticationCode| (&key request-options)
  "TDLib compatible: Request authentication code.

   Args:
     request-options: Optional request options"
  (declare (ignore request-options))
  (request-authentication-code))

(defun |checkAuthenticationCode| (code &key request-options)
  "TDLib compatible: Check authentication code.

   Args:
     code: Verification code
     request-options: Optional request options"
  (declare (ignore request-options))
  (check-authentication-code code))

(defun |checkAuthenticationPassword| (password)
  "TDLib compatible: Check 2FA password.

   Args:
     password: Password string"
  (set-authentication-password password))

(defun |registerUser| (first-name last-name)
  "TDLib compatible: Register new user.

   Args:
     first-name: First name
     last-name: Last name"
  (register-user first-name last-name))

;;; ### Connection Integration

(defun ensure-auth-connection ()
  "Ensure connection to Telegram servers is established.

   Returns:
     Connection instance or NIL"
  (unless *auth-connection*
    ;; Create connection to default DC
    (let ((conn (cl-telegram/network:make-connection
                 :host "149.154.167.51"  ; DC2
                 :port 443)))
      (setf *auth-connection* conn)
      (cl-telegram/network:connect conn)))
  *auth-connection*)

(defun close-auth-connection ()
  "Close the authentication connection."
  (when *auth-connection*
    (cl-telegram/network:disconnect *auth-connection*)
    (setf *auth-connection* nil))
  t)

;;; ### Demo/Test Functions

(defun demo-auth-flow ()
  "Run a demo authentication flow for testing.

   This simulates the complete auth process without actual network calls."
  (format t "=== Demo Auth Flow ===~%")

  (format t "1. Setting phone number...~%")
  (set-authentication-phone-number "+1234567890")

  (format t "2. Requesting code...~%")
  (request-authentication-code)

  (format t "3. Checking code (12345)...~%")
  (let ((result (check-authentication-code "12345")))
    (format t "   Result: ~A~%" result))

  (format t "4. Current state: ~A~%" (get-authentication-state))
  (format t "=== Auth Flow Complete ===~%")

  (authorized-p))
