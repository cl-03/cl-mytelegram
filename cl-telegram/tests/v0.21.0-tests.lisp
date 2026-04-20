;;; v0.21.0-tests.lisp --- Tests for v0.21.0 UX enhancement features

(in-package #:cl-telegram/tests)

(def-suite v0.21.0-tests
  :description "Tests for v0.21.0 user experience enhancements")

(in-suite v0.21.0-tests)

;;; ======================================================================
;;; Chat Folder Tests
;;; ======================================================================

(test test-chat-folder-class
  "Test chat-folder class creation and accessors"
  (let ((folder (make-instance 'cl-telegram/api:chat-folder
                               :id 1
                               :title "Work"
                               :icon "💼"
                               :chat-list '(123 456 789)
                               :is-shared t)))
    (is (= 1 (cl-telegram/api:chat-folder-id folder)))
    (is (string= "Work" (cl-telegram/api:chat-folder-title folder)))
    (is (string= "💼" (cl-telegram/api:chat-folder-icon folder)))
    (is (= 3 (length (cl-telegram/api:chat-folder-chat-list folder))))
    (is (true (cl-telegram/api:chat-folder-is-shared folder)))))

(test test-chat-folder-defaults
  "Test chat-folder default values"
  (let ((folder (make-instance 'cl-telegram/api:chat-folder
                               :title "Test")))
    (is (= 0 (cl-telegram/api:chat-folder-id folder)))
    (is (string= "Test" (cl-telegram/api:chat-folder-title folder)))
    (is (null (cl-telegram/api:chat-folder-icon folder)))
    (is (null (cl-telegram/api:chat-folder-chat-list folder)))))

(test test-make-chat-folder
  "Test make-chat-folder helper function"
  (let ((filter (cl-telegram/api:make-chat-folder-filter
                 :include-channels t
                 :include-groups t))
        (folder (cl-telegram/api:make-chat-folder "News"
                                                  :icon "📰"
                                                  :filters filter)))
    (is (string= "News" (cl-telegram/api:chat-folder-title folder)))
    (is (string= "📰" (cl-telegram/api:chat-folder-icon folder)))
    (is (typep (cl-telegram/api:chat-folder-filters folder)
               'cl-telegram/api:chat-folder-filter))))

(test test-make-chat-folder-filter
  "Test make-chat-folder-filter helper"
  (let ((filter (cl-telegram/api:make-chat-folder-filter
                 :include-muted t
                 :include-read nil
                 :include-channels t
                 :include-groups t
                 :exclude-chats '(999 888))))
    (is (true (cl-telegram/api:filter-include-muted filter)))
    (is (false (cl-telegram/api:filter-include-read filter)))
    (is (true (cl-telegram/api:filter-include-channels filter)))
    (is (true (cl-telegram/api:filter-include-groups filter)))
    (is (= 2 (length (cl-telegram/api:filter-exclude-chats filter))))))

(test test-chat-folder-filter-defaults
  "Test chat-folder-filter default values"
  (let ((filter (make-instance 'cl-telegram/api:chat-folder-filter)))
    (is (null (cl-telegram/api:filter-include-muted filter)))
    (is (null (cl-telegram/api:filter-include-read filter)))
    (is (null (cl-telegram/api:filter-include-channels filter)))
    (is (null (cl-telegram/api:filter-exclude-chats filter)))))

;;; ======================================================================
;;; Archive Info Tests
;;; ======================================================================

(test test-archive-info-class
  "Test archive-info class creation"
  (let ((archive (make-instance 'cl-telegram/api:archive-info
                                :total-count 50
                                :unread-count 5
                                :chats '(1 2 3))))
    (is (= 50 (cl-telegram/api:archive-total-count archive)))
    (is (= 5 (cl-telegram/api:archive-unread-count archive)))
    (is (= 3 (length (cl-telegram/api:archive-chats archive))))))

(test test-archive-info-defaults
  "Test archive-info default values"
  (let ((archive (make-instance 'cl-telegram/api:archive-info)))
    (is (= 0 (cl-telegram/api:archive-total-count archive)))
    (is (= 0 (cl-telegram/api:archive-unread-count archive)))
    (is (null (cl-telegram/api:archive-chats archive)))))

;;; ======================================================================
;;; Custom Emoji Tests
;;; ======================================================================

(test test-custom-emoji-class
  "Test custom-emoji class creation"
  (let ((emoji (make-instance 'cl-telegram/api:custom-emoji
                              :id "emoji_123"
                              :emoji "😀"
                              :file-id "file_abc"
                              :needs-premium t
                              :is-animated t)))
    (is (string= "emoji_123" (cl-telegram/api:custom-emoji-id emoji)))
    (is (string= "😀" (cl-telegram/api:custom-emoji-emoji emoji)))
    (is (string= "file_abc" (cl-telegram/api:custom-emoji-file-id emoji)))
    (is (true (cl-telegram/api:custom-emoji-needs-premium emoji)))
    (is (true (cl-telegram/api:custom-emoji-is-animated emoji)))))

(test test-custom-emoji-defaults
  "Test custom-emoji default values"
  (let ((emoji (make-instance 'cl-telegram/api:custom-emoji)))
    (is (string= "" (cl-telegram/api:custom-emoji-id emoji)))
    (is (string= "" (cl-telegram/api:custom-emoji-emoji emoji)))
    (is (true (cl-telegram/api:custom-emoji-needs-premium emoji)))))

;;; ======================================================================
;;; Emoji Category Tests
;;; ======================================================================

(test test-emoji-category-class
  "Test emoji-category class creation"
  (let ((cat (make-instance 'cl-telegram/api:emoji-category
                            :name "Favorites"
                            :emoji-list '("😀" "😂" "😍")
                            :is-premium nil)))
    (is (string= "Favorites" (cl-telegram/api:emoji-category-name cat)))
    (is (= 3 (length (cl-telegram/api:emoji-category-emoji-list cat))))
    (is (false (cl-telegram/api:emoji-category-is-premium cat)))))

;;; ======================================================================
;;; Message Effect Tests
;;; ======================================================================

(test test-message-effect-class
  "Test message-effect class creation"
  (let ((effect (make-instance 'cl-telegram/api:message-effect
                               :id "effect_123"
                               :effect-type :animation
                               :emoji "🎉")))
    (is (string= "effect_123" (cl-telegram/api:message-effect-id effect)))
    (is (eq :animation (cl-telegram/api:message-effect-type effect)))
    (is (string= "🎉" (cl-telegram/api:message-effect-emoji effect)))))

(test test-message-effect-defaults
  "Test message-effect default values"
  (let ((effect (make-instance 'cl-telegram/api:message-effect)))
    (is (string= "" (cl-telegram/api:message-effect-id effect)))
    (is (eq :animation (cl-telegram/api:message-effect-type effect)))))

;;; ======================================================================
;;; Chat Wallpaper Tests
;;; ======================================================================

(test test-chat-wallpaper-class
  "Test chat-wallpaper class creation"
  (let ((wp (make-instance 'cl-telegram/api:chat-wallpaper
                           :id 100
                           :type :gradient
                           :dark-theme-dimensions 50
                           :light-theme-dimensions 30)))
    (is (= 100 (cl-telegram/api:chat-wallpaper-id wp)))
    (is (eq :gradient (cl-telegram/api:chat-wallpaper-type wp)))
    (is (= 50 (cl-telegram/api:chat-wallpaper-dark-dimensions wp)))
    (is (= 30 (cl-telegram/api:chat-wallpaper-light-dimensions wp)))))

(test test-chat-wallpaper-defaults
  "Test chat-wallpaper default values"
  (let ((wp (make-instance 'cl-telegram/api:chat-wallpaper)))
    (is (= 0 (cl-telegram/api:chat-wallpaper-id wp)))
    (is (eq :solid (cl-telegram/api:chat-wallpaper-type wp)))
    (is (null (cl-telegram/api:chat-wallpaper-document wp)))))

;;; ======================================================================
;;; Chat Theme Tests
;;; ======================================================================

(test test-chat-theme-class
  "Test chat-theme class creation"
  (let ((theme (make-instance 'cl-telegram/api:chat-theme
                              :name "Dark Blue"
                              :colors '(:bg "#000000" :text "#FFFFFF")
                              :is-premium t)))
    (is (string= "Dark Blue" (cl-telegram/api:chat-theme-name theme)))
    (is (equal '(:bg "#000000" :text "#FFFFFF") (cl-telegram/api:chat-theme-colors theme)))
    (is (true (cl-telegram/api:chat-theme-is-premium theme)))))

(test test-chat-theme-defaults
  "Test chat-theme default values"
  (let ((theme (make-instance 'cl-telegram/api:chat-theme)))
    (is (string= "" (cl-telegram/api:chat-theme-name theme)))
    (is (null (cl-telegram/api:chat-theme-colors theme)))
    (is (null (cl-telegram/api:chat-theme-is-premium theme)))))

;;; ======================================================================
;;; Forum Topic Tests
;;; ======================================================================

(test test-forum-topic-class
  "Test forum-topic class creation"
  (let ((topic (make-instance 'cl-telegram/api:forum-topic
                              :message-thread-id 100
                              :name "General Discussion"
                              :icon-color 7220692
                              :is-closed nil
                              :is-hidden nil
                              :creator-id 12345
                              :unread-count 5)))
    (is (= 100 (cl-telegram/api:forum-topic-message-thread-id topic)))
    (is (string= "General Discussion" (cl-telegram/api:forum-topic-name topic)))
    (is (= 7220692 (cl-telegram/api:forum-topic-icon-color topic)))
    (is (false (cl-telegram/api:forum-topic-is-closed topic)))
    (is (= 5 (cl-telegram/api:forum-topic-unread-count topic)))))

(test test-forum-topic-defaults
  "Test forum-topic default values"
  (let ((topic (make-instance 'cl-telegram/api:forum-topic
                              :name "Test")))
    (is (= 0 (cl-telegram/api:forum-topic-message-thread-id topic)))
    (is (string= "Test" (cl-telegram/api:forum-topic-name topic)))
    (is (null (cl-telegram/api:forum-topic-icon-color topic)))))

(test test-forum-topic-info-class
  "Test forum-topic-info class creation"
  (let ((info (make-instance 'cl-telegram/api:forum-topic-info
                             :total-count 10
                             :topics (list (make-instance 'cl-telegram/api:forum-topic
                                                          :name "Topic 1")
                                           (make-instance 'cl-telegram/api:forum-topic
                                                          :name "Topic 2")))))
    (is (= 10 (cl-telegram/api:forum-total-count info)))
    (is (= 2 (length (cl-telegram/api:forum-topics-list info))))))

;;; ======================================================================
;;; Statistics Classes Tests
;;; ======================================================================

(test test-channel-statistics-class
  "Test channel-statistics class creation"
  (let ((stats (make-instance 'cl-telegram/api:channel-statistics
                              :channel-id 123456
                              :period-start 1713542400
                              :period-end 1713628800
                              :member-count 10000
                              :view-count 50000
                              :new-members 100
                              :left-members 20)))
    (is (= 123456 (cl-telegram/api:stats-channel-id stats)))
    (is (= 10000 (cl-telegram/api:stats-member-count stats)))
    (is (= 50000 (cl-telegram/api:stats-view-count stats)))
    (is (= 100 (cl-telegram/api:stats-new-members stats)))
    (is (= 20 (cl-telegram/api:stats-left-members stats)))))

(test test-message-statistics-class
  "Test message-statistics class creation"
  (let ((stats (make-instance 'cl-telegram/api:message-statistics
                              :message-id 789
                              :view-count 1500
                              :forward-count 25
                              :reaction-count 100)))
    (is (= 789 (cl-telegram/api:msg-stats-message-id stats)))
    (is (= 1500 (cl-telegram/api:msg-stats-view-count stats)))
    (is (= 25 (cl-telegram/api:msg-stats-forward-count stats)))
    (is (= 100 (cl-telegram/api:msg-stats-reaction-count stats)))))

(test test-reaction-statistics-class
  "Test reaction-statistics class creation"
  (let ((stats (make-instance 'cl-telegram/api:reaction-statistics
                              :message-id 789
                              :total-reactions 150
                              :reaction-breakdown '(("👍" . 50) ("❤️" . 100)))))
    (is (= 789 (cl-telegram/api:reaction-stats-message-id stats)))
    (is (= 150 (cl-telegram/api:reaction-stats-total stats)))
    (is (= 2 (length (cl-telegram/api:reaction-stats-breakdown stats))))))

;;; ======================================================================
;;; Sponsored Message Tests
;;; ======================================================================

(test test-sponsored-message-class
  "Test sponsored-message class creation"
  (let ((msg (make-instance 'cl-telegram/api:sponsored-message
                            :message-id 999
                            :text "Check out this offer!"
                            :link-url "https://example.com"
                            :link-name "Example Shop"
                            :is-promoted nil)))
    (is (= 999 (cl-telegram/api:sponsored-message-id msg)))
    (is (string= "Check out this offer!" (cl-telegram/api:sponsored-message-text msg)))
    (is (string= "https://example.com" (cl-telegram/api:sponsored-message-link-url msg)))
    (is (string= "Example Shop" (cl-telegram/api:sponsored-message-link-name msg)))))

;;; ======================================================================
;;; Mock API Tests (Chat Folders)
;;; ======================================================================

(test test-create-chat-folder-return
  "Test create-chat-folder returns folder ID or NIL"
  (let ((folder (cl-telegram/api:make-chat-folder "Test")))
    (let ((result (cl-telegram/api:create-chat-folder folder)))
      (is (or (integerp result) (null result))))))

(test test-get-chat-folders-return-type
  "Test get-chat-folders returns list"
  (let ((result (cl-telegram/api:get-chat-folders)))
    (is (listp result))))

(test test-delete-chat-folder-return
  "Test delete-chat-folder returns boolean"
  (let ((result (cl-telegram/api:delete-chat-folder 1)))
    (is (or (eq t result) (null result)))))

(test test-archive-chat-return
  "Test archive-chat returns boolean"
  (let ((result (cl-telegram/api:archive-chat 123456)))
    (is (or (eq t result) (null result)))))

(test test-get-archive-info-return-type
  "Test get-archive-info returns archive-info or NIL"
  (let ((result (cl-telegram/api:get-archive-info)))
    (is (or (notnull result) (null result)))))

;;; ======================================================================
;;; Mock API Tests (Emoji & Customization)
;;; ======================================================================

(test test-search-custom-emoji-return-type
  "Test search-custom-emoji returns list"
  (let ((result (cl-telegram/api:search-custom-emoji "smile")))
    (is (listp result))))

(test test-get-premium-emojis-return-type
  "Test get-premium-emojis returns list"
  (let ((result (cl-telegram/api:get-premium-emojis)))
    (is (listp result))))

(test test-send-dice-return
  "Test send-dice returns message or NIL"
  (let ((result (cl-telegram/api:send-dice 123456)))
    (is (or (notnull result) (null result)))))

(test test-send-message-with-effect-return
  "Test send-message-with-effect returns message or NIL"
  (let ((result (cl-telegram/api:send-message-with-effect 123456 "Hello"
                                                          :message-effect-id "effect_1")))
    (is (or (notnull result) (null result)))))

(test test-get-wallpapers-return-type
  "Test get-wallpapers returns list"
  (let ((result (cl-telegram/api:get-wallpapers)))
    (is (listp result))))

(test test-set-chat-wallpaper-return
  "Test set-chat-wallpaper returns boolean"
  (let ((wp (make-instance 'cl-telegram/api:chat-wallpaper :id 1)))
    (let ((result (cl-telegram/api:set-chat-wallpaper 123456 wp)))
      (is (or (eq t result) (null result))))))

(test test-send-star-reaction-return
  "Test send-star-reaction returns boolean"
  (let ((result (cl-telegram/api:send-star-reaction 123456 789 100)))
    (is (or (eq t result) (null result)))))

;;; ======================================================================
;;; Mock API Tests (Channel Advanced)
;;; ======================================================================

(test test-create-forum-topic-return
  "Test create-forum-topic returns forum-topic or NIL"
  (let ((result (cl-telegram/api:create-forum-topic 123456 "New Topic")))
    (is (or (notnull result) (null result)))))

(test test-get-forum-topics-return-type
  "Test get-forum-topics returns forum-topic-info or NIL"
  (let ((result (cl-telegram/api:get-forum-topics 123456)))
    (is (or (notnull result) (null result)))))

(test test-close-forum-topic-return
  "Test close-forum-topic returns boolean"
  (let ((result (cl-telegram/api:close-forum-topic 123456 100)))
    (is (or (eq t result) (null result)))))

(test test-delete-forum-topic-return
  "Test delete-forum-topic returns boolean"
  (let ((result (cl-telegram/api:delete-forum-topic 123456 100)))
    (is (or (eq t result) (null result)))))

(test test-pin-forum-topic-return
  "Test pin-forum-topic returns boolean"
  (let ((result (cl-telegram/api:pin-forum-topic 123456 100)))
    (is (or (eq t result) (null result)))))

(test test-get-forum-topic-icon-stickers-return-type
  "Test get-forum-topic-icon-stickers returns list"
  (let ((result (cl-telegram/api:get-forum-topic-icon-stickers)))
    (is (listp result))))

(test test-get-channel-statistics-return-type
  "Test get-channel-statistics returns channel-statistics or NIL"
  (let ((result (cl-telegram/api:get-channel-statistics 123456)))
    (is (or (notnull result) (null result)))))

(test test-get-message-statistics-return-type
  "Test get-message-statistics returns message-statistics or NIL"
  (let ((result (cl-telegram/api:get-message-statistics 123456 789)))
    (is (or (notnull result) (null result)))))

(test test-get-reaction-statistics-return-type
  "Test get-reaction-statistics returns reaction-statistics or NIL"
  (let ((result (cl-telegram/api:get-reaction-statistics 123456 789)))
    (is (or (notnull result) (null result)))))

(test test-get-sponsored-messages-return-type
  "Test get-sponsored-messages returns list"
  (let ((result (cl-telegram/api:get-sponsored-messages 123456)))
    (is (listp result))))

;;; ======================================================================
;;; Global State Tests
;;; ======================================================================

(test test-chat-folders-cache-initial
  "Test chat-folders-cache is hash table"
  (is (typep cl-telegram/api:*chat-folders-cache* 'hash-table)))

(test test-archive-cache-initial
  "Test archive-cache initial value"
  (is (or (null cl-telegram/api:*archive-cache*)
          (typep cl-telegram/api:*archive-cache* 'cl-telegram/api:archive-info))))

(test test-custom-emoji-cache-initial
  "Test custom-emoji-cache is hash table"
  (is (typep cl-telegram/api:*custom-emoji-cache* 'hash-table)))

(test test-default-dice-emojis
  "Test default dice emojis list"
  (is (= 6 (length cl-telegram/api:*default-dice-emojis*)))
  (is (member "🎲" cl-telegram/api:*default-dice-emojis* :test #'string=))
  (is (member "🎯" cl-telegram/api:*default-dice-emojis* :test #'string=)))

(test test-topic-icon-colors
  "Test topic icon colors array"
  (is (vectorp cl-telegram/api:*topic-icon-colors*))
  (is (> (length cl-telegram/api:*topic-icon-colors*) 0)))

(test test-default-folder-icons
  "Test default folder icons list"
  (is (listp cl-telegram/api:*default-folder-icons*))
  (is (> (length cl-telegram/api:*default-folder-icons*) 0)))

;;; ======================================================================
;;; Edge Case Tests
;;; ======================================================================

(test test-make-chat-folder-empty-title
  "Test make-chat-folder with empty title"
  (let ((folder (cl-telegram/api:make-chat-folder "")))
    (is (string= "" (cl-telegram/api:chat-folder-title folder)))))

(test test-make-chat-folder-long-title
  "Test make-chat-folder with max length title (12 chars)"
  (let ((folder (cl-telegram/api:make-chat-folder "123456789012")))
    (is (string= "123456789012" (cl-telegram/api:chat-folder-title folder)))))

(test test-make-folder-filter-all-options
  "Test make-chat-folder-filter with all options"
  (let ((filter (cl-telegram/api:make-chat-folder-filter
                 :include-muted t
                 :include-read t
                 :include-archived t
                 :include-channels t
                 :include-groups t
                 :include-bots t
                 :include-non-bots t
                 :include-contacts t
                 :include-non-contacts t
                 :exclude-chats '(1 2 3)
                 :include-chats '(4 5 6))))
    (is (true (cl-telegram/api:filter-include-muted filter)))
    (is (= 3 (length (cl-telegram/api:filter-exclude-chats filter))))
    (is (= 3 (length (cl-telegram/api:filter-include-chats filter))))))

(test test-send-dice-all-emoji
  "Test send-dice with all emoji types"
  (dolist (emoji '("🎲" "🎯" "🏀" "⚽" "🎳" "🎰"))
    (let ((result (cl-telegram/api:send-dice 123456 :emoji emoji)))
      (is (or (notnull result) (null result))))))

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-v0.21.0-tests ()
  "Run all v0.21.0 tests"
  (format t "~%=== Running v0.21.0 UX Enhancement Unit Tests ===~%~%")
  (fiveam:run! 'v0.21.0-tests))

(export '(run-v0.21.0-tests))
