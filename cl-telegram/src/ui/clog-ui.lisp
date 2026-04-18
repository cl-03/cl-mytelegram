;;; clog-ui.lisp --- CLOG-based GUI client for Telegram
;;;
;;; Provides a web-based graphical user interface using CLOG
;;; (Common Lisp Omnigenous Web). Runs a local web server and
;;; provides a Telegram-like chat interface.

(in-package #:cl-telegram/ui)

;;; ### CLOG UI State

(defvar *clog-port* 8080
  "Port for CLOG web server")

(defvar *clog-host* "localhost"
  "Host for CLOG web server")

(defvar *clog-connections* (make-hash-table :test 'equal)
  "Active CLOG browser connections")

(defvar *current-chat-id* nil
  "Currently selected chat ID")

(defvar *message-page-size* 50
  "Number of messages to load per page")

;;; ### CLOG Application

(defun start-clog-ui (&key (port *clog-port*) (host *clog-host*))
  "Start the CLOG GUI web server.

   Args:
     port: Port number (default: 8080)
     host: Host to bind (default: localhost)

   Returns:
     T on success

   Opens browser window automatically."
  (setf *clog-port* port)
  (setf *clog-host* host)

  ;; Start CLOG server
  (clog:run *clog-port*
            :host *clog-host*
            :document (lambda (clog-window)
                        (setup-clog-window clog-window)))

  (format t "CLOG UI started at http://~A:~A~%" host port)
  (format t "Press Ctrl+C to stop~%")
  t)

(defun stop-clog-ui ()
  "Stop the CLOG GUI web server.

   Returns:
     T on success"
  (clog:stop)
  (format t "CLOG UI stopped~%")
  t)

(defun setup-clog-window (win)
  "Setup CLOG browser window with Telegram UI.

   Args:
     win: CLOG window object"
  ;; Store connection
  (setf (gethash (clog:connection-id win) *clog-connections*) win)

  ;; Set window title
  (clog:set-title win "cl-telegram")

  ;; Setup HTML structure
  (setup-clog-layout win)

  ;; Load chat list
  (refresh-chat-list win)

  ;; Bind keyboard shortcuts
  (bind-clog-shortcuts win))

;;; ### HTML Layout

(defun setup-clog-layout (win)
  "Setup main HTML layout.

   Args:
     win: CLOG window object"
  (let ((body (clog:body win)))
    ;; Clear body
    (clog:clear! body)

    ;; Add CSS styles
    (clog:append! body
                  (clog:create-css-link win "
    <style>
      :root {
        --bg-primary: #1e2a38;
        --bg-secondary: #2d3b4a;
        --bg-tertiary: #3a4b5c;
        --text-primary: #ffffff;
        --text-secondary: #a0b0c0;
        --accent: #3390ec;
        --accent-hover: #2578d4;
        --message-in: #2d3b4a;
        --message-out: #3390ec;
        --border: #405060;
      }

      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }

      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: var(--bg-primary);
        color: var(--text-primary);
        height: 100vh;
        overflow: hidden;
      }

      .app-container {
        display: flex;
        height: 100vh;
      }

      /* Sidebar */
      .sidebar {
        width: 320px;
        background: var(--bg-secondary);
        border-right: 1px solid var(--border);
        display: flex;
        flex-direction: column;
      }

      .sidebar-header {
        padding: 16px;
        background: var(--bg-tertiary);
        border-bottom: 1px solid var(--border);
        display: flex;
        justify-content: space-between;
        align-items: center;
      }

      .sidebar-header h1 {
        font-size: 18px;
        font-weight: 600;
      }

      .refresh-btn {
        background: var(--accent);
        border: none;
        color: white;
        width: 32px;
        height: 32px;
        border-radius: 50%;
        cursor: pointer;
        font-size: 16px;
      }

      .refresh-btn:hover {
        background: var(--accent-hover);
      }

      .chat-list {
        flex: 1;
        overflow-y: auto;
      }

      .chat-item {
        display: flex;
        padding: 12px 16px;
        cursor: pointer;
        border-bottom: 1px solid var(--border);
        transition: background 0.2s;
      }

      .chat-item:hover {
        background: var(--bg-tertiary);
      }

      .chat-item.active {
        background: var(--bg-tertiary);
        border-left: 3px solid var(--accent);
      }

      .chat-avatar {
        width: 48px;
        height: 48px;
        border-radius: 50%;
        background: var(--accent);
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 600;
        margin-right: 12px;
        flex-shrink: 0;
      }

      .chat-info {
        flex: 1;
        min-width: 0;
      }

      .chat-name {
        font-weight: 500;
        margin-bottom: 4px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      .chat-last-message {
        color: var(--text-secondary);
        font-size: 13px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      .chat-meta {
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        margin-left: 8px;
      }

      .chat-time {
        color: var(--text-secondary);
        font-size: 12px;
      }

      .unread-badge {
        background: var(--accent);
        color: white;
        font-size: 12px;
        padding: 2px 8px;
        border-radius: 12px;
        margin-top: 4px;
      }

      /* Main Chat Area */
      .chat-area {
        flex: 1;
        display: flex;
        flex-direction: column;
        background: var(--bg-primary);
      }

      .chat-header {
        padding: 12px 20px;
        background: var(--bg-secondary);
        border-bottom: 1px solid var(--border);
        display: flex;
        align-items: center;
      }

      .chat-header-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        background: var(--accent);
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 600;
      }

      .chat-header-info {
        margin-left: 12px;
      }

      .chat-header-name {
        font-weight: 600;
      }

      .chat-header-status {
        color: var(--text-secondary);
        font-size: 13px;
      }

      .messages-container {
        flex: 1;
        overflow-y: auto;
        padding: 20px;
        display: flex;
        flex-direction: column;
        gap: 8px;
      }

      .message {
        max-width: 70%;
        padding: 10px 14px;
        border-radius: 12px;
        position: relative;
        word-wrap: break-word;
      }

      .message-incoming {
        background: var(--message-in);
        align-self: flex-start;
        border-bottom-left-radius: 4px;
      }

      .message-outgoing {
        background: var(--message-out);
        align-self: flex-end;
        border-bottom-right-radius: 4px;
      }

      .message-text {
        line-height: 1.4;
      }

      .message-meta {
        display: flex;
        justify-content: flex-end;
        align-items: center;
        gap: 6px;
        margin-top: 4px;
        font-size: 12px;
        opacity: 0.7;
      }

      .message-sender {
        font-weight: 600;
        color: var(--accent);
        margin-bottom: 4px;
        font-size: 13px;
      }

      /* Input Area */
      .input-area {
        padding: 16px 20px;
        background: var(--bg-secondary);
        border-top: 1px solid var(--border);
        display: flex;
        gap: 12px;
        align-items: center;
      }

      .message-input {
        flex: 1;
        background: var(--bg-tertiary);
        border: 1px solid var(--border);
        border-radius: 20px;
        padding: 12px 20px;
        color: var(--text-primary);
        font-size: 14px;
        resize: none;
        outline: none;
        max-height: 120px;
        font-family: inherit;
      }

      .message-input:focus {
        border-color: var(--accent);
      }

      .send-button {
        background: var(--accent);
        border: none;
        color: white;
        width: 44px;
        height: 44px;
        border-radius: 50%;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: background 0.2s;
        font-size: 18px;
      }

      .send-button:hover {
        background: var(--accent-hover);
      }

      .empty-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        height: 100%;
        color: var(--text-secondary);
      }

      .empty-state-icon {
        font-size: 64px;
        margin-bottom: 16px;
      }

      /* Search Box */
      .search-box {
        padding: 12px 16px;
        background: var(--bg-secondary);
        border-bottom: 1px solid var(--border);
      }

      .search-input {
        width: 100%;
        background: var(--bg-tertiary);
        border: 1px solid var(--border);
        border-radius: 20px;
        padding: 8px 16px;
        color: var(--text-primary);
        font-size: 14px;
        outline: none;
      }

      .search-input:focus {
        border-color: var(--accent);
      }

      /* Scrollbar */
      ::-webkit-scrollbar {
        width: 8px;
      }

      ::-webkit-scrollbar-track {
        background: var(--bg-primary);
      }

      ::-webkit-scrollbar-thumb {
        background: var(--border);
        border-radius: 4px;
      }

      ::-webkit-scrollbar-thumb:hover {
        background: var(--text-secondary);
      }

      /* Loading indicator */
      .loading {
        display: flex;
        justify-content: center;
        padding: 20px;
        color: var(--text-secondary);
      }

      .typing-indicator {
        display: inline-flex;
        gap: 4px;
      }

      .typing-indicator span {
        width: 8px;
        height: 8px;
        background: var(--text-secondary);
        border-radius: 50%;
        animation: typing 1.4s infinite;
      }

      .typing-indicator span:nth-child(2) { animation-delay: 0.2s; }
      .typing-indicator span:nth-child(3) { animation-delay: 0.4s; }

      @keyframes typing {
        0%, 60%, 100% { transform: translateY(0); }
        30% { transform: translateY(-10px); }
      }
    </style>
    "))

    ;; Create app structure
    (clog:append! body
                  (clog:create-element win "div" :class "app-container"
                    (clog:create-element win "div" :class "sidebar"
                      (clog:create-element win "div" :class "sidebar-header"
                        (clog:create-element win "h1" :text "cl-telegram")
                        (clog:create-element win "button" :class "refresh-btn" :text "↻"
                                             :onclick "location.reload()"))
                      (clog:create-element win "div" :class "search-box"
                        (clog:create-element win "input" :class "search-input"
                                             :type "text"
                                             :placeholder "Search chats..."))
                      (clog:create-element win "div" :id "chat-list" :class "chat-list"))
                    (clog:create-element win "div" :id "chat-area" :class "chat-area"
                      (clog:create-element win "div" :id "empty-state" :class "empty-state"
                        (clog:create-element win "div" :class "empty-state-icon" :text "💬")
                        (clog:create-element win "p" :text "Select a chat to start messaging"))))))

    ;; Setup event handlers
    (setup-clog-events win)))

(defun setup-clog-events (win)
  "Setup JavaScript event handlers.

   Args:
     win: CLOG window object"
  ;; Search functionality
  (let ((search-input (clog:create-element win "input"
                                           :class "search-input"
                                           :type "text"
                                           :placeholder "Search chats...")))
    (clog:on search-input :input
             (lambda (ev)
               (let ((query (clog:value ev)))
                 (filter-chat-list win query))))
    search-input))

;;; ### Chat List

(defun refresh-chat-list (win)
  "Refresh the chat list.

   Args:
     win: CLOG window object"
  (let ((chat-list (clog:get-element-by-id win "chat-list")))
    (clog:clear! chat-list)

    ;; Get cached chats
    (let ((chats (cl-telegram/api:list-cached-chats :limit 100)))
      (if (null chats)
          ;; No chats - show empty state
          (clog:append! chat-list
                        (clog:create-element win "div" :class "empty-state"
                          (clog:create-element win "p" :text "No chats yet")))
          ;; Render chat items
          (dolist (chat chats)
            (render-chat-item win chat-list chat))))))

(defun render-chat-item (win container chat)
  "Render a single chat item.

   Args:
     win: CLOG window object
     container: Container element
     chat: Chat plist"
  (let* ((chat-id (getf chat :id))
         (title (or (getf chat :title)
                    (getf chat :first-name)
                    "Unknown"))
         (last-msg (or (getf chat :last-message-text) ""))
         (last-date (getf chat :last-message-date))
         (unread (getf chat :unread-count 0))
         (avatar-initials (subseq title 0 (min 2 (length title))))
         (chat-el (clog:create-element win "div"
                                       :class "chat-item"
                                       :id (format nil "chat-~A" chat-id)
                                       :data-chat-id (format nil "~A" chat-id))))
    ;; Click handler
    (clog:on chat-el :click
             (lambda (ev)
               (declare (ignore ev))
               (select-chat win chat-id)))

    ;; Build chat item
    (clog:append! chat-el
                  (clog:create-element win "div" :class "chat-avatar"
                                       :text avatar-initials)
                  (clog:create-element win "div" :class "chat-info"
                    (clog:create-element win "div" :class "chat-name" :text title)
                    (clog:create-element win "div" :class "chat-last-message" :text last-msg))
                  (clog:create-element win "div" :class "chat-meta"
                    (clog:create-element win "span" :class "chat-time"
                                         :text (format-time last-date))
                    (when (plusp unread)
                      (clog:create-element win "span" :class "unread-badge"
                                           :text (format nil "~A" unread)))))

    (clog:append! container chat-el)))

(defun filter-chat-list (win query)
  "Filter chat list by search query.

   Args:
     win: CLOG window object
     query: Search query string"
  (let ((chat-list (clog:get-element-by-id win "chat-list"))
        (items (clog:query-selector-all win ".chat-item")))
    (dolist (item items)
      (let* ((name-el (clog:query-selector item ".chat-name"))
             (name (clog:text name-el)))
        (if (search query name :test #'string-equal)
            (clog:set-style item "display" "flex")
            (clog:set-style item "display" "none"))))))

(defun select-chat (win chat-id)
  "Select a chat to view.

   Args:
     win: CLOG window object
     chat-id: Chat identifier"
  (setf *current-chat-id* chat-id)

  ;; Update active state
  (let ((chat-list (clog:get-element-by-id win "chat-list")))
    (dolist (el (clog:children chat-list))
      (clog:remove-class! el "active"))
    (let ((selected (clog:get-element-by-id win (format nil "chat-~A" chat-id))))
      (when selected
        (clog:add-class! selected "active"))))

  ;; Load messages
  (load-messages win chat-id)

  ;; Update header
  (update-chat-header win chat-id))

(defun load-messages (win chat-id)
  "Load messages for a chat.

   Args:
     win: CLOG window object
     chat-id: Chat identifier"
  (let ((container (clog:get-element-by-id win "messages-container")))
    (clog:clear! container)

    ;; Get cached messages
    (let ((messages (cl-telegram/api:get-cached-messages chat-id
                                                         :limit *message-page-size*)))
      (if (null messages)
          (clog:append! container
                        (clog:create-element win "div" :class "empty-state"
                          (clog:create-element win "p" :text "No messages yet")))
          (dolist (msg (nreverse messages))
            (render-message win container msg)))))

  ;; Scroll to bottom
  (clog:run-script win "
    (function() {
      var container = document.querySelector('.messages-container');
      if (container) {
        container.scrollTop = container.scrollHeight;
      }
    })();
  "))

(defun render-message (win container message)
  "Render a single message.

   Args:
     win: CLOG window object
     container: Container element
     message: Message plist"
  (let* ((from (getf message :from))
         (from-id (getf from :id))
         (from-name (getf from :first-name))
         (text (or (getf message :text) ""))
         (date (getf message :date))
         (is-outgoing (eq from-id cl-telegram/api::*auth-user-id*))
         (msg-class (if is-outgoing "message message-outgoing" "message message-incoming"))
         (msg-el (clog:create-element win "div" :class msg-class)))
    ;; Add sender name for incoming messages
    (unless is-outgoing
      (clog:append! msg-el
                    (clog:create-element win "div" :class "message-sender"
                                         :text from-name)))

    ;; Message text
    (clog:append! msg-el
                  (clog:create-element win "div" :class "message-text" :text text)
                  (clog:create-element win "div" :class "message-meta"
                    (clog:create-element win "span" :text (format-time date))))

    (clog:append! container msg-el)))

(defun update-chat-header (win chat-id)
  "Update chat header.

   Args:
     win: CLOG window object
     chat-id: Chat identifier"
  (let ((chat (cl-telegram/api:get-cached-chat chat-id)))
    (when chat
      (let* ((title (or (getf chat :title)
                        (getf chat :first-name)
                        "Unknown"))
             (avatar-initials (subseq title 0 (min 2 (length title))))
             (status "last seen recently"))
        ;; Replace chat area
        (let ((chat-area (clog:get-element-by-id win "chat-area")))
          (clog:clear! chat-area)
          (clog:append! chat-area
                        (clog:create-element win "div" :class "chat-header"
                          (clog:create-element win "div" :class "chat-header-avatar"
                                               :text avatar-initials)
                          (clog:create-element win "div" :class "chat-header-info"
                            (clog:create-element win "div" :class "chat-header-name" :text title)
                            (clog:create-element win "div" :class "chat-header-status" :text status)))
                        (clog:create-element win "div" :id "messages-container" :class "messages-container")
                        (clog:create-element win "div" :class "input-area"
                          (clog:create-element win "textarea"
                                               :id "message-input"
                                               :class "message-input"
                                               :placeholder "Type a message..."
                                               :rows 1)
                          (clog:create-element win "button"
                                               :id "send-button"
                                               :class "send-button"
                                               :text "➤"))))

        ;; Bind send button and input
        (setup-message-input win))))))

(defun setup-message-input (win)
  "Setup message input handlers.

   Args:
     win: CLOG window object"
  (let ((input (clog:get-element-by-id win "message-input"))
        (send-btn (clog:get-element-by-id win "send-button")))

    ;; Send button click
    (clog:on send-btn :click
             (lambda (ev)
               (declare (ignore ev))
               (send-message-from-input win)))

    ;; Enter key to send
    (clog:on input :keydown
             (lambda (ev)
               (when (and (string= (clog:key ev) "Enter")
                          (not (clog:shift-key-p ev)))
                 (clog:prevent-default ev)
                 (send-message-from-input win))))))

(defun send-message-from-input (win)
  "Send message from input field.

   Args:
     win: CLOG window object"
  (let ((input (clog:get-element-by-id win "message-input")))
    (when input
      (let ((text (clog:value input)))
        (when (and text (> (length text) 0) *current-chat-id*)
          ;; Send via API
          (handler-case
              (cl-telegram/api:send-message *current-chat-id* text)
            (error (e)
              (format *error-output* "Failed to send message: ~A~%" e)))

          ;; Cache message locally
          (cl-telegram/api:cache-message
           (list :id (random 1000000)
                 :chat-id *current-chat-id*
                 :from (list :id cl-telegram/api::*auth-user-id*
                             :first-name "You")
                 :text text
                 :date (get-universal-time)))

          ;; Clear input
          (clog:set-value input "")

          ;; Reload messages
          (load-messages win *current-chat-id*))))))

;;; ### Utilities

(defun format-time (timestamp)
  "Format Unix timestamp for display.

   Args:
     timestamp: Unix timestamp

   Returns:
     Formatted time string"
  (if timestamp
      (let ((time (decode-universal-time timestamp 0)))
        (format nil "~2,'0d:~2,'0d" (third time) (fourth time)))
      ""))

(defun bind-clog-shortcuts (win)
  "Bind keyboard shortcuts.

   Args:
     win: CLOG window object"
  (clog:run-script win "
    document.addEventListener('keydown', function(e) {
      // Ctrl+R: Refresh chat list
      if (e.ctrlKey && e.key === 'r') {
        e.preventDefault();
        location.reload();
      }
      // Ctrl+K: Focus search
      if (e.ctrlKey && e.key === 'k') {
        e.preventDefault();
        document.querySelector('.search-input').focus();
      }
    });
  "))

;;; ### REPL Commands

(defun show-clog-ui ()
  "Open CLOG UI in default browser.

   Returns:
     T on success"
  (let ((url (format nil "http://~A:~A" *clog-host* *clog-port*)))
    (format t "Opening CLOG UI at ~A~%" url)
    ;; Try to open browser based on platform
    #+linux (ignore-errors (uiop:run-program (list "xdg-open" url)))
    #+macos (ignore-errors (uiop:run-program (list "open" url)))
    #+windows (ignore-errors (uiop:run-program (format nil "start ~A" url)))
    t))

(defun create-demo-ui ()
  "Create a demo UI with sample data.

   Returns:
     T on success"
  ;; Create sample chats for demo
  (cl-telegram/api:cache-chat '(:id 1 :title "Alice" :first-name "Alice"
                                  :last-message-text "Hello!" :last-message-date 1609459200
                                  :unread-count 1))
  (cl-telegram/api:cache-chat '(:id 2 :title "Bob" :first-name "Bob"
                                  :last-message-text "See you tomorrow" :last-message-date 1609459100
                                  :unread-count 0))
  (cl-telegram/api:cache-chat '(:id 3 :title "Project Group"
                                  :last-message-text "Meeting at 3pm" :last-message-date 1609459000
                                  :unread-count 5))

  ;; Add sample messages
  (cl-telegram/api:cache-message '(:id 1 :chat-id 1 :from (:id 100 :first-name "Alice")
                                     :date 1609459100 :text "Hi there!"))
  (cl-telegram/api:cache-message '(:id 2 :chat-id 1 :from (:id 100 :first-name "Alice")
                                     :date 1609459200 :text "How are you?"))

  ;; Start UI
  (start-clog-ui)
  t)

;;; ### Auto-refresh

(defvar *auto-refresh-interval* 30
  "Interval in seconds for auto-refreshing chat list")

(defvar *auto-refresh-timer* nil
  "Timer for auto-refresh")

(defun start-auto-refresh ()
  "Start automatic chat list refresh.

   Returns:
     T on success"
  (when *auto-refresh-timer*
    (cancel-timer *auto-refresh-timer*))

  (setf *auto-refresh-timer*
        (bt:make-thread
         (lambda ()
           (loop
             (sleep *auto-refresh-interval*)
             (when (and (boundp '*clog-connections*)
                        (> (hash-table-count *clog-connections*) 0))
               (dolist (win (hash-table-values *clog-connections*))
                 (refresh-chat-list win)))))
         :name "clog-auto-refresh"))
  t)

(defun stop-auto-refresh ()
  "Stop automatic chat list refresh.

   Returns:
     T on success"
  (when *auto-refresh-timer*
    (bt:destroy-thread *auto-refresh-timer*)
    (setf *auto-refresh-timer* nil))
  t)
