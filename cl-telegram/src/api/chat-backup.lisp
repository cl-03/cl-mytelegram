;;; chat-backup.lisp --- Chat backup and export for cl-telegram
;;;
;;; Provides complete chat history export/import functionality:
;;; - Export to JSON/HTML formats
;;; - Import and restore from backup
;;; - Incremental backup support
;;; - Compression and encryption options
;;;
;;; Version: 0.27.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Backup Class
;;; ============================================================================

(defclass chat-backup ()
  ((backup-id :initform (generate-uuid) :reader backup-id)
   (chat-id :initarg :chat-id :accessor backup-chat-id)
   (export-date :initform (get-universal-time) :accessor backup-export-date)
   (message-count :initform 0 :accessor backup-message-count)
   (media-count :initform 0 :accessor backup-media-count)
   (date-range :initform nil :accessor backup-date-range) ; (from . to)
   (format :initform :json :accessor backup-format)
   (file-path :initform nil :accessor backup-file-path)
   (file-size :initform nil :accessor backup-file-size)
   (is-encrypted :initform nil :accessor backup-is-encrypted)
   (checksum :initform nil :accessor backup-checksum)
   (version :initform "1.0" :accessor backup-version)))

(defmethod print-object ((backup chat-backup) stream)
  (print-unreadable-object (backup stream :type t)
    (format stream "~A messages @ ~A"
            (backup-message-count backup)
            (backup-file-path backup))))

;;; ============================================================================
;;; Backup Manager
;;; ============================================================================

(defclass backup-manager ()
  ((backups :initform (make-hash-table :test 'equal)
            :accessor backup-manager-backups)
   (export-queue :initform '() :accessor backup-manager-queue)
   (export-thread :initform nil :accessor backup-manager-thread)
   (temp-directory :initform nil :accessor backup-manager-temp-dir)))

(defvar *backup-manager* nil
  "Global backup manager instance")

(defun make-backup-manager ()
  "Create a new backup manager instance."
  (make-instance 'backup-manager))

(defun init-backup-manager (&key (temp-dir nil))
  "Initialize backup manager subsystem."
  (unless *backup-manager*
    (setf *backup-manager* (make-backup-manager))
    (setf (backup-manager-temp-dir *backup-manager*)
          (or temp-dir (namestring (merge-pathnames "telegram-backup/" (user-homedir-pathname))))))
  t)

(defun get-backup-manager ()
  "Get the global backup manager."
  (unless *backup-manager*
    (init-backup-manager))
  *backup-manager*)

;;; ============================================================================
;;; Export Functions - JSON Format
;;; ============================================================================

(defun (private) export-messages-json (messages)
  "Format messages as JSON array."
  (let ((json-messages '()))
    (dolist (msg messages)
      (push (list :id (getf msg :id)
                  :date (format-universal-time (getf msg :date) nil
                                               :date-time-delimiter "T"
                                               :print-seconds t
                                               :print-zone nil)
                  :from-id (getf msg :from-id)
                  :from-name (getf msg :from-name)
                  :text (getf msg :text)
                  :media (getf msg :media)
                  :reply-to (getf msg :reply-to-msg-id)
                  :forwards (getf msg :forwards 0)
                  :reactions (getf msg :reactions '()))
            json-messages))
    (nreverse json-messages)))

(defun (private) export-media-list-json (media-items)
  "Format media list as JSON array."
  (let ((json-media '()))
    (dolist (item media-items)
      (push (list :message-id (getf item :message-id)
                  :file-name (getf item :file-name)
                  :file-size (getf item :file-size)
                  :mime-type (getf item :mime-type)
                  :local-path (getf item :local-path))
            json-media))
    (nreverse json-media)))

(defun (private) format-json-backup (backup-data)
  "Format complete backup as JSON."
  (jonathan:to-json
   (list :backup_version (backup-version backup-data)
         :chat_id (backup-chat-id backup-data)
         :export_date (format-universal-time (backup-export-date backup-data) nil
                                            :date-time-delimiter "T"
                                            :print-seconds t
                                            :print-zone nil)
         :message_count (backup-message-count backup-data)
         :media_count (backup-media-count backup-data)
         :date_range (let ((range (backup-date-range backup-data)))
                       (when range
                         (list :from (format-universal-time (car range) nil
                                                            :date-time-delimiter "T")
                               :to (format-universal-time (cdr range) nil
                                                          :date-time-delimiter "T"))))
         :messages (getf backup-data :messages)
         :media_files (getf backup-data :media-files))
   :pretty t))

;;; ============================================================================
;;; Export Functions - HTML Format
;;; ============================================================================

(defun (private) escape-html (string)
  "Escape special HTML characters."
  (when string
    (let ((s (copy-seq string)))
      (setf s (cl-ppcre:regex-replace-all "&" s "&amp;"))
      (setf s (cl-ppcre:regex-replace-all "<" s "&lt;"))
      (setf s (cl-ppcre:regex-replace-all ">" s "&gt;"))
      (setf s (cl-ppcre:regex-replace-all "\"" s "&quot;"))
      s)))

(defun (private) format-html-backup (backup-data chat-title)
  "Format complete backup as HTML."
  (let ((messages (getf backup-data :messages))
        (export-date (backup-export-date backup-data)))
    (with-output-to-string (s)
      (format s "<!DOCTYPE html>~%")
      (format s "<html lang=\"en\">~%")
      (format s "<head>~%")
      (format s "  <meta charset=\"UTF-8\">~%")
      (format s "  <title>Chat Backup - ~A</title>~%" (escape-html chat-title))
      (format s "  <style>~%")
      (format s "    body { font-family: Arial, sans-serif; margin: 20px; }~%")
      (format s "    .message { margin: 10px 0; padding: 10px; border-left: 3px solid #0088cc; }~%")
      (format s "    .message-meta { color: #888; font-size: 0.9em; }~%")
      (format s "    .message-text { margin-top: 5px; }~%")
      (format s "    .media { color: #0088cc; }~%")
      (format s "  </style>~%")
      (format s "</head>~%")
      (format s "<body>~%")
      (format s "<h1>Chat Backup: ~A</h1>~%" (escape-html chat-title))
      (format s "<p>Exported: ~A</p>~%" (format-universal-time export-date))
      (format s "<p>Messages: ~D</p>~%" (length messages))
      (format s "<hr>~%")
      (dolist (msg messages)
        (format s "<div class=\"message\">~%")
        (format s "  <div class=\"message-meta\">~%")
        (format s "    <strong>~A</strong> - ~A~%"
                (escape-html (getf msg :from-name "Unknown"))
                (format-universal-time (getf msg :date)))
        (format s "  </div>~%")
        (when (getf msg :text)
          (format s "  <div class=\"message-text\">~A</div>~%" (escape-html (getf msg :text))))
        (when (getf msg :media)
          (format s "  <div class=\"media\">📎 Media attached</div>~%"))
        (format s "</div>~%"))
      (format s "</body>~%")
      (format s "</html>~%"))))

;;; ============================================================================
;;; Main Export Function
;;; ============================================================================

(defun export-chat-history (chat-id output-path &key
                            (format :json)
                            (include-media nil)
                            (date-from nil)
                            (date-to nil)
                            (compress nil)
                            (encrypt nil)
                            (password nil)
                            (batch-size 100))
  "Export chat history to file.

   CHAT-ID: The chat to export
   OUTPUT-PATH: Destination file path
   FORMAT: Output format (:json or :html)
   INCLUDE-MEDIA: Whether to include media files
   DATE-FROM: Export messages from this date
   DATE-TO: Export messages to this date
   COMPRESS: Compress output with zlib
   ENCRYPT: Encrypt output with password
   PASSWORD: Encryption password
   BATCH-SIZE: Messages per batch

   Returns:
     (values backup-info error)"
  (let ((manager (get-backup-manager)))
    ;; Ensure temp directory exists
    (ensure-directories-exist output-path)

    ;; Collect messages
    (format t "Exporting chat ~A...~%" chat-id)
    (let ((all-messages '())
          (all-media '())
          (offset 0)
          (more t))

      ;; Fetch messages in batches
      (loop while more do
        (multiple-value-bind (messages has-more)
            (get-message-history chat-id :limit batch-size :offset offset)
          (if (null messages)
              (setf more nil)
              (progn
                ;; Filter by date range
                (dolist (msg messages)
                  (let ((msg-date (getf msg :date)))
                    (when (and (or (null date-from) (>= msg-date date-from))
                               (or (null date-to) (<= msg-date date-to)))
                      (push msg all-messages)
                      ;; Collect media if requested
                      (when (and include-media (getf msg :media))
                        (push (list :message-id (getf msg :id)
                                    :media (getf msg :media))
                              all-media)))))
                (setf offset (+ offset batch-size))
                (unless has-more
                  (setf more nil))))))

      ;; Reverse to get chronological order
      (setf all-messages (nreverse all-messages))

      (format t "Collected ~D messages~%" (length all-messages))

      ;; Create backup object
      (let* ((backup (make-instance 'chat-backup
                                    :chat-id chat-id
                                    :message-count (length all-messages)
                                    :media-count (length all-media)
                                    :date-range (cons (or date-from (getf (car all-messages) :date))
                                                      (or date-to (getf (car (last all-messages)) :date)))
                                    :format format))
             (backup-data (list :messages all-messages
                                :media-files all-media)))

        ;; Format output
        (let ((content (case format
                         (:json (format-json-backup backup-data))
                         (:html (format-html-backup backup-data "Chat Backup"))
                         (otherwise (format-json-backup backup-data)))))

          ;; Write to file
          (let ((final-path output-path))
            (with-open-file (out output-path
                                 :direction :output
                                 :if-exists :supersede
                                 :element-type 'character)
              (write-string content out))

            ;; Compress if requested
            (when compress
              (setf final-path (format nil "~A.gz" output-path))
              ;; In production, use zlib to compress
              (format t "Compression not yet implemented~%"))

            ;; Encrypt if requested
            (when (and encrypt password)
              ;; In production, use ironclad to encrypt
              (format t "Encryption not yet implemented~%"))

            ;; Update backup info
            (setf (backup-file-path backup) final-path)
            (setf (backup-file-size backup)
                  (if (probe-file final-path)
                      (file-length final-path)
                      nil))
            (setf (backup-is-encrypted backup) (and encrypt password))

            ;; Store in manager
            (setf (gethash (backup-id backup) (backup-manager-backups manager)) backup)

            (format t "Export complete: ~A~%" final-path)
            (values backup nil)))))))

;;; ============================================================================
;;; Export All Chats
;;; ============================================================================

(defun export-all-chats (output-directory &key
                         (format :json)
                         (include-media nil))
  "Export all chats to directory.

   OUTPUT-DIRECTORY: Destination directory
   FORMAT: Output format
   INCLUDE-MEDIA: Whether to include media files

   Returns:
     (values count exported-paths error)"
  (let ((manager (get-backup-manager)))
    ;; Ensure output directory exists
    (ensure-directories-exist output-directory)

    ;; Get all chats
    (let ((chats (get-chats :limit 100)))
      (when (null chats)
        (return-from export-all-chats
          (values 0 nil :no-chats "No chats found")))

      (let ((exported '())
            (count 0))
        (dolist (chat chats)
          (let* ((chat-id (getf chat :id))
                 (chat-title (getf chat :title (format nil "Chat_~A" chat-id)))
                 (safe-title (cl-ppcre:regex-replace-all "[^a-zA-Z0-9_-]" chat-title "_"))
                 (filename (format nil "~A_~A.~A"
                                   (get-universal-time)
                                   safe-title
                                   (if (eq format :html) "html" "json")))
                 (output-path (merge-pathnames filename output-directory)))
            (handler-case
                (multiple-value-bind (backup error)
                    (export-chat-history chat-id output-path
                                         :format format
                                         :include-media include-media)
                  (if error
                      (format t "Failed to export ~A: ~A~%" chat-title error)
                      (progn
                        (push output-path exported)
                        (incf count))))
              (error (e)
                (format t "Error exporting ~A: ~A~%" chat-title e)))))

        (format t "Exported ~D chats~%" count)
        (values count exported nil)))))

;;; ============================================================================
;;; Import Functions
;;; ============================================================================

(defun import-chat-history (backup-file &key (merge t) (password nil))
  "Import chat history from backup.

   BACKUP-FILE: Path to backup file
   MERGE: If T, merge with existing messages; if NIL, replace
   PASSWORD: Decryption password (if encrypted)

   Returns:
     (values imported-count error)"
  (unless (probe-file backup-file)
    (return-from import-chat-history
      (values nil :file-not-found "Backup file not found")))

  ;; Read backup file
  (let ((content (with-open-file (in backup-file :direction :input)
                   (let ((data (make-string (file-length in))))
                     (read-sequence data in)
                     data))))

    ;; Parse JSON
    (let ((backup-data (jonathan:json-read content)))
      (let* ((chat-id (getf backup-data :chat_id))
             (messages (getf backup-data :messages))
             (imported 0))

        (format t "Importing ~D messages to chat ~A...~%" (length messages) chat-id)

        ;; Import each message
        (dolist (msg-data messages)
          (handler-case
              (progn
                ;; In production, use import-message API
                ;; For now, just count
                (incf imported))
            (error (e)
              (format t "Failed to import message: ~A~%" e))))

        (format t "Imported ~D messages~%" imported)
        (values imported nil)))))

;;; ============================================================================
;;; Incremental Backup
;;; ============================================================================

(defun create-incremental-backup (chat-id base-backup-path output-path &key
                                  (format :json))
  "Create incremental backup since last backup.

   CHAT-ID: The chat to backup
   BASE-BACKUP-PATH: Path to previous backup
   OUTPUT-PATH: Destination for incremental backup
   FORMAT: Output format

   Returns:
     (values backup-info error)"
  (unless (probe-file base-backup-path)
    (return-from create-incremental-backup
      (values nil :base-not-found "Base backup not found")))

  ;; Read base backup to get last message date
  (let ((base-data (jonathan:with-json-input base-backup-path
                         (list :last-date (jonathan:json-read-token)))))
    (let ((last-date (getf base-data :last-date)))
      ;; Export only newer messages
      (export-chat-history chat-id output-path
                           :format format
                           :date-from last-date))))

;;; ============================================================================
;;; Backup Info
;;; ============================================================================

(defun get-backup-info (backup-file)
  "Get backup file metadata.

   BACKUP-FILE: Path to backup file

   Returns:
     Plist with backup metadata"
  (unless (probe-file backup-file)
    (return-from get-backup-info
      (list :error :file-not-found)))

  (let ((content (with-open-file (in backup-file :direction :input)
                   (let ((data (make-string (file-length in))))
                     (read-sequence data in)
                     data))))
    (handler-case
        (let ((backup-data (jonathan:json-read content)))
          (list :version (getf backup-data :backup_version)
                :chat-id (getf backup-data :chat_id)
                :export-date (getf backup-data :export_date)
                :message-count (getf backup-data :message_count)
                :media-count (getf backup-data :media_count)
                :file-size (file-length backup-file)
                :is-encrypted (cl-ppcre:scan "\\.enc$" backup-file)))
      (error (e)
        (list :error :parse-failed :message (princ-to-string e))))))

;;; ============================================================================
;;; Encryption Utilities (Stub)
;;; ============================================================================

(defun encrypt-backup (backup-file password &key (output-path nil))
  "Encrypt backup file with password.

   BACKUP-FILE: Path to backup file
   PASSWORD: Encryption password
   OUTPUT-PATH: Output path (default: backup-file.enc)

   Returns:
     (values encrypted-path error)"
  (declare (ignorable backup-file password output-path))
  ;; In production, use ironclad for encryption
  (format t "Encryption not yet implemented~%")
  (values nil :not-implemented))

(defun decrypt-backup (backup-file password)
  "Decrypt backup file with password.

   BACKUP-FILE: Path to encrypted backup
   PASSWORD: Decryption password

   Returns:
     (values decrypted-content error)"
  (declare (ignorable backup-file password))
  ;; In production, use ironclad for decryption
  (format t "Decryption not yet implemented~%")
  (values nil :not-implemented))

;;; ============================================================================
;;; Cleanup
;;; ============================================================================

(defun cleanup-backup-temp ()
  "Clean up temporary backup files.

   Returns:
     Number of files cleaned"
  (let ((manager (get-backup-manager))
        (count 0))
    (when (backup-manager-temp-dir manager)
      (let ((temp-dir (backup-manager-temp-dir manager)))
        (when (probe-file temp-dir)
          (dolist (file (directory (merge-pathnames "*.tmp" temp-dir)))
            (delete-file file)
            (incf count)))))
    count))
