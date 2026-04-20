;;; group-video-call.lisp --- Group video call enhancements for cl-telegram
;;;
;;; Provides advanced group video call features including:
;;; - Multi-participant video streaming (10+ users)
;;; - Screen sharing support
;;; - Adaptive video quality
;;; - Call recording
;;; - AI noise reduction
;;;
;;; Version: 0.26.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Video Stream Class
;;; ============================================================================

(defclass group-video-stream ()
  ((stream-id :initarg :stream-id :reader stream-id)
   (group-call-id :initarg :group-call-id :accessor stream-group-call-id)
   (participant-id :initarg :participant-id :accessor stream-participant-id)
   (state :initform :inactive :accessor stream-state)
   (resolution :initform :hd :accessor stream-resolution)
   (fps :initform 30 :accessor stream-fps)
   (bitrate :initform 2500000 :accessor stream-bitrate)
   (is-screen-share :initform nil :accessor stream-is-screen-share)
   (is-speaking :initform nil :accessor stream-is-speaking)
   (audio-level :initform 0.0 :accessor stream-audio-level)
   (connection-stats :initform nil :accessor stream-connection-stats)
   (webrtc-handle :initform nil :accessor stream-webrtc-handle)))

(defun make-group-video-stream (group-call-id participant-id &key (stream-id nil))
  "Create a new group video stream.

   GROUP-CALL-ID: The group call identifier
   PARTICIPANT-ID: The participant's user ID
   STREAM-ID: Optional stream ID (auto-generated if nil)

   Returns:
     group-video-stream instance"
  (let ((sid (or stream-id (format nil "~A-~A" group-call-id (get-universal-time)))))
    (make-instance 'group-video-stream
                   :stream-id sid
                   :group-call-id group-call-id
                   :participant-id participant-id)))

;;; ============================================================================
;;; Video Layout Class
;;; ============================================================================

(defclass video-layout ()
  ((layout-type :initform :grid :accessor layout-type)
   (participants :initform nil :accessor layout-participants)
   (pinned-participant :initform nil :accessor layout-pinned)
   (active-speaker :initform nil :accessor layout-active-speaker)
   (grid-columns :initform 3 :accessor layout-columns)
   (grid-rows :initform 2 :accessor layout-rows)
   (last-updated :initform nil :accessor layout-last-updated)))

(defun make-video-layout (&key (type :grid))
  "Create a new video layout.

   TYPE: Layout type (:grid, :speaker, :spotlight)

   Returns:
     video-layout instance"
  (let ((layout (make-instance 'video-layout :layout-type type)))
    (case type
      (:grid
       (setf (layout-columns layout) 3
             (layout-rows layout) 2))
      (:speaker
       (setf (layout-columns layout) 1
             (layout-rows layout) 4))
      (:spotlight
       (setf (layout-columns layout) 2
             (layout-rows layout) 2)))
    layout))

(defun update-video-layout (layout participant-id &key (action :add) (pin nil))
  "Update video layout with participant.

   LAYOUT: The video-layout instance
   PARTICIPANT-ID: Participant to add/remove
   ACTION: :add, :remove, or :update
   PIN: Whether to pin this participant

   Returns:
     T on success"
  (case action
    (:add
     (unless (member participant-id (layout-participants layout))
       (push participant-id (layout-participants layout))))
    (:remove
     (setf (layout-participants layout)
           (remove participant-id (layout-participants layout)))
     (when (eql (layout-pinned layout) participant-id)
       (setf (layout-pinned layout) nil)))
    (:update
     (setf (layout-active-speaker layout) participant-id)))
  (when pin
    (setf (layout-pinned layout) participant-id))
  (setf (layout-last-updated layout) (get-universal-time))
  t)

(defun get-layout-grid (layout participant-count)
  "Calculate optimal grid dimensions for participant count.

   LAYOUT: The video-layout instance
   PARTICIPANT-COUNT: Number of participants

   Returns:
     (values columns rows)"
  (let* ((cols (ceiling (sqrt participant-count)))
         (rows (ceiling (/ participant-count cols))))
    (values cols rows)))

;;; ============================================================================
;;; Group Video Call Manager
;;; ============================================================================

(defclass group-video-manager ()
  ((active-streams :initform (make-hash-table :test 'equal) :accessor video-manager-streams)
   (active-layouts :initform (make-hash-table :test 'equal) :accessor video-manager-layouts)
   (recording-streams :initform (make-hash-table :test 'equal) :accessor video-manager-recordings)
   (screen-share-streams :initform (make-hash-table :test 'equal) :accessor video-manager-screen-shares)
   (quality-settings :initform (make-hash-table :test 'equal) :accessor video-manager-quality-settings)
   (noise-reduction-enabled :initform (make-hash-table :test 'equal) :accessor video-manager-noise-reduction)
   (stats-history :initform (make-hash-table :test 'equal) :accessor video-manager-stats)
   (max-participants :initform 10 :accessor video-manager-max-participants)
   (default-quality :initform :hd :accessor video-manager-default-quality)
   (recording-directory :initform nil :accessor video-manager-recording-dir)))

(defvar *group-video-manager* nil
  "Global group video manager instance")

(defun make-group-video-manager ()
  "Create a new group video manager instance.

   Returns:
     group-video-manager instance"
  (make-instance 'group-video-manager))

(defun init-group-video (&key (max-participants 10) (default-quality :hd)
                               (recording-dir nil))
  "Initialize group video subsystem.

   MAX-PARTICIPANTS: Maximum participants in group video call
   DEFAULT-QUALITY: Default video quality (:ld :sd :hd :fhd)
   RECORDING-DIR: Directory for call recordings

   Returns:
     T on success"
  (unless *group-video-manager*
    (setf *group-video-manager* (make-group-video-manager))
    (setf (video-manager-max-participants *group-video-manager*) max-participants)
    (setf (video-manager-default-quality *group-video-manager*) default-quality)
    (setf (video-manager-recording-dir *group-video-manager*)
          (or recording-dir (namestring (merge-pathnames "recordings/" (user-homedir-pathname)))))
    ;; Ensure recording directory exists
    (unless (probe-file (video-manager-recording-dir *group-video-manager*))
      (ensure-directories-exist (video-manager-recording-dir *group-video-manager*)))
    (format t "Group video initialized (max: ~D participants, quality: ~A)~%"
            max-participants default-quality))
  t)

(defun shutdown-group-video ()
  "Shutdown group video subsystem.

   Returns:
     T on success"
  (when *group-video-manager*
    ;; Stop all active streams
    (maphash (lambda (stream-id stream)
               (declare (ignore stream-id))
               (stop-group-video-stream (stream-group-call-id stream)))
             (video-manager-streams *group-video-manager*))
    (setf *group-video-manager* nil))
  t)

;;; ============================================================================
;;; Video Quality Presets
;;; ============================================================================

(defparameter *video-quality-presets*
  '((:ld . (:width 176 :height 144 :bitrate 100000 :fps 15))
    (:sd . (:width 640 :height 480 :bitrate 500000 :fps 20))
    (:hd . (:width 1280 :height 720 :bitrate 2500000 :fps 30))
    (:fhd . (:width 1920 :height 1080 :bitrate 5000000 :fps 30))
    (:screen . (:width 1920 :height 1080 :bitrate 8000000 :fps 15))))

(defun get-quality-preset (quality)
  "Get video quality preset parameters.

   QUALITY: Quality keyword (:ld, :sd, :hd, :fhd, :screen)

   Returns:
     Plist with :width, :height, :bitrate, :fps"
  (cdr (assoc quality *video-quality-presets*)))

(defun calculate-adaptive-quality (bandwidth-kbps &key (min-quality :ld) (max-quality :hd))
  "Calculate optimal video quality based on available bandwidth.

   BANDWIDTH-KBPS: Available bandwidth in kbps
   MIN-QUALITY: Minimum quality to use
   MAX-QUALITY: Maximum quality to use

   Returns:
     Quality keyword"
  (let* ((presets *video-quality-presets*)
         (quality-order '(:ld :sd :hd :fhd))
         (min-idx (position min-quality quality-order))
         (max-idx (position max-quality quality-order)))
    (dolist (preset presets :sd)
      (let* ((q (car preset))
             (params (cdr preset))
             (required-bitrate (/ (getf params :bitrate) 1000)))
        (when (and (<= required-bitrate bandwidth-kbps)
                   (let ((idx (position q quality-order)))
                     (and (>= idx min-idx) (<= idx max-idx))))
          (return-from calculate-adaptive-quality q))))))

;;; ============================================================================
;;; Core Video Stream Functions
;;; ============================================================================

(defun start-group-video-stream (group-call-id &key (resolution :hd) (fps 30)
                                                    (participant-id nil))
  "Start video streaming in group call.

   GROUP-CALL-ID: The group call identifier
   RESOLUTION: Video resolution (:ld, :sd, :hd, :fhd)
   FPS: Frames per second (15-60)
   PARTICIPANT-ID: Participant ID (auto-detected if nil)

   Returns:
     (values stream-id error)"
  (unless *group-video-manager*
    (init-group-video))

  ;; Check participant limit
  (let ((current-count (hash-table-count (video-manager-streams *group-video-manager*))))
    (when (>= current-count (video-manager-max-participants *group-video-manager*))
      (return-from start-group-video-stream
        (values nil :max-participants-reached
                (format nil "Maximum ~D participants reached"
                        (video-manager-max-participants *group-video-manager*))))))

  (let ((pid (or participant-id (getf (get-me) :id))))
    (unless pid
      (return-from start-group-video-stream
        (values nil :not-authenticated "User not authenticated")))

    ;; Create video stream
    (let ((stream (make-group-video-stream group-call-id pid)))
      (setf (stream-resolution stream) resolution)
      (setf (stream-fps stream) fps)

      ;; Get quality preset
      (let ((preset (get-quality-preset resolution)))
        (when preset
          (setf (stream-bitrate stream) (getf preset :bitrate))))

      ;; Initialize WebRTC stream if available
      (if (and (fboundp 'create-webrtc-media-stream)
               (fboundp 'init-webrtc))
          (progn
            (init-webrtc)
            (let ((success (create-webrtc-media-stream
                            :audio t
                            :video t
                            :video-bitrate (stream-bitrate stream)
                            :video-fps fps)))
              (if success
                  (progn
                    (setf (stream-webrtc-handle stream) t)
                    (setf (stream-state stream) :active))
                  (return-from start-group-video-stream
                    (values nil :webrtc-init-failed "Failed to initialize WebRTC")))))
          ;; Fallback: mock stream for testing
          (setf (stream-state stream) :active))

      ;; Store stream
      (setf (gethash (stream-id stream)
                     (video-manager-streams *group-video-manager*))
            stream)

      ;; Update layout
      (let ((layout (gethash group-call-id (video-manager-layouts *group-video-manager*))))
        (unless layout
          (setf layout (make-video-layout :type :grid))
          (setf (gethash group-call-id (video-manager-layouts *group-video-manager*)) layout))
        (update-video-layout layout pid :action :add))

      (format t "Started video stream: ~A (resolution: ~A, fps: ~D)~%"
              (stream-id stream) resolution fps)
      (values (stream-id stream) nil))))

(defun stop-group-video-stream (group-call-id &key (participant-id nil))
  "Stop video streaming in group call.

   GROUP-CALL-ID: The group call identifier
   PARTICIPANT-ID: Participant ID (current user if nil)

   Returns:
     (values t error)"
  (unless *group-video-manager*
    (return-from stop-group-video-stream
      (values nil :not-initialized "Group video not initialized")))

  (let ((pid (or participant-id (getf (get-me) :id))))
    (unless pid
      (return-from stop-group-video-stream
        (values nil :not-authenticated "User not authenticated")))

    ;; Find and stop stream
    (let ((stream nil))
      (maphash (lambda (sid s)
                 (declare (ignore sid))
                 (when (and (eql (stream-group-call-id s) group-call-id)
                            (eql (stream-participant-id s) pid))
                   (setf stream s)))
               (video-manager-streams *group-video-manager*))

      (unless stream
        (return-from stop-group-video-stream
          (values nil :stream-not-found "No active stream found")))

      ;; Stop WebRTC if active
      (when (and (stream-webrtc-handle stream)
                 (fboundp 'close-webrtc-media-stream))
        (close-webrtc-media-stream))

      ;; Update layout
      (let ((layout (gethash group-call-id (video-manager-layouts *group-video-manager*))))
        (when layout
          (update-video-layout layout pid :action :remove)))

      ;; Remove from screen shares if present
      (remhash group-call-id (video-manager-screen-shares *group-video-manager*))

      ;; Remove stream
      (let ((sid (stream-id stream)))
        (remhash sid (video-manager-streams *group-video-manager*))
        (setf (stream-state stream) :inactive))

      (format t "Stopped video stream: ~A~%" (stream-id stream))
      (values t nil))))

;;; ============================================================================
;;; Screen Sharing
;;; ============================================================================

(defun enable-screen-sharing (group-call-id &key (capture-window nil)
                                                  (capture-monitor nil)
                                                  (quality :screen))
  "Enable screen sharing in group call.

   GROUP-CALL-ID: The group call identifier
   CAPTURE-WINDOW: Specific window to capture (nil for full screen)
   CAPTURE-MONITOR: Monitor ID for multi-monitor setups (nil for primary)
   QUALITY: Screen sharing quality preset

   Returns:
     (values stream-id error)"
  (unless *group-video-manager*
    (return-from enable-screen-sharing
      (values nil :not-initialized "Group video not initialized")))

  ;; Check if already sharing
  (when (gethash group-call-id (video-manager-screen-shares *group-video-manager*))
    (return-from enable-screen-sharing
      (values nil :already-sharing "Screen sharing already active")))

  ;; Start screen share stream
  (multiple-value-bind (stream-id error)
      (start-group-video-stream group-call-id
                                :resolution quality
                                :fps 15
                                :participant-id (getf (get-me) :id))
    (when error
      (return-from enable-screen-sharing (values nil error)))

    ;; Get stream and mark as screen share
    (let ((stream (gethash stream-id (video-manager-streams *group-video-manager*))))
      (when stream
        (setf (stream-is-screen-share stream) t)
        (setf (stream-state stream) :screen-sharing)

        ;; Store in screen share hash
        (setf (gethash group-call-id (video-manager-screen-shares *group-video-manager*))
              stream)

        ;; Enable screen capture in WebRTC (if available)
        (when (and (fboundp '%enable-screen-capture)
                   (stream-webrtc-handle stream))
          (let ((source-type (if capture-window 1 0)))
            (%enable-screen-capture (stream-webrtc-handle stream) source-type)))

        (format t "Screen sharing enabled: ~A~%" stream-id)
        (values stream-id nil)))))

(defun disable-screen-sharing (group-call-id)
  "Disable screen sharing in group call.

   GROUP-CALL-ID: The group call identifier

   Returns:
     (values t error)"
  (let ((stream (gethash group-call-id (video-manager-screen-shares *group-video-manager*))))
    (unless stream
      (return-from disable-screen-sharing
        (values nil :not-sharing "Screen sharing not active")))

    ;; Switch back to normal video
    (setf (stream-is-screen-share stream) nil)
    (setf (stream-state stream) :active)
    (setf (stream-resolution stream) :hd)

    ;; Remove from screen share hash
    (remhash group-call-id (video-manager-screen-shares *group-video-manager*))

    (format t "Screen sharing disabled: ~A~%" (stream-id stream))
    (values t nil)))

(defun get-screen-share-streams (group-call-id)
  "Get all active screen share streams in group call.

   GROUP-CALL-ID: The group call identifier

   Returns:
     List of stream objects"
  (let ((result nil))
    (maphash (lambda (sid stream)
               (declare (ignore sid))
               (when (and (eql (stream-group-call-id stream) group-call-id)
                          (stream-is-screen-share stream))
                 (push stream result)))
             (video-manager-streams *group-video-manager*))
    result))

;;; ============================================================================
;;; Video Quality Control
;;; ============================================================================

(defun set-video-quality (group-call-id quality &key (participant-id nil))
  "Set video quality for group call stream.

   GROUP-CALL-ID: The group call identifier
   QUALITY: Quality keyword (:auto, :ld, :sd, :hd, :fhd)
   PARTICIPANT-ID: Target participant (current user if nil)

   Returns:
     (values t error)"
  (unless *group-video-manager*
    (return-from set-video-quality
      (values nil :not-initialized "Group video not initialized")))

  (let ((pid (or participant-id (getf (get-me) :id))))
    (unless pid
      (return-from set-video-quality
        (values nil :not-authenticated "User not authenticated")))

    ;; Find stream
    (let ((stream nil))
      (maphash (lambda (sid s)
                 (declare (ignore sid))
                 (when (and (eql (stream-group-call-id s) group-call-id)
                            (eql (stream-participant-id s) pid))
                   (setf stream s)))
               (video-manager-streams *group-video-manager*))

      (unless stream
        (return-from set-video-quality
          (values nil :stream-not-found "No active stream found")))

      ;; Handle auto quality
      (let ((final-quality quality))
        (when (eql quality :auto)
          ;; Estimate bandwidth from connection stats
          (let ((estimated-bandwidth 5000)) ; Default 5 Mbps
            (setf final-quality (calculate-adaptive-quality estimated-bandwidth))))

        ;; Update stream quality
        (let ((preset (get-quality-preset final-quality)))
          (when preset
            (setf (stream-resolution stream) final-quality)
            (setf (stream-bitrate stream) (getf preset :bitrate))
            (setf (stream-fps stream) (getf preset :fps))

            ;; Apply WebRTC quality change if available
            (when (and (fboundp '%set-video-quality)
                       (stream-webrtc-handle stream))
              (%set-video-quality (stream-webrtc-handle stream)
                                  (getf preset :width)
                                  (getf preset :height)
                                  (getf preset :bitrate)
                                  (getf preset :fps)))

            ;; Store quality setting
            (setf (gethash (stream-id stream)
                           (video-manager-quality-settings *group-video-manager*))
                  final-quality)

            (format t "Video quality set to ~A for stream ~A~%"
                    final-quality (stream-id stream))
            (values t nil)))))))

(defun get-video-quality (group-call-id &key (participant-id nil))
  "Get current video quality for a participant.

   GROUP-CALL-ID: The group call identifier
   PARTICIPANT-ID: Target participant (current user if nil)

   Returns:
     Quality keyword or NIL"
  (let ((pid (or participant-id (getf (get-me) :id))))
    (when pid
      (maphash (lambda (sid s)
                 (declare (ignore sid))
                 (when (and (eql (stream-group-call-id s) group-call-id)
                            (eql (stream-participant-id s) pid))
                   (return-from get-video-quality (stream-resolution s))))
               (video-manager-streams *group-video-manager*)))
    nil))

;;; ============================================================================
;;; Video Layout Management
;;; ============================================================================

(defun get-group-video-layout (group-call-id)
  "Get current video layout for group call.

   GROUP-CALL-ID: The group call identifier

   Returns:
     Layout plist with :type, :participants, :pinned, :active-speaker, :columns, :rows"
  (let ((layout (gethash group-call-id (video-manager-layouts *group-video-manager*))))
    (if layout
        (list :type (layout-type layout)
              :participants (layout-participants layout)
              :pinned (layout-pinned layout)
              :active-speaker (layout-active-speaker layout)
              :columns (layout-columns layout)
              :rows (layout-rows layout))
        (list :type :grid
              :participants nil
              :pinned nil
              :active-speaker nil
              :columns 3
              :rows 2))))

(defun pin-participant-video (group-call-id participant-id)
  "Pin participant video to prominent position.

   GROUP-CALL-ID: The group call identifier
   PARTICIPANT-ID: Participant to pin

   Returns:
     (values t error)"
  (let ((layout (gethash group-call-id (video-manager-layouts *group-video-manager*))))
    (unless layout
      (return-from pin-participant-video
        (values nil :no-layout "No layout found")))

    (unless (member participant-id (layout-participants layout))
      (return-from pin-participant-video
        (values nil :participant-not-in-call "Participant not in call")))

    (update-video-layout layout participant-id :pin t)
    (format t "Pinned participant ~A in call ~A~%" participant-id group-call-id)
    (values t nil)))

(defun unpin-participant-video (group-call-id participant-id)
  "Unpin participant video.

   GROUP-CALL-ID: The group call identifier
   PARTICIPANT-ID: Participant to unpin

   Returns:
     (values t error)"
  (let ((layout (gethash group-call-id (video-manager-layouts *group-video-manager*))))
    (unless layout
      (return-from unpin-participant-video
        (values nil :no-layout "No layout found")))

    (update-video-layout layout participant-id :pin nil)
    (format t "Unpinned participant ~A in call ~A~%" participant-id group-call-id)
    (values t nil)))

(defun set-video-layout-type (group-call-id type)
  "Set video layout type.

   GROUP-CALL-ID: The group call identifier
   TYPE: Layout type (:grid, :speaker, :spotlight)

   Returns:
     (values t error)"
  (let ((layout (gethash group-call-id (video-manager-layouts *group-video-manager*))))
    (unless layout
      (setf layout (make-video-layout :type type))
      (setf (gethash group-call-id (video-manager-layouts *group-video-manager*)) layout))

    (setf (layout-type layout) type)
    (case type
      (:grid
       (setf (layout-columns layout) 3
             (layout-rows layout) 2))
      (:speaker
       (setf (layout-columns layout) 1
             (layout-rows layout) 4))
      (:spotlight
       (setf (layout-columns layout) 2
             (layout-rows layout) 2)))

    (format t "Layout type set to ~A for call ~A~%" type group-call-id)
    (values t nil)))

;;; ============================================================================
;;; Call Recording
;;; ============================================================================

(defun toggle-group-call-recording (group-call-id &key (output-path nil))
  "Toggle call recording.

   GROUP-CALL-ID: The group call identifier
   OUTPUT-PATH: Custom output path (auto-generated if nil)

   Returns:
     (values recording-path error)"
  (unless *group-video-manager*
    (return-from toggle-group-call-recording
      (values nil :not-initialized "Group video not initialized")))

  ;; Check if already recording
  (let ((existing (gethash group-call-id (video-manager-recordings *group-video-manager*))))
    (when existing
      ;; Stop recording
      (stop-group-call-recording group-call-id)
      (return-from toggle-group-call-recording
        (values nil :recording-stopped "Recording stopped"))))

  ;; Start recording
  (let* ((timestamp (format-time-string "~Y~m~d_~H~M~S"))
         (default-path (format nil "~Acall_~A_~A.mkv"
                               (video-manager-recording-dir *group-video-manager*)
                               group-call-id timestamp))
         (recording-path (or output-path default-path)))

    ;; Ensure directory exists
    (ensure-directories-exist recording-path)

    ;; Get all active streams for this call
    (let ((streams nil))
      (maphash (lambda (sid stream)
                 (declare (ignore sid))
                 (when (eql (stream-group-call-id stream) group-call-id)
                   (push stream streams)))
               (video-manager-streams *group-video-manager*))

      (when (null streams)
        (return-from toggle-group-call-recording
          (values nil :no-active-streams "No active streams to record")))

      ;; Start WebRTC recording if available
      (let ((recording-started nil))
        (when (fboundp '%start-recording)
          (dolist (stream streams)
            (when (stream-webrtc-handle stream)
              (%start-recording (stream-webrtc-handle stream) recording-path)
              (setf recording-started t))))

        ;; Store recording info
        (setf (gethash group-call-id (video-manager-recordings *group-video-manager*))
              (list :path recording-path
                    :streams streams
                    :start-time (get-universal-time)
                    :active t))

        (format t "Started recording call ~A to ~A~%" group-call-id recording-path)
        (values recording-path nil)))))

(defun stop-group-call-recording (group-call-id)
  "Stop call recording.

   GROUP-CALL-ID: The group call identifier

   Returns:
     (values recording-path duration error)"
  (let ((recording (gethash group-call-id (video-manager-recordings *group-video-manager*))))
    (unless recording
      (return-from stop-group-call-recording
        (values nil nil :not-recording "Call not being recorded")))

    ;; Stop WebRTC recording if available
    (when (fboundp '%stop-recording)
      (dolist (stream (getf recording :streams))
        (when (stream-webrtc-handle stream)
          (%stop-recording (stream-webrtc-handle stream)))))

    ;; Calculate duration
    (let* ((start-time (getf recording :start-time))
           (end-time (get-universal-time))
           (duration (- end-time start-time)))

      ;; Update recording info
      (setf (getf recording :active) nil)
      (setf (getf recording :end-time) end-time)
      (setf (getf recording :duration) duration)

      ;; Remove from active recordings
      (remhash group-call-id (video-manager-recordings *group-video-manager*))

      (format t "Stopped recording call ~A (duration: ~D seconds)~%"
              group-call-id duration)
      (values (getf recording :path) duration nil))))

(defun get-group-call-recording (group-call-id)
  "Get recording info for a group call.

   GROUP-CALL-ID: The group call identifier

   Returns:
     Recording plist or NIL"
  ;; Check active recordings
  (let ((recording (gethash group-call-id (video-manager-recordings *group-video-manager*))))
    (when recording
      (return-from get-group-call-recording
        (list :path (getf recording :path)
              :active t
              :start-time (getf recording :start-time)))))
  ;; Check completed recordings (would be stored in database in production)
  nil)

;;; ============================================================================
;;; AI Noise Reduction
;;; ============================================================================

(defun enable-ai-noise-reduction (group-call-id &key (level :auto)
                                                    (participant-id nil))
  "Enable AI noise reduction for group call.

   GROUP-CALL-ID: The group call identifier
   LEVEL: Noise reduction level (:auto, :off, :low, :medium, :high)
   PARTICIPANT-ID: Target participant (current user if nil)

   Returns:
     (values t error)"
  (unless *group-video-manager*
    (return-from enable-ai-noise-reduction
      (values nil :not-initialized "Group video not initialized")))

  (let ((pid (or participant-id (getf (get-me) :id))))
    (unless pid
      (return-from enable-ai-noise-reduction
        (values nil :not-authenticated "User not authenticated")))

    ;; Find stream
    (let ((stream nil))
      (maphash (lambda (sid s)
                 (declare (ignore sid))
                 (when (and (eql (stream-group-call-id s) group-call-id)
                            (eql (stream-participant-id s) pid))
                   (setf stream s)))
               (video-manager-streams *group-video-manager*))

      (unless stream
        (return-from enable-ai-noise-reduction
          (values nil :stream-not-found "No active stream found")))

      ;; Map level to numeric value
      (let ((noise-level (case level
                           (:off 0.0)
                           (:low 0.3)
                           (:medium 0.6)
                           (:high 0.9)
                           (:auto 0.6)
                           (otherwise 0.6))))

        ;; Enable in WebRTC if available
        (when (and (fboundp '%enable-noise-suppression)
                   (stream-webrtc-handle stream))
          (%enable-noise-suppression (stream-webrtc-handle stream) noise-level))

        ;; Store setting
        (setf (gethash (stream-id stream)
                       (video-manager-noise-reduction *group-video-manager*))
              level)

        (format t "AI noise reduction enabled (~A) for stream ~A~%"
                level (stream-id stream))
        (values t nil)))))

(defun disable-ai-noise-reduction (group-call-id &key (participant-id nil))
  "Disable AI noise reduction.

   GROUP-CALL-ID: The group call identifier
   PARTICIPANT-ID: Target participant (current user if nil)

   Returns:
     (values t error)"
  (enable-ai-noise-reduction group-call-id :level :off :participant-id participant-id))

;;; ============================================================================
;;; Statistics and Monitoring
;;; ============================================================================

(defun get-group-video-stats (group-call-id)
  "Get statistics for group video call.

   GROUP-CALL-ID: The group call identifier

   Returns:
     Statistics plist"
  (let ((streams nil)
        (layout (gethash group-call-id (video-manager-layouts *group-video-manager*)))
        (recording (gethash group-call-id (video-manager-recordings *group-video-manager*))))

    ;; Collect stream stats
    (maphash (lambda (sid stream)
               (declare (ignore sid))
               (when (eql (stream-group-call-id stream) group-call-id)
                 (push (list :stream-id (stream-id stream)
                             :participant (stream-participant-id stream)
                             :state (stream-state stream)
                             :resolution (stream-resolution stream)
                             :fps (stream-fps stream)
                             :bitrate (stream-bitrate stream)
                             :is-screen-share (stream-is-screen-share stream))
                       streams)))
             (video-manager-streams *group-video-manager*))

    (list :group-call-id group-call-id
          :stream-count (length streams)
          :streams streams
          :layout (if layout
                      (list :type (layout-type layout)
                            :participants (layout-participants layout)
                            :pinned (layout-pinned layout))
                      nil)
          :is-recording (and recording (getf recording :active))
          :recording-path (when recording (getf recording :path)))))

(defun get-participant-video-stats (group-call-id participant-id)
  "Get video statistics for a specific participant.

   GROUP-CALL-ID: The group call identifier
   PARTICIPANT-ID: The participant ID

   Returns:
     Statistics plist"
  (maphash (lambda (sid stream)
             (declare (ignore sid))
             (when (and (eql (stream-group-call-id stream) group-call-id)
                        (eql (stream-participant-id stream) participant-id))
               (return-from get-participant-video-stats
                 (list :stream-id (stream-id stream)
                       :state (stream-state stream)
                       :resolution (stream-resolution stream)
                       :fps (stream-fps stream)
                       :bitrate (stream-bitrate stream)
                       :is-screen-share (stream-is-screen-share stream)
                       :is-speaking (stream-is-speaking stream)
                       :audio-level (stream-audio-level stream)))))
           (video-manager-streams *group-video-manager*))
  nil)

;;; ============================================================================
;;; Integration with Group Call System
;;; ============================================================================

(defun on-group-call-video-joined (group-call-id)
  "Callback when user joins a group call with video.

   GROUP-CALL-ID: The group call identifier

   Returns:
     T on success"
  ;; Auto-start video if enabled in settings
  (let ((auto-start-video t)) ; Would come from settings
    (when auto-start-video
      (start-group-video-stream group-call-id :resolution :hd)))
  t)

(defun on-group-call-left (group-call-id)
  "Callback when user leaves a group call.

   GROUP-CALL-ID: The group call identifier

   Returns:
     T on success"
  ;; Stop video if active
  (stop-group-video-stream group-call-id)
  ;; Stop screen sharing if active
  (when (gethash group-call-id (video-manager-screen-shares *group-video-manager*))
    (disable-screen-sharing group-call-id))
  t)

;;; Export symbols
;;; Note: These will be added to api-package.lisp in a separate commit
