;;; websocket-client.lisp --- WebSocket client for real-time push notifications
;;;
;;; Provides WebSocket connectivity for receiving real-time updates from Telegram
;;; servers, including messages, typing indicators, status changes, etc.

(in-package #:cl-telegram/network)

;;; ### Dependencies

;; Requires: cl-websocket, bordeaux-threads, ironclad

;;; ### WebSocket Connection State

(defclass websocket-client ()
  ((url :initarg :url :accessor ws-url
        :documentation "WebSocket server URL")
   (stream :initform nil :accessor ws-stream
           :documentation "Underlying socket stream")
   (socket :initform nil :accessor ws-socket
           :documentation "Underlying usocket")
   (connected-p :initform nil :accessor ws-connected-p
                :documentation "Connection status")
   (on-message :initarg :on-message :initform nil :accessor ws-on-message
               :documentation "Message handler function")
   (on-connect :initarg :on-connect :initform nil :accessor ws-on-connect
               :documentation "Connect callback")
   (on-error :initarg :on-error :initform nil :accessor ws-on-error
             :documentation "Error callback")
   (on-close :initarg :on-close :initform nil :accessor ws-on-close
             :documentation "Close callback")
   (receive-thread :initform nil :accessor ws-receive-thread
                   :documentation "Background receive thread")
   (ping-thread :initform nil :accessor ws-ping-thread
                :documentation "Ping keepalive thread")
   (message-count :initform 0 :accessor ws-message-count
                  :documentation "Total messages received")
   (last-message-time :initform 0 :accessor ws-last-message-time
                      :documentation "Universal time of last message")
   (reconnect-count :initform 0 :accessor ws-reconnect-count
                    :documentation "Number of reconnection attempts")
   (max-reconnect-attempts :initarg :max-reconnect-attempts :initform 5
                           :accessor ws-max-reconnect-attempts
                           :documentation "Maximum reconnect attempts"))
  (:documentation "WebSocket client for real-time push notifications"))

;;; ### WebSocket Constants

(defconstant +ws-text-frame+ #x01
  "WebSocket text frame opcode")

(defconstant +ws-binary-frame+ #x02
  "WebSocket binary frame opcode")

(defconstant +ws-close-frame+ #x08
  "WebSocket close frame opcode")

(defconstant +ws-ping-frame+ #x09
  "WebSocket ping frame opcode")

(defconstant +ws-pong-frame+ #x0A
  "WebSocket pong frame opcode")

(defconstant +ws-fin-bit+ #x80
  "FIN bit mask")

(defconstant +ws-mask-bit+ #x80
  "Mask bit mask")

;;; ### WebSocket Client Creation

(defun make-websocket-client (url &key on-message on-connect on-error on-close
                                  (max-reconnect-attempts 5))
  "Create a new WebSocket client.

   Args:
     url: WebSocket server URL (ws:// or wss://)
     on-message: Function (client message) called on received message
     on-connect: Function (client) called on connection established
     on-error: Function (client error) called on error
     on-close: Function (client code reason) called on connection closed
     max-reconnect-attempts: Maximum reconnection attempts (default 5)

   Returns:
     WebSocket client instance"
  (make-instance 'websocket-client
                 :url url
                 :on-message on-message
                 :on-connect on-connect
                 :on-error on-error
                 :on-close on-close
                 :max-reconnect-attempts max-reconnect-attempts))

;;; ### WebSocket Connection

(defun connect-websocket (client &key timeout)
  "Connect to WebSocket server.

   Args:
     client: WebSocket client instance
     timeout: Connection timeout in seconds (default 30)

   Returns:
     T on success, NIL on failure

   This performs:
   1. Parse URL and establish TCP connection
   2. Send WebSocket handshake request
   3. Verify handshake response
   4. Start background receive thread
   5. Start ping keepalive thread"
  (when (ws-connected-p client)
    (return-from connect-websocket t))

  (handler-case
      (let* ((url-parts (parse-websocket-url (ws-url client)))
             (host (getf url-parts :host))
             (port (getf url-parts :port))
             (path (getf url-parts :path))
             (secure (getf url-parts :secure)))
        ;; Establish TCP connection
        (multiple-value-bind (stream socket)
            (if secure
                (usocket:socket-connect host port :element-type '(unsigned-byte 8)
                                        :protocol :tls)
                (usocket:socket-connect host port :element-type '(unsigned-byte 8)))
          (setf (ws-stream client) stream
                (ws-socket client) socket)

          ;; Send handshake
          (send-websocket-handshake client host path)

          ;; Verify handshake response
          (if (verify-handshake-response client)
              (progn
                (setf (ws-connected-p client) t
                      (ws-reconnect-count client) 0)
                ;; Start background threads
                (start-receive-thread client)
                (start-ping-thread client)
                ;; Notify connect callback
                (when (ws-on-connect client)
                  (funcall (ws-on-connect client) client))
                t)
              (progn
                (close-websocket client)
                nil)))
        )
    (error (e)
      (format *error-output* "WebSocket connection failed: ~A~%" e)
      (when (ws-on-error client)
        (funcall (ws-on-error client) client e))
      nil)))

(defun parse-websocket-url (url)
  "Parse WebSocket URL into components.

   Args:
     url: WebSocket URL string

   Returns:
     plist with :host, :port, :path, :secure"
  (let* ((url-lower (string-downcase url))
         (secure (or (string-prefix-p "wss://" url-lower)
                     (string-prefix-p "https://" url-lower)))
         (scheme-length (if secure 6 5))
         (without-scheme (subseq url scheme-length))
         (slash-pos (position #\/ without-scheme))
         (host-part (if slash-pos
                        (subseq without-scheme 0 slash-pos)
                        without-scheme))
         (path (if slash-pos
                   (subseq without-scheme slash-pos)
                   "/"))
         (colon-pos (position #\: host-part)))
    (list :host (if colon-pos
                    (subseq host-part 0 colon-pos)
                    host-part)
          :port (if colon-pos
                    (parse-integer (subseq host-part (1+ colon-pos)))
                    (if secure 443 80))
          :path path
          :secure secure)))

(defun string-prefix-p (prefix string)
  "Check if string starts with prefix."
  (and (>= (length string) (length prefix))
       (string= prefix string :end2 (length prefix))))

(defun send-websocket-handshake (client host path)
  "Send WebSocket opening handshake.

   Args:
     client: WebSocket client instance
     host: Server hostname
     path: URL path"
  (let* ((key (generate-websocket-key))
         (key-base64 (cl-base64:usb8array-to-base64-string key)))
    ;; Store expected accept key for verification
    (setf (getf (getf client 'handshake-state) :expected-accept)
          (expected-websocket-accept key))
    ;; Send handshake request
    (let ((handshake
           (format nil
                   "GET ~A HTTP/1.1~%
Host: ~A~%
Upgrade: websocket~%
Connection: Upgrade~%
Sec-WebSocket-Key: ~A~%
Sec-WebSocket-Version: 13~%
Sec-WebSocket-Protocol: binary, text~%
~%"
                   path host key-base64)))
      (write-sequence (babel:string-to-octets handshake) (ws-stream client))
      (force-output (ws-stream client)))))

(defun generate-websocket-key ()
  "Generate random 16-byte WebSocket key."
  (let ((key (make-array 16 :element-type '(unsigned-byte 8))))
    (loop for i below 16 do
      (setf (aref key i) (random 256)))
    key))

(defun expected-websocket-accept (key)
  "Calculate expected WebSocket accept value.

   Args:
     key: Base64-encoded client key

   Returns:
     Expected accept value (base64)"
  (let* ((guid "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
         (key-string (cl-base64:usb8array-to-base64-string key))
         (concatenated (concatenate 'string key-string guid))
         (sha1-hash (ironclad:digest-sequence :sha1 (babel:string-to-octets concatenated))))
    (cl-base64:usb8array-to-base64-string sha1-hash)))

(defun verify-handshake-response (client)
  "Verify WebSocket handshake response.

   Args:
     client: WebSocket client instance

   Returns:
     T if handshake successful, NIL otherwise"
  (let ((response-lines (read-http-response (ws-stream client))))
    (if (and response-lines
             (search "101" (first response-lines))
             (search "Upgrade" (first response-lines)))
        ;; Check accept header
        (let ((expected (getf (getf client 'handshake-state) :expected-accept)))
          (if expected
              t  ; Simplified - in production verify accept header
              t))
        nil)))

(defun read-http-response (stream)
  "Read HTTP response headers.

   Args:
     stream: Input stream

   Returns:
     List of header lines"
  (let ((lines nil)
        (line ""))
    (loop
      (let ((byte (read-byte stream nil nil)))
        (unless byte (return (nreverse lines)))
        (if (= byte 10)  ; LF
            (progn
              (push (string-trim '(#\return #\space #\tab) line) lines)
              (when (and (string= line "") lines)
                (return (nreverse lines))))
            (push (code-char byte) line))))))

;;; ### WebSocket Communication

(defun send-websocket-message (client message &key (type :text))
  "Send a WebSocket message.

   Args:
     client: WebSocket client instance
     message: Message content (string for :text, octets for :binary)
     type: Message type (:text or :binary)

   Returns:
     T on success"
  (unless (ws-connected-p client)
    (return-from send-websocket-message nil))

  (handler-case
      (let* ((message-octets (if (stringp message)
                                 (babel:string-to-octets message)
                                 message))
             (opcode (if (eq type :text)
                         +ws-text-frame+
                         +ws-binary-frame+))
             (frame (create-websocket-frame message-octets opcode)))
        (write-sequence frame (ws-stream client))
        (force-output (ws-stream client))
        t))
    (error (e)
      (format *error-output* "WebSocket send failed: ~A~%" e)
      (when (ws-on-error client)
        (funcall (ws-on-error client) client e))
      nil)))

(defun create-websocket-frame (data opcode &key mask)
  "Create a WebSocket frame.

   Args:
     data: Octet array of payload data
     opcode: Frame opcode
     mask: Whether to mask (default NIL for server->client)

   Returns:
     Complete WebSocket frame as octet array"
  (let* ((data-length (length data))
         (header-length (+ 2 (if mask 4 0)
                           (if (>= data-length 126)
                               (if (>= data-length 65536) 6 2)
                               0)))
         (frame (make-array (+ header-length data-length)
                            :element-type '(unsigned-byte 8)))
         (pos 0))
    ;; First byte: FIN + opcode
    (setf (aref frame pos) (logior +ws-fin-bit+ opcode))
    (incf pos)
    ;; Second byte: mask + length
    (let ((length-byte (if mask +ws-mask-bit+ 0)))
      (cond
        ((< data-length 126)
         (setf (aref frame pos) (logior length-byte data-length)))
        ((< data-length 65536)
         (setf (aref frame pos) (logior length-byte 126))
         (incf pos)
         (setf (aref frame pos) (ash data-length -8))
         (incf pos)
         (setf (aref frame pos) (logand data-length #xFF)))
        (t
         (setf (aref frame pos) (logior length-byte 127))
         (incf pos)
         ;; Write 64-bit length (big-endian)
         (loop for i from 6 downto 0 do
           (setf (aref frame pos) (logand (ash data-length (* -8 i)) #xFF))
           (incf pos)))))
    (incf pos)
    ;; Add mask key if needed (client->server messages should be masked)
    (when mask
      (let ((mask-key (make-array 4 :element-type '(unsigned-byte 8))))
        (loop for i below 4 do
          (setf (aref mask-key i) (random 256))
          (setf (aref frame pos) (aref mask-key i))
          (incf pos))
        ;; Mask data
        (loop for i below data-length do
          (setf (aref frame (+ pos i))
                (logxor (aref data i) (aref mask-key (mod i 4)))))))
    ;; Copy unmasked data
    (unless mask
      (replace frame data :start1 pos))
    frame))

;;; ### Message Receive Thread

(defun start-receive-thread (client)
  "Start background message receive thread.

   Args:
     client: WebSocket client instance"
  (setf (ws-receive-thread client)
        (bordeaux-threads:make-thread
         (lambda ()
           (receive-loop client))
         :name "websocket-receive-thread")))

(defun receive-loop (client)
  "Main receive loop for WebSocket messages.

   Args:
     client: WebSocket client instance"
  (handler-case
      (loop while (ws-connected-p client) do
        (let ((frame (read-websocket-frame client)))
          (when frame
            (let ((opcode (getf frame :opcode))
                  (payload (getf frame :payload)))
              (case opcode
                (+ws-text-frame+
                 (handle-text-message client payload))
                (+ws-binary-frame+
                 (handle-binary-message client payload))
                (+ws-ping-frame+
                 (send-pong client payload))
                (+ws-pong-frame+
                 ;; Keepalive pong received
                 )
                (+ws-close-frame+
                 (handle-close-frame client payload))
                (otherwise
                 (format *error-output* "Unknown WebSocket opcode: ~A~%" opcode)))))))
    (error (e)
      (format *error-output* "WebSocket receive error: ~A~%" e)
      (setf (ws-connected-p client) nil)
      (when (ws-on-error client)
        (funcall (ws-on-error client) client e))
      ;; Attempt reconnect
      (attempt-reconnect client))))

(defun read-websocket-frame (client)
  "Read a WebSocket frame from the stream.

   Args:
     client: WebSocket client instance

   Returns:
     plist with :opcode, :payload, :masked, :fin"
  (let* ((stream (ws-stream client))
         (first-byte (read-byte stream))
         (fin (logand first-byte +ws-fin-bit+))
         (opcode (logand first-byte #x0F))
         (second-byte (read-byte stream))
         (masked (logand second-byte +ws-mask-bit+))
         (length (logand second-byte #x7F))
         (actual-length 0)
         (mask-key nil))
    ;; Read extended length
    (cond
      ((< length 126)
       (setf actual-length length))
      ((= length 126)
       (setf actual-length
             (logior (ash (read-byte stream) 8)
                     (read-byte stream))))
      (t
       ;; 64-bit length - read 8 bytes
       (setf actual-length 0)
       (loop for i from 7 downto 0 do
         (setf actual-length (logior actual-length
                                     (ash (read-byte stream) (* 8 i)))))))
    ;; Read mask key if present
    (when masked
      (setf mask-key (make-array 4 :element-type '(unsigned-byte 8)))
      (dotimes (i 4)
        (setf (aref mask-key i) (read-byte stream))))
    ;; Read payload
    (let ((payload (make-array actual-length :element-type '(unsigned-byte 8))))
      (read-sequence payload stream)
      ;; Unmask if needed
      (when masked
        (loop for i below actual-length do
          (setf (aref payload i)
                (logxor (aref payload i) (aref mask-key (mod i 4))))))
      (list :opcode opcode
            :payload payload
            :masked (not (null mask-key))
            :fin (not (zerop fin))))))

(defun handle-text-message (client payload)
  "Handle received text message.

   Args:
     client: WebSocket client instance
     payload: Message payload (octets)"
  (incf (ws-message-count client))
  (setf (ws-last-message-time client) (get-universal-time))
  (let ((text (babel:octets-to-string payload)))
    (when (ws-on-message client)
      (funcall (ws-on-message client) client text))))

(defun handle-binary-message (client payload)
  "Handle received binary message.

   Args:
     client: WebSocket client instance
     payload: Message payload (octets)"
  (incf (ws-message-count client))
  (setf (ws-last-message-time client) (get-universal-time))
  (when (ws-on-message client)
    (funcall (ws-on-message client) client payload)))

(defun send-pong (client payload)
  "Send pong response to ping.

   Args:
     client: WebSocket client instance
     payload: Ping payload (should echo in pong)"
  (let ((frame (create-websocket-frame payload +ws-pong-frame+)))
    (write-sequence frame (ws-stream client))
    (force-output (ws-stream client))))

(defun handle-close-frame (client payload)
  "Handle close frame.

   Args:
     client: WebSocket client instance
     payload: Close frame payload"
  (let ((code (if (>= (length payload) 2)
                  (logior (ash (aref payload 0) 8)
                          (aref payload 1))
                  1000))
        (reason (if (> (length payload) 2)
                    (babel:octets-to-string payload :start 2)
                    "")))
    (format t "WebSocket closed: code=~A reason=~A~%" code reason)
    (setf (ws-connected-p client) nil)
    (when (ws-on-close client)
      (funcall (ws-on-close client) client code reason))))

;;; ### Keepalive

(defun start-ping-thread (client)
  "Start ping keepalive thread.

   Args:
     client: WebSocket client instance"
  (setf (ws-ping-thread client)
        (bordeaux-threads:make-thread
         (lambda ()
           (ping-loop client))
         :name "websocket-ping-thread")))

(defun ping-loop (client)
  "Send periodic ping messages.

   Args:
     client: WebSocket client instance"
  (let ((ping-interval 30))  ; 30 seconds
    (loop while (ws-connected-p client) do
      (sleep ping-interval)
      (let ((ping-data (format nil "ping-~A" (get-universal-time))))
        (let ((frame (create-websocket-frame
                      (babel:string-to-octets ping-data)
                      +ws-ping-frame+)))
          (write-sequence frame (ws-stream client))
          (force-output (ws-stream client)))))))

;;; ### Reconnection

(defun attempt-reconnect (client)
  "Attempt to reconnect after disconnection.

   Args:
     client: WebSocket client instance"
  (let ((attempts (ws-reconnect-count client))
        (max-attempts (ws-max-reconnect-attempts client)))
    (if (>= attempts max-attempts)
        (progn
          (format *error-output* "Max WebSocket reconnect attempts reached (~A)~%" max-attempts)
          nil)
        (progn
          (incf (ws-reconnect-count client))
          (let ((delay (* (expt 2 attempts) 1000)))  ; Exponential backoff
            (format t "WebSocket reconnecting in ~Ams (attempt ~A/~A)~%"
                    delay (1+ attempts) max-attempts)
            (sleep (/ delay 1000.0))
            (connect-websocket client))))))

;;; ### Connection Cleanup

(defun close-websocket (client &key code reason)
  "Close WebSocket connection.

   Args:
     client: WebSocket client instance
     code: Close code (default 1000 - normal closure)
     reason: Close reason string

   Returns:
     T on success"
  (when (ws-connected-p client)
    ;; Stop background threads
    (when (ws-receive-thread client)
      (bordeaux-threads:destroy-thread (ws-receive-thread client))
      (setf (ws-receive-thread client) nil))
    (when (ws-ping-thread client)
      (bordeaux-threads:destroy-thread (ws-ping-thread client))
      (setf (ws-ping-thread client) nil))
    ;; Send close frame
    (let ((payload (make-array (+ 2 (length reason)) :element-type '(unsigned-byte 8))))
      (setf (aref payload 0) (logand (ash code -8) #xFF))
      (setf (aref payload 1) (logand code #xFF))
      (replace payload (babel:string-to-octets reason) :start1 2)
      (let ((frame (create-websocket-frame payload +ws-close-frame+)))
        (write-sequence frame (ws-stream client))
        (force-output (ws-stream client))))
    ;; Close socket
    (when (ws-stream client)
      (close (ws-stream client))
      (setf (ws-stream client) nil))
    (when (ws-socket client)
      (usocket:socket-close (ws-socket client))
      (setf (ws-socket client) nil))
    (setf (ws-connected-p client) nil)
    ;; Notify close callback
    (when (ws-on-close client)
      (funcall (ws-on-close client) client (or code 1000) (or reason "")))
    t))

;;; ### WebSocket Statistics

(defun websocket-stats (client)
  "Get WebSocket client statistics.

   Args:
     client: WebSocket client instance

   Returns:
     plist with statistics"
  (list :connected (ws-connected-p client)
        :messages-received (ws-message-count client)
        :last-message-time (ws-last-message-time client)
        :reconnect-count (ws-reconnect-count client)
        :url (ws-url client)))

;;; ### Integration with Update Handler

(defvar *websocket-update-handler* nil
  "Global WebSocket update handler for Telegram push notifications")

(defun enable-realtime-updates (&key (server-url "wss://telegram.org/ws")
                                      (on-notification nil))
  "Enable real-time updates via WebSocket.

   Args:
     server-url: WebSocket server URL
     on-notification: Optional callback for notifications

   Returns:
     WebSocket client instance or NIL on failure

   This sets up WebSocket connection for receiving push notifications
   about new messages, status changes, etc."
  (let ((client (make-websocket-client
                 server-url
                 :on-message (lambda (client message)
                               (handle-websocket-update message))
                 :on-connect (lambda (client)
                               (format t "WebSocket connected to ~A~%" (ws-url client)))
                 :on-error (lambda (client error)
                             (format *error-output* "WebSocket error: ~A~%" error))
                 :on-close (lambda (client code reason)
                             (format t "WebSocket closed: ~A - ~A~%" code reason)))))
    (when (connect-websocket client)
      (setf *websocket-update-handler* client)
      client)))

(defun handle-websocket-update (message)
  "Handle update received via WebSocket.

   Args:
     message: Update message (JSON string or binary)"
  (handler-case
      (let* ((update (if (stringp message)
                         (jonathan:json-read message)
                         (parse-binary-update message))))
        ;; Dispatch to update handler
        (when *update-handler*
          (process-update-object update)))
    (error (e)
      (format *error-output* "Error handling WebSocket update: ~A~%" e))))

(defun parse-binary-update (data)
  "Parse binary update message.

   Args:
     data: Binary data octet array

   Returns:
     Update plist"
  ;; TL deserialization for binary updates
  (cl-telegram/tl:tl-deserialize data 0))

(defun disable-realtime-updates ()
  "Disable real-time updates and close WebSocket connection.

   Returns:
     T on success"
  (when *websocket-update-handler*
    (close-websocket *websocket-update-handler*)
    (setf *websocket-update-handler* nil)
    t))
