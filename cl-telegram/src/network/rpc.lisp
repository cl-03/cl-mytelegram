;;; rpc.lisp --- RPC call handling

(in-package #:cl-telegram/network)

;;; ### RPC Request Invocation

(defun rpc-call (conn request &key timeout)
  "Make a synchronous RPC call.

   Args:
     conn: Connection instance
     request: Serialized TL request body
     timeout: Timeout in milliseconds (default 30000)

   Returns:
     TL object response or error list

   Example:
     (rpc-call conn (tl-serialize (make-tl-ok)))"
  (connection-send-rpc conn request :timeout timeout))

(defun rpc-call-async (conn request callback)
  "Make an asynchronous RPC call.

   Args:
     conn: Connection instance
     request: Serialized TL request body
     callback: Function to call with response (receives result)

   The callback receives either:
   - TL object on success
   - List (:error code message) on error"
  (let* ((msg-id (generate-msg-id conn))
         (seqno (get-and-incf-seqno conn))
         (promise (cons nil nil)))
    ;; Store pending request with callback
    (setf (gethash msg-id (conn-pending-requests conn))
          (cons callback promise))
    ;; Build and send message
    (let* ((rpc-message (cl-telegram/mtproto:make-rpc-request
                         (conn-session-id conn) msg-id request))
           (multiple-value-bind (encrypted msg-key)
               (cl-telegram/mtproto:encrypt-message (conn-auth-key conn) rpc-message
                                                    :from-client t)
             (let ((packet (cl-telegram/mtproto:make-transport-packet
                            (conn-auth-key-id conn) msg-key encrypted)))
               (connection-send conn packet)))))
  t)

(defun wait-for-response (conn msg-id &key (timeout 30000))
  "Wait for a specific RPC response.

   Args:
     conn: Connection instance
     msg-id: Message ID to wait for
     timeout: Timeout in milliseconds

   Returns:
     Response TL object or NIL on timeout"
  (let ((promise (gethash msg-id (conn-pending-requests conn))))
    (when promise
      (loop with start = (get-universal-time)
            with timeout-sec = (/ timeout 1000)
            for elapsed = (- (get-universal-time) start)
            while (not (cdr promise))
            while (< elapsed timeout-sec)
            do (sleep 0.01)
            finally (return
                      (if (cdr promise)
                          (car promise)
                          nil))))))

;;; ### RPC Request Builders

(defun build-rpc-request (msg-id seqno body)
  "Build an RPC request message.

   Args:
     msg-id: 64-bit message ID
     seqno: Sequence number
     body: Serialized TL request

   Returns:
     Complete message bytes (unencrypted)"
  (cl-telegram/mtproto:make-rpc-request msg-id seqno body))

;;; ### Batch RPC

(defun rpc-batch (conn requests &key timeout)
  "Execute multiple RPC requests in a batch.

   Args:
     conn: Connection instance
     requests: List of serialized TL requests
     timeout: Timeout in milliseconds

   Returns:
     List of responses (or errors)"
  (let ((results nil)
        (promises nil))
    ;; Send all requests
    (dolist (request requests)
      (let* ((msg-id (generate-msg-id conn))
             (promise (cons nil nil)))
        (setf (gethash msg-id (conn-pending-requests conn)) promise)
        (push promise promises)
        (let* ((rpc-message (cl-telegram/mtproto:make-rpc-request
                             (conn-session-id conn) msg-id request))
               (multiple-value-bind (encrypted msg-key)
                   (cl-telegram/mtproto:encrypt-message (conn-auth-key conn) rpc-message
                                                        :from-client t)
                 (let ((packet (cl-telegram/mtproto:make-transport-packet
                                (conn-auth-key-id conn) msg-key encrypted)))
                   (connection-send conn packet))))))
    ;; Wait for all responses
    (dolist (promise promises)
      (push (wait-for-promise promise timeout) results))
    (nreverse results)))

(defun wait-for-promise (promise &key (timeout 30000))
  "Wait for a promise to complete."
  (loop with start = (get-universal-time)
        with timeout-sec = (/ timeout 1000)
        for elapsed = (- (get-universal-time) start)
        while (not (cdr promise))
        while (< elapsed timeout-sec)
        do (sleep 0.01)
        finally (return
                  (if (cdr promise)
                      (car promise)
                      (list :error :timeout "Request timeout")))))

;;; ### RPC with Retry

(defun rpc-call-with-retry (conn request &key (max-retries 3) timeout)
  "Make an RPC call with automatic retry on failure.

   Args:
     conn: Connection instance
     request: Serialized TL request
     max-retries: Maximum retry attempts (default 3)
     timeout: Timeout per attempt in milliseconds

   Returns:
     Response or error after all retries exhausted"
  (let ((attempt 0)
        (last-error nil))
    (loop while (< attempt max-retries)
          do (handler-case
                 (let ((result (rpc-call conn request :timeout timeout)))
                   (if (and (listp result)
                            (eq (car result) :error))
                       (progn
                         (setf last-error result)
                         (incf attempt)
                         (sleep (* 0.1 attempt)))  ; Backoff
                       (return result)))
               (error (e)
                 (setf last-error e)
                 (incf attempt)
                 (sleep (* 0.1 attempt))))
          finally (return (or last-error
                              (list :error :max-retries "Max retries exceeded"))))))

;;; ### Invoke Helper Macros

(defmacro with-rpc-call ((result conn request &key timeout) &body body)
  "Execute RPC call and bind result to variable.

   Example:
     (with-rpc-call (result conn request :timeout 5000)
       (if (error-p result)
           (handle-error result)
           (process-result result)))"
  `(let ((,result (rpc-call ,conn ,request :timeout ,timeout)))
     ,@body))

(defmacro rpc-handler-case (call &rest cases)
  "Handle RPC call with error cases.

   Example:
     (rpc-handler-case (rpc-call conn request)
       ((:error code msg) (format t \"Error ~A: ~A\" code msg))
       (result (process-result result)))"
  `(let ((rpc-result ,call))
     (if (and (listp rpc-result)
              (eq (car rpc-result) :error))
         (destructuring-bind (&optional (code nil) (message nil)) (cdr rpc-result)
           (cond ,@(loop for (pattern . handler) in cases
                         collect `((eq ',pattern code) ,@handler))))
         (let ((result rpc-result))
           ,@cases))))

;;; ### Ping/Pong

(defun send-ping (conn)
  "Send a ping request to keep connection alive.

   ping#7abe77ec ping_id:long = Pong"
  (let* ((ping-id (random (expt 2 63)))
         (request (concatenate '(simple-array (unsigned-byte 8))
                               (cl-telegram/tl:serialize-int32 #x7abe77ec)
                               (cl-telegram/tl:serialize-int64 ping-id))))
    (rpc-call conn request :timeout 5000)))

(defun send-ping-delay-disconnect (conn ping-id disconnect-delay)
  "Send ping with delayed disconnect.

   ping_delay_disconnect#f3427b8c ping_id:long disconnect_delay:int"
  (let ((request (concatenate '(simple-array (unsigned-byte 8))
                              (cl-telegram/tl:serialize-int32 #xf3427b8c)
                              (cl-telegram/tl:serialize-int64 ping-id)
                              (cl-telegram/tl:serialize-int32 disconnect-delay))))
    (rpc-call conn request :timeout 5000)))

;;; ### Get Future Salts

(defun get-future-salts (conn &key (num 1))
  "Request future server salts for message ID generation.

   get_future_salts#b921bd04 num:int = FutureSalts"
  (let ((request (concatenate '(simple-array (unsigned-byte 8))
                              (cl-telegram/tl:serialize-int32 #xb921bd04)
                              (cl-telegram/tl:serialize-int32 num))))
    (rpc-call conn request :timeout 5000)))
