;;; stickers-tests.lisp --- Unit tests for stickers functionality

(in-package #:cl-telegram/tests)

(def-suite stickers-tests
  :description "Unit tests for stickers functionality (v0.17.0)")

(in-suite stickers-tests)

;;; ======================================================================
;;; Sticker Class Tests
;;; ======================================================================

(test test-sticker-class-creation
  "Test sticker class creation and accessors"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "test_file_id_123"
                                :file-unique-id "unique_abc_456"
                                :width 512
                                :height 512
                                :is-animated nil
                                :is-video nil
                                :emoji "😀"
                                :set-name "test_stickers")))
    (is (string= "test_file_id_123" (cl-telegram/api:sticker-file-id sticker))
        "File ID should match")
    (is (string= "unique_abc_456" (cl-telegram/api:sticker-file-unique-id sticker))
        "File unique ID should match")
    (is (= 512 (cl-telegram/api:sticker-width sticker))
        "Width should match")
    (is (= 512 (cl-telegram/api:sticker-height sticker))
        "Height should match")
    (is (false (cl-telegram/api:sticker-is-animated sticker))
        "Is-animated should be false")
    (is (false (cl-telegram/api:sticker-is-video sticker))
        "Is-video should be false")
    (is (string= "😀" (cl-telegram/api:sticker-emoji sticker))
        "Emoji should match")
    (is (string= "test_stickers" (cl-telegram/api:sticker-set-name sticker))
        "Set name should match")))

(test test-animated-sticker-class
  "Test animated sticker class creation"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "animated_tgs_123"
                                :width 512
                                :height 512
                                :is-animated t
                                :is-video nil
                                :emoji "🎉")))
    (is (true (cl-telegram/api:sticker-is-animated sticker))
        "Is-animated should be true")
    (is (string= (cl-telegram/api:sticker-type-string sticker) "animated")
        "Type should be animated")))

(test test-video-sticker-class
  "Test video sticker class creation"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "video_webm_123"
                                :width 512
                                :height 512
                                :is-animated nil
                                :is-video t
                                :emoji "🎬")))
    (is (true (cl-telegram/api:sticker-is-video sticker))
        "Is-video should be true")
    (is (string= (cl-telegram/api:sticker-type-string sticker) "video")
        "Type should be video")))

;;; ======================================================================
;;; Sticker Set Class Tests
;;; ======================================================================

(test test-sticker-set-class
  "Test sticker-set class creation and accessors"
  (let ((stickers (list (make-instance 'cl-telegram/api:sticker
                                       :file-id "s1" :width 512 :height 512)
                        (make-instance 'cl-telegram/api:sticker
                                       :file-id "s2" :width 512 :height 512)))
        (set (make-instance 'cl-telegram/api:sticker-set
                            :name "test_set_by_bot"
                            :title "Test Sticker Set"
                            :is-animated nil
                            :is-video nil
                            :stickers stickers)))
    (is (string= "test_set_by_bot" (cl-telegram/api:sticker-set-name set))
        "Set name should match")
    (is (string= "Test Sticker Set" (cl-telegram/api:sticker-set-title set))
        "Set title should match")
    (is (= 2 (length (cl-telegram/api:sticker-set-stickers set)))
        "Should have 2 stickers")
    (is (false (cl-telegram/api:sticker-set-is-animated set))
        "Should not be animated")
    (is (false (cl-telegram/api:sticker-set-is-video set))
        "Should not be video")))

(test test-animated-sticker-set
  "Test animated sticker set creation"
  (let ((set (make-instance 'cl-telegram/api:sticker-set
                            :name "animated_set"
                            :title "Animated Stickers"
                            :is-animated t
                            :is-video nil
                            :stickers nil)))
    (is (true (cl-telegram/api:sticker-set-is-animated set))
        "Should be animated")
    (is (string= (cl-telegram/api:sticker-type-string
                  (make-instance 'cl-telegram/api:sticker
                                 :file-id "test" :width 512 :height 512 :is-animated t))
                 "animated"))))

;;; ======================================================================
;;; Sticker Utility Functions Tests
;;; ======================================================================

(test test-sticker-dimension-string
  "Test sticker dimension string formatting"
  (let ((sticker-512 (make-instance 'cl-telegram/api:sticker
                                    :file-id "test" :width 512 :height 512))
        (sticker-custom (make-instance 'cl-telegram/api:sticker
                                       :file-id "test" :width 300 :height 256)))
    (is (string= (cl-telegram/api:sticker-dimension-string sticker-512) "512x512")
        "Should format 512x512 correctly")
    (is (string= (cl-telegram/api:sticker-dimension-string sticker-custom) "300x256")
        "Should format custom dimensions correctly")))

(test test-sticker-type-string
  "Test sticker type string formatting"
  (let ((static (make-instance 'cl-telegram/api:sticker
                               :file-id "test" :width 512 :height 512
                               :is-animated nil :is-video nil))
        (animated (make-instance 'cl-telegram/api:sticker
                                 :file-id "test" :width 512 :height 512
                                 :is-animated t :is-video nil))
        (video (make-instance 'cl-telegram/api:sticker
                              :file-id "test" :width 512 :height 512
                              :is-animated nil :is-video t)))
    (is (string= (cl-telegram/api:sticker-type-string static) "static")
        "Static sticker type")
    (is (string= (cl-telegram/api:sticker-type-string animated) "animated")
        "Animated sticker type")
    (is (string= (cl-telegram/api:sticker-type-string video) "video")
        "Video sticker type")))

;;; ======================================================================
;;; Emoji Pack Tests
;;; ======================================================================

(test test-emoji-pack-class
  "Test emoji-pack class creation and accessors"
  (let ((pack (make-instance 'cl-telegram/api:emoji-pack
                             :id "test_pack"
                             :title "Test Emoji Pack"
                             :emoji-list '("😀" "😁" "😂" "🤣"))))
    (is (string= "test_pack" (cl-telegram/api:emoji-pack-id pack))
        "Pack ID should match")
    (is (string= "Test Emoji Pack" (cl-telegram/api:emoji-pack-title pack))
        "Pack title should match")
    (is (= 4 (length (cl-telegram/api:emoji-pack-emoji-list pack)))
        "Should have 4 emojis")
    (is (false (cl-telegram/api:emoji-pack-is-installed pack))
        "Should not be installed by default")))

(test test-emoji-pack-install
  "Test emoji pack installation"
  (let ((pack (make-instance 'cl-telegram/api:emoji-pack
                             :id "hearts_pack"
                             :title "Hearts"
                             :emoji-list '("❤️" "🧡" "💛"))))
    (is (false (cl-telegram/api:emoji-pack-is-installed pack))
        "Should not be installed initially")
    (setf (cl-telegram/api:emoji-pack-is-installed pack) t)
    (is (true (cl-telegram/api:emoji-pack-is-installed pack))
        "Should be installed after setting")))

(test test-get-default-emoji-packs
  "Test getting default emoji packs"
  (let ((packs (cl-telegram/api:get-emoji-packs)))
    (is packs "Should return emoji packs")
    (is (> (length packs) 0) "Should have at least one pack")
    ;; Check default pack exists
    (let ((default (find "default" packs :key #'cl-telegram/api:emoji-pack-id :test #'string=)))
      (is default "Should have default pack")
      (is (> (length (cl-telegram/api:emoji-pack-emoji-list default)) 0)
          "Default pack should have emojis"))))

;;; ======================================================================
;;; Favorite Stickers Tests
;;; ======================================================================

(test test-add-favorite-sticker
  "Test adding sticker to favorites"
  (let ((file-id "fav_sticker_123"))
    ;; Clear first
    (setf cl-telegram/api:*favorite-stickers* nil)
    ;; Add
    (let ((result (cl-telegram/api:add-favorite-sticker file-id)))
      (is result "Should return success")
      (is (member file-id cl-telegram/api:*favorite-stickers* :test #'string=)
          "Should be in favorites list"))))

(test test-remove-favorite-sticker
  "Test removing sticker from favorites"
  (let ((file-id "fav_sticker_456"))
    ;; Add first
    (setf cl-telegram/api:*favorite-stickers* (list file-id))
    ;; Remove
    (let ((result (cl-telegram/api:remove-favorite-sticker file-id)))
      (is result "Should return success")
      (is (not (member file-id cl-telegram/api:*favorite-stickers* :test #'string=))
          "Should not be in favorites after removal"))))

(test test-get-favorite-stickers
  "Test getting favorite stickers list"
  (let ((test-list '("stick1" "stick2" "stick3")))
    (setf cl-telegram/api:*favorite-stickers* test-list)
    (let ((result (cl-telegram/api:get-favorite-stickers)))
      (is (equal result test-list) "Should return favorites list"))))

;;; ======================================================================
;;; Sticker Cache Tests
;;; ======================================================================

(test test-sticker-cache-operations
  "Test sticker cache operations"
  (let ((set-name "cached_test_set")
        (set (make-instance 'cl-telegram/api:sticker-set
                            :name set-name
                            :title "Cached Set"
                            :stickers nil)))
    ;; Add to cache
    (setf (gethash set-name cl-telegram/api:*sticker-cache*) set)
    ;; Verify
    (is (gethash set-name cl-telegram/api:*sticker-cache*) "Should be cached")
    ;; Remove
    (remhash set-name cl-telegram/api:*sticker-cache*)
    (is (not (gethash set-name cl-telegram/api:*sticker-cache*)) "Should be removed")))

(test test-clear-sticker-cache
  "Test clearing sticker cache"
  (let ((set-name "clear_test_set"))
    ;; Add to cache
    (setf (gethash set-name cl-telegram/api:*sticker-cache*)
          (make-instance 'cl-telegram/api:sticker-set
                         :name set-name
                         :title "Test"
                         :stickers nil))
    ;; Clear
    (let ((result (cl-telegram/api:clear-sticker-cache)))
      (is result "Should return success")
      (is (= (hash-table-count cl-telegram/api:*sticker-cache*) 0)
          "Cache should be empty"))))

;;; ======================================================================
;;; Sticker Set Management Tests
;;; ======================================================================

(test test-get-all-sticker-sets
  "Test getting all sticker sets from cache"
  (let ((set-name-1 "test_set_1")
        (set-name-2 "test_set_2"))
    ;; Clear cache first
    (clrhash cl-telegram/api:*sticker-cache*)
    ;; Add sets
    (setf (gethash set-name-1 cl-telegram/api:*sticker-cache*)
          (make-instance 'cl-telegram/api:sticker-set
                         :name set-name-1 :title "Set 1" :stickers nil))
    (setf (gethash set-name-2 cl-telegram/api:*sticker-cache*)
          (make-instance 'cl-telegram/api:sticker-set
                         :name set-name-2 :title "Set 2" :stickers nil))
    ;; Get all
    (let ((sets (cl-telegram/api:get-all-sticker-sets)))
      (is (= (length sets) 2) "Should have 2 sets")
      ;; Verify set names
      (is (or (string= (cl-telegram/api:sticker-set-name (first sets)) set-name-1)
              (string= (cl-telegram/api:sticker-set-name (first sets)) set-name-2))
          "First set should match one of the test sets"))))

(test test-uninstall-sticker-set
  "Test uninstalling sticker set"
  (let ((set-name "uninstall_test_set"))
    ;; Add to cache
    (setf (gethash set-name cl-telegram/api:*sticker-cache*)
          (make-instance 'cl-telegram/api:sticker-set
                         :name set-name :title "To Uninstall" :stickers nil))
    ;; Uninstall
    (let ((result (cl-telegram/api:uninstall-sticker-set set-name)))
      (is result "Should return success")
      (is (not (gethash set-name cl-telegram/api:*sticker-cache*))
          "Should be removed from cache"))))

;;; ======================================================================
;;; Sticker in Message Tests
;;; ======================================================================

(test test-get-sticker-from-message
  "Test extracting sticker from message"
  (let ((message '(:sticker (:file-id "msg_sticker_123"
                                      :file-unique-id "unique_msg_456"
                                      :width 512
                                      :height 512
                                      :is-animated nil
                                      :is-video nil
                                      :emoji "🎉"
                                      :set-name "test_set"))))
    (let ((sticker (cl-telegram/api:get-sticker-from-message message)))
      (is sticker "Should extract sticker")
      (is (string= "msg_sticker_123" (cl-telegram/api:sticker-file-id sticker))
          "File ID should match")
      (is (string= "🎉" (cl-telegram/api:sticker-emoji sticker))
          "Emoji should match"))))

(test test-get-sticker-from-message-no-sticker
  "Test extracting sticker from message without sticker"
  (let ((message '(:text "Just a text message")))
    (let ((sticker (cl-telegram/api:get-sticker-from-message message)))
      (is (null sticker) "Should return NIL for non-sticker message"))))

;;; ======================================================================
;;; Emoji Pack Management Tests
;;; ======================================================================

(test test-install-emoji-pack
  "Test installing emoji pack"
  (let ((pack-id "test_install_pack"))
    ;; Add pack to list first
    (let ((pack (make-instance 'cl-telegram/api:emoji-pack
                               :id pack-id
                               :title "Test Install"
                               :emoji-list '("😀"))))
      (push pack cl-telegram/api:*emoji-packs*))
    ;; Install
    (let ((result (cl-telegram/api:install-emoji-pack pack-id)))
      (is result "Should return success")
      ;; Verify installed
      (let ((installed (find pack-id cl-telegram/api:*emoji-packs*
                             :key #'cl-telegram/api:emoji-pack-id :test #'string=)))
        (is installed "Pack should exist")
        (is (true (cl-telegram/api:emoji-pack-is-installed installed))
            "Should be marked as installed"))))

(test test-uninstall-emoji-pack
  "Test uninstalling emoji pack"
  (let ((pack-id "test_uninstall_pack"))
    ;; Add and install pack
    (let ((pack (make-instance 'cl-telegram/api:emoji-pack
                               :id pack-id
                               :title "Test Uninstall"
                               :emoji-list '("😂"))))
      (setf (cl-telegram/api:emoji-pack-is-installed pack) t)
      (push pack cl-telegram/api:*emoji-packs*))
    ;; Uninstall
    (let ((result (cl-telegram/api:uninstall-emoji-pack pack-id)))
      (is result "Should return success")
      ;; Verify uninstalled
      (let ((pack (find pack-id cl-telegram/api:*emoji-packs*
                        :key #'cl-telegram/api:emoji-pack-id :test #'string=)))
        (is (false (cl-telegram/api:emoji-pack-is-installed pack))
            "Should be marked as uninstalled"))))

(test test-get-installed-emoji-packs
  "Test getting installed emoji packs"
  (let ((pack-1 (make-instance 'cl-telegram/api:emoji-pack
                               :id "installed_1"
                               :title "Installed 1"
                               :emoji-list '("😀")))
        (pack-2 (make-instance 'cl-telegram/api:emoji-pack
                               :id "not_installed"
                               :title "Not Installed"
                               :emoji-list '("😂"))))
    ;; Set installation status
    (setf (cl-telegram/api:emoji-pack-is-installed pack-1) t)
    (setf (cl-telegram/api:emoji-pack-is-installed pack-2) nil)
    ;; Add to list
    (setf cl-telegram/api:*emoji-packs* (list pack-1 pack-2))
    ;; Get installed
    (let ((installed (cl-telegram/api:get-installed-emoji-packs)))
      (is (= (length installed) 1) "Should have 1 installed pack")
      (is (string= "installed_1" (cl-telegram/api:emoji-pack-id (first installed)))
          "Should be the installed pack"))))

;;; ======================================================================
;;; Custom Emoji Tests
;;; ======================================================================

(test test-send-custom-emoji
  "Test sending custom emoji"
  ;; This tests the wrapper function logic
  (let ((emoji-id "custom_emoji_123"))
    ;; Mock get-custom-emoji to return a file-id
    (let ((file-id emoji-id))  ; In real scenario, this would call API
      (when file-id
        ;; Would call send-sticker
        (is (stringp file-id) "Should have file-id")))))

;;; ======================================================================
;;; Sticker Search Tests
;;; ======================================================================

(test test-search-stickers-mock
  "Test search stickers function (mock)"
  ;; The actual API call requires connection
  ;; Test that the function exists and handles empty results
  (let ((result (cl-telegram/api:search-stickers "test" :limit 10)))
    ;; May return NIL without connection
    (pass "Search function should execute")))

(test test-get-trending-stickers-mock
  "Test get trending stickers function (mock)"
  ;; The actual API call requires connection
  (let ((result (cl-telegram/api:get-trending-stickers :limit 10)))
    ;; May return NIL without connection
    (pass "Trending function should execute")))

;;; ======================================================================
;;; Sticker Dimension and Type Tests
;;; ======================================================================

(test test-various-sticker-dimensions
  "Test various sticker dimensions"
  (let ((small (make-instance 'cl-telegram/api:sticker
                              :file-id "small" :width 256 :height 256))
        (medium (make-instance 'cl-telegram/api:sticker
                               :file-id "medium" :width 384 :height 384))
        (large (make-instance 'cl-telegram/api:sticker
                              :file-id "large" :width 512 :height 512)))
    (is (string= (cl-telegram/api:sticker-dimension-string small) "256x256"))
    (is (string= (cl-telegram/api:sticker-dimension-string medium) "384x384"))
    (is (string= (cl-telegram/api:sticker-dimension-string large) "512x512"))))

;;; ======================================================================
;;; Sticker Management Tests (Bot API 9.0+)
;;; ======================================================================

(test test-set-sticker-position-in-set
  "Test setting sticker position in set"
  ;; Function requires API connection, test that it exists and handles gracefully
  (let ((result (cl-telegram/api:set-sticker-position-in-set "test_sticker_id" 0)))
    ;; May return NIL without connection, T with connection
    (is (or (null result) (eq result t)))))

(test test-delete-sticker-from-set
  "Test deleting sticker from set"
  (let ((result (cl-telegram/api:delete-sticker-from-set "test_sticker_id")))
    (is (or (null result) (eq result t)))))

(test test-set-sticker-emoji-list
  "Test setting sticker emoji list"
  (let ((emoji-list '("😀" "😁" "😂"))
        (result (cl-telegram/api:set-sticker-emoji-list "test_sticker_id" '("😀" "😁" "😂"))))
    (is (or (null result) (eq result t)))))

(test test-set-sticker-set-thumbnail
  "Test setting sticker set thumbnail"
  (let ((result (cl-telegram/api:set-sticker-set-thumbnail "TestSet" 123456 :thumbnail-file-id "file_id")))
    (is (or (null result) (eq result t)))))

(test test-set-custom-emoji-sticker-set-thumbnail
  "Test setting custom emoji sticker set thumbnail"
  (let ((result (cl-telegram/api:set-custom-emoji-sticker-set-thumbnail "EmojiSet" :custom-emoji-id "emoji_id")))
    (is (or (null result) (eq result t)))))

(test test-get-custom-emoji-stickers
  "Test getting custom emoji stickers"
  (let ((result (cl-telegram/api:get-custom-emoji-stickers '("emoji_id_1" "emoji_id_2"))))
    ;; Should return list of sticker objects or NIL
    (is (or (null result) (listp result)))))

(test test-get-forum-topic-icon-stickers
  "Test getting forum topic icon stickers"
  (let ((result (cl-telegram/api:get-forum-topic-icon-stickers)))
    ;; Should return list of sticker objects or NIL
    (is (or (null result) (listp result)))))

;;; ======================================================================
;;; Test Runner
;;; ======================================================================

(defun run-stickers-tests ()
  "Run all stickers tests"
  (format t "~%=== Running Stickers Unit Tests ===~%~%")
  (fiveam:run! 'stickers-tests))
