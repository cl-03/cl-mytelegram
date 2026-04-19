;;; media-editing-tests.lisp --- Tests for multimedia editing features
;;;
;;; Tests for message editing, media processing, and overlay functions

(in-package #:cl-telegram/tests)

;;; ### Edit Message Text Tests

(deftest test-edit-message-text-signature
  "Test edit-message-text function exists"
  (is (fboundp 'cl-telegram/api:edit-message-text)))

(deftest test-edit-message-caption-signature
  "Test edit-message-caption function exists"
  (is (fboundp 'cl-telegram/api:edit-message-caption)))

(deftest test-edit-message-media-signature
  "Test edit-message-media function exists"
  (is (fboundp 'cl-telegram/api:edit-message-media)))

(deftest test-edit-message-reply-markup-signature
  "Test edit-message-reply-markup function exists"
  (is (fboundp 'cl-telegram/api:edit-message-reply-markup)))

(deftest test-edit-message-live-location-signature
  "Test edit-message-live-location function exists"
  (is (fboundp 'cl-telegram/api:edit-message-live-location)))

(deftest test-stop-message-live-location-signature
  "Test stop-message-live-location function exists"
  (is (fboundp 'cl-telegram/api:stop-message-live-location)))

;;; ### Media Processing Tests

(deftest test-crop-media-signature
  "Test crop-media function exists"
  (is (fboundp 'cl-telegram/api:crop-media)))

(deftest test-rotate-media-signature
  "Test rotate-media function exists"
  (is (fboundp 'cl-telegram/api:rotate-media)))

(deftest test-apply-filter-signature
  "Test apply-filter function exists"
  (is (fboundp 'cl-telegram/api:apply-filter)))

(deftest test-generate-thumbnail-signature
  "Test generate-thumbnail function exists"
  (is (fboundp 'cl-telegram/api:generate-thumbnail)))

(deftest test-add-text-overlay-signature
  "Test add-text-overlay function exists"
  (is (fboundp 'cl-telegram/api:add-text-overlay)))

(deftest test-add-emoji-sticker-signature
  "Test add-emoji-sticker function exists"
  (is (fboundp 'cl-telegram/api:add-emoji-sticker)))

;;; ### Helper Function Tests

(deftest test-make-input-media-photo
  "Test make-input-media-photo creates correct structure"
  (let ((media (cl-telegram/api:make-input-media-photo
                :media "file_id_123"
                :caption "Test caption"
                :has-spoiler t)))
    (is (listp media))
    (is (eq (getf media :@type) :inputMediaPhoto))
    (is (string= (getf media :media) "file_id_123"))
    (is (string= (getf media :caption) "Test caption"))
    (is (getf media :has_spoiler))))

(deftest test-make-input-media-video
  "Test make-input-media-video creates correct structure"
  (let ((media (cl-telegram/api:make-input-media-video
                :media "video_id"
                :duration 60
                :width 1920
                :height 1080
                :supports-streaming t)))
    (is (listp media))
    (is (eq (getf media :@type) :inputMediaVideo))
    (is (= (getf media :duration) 60))
    (is (= (getf media :width) 1920))
    (is (= (getf media :height) 1080))))

(deftest test-make-input-media-audio
  "Test make-input-media-audio creates correct structure"
  (let ((media (cl-telegram/api:make-input-media-audio
                :media "audio_id"
                :performer "Artist"
                :title "Song Title"
                :duration 180)))
    (is (listp media))
    (is (eq (getf media :@type) :inputMediaAudio))
    (is (string= (getf media :performer) "Artist"))
    (is (string= (getf media :title) "Song Title"))))

(deftest test-make-input-media-document
  "Test make-input-media-document creates correct structure"
  (let ((media (cl-telegram/api:make-input-media-document
                :media "doc_id"
                :caption "Document caption")))
    (is (listp media))
    (is (eq (getf media :@type) :inputMediaDocument))
    (is (string= (getf media :caption) "Document caption"))))

(deftest test-make-input-media-animation
  "Test make-input-media-animation creates correct structure"
  (let ((media (cl-telegram/api:make-input-media-animation
                :media "gif_id"
                :duration 5
                :has-spoiler t)))
    (is (listp media))
    (is (eq (getf media :@type) :inputMediaAnimation))
    (is (= (getf media :duration) 5))
    (is (getf media :has_spoiler))))

;;; ### Media Processing Function Tests

(deftest test-crop-media-returns-params
  "Test crop-media returns crop parameters"
  (multiple-value-bind (result error)
      (cl-telegram/api:crop-media "file_id" :x 10 :y 20 :width 100 :height 100)
    (is (null error))
    (is (listp result))
    (is (getf result :media))
    (is (getf result :crop))))

(deftest test-rotate-media-returns-params
  "Test rotate-media returns rotation parameters"
  (dolist (degrees '(90 180 270))
    (multiple-value-bind (result error)
        (cl-telegram/api:rotate-media "file_id" :degrees degrees)
      (is (null error))
      (is (getf result :rotation)))))

(deftest test-apply-filter-returns-params
  "Test apply-filter returns filter parameters"
  (let ((filters '(:grayscale :sepia :vintage :dramatic :vivid)))
    (dolist (filter filters)
      (multiple-value-bind (result error)
          (cl-telegram/api:apply-filter "file_id" filter :intensity 0.8)
        (is (null error))
        (is (getf result :filter))
        (is (eq (getf result :filter) filter))))))

(deftest test-generate-thumbnail-returns-params
  "Test generate-thumbnail returns thumbnail parameters"
  (multiple-value-bind (result error)
      (cl-telegram/api:generate-thumbnail "file_id" :size 320 :format :jpeg)
    (is (null error))
    (is (listp result))
    (is (eq (getf result :type) :thumbnail))))

(deftest test-add-text-overlay-returns-params
  "Test add-text-overlay returns overlay parameters"
  (multiple-value-bind (result error)
      (cl-telegram/api:add-text-overlay "file_id" "Overlay text"
                                        :position :bottom
                                        :size 24
                                        :color :white)
    (is (null error))
    (is (getf result :text_overlay))))

(deftest test-add-emoji-sticker-returns-params
  "Test add-emoji-sticker returns emoji parameters"
  (multiple-value-bind (result error)
      (cl-telegram/api:add-emoji-sticker "file_id" "😀"
                                         :position :top-right
                                         :size 64)
    (is (null error))
    (is (getf result :emoji_overlay))))

;;; ### Edit Checklist Test

(deftest test-edit-message-checklist-signature
  "Test edit-message-checklist function exists"
  (is (fboundp 'cl-telegram/api:edit-message-checklist)))

;;; ### Unified Edit Interface Test

(deftest test-edit-message-signature
  "Test unified edit-message function exists"
  (is (fboundp 'cl-telegram/api:edit-message)))

;;; ### Integration Tests

(deftest test-media-editing-api-existence
  "Test that all media editing API functions exist"
  (let ((functions
         '(cl-telegram/api:edit-message-text
           cl-telegram/api:edit-message-caption
           cl-telegram/api:edit-message-media
           cl-telegram/api:edit-message-reply-markup
           cl-telegram/api:edit-message-live-location
           cl-telegram/api:stop-message-live-location
           cl-telegram/api:crop-media
           cl-telegram/api:rotate-media
           cl-telegram/api:apply-filter
           cl-telegram/api:generate-thumbnail
           cl-telegram/api:add-text-overlay
           cl-telegram/api:add-emoji-sticker
           cl-telegram/api:edit-message-checklist
           cl-telegram/api:edit-message
           cl-telegram/api:make-input-media-photo
           cl-telegram/api:make-input-media-video
           cl-telegram/api:make-input-media-audio
           cl-telegram/api:make-input-media-document
           cl-telegram/api:make-input-media-animation)))
    (dolist (fn functions)
      (is (fboundp fn) (format nil "Function ~A should exist" fn)))))

;;; ### Test Runner

(defun run-media-editing-tests ()
  "Run all media editing tests.

   Returns:
     T if all tests pass"
  (format t "~%Running Media Editing Tests...~%")
  (let ((results (list
                  (fiveam:run! 'test-edit-message-text-signature)
                  (fiveam:run! 'test-edit-message-caption-signature)
                  (fiveam:run! 'test-edit-message-media-signature)
                  (fiveam:run! 'test-edit-message-reply-markup-signature)
                  (fiveam:run! 'test-edit-message-live-location-signature)
                  (fiveam:run! 'test-stop-message-live-location-signature)
                  (fiveam:run! 'test-crop-media-signature)
                  (fiveam:run! 'test-rotate-media-signature)
                  (fiveam:run! 'test-apply-filter-signature)
                  (fiveam:run! 'test-generate-thumbnail-signature)
                  (fiveam:run! 'test-add-text-overlay-signature)
                  (fiveam:run! 'test-add-emoji-sticker-signature)
                  (fiveam:run! 'test-make-input-media-photo)
                  (fiveam:run! 'test-make-input-media-video)
                  (fiveam:run! 'test-make-input-media-audio)
                  (fiveam:run! 'test-make-input-media-document)
                  (fiveam:run! 'test-make-input-media-animation)
                  (fiveam:run! 'test-crop-media-returns-params)
                  (fiveam:run! 'test-rotate-media-returns-params)
                  (fiveam:run! 'test-apply-filter-returns-params)
                  (fiveam:run! 'test-generate-thumbnail-returns-params)
                  (fiveam:run! 'test-add-text-overlay-returns-params)
                  (fiveam:run! 'test-add-emoji-sticker-returns-params)
                  (fiveam:run! 'test-edit-message-checklist-signature)
                  (fiveam:run! 'test-edit-message-signature)
                  (fiveam:run! 'test-media-editing-api-existence))))
    (if (every #'identity results)
        (progn
          (format t "All tests passed!~%")
          t)
        (progn
          (format t "Some tests failed!~%")
          nil))))
