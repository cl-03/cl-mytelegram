;;; cli-client.lisp --- CLI client interface

(in-package #:cl-telegram/ui)

;;; ### CLI Client State

(defvar *cli-client* nil
  "Current CLI client instance.")

(defvar *cli-chats* nil
  "List of known chats.")

(defvar *cli-current-chat* nil
  "Currently selected chat.")

(defvar *cli-messages* (make-hash-table)
  "Messages by chat ID.")

(defvar *cli-running* nil
  "Whether CLI client is running.")

(defclass cli-client ()
  ((auth-state :initform :wait-phone-number :accessor cli-auth-state)
   (username :initarg :username :initform nil :accessor cli-username)
   (phone :initarg :phone :initform nil :accessor cli-phone)))

;;; ### Main CLI Loop

(defun run-cli-client ()
  "Run the CLI client main loop."
  (format t "~%")
  (format t "╔════════════════════════════════════════╗~%")
  (format t "║     cl-telegram CLI Client v0.2.0     ║~%")
  (format t "║     Pure Common Lisp Telegram         ║~%")
  (format t "╚════════════════════════════════════════╝~%")
  (format t "~%")

  (setf *cli-running* t)
  (setf *cli-client* (make-instance 'cli-client))

  ;; Run authentication flow first
  (unless (cli-authenticate)
    (format t "Authentication failed. Exiting.~%")
    (setf *cli-running* nil)
    (return-from run-cli-client))

  (format t "~%")
  (format t "Commands:~%")
  (format t "  /chats     - List chats~%")
  (format t "  /send      - Send message~%")
  (format t "  /me        - Show my info~%")
  (format t "  /help      - Show help~%")
  (format t "  /quit      - Exit client~%")
  (format t "~%")

  ;; Main message loop
  (loop while *cli-running* do
    (format t "~%[you] ")
    (finish-output)
    (let ((input (handler-case
                     (read-line)
                   (end-of-file ()
                     (setf *cli-running* nil)
                     nil))))
      (when input
        (cli-process-command input)))))

(defun cli-authenticate ()
  "Run authentication flow.

   Returns:
     T if authenticated successfully"
  (format t "~%--- Authentication ---~%")

  ;; Step 1: Phone number
  (format t "Enter phone number (or 'demo' for demo mode): ")
  (finish-output)
  (let ((phone (read-line)))
    (cond
      ((string= phone "demo")
       (cl-telegram/api:demo-auth-flow)
       t)
      (t
       (let ((result (cl-telegram/api:set-authentication-phone-number phone)))
         (if result
             (progn
               (format t "Phone number set.~%")
               ;; Step 2: Code
               (format t "Enter verification code (use 12345 for demo): ")
               (finish-output)
               (let ((code (read-line)))
                 (let ((result (cl-telegram/api:check-authentication-code code)))
                   (if (eq (car result) :success)
                       (progn
                         (format t "Authenticated!~%")
                         t)
                       (progn
                         (format t "Authentication failed: ~A~%~
                                    (Hint: Use 12345 for demo)~%"
                                 (cadr result))
                         nil))))))
             nil))))))

;;; ### Command Processing

(defun cli-process-command (input)
  "Process a user command.

   Args:
     input: User input string"
  (cond
    ;; Empty input
    ((string= input "") nil)

    ;; Commands
    ((string= input "/quit")
     (setf *cli-running* nil)
     (format t "Goodbye!~%"))

    ((string= input "/exit")
     (setf *cli-running* nil)
     (format t "Goodbye!~%"))

    ((string= input "/help")
     (cli-show-help))

    ((string= input "/chats")
     (cli-show-chats))

    ((string= input "/me")
     (cli-show-me))

    ((string= input "/demo")
     (cl-telegram/api:demo-auth-flow))

    ;; Chat selection (just a number)
    ((every #'digit-char-p input)
     (let ((chat-num (parse-integer input)))
       (when (and *cli-chats*
                  (>= chat-num 1)
                  (<= chat-num (length *cli-chats*)))
         (let ((chat (nth (1- chat-num) *cli-chats*)))
           (setf *cli-current-chat* (getf chat :id))
           (format t "~%Selected chat: ~A~%" (getf chat :title))
           ;; Show recent messages
           (cli-show-chat-history (getf chat :id))))))

    ((string-prefix-p input "/send")
     (cli-send-message (subseq input 5)))

    ;; Default: treat as message to current chat
    (t
     (cli-send-message input))))

(defun string-prefix-p (string prefix)
  "Check if string starts with prefix."
  (and (>= (length string) (length prefix))
       (string= string prefix :end2 (length prefix))))

;;; ### Command Implementations

(defun cli-show-help ()
  "Show help information."
  (format t "~%Available commands:~%")
  (format t "  /chats          - List all chats~%")
  (format t "  /send <text>    - Send a message~%")
  (format t "  /me             - Show your profile~%")
  (format t "  /demo           - Run demo auth flow~%")
  (format t "  /help           - Show this help~%")
  (format t "  /quit or /exit  - Exit client~%")
  (format t "~%")
  (format t "Or type a chat number to select it, then type a message to send.~%"))

(defun cli-show-chats ()
  "Display chat list."
  (format t "~%--- Chats ---~%")

  ;; Fetch real chats from API
  (multiple-value-bind (chats error)
      (cl-telegram/api:get-chats :limit 50)
    (if error
        (format t "Error loading chats: ~A~%" error)
        (progn
          (setf *cli-chats* chats)
          (if (null chats)
              (format t "No chats yet.~%")
              (loop for i from 1
                    for chat in chats do
                      (let* ((id (getf chat :id))
                             (title (or (getf chat :title)
                                        (getf chat :first-name)
                                        "Unknown"))
                             (last-message (getf chat :last-message))
                             (unread (or (getf chat :unread-count) 0)))
                        (format t " ~D. ~A~%" i title)
                        (format t "   ~A ~A~%"
                                (if (plusp unread)
                                    (format nil "[~D]" unread)
                                    " ")
                                (or last-message "No messages"))))))))
  (format t "~%~%Select a chat by typing its number, or use /send <message>~%")

(defun cli-show-me ()
  "Show current user info."
  (format t "~%--- My Profile ---~%")
  (let ((state (cl-telegram/api:get-authentication-state)))
    (format t "  Auth State: ~A~%" state)
    (format t "  Phone: ~A~%" (or (cl-telegram/api::*auth-phone-number*) "Not set"))
    (format t "  Authorized: ~A~%" (cl-telegram/api:authorized-p))
    ;; Try to get real user info
    (multiple-value-bind (user error)
        (cl-telegram/api:get-me)
      (if (and user (not error))
          (let ((first-name (getf user :first-name))
                (last-name (getf user :last-name))
                (username (getf user :username))
                (bio (getf user :bio)))
            (format t "  Name: ~A ~A~%" (or first-name "") (or last-name ""))
            (when username
              (format t "  Username: @~A~%" username))
            (when bio
              (format t "  Bio: ~A~%" bio)))
          (format t "  (User info not available)~%"))))
  (format t "~%"))

(defun cli-send-message (text)
  "Send a message.

   Args:
     text: Message text to send"
  (when (string= text "")
    (return-from cli-send-message))

  (if (cl-telegram/api:authorized-p)
      (progn
        ;; Send via Messages API
        (let ((chat-id (or *cli-current-chat* 1)))
          (multiple-value-bind (result error)
              (cl-telegram/api:send-message chat-id text)
            (if error
                (format t "[error] Failed to send: ~A~%" error)
                (progn
                  (format t "[sent] ~A~%" text)
                  ;; Store in local message history
                  (push (list :id (get-universal-time)
                              :from :me
                              :text text
                              :date (get-universal-time))
                        (gethash chat-id *cli-messages*)))))))
      (format t "Not authorized. Use /demo to authenticate.~%")))

;;; ### Message Display

(defun cli-show-chat-history (chat-id &key (limit 20))
  "Show recent message history for a chat.

   Args:
     chat-id: ID of chat to show history for
     limit: Number of messages to show"
  (format t "~%--- Chat History ---~%")
  (multiple-value-bind (messages error)
      (cl-telegram/api:get-messages chat-id :limit limit)
    (if error
        (format t "Error loading messages: ~A~%" error)
        (if (null messages)
            (format t "No messages yet.~%")
            (progn
              (loop for msg in messages do
                (let* ((from (getf msg :from-id))
                       (text (getf msg :text))
                       (date (getf msg :date)))
                  (format t "[~A] ~A~%"
                          (if (eq from :me) "you" "peer")
                          text)))
              (format t "~%"))))))

(defun cli-display-message (message)
  "Display a message in CLI.

   Args:
     message: Message object (plist)
   "
  (let* ((from (getf message :from))
         (text (getf message :text))
         (date (getf message :date)))
    (format t "[~A] ~A~%"
            (if (eq from :me) "you" "peer")
            text)
    (declare (ignore date))))

(defun cli-display-chat-list (chats)
  "Display chat list in CLI.

   Args:
     chats: List of chat objects"
  (if (null chats)
      (format t "No chats yet.~%")
      (progn
        (format t "~%--- Chats ---~%")
        (loop for i from 1
              for chat in chats do
                (format t " ~D. ~A~%" i (getf chat :name))
                (format t "   ~A~%" (getf chat :last_message)))
        (format t "~%"))))

(defun cli-display-new-message (chat-id message)
  "Display a new message notification.

   Args:
     chat-id: ID of chat message belongs to
     message: Message object"
  (let ((from (getf message :from))
        (text (getf message :text)))
    (format t "~%[NEW from ~A] ~A~%" from text)
    (format t "[you] ")))

;;; ### Utility Functions

(defun cli-clear-screen ()
  "Clear the terminal screen."
  ;; Works on most terminals
  (format t "~C[2J~C[H" #\Esc #\Esc))

(defun cli-beep ()
  "Play a beep sound."
  (format t "~C[7m~C[0m" #\Esc #\Esc))

(defun cli-confirm (prompt)
  "Ask for yes/no confirmation.

   Args:
     prompt: Question to ask

   Returns:
     T if user confirms"
  (format t "~A (y/n): " prompt)
  (finish-output)
  (let ((response (read-line)))
    (member (char (string-downcase response) 0) '(#\y #\Y))))

;;; ### REPL Integration

(defun cli-eval (code-string)
  "Evaluate Lisp code in CLI context.

   Args:
     code-string: Lisp code as string

   Returns:
     Result of evaluation"
  (handler-case
      (let ((result (eval (read-from-string code-string))))
        (format t "=> ~A~%" result)
        result)
    (error (e)
      (format t "Error: ~A~%" e)
      nil)))

;;; ### Run Options

(defun run-cli-client-with-auth (phone code)
  "Run CLI client with pre-provided auth.

   Args:
     phone: Phone number string
     code: Verification code"
  (cl-telegram/api:set-authentication-phone-number phone)
  (cl-telegram/api:check-authentication-code code)
  (run-cli-client))

(defun run-demo-cli ()
  "Run CLI client in demo mode."
  (run-cli-client-with-auth "+1234567890" "12345"))
