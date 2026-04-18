;;; proxy-tests.lisp --- Tests for proxy support

(in-package #:cl-telegram/network)

(in-package #:cl-telegram/tests)

(def-suite* proxy-tests
  :description "Tests for SOCKS5 and HTTP proxy support")

;;; ### Proxy Configuration Tests

(test proxy-config-default
  "Test default proxy configuration is disabled"
  (reset-proxy-config)
  (is (eq :none (proxy-config-type *global-proxy-config*)))
  (is (string= "" (proxy-config-host *global-proxy-config*)))
  (is (= 0 (proxy-config-port *global-proxy-config*)))
  (is (not (proxy-enabled-p))))

(test proxy-config-socks5
  "Test SOCKS5 proxy configuration"
  (configure-proxy :type :socks5 :host "127.0.0.1" :port 1080)
  (is (eq :socks5 (proxy-config-type *global-proxy-config*)))
  (is (string= "127.0.0.1" (proxy-config-host *global-proxy-config*)))
  (is (= 1080 (proxy-config-port *global-proxy-config*)))
  (is (proxy-enabled-p))
  (reset-proxy-config))

(test proxy-config-http
  "Test HTTP proxy configuration"
  (configure-proxy :type :http :host "proxy.example.com" :port 8080
                   :username "user" :password "pass")
  (is (eq :http (proxy-config-type *global-proxy-config*)))
  (is (string= "proxy.example.com" (proxy-config-host *global-proxy-config*)))
  (is (= 8080 (proxy-config-port *global-proxy-config*)))
  (is (string= "user" (proxy-config-username *global-proxy-config*)))
  (is (string= "pass" (proxy-config-password *global-proxy-config*)))
  (is (proxy-enabled-p))
  (reset-proxy-config))

(test proxy-config-reset
  "Test proxy configuration reset"
  (configure-proxy :type :socks5 :host "test" :port 1234)
  (is (proxy-enabled-p))
  (reset-proxy-config)
  (is (not (proxy-enabled-p)))
  (is (eq :none (proxy-config-type *global-proxy-config*))))

(test get-proxy-info
  "Test proxy info retrieval"
  (configure-proxy :type :socks5 :host "localhost" :port 1080
                   :username "admin" :password "secret"
                   :use-dns t :timeout 15000)
  (let ((info (get-proxy-info)))
    (is (getf info :enabled))
    (is (eq :socks5 (getf info :type)))
    (is (string= "localhost" (getf info :host)))
    (is (= 1080 (getf info :port)))
    (is (getf info :has-auth))
    (is (getf info :use-dns))
    (is (= 15000 (getf info :timeout)))))
  (reset-proxy-config))

;;; ### SOCKS5 Protocol Tests

(test socks5-convert-host-ipv4
  "Test IPv4 address conversion for SOCKS5"
  (multiple-value-bind (addr-type addr-bytes)
      (socks5-convert-host "192.168.1.100")
    (is (= addr-type +socks5-addr-ipv4+))
    (is (= 4 (length addr-bytes)))
    (is (= 192 (aref addr-bytes 0)))
    (is (= 168 (aref addr-bytes 1)))
    (is (= 1 (aref addr-bytes 2)))
    (is (= 100 (aref addr-bytes 3)))))

(test socks5-convert-host-domain
  "Test domain name conversion for SOCKS5"
  (multiple-value-bind (addr-type addr-bytes)
      (socks5-convert-host "telegram.org")
    (is (= addr-type +socks5-addr-domain+))
    ;; First byte is length
    (is (= 12 (aref addr-bytes 0)))
    ;; Rest is domain bytes
    (is (string= "telegram.org"
                 (babel:octets-to-string (subseq addr-bytes 1)))))

;;; ### Proxy Error Tests

(test proxy-error-conditions
  "Test proxy error signaling"
  (signals-error
   (error 'proxy-error
          :message "Test error"
          :proxy-host "test"
          :proxy-port 1234)
   proxy-error))

(test proxy-invalid-type
  "Test error on invalid proxy type"
  (let ((config (make-proxy-config :type :invalid)))
    (signals-error
     (connect-through-proxy "target" 443 :config config)
     proxy-error)))

;;; ### Helper function tests

(test proxy-enabled-predicate
  "Test proxy-enabled-p with various configurations"
  ;; Disabled
  (reset-proxy-config)
  (is (not (proxy-enabled-p)))

  ;; Enabled - missing host
  (configure-proxy :type :socks5 :port 1080)
  (is (not (proxy-enabled-p)))

  ;; Enabled - missing port
  (configure-proxy :type :socks5 :host "test")
  (is (not (proxy-enabled-p)))

  ;; Fully enabled
  (configure-proxy :type :socks5 :host "test" :port 1080)
  (is (proxy-enabled-p))
  (reset-proxy-config))

;;; ### Integration-style tests (mocked)

(test proxy-configuration-roundtrip
  "Test configuration can be set and retrieved"
  (let ((original-config (list :type :socks5
                               :host "proxy.test.local"
                               :port 9050
                               :username "testuser"
                               :password "testpass"
                               :use-dns t
                               :timeout 20000)))
    (apply #'configure-proxy original-config)
    (let ((info (get-proxy-info)))
      (is (getf info :enabled))
      (is (eq :socks5 (getf info :type)))
      (is (string= "proxy.test.local" (getf info :host)))
      (is (= 9050 (getf info :port)))
      (is (getf info :has-auth))
      (is (getf info :use-dns))
      (is (= 20000 (getf info :timeout)))))
  (reset-proxy-config))
