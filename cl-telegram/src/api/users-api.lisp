;;; users-api.lisp --- Users API implementation

(in-package #:cl-telegram/api)

(defvar *user-cache* (make-hash-table :test 'eql)
  "Cache for user objects")

;;; ### Current User

(defun get-me ()
  "Get information about the current user.

   Returns: user object on success, error on failure"
  (unless (authorized-p)
    (return-from get-me
      (values nil :not-authorized "User not authenticated")))

  ;; Check cache first
  (let ((cached (gethash *auth-user-id* *user-cache*)))
    (when cached
      (return-from get-me (values cached nil))))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-me
        (values nil :no-connection "No active connection")))

    ;; Create getUsers TL object with current user ID
    (let ((request (make-tl-object
                    'users.getUsers
                    :id (list (make-tl-object 'inputUserSelf)))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :users)
              (let ((users (getf result :users)))
                (when (and users (> (length users) 0))
                  (let ((me (first users)))
                    ;; Cache the result
                    (setf *auth-user-id* (getf me :id))
                    (setf (gethash *auth-user-id* *user-cache*) me)
                    (values me nil))))
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Get me timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Get Users

(defun get-users (user-ids)
  "Get information about multiple users.

   USER-IDS: List of user IDs to retrieve

   Returns: list of user objects on success, error on failure"
  (unless (authorized-p)
    (return-from get-users
      (values nil :not-authorized "User not authenticated")))

  (unless (and user-ids (listp user-ids) (> (length user-ids) 0))
    (return-from get-users
      (values nil :invalid-argument "User IDs must be a non-empty list")))

  ;; Check cache for known users
  (let ((cached-users nil)
        (uncached-ids nil))
    (dolist (uid user-ids)
      (let ((cached (gethash uid *user-cache*)))
        (if cached
            (push cached cached-users)
            (push uid uncached-ids))))

    ;; If all cached, return immediately
    (when (null uncached-ids)
      (return-from get-users (values (nreverse cached-users) nil))))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-users
        (values nil :no-connection "No active connection")))

    ;; Build input user list
    (let ((input-users (mapcar (lambda (uid)
                                 (make-tl-object 'inputUser
                                                 :user-id uid
                                                 :access-hash 0))
                               user-ids)))
      (let ((request (make-tl-object
                      'users.getUsers
                      :id input-users)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:ok (result)
            (if (eq (getf result :@type) :users)
                (let ((users (getf result :users)))
                  ;; Cache the results
                  (dolist (user users)
                    (let ((id (getf user :id)))
                      (when id
                        (setf (gethash id *user-cache*) user))))
                  (values users nil))
                (values nil :unexpected-response result)))
          (:timeout ()
            (values nil :timeout "Get users timeout"))
          (:error (err)
            (values nil :rpc-error err)))))))

(defun get-user (user-id)
  "Get information about a single user.

   USER-ID: The unique identifier of the user

   Returns: user object on success, error on failure"
  (unless (authorized-p)
    (return-from get-user
      (values nil :not-authorized "User not authenticated")))

  ;; Check cache first
  (let ((cached (gethash user-id *user-cache*)))
    (when cached
      (return-from get-user (values cached nil))))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-user
        (values nil :no-connection "No active connection")))

    ;; Create getUsers TL object
    (let ((request (make-tl-object
                    'users.getUsers
                    :id (list (make-tl-object 'inputUser
                                              :user-id user-id
                                              :access-hash 0)))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :users)
              (let ((users (getf result :users)))
                (when (and users (> (length users) 0))
                  (let ((user (first users)))
                    ;; Cache the result
                    (setf (gethash user-id *user-cache*) user)
                    (values user nil))))
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Get user timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### User Search

(defun search-users (query &key (limit 50))
  "Search for users by name.

   QUERY: Search query string
   LIMIT: Maximum number of results (1-100)

   Returns: list of matching users"
  (unless (authorized-p)
    (return-from search-users
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max limit 1) 100))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-users
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'contacts.search
                    :q query
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :contactsFound)
              (values (getf result :results) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### User Profile

(defun get-user-profile-photos (user-id &key (offset 0) (limit 100))
  "Get user profile photos.

   USER-ID: The unique identifier of the user
   OFFSET: Number of photos to skip
   LIMIT: Maximum number of photos (1-100)

   Returns: list of profile photos"
  (unless (authorized-p)
    (return-from get-user-profile-photos
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-user-profile-photos
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'photos.getUserPhotos
                    :user-id (make-tl-object 'inputUser
                                             :user-id user-id
                                             :access-hash 0)
                    :offset offset
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :photos)
              (values (getf result :photos) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-user-full-info (user-id)
  "Get full information about a user.

   USER-ID: The unique identifier of the user

   Returns: user full info object"
  (unless (authorized-p)
    (return-from get-user-full-info
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-user-full-info
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'users.getFullUser
                    :id (make-tl-object 'inputUser
                                        :user-id user-id
                                        :access-hash 0))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :userFull)
              (values result nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### User Status

(defun get-user-status (user-id)
  "Get user online status.

   USER-ID: The unique identifier of the user

   Returns: user status object"
  (unless (authorized-p)
    (return-from get-user-status
      (values nil :not-authorized "User not authenticated")))

  ;; Try to get from cached user data first
  (let ((cached (gethash user-id *user-cache*)))
    (when cached
      (let ((status (getf cached :status)))
        (when status
          (return-from get-user-status (values status nil))))))

  ;; For fresh status, we'd need to use getUserStatus
  ;; This is a simplified version
  (let ((user (get-user user-id)))
    (if user
        (values (getf user :status) nil)
        (values nil :user-not-found "User not found"))))

;;; ### Contact Management

(defvar *contacts-cache* nil
  "Cached contacts list")

(defun get-contacts (&key (hash 0))
  "Get contact list.

   HASH: Contact list hash for caching

   Returns: list of contacts"
  (unless (authorized-p)
    (return-from get-contacts
      (values nil :not-authorized "User not authenticated")))

  ;; Return cached contacts if available
  (when (and *contacts-cache* (zerop hash))
    (return-from get-contacts (values *contacts-cache* nil)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-contacts
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'contacts.getContacts
                    :hash hash)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :contacts)
              (progn
                (setf *contacts-cache* (getf result :contacts))
                (values *contacts-cache* nil))
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun add-contact (user-id &key (first-name "") (last-name "") (phone-number ""))
  "Add a user to contacts.

   USER-ID: The unique identifier of the user
   FIRST-NAME: User's first name
   LAST-NAME: User's last name
   PHONE-NUMBER: User's phone number

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from add-contact
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from add-contact
        (values nil :no-connection "No active connection")))

    (let ((contact (make-tl-object 'inputPhoneContact
                                   :client-id 0
                                   :phone-number phone-number
                                   :first-name first-name
                                   :last-name last-name)))
      (let ((request (make-tl-object
                      'contacts.addContact
                      :contact contact
                      :share nil)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:ok (result)
            (if (eq (getf result :@type) :contactsImported)
                (values t nil)
                (values nil :unexpected-response result)))
          (:error (err)
            (values nil :rpc-error err)))))))

(defun delete-contacts (user-ids)
  "Delete users from contacts.

   USER-IDS: List of user IDs to delete

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from delete-contacts
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from delete-contacts
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'contacts.deleteContacts
                    :id (mapcar (lambda (uid)
                                  (make-tl-object 'inputUser
                                                  :user-id uid
                                                  :access-hash 0))
                                user-ids))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun block-user (user-id)
  "Block a user.

   USER-ID: The unique identifier of the user

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from block-user
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from block-user
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'contacts.block
                    :id (make-tl-object 'inputUser
                                        :user-id user-id
                                        :access-hash 0))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun unblock-user (user-id)
  "Unblock a user.

   USER-ID: The unique identifier of the user

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from unblock-user
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from unblock-user
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'contacts.unblock
                    :id (make-tl-object 'inputUser
                                        :user-id user-id
                                        :access-hash 0))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-blocked-users (&key (offset 0) (limit 100))
  "Get list of blocked users.

   OFFSET: Number of users to skip
   LIMIT: Maximum number of users to retrieve (1-100)

   Returns: list of blocked users"
  (unless (authorized-p)
    (return-from get-blocked-users
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-blocked-users
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'contacts.getBlocked
                    :offset offset
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :contactsBlocked)
              (values (getf result :blocked) nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### User Settings

(defun set-user-profile-photo (photo-file)
  "Set user profile photo.

   PHOTO-FILE: Input file containing the photo

   Returns: updated user object on success, error on failure"
  (unless (authorized-p)
    (return-from set-user-profile-photo
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from set-user-profile-photo
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'photos.uploadProfilePhoto
                    :file (make-tl-object 'inputFile
                                          :id (random (expt 2 63))
                                          :name "profile.jpg"
                                          :data photo-file))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :photo)
              (values result nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun delete-user-profile-photo (photo-id)
  "Delete a profile photo.

   PHOTO-ID: ID of the photo to delete

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from delete-user-profile-photo
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (let ((request (make-tl-object
                    'photos.deletePhotos
                    :id (list photo-id))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :ok)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun set-bio (bio-text)
  "Set user bio.

   BIO-TEXT: New bio text (0-70 characters)

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from set-bio
      (values nil :not-authorized "User not authenticated")))

  (when (> (length bio-text) 70)
    (return-from set-bio
      (values nil :invalid-bio "Bio must be 0-70 characters")))

  (let ((connection (ensure-auth-connection)))
    (let ((request (make-tl-object
                    'account.updateProfile
                    :bio bio-text)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :userProfile)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### TDLib Compatibility

(defun |getUsers| (user-ids)
  "TDLib compatible getUsers."
  (get-users user-ids))

(defun |getUser| (user-id)
  "TDLib compatible getUser."
  (get-user user-id))

(defun |getMe| ()
  "TDLib compatible getMe."
  (get-me))

(defun |searchUsers| (query &key limit)
  "TDLib compatible searchUsers."
  (search-users query :limit (or limit 50)))

(defun |getContacts| (&key hash)
  "TDLib compatible getContacts."
  (get-contacts :hash (or hash 0)))

(defun |createPrivateChat| (user-id)
  "TDLib compatible createPrivateChat (delegates to chats-api)."
  (create-private-chat user-id))
