;;; media-gallery.lisp --- Media gallery viewer for Web UI
;;;
;;; Provides media gallery functionality for the web interface:
;;; - Grid view of all media in a chat
;;; - Lightbox-style fullscreen viewer
;;; - Filter by media type (photos, videos, documents)
;;; - Lazy loading for large galleries

(in-package #:cl-telegram/ui)

;;; ============================================================================
;;; Media Gallery State
;;; ============================================================================

(defvar *media-gallery-cache* (make-hash-table :test 'eq)
  "Cache of media items per chat")

(defvar *media-gallery-limit* 100
  "Maximum media items to load per gallery")

;;; ============================================================================
;;; Media Extraction and Indexing
;;; ============================================================================

(defun extract-media-from-chat (chat-id &key (limit *media-gallery-limit*))
  "Extract all media from a chat.

   Args:
     chat-id: Chat identifier
     limit: Maximum items to return

   Returns:
     List of media item plists"
  (let* ((messages (get-cached-messages chat-id :limit 500))
         (media-items nil))

    (dolist (msg messages)
      (when (and media-items (< (length media-items) limit))
        (let ((media (getf msg :media)))
          (when media
            (push (list :file-id (getf media :file-id)
                        :type (getf media :@type)
                        :mime-type (getf media :mime-type)
                        :file-size (getf media :file-size)
                        :file-name (getf media :file-name)
                        :width (getf media :width)
                        :height (getf media :height)
                        :duration (getf media :duration)
                        :thumb-file-id (getf media :thumb-file-id)
                        :message-id (getf msg :id)
                        :date (getf msg :date)
                        :caption (getf msg :caption))
                  media-items)))))

    (nreverse media-items)))

(defun get-media-for-gallery (chat-id &key (type :all) (offset 0) (limit 50))
  "Get paginated media for gallery view.

   Args:
     chat-id: Chat identifier
     type: Media type filter (:all :photo :video :document :audio)
     offset: Pagination offset
     limit: Items per page

   Returns:
     List of media items"
  (let* ((cache-key (intern (format nil "~A-~A" chat-id type)))
         (cached (gethash cache-key *media-gallery-cache*)))

    (unless cached
      (setf cached (extract-media-from-chat chat-id))
      (setf (gethash cache-key *media-gallery-cache*) cached))

    ;; Filter by type
    (let ((filtered (if (eq type :all)
                        cached
                        (remove-if-not (lambda (item)
                                         (or (eq (getf item :type) type)
                                             (and (eq type :photo)
                                                  (member (getf item :type)
                                                          '(:photo :messageMediaPhoto)))))
                                       cached))))
      ;; Paginate
      (subseq filtered offset (min (+ offset limit) (length filtered))))))

(defun clear-media-gallery-cache (&optional chat-id)
  "Clear media gallery cache.

   Args:
     chat-id: Specific chat to clear, or NIL for all

   Returns:
     T on success"
  (if chat-id
      (clrhash *media-gallery-cache*)
      (maphash (lambda (key value)
                 (declare (ignore key value))
                 (remhash key *media-gallery-cache*))
               *media-gallery-cache*))
  t)

;;; ============================================================================
;;; HTML Generation for Media Gallery
;;; ============================================================================

(defun generate-media-gallery-html (chat-id &key (type :all))
  "Generate HTML for media gallery.

   Args:
     chat-id: Chat identifier
     type: Media type filter

   Returns:
     HTML string"
  (let ((media-items (get-media-for-gallery chat-id :type type :limit 100)))
    (format nil
            "<div class=\"media-gallery\" data-chat-id=\"~A\" data-type=\"~A\">
  <div class=\"media-gallery-header\">
    <h3>~:[All Media~;~:*~A Media~]</h3>
    <div class=\"media-gallery-filters\">
      <button class=\"filter-btn ~:[~;active~]\" data-filter=\"all\">All</button>
      <button class=\"filter-btn ~:[~;active~]\" data-filter=\"photo\">Photos</button>
      <button class=\"filter-btn ~:[~;active~]\" data-filter=\"video\">Videos</button>
      <button class=\"filter-btn ~:[~;active~]\" data-filter=\"document\">Documents</button>
    </div>
    <button class=\"close-gallery-btn\" onclick=\"closeMediaGallery()\">✕</button>
  </div>
  <div class=\"media-gallery-grid\" id=\"media-gallery-grid\">
    ~{~A~}
  </div>
  <div class=\"media-gallery-load-more\" id=\"load-more-container\" ~:[style=\"display:none;\"~;~]>
    <button onclick=\"loadMoreMedia()\">Load More</button>
  </div>
  <div class=\"media-lightbox\" id=\"media-lightbox\" style=\"display:none;\">
    <div class=\"lightbox-content\" id=\"lightbox-content\"></div>
    <button class=\"lightbox-close\" onclick=\"closeLightbox()\">✕</button>
    <button class=\"lightbox-prev\" onclick=\"previousMedia()\">‹</button>
    <button class=\"lightbox-next\" onclick=\"nextMedia()\">›</button>
  </div>
</div>"
            chat-id (string-downcase type)
            (not (eq type :all)) (symbol-name type)
            (eq type :all) (eq type :photo) (eq type :video) (eq type :document)
            (mapcar #'generate-media-item-html media-items)
            (>= (length media-items) 100))))

(defun generate-media-item-html (media-item)
  "Generate HTML for a single media item.

   Args:
     media-item: Media item plist

   Returns:
     HTML string"
  (let* ((file-id (getf media-item :file-id))
         (type (getf media-item :type))
         (mime-type (getf media-item :mime-type))
         (file-size (getf media-item :file-size))
         (width (getf media-item :width))
         (height (getf media-item :height))
         (duration (getf media-item :duration))
         (caption (getf media-item :caption))
         (date (getf media-item :date))
         (thumb-id (getf media-item :thumb-file-id)))

    (cond
      ;; Photo
      ((or (eq type :photo) (eq type :messageMediaPhoto))
       (format nil
               "<div class=\"media-item photo\" data-file-id=\"~A\" data-type=\"photo\" onclick=\"openLightbox('~A')\">
  <img src=\"/api/media/thumb/~A\" alt=\"~:[~;~:*~A~]\" loading=\"lazy\">
  ~:[~;<div class=\"media-item-duration\">📷</div>~]
  ~:[~;<div class=\"media-item-caption\">~A</div>~]
</div>"
               file-id file-id (or thumb-id file-id)
               caption
               caption))

      ;; Video
      ((or (eq type :video) (eq type :messageMediaVideo))
       (format nil
               "<div class=\"media-item video\" data-file-id=\"~A\" data-type=\"video\" onclick=\"openLightbox('~A')\">
  <img src=\"/api/media/thumb/~A\" alt=\"Video thumbnail\" loading=\"lazy\">
  <div class=\"media-item-duration\">▶ ~:[~;~:*~A~]</div>
  ~:[~;<div class=\"media-item-caption\">~A</div>~]
</div>"
               file-id file-id (or thumb-id file-id)
               (format-video-duration duration)
               caption))

      ;; Document
      ((or (eq type :document) (eq type :messageMediaDocument))
       (format nil
               "<div class=\"media-item document\" data-file-id=\"~A\" data-type=\"document\" onclick=\"downloadMedia('~A')\">
  <div class=\"document-icon\">📎</div>
  <div class=\"document-info\">
    <div class=\"document-name\">~A</div>
    <div class=\"document-size\">~A</div>
  </div>
</div>"
               file-id file-id
               (or (getf media-item :file-name) "Unknown")
               (format-file-size file-size)))

      ;; Audio
      ((or (eq type :audio) (eq type :messageMediaAudio))
       (format nil
               "<div class=\"media-item audio\" data-file-id=\"~A\" data-type=\"audio\">
  <div class=\"audio-icon\">🎵</div>
  <div class=\"audio-info\">
    <div class=\"audio-title\">~:[Audio~;~:*~A~]</div>
    <div class=\"audio-duration\">~A</div>
  </div>
</div>"
               file-id
               caption
               (format-video-duration duration)))

      ;; Default/Unknown
      (t
       (format nil
               "<div class=\"media-item unknown\" data-file-id=\"~A\">
  <div class=\"unknown-icon\">📄</div>
  <div class=\"media-item-type\">Unknown</div>
</div>"
               file-id)))))

(defun format-video-duration (seconds)
  "Format video duration in MM:SS format.

   Args:
     seconds: Duration in seconds

   Returns:
     Formatted string"
  (if seconds
      (format nil "~D:~2,'0D" (truncate seconds 60) (mod seconds 60))
      ""))

(defun format-file-size (bytes)
  "Format file size for display.

   Args:
     bytes: File size in bytes

   Returns:
     Formatted string"
  (cond
    ((null bytes) "")
    ((< bytes 1024) (format nil "~A B\" bytes))
    ((< bytes (* 1024 1024)) (format nil "~,1f KB" (/ bytes 1024.0)))
    ((< bytes (* 1024 1024 1024)) (format nil "~,1f MB" (/ bytes (* 1024.0 1024))))
    (t (format nil "~,1f GB" (/ bytes (* 1024.0 1024 1024))))))

;;; ============================================================================
;;; Web API Endpoints for Media
;;; ============================================================================

(defun register-media-api-routes ()
  "Register media API routes with Hunchentoot.

   Returns:
     T on success"
  ;; This would be called when starting the web server
  ;; Routes are handled in web-server.lisp handle-api-request
  t)

(defun handle-media-thumb-request (file-id)
  "Handle media thumbnail request.

   Args:
     file-id: Telegram file ID

   Returns:
     Image data or redirect"
  (handler-case
      (let* ((temp-path (merge-pathnames (format nil "thumb-~A.jpg" file-id)
                                         (uiop:temporary-directory))))
        ;; Download thumbnail
        (cl-telegram/api:download-file file-id temp-path)

        (if (probe-file temp-path)
            (progn
              (setf (hunchentoot:content-type*) "image/jpeg")
              (with-open-file (s temp-path :direction :input :element-type '(unsigned-byte 8))
                (let ((data (make-array (file-length s) :element-type '(unsigned-byte 8))))
                  (read-sequence data s)
                  data)))
            (progn
              (hunchentoot:return-code 404)
              "Thumbnail not found")))
    (error (e)
      (format *error-output* "Thumbnail error: ~A~%" e)
      (hunchentoot:return-code 500)
      "Error loading thumbnail")))

(defun handle-media-download-request (file-id)
  "Handle media download request.

   Args:
     file-id: Telegram file ID

   Returns:
     File data with appropriate content-type"
  (handler-case
      (let* ((temp-path (merge-pathnames (format nil "media-~A" file-id)
                                         (uiop:temporary-directory))))
        (cl-telegram/api:download-file file-id temp-path)

        (if (probe-file temp-path)
            (let* ((ext (pathname-type temp-path))
                   (content-type (case (intern (string-upcase ext) :keyword)
                                   (:jpeg "image/jpeg")
                                   (:jpg "image/jpeg")
                                   (:png "image/png")
                                   (:gif "image/gif")
                                   (:webp "image/webp")
                                   (:mp4 "video/mp4")
                                   (:webm "video/webm")
                                   (:pdf "application/pdf")
                                   (:zip "application/zip")
                                   (t "application/octet-stream"))))
              (setf (hunchentoot:content-type*) content-type)
              (setf (hunchentoot:header-out :content-disposition)
                    (format nil "attachment; filename=\"~A\"" file-id))
              (with-open-file (s temp-path :direction :input :element-type '(unsigned-byte 8))
                (let ((data (make-array (file-length s) :element-type '(unsigned-byte 8))))
                  (read-sequence data s)
                  data)))
            (progn
              (hunchentoot:return-code 404)
              "File not found")))
    (error (e)
      (format *error-output* "Download error: ~A~%" e)
      (hunchentoot:return-code 500)
      "Error downloading file"))))

;;; ============================================================================
;;; CLOG Integration Functions
;;; ============================================================================

(defun render-media-gallery (win chat-id container)
  "Render media gallery in CLOG window.

   Args:
     win: CLOG window object
     chat-id: Chat identifier
     container: Container element

   Returns:
     Gallery element"
  (let ((gallery-html (generate-media-gallery-html chat-id :type :all)))
    (clog:html container gallery-html)

    ;; Add event handlers
    (clog:run-script win "
      // Filter buttons
      document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', function() {
          const filter = this.dataset.filter;
          filterGallery(filter);
        });
      });
    ")

    gallery))

(defun show-media-gallery-ui (win chat-id)
  "Show media gallery overlay.

   Args:
     win: CLOG window object
     chat-id: Chat identifier

   Returns:
     T on success"
  (let* ((overlay (clog:create-element win "div"
                                       :class "media-gallery-overlay"
                                       :style "position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.95); z-index: 10000; overflow-y: auto;"))
         (content (clog:create-element win "div"
                                       :style "padding: 20px; max-width: 1400px; margin: 0 auto;")))
    (clog:append! overlay content)
    (clog:append! (clog:body win) overlay)

    ;; Render gallery
    (render-media-gallery win chat-id content)

    t))

(defun open-lightbox (win file-id media-type)
  "Open media lightbox.

   Args:
     win: CLOG window object
     file-id: File identifier
     media-type: Type of media

   Returns:
     T on success"
  (handler-case
      (let* ((temp-path (merge-pathnames (format nil "media-~A" file-id)
                                         (uiop:temporary-directory))))
        (cl-telegram/api:download-file file-id temp-path)

        (when (probe-file temp-path)
          (clog:eval-in-window win
            (let ((content (clog:get-element-by-id "lightbox-content")))
              (clog:html content
                (case (intern (string-upcase media-type) :keyword)
                  ((:photo :messageMediaPhoto)
                   (format nil "<img src=\"file://~A\" style=\"max-width:100%;max-height:90vh;\"/>" temp-path))
                  ((:video :messageMediaVideo)
                   (format nil "<video src=\"file://~A\" controls autoplay style=\"max-width:100%;max-height:90vh;\"/>" temp-path))
                  (t
                   (format nil "<a href=\"file://~A\" download>Download ~A</a>" temp-path file-id)))))))))
    (error (e)
      (format *error-output* "Lightbox error: ~A~%" e)))
  t)

;;; ============================================================================
;;; Gallery CSS
;;; ============================================================================

(defun generate-gallery-css ()
  "Generate CSS for media gallery.

   Returns:
     CSS string"
  "
/* Media Gallery */
.media-gallery {
  padding: var(--space-lg);
}

.media-gallery-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-lg);
  padding-bottom: var(--space-md);
  border-bottom: 1px solid var(--border);
}

.media-gallery-header h3 {
  font-size: var(--font-size-lg);
  font-weight: 600;
}

.media-gallery-filters {
  display: flex;
  gap: var(--space-sm);
}

.filter-btn {
  background: var(--bg-tertiary);
  border: none;
  color: var(--text-secondary);
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: var(--font-size-sm);
  transition: all var(--transition-fast);
}

.filter-btn:hover {
  background: var(--accent);
  color: white;
}

.filter-btn.active {
  background: var(--accent);
  color: white;
}

.close-gallery-btn {
  background: transparent;
  border: none;
  color: var(--text-secondary);
  font-size: 24px;
  cursor: pointer;
  padding: var(--space-sm);
  line-height: 1;
}

.close-gallery-btn:hover {
  color: var(--text-primary);
}

/* Gallery Grid */
.media-gallery-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--space-md);
}

.media-item {
  aspect-ratio: 1;
  background: var(--bg-tertiary);
  border-radius: var(--radius-md);
  overflow: hidden;
  cursor: pointer;
  position: relative;
  transition: transform var(--transition-fast);
}

.media-item:hover {
  transform: scale(1.05);
}

.media-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.media-item-duration {
  position: absolute;
  bottom: 8px;
  right: 8px;
  background: rgba(0, 0, 0, 0.7);
  color: white;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 12px;
}

.media-item-caption {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: linear-gradient(transparent, rgba(0, 0, 0, 0.8));
  color: white;
  padding: 20px 8px 8px;
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Document Item */
.media-item.document {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: var(--space-sm);
}

.document-icon {
  font-size: 48px;
}

.document-info {
  text-align: center;
  padding: var(--space-sm);
}

.document-name {
  font-weight: 500;
  font-size: var(--font-size-sm);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}

.document-size {
  color: var(--text-secondary);
  font-size: var(--font-size-xs);
}

/* Audio Item */
.media-item.audio {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
}

.audio-icon {
  font-size: 48px;
}

.audio-info {
  text-align: center;
  padding: var(--space-sm);
}

.audio-title {
  font-weight: 500;
}

.audio-duration {
  color: var(--text-secondary);
  font-size: var(--font-size-xs);
}

/* Lightbox */
.media-lightbox {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.95);
  z-index: 10001;
  display: flex;
  align-items: center;
  justify-content: center;
}

.lightbox-content {
  max-width: 90%;
  max-height: 90%;
}

.lightbox-content img,
.lightbox-content video {
  max-width: 100%;
  max-height: 90vh;
  border-radius: var(--radius-md);
}

.lightbox-close {
  position: absolute;
  top: 20px;
  right: 20px;
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  font-size: 24px;
  cursor: pointer;
}

.lightbox-prev,
.lightbox-next {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 50px;
  height: 50px;
  font-size: 32px;
  cursor: pointer;
  border-radius: 50%;
}

.lightbox-prev {
  left: 20px;
}

.lightbox-next {
  right: 20px;
}

/* Load More */
.media-gallery-load-more {
  text-align: center;
  padding: var(--space-lg);
}

.media-gallery-load-more button {
  background: var(--accent);
  border: none;
  color: white;
  padding: var(--space-md) var(--space-xl);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: var(--font-size-md);
}

/* Responsive */
@media (max-width: 768px) {
  .media-gallery-grid {
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-xs);
  }

  .media-gallery-header {
    flex-direction: column;
    gap: var(--space-md);
    align-items: flex-start;
  }

  .media-gallery-filters {
    flex-wrap: wrap;
  }
}
"))

;;; ============================================================================
;;; End of media-gallery.lisp
;;; ============================================================================
