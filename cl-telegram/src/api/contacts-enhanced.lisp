;;; contacts-enhanced.lisp --- Contact management enhancements
;;; Part of v0.22.0 - Notification System, Contacts, and Utilities

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Contact Classes
;;; ======================================================================

(defclass contact-vcard ()
  ((version :initarg :version :accessor contact-vcard-version
            :initform "3.0" :documentation "vCard version")
   (formatted-name :initarg :formatted-name :accessor contact-vcard-formatted-name
                   :initform "" :documentation "Formatted name")
   (first-name :initarg :first-name :accessor contact-vcard-first-name
               :initform "" :documentation "First name")
   (last-name :initarg :last-name :accessor contact-vcard-last-name
              :initform "" :documentation "Last name")
   (phone-numbers :initarg :phone-numbers :accessor contact-vcard-phone-numbers
                  :initform nil :documentation "List of phone numbers")
   (emails :initarg :emails :accessor contact-vcard-emails
           :initform nil :documentation "List of email addresses")
   (organization :initarg :organization :accessor contact-vcard-organization
                 :initform "" :documentation "Organization/Company")
   (title :initarg :title :accessor contact-vcard-title
          :initform "" :documentation "Job title")
   (note :initarg :note :accessor contact-vcard-note
         :initform "" :documentation "Additional notes")
   (photo :initarg :photo :accessor contact-vcard-photo
          :initform nil :documentation "Photo data (base64 or URL)")))

(defclass contact-suggestion ()
  ((user-id :initarg :user-id :accessor contact-suggestion-user-id
            :initform 0 :documentation "Suggested user ID")
   (reason :initarg :reason :accessor contact-suggestion-reason
           :initform "" :documentation "Suggestion reason")
   (mutual-contacts :initarg :mutual-contacts
                    :accessor contact-suggestion-mutual-contacts
                    :initform 0 :documentation "Number of mutual contacts")
   (mutual-groups :initarg :mutual-groups
                  :accessor contact-suggestion-mutual-groups
                  :initform nil :documentation "List of mutual group chats")))

(defclass contact-import-result ()
  ((imported :initarg :imported :accessor contact-import-result-imported
             :initform 0 :documentation "Number of contacts imported")
   (updated :initarg :updated :accessor contact-import-result-updated
            :initform 0 :documentation "Number of contacts updated")
   (skipped :initarg :skipped :accessor contact-import-result-skipped
            :initform 0 :documentation "Number of contacts skipped")
   (errors :initarg :errors :accessor contact-import-result-errors
           :initform nil :documentation "List of import errors")))

(defclass blocked-user ()
  ((user-id :initarg :user-id :accessor blocked-user-user-id
            :initform 0 :documentation "Blocked user ID")
   (blocked-at :initarg :blocked-at :accessor blocked-user-blocked-at
               :initform 0 :documentation "Unix timestamp when blocked")
   (reason :initarg :reason :accessor blocked-user-reason
           :initform "" :documentation "Block reason")))

;;; ======================================================================
;;; Global State
;;; ======================================================================

(defvar *contact-cache* (make-hash-table :test 'equal)
  "Cache of contact information")

(defvar *contact-sync-pending* nil
  "Pending contact synchronization flag")

(defvar *blocked-users-cache* nil
  "Cached list of blocked users")

(defvar *contact-suggestions-cache* nil
  "Cached contact suggestions")

;;; ======================================================================
;;; vCard Export/Import
;;; ======================================================================

(defun make-vcard-from-user (user)
  "Create a vCard from a user object.
   USER: User object or user data plist
   Returns contact-vcard object."
  (make-instance 'contact-vcard
                 :formatted-name (gethash "first_name" user "")
                 :first-name (gethash "first_name" user "")
                 :last-name (gethash "last_name" user "")
                 :phone-numbers (list (gethash "phone_number" user ""))
                 :organization (gethash "organization" user "")
                 :title (gethash "title" user "")))

(defun export-contact-vcard (user-id &key file-path)
  "Export a contact to vCard format.
   USER-ID: Telegram user ID
   FILE-PATH: Optional file path to save vCard
   Returns vCard string on success, NIL on failure."
  (handler-case
      (let* ((user (get-user user-id))
             (vcard (make-vcard-from-user user))
             (vcard-lines
              (list
               "BEGIN:VCARD"
               "VERSION:3.0"
               (format nil "FN:~A" (contact-vcard-formatted-name vcard))
               (format nil "N:~A;~A;;;"
                       (contact-vcard-last-name vcard)
                       (contact-vcard-first-name vcard))
               (when (car (contact-vcard-phone-numbers vcard))
                 (format nil "TEL;TYPE=CELL:~A" (car (contact-vcard-phone-numbers vcard))))
               (when (contact-vcard-organization vcard)
                 (format nil "ORG:~A" (contact-vcard-organization vcard)))
               (when (contact-vcard-title vcard)
                 (format nil "TITLE:~A" (contact-vcard-title vcard)))
               "END:VCARD")))
        (let ((vcard-string (format nil "~{~A~^~%~}" (remove nil vcard-lines))))
          (when file-path
            (with-open-file (out file-path :direction :output
                                              :if-exists :supersede)
              (write-string vcard-string out)))
          vcard-string)))
    (error (e)
      (log-message :error "Error exporting vCard: ~A" e)
      nil)))

(defun parse-vcard (vcard-string)
  "Parse a vCard string into a contact-vcard object.
   VCARD-STRING: vCard format string
   Returns contact-vcard object or NIL on parse error."
  (handler-case
      (let* ((lines (uiop:split-string vcard-string :separator '(#\Newline #\Return)))
             (vcard (make-instance 'contact-vcard)))
        (dolist (line lines)
          (let ((line (string-trim '(#\Space #\Tab) line)))
            (cond
              ((string-prefix-p "FN:" line)
               (setf (contact-vcard-formatted-name vcard) (subseq line 3)))
              ((string-prefix-p "N:" line)
               (let* ((name-parts (uiop:split-string (subseq line 2) :separator '(#\;)))
                      (last (car name-parts))
                      (first (cadr name-parts)))
                 (when last (setf (contact-vcard-last-name vcard) last))
                 (when first (setf (contact-vcard-first-name vcard) first))))
              ((string-prefix-p "TEL:" line)
               (push (subseq line 4) (contact-vcard-phone-numbers vcard)))
              ((string-prefix-p "EMAIL:" line)
               (push (subseq line 6) (contact-vcard-emails vcard)))
              ((string-prefix-p "ORG:" line)
               (setf (contact-vcard-organization vcard) (subseq line 4)))
              ((string-prefix-p "TITLE:" line)
               (setf (contact-vcard-title vcard) (subseq line 6)))
              ((string-prefix-p "NOTE:" line)
               (setf (contact-vcard-note vcard) (subseq line 5))))))
        vcard))
    (error (e)
      (log-message :error "Error parsing vCard: ~A" e)
      nil)))

(defun import-contact-vcard (vcard-string &key add-to-contacts)
  "Import a contact from vCard format.
   VCARD-STRING: vCard format string
   ADD-TO-CONTACTS: Add to Telegram contacts if T
   Returns contact-vcard object and optionally adds to contacts."
  (let ((vcard (parse-vcard vcard-string)))
    (when vcard
      (when add-to-contacts
        (import-contacts (list (cons (car (contact-vcard-phone-numbers vcard))
                                     (contact-vcard-formatted-name vcard)))))
      vcard)))

(defun export-all-contacts (&key file-path)
  "Export all contacts to vCard format (multi-vCard file).
   FILE-PATH: Path to save exported contacts
   Returns number of contacts exported."
  (handler-case
      (let ((contacts (get-contacts))
            (vcard-strings nil))
        (dolist (contact contacts)
          (let ((user (get-user (gethash "user_id" contact))))
            (when user
              (push (export-contact-vcard (gethash "user_id" contact)) vcard-strings))))
        (when file-path
          (with-open-file (out file-path :direction :output
                                            :if-exists :supersede)
            (format out "~{~A~%~%~}" vcard-strings)))
        (length vcard-strings)))
    (error (e)
      (log-message :error "Error exporting all contacts: ~A" e)
      0)))

;;; ======================================================================
;;; Contact Import/Export
;;; ======================================================================

(defun import-contacts (contacts-list)
  "Import contacts from a list of (phone . name) cons cells.
   CONTACTS-LIST: List of (phone-number . contact-name) cons cells
   Returns contact-import-result object."
  (handler-case
      (let* ((connection (get-current-connection))
             (contacts-json (json:encode-to-string
                             (loop for (phone . name) in contacts-list
                                   collect `(("phone_number" . ,phone)
                                             ("first_name" . ,name))))))
        (let ((result (make-api-call connection "importContacts"
                                     `(("contacts" . ,contacts-json)))))
          (if result
              (make-instance 'contact-import-result
                             :imported (length (gethash "imported" result nil))
                             :updated (length (gethash "updated" result nil)))
              (make-instance 'contact-import-result :skipped (length contacts-list)))))
    (error (e)
      (log-message :error "Error importing contacts: ~A" e)
      (make-instance 'contact-import-result :errors (list (princ-to-string e))))))

(defun delete-contacts (user-ids)
  "Delete contacts from the contact list.
   USER-IDS: List of user IDs to delete
   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_ids" . ,(json:encode-to-string user-ids)))))
        (let ((result (make-api-call connection "deleteContacts" params)))
          (if result
              (progn
                (log-message :info "~A contacts deleted" (length user-ids))
                ;; Clear cache
                (dolist (id user-ids)
                  (remhash (format nil "~A" id) *contact-cache*))
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting contacts: ~A" e)
      nil)))

(defun get-contacts-status (&key force-refresh)
  "Get contact list status information.
   FORCE-REFRESH: Force server refresh if T
   Returns plist with contact status information."
  (handler-case
      (let* ((connection (get-current-connection))
             (result (make-api-call connection "getContactsStatus" nil)))
        (if result
            `(:contact-count ,(gethash "contact_count" result 0)
              :sync-pending ,(gethash "sync_pending" result nil)
              :last-sync ,(gethash "last_sync" result 0))
            `(:contact-count 0 :sync-pending nil :last-sync 0)))
    (error (e)
      (log-message :error "Error getting contacts status: ~A" e)
      `(:contact-count 0 :sync-pending nil :last-sync 0))))

;;; ======================================================================
;;; Contact Synchronization
;;; ======================================================================

(defun sync-contacts (&key contacts-list force-upload)
  "Synchronize contacts with Telegram server.
   CONTACTS-LIST: Optional list of (phone . name) to sync
   FORCE-UPLOAD: Force upload even if server has newer data
   Returns contact-import-result object."
  (handler-case
      (progn
        (setq *contact-sync-pending* t)
        (let ((contacts (or contacts-list
                            (get-contacts))))
          (let ((result (import-contacts
                         (loop for contact in contacts
                               collect (cons (gethash "phone_number" contact "")
                                             (gethash "first_name" contact ""))))))
            (setq *contact-sync-pending* nil)
            (log-message :info "Contact sync completed: ~A imported, ~A updated"
                         (contact-import-result-imported result)
                         (contact-import-result-updated result))
            result)))
    (error (e)
      (setq *contact-sync-pending* nil)
      (log-message :error "Error syncing contacts: ~A" e)
      (make-instance 'contact-import-result :errors (list (princ-to-string e))))))

(defun get-contact-sync-status ()
  "Get current contact synchronization status.
   Returns plist with sync status."
  `(:sync-pending ,*contact-sync-pending*
    :cache-size ,(hash-table-count *contact-cache*)
    :last-sync ,(gethash "last_sync" *contact-cache* 0)))

;;; ======================================================================
;;; Contact Suggestions
;;; ======================================================================

(defun get-contact-suggestions (&key limit)
  "Get contact suggestions from Telegram.
   LIMIT: Maximum number of suggestions to return
   Returns list of contact-suggestion objects."
  (handler-case
      (let* ((connection (get-current-connection))
             (result (make-api-call connection "getContactSuggestions" nil)))
        (if result
            (loop for sugg-data across (gethash "suggestions" result)
                  for i from 0
                  when (or (null limit) (< i limit))
                  collect (make-instance 'contact-suggestion
                                         :user-id (gethash "user_id" sugg-data 0)
                                         :reason (gethash "reason" sugg-data "")
                                         :mutual-contacts (gethash "mutual_contacts" sugg-data 0)
                                         :mutual-groups (gethash "mutual_groups" sugg-data nil)))
            nil))
    (error (e)
      (log-message :error "Error getting contact suggestions: ~A" e)
      nil)))

(defun dismiss-contact-suggestion (user-id)
  "Dismiss a contact suggestion.
   USER-ID: User ID of suggestion to dismiss
   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_id" . ,user-id))))
        (let ((result (make-api-call connection "dismissContactSuggestion" params)))
          (if result
              (progn
                (log-message :info "Suggestion dismissed for user ~A" user-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error dismissing suggestion: ~A" e)
      nil)))

;;; ======================================================================
;;; Blocked Users Management
;;; ======================================================================

(defun get-blocked-users ()
  "Get list of blocked users.
   Returns list of blocked-user objects."
  (handler-case
      (let* ((connection (get-current-connection))
             (result (make-api-call connection "getBlockedUsers" nil)))
        (if result
            (loop for user-data across (gethash "users" result)
                  collect (make-instance 'blocked-user
                                         :user-id (gethash "user_id" user-data 0)
                                         :blocked-at (gethash "blocked_at" user-data 0)
                                         :reason (gethash "reason" user-data "")))
            nil))
    (error (e)
      (log-message :error "Error getting blocked users: ~A" e)
      nil)))

(defun block-user (user-id &key reason duration)
  "Block a user.
   USER-ID: User ID to block
   REASON: Optional block reason
   DURATION: Optional block duration in seconds (NIL = permanent)
   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_id" . ,user-id))))
        (when reason
          (push (cons "reason" reason) params))
        (when duration
          (push (cons "duration" duration) params))
        (let ((result (make-api-call connection "blockUser" params)))
          (if result
              (progn
                (log-message :info "User ~A blocked" user-id)
                ;; Add to cache
                (let ((blocked (make-instance 'blocked-user
                                              :user-id user-id
                                              :blocked-at (get-universal-time)
                                              :reason (or reason ""))))
                  (push blocked *blocked-users-cache*))
                t)
              nil)))
    (error (e)
      (log-message :error "Error blocking user: ~A" e)
      nil)))

(defun unblock-user (user-id)
  "Unblock a user.
   USER-ID: User ID to unblock
   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_id" . ,user-id))))
        (let ((result (make-api-call connection "unblockUser" params)))
          (if result
              (progn
                (log-message :info "User ~A unblocked" user-id)
                ;; Remove from cache
                (setf *blocked-users-cache*
                      (remove-if (lambda (b) (= (blocked-user-user-id b) user-id))
                                 *blocked-users-cache*))
                t)
              nil)))
    (error (e)
      (log-message :error "Error unblocking user: ~A" e)
      nil)))

(defun user-blocked-p (user-id)
  "Check if a user is blocked.
   USER-ID: User ID to check
   Returns T if blocked, NIL otherwise."
  (let ((blocked (find user-id *blocked-users-cache*
                       :key #'blocked-user-user-id)))
    (not (null blocked))))

;;; ======================================================================
;;; Contact Sharing
;;; ======================================================================

(defun share-contact (user-id chat-id &key message)
  "Share a contact in a chat.
   USER-ID: User ID of contact to share
   CHAT-ID: Target chat ID
   MESSAGE: Optional message to include
   Returns sent Message object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("user_id" . ,user-id)
                       ("chat_id" . ,chat-id))))
        (when message
          (push (cons "message" message) params))
        (let ((result (make-api-call connection "shareContact" params)))
          (if result
              (progn
                (log-message :info "Contact shared in chat ~A" chat-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error sharing contact: ~A" e)
      nil)))

(defun request-contact (chat-id &key text)
  "Request a contact from a user in a chat.
   CHAT-ID: Target chat ID
   TEXT: Optional request message text
   Returns sent Message object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("request_contact" . "true"))))
        (when text
          (push (cons "text" text) params))
        (let ((result (make-api-call connection "sendMessage" params)))
          (if result
              (progn
                (log-message :info "Contact requested in chat ~A" chat-id)
                result)
              nil)))
    (error (e)
      (log-message :error "Error requesting contact: ~A" e)
      nil)))

;;; ======================================================================
;;; Nearby Contacts (Location-based)
;;; ======================================================================

(defun get-nearby-users (&key latitude longitude distance)
  "Get nearby users based on location.
   LATITUDE: Current latitude
   LONGITUDE: Current longitude
   DISTANCE: Search radius in meters
   Returns list of user objects."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("latitude" . ,latitude)
                       ("longitude" . ,longitude))))
        (when distance
          (push (cons "distance" distance) params))
        (let ((result (make-api-call connection "getNearbyUsers" params)))
          (if result
              (gethash "users" result nil)
              nil)))
    (error (e)
      (log-message :error "Error getting nearby users: ~A" e)
      nil)))

(defun toggle-nearby-users (enabled-p)
  "Toggle visibility to nearby users.
   ENABLED-P: T to show, NIL to hide
   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("enabled" . ,(if enabled-p "true" "false")))))
        (let ((result (make-api-call connection "toggleNearbyUsers" params)))
          (if result
              (progn
                (log-message :info "Nearby users ~A" (if enabled-p "enabled" "disabled"))
                t)
              nil)))
    (error (e)
      (log-message :error "Error toggling nearby users: ~A" e)
      nil)))
