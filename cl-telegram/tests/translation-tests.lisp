;;; translation-tests.lisp --- Tests for message translation feature

(in-package #:cl-telegram/tests)

(def-suite* translation-tests
  :description "Translation feature tests")

;;; ============================================================================
;;; Language Support Tests
;;; ============================================================================

(test test-supported-languages
  "Test that supported languages list is properly defined"
  (let ((languages cl-telegram/api:*supported-languages*))
    (is (not (null languages)) "Languages list should not be nil")
    (is (> (length languages) 60) "Should support 60+ languages")
    ;; Check for common languages
    (is (assoc :en languages) "English should be supported")
    (is (assoc :zh languages) "Chinese should be supported")
    (is (assoc :ja languages) "Japanese should be supported")
    (is (assoc :ru languages) "Russian should be supported")
    (is (assoc :de languages) "German should be supported")
    (is (assoc :fr languages) "French should be supported")
    (is (assoc :es languages) "Spanish should be supported")))

(test test-get-language-name
  "Test language name lookup"
  (is (string= (cl-telegram/api:get-language-name :en) "English"))
  (is (string= (cl-telegram/api:get-language-name :zh) "Chinese (Simplified)"))
  (is (string= (cl-telegram/api:get-language-name :ja) "Japanese"))
  (is (null (cl-telegram/api:get-language-name :invalid))))

(test test-get-language-code
  "Test language code lookup"
  (is (eq (cl-telegram/api:get-language-code :en) :en))
  (is (eq (cl-telegram/api:get-language-code "English") :en))
  (is (eq (cl-telegram/api:get-language-code "english") :en))
  (is (eq (cl-telegram/api:get-language-code "Chinese (Simplified)") :zh)))

;;; ============================================================================
;;; Translation Cache Tests
;;; ============================================================================

(test test-cache-key-generation
  "Test cache key generation"
  (let ((key1 (cl-telegram/api::cache-key "Hello" :zh :en))
        (key2 (cl-telegram/api::cache-key "Hello" :zh :en))
        (key3 (cl-telegram/api::cache-key "Hello" :ja :en))
        (key4 (cl-telegram/api::cache-key "World" :zh :en)))
    (is (string= key1 key2) "Same inputs should produce same key")
    (is (not (string= key1 key3)) "Different target lang should produce different key")
    (is (not (string= key1 key4)) "Different text should produce different key")))

(test test-translation-cache-operations
  "Test translation cache operations"
  (let ((text "Hello")
        (translation "你好")
        (target :zh)
        (source :en))
    ;; Clear cache first
    (cl-telegram/api:clear-translation-cache)

    ;; Cache should be empty
    (is (null (cl-telegram/api:get-cached-translation text target :source-lang source)))

    ;; Cache translation
    (cl-telegram/api::cache-translation text translation target :source-lang source)

    ;; Should retrieve cached translation
    (let ((cached (cl-telegram/api:get-cached-translation text target :source-lang source)))
      (is (not (null cached)) "Cached translation should exist")
      (is (string= (getf cached :translation) translation) "Cached translation should match"))))

(test test-translation-cache-lru
  "Test LRU cache eviction"
  (cl-telegram/api:clear-translation-cache)
  (let ((original-size cl-telegram/api:*translation-cache-size*))
    ;; Temporarily set small cache size
    (setf cl-telegram/api:*translation-cache-size* 3)

    ;; Add 5 items
    (cl-telegram/api::cache-translation "text1" "trans1" :zh :source-lang :en)
    (cl-telegram/api::cache-translation "text2" "trans2" :zh :source-lang :en)
    (cl-telegram/api::cache-translation "text3" "trans3" :zh :source-lang :en)
    (cl-telegram/api::cache-translation "text4" "trans4" :zh :source-lang :en)
    (cl-telegram/api::cache-translation "text5" "trans5" :zh :source-lang :en)

    ;; Cache should only have 3 items
    (is (<= (hash-table-count cl-telegram/api:*translation-cache*) 3))

    ;; Restore original size
    (setf cl-telegram/api:*translation-cache-size* original-size)))

;;; ============================================================================
;;; Translation History Tests
;;; ============================================================================

(test test-translation-history
  "Test translation history tracking"
  (let ((original-history (copy-list cl-telegram/api:*translation-history*)))
    (unwind-protect
         (progn
           ;; Clear history
           (setf cl-telegram/api:*translation-history* nil)

           ;; Add translations to history
           (cl-telegram/api::add-to-translation-history
            (list :text "Hello" :translation "你好" :source-lang :en :target-lang :zh))
           (cl-telegram/api::add-to-translation-history
            (list :text "World" :translation "世界" :source-lang :en :target-lang :zh))

           ;; Check history
           (is (= (length cl-telegram/api:*translation-history*) 2))

           ;; Get history with limit
           (let ((history (cl-telegram/api:get-translation-history :limit 1)))
             (is (= (length history) 1))
             (is (string= (getf (first history) :text) "Hello"))))
      ;; Restore original history
      (setf cl-telegram/api:*translation-history* original-history))))

(test test-translation-history-limit
  "Test translation history is limited to 100 items"
  (let ((original-history (copy-list cl-telegram/api:*translation-history*)))
    (unwind-protect
         (progn
           (setf cl-telegram/api:*translation-history* nil)

           ;; Add 150 translations
           (dotimes (i 150)
             (cl-telegram/api::add-to-translation-history
              (list :text (format nil "text~A" i)
                    :translation (format nil "trans~A" i)
                    :source-lang :en
                    :target-lang :zh)))

           ;; Should only keep last 100
           (is (= (length cl-telegram/api:*translation-history*) 100)))
      (setf cl-telegram/api:*translation-history* original-history))))

;;; ============================================================================
;;; Language Preferences Tests
;;; ============================================================================

(test test-chat-language-preference
  "Test per-chat language preferences"
  (let ((chat-id 12345)
        (language :ja))
    ;; Set preference
    (is (cl-telegram/api:set-chat-language chat-id language))

    ;; Get preference
    (is (eq (cl-telegram/api:get-chat-language chat-id) language))

    ;; Get preference for unknown chat (should return default)
    (is (eq (cl-telegram/api:get-chat-language 99999 :default :en) :en))))

(test test-auto-translation-toggle
  "Test auto-translation enable/disable"
  (let ((original-state cl-telegram/api:*auto-translation-enabled*))
    (unwind-protect
         (progn
           ;; Enable
           (is (cl-telegram/api:enable-auto-translation t))
           (is (cl-telegram/api:auto-translation-enabled-p))

           ;; Disable
           (is (cl-telegram/api:enable-auto-translation nil))
           (is (null (cl-telegram/api:auto-translation-enabled-p))))
      ;; Restore original state
      (setf cl-telegram/api:*auto-translation-enabled* original-state))))

;;; ============================================================================
;;; URL Encoding Tests
;;; ============================================================================

(test test-url-encoding
  "Test URL encoding"
  (is (string= (cl-telegram/api::url-encode "Hello") "Hello"))
  (is (string= (cl-telegram/api::url-encode "Hello World") "Hello%20World"))
  (is (string= (cl-telegram/api::url-encode "你好") "%E4%BD%A0%E5%A5%BD"))
  (is (string= (cl-telegram/api::url-encode "a&b=c") "a%26b%3Dc")))

;;; ============================================================================
;;; Keywordize Tests
;;; ============================================================================

(test test-keywordize
  "Test string to keyword conversion"
  (is (eq (cl-telegram/api::keywordize "EN") :en))
  (is (eq (cl-telegram/api::keywordize "en") :en))
  (is (eq (cl-telegram/api::keywordize nil) :unknown))
  (is (eq (cl-telegram/api::keywordize "RUSSIAN") :russian)))

;;; ============================================================================
;;; Translation Info Tests
;;; ============================================================================

(test test-get-translation-info
  "Test translation info retrieval"
  (let ((message '(:id 100 :text "Hello" :translated-text "你好"
                       :translation-source-lang :en
                       :translation-target-lang :zh)))
    (let ((info (cl-telegram/api:get-translation-info 100 nil)))
      ;; Note: This test would need a mock get-message-by-id
      ;; For now, just verify the function exists and returns a plist structure
      (is (listp info)))))

;;; ============================================================================
;;; Bulk Translation Tests
;;; ============================================================================

(test test-translate-messages
  "Test translating multiple messages"
  ;; This is a structural test since we can't call the actual API without a key
  (let ((result (cl-telegram/api:translate-messages '(1 2 3) 12345 :zh :use-cache nil)))
    (is (listp result))
    ;; Should return a result for each message ID
    (is (= (length result) 3))))

;;; ============================================================================
;;; Configuration Tests
;;; ============================================================================

(test test-configure-translation-api-deepl
  "Test DeepL API configuration"
  (let ((original-key cl-telegram/api:*translation-api-key*)
        (original-endpoint cl-telegram/api:*translation-api-endpoint*))
    (unwind-protect
         (progn
           (cl-telegram/api:configure-translation-api :provider :deepl :api-key "test-key")
           (is (string= cl-telegram/api:*translation-api-key* "test-key"))
           (is (string= cl-telegram/api:*translation-api-endpoint*
                        "https://api.deepl.com/v2/translate")))
      ;; Restore
      (setf cl-telegram/api:*translation-api-key* original-key)
      (setf cl-telegram/api:*translation-api-endpoint* original-endpoint))))

(test test-configure-translation-api-google
  "Test Google Translate API configuration"
  (let ((original-endpoint cl-telegram/api:*translation-api-endpoint*))
    (unwind-protect
         (progn
           (cl-telegram/api:configure-translation-api :provider :google :api-key "test-key")
           (is (string= cl-telegram/api:*translation-api-endpoint*
                        "https://translation.googleapis.com/language/translate/v2")))
      (setf cl-telegram/api:*translation-api-endpoint* original-endpoint))))

(test test-configure-translation-api-libretranslate
  "Test LibreTranslate API configuration"
  (let ((original-endpoint cl-telegram/api:*translation-api-endpoint*))
    (unwind-protect
         (progn
           (cl-telegram/api:configure-translation-api :provider :libretranslate
                                                      :api-key nil
                                                      :endpoint "https://custom-translate.com")
           (is (string= cl-telegram/api:*translation-api-endpoint*
                        "https://custom-translate.com")))
      (setf cl-telegram/api:*translation-api-endpoint* original-endpoint))))

;;; ============================================================================
;;; Integration Tests (Mock)
;;; ============================================================================

(test test-translation-without-api-key
  "Test translation fails gracefully without API key"
  (let ((original-key cl-telegram/api:*translation-api-key*))
    (unwind-protect
         (progn
           (setf cl-telegram/api:*translation-api-key* nil)
           (signals error (cl-telegram/api:translate-text "Hello" :zh)))
      (setf cl-telegram/api:*translation-api-key* original-key))))

;;; ============================================================================
;;; Auto Translation Handler Tests
;;; ============================================================================

(test test-auto-translation-handler-registration
  "Test auto-translation handler registration"
  ;; Verify the function exists and returns T
  (is (cl-telegram/api:register-auto-translation-handler))
  ;; Handler should be registered
  t)

(test test-auto-translation-handler-unregistration
  "Test auto-translation handler unregistration"
  ;; Verify the function exists and returns T
  (is (cl-telegram/api:unregister-auto-translation-handler))
  t)

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-translation-tests ()
  "Run all translation tests.

   Returns:
     Test results"
  (fiveam:run! 'translation-tests))

;;; ============================================================================
;;; End of translation-tests.lisp
;;; ============================================================================
