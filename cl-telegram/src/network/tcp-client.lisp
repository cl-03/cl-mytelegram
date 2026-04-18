;;; tcp-client.lisp --- TCP client using cl-async

(in-package #:cl-telegram/network)

(import 'cl-async:connect
        'cl-async:socket-send
        'cl-async:socket-receive
        'cl-async:close-socket
        'cl-async:with-event-loop
        'cl-async:timeout-after)

;;; ### TCP Client with cl-async

(defclass tcp-client ()
  ((host :initarg :host :accessor client-host
         :documentation "Server hostname or IP")
   (port :initarg :port :accessor client-port
         :documentation "Server port")
   (socket :initarg :socket :initform nil :accessor client-socket
           :documentation "cl-async socket object")
   (stream :initarg :stream :initform nil :accessor client-stream
           :documentation "Socket stream")
   (connected-p :initform nil :accessor client-connected-p
                :documentation "Connection status")
   (read-buffer :initform (make-array 4096 :element-type '(unsigned-byte 8))
                :accessor client-read-buffer
                :documentation "Read buffer")
   (buffer-position :initform 0 :accessor client-buffer-pos
                    :documentation "Current buffer position")
   (on-connect-cb :initarg :on-connect :initform nil :accessor client-on-connect
                  :documentation "Connection callback")
   (on-data-cb :initarg :on-data :initform nil :accessor client-on-data
               :documentation "Data received callback")
   (on-error-cb :initarg :on-error :initform nil :accessor client-on-error
                :documentation "Error callback")
   (on-disconnect-cb :initarg :on-disconnect :initform nil :accessor client-on-disconnect
                     :documentation "Disconnect callback"))
  (:documentation "Asynchronous TCP client using cl-async"))

(defun make-tcp-client (host port &key on-connect on-data on-error on-disconnect)
  "Create a new TCP client.

   Args:
     host: Server hostname or IP address
     port: Server port number
     on-connect: Callback function when connected (receives client)
     on-data: Callback function when data received (receives client data)
     on-error: Callback function on error (receives client error)
     on-disconnect: Callback function on disconnect (receives client)

   Returns:
     New tcp-client instance"
  (make-instance 'tcp-client
                 :host host
                 :port port
                 :on-connect on-connect
                 :on-data on-data
                 :on-error on-error
                 :on-disconnect on-disconnect))

(defun client-connect (client &key (timeout 10000))
  "Connect to the server asynchronously.

   Args:
     client: TCP client instance
     timeout: Connection timeout in milliseconds (default 10s)

   Returns:
     T if connection initiated successfully

   Note: This is non-blocking. Use on-connect callback to know when actually connected."
  (handler-case
      (cl-async:connect
       (client-host client)
       (client-port client)
       (lambda (socket)
         ;; On connect callback
         (setf (client-socket client) socket
               (client-connected-p client) t)
         (when (client-on-connect client)
           (funcall (client-on-connect client) client))
         ;; Start reading
         (client-start-receive client))
       (lambda (data)
         ;; On data callback
         (when (client-on-data client)
           (funcall (client-on-data client) client data)))
       (lambda (err)
         ;; On error callback
         (setf (client-connected-p client) nil)
         (when (client-on-error client)
           (funcall (client-on-error client) client err))))
    (error (e)
      (setf (client-connected-p client) nil)
      (when (client-on-error client)
        (funcall (client-on-error client) client e))
      nil)))

(defun client-start-receive (client)
  "Start receiving data from the socket.

   Internal function called after connection."
  (let ((socket (client-socket client)))
    (when socket
      (cl-async:socket-receive
       socket
       (client-read-buffer client)
       (lambda (data)
         ;; Process received data
         (when (client-on-data client)
           (funcall (client-on-data client) client data))
         ;; Continue receiving
         (client-start-receive client))
       (lambda (err)
         ;; Handle receive error
         (when (client-on-error client)
           (funcall (client-on-error client) client err)))))))

(defun client-disconnect (client)
  "Disconnect from the server.

   Args:
     client: TCP client instance"
  (when (client-socket client)
    (handler-case
        (cl-async:close-socket (client-socket client))
      (error () nil))
    (setf (client-socket client) nil))
  (when (client-stream client)
    (ignore-errors (close (client-stream client)))
    (setf (client-stream client) nil))
  (setf (client-connected-p client) nil)
  (when (client-on-disconnect client)
    (funcall (client-on-disconnect client) client))
  t)

(defun client-send (client data)
  "Send data to the server asynchronously.

   Args:
     client: TCP client instance
     data: Byte array to send

   Returns:
     T if send initiated successfully"
  (unless (client-connected-p client)
    (error "Not connected"))
  (let ((socket (client-socket client)))
    (when socket
      (handler-case
          (cl-async:socket-send socket data)
          t)
      t)))

(defun client-send-sync (client data &key (timeout 10000))
  "Send data and wait for completion (blocking).

   Args:
     client: TCP client instance
     data: Byte array to send
     timeout: Timeout in milliseconds

   Returns:
     T if send completed successfully"
  (let ((completed-p nil)
        (error-out nil))
    (client-send client data)
    ;; Wait for completion
    (cl-async:with-event-loop ()
      (cl-async:timeout-after (/ timeout 1000)
        (setf completed-p t)))
    (if error-out
        (error error-out)
        completed-p)))

(defun client-receive (client length &key (timeout 10000))
  "Receive exactly LENGTH bytes from the server (blocking).

   Args:
     client: TCP client instance
     length: Number of bytes to receive
     timeout: Timeout in milliseconds

   Returns:
     Byte array containing received data, or NIL on timeout"
  (declare (ignore timeout))
  (let ((buffer (make-array length :element-type '(unsigned-byte 8)))
        (received 0))
    (loop while (< received length) do
      (let* ((socket (client-socket client))
             (chunk (when socket
                      (cl-async:socket-receive-sync socket (- length received)))))
        (unless chunk
          (return-from client-receive nil))
        (replace buffer chunk :start1 received)
        (incf received (length chunk))))
    buffer))

;;; ### Synchronous TCP client (using usocket)

(defclass sync-tcp-client ()
  ((host :initarg :host :accessor sync-client-host)
   (port :initarg :port :accessor sync-client-port)
   (socket :initarg :socket :initform nil :accessor sync-client-socket)
   (stream :initarg :stream :initform nil :accessor sync-client-stream)
   (connected-p :initform nil :accessor sync-client-connected-p)))

(defun make-sync-tcp-client (host port)
  "Create a synchronous TCP client."
  (make-instance 'sync-tcp-client :host host :port port))

(defun sync-client-connect (client &key (timeout 10))
  "Connect to server (blocking).

   Args:
     client: Sync TCP client
     timeout: Connection timeout in seconds

   Returns:
     T if connected successfully"
  (handler-case
      (let* ((socket (usocket:socket-connect (sync-client-host client)
                                             (sync-client-port client)
                                             :element-type '(unsigned-byte 8)
                                             :timeout timeout)))
        (setf (sync-client-socket client) socket
              (sync-client-stream client) (usocket:socket-stream socket)
              (sync-client-connected-p client) t)
        t)
    (error (e)
      (format *error-output* "Connection failed: ~A~%" e)
      nil)))

(defun sync-client-disconnect (client)
  "Disconnect from server."
  (when (sync-client-stream client)
    (close (sync-client-stream client)))
  (when (sync-client-socket client)
    (usocket:socket-close (sync-client-socket client)))
  (setf (sync-client-connected-p client) nil)
  t)

(defun sync-client-send (client data)
  "Send data (blocking)."
  (unless (sync-client-connected-p client)
    (error "Not connected"))
  (write-sequence data (sync-client-stream client))
  (finish-output (sync-client-stream client))
  t)

(defun sync-client-receive (client length)
  "Receive exactly LENGTH bytes (blocking)."
  (unless (sync-client-connected-p client)
    (error "Not connected"))
  (let ((buffer (make-array length :element-type '(unsigned-byte 8))))
    (read-sequence buffer (sync-client-stream client))
    buffer))

(defun sync-client-receive-available (client)
  "Receive all available data without blocking."
  (unless (sync-client-connected-p client)
    (error "Not connected"))
  (let ((stream (sync-client-stream client)))
    (when (listen stream)
      (let ((buffer (make-array 1024 :element-type '(unsigned-byte 8)))
            (position 0))
        (loop for byte = (read-byte stream nil nil)
              while byte do
                (when (>= position (length buffer))
                  ;; Expand buffer
                  (let ((new-buffer (make-array (* 2 (length buffer))
                                                :element-type '(unsigned-byte 8))))
                    (replace new-buffer buffer)
                    (setf buffer new-buffer)))
                (setf (aref buffer position) byte)
                (incf position))
          (subseq buffer 0 position))))))

;;; ### Connection state utilities

(defun client-reconnect (client &key (delay 1000))
  "Reconnect after a delay.

   Args:
     client: TCP client
     delay: Delay in milliseconds before reconnecting"
  (declare (type (member :async :sync) *connection-type*))
  (client-disconnect client)
  ;; Schedule reconnect
  (cl-async:timeout-after (/ delay 1000)
    (lambda ()
      (client-connect client))))

(defun client-reset (client)
  "Reset client state."
  (setf (client-socket client) nil
        (client-stream client) nil
        (client-connected-p client) nil
        (client-buffer-pos client) 0))
