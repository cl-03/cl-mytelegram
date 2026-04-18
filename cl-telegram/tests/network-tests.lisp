;;; network-tests.lisp --- Tests for network layer

(in-package #:cl-telegram/tests)

(def-suite* network-tests
  :description "Tests for network layer")

;;; ### TCP Client tests

(test make-tcp-client
  "Test TCP client creation"
  (let ((client (cl-telegram/network:make-tcp-client "149.154.167.51" 443)))
    (is (typep client 'cl-telegram/network::tcp-client))
    (is (string= (cl-telegram/network:client-host client) "149.154.167.51"))
    (is (= (cl-telegram/network:client-port client) 443))
    (is (not (cl-telegram/network:client-connected-p client)))))

(test make-sync-tcp-client
  "Test synchronous TCP client creation"
  (let ((client (cl-telegram/network:make-sync-tcp-client "149.154.167.51" 443)))
    (is (typep client 'cl-telegram/network::sync-tcp-client))
    (is (string= (cl-telegram/network:sync-client-host client) "149.154.167.51"))
    (is (= (cl-telegram/network:sync-client-port client) 443))))

;;; ### Connection tests

(test make-connection
  "Test connection creation"
  (let ((conn (cl-telegram/network:make-connection :host "149.154.167.51" :port 443)))
    (is (typep conn 'cl-telegram/network::connection))
    (is (= (length (cl-telegram/network:conn-session-id conn)) 8))
    (is (= (cl-telegram/network:conn-seqno conn) 0))
    (is (not (cl-telegram/network:connected-p conn)))))

(test generate-msg-id
  "Test message ID generation"
  (let ((conn (cl-telegram/network:make-connection :host "149.154.167.51" :port 443)))
    (let ((msg-id1 (cl-telegram/network:generate-msg-id conn))
          (msg-id2 (cl-telegram/network:generate-msg-id conn)))
      ;; Message IDs should be increasing
      (is (< msg-id1 msg-id2))
      ;; Should have client bit set (bit 0-1 = 01)
      (is (= (logand msg-id1 #b11) #b01)))))

(test get-and-incf-seqno
  "Test sequence number increment"
  (let ((conn (cl-telegram/network:make-connection :host "149.154.167.51" :port 443)))
    (let ((seq1 (cl-telegram/network::get-and-incf-seqno conn))
          (seq2 (cl-telegram/network::get-and-incf-seqno conn))
          (seq3 (cl-telegram/network::get-and-incf-seqno conn)))
      (is (= seq1 0))
      (is (= seq2 1))
      (is (= seq3 2)))))

;;; ### Event handler tests

(test event-handler-registration
  "Test event handler registration"
  (let ((conn (cl-telegram/network:make-connection :host "149.154.167.51" :port 443))
        (events-received nil))
    (cl-telegram/network:set-event-handler conn :update
      (lambda (data) (push :update events-received)))
    (cl-telegram/network:set-event-handler conn :error
      (lambda (data) (push :error events-received)))
    (is (= (length (cl-telegram/network:conn-event-handlers conn)) 2))
    ;; Test notification
    (cl-telegram/network:notify-event-handlers conn :update "test-data")
    (is (find :update events-received))))

(test event-handler-removal
  "Test event handler removal"
  (let ((conn (cl-telegram/network:make-connection :host "149.154.167.51" :port 443)))
    (let ((handler (lambda (data) (declare (ignore data)))))
      (cl-telegram/network:set-event-handler conn :update handler)
      (is (= (length (cl-telegram/network:conn-event-handlers conn)) 1))
      (cl-telegram/network:remove-event-handler conn handler)
      (is (= (length (cl-telegram/network:conn-event-handlers conn)) 0)))))

;;; ### RPC helper tests

(test rpc-handler-case-success
  "Test RPC handler case macro for success"
  (let ((result (cl-telegram/network::rpc-handler-case
                    (let ((x 10)) x)  ; Simulate success
                  ((:error code msg) (list :got-error code msg))
                  (result (list :got-result result)))))
    (is (equal result '(:got-result 10)))))

(test rpc-handler-case-error
  "Test RPC handler case macro for error"
  (let ((result (cl-telegram/network::rpc-handler-case
                    (list :error 404 "Not found")  ; Simulate error
                  ((:error code msg) (list :got-error code msg))
                  (result (list :got-result result)))))
    (is (equal result '(:got-error 404 "Not found")))))

;;; ### Integration test placeholder

(test connection-lifecycle-placeholder
  "Placeholder for connection lifecycle test (requires network)"
  ;; This test would require actual network connection
  (is (functionp #'cl-telegram/network:connect))
  (is (functionp #'cl-telegram/network:disconnect))
  (is (functionp #'cl-telegram/network:rpc-call)))

(defun run-network-tests ()
  "Run all network tests"
  (run! 'network-tests))
