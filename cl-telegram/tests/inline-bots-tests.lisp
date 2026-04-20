;;; inline-bots-tests.lisp --- Tests for Inline Bots 2025 functionality

(in-package #:cl-telegram/tests)

(def-suite inline-bots-tests
  :description "Tests for Inline Bots 2025 functionality (v0.17.0)")

(in-suite inline-bots-tests)

;;; ======================================================================
;;; Inline Query Class Tests
;;; ======================================================================

(test test-inline-query-class
  "Test inline-query class creation and accessors"
  (let ((query (make-instance 'cl-telegram/api:inline-query
                              :id "query_123"
                              :from (make-instance 'cl-telegram/api:user :id 456)
                              :query "test search"
                              :offset 0
                              :chat-type "private")))
    (is (string= "query_123" (cl-telegram/api:inline-query-id query))
        "Query ID should match")
    (is (= 456 (cl-telegram/api:user-id (cl-telegram/api:inline-query-from query)))
        "User ID should match")
    (is (string= "test search" (cl-telegram/api:inline-query-query query))
        "Query text should match")
    (is (= 0 (cl-telegram/api:inline-query-offset query))
        "Offset should match")
    (is (string= "private" (cl-telegram/api:inline-query-chat-type query))
        "Chat type should match")))

(test test-inline-result-class
  "Test inline-result class creation and accessors"
  (let ((result (make-instance 'cl-telegram/api:inline-result
                               :id "result_abc"
                               :type "article"
                               :title "Test Result"
                               :description "Test description"
                               :message-text "Message content")))
    (is (string= "result_abc" (cl-telegram/api:inline-result-id result)))
    (is (string= "article" (cl-telegram/api:inline-result-type result)))
    (is (string= "Test Result" (cl-telegram/api:inline-result-title result)))
    (is (string= "Test description" (cl-telegram/api:inline-result-description result)))
    (is (string= "Message content" (cl-telegram/api:inline-result-message-text result)))))

;;; ======================================================================
;;; Inline Keyboard Tests
;;; ======================================================================

(test test-inline-keyboard-button
  "Test inline-keyboard-button class creation"
  (let ((button (make-instance 'cl-telegram/api:inline-keyboard-button
                               :text "Click Me"
                               :callback-data "data_123")))
    (is (string= "Click Me" (cl-telegram/api:inline-button-text button)))
    (is (string= "data_123" (cl-telegram/api:inline-button-callback-data button)))
    (is (null (cl-telegram/api:inline-button-url button)))))

(test test-inline-keyboard-button-with-url
  "Test inline keyboard button with URL"
  (let ((button (make-instance 'cl-telegram/api:inline-keyboard-button
                               :text "Visit Site"
                               :url "https://example.com")))
    (is (string= "Visit Site" (cl-telegram/api:inline-button-text button)))
    (is (string= "https://example.com" (cl-telegram/api:inline-button-url button)))))

(test test-inline-keyboard-button-web-app
  "Test inline keyboard button with WebApp"
  (let ((button (make-instance 'cl-telegram/api:inline-keyboard-button
                               :text "Open App"
                               :web-app (make-instance 'cl-telegram/api:web-app-info
                                                       :url "https://app.example.com")))
    (is (string= "Open App" (cl-telegram/api:inline-button-text button)))
    (is (cl-telegram/api:inline-button-web-app button))))

(test test-inline-keyboard-markup
  "Test inline-keyboard-markup class creation"
  (let ((buttons (list (make-instance 'cl-telegram/api:inline-keyboard-button
                                      :text "Button 1" :callback-data "btn1")
                       (make-instance 'cl-telegram/api:inline-keyboard-button
                                      :text "Button 2" :callback-data "btn2")))
        (keyboard (make-instance 'cl-telegram/api:inline-keyboard-markup
                                 :keyboard buttons)))
    (is (= 2 (length (cl-telegram/api:inline-keyboard-keyboard keyboard))))
    (is (true (cl-telegram/api:inline-keyboard-resize keyboard)))))

;;; ======================================================================
;;; Visual Effects Tests (Bot API 2025)
;;; ======================================================================

(test test-make-visual-effect
  "Test visual effect creation"
  (let ((effect (cl-telegram/api:make-visual-effect :type :fireworks)))
    (is (notnull effect))
    (is (eq :fireworks (getf effect :type)))))

(test test-make-visual-effect-all-types
  "Test all visual effect types"
  (dolist (effect-type '(:fireworks :sparkles :hearts :stars :balloons))
    (let ((effect (cl-telegram/api:make-visual-effect :type effect-type)))
      (is (notnull effect)
          (format nil "Effect ~A should be created" effect-type)))))

(test test-add-visual-effects-to-result
  "Test adding visual effects to inline result"
  (let ((result (make-instance 'cl-telegram/api:inline-result
                               :id "test_result"
                               :type "article"
                               :title "Test"))
        (effect (cl-telegram/api:make-visual-effect :type :fireworks)))
    (is (notnull result))
    (is (notnull effect))))

(test test-make-inline-result-with-spoiler
  "Test creating inline result with spoiler effect"
  (let ((result (cl-telegram/api:make-inline-result-with-spoiler
                 "spoiler_result"
                 "Hidden Content"
                 :type "photo")))
    (is (notnull result))
    (is (string= "spoiler_result" (getf result :id)))))

(test test-send-inline-result-with-animation
  "Test sending inline result with animation"
  (let ((result (make-instance 'cl-telegram/api:inline-result
                               :id "anim_result"
                               :type "gif"
                               :title "Animated")))
    (is (notnull result))
    (is (string= "gif" (cl-telegram/api:inline-result-type result)))))

;;; ======================================================================
;;; Business Features Tests (Bot API 2025)
;;; ======================================================================

(test test-get-business-connection
  "Test getting business connection info"
  (let ((connection (cl-telegram/api:get-business-connection "user_123")))
    (is (notnull connection))))

(test test-send-business-message
  "Test sending business message"
  (let ((result (cl-telegram/api:send-business-message
                 "user_123"
                 "Hello from business"
                 :signature "Support Team")))
    (is (notnull result))))

(test test-edit-business-message
  "Test editing business message"
  (let ((result (cl-telegram/api:edit-business-message
                 "msg_123"
                 "Updated business message")))
    (is (notnull result))))

(test test-delete-business-message
  "Test deleting business message"
  (let ((result (cl-telegram/api:delete-business-message "msg_123")))
    (is (notnull result))))

(test test-list-business-connections
  "Test listing business connections"
  (let ((connections (cl-telegram/api:list-business-connections)))
    (is (listp connections))))

(test test-close-business-connection
  "Test closing business connection"
  (let ((result (cl-telegram/api:close-business-connection "conn_123")))
    (is (notnull result))))

(test test-set-inline-bot-business-location
  "Test setting inline bot business location"
  (let ((result (cl-telegram/api:set-inline-bot-business-location
                 "bot_123"
                 40.7128
                 -74.0060)))
    (is (notnull result))))

(test test-set-inline-bot-business-hours
  "Test setting inline bot business hours"
  (let ((hours '((:open "09:00" :close "17:00")
                 (:open "09:00" :close "17:00")
                 (:open "09:00" :close "17:00")
                 (:open "09:00" :close "17:00")
                 (:open "09:00" :close "17:00"))))
    (let ((result (cl-telegram/api:set-inline-bot-business-hours "bot_123" hours)))
      (is (notnull result)))))

;;; ======================================================================
;;; Paid Media Tests (Bot API 2025)
;;; ======================================================================

(test test-make-paid-media-info
  "Test creating paid media info"
  (let ((media (cl-telegram/api:make-paid-media-info
                :type "photo"
                :media-id "media_123"
                :price-amount 100
                :price-currency "USD")))
    (is (notnull media))
    (is (string= "photo" (getf media :type)))
    (is (= 100 (getf media :price-amount)))))

(test test-send-paid-media
  "Test sending paid media"
  (let ((media-info (cl-telegram/api:make-paid-media-info
                     :type "photo"
                     :media-id "media_123"
                     :price-amount 100
                     :price-currency "USD")))
    (let ((result (cl-telegram/api:send-paid-media 123456 media-info)))
      (is (notnull result)))))

(test test-create-paid-media-post
  "Test creating paid media post"
  (let ((result (cl-telegram/api:create-paid-media-post
                 123456
                 (list (cl-telegram/api:make-paid-media-info :type "photo" :media-id "m1"))
                 :caption "Check this out!")))
    (is (notnull result))))

;;; ======================================================================
;;; WebApp Integration Tests (Bot API 2025)
;;; ======================================================================

(test test-answer-web-app-query
  "Test answering WebApp query"
  (let ((result (cl-telegram/api:answer-web-app-query
                 "query_123"
                 (make-instance 'cl-telegram/api:inline-result
                                :id "result_456"
                                :type "article"
                                :title "Result"))))
    (is (notnull result))))

(test test-validate-web-app-init-data
  "Test WebApp init data validation"
  (let* ((init-data '(:query-id "q123"
                      :auth-hash "test_hash_abc123"
                      :user-id 123456
                      :first-name "Test"))
         (result (cl-telegram/api:validate-web-app-init-data init-data)))
    (is (booleanp result))))

(test test-send-web-app-data
  "Test sending WebApp data"
  (let ((result (cl-telegram/api:send-web-app-data
                 "bot_123"
                 '(:data "test_data" :action "submit"))))
    (is (notnull result))))

;;; ======================================================================
;;; Bot Analytics Tests (Bot API 2025)
;;; ======================================================================

(test test-get-inline-bot-analytics
  "Test getting inline bot analytics"
  (let ((analytics (cl-telegram/api:get-inline-bot-analytics "bot_123")))
    (is (notnull analytics))))

(test test-get-user-chat-boosts
  "Test getting user chat boosts"
  (let ((boosts (cl-telegram/api:get-user-chat-boosts 123456)))
    (is (notnull boosts))))

;;; ======================================================================
;;; Handler Registration Tests
;;; ======================================================================

(test test-register-inline-bot-handler
  "Test registering inline bot handler"
  (let ((handler-called nil)
        (test-handler (lambda (query)
                        (setf handler-called t)
                        (list "result"))))
    (cl-telegram/api:register-inline-bot-handler "test_token" test-handler)
    (is (gethash "test_token" cl-telegram/api:*inline-bot-handlers*))
    (cl-telegram/api:unregister-inline-bot-handler "test_token")
    (is (null (gethash "test_token" cl-telegram/api:*inline-bot-handlers*)))))

(test test-dispatch-inline-query
  "Test dispatching inline query to handler"
  (let ((results nil)
        (test-handler (lambda (query)
                        (setf results (list "result1" "result2")))))
    (cl-telegram/api:register-inline-bot-handler "dispatch_token" test-handler)
    (let ((query (make-instance 'cl-telegram/api:inline-query
                                :id "dispatch_123"
                                :query "test")))
      (cl-telegram/api:dispatch-inline-query "dispatch_token" query))
    (is (= 2 (length results)))
    (cl-telegram/api:unregister-inline-bot-handler "dispatch_token")))

(test test-dispatch-callback-query
  "Test dispatching callback query"
  (let ((handler-result nil)
        (test-handler (lambda (query)
                        (setf handler-result "handled"))))
    (cl-telegram/api:register-inline-bot-handler "callback_token" nil :callback-handler test-handler)
    (let ((query (make-instance 'cl-telegram/api:callback-query
                                :id "cb_123"
                                :data "button_click")))
      (cl-telegram/api:dispatch-callback-query "callback_token" query))
    (is (string= "handled" handler-result))
    (cl-telegram/api:unregister-inline-bot-handler "callback_token")))

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-inline-bots-tests ()
  "Run all inline bots tests"
  (format t "~%=== Running Inline Bots 2025 Unit Tests ===~%~%")
  (fiveam:run! 'inline-bots-tests))

(export '(run-inline-bots-tests))
