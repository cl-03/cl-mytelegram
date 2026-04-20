;;; bot-api-9-advanced.lisp --- Advanced Bot API features for v0.30.0
;;;
;;; Provides CLOG-based implementation for advanced Mini App features:
;;; - Biometric Authentication (WebAuthn)
;;; - Contacts API
;;;
;;; Reference: https://core.telegram.org/bots/webapps
;;; Version: 0.30.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Biometric Authentication (WebAuthn)
;;; ============================================================================

(defvar *biometric-managers* (make-hash-table :test 'equal)
  "Hash table storing biometric manager instances")

(defun is-biometric-available ()
  "Check if biometric authentication is available.

   Returns:
     T if available, NIL otherwise

   Example:
     (is-biometric-available)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from is-biometric-available nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 window.PublicKeyCredential && window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()
                   .then(available => available)
                   .catch(() => false);
               " :wait t)))
          result)
      (t (e)
        (log:error "Exception in is-biometric-available: ~A" e)
        nil))))

(defun request-biometric-auth (&key (reason "Authenticate to continue") (timeout 60000))
  "Request biometric authentication.

   Args:
     reason: Reason text displayed to user
     timeout: Authentication timeout in ms

   Returns:
     Authentication result plist or NIL

   Example:
     (request-biometric-auth :reason \"Confirm payment\")"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from request-biometric-auth nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise(async (resolve) => {
                   try {
                     // Check if WebAuthn is supported
                     if (!window.PublicKeyCredential) {
                       resolve({ success: false, error: 'WebAuthn not supported' });
                       return;
                     }

                     // Create authentication challenge
                     const challenge = new Uint8Array(32);
                     crypto.getRandomValues(challenge);

                     const publicKey = {
                       challenge: challenge,
                       timeout: ~D,
                       userVerification: 'required',
                       rpId: location.hostname
                     };

                     const credential = await navigator.credentials.get({
                       publicKey: publicKey
                     });

                     resolve({
                       success: true,
                       credentialId: credential.id,
                       authenticatorData: credential.response.authenticatorData,
                       clientDataJSON: credential.response.clientDataJSON,
                       signature: credential.response.signature,
                       userHandle: credential.response.userHandle
                     });
                   } catch (error) {
                     resolve({
                       success: false,
                       error: error.name === 'NotAllowedError' ? 'User cancelled' : error.message,
                       code: error.name
                     });
                   }
                 });
               " timeout) :wait t)))
          result)
      (t (e)
        (log:error "Exception in request-biometric-auth: ~A" e)
        nil))))

(defun enroll-biometric (&key (biometric-type :fingerprint) (user-name "User"))
  "Enroll new biometric data.

   Args:
     biometric-type: Type of biometric (:fingerprint, :face, :iris)
     user-name: User display name

   Returns:
     Enrollment result plist or NIL

   Example:
     (enroll-biometric :biometric-type :face :user-name \"John\")"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from enroll-biometric nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise(async (resolve) => {
                   try {
                     // Check if WebAuthn is supported
                     if (!window.PublicKeyCredential) {
                       resolve({ success: false, error: 'WebAuthn not supported' });
                       return;
                     }

                     // Create registration challenge
                     const challenge = new Uint8Array(32);
                     crypto.getRandomValues(challenge);
                     const userId = new Uint8Array(32);
                     crypto.getRandomValues(userId);

                     const publicKey = {
                       challenge: challenge,
                       rp: {
                         name: document.title,
                         id: location.hostname
                       },
                       user: {
                         id: userId,
                         name: '~A',
                         displayName: '~A'
                       },
                       pubKeyCredParams: [
                         { type: 'public-key', alg: -7 },
                         { type: 'public-key', alg: -257 }
                       ],
                       timeout: 60000,
                       authenticatorSelection: {
                         authenticatorAttachment: 'platform',
                         userVerification: 'required'
                       }
                     };

                     const credential = await navigator.credentials.create({
                       publicKey: publicKey
                     });

                     resolve({
                       success: true,
                       credentialId: credential.id,
                       credentialType: credential.type,
                       transports: credential.response.getTransports ?
                         credential.response.getTransports() : []
                     });
                   } catch (error) {
                     resolve({
                       success: false,
                       error: error.name === 'NotAllowedError' ? 'User cancelled' : error.message,
                       code: error.name
                     });
                   }
                 });
               " user-name user-name) :wait t)))
          result)
      (t (e)
        (log:error "Exception in enroll-biometric: ~A" e)
        nil))))

(defun is-biometric-enrolled-p ()
  "Check if user has enrolled biometric data.

   Returns:
     T if enrolled, NIL otherwise

   Example:
     (is-biometric-enrolled-p)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from is-biometric-enrolled-p nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 navigator.credentials.get({
                   publicKey: {
                     challenge: new Uint8Array(32),
                     allowCredentials: [],
                     timeout: 1000
                   }
                 })
                 .then(credential => credential !== null)
                 .catch(() => false);
               " :wait t)))
          result)
      (t (e)
        (log:error "Exception in is-biometric-enrolled-p: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 2: Contacts API
;;; ============================================================================

(defvar *contacts-cache* (make-hash-table :test 'equal)
  "Cache for contacts data")

(defun is-contacts-api-supported ()
  "Check if Contacts API is supported.

   Returns:
     T if supported, NIL otherwise

   Example:
     (is-contacts-api-supported)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from is-contacts-api-supported nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 'contacts' in navigator || 'ContactPicker' in window;
               " :wait t)))
          result)
      (t (e)
        (log:error "Exception in is-contacts-api-supported: ~A" e)
        nil))))

(defun select-contacts (&key (multiple t) (limit 10))
  "Open contact picker.

   Args:
     multiple: If T, allow multiple contact selection
     limit: Maximum number of contacts to return

   Returns:
     List of contact plists or NIL

   Example:
     (select-contacts :multiple t :limit 5)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from select-contacts nil))
    (unless (is-contacts-api-supported)
      (log:warn "Contacts API not supported")
      (return-from select-contacts nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise((resolve) => {
                   const props = ['name', 'tel', 'email'];

                   navigator.contacts.select(props, {
                     multiple: ~:[false;true~]
                   })
                   .then(contacts => {
                     const result = contacts.slice(0, ~D).map(contact => ({
                       name: contact.name || contact.family || contact.given || '',
                       tel: contact.tel ? contact.tel[0] : null,
                       email: contact.email ? contact.email[0] : null
                     }));
                     resolve(result);
                   })
                   .catch(err => {
                     if (err.name === 'NotAllowedError') {
                       resolve(null); // User denied permission
                     } else if (err.name === 'AbortError') {
                       resolve([]); // User cancelled picker
                     } else {
                       resolve(null); // Other error
                     }
                   });
                 });
               " multiple limit) :wait t)))
          result)
      (t (e)
        (log:error "Exception in select-contacts: ~A" e)
        nil))))

(defun get-contact-details (contact-id)
  "Get detailed contact information.

   Args:
     contact-id: Contact identifier

   Returns:
     Contact detail plist or NIL

   Example:
     (get-contact-details \"contact_123\")"
  (let ((manager (get-mini-app-manager)))
    (unless (and (mini-app-connected-p manager) contact-id)
      (return-from get-contact-details nil))
    (handler-case
        (gethash contact-id *contacts-cache*)
      (t (e)
        (log:error "Exception in get-contact-details: ~A" e)
        nil))))

(defun cache-contacts (contacts)
  "Cache contacts data.

   Args:
     contacts: List of contact plists

   Returns:
     T

   Example:
     (cache-contacts contacts)"
  (let ((index 0))
    (dolist (contact contacts)
      (let ((contact-id (format nil "contact_~A_~A" (get-universal-time) index)))
        (setf (gethash contact-id *contacts-cache*) contact)
        (setf (getf contact :id) contact-id)
        (incf index))))
  (log:info "Cached ~D contacts" (length contacts))
  t)

(defun clear-contacts-cache ()
  "Clear contacts cache.

   Returns:
     T

   Example:
     (clear-contacts-cache)"
  (clrhash *contacts-cache*)
  (log:info "Contacts cache cleared")
  t)

;;; ============================================================================
;;; Section 3: Telegram WebApp Advanced Features
;;; ============================================================================

(defun expand-web-app ()
  "Expand the Mini App to full height.

   Returns:
     T

   Example:
     (expand-web-app)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from expand-web-app nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window "
            Telegram.WebApp.expand();
          ")
          t)
      (t (e)
        (log:error "Exception in expand-web-app: ~A" e)
        nil))))

(defun close-web-app ()
  "Close the Mini App.

   Returns:
     T

   Example:
     (close-web-app)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from close-web-app nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window "
            Telegram.WebApp.close();
          ")
          t)
      (t (e)
        (log:error "Exception in close-web-app: ~A" e)
        nil))))

(defun toggle-web-app-confirmation (&key (enable t))
  "Enable or disable close confirmation.

   Args:
     enable: If T, enable confirmation

   Returns:
     T

   Example:
     (toggle-web-app-confirmation :enable t)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from toggle-web-app-confirmation nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window (format nil "
            Telegram.WebApp~:[.disableCloseConfirmation();.enableCloseConfirmation();~]
          " enable))
          t)
      (t (e)
        (log:error "Exception in toggle-web-app-confirmation: ~A" e)
        nil))))

(defun setup-main-button (text &key (visible t) (progress nil))
  "Setup the Telegram Main Button.

   Args:
     text: Button text
     visible: If T, show button
     progress: Progress value (0.0-1.0) or NIL

   Returns:
     T

   Example:
     (setup-main-button \"Submit\" :visible t)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from setup-main-button nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window (format nil "
            const mainButton = Telegram.WebApp.MainButton;
            mainButton.text = '~A';
            mainButton.setParams({
              ~@[visible: ~:[false;true~],~]
              ~@[is_progress_visible: ~:[false;true~]~]
            });
            mainButton.show();
          " text (if visible t nil) (if progress t nil))))
      (t (e)
        (log:error "Exception in setup-main-button: ~A" e)
        nil))))

(defun on-main-button-click (handler-id handler-fn)
  "Register handler for Main Button click.

   Args:
     handler-id: Unique handler identifier
     handler-fn: Function to call on click

   Returns:
     T

   Example:
     (on-main-button-click 'submit (lambda () (submit-form)))"
  (let ((manager (get-mini-app-manager)))
    (when (mini-app-connected-p manager)
      (let ((window (mini-app-window manager)))
        (clog:run-js window (format nil "
          Telegram.WebApp.MainButton.onClick(() => {
            console.log('Main button clicked: ~A');
          });
        " handler-id))))
    (setf (gethash handler-id *share-target-handlers*) handler-fn)
    t))

;;; ============================================================================
;;; Section 4: Cache and Cleanup
;;; ============================================================================

(defun clear-biometric-cache ()
  "Clear biometric-related cache.

   Returns:
     T

   Example:
     (clear-biometric-cache)"
  (clrhash *biometric-managers*)
  (log:info "Biometric cache cleared")
  t)

(defun clear-advanced-cache ()
  "Clear all advanced feature caches.

   Returns:
     T

   Example:
     (clear-advanced-cache)"
  (clear-contacts-cache)
  (clear-biometric-cache)
  (log:info "Advanced feature caches cleared")
  t)

(defun get-advanced-stats ()
  "Get advanced features statistics.

   Returns:
     Plist with stats

   Example:
     (get-advanced-stats)"
  (list :biometric-managers (hash-table-count *biometric-managers*)
        :contacts-cached (hash-table-count *contacts-cache*)
        :contacts-api-supported (is-contacts-api-supported)
        :biometric-available (is-biometric-available)))

;;; ============================================================================
;;; Section 5: Initialization
;;; ============================================================================

(defun initialize-bot-api-9-advanced ()
  "Initialize advanced Bot API features.

   Returns:
     T on success

   Example:
     (initialize-bot-api-9-advanced)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (log:error "Mini App not connected, cannot initialize advanced features")
      (return-from initialize-bot-api-9-advanced nil))
    (handler-case
        (progn
          ;; Pre-check capabilities
          (is-biometric-available)
          (is-contacts-api-supported)
          (log:info "Advanced Bot API features initialized")
          t)
      (t (e)
        (log:error "Exception in initialize-bot-api-9-advanced: ~A" e)
        nil))))
