;;; rpc.lisp --- RPC call handling

(in-package #:cl-telegram/network)

;;; ### Message Queue

(defstruct message-queue-item
  "Item in message queue"
  (request nil :type (or null simple-array))
  (priority 0 :type integer)
  (created-at 0 :type integer)
  (callback nil :type (or null function))
  (promise (cons nil nil) :type cons)
  (retry-count 0 :type integer)
  (max-retries 3 :type integer))

(defclass message-queue ()
  ((queue :initform (make-array 100 :adjustable t :fill-pointer 0)
          :accessor queue-items
          :documentation "Priority queue of messages")
   (lock :initform (bt:make-lock "message-queue")
         :accessor queue-lock
         :documentation "Lock for thread-safe access")
   (max-size :initarg :max-size :initform 1000
             :accessor queue-max-size
             :documentation "Maximum queue size")
   (processing-p :initform nil :accessor queue-processing-p
                 :documentation "Whether queue is being processed"))
  (:documentation "Priority message queue for RPC requests"))

(defun make-message-queue (&key (max-size 1000))
  "Create a new message queue.

   Args:
     max-size: Maximum queue size (default 1000)

   Returns:
     Message queue instance"
  (make-instance 'message-queue :max-size max-size))

(defun enqueue-message (queue request &key (priority 0) callback)
  "Add a message to the queue.

   Args:
     queue: Message queue instance
     request: Serialized TL request
     priority: Priority (higher = more urgent, default 0)
     callback: Optional callback function

   Returns:
     Promise cons cell (value . done-p)"
  (bt:with-lock-held ((queue-lock queue))
    (if (>= (length (queue-items queue)) (queue-max-size queue))
        (error "Message queue full")
        (let ((item (make-message-queue-item
                     :request request
                     :priority priority
                     :created-at (get-universal-time)
                     :callback callback)))
          (vector-push-extend item (queue-items queue))
          ;; Sort by priority (descending)
          (sort (queue-items queue) #'> :key #'message-queue-item-priority)
          (item-promise item)))))

(defun dequeue-message (queue)
  "Remove and return the highest priority message.

   Args:
     queue: Message queue instance

   Returns:
     Message queue item or nil"
  (bt:with-lock-held ((queue-lock queue))
    (if (> (length (queue-items queue)) 0)
        (aref (queue-items queue) 0)
        nil)))

(defun remove-message (queue index)
  "Remove a message at specific index.

   Args:
     queue: Message queue instance
     index: Index to remove

   Returns:
     Removed item or nil"
  (bt:with-lock-held ((queue-lock queue))
    (when (and (>= index 0)
               (< index (length (queue-items queue))))
      (let ((item (aref (queue-items queue) index)))
        (delete index (queue-items queue))
        item))))

(defun queue-length (queue)
  "Get current queue length."
  (bt:with-lock-held ((queue-lock queue))
    (length (queue-items queue))))

(defun queue-stats (queue)
  "Get queue statistics.

   Returns:
     plist with queue stats"
  (bt:with-lock-held ((queue-lock queue))
    (let ((items (queue-items queue))
          (total (length items))
          (high-priority 0)
          (medium-priority 0)
          (low-priority 0)
          (oldest-age 0)
          (now (get-universal-time)))
      (loop for item across items do
        (let ((priority (message-queue-item-priority item))
              (age (- now (message-queue-item-created-at item))))
          (cond
            ((>= priority 10) (incf high-priority))
            ((>= priority 1) (incf medium-priority))
            (t (incf low-priority)))
          (when (> age oldest-age)
            (setf oldest-age age))))
      (list :total total
            :high-priority high-priority
            :medium-priority medium-priority
            :low-priority low-priority
            :oldest-message-age-seconds oldest-age))))

(defun process-queue (conn queue &key (batch-size 10) timeout)
  "Process messages in the queue.

   Args:
     conn: Connection instance
     queue: Message queue instance
     batch-size: Number of messages to process in batch (default 10)
     timeout: Timeout per message in milliseconds

   Returns:
     Number of messages processed"
  (setf (queue-processing-p queue) t)
  (let ((processed 0)
        (batch nil))
    ;; Collect batch
    (bt:with-lock-held ((queue-lock queue))
      (loop for i from 0 below (min batch-size (length (queue-items queue)))
            for item = (aref (queue-items queue) i)
            do (push item batch)))
    ;; Process batch
    (dolist (item (nreverse batch))
      (handler-case
          (let* ((request (message-queue-item-request item))
                 (promise (message-queue-item-promise item))
                 (result (rpc-call conn request :timeout (or timeout 30000))))
            ;; Set result
            (setf (car promise) result
                  (cdr promise) t)
            ;; Call callback if provided
            (when (message-queue-item-callback item)
              (funcall (message-queue-item-callback item) result))
            (incf processed)
            ;; Remove from queue
            (bt:with-lock-held ((queue-lock queue))
              (delete item (queue-items queue))))
        (error (e)
          ;; Increment retry count
          (incf (message-queue-item-retry-count item))
          (when (>= (message-queue-item-retry-count item)
                    (message-queue-item-max-retries item))
            ;; Max retries reached, remove from queue
            (setf (cdr promise) t
                  (car promise) (list :error :max-retries (format nil "~A" e)))
            (bt:with-lock-held ((queue-lock queue))
              (delete item (queue-items queue)))))))
    (setf (queue-processing-p queue) nil)
    processed))

(defvar *global-message-queue* nil
  "Global message queue instance")

(defun init-global-queue (&key (max-size 1000))
  "Initialize global message queue.

   Args:
     max-size: Maximum queue size"
  (setf *global-message-queue* (make-message-queue :max-size max-size)))

(defun enqueue-rpc-request (request &key (priority 0) callback)
  "Add RPC request to global queue.

   Args:
     request: Serialized TL request
     priority: Priority (higher = more urgent)
     callback: Optional callback

   Returns:
     Promise cons cell"
  (unless *global-message-queue*
    (init-global-queue))
  (enqueue-message *global-message-queue* request
                   :priority priority
                   :callback callback))

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
