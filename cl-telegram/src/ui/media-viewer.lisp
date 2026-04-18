;;; media-viewer.lisp --- Media viewer for CLOG GUI

(in-package #:cl-telegram/ui)

;;; ### Media Types

(defclass media-item ()
  ((file-id :initarg :file-id :reader media-file-id)
   (file-type :initarg :file-type :reader media-file-type)
   (file-path :initform nil :accessor media-file-path)
   (file-size :initarg :file-size :reader media-file-size)
   (mime-type :initarg :mime-type :reader media-mime-type)
   (thumbnail :initarg :thumbnail :reader media-thumbnail)
   (caption :initarg :caption :reader media-caption)
   (width :initarg :width :initform nil :reader media-width)
   (height :initarg :height :initform nil :reader media-height)
   (duration :initarg :duration :initform nil :reader media-duration)))

(defclass media-viewer ()
  ((current-media :initform nil :accessor viewer-current-media)
   (media-history :initform nil :accessor viewer-media-history)
   (chat-id :initarg :chat-id :reader viewer-chat-id)
   (message-id :initarg :message-id :reader viewer-message-id)
   (window :initarg :window :reader viewer-window)
   (zoom-level :initform 1.0 :accessor viewer-zoom-level)
   (fullscreen-p :initform nil :accessor viewer-fullscreen-p)))

;;; ### Media Extraction from Messages

(defun extract-media-from-message (message)
  "Extract media information from a message object.

   Returns: media-item object or NIL if no media"
  (let* ((media (getf message :media))
         (photo (getf media :photo))
         (document (getf media :document))
         (video (getf media :video))
         (audio (getf media :audio))
         (voice (getf media :voice))
         (animation (getf media :animation)))
    (cond
      ;; Photo
      (photo
       (let* ((sizes (getf photo :sizes))
              (largest (car (last sizes)))
              (file-id (getf largest :file-id)))
         (make-instance 'media-item
                        :file-id file-id
                        :file-type :photo
                        :mime-type "image/jpeg"
                        :width (getf largest :width)
                        :height (getf largest :height)
                        :caption (getf message :caption))))
      ;; Document
      (document
       (make-instance 'media-item
                      :file-id (getf document :file-id)
                      :file-type :document
                      :file-size (getf document :file-size)
                      :mime-type (getf document :mime-type)
                      :file-name (getf document :file-name)
                      :thumbnail (getf document :thumbnail)
                      :caption (getf message :caption)))
      ;; Video
      (video
       (make-instance 'media-item
                      :file-id (getf video :file-id)
                      :file-type :video
                      :file-size (getf video :file-size)
                      :mime-type (getf video :mime-type)
                      :width (getf video :width)
                      :height (getf video :height)
                      :duration (getf video :duration)
                      :thumbnail (getf video :thumbnail)
                      :caption (getf message :caption)))
      ;; Audio
      (audio
       (make-instance 'media-item
                      :file-id (getf audio :file-id)
                      :file-type :audio
                      :file-size (getf audio :file-size)
                      :mime-type (getf audio :mime-type)
                      :duration (getf audio :duration)
                      :caption (getf message :caption)))
      ;; Voice
      (voice
       (make-instance 'media-item
                      :file-id (getf voice :file-id)
                      :file-type :voice
                      :file-size (getf voice :file-size)
                      :mime-type (getf voice :mime-type)
                      :duration (getf voice :duration)
                      :caption (getf message :caption)))
      ;; Animation (GIF)
      (animation
       (make-instance 'media-item
                      :file-id (getf animation :file-id)
                      :file-type :animation
                      :file-size (getf animation :file-size)
                      :mime-type (getf animation :mime-type)
                      :width (getf animation :width)
                      :height (getf animation :height)
                      :caption (getf message :caption)))
      (t nil))))

;;; ### Media Download

(defun download-media (media-item &key (destination nil) (progress-callback nil))
  "Download media to local file.

   MEDIA-ITEM: media-item object
   DESTINATION: Optional destination path (defaults to temp directory)
   PROGRESS-CALLBACK: Optional callback for progress updates

   Returns: (values file-path error)"
  (let* ((temp-dir (uiop:temporary-directory))
         (file-ext (case (media-file-type media-item)
                     (:photo "jpg")
                     (:video "mp4")
                     (:audio "mp3")
                     (:animation "gif")
                     (:document (or (pathname-type (media-file-path media-item)) "dat"))
                     (otherwise "dat")))
         (dest-path (or destination
                        (merge-pathnames
                         (format nil "media-~A-~A.~A"
                                 (media-file-type media-item)
                                 (media-file-id media-item)
                                 file-ext)
                         temp-dir))))
    (handler-case
        (progn
          (cl-telegram/api:download-file
           (media-file-id media-item)
           dest-path
           :progress-callback progress-callback)
          (setf (media-file-path media-item) dest-path)
          (values dest-path nil))
      (error (e)
        (values nil (format nil "Download error: ~A" e))))))

;;; ### CLOG Media Rendering

(defun render-media-thumbnail (win media-item &key (max-width 200) (max-height 200))
  "Render media thumbnail in CLOG.

   Returns: CLOG element"
  (let* ((thumb-path (media-thumbnail media-item))
         (file-path (media-file-path media-item))
         (src-path (or thumb-path file-path)))
    (cond
      ;; Have local file
      (file-path
       (clog:create-element win "img"
                            :src (format nil "file://~A" file-path)
                            :class "media-thumbnail"
                            :style (format nil "max-width: ~Dpx; max-height: ~Dpx;"
                                          max-width max-height)))
      ;; No file yet, show placeholder
      (t
       (let ((placeholder (clog:create-element win "div"
                                               :class "media-placeholder"
                                               :style "width: 100px; height: 100px; background: #333; display: flex; align-items: center; justify-content: center;"))
             (icon (case (media-file-type media-item)
                     (:photo "📷")
                     (:video "🎬")
                     (:audio "🎵")
                     (:animation "🎞️")
                     (:document "📎")
                     (otherwise "📄"))))
         (clog:append! placeholder
           (clog:create-element win "span"
                                :text icon
                                :style "font-size: 2em;"))
         placeholder)))))

(defun render-media-viewer (win media-item)
  "Render full media viewer in CLOG.

   Returns: CLOG element container"
  (let* ((container (clog:create-element win "div" :class "media-viewer-container"
                                         :style "position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.9); z-index: 1000; display: flex; flex-direction: column;"))
         (header (clog:create-element win "div" :class "media-viewer-header"
                                      :style "padding: 10px 20px; display: flex; justify-content: space-between; align-items: center; color: white;"))
         (content (clog:create-element win "div" :class "media-viewer-content"
                                       :style "flex: 1; display: flex; align-items: center; justify-content: center; overflow: hidden;"))
         (footer (clog:create-element win "div" :class "media-viewer-footer"
                                      :style "padding: 10px 20px; color: white; text-align: center;")))
    ;; Header with close button
    (let ((close-btn (clog:create-element win "button" :text "✕ Close"
                                          :style "background: transparent; border: 1px solid white; color: white; padding: 5px 15px; cursor: pointer; border-radius: 5px;")))
      (clog:on close-btn :click (lambda (e)
                                  (declare (ignore e))
                                  (clog:remove! container)))
      (clog:append! header close-btn)
      (clog:append! header
        (clog:create-element win "span"
                             :text (format nil "~A" (media-file-type media-item)))))

    ;; Content based on media type
    (let ((file-path (media-file-path media-item)))
      (case (media-file-type media-item)
        ((:photo :animation)
         (if file-path
             (let ((img (clog:create-element win "img"
                                             :src (format nil "file://~A" file-path)
                                             :style "max-width: 100%; max-height: 100%; object-fit: contain;")))
               (clog:append! content img))
             ;; Downloading placeholder
             (let ((spinner (clog:create-element win "div"
                                                 :class "spinner"
                                                 :style "color: white; font-size: 2em;")))
               (setf (clog:text spinner) "⏳ Downloading...")
               (clog:append! content spinner)
               ;; Start download asynchronously
               (bt:make-thread
                (lambda ()
                  (multiple-value-bind (path error)
                      (download-media media-item)
                    (if path
                        (clog:eval-in-window win
                          (let ((img (clog:create-element win "img"
                                                          :src (format nil "file://~A" path))))
                            (clog:append! (clog:get-element win "media-viewer-content") img)
                            (clog:remove! spinner)))
                        (format t "Download error: ~A~%" error))))
                :name "media-download"))))
        ((:video)
         (if file-path
             (let ((video (clog:create-element win "video"
                                               :controls t
                                               :style "max-width: 100%; max-height: 100%;")))
               (clog:evaluate video "this.src = 'file://" file-path "';")
               (clog:append! content video))
             (clog:append! content
               (clog:create-element win "div" :text "🎬 Video (download to play)"
                                    :style "color: white; font-size: 1.5em;"))))
        ((:audio :voice)
         (if file-path
             (let ((audio (clog:create-element win "audio"
                                               :controls t
                                               :style "width: 80%;")))
               (clog:evaluate audio "this.src = 'file://" file-path "';")
               (clog:append! content audio))
             (clog:append! content
               (clog:create-element win "div" :text "🎵 Audio (download to play)"
                                    :style "color: white; font-size: 1.5em;"))))
        ((:document)
         (clog:append! content
           (clog:create-element win "div"
                                :style "color: white; text-align: center;"
                                (clog:create-element win "div"
                                                     :text "📎 Document"
                                                     :style "font-size: 3em; margin-bottom: 20px;")
                                (clog:create-element win "div"
                                                     :text (or (media-file-name media-item) "Unknown file")
                                                     :style "font-size: 1.2em; margin-bottom: 10px;")
                                (clog:create-element win "div"
                                                     :text (format nil "~D KB" (truncate (media-file-size media-item) 1024))
                                                     :style "font-size: 1em; color: #aaa;")
                                (let ((download-btn (clog:create-element win "button"
                                                                         :text "Download"
                                                                         :style "margin-top: 20px; padding: 10px 30px; font-size: 1em; cursor: pointer;")))
                                  (clog:on download-btn :click
                                           (lambda (e)
                                             (declare (ignore e))
                                             (multiple-value-bind (path error)
                                                 (download-media media-item)
                                               (if path
                                                   (format t "Downloaded to: ~A~%" path)
                                                   (format t "Download error: ~A~%" error)))))
                                  download-btn))))))

    ;; Footer with caption
    (let ((caption (media-caption media-item)))
      (when caption
        (clog:append! footer
          (clog:create-element win "div" :text caption
                               :style "max-width: 80%; margin: 0 auto;"))))

    ;; Assemble
    (clog:append! container header)
    (clog:append! container content)
    (clog:append! container footer)
    container))

(defun open-media-viewer (win message)
  "Open media viewer for a message.

   WIN: CLOG window
   MESSAGE: Message object containing media

   Returns: media-viewer instance or NIL"
  (let ((media-item (extract-media-from-message message)))
    (when media-item
      ;; Download media first
      (let ((download-status (clog:create-element win "div"
                                                  :text "⏳ Loading media..."
                                                  :style "position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: rgba(0,0,0,0.8); color: white; padding: 20px 40px; border-radius: 10px; z-index: 2000;")))
        (clog:append! (clog:body win) download-status)
        ;; Start download in background
        (bt:make-thread
         (lambda ()
           (multiple-value-bind (path error)
               (download-media media-item)
             (clog:eval-in-window win
               (clog:remove! download-status))
             (if path
                 (clog:eval-in-window win
                   (render-media-viewer win media-item))
                 (clog:eval-in-window win
                   (let ((error-msg (clog:create-element win "div"
                                                         :text (format nil "❌ Error: ~A" error)
                                                         :style "color: red; padding: 20px;")))
                     (clog:append! (clog:body win) error-msg)
                     (sleep 3)
                     (clog:remove! error-msg))))))
         :name "media-viewer-download"))
      media-item)))

;;; ### Media Gallery View

(defun render-media-gallery (win messages &key (columns 3))
  "Render media gallery grid from multiple messages.

   MESSAGES: List of messages containing media
   COLUMNS: Number of columns in grid

   Returns: CLOG element"
  (let* ((gallery (clog:create-element win "div" :class "media-gallery"
                                       :style (format nil "display: grid; grid-template-columns: repeat(~D, 1fr); gap: 10px; padding: 10px;" columns)))
         (media-items (remove nil (mapcar #'extract-media-from-message messages))))
    (dolist (media-item media-items)
      (let ((item-container (clog:create-element win "div"
                                                 :class "media-gallery-item"
                                                 :style "position: relative; aspect-ratio: 1; overflow: hidden; border-radius: 8px; cursor: pointer;"))
            (thumb (render-media-thumbnail win media-item :max-width 300 :max-height 300)))
        ;; Make clickable to open full viewer
        (clog:on item-container :click
                 (lambda (e)
                   (declare (ignore e))
                   (open-media-viewer win (find-if (lambda (msg)
                                                     (equal (getf (getf msg :media) :file-id)
                                                            (media-file-id media-item)))
                                                   messages))))
        (clog:append! item-container thumb)
        (clog:append! gallery item-container)))
    gallery))

;;; ### Helper Functions

(defun find-messages-with-media (messages)
  "Filter messages that contain media.

   Returns: List of messages with media"
  (remove-if (lambda (msg)
               (null (extract-media-from-message msg)))
             messages))

(defun get-media-count (messages)
  "Count media items in messages.

   Returns: Number of media items"
  (length (find-messages-with-media messages)))
