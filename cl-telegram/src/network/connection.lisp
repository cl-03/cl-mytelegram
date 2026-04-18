;;; connection.lisp --- Connection management

(in-package #:cl-telegram/network)

;;; ### Connection Class

(defclass connection ()
  ((session-id :initarg :session-id :accessor conn-session-id
               :documentation "8-byte session ID")
   (seqno :initarg :seqno :initform 0 :accessor conn-seqno
          :documentation "Sequence number for messages")
   (last-msg-id :initarg :last-msg-id :initform 0 :accessor conn-last-msg-id
                 :documentation "Last message ID sent")
   (server-salt :initarg :server-salt :initform nil :accessor conn-server-salt
                :documentation "Server salt for message ID generation")
   (auth-key :initarg :auth-key :initform nil :accessor conn-auth-key
             :documentation "Authorization key (256 bytes)")
   (auth-key-id :initarg :auth-key-id :initform nil :accessor conn-auth-key-id
                :documentation "First 8 bytes of SHA256(auth_key)")
   (tcp-client :initarg :tcp-client :initform nil :accessor conn-tcp-client
               :documentation "Underlying TCP client")
   (pending-requests :initform (make-hash-table) :accessor conn-pending-requests
                     :documentation "Pending RPC requests by msg-id")
   (event-handlers :initform nil :accessor conn-event-handlers
                   :documentation "List of event handler functions"))
  (:documentation "MTProto connection with state management"))

;;; ### Connection Creation

(defun make-connection (&key host (port 443) auth-key)
  "Create a new MTProto connection.

   Args:
     host: Telegram server hostname
     port: Server port (default 443)
     auth-key: Optional authorization key (256 bytes)

   Returns:
     New connection instance"
  (let* ((session-id (generate-session-id))
         (tcp-client (make-tcp-client host port
                                      :on-connect #'on-connected
                                      :on-data #'on-data-received
                                      :on-error #'on-error-occurred
                                      :on-disconnect #'on-disconnected))
         (conn (make-instance 'connection
                              :session-id session-id
                              :auth-key auth-key
                              :tcp-client tcp-client)))
    ;; Compute auth-key-id if auth-key is set
    (when auth-key
      (setf (conn-auth-key-id conn)
            (cl-telegram/mtproto:compute-auth-key-id auth-key)))
    conn))

(defun generate-session-id ()
  "Generate a random 64-bit session ID."
  (let ((session-id (make-array 8 :element-type '(unsigned-byte 8))))
    (loop for i below 8 do
      (setf (aref session-id i) (random 256)))
    session-id))

;;; ### Connection Lifecycle

(defun connect (conn)
  "Establish connection to Telegram server.

   Args:
     conn: Connection instance

   Returns:
     T if connection initiated successfully"
  (client-connect (conn-tcp-client conn)))

(defun disconnect (conn)
  "Close the connection.

   Args:
     conn: Connection instance"
  ;; Cancel pending requests
  (loop for msg-id being the hash-keys of (conn-pending-requests conn) do
    (let ((promise (gethash msg-id (conn-pending-requests conn))))
      (setf (cdr promise) :cancelled)))
  (clrhash (conn-pending-requests conn))
  ;; Disconnect TCP
  (client-disconnect (conn-tcp-client conn)))

(defun connected-p (conn)
  "Check if connection is active."
  (client-connected-p (conn-tcp-client conn)))

(defun reconnect (conn &key (delay 1000))
  "Reconnect after a delay.

   Args:
     conn: Connection instance
     delay: Delay in milliseconds"
  (client-reconnect (conn-tcp-client conn) :delay delay))

;;; ### Message Sending

(defun connection-send (conn message)
  "Send an encrypted MTProto message.

   Args:
     conn: Connection instance
     message: Complete transport packet bytes

   Returns:
     T if send successful"
  (unless (connected-p conn)
    (error "Connection not established"))
  (client-send (conn-tcp-client conn) message))

(defun connection-send-rpc (conn request-body &key timeout)
  "Send an RPC request and wait for response.

   Args:
     conn: Connection instance
     request-body: Serialized TL request
     timeout: Timeout in milliseconds (default 30000)

   Returns:
     RPC response TL object"
  (let* ((msg-id (generate-msg-id conn))
         (seqno (get-and-incf-seqno conn))
         (promise (cons nil nil))  ; (value . done-p)
         (timeout (or timeout 30000)))
    ;; Store pending request
    (setf (gethash msg-id (conn-pending-requests conn)) promise)
    ;; Build and send message
    (let* ((rpc-message (cl-telegram/mtproto:make-rpc-request
                         (conn-session-id conn) msg-id request-body))
           (multiple-value-bind (encrypted msg-key)
               (cl-telegram/mtproto:encrypt-message (conn-auth-key conn) rpc-message
                                                    :from-client t)
             (let ((packet (cl-telegram/mtproto:make-transport-packet
                            (conn-auth-key-id conn) msg-key encrypted)))
               (connection-send conn packet))))
    ;; Wait for response
    (loop with start = (get-universal-time)
          with timeout-sec = (/ timeout 1000)
          for elapsed = (- (get-universal-time) start)
          while (not (cdr promise))
          while (< elapsed timeout-sec)
          do (sleep 0.01)
          finally (return
                    (if (cdr promise)
                        (if (eq (car promise) :cancelled)
                            (error "Request cancelled"))
                        (car promise)
                        (error "Request timeout")))))))

(defun generate-msg-id (conn)
  "Generate a unique message ID.

   MTProto message ID format:
   - Bits 0-2: ignored (set to 0)
   - Bits 3-59: Unix time in milliseconds
   - Bits 60-61: message type (01 for client, 10 for server)
   - Bit 62-63: set to 0

   Args:
     conn: Connection instance

   Returns:
     64-bit message ID integer"
  (let* ((salt (or (conn-server-salt conn) 0))
         (now (* (get-universal-time) 1000))  ; Convert to milliseconds
         ;; Add some randomness to lower bits
         (random-bits (random 1000))
         (msg-id (logior (ash now 3) random-bits #b01)))
    (declare (ignore salt))  ; Salt used for server messages
    (setf (conn-last-msg-id conn) msg-id)
    msg-id))

(defun get-and-incf-seqno (conn)
  "Get current sequence number and increment.

   Seqno rules:
   - Start at 0
   - Increment by 1 for each message
   - Increment by 2 for certain message types

   Returns:
     Current seqno (before increment)"
  (let ((seqno (conn-seqno conn)))
    (setf (conn-seqno conn) (+ seqno 1))
    seqno))

;;; ### Message Receiving

(defun on-data-received (client data)
  "Handle received data from TCP client.

   Args:
     client: TCP client that received data
     data: Byte array of received data"
  (let ((conn (find-connection-for-client client)))
    (when conn
      (handle-incoming-packet conn data))))

(defun handle-incoming-packet (conn packet)
  "Process an incoming MTProto transport packet.

   Args:
     conn: Connection instance
     packet: Complete transport packet bytes"
  (handler-case
      (multiple-value-bind (auth-key-id msg-key encrypted-data)
          (cl-telegram/mtproto:parse-transport-packet packet)
        (declare (ignore auth-key-id))
        ;; Decrypt message
        (let ((decrypted (cl-telegram/mtproto:decrypt-message
                          (conn-auth-key conn) msg-key encrypted-data
                          :from-client nil)))
          ;; Parse message header
          (let ((msg-id (cl-telegram/tl:deserialize-int64 decrypted 0))
                (seqno (cl-telegram/tl:deserialize-int32 decrypted 8))
                (length (cl-telegram/tl:deserialize-int32 decrypted 12))
                (body (subseq decrypted 16)))
            (declare (ignore seqno))
            ;; Handle based on message type
            (handle-message-body conn msg-id length body))))
    (error (e)
      (format *error-output* "Error handling packet: ~A~%" e))))

(defun handle-message-body (conn msg-id length body)
  "Handle decrypted message body.

   Args:
     conn: Connection instance
     msg-id: Message ID
     length: Body length
     body: Message body bytes"
  (let ((constructor (cl-telegram/tl:deserialize-int32 body 0)))
    (cond
      ;; RPC Result
      ((= constructor #xf35c6d01)  ; rpc_result
       (handle-rpc-result conn msg-id body))
      ;; RPC Error
      ((= constructor #x2144ca19)  ; rpc_error
       (handle-rpc-error conn msg-id body))
      ;; Message Container (multiple messages)
      ((= constructor #x73f1f8dc)  ; msg_container
       (handle-msg-container conn msg-id body))
      ;; Gzip Packed
      ((= constructor #x3072cfa1)  ; gzip_packed
       (handle-gzip-packed conn msg-id body))
      ;; Bad Server Salt
      ((= constructor #xedab447b)
       (handle-bad-server-salt conn msg-id body))
      ;; Bad Msg Notification
      ((= constructor #xa7eff811)
       (handle-bad-msg-notification conn msg-id body))
      ;; New Session Created
      ((= constructor #x9ec20908)
       (handle-new-session conn msg-id body))
      ;; Updates (various types)
      (t
       (handle-update conn msg-id body)))))

(defun handle-rpc-result (conn msg-id body)
  "Handle RPC result response.

   rpc_result#f35c6d01 req_msg_id:long result:string"
  (let ((req-msg-id (cl-telegram/tl:deserialize-int64 body 4)))
    (let ((promise (gethash req-msg-id (conn-pending-requests conn))))
      (when promise
        ;; Parse result
        (let ((result (cl-telegram/tl:tl-deserialize body 12)))
          (setf (car promise) result
                (cdr promise) t))
        ;; Remove from pending
        (remhash req-msg-id (conn-pending-requests conn))))))

(defun handle-rpc-error (conn msg-id body)
  "Handle RPC error response.

   rpc_error#2144ca19 error_code:int error_message:string"
  (let ((req-msg-id (cl-telegram/tl:deserialize-int64 body 4))
        (error-code (cl-telegram/tl:deserialize-int32 body 12))
        (error-message (cl-telegram/tl:deserialize-string body 16)))
    (let ((promise (gethash req-msg-id (conn-pending-requests conn))))
      (when promise
        (setf (car promise) (list :error error-code error-message)
              (cdr promise) t))
      (remhash req-msg-id (conn-pending-requests conn)))
    ;; Notify event handlers
    (notify-event-handlers conn :error (list :code error-code :message error-message))))

(defun handle-msg-container (conn msg-id body)
  "Handle message container (multiple messages in one packet).

   msg_container#73f1f8dc messages:vector<Message>"
  (let ((count (cl-telegram/tl:deserialize-int32 body 4)))
    (declare (ignore count))
    ;; Parse each message in container
    ;; TODO: Implement full container parsing
    ))

(defun handle-gzip-packed (conn msg-id body)
  "Handle gzip-packed message.

   gzip_packed#3072cfa1 packed_data:string"
  ;; TODO: Decompress and handle
  (declare (ignore conn msg-id body)))

(defun handle-bad-server-salt (conn msg-id body)
  "Handle bad_server_salt notification.

   bad_server_salt#edab447b bad_msg_id:long bad_msg_seqno:int error_code:int new_server_salt:long"
  (let ((new-salt (cl-telegram/tl:deserialize-int64 body 20)))
    (setf (conn-server-salt conn) new-salt)
    ;; TODO: Retry the failed message with new salt
    ))

(defun handle-bad-msg-notification (conn msg-id body)
  "Handle bad_msg_notification.

   bad_msg_notification#a7eff811 bad_msg_id:long bad_msg_seqno:int error_code:int"
  (let ((error-code (cl-telegram/tl:deserialize-int32 body 20)))
    (format *error-output* "Bad msg notification: error_code=~D~%" error-code)))

(defun handle-new-session (conn msg-id body)
  "Handle new_session_created.

   new_session_created#9ec20908 first_msg_id:long unique_id:long server_salt:long"
  (let ((server-salt (cl-telegram/tl:deserialize-int64 body 24)))
    (setf (conn-server-salt conn) server-salt)))

(defun handle-update (conn msg-id body)
  "Handle an update (notification from server).

   Args:
     conn: Connection instance
     msg-id: Message ID
     body: Update body bytes"
  ;; Parse update type and notify handlers
  (handler-case
      (let ((update (cl-telegram/tl:tl-deserialize body 4)))
        (notify-event-handlers conn :update update))
    (error () nil)))

;;; ### Event Handlers

(defun set-event-handler (conn event-type handler)
  "Register an event handler.

   Args:
     conn: Connection instance
     event-type: Keyword (:update, :error, :connected, :disconnected)
     handler: Function to call with event data"
  (push (cons event-type handler) (conn-event-handlers conn)))

(defun remove-event-handler (conn handler)
  "Remove an event handler."
  (setf (conn-event-handlers conn)
        (remove handler (conn-event-handlers conn) :key #'cdr)))

(defun notify-event-handlers (conn event-type data)
  "Notify all registered event handlers."
  (loop for (type . handler) in (conn-event-handlers conn)
        when (eq type event-type)
        do (handler-case
               (funcall handler data)
             (error (e)
               (format *error-output* "Event handler error: ~A~%" e)))))

;;; ### Connection Lookup

(defvar *connections* (make-hash-table)
  "Global registry of connections by TCP client.")

(defun register-connection (conn)
  "Register a connection in the global registry."
  (setf (gethash (conn-tcp-client conn) *connections*) conn))

(defun unregister-connection (conn)
  "Unregister a connection."
  (remhash (conn-tcp-client conn) *connections*))

(defun find-connection-for-client (tcp-client)
  "Find connection by TCP client."
  (gethash tcp-client *connections*))

;;; ### TCP Client Callbacks

(defun on-connected (client)
  "Called when TCP connection is established."
  (let ((conn (find-connection-for-client client)))
    (when conn
      (notify-event-handlers conn :connected nil))))

(defun on-error-occurred (client error)
  "Called when TCP error occurs."
  (let ((conn (find-connection-for-client client)))
    (when conn
      (notify-event-handlers conn :error error))))

(defun on-disconnected (client)
  "Called when TCP connection is closed."
  (let ((conn (find-connection-for-client client)))
    (when conn
      (notify-event-handlers conn :disconnected nil))))
