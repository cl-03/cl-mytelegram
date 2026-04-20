;;; chat-folders.lisp --- Chat folder management and organization
;;; Part of v0.21.0 - User Experience Enhancements

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Chat Folder Classes
;;; ======================================================================

(defclass chat-folder ()
  ((id :initarg :id :accessor chat-folder-id
       :initform 0 :documentation "Unique folder identifier")
   (title :initarg :title :accessor chat-folder-title
          :initform "" :documentation "Folder name, 1-12 chars")
   (icon :initarg :icon :accessor chat-folder-icon
         :initform nil :documentation "Icon name or emoji")
   (chat-list :initarg :chat-list :accessor chat-folder-chat-list
              :initform nil :documentation "List of chat IDs in folder")
   (filters :initarg :filters :accessor chat-folder-filters
             :initform nil :documentation "Filter settings")
   (is-shared :initarg :is-shared :accessor chat-folder-is-shared
              :initform nil :documentation "True if folder is shared")))

(defclass chat-folder-filter ()
  ((include-muted :initarg :include-muted :accessor filter-include-muted
                  :initform nil :documentation "Include muted chats")
   (include-read :initarg :include-read :accessor filter-include-read
                 :initform nil :documentation "Include read chats")
   (include-archived :initarg :include-archived :accessor filter-include-archived
                     :initform nil :documentation "Include archived chats")
   (include-channels :initarg :include-channels :accessor filter-include-channels
                     :initform nil :documentation "Include channel chats")
   (include-groups :initarg :include-groups :accessor filter-include-groups
                   :initform nil :documentation "Include group chats")
   (include-bots :initarg :include-bots :accessor filter-include-bots
                 :initform nil :documentation "Include bot chats")
   (include-non-bots :initarg :include-non-bots :accessor filter-include-non-bots
                     :initform nil :documentation "Include non-bot chats")
   (include-contacts :initarg :include-contacts :accessor filter-include-contacts
                     :initform nil :documentation "Include contact chats")
   (include-non-contacts :initarg :include-non-contacts :accessor filter-include-non-contacts
                         :initform nil :documentation "Include non-contact chats")
   (exclude-chats :initarg :exclude-chats :accessor filter-exclude-chats
                  :initform nil :documentation "List of chat IDs to exclude")
   (include-chats :initarg :include-chats :accessor filter-include-chats
                  :initform nil :documentation "List of chat IDs to include")))

(defclass folder-chat-filter ()
  ((type :initarg :type :accessor folder-filter-type
         :initform :all :documentation "Filter type: :all, :contacts, :non-contacts, etc.")
   (chat-ids :initarg :chat-ids :accessor folder-filter-chat-ids
             :initform nil :documentation "Specific chat IDs")))

(defclass archive-info ()
  ((total-count :initarg :total-count :accessor archive-total-count
                :initform 0 :documentation "Total archived chats")
   (unread-count :initarg :unread-count :accessor archive-unread-count
                 :initform 0 :documentation "Unread archived chats")
   (chats :initarg :chats :accessor archive-chats
          :initform nil :documentation "List of archived chat objects")))

;;; ======================================================================
;;; Chat Folder Management
;;; ======================================================================

(defun make-chat-folder (title &key icon chat-list filters is-shared)
  "Create a new chat folder.

   TITLE: Folder name, 1-12 characters
   ICON: Optional icon name or emoji
   CHAT-LIST: Optional list of chat IDs to include
   FILTERS: Optional chat-folder-filter object
   IS-SHARED: Optional shared folder flag

   Returns chat-folder object."
  (make-instance 'chat-folder
                 :title title
                 :icon icon
                 :chat-list chat-list
                 :filters filters
                 :is-shared is-shared))

(defun make-chat-folder-filter (&key include-muted include-read include-archived
                                      include-channels include-groups include-bots
                                      include-non-bots include-contacts include-non-contacts
                                      exclude-chats include-chats)
  "Create a chat folder filter with specified options.

   INCLUDE-MUTED: Include muted chats if T
   INCLUDE-READ: Include read chats if T
   INCLUDE-ARCHIVED: Include archived chats if T
   INCLUDE-CHANNELS: Include channel chats if T
   INCLUDE-GROUPS: Include group chats if T
   INCLUDE-BOTS: Include bot chats if T
   INCLUDE-NON-BOTS: Include non-bot chats if T
   INCLUDE-CONTACTS: Include contact chats if T
   INCLUDE-NON-CONTACTS: Include non-contact chats if T
   EXCLUDE-CHATS: List of chat IDs to exclude
   INCLUDE-CHATS: List of chat IDs to include

   Returns chat-folder-filter object."
  (make-instance 'chat-folder-filter
                 :include-muted include-muted
                 :include-read include-read
                 :include-archived include-archived
                 :include-channels include-channels
                 :include-groups include-groups
                 :include-bots include-bots
                 :include-non-bots include-non-bots
                 :include-contacts include-contacts
                 :include-non-contacts include-non-contacts
                 :exclude-chats exclude-chats
                 :include-chats include-chats))

(defun create-chat-folder (folder &key account-id)
  "Create a new chat folder on the server.

   FOLDER: chat-folder object to create
   ACCOUNT-ID: Optional account identifier for multi-account support

   Returns created folder ID on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("title" . ,(chat-folder-title folder))))
             (filter (chat-folder-filters folder)))
        (when (chat-folder-icon folder)
          (push (cons "icon" (chat-folder-icon folder)) params))
        (when filter
          ;; Add filter settings
          (when (filter-include-channels filter)
            (push (cons "include_channels" "true") params))
          (when (filter-include-groups filter)
            (push (cons "include_groups" "true") params))
          (when (filter-include-bots filter)
            (push (cons "include_bots" "true") params))
          (when (filter-include-contacts filter)
            (push (cons "include_contacts" "true") params))
          (when (filter-exclude-chats filter)
            (push (cons "exclude_chats"
                      (json:encode-to-string (filter-exclude-chats filter))) params))
          (when (filter-include-chats filter)
            (push (cons "include_chats"
                      (json:encode-to-string (filter-include-chats filter))) params))))

        (let ((result (make-api-call connection "addChatFolder" params)))
          (if result
              (progn
                (log-message :info "Chat folder '~A' created" (chat-folder-title folder))
                (gethash "id" result 0))
              nil)))
    (error (e)
      (log-message :error "Error creating chat folder: ~A" (princ-to-string e))
      nil)))

(defun edit-chat-folder (folder-id folder &key account-id)
  "Edit an existing chat folder.

   FOLDER-ID: ID of folder to edit
   FOLDER: chat-folder object with updated values
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_id" . ,folder-id)
                       ("title" . ,(chat-folder-title folder)))))
        (when (chat-folder-icon folder)
          (push (cons "icon" (chat-folder-icon folder)) params))

        (let ((result (make-api-call connection "editChatFolder" params)))
          (if result
              (progn
                (log-message :info "Chat folder ~A edited" folder-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error editing chat folder: ~A" (princ-to-string e))
      nil)))

(defun delete-chat-folder (folder-id &key account-id)
  "Delete a chat folder.

   FOLDER-ID: ID of folder to delete
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_id" . ,folder-id))))
        (let ((result (make-api-call connection "deleteChatFolder" params)))
          (if result
              (progn
                (log-message :info "Chat folder ~A deleted" folder-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting chat folder: ~A" (princ-to-string e))
      nil)))

(defun get-chat-folders (&key account-id)
  "Get list of all chat folders.

   ACCOUNT-ID: Optional account identifier

   Returns list of chat-folder objects on success, NIL on failure."
  (handler-case
      (let ((connection (get-current-connection)))
        (let ((result (make-api-call connection "getChatFolders" nil)))
          (if result
              (loop for folder-data across (gethash "folders" result)
                    collect (parse-chat-folder folder-data))
              nil)))
    (error (e)
      (log-message :error "Error getting chat folders: ~A" (princ-to-string e))
      nil)))

(defun parse-chat-folder (data)
  "Parse chat folder from API response."
  (make-instance 'chat-folder
                 :id (gethash "id" data 0)
                 :title (gethash "title" data "")
                 :icon (gethash "icon" data nil)
                 :chat-list (gethash "chat_list" data nil)
                 :is-shared (gethash "is_shared" data nil)))

(defun get-chat-folder (folder-id &key account-id)
  "Get a specific chat folder by ID.

   FOLDER-ID: ID of folder to get
   ACCOUNT-ID: Optional account identifier

   Returns chat-folder object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_id" . ,folder-id))))
        (let ((result (make-api-call connection "getChatFolder" params)))
          (if result
              (parse-chat-folder result)
              nil)))
    (error (e)
      (log-message :error "Error getting chat folder: ~A" (princ-to-string e))
      nil)))

(defun add-chat-to-folder (folder-id chat-id &key account-id)
  "Add a chat to a folder.

   FOLDER-ID: ID of folder
   CHAT-ID: ID of chat to add
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_id" . ,folder-id)
                       ("chat_id" . ,chat-id))))
        (let ((result (make-api-call connection "addChatToFolder" params)))
          (if result
              (progn
                (log-message :info "Chat ~A added to folder ~A" chat-id folder-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error adding chat to folder: ~A" (princ-to-string e))
      nil)))

(defun remove-chat-from-folder (folder-id chat-id &key account-id)
  "Remove a chat from a folder.

   FOLDER-ID: ID of folder
   CHAT-ID: ID of chat to remove
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_id" . ,folder-id)
                       ("chat_id" . ,chat-id))))
        (let ((result (make-api-call connection "removeChatFromFolder" params)))
          (if result
              (progn
                (log-message :info "Chat ~A removed from folder ~A" chat-id folder-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error removing chat from folder: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Archive Management
;;; ======================================================================

(defun archive-chat (chat-id &key account-id)
  "Archive a chat.

   CHAT-ID: ID of chat to archive
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id))))
        (let ((result (make-api-call connection "archiveChat" params)))
          (if result
              (progn
                (log-message :info "Chat ~A archived" chat-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error archiving chat: ~A" (princ-to-string e))
      nil)))

(defun unarchive-chat (chat-id &key account-id)
  "Unarchive a chat.

   CHAT-ID: ID of chat to unarchive
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id))))
        (let ((result (make-api-call connection "unarchiveChat" params)))
          (if result
              (progn
                (log-message :info "Chat ~A unarchived" chat-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error unarchiving chat: ~A" (princ-to-string e))
      nil)))

(defun get-archived-chats (&key offset limit account-id)
  "Get list of archived chats.

   OFFSET: Offset for pagination
   LIMIT: Maximum number of chats to return
   ACCOUNT-ID: Optional account identifier

   Returns archive-info object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params nil))
        (when offset
          (push (cons "offset" offset) params))
        (when limit
          (push (cons "limit" limit) params))

        (let ((result (make-api-call connection "getArchivedChats" params)))
          (if result
              (make-instance 'archive-info
                             :total-count (gethash "total_count" result 0)
                             :unread-count (gethash "unread_count" result 0)
                             :chats (gethash "chats" result nil))
              nil)))
    (error (e)
      (log-message :error "Error getting archived chats: ~A" (princ-to-string e))
      nil)))

(defun get-archive-info (&key account-id)
  "Get archive information including counts.

   ACCOUNT-ID: Optional account identifier

   Returns archive-info object on success, NIL on failure."
  (handler-case
      (let ((connection (get-current-connection)))
        (let ((result (make-api-call connection "getArchiveInfo" nil)))
          (if result
              (make-instance 'archive-info
                             :total-count (gethash "total_count" result 0)
                             :unread-count (gethash "unread_count" result 0))
              nil)))
    (error (e)
      (log-message :error "Error getting archive info: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Chat List Management
;;; ======================================================================

(defun get-chat-list (folder-id &key offset limit account-id)
  "Get list of chats in a folder.

   FOLDER-ID: ID of folder (0 for main list, 1 for archive)
   OFFSET: Offset for pagination
   LIMIT: Maximum number of chats to return
   ACCOUNT-ID: Optional account identifier

   Returns list of chat objects on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_id" . ,folder-id))))
        (when offset
          (push (cons "offset" offset) params))
        (when limit
          (push (cons "limit" limit) params))

        (let ((result (make-api-call connection "getChatList" params)))
          (if result
              (gethash "chats" result nil)
              nil)))
    (error (e)
      (log-message :error "Error getting chat list: ~A" (princ-to-string e))
      nil)))

(defun reorder-chat-folders (folder-ids &key account-id)
  "Reorder chat folders.

   FOLDER-IDS: List of folder IDs in new order
   ACCOUNT-ID: Optional account identifier

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_ids" . ,(json:encode-to-string folder-ids)))))
        (let ((result (make-api-call connection "reorderChatFolders" params)))
          (if result
              (progn
                (log-message :info "Chat folders reordered")
                t)
              nil)))
    (error (e)
      (log-message :error "Error reordering chat folders: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Folder Sharing
;;; ======================================================================

(defun share-chat-folder (folder-id &key account-id)
  "Generate a shareable link for a chat folder.

   FOLDER-ID: ID of folder to share
   ACCOUNT-ID: Optional account identifier

   Returns share URL on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("folder_id" . ,folder-id))))
        (let ((result (make-api-call connection "shareChatFolder" params)))
          (if result
              (progn
                (log-message :info "Folder ~A share link generated" folder-id)
                (gethash "url" result ""))
              nil)))
    (error (e)
      (log-message :error "Error sharing chat folder: ~A" (princ-to-string e))
      nil)))

(defun import-chat-folder (url &key account-id)
  "Import a chat folder from a share link.

   URL: Folder share URL
   ACCOUNT-ID: Optional account identifier

   Returns imported folder ID on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("url" . ,url))))
        (let ((result (make-api-call connection "importChatFolder" params)))
          (if result
              (progn
                (log-message :info "Chat folder imported from ~A" url)
                (gethash "folder_id" result 0))
              nil)))
    (error (e)
      (log-message :error "Error importing chat folder: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Global State
;;; ======================================================================

(defvar *chat-folders-cache* (make-hash-table :test 'equal)
  "Cache of chat folders by folder ID")

(defvar *archive-cache* nil
  "Cached archive info")

(defvar *default-folder-icons*
  '("All" "Unread" "Contacts" "Groups" "Channels" "Bots" "Custom")
  "Default folder icon options")

;;; ======================================================================
;;; v0.32.0 Enhancements: Pinned Chats and Unread Marks
;;; ======================================================================

(defvar *pinned-chats* (make-hash-table :test 'equal)
  "Hash table storing pinned chats by folder")

(defvar *unread-marks* (make-hash-table :test 'equal)
  "Hash table storing unread marks")

(defun pin-chat (chat-id &key (position 0) (folder-id nil))
  "Pin a chat to the top of the chat list.

   CHAT-ID: Chat identifier
   POSITION: Pin position (0 = top)
   FOLDER-ID: Optional folder ID

   Returns T on success."
  (let ((folder-key (or folder-id "default")))
    (let ((pins (gethash folder-key *pinned-chats* nil)))
      (let ((existing (position chat-id pins :key #'car)))
        (when existing
          (setf pins (delete chat-id pins :key #'car))))
      (push (cons chat-id position) pins)
      (setf (gethash folder-key *pinned-chats*) (sort pins #'< :key #'cdr))))
  (log:info "Chat pinned: ~A" chat-id)
  t)

(defun unpin-chat (chat-id &key (folder-id nil))
  "Unpin a chat.

   CHAT-ID: Chat identifier
   FOLDER-ID: Optional folder ID

   Returns T on success."
  (let ((folder-key (or folder-id "default")))
    (let ((pins (gethash folder-key *pinned-chats* nil)))
      (when pins
        (setf pins (delete chat-id pins :key #'car))
        (setf (gethash folder-key *pinned-chats* pins)))))
  (log:info "Chat unpinned: ~A" chat-id)
  t)

(defun get-pinned-chats (&key (folder-id nil))
  "Get all pinned chats.

   FOLDER-ID: Optional folder ID

   Returns list of pinned chat IDs in order."
  (let ((folder-key (or folder-id "default")))
    (let ((pins (gethash folder-key *pinned-chats* nil)))
      (when pins
        (mapcar #'car (sort pins #'< :key #'cdr))))))

(defun get-unread-marks (&key (chat-id nil) (folder-id nil))
  "Get unread marks for chats.

   CHAT-ID: Optional chat ID filter
   FOLDER-ID: Optional folder ID filter

   Returns plist with unread information."
  (cond
    (chat-id
     (gethash chat-id *unread-marks* nil))
    (t
     (let ((result nil))
       (maphash (lambda (k v)
                  (push (cons k v) result))
                *unread-marks*)
       result))))

(defun set-unread-mark (chat-id unread-count &key (last-message-id nil))
  "Set unread mark for a chat.

   CHAT-ID: Chat identifier
   UNREAD-COUNT: Number of unread messages
   LAST-MESSAGE-ID: Optional last message ID

   Returns T on success."
  (setf (gethash chat-id *unread-marks*)
        (list :unread-count unread-count
              :last-message-id last-message-id
              :updated-at (get-universal-time)))
  (log:info "Unread mark set for ~A: ~D messages" chat-id unread-count)
  t)

(defun clear-unread-mark (chat-id)
  "Clear unread mark for a chat.

   CHAT-ID: Chat identifier

   Returns T on success."
  (remhash chat-id *unread-marks*)
  (log:info "Unread mark cleared for ~A" chat-id)
  t)

(defun mark-as-read (chat-id &key (max-id nil))
  "Mark all messages in a chat as read.

   CHAT-ID: Chat identifier
   MAX-ID: Optional maximum message ID to mark as read

   Returns T on success."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id))))
        (when max-id
          (push (cons "max_id" max-id) params))
        (let ((result (make-api-call connection "markAsRead" params)))
          (when result
            (clear-unread-mark chat-id)
            (log:info "Chat marked as read: ~A" chat-id)
            t)))
    (error (e)
      (log:info "Mark as read failed: ~A" e)
      nil)))

(defun mark-all-as-read ()
  "Mark all chats as read.

   Returns T on success."
  (let ((count 0))
    (maphash (lambda (k v)
               (declare (ignore v))
               (when (mark-as-read k)
                 (incf count)))
             *unread-marks*)
    (log:info "~D chats marked as read" count)
    t))

(defun get-chat-folder-stats (&key (folder-id nil))
  "Get statistics for chat folders.

   FOLDER-ID: Optional folder ID filter

   Returns plist with statistics."
  (let ((total-folders 0)
        (total-chats 0)
        (total-pinned 0)
        (total-unread 0))
    (maphash (lambda (k v)
               (declare (ignore k))
               (incf total-folders)
               (incf total-chats (length (chat-folder-chat-list v))))
             *chat-folders-cache*)
    (maphash (lambda (k v)
               (declare (ignore k))
               (incf total-pinned (length v)))
             *pinned-chats*)
    (maphash (lambda (k v)
               (declare (ignore k))
               (incf total-unread (or (getf v :unread-count 0))))
             *unread-marks*)
    (list :total-folders total-folders
          :total-chats total-chats
          :total-pinned total-pinned
          :total-unread total-unread)))
