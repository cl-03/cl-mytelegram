;;; api-tests.lisp --- Tests for API layer

(in-package #:cl-telegram/tests)

(def-suite* api-tests
  :description "Tests for API layer")

;;; ### Authentication API tests

(test auth-state-initial
  "Test initial auth state"
  (let ((state (cl-telegram/api:get-authentication-state)))
    (is (member state '(:wait-tdlib-parameters :wait-phone-number)))))

(test set-phone-number
  "Test setting phone number"
  (let ((result (cl-telegram/api:set-authentication-phone-number "+1234567890")))
    (is result)
    (is (cl-telegram/api:needs-code-p))))

(test request-code
  "Test requesting authentication code"
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (let ((result (cl-telegram/api:request-authentication-code)))
    (is (eq (car result) :success))
    (is (getf result :code-sent))))

(test check-code-valid
  "Test checking valid code"
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:request-authentication-code)
  (let ((result (cl-telegram/api:check-authentication-code "12345")))
    (is (eq (car result) :success))
    (is (cl-telegram/api:authorized-p))))

(test check-code-invalid
  "Test checking invalid code"
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (let ((result (cl-telegram/api:check-authentication-code "00000")))
    (is (eq (car result) :error))
    (is (not (cl-telegram/api:authorized-p)))))

(test reset-session
  "Test resetting auth session"
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (is (cl-telegram/api:needs-code-p))
  (cl-telegram/api:reset-auth-session)
  (is (member (cl-telegram/api:get-authentication-state)
              '(:wait-tdlib-parameters :wait-phone-number))))

(test authorized-predicate
  "Test authorized-p function"
  (cl-telegram/api:reset-auth-session)
  (is (not (cl-telegram/api:authorized-p)))
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (is (not (cl-telegram/api:authorized-p)))
  (cl-telegram/api:check-authentication-code "12345")
  (is (cl-telegram/api:authorized-p)))

;;; ### Registration tests

(test register-user-valid
  "Test registering a new user"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (let ((result (cl-telegram/api:register-user "John" "Doe" :bio "Lisp developer")))
    (is (eq (car result) :success))
    (is (getf result :registered))))

(test register-user-invalid-name
  "Test registering with invalid name"
  (let ((result (cl-telegram/api:register-user "" "Doe")))
    (is (eq (car result) :error))))

;;; ### Session info tests

(test get-auth-session
  "Test getting session info"
  (let ((session (cl-telegram/api:get-auth-session)))
    (is (listp session))
    (is (getf session :state))
    (is (getf session :phone))
    (is (getf session :code-info))))

;;; ### TDLib compatibility tests

(test tdlib-set-parameters
  "Test TDLib compatible setTdlibParameters"
  (let ((result (cl-telegram/api:|setTdlibParameters| :parameters '())))
    (is (getf result :ok))))

(test tdlib-set-phone
  "Test TDLib compatible setAuthenticationPhoneNumber"
  (cl-telegram/api:|setAuthenticationPhoneNumber| "+1234567890")
  (is (cl-telegram/api:needs-code-p)))

(test tdlib-check-code
  "Test TDLib compatible checkAuthenticationCode"
  (cl-telegram/api:|setAuthenticationPhoneNumber| "+1234567890")
  (let ((result (cl-telegram/api:|checkAuthenticationCode| "12345")))
    (is (eq (car result) :success))))

(test tdlib-register
  "Test TDLib compatible registerUser"
  (let ((result (cl-telegram/api:|registerUser| "Jane" "Doe")))
    (is (eq (car result) :success))))

;;; ### Demo flow test

(test demo-auth-flow
  "Test demo authentication flow"
  (let ((result (cl-telegram/api:demo-auth-flow)))
    (is result)))

;;; ### Connection tests

(test ensure-connection
  "Test ensuring auth connection"
  (let ((conn (cl-telegram/api:ensure-auth-connection)))
    (is conn)
    (is (typep conn 'cl-telegram/network::connection))))

(test close-connection
  "Test closing auth connection"
  (cl-telegram/api:ensure-auth-connection)
  (let ((result (cl-telegram/api:close-auth-connection)))
    (is result)))

;;; ### Messages API tests

(test send-message-authorized
  "Test send-message when authorized"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:send-message 123 "Hello, World!")
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test send-message-unauthorized
  "Test send-message when not authorized"
  (cl-telegram/api:reset-auth-session)
  (multiple-value-bind (result error)
      (cl-telegram/api:send-message 123 "Hello")
    (is (eq error :not-authorized))))

(test send-message-invalid-text
  "Test send-message with invalid text"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  ;; Empty message
  (multiple-value-bind (result error)
      (cl-telegram/api:send-message 123 "")
    (is (eq error :invalid-message)))
  ;; Too long message
  (multiple-value-bind (result error)
      (cl-telegram/api:send-message 123 (make-string 5000 :initial-element #\a))
    (is (eq error :invalid-message))))

(test get-messages-authorized
  "Test get-messages when authorized"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:get-messages 123 :limit 10)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test delete-messages
  "Test delete-messages"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:delete-messages 123 '(1 2 3))
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test edit-message
  "Test edit-message"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:edit-message 123 456 "Edited text")
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

;;; ### Chats API tests

(test get-chats-authorized
  "Test get-chats when authorized"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:get-chats :limit 50)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test get-chats-unauthorized
  "Test get-chats when not authorized"
  (cl-telegram/api:reset-auth-session)
  (multiple-value-bind (result error)
      (cl-telegram/api:get-chats)
    (is (eq error :not-authorized))))

(test get-chat
  "Test get-chat"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:get-chat 123)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test create-private-chat
  "Test create-private-chat"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:create-private-chat 123)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test send-chat-action
  "Test send-chat-action"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:send-chat-action 123 :typing)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

;;; ### Users API tests

(test get-me-authorized
  "Test get-me when authorized"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:get-me)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test get-me-unauthorized
  "Test get-me when not authorized"
  (cl-telegram/api:reset-auth-session)
  (multiple-value-bind (result error)
      (cl-telegram/api:get-me)
    (is (eq error :not-authorized))))

(test get-user
  "Test get-user"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:get-user 123)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test get-users
  "Test get-users"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:get-users '(1 2 3))
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test search-users
  "Test search-users"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:search-users "john" :limit 10)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

(test block-unblock-user
  "Test block and unblock user"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (block-result block-error)
      (cl-telegram/api:block-user 123)
    (is (not (eq block-error :not-authorized))))
  (multiple-value-bind (unblock-result unblock-error)
      (cl-telegram/api:unblock-user 123)
    (is (not (eq unblock-error :not-authorized)))))

(test get-contacts
  "Test get-contacts"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:get-contacts)
    ;; Should not be :not-authorized
    (is (not (eq error :not-authorized)))))

;;; ### TDLib compatibility wrappers

(test tdlib-send-message
  "Test TDLib compatible sendMessage"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:|sendMessage| 123 "Test message")
    (is (not (eq error :not-authorized)))))

(test tdlib-get-chats
  "Test TDLib compatible getChats"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:|getChats|)
    (is (not (eq error :not-authorized)))))

(test tdlib-get-user
  "Test TDLib compatible getUser"
  (cl-telegram/api:reset-auth-session)
  (cl-telegram/api:set-authentication-phone-number "+1234567890")
  (cl-telegram/api:check-authentication-code "12345")
  (multiple-value-bind (result error)
      (cl-telegram/api:|getUser| 123)
    (is (not (eq error :not-authorized)))))

(defun run-api-tests ()
  "Run all API tests"
  (run! 'api-tests))
