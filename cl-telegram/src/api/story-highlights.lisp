;;; story-highlights.lisp --- Story highlights management for cl-telegram
;;;
;;; Provides story highlights functionality:
;;; - Create highlights with custom covers
;;; - Edit highlight title, cover, and stories
;;; - Reorder highlights
;;; - Privacy settings (public/contacts/close-friends/custom)
;;; - Delete highlights

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Story Highlights State
;;; ============================================================================

(defvar *highlights-cache* (make-hash-table :test 'eq)
  "Cache of story highlights per user")

(defvar *highlights-enabled* t
  "Whether highlights feature is enabled")

;;; ============================================================================
;;; Highlights CRUD
;;; ============================================================================

(defun create-story-highlight (title story-ids &key (cover-story-id nil)
                                                    (description nil)
                                                    (privacy :public))
  "Create a new story highlight.

   Args:
     title: Highlight title
     story-ids: List of story IDs to include
     cover-story-id: Story ID for cover image (default: first story)
     description: Optional highlight description
     privacy: Privacy setting (:public :contacts :close-friends :custom)

   Returns:
     Highlight ID on success, or error plist

   Example:
     (create-story-highlight \"Travel 2024\" '(1001 1002 1003)
                             :cover-story-id 1001
                             :description \"My travels around the world\")"
  (unless (and title story-ids)
    (return-from create-story-highlight
      (list :error "Title and story IDs are required")))

  (let ((request `(:method "stories.createHighlight"
                   :parameters (:title ,title
                                 :story_ids ,story-ids
                                 ,@(when cover-story-id
                                     `(:cover_story_id ,cover-story-id))
                                 ,@(when description
                                     `(:description ,description))
                                 ,@(when privacy
                                     `(:privacy ,(privacy-to-string privacy)))))))
    (handler-case
        (let ((response (send-api-request request)))
          (let ((highlight-id (getf response :highlight_id)))
            ;; Invalidate cache
            (clear-highlights-cache)
            highlight-id))
      (error (e)
        (list :error (format nil "Failed to create highlight: ~A" e))))))

(defun edit-story-highlight (highlight-id &key (title nil title-p)
                                        (description nil desc-p)
                                        (cover-story-id nil cover-p)
                                        (story-ids nil stories-p)
                                        (privacy nil privacy-p))
  "Edit an existing story highlight.

   Args:
     highlight-id: Highlight identifier
     title: New title (optional)
     description: New description (optional)
     cover-story-id: New cover story ID (optional)
     story-ids: New list of story IDs (optional)
     privacy: New privacy setting (optional)

   Returns:
     T on success, or error plist

   Example:
     (edit-story-highlight 12345 :title \"Updated Title\" :privacy :contacts)"
  (let ((request `(:method "stories.editHighlight"
                   :parameters (:highlight_id ,highlight-id
                                 ,@(when title-p `(:title ,title))
                                 ,@(when desc-p `(:description ,description))
                                 ,@(when cover-p `(:cover_story_id ,cover-story-id))
                                 ,@(when stories-p `(:story_ids ,story-ids))
                                 ,@(when privacy-p
                                     `(:privacy ,(privacy-to-string privacy)))))))
    (handler-case
        (let ((response (send-api-request request)))
          (declare (ignore response))
          ;; Invalidate cache
          (remhash highlight-id *highlights-cache*)
          t)
      (error (e)
        (list :error (format nil "Failed to edit highlight: ~A" e))))))

(defun edit-highlight-cover (highlight-id story-id &key (crop-x 0) (crop-y 0)
                                                  (crop-width 1.0) (crop-height 1.0)
                                                  (rotation 0))
  "Edit highlight cover image.

   Args:
     highlight-id: Highlight identifier
     story-id: Story ID to use as cover
     crop-x: Crop X offset (0-1)
     crop-y: Crop Y offset (0-1)
     crop-width: Crop width (0-1)
     crop-height: Crop height (0-1)
     rotation: Rotation angle in degrees

   Returns:
     T on success, or error plist

   Example:
     (edit-highlight-cover 12345 1001 :crop-x 0.1 :crop-y 0.1
                           :crop-width 0.8 :crop-height 0.8)"
  (let ((request `(:method "stories.editHighlightCover"
                   :parameters (:highlight_id ,highlight-id
                                 :story_id ,story-id
                                 :crop_x ,crop-x
                                 :crop_y ,crop-y
                                 :crop_width ,crop-width
                                 :crop_height ,crop-height
                                 :rotation ,rotation))))
    (handler-case
        (let ((response (send-api-request request)))
          (declare (ignore response))
          (remhash highlight-id *highlights-cache*)
          t)
      (error (e)
        (list :error (format nil "Failed to edit cover: ~A" e))))))

(defun delete-story-highlight (highlight-id)
  "Delete a story highlight.

   Args:
     highlight-id: Highlight identifier

   Returns:
     T on success, or error plist

   Example:
     (delete-story-highlight 12345)"
  (let ((request `(:method "stories.deleteHighlight"
                   :parameters (:highlight_id ,highlight-id))))
    (handler-case
        (let ((response (send-api-request request)))
          (declare (ignore response))
          ;; Invalidate cache
          (remhash highlight-id *highlights-cache*)
          t)
      (error (e)
        (list :error (format nil "Failed to delete highlight: ~A" e))))))

(defun reorder-story-highlights (highlight-ids)
  "Reorder story highlights.

   Args:
     highlight-ids: List of highlight IDs in desired order

   Returns:
     T on success, or error plist

   Example:
     (reorder-story-highlights '(3 1 2)) ; New order"
  (let ((request `(:method "stories.reorderHighlights"
                   :parameters (:highlight_ids ,highlight-ids))))
    (handler-case
        (let ((response (send-api-request request)))
          (declare (ignore response))
          ;; Invalidate cache
          (clear-highlights-cache)
          t)
      (error (e)
        (list :error (format nil "Failed to reorder highlights: ~A" e))))))

;;; ============================================================================
;;; Highlights Retrieval
;;; ============================================================================

(defun get-story-highlights (&optional (user-id nil))
  "Get story highlights for a user.

   Args:
     user-id: User ID (nil for current user)

   Returns:
     List of highlight plists

   Example:
     (get-story-highlights) ; Current user
     (get-story-highlights 12345) ; Specific user"
  (let ((uid (or user-id (get-me-id))))
    (unless uid
      (return-from get-story-highlights nil))

    ;; Check cache first
    (let ((cached (gethash uid *highlights-cache*)))
      (when cached
        return cached))

    (let ((request `(:method "stories.getHighlights"
                     :parameters (:user_id ,uid))))
      (handler-case
          (let ((response (send-api-request request)))
            (let ((highlights (getf response :highlights)))
              ;; Cache results
              (setf (gethash uid *highlights-cache*) highlights)
              highlights))
        (error (e)
          (format nil "Failed to get highlights: ~A" e)))))

(defun get-story-highlight (highlight-id)
  "Get detailed info about a specific highlight.

   Args:
     highlight-id: Highlight identifier

   Returns:
     Highlight plist with full details

   Example:
     (get-story-highlight 12345)"
  (let ((request `(:method "stories.getHighlight"
                   :parameters (:highlight_id ,highlight-id))))
    (handler-case
        (let ((response (send-api-request request)))
          (getf response :highlight))
      (error (e)
        (list :error (format nil "Failed to get highlight: ~A" e))))))

(defun get-highlight-stories (highlight-id)
  "Get stories in a highlight.

   Args:
     highlight-id: Highlight identifier

   Returns:
     List of story plists

   Example:
     (get-highlight-stories 12345)"
  (let ((highlight (get-story-highlight highlight-id)))
    (when highlight
      (getf highlight :stories))))

;;; ============================================================================
;;; Story Management in Highlights
;;; ============================================================================

(defun add-stories-to-highlight (highlight-id story-ids)
  "Add stories to an existing highlight.

   Args:
     highlight-id: Highlight identifier
     story-ids: List of story IDs to add

   Returns:
     T on success, or error plist"
  (let* ((highlight (get-story-highlight highlight-id))
         (existing-stories (getf highlight :stories '()))
         (all-stories (append existing-stories story-ids)))
    (edit-story-highlight highlight-id :story-ids all-stories :stories-p t)))

(defun remove-stories-from-highlight (highlight-id story-ids)
  "Remove stories from a highlight.

   Args:
     highlight-id: Highlight identifier
     story-ids: List of story IDs to remove

   Returns:
     T on success, or error plist"
  (let* ((highlight (get-story-highlight highlight-id))
         (existing-stories (getf highlight :stories '()))
         (remaining (set-difference existing-stories story-ids)))
    (if remaining
        (edit-story-highlight highlight-id :story-ids remaining :stories-p t)
        (list :error "Cannot remove all stories, delete highlight instead"))))

;;; ============================================================================
;;; Privacy Settings
;;; ============================================================================

(defun set-highlight-privacy (highlight-id privacy)
  "Set highlight privacy.

   Args:
     highlight-id: Highlight identifier
     privacy: Privacy setting (:public :contacts :close-friends :custom)

   Returns:
     T on success, or error plist

   Privacy levels:
     :public - Anyone can see
     :contacts - Only contacts can see
     :close-friends - Only close friends can see
     :custom - Custom privacy rules"
  (edit-story-highlight highlight-id :privacy privacy :privacy-p t))

(defun get-highlight-privacy (highlight-id)
  "Get highlight privacy setting.

   Args:
     highlight-id: Highlight identifier

   Returns:
     Privacy keyword"
  (let ((highlight (get-story-highlight highlight-id)))
    (when highlight
      (string-to-keyword (getf highlight :privacy :public)))))

(defun privacy-to-string (privacy)
  "Convert privacy keyword to string.

   Args:
     privacy: Privacy keyword

   Returns:
     Privacy string"
  (case privacy
    (:public "public")
    (:contacts "contacts")
    (:close-friends "close_friends")
    (:custom "custom")
    (otherwise "public")))

(defun string-to-keyword (string)
  "Convert string to keyword.

   Args:
     string: String to convert

   Returns:
     Keyword"
  (if string
      (intern (string-upcase (substitute #\- #\_ string)) :keyword)
      :unknown))

;;; ============================================================================
;;; Highlight Stories Viewing
;;; ============================================================================

(defun view-highlight-stories (highlight-id)
  "View stories in a highlight (mark as viewed).

   Args:
     highlight-id: Highlight identifier

   Returns:
     T on success"
  (let ((stories (get-highlight-stories highlight-id)))
    (dolist (story stories)
      (mark-story-as-viewed (getf story :id)))
    t))

(defun mark-story-as-viewed (story-id)
  "Mark a story as viewed.

   Args:
     story-id: Story identifier

   Returns:
     T on success"
  (let ((request `(:method "stories.markViewed"
                   :parameters (:story_ids (,story-id)))))
    (handler-case
        (progn
          (send-api-request request)
          t)
      (error (e)
        (declare (ignore e))
        nil))))

;;; ============================================================================
;;; Cache Management
;;; ============================================================================

(defun clear-highlights-cache (&optional user-id)
  "Clear highlights cache.

   Args:
     user-id: Specific user to clear, or NIL for all

   Returns:
     T on success"
  (if user-id
      (remhash user-id *highlights-cache*)
      (clrhash *highlights-cache*))
  t)

(defun refresh-highlights (&optional user-id)
  "Refresh highlights from server.

   Args:
     user-id: User ID to refresh, or NIL for current user

   Returns:
     Updated highlights"
  (clear-highlights-cache user-id)
  (get-story-highlights user-id))

;;; ============================================================================
;;; Highlight Utilities
;;; ============================================================================

(defun get-highlight-count (&optional (user-id nil))
  "Get count of highlights for a user.

   Args:
     user-id: User ID (nil for current user)

   Returns:
     Number of highlights"
  (let ((highlights (get-story-highlights user-id)))
    (if (listp highlights)
        (length highlights)
        0)))

(defun get-highlight-by-title (title &optional (user-id nil))
  "Find highlight by title.

   Args:
     title: Highlight title to find
     user-id: User ID (nil for current user)

   Returns:
     Highlight plist or NIL"
  (let ((highlights (get-story-highlights user-id)))
    (find-if (lambda (h)
               (string= (getf h :title) title))
             highlights)))

(defun search-highlights (query &optional (user-id nil))
  "Search highlights by title or description.

   Args:
     query: Search query
     user-id: User ID (nil for current user)

   Returns:
     List of matching highlights"
  (let ((highlights (get-story-highlights user-id)))
    (remove-if-not (lambda (h)
                     (or (search query (getf h :title) :test #'char-equal)
                         (search query (getf h :description) :test #'char-equal)))
                   highlights)))

(defun highlight-has-story-p (highlight-id story-id)
  "Check if highlight contains a specific story.

   Args:
     highlight-id: Highlight identifier
     story-id: Story identifier

   Returns:
     T if story is in highlight"
  (let ((stories (get-highlight-stories highlight-id)))
    (member story-id stories)))

;;; ============================================================================
;;; Archive Integration
;;; ============================================================================

(defun archive-story-to-highlight (story-id highlight-id)
  "Archive a story to a highlight.

   Args:
     story-id: Story identifier
     highlight-id: Highlight identifier

   Returns:
     T on success"
  (add-stories-to-highlight highlight-id (list story-id)))

(defun create-highlight-from-archived-stories (title story-ids &key (cover-story-id nil))
  "Create a highlight from archived stories.

   Args:
     title: Highlight title
     story-ids: List of archived story IDs
     cover-story-id: Story ID for cover

   Returns:
     Highlight ID on success"
  (create-story-highlight title story-ids :cover-story-id cover-story-id))

;;; ============================================================================
;;; Bulk Operations
;;; ============================================================================

(defun delete-multiple-highlights (highlight-ids)
  "Delete multiple highlights.

   Args:
     highlight-ids: List of highlight IDs

   Returns:
     List of results (T for success, error plist for failure)"
  (mapcar #'delete-story-highlight highlight-ids))

(defun export-highlights (&optional (user-id nil))
  "Export highlights as JSON-serializable data.

   Args:
     user-id: User ID (nil for current user)

   Returns:
     Export data plist"
  (let ((highlights (get-story-highlights user-id)))
    (list :user-id user-id
          :count (length highlights)
          :highlights highlights
          :exported-at (get-universal-time))))

;;; ============================================================================
;;; End of story-highlights.lisp
;;; ============================================================================
