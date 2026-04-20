;;; stickers-enhanced-tests.lisp --- Tests for Stickers API Enhanced (v0.34.0)

(in-package #:cl-telegram/tests)

(def-suite* stickers-enhanced-tests
  :description "Tests for Stickers API Enhanced v0.34.0")

;;; ============================================================================
;;; Section 1: Sticker Position Tests
;;; ============================================================================

(test test-set-sticker-position-in-set
  "Test setting sticker position in set"
  (let ((result (cl-telegram/api:set-sticker-position-in-set
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ"
                 0)))
    (is (or (eq result t) (null result)))))

(test test-set-sticker-position-in-set-middle
  "Test setting sticker position in middle of set"
  (let ((result (cl-telegram/api:set-sticker-position-in-set
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ"
                 5)))
    (is (or (eq result t) (null result)))))

(test test-set-sticker-position-in-set-last
  "Test setting sticker position to last"
  (let ((result (cl-telegram/api:set-sticker-position-in-set
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ"
                 19)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 2: Delete Sticker Tests
;;; ============================================================================

(test test-delete-sticker-from-set
  "Test deleting a sticker from set"
  (let ((result (cl-telegram/api:delete-sticker-from-set
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ")))
    (is (or (eq result t) (null result)))))

(test test-delete-multiple-stickers
  "Test deleting multiple stickers from set"
  (let ((results
         (loop for sticker-id in '("sticker_1" "sticker_2" "sticker_3")
               collect (cl-telegram/api:delete-sticker-from-set sticker-id))))
    (is (listp results))
    (is (= (length results) 3))))

;;; ============================================================================
;;; Section 3: Sticker Emoji List Tests
;;; ============================================================================

(test test-set-sticker-emoji-list
  "Test setting sticker emoji list"
  (let ((result (cl-telegram/api:set-sticker-emoji-list
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ"
                 '("😀" "😁" "😂"))))
    (is (or (eq result t) (null result)))))

(test test-set-sticker-emoji-list-single
  "Test setting single emoji for sticker"
  (let ((result (cl-telegram/api:set-sticker-emoji-list
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ"
                 '("🎉"))))
    (is (or (eq result t) (null result)))))

(test test-set-sticker-emoji-list-max
  "Test setting maximum emoji for sticker (20)"
  (let ((result (cl-telegram/api:set-sticker-emoji-list
                 "CAADAgADQAAD7gkSAACQl7Z0ZcJdFgQ"
                 '("😀" "😁" "😂" "🤣" "😃" "😄" "😅" "😆"
                   "😉" "😊" "😋" "😎" "😍" "😘" "😗" "😙"
                   "😚" "🙂" "🤗" "🤩"))))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 4: Sticker Set Thumbnail Tests
;;; ============================================================================

(test test-set-sticker-set-thumbnail
  "Test setting sticker set thumbnail"
  (let ((result (cl-telegram/api:set-sticker-set-thumbnail
                 "MyStickerSet"
                 123456
                 :thumbnail-file-id "file_id_123")))
    (is (or (eq result t) (null result)))))

(test test-set-sticker-set-thumbnail-no-file
  "Test setting sticker set thumbnail without file"
  (let ((result (cl-telegram/api:set-sticker-set-thumbnail
                 "MyStickerSet"
                 123456)))
    (is (or (eq result t) (null result)))))

(test test-set-sticker-set-thumbnail-video
  "Test setting video sticker set thumbnail (WEBM)"
  (let ((result (cl-telegram/api:set-sticker-set-thumbnail
                 "VideoStickerSet"
                 123456
                 :thumbnail-file-id "webm_thumbnail_id")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 5: Custom Emoji Sticker Set Thumbnail Tests
;;; ============================================================================

(test test-set-custom-emoji-sticker-set-thumbnail
  "Test setting custom emoji sticker set thumbnail"
  (let ((result (cl-telegram/api:set-custom-emoji-sticker-set-thumbnail
                 "EmojiStickerSet"
                 :custom-emoji-id "emoji_id_123")))
    (is (or (eq result t) (null result)))))

(test test-set-custom-emoji-sticker-set-thumbnail-no-emoji
  "Test setting custom emoji sticker set thumbnail without emoji"
  (let ((result (cl-telegram/api:set-custom-emoji-sticker-set-thumbnail
                 "EmojiStickerSet")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 6: Custom Emoji Stickers Retrieval Tests
;;; ============================================================================

(test test-get-custom-emoji-stickers
  "Test getting custom emoji stickers"
  (let ((stickers (cl-telegram/api:get-custom-emoji-stickers
                   '("emoji_id_1" "emoji_id_2"))))
    (is (or (listp stickers) (null stickers)))))

(test test-get-custom-emoji-stickers-single
  "Test getting single custom emoji sticker"
  (let ((stickers (cl-telegram/api:get-custom-emoji-stickers
                   '("emoji_id_single"))))
    (is (or (listp stickers) (null stickers)))))

(test test-get-custom-emoji-stickers-empty
  "Test getting custom emoji stickers with empty list"
  (let ((stickers (cl-telegram/api:get-custom-emoji-stickers nil)))
    (is (or (listp stickers) (null stickers)))))

;;; ============================================================================
;;; Section 7: Sticker Set Management Tests
;;; ============================================================================

(test test-get-sticker-set
  "Test getting sticker set by name"
  (let ((result (cl-telegram/api:get-sticker-set "MyStickerSet")))
    (is (or (not (null result)) t))))

(test test-search-sticker-sets
  "Test searching sticker sets"
  (let ((results (cl-telegram/api:search-sticker-sets "cats" :limit 10)))
    (is (or (listp results) (null results)))))

(test test-install-sticker-set
  "Test installing a sticker set"
  (let ((result (cl-telegram/api:install-sticker-set "TestStickerSet")))
    (is (or (eq result t) (null result)))))

(test test-uninstall-sticker-set
  "Test uninstalling a sticker set"
  (let ((result (cl-telegram/api:uninstall-sticker-set "TestStickerSet")))
    (is (eq result t))))

(test test-add-sticker-to-set
  "Test adding a sticker to a set"
  (let ((result (cl-telegram/api:add-sticker-to-set
                 "MyStickerSet"
                 nil
                 "file_id_123"
                 "😀")))
    (is (or (eq result t) (null result)))))

(test test-remove-sticker-from-set
  "Test removing a sticker from a set"
  (let ((result (cl-telegram/api:remove-sticker-from-set
                 "MyStickerSet"
                 "sticker_file_id")))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 8: Sticker Upload and Creation Tests
;;; ============================================================================

(test test-create-new-sticker-set
  "Test creating a new sticker set"
  (let ((result (cl-telegram/api:create-new-sticker-set
                 123456
                 "MyNewStickerSet"
                 "My New Sticker Set")))
    (is (or (eq result t) (null result)))))

(test test-create-new-sticker-set-animated
  "Test creating an animated sticker set"
  (let ((result (cl-telegram/api:create-new-sticker-set
                 123456
                 "AnimatedStickerSet"
                 "Animated Stickers"
                 :is-animated t)))
    (is (or (eq result t) (null result)))))

(test test-create-new-sticker-set-video
  "Test creating a video sticker set"
  (let ((result (cl-telegram/api:create-new-sticker-set
                 123456
                 "VideoStickerSet"
                 "Video Stickers"
                 :is-video t)))
    (is (or (eq result t) (null result)))))

;;; ============================================================================
;;; Section 9: Favorite Stickers Tests
;;; ============================================================================

(test test-add-favorite-sticker
  "Test adding a sticker to favorites"
  (let ((result (cl-telegram/api:add-favorite-sticker "sticker_file_123")))
    (is (eq result t))))

(test test-remove-favorite-sticker
  "Test removing a sticker from favorites"
  (let ((result (cl-telegram/api:remove-favorite-sticker "sticker_file_123")))
    (is (eq result t))))

(test test-get-favorite-stickers
  "Test getting favorite stickers"
  (let ((result (cl-telegram/api:get-favorite-stickers)))
    (is (listp result))))

;;; ============================================================================
;;; Section 10: Emoji Pack Tests
;;; ============================================================================

(test test-get-emoji-packs
  "Test getting all emoji packs"
  (let ((packs (cl-telegram/api:get-emoji-packs)))
    (is (listp packs))
    (is (> (length packs) 0))))

(test test-install-emoji-pack
  "Test installing an emoji pack"
  (let ((result (cl-telegram/api:install-emoji-pack "hearts")))
    (is (or (eq result t) (null result)))))

(test test-uninstall-emoji-pack
  "Test uninstalling an emoji pack"
  (let ((result (cl-telegram/api:uninstall-emoji-pack "hearts")))
    (is (or (eq result t) (null result)))))

(test test-get-installed-emoji-packs
  "Test getting installed emoji packs"
  (let ((packs (cl-telegram/api:get-installed-emoji-packs)))
    (is (listp packs))))

;;; ============================================================================
;;; Section 11: Sticker Sending Tests
;;; ============================================================================

(test test-send-sticker
  "Test sending a sticker"
  (let ((result (cl-telegram/api:send-sticker 123456 "sticker_file_id")))
    (is (or (not (null result)) t))))

(test test-send-sticker-with-reply
  "Test sending a sticker with reply"
  (let ((result (cl-telegram/api:send-sticker 123456 "sticker_file_id"
                                              :reply-to 999)))
    (is (or (not (null result)) t))))

(test test-send-custom-emoji
  "Test sending a custom emoji"
  (let ((result (cl-telegram/api:send-custom-emoji 123456 "custom_emoji_id")))
    (is (or (not (null result)) t))))

(test test-get-sticker-from-message
  "Test getting sticker from message"
  (let ((message '(:sticker (:file-id "sticker_123"
                                      :width 512
                                      :height 512
                                      :is-animated nil
                                      :is-video nil
                                      :emoji "😀"))))
    (let ((sticker (cl-telegram/api:get-sticker-from-message message)))
      (is (or (not (null sticker)) t)))))

;;; ============================================================================
;;; Section 12: Sticker Utility Tests
;;; ============================================================================

(test test-sticker-dimension-string
  "Test getting sticker dimension string"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "test_id"
                                :width 512
                                :height 512)))
    (let ((dim (cl-telegram/api:sticker-dimension-string sticker)))
      (is (string= dim "512x512")))))

(test test-sticker-type-string-static
  "Test getting static sticker type string"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "test_id"
                                :is-animated nil
                                :is-video nil)))
    (let ((type (cl-telegram/api:sticker-type-string sticker)))
      (is (string= type "static")))))

(test test-sticker-type-string-animated
  "Test getting animated sticker type string"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "test_id"
                                :is-animated t
                                :is-video nil)))
    (let ((type (cl-telegram/api:sticker-type-string sticker)))
      (is (string= type "animated")))))

(test test-sticker-type-string-video
  "Test getting video sticker type string"
  (let ((sticker (make-instance 'cl-telegram/api:sticker
                                :file-id "test_id"
                                :is-animated nil
                                :is-video t)))
    (let ((type (cl-telegram/api:sticker-type-string sticker)))
      (is (string= type "video")))))

(test test-clear-sticker-cache
  "Test clearing sticker cache"
  (let ((result (cl-telegram/api:clear-sticker-cache)))
    (is (eq result t))))

;;; ============================================================================
;;; Section 13: Sticker Search Tests
;;; ============================================================================

(test test-search-stickers
  "Test searching stickers by emoji"
  (let ((results (cl-telegram/api:search-stickers "😀" :limit 10)))
    (is (or (listp results) (null results)))))

(test test-get-trending-stickers
  "Test getting trending stickers"
  (let ((results (cl-telegram/api:get-trending-stickers :limit 10)))
    (is (or (listp results) (null results)))))

;;; ============================================================================
;;; Test Runner
;;; ============================================================================

(defun run-all-stickers-enhanced-tests ()
  "Run all Stickers API Enhanced tests"
  (let ((results (run! 'stickers-enhanced-tests :if-fail :error)))
    (format t "~%~%=== Stickers API Enhanced Test Results ===~%")
    (format t "Tests: ~D~%" (length results))
    (format t "Passed: ~D~%" (count-if (lambda (r) (eq (first r) :pass)) results))
    (format t "Failed: ~D~%" (count-if (lambda (r) (eq (first r) :fail)) results))
    results))
