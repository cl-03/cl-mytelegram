;;; bot-api-8-tests.lisp --- Tests for Bot API 8.0 features
;;;
;;; Tests for:
;;; - Message reactions
;;; - Emoji status
;;; - Advanced media editing
;;; - Story highlights
;;; - Message translation

(defpackage #:cl-telegram/tests
  (:nicknames #:cl-tg/tests)
  (:use #:cl #:fiveam)
  (:export #:run-all-tests
           #:run-bot-api-8-tests))

(in-package #:cl-telegram/tests)

(in-package #:cl-telegram/tests)

;;; ============================================================================
;;; Message Reactions Tests
;;; ============================================================================

(def-suite* bot-api-8-reaction-tests
  :in bot-api-8-tests
  :description "Tests for Bot API 8.0 message reaction features")

(test test-make-reaction-type-emoji
  "Test creating emoji reaction types"
  (let ((reaction (cl-telegram/api:make-reaction-type-emoji "👍")))
    (is (typep reaction 'cl-telegram/api:reaction-type))
    (is (equal (cl-telegram/api:reaction-type-type reaction) :emoji))
    (is (equal (cl-telegram/api:reaction-type-emoji reaction) "👍"))))

(test test-make-reaction-type-custom-emoji
  "Test creating custom emoji reaction types"
  (let ((reaction (cl-telegram/api:make-reaction-type-custom-emoji "123456")))
    (is (typep reaction 'cl-telegram/api:reaction-type))
    (is (equal (cl-telegram/api:reaction-type-type reaction) :custom-emoji))
    (is (equal (cl-telegram/api:reaction-type-custom-emoji-id reaction) "123456"))))

(test test-make-reaction-type-star
  "Test creating star reaction types"
  (let ((reaction (cl-telegram/api:make-reaction-type-star)))
    (is (typep reaction 'cl-telegram/api:reaction-type))
    (is (equal (cl-telegram/api:reaction-type-type reaction) :star))))

(test test-reaction-to-tl
  "Test converting reaction types to TL objects"
  (let* ((emoji-reaction (cl-telegram/api:make-reaction-type-emoji "❤️"))
         (tl-obj (cl-telegram/api:reaction-to-tl emoji-reaction)))
    (is (not (null tl-obj)))
    ;; TL object should have the emoji
    (is (equal (getf tl-obj :emoticon) "❤️"))))

(test test-on-message-reaction
  "Test registering reaction update handlers"
  (let ((called-with nil)
        (handler-fn (lambda (chat-id msg-id old new)
                      (setf called-with (list chat-id msg-id old new)))))
    (let ((handler-id (cl-telegram/api:on-message-reaction handler-fn)))
      (is (not (null handler-id)))
      (is (gethash handler-id cl-telegram/api:*reaction-update-handlers*))
      ;; Unregister
      (cl-telegram/api:unregister-reaction-handler handler-id)
      (is (null (gethash handler-id cl-telegram/api:*reaction-update-handlers*))))))

(test test-process-reaction-update
  "Test processing reaction updates"
  (let ((called-with nil)
        (handler-fn (lambda (chat-id msg-id old new)
                      (setf called-with (list chat-id msg-id old new)))))
    (let ((handler-id (cl-telegram/api:on-message-reaction handler-fn)))
      (let ((update (make-instance 'cl-telegram/api:message-reaction-update
                                   :chat-id 123
                                   :message-id 456
                                   :date (get-universal-time)
                                   :old-reaction nil
                                   :new-reaction "👍")))
        (cl-telegram/api:process-reaction-update update)
        (is (equal called-with '(123 456 nil "👍"))))
      (cl-telegram/api:unregister-reaction-handler handler-id))))

;;; ============================================================================
;;; Emoji Status Tests
;;; ============================================================================

(def-suite* bot-api-8-emoji-status-tests
  :in bot-api-8-tests
  :description "Tests for Bot API 8.0 emoji status features")

(test test-emoji-status-slots
  "Test emoji-status class slots"
  (let ((status (make-instance 'cl-telegram/api:emoji-status
                               :document-id "123456"
                               :emoji "🔥"
                               :is-premium t
                               :is-active t)))
    (is (equal (cl-telegram/api:emoji-status-document-id status) "123456"))
    (is (equal (cl-telegram/api:emoji-status-emoji status) "🔥"))
    (is (cl-telegram/api:emoji-status-is-premium status))
    (is (cl-telegram/api:emoji-status-is-active status))))

(test test-set-emoji-status
  "Test setting emoji status (integration)"
  ;; This would require a real connection, so we just test the function exists
  (is (fboundp 'cl-telegram/api:set-emoji-status))
  (is (fboundp 'cl-telegram/api:clear-emoji-status))
  (is (fboundp 'cl-telegram/api:get-emoji-statuses)))

(test test-get-supported-languages
  "Test getting supported translation languages"
  (let ((languages (cl-telegram/api:get-supported-languages)))
    (is (listp languages))
    (is (> (length languages) 50))
    ;; Check for some common languages
    (is (find "en" languages :key #'car :test #'string=))
    (is (find "ru" languages :key #'car :test #'string=))
    (is (find "zh" languages :key #'car :test #'string=))))

;;; ============================================================================
;;; Advanced Media Editing Tests
;;; ============================================================================

(def-suite* bot-api-8-media-editing-tests
  :in bot-api-8-tests
  :description "Tests for Bot API 8.0 advanced media editing features")

(test test-media-edit-options
  "Test media-edit-options class"
  (let ((options (make-instance 'cl-telegram/api:media-edit-options
                                :crop-rectangle '(0 0 100 100)
                                :rotation-angle 90
                                :filter-type "clarendon"
                                :overlay-text "Hello"
                                :caption "Test caption"
                                :parse-mode :html)))
    (is (equal (cl-telegram/api:media-edit-crop options) '(0 0 100 100)))
    (is (equal (cl-telegram/api:media-edit-rotation options) 90))
    (is (equal (cl-telegram/api:media-edit-filter options) "clarendon"))
    (is (equal (cl-telegram/api:media-edit-overlay-text options) "Hello"))
    (is (equal (cl-telegram/api:media-edit-caption options) "Test caption"))
    (is (equal (cl-telegram/api:media-edit-parse-mode options) :html))))

(test test-available-media-filters
  "Test available media filters list"
  (is (not (null cl-telegram/api:+available-media-filters+)))
  (is (member "clarendon" cl-telegram/api:+available-media-filters+ :test #'string=))
  (is (member "grayscale" cl-telegram/api:+available-media-filters+ :test #'string=))
  (is (member "sepia" cl-telegram/api:+available-media-filters+ :test #'string=)))

(test test-crop-media
  "Test crop media function"
  ;; Currently a stub, just test it doesn't error
  (let ((result (cl-telegram/api:crop-media "test.jpg" :x 0 :y 0 :width 100 :height 100)))
    (is (equal result "test.jpg"))))

(test test-rotate-media
  "Test rotate media function"
  ;; Currently a stub
  (let ((result (cl-telegram/api:rotate-media "test.jpg" :angle 90)))
    (is (equal result "test.jpg"))))

(test test-apply-media-filter
  "Test apply media filter function"
  ;; Currently a stub
  (let ((result (cl-telegram/api:apply-media-filter "test.jpg" "clarendon" :intensity 0.8)))
    (is (equal result "test.jpg"))))

(test test-edit-message-caption
  "Test edit message caption function"
  ;; Test function exists
  (is (fboundp 'cl-telegram/api:edit-message-caption)))

;;; ============================================================================
;;; Story Highlights Tests
;;; ============================================================================

(def-suite* bot-api-8-story-highlights-tests
  :in bot-api-8-tests
  :description "Tests for Bot API 8.0 story highlights features")

(test test-story-highlight-class
  "Test story-highlight class"
  (let ((highlight (make-instance 'cl-telegram/api:story-highlight
                                  :id 1
                                  :title "My Highlight"
                                  :cover-media "cover.jpg"
                                  :stories '(1 2 3)
                                  :date-created (get-universal-time)
                                  :is-hidden nil
                                  :privacy-type :public)))
    (is (equal (cl-telegram/api:story-highlight-id highlight) 1))
    (is (equal (cl-telegram/api:story-highlight-title highlight) "My Highlight"))
    (is (equal (cl-telegram/api:story-highlight-cover highlight) "cover.jpg"))
    (is (equal (cl-telegram/api:story-highlight-stories highlight) '(1 2 3)))
    (is (equal (cl-telegram/api:story-highlight-privacy highlight) :public))))

(test test-highlight-cover-class
  "Test highlight-cover class"
  (let ((cover (make-instance 'cl-telegram/api:highlight-cover
                              :media-id "media123"
                              :crop-area '(0 0 100 100)
                              :filter "clarendon")))
    (is (equal (cl-telegram/api:highlight-cover-media-id cover) "media123"))
    (is (equal (cl-telegram/api:highlight-cover-crop cover) '(0 0 100 100)))
    (is (equal (cl-telegram/api:highlight-cover-filter cover) "clarendon"))))

(test test-highlights-api
  "Test highlights API functions exist"
  (is (fboundp 'cl-telegram/api:create-highlight))
  (is (fboundp 'cl-telegram/api:edit-highlight))
  (is (fboundp 'cl-telegram/api:edit-highlight-cover))
  (is (fboundp 'cl-telegram/api:reorder-highlights))
  (is (fboundp 'cl-telegram/api:get-highlights))
  (is (fboundp 'cl-telegram/api:delete-highlight))
  (is (fboundp 'cl-telegram/api:set-highlight-privacy))
  (is (fboundp 'cl-telegram/api:add-stories-to-highlight)))

(test test-highlights-cache
  "Test highlights cache"
  (is (typep cl-telegram/api:*highlights-cache* 'hash-table))
  (is (typep cl-telegram/api:*highlight-covers-cache* 'hash-table)))

;;; ============================================================================
;;; Message Translation Tests
;;; ============================================================================

(def-suite* bot-api-8-translation-tests
  :in bot-api-8-tests
  :description "Tests for Bot API 8.0 message translation features")

(test test-translation-result-class
  "Test translation-result class"
  (let ((result (make-instance 'cl-telegram/api:translation-result
                               :original-text "Hello"
                               :translated-text "Привет"
                               :source-language "en"
                               :target-language "ru"
                               :was-auto-detected nil)))
    (is (equal (cl-telegram/api:translation-original-text result) "Hello"))
    (is (equal (cl-telegram/api:translation-translated-text result) "Привет"))
    (is (equal (cl-telegram/api:translation-source-language result) "en"))
    (is (equal (cl-telegram/api:translation-target-language result) "ru"))
    (is (not (cl-telegram/api:translation-auto-detected result)))))

(test test-translate-text
  "Test translate text function"
  ;; Test function exists
  (is (fboundp 'cl-telegram/api:translate-text))
  (is (fboundp 'cl-telegram/api:translate-message)))

(test test-set-chat-language
  "Test setting chat language preference"
  (let ((chat-id 123)
        (language "es"))
    (is (cl-telegram/api:set-chat-language chat-id language))
    (is (equal (gethash chat-id cl-telegram/api:*chat-language-preferences*) language))
    ;; Cleanup
    (remhash chat-id cl-telegram/api:*chat-language-preferences*)))

(test test-auto-translation
  "Test auto-translation functions"
  (let ((chat-id 456))
    ;; Enable
    (is (cl-telegram/api:enable-auto-translation chat-id :target-language "fr"))
    (is (cl-telegram/api:auto-translation-enabled-p chat-id))
    ;; Disable
    (is (cl-telegram/api:disable-auto-translation chat-id))
    (is (not (cl-telegram/api:auto-translation-enabled-p chat-id)))))

(test test-translation-cache
  "Test translation cache functions"
  ;; Add something to cache
  (setf (gethash "test-key" cl-telegram/api:*translation-cache*) "test-value")
  (is (equal (gethash "test-key" cl-telegram/api:*translation-cache*) "test-value"))
  ;; Clear cache
  (is (cl-telegram/api:clear-translation-cache))
  (is (zerop (hash-table-count cl-telegram/api:*translation-cache*))))

(test test-translation-history
  "Test translation history"
  ;; Test function exists
  (is (fboundp 'cl-telegram/api:get-translation-history)))

;;; ============================================================================
;;; Integration Tests (require real connection)
;;; ============================================================================

(def-suite* bot-api-8-integration-tests
  :in bot-api-8-tests
  :description "Integration tests for Bot API 8.0 features (require real connection)")

(test test-send-reaction-integration
  "Test sending a reaction to a message (requires real connection)"
  (let ((chat-id 123)  ; Replace with real chat ID
        (message-id 456))
    ;; Skip if not connected
    (when (and (boundp 'cl-telegram/api:*auth-connection*)
               cl-telegram/api:*auth-connection*)
      (let ((result (cl-telegram/api:send-message-reaction chat-id message-id "👍")))
        (is (not (null result)))))))

(test test-set-emoji-status-integration
  "Test setting emoji status (requires real connection)"
  (when (and (boundp 'cl-telegram/api:*auth-connection*)
             cl-telegram/api:*auth-connection*)
    (let ((result (cl-telegram/api:set-emoji-status "🔥")))
      (is (not (null result))))))

(test test-translate-message-integration
  "Test translating a message (requires real connection)"
  (let ((chat-id 123)
        (message-id 456))
    (when (and (boundp 'cl-telegram/api:*auth-connection*)
               cl-telegram/api:*auth-connection*)
      (let ((result (cl-telegram/api:translate-message chat-id message-id :target-language "en")))
        (is (typep result 'cl-telegram/api:translation-result))))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-bot-api-8-tests ()
  "Run all Bot API 8.0 tests"
  (let ((results nil))
    (format t "~%=== Running Bot API 8.0 Tests ===~%~%")

    ;; Reaction tests
    (format t "Running reaction tests...~%")
    (push (fiveam:run! 'bot-api-8-reaction-tests) results)

    ;; Emoji status tests
    (format t "Running emoji status tests...~%")
    (push (fiveam:run! 'bot-api-8-emoji-status-tests) results)

    ;; Media editing tests
    (format t "Running media editing tests...~%")
    (push (fiveam:run! 'bot-api-8-media-editing-tests) results)

    ;; Story highlights tests
    (format t "Running story highlights tests...~%")
    (push (fiveam:run! 'bot-api-8-story-highlights-tests) results)

    ;; Translation tests
    (format t "Running translation tests...~%")
    (push (fiveam:run! 'bot-api-8-translation-tests) results)

    ;; Summary
    (format t "~%=== Bot API 8.0 Tests Complete ===~%")
    (format t "Total: ~A, Passed: ~A, Failed: ~A~%"
            (length results)
            (count-if #'identity results)
            (count-if #'null results))
    results))
