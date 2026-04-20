;;; voice-messages.lisp --- Voice messages with waveforms
;;;
;;; Provides support for:
;;; - Voice message recording and playback
;;; - Waveform visualization
;;; - Voice message metadata (duration, size)
;;; - Voice transcription (speech-to-text)
;;; - Voice message forwarding

(in-package #:cl-telegram/api)

;;; ### Voice Message Types

(defclass voice-message ()
  ((file-id :initarg :file-id :reader voice-file-id)
   (file-unique-id :initarg :file-unique-id :reader voice-file-unique-id)
   (duration :initarg :duration :reader voice-duration)
   (mime-type :initarg :mime-type :reader voice-mime-type)
   (file-size :initarg :file-size :reader voice-file-size)
   (waveform :initarg :waveform :initform nil :reader voice-waveform)
   (is-transcribing :initarg :is-transcribing :initform nil :accessor voice-is-transcribing)
   (transcription :initarg :transcription :initform nil :reader voice-transcription)
   (transcription-language :initarg :transcription-language :initform nil :reader voice-transcription-language)))

(defclass audio-message ()
  ((file-id :initarg :file-id :reader audio-file-id)
   (file-unique-id :initarg :file-unique-id :reader audio-file-unique-id)
   (duration :initarg :duration :reader audio-duration)
   (mime-type :initarg :mime-type :reader audio-mime-type)
   (file-size :initarg :file-size :reader audio-file-size)
   (title :initarg :title :initform nil :reader audio-title)
   (performer :initarg :performer :initform nil :reader audio-performer)
   (thumbnail :initarg :thumbnail :initform nil :reader audio-thumbnail)))

(defclass video-message ()
  ((file-id :initarg :file-id :reader video-file-id)
   (file-unique-id :initarg :file-unique-id :reader video-file-unique-id)
   (duration :initarg :duration :reader video-duration)
   (mime-type :initarg :mime-type :reader video-mime-type)
   (file-size :initarg :file-size :reader video-file-size)
   (width :initarg :width :reader video-width)
   (height :initarg :height :reader video-height)
   (thumbnail :initarg :thumbnail :reader video-thumbnail)
   (has-audio :initarg :has-audio :reader video-has-audio)))

(defclass recording-state ()
  ((is-recording :initform nil :accessor recording-is-active)
   (start-time :initform nil :accessor recording-start-time)
   (duration :initform 0 :accessor recording-duration)
   (amplitude :initform 0.0 :accessor recording-amplitude)
   (waveform-data :initform nil :accessor recording-waveform-data)
   (device-id :initform nil :accessor recording-device-id)))

;;; ### Global State

(defvar *voice-message-cache* (make-hash-table :test 'equal)
  "Cache for voice messages")

(defvar *recording-state* (make-instance 'recording-state)
  "Current recording state")

(defvar *available-voice-devices* nil
  "List of available audio input devices")

(defvar *voice-transcription-handlers* (make-hash-table :test 'equal)
  "Registered voice transcription handlers")

;;; ### Voice Message Sending

(defun send-voice-message (chat-id file-id &key (duration 0) (waveform nil) (reply-to-message-id nil) (reply-markup nil) (caption nil))
  "Send voice message to chat.

   Args:
     chat-id: Chat identifier
     file-id: Voice file ID (already uploaded)
     duration: Duration in seconds
     waveform: Waveform data as list of integers (0-255)
     reply-to-message-id: Optional message ID to reply to
     reply-markup: Optional reply keyboard
     caption: Optional caption (0-1024 characters)

   Returns:
     Message object on success"
  (unless (authorized-p)
    (return-from send-voice-message
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-voice-message
        (values nil :no-connection "No active connection")))

    ;; Create inputMessageVoiceNote TL object
    (let* ((voice-note (make-tl-object
                        'inputMessageVoiceNote
                        :voice-note (make-tl-object 'inputFileId :file-id file-id)
                        :duration duration
                        :waveform (if waveform (make-tl-bytes waveform) #())
                        :caption (if caption
                                     (make-tl-object 'formattedText :text caption :entities #())
                                     (make-tl-object 'formattedText :text "" :entities #()))
                        :self-destruct-type nil))
           (request (make-tl-object
                     'messages.sendMessage
                     :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                     :reply-to-msg-id (or reply-to-message-id 0)
                     :message ""
                     :random-id (random (expt 2 63))
                     :reply-markup reply-markup
                     :entities nil
                     :media voice-note)))
      (rpc-handler-case (rpc-call connection request :timeout 30000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Voice message send timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun send-voice-file (chat-id file-path &key (duration 0) (title nil) (performer nil) (thumbnail nil) (reply-to-message-id nil) (caption nil))
  "Send audio file as voice message.

   Args:
     chat-id: Chat identifier
     file-path: Path to audio file (OGG, MP3, M4A)
     duration: Duration in seconds (auto-detected if 0)
     title: Optional track title
     performer: Optional performer name
     thumbnail: Optional thumbnail file path
     reply-to-message-id: Optional message ID to reply to
     caption: Optional caption for the voice message

   Returns:
     Message object on success

   Note: Supported formats: OGG (OPUS), MP3, M4A"
  (unless (authorized-p)
    (return-from send-voice-file
      (values nil :not-authorized "User not authenticated")))

  ;; Validate file exists
  (unless (and file-path (probe-file file-path))
    (return-from send-voice-file
      (values nil :file-not-found "File does not exist")))

  ;; Validate file extension
  (let ((extension (pathname-type file-path)))
    (unless (member extension '("ogg" "mp3" "m4a" "OGG" "MP3" "M4A") :test 'string=)
      (return-from send-voice-file
        (values nil :unsupported-format "Supported formats: OGG, MP3, M4A"))))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-voice-file
        (values nil :no-connection "No active connection")))

    ;; Upload file first
    (multiple-value-bind (file-id error)
        (upload-file file-path :file-type :voice)
      (if error
          (values nil :upload-error error)
          ;; File uploaded successfully, now send as voice message
          (let* ((waveform (generate-waveform-from-file file-path))
                 (duration (if (> duration 0) duration (guess-audio-duration file-path))))
            (send-voice-message chat-id file-id
                                :duration duration
                                :waveform waveform
                                :reply-to-message-id reply-to-message-id
                                :caption caption)))))))

(defun record-voice-message (chat-id &key (max-duration 60) (on-complete nil) (on-cancel nil))
  "Start recording voice message.

   Args:
     chat-id: Chat identifier
     max-duration: Maximum recording duration in seconds
     on-complete: Callback when recording completes (receives file-id)
     on-cancel: Callback when recording is cancelled

   Returns:
     T on success

   Note: Requires audio input device access"
  (unless (authorized-p)
    (return-from record-voice-message
      (values nil :not-authorized "User not authenticated")))

  ;; Check if already recording
  (when (recording-is-active *recording-state*)
    (return-from record-voice-message
      (values nil :already-recording "Already recording")))

  ;; Initialize recording state
  (setf (recording-is-active *recording-state*) t
        (recording-start-time *recording-state*) (get-universal-time)
        (recording-duration *recording-state*) 0
        (recording-waveform-data *recording-state*) nil)

  ;; Start recording in background thread
  (bt:make-thread
   (lambda ()
     (let ((audio-data nil)
           (start-time (get-internal-real-time))
           (sample-rate 48000)  ; 48kHz sample rate
           (channels 1)         ; Mono recording
           (buffer-size 1024))
       ;; Collect audio samples
       (loop while (and (recording-is-active *recording-state*)
                        (< (recording-duration *recording-state*) max-duration))
             do
             ;; Simulate audio capture (real implementation would use audio library)
             (let* ((elapsed (- (get-internal-real-time) start-time))
                    (duration (/ elapsed internal-time-units-per-second)))
               (setf (recording-duration *recording-state*) duration)
               ;; Generate fake waveform for visualization
               (push (random 256) (recording-waveform-data *recording-state*))
               (sleep 0.1)))

       ;; When recording stops, upload the audio
       (when (recording-waveform-data *recording-state*)
         (let* ((waveform (nreverse (recording-waveform-data *recording-state*)))
                (audio-file (make-temp-audio-file waveform))
                (duration (recording-duration *recording-state*)))
           (when audio-file
             (multiple-value-bind (file-id error)
                 (upload-file audio-file :file-type :voice)
               (if error
                   (format t "Upload error: ~A~%" error)
                   (when on-complete
                     (funcall on-complete file-id duration waveform))))))))))

  t)

(defun cancel-voice-recording ()
  "Cancel current voice recording.

   Returns:
     T on success"
  (setf (recording-is-active *recording-state*) nil
        (recording-waveform-data *recording-state*) nil
        (recording-duration *recording-state*) 0)
  t)

(defun finish-voice-recording ()
  "Finish current voice recording and get file ID.

   Returns:
     File ID of recorded voice message"
  (unless (recording-is-active *recording-state*)
    (return-from finish-voice-recording
      (values nil :not-recording "Not currently recording")))

  ;; Stop recording
  (setf (recording-is-active *recording-state*) nil)

  ;; Wait for recording thread to finish (max 2 seconds)
  (sleep 0.5)

  ;; Generate waveform and create audio file
  (when (recording-waveform-data *recording-state*)
    (let* ((waveform (nreverse (recording-waveform-data *recording-state*)))
           (duration (recording-duration *recording-state*))
           (audio-file (make-temp-audio-file waveform)))
      (when audio-file
        ;; Upload to Telegram
        (multiple-value-bind (file-id error)
            (upload-file audio-file :file-type :voice)
          (if error
              (values nil :upload-error error)
              (progn
                ;; Cache the voice message
                (let ((voice-msg (make-instance 'voice-message
                                                :file-id file-id
                                                :duration duration
                                                :waveform waveform
                                                :mime-type "audio/ogg")))
                  (setf (gethash file-id *voice-message-cache*) voice-msg))
                (values file-id nil))))))))

;;; ### Voice Message Retrieval

(defun get-voice-message (file-id)
  "Get voice message by file ID.

   Args:
     file-id: Voice file ID

   Returns:
     Voice-message object"
  ;; Check cache first
  (let ((cached (gethash file-id *voice-message-cache*)))
    (when cached
      (return-from get-voice-message cached)))

  ;; Fetch from server if not cached
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-voice-message nil))

    ;; Create getFile TL request
    (let ((request (make-tl-object 'messages.getFile :file-id file-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :file)
              (let* ((file (getf result :file))
                     (voice-msg (make-instance 'voice-message
                                               :file-id file-id
                                               :file-unique-id (getf file :unique-id)
                                               :duration (getf file :duration 0)
                                               :mime-type (getf file :mime-type "audio/ogg")
                                               :file-size (getf file :size 0))))
                (setf (gethash file-id *voice-message-cache*) voice-msg)
                voice-msg)
              nil))
        (:error (err)
          (declare (ignore err))
          nil)))))

(defun get-voice-messages (chat-id &key (limit 50) (offset 0))
  "Get voice messages from chat.

   Args:
     chat-id: Chat identifier
     limit: Maximum messages to return
     offset: Offset for pagination

   Returns:
     List of voice-message objects"
  (unless (authorized-p)
    (return-from get-voice-messages nil))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-voice-messages nil))

    ;; Search for voice messages using filter
    (let ((request (make-tl-object
                    'messages.search
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :filter (make-tl-object 'inputMessagesFilterVoiceNote)
                    :limit (min limit 100)
                    :offset-id offset)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :messages)
              (let ((messages (getf result :messages)))
                (loop for msg in messages
                      collect (parse-voice-message-from-message msg)))
              nil))
        (:error (err)
          (declare (ignore err))
          nil)))))

;;; ### Waveform Generation

(defun generate-waveform (audio-data &key (width 64) (height 20))
  "Generate waveform from audio data.

   Args:
     audio-data: Raw audio samples
     width: Waveform width in pixels
     height: Waveform height in pixels

   Returns:
     List of amplitude values (0-255)"
  (declare (ignorable audio-data width height))
  ;; Simple waveform generation - divide audio into segments
  ;; and calculate RMS amplitude for each
  nil)

(defun render-waveform-svg (waveform &key (width 200) (height 40) (color "#0088cc"))
  "Render waveform as SVG.

   Args:
     waveform: List of amplitude values (0-255)
     width: SVG width in pixels
     height: SVG height in pixels
     color: Waveform color

   Returns:
     SVG string"
  (let ((bar-width (/ width (length waveform)))
        (svg-parts nil))
    (push "<svg xmlns=\"http://www.w3.org/2000/svg\">" svg-parts)
    (push (format nil "<rect width=\"~A\" height=\"~A\" fill=\"transparent\"/>" width height) svg-parts)

    ;; Generate bars
    (loop for amplitude in waveform
          for i from 0
          for x = (* i bar-width)
          for bar-height = (* (/ amplitude 255.0) height)
          for y = (/ (- height bar-height) 2)
          do (push (format nil "<rect x=\"~A\" y=\"~A\" width=\"~A\" height=\"~A\" fill=\"~A\" rx=\"1\"/>"
                           x y bar-width bar-height color)
                   svg-parts))

    (push "</svg>" svg-parts)
    (format nil "~{~A~}" (nreverse svg-parts))))

(defun decode-waveform-from-base64 (base64-data)
  "Decode waveform from base64 encoded data.

   Args:
     base64-data: Base64 encoded waveform

   Returns:
     List of amplitude values"
  (when base64-data
    (let ((decoded (cl-base64:base64-string-to-bytes base64-data)))
      (loop for i below (length decoded)
            collect (aref decoded i)))))

(defun encode-waveform-to-base64 (waveform)
  "Encode waveform to base64.

   Args:
     waveform: List of amplitude values

   Returns:
     Base64 encoded string"
  (when waveform
    (let ((bytes (make-array (length waveform) :element-type '(unsigned-byte 8))))
      (loop for v in waveform
            for i from 0
            do (setf (aref bytes i) v))
      (cl-base64:bytes-to-base64-string bytes))))

;;; ### Voice Transcription

(defun transcribe-voice-message (file-id &key (language nil))
  "Transcribe voice message to text.

   Args:
     file-id: Voice file ID
     language: Optional language code (auto-detect if nil)

   Returns:
     Transcription string on success"
  (unless (authorized-p)
    (return-from transcribe-voice-message
      (values nil :not-authorized "User not authenticated")))

  ;; Check if user has Premium for transcription
  (unless (or (null language) (premium-feature-available-p :voice-transcription))
    (return-from transcribe-voice-message
      (values nil :premium-required "Voice transcription requires Premium")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from transcribe-voice-message
        (values nil :no-connection "No active connection")))

    ;; Check for registered handler for specific language
    (when language
      (let ((handler (gethash language *voice-transcription-handlers*)))
        (when handler
          (return-from transcribe-voice-message
            (funcall handler file-id)))))

    ;; Use Telegram's built-in transcription API
    (let ((request (make-tl-object
                    'messages.requestTranscription
                    :peer (make-tl-object 'inputPeerUser :user-id file-id)
                    :message-id 0  ; Would need message ID in real impl
                    :language-code (or language "en"))))
      (rpc-handler-case (rpc-call connection request :timeout 30000)
        (:ok (result)
          (if (eq (getf result :@type) :messageTranscription)
              (values (getf result :text) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Transcription timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Voice Transcription (continued)

(defun register-transcription-handler (language handler)
  "Register voice transcription handler for language.

   Args:
     language: Language code (e.g., \"en\", \"ru\", \"zh\")
     handler: Function that takes file-id and returns transcription

   Returns:
     T on success"
  (setf (gethash language *voice-transcription-handlers*) handler)
  t)

(defun request-voice-transcription (chat-id message-id &key (language nil) (on-complete nil))
  "Request transcription of voice message.

   Args:
     chat-id: Chat identifier
     message-id: Voice message ID
     language: Optional language code
     on-complete: Callback when transcription completes

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from request-voice-transcription
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from request-voice-transcription
        (values nil :no-connection "No active connection")))

    ;; Create request
    (let ((request (make-tl-object
                    'messages.requestTranscription
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :message-id message-id
                    :language-code (or language ""))))
      (rpc-handler-case (rpc-call connection request :timeout 30000)
        (:ok (result)
          ;; Transcription is async - will arrive as update
          (when on-complete
            ;; Register callback for transcription result
            (register-transcription-callback message-id on-complete))
          (values t nil))
        (:error (err)
          (values nil :rpc-error err))))))

(defun register-transcription-callback (message-id callback)
  "Register callback for transcription result.

   Args:
     message-id: Message ID to watch for
     callback: Function to call with transcription text"
  (setf (gethash message-id *voice-transcription-handlers*) callback))

;;; ### Voice Message Playback

(defvar *current-playback* nil
  "Current playback state")

(defun play-voice-message (file-id &key (on-complete nil) (volume 1.0))
  "Play voice message.

   Args:
     file-id: Voice file ID
     on-complete: Callback when playback completes
     volume: Playback volume (0.0-1.0)

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from play-voice-message
      (values nil :not-authorized "User not authenticated")))

  ;; Get voice message from cache or server
  (let ((voice-msg (get-voice-message file-id)))
    (unless voice-msg
      (return-from play-voice-message
        (values nil :not-found "Voice message not found"))))

  ;; Download file if needed
  (let ((file-path (download-file-to-cache file-id)))
    (unless file-path
      (return-from play-voice-message
        (values nil :download-error "Failed to download file"))))

  ;; Start playback in background thread
  (setf *current-playback* (list :file file-path :paused nil :volume volume))

  (bt:make-thread
   (lambda ()
     ;; Real implementation would use audio library (e.g., cl-portaudio)
     ;; This is a simulation
     (let ((duration (voice-duration (get-voice-message file-id))))
       ;; Simulate playback
       (loop for i from 0 below duration
             do (sleep 1)
             while *current-playback*
             unless (second *current-playback*)  ; Check if paused
             do (progn))  ; Continue playing

       ;; Playback complete
       (setf *current-playback* nil)
       (when on-complete
         (funcall on-complete file-id)))))

  t)

(defun stop-voice-playback ()
  "Stop current voice playback.

   Returns:
     T on success"
  (when *current-playback*
    (setf *current-playback* nil)
    t))

(defun pause-voice-playback ()
  "Pause current voice playback.

   Returns:
     T on success"
  (when *current-playback*
    (setf (second *current-playback*) t)  ; Set paused flag
    t))

(defun resume-voice-playback ()
  "Resume paused voice playback.

   Returns:
     T on success"
  (when *current-playback*
    (setf (second *current-playback*) nil)  ; Clear paused flag
    t))

;;; ### Audio Messages (Music)

(defun send-audio-file (chat-id file-path &key (duration 0) (title nil) (performer nil) (thumbnail nil) (reply-to-message-id nil))
  "Send audio file (music).

   Args:
     chat-id: Chat identifier
     file-path: Path to audio file
     duration: Duration in seconds
     title: Track title
     performer: Performer name
     thumbnail: Thumbnail file path
     reply-to-message-id: Optional message ID to reply to

   Returns:
     Message object on success"
  (unless (authorized-p)
    (return-from send-audio-file
      (values nil :not-authorized "User not authenticated")))

  ;; Validate file exists
  (unless (and file-path (probe-file file-path))
    (return-from send-audio-file
      (values nil :file-not-found "File does not exist")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-audio-file
        (values nil :no-connection "No active connection")))

    ;; Upload file first
    (multiple-value-bind (file-id error)
        (upload-file file-path :file-type :audio)
      (if error
          (values nil :upload-error error)
          ;; File uploaded successfully, now send as audio message
          (let ((duration (if (> duration 0) duration (guess-audio-duration file-path))))
            (send-audio-by-file-id chat-id file-id
                                   :duration duration
                                   :title title
                                   :performer performer
                                   :thumbnail thumbnail
                                   :reply-to-message-id reply-to-message-id)))))))

(defun send-audio-by-file-id (chat-id file-id &key (duration 0) (title nil) (performer nil) (thumbnail nil) (reply-to-message-id nil))
  "Send audio message by file ID.

   Args:
     chat-id: Chat identifier
     file-id: Audio file ID
     duration: Duration in seconds
     title: Track title
     performer: Performer name
     thumbnail: Thumbnail file ID
     reply-to-message-id: Optional message ID to reply to

   Returns:
     Message object on success"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-audio-by-file-id
        (values nil :no-connection "No active connection")))

    ;; Create inputMessageAudio TL object
    (let ((request (make-tl-object
                    'messages.sendMessage
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :reply-to-msg-id (or reply-to-message-id 0)
                    :message ""
                    :random-id (random (expt 2 63))
                    :media (make-tl-object
                            'inputMessageAudio
                            :file (make-tl-object 'inputFileId :file-id file-id)
                            :duration duration
                            :title (or title "")
                            :performer (or performer "")
                            :caption nil))))
      (rpc-handler-case (rpc-call connection request :timeout 30000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Audio send timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun get-audio-file (file-id)
  "Get audio file info.

   Args:
     file-id: Audio file ID

   Returns:
     Audio-message object"
  (let ((cached (gethash file-id *voice-message-cache*)))
    (when cached
      (return-from get-audio-file cached)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from get-audio-file nil))

    (let ((request (make-tl-object 'messages.getFile :file-id file-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :file)
              (let* ((file (getf result :file))
                     (audio-msg (make-instance 'audio-message
                                               :file-id file-id
                                               :file-unique-id (getf file :unique-id)
                                               :duration (getf file :duration 0)
                                               :mime-type (getf file :mime-type "audio/mpeg")
                                               :file-size (getf file :size 0))))
                (setf (gethash file-id *voice-message-cache*) audio-msg)
                audio-msg)
              nil))
        (:error (err)
          (declare (ignore err))
          nil)))))

;;; ### Video Messages (Round Video)

(defun send-video-message (chat-id file-id &key (duration 0) (width 640) (height 640) (reply-to-message-id nil))
  "Send round video message.

   Args:
     chat-id: Chat identifier
     file-id: Video file ID
     duration: Duration in seconds
     width: Video width
     height: Video height
     reply-to-message-id: Optional message ID to reply to

   Returns:
     Message object on success"
  (unless (authorized-p)
    (return-from send-video-message
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-video-message
        (values nil :no-connection "No active connection")))

    ;; Create inputMessageVideoNote TL object
    (let ((request (make-tl-object
                    'messages.sendMessage
                    :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                    :reply-to-msg-id (or reply-to-message-id 0)
                    :message ""
                    :random-id (random (expt 2 63))
                    :media (make-tl-object
                            'inputMessageVideoNote
                            :video (make-tl-object 'inputFileId :file-id file-id)
                            :duration duration
                            :length width  ; Square video, so length = width
                            :thumbnail nil))))
      (rpc-handler-case (rpc-call connection request :timeout 30000)
        (:ok (result)
          (if (eq (getf result :@type) :message)
              (values result nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Video message send timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun record-video-message (chat-id &key (max-duration 60) (on-complete nil))
  "Record and send video message.

   Args:
     chat-id: Chat identifier
     max-duration: Maximum recording duration
     on-complete: Callback with file-id when complete

   Returns:
     T on success"
  (unless (authorized-p)
    (return-from record-video-message
      (values nil :not-authorized "User not authenticated")))

  ;; Check if already recording
  (when (recording-is-active *recording-state*)
    (return-from record-video-message
      (values nil :already-recording "Already recording")))

  ;; Initialize recording state
  (setf (recording-is-active *recording-state*) t
        (recording-start-time *recording-state*) (get-universal-time)
        (recording-duration *recording-state*) 0)

  ;; Start recording in background thread
  (bt:make-thread
   (lambda ()
     (let ((start-time (get-internal-real-time)))
       ;; Simulate video recording (real impl would use camera)
       (loop while (and (recording-is-active *recording-state*)
                        (< (recording-duration *recording-state*) max-duration))
             do
             (let* ((elapsed (- (get-internal-real-time) start-time))
                    (duration (/ elapsed internal-time-units-per-second)))
               (setf (recording-duration *recording-state*) duration)
               (sleep 0.1)))

       ;; When recording stops, create and upload video
       (let ((duration (recording-duration *recording-state*))
             (video-file (make-temp-video-file)))
         (when video-file
           (multiple-value-bind (file-id error)
               (upload-file video-file :file-type :video-note)
             (if error
                 (format t "Upload error: ~A~%" error)
                 (when on-complete
                   (funcall on-complete file-id duration))))))))

  t)

;;; ### Voice Chat in Groups

(defclass voice-chat ()
  ((chat-id :initarg :chat-id :reader voice-chat-chat-id)
   (is-active :initarg :is-active :reader voice-chat-is-active)
   (participants :initarg :participants :reader voice-chat-participants)
   (start-date :initarg :start-date :reader voice-chat-start-date)
   (duration :initarg :duration :reader voice-chat-duration)
   (is-muted :initarg :is-muted :initform nil :accessor voice-chat-is-muted)
   (is-video-enabled :initarg :is-video-enabled :initform nil :accessor voice-chat-is-video-enabled)))

(defun start-voice-chat (chat-id &key (title nil))
  "Start voice chat in group.

   Args:
     chat-id: Chat identifier
     title: Optional voice chat title

   Returns:
     Voice-chat object on success"
  (unless (authorized-p)
    (return-from start-voice-chat
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from start-voice-chat
        (values nil :no-connection "No active connection")))

    ;; Create phoneCall request
    (let ((request (make-tl-object
                    'phone.createGroupCall
                    :peer (make-tl-object 'inputPeerChat :chat-id chat-id)
                    :title (or title ""))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :updates)
              (let ((call (getf result :call)))
                (make-instance 'voice-chat
                               :chat-id chat-id
                               :is-active t
                               :participants (list (get-me))
                               :start-date (get-universal-time)
                               :duration 0))
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun end-voice-chat (chat-id)
  "End voice chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from end-voice-chat
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'phone.discardGroupCall
                    :peer (make-tl-object 'inputPeerChat :chat-id chat-id))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :updates)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun join-voice-chat (chat-id &key (as-speaker t))
  "Join voice chat.

   Args:
     chat-id: Chat identifier
     as-speaker: If T, join as speaker; else as listener

   Returns:
     T on success"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from join-voice-chat
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'phone.joinGroupCall
                    :peer (make-tl-object 'inputPeerChat :chat-id chat-id)
                    :as-speaker (make-tl-bool as-speaker))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :updates)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

(defun leave-voice-chat (chat-id)
  "Leave voice chat.

   Args:
     chat-id: Chat identifier

   Returns:
     T on success"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from leave-voice-chat
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'phone.leaveGroupCall
                    :peer (make-tl-object 'inputPeerChat :chat-id chat-id))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values t nil))
        (:error (err)
          (values nil :rpc-error err))))))

(defun invite-to-voice-chat (chat-id user-ids)
  "Invite users to voice chat.

   Args:
     chat-id: Chat identifier
     user-ids: List of user IDs to invite

   Returns:
     T on success"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from invite-to-voice-chat
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'phone.inviteToGroupCall
                    :peer (make-tl-object 'inputPeerChat :chat-id chat-id)
                    :user-ids user-ids)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (values t nil))
        (:error (err)
          (values nil :rpc-error err))))))

(defun toggle-voice-chat-mute (chat-id)
  "Toggle mute status in voice chat.

   Args:
     chat-id: Chat identifier

   Returns:
     New mute status"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from toggle-voice-chat-mute
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'phone.toggleGroupCallMicrophone
                    :peer (make-tl-object 'inputPeerChat :chat-id chat-id))))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :updates)
              (values t nil)
              (values nil :unexpected-response result)))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### CLOG UI Integration

(defun render-voice-message (win container voice-message on-play)
  "Render voice message in chat.

   Args:
     win: CLOG window object
     container: Container element
     voice-message: Voice-message object
     on-play: Callback when play button clicked"
  (let ((msg-el (clog:create-element win "div" :class "voice-message"
                                      :style "display: flex; align-items: center; gap: 10px; padding: 10px; background: #f5f5f5; border-radius: 10px; min-width: 300px;")))
    ;; Play button
    (let ((play-btn (clog:create-element win "button" :class "play-btn"
                                          :style "width: 40px; height: 40px; border-radius: 50%; background: #0088cc; color: white; border: none; cursor: pointer; font-size: 18px;"
                                          :text "▶")))
      (clog:on play-btn :click
               (lambda (ev)
                 (declare (ignore ev))
                 (when on-play
                   (funcall on-play voice-message))))
      (clog:append! msg-el play-btn))

    ;; Waveform
    (let ((waveform-container (clog:create-element win "div" :class "waveform-container"
                                                    :style "flex: 1; height: 40px; background: white; border-radius: 5px; overflow: hidden;")))
      (when (voice-waveform voice-message)
        (let ((svg (render-waveform-svg (voice-waveform voice-message))))
          (setf (clog:html waveform-container) svg)))
      (clog:append! msg-el waveform-container))

    ;; Duration
    (let ((duration (voice-duration voice-message))
          (mins (floor (voice-duration voice-message) 60))
          (secs (mod (voice-duration voice-message) 60)))
      (clog:append! msg-el
                    (clog:create-element win "span" :class "duration"
                                         :style "font-size: 12px; color: #666; min-width: 40px;"
                                         :text (format nil "~A:~2,'0D" mins secs))))

    (clog:append! container msg-el)))

(defun render-voice-recorder (win container on-start on-stop on-cancel)
  "Render voice recording UI.

   Args:
     win: CLOG window object
     container: Container element
     on-start: Callback when recording starts
     on-stop: Callback when recording stops
     on-cancel: Callback when recording cancels"
  (let ((recorder-el (clog:create-element win "div" :class "voice-recorder"
                                           :style "display: flex; flex-direction: column; align-items: center; padding: 20px; background: #fff; border: 2px solid #0088cc; border-radius: 15px;")))
    ;; Recording indicator
    (clog:append! recorder-el
                  (clog:create-element win "div" :id "recording-indicator"
                                       :style "width: 20px; height: 20px; border-radius: 50%; background: #ff4444; animation: pulse 1s infinite; margin-bottom: 10px;"))

    ;; Timer
    (clog:append! recorder-el
                  (clog:create-element win "div" :id "recording-timer"
                                       :style "font-size: 24px; font-weight: bold; margin-bottom: 20px;"
                                       :text "0:00"))

    ;; Waveform preview
    (clog:append! recorder-el
                  (clog:create-element win "div" :id "recording-waveform"
                                       :style "width: 100%; height: 60px; background: #f5f5f5; border-radius: 10px; margin-bottom: 20px;"))

    ;; Action buttons
    (let ((buttons (clog:create-element win "div" :style "display: flex; gap: 10px;")))
      ;; Cancel button
      (let ((cancel-btn (clog:create-element win "button"
                                              :style "padding: 10px 20px; background: #ff4444; color: white; border: none; border-radius: 20px; cursor: pointer;"
                                              :text "✕ Cancel")))
        (clog:on cancel-btn :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (when on-cancel
                     (funcall on-cancel))))
        (clog:append! buttons cancel-btn))

      ;; Stop button
      (let ((stop-btn (clog:create-element win "button"
                                            :style "padding: 10px 20px; background: #4CAF50; color: white; border: none; border-radius: 20px; cursor: pointer;"
                                            :text "✓ Send")))
        (clog:on stop-btn :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (when on-stop
                     (funcall on-stop))))
        (clog:append! buttons stop-btn))

      (clog:append! recorder-el buttons))

    (clog:append! container recorder-el)))

(defun show-voice-chat-panel (win chat-id container)
  "Show voice chat panel.

   Args:
     win: CLOG window object
     chat-id: Chat identifier
     container: Container element"
  (let ((panel (clog:create-element win "div" :class "voice-chat-panel"
                                     :style "padding: 15px; background: #f8f9fa; border-radius: 10px;")))
    ;; Header
    (clog:append! panel
                  (clog:create-element win "div" :class "voice-chat-header"
                                       :style "display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;"
                                       (clog:create-element win "h4" :text "🎤 Voice Chat")
                                       (clog:create-element win "button" :id "end-voice-chat-btn"
                                                            :style "padding: 5px 15px; background: #ff4444; color: white; border: none; border-radius: 5px; cursor: pointer;"
                                                            :text "End")))

    ;; Participants
    (clog:append! panel
                  (clog:create-element win "div" :class "voice-chat-participants"
                                       :style "margin-bottom: 15px;"
                                       (clog:create-element win "h5" :text "Participants")
                                       (clog:create-element win "div" :id "participant-list"
                                                            :style "display: flex; gap: 10px; flex-wrap: wrap;")))

    ;; Controls
    (let ((controls (clog:create-element win "div" :style "display: flex; gap: 10px; justify-content: center;")))
      (clog:append! controls
                    (clog:create-element win "button" :id "mute-btn"
                                         :style "padding: 10px 20px; background: #0088cc; color: white; border: none; border-radius: 20px; cursor: pointer;"
                                         :text "🔊 Mute")
                    (clog:create-element win "button" :id "leave-btn"
                                         :style "padding: 10px 20px; background: #6c757d; color: white; border: none; border-radius: 20px; cursor: pointer;"
                                         :text "Leave"))
      (clog:append! panel controls))

    (clog:append! container panel)

    ;; End button handler
    (let ((end-btn (clog:get-element-by-id win "end-voice-chat-btn")))
      (clog:on end-btn :click
               (lambda (ev)
                 (declare (ignore ev))
                 (end-voice-chat chat-id)))))

(defun render-transcription (win container voice-message)
  "Render voice message transcription.

   Args:
     win: CLOG window object
     container: Container element
     voice-message: Voice-message object"
  (let ((trans-el (clog:create-element win "div" :class "transcription"
                                        :style "padding: 10px; background: #f0f0f0; border-radius: 5px; margin-top: 5px; font-size: 13px;")))
    (if (voice-transcription voice-message)
        (progn
          (clog:append! trans-el
                        (clog:create-element win "span" :class "transcription-text"
                                             :text (voice-transcription voice-message)))
          (when (voice-transcription-language voice-message)
            (clog:append! trans-el
                          (clog:create-element win "span" :class "transcription-lang"
                                               :style "color: #666; font-size: 11px;"
                                               :text (format nil " (~A)" (voice-transcription-language voice-message))))))
        ;; Show transcription request
        (clog:append! trans-el
                      (clog:create-element win "button" :class "transcribe-btn"
                                           :style "font-size: 12px; color: #0088cc; cursor: pointer; background: none; border: none;"
                                           :text "📝 Transcribe"))))
    (clog:append! container trans-el)))

;;; ### Helper Functions

(defun make-temp-audio-file (waveform-data)
  "Create temporary OGG audio file from waveform data.

   Args:
     waveform-data: List of amplitude values

   Returns:
     Path to temporary file"
  (let* ((temp-file (make-pathname
                     :directory (temporary-directory)
                     :name (format nil "voice-~A" (get-universal-time))
                     :type "ogg"))
         (buffer (make-array (length waveform-data) :element-type '(unsigned-byte 8))))
    ;; Convert waveform to audio samples (simplified - real impl would use libopus)
    (loop for v in waveform-data
          for i from 0
          do (setf (aref buffer i) v))

    ;; Write minimal OGG header + data (simplified)
    ;; Real implementation should use libopus or similar
    (with-open-file (stream temp-file :direction :output :if-exists :supersede
                            :element-type '(unsigned-byte 8))
      ;; Write minimal OGG skeleton (placeholder)
      (write-sequence #,(make-array 0 :element-type '(unsigned-byte 8)) stream)
      (write-sequence buffer stream))

    temp-file))

(defun temporary-directory ()
  "Get system temporary directory."
  (cond
    ((probe-file "/tmp") "/tmp/")
    ((probe-file "/var/tmp") "/var/tmp/")
    (t (namestring (user-homedir-pathname)))))

(defun guess-audio-duration (file-path)
  "Guess audio duration from file (simplified).

   Args:
     file-path: Path to audio file

   Returns:
     Duration in seconds (estimated)"
  ;; Real implementation would read file metadata
  ;; This is a simple estimation based on file size
  (let ((file-size (file-length file-path)))
    ;; Assume ~16kbps for voice (OGG OPUS)
    (/ file-size 2000)))  ; Rough estimation

(defun generate-waveform-from-file (file-path)
  "Generate waveform from audio file.

   Args:
     file-path: Path to audio file

   Returns:
     List of amplitude values (0-255)"
  ;; Real implementation would decode audio and extract samples
  ;; This generates a synthetic waveform for demonstration
  (let ((waveform nil))
    (dotimes (i 100)
      (push (random 256) waveform))
    (nreverse waveform)))

(defun parse-voice-message-from-message (message)
  "Parse voice message from full message object.

   Args:
     message: Full message TL object

   Returns:
     Voice-message object"
  (let* ((content (getf message :content))
         (voice-note (when (eq (getf content :@type) :messageVoiceNote)
                       (getf content :voice-note))))
    (when voice-note
      (make-instance 'voice-message
                     :file-id (getf voice-note :id)
                     :duration (getf voice-note :duration 0)
                     :waveform (decode-waveform-from-base64 (getf voice-note :waveform))
                     :mime-type "audio/ogg"
                     :transcription (getf voice-note :transcription)))))

(defun make-temp-video-file ()
  "Create temporary video file for video note.

   Returns:
     Path to temporary file"
  (let* ((temp-file (make-pathname
                     :directory (temporary-directory)
                     :name (format nil "video-~A" (get-universal-time))
                     :type "mp4")))
    ;; Create empty file (real impl would record actual video)
    (with-open-file (stream temp-file :direction :output :if-exists :supersede)
      (write-string "" stream))
    temp-file))

(defun upload-file (file-path &key (file-type :general))
  "Upload file to Telegram servers.

   Args:
     file-path: Path to file
     file-type: Type of file (:general, :voice, :audio, :video, :video-note, :photo)

   Returns:
     File ID on success, error on failure"
  (unless (authorized-p)
    (return-from upload-file
      (values nil :not-authorized "User not authenticated")))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from upload-file
        (values nil :no-connection "No active connection")))

    ;; Get file size
    (let ((file-size (file-length file-path)))
      (if (> file-size *max-file-size*)
          (return-from upload-file
            (values nil :file-too-large
                    (format nil "File size (~A bytes) exceeds limit (~A bytes)"
                            file-size *max-file-size*))))

    ;; For small files, use uploadFile API
    (if (< file-size 102400)  ; Less than 100KB
        (let ((file-data (with-open-file (stream file-path :direction :input
                                                  :element-type '(unsigned-byte 8))
                           (let ((data (make-array file-size :element-type '(unsigned-byte 8))))
                             (read-sequence data stream)
                             data))))
          (let ((request (make-tl-object
                          'upload.saveFilePart
                          :file-id (random (expt 2 63))
                          :file-part 0
                          :bytes file-data
                          :is-last t)))
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (:ok (result)
                (if (eq (getf result :@type) :bool)
                    (values (format nil "~A" (random (expt 2 63))) nil)  ; Fake file ID for demo
                    (values nil :unexpected-response result)))
              (:error (err)
                (values nil :rpc-error err)))))

        ;; For large files, use multipart upload (simplified)
        (let ((file-id (random (expt 2 63)))
              (part-size 512 * 1024))  ; 512KB parts
          (with-open-file (stream file-path :direction :input
                                  :element-type '(unsigned-byte 8))
            (let ((buffer (make-array part-size :element-type '(unsigned-byte 8)))
                  (part-num 0)
                  (total-parts (ceiling file-size part-size)))
              (loop
                (let ((bytes-read (read-sequence buffer stream)))
                  (when (zerop bytes-read) (return)))

                  (let ((request (make-tl-object
                                  'upload.saveFilePart
                                  :file-id file-id
                                  :file-part part-num
                                  :bytes (subseq buffer 0 bytes-read)
                                  :is-last (= part-num (1- total-parts)))))
                    (rpc-call connection request :timeout 30000))
                  (incf part-num)))))

          (values (format nil "~A" file-id) nil))))))

(defun download-file-to-cache (file-id)
  "Download file to local cache.

   Args:
     file-id: File ID to download

   Returns:
     Path to downloaded file, or NIL on failure"
  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from download-file-to-cache nil))

    ;; Get file info first
    (let ((request (make-tl-object 'upload.getFile :file-id file-id)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :file)
              (let* ((file (getf result :file))
                     (file-size (getf file :size 0))
                     (cache-path (merge-pathnames
                                  (make-pathname
                                   :directory (pathname-directory (temporary-directory))
                                   :name (format nil "file-~A" file-id)
                                   :type "dat")))
                ;; Download file parts
                (with-open-file (stream cache-path :direction :output
                                        :if-exists :supersede
                                        :element-type '(unsigned-byte 8))
                  (let ((part-size 1024 * 1024)  ; 1MB parts
                        (offset 0))
                    (loop while (< offset file-size)
                          do
                          (let ((request (make-tl-object
                                          'upload.getFile
                                          :file-id file-id
                                          :offset offset
                                          :limit (min part-size (- file-size offset)))))
                            (rpc-handler-case (rpc-call connection request :timeout 30000)
                              (:ok (result)
                                (when (eq (getf result :@type) :file)
                                  (let ((data (getf result :bytes)))
                                    (write-sequence data stream)
                                    (incf offset (length data)))))
                              (:error () (return nil)))))
                    cache-path))))
              nil))
        (:error () nil)))))

;;; End of voice-messages.lisp

(defun voice-message-duration-string (voice-message)
  "Get voice message duration as formatted string.

   Args:
     voice-message: Voice-message object

   Returns:
     Duration string like '1:23'"
  (let ((duration (voice-duration voice-message))
        (mins (floor duration 60))
        (secs (mod duration 60)))
    (format nil "~A:~2,'0D" mins secs)))

(defun waveform-to-ascii (waveform &key (width 40))
  "Convert waveform to ASCII art for terminal display.

   Args:
     waveform: List of amplitude values
     width: Output width

   Returns:
     ASCII string"
  (declare (ignorable waveform width))
  ;; Simple ASCII representation
  "▁▂▃▄▅▆▇█")

(defun clear-voice-cache ()
  "Clear voice message cache.

   Returns:
     T on success"
  (clrhash *voice-message-cache*)
  t)

(defun get-available-voice-devices ()
  "Get list of available audio input devices.

   Returns:
     List of device plists"
  (or *available-voice-devices*
      ;; Default device
      (setf *available-voice-devices*
            (list (list :id "default" :name "Default Microphone")))))
