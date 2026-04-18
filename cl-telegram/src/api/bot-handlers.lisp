;;; bot-handlers.lisp --- Bot command router and message handlers
;;;
;;; Provides a framework for handling bot commands and messages.

(in-package #:cl-telegram/api)

;;; ### Bot Handler State

(defclass bot-handler ()
  ((token :initarg :token :reader bot-token)
   (config :initarg :config :reader bot-config)
   (commands :initform (make-hash-table :test 'equal) :accessor bot-commands)
   (message-handlers :initform nil :accessor bot-message-handlers)
   (update-handlers :initform nil :accessor bot-update-handlers)
   (last-update-id :initform 0 :accessor bot-last-update-id)
   (running-p :initform nil :accessor bot-running-p)
   (thread :initform nil :accessor bot-thread))
  (:documentation "Telegram Bot handler instance"))

(defun make-bot-handler (token &key timeout)
  "Create a new bot handler.

   Args:
     token: Bot token from @BotFather
     timeout: Long polling timeout in seconds (default: 30)

   Returns:
     Bot handler instance

   Example:
     (defparameter *bot* (make-bot-handler \"123456:ABC-DEF1234ghIkl-zyx57W2v1u123ewF135\"))"
  (let ((config (make-bot :token token :timeout (or timeout 30))))
    (make-instance 'bot-handler :token token :config config)))

;;; ### Command Registration

(defmacro defcommand ((command bot &key description) &body body)
  "Define a bot command handler.

   Args:
     command: Command string (without /)
     bot: Bot handler variable
     description: Optional command description

   Body bindings:
     message: The message object (plist)
     chat-id: Chat identifier
     from: User who sent the message
     args: List of command arguments

   Example:
     (defcommand (\"start\" *bot* :description \"Start the bot\")
       (format t \"Received /start from ~A~\" chat-id)
       (bot-send-message *bot* chat-id \"Welcome!\"))"
  (let ((handler-fn (gensym "CMD-")))
    `(progn
       (defun ,handler-fn (message chat-id from args)
         ,@body)
       (register-command ,bot ,command #',handler-fn ,description))))

(defun register-command (bot command handler &optional description)
  "Register a command handler.

   Args:
     bot: Bot handler instance
     command: Command string (without /)
     handler: Function (message chat-id from args)
     description: Optional description for bot_commands

   Returns:
     T on success"
  (setf (gethash command (bot-commands bot))
        (list :handler handler :description description))
  t)

(defun unregister-command (bot command)
  "Remove a command handler.

   Args:
     bot: Bot handler instance
     command: Command string to remove

   Returns:
     T on success"
  (remhash command (bot-commands bot)))

;;; ### Message Handler Registration

(defun register-message-handler (bot predicate handler)
  "Register a custom message handler.

   Args:
     bot: Bot handler instance
     predicate: Function (message) -> boolean
     handler: Function (message chat-id from)

   Example:
     ;; Handle all photos
     (register-message-handler *bot*
       (lambda (msg) (getf msg :photo))
       (lambda (msg chat-id from)
         (format t \"Photo from ~A~\" chat-id)))"
  (push (list :predicate predicate :handler handler)
        (bot-message-handlers bot))
  t)

;;; ### Update Processing

(defun process-update (bot update)
  "Process a single update.

   Args:
     bot: Bot handler instance
     update: Update object (plist)

   Returns:
     T if update was handled"
  (let* ((message (getf update :message))
         (edited-message (getf update :edited-message))
         (callback-query (getf update :callback-query))
         (chat-id nil)
         (from nil)
         (msg nil))

    ;; Determine message source
    (cond
      (message
       (setf msg message
             chat-id (getf message :chat-id)
             from (getf message :from)))
      (edited-message
       (setf msg edited-message
             chat-id (getf edited-message :chat-id)
             from (getf edited-message :from)))
      (callback-query
       (setf chat-id (getf (getf callback-query :message) :chat-id)
             from (getf callback-query :from))
       (return-from process-update
         (process-callback-query bot callback-query))))

    ;; Update last update ID
    (setf (bot-last-update-id bot) (getf update :update-id))

    ;; Check for commands
    (when (and msg (getf msg :text))
      (let ((text (getf msg :text)))
        (when (and (> (length text) 0)
                   (char= (char text 0) #\/))
          (return-from process-update
            (process-command bot msg text chat-id from)))))

    ;; Run custom message handlers
    (dolist (handler-spec (bot-message-handlers bot))
      (let ((predicate (getf handler-spec :predicate))
            (handler (getf handler-spec :handler)))
        (when (funcall predicate msg)
          (funcall handler msg chat-id from)
          (return-from process-update t))))

    t))

(defun process-command (bot message text chat-id from)
  "Process a command message.

   Args:
     bot: Bot handler instance
     message: Message object
     text: Message text (starts with /)
     chat-id: Chat identifier
     from: Sender user object

   Returns:
     T if command was handled"
  ;; Parse command and arguments
  (let* ((parts (cl-ppcre:split "\\s+" text))
         (command-with-bot (car parts))
         (args (cdr parts))
         ;; Remove @botname suffix if present
         (command (cl-ppcre:regex-replace "@[a-zA-Z0-9_]+$" command-with-bot "")))
    ;; Remove leading /
    (when (char= (char command 0) #\/)
      (setf command (subseq command 1)))

    ;; Look up handler
    (let ((cmd-entry (gethash (string-downcase command) (bot-commands bot))))
      (if cmd-entry
          (progn
            (funcall (getf cmd-entry :handler) message chat-id from args)
            t)
          ;; Unknown command
          (progn
            (bot-send-message bot chat-id
                              (format nil "Unknown command: ~A. Use /help for available commands." command))
            nil)))))

(defun process-callback-query (bot callback-query)
  "Process a callback query (inline button press).

   Args:
     bot: Bot handler instance
     callback-query: CallbackQuery object

   Returns:
     T if handled"
  (let* ((data (getf callback-query :data))
         (chat-id (getf (getf callback-query :message) :chat-id))
         (from (getf callback-query :from)))
    ;; Default handler - can be overridden
    (format t "Callback query from ~A: ~A~%" from data)
    t))

;;; ### Bot Polling Loop

(defun start-polling (bot &key timeout)
  "Start the bot polling loop.

   Args:
     bot: Bot handler instance
     timeout: Long polling timeout (default: 30)

   Returns:
     T if polling started

   This runs in a background thread. Use stop-polling to stop."
  (when (bot-running-p bot)
    (return-from start-polling nil))

  (setf (bot-running-p bot) t)
  (setf (bot-thread bot)
        (bordeaux-threads:make-thread
         (lambda ()
           (handler-case
               (loop while (bot-running-p bot) do
                 (let ((updates (get-updates (bot-config bot)
                                            :offset (1+ (bot-last-update-id bot))
                                            :timeout timeout)))
                   (dolist (update updates)
                     (process-update bot update))))
             (error (e)
               (format *error-output* "Bot polling error: ~A~%" e)
               (setf (bot-running-p bot) nil)))))
         :name (format nil "bot-poll-thread-~A" (subseq (bot-token bot) 0 10))))
  t)

(defun stop-polling (bot)
  "Stop the bot polling loop.

   Args:
     bot: Bot handler instance

   Returns:
     T on success"
  (setf (bot-running-p bot) nil)
  (when (bot-thread bot)
    (bordeaux-threads:destroy-thread (bot-thread bot))
    (setf (bot-thread bot) nil))
  t)

(defun bot-running-p (bot)
  "Check if bot is running.

   Args:
     bot: Bot handler instance

   Returns:
     T if bot is actively polling"
  (slot-value bot 'running-p))

;;; ### Helper Commands

(defun setup-basic-commands (bot)
  "Setup basic /start and /help commands.

   Args:
     bot: Bot handler instance"
  (defcommand ("start" bot :description "Start the bot")
    (declare (ignore args))
    (bot-send-message bot chat-id
                      (format nil "Hello~@[ ~A~]! I'm a bot. Use /help for available commands."
                              (getf from :first-name))))
  (defcommand ("help" bot :description "Show available commands")
    (declare (ignore args))
    (let ((commands-text
           (with-output-to-string (s)
             (format s "Available commands:~%")
             (maphash (lambda (cmd data)
                        (format s "/~A - ~A~%" cmd (or (getf data :description) "No description")))
                      (bot-commands bot)))))
      (bot-send-message bot chat-id commands-text))))

;;; ### Inline Query Support

(defun register-inline-handler (bot handler)
  "Register an inline query handler.

   Args:
     bot: Bot handler instance
     handler: Function (inline-query) -> results list

   Returns:
     T on success"
  (push handler (bot-update-handlers bot))
  t)

(defun answer-inline-query (bot inline-query-id results &key cache-time is-personal next-offset switch-pm-text)
  "Answer an inline query.

   Args:
     bot: Bot handler instance
     inline-query-id: ID of the inline query
     results: List of InlineQueryResult objects
     cache-time: Cache time in seconds
     is-personal: True if results are personal
     next-offset: Offset for next query
     switch-pm-text: Text to show in PM button

   Returns:
     T on success"
  (let ((params `((:inline_query_id . ,inline-query-id)
                  (:results . ,results)
                  ,@(when cache-time `((:cache_time . ,cache-time)))
                  ,@(when is-personal `((:is_personal . ,is-personal)))
                  ,@(when next-offset `((:next_offset . ,next-offset)))
                  ,@(when switch-pm-text `((:switch_pm_text . ,switch-pm-text))))))
    (multiple-value-bind (result error)
        (bot-request (bot-config bot) "answerInlineQuery" :params params)
      (if result t (values nil error)))))
