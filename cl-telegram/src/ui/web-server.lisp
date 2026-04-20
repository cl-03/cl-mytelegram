;;; web-server.lisp --- Standalone web server for cl-telegram Web UI
;;;
;;; Provides a standalone web server that serves the cl-telegram Web UI
;;; with WebSocket real-time updates support.

(in-package #:cl-telegram/ui)

;;; ============================================================================
;;; Configuration
;;; ============================================================================

(defvar *web-server-port* 8080
  "Default port for the web server")

(defvar *web-server-host* "0.0.0.0"
  "Host to bind the web server")

(defvar *web-server-root*
  (merge-pathnames "web-assets/" *load-pathname*)
  "Root directory for static web assets")

(defvar *websocket-clients* (make-hash-table :test 'eq)
  "Connected WebSocket clients for real-time updates")

(defvar *websocket-server* nil
  "WebSocket server instance")

;;; ============================================================================
;;; HTML Template
;;; ============================================================================

(defun generate-index-html ()
  "Generate the main HTML page for the web UI.

   Returns:
     HTML string"
  (format nil
          "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <meta name=\"theme-color\" content=\"#3390ec\">
  <meta name=\"description\" content=\"A pure Common Lisp Telegram client\">

  <title>cl-telegram</title>

  <!-- PWA Manifest -->
  <link rel=\"manifest\" href=\"/manifest.json\">

  <!-- Icons -->
  <link rel=\"icon\" type=\"image/png\" sizes=\"32x32\" href=\"/icons/favicon-32x32.png\">
  <link rel=\"icon\" type=\"image/png\" sizes=\"16x16\" href=\"/icons/favicon-16x16.png\">
  <link rel=\"apple-touch-icon\" sizes=\"180x180\" href=\"/icons/apple-touch-icon.png\">

  <!-- Styles -->
  <link rel=\"stylesheet\" href=\"/styles/main.css\">
  <link rel=\"stylesheet\" href=\"/styles/mobile.css\">
</head>
<body>
  <div class=\"app-container\">
    <!-- Sidebar -->
    <aside class=\"sidebar\" id=\"sidebar\">
      <div class=\"sidebar-header\">
        <h1>💬 cl-telegram</h1>
        <div class=\"header-actions\">
          <button class=\"header-btn\" title=\"Settings\" onclick=\"toggleSettings()\">⚙</button>
          <button class=\"header-btn\" title=\"Refresh\" onclick=\"location.reload()\">↻</button>
        </div>
      </div>

      <div class=\"search-box\">
        <input type=\"text\" class=\"search-input\" placeholder=\"Search chats...\">
      </div>

      <div class=\"chat-list\" id=\"chat-list\">
        <!-- Chat items will be rendered here -->
        <div class=\"loading\">Loading chats...</div>
      </div>
    </aside>

    <!-- Sidebar Overlay (Mobile) -->
    <div class=\"sidebar-overlay\" id=\"sidebar-overlay\"></div>

    <!-- Main Chat Area -->
    <main class=\"chat-area\" id=\"chat-area\">
      <div class=\"empty-state\" id=\"empty-state\">
        <div class=\"empty-state-icon\">💬</div>
        <p class=\"empty-state-text\">Select a chat to start messaging</p>
      </div>
    </main>
  </div>

  <!-- JavaScript -->
  <script src=\"/js/app.js\"></script>
  <script src=\"/js/events.js\"></script>

  <!-- PWA Registration -->
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
          .then(reg => console.log('SW registered:', reg.scope))
          .catch(err => console.error('SW failed:', err));
      });
    }
  </script>
</body>
</html>"))

;;; ============================================================================
;;; HTTP Request Handlers
;;; ============================================================================

(defun handle-http-request (request)
  "Handle incoming HTTP requests.

   Args:
     request: Hunchentoot request object

   Returns:
     Response body, status code, and headers"
  (let* ((uri (hunchentoot:request-uri request))
         (method (hunchentoot:request-method request)))

    (cond
      ;; Root path - serve main HTML
      ((string= uri "/")
       (handle-index-page))

      ;; Static assets
      ((string-prefix-p "/styles/" uri)
       (serve-static-file uri "styles/"))

      ((string-prefix-p "/js/" uri)
       (serve-static-file uri "js/"))

      ((string-prefix-p "/icons/" uri)
       (serve-static-file uri "icons/"))

      ;; Manifest
      ((string= uri "/manifest.json")
       (serve-manifest))

      ;; Service Worker
      ((string= uri "/sw.js")
       (serve-service-worker))

      ;; API endpoints
      ((string-prefix-p "/api/" uri)
       (handle-api-request request))

      ;; 404
      (t
       (hunchentoot:return-code 404)
       "Not Found"))))

(defun handle-index-page ()
  "Serve the main index page.

   Returns:
     HTML string"
  (setf (hunchentoot:content-type*) \"text/html; charset=utf-8\")
  (generate-index-html))

(defun serve-static-file (uri prefix)
  "Serve a static file from the web-assets directory.

   Args:
     uri: Request URI
     prefix: URL prefix to strip

   Returns:
     File contents or 404"
  (let* ((relative-path (subseq uri (1+ (length prefix))))
         (file-path (merge-pathnames relative-path
                                     (merge-pathnames prefix *web-server-root*))))
    (if (probe-file file-path)
        (let ((content-type (guess-content-type file-path)))
          (setf (hunchentoot:content-type*) content-type)
          (with-open-file (s file-path :direction :input)
            (let ((content (make-string (file-length s))))
              (read-sequence content s)
              content)))
        (progn
          (hunchentoot:return-code 404)
          \"File not found\"))))

(defun serve-manifest ()
  "Serve the PWA manifest.

   Returns:
     JSON manifest"
  (setf (hunchentoot:content-type*) \"application/json\")
  (with-open-file (s (merge-pathnames \"manifest.json\" *web-server-root*)
                     :direction :input)
    (let ((content (make-string (file-length s))))
      (read-sequence content s)
      content)))

(defun serve-service-worker ()
  "Serve the service worker JavaScript.

   Returns:
     JavaScript code"
  (setf (hunchentoot:content-type*) \"application/javascript\")
  (with-open-file (s (merge-pathnames \"sw.js\" *web-server-root*)
                     :direction :input)
    (let ((content (make-string (file-length s))))
      (read-sequence content s)
      content)))

(defun guess-content-type (file-path)
  "Guess content type from file extension.

   Args:
     file-path: Path to file

   Returns:
     MIME type string"
  (let ((ext (pathname-type file-path)))
    (cond
      ((string= ext \"css\") \"text/css\")
      ((string= ext \"js\") \"application/javascript\")
      ((string= ext \"json\") \"application/json\")
      ((string= ext \"html\") \"text/html\")
      ((string= ext \"png\") \"image/png\")
      ((string= ext \"jpg\") \"image/jpeg\")
      ((string= ext \"svg\") \"image/svg+xml\")
      (t \"application/octet-stream\"))))

;;; ============================================================================
;;; API Request Handlers
;;; ============================================================================

(defun handle-api-request (request)
  "Handle API requests.

   Args:
     request: Hunchentoot request object

   Returns:
     JSON response"
  (setf (hunchentoot:content-type*) \"application/json\")

  (let* ((uri (hunchentoot:request-uri request))
         (parts (cl-ppcre:split \"/\" uri)))
    (when (>= (length parts) 3)
      (let ((resource (elt parts 2)))
        (case (intern (string-upcase resource) :keyword)
          (:chats (api-list-chats request))
          (:messages (api-get-messages request))
          (:send (api-send-message request))
          (:media (handle-media-api-request request))
          (t
           (hunchentoot:return-code 400)
           \"{\\\"error\\\": \\\"Unknown resource\\\"}\"))))))

(defun api-list-chats (request)
  "List chats API endpoint.

   Args:
     request: Request object

   Returns:
     JSON array of chats"
  (declare (ignore request))
  (let ((chats (cl-telegram/api:list-cached-chats :limit 100)))
    (jonathan:json-write chats)))

(defun api-get-messages (request)
  "Get messages API endpoint.

   Args:
     request: Request object

   Returns:
     JSON array of messages"
  (let* ((uri (hunchentoot:request-uri request))
         (parts (cl-ppcre:split \"/\" uri))
         (chat-id (when (>= (length parts) 4) (elt parts 3))))
    (if chat-id
        (let ((messages (cl-telegram/api:get-cached-messages
                         (parse-integer chat-id :junk-allowed t)
                         :limit 50)))
          (jonathan:json-write messages))
        (progn
          (hunchentoot:return-code 400)
          \"{\\\"error\\\": \\\"Chat ID required\\\"}\"))))

(defun api-send-message (request)
  "Send message API endpoint.

   Args:
     request: Request object

   Returns:
     JSON response"
  (when (string= (hunchentoot:request-method request) :post)
    (let* ((body (hunchentoot:raw-post-data request :force-text t))
           (data (jonathan:json-read body))
           (chat-id (getf data :chat_id))
           (text (getf data :text)))
      (if (and chat-id text)
          (handler-case
              (let ((message (cl-telegram/api:send-message chat-id text)))
                (jonathan:json-write (list :success t :message message)))
            (error (e)
              (hunchentoot:return-code 500)
              (jonathan:json-write (list :success nil :error (princ-to-string e)))))
          (progn
            (hunchentoot:return-code 400)
            \"{\\\"error\\\": \\\"chat_id and text required\\\"}\")))))

;;; ============================================================================
;;; Media API Request Handlers
;;; ============================================================================

(defun handle-media-api-request (request)
  "Handle media API requests.

   Args:
     request: Hunchentoot request object

   Returns:
     Response based on sub-resource"
  (let* ((uri (hunchentoot:request-uri request))
         (parts (cl-ppcre:split "/" uri)))
    (when (>= (length parts) 4)
      (let ((sub-resource (elt parts 3))
            (file-id (when (>= (length parts) 5) (elt parts 4))))
        (cond
          ((string= sub-resource "thumb")
           (if file-id
               (handle-media-thumb-request file-id)
               (progn
                 (hunchentoot:return-code 400)
                 "{\"error\": \"File ID required\"}"))))
          ((string= sub-resource "download")
           (if file-id
               (handle-media-download-request file-id)
               (progn
                 (hunchentoot:return-code 400)
                 "{\"error\": \"File ID required\"}"))))
        (t
         (hunchentoot:return-code 400)
         "{\"error\": \"Unknown media resource\"}")))))

;;; ============================================================================
;;; WebSocket Server
;;; ============================================================================

(defun start-websocket-server (&key (port *web-server-port*))
  \"Start WebSocket server for real-time updates.

   Args:
     port: Port number

   Returns:
     T on success\"
  (handler-case
      (progn
        ;; Create WebSocket listener
        (setf *websocket-server*
              (usocket:socket-listen \"0.0.0.0\" port
                                     :reuseaddress t
                                     :element-type '(unsigned-byte 8)))

        ;; Start acceptor thread
        (bordeaux-threads:make-thread
         (lambda ()
           (websocket-acceptor-loop))
         :name \"websocket-acceptor\")

        (format t \"WebSocket server started on port ~A~%\" port)
        t)
    (error (e)
      (format *error-output* \"Failed to start WebSocket server: ~A~%\" e)
      nil)))

(defun websocket-acceptor-loop ()
  \"Main loop for accepting WebSocket connections.\"
  (loop
    (handler-case
        (let ((client (usocket:socket-accept *websocket-server*)))
          ;; Store client
          (setf (gethash (usocket:socket client) *websocket-clients*) client)

          ;; Handle client in new thread
          (bordeaux-threads:make-thread
           (lambda ()
             (websocket-client-handler client))
           :name \"websocket-client\"))
      (error (e)
        (format *error-output* \"WebSocket accept error: ~A~%\" e)))))

(defun websocket-client-handler (client)
  \"Handle WebSocket client communication.

   Args:
     client: Usocket client\"
  (unwind-protect
       (let ((stream (usocket:socket-stream client)))
         ;; WebSocket handshake and message loop
         (websocket-handshake-and-serve stream))
    (usocket:socket-close client)
    (remhash (usocket:socket client) *websocket-clients*)))

(defun websocket-handshake-and-serve (stream)
  \"Perform WebSocket handshake and serve messages.

   Args:
     stream: Client stream\"
  ;; Read HTTP upgrade request
  (let ((request-line (read-line stream nil nil)))
    (when (and request-line (search \"GET\" request-line))
      ;; Send upgrade response
      (send-websocket-upgrade stream)

      ;; Message loop
      (loop
        (let ((frame (read-websocket-frame stream)))
          (when frame
            (handle-websocket-message stream frame)))))))

(defun send-websocket-upgrade (stream)
  \"Send WebSocket upgrade response.

   Args:
     stream: Output stream\"
  (write-sequence
   (babel:string-to-octets
    \"HTTP/1.1 101 Switching Protocols\\r\\n
Upgrade: websocket\\r\\n
Connection: Upgrade\\r\\n
Sec-WebSocket-Accept: abc123\\r\\n
\\r\\n\")
   stream)
  (force-output stream))

(defun read-websocket-frame (stream)
  \"Read a WebSocket frame.

   Args:
     stream: Input stream

   Returns:
     Frame plist or NIL\"
  ;; Simplified - full implementation in websocket-client.lisp
  nil)

(defun handle-websocket-message (stream frame)
  \"Handle incoming WebSocket message.

   Args:
     stream: Client stream
     frame: Frame data\"
  ;; Echo back for now
  frame)

(defun broadcast-to-websocket-clients (message)
  \"Broadcast message to all connected WebSocket clients.

   Args:
     message: Message string\"
  (let ((octets (babel:string-to-octets message)))
    (maphash (lambda (key client)
               (declare (ignore key))
               (handler-case
                   (send-websocket-message client octets)
                 (error (e)
                   (format *error-output* \"Broadcast failed: ~A~%\" e))))
             *websocket-clients*)))

(defun send-websocket-message (client data)
  \"Send WebSocket message to client.

   Args:
     client: Usocket client
     data: Octet array\"
  (let ((stream (usocket:socket-stream client)))
    ;; Create and send WebSocket frame
    (write-sequence data stream)
    (force-output stream)))

;;; ============================================================================
;;; Integration with Update Handler
;;; ============================================================================

(defun enable-realtime-push ()
  \"Enable real-time push notifications to web clients.

   Returns:
     T on success\"
  ;; Register update handler
  (register-update-handler :update-new-message
    (lambda (update)
      (let ((json (jonathan:json-write update)))
        (broadcast-to-websocket-clients json))))

  (register-update-handler :update-message-edited
    (lambda (update)
      (let ((json (jonathan:json-write update)))
        (broadcast-to-websocket-clients json))))

  (register-update-handler :update-user-status
    (lambda (update)
      (let ((json (jonathan:json-write update)))
        (broadcast-to-websocket-clients json))))

  (register-update-handler :update-user-typing
    (lambda (update)
      (let ((json (jonathan:json-write update)))
        (broadcast-to-websocket-clients json))))

  (format t \"Real-time push enabled~%\")
  t)

(defun disable-realtime-push ()
  \"Disable real-time push notifications.

   Returns:
     T on success\"
  (clear-update-handlers :update-new-message)
  (clear-update-handlers :update-message-edited)
  (clear-update-handlers :update-user-status)
  (clear-update-handlers :update-user-typing)
  (format t \"Real-time push disabled~%\")
  t)

;;; ============================================================================
;;; Main Entry Point
;;; ============================================================================

(defun run-web-server (&key (port *web-server-port*)
                            (host *web-server-host*)
                            (use-hunchentoot t))
  \"Run the cl-telegram web server.

   Args:
     port: Port number (default: 8080)
     host: Host to bind (default: 0.0.0.0)
     use-hunchentoot: Whether to use Hunchentoot HTTP server

   Returns:
     T on success

   Example:
     (run-web-server :port 3000)\"
  (setf *web-server-port* port)
  (setf *web-server-host* host)

  (if use-hunchentoot
      ;; Use Hunchentoot
      (progn
        (hunchentoot:start
         (make-instance 'hunchentoot:easy-acceptor
                        :port port
                        :address host
                        :document-root *web-server-root*))

        (format t \"cl-telegram Web UI started at http://~A:~A~%\" host port)
        (format t \"Press Ctrl+C to stop~%\")

        t)
      ;; Use custom server (TODO)
      (format *error-output* \"Custom server not implemented yet~%\")))

(defun stop-web-server ()
  \"Stop the web server.

   Returns:
     T on success\"
  (handler-case
      (hunchentoot:stop *)
    (error () nil))

  (when *websocket-server*
    (usocket:socket-close *websocket-server*)
    (setf *websocket-server* nil))

  (format t \"Web server stopped~%\")
  t)

;;; ============================================================================
;;; REPL Convenience Functions
;;; ============================================================================

(defun open-web-ui-in-browser (&key (port *web-server-port*))
  \"Open the web UI in default browser.

   Args:
     port: Port number

   Returns:
     T on success\"
  (let ((url (format nil \"http://localhost:~A\" port)))
    #+linux (uiop:run-program (list \"xdg-open\" url))
    #+macos (uiop:run-program (list \"open\" url))
    #+windows (uiop:run-program (list \"cmd\" \"/c\" \"start\" url))
    (format t \"Opening ~A in browser...~%\" url)
    t))

;;; ============================================================================
;;; End of web-server.lisp
;;; ============================================================================
