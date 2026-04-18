;;; connection.lisp --- Connection management

(in-package #:cl-telegram/network)

;;; ### Connection Pool

(defvar *connection-pool* (make-hash-table :test 'equal)
  "Pool of connections keyed by host:port")

(defvar *pool-lock* (bt:make-lock "connection-pool")
  "Lock for thread-safe pool access")

(defstruct connection-pool-entry
  "Entry in connection pool"
  (connection nil :type (or null connection))
  (created-at 0 :type integer)
  (last-used-at 0 :type integer)
  (use-count 0 :type integer)
  (max-use-count 100 :type integer)
  (health-status :unknown :type (member :unknown :healthy :unhealthy :reconnecting)))

(defun pool-key (host port)
  "Generate pool key from host and port."
  (format nil "~A:~A" host port))

(defun get-connection-from-pool (host port)
  "Get a connection from the pool or create new one.

   Args:
     host: Telegram server hostname
     port: Server port (default 443)

   Returns:
     Connection instance (existing or new)"
  (let ((key (pool-key host port)))
    (bt:with-lock-held (*pool-lock*)
      (let ((entry (gethash key *connection-pool*)))
        (if (and entry
                 (eq (connection-pool-entry-health-status entry) :healthy)
                 (< (connection-pool-entry-use-count entry)
                    (connection-pool-entry-max-use-count entry))
                 (connected-p (connection-pool-entry-connection entry)))
            ;; Return existing healthy connection
            (progn
              (setf (connection-pool-entry-last-used-at entry) (get-universal-time))
              (incf (connection-pool-entry-use-count entry))
              (connection-pool-entry-connection entry))
            ;; Create new connection
            (let ((new-conn (make-connection :host host :port port)))
              (setf (gethash key *connection-pool*)
                    (make-connection-pool-entry
                     :connection new-conn
                     :created-at (get-universal-time)
                     :last-used-at (get-universal-time)
                     :use-count 1
                     :health-status :healthy))
              new-conn))))))

(defun return-connection-to-pool (conn)
  "Return a connection to the pool for reuse.

   Args:
     conn: Connection instance"
  (let ((tcp-client (conn-tcp-client conn)))
    (bt:with-lock-held (*pool-lock*)
      (loop for key being the hash-keys of *connection-pool*
            for entry being the hash-values of *connection-pool*
            when (eq (connection-pool-entry-connection entry) conn)
            do (progn
                 (setf (connection-pool-entry-last-used-at entry) (get-universal-time))
                 ;; Mark for reconnection if disconnected
                 (unless (connected-p tcp-client)
                   (setf (connection-pool-entry-health-status entry) :reconnecting))
                 (return-from return-connection-to-pool t))))))

(defun remove-connection-from-pool (conn)
  "Remove a connection from the pool.

   Args:
     conn: Connection instance"
  (bt:with-lock-held (*pool-lock*)
    (loop for key being the hash-keys of *connection-pool*
          for entry being the hash-values of *connection-pool*
          when (eq (connection-pool-entry-connection entry) conn)
          do (progn
               (remhash key *connection-pool*)
               (disconnect conn)
               (return-from remove-connection-from-pool t)))))

(defun pool-stats ()
  "Get connection pool statistics.

   Returns:
     plist with pool statistics"
  (bt:with-lock-held (*pool-lock*)
    (let ((total 0)
          (healthy 0)
          (unhealthy 0)
          (reconnecting 0)
          (oldest-age 0)
          (now (get-universal-time)))
      (loop for entry being the hash-values of *connection-pool* do
        (incf total)
        (let ((age (- now (connection-pool-entry-created-at entry))))
          (when (> age oldest-age)
            (setf oldest-age age)))
        (ecase (connection-pool-entry-health-status entry)
          (:healthy (incf healthy))
          (:unhealthy (incf unhealthy))
          (:reconnecting (incf reconnecting))
          (:unknown nil)))
      (list :total total
            :healthy healthy
            :unhealthy unhealthy
            :reconnecting reconnecting
            :oldest-connection-age-seconds oldest-age))))

(defun cleanup-pool (&key (max-age 3600) (idle-timeout 300))
  "Clean up old and idle connections.

   Args:
     max-age: Maximum connection age in seconds (default 1 hour)
     idle-timeout: Idle timeout in seconds (default 5 minutes)"
  (bt:with-lock-held (*pool-lock*)
    (let ((now (get-universal-time))
          (removed 0))
      (loop for key being the hash-keys of *connection-pool*
            for entry being the hash-values of *connection-pool* do
        (let ((age (- now (connection-pool-entry-created-at entry)))
              (idle (- now (connection-pool-entry-last-used-at entry))))
          (when (or (> age max-age)
                    (> idle idle-timeout)
                    (eq (connection-pool-entry-health-status entry) :unhealthy))
            (disconnect (connection-pool-entry-connection entry))
            (remhash key *connection-pool*)
            (incf removed))))
      removed)))

;;; ### Auto-Reconnect Manager

(defclass auto-reconnect-manager ()
  ((reconnect-delay :initarg :reconnect-delay :initform 1000
                    :accessor reconnect-delay
                    :documentation "Base delay between reconnect attempts in ms")
   (max-delay :initarg :max-delay :initform 30000
              :accessor max-delay
              :documentation "Maximum reconnect delay in ms")
   (multiplier :initarg :multiplier :initform 2.0
               :accessor reconnect-multiplier
              :documentation "Delay multiplier after each attempt")
   (max-attempts :initarg :max-attempts :initform nil
                 :accessor max-reconnect-attempts
                 :documentation "Maximum reconnect attempts (nil for unlimited)")
   (attempt-count :initform 0 :accessor reconnect-attempt-count
                  :documentation "Current attempt count")
   (reconnecting-p :initform nil :accessor reconnecting-p
                   :documentation "Whether currently reconnecting")
   (connection :initarg :connection :accessor reconnect-connection
               :documentation "Connection being managed"))
  (:documentation "Manages automatic reconnection with exponential backoff"))

(defun make-auto-reconnect-manager (conn &key reconnect-delay max-delay multiplier max-attempts)
  "Create auto-reconnect manager.

   Args:
     conn: Connection to manage
     reconnect-delay: Initial delay in ms (default 1000)
     max-delay: Maximum delay in ms (default 30000)
     multiplier: Backoff multiplier (default 2.0)
     max-attempts: Max attempts or nil for unlimited

   Returns:
     Auto-reconnect manager instance"
  (make-instance 'auto-reconnect-manager
                 :connection conn
                 :reconnect-delay (or reconnect-delay 1000)
                 :max-delay (or max-delay 30000)
                 :multiplier (or multiplier 2.0)
                 :max-attempts max-attempts))

(defun start-auto-reconnect (manager)
  "Start automatic reconnection.

   Args:
     manager: Auto-reconnect manager instance"
  (setf (reconnecting-p manager) t)
  ;; Register disconnect handler
  (set-event-handler (reconnect-connection manager) :disconnected
                     (lambda (data)
                       (declare (ignore data))
                       (schedule-reconnect manager)))
  ;; Start reconnection loop
  (bt:make-thread (lambda ()
                    (reconnect-loop manager))
                  :name "auto-reconnect-thread"))

(defun schedule-reconnect (manager)
  "Schedule a reconnect attempt.

   Args:
     manager: Auto-reconnect manager instance"
  (let ((delay (calculate-reconnect-delay manager)))
    (format t "Scheduling reconnect in ~Dms (attempt ~D)~%"
            delay (reconnect-attempt-count manager))
    (sleep (/ delay 1000.0))
    (attempt-reconnect manager)))

(defun calculate-reconnect-delay (manager)
  "Calculate delay with exponential backoff.

   Args:
     manager: Auto-reconnect manager instance

   Returns:
     Delay in milliseconds"
  (let ((attempts (reconnect-attempt-count manager))
        (base (reconnect-delay manager))
        (max (max-delay manager))
        (mult (reconnect-multiplier manager)))
    (min max (floor (* base (expt mult attempts))))))

(defun attempt-reconnect (manager)
  "Attempt to reconnect.

   Args:
     manager: Auto-reconnect manager instance"
  (let ((conn (reconnect-connection manager)))
    (incf (reconnect-attempt-count manager))
    ;; Check max attempts
    (when (and (max-reconnect-attempts manager)
               (>= (reconnect-attempt-count manager) (max-reconnect-attempts manager)))
      (setf (reconnecting-p manager) nil)
      (error "Max reconnect attempts (~D) reached" (max-reconnect-attempts manager)))
    ;; Attempt reconnect
    (handler-case
        (progn
          (setf (connection-pool-entry-health-status
                 (get-entry-for-connection conn))
                :reconnecting)
          (reconnect conn :delay 0)
          (sleep 0.5) ; Wait for connection
          (if (connected-p conn)
              (progn
                (setf (reconnect-attempt-count manager) 0) ; Reset on success
                (setf (connection-pool-entry-health-status
                       (get-entry-for-connection conn))
                      :healthy)
                (setf (reconnecting-p manager) nil)
                (format t "Reconnected successfully~%"))
              (schedule-reconnect manager)))
      (error (e)
        (format *error-output* "Reconnect failed: ~A~%" e)
        (schedule-reconnect manager)))))

(defun reconnect-loop (manager)
  "Main reconnection loop.

   Args:
     manager: Auto-reconnect manager instance"
  (loop while (reconnecting-p manager) do
    (sleep 1)))

(defun stop-auto-reconnect (manager)
  "Stop automatic reconnection.

   Args:
     manager: Auto-reconnect manager instance"
  (setf (reconnecting-p manager) nil))

(defvar *connection-to-entry* (make-hash-table :test 'eq)
  "Map connections to pool entries")

(defun get-entry-for-connection (conn)
  "Get pool entry for a connection."
  (bt:with-lock-held (*pool-lock*)
    (gethash conn *connection-to-entry*)))

(defun set-entry-for-connection (conn entry)
  "Set pool entry for a connection."
  (bt:with-lock-held (*pool-lock*)
    (setf (gethash conn *connection-to-entry*) entry)))

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
