;;; messages-api.lisp --- Messages API implementation

(in-package #:cl-telegram/api)

;;; ### Message Sending

(defun send-message (chat-id text &key (parse-mode nil) (entities nil))
  "Send a text message to a chat.

   CHAT-ID: The unique identifier of the chat
   TEXT: Text of the message to send (1-4096 characters)
   PARSE-MODE: Optional parsing mode (:markdown, :html)
   ENTITIES: Optional message entities for formatting

   Returns: message object on success, error on failure"
  (unless (authorized-p)
    (return-from send-message
      (values nil :not-authorized "User not authenticated")))

  (unless (and text (> (length text) 0) (<= (length text) 4096))
    (return-from send-message
      (values nil :invalid-message "Message text must be 1-4096 characters")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-message
        (values nil :no-connection "No active connection")))

    ;; Create sendMessage TL object
    (let ((request (make-tl-object
                    'messages.sendMessage
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :message text
                    :random-id (random (expt 2 63)))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Message send timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Retrieval

(defun get-messages (chat-id &key (limit 50) (offset 0) (from-message-id nil))
  "Get message history for a chat.

   CHAT-ID: The unique identifier of the chat
   LIMIT: Number of messages to retrieve (1-100)
   OFFSET: Number of messages to skip
   FROM-MESSAGE-ID: Optional starting message ID

   Returns: list of messages on success, error on failure"
  (unless (authorized-p)
    (return-from get-messages
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max limit 1) 100))
  (setf offset (max offset 0))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-messages
        (values nil :no-connection "No active connection")))

    ;; Create searchMessages TL object
    (let ((request (make-tl-object
                    'messages.search
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :filter (make-tl-object 'inputMessagesFilterEmpty)
                    :limit limit
                    :offset-id (or from-message-id 0))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :messages)
              (values (getf result :messages) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Get messages timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-message-history (chat-id &key (limit 50) (offset-id 0))
  "Get message history with pagination.

   CHAT-ID: The unique identifier of the chat
   LIMIT: Number of messages to retrieve
   OFFSET-ID: Start from this message ID (0 for newest)

   Returns: (values messages has-more)"
  (multiple-value-bind (messages error)
      (get-messages chat-id :limit limit :offset offset-id)
    (if error
        (values nil nil)
        (values messages (>= (length messages) limit)))))

;;; ### Message Deletion

(defun delete-messages (chat-id message-ids)
  "Delete messages from a chat.

   CHAT-ID: The unique identifier of the chat
   MESSAGE-IDS: List of message IDs to delete

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from delete-messages
      (values nil :not-authorized "User not authenticated")))

  (unless (and message-ids (listp message-ids) (> (length message-ids) 0))
    (return-from delete-messages
      (values nil :invalid-argument "Message IDs must be a non-empty list")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from delete-messages
        (values nil :no-connection "No active connection")))

    ;; Create deleteMessages TL object
    (let ((request (make-tl-object
                    'messages.deleteMessages
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :id message-ids
                    :revoke t)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :messagesAffected)
              (values t nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Delete messages timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Editing

(defun edit-message (chat-id message-id new-text &key (parse-mode nil))
  "Edit a message text.

   CHAT-ID: The unique identifier of the chat
   MESSAGE-ID: ID of the message to edit
   NEW-TEXT: New text for the message

   Returns: edited message on success, error on failure"
  (unless (authorized-p)
    (return-from edit-message
      (values nil :not-authorized "User not authenticated")))

  (unless (and new-text (> (length new-text) 0) (<= (length new-text) 4096))
    (return-from edit-message
      (values nil :invalid-message "Message text must be 1-4096 characters")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from edit-message
        (values nil :no-connection "No active connection")))

    ;; Create editMessageText TL object
    (let ((request (make-tl-object
                    'messages.editMessage
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :message-id message-id
                    :message new-text)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Edit message timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Forwarding

(defun forward-messages (from-chat-id to-chat-id message-ids &key (as-silent nil))
  "Forward messages from one chat to another.

   FROM-CHAT-ID: Source chat ID
   TO-CHAT-ID: Destination chat ID
   MESSAGE-IDS: List of message IDs to forward
   AS-SILENT: Send silently (no notification)

   Returns: forwarded messages on success, error on failure"
  (unless (authorized-p)
    (return-from forward-messages
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from forward-messages
        (values nil :no-connection "No active connection")))

    ;; Create forwardMessages TL object
    (let ((request (make-tl-object
                    'messages.forwardMessages
                    :from-peer (make-tl-object 'inputPeerUser :user-id from-chat-id)
                    :to-peer (make-tl-object 'inputPeerUser :user-id to-chat-id)
                    :id message-ids
                    :random-id (list (random (expt 2 63)))
                    :silent as-silent)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :updates)
              (values (getf result :updates) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Forward messages timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Reactions

(defun send-reaction (chat-id message-id reaction-type)
  "Send a reaction to a message.

   CHAT-ID: The unique identifier of the chat
   MESSAGE-ID: ID of the message to react to
   REACTION-TYPE: Type of reaction (:emoji :custom-emoji)

   Returns: t on success, error on failure"
  (unless (authorized-p)
    (return-from send-reaction
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-reaction
        (values nil :no-connection "No active connection")))

    ;; Create sendReaction TL object
    (let ((request (make-tl-object
                    'messages.sendReaction
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :message-id message-id
                    :reaction reaction-type)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :messageReaction)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Search

(defun search-messages (chat-id query &key (limit 50))
  "Search for messages containing text.

   CHAT-ID: The unique identifier of the chat
   QUERY: Search query string
   LIMIT: Maximum number of results

   Returns: list of matching messages"
  (unless (authorized-p)
    (return-from search-messages
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-messages
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.search
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :query query
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values (getf result :messages) nil))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### TDLib Compatibility

(defun |sendMessage| (chat-id text &key parse-mode entities)
  "TDLib compatible sendMessage."
  (send-message chat-id text :parse-mode parse-mode :entities entities))

(defun |getMessages| (chat-id message-ids)
  "TDLib compatible getMessages by IDs."
  (declare (ignore message-ids))
  (get-messages chat-id))

(defun |deleteMessages| (chat-id message-ids &key revoke)
  "TDLib compatible deleteMessages."
  (declare (ignore revoke))
  (delete-messages chat-id message-ids))

(defun |editMessageText| (chat-id message-id text &key parse-mode)
  "TDLib compatible editMessageText."
  (edit-message chat-id message-id text :parse-mode parse-mode))

(defun |forwardMessages| (from-chat-id to-chat-id message-ids &key as-silent)
  "TDLib compatible forwardMessages."
  (forward-messages from-chat-id to-chat-id message-ids :as-silent as-silent))

;;; ### File/Media Transfer

(defvar *upload-part-size* 524288  ; 512 KB
  "Size of each upload part")

(defvar *max-file-size* 2147483648  ; 2 GB
  "Maximum file size for uploads")

(defun send-file (chat-id file-path &key file-name file-type caption progress-callback)
  "Send a file to a chat.

   CHAT-ID: The unique identifier of the chat
   FILE-PATH: Path to the file to upload
   FILE-NAME: Optional custom file name
   FILE-TYPE: Type of file (:document :photo :audio :video :voice)
   CAPTION: Optional caption (0-1024 characters)
   PROGRESS-CALLBACK: Optional callback (bytes-sent total-bytes)

   Returns: (values message error)

   Example:
   (send-file 123 \"/path/to/file.jpg\"
              :file-type :photo
              :caption \"My photo\"
              :progress-callback (lambda (sent total)
                                   (format t \"~D%~%\" (* 100 sent total))))"
  (unless (authorized-p)
    (return-from send-file
      (values nil :not-authorized "User not authenticated")))

  ;; Validate file
  (unless (probe-file file-path)
    (return-from send-file
      (values nil :file-not-found (format nil "File not found: ~A" file-path))))

  (let ((file-size (file-length file-path)))
    (when (> file-size *max-file-size*)
      (return-from send-file
        (values nil :file-too-large
                (format nil "File size (~D bytes) exceeds maximum (~D bytes)"
                        file-size *max-file-size*))))

    (let ((connection (ensure-auth-connection)))
      (unless connection
        (return-from send-file
          (values nil :no-connection "No active connection")))

      (handler-case
          ;; Step 1: Get file ID for upload
          (let* ((file-id (generate-file-id file-name (or file-type :document)))
                 (parts (ceiling file-size *upload-part-size*))
                 (uploaded-parts 0))

            (format t "Uploading file: ~A (~D bytes, ~D parts)~%"
                    file-name file-size parts)

            ;; Step 2: Upload file parts
            (with-open-file (stream file-path :element-type '(unsigned-byte 8))
              (loop for part from 0 below parts do
                (let* ((buffer (make-array *upload-part-size*
                                           :element-type '(unsigned-byte 8)))
                       (bytes-read (read-sequence buffer stream))
                       (actual-buffer (if (= bytes-read *upload-part-size*)
                                          buffer
                                          (subseq buffer 0 bytes-read))))

                  ;; Upload part
                  (upload-file-part connection file-id part actual-buffer)

                  (incf uploaded-parts)
                  (when progress-callback
                    (funcall progress-callback
                             (* uploaded-parts *upload-part-size*)
                             file-size)))))

            ;; Step 3: Send message with file
            (let ((request (make-tl-object
                            'messages.sendMedia
                            :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                            :media (case file-type
                                     (:photo
                                      (make-tl-object 'inputMediaUploadedPhoto
                                                      :file file-id
                                                      :caption (or caption "")))
                                     (:document
                                      (make-tl-object 'inputMediaUploadedDocument
                                                      :file file-id
                                                      :caption (or caption "")
                                                      :mime-type "application/octet-stream"))
                                     (t
                                      (make-tl-object 'inputMediaUploadedDocument
                                                      :file file-id
                                                      :caption (or caption ""))))
                            :random-id (random (expt 2 63)))))
              (rpc-handler-case (rpc-call connection request :timeout 60000)
                (:ok (result)
                  (if (eq (getf result :@type) :message)
                      (values result nil)
                      (values nil :unexpected-response result)))
                (:timeout ()
                  (values nil :timeout "File upload timeout"))
                (:error (err)
                  (values nil :rpc-error err))))))
        (error (e)
          (values nil :upload-error (format nil "Upload failed: ~A" e)))))))

(defun download-file (file-id destination-path &key progress-callback)
  "Download a file from Telegram.

   FILE-ID: The file identifier
   DESTINATION-PATH: Path to save the file
   PROGRESS-CALLBACK: Optional callback (bytes-received total-bytes)

   Returns: (values destination-path error)

   Example:
   (download-file \"AgADBAAD...\" \"/tmp/download.jpg\"
                  :progress-callback (lambda (received total)
                                       (format t \"~D%~%\" (* 100 received total))))"
  (unless (authorized-p)
    (return-from download-file
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from download-file
        (values nil :no-connection "No active connection")))

    (handler-case
        ;; Step 1: Get file location
        (let* ((file-location (get-file-location connection file-id))
               (file-size (getf file-location :size))
               (dc-id (getf file-location :dc-id))
               (bytes-downloaded 0))

          (format t "Downloading file: ~A (~D bytes)~%" file-id file-size)

          ;; Step 2: Download file parts
          (with-open-file (stream destination-path
                                  :direction :output
                                  :element-type '(unsigned-byte 8)
                                  :if-exists :supersede)
            (loop for offset from 0 below file-size by *upload-part-size*
                  for limit = (min (+ offset *upload-part-size*) file-size)
                  for size = (- limit offset)
                  do (let ((part-data (download-file-part connection dc-id file-location offset size)))
                       (write-sequence part-data stream)
                       (incf bytes-downloaded size)
                       (when progress-callback
                         (funcall progress-callback bytes-downloaded file-size)))))

          (values destination-path nil))
      (error (e)
        (values nil :download-error (format nil "Download failed: ~A" e))))))

(defun send-photo (chat-id file-path &key caption progress-callback)
  "Send a photo to a chat.

   CHAT-ID: The unique identifier of the chat
   FILE-PATH: Path to the image file
   CAPTION: Optional caption (0-1024 characters)
   PROGRESS-CALLBACK: Optional callback for upload progress

   Returns: (values message error)"
  (send-file chat-id file-path
             :file-type :photo
             :caption caption
             :progress-callback progress-callback))

(defun send-document (chat-id file-path &key file-name caption progress-callback)
  "Send a document to a chat.

   CHAT-ID: The unique identifier of the chat
   FILE-PATH: Path to the document file
   FILE-NAME: Optional custom file name
   CAPTION: Optional caption (0-1024 characters)
   PROGRESS-CALLBACK: Optional callback for upload progress

   Returns: (values message error)"
  (send-file chat-id file-path
             :file-type :document
             :file-name file-name
             :caption caption
             :progress-callback progress-callback))

(defun send-audio (chat-id file-path &key caption progress-callback)
  "Send an audio file to a chat.

   CHAT-ID: The unique identifier of the chat
   FILE-PATH: Path to the audio file
   CAPTION: Optional caption
   PROGRESS-CALLBACK: Optional callback for upload progress

   Returns: (values message error)"
  (send-file chat-id file-path
             :file-type :audio
             :caption caption
             :progress-callback progress-callback))

(defun send-video (chat-id file-path &key caption progress-callback)
  "Send a video file to a chat.

   CHAT-ID: The unique identifier of the chat
   FILE-PATH: Path to the video file
   CAPTION: Optional caption
   PROGRESS-CALLBACK: Optional callback for upload progress

   Returns: (values message error)"
  (send-file chat-id file-path
             :file-type :video
             :caption caption
             :progress-callback progress-callback))

;;; ### Internal Helper Functions

(defun generate-file-id (file-name file-type)
  "Generate a unique file ID for upload."
  (format nil "~A_~A_~A"
          (symbol-name file-type)
          (get-universal-time)
          (random (expt 2 32))))

(defun upload-file-part (connection file-id part-number data)
  "Upload a single file part.

   Returns: t on success"
  (let ((request (make-tl-object
                  'upload.saveFilePart
                  :file-id (parse-integer file-name file-id :start 2)
                  :file-part part-number
                  :bytes data)))
    (rpc-handler-case (rpc-call connection request :timeout 30000)
      (:ok (result)
        (if (getf result :ok)
            t
            (error "Upload part failed")))
      (:error (err)
        (error "Upload error: ~A" err)))))

(defun get-file-location (connection file-id)
  "Get file location information."
  (let ((request (make-tl-object
                  'upload.getFile
                  :location (make-tl-object 'inputDocumentFileLocation
                                            :id file-id))))
    (rpc-handler-case (rpc-call connection request :timeout 10000)
      (:ok (result)
        result)
      (:error (err)
        (error "Get file location error: ~A" err)))))

(defun download-file-part (connection dc-id file-location offset limit)
  "Download a file part.

   Returns: Byte array of file data"
  (let ((request (make-tl-object
                  'upload.getFile
                  :location file-location
                  :offset offset
                  :limit limit)))
    (rpc-handler-case (rpc-call connection request :timeout 30000)
      (:ok (result)
        (getf result :bytes))
      (:error (err)
        (error "Download error: ~A" err)))))

(defun get-file-type-from-path (file-path)
  "Determine file type from file extension."
  (let ((ext (pathname-type file-path)))
    (cond
      ((member ext '("jpg" "jpeg" "png" "gif" "bmp" "webp") :test #'string=) :photo)
      ((member ext '("mp3" "flac" "wav" "ogg" "m4a") :test #'string=) :audio)
      ((member ext '("mp4" "avi" "mkv" "mov" "webm") :test #'string=) :video)
      (t :document))))
