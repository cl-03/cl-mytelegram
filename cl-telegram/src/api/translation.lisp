;;; translation.lisp --- Message translation feature for cl-telegram
;;;
;;; Provides message translation capabilities:
;;; - Translate individual messages
;;; - Translate arbitrary text
;;; - 60+ languages with auto-detection
;;; - Per-chat language preferences
;;; - Auto translation toggle
;;; - Translation cache (LRU)
;;; - Translation history

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Configuration
;;; ============================================================================

(defvar *translation-api-key* nil
  "Translation API key (e.g., Google Translate, DeepL, or LibreTranslate)")

(defvar *translation-api-endpoint* "https://api.deepl.com/v2/translate"
  "Translation API endpoint")

(defvar *translation-cache-size* 1000
  "Maximum size of translation cache (LRU)")

(defvar *translation-cache* (make-hash-table :test 'equal)
  "Cache of previous translations")

(defvar *translation-history* nil
  "Recent translation history")

(defvar *chat-language-preferences* (make-hash-table :test 'eq)
  "Per-chat language preferences")

(defvar *auto-translation-enabled* nil
  "Global auto-translation toggle")

;;; ============================================================================
;;; Supported Languages
;;; ============================================================================

(defparameter *supported-languages*
  '((:af . "Afrikaans")
    (:sq . "Albanian")
    (:am . "Amharic")
    (:ar . "Arabic")
    (:hy . "Armenian")
    (:az . "Azerbaijani")
    (:eu . "Basque")
    (:be . "Belarusian")
    (:bn . "Bengali")
    (:bs . "Bosnian")
    (:bg . "Bulgarian")
    (:ca . "Catalan")
    (:ceb . "Cebuano")
    (:ny . "Chichewa")
    (:zh . "Chinese (Simplified)")
    (:zh-tw . "Chinese (Traditional)")
    (:co . "Corsican")
    (:hr . "Croatian")
    (:cs . "Czech")
    (:da . "Danish")
    (:nl . "Dutch")
    (:en . "English")
    (:eo . "Esperanto")
    (:et . "Estonian")
    (:tl . "Filipino")
    (:fi . "Finnish")
    (:fr . "French")
    (:fy . "Frisian")
    (:gl . "Galician")
    (:ka . "Georgian")
    (:de . "German")
    (:el . "Greek")
    (:gu . "Gujarati")
    (:ht . "Haitian Creole")
    (:ha . "Hausa")
    (:haw . "Hawaiian")
    (:he . "Hebrew")
    (:hi . "Hindi")
    (:hmn . "Hmong")
    (:hu . "Hungarian")
    (:is . "Icelandic")
    (:ig . "Igbo")
    (:id . "Indonesian")
    (:ga . "Irish")
    (:it . "Italian")
    (:ja . "Japanese")
    (:jw . "Javanese")
    (:kn . "Kannada")
    (:kk . "Kazakh")
    (:km . "Khmer")
    (:ko . "Korean")
    (:ku . "Kurdish (Kurmanji)")
    (:ky . "Kyrgyz")
    (:lo . "Lao")
    (:la . "Latin")
    (:lv . "Latvian")
    (:lt . "Lithuanian")
    (:lb . "Luxembourgish")
    (:mk . "Macedonian")
    (:mg . "Malagasy")
    (:ms . "Malay")
    (:ml . "Malayalam")
    (:mt . "Maltese")
    (:mi . "Maori")
    (:mr . "Marathi")
    (:mn . "Mongolian")
    (:my . "Myanmar (Burmese)")
    (:ne . "Nepali")
    (:no . "Norwegian")
    (:ps . "Pashto")
    (:fa . "Persian")
    (:pl . "Polish")
    (:pt . "Portuguese")
    (:pa . "Punjabi")
    (:ro . "Romanian")
    (:ru . "Russian")
    (:sm . "Samoan")
    (:gd . "Scots Gaelic")
    (:sr . "Serbian")
    (:st . "Sesotho")
    (:sn . "Shona")
    (:sd . "Sindhi")
    (:si . "Sinhala")
    (:sk . "Slovak")
    (:sl . "Slovenian")
    (:so . "Somali")
    (:es . "Spanish")
    (:su . "Sundanese")
    (:sw . "Swahili")
    (:sv . "Swedish")
    (:tg . "Tajik")
    (:ta . "Tamil")
    (:te . "Telugu")
    (:th . "Thai")
    (:tr . "Turkish")
    (:uk . "Ukrainian")
    (:ur . "Urdu")
    (:uz . "Uzbek")
    (:vi . "Vietnamese")
    (:cy . "Welsh")
    (:xh . "Xhosa")
    (:yi . "Yiddish")
    (:yo . "Yoruba")
    (:zu . "Zulu"))
  "List of supported languages with codes")

(defun get-language-name (code)
  "Get language name from code.

   Args:
     code: Language keyword code

   Returns:
     Language name string"
  (or (cdr (assoc code *supported-languages*))
      (string code)))

(defun get-language-code (name-or-code)
  "Get language code from name or return code if valid.

   Args:
     name-or-code: Language name or code

   Returns:
     Language keyword code"
  (if (keywordp name-or-code)
      name-or-code
      (let ((code (find-if (lambda (pair)
                             (or (string= (cdr pair) name-or-code)
                                 (string= (symbol-name (car pair)) name-or-code)))
                           *supported-languages*)))
        (when code (car code)))))

;;; ============================================================================
;;; Translation Cache
;;; ============================================================================

(defun cache-key (text target-lang source-lang)
  "Generate cache key for translation.

   Args:
     text: Source text
     target-lang: Target language
     source-lang: Source language

   Returns:
     Cache key string"
  (format nil "~A:~A:~A" source-lang target-lang (sxhash text)))

(defun get-cached-translation (text target-lang &key (source-lang :auto))
  "Get cached translation if available.

   Args:
     text: Source text
     target-lang: Target language
     source-lang: Source language (default: auto)

   Returns:
     Cached translation or NIL"
  (let ((key (cache-key text target-lang source-lang)))
    (gethash key *translation-cache*)))

(defun cache-translation (text translation target-lang &key (source-lang :auto))
  "Cache a translation.

   Args:
     text: Source text
     translation: Translated text
     target-lang: Target language
     source-lang: Source language

   Returns:
     T on success"
  (let ((key (cache-key text target-lang source-lang)))
    ;; Evict oldest if cache is full
    (when (>= (hash-table-count *translation-cache*) *translation-cache-size*)
      (let ((oldest-key (first (hash-table-keys *translation-cache*))))
        (remhash oldest-key *translation-cache*)))
    (setf (gethash key *translation-cache*)
          (list :text text
                :translation translation
                :target-lang target-lang
                :source-lang source-lang
                :cached-at (get-universal-time)))
    t))

(defun clear-translation-cache ()
  "Clear translation cache.

   Returns:
     T on success"
  (clrhash *translation-cache*)
  t)

;;; ============================================================================
;;; Translation History
;;; ============================================================================

(defun add-to-translation-history (translation-record)
  "Add translation to history.

   Args:
     translation-record: Translation record plist

   Returns:
     T on success"
  (push translation-record *translation-history*)
  ;; Keep only last 100 translations
  (when (> (length *translation-history*) 100)
    (setf *translation-history* (subseq *translation-history* 0 100)))
  t)

(defun get-translation-history (&key (limit 20))
  "Get recent translation history.

   Args:
     limit: Maximum items to return

   Returns:
     List of translation records"
  (subseq *translation-history* 0 (min limit (length *translation-history*))))

;;; ============================================================================
;;; Language Preferences
;;; ============================================================================

(defun set-chat-language (chat-id language-code)
  "Set language preference for a chat.

   Args:
     chat-id: Chat identifier
     language-code: Target language code

   Returns:
     T on success"
  (setf (gethash chat-id *chat-language-preferences*) language-code)
  t)

(defun get-chat-language (chat-id &key (default :en))
  "Get language preference for a chat.

   Args:
     chat-id: Chat identifier
     default: Default language if not set

   Returns:
     Language code"
  (gethash chat-id *chat-language-preferences* default))

(defun enable-auto-translation (&optional (enabled t))
  "Enable or disable auto-translation.

   Args:
     enabled: T to enable, NIL to disable

   Returns:
     T on success"
  (setf *auto-translation-enabled* enabled)
  t)

(defun auto-translation-enabled-p ()
  "Check if auto-translation is enabled.

   Returns:
     T if enabled"
  *auto-translation-enabled*)

;;; ============================================================================
;;; Translation API
;;; ============================================================================

(defun translate-text (text target-lang &key (source-lang :auto) (use-cache t))
  "Translate text to target language.

   Args:
     text: Text to translate
     target-lang: Target language code
     source-lang: Source language code (default: auto-detect)
     use-cache: Whether to use cache (default: T)

   Returns:
     Translation result plist:
     (:translated-text :source-lang :target-lang :confidence)

   Example:
     (translate-text \"Hello\" :zh)
     => (:translated-text \"你好\" :source-lang :en :target-lang :zh :confidence 1.0)"
  (unless *translation-api-key*
    (error "Translation API key not set. Set *translation-api-key* first."))

  ;; Check cache
  (when use-cache
    (let ((cached (get-cached-translation text target-lang :source-lang source-lang)))
      (when cached
        return cached)))

  ;; Call translation API
  (handler-case
      (let* ((response (call-translation-api text target-lang source-lang))
             (translated-text (getf response :translated-text))
             (detected-lang (getf response :detected-lang)))
        ;; Cache result
        (when use-cache
          (cache-translation text translated-text target-lang :source-lang (or detected-lang source-lang)))
        ;; Add to history
        (add-to-translation-history
         (list :text text
               :translation translated-text
               :source-lang (or detected-lang source-lang)
               :target-lang target-lang
               :timestamp (get-universal-time)))
        response)
    (error (e)
      (list :error (format nil "Translation failed: ~A" e)
            :original-text text
            :target-lang target-lang))))

(defun call-translation-api (text target-lang source-lang)
  "Call external translation API.

   Args:
     text: Text to translate
     target-lang: Target language code
     source-lang: Source language code

   Returns:
     Translation result plist

   Note: This is a DeepL-compatible implementation.
         Modify for Google Translate, LibreTranslate, etc."
  (let* ((target-code (string-upcase (symbol-name target-lang)))
         (url (format nil "~A?auth_key=~A&text=~A&target_lang=~A~@[&source_lang=~A~]"
                      *translation-api-endpoint*
                      *translation-api-key*
                      (url-encode text)
                      target-code
                      (and (not (eq source-lang :auto))
                           (string-upcase (symbol-name source-lang))))))
    (handler-case
        (let* ((response (dex:get url))
               (json (jonathan:json-read response))
               (translations (getf json :translations)))
          (if translations
              (let ((first-trans (first translations)))
                (list :translated-text (getf first-trans :text)
                      :detected-lang (keywordize (getf first-trans :detected_source_language))
                      :confidence 1.0))
              (list :translated-text text
                    :detected-lang :unknown
                    :confidence 0.0)))
      (error (e)
        (list :error (princ-to-string e)
              :translated-text text
              :detected-lang :unknown
              :confidence 0.0)))))

(defun url-encode (text)
  "URL encode text.

   Args:
     text: Text to encode

   Returns:
     URL-encoded string"
  (babel:octets-to-string
   (drakma:url-encode (babel:string-to-octets text :encoding :utf-8) nil)))

(defun keywordize (string)
  "Convert string to keyword.

   Args:
     string: String to convert

   Returns:
     Keyword"
  (if string
      (intern (string-downcase string) :keyword)
      :unknown))

;;; ============================================================================
;;; Message Translation
;;; ============================================================================

(defun translate-message (message-id chat-id target-lang &key (use-cache t))
  "Translate a message.

   Args:
     message-id: Message identifier
     chat-id: Chat identifier
     target-lang: Target language code
     use-cache: Whether to use cache

   Returns:
     Translation result plist with original message"
  (let* ((message (get-message-by-id chat-id message-id))
         (text (getf message :text))
         (entities (getf message :entities)))
    (if text
        (let ((result (translate-text text target-lang
                                      :use-cache use-cache)))
          (list :message-id message-id
                :chat-id chat-id
                :original-text text
                :translated-text (getf result :translated-text)
                :target-lang target-lang
                :source-lang (getf result :detected-lang)
                :entities entities
                :timestamp (get-universal-time)))
        (list :error "Message has no text to translate"
              :message-id message-id))))

(defun translate-message-text (message text target-lang &key (use-cache t))
  "Translate message text (for messages with special formatting).

   Args:
     message: Message plist
     text: Text to translate
     target-lang: Target language

   Returns:
     Translation result with entity mapping"
  (translate-text text target-lang :use-cache use-cache))

;;; ============================================================================
;;; Auto Translation
;;; ============================================================================

(defun maybe-auto-translate-message (message chat-id)
  "Auto-translate message if enabled and needed.

   Args:
     message: Message plist
     chat-id: Chat identifier

   Returns:
     Message with translation if auto-translated, or original message"
  (unless *auto-translation-enabled*
    (return-from maybe-auto-translate-message message))

  (let* ((target-lang (get-chat-language chat-id))
         (text (getf message :text)))
    (if text
        (let ((result (translate-text text target-lang :use-cache t)))
          (append message
                  (list :translated-text (getf result :translated-text)
                        :translation-source-lang (getf result :detected-lang)
                        :translation-target-lang target-lang)))
        message)))

(defun register-auto-translation-handler ()
  "Register auto-translation handler for incoming messages.

   Returns:
     T on success"
  (register-update-handler :update-new-message
    (lambda (update)
      (let* ((message (getf update :message))
             (chat-id (getf message :peer-id)))
        (when message
          (let ((translated (maybe-auto-translate-message message chat-id)))
            ;; Store translated message
            (cache-message translated))))))
  t)

(defun unregister-auto-translation-handler ()
  "Unregister auto-translation handler.

   Returns:
     T on success"
  (clear-update-handlers :update-new-message)
  t)

;;; ============================================================================
;;; Bulk Translation
;;; ============================================================================

(defun translate-messages (message-ids chat-id target-lang &key (use-cache t))
  "Translate multiple messages.

   Args:
     message-ids: List of message IDs
     chat-id: Chat identifier
     target-lang: Target language
     use-cache: Whether to use cache

   Returns:
     List of translation results"
  (mapcar (lambda (message-id)
            (translate-message message-id chat-id target-lang :use-cache use-cache))
          message-ids))

(defun translate-chat-messages (chat-id target-lang &key (limit 50) (use-cache t))
  "Translate recent messages in a chat.

   Args:
     chat-id: Chat identifier
     target-lang: Target language
     limit: Number of messages to translate
     use-cache: Whether to use cache

   Returns:
     List of translation results"
  (let ((messages (get-cached-messages chat-id :limit limit)))
    (remove-if (lambda (result) (getf result :error))
               (mapcar (lambda (message)
                         (let ((text (getf message :text)))
                           (when text
                             (translate-text text target-lang :use-cache use-cache))))
                       messages))))

;;; ============================================================================
;;; Translation Info
;;; ============================================================================

(defun get-translation-info (message-id chat-id)
  "Get translation info for a message.

   Args:
     message-id: Message identifier
     chat-id: Chat identifier

   Returns:
     Translation info plist or NIL"
  (let ((message (get-message-by-id chat-id message-id)))
    (when message
      (list :has-translation (and (getf message :translated-text) t)
            :source-lang (getf message :translation-source-lang)
            :target-lang (getf message :translation-target-lang)
            :original-text (getf message :text)
            :translated-text (getf message :translated-text)))))

(defun list-supported-languages ()
  "List all supported languages.

   Returns:
     List of (code . name) pairs"
  *supported-languages*)

(defun detect-language (text)
  "Detect language of text.

   Args:
     text: Text to analyze

   Returns:
     Detected language code"
  ;; Use translation API for detection
  (let ((result (translate-text text :en :source-lang :auto)))
    (getf result :detected-lang)))

;;; ============================================================================
;;; Configuration
;;; ============================================================================

(defun configure-translation-api (&key (provider :deepl) api-key endpoint)
  "Configure translation API.

   Args:
     provider: API provider (:deepl :google :libretranslate)
     api-key: API key
     endpoint: API endpoint URL

   Returns:
     T on success

   Example:
     (configure-translation-api :provider :deepl :api-key \"your-key\")
     (configure-translation-api :provider :libretranslate
                                :api-key nil
                                :endpoint \"https://libretranslate.de/translate\")"
  (setf *translation-api-key* api-key)
  (when endpoint
    (setf *translation-api-endpoint* endpoint))
  (case provider
    (:deepl
     (setf *translation-api-endpoint* "https://api.deepl.com/v2/translate"))
    (:google
     (setf *translation-api-endpoint*
           "https://translation.googleapis.com/language/translate/v2"))
    (:libretranslate
     (setf *translation-api-endpoint*
           (or endpoint "https://libretranslate.de/translate"))))
  t)

;;; ============================================================================
;;; End of translation.lisp
;;; ============================================================================
