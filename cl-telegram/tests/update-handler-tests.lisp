;;; update-handler-tests.lisp --- Tests for real-time update handler

(in-package #:cl-telegram/tests)

(def-suite* update-handler-tests
  :description "Tests for real-time update handler")

;;; ### Mock Connection

(defun make-mock-connection ()
  "Create a mock MTProto connection for testing."
  (list :connected t
        :dc-id 1
        :auth-key (make-array 256 :element-type '(unsigned-byte 8) :initial-element 0)))

;;; ### Handler Creation Tests

(test test-make-update-handler
  "Test update handler creation"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (is (typep handler 'cl-telegram/api::update-handler))
    (is (eq (cl-telegram/api::update-connection handler) conn))
    (is (typep (cl-telegram/api::update-handlers handler) 'hash-table))
    (is (not (cl-telegram/api::update-running-p handler)))))

;;; ### Handler Registration Tests

(test test-register-update-handler
  "Test handler registration"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn))
         (called-p nil)
         (test-handler (lambda (update)
                         (setf called-p t)
                         update)))
    ;; Save global handler
    (let ((old-handler cl-telegram/api::*update-handler*))
      (unwind-protect
           (progn
             ;; Set global handler
             (cl-telegram/api:set-update-handler handler)

             ;; Register handler for :test-update type
             (cl-telegram/api:register-update-handler :test-update test-handler)

             ;; Verify registration
             (let ((handlers (gethash :test-update (cl-telegram/api::update-handlers handler))))
               (is handlers "Handler should be registered")
               (is (equal handlers (list test-handler)))))
        ;; Restore global handler
        (cl-telegram/api:set-update-handler old-handler)))))

(test test-unregister-update-handler
  "Test handler unregistration"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn))
         (test-handler (lambda (update) update)))
    (cl-telegram/api:register-update-handler :test-unregister test-handler)
    (is (gethash :test-unregister (cl-telegram/api::update-handlers handler)))
    (cl-telegram/api:unregister-update-handler :test-unregister test-handler)
    (let ((handlers (gethash :test-unregister (cl-telegram/api::update-handlers handler))))
      (is (or (null handlers) (null (car handlers)) "Handler should be removed"))))

(test test-clear-update-handlers
  "Test clearing all handlers for a type"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:register-update-handler :test-clear (lambda (update) update))
    (cl-telegram/api:register-update-handler :test-clear (lambda (update) update))
    (cl-telegram/api:clear-update-handlers :test-clear)
    (is (null (gethash :test-clear (cl-telegram/api::update-handlers handler)))))

;;; ### Update Dispatch Tests

(test test-dispatch-update
  "Test update dispatch to handlers"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn))
         (called-with nil)
         (test-handler (lambda (update)
                         (setf called-with update))))
    (cl-telegram/api:set-update-handler handler)
    (cl-telegram/api:register-update-handler :test-dispatch test-handler)

    (let ((test-update (list :@type :test-dispatch :data "test-data")))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::dispatch-update test-update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (eq called-with test-update) "Handler should receive the update"))))

(test test-process-update-object
  "Test processing update objects"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn))
         (called nil))
    (cl-telegram/api:set-update-handler handler)

    ;; Register handler for new message
    (cl-telegram/api:register-update-handler :update-new-message
                                              (lambda (update) (setf called t)))

    (let ((update (list :@type :update-new-message
                        :message (list :chat-id 123 :id 1 :text "Hello"))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::process-update-object update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is called "Should dispatch to registered handler"))))

;;; ### Message Handler Tests

(test test-handle-new-message
  "Test new message handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-new-message
                        :message (list :chat-id 123
                                       :id 456
                                       :from (list :id 789 :first-name "Test")
                                       :text "Hello World"))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-new-message update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1) "Should increment count")
      (is (= (cl-telegram/api::update-last-update-id handler) 456) "Should update last ID"))))

(test test-handle-user-status-update
  "Test user status update handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-user-status
                        :user-id 123
                        :status (list :@type :userStatusOnline
                                      :expires 1234567890))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-user-status-update update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

(test test-handle-user-typing-update
  "Test user typing indicator handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-user-typing
                        :chat-id 123
                        :user-id 456
                        :action (list :@type :sendMessageTypingAction))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-user-typing-update update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

;;; ### Chat Handler Tests

(test test-handle-new-chat
  "Test new chat handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-new-chat
                        :chat (list :id 123
                                    :title "Test Chat"
                                    :type (list :@type :chatTypePrivate))))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-new-chat update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

(test test-handle-chat-title-update
  "Test chat title update handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-chat-title
                        :chat-id 123
                        :title "New Title"))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-chat-title-update update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

;;; ### Callback Query Handler Tests

(test test-handle-callback-query-update
  "Test callback query handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-new-callback-query
                        :callback-query (list :id "query-123"
                                              :chat-id 456
                                              :message-id 789
                                              :from (list :id 111 :first-name "User")
                                              :data "btn:action:123"))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-callback-query-update update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

(test test-handle-inline-query-update
  "Test inline query handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-new-inline-query
                        :inline-query (list :id "inline-123"
                                            :from (list :id 456 :first-name "User")
                                            :query "search term"
                                            :offset ""))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-inline-query-update update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

;;; ### System Handler Tests

(test test-handle-authorization-state-update
  "Test authorization state handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-authorization-state
                        :authorization-state (list :@type :authorizationStateReady)))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-authorization-state-update update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

(test test-handle-connection-state-update
  "Test connection state handler"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    (cl-telegram/api:set-update-handler handler)

    (let ((update (list :@type :update-connection-state
                        :state (list :@type :connectionStateReady)))))
      (let ((old-handler cl-telegram/api::*update-handler*))
        (unwind-protect
             (progn
               (cl-telegram/api:set-update-handler handler)
               (cl-telegram/api::handle-connection-state-update update))
          (cl-telegram/api:set-update-handler old-handler)))
      (is (= (cl-telegram/api::update-processed-count handler) 1)))))

;;; ### Statistics Tests

(test test-update-stats
  "Test update statistics"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    ;; Process some updates
    (let ((old-handler cl-telegram/api::*update-handler*))
      (unwind-protect
           (progn
             (cl-telegram/api:set-update-handler handler)
             (cl-telegram/api::handle-new-message (list :@type :update-new-message
                                                        :message (list :chat-id 123 :id 1)))
             (cl-telegram/api::handle-new-message (list :@type :update-new-message
                                                        :message (list :chat-id 123 :id 2))))
        (cl-telegram/api:set-update-handler old-handler)))

    (let ((stats (cl-telegram/api:update-stats handler)))
      (is (= (getf stats :processed) 2) "Should have processed 2 updates")
      (is (= (getf stats :queued) 0) "Queue should be empty")
      (is (not (getf stats :running)) "Should not be running"))))

;;; ### Start/Stop Polling Tests

(test test-start-stop-update-loop
  "Test starting and stopping update loop"
  (let* ((conn (make-mock-connection))
         (handler (cl-telegram/api:make-update-handler conn)))
    ;; Initially not running
    (is (not (cl-telegram/api::update-running-p handler)))

    ;; Note: Can't fully test polling without real MTProto connection
    ;; But we can test the start/stop mechanism

    ;; Start would fail without real connection, so just test stop
    (cl-telegram/api:stop-update-loop handler)

    ;; Verify stopped
    (is (not (cl-telegram/api::update-running-p handler)))))

;;; ### Macro Tests

(test test-with-update-handler
  "Test with-update-handler macro"
  (let ((conn (make-mock-connection))
        (handler-outside nil))
    (cl-telegram/api:with-update-handler (conn)
      (setf handler-outside cl-telegram/api::*update-handler*))
    ;; After macro exits, handler should be cleared
    (is (null cl-telegram/api::*update-handler*) "Handler should be cleared after unwind")
    (is (typep handler-outside 'cl-telegram/api::update-handler))))
