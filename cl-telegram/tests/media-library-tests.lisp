;;; media-library-tests.lisp --- Tests for media library functionality

(in-package #:cl-telegram/tests)

(defsuite* media-library-suite ())

;;; ============================================================================
;;; Test Utilities
;;; ============================================================================

(defmacro with-media-manager ((&optional) &body body)
  "Execute body with media manager initialized."
  `(progn
     (setf cl-telegram/api::*media-manager* nil)
     (cl-telegram/api:init-media-manager)
     (unwind-protect
          (progn ,@body)
       (setf cl-telegram/api::*media-manager* nil))))

;;; ============================================================================
;;; Media Item Class Tests
;;; ============================================================================

(deftest test-media-item-creation ()
  "Test creating a media-item instance."
  (let ((media (make-instance 'cl-telegram/api:media-item
                              :id 12345
                              :chat-id 100
                              :message-id 200
                              :type :photo
                              :file-name "test.jpg"
                              :file-size 1024
                              :mime-type "image/jpeg"
                              :width 800
                              :height 600)))
    (is (typep media 'cl-telegram/api:media-item))
    (is (= (cl-telegram/api:media-id media) 12345))
    (is (= (cl-telegram/api:media-chat-id media) 100))
    (is (= (cl-telegram/api:media-message-id media) 200))
    (is (eq (cl-telegram/api:media-type media) :photo))
    (is (string= (cl-telegram/api:media-file-name media) "test.jpg"))
    (is (= (cl-telegram/api:media-file-size media) 1024))
    (is (= (cl-telegram/api:media-width media) 800))
    (is (= (cl-telegram/api:media-height media) 600))))

(deftest test-media-item-with-all-fields ()
  "Test media-item with all optional fields."
  (let ((media (make-instance 'cl-telegram/api:media-item
                              :id 99999
                              :chat-id 100
                              :message-id 200
                              :type :video
                              :file-name "video.mp4"
                              :file-size 2048576
                              :mime-type "video/mp4"
                              :width 1920
                              :height 1080
                              :duration 120
                              :date 1700000000
                              :caption "Test video caption")))
    (is (= (cl-telegram/api:media-duration media) 120))
    (is (= (cl-telegram/api:media-date media) 1700000000))
    (is (string= (cl-telegram/api:media-caption media) "Test video caption"))))

;;; ============================================================================
;;; Media Manager Tests
;;; ============================================================================

(deftest test-media-manager-initialization ()
  "Test media manager initialization."
  (with-media-manager ()
    (let ((manager (cl-telegram/api:get-media-manager)))
      (is (typep manager 'cl-telegram/api:media-manager))
      (is (typep (cl-telegram/api:media-manager-media manager) 'hash-table))
      (is (typep (cl-telegram/api:media-manager-cache manager) 'hash-table)))))

(deftest test-get-media-manager ()
  "Test get-media-manager auto-initialization."
  (setf cl-telegram/api::*media-manager* nil)
  (let ((manager (cl-telegram/api:get-media-manager)))
    (is (typep manager 'cl-telegram/api:media-manager))
    (is (not (null cl-telegram/api::*media-manager*)))))

;;; ============================================================================
;;; Media Retrieval Tests
;;; ============================================================================

(deftest test-get-all-photos ()
  "Test retrieving all photos."
  (with-media-manager ()
    (let ((photos (cl-telegram/api:get-all-photos :limit 50)))
      (is (listp photos))
      (is (null photos)))))  ; Empty when no media exists

(deftest test-get-all-videos ()
  "Test retrieving all videos."
  (with-media-manager ()
    (let ((videos (cl-telegram/api:get-all-videos :limit 50)))
      (is (listp videos))
      (is (null videos)))))

(deftest test-get-all-documents ()
  "Test retrieving all documents."
  (with-media-manager ()
    (let ((docs (cl-telegram/api:get-all-documents :limit 50)))
      (is (listp docs))
      (is (null docs)))))

(deftest test-get-all-audio ()
  "Test retrieving all audio files."
  (with-media-manager ()
    (let ((audio (cl-telegram/api:get-all-audio :limit 50)))
      (is (listp audio))
      (is (null audio)))))

(deftest test-get-all-files ()
  "Test retrieving all files."
  (with-media-manager ()
    (let ((files (cl-telegram/api:get-all-files :limit 100)))
      (is (listp files))
      (is (null files)))))

(deftest test-get-chat-media ()
  "Test retrieving media from specific chat."
  (with-media-manager ()
    (let ((media (cl-telegram/api:get-chat-media :chat-id 123456 :type :photo :limit 20)))
      (is (listp media))
      (is (null media)))))

;;; ============================================================================
;;; Media Search Tests
;;; ============================================================================

(deftest test-search-files ()
  "Test searching files by name."
  (with-media-manager ()
    (let ((results (cl-telegram/api:search-files "test" :type :document :limit 20)))
      (is (listp results))
      (is (null results)))))

(deftest test-search-files-by-type ()
  "Test searching files by type."
  (with-media-manager ()
    (let ((pdfs (cl-telegram/api:search-files ".pdf" :type :document :limit 20)))
      (is (listp pdfs))
      (is (null pdfs)))))

;;; ============================================================================
;;; Media Filtering and Sorting Tests
;;; ============================================================================

(deftest test-filter-media-by-chat ()
  "Test filtering media by chat."
  (with-media-manager ()
    (let ((media-list (list (make-instance 'cl-telegram/api:media-item
                                           :id 1 :chat-id 100 :message-id 1 :type :photo)
                            (make-instance 'cl-telegram/api:media-item
                                           :id 2 :chat-id 200 :message-id 2 :type :photo)))
          (filtered (cl-telegram/api:filter-media-by-chat media-list 100)))
      (is (= (length filtered) 1))
      (is (= (cl-telegram/api:media-chat-id (first filtered)) 100)))))

(deftest test-sort-media-by-date ()
  "Test sorting media by date."
  (let ((media-list (list (make-instance 'cl-telegram/api:media-item
                                         :id 1 :chat-id 100 :message-id 1 :type :photo
                                         :date 1700200000)
                          (make-instance 'cl-telegram/api:media-item
                                         :id 2 :chat-id 100 :message-id 2 :type :photo
                                         :date 1700100000)
                          (make-instance 'cl-telegram/api:media-item
                                         :id 3 :chat-id 100 :message-id 3 :type :photo
                                         :date 1700300000))))
    (let ((sorted (cl-telegram/api:sort-media-by-date media-list :descending nil)))
      (is (= (cl-telegram/api:media-date (first sorted)) 1700100000))
      (is (= (cl-telegram/api:media-date (car (last sorted))) 1700300000)))))

(deftest test-group-media-by-month ()
  "Test grouping media by month."
  (let ((media-list (list (make-instance 'cl-telegram/api:media-item
                                         :id 1 :chat-id 100 :message-id 1 :type :photo
                                         :date 1704067200)  ; 2024-01-01
                          (make-instance 'cl-telegram/api:media-item
                                         :id 2 :chat-id 100 :message-id 2 :type :photo
                                         :date 1704067200)  ; 2024-01-01
                          (make-instance 'cl-telegram/api:media-item
                                         :id 3 :chat-id 100 :message-id 3 :type :photo
                                         :date 1706745600))))  ; 2024-02-01
    (let ((grouped (cl-telegram/api:group-media-by-month media-list)))
      (is (>= (length grouped) 1)))))

;;; ============================================================================
;;; Batch Operations Tests
;;; ============================================================================

(deftest test-download-media-batch ()
  "Test batch media download."
  (with-media-manager ()
    ;; Mock test - actual download requires real media
    (let ((result (cl-telegram/api:download-media-batch '(1 2 3) "/tmp/media")))
      (is (typep result '(or null cons))))))

(deftest test-delete-media-batch ()
  "Test batch media deletion."
  (with-media-manager ()
    (let ((deleted (cl-telegram/api:delete-media-batch '(1 2 3))))
      (is (typep deleted '(or boolean null)))))

;;; ============================================================================
;;; Statistics Tests
;;; ============================================================================

(deftest test-get-media-statistics ()
  "Test getting media statistics."
  (with-media-manager ()
    (let ((stats (cl-telegram/api:get-media-statistics)))
      (is (listp stats))
      (is (getf stats :total-photos))
      (is (getf stats :total-videos))
      (is (getf stats :total-documents))
      (is (getf stats :total-audio)))))

(deftest test-get-media-usage-by-chat ()
  "Test getting media usage by chat."
  (with-media-manager ()
    (let ((usage (cl-telegram/api:get-media-usage-by-chat :limit 10)))
      (is (listp usage))
      (is (null usage)))))

(deftest test-get-media-usage-by-type ()
  "Test getting media usage by type."
  (with-media-manager ()
    (let ((usage (cl-telegram/api:get-media-usage-by-type)))
      (is (listp usage))
      (is (getf usage :photo))
      (is (getf usage :video))
      (is (getf usage :document))
      (is (getf usage :audio)))))

;;; ============================================================================
;;; Individual Media Item Tests
;;; ============================================================================

(deftest test-get-media-item ()
  "Test getting individual media item."
  (with-media-manager ()
    (let ((item (cl-telegram/api:get-media-item 12345)))
      (is (null item)))))  ; Returns nil when not found

;;; ============================================================================
;;; Cache Management Tests
;;; ============================================================================

(deftest test-get-media-cache-stats ()
  "Test getting media cache statistics."
  (with-media-manager ()
    (let ((stats (cl-telegram/api:get-media-cache-stats)))
      (is (listp stats))
      (is (getf stats :cache_size))
      (is (getf stats :cache_hits))
      (is (getf stats :cache_misses)))))

(deftest test-clear-media-cache ()
  "Test clearing media cache."
  (with-media-manager ()
    (let ((manager (cl-telegram/api:get-media-manager)))
      ;; Add something to cache
      (setf (gethash "test" (cl-telegram/api:media-manager-cache manager)) 'result)
      (is (not (null (gethash "test" (cl-telegram/api:media-manager-cache manager)))))
      ;; Clear cache
      (cl-telegram/api:clear-media-cache)
      (is (null (gethash "test" (cl-telegram/api:media-manager-cache manager)))))))

(deftest test-set-media-cache-ttl ()
  "Test setting media cache TTL."
  (with-media-manager ()
    (is (cl-telegram/api:set-media-cache-ttl 600))
    (let ((manager (cl-telegram/api:get-media-manager)))
      (is (= (cl-telegram/api:media-manager-ttl manager) 600)))))

;;; ============================================================================
;;; Utility Function Tests
;;; ============================================================================

(deftest test-detect-media-type ()
  "Test media type detection from filename."
  (is (eq (cl-telegram/api:detect-media-type "photo.jpg") :photo))
  (is (eq (cl-telegram/api:detect-media-type "image.png") :photo))
  (is (eq (cl-telegram/api:detect-media-type "video.mp4") :video))
  (is (eq (cl-telegram/api:detect-media-type "document.pdf") :document))
  (is (eq (cl-telegram/api:detect-media-type "audio.mp3") :audio)))

(deftest test-get-file-extension ()
  "Test getting file extension."
  (is (string= (cl-telegram/api:get-file-extension "file.jpg") "jpg"))
  (is (string= (cl-telegram/api:get-file-extension "archive.tar.gz") "gz"))
  (is (null (cl-telegram/api:get-file-extension "noextension"))))

(deftest test-export-media-list ()
  "Test exporting media list to JSON."
  (with-media-manager ()
    (let ((media-list (list (make-instance 'cl-telegram/api:media-item
                                           :id 1 :chat-id 100 :message-id 1 :type :photo
                                           :file-name "test.jpg" :file-size 1024)))
          (json (cl-telegram/api:export-media-list media-list "/tmp/media-export.json")))
      (is (typep json '(or null cons))))))

;;; ============================================================================
;;; Edge Case Tests
;;; ============================================================================

(deftest test-get-all-media-with-zero-limit ()
  "Test get-all-media with zero limit."
  (with-media-manager ()
    (let ((media (cl-telegram/api:get-all-media :limit 0)))
      (is (listp media))
      (is (null media)))))

(deftest test-get-all-media-with-negative-limit ()
  "Test get-all-media with negative limit."
  (with-media-manager ()
    (let ((media (cl-telegram/api:get-all-media :limit -10)))
      (is (listp media))
      (is (<= (length media) 100)))))

(deftest test-get-chat-media-with-invalid-chat ()
  "Test get-chat-media with invalid chat ID."
  (with-media-manager ()
    (let ((media (cl-telegram/api:get-chat-media :chat-id -1 :type :photo)))
      (is (listp media))
      (is (null media)))))

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-all-media-library-tests ()
  "Run all media library tests."
  (run! 'media-library-suite))
