;;; proxy.lisp --- SOCKS5 and HTTP proxy support

(in-package #:cl-telegram/network)

;;; ### Proxy Types and Configuration

(define-condition proxy-error (error)
  ((message :initarg :message :reader proxy-error-message)
   (proxy-host :initarg :proxy-host :reader proxy-error-host)
   (proxy-port :initarg :proxy-port :reader proxy-error-port))
  (:documentation "Proxy connection error")
  (:report (lambda (condition stream)
             (format stream "Proxy error (~A:~A): ~A"
                     (proxy-error-host condition)
                     (proxy-error-port condition)
                     (proxy-error-message condition)))))

(defenum proxy-type
  "Proxy type enumeration"
  :none      ; No proxy (direct connection)
  :socks4    ; SOCKS4 proxy
  :socks5    ; SOCKS5 proxy
  :http      ; HTTP CONNECT proxy
  :https)    ; HTTPS CONNECT proxy

(defstruct proxy-config
  "Proxy configuration"
  (type :none :type (member :none :socks4 :socks5 :http :https))
  (host "" :type string)
  (port 0 :type integer)
  (username nil :type (or null string))
  (password nil :type (or null string))
  (use-dns nil :type boolean)  ; Use remote DNS resolution (SOCKS5)
  (timeout 10000 :type integer))  ; Connection timeout in ms

(defvar *global-proxy-config* (make-proxy-config)
  "Global proxy configuration")

(defun configure-proxy (&key type host port username password use-dns timeout)
  "Configure global proxy settings.

   Args:
     type: Proxy type (:socks4, :socks5, :http, :https, :none)
     host: Proxy hostname or IP
     port: Proxy port
     username: Optional username for proxy auth
     password: Optional password for proxy auth
     use-dns: Use remote DNS resolution (SOCKS5 only)
     timeout: Connection timeout in milliseconds

   Example:
     (configure-proxy :type :socks5 :host \"127.0.0.1\" :port 1080)
     (configure-proxy :type :http :host \"proxy.example.com\" :port 8080
                      :username \"user\" :password \"pass\")"
  (when type
    (setf (proxy-config-type *global-proxy-config*) type))
  (when host
    (setf (proxy-config-host *global-proxy-config*) host))
  (when port
    (setf (proxy-config-port *global-proxy-config*) port))
  (when username
    (setf (proxy-config-username *global-proxy-config*) username))
  (when password
    (setf (proxy-config-password *global-proxy-config*) password))
  (when use-dns
    (setf (proxy-config-use-dns *global-proxy-config*) use-dns))
  (when timeout
    (setf (proxy-config-timeout *global-proxy-config*) timeout))
  *global-proxy-config*)

(defun reset-proxy-config ()
  "Reset proxy configuration to disabled."
  (setf (proxy-config-type *global-proxy-config*) :none
        (proxy-config-host *global-proxy-config*) ""
        (proxy-config-port *global-proxy-config*) 0
        (proxy-config-username *global-proxy-config*) nil
        (proxy-config-password *global-proxy-config*) nil
        (proxy-config-use-dns *global-proxy-config*) nil)
  *global-proxy-config*)

(defun proxy-enabled-p ()
  "Check if proxy is enabled."
  (and (not (eq (proxy-config-type *global-proxy-config*) :none))
       (plusp (length (proxy-config-host *global-proxy-config*)))
       (plusp (proxy-config-port *global-proxy-config*))))

;;; ### SOCKS5 Protocol Constants

(defconstant +socks5-version+ #x05
  "SOCKS5 protocol version")

(defconstant +socks5-auth-none+ #x00
  "No authentication")

(defconstant +socks5-auth-gssapi+ #x01
  "GSSAPI authentication")

(defconstant +socks5-auth-username+ #x02
  "Username/password authentication")

(defconstant +socks5-auth-no-acceptable+ #xff
  "No acceptable authentication")

(defconstant +socks5-connect+ #x01
  "CONNECT command")

(defconstant +socks5-bind+ #x02
  "BIND command")

(defconstant +socks5-associate+ #x03
  "UDP ASSOCIATE command")

(defconstant +socks5-addr-ipv4+ #x01
  "IPv4 address")

(defconstant +socks5-addr-domain+ #x03
  "Domain name")

(defconstant +socks5-addr-ipv6+ #x04
  "IPv6 address")

(defconstant +socks5-status-success+ #x00
  "Request successful")

(defconstant +socks5-status-failure+ #x01
  "General failure")

(defconstant +socks5-status-not-allowed+ #x02
  "Connection not allowed by ruleset")

(defconstant +socks5-status-network-unreachable+ #x03
  "Network unreachable")

(defconstant +socks5-status-host-unreachable+ #x04
  "Host unreachable")

(defconstant +socks5-status-connection-refused+ #x05
  "Connection refused")

(defconstant +socks5-status-ttl-expired+ #x06
  "TTL expired")

(defconstant +socks5-status-command-not-supported+ #x07
  "Command not supported")

(defconstant +socks5-status-addr-type-not-supported+ #x08
  "Address type not supported")

;;; ### SOCKS5 Implementation

(defun socks5-convert-host (host)
  "Convert host to bytes for SOCKS5.

   Returns:
     (values addr-type addr-bytes)"
  (if (cl-ppcre:scan "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$" host)
      ;; IPv4 address
      (let* ((parts (mapcar #'parse-integer (cl-ppcre:split "\\." host)))
             (addr (make-array 4 :element-type '(unsigned-byte 8))))
        (loop for i from 0 below 4 do
              (setf (aref addr i) (nth i parts)))
        (values +socks5-addr-ipv4+ addr))
      ;; Domain name
      (let* ((octets (babel:string-to-octets host))
             (len (length octets))
             (addr (make-array (1+ len) :element-type '(unsigned-byte 8))))
        (setf (aref addr 0) len)
        (replace addr octets :start1 1)
        (values +socks5-addr-domain+ addr))))

(defun socks5-authenticate (stream username password)
  "Authenticate with SOCKS5 server using username/password.

   Args:
     stream: Socket stream
     username: Username
     password: Password

   Returns:
     T on success

   Raises:
     proxy-error on failure"
  (let* ((username-bytes (babel:string-to-octets username))
         (password-bytes (babel:string-to-octets password))
         (auth-request (make-array (+ 3 (length username-bytes) (length password-bytes))
                                   :element-type '(unsigned-byte 8))))
    ;; Auth request: version(1) + username_len(1) + username + password_len(1) + password
    (setf (aref auth-request 0) #x01)  ; Subnegotiation version
    (setf (aref auth-request 1) (length username-bytes))
    (replace auth-request username-bytes :start1 2)
    (setf (aref auth-request (+ 2 (length username-bytes))) (length password-bytes))
    (replace auth-request password-bytes :start1 (+ 3 (length username-bytes))))

  ;; Send auth request
  (write-sequence auth-request stream)
  (finish-output stream)

  ;; Read auth response (2 bytes: version, status)
  (let ((response (make-array 2 :element-type '(unsigned-byte 8))))
    (read-sequence response stream)
    (unless (= (aref response 1) #x00)
      (error 'proxy-error
             :message (format nil "Authentication failed: ~A"
                              (if (= (aref response 1) #xff)
                                  "Invalid credentials"
                                  "Unknown error"))
             :proxy-host (proxy-config-host *global-proxy-config*)
             :proxy-port (proxy-config-port *global-proxy-config*)))))

(defun socks5-connect (stream target-host target-port)
  "Establish connection through SOCKS5 proxy.

   Args:
     stream: Socket stream to proxy
     target-host: Target hostname or IP
     target-port: Target port

   Returns:
     T on success

   Raises:
     proxy-error on failure"
  (let ((config *global-proxy-config*))
    ;; Step 1: Send greeting
    (let ((methods (if (and (proxy-config-username config)
                            (proxy-config-password config))
                       #(#x00 #x02)  ; None and username/password
                       #(#x00))))    ; None only
      (let ((greeting (make-array (+ 2 (length methods)) :element-type '(unsigned-byte 8))))
        (setf (aref greeting 0) +socks5-version+)
        (setf (aref greeting 1) (length methods))
        (replace greeting methods :start1 2)
        (write-sequence greeting stream)
        (finish-output stream)))

    ;; Step 2: Receive greeting response
    (let ((response (make-array 2 :element-type '(unsigned-byte 8))))
      (read-sequence response stream)
      (let ((version (aref response 0))
            (method (aref response 1)))
        (unless (= version +socks5-version+)
          (error 'proxy-error
                 :message (format nil "Invalid SOCKS version: ~A" version)
                 :proxy-host (proxy-config-host config)
                 :proxy-port (proxy-config-port config)))
        (cond
          ((= method +socks5-auth-none+)
           ;; No auth required
           )
          ((= method +socks5-auth-username+)
           ;; Username/password auth required
           (unless (and (proxy-config-username config)
                        (proxy-config-password config))
             (error 'proxy-error
                    :message "Username/password required but not provided"
                    :proxy-host (proxy-config-host config)
                    :proxy-port (proxy-config-port config)))
           (socks5-authenticate stream
                                (proxy-config-username config)
                                (proxy-config-password config)))
          ((= method +socks5-auth-no-acceptable+)
           (error 'proxy-error
                  :message "No acceptable authentication method"
                  :proxy-host (proxy-config-host config)
                  :proxy-port (proxy-config-port config)))
          (t
           (error 'proxy-error
                  :message (format nil "Unsupported auth method: ~A" method)
                  :proxy-host (proxy-config-host config)
                  :proxy-port (proxy-config-port config))))))

    ;; Step 3: Send connect request
    (multiple-value-bind (addr-type addr-bytes) (socks5-convert-host target-host)
      (let* ((addr-len (length addr-bytes))
             (request (make-array (+ 4 addr-len 2) :element-type '(unsigned-byte 8))))
        (setf (aref request 0) +socks5-version+)
        (setf (aref request 1) +socks5-connect+)
        (setf (aref request 2) #x00)  ; Reserved
        (setf (aref request 3) addr-type)
        (replace request addr-bytes :start1 4)
        (setf (aref request (+ 4 addr-len)) (ldb (byte 8 8) target-port))
        (setf (aref request (+ 5 addr-len)) (ldb (byte 8 0) target-port))

        ;; Send request
        (write-sequence request stream)
        (finish-output stream)))

    ;; Step 4: Receive connect response
    (let ((response (make-array 4 :element-type '(unsigned-byte 8))))
      (read-sequence response stream)
      (let ((status (aref response 1)))
        (unless (= status +socks5-status-success+)
          (error 'proxy-error
                 :message (format nil "Connection failed: ~A"
                                  (case status
                                    ((#x02) "Connection not allowed")
                                    ((#x03) "Network unreachable")
                                    ((#x04) "Host unreachable")
                                    ((#x05) "Connection refused")
                                    ((#x06) "TTL expired")
                                    ((#x07) "Command not supported")
                                    ((#x08) "Address type not supported")
                                    (otherwise "Unknown error")))
                 :proxy-host (proxy-config-host config)
                 :proxy-port (proxy-config-port config))))

      ;; Read remaining response (address and port)
      (let ((addr-type (aref response 3)))
        (let ((addr-len (case addr-type
                          ((#x01) 4)   ; IPv4
                          ((#x04) 16)  ; IPv6
                          (t (progn
                               ;; Domain name - read length byte
                               (let ((buf (make-array 1 :element-type '(unsigned-byte 8))))
                                 (read-sequence buf stream)
                                 (aref buf 0)))))))
          ;; Skip address and port
          (let ((skip-bytes (+ addr-len 2)))
            (when (plusp skip-bytes)
              (let ((buf (make-array skip-bytes :element-type '(unsigned-byte 8))))
                (read-sequence buf stream)))))))

    t))

;;; ### HTTP CONNECT Proxy

(defun http-connect (stream target-host target-port)
  "Establish connection through HTTP CONNECT proxy.

   Args:
     stream: Socket stream to proxy
     target-host: Target hostname or IP
     target-port: Target port

   Returns:
     T on success

   Raises:
     proxy-error on failure"
  (let ((config *global-proxy-config*))
    ;; Build CONNECT request
    (let ((request-line (format nil "CONNECT ~A:~A HTTP/1.1~%" target-host target-port))
          (host-header (format nil "Host: ~A:~A~%" target-host target-port))
          (proxy-auth-header (when (and (proxy-config-username config)
                                        (proxy-config-password config))
                               (let* ((credentials (format nil "~A:~A"
                                                           (proxy-config-username config)
                                                           (proxy-config-password config)))
                                      (encoded (cl-base64:usb8-array-to-base64
                                                (babel:string-to-octets credentials))))
                                 (format nil "Proxy-Authorization: Basic ~A~%" encoded))))
          (end-headers "~%"))
      (let ((request (concatenate 'string
                                  request-line
                                  host-header
                                  (or proxy-auth-header "")
                                  end-headers)))
        ;; Send request
        (write-sequence (babel:string-to-octets request) stream)
        (finish-output stream)))

    ;; Read response line
    (let ((line (read-line stream)))
      (if (cl-ppcre:scan "HTTP/1\\.[01] 200" line)
          ;; Success - consume remaining headers
          (progn
            (loop for line = (read-line stream)
                  while (and line (plusp (length line))))
            t)
          ;; Failed
          (error 'proxy-error
                 :message (format nil "Proxy returned: ~A" line)
                 :proxy-host (proxy-config-host config)
                 :proxy-port (proxy-config-port config))))))

;;; ### Proxy Connection Wrapper

(defun connect-through-proxy (host port &key (config *global-proxy-config*))
  "Connect to host:port through configured proxy.

   Args:
     host: Target hostname or IP
     port: Target port
     config: Proxy configuration (defaults to *global-proxy-config*)

   Returns:
     (values stream socket) - Connected stream and socket

   Raises:
     proxy-error on connection failure"
  (let ((proxy-type (proxy-config-type config))
        (proxy-host (proxy-config-host config))
        (proxy-port (proxy-config-port config)))

    (cond
      ;; Direct connection (no proxy)
      ((eq proxy-type :none)
       (let* ((socket (usocket:socket-connect host port
                                              :element-type '(unsigned-byte 8)
                                              :timeout (/ (proxy-config-timeout config) 1000)))
              (stream (usocket:socket-stream socket)))
         (values stream socket)))

      ;; SOCKS5 proxy
      ((eq proxy-type :socks5)
       (let* ((socket (usocket:socket-connect proxy-host proxy-port
                                              :element-type '(unsigned-byte 8)
                                              :timeout (/ (proxy-config-timeout config) 1000)))
              (stream (usocket:socket-stream socket)))
         (handler-case
             (progn
               (socks5-connect stream host port)
               (values stream socket))
           (error (e)
             (close stream)
             (usocket:socket-close socket)
             (error e)))))

      ;; SOCKS4 proxy (simplified, no auth)
      ((eq proxy-type :socks4)
       (let* ((socket (usocket:socket-connect proxy-host proxy-port
                                              :element-type '(unsigned-byte 8)
                                              :timeout (/ (proxy-config-timeout config) 1000)))
              (stream (usocket:socket-stream socket)))
         (handler-case
             (progn
               ;; SOCKS4 CONNECT
               (let ((request (make-array 8 :element-type '(unsigned-byte 8))))
                 (setf (aref request 0) #x04)  ; SOCKS4 version
                 (setf (aref request 1) #x01)  ; CONNECT command
                 (setf (aref request 2) (ldb (byte 8 8) port))
                 (setf (aref request 3) (ldb (byte 8 0) port))
                 ;; IPv4 address (4 bytes)
                 (let ((ip (cl-ppcre:scan "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$" host)))
                   (unless ip
                     (error 'proxy-error
                            :message "SOCKS4 only supports IP addresses"
                            :proxy-host proxy-host
                            :proxy-port proxy-port))
                   (let ((parts (mapcar #'parse-integer (cl-ppcre:split "\\." host))))
                     (loop for i from 0 below 4 do
                           (setf (aref request (+ 4 i)) (nth i parts)))))
                 (setf (aref request 7) #x00)  ; Null terminator for user ID
                 (write-sequence request stream)
                 (finish-output stream))

               ;; Read response (8 bytes)
               (let ((response (make-array 8 :element-type '(unsigned-byte 8))))
                 (read-sequence response stream)
                 (unless (= (aref response 1) #x5a)
                   (error 'proxy-error
                          :message (format nil "SOCKS4 connection failed: ~A" (aref response 1))
                          :proxy-host proxy-host
                          :proxy-port proxy-port)))
               (values stream socket))
           (error (e)
             (close stream)
             (usocket:socket-close socket)
             (error e)))))

      ;; HTTP/HTTPS proxy
      ((or (eq proxy-type :http) (eq proxy-type :https))
       (let* ((socket (usocket:socket-connect proxy-host proxy-port
                                              :element-type '(unsigned-byte 8)
                                              :timeout (/ (proxy-config-timeout config) 1000)))
              (stream (usocket:socket-stream socket)))
         (handler-case
             (progn
               (http-connect stream host port)
               (values stream socket))
           (error (e)
             (close stream)
             (usocket:socket-close socket)
             (error e)))))

      (t
       (error 'proxy-error
              :message (format nil "Unknown proxy type: ~A" proxy-type)
              :proxy-host proxy-host
              :proxy-port proxy-port)))))

;;; ### Async Proxy Connection (cl-async)

(defun async-connect-through-proxy (host port callback &key (config *global-proxy-config*))
  "Connect to host:port through proxy asynchronously.

   Args:
     host: Target hostname or IP
     port: Target port
     callback: Function called with (values stream socket) on success
               or (nil error) on failure
     config: Proxy configuration

   Returns:
     T if connection initiated"
  (let ((proxy-type (proxy-config-type config))
        (proxy-host (proxy-config-host config))
        (proxy-port (proxy-config-port config)))

    (cond
      ;; Direct connection
      ((eq proxy-type :none)
       (handler-case
           (let ((socket (cl-async:connect
                          host port
                          (lambda (sock)
                            (let ((stream (cl-async:socket-stream sock)))
                              (funcall callback stream socket)))
                          (lambda (data)
                            ;; Data handler - not used for initial connection
                            ))))
             (funcall callback (cl-async:socket-stream socket) socket)
             t)
         (error (e)
           (funcall callback nil e)
           nil)))

      ;; SOCKS5 proxy
      ((eq proxy-type :socks5)
       (handler-case
           (let ((socket (cl-async:connect
                          proxy-host proxy-port
                          (lambda (sock)
                            (let ((stream (cl-async:socket-stream sock)))
                              (handler-case
                                  (progn
                                    (socks5-connect stream host port)
                                    (funcall callback stream socket))
                                (error (e)
                                  (funcall callback nil e)))))))))
             t)
         (error (e)
           (funcall callback nil e)
           nil)))

      ;; HTTP proxy
      ((or (eq proxy-type :http) (eq proxy-type :https))
       (handler-case
           (let ((socket (cl-async:connect
                          proxy-host proxy-port
                          (lambda (sock)
                            (let ((stream (cl-async:socket-stream sock)))
                              (handler-case
                                  (progn
                                    (http-connect stream host port)
                                    (funcall callback stream socket))
                                (error (e)
                                  (funcall callback nil e)))))))))
             t)
         (error (e)
           (funcall callback nil e)
           nil)))

      (t
       (funcall callback nil
                (error 'proxy-error
                       :message (format nil "Unknown proxy type: ~A" proxy-type)
                       :proxy-host proxy-host
                       :proxy-port proxy-port))
       nil))))

;;; ### System Proxy Auto-Detection

(defun detect-system-proxy ()
  "Detect system proxy settings from environment.

   Checks environment variables:
   - ALL_PROXY, all_proxy (general)
   - HTTPS_PROXY, https_proxy (HTTPS)
   - HTTP_PROXY, http_proxy (HTTP)
   - SOCKS_PROXY, socks_proxy (SOCKS)

   Returns:
     Proxy config plist or nil if no proxy configured

   Example:
     (detect-system-proxy)
     => (:type :socks5 :host \"127.0.0.1\" :port 1080)"
  (macrolet ((get-env (names)
               `(or ,@(loop for name in names
                            collect `(uiop:getenv ,name)))))
    (let* ((all-proxy (get-env ("ALL_PROXY" "all_proxy")))
           (https-proxy (get-env ("HTTPS_PROXY" "https_proxy")))
           (http-proxy (get-env ("HTTP_PROXY" "http_proxy")))
           (socks-proxy (get-env ("SOCKS_PROXY" "socks_proxy")))
           (proxy-url (or all-proxy https-proxy http-proxy socks-proxy)))

      (when proxy-url
        ;; Parse proxy URL: scheme://[user:pass@]host:port
        (multiple-value-bind (match-starts match-ends)
            (cl-ppcre:scan "^([^:]+)://(?:([^:]+):([^@]+)@)?([^:/]+)(?::(\\d+))?$" proxy-url)
          (declare (ignore match-starts))
          (when match-ends
            (let* ((scheme (subseq proxy-url 0 (elt match-ends 0)))
                   (username (when (elt match-ends 1)
                               (subseq proxy-url (elt match-starts 1) (elt match-ends 1))))
                   (password (when (elt match-ends 2)
                               (subseq proxy-url (elt match-starts 2) (elt match-ends 2))))
                   (host (subseq proxy-url (elt match-starts 3) (elt match-ends 3)))
                   (port (when (elt match-ends 4)
                           (parse-integer (subseq proxy-url (elt match-starts 4) (elt match-ends 4))))))
              (list :type (case (intern (string-upcase scheme) "KEYWORD")
                            ((:socks :socks5) :socks5)
                            (:socks4 :socks4)
                            (:http :http)
                            (:https :https)
                            (otherwise :http))
                    :host host
                    :port (or port 1080)
                    :username username
                    :password password)))))))))

(defun use-system-proxy ()
  "Configure proxy from system environment.

   Returns:
     Proxy config if detected, nil otherwise"
  (let ((proxy-info (detect-system-proxy)))
    (when proxy-info
      (apply #'configure-proxy proxy-info)
      *global-proxy-config*)))

;;; ### Utility Functions

(defun get-proxy-info ()
  "Get current proxy configuration as plist.

   Returns:
     plist with proxy information"
  (let ((config *global-proxy-config*))
    (list :enabled (proxy-enabled-p)
          :type (proxy-config-type config)
          :host (proxy-config-host config)
          :port (proxy-config-port config)
          :has-auth (and (proxy-config-username config)
                         (proxy-config-password config))
          :use-dns (proxy-config-use-dns config)
          :timeout (proxy-config-timeout config))))

(defun with-proxy-connection ((stream host port &key timeout) &body body)
  "Execute body with proxy connection to host:port.

   Args:
     stream: Bound variable for the stream
     host: Target host
     port: Target port
     timeout: Optional timeout override

   Example:
     (with-proxy-connection (stream \"telegram.org\" 443)
       (write-sequence request stream)
       (finish-output stream)
       (read-sequence response stream))"
  (multiple-value-bind (stream socket)
      (connect-through-proxy host port
                             :timeout (or timeout
                                            (proxy-config-timeout *global-proxy-config*)))
    (unwind-protect
         (progn ,@body)
      (when stream
        (close stream))
      (when socket
        (usocket:socket-close socket)))))
