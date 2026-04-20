;;; media-albums.lisp --- Media album management for cl-telegram
;;;
;;; Provides smart media album features:
;;; - Create and manage media albums
;;; - Auto-create albums based on patterns
;;; - Tag system for media organization
;;; - Search and filter media
;;; - Export albums
;;;
;;; Version: 0.26.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Media Album Class
;;; ============================================================================

(defclass media-album ()
  ((album-id :initarg :album-id :reader album-id)
   (title :initarg :title :accessor album-title)
   (description :initform "" :accessor album-description)
   (cover-media-id :initform nil :accessor album-cover-media-id)
   (media-ids :initform nil :accessor album-media-ids)
   (chat-id :initform nil :accessor album-chat-id)
   (created-date :initform (get-universal-time) :accessor album-created-date)
   (updated-date :initform nil :accessor album-updated-date)
   (is-auto-created :initform nil :accessor album-is-auto-created)
   (tags :initform nil :accessor album-tags)
   (media-count :initform 0 :accessor album-media-count)
   (is-deleted :initform nil :accessor album-is-deleted)))

(defun make-media-album (title chat-id &key (description nil) (album-id nil))
  "Create a new media album.

   TITLE: Album title
   CHAT-ID: Chat this album belongs to
   DESCRIPTION: Optional description
   ALBUM-ID: Optional custom album ID

   Returns:
     media-album instance"
  (let ((aid (or album-id (format nil "~A-~A" chat-id (get-universal-time)))))
    (make-instance 'media-album
                   :album-id aid
                   :title title
                   :chat-id chat-id
                   :description (or description ""))))

;;; ============================================================================
;;; Media Item Class
;;; ============================================================================

(defclass media-item ()
  ((media-id :initarg :media-id :reader media-id)
   (file-id :initarg :file-id :accessor media-file-id)
   (type :initarg :type :accessor media-type) ; :photo, :video, :document, :audio
   (file-size :initform nil :accessor media-file-size)
   (mime-type :initform nil :accessor media-mime-type)
   (width :initform nil :accessor media-width)
   (height :initform nil :accessor media-height)
   (duration :initform nil :accessor media-duration)
   (date :initform nil :accessor media-date)
   (chat-id :initform nil :accessor media-chat-id)
   (message-id :initform nil :accessor media-message-id)
   (tags :initform nil :accessor media-tags)
   (thumbnail-path :initform nil :accessor media-thumbnail-path)
   (file-path :initform nil :accessor media-file-path)
   (caption :initform nil :accessor media-caption)
   (is-favorite :initform nil :accessor media-is-favorite)))

(defun make-media-item (media-id file-id type &key (chat-id nil) (date nil))
  "Create a new media item.

   MEDIA-ID: Unique identifier
   FILE-ID: Telegram file ID
   TYPE: Media type keyword
   CHAT-ID: Source chat ID
   DATE: Media date

   Returns:
     media-item instance"
  (make-instance 'media-item
                 :media-id media-id
                 :file-id file-id
                 :type type
                 :chat-id chat-id
                 :date (or date (get-universal-time))))

;;; ============================================================================
;;; Media Album Manager
;;; ============================================================================

(defclass media-album-manager ()
  ((albums :initform (make-hash-table :test 'equal) :accessor album-manager-albums)
   (media-items :initform (make-hash-table :test 'equal) :accessor album-manager-media)
   (chat-albums :initform (make-hash-table :test 'equal) :accessor album-manager-chat-albums)
   (tags-index :initform (make-hash-table :test 'equal) :accessor album-manager-tags-index)
   (cache :initform (make-hash-table :test 'equal) :accessor album-manager-cache)
   (last-updated :initform nil :accessor album-manager-last-updated)))

(defvar *media-album-manager* nil
  "Global media album manager instance")

(defun make-media-album-manager ()
  "Create a new media album manager instance.

   Returns:
     media-album-manager instance"
  (make-instance 'media-album-manager))

(defun init-media-albums ()
  "Initialize media album subsystem.

   Returns:
     T on success"
  (unless *media-album-manager*
    (setf *media-album-manager* (make-media-album-manager))
    (format t "Media album manager initialized~%"))
  t)

(defun shutdown-media-albums ()
  "Shutdown media album subsystem.

   Returns:
     T on success"
  (when *media-album-manager*
    ;; Save to database if needed
    (setf *media-album-manager* nil))
  t)

;;; ============================================================================
;;; Album CRUD Operations
;;; ============================================================================

(defun create-media-album (title chat-id &key (description nil) (cover-media-id nil))
  "Create a new media album.

   TITLE: Album title
   CHAT-ID: Chat this album belongs to
   DESCRIPTION: Optional description
   COVER-MEDIA-ID: Cover media file ID

   Returns:
     (values album-id error)"
  (init-media-albums)

  (let* ((album (make-media-album title chat-id :description description))
         (album-id (album-id album)))
    ;; Set cover if provided
    (when cover-media-id
      (setf (album-cover-media-id album) cover-media-id))

    ;; Store album
    (let ((manager *media-album-manager*))
      (setf (gethash album-id (album-manager-albums manager)) album)

      ;; Index by chat
      (let ((chat-index (gethash chat-id (album-manager-chat-albums manager) nil)))
        (setf (gethash chat-id (album-manager-chat-albums manager))
              (cons album-id chat-index))))

    (format t "Created album: ~A (~A)~%" title album-id)
    (values album-id nil)))

(defun delete-media-album (album-id)
  "Delete a media album.

   ALBUM-ID: Album to delete

   Returns:
     (values t error)"
  (let ((manager *media-album-manager*))
    (unless manager
      (return-from delete-media-album
        (values nil :not-initialized "Media albums not initialized")))

    (let ((album (gethash album-id (album-manager-albums manager))))
      (unless album
        (return-from delete-media-album
          (values nil :not-found (format nil "Album ~A not found" album-id))))

      ;; Remove from chat index
      (let ((chat-id (album-chat-id album)))
        (let ((chat-index (gethash chat-id (album-manager-chat-albums manager))))
          (setf (gethash chat-id (album-manager-chat-albums manager))
                (remove album-id chat-index))))

      ;; Mark as deleted
      (setf (album-is-deleted album) t)
      (setf (album-updated-date album) (get-universal-time))

      ;; Remove from storage
      (remhash album-id (album-manager-albums manager))

      (format t "Deleted album: ~A~%" album-id)
      (values t nil))))

(defun edit-media-album (album-id &key (title nil) (description nil) (cover-media-id nil))
  "Edit a media album.

   ALBUM-ID: Album to edit
   TITLE: New title
   DESCRIPTION: New description
   COVER-MEDIA-ID: New cover media

   Returns:
     (values t error)"
  (let ((album (gethash album-id (album-manager-albums *media-album-manager*))))
    (unless album
      (return-from edit-media-album
        (values nil :not-found (format nil "Album ~A not found" album-id))))

    (when title
      (setf (album-title album) title))
    (when description
      (setf (album-description album) description))
    (when cover-media-id
      (setf (album-cover-media-id album) cover-media-id))

    (setf (album-updated-date album) (get-universal-time))

    (format t "Edited album: ~A~%" album-id)
    (values t nil)))

(defun get-media-albums (chat-id)
  "Get all media albums for a chat.

   CHAT-ID: Chat to get albums for

   Returns:
     List of album IDs"
  (let ((manager *media-album-manager*))
    (unless manager
      (return-from get-media-albums nil))

    (gethash chat-id (album-manager-chat-albums manager) nil)))

(defun get-media-album (album-id &key (force-refresh nil))
  "Get specific album details.

   ALBUM-ID: Album to retrieve
   FORCE-REFRESH: Reload from server

   Returns:
     Album plist or NIL"
  (let* ((manager *media-album-manager*)
         (album (when manager
                  (gethash album-id (album-manager-albums manager)))))
    (unless album
      (return-from get-media-album nil))

    (list :album-id (album-id album)
          :title (album-title album)
          :description (album-description album)
          :cover-media-id (album-cover-media-id album)
          :media-ids (album-media-ids album)
          :media-count (album-media-count album)
          :chat-id (album-chat-id album)
          :created-date (album-created-date album)
          :updated-date (album-updated-date album)
          :is-auto-created (album-is-auto-created album)
          :tags (album-tags album))))

;;; ============================================================================
;;; Media Management
;;; ============================================================================

(defun add-media-to-album (album-id media-ids)
  "Add media to album.

   ALBUM-ID: Album to add to
   MEDIA-IDS: List of media IDs to add

   Returns:
     (values t error)"
  (let ((album (gethash album-id (album-manager-albums *media-album-manager*))))
    (unless album
      (return-from add-media-to-album
        (values nil :not-found (format nil "Album ~A not found" album-id))))

    ;; Add media IDs
    (dolist (mid media-ids)
      (unless (member mid (album-media-ids album))
        (push mid (album-media-ids album))
        (incf (album-media-count album))))

    ;; Set cover if none exists
    (unless (album-cover-media-id album)
      (when media-ids
        (setf (album-cover-media-id album) (first media-ids))))

    (setf (album-updated-date album) (get-universal-time))

    (format t "Added ~D media to album ~A~%" (length media-ids) album-id)
    (values t nil)))

(defun remove-media-from-album (album-id media-ids)
  "Remove media from album.

   ALBUM-ID: Album to remove from
   MEDIA-IDS: List of media IDs to remove

   Returns:
     (values t error)"
  (let ((album (gethash album-id (album-manager-albums *media-album-manager*))))
    (unless album
      (return-from remove-media-from-album
        (values nil :not-found (format nil "Album ~A not found" album-id))))

    ;; Remove media IDs
    (dolist (mid media-ids)
      (when (member mid (album-media-ids album))
        (setf (album-media-ids album) (remove mid (album-media-ids album)))
        (decf (album-media-count album))))

    ;; Update cover if removed
    (when (and (album-cover-media-id album)
               (member (album-cover-media-id album) media-ids))
      (setf (album-cover-media-id album)
            (first (album-media-ids album))))

    (setf (album-updated-date album) (get-universal-time))

    (format t "Removed ~D media from album ~A~%" (length media-ids) album-id)
    (values t nil)))

(defun reorder-album-media (album-id media-ids)
  "Reorder media in album.

   ALBUM-ID: Album to reorder
   MEDIA-IDS: New order of media IDs

   Returns:
     (values t error)"
  (let ((album (gethash album-id (album-manager-albums *media-album-manager*))))
    (unless album
      (return-from reorder-album-media
        (values nil :not-found (format nil "Album ~A not found" album-id))))

    ;; Verify all IDs exist
    (dolist (mid media-ids)
      (unless (member mid (album-media-ids album))
        (return-from reorder-album-media
          (values nil :media-not-found (format nil "Media ~A not in album" mid)))))

    (setf (album-media-ids album) media-ids)
    (setf (album-updated-date album) (get-universal-time))

    (format t "Reordered media in album ~A~%" album-id)
    (values t nil)))

;;; ============================================================================
;;; Smart Albums
;;; ============================================================================

(defun auto-create-albums (chat-id &key (by-date t) (by-event t) (min-items 3))
  "Auto-create albums based on media patterns.

   CHAT-ID: Chat to analyze
   BY-DATE: Group by date (day/week/month)
   BY-EVENT: Detect events (trips, parties, etc.)
   MIN-ITEMS: Minimum items per album

   Returns:
     List of created album IDs"
  (let ((created-albums nil))
    ;; Get all media for chat
    (let ((media-list (get-chat-media chat-id)))
      (unless media-list
        (return-from auto-create-albums nil))

      ;; Group by date
      (when by-date
        (let ((date-groups (group-media-by-date media-list)))
          (maphash (lambda (date-key items)
                     (when (>= (length items) min-items)
                       (let* ((date-str (format-date-key date-key))
                              (album-title (format nil "~A Media" date-str)))
                         (multiple-value-bind (album-id error)
                             (create-media-album album-title chat-id
                                                 :description (format nil "Auto-created for ~A" date-str))
                           (unless error
                             (add-media-to-album album-id (mapcar #'media-id items))
                             (setf (album-is-auto-created
                                    (gethash album-id (album-manager-albums *media-album-manager*))) t)
                             (push album-id created-albums))))))
                   date-groups)))

      ;; Group by event (would use ML/clustering in production)
      (when by-event
        (let ((event-groups (detect-media-events media-list)))
          (dolist (event event-groups)
            (when (>= (length (getf event :media)) min-items)
              (multiple-value-bind (album-id error)
                  (create-media-album (getf event :title) chat-id
                                      :description (getf event :description))
                (unless error
                  (add-media-to-album album-id (mapcar #'media-id (getf event :media)))
                  (setf (album-is-auto-created
                         (gethash album-id (album-manager-albums *media-album-manager*))) t)
                  (push album-id created-albums)))))))

    created-albums))

(defun group-media-by-date (media-list)
  "Group media items by date.

   MEDIA-LIST: List of media-item objects

   Returns:
     Hash table with date keys"
  (let ((groups (make-hash-table :test 'equal)))
    (dolist (media media-list)
      (let* ((date (media-date media))
             (date-key (format-time-string "~Y-~m-~d" date)))
        (let ((existing (gethash date-key groups nil)))
          (setf (gethash date-key groups) (cons media existing)))))
    groups))

(defun detect-media-events (media-list)
  "Detect media events (clusters of related media).

   MEDIA-LIST: List of media-item objects

   Returns:
     List of event plists"
  ;; In production, would use ML clustering based on:
  ;; - Temporal proximity
  ;; - Location data
  ;; - Visual similarity
  ;; - Caption keywords

  ;; Simple mock: group by consecutive days
  (let ((events nil)
        (current-event nil)
        (last-date nil))

    (dolist (media (sort media-list #'< :key #'media-date))
      (let ((date (media-date media)))
        (if (or (null last-date)
                (<= (- date last-date) (* 3 24 60 60))) ; Within 3 days
            ;; Same event
            (push media current-event)
            ;; New event
            (when current-event
              (push (list :media (nreverse current-event)
                          :title (format nil "Event ~A"
                                        (format-time-string "~Y-~m-~d" (media-date (first current-event))))
                          :description "Auto-detected event")
                    events)
              (setf current-event (list media)))))
        (setf last-date date)))

    ;; Don't forget last event
    (when current-event
      (push (list :media (nreverse current-event)
                  :title (format nil "Event ~A"
                                (format-time-string "~Y-~m-~d" (media-date (first current-event))))
                  :description "Auto-detected event")
            events))

    (nreverse events)))

;;; ============================================================================
;;; Tag System
;;; ============================================================================

(defun add-media-tags (media-id tags)
  "Add tags to media.

   MEDIA-ID: Media to tag
   TAGS: List of tag strings

   Returns:
     (values t error)"
  (let ((manager *media-album-manager*))
    (unless manager
      (return-from add-media-tags
        (values nil :not-initialized "Media albums not initialized")))

    ;; Get or create media item
    (let ((item (gethash media-id (album-manager-media manager))))
      (unless item
        ;; Create placeholder
        (setf item (make-media-item media-id nil :unknown))
        (setf (gethash media-id (album-manager-media manager)) item))

      ;; Add tags
      (dolist (tag tags)
        (unless (member tag (media-tags item))
          (push tag (media-tags item))
          ;; Update tag index
          (let ((indexed (gethash tag (album-manager-tags-index manager) nil)))
            (setf (gethash tag (album-manager-tags-index manager))
                  (cons media-id indexed)))))

      (format t "Added tags ~A to media ~A~%" tags media-id)
      (values t nil))))

(defun remove-media-tags (media-id tags)
  "Remove tags from media.

   MEDIA-ID: Media to update
   TAGS: List of tags to remove

   Returns:
     (values t error)"
  (let ((item (gethash media-id (album-manager-media *media-album-manager*))))
    (unless item
      (return-from remove-media-tags
        (values nil :not-found (format nil "Media ~A not found" media-id))))

    ;; Remove tags
    (dolist (tag tags)
      (setf (media-tags item) (remove tag (media-tags item) :test 'string=))
      ;; Update tag index
      (let ((indexed (gethash tag (album-manager-tags-index *media-album-manager*))))
        (when indexed
          (setf (gethash tag (album-manager-tags-index *media-album-manager*))
                (remove media-id indexed)))))

    (format t "Removed tags ~A from media ~A~%" tags media-id)
    (values t nil)))

(defun search-media-by-tags (chat-id tags &key (match-all nil))
  "Search media by tags.

   CHAT-ID: Chat to search in
   TAGS: Tags to search for
   MATCH-ALL: If true, require all tags; otherwise any tag

   Returns:
     List of media IDs"
  (let ((results nil)
        (manager *media-album-manager*))

    (if match-all
        ;; Match all tags
        (let ((tag-sets (loop for tag in tags
                              collect (gethash tag (album-manager-tags-index manager) nil))))
          (when tag-sets
            (let ((common (reduce #'intersection tag-sets :key #'list-to-set)))
              (setf results (coerce common 'list)))))
        ;; Match any tag
        (let ((seen (make-hash-table :test 'equal)))
          (dolist (tag tags)
            (let ((indexed (gethash tag (album-manager-tags-index manager) nil)))
              (dolist (media-id indexed)
                (unless (gethash media-id seen)
                  (setf (gethash media-id seen) t)
                  (push media-id results)))))))

    ;; Filter by chat if specified
    (when chat-id
      (setf results (remove-if-not
                     (lambda (mid)
                       (let ((item (gethash mid (album-manager-media manager))))
                         (and item (eql (media-chat-id item) chat-id))))
                     results)))

    results))

(defun get-popular-tags (chat-id &key (limit 20))
  "Get most used tags.

   CHAT-ID: Chat to get tags for (nil for global)
   LIMIT: Maximum tags to return

   Returns:
     List of (tag . count) pairs"
  (let ((tag-counts (make-hash-table :test 'equal))
        (manager *media-album-manager*))

    ;; Count tags
    (if chat-id
        ;; Filter by chat
        (maphash (lambda (mid item)
                   (when (and item (eql (media-chat-id item) chat-id))
                     (dolist (tag (media-tags item))
                       (incf (gethash tag tag-counts 0)))))
                 (album-manager-media manager))
        ;; All tags
        (maphash (lambda (tag media-list)
                   (declare (ignore media-list))
                   (incf (gethash tag tag-counts 0)))
                 (album-manager-tags-index manager)))

    ;; Sort by count
    (let ((sorted-tags nil))
      (maphash (lambda (tag count)
                 (push (cons tag count) sorted-tags))
               tag-counts)
      (subseq (sort sorted-tags #'> :key #'cdr) 0 (min limit (length sorted-tags))))))

;;; ============================================================================
;;; Search and Filter
;;; ============================================================================

(defun search-media (chat-id &key (type nil) (date-from nil) (date-to nil)
                              (tags nil) (query nil) (limit 50))
  "Search media with filters.

   CHAT-ID: Chat to search in
   TYPE: Media type filter (:photo, :video, :document)
   DATE-FROM: Start date
   DATE-TO: End date
   TAGS: Tags to filter by
   QUERY: Text query (caption search)
   LIMIT: Maximum results

   Returns:
     List of media IDs"
  (let ((results nil)
        (manager *media-album-manager*))

    (maphash (lambda (mid item)
               (when item
                 ;; Apply filters
                 (let ((match t))
                   ;; Type filter
                   (when (and type (not (eql (media-type item) type)))
                     (setf match nil))

                   ;; Chat filter
                   (when (and chat-id (not (eql (media-chat-id item) chat-id)))
                     (setf match nil))

                   ;; Date filters
                   (when (and date-from (media-date item))
                     (when (< (media-date item) date-from)
                       (setf match nil)))
                   (when (and date-to (media-date item))
                     (when (> (media-date item) date-to)
                       (setf match nil)))

                   ;; Tag filter
                   (when tags
                     (unless (intersection tags (media-tags item) :test 'string=)
                       (setf match nil)))

                   ;; Query filter (caption search)
                   (when query
                     (unless (and (media-caption item)
                                  (search query (media-caption item) :test #'char-equal))
                       (setf match nil)))

                   ;; Add if matched
                   (when match
                     (push mid results)))))
             (album-manager-media manager))

    (subseq results 0 (min limit (length results)))))

(defun filter-media-by-type (chat-id type)
  "Filter media by type.

   CHAT-ID: Chat to filter
   TYPE: Media type (:photo, :video, :document, :audio)

   Returns:
     List of media IDs"
  (search-media chat-id :type type))

(defun get-media-timeline (chat-id &key (start-date nil) (end-date nil))
  "Get media timeline.

   CHAT-ID: Chat to get timeline for
   START-DATE: Optional start date
   END-DATE: Optional end date

   Returns:
     List of (date . media-list) pairs"
  (let ((timeline (make-hash-table :test 'equal))
        (media-list (search-media chat-id :date-from start-date :date-to end-date :limit 1000)))

    ;; Group by date
    (dolist (mid media-list)
      (let* ((item (gethash mid (album-manager-media *media-album-manager*)))
             (date (when (media-date item)
                     (format-time-string "~Y-~m-~d" (media-date item)))))
        (when date
          (let ((existing (gethash date timeline nil)))
            (setf (gethash date timeline) (cons mid existing))))))

    ;; Convert to sorted list
    (let ((result nil))
      (maphash (lambda (date items)
                 (push (cons date items) result))
               timeline)
      (sort result #'string> :key #'car))))

;;; ============================================================================
;;; Export
;;; ============================================================================

(defun export-media-album (album-id output-directory &key (format nil))
  "Export album to directory.

   ALBUM-ID: Album to export
   OUTPUT-DIRECTORY: Destination directory
   FORMAT: Output format (nil for original)

   Returns:
     (values exported-count error)"
  (let ((album (gethash album-id (album-manager-albums *media-album-manager*))))
    (unless album
      (return-from export-media-album
        (values nil :not-found (format nil "Album ~A not found" album-id))))

    ;; Ensure directory exists
    (ensure-directories-exist (format nil "~Aexport/" output-directory))

    (let ((exported 0))
      (dolist (media-id (album-media-ids album))
        (let ((item (gethash media-id (album-manager-media *media-album-manager*))))
          (when item
            ;; Download and save
            (let* ((file-path (format nil "~Aexport/~A" output-directory media-id))
                   (success (download-file (media-file-id item) file-path)))
              (when success
                (incf exported))))))

      (format t "Exported ~D media from album ~A~%" exported album-id)
      (values exported nil))))

(defun export-all-media (chat-id output-directory)
  "Export all media from chat.

   CHAT-ID: Chat to export
   OUTPUT-DIRECTORY: Destination directory

   Returns:
     (values exported-count error)"
  (let ((media-list (search-media chat-id :limit 1000))
        (exported 0))

    ;; Ensure directory exists
    (ensure-directories-exist output-directory)

    (dolist (media-id media-list)
      (let ((item (gethash media-id (album-manager-media *media-album-manager*))))
        (when item
          (let* ((subdir (format nil "~A/~A/" output-directory (media-type item)))
                 (file-path (format nil "~A~A" subdir media-id))
                 (success (download-file (media-file-id item) file-path)))
            (when success
              (incf exported))))))

    (format t "Exported ~D media from chat ~A~%" exported chat-id)
    (values exported nil)))

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun get-chat-media (chat-id)
  "Get all media for a chat.

   CHAT-ID: Chat to query

   Returns:
     List of media-item objects"
  ;; In production, query database or Telegram API
  (declare (ignorable chat-id))
  nil)

(defun format-date-key (date-key)
  "Format date key as readable string.

   DATE-KEY: Date string

   Returns:
     Formatted string"
  date-key)

(defun list-to-set (list)
  "Convert list to set (hash table).

   LIST: List to convert

   Returns:
     Hash table"
  (let ((set (make-hash-table :test 'equal)))
    (dolist (item list)
      (setf (gethash item set) t))
    set))

(defun intersection (&rest lists)
  "Find intersection of multiple lists.

   LISTS: Lists to intersect

   Returns:
     List of common elements"
  (if (null lists)
      nil
      (let ((result (first lists)))
        (dolist (lst (rest lists))
          (setf result (remove-if-not (lambda (x) (member x lst)) result)))
        result)))

(defun download-file (file-id output-path)
  "Download file from Telegram.

   FILE-ID: Telegram file ID
   OUTPUT-PATH: Destination path

   Returns:
     T on success, NIL on failure"
  ;; In production, use the file download API
  (declare (ignorable file-id output-path))
  t)

;;; Export symbols (to be added to api-package.lisp)
;; #:create-media-album
;; #:delete-media-album
;; #:edit-media-album
;; #:get-media-albums
;; #:get-media-album
;; #:add-media-to-album
;; #:remove-media-from-album
;; #:reorder-album-media
;; #:auto-create-albums
;; #:add-media-tags
;; #:remove-media-tags
;; #:search-media-by-tags
;; #:get-popular-tags
;; #:search-media
;; #:filter-media-by-type
;; #:get-media-timeline
;; #:export-media-album
;; #:export-all-media
