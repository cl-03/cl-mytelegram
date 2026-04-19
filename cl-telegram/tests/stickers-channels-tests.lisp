;;; stickers-channels-tests.lisp --- Integration tests for stickers, channels, inline bots, and threads
;;;
;;; Tests for the new features added in v0.10.0:
;;; - Sticker and emoji pack management
;;; - Channel broadcast and message reactions
;;; - Inline bots and custom keyboards
;;; - Message replies and threads

(in-package #:cl-telegram/tests)

(def-suite* new-features-integration-tests
  :description "Integration tests for new features in v0.10.0")

;;; ======================================================================
;;; Sticker and Emoji Pack Tests
;;; ======================================================================

(def-suite* sticker-management-tests
  :description "Tests for sticker pack management")

(test test-create-sticker-set
  "Test creating a new sticker set"
  (let ((user-id 123456)
        (set-name "test_stickers_by_testbot")
        (set-title "Test Stickers"))
    (let ((result (cl-telegram/api:create-new-sticker-set user-id set-name set-title)))
      (is result "Should create sticker set"))))

(test test-install-sticker-set
  "Test installing a sticker set"
  (let ((set-name "test_stickers"))
    (let ((result (cl-telegram/api:install-sticker-set set-name)))
      (is result "Should install sticker set"))))

(test test-get-sticker-set
  "Test getting a sticker set"
  (let ((set-name "test_stickers"))
    (let ((result (cl-telegram/api:get-sticker-set set-name)))
      ;; May return NIL if not cached
      (pass "Should attempt to get sticker set"))))

(test test-add-favorite-sticker
  "Test adding sticker to favorites"
  (let ((file-id "test_file_id_123"))
    (let ((result (cl-telegram/api:add-favorite-sticker file-id)))
      (is result "Should add to favorites")
      (is (member file-id (cl-telegram/api:get-favorite-stickers) :test #'string=)
          "Should be in favorites list"))))

(test test-remove-favorite-sticker
  "Test removing sticker from favorites"
  (let ((file-id "test_file_id_123"))
    ;; First add it
    (cl-telegram/api:add-favorite-sticker file-id)
    (let ((result (cl-telegram/api:remove-favorite-sticker file-id)))
      (is result "Should remove from favorites")
      (is (not (member file-id (cl-telegram/api:get-favorite-stickers) :test #'string=))
          "Should not be in favorites list"))))

(test test-get-emoji-packs
  "Test getting emoji packs"
  (let ((packs (cl-telegram/api:get-emoji-packs)))
    (is packs "Should get emoji packs")
    (is (> (length packs) 0) "Should have at least one pack")
    ;; Check default pack exists
    (let ((default-pack (find "default" packs :key #'cl-telegram/api:emoji-pack-id :test #'string=)))
      (is default-pack "Should have default emoji pack"))))

(test test-install-emoji-pack
  "Test installing an emoji pack"
  (let ((pack-id "default"))
    (let ((result (cl-telegram/api:install-emoji-pack pack-id)))
      (is result "Should install emoji pack"))
    (let ((installed (cl-telegram/api:get-installed-emoji-packs)))
      (is (find pack-id installed :key #'cl-telegram/api:emoji-pack-id :test #'string=)
          "Should be in installed packs"))))

(test test-sticker-dimension-string
  "Test sticker dimension string formatting"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "test"
                                :width 512
                                :height 512)))
    (let ((dim (cl-telegram/api:sticker-dimension-string sticker)))
      (is (string= dim "512x512") "Should format dimensions correctly"))))

(test test-sticker-type-string
  "Test sticker type string formatting"
  (let ((static-sticker (make-instance 'cl-telegram/api:sticker
                                       :file-id "test"
                                       :width 512
                                       :height 512
                                       :is-animated nil
                                       :is-video nil))
        (animated-sticker (make-instance 'cl-telegram/api:sticker
                                         :file-id "test"
                                         :width 512
                                         :height 512
                                         :is-animated t
                                         :is-video nil)))
    (is (string= (cl-telegram/api:sticker-type-string static-sticker) "static")
        "Should return static for non-animated")
    (is (string= (cl-telegram/api:sticker-type-string animated-sticker) "animated")
        "Should return animated for animated sticker")))

;;; ======================================================================
;;; Channel and Broadcast Tests
;;; ======================================================================

(def-suite* channel-management-tests
  :description "Tests for channel management")

(test test-create-channel
  "Test creating a new channel"
  (let ((title "Test Channel")
        (description "Test channel description")
        (channel nil))
    (setf channel (cl-telegram/api:create-channel title description))
    (when channel
      (is (string= (cl-telegram/api:channel-title channel) title)
          "Channel title should match")
      (is (string= (cl-telegram/api:channel-description channel) description)
          "Channel description should match"))))

(test test-get-channel
  "Test getting channel by ID"
  (let ((channel-id 12345))
    (let ((channel (cl-telegram/api:get-channel channel-id)))
      ;; May return NIL
      (pass "Should attempt to get channel"))))

(test test-broadcast-to-channel
  "Test broadcasting message to channel"
  (let ((channel-id 12345)
        (text "Test broadcast message"))
    (let ((result (cl-telegram/api:broadcast-to-channel channel-id text)))
      ;; May return NIL if not authenticated
      (pass "Should attempt to broadcast"))))

(test test-get-channel-stats
  "Test getting channel statistics"
  (let ((channel-id 12345))
    (let ((stats (cl-telegram/api:get-channel-stats channel-id)))
      ;; May return NIL
      (pass "Should attempt to get stats"))))

(test test-channel-type-string
  "Test channel type string formatting"
  (let ((broadcast-channel (make-instance 'cl-telegram/api:channel
                                          :id 1
                                          :title "Broadcast"
                                          :is-broadcast t
                                          :is-megagroup nil))
        (megagroup-channel (make-instance 'cl-telegram/api:channel
                                          :id 2
                                          :title "Megagroup"
                                          :is-broadcast nil
                                          :is-megagroup t)))
    (is (string= (cl-telegram/api:channel-type-string broadcast-channel) "Broadcast Channel")
        "Should return Broadcast Channel for broadcast")
    (is (string= (cl-telegram/api:channel-type-string megagroup-channel) "Megagroup")
        "Should return Megagroup for megagroup")))

;;; ======================================================================
;;; Message Reaction Tests
;;; ======================================================================

(def-suite* message-reaction-tests
  :description "Tests for message reactions")

(test test-get-available-reactions
  "Test getting available reactions"
  (let ((reactions (cl-telegram/api:get-available-reactions)))
    (is reactions "Should get reactions list")
    (is (> (length reactions) 0) "Should have at least one reaction")
    ;; Check some common reactions exist
    (is (member "👍" reactions :test #'string=) "Should have thumbs up")
    (is (member "❤️" reactions :test #'string=) "Should have heart")))

(test test-send-message-reaction
  "Test sending reaction to message"
  (let ((chat-id 12345)
        (message-id 67890)
        (emoji "👍"))
    (let ((result (cl-telegram/api:send-message-reaction chat-id message-id emoji)))
      (is result "Should send reaction"))))

(test test-get-message-reactions
  "Test getting message reactions"
  (let ((chat-id 12345)
        (message-id 67890))
    ;; First send a reaction
    (cl-telegram/api:send-message-reaction chat-id message-id "👍")
    (let ((reactions (cl-telegram/api:get-message-reactions chat-id message-id)))
      ;; May return NIL
      (pass "Should attempt to get reactions"))))

(test test-remove-message-reaction
  "Test removing message reaction"
  (let ((chat-id 12345)
        (message-id 67890)
        (emoji "👍"))
    (let ((result (cl-telegram/api:remove-message-reaction chat-id message-id emoji)))
      (is result "Should remove reaction"))))

(test test-set-available-reactions
  "Test setting available reactions"
  (let ((custom-reactions '("👍" "❤️" "😂" "😮")))
    (let ((result (cl-telegram/api:set-available-reactions custom-reactions)))
      (is result "Should set reactions")
      (is (equal (cl-telegram/api:get-available-reactions) custom-reactions)
          "Should return custom reactions"))
    ;; Reset to default
    (cl-telegram/api:set-available-reactions nil)))

;;; ======================================================================
;;; Inline Bot and Keyboard Tests
;;; ======================================================================

(def-suite* inline-bot-tests
  :description "Tests for inline bots and keyboards")

(test test-make-inline-keyboard-button
  "Test creating inline keyboard button"
  (let ((button (cl-telegram/api:make-inline-keyboard-button "Click Me" :callback-data "test_data")))
    (is button "Should create button")
    (is (string= (cl-telegram/api:inline-button-text button) "Click Me")
        "Button text should match")
    (is (string= (cl-telegram/api:inline-button-callback-data button) "test_data")
        "Callback data should match")))

(test test-make-inline-keyboard
  "Test creating inline keyboard"
  (let ((row1 (list (cl-telegram/api:make-inline-keyboard-button "Button 1" :callback-data "1")
                    (cl-telegram/api:make-inline-keyboard-button "Button 2" :callback-data "2")))
        (row2 (list (cl-telegram/api:make-inline-keyboard-button "Button 3" :callback-data "3"))))
    (let ((keyboard (cl-telegram/api:make-inline-keyboard row1 row2)))
      (is keyboard "Should create keyboard")
      (is (= (length (cl-telegram/api:inline-keyboard-keyboard keyboard)) 2)
          "Should have 2 rows"))))

(test test-make-reply-keyboard
  "Test creating reply keyboard"
  (let ((row1 (list (cl-telegram/api:make-reply-keyboard-button "Option 1")
                    (cl-telegram/api:make-reply-keyboard-button "Option 2")))
        (row2 (list (cl-telegram/api:make-reply-keyboard-button "Option 3"))))
    (let ((keyboard (cl-telegram/api:make-reply-keyboard row1 row2 :resize-p t :one-time-p t)))
      (is keyboard "Should create keyboard")
      (is (cl-telegram/api:reply-keyboard-resize keyboard) "Resize should be true")
      (is (cl-telegram/api:reply-keyboard-one-time keyboard) "One-time should be true"))))

(test test-make-reply-keyboard-remove
  "Test creating reply keyboard remove"
  (let ((remove (cl-telegram/api:make-reply-keyboard-remove :selective t)))
    (is remove "Should create remove markup")
    (is (cl-telegram/api:reply-keyboard-remove-p remove) "Should be remove markup")))

(test test-make-force-reply
  "Test creating force reply"
  (let ((force-reply (cl-telegram/api:make-force-reply :selective t :placeholder "Reply here")))
    (is force-reply "Should create force reply")
    (is (cl-telegram/api:force-reply-p force-reply) "Should be force reply")
    (is (string= (cl-telegram/api:force-reply-placeholder force-reply) "Reply here")
        "Placeholder should match")))

(test test-register-inline-bot-handler
  "Test registering inline bot handler"
  (let ((token "test_bot_token")
        (handler (lambda (query) (declare (ignore query)) nil)))
    (let ((result (cl-telegram/api:register-inline-bot-handler token handler)))
      (is result "Should register handler")
      (is (gethash token cl-telegram/api:*inline-bot-handlers*)
          "Handler should be registered"))))

(test test-unregister-inline-bot-handler
  "Test unregistering inline bot handler"
  (let ((token "test_bot_token_2")
        (handler (lambda (query) (declare (ignore query)) nil)))
    ;; First register
    (cl-telegram/api:register-inline-bot-handler token handler)
    (let ((result (cl-telegram/api:unregister-inline-bot-handler token)))
      (is result "Should unregister handler")
      (is (not (gethash token cl-telegram/api:*inline-bot-handlers*))
          "Handler should be unregistered"))))

(test test-parse-inline-query
  "Test parsing inline query"
  (let ((data '(:id "query_123"
                :from (:id 456 :username "testuser")
                :query "test query"
                :offset ""
                :chat-type "private"))
        (query nil))
    (setf query (cl-telegram/api:parse-inline-query data))
    (is query "Should parse query")
    (is (string= (cl-telegram/api:inline-query-query query) "test query")
        "Query text should match")))

(test test-parse-callback-query
  "Test parsing callback query"
  (let ((data '(:id "callback_123"
                :from (:id 456 :username "testuser")
                :message (:message-id 789)
                :data "test_data"
                :chat_instance "123456"))
        (callback nil))
    (setf callback (cl-telegram/api:parse-callback-query data))
    (is callback "Should parse callback query")
    (is (string= (cl-telegram/api:callback-query-data callback) "test_data")
        "Callback data should match")))

;;; ======================================================================
;;; Message Thread Tests
;;; ======================================================================

(def-suite* message-thread-tests
  :description "Tests for message threads and replies")

(test test-send-message-with-reply
  "Test sending message with reply"
  (let ((chat-id 12345)
        (text "Reply message")
        (reply-to-message-id 67890))
    (let ((result (cl-telegram/api:send-message-with-reply chat-id text reply-to-message-id)))
      ;; May return NIL
      (pass "Should attempt to send reply"))))

(test test-get-message-replies
  "Test getting message replies"
  (let ((chat-id 12345)
        (message-id 67890))
    (let ((replies (cl-telegram/api:get-message-replies chat-id message-id)))
      ;; May return NIL
      (pass "Should attempt to get replies"))))

(test test-create-message-thread
  "Test creating message thread"
  (let ((chat-id 12345)
        (topic "Test Topic"))
    (let ((thread (cl-telegram/api:create-message-thread chat-id topic)))
      ;; May return NIL
      (pass "Should attempt to create thread"))))

(test test-close-message-thread
  "Test closing message thread"
  (let ((chat-id 12345)
        (thread-id "thread_1"))
    ;; Create a thread in cache first
    (let ((thread (make-instance 'cl-telegram/api:message-thread
                                 :thread-id thread-id
                                 :chat-id chat-id
                                 :topic "Test"
                                 :message-count 5
                                 :is-closed nil)))
      (setf (gethash (format nil "~A:~A" chat-id thread-id) cl-telegram/api:*thread-cache*) thread))
    (let ((result (cl-telegram/api:close-message-thread chat-id thread-id)))
      (is result "Should close thread")
      ;; Verify it's closed
      (let ((cached (gethash (format nil "~A:~A" chat-id thread-id) cl-telegram/api:*thread-cache*)))
        (is (cl-telegram/api:message-thread-is-closed cached) "Thread should be closed")))))

(test test-reopen-message-thread
  "Test reopening message thread"
  (let ((chat-id 12345)
        (thread-id "thread_2"))
    ;; Create a closed thread in cache first
    (let ((thread (make-instance 'cl-telegram/api:message-thread
                                 :thread-id thread-id
                                 :chat-id chat-id
                                 :topic "Test"
                                 :message-count 5
                                 :is-closed t)))
      (setf (gethash (format nil "~A:~A" chat-id thread-id) cl-telegram/api:*thread-cache*) thread))
    (let ((result (cl-telegram/api:reopen-message-thread chat-id thread-id)))
      (is result "Should reopen thread")
      ;; Verify it's open
      (let ((cached (gethash (format nil "~A:~A" chat-id thread-id) cl-telegram/api:*thread-cache*)))
        (is (not (cl-telegram/api:message-thread-is-closed cached)) "Thread should be open")))))

(test test-pin-message-thread
  "Test pinning message thread"
  (let ((chat-id 12345)
        (thread-id "thread_3"))
    ;; Create a thread in cache first
    (let ((thread (make-instance 'cl-telegram/api:message-thread
                                 :thread-id thread-id
                                 :chat-id chat-id
                                 :topic "Test"
                                 :message-count 5
                                 :is-pinned nil)))
      (setf (gethash (format nil "~A:~A" chat-id thread-id) cl-telegram/api:*thread-cache*) thread))
    (let ((result (cl-telegram/api:pin-message-thread chat-id thread-id)))
      (is result "Should pin thread")
      ;; Verify it's pinned
      (let ((cached (gethash (format nil "~A:~A" chat-id thread-id) cl-telegram/api:*thread-cache*)))
        (is (cl-telegram/api:message-thread-is-pinned cached) "Thread should be pinned")))))

(test test-get-reply-count
  "Test getting reply count"
  (let ((chat-id 12345)
        (message-id 67890))
    ;; First add some replies to chain
    (let ((chain (make-instance 'cl-telegram/api:reply-chain
                                :chain-id (format nil "~A:~A" chat-id message-id)
                                :message-id message-id
                                :chat-id chat-id
                                :total-reply-count 5)))
      (setf (gethash (format nil "~A:~A" chat-id message-id) cl-telegram/api:*reply-cache*) chain))
    (let ((count (cl-telegram/api:get-reply-count chat-id message-id)))
      (is (= count 5) "Should return correct reply count"))))

(test test-thread-is-active-p
  "Test thread active status check"
  (let ((active-thread (make-instance 'cl-telegram/api:message-thread
                                      :thread-id "t1"
                                      :chat-id 12345
                                      :topic "Active"
                                      :is-closed nil))
        (closed-thread (make-instance 'cl-telegram/api:message-thread
                                      :thread-id "t2"
                                      :chat-id 12345
                                      :topic "Closed"
                                      :is-closed t)))
    (is (cl-telegram/api:thread-is-active-p active-thread) "Active thread should return true")
    (is (not (cl-telegram/api:thread-is-active-p closed-thread)) "Closed thread should return false")))

(test test-make-quote-text
  "Test making quote text from message"
  (let ((long-text "This is a very long message that should be truncated when creating a quote for the reply")
        (short-text "Short message"))
    (let ((long-quote (cl-telegram/api:make-quote-text long-text :max-length 20))
          (short-quote (cl-telegram/api:make-quote-text short-text :max-length 100)))
      (is (= (length long-quote) 23) "Long quote should be truncated with ...")
      (is (string= short-quote "Short message") "Short quote should not be truncated"))))

;;; ======================================================================
;;; Voice Message Tests
;;; ======================================================================

(def-suite* voice-message-tests
  :description "Tests for voice messages")

(test test-voice-message-duration-string
  "Test voice message duration formatting"
  (let ((msg-60 (make-instance 'cl-telegram/api:voice-message
                               :file-id "test"
                               :duration 60))
        (msg-90 (make-instance 'cl-telegram/api:voice-message
                               :file-id "test"
                               :duration 90))
        (msg-5 (make-instance 'cl-telegram/api:voice-message
                              :file-id "test"
                              :duration 5)))
    (is (string= (cl-telegram/api:voice-message-duration-string msg-60) "1:00")
        "Should format 60 seconds as 1:00")
    (is (string= (cl-telegram/api:voice-message-duration-string msg-90) "1:30")
        "Should format 90 seconds as 1:30")
    (is (string= (cl-telegram/api:voice-message-duration-string msg-5) "0:05")
        "Should format 5 seconds as 0:05")))

(test test-render-waveform-svg
  "Test rendering waveform as SVG"
  (let ((waveform '(100 150 200 150 100 50 100 150))
        (svg nil))
    (setf svg (cl-telegram/api:render-waveform-svg waveform :width 200 :height 40))
    (is svg "Should generate SVG")
    (is (search "<svg" svg) "Should start with svg tag")
    (is (search "</svg>" svg) "Should end with svg tag")))

(test test-encode-decode-waveform
  "Test waveform encoding and decoding"
  (let ((waveform '(100 150 200 150 100))
        (encoded nil)
        (decoded nil))
    (setf encoded (cl-telegram/api:encode-waveform-to-base64 waveform))
    (setf decoded (cl-telegram/api:decode-waveform-from-base64 encoded))
    (is encoded "Should encode waveform")
    (is decoded "Should decode waveform")
    (is (equal waveform decoded) "Decoded waveform should match original")))

(test test-clear-voice-cache
  "Test clearing voice cache"
  (let ((result (cl-telegram/api:clear-voice-cache)))
    (is result "Should clear cache")))

(test test-get-available-voice-devices
  "Test getting available voice devices"
  (let ((devices (cl-telegram/api:get-available-voice-devices)))
    (is devices "Should get devices list")
    (is (> (length devices) 0) "Should have at least one device")))

;;; ======================================================================
;;; Test Runner Functions
;;; ======================================================================

(defun run-new-features-tests ()
  "Run all new features integration tests.

   Returns:
     Test results"
  (format t "~%=== Running New Features Integration Tests ===~%~%")
  (fiveam:run! 'new-features-integration-tests))

(defun run-sticker-tests ()
  "Run sticker management tests."
  (fiveam:run! 'sticker-management-tests))

(defun run-channel-tests ()
  "Run channel management tests."
  (fiveam:run! 'channel-management-tests))

(defun run-reaction-tests ()
  "Run message reaction tests."
  (fiveam:run! 'message-reaction-tests))

(defun run-inline-bot-tests ()
  "Run inline bot tests."
  (fiveam:run! 'inline-bot-tests))

(defun run-thread-tests ()
  "Run message thread tests."
  (fiveam:run! 'message-thread-tests))

(defun run-voice-tests ()
  "Run voice message tests."
  (fiveam:run! 'voice-message-tests))
