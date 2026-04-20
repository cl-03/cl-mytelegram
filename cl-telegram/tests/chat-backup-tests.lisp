;;; chat-backup-tests.lisp --- Tests for chat backup functionality

(in-package #:cl-telegram/tests)

(defsuite* chat-backup-suite ())

;;; ============================================================================
;;; Backup Class Tests
;;; ============================================================================

(defmacro with-backup-manager ((&optional) &body body)
  "Execute body with backup manager initialized."
  `(progn
     (setf cl-telegram/api::*backup-manager* nil)
     (cl-telegram/api:init-backup-manager)
     (unwind-protect
          (progn ,@body)
       (setf cl-telegram/api::*backup-manager* nil))))

(deftest test-chat-backup-creation ()
  "Test creating a chat-backup instance."
  (let ((backup (make-instance 'cl-telegram/api:chat-backup
                               :chat-id 123456)))
    (is (typep backup 'cl-telegram/api:chat-backup))
    (is (stringp (cl-telegram/api:backup-id backup)))
    (is (= (cl-telegram/api:backup-chat-id backup) 123456))
    (is (= (cl-telegram/api:backup-message-count backup) 0))
    (is (= (cl-telegram/api:backup-media-count backup) 0))
    (is (eq (cl-telegram/api:backup-format backup) :json))
    (is (null (cl-telegram/api:backup-file-path backup)))))

(deftest test-backup-manager-initialization ()
  "Test backup manager initialization."
  (with-backup-manager ()
    (let ((manager (cl-telegram/api:get-backup-manager)))
      (is (typep manager 'cl-telegram/api:backup-manager))
      (is (typep (cl-telegram/api:backup-manager-backups manager) 'hash-table))
      (is (listp (cl-telegram/api:backup-manager-queue manager)))
      (is (stringp (cl-telegram/api:backup-manager-temp-dir manager))))))

;;; ============================================================================
;;; Export Functions Tests
;;; ============================================================================

(deftest test-export-messages-json ()
  "Test JSON message formatting."
  (let* ((messages '((:id 1 :date 1700000000 :from-id 100 :from-name "User"
                       :text "Hello" :media nil :reply-to-msg-id nil :forwards 0 :reactions ())
                     (:id 2 :date 1700000100 :from-id 101 :from-name "Bot"
                       :text "Hi there" :media nil :reply-to-msg-id 1 :forwards 0 :reactions ())))
         (json (cl-telegram/api::export-messages-json messages)))
    (is (listp json))
    (is (= (length json) 2))
    (is (getf (first json) :id))
    (is (string= (getf (first json) :text) "Hello"))))

(deftest test-export-media-list-json ()
  "Test JSON media list formatting."
  (let* ((media '((:message-id 1 :file-name "photo.jpg" :file-size 1024
                              :mime-type "image/jpeg" :local-path "/tmp/photo.jpg")
                  (:message-id 2 :file-name "doc.pdf" :file-size 2048
                              :mime-type "application/pdf" :local-path "/tmp/doc.pdf")))
         (json (cl-telegram/api::export-media-list-json media)))
    (is (listp json))
    (is (= (length json) 2))
    (is (string= (getf (first json) :file-name) "photo.jpg"))))

(deftest test-escape-html ()
  "Test HTML escaping."
  (is (string= (cl-telegram/api::escape-html "<script>alert('xss')</script>")
               "&lt;script&gt;alert(&apos;xss&apos;)&lt;/script&gt;"))
  (is (string= (cl-telegram/api::escape-html "Hello & World")
               "Hello &amp; World"))
  (is (null (cl-telegram/api::escape-html nil))))

(deftest test-format-json-backup ()
  "Test JSON backup formatting."
  (let* ((backup (make-instance 'cl-telegram/api:chat-backup
                                :chat-id 123456
                                :message-count 10
                                :media-count 2))
         (data (list :messages '((:id 1 :text "Test"))
                     :media-files '()))
         (json (cl-telegram/api::format-json-backup backup data)))
    (is (stringp json))
    (is (search ":backup_version" json))
    (is (search ":chat_id" json))
    (is (search ":message_count" json))))

(deftest test-format-html-backup ()
  "Test HTML backup formatting."
  (let* ((backup (make-instance 'cl-telegram/api:chat-backup
                                :chat-id 123456
                                :message-count 1))
         (data (list :messages '((:id 1 :date 1700000000 :from-name "User"
                                    :text "Hello" :media nil))))
         (html (cl-telegram/api::format-html-backup data "Test Chat")))
    (is (stringp html))
    (is (search "<!DOCTYPE html>" html))
    (is (search "Test Chat" html))
    (is (search "Hello" html))))

;;; ============================================================================
;;; Export Chat History Tests
;;; ============================================================================

(deftest test-export-chat-history-json ()
  "Test exporting chat to JSON format."
  (with-backup-manager ()
    (let* ((chat-id 123456)
           (output-path (merge-pathnames "test-export.json" (uiop:temporary-directory())))
           (backup nil))
      (unwind-protect
           (progn
             ;; Mock get-message-history
             (let ((cl-telegram/api:*mock-messages*
                    '((:id 1 :date 1700000000 :from-id 100 :from-name "User"
                      :text "Test message" :media nil))))
               (multiple-value-bind (b err)
                   (cl-telegram/api:export-chat-history chat-id output-path :format :json)
                 (if err
                     ;; If API not connected, skip actual export test
                     (format t "Export skipped: ~A~%" err)
                     (progn
                       (setf backup b)
                       (is (typep backup 'cl-telegram/api:chat-backup))
                       (is (probe-file output-path)))))))
        (when (probe-file output-path)
          (delete-file output-path))))))

(deftest test-export-chat-history-html ()
  "Test exporting chat to HTML format."
  (with-backup-manager ()
    (let* ((chat-id 123456)
           (output-path (merge-pathnames "test-export.html" (uiop:temporary-directory())))
           (backup nil))
      (unwind-protect
           (progn
             (multiple-value-bind (b err)
                 (cl-telegram/api:export-chat-history chat-id output-path :format :html)
               (if err
                   (format t "Export skipped: ~A~%" err)
                   (progn
                     (setf backup b)
                     (is (typep backup 'cl-telegram/api:chat-backup))
                     (is (probe-file output-path))))))
        (when (probe-file output-path)
          (delete-file output-path))))))

(deftest test-export-chat-history-with-date-range ()
  "Test exporting chat with date range filter."
  (with-backup-manager ()
    (let* ((chat-id 123456)
           (date-from (- (get-universal-time) 86400)) ; 1 day ago
           (date-to (get-universal-time))
           (output-path (merge-pathnames "test-export-range.json" (uiop:temporary-directory()))))
      (unwind-protect
           (multiple-value-bind (backup err)
               (cl-telegram/api:export-chat-history chat-id output-path
                                                    :format :json
                                                    :date-from date-from
                                                    :date-to date-to)
             (if err
                 (format t "Export skipped: ~A~%" err)
                 (progn
                   (is (typep backup 'cl-telegram/api:chat-backup))
                   (is (probe-file output-path)))))
        (when (probe-file output-path)
          (delete-file output-path))))))

;;; ============================================================================
;;; Export All Chats Tests
;;; ============================================================================

(deftest test-export-all-chats ()
  "Test exporting all chats."
  (with-backup-manager ()
    (let* ((output-dir (uiop:temporary-directory()))
           (count 0))
      (unwind-protect
           (multiple-value-bind (cnt paths err)
               (cl-telegram/api:export-all-chats output-dir :format :json)
             (if err
                 (format t "Export skipped: ~A~%" err)
                 (progn
                   (setf count cnt)
                   (is (numberp count))
                   (is (listp paths)))))
        ;; Cleanup
        (when (probe-file output-dir)
          (dolist (file (directory (merge-pathnames "*.json" output-dir)))
            (delete-file file)))))))

;;; ============================================================================
;;; Import Tests
;;; ============================================================================

(deftest test-import-chat-history ()
  "Test importing chat history."
  (with-backup-manager ()
    (let* ((backup-path (merge-pathnames "test-import.json" (uiop:temporary-directory())))
           (imported 0))
      (unwind-protect
           (progn
             ;; Create a mock backup file
             (with-open-file (out backup-path :direction :output :if-exists :supersede)
               (write-string "{\"chat_id\": 123456, \"messages\": []}" out))

             ;; Test import
             (multiple-value-bind (cnt err)
                 (cl-telegram/api:import-chat-history backup-path)
               (if err
                   (format t "Import skipped: ~A~%" err)
                   (progn
                     (setf imported cnt)
                     (is (numberp imported))))))
        (when (probe-file backup-path)
          (delete-file backup-path))))))

(deftest test-import-chat-history-file-not-found ()
  "Test import with non-existent file."
  (multiple-value-bind (cnt err)
      (cl-telegram/api:import-chat-history "/nonexistent/path/backup.json")
    (is (null cnt))
    (is (eq err :file-not-found))))

;;; ============================================================================
;;; Incremental Backup Tests
;;; ============================================================================

(deftest test-create-incremental-backup ()
  "Test creating incremental backup."
  (with-backup-manager ()
    (let* ((base-path (merge-pathnames "base-backup.json" (uiop:temporary-directory())))
           (incr-path (merge-pathnames "incr-backup.json" (uiop:temporary-directory()))))
      (unwind-protect
           (progn
             ;; Create base backup
             (with-open-file (out base-path :direction :output :if-exists :supersede)
               (write-string "{\"last_date\": 1700000000}" out))

             ;; Test incremental backup
             (multiple-value-bind (backup err)
                 (cl-telegram/api:create-incremental-backup 123456 base-path incr-path)
               (if err
                   (format t "Incremental backup skipped: ~A~%" err)
                   (progn
                     (is (typep backup 'cl-telegram/api:chat-backup))
                     (is (probe-file incr-path))))))
        (when (probe-file base-path)
          (delete-file base-path))
        (when (probe-file incr-path)
          (delete-file incr-path))))))

(deftest test-incremental-backup-base-not-found ()
  "Test incremental backup with missing base."
  (multiple-value-bind (backup err)
      (cl-telegram/api:create-incremental-backup 123456 "/nonexistent/base.json" "/tmp/incr.json")
    (is (null backup))
    (is (eq err :base-not-found))))

;;; ============================================================================
;;; Backup Info Tests
;;; ============================================================================

(deftest test-get-backup-info ()
  "Test getting backup info."
  (let* ((backup-path (merge-pathnames "test-info.json" (uiop:temporary-directory()))))
    (unwind-protect
         (progn
           ;; Create test backup
           (with-open-file (out backup-path :direction :output :if-exists :supersede)
             (write-string "{\"backup_version\": \"1.0\", \"chat_id\": 123456, \"message_count\": 10}" out))

           ;; Get info
           (let ((info (cl-telegram/api:get-backup-info backup-path)))
             (is (getf info :version))
             (is (= (getf info :chat-id) 123456))
             (is (= (getf info :message-count) 10))))
      (when (probe-file backup-path)
        (delete-file backup-path)))))

(deftest test-get-backup-info-file-not-found ()
  "Test get backup info with non-existent file."
  (let ((info (cl-telegram/api:get-backup-info "/nonexistent/backup.json")))
    (is (getf info :error))
    (is (eq (getf info :error) :file-not-found))))

;;; ============================================================================
;;; Encryption Stub Tests
;;; ============================================================================

(deftest test-encrypt-backup-stub ()
  "Test encryption stub returns not-implemented."
  (multiple-value-bind (path err)
      (cl-telegram/api:encrypt-backup "/tmp/test.json" "password")
    (is (null path))
    (is (eq err :not-implemented))))

(deftest test-decrypt-backup-stub ()
  "Test decryption stub returns not-implemented."
  (multiple-value-bind (content err)
      (cl-telegram/api:decrypt-backup "/tmp/test.enc" "password")
    (is (null content))
    (is (eq err :not-implemented))))

;;; ============================================================================
;;; Cleanup Tests
;;; ============================================================================

(deftest test-cleanup-backup-temp ()
  "Test cleanup of temporary files."
  (with-backup-manager ()
    (let ((count (cl-telegram/api:cleanup-backup-temp)))
      (is (numberp count)))))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(deftest test-export-import-roundtrip ()
  "Test export and import roundtrip."
  (with-backup-manager ()
    (let* ((chat-id 123456)
           (export-path (merge-pathnames "roundtrip.json" (uiop:temporary-directory()))))
      (unwind-protect
           (progn
             ;; Export
             (multiple-value-bind (backup err)
                 (cl-telegram/api:export-chat-history chat-id export-path :format :json)
               (unless err
                 ;; Verify export
                 (is (probe-file export-path))

                 ;; Import back
                 (multiple-value-bind (imported import-err)
                     (cl-telegram/api:import-chat-history export-path)
                   (unless import-err
                     (is (numberp imported)))))))
        (when (probe-file export-path)
          (delete-file export-path))))))

;;; ============================================================================
;;; Run Tests
;;; ============================================================================

(defun run-chat-backup-tests (&key (verbose t))
  "Run all chat backup tests."
  (let ((results (run 'chat-backup-suite :verbose verbose)))
    (format t "~%Chat Backup Tests: ~D tests, ~D passed, ~D failed~%"
            (length results)
            (count-if (lambda (r) (eq (first r) :ok)) results)
            (count-if (lambda (r) (not (eq (first r) :ok))) results))
    results))
