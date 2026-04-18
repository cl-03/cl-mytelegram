;;; update-handler.lisp --- Real-time update processor for MTProto client
;;;
;;; Provides a framework for handling real-time updates from Telegram servers.
;;; Handles: new messages, user status changes, chat updates, etc.

(in-package #:cl-telegram/api)

;;; ### Update Handler State

(defclass update-handler ()
  ((connection :initarg :connection :accessor update-connection
               :documentation "MTProto connection instance")
   (handlers :initform (make-hash-table :test 'eq) :accessor update-handlers
             :documentation "Update type -> handler function list")
   (queue :initform (make-array 1000 :adjustable t :fill-pointer 0)
          :accessor update-queue
          :documentation "Pending updates queue")
   (running-p :initform nil :accessor update-running-p
              :documentation "True if update loop is running")
   (thread :initform nil :accessor update-thread
           :documentation "Background update listener thread")
   (processed-count :initform 0 :accessor update-processed-count
                    :documentation "Number of processed updates")
   (last-update-id :initform 0 :accessor update-last-update-id
                   :documentation "Last processed update ID"))
  (:documentation "Telegram update handler instance"))

(defun make-update-handler (connection)
  "Create a new update handler.

   Args:
     connection: MTProto connection instance

   Returns:
     Update handler instance"
  (make-instance 'update-handler :connection connection))

;;; ### Update Registration

(defun register-update-handler (update-type handler)
  "Register a handler for a specific update type.

   Args:
     update-type: Keyword symbol (e.g., :update-new-message)
     handler: Function (update) -> T

   Returns:
     T on success

   Example:
     (register-update-handler :update-new-message
       (lambda (update)
         (let ((msg (getf update :message)))
           (format t \"New message: ~A~%\" (getf msg :text)))))"
  (let ((existing (gethash update-type (update-handlers *update-handler*))))
    (setf (gethash update-type (update-handlers *update-handler*))
          (append (or existing nil) (list handler))))
  t)

(defun unregister-update-handler (update-type handler)
  "Remove a specific handler for an update type.

   Args:
     update-type: Keyword symbol
     handler: Function to remove

   Returns:
     T on success"
  (let ((existing (gethash update-type (update-handlers *update-handler*))))
    (when existing
      (setf (gethash update-type (update-handlers *update-handler*))
            (remove handler existing))))
  t)

(defun clear-update-handlers (update-type)
  "Clear all handlers for an update type.

   Args:
     update-type: Keyword symbol

   Returns:
     T on success"
  (remhash update-type (update-handlers *update-handler*)))

;;; ### Update Processing

(defun dispatch-update (update)
  "Dispatch an update to registered handlers.

   Args:
     update: Update object (plist)

   Returns:
     T if any handler processed it"
  (let* ((update-type (getf update :@type))
         (handlers (gethash update-type (update-handlers *update-handler*))))
    (when handlers
      (dolist (handler handlers)
        (handler-case
            (funcall handler update)
          (error (e)
            (format *error-output* "Update handler error (~A): ~A~%" update-type e))))
      t)))

(defun process-update-object (update)
  "Process a single update object.

   Args:
     update: Update object from MTProto

   Returns:
     T if processed successfully"
  (let ((update-type (getf update :@type)))
    (case update-type
      ;; Message updates
      (:update-new-message
       (handle-new-message update))
      (:update-message-content
       (handle-message-content-update update))
      (:update-message-edited
       (handle-message-edited update))
      (:update-message-send-succeeded
       (handle-message-send-succeeded update))
      (:update-message-content-opened
       (handle-message-content-opened update))
      (:update-message-interaction-info
       (handle-message-interaction-update update))
      (:update-message-live-location-viewed
       (handle-live-location-viewed update))
      (:update-message-timer
       (handle-message-timer update))

      ;; Chat updates
      (:update-new-chat
       (handle-new-chat update))
      (:update-chat-title
       (handle-chat-title-update update))
      (:update-chat-photo
       (handle-chat-photo-update update))
      (:update-chat-permissions
       (handle-chat-permissions-update update))
      (:update-chat-last-message
       (handle-chat-last-message-update update))
      (:update-chat-position
       (handle-chat-position-update update))
      (:update-chat-unread-count
       (handle-chat-unread-count-update update))
      (:update-chat-is-marked-as-unread
       (handle-chat-marked-as-unread-update update))
      (:update-chat-is-pinned
       (handle-chat-pinned-update update))
      (:update-chat-action-bar
       (handle-chat-action-bar-update update))
      (:update-chat-blocked
       (handle-chat-blocked-update update))
      (:update-chat-default-reaction
       (handle-chat-default-reaction-update update))

      ;; User updates
      (:update-user
       (handle-user-update update))
      (:update-user-full-info
       (handle-user-full-info-update update))
      (:update-user-status
       (handle-user-status-update update))
      (:update-user-typing
       (handle-user-typing-update update))

      ;; Notification updates
      (:update-new-callback-query
       (handle-callback-query-update update))
      (:update-new-inline-query
       (handle-inline-query-update update))
      (:update-new-chosen-inline-result
       (handle-chosen-inline-result-update update))
      (:update-new-shipped-inline-query
       (handle-shipped-inline-query-update update))
      (:update-new-pre-checkout-query
       (handle-pre-checkout-query-update update))
      (:update-new-callback-query
       (handle-callback-query-update update))

      ;; Other updates
      (:update-authorization-state
       (handle-authorization-state-update update))
      (:update-connection-state
       (handle-connection-state-update update))
      (:update-new-call
       (handle-new-call-update update))
      (:update-user-privacy-setting-rules
       (handle-user-privacy-rules-update update))
      (:update-unread-message-count
       (handle-unread-message-count-update update))
      (:update-unread-chat-count
       (handle-unread-chat-count-update update))
      (:update-scope-notification-settings
       (handle-scope-notification-settings-update update))
      (:update-notification
       (handle-notification-update update))
      (:update-notification-group
       (handle-notification-group-update update))
      (:update-active-notifications
       (handle-active-notifications-update update))
      (:update-have-pending-notification-requests
       (handle-pending-notification-requests-update update))

      ;; Default dispatch
      (t
       (dispatch-update update)))))

;;; ### Message Update Handlers

(defun handle-new-message (update)
  "Handle new message update.

   Args:
     update: Update object with :message field"
  (let* ((message (getf update :message))
         (chat-id (getf message :chat-id))
         (message-id (getf message :id))
         (from (getf message :from))
         (text (getf message :text)))
    (incf (update-processed-count *update-handler*))
    (setf (update-last-update-id *update-handler*) message-id)
    ;; Dispatch to registered handlers
    (dispatch-update update)
    (format t "[NEW MESSAGE] Chat ~A: ~A~@[ from ~A~]~%"
            chat-id (or text \"[non-text]\") (getf from :first-name))))

(defun handle-message-content-update (update)
  "Handle message content change (edited message, etc.)"
  (let ((message-id (getf update :message-id))
        (new-content (getf update :new-content)))
    (incf (update-processed-count *update-handler*))
    (dispatch-update update)
    (format t \"[MESSAGE EDITED] ID: ~A~%\" message-id)))

(defun handle-message-edited (update)
  "Handle message edited event."
  (let ((message (getf update :message))
        (edit-date (getf update :edit-date)))
    (incf (update-processed-count *update-handler*))
    (dispatch-update update)
    (format t \"[MESSAGE EDITED] ~A at ~A~%\"
            (getf message :id) edit-date)))

(defun handle-message-send-succeeded (update)
  "Handle message send succeeded (temporary -> permanent message ID)."
  (let ((old-id (getf update :old-message-id))
        (new-id (getf update :new-message-id)))
    (dispatch-update update)
    (format t \"[SEND OK] ~A -> ~A~%\" old-id new-id)))

(defun handle-message-content-opened (update)
  "Handle message content opened (e.g., self-destruct timer started)."
  (dispatch-update update))

(defun handle-message-interaction-update (update)
  "Handle message interaction info (view count, etc.)."
  (dispatch-update update))

(defun handle-live-location-viewed (update)
  "Handle live location viewed."
  (let ((chat-id (getf update :chat-id))
        (message-id (getf update :message-id)))
    (dispatch-update update)
    (format t \"[LIVE LOCATION VIEWED] ~A/~A~%\" chat-id message-id)))

(defun handle-message-timer (update)
  "Handle message timer (self-destruct, etc.)."
  (dispatch-update update))

;;; ### Chat Update Handlers

(defun handle-new-chat (update)
  "Handle new chat loaded/created."
  (let ((chat (getf update :chat)))
    (dispatch-update update)
    (format t \"[NEW CHAT] ~A (~A)~%\"
            (getf chat :title) (getf chat :type))))

(defun handle-chat-title-update (update)
  "Handle chat title changed."
  (let ((chat-id (getf update :chat-id))
        (title (getf update :title)))
    (dispatch-update update)
    (format t \"[CHAT TITLE] ~A -> ~A~%\" chat-id title)))

(defun handle-chat-photo-update (update)
  "Handle chat photo changed."
  (dispatch-update update))

(defun handle-chat-permissions-update (update)
  "Handle chat permissions changed."
  (dispatch-update update))

(defun handle-chat-last-message-update (update)
  "Handle chat last message changed."
  (dispatch-update update))

(defun handle-chat-position-update (update)
  "Handle chat position in chat list changed."
  (dispatch-update update))

(defun handle-chat-unread-count-update (update)
  "Handle chat unread count changed."
  (dispatch-update update))

(defun handle-chat-marked-as-unread-update (update)
  "Handle chat marked/unmarked as unread."
  (dispatch-update update))

(defun handle-chat-pinned-update (update)
  "Handle chat pinned/unpinned."
  (dispatch-update update))

(defun handle-chat-action-bar-update (update)
  "Handle chat action bar changed."
  (dispatch-update update))

(defun handle-chat-blocked-update (update)
  "Handle chat blocked/unblocked."
  (dispatch-update update))

(defun handle-chat-default-reaction-update (update)
  "Handle chat default reaction changed."
  (dispatch-update update))

;;; ### User Update Handlers

(defun handle-user-update (update)
  "Handle user data changed."
  (let ((user (getf update :user)))
    (dispatch-update update)
    ;; Update cache
    (when user
      (let ((uid (getf user :id)))
        (when uid
          (setf (gethash uid *user-cache*) user)))))
  (format t \"[USER UPDATE] ~A~%\" (getf (getf update :user) :first-name)))

(defun handle-user-full-info-update (update)
  "Handle user full info changed."
  (dispatch-update update))

(defun handle-user-status-update (update)
  "Handle user status changed (online/offline)."
  (let ((user-id (getf update :user-id))
        (status (getf update :status)))
    (dispatch-update update)
    (format t \"[USER STATUS] ~A -> ~A~%\" user-id (getf status :@type))))

(defun handle-user-typing-update (update)
  "Handle user typing indicator."
  (let ((chat-id (getf update :chat-id))
        (user-id (getf update :user-id))
        (action (getf update :action)))
    (dispatch-update update)
    (format t \"[TYPING] ~A in chat ~A (~A)~%\"
            user-id chat-id (getf action :@type))))

;;; ### Callback Query and Inline Handlers

(defun handle-callback-query-update (update)
  "Handle new callback query (inline button press)."
  (let* ((query (getf update :callback-query))
         (chat-id (getf query :chat-id))
         (message-id (getf query :message-id))
         (from (getf query :from))
         (data (getf query :data)))
    (dispatch-update update)
    (format t \"[CALLBACK QUERY] from ~A: ~A~%\" (getf from :id) data)))

(defun handle-inline-query-update (update)
  "Handle new inline query."
  (let* ((query (getf update :inline-query))
         (from (getf query :from))
         (query-text (getf query :query)))
    (dispatch-update update)
    (format t \"[INLINE QUERY] from ~A: ~A~%\" (getf from :id) query-text)))

(defun handle-chosen-inline-result-update (update)
  "Handle chosen inline result."
  (dispatch-update update))

(defun handle-shipped-inline-query-update (update)
  "Handle shipped inline query (payment)."
  (dispatch-update update))

(defun handle-pre-checkout-query-update (update)
  "Handle pre-checkout query (payment)."
  (dispatch-update update))

;;; ### System Update Handlers

(defun handle-authorization-state-update (update)
  "Handle authorization state changed."
  (let ((state (getf update :authorization-state)))
    (dispatch-update update)
    (format t \"[AUTH STATE] ~A~%\" (getf state :@type))))

(defun handle-connection-state-update (update)
  "Handle connection state changed."
  (let ((state (getf update :state)))
    (dispatch-update update)
    (format t \"[CONNECTION STATE] ~A~%\" (getf state :@type))))

(defun handle-new-call-update (update)
  "Handle new call."
  (dispatch-update update))

(defun handle-user-privacy-rules-update (update)
  "Handle user privacy settings changed."
  (dispatch-update update))

(defun handle-unread-message-count-update (update)
  "Handle unread message count changed."
  (dispatch-update update))

(defun handle-unread-chat-count-update (update)
  "Handle unread chat count changed."
  (dispatch-update update))

(defun handle-scope-notification-settings-update (update)
  "Handle scope notification settings changed."
  (dispatch-update update))

(defun handle-notification-update (update)
  "Handle new notification."
  (dispatch-update update))

(defun handle-notification-group-update (update)
  "Handle notification group changed."
  (dispatch-update update))

(defun handle-active-notifications-update (update)
  "Handle active notifications list."
  (dispatch-update update))

(defun handle-pending-notification-requests-update (update)
  "Handle pending notification requests."
  (dispatch-update update))

;;; ### Update Loop

(defun start-update-loop (handler &optional (poll-interval 1.0))
  "Start the update listener loop.

   Args:
     handler: Update handler instance
     poll-interval: Polling interval in seconds (default: 1.0)

   Returns:
     T if started successfully

   This runs in a background thread and processes updates
   as they arrive from the MTProto connection."
  (when (update-running-p handler)
    (return-from start-update-loop nil))

  (setf (update-running-p handler) t)
  (setf (update-thread handler)
        (bordeaux-threads:make-thread
         (lambda ()
           (handler-case
               (loop while (update-running-p handler) do
                 (handler-case
                     ;; Get pending updates from connection
                     (let ((updates (get-pending-updates
                                     (update-connection handler))))
                       (when updates
                         (dolist (update updates)
                           (vector-push-extend update (update-queue handler))
                           (process-update-object update))))
                   (error (e)
                     (format *error-output* \"Update loop error: ~A~%\" e)))
                 (sleep poll-interval)))
             (error (e)
               (format *error-output* \"Update loop crashed: ~A~%\" e)
               (setf (update-running-p handler) nil)))))
         :name \"update-listener-thread\"))
  t)

(defun stop-update-loop (handler)
  "Stop the update listener loop.

   Args:
     handler: Update handler instance

   Returns:
     T on success"
  (setf (update-running-p handler) nil)
  (when (update-thread handler)
    (bordeaux-threads:destroy-thread (update-thread handler))
    (setf (update-thread handler) nil))
  t)

(defun get-pending-updates (connection)
  "Get pending updates from MTProto connection.

   Args:
     connection: MTProto connection instance

   Returns:
     List of update objects, or NIL if none"
  ;; This would be implemented to actually fetch updates from the connection
  ;; For now, it's a placeholder for the real MTProto update retrieval
  (declare (ignore connection))
  nil)

;;; ### Global Update Handler

(defvar *update-handler* nil
  "Global update handler instance")

(defun set-update-handler (handler)
  "Set the global update handler.

   Args:
     handler: Update handler instance

   Returns:
     T on success"
  (setf *update-handler* handler))

(defun remove-update-handler ()
  "Remove the global update handler.

   Returns:
     T on success"
  (setf *update-handler* nil))

;;; ### Convenience Macros

(defmacro with-update-handler ((handler-type &rest args) &body body)
  "Execute body with a temporary update handler.

   Example:
     (with-update-handler (:user-status
                           (lambda (update)
                             (format t \"User status changed: ~A~%\" update)))
       (start-update-loop *handler*))"
  (let ((handler-var (gensym)))
    `(let ((,handler-var (make-update-handler ,@args)))
       (setf *update-handler* ,handler-var)
       (unwind-protect
            (progn ,@body)
         (stop-update-loop ,handler-var)
         (setf *update-handler* nil)))))

;;; ### Update Statistics

(defun update-stats (handler)
  "Get update handler statistics.

   Args:
     handler: Update handler instance

   Returns:
     Plist with :processed, :queued, :running, :last-id"
  (list :processed (update-processed-count handler)
        :queued (length (update-queue handler))
        :running (update-running-p handler)
        :last-id (update-last-update-id handler)))
