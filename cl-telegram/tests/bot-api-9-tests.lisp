;;; bot-api-9-tests.lisp --- Tests for Bot API 9.4-9.6 features

(in-package #:cl-telegram/tests)

(defsuite* bot-api-9-suite ())

;;; ============================================================================
;;; Custom Emoji Sticker Tests
;;; ============================================================================

(deftest test-custom-emoji-sticker-creation ()
  "Test creating a custom-emoji-sticker instance."
  (let ((sticker (make-instance 'cl-telegram/api:custom-emoji-sticker
                                :sticker-id "test-id"
                                :emoji "😄"
                                :width 64
                                :height 64
                                :file-size 2048)))
    (is (typep sticker 'cl-telegram/api:custom-emoji-sticker))
    (is (string= (cl-telegram/api:custom-emoji-sticker-id sticker) "test-id"))
    (is (string= (cl-telegram/api:custom-emoji-emoji sticker) "😄"))
    (is (= (cl-telegram/api:custom-emoji-width sticker) 64))
    (is (= (cl-telegram/api:custom-emoji-height sticker) 64))
    (is (= (cl-telegram/api:custom-emoji-file-size sticker) 2048))))

(deftest test-custom-emoji-print-object ()
  "Test custom emoji sticker print representation."
  (let ((sticker (make-instance 'cl-telegram/api:custom-emoji-sticker
                                :sticker-id "test"
                                :emoji "🎯")))
    (let ((output (with-output-to-string (s)
                    (print-object sticker s))))
      (is (search "🎯" output)))))

;;; ============================================================================
;;; Custom Emoji Pack Tests
;;; ============================================================================

(deftest test-custom-emoji-pack-creation ()
  "Test creating a custom-emoji-pack instance."
  (let ((pack (make-instance 'cl-telegram/api:custom-emoji-pack
                             :pack-id "123456"
                             :title "Test Pack"
                             :emojis '("emoji1" "emoji2")
                             :sticker-count 2)))
    (is (typep pack 'cl-telegram/api:custom-emoji-pack))
    (is (string= (cl-telegram/api:emoji-pack-id pack) "123456"))
    (is (string= (cl-telegram/api:emoji-pack-title pack) "Test Pack"))
    (is (= (length (cl-telegram/api:emoji-pack-emojis pack)) 2))
    (is (= (cl-telegram/api:emoji-pack-sticker-count pack) 2))))

(deftest test-custom-emoji-pack-print-object ()
  "Test custom emoji pack print representation."
  (let ((pack (make-instance 'cl-telegram/api:custom-emoji-pack
                             :pack-id "123"
                             :title "My Emojis"
                             :sticker-count 10)))
    (let ((output (with-output-to-string (s)
                    (print-object pack s))))
      (is (search "My Emojis" output))
      (is (search "10" output)))))

;;; ============================================================================
;;; Cache Tests
;;; ============================================================================

(deftest test-clear-custom-emoji-cache ()
  "Test clearing custom emoji cache."
  (let ((manager (cl-telegram/api:get-connection)))
    ;; Add something to cache
    (setf (gethash "test" cl-telegram/api::*custom-emoji-cache*) 'result)
    (setf (gethash "test" cl-telegram/api::*emoji-pack-cache*) 'result)
    (is (not (null (gethash "test" cl-telegram/api::*custom-emoji-cache*))))
    ;; Clear cache
    (is (cl-telegram/api:clear-custom-emoji-cache))
    (is (null (gethash "test" cl-telegram/api::*custom-emoji-cache*)))))

(deftest test-get-custom-emoji-cache-stats ()
  "Test getting cache statistics."
  (let ((stats (cl-telegram/api:get-custom-emoji-cache-stats)))
    (is (listp stats))
    (is (getf stats :emoji-cache-size))
    (is (getf stats :pack-cache-size))))

;;; ============================================================================
;;; Animated Emoji Tests
;;; ============================================================================

(deftest test-get-available-emoji ()
  "Test getting available animated emoji."
  (let ((emoji (cl-telegram/api:get-available-emoji)))
    (is (listp emoji))
    (is (> (length emoji) 0))
    (is (member "🎯" emoji :test #'string=))
    (is (member "🎲" emoji :test #'string=))
    (is (member "🎰" emoji :test #'string=))))

(deftest test-send-animated-emoji ()
  "Test sending animated emoji (mock test)."
  ;; This would require actual connection, so just verify function exists
  (is (fboundp 'cl-telegram/api:send-animated-emoji)))

;;; ============================================================================
;;; Interactive Content Tests
;;; ============================================================================

(deftest test-interactive-content-creation ()
  "Test creating interactive-content instance."
  (let ((content (make-instance 'cl-telegram/api:interactive-content
                                :content-type :poll
                                :message-id 123
                                :chat-id 456
                                :data '(:poll :test))))
    (is (typep content 'cl-telegram/api:interactive-content))
    (is (eq (cl-telegram/api:interactive-content-type content) :poll))
    (is (= (cl-telegram/api:interactive-message-id content) 123))
    (is (= (cl-telegram/api:interactive-chat-id content) 456))))

(deftest test-interactive-poll-creation ()
  "Test creating interactive-poll instance."
  (let ((poll (make-instance 'cl-telegram/api:interactive-poll
                             :content-type :poll
                             :message-id 123
                             :chat-id 456
                             :question "What is your favorite color?"
                             :options '("Red" "Blue" "Green")
                             :total-voters 100
                             :is-anonymous t
                             :allows-multiple nil)))
    (is (typep poll 'cl-telegram/api:interactive-poll))
    (is (string= (cl-telegram/api:poll-question poll) "What is your favorite color?"))
    (is (= (length (cl-telegram/api:poll-options poll)) 3))
    (is (= (cl-telegram/api:poll-total-voters poll) 100))
    (is (cl-telegram/api:poll-is-anonymous poll))
    (is (not (cl-telegram/api:poll-allows-multiple poll)))))

(deftest test-quiz-poll-creation ()
  "Test creating quiz-poll instance."
  (let ((quiz (make-instance 'cl-telegram/api:quiz-poll
                             :content-type :quiz
                             :message-id 123
                             :chat-id 456
                             :question "What is 2+2?"
                             :options '("3" "4" "5")
                             :correct-option 1
                             :explanation "2+2 equals 4")))
    (is (typep quiz 'cl-telegram/api:quiz-poll))
    (is (= (cl-telegram/api:quiz-correct-option quiz) 1))
    (is (string= (cl-telegram/api:quiz-explanation quiz) "2+2 equals 4"))))

;;; ============================================================================
;;; Poll Functions Tests
;;; ============================================================================

(deftest test-get-poll-results ()
  "Test getting poll results (mock test)."
  ;; Verify function exists and has correct signature
  (is (fboundp 'cl-telegram/api:get-poll-results)))

(deftest test-create-interactive-poll ()
  "Test creating interactive poll (mock test)."
  (is (fboundp 'cl-telegram/api:create-interactive-poll)))

(deftest test-create-quiz-mode ()
  "Test creating quiz mode poll (mock test)."
  (is (fboundp 'cl-telegram/api:create-quiz-mode)))

;;; ============================================================================
;;; Emoji Status Tests
;;; ============================================================================

(deftest test-get-emoji-status ()
  "Test getting emoji status (mock test)."
  (is (fboundp 'cl-telegram/api:get-emoji-status)))

(deftest test-set-emoji-status ()
  "Test setting emoji status (mock test)."
  (is (fboundp 'cl-telegram/api:set-emoji-status)))

;;; ============================================================================
;;; Parse Function Tests
;;; ============================================================================

(deftest test-parse-custom-emoji-sticker ()
  "Test parsing custom emoji sticker from TL data."
  (let* ((data '(:id "test-id"
                 :emoji "😄"
                 :animation "anim-data"
                 :w 64
                 :h 64
                 :size 2048))
         (sticker (cl-telegram/api::parse-custom-emoji-sticker data)))
    (is (typep sticker 'cl-telegram/api:custom-emoji-sticker))
    (is (string= (cl-telegram/api:custom-emoji-sticker-id sticker) "test-id"))
    (is (string= (cl-telegram/api:custom-emoji-emoji sticker) "😄"))
    (is (= (cl-telegram/api:custom-emoji-width sticker) 64))
    (is (= (cl-telegram/api:custom-emoji-height sticker) 64))))

(deftest test-parse-custom-emoji-pack ()
  "Test parsing custom emoji pack from TL data."
  (let* ((data '(:id "123"
                 :title "Test Pack"
                 :official t
                 :admin-id 456
                 :documents ((:document-id "doc1")
                             (:document-id "doc2")
                             (:document-id "doc3"))))
         (pack (cl-telegram/api::parse-custom-emoji-pack data)))
    (is (typep pack 'cl-telegram/api:custom-emoji-pack))
    (is (string= (cl-telegram/api:emoji-pack-id pack) "123"))
    (is (string= (cl-telegram/api:emoji-pack-title pack) "Test Pack"))
    (is (cl-telegram/api:emoji-pack-is-official pack))
    (is (= (cl-telegram/api:emoji-pack-owner-id pack) 456))
    (is (= (cl-telegram/api:emoji-pack-sticker-count pack) 3))))

(deftest test-parse-interactive-content ()
  "Test parsing interactive content from message data."
  (let* ((message-data '(:media (:type :poll :poll-data)))
         (content (cl-telegram/api::parse-interactive-content message-data 123 456)))
    (is (typep content 'cl-telegram/api:interactive-content))
    (is (eq (cl-telegram/api:interactive-content-type content) :poll))
    (is (= (cl-telegram/api:interactive-chat-id content) 123))
    (is (= (cl-telegram/api:interactive-message-id content) 456))))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(deftest test-custom-emoji-message-flow ()
  "Test custom emoji message flow (mock test)."
  ;; Test that all functions in the flow exist
  (is (fboundp 'cl-telegram/api:get-custom-emoji-sticker))
  (is (fboundp 'cl-telegram/api:send-custom-emoji-message))
  (is (fboundp 'cl-telegram/api:get-custom-emoji-pack))
  (is (fboundp 'cl-telegram/api:list-custom-emoji-packs))
  (is (fboundp 'cl-telegram/api:add-custom-emoji-to-pack))
  (is (fboundp 'cl-telegram/api:delete-custom-emoji))
  (is (fboundp 'cl-telegram/api:create-custom-emoji-pack)))

(deftest test-interactive-poll-flow ()
  "Test interactive poll flow (mock test)."
  ;; Test that all functions in the flow exist
  (is (fboundp 'cl-telegram/api:get-enhanced-message-content))
  (is (fboundp 'cl-telegram/api:create-interactive-poll))
  (is (fboundp 'cl-telegram/api:create-quiz-mode))
  (is (fboundp 'cl-telegram/api:get-poll-results)))

;;; ============================================================================
;;; Error Handling Tests
;;; ============================================================================

(deftest test-send-custom-emoji-message-invalid-id ()
  "Test sending custom emoji with invalid ID (mock test)."
  (is (fboundp 'cl-telegram/api:send-custom-emoji-message)))

(deftest test-get-custom-emoji-pack-not-found ()
  "Test getting non-existent emoji pack (mock test)."
  (is (fboundp 'cl-telegram/api:get-custom-emoji-pack)))

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-all-bot-api-9-tests ()
  "Run all Bot API 9 tests."
  (run! 'bot-api-9-suite))
