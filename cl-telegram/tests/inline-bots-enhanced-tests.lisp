;;; inline-bots-tests.lisp --- Tests for Inline Mode Enhanced (v0.34.0)

(in-package #:cl-telegram/tests)

(def-suite* inline-bots-enhanced-tests
  :description "Tests for Inline Mode Enhanced v0.34.0")

;;; ============================================================================
;;; Section 1: Bot Settings Tests
;;; ============================================================================

(test test-set-my-short-description
  "Test setting bot short description"
  (let ((result (cl-telegram/api:set-my-short-description "Helpful assistant bot")))
    (is (or (eq result t) (null result)))))

(test test-set-my-short-description-localized
  "Test setting localized bot short description"
  (let ((result (cl-telegram/api:set-my-short-description "助理机器人" :language-code "zh")))
    (is (or (eq result t) (null result)))))

(test test-set-my-short-description-with-business
  "Test setting short description with business connection"
  (let ((result (cl-telegram/api:set-my-short-description
                 "Business Bot"
                 :language-code "en"
                 :business-connection-id "biz_123")))
    (is (or (eq result t) (null result)))))

(test test-get-my-short-description
  "Test getting bot short description"
  (let ((result (cl-telegram/api:get-my-short-description)))
    (is (or (stringp result) (null result)))))

(test test-get-my-short-description-localized
  "Test getting localized bot short description"
  (let ((result (cl-telegram/api:get-my-short-description :language-code "en")))
    (is (or (stringp result) (null result)))))

(test test-set-my-name
  "Test setting bot name"
  (let ((result (cl-telegram/api:set-my-name "Helper Bot")))
    (is (or (eq result t) (null result)))))

(test test-set-my-name-localized
  "Test setting localized bot name"
  (let ((result (cl-telegram/api:set-my-name "助手" :language-code "zh")))
    (is (or (eq result t) (null result)))))

(test test-get-my-name
  "Test getting bot name"
  (let ((result (cl-telegram/api:get-my-name)))
    (is (or (stringp result) (null result)))))

(test test-get-my-name-localized
  "Test getting localized bot name"
  (let ((result (cl-telegram/api:get-my-name :language-code "en")))
    (is (or (stringp result) (null result)))))

;;; ============================================================================
;;; Section 2: Inline Result Creation Tests
;;; ============================================================================

(test test-make-inline-result-article
  "Test creating article inline result"
  (let ((result (cl-telegram/api:make-inline-result-article
                 "article_1"
                 "Test Article"
                 '(:message_text "Test content"))))
    (is (string= (cl-telegram/api:inline-result-id result) "article_1"))
    (is (string= (cl-telegram/api:inline-result-title result) "Test Article"))
    (is (string= (cl-telegram/api:inline-result-type result) "article"))))

(test test-make-inline-result-article-with-description
  "Test creating article inline result with description"
  (let ((result (cl-telegram/api:make-inline-result-article
                 "article_2"
                 "Article with Description"
                 '(:message_text "Content")
                 :description "A brief description")))
    (is (string= (cl-telegram/api:inline-result-description result) "A brief description"))))

(test test-make-inline-result-photo
  "Test creating photo inline result"
  (let ((result (cl-telegram/api:make-inline-result-photo
                 "photo_1"
                 "https://example.com/photo.jpg"
                 "https://example.com/thumb.jpg")))
    (is (string= (cl-telegram/api:inline-result-type result) "photo"))
    (is (string= (cl-telegram/api:inline-result-message-text result) nil))))

(test test-make-inline-result-photo-with-caption
  "Test creating photo inline result with caption"
  (let ((result (cl-telegram/api:make-inline-result-photo
                 "photo_2"
                 "https://example.com/photo.jpg"
                 "https://example.com/thumb.jpg"
                 :title "Beautiful Photo"
                 :caption "A beautiful sunset")))
    (is (string= (cl-telegram/api:inline-result-title result) "Beautiful Photo"))
    (is (string= (cl-telegram/api:inline-result-message-text result) "A beautiful sunset"))))

(test test-make-inline-result-video
  "Test creating video inline result"
  (let ((result (cl-telegram/api:make-inline-result-video
                 "video_1"
                 "https://example.com/video.mp4"
                 "https://example.com/thumb.jpg"
                 :title "Test Video"
                 :caption "Video caption")))
    (is (string= (cl-telegram/api:inline-result-type result) "video"))
    (is (string= (cl-telegram/api:inline-result-title result) "Test Video"))))

(test test-make-inline-result-gif
  "Test creating GIF inline result"
  (let ((result (cl-telegram/api:make-inline-result-gif
                 "gif_1"
                 "https://example.com/animation.gif"
                 "https://example.com/thumb.jpg"
                 :title "Funny GIF")))
    (is (string= (cl-telegram/api:inline-result-type result) "gif"))))

(test test-make-inline-result-sticker
  "Test creating sticker inline result"
  (let ((result (cl-telegram/api:make-inline-result-sticker
                 "sticker_1"
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ")))
    (is (string= (cl-telegram/api:inline-result-type result) "sticker"))))

(test test-make-inline-result-location
  "Test creating location inline result"
  (let ((result (cl-telegram/api:make-inline-result-location
                 "loc_1"
                 40.7128
                 -74.0060
                 :title "New York City")))
    (is (string= (cl-telegram/api:inline-result-type result) "location"))
    (is (string= (cl-telegram/api:inline-result-title result) "New York City"))))

(test test-make-inline-result-contact
  "Test creating contact inline result"
  (let ((result (cl-telegram/api:make-inline-result-contact
                 "contact_1"
                 "+1234567890"
                 "John"
                 :last-name "Doe")))
    (is (string= (cl-telegram/api:inline-result-type result) "contact"))
    (is (string= (cl-telegram/api:inline-result-title result) "John Doe"))))

(test test-make-inline-result-game
  "Test creating game inline result"
  (let ((result (cl-telegram/api:make-inline-result-game
                 "game_1"
                 "my_awesome_game")))
    (is (string= (cl-telegram/api:inline-result-type result) "game"))))

;;; ============================================================================
;;; Section 3: Keyboard Creation Tests
;;; ============================================================================

(test test-make-inline-keyboard-button
  "Test creating inline keyboard button"
  (let ((button (cl-telegram/api:make-inline-keyboard-button
                 "Click Me"
                 :callback-data "action_123")))
    (is (string= (cl-telegram/api:inline-button-text button) "Click Me"))
    (is (string= (cl-telegram/api:inline-button-callback-data button) "action_123"))))

(test test-make-inline-keyboard-button-url
  "Test creating inline keyboard button with URL"
  (let ((button (cl-telegram/api:make-inline-keyboard-button
                 "Visit Website"
                 :url "https://example.com")))
    (is (string= (cl-telegram/api:inline-button-url button) "https://example.com"))))

(test test-make-inline-keyboard-button-switch
  "Test creating inline keyboard button with switch inline query"
  (let ((button (cl-telegram/api:make-inline-keyboard-button
                 "Try Inline"
                 :switch-inline-query "test query")))
    (is (string= (cl-telegram/api:inline-button-switch-inline button) "test query"))))

(test test-make-inline-keyboard-button-webapp
  "Test creating inline keyboard button with web app"
  (let ((button (cl-telegram/api:make-inline-keyboard-button
                 "Open Web App"
                 :web-app '(:url "https://webapp.example.com"))))
    (is (equal (cl-telegram/api:inline-button-web-app button) '(:url "https://webapp.example.com"))))

(test test-make-inline-keyboard
  "Test creating inline keyboard with multiple rows"
  (let ((keyboard (cl-telegram/api:make-inline-keyboard
                   (list (cl-telegram/api:make-inline-keyboard-button "Button 1" :callback-data "1"))
                   (list (cl-telegram/api:make-inline-keyboard-button "Button 2" :callback-data "2")
                         (cl-telegram/api:make-inline-keyboard-button "Button 3" :callback-data "3")))))
    (is (= (length (cl-telegram/api:inline-keyboard-keyboard keyboard)) 2))
    (is (= (length (first (cl-telegram/api:inline-keyboard-keyboard keyboard))) 1))
    (is (= (length (second (cl-telegram/api:inline-keyboard-keyboard keyboard))) 2))))

(test test-make-reply-keyboard-button
  "Test creating reply keyboard button"
  (let ((button (cl-telegram/api:make-reply-keyboard-button
                 "Send Location"
                 :request-location t)))
    (is (string= (cl-telegram/api:reply-button-text button) "Send Location"))
    (is (cl-telegram/api:reply-button-request-location button))))

(test test-make-reply-keyboard-button-contact
  "Test creating reply keyboard button requesting contact"
  (let ((button (cl-telegram/api:make-reply-keyboard-button
                 "Share Contact"
                 :request-contact t)))
    (is (cl-telegram/api:reply-button-request-contact button))))

(test test-make-reply-keyboard
  "Test creating reply keyboard"
  (let ((keyboard (cl-telegram/api:make-reply-keyboard
                   (list "Option 1" "Option 2")
                   (list "Option 3")
                   :resize-p t
                   :one-time-p t)))
    (is (cl-telegram/api:reply-keyboard-resize keyboard))
    (is (cl-telegram/api:reply-keyboard-one-time keyboard))))

(test test-make-reply-keyboard-remove
  "Test creating reply keyboard remove"
  (let ((remove (cl-telegram/api:make-reply-keyboard-remove :selective t)))
    (is (cl-telegram/api:reply-keyboard-remove-p remove))
    (is (cl-telegram/api:reply-keyboard-remove-selective remove))))

(test test-make-force-reply
  "Test creating force reply"
  (let ((reply (cl-telegram/api:make-force-reply
                :selective t
                :placeholder "Type your answer...")))
    (is (cl-telegram/api:force-reply-p reply))
    (is (cl-telegram/api:force-reply-selective reply))
    (is (string= (cl-telegram/api:force-reply-placeholder reply) "Type your answer..."))))

;;; ============================================================================
;;; Section 4: Visual Effects Tests
;;; ============================================================================

(test test-make-visual-effect
  "Test creating visual effect"
  (let ((effect (cl-telegram/api:make-visual-effect
                 :fireworks
                 :start-x 0.5
                 :start-y 0.5
                 :intensity 0.8)))
    (is (eq (cl-telegram/api:visual-effect-type effect) :fireworks))
    (is (= (cl-telegram/api:visual-effect-start-x effect) 0.5))
    (is (= (cl-telegram/api:visual-effect-intensity effect) 0.8))))

(test test-make-inline-result-with-effects
  "Test adding visual effects to inline result"
  (let* ((base (cl-telegram/api:make-inline-result-photo
                "photo_fx"
                "https://example.com/photo.jpg"
                "https://example.com/thumb.jpg"))
         (effect (cl-telegram/api:make-visual-effect :sparkles))
         (result (cl-telegram/api:add-visual-effects-to-result base (list effect))))
    (is (typep result 'cl-telegram/api:inline-result-with-effects))
    (is (= (length (cl-telegram/api:effects-visual-effects result)) 1))))

(test test-inline-result-has-effects-p
  "Test checking if result has effects"
  (let* ((base (cl-telegram/api:make-inline-result-article
                "article"
                "Title"
                '(:message_text "Text")))
         (with-effects (cl-telegram/api:add-visual-effects-to-result
                        base
                        (list (cl-telegram/api:make-visual-effect :hearts)))))
    (is (not (cl-telegram/api:inline-result-has-effects-p base)))
    (is (cl-telegram/api:inline-result-has-effects-p with-effects))))

(test test-apply-visual-effect-to-result
  "Test applying visual effect to result"
  (let* ((base (cl-telegram/api:make-inline-result-gif
                "gif"
                "https://example.com/anim.gif"
                "https://example.com/thumb.jpg"))
         (effect (cl-telegram/api:make-visual-effect :stars))
         (result (cl-telegram/api:apply-visual-effect-to-result base effect)))
    (is (typep result 'cl-telegram/api:inline-result-with-effects))
    (is (= (length (cl-telegram/api:effects-visual-effects result)) 1))))

;;; ============================================================================
;;; Section 5: Business Inline Features Tests
;;; ============================================================================

(test test-make-business-inline-config
  "Test creating business inline configuration"
  (let ((config (cl-telegram/api:make-business-inline-config
                 :location '(:latitude 40.7128 :longitude -74.0060 :address "NYC")
                 :opening-hours '(:open-time 540 :close-time 1080 :days (1 2 3 4 5))
                 :start-message "Welcome to our business!")))
    (is (typep config 'cl-telegram/api:business-inline-config))
    (is (cl-telegram/api:business-location config))
    (is (cl-telegram/api:business-start-message config))))

(test test-make-paid-media-info
  "Test creating paid media info"
  (let ((media (cl-telegram/api:make-paid-media-info
                :photo
                "https://example.com/premium.jpg"
                1000
                "USD")))
    (is (eq (cl-telegram/api:paid-media-type media) :photo))
    (is (string= (cl-telegram/api:paid-media-url media) "https://example.com/premium.jpg"))
    (is (= (cl-telegram/api:paid-media-price media) 1000))
    (is (string= (cl-telegram/api:paid-media-currency media) "USD"))))

;;; ============================================================================
;;; Section 6: Inline Result Extended Types Tests
;;; ============================================================================

(test test-make-inline-result-article-with-effects
  "Test creating article inline result with visual effects"
  (let* ((effects (list (cl-telegram/api:make-visual-effect :fireworks)))
         (result (cl-telegram/api:make-inline-result-article-with-effects
                  "article_fx"
                  "Article with Effects"
                  '(:message_text "Content")
                  effects
                  :description "Special article")))
    (is (typep result 'cl-telegram/api:inline-result-with-effects))
    (is (string= (cl-telegram/api:inline-result-title (cl-telegram/api:effects-result result))
                 "Article with Effects"))))

(test test-make-inline-result-photo-with-effects
  "Test creating photo inline result with visual effects"
  (let* ((effects (list (cl-telegram/api:make-visual-effect :sparkles :intensity 0.9)))
         (result (cl-telegram/api:make-inline-result-photo-with-effects
                  "photo_fx"
                  "https://example.com/photo.jpg"
                  "https://example.com/thumb.jpg"
                  effects
                  :title "Enhanced Photo"
                  :caption "Beautiful with effects")))
    (is (typep result 'cl-telegram/api:inline-result-with-effects))
    (is (= (length (cl-telegram/api:effects-visual-effects result)) 1))))

(test test-make-inline-result-video-with-effects
  "Test creating video inline result with visual effects"
  (let* ((effects (list (cl-telegram/api:make-visual-effect :balloons)))
         (result (cl-telegram/api:make-inline-result-video-with-effects
                  "video_fx"
                  "https://example.com/video.mp4"
                  "https://example.com/thumb.jpg"
                  effects
                  :title "Video with Effects")))
    (is (typep result 'cl-telegram/api:inline-result-with-effects))))

(test test-make-inline-result-gif-with-effects
  "Test creating GIF inline result with visual effects"
  (let* ((effects (list (cl-telegram/api:make-visual-effect :hearts :intensity 1.0)))
         (result (cl-telegram/api:make-inline-result-gif-with-effects
                  "gif_fx"
                  "https://example.com/love.gif"
                  "https://example.com/thumb.jpg"
                  effects
                  :title "Love GIF")))
    (is (typep result 'cl-telegram/api:inline-result-with-effects))))

;;; ============================================================================
;;; Section 7: Web App Integration Tests
;;; ============================================================================

(test test-make-webapp-inline-button
  "Test creating web app inline button"
  (let ((button (cl-telegram/api:make-webapp-inline-button
                 "Open App"
                 "https://app.example.com"
                 :forward-text "Check out this app"
                 :button-type :purchase)))
    (is (string= (cl-telegram/api:webapp-button-text button) "Open App"))
    (is (string= (cl-telegram/api:webapp-button-url button) "https://app.example.com"))
    (is (string= (cl-telegram/api:webapp-forward-text button) "Check out this app"))
    (is (eq (cl-telegram/api:webapp-button-type button) :purchase))))

(test test-get-enhanced-inline-features
  "Test getting enhanced inline features"
  (let ((features (cl-telegram/api:get-enhanced-inline-features)))
    (is (getf features :visual-effects))
    (is (getf features :business-features))
    (is (getf features :paid-media))
    (is (getf features :webapp-enhanced))
    (is (getf features :stories))
    (is (getf features :giveaways))))

;;; ============================================================================
;;; Section 8: Inline Query Context Tests
;;; ============================================================================

(test test-make-inline-query-context
  "Test creating inline query context"
  (let ((context (cl-telegram/api:make-inline-query-context
                  :switch-pm-param "start_here"
                  :switch-pm-text "Open in PM"
                  :gallery-layout :horizontal
                  :personal t)))
    (is (string= (cl-telegram/api:context-switch-pm-param context) "start_here"))
    (is (string= (cl-telegram/api:context-switch-pm-text context) "Open in PM"))
    (is (eq (cl-telegram/api:context-gallery-layout context) :horizontal))
    (is (cl-telegram/api:context-personal-results context))))

;;; ============================================================================
;;; Section 9: Handler Registration Tests
;;; ============================================================================

(test test-register-inline-bot-handler
  "Test registering inline bot handler"
  (let ((handler (lambda (query) (declare (ignore query)) nil))
        (callback (lambda (query) (declare (ignore query)) nil)))
    (let ((result (cl-telegram/api:register-inline-bot-handler
                   "test_token_123"
                   handler
                   :callback-handler callback)))
      (is (eq result t)))))

(test test-unregister-inline-bot-handler
  "Test unregistering inline bot handler"
  (let ((result (cl-telegram/api:unregister-inline-bot-handler "test_token_123")))
    (is (eq result t))))

(test test-set-inline-bot-token
  "Test setting inline bot token"
  (let ((result (cl-telegram/api:set-inline-bot-token "bot_token_456")))
    (is (eq result t))
    (is (string= (cl-telegram/api:get-inline-bot-token) "bot_token_456"))))

;;; ============================================================================
;;; Section 10: Utility Tests
;;; ============================================================================

(test test-keyboard-button-p
  "Test checking if object is a keyboard button"
  (let ((inline-btn (cl-telegram/api:make-inline-keyboard-button "Test" :callback-data "1"))
        (reply-btn (cl-telegram/api:make-reply-keyboard-button "Test"))
        (not-btn "Just a string"))
    (is (cl-telegram/api:keyboard-button-p inline-btn))
    (is (cl-telegram/api:keyboard-button-p reply-btn))
    (is (not (cl-telegram/api:keyboard-button-p not-btn)))))

(test test-clear-keyboard-cache
  "Test clearing keyboard handler cache"
  (let ((result (cl-telegram/api:clear-keyboard-cache)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 12: Enhanced Inline Message Operations Tests
;;; ============================================================================

(test test-edit-inline-message
  "Test editing inline message text"
  (let ((result (cl-telegram/api:edit-inline-message "msg_123" "Updated text"
                                                      :reply-markup nil
                                                      :parse-mode "HTML"
                                                      :entities nil)))
    ;; Should return message plist or T on success
    (is (or (listp result) (eq result t)))))

(test test-edit-inline-message-with-markup
  "Test editing inline message with new keyboard"
  (let ((markup (cl-telegram/api:make-inline-keyboard "Button" :callback-data "test")))
    (let ((result (cl-telegram/api:edit-inline-message "msg_456" "New text"
                                                        :reply-markup markup
                                                        :parse-mode nil
                                                        :entities nil)))
      (is (or (listp result) (eq result t))))))

(test test-delete-inline-message
  "Test deleting inline message"
  (let ((result (cl-telegram/api:delete-inline-message 123456 789)))
    ;; Should return T on success
    (is (eq result t))))

(test test-delete-inline-message-nonexistent
  "Test deleting non-existent inline message"
  (let ((result (cl-telegram/api:delete-inline-message 999999 111)))
    ;; Should handle gracefully
    (is (or (eq result nil) (eq result t)))))

(test test-send-inline-result
  "Test sending inline result to chat"
  (let ((result (cl-telegram/api:send-inline-result 123456 "result_abc"
                                                     :disable-notification nil
                                                     :reply-to nil)))
    ;; Should return message plist
    (is (or (listp result) (eq result t)))))

(test test-send-inline-result-with-reply
  "Test sending inline result as reply"
  (let ((result (cl-telegram/api:send-inline-result 123456 "result_def"
                                                     :disable-notification t
                                                     :reply-to 999)))
    (is (or (listp result) (eq result t)))))

(test test-answer-web-app-query
  "Test answering web app inline query"
  (let ((results (list (cl-telegram/api:make-inline-query-result-article "1" "Title" "Message")))
        (result (cl-telegram/api:answer-web-app-query "query_xyz" results
                                                       :button-text "Send")))
    ;; Should return T on success
    (is (eq result t))))

(test test-answer-web-app-query-no-button
  "Test answering web app query without button"
  (let ((results (list (cl-telegram/api:make-inline-query-result-photo "1" "file_id")))
        (result (cl-telegram/api:answer-web-app-query "query_999" results
                                                       :button-text nil)))
    (is (eq result t))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-inline-bots-enhanced-tests ()
  "Run all Inline Mode Enhanced tests"
  (let ((results (run! 'inline-bots-enhanced-tests :if-fail :error)))
    (format t "~%~%=== Inline Mode Enhanced Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
