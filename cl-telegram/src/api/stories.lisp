;;; stories.lisp --- Telegram Stories support
;;;
;;; Provides support for:
;;; - Stories viewing and posting
;;; - Stories list and highlights
;;; - Story privacy settings
;;; - Story reactions and views
;;; - Story expiration handling

(in-package #:cl-telegram/api)

;;; ### Story Types

(defclass story ()
  ((id :initarg :id :reader story-id)
   (owner :initarg :owner :reader story-owner)
   (date :initarg :date :reader story-date)
   (expiration-date :initarg :expiration-date :reader story-expiration-date)
   (media :initarg :media :reader story-media)
   (caption :initarg :caption :initform nil :reader story-caption)
   (is-pinned :initarg :is-pinned :initform nil :reader story-is-pinned)
   (privacy :initarg :privacy :reader story-privacy)
   (can-reply :initarg :can-reply :initform t :reader story-can-reply)
   (can-reshare :initarg :can-reshare :initform t :reader story-can-reshare)
   (views-count :initarg :views-count :initform 0 :reader story-views-count)
   (reactions :initarg :reactions :initform nil :reader story-reactions)
   (is-viewed :initarg :is-viewed :initform nil :reader story-is-viewed)
   (is-forwarded :initarg :is-forwarded :initform nil :reader story-is-forwarded)))

(defclass story-highlight ()
  ((id :initarg :id :reader highlight-id)
   (title :initarg :title :reader highlight-title)
   (cover-media :initarg :cover-media :reader highlight-cover-media)
   (stories :initarg :stories :initform nil :reader highlight-stories)
   (date-created :initarg :date-created :reader highlight-date-created)))

(defclass story-privacy ()
  ((type :initarg :type :initform 'everybody :reader story-privacy-type)
   (allowed-users :initarg :allowed-users :initform nil :reader story-privacy-allowed)
   (blocked-users :initarg :blocked-users :initform nil :reader story-privacy-blocked)
   (is-dark :initarg :is-dark :initform nil :reader story-privacy-is-dark)))

(defclass stories-state ()
  ((has-unviewed :initform nil :accessor stories-has-unviewed)
   (unviewed-count :initform 0 :accessor stories-unviewed-count)
   (active-story-id :initform nil :accessor stories-active-story-id)
   (current-index :initform 0 :accessor stories-current-index)))

;;; ### Global State

(defvar *stories-cache* (make-hash-table :test 'equal)
  "Cache for stories by owner ID")

(defvar *highlights-cache* (make-hash-table :test 'equal)
  "Cache for story highlights")

(defvar *stories-state* (make-instance 'stories-state)
  "Current stories viewing state")

(defvar *stories-upload-queue* nil
  "Queue for pending story uploads")

;;; ### Stories Retrieval

(defun get-stories (owner-id &key (limit 10))
  "Get stories from a user or channel.

   Args:
     owner-id: User or channel ID
     limit: Maximum stories to return

   Returns:
     List of story objects"
  (let ((key (format nil \"~A\" owner-id)))
    (let ((cached (gethash key *stories-cache*)))
      (if cached
          (subseq cached 0 (min limit (length cached)))
          ;; TODO: Implement API call
          nil))))

(defun get-all-stories (&key (limit 100))
  "Get all available stories from all contacts.

   Args:
     limit: Maximum total stories to return

   Returns:
     List of story objects grouped by owner"
  (declare (ignorable limit))
  ;; TODO: Implement API call
  nil)

(defun get-unviewed-stories ()
  "Get all unviewed stories.

   Returns:
     List of unviewed story objects"
  (let ((unviewed nil))
    (maphash (lambda (key stories)
               (declare (ignore key))
               (loop for story in stories
                     unless (story-is-viewed story)
                     do (push story unviewed)))
             *stories-cache*)
    (nreverse unviewed)))

(defun get-story-by-id (owner-id story-id)
  "Get specific story by owner and story ID.

   Args:
     owner-id: User or channel ID
     story-id: Story ID

   Returns:
     Story object or NIL"
  (let ((key (format nil \"~A\" owner-id)))
    (let ((stories (gethash key *stories-cache*)))
      (when stories
        (find story-id stories :key #'story-id :test #'=)))))

;;; ### Stories Posting

(defun post-story (media &key (caption nil) (privacy 'everybody) (can-reply t) (can-reshare t) (is-pinned nil))
  "Post a new story.

   Args:
     media: Media to post (photo or video)
     caption: Optional caption text
     privacy: Privacy setting (everybody/contacts/close-friends/custom)
     can-reply: Whether others can reply to story
     can-reshare: Whether others can reshare story
     is-pinned: Whether to pin story to profile

   Returns:
     Story object on success"
  (declare (ignorable media caption privacy can-reply can-reshare is-pinned))
  ;; TODO: Implement API call
  nil)

(defun post-story-photo (photo-file-id &key (caption nil) (duration 24))
  "Post a photo story.

   Args:
     photo-file-id: Photo file ID
     caption: Optional caption
     duration: Story duration in hours (default 24)

   Returns:
     Story object on success"
  (declare (ignorable photo-file-id caption duration))
  ;; TODO: Implement API call
  nil)

(defun post-story-video (video-file-id &key (caption nil) (duration 24))
  "Post a video story.

   Args:
     video-file-id: Video file ID
     caption: Optional caption
     duration: Story duration in hours

   Returns:
     Story object on success"
  (declare (ignorable video-file-id caption duration))
  ;; TODO: Implement API call
  nil)

(defun delete-story (story-id)
  "Delete a story.

   Args:
     story-id: Story ID to delete

   Returns:
     T on success"
  (declare (ignorable story-id))
  ;; TODO: Implement API call
  nil)

(defun edit-story (story-id &key (caption nil) (privacy nil))
  "Edit story properties.

   Args:
     story-id: Story ID to edit
     caption: New caption
     privacy: New privacy setting

   Returns:
     T on success"
  (declare (ignorable story-id caption privacy))
  ;; TODO: Implement API call
  nil)

(defun pin-story (story-id)
  "Pin story to profile.

   Args:
     story-id: Story ID to pin

   Returns:
     T on success"
  (declare (ignorable story-id))
  ;; TODO: Implement API call
  nil)

(defun unpin-story (story-id)
  "Unpin story from profile.

   Args:
     story-id: Story ID to unpin

   Returns:
     T on success"
  (declare (ignorable story-id))
  ;; TODO: Implement API call
  nil)

;;; ### Story Privacy

(defun set-story-privacy (privacy-type &key (allowed-users nil) (blocked-users nil))
  "Set default story privacy setting.

   Args:
     privacy-type: everybody/contacts/close-friends/custom
     allowed-users: List of user IDs (for custom)
     blocked-users: List of blocked user IDs

   Returns:
     Story-privacy object"
  (make-instance 'story-privacy
                 :type privacy-type
                 :allowed-users allowed-users
                 :blocked-users blocked-users))

(defun get-story-privacy-settings ()
  "Get current story privacy settings.

   Returns:
     Story-privacy object"
  ;; TODO: Implement API call
  (make-instance 'story-privacy :type 'everybody))

;;; ### Story Interactions

(defun mark-story-viewed (story-id)
  "Mark story as viewed.

   Args:
     story-id: Story ID

   Returns:
     T on success"
  (let ((story (get-story-by-id 0 story-id))) ; 0 is placeholder
    (when story
      (setf (slot-value story 'is-viewed) t)
      t)))

(defun send-story-reaction (story-id emoji)
  "Send reaction to a story.

   Args:
     story-id: Story ID
     emoji: Reaction emoji

   Returns:
     T on success"
  (declare (ignorable story-id emoji))
  ;; TODO: Implement API call
  nil)

(defun get-story-views (story-id &key (limit 100))
  "Get users who viewed the story.

   Args:
     story-id: Story ID
     limit: Maximum users to return

   Returns:
     List of user objects"
  (declare (ignorable story-id limit))
  ;; TODO: Implement API call
  nil)

(defun get-story-reactions (story-id)
  "Get reactions on a story.

   Args:
     story-id: Story ID

   Returns:
     List of reaction objects"
  (let ((story (get-story-by-id 0 story-id)))
    (when story
      (story-reactions story))))

(defun forward-story (story-id to-chat-id)
  "Forward story to a chat.

   Args:
     story-id: Story ID
     to-chat-id: Chat ID to forward to

   Returns:
     Message object on success"
  (declare (ignorable story-id to-chat-id))
  ;; TODO: Implement API call
  nil)

(defun reply-to-story (story-id text &key (media nil))
  "Send reply to a story.

   Args:
     story-id: Story ID
     text: Reply text
     media: Optional media attachment

   Returns:
     Message object on success"
  (declare (ignorable story-id text media))
  ;; TODO: Implement API call
  nil)

;;; ### Story Highlights

(defun create-highlight (title &key (cover-media nil) (story-ids nil))
  "Create a new story highlight.

   Args:
     title: Highlight title
     cover-media: Optional cover media
     story-ids: List of story IDs to include

   Returns:
     Story-highlight object on success"
  (declare (ignorable title cover-media story-ids))
  ;; TODO: Implement API call
  nil)

(defun get-highlights (&key (owner-id nil))
  "Get story highlights.

   Args:
     owner-id: Optional owner ID (defaults to current user)

   Returns:
     List of story-highlight objects"
  (declare (ignorable owner-id))
  (loop for key being the hash-keys of *highlights-cache*
        when (or (null owner-id) (search (format nil \"~A\" owner-id) key))
        append (gethash key *highlights-cache*)))

(defun get-highlight (highlight-id)
  "Get specific highlight by ID.

   Args:
     highlight-id: Highlight ID

   Returns:
     Story-highlight object or NIL"
  (loop for key being the hash-keys of *highlights-cache*
        for highlights = (gethash key *highlights-cache*)
        for highlight = (find highlight-id highlights :key #'highlight-id :test #'=)
        when highlight return highlight))

(defun edit-highlight (highlight-id &key (title nil) (cover-media nil))
  "Edit highlight properties.

   Args:
     highlight-id: Highlight ID
     title: New title
     cover-media: New cover media

   Returns:
     T on success"
  (declare (ignorable highlight-id title cover-media))
  ;; TODO: Implement API call
  nil)

(defun add-stories-to-highlight (highlight-id story-ids)
  "Add stories to highlight.

   Args:
     highlight-id: Highlight ID
     story-ids: List of story IDs to add

   Returns:
     T on success"
  (declare (ignorable highlight-id story-ids))
  ;; TODO: Implement API call
  nil)

(defun remove-highlight (highlight-id)
  "Remove a highlight.

   Args:
     highlight-id: Highlight ID

   Returns:
     T on success"
  (declare (ignorable highlight-id))
  ;; TODO: Implement API call
  nil)

;;; ### Stories Viewing

(defun view-next-story ()
  "View next story in sequence.

   Returns:
     Story object or NIL"
  (let* ((unviewed (get-unviewed-stories))
         (index (stories-current-index *stories-state*)))
    (if (< index (length unviewed))
        (let ((story (nth index unviewed)))
          (mark-story-viewed (story-id story))
          (incf (stories-current-index *stories-state*))
          (setf (stories-active-story-id *stories-state*) (story-id story))
          story)
        nil)))

(defun view-previous-story ()
  "View previous story.

   Returns:
     Story object or NIL"
  (let ((index (stories-current-index *stories-state*)))
    (when (> index 0)
      (decf (stories-current-index *stories-state*))
      (view-next-story))))

(defun close-stories-viewer ()
  "Close stories viewer.

   Returns:
     T on success"
  (setf (stories-active-story-id *stories-state*) nil
        (stories-current-index *stories-state*) 0
        (stories-has-unviewed *stories-state*) nil
        (stories-unviewed-count *stories-state*) 0)
  t)

;;; ### Story Expiration

(defun get-expiring-stories (&key (within-minutes 60))
  "Get stories that will expire soon.

   Args:
     within-minutes: Time window in minutes

   Returns:
     List of expiring story objects"
  (let ((cutoff (- (get-universal-time) (* within-minutes 60))))
    (let ((expiring nil))
      (maphash (lambda (key stories)
                 (declare (ignore key))
                 (loop for story in stories
                       when (and (story-expiration-date story)
                                 (<= (story-expiration-date story) (+ (get-universal-time) (* within-minutes 60))))
                       do (push story expiring)))
               *stories-cache*)
      (nreverse expiring))))

(defun cleanup-expired-stories ()
  "Remove expired stories from cache.

   Returns:
     Number of stories removed"
  (let ((now (get-universal-time))
        (count 0))
    (maphash (lambda (key stories)
               (let ((remaining (remove-if (lambda (s)
                                             (when (and (story-expiration-date s)
                                                        (<= (story-expiration-date s) now))
                                               (incf count)
                                               t))
                                           stories)))
                 (when (< (length remaining) (length stories))
                   (setf (gethash key *stories-cache*) remaining))))
             *stories-cache*)
    count))

;;; ### Story Statistics

(defun get-story-stats (story-id)
  "Get statistics for a story.

   Args:
     story-id: Story ID

   Returns:
     Stats plist with views, reactions, shares"
  (let ((story (get-story-by-id 0 story-id)))
    (when story
      (list :views (story-views-count story)
            :reactions (story-reactions story)
            :is-viewed (story-is-viewed story)
            :is-pinned (story-is-pinned story)))))

(defun get-stories-stats ()
  "Get overall stories statistics.

   Returns:
     Stats plist"
  (let ((total 0)
        (viewed 0)
        (unviewed 0))
    (maphash (lambda (key stories)
               (declare (ignore key))
               (incf total (length stories))
               (loop for s in stories
                     if (story-is-viewed s)
                     do (incf viewed)
                     else do (incf unviewed)))
             *stories-cache*)
    (list :total-stories total
          :viewed viewed
          :unviewed unviewed)))

;;; ### CLOG UI Integration

(defun render-stories-bar (win container on-click)
  "Render stories bar at top of chat list.

   Args:
     win: CLOG window object
     container: Container element
     on-click: Callback when story clicked"
  (let ((stories-bar (clog:create-element win "div" :class "stories-bar"
                                           :style "display: flex; gap: 10px; padding: 10px; overflow-x: auto; background: #f5f5f5;")))
    ;; Get stories from all contacts
    (let ((all-stories (get-all-stories :limit 20)))
      (if (null all-stories)
          (clog:append! stories-bar
                        (clog:create-element win "span" :text "No stories" :style "color: #999;"))
          ;; Group by owner and render circles
          (let ((owners (make-hash-table :test 'equal)))
            (loop for story in all-stories
                  for owner = (story-owner story)
                  do (push story (gethash owner owners)))
            (maphash (lambda (owner-id stories)
                       (let ((owner-circle (clog:create-element win "div" :class "story-circle"
                                                                 :style "display: flex; flex-direction: column; align-items: center; cursor: pointer; min-width: 70px;")))
                         ;; Story ring (gradient border)
                         (let ((ring (clog:create-element win "div" :class "story-ring"
                                                           :style "width: 60px; height: 60px; border-radius: 50%; padding: 3px; background: linear-gradient(45deg, #f09433, #e6683c, #dc2743, #cc2366, #bc1888);")))
                           (let ((avatar (clog:create-element win "div" :class "story-avatar"
                                                               :style "width: 100%; height: 100%; border-radius: 50%; background: white; display: flex; align-items: center; justify-content: center; font-size: 24px;")))
                             (setf (clog:text avatar) (subseq (format nil "~A" owner-id) 0 1))
                             (clog:append! ring avatar))
                           (clog:append! owner-circle ring))
                         ;; Owner name
                         (clog:append! owner-circle
                                       (clog:create-element win "span" :class "story-owner-name"
                                                             :style "font-size: 11px; margin-top: 5px; color: #666;"
                                                             :text (format nil "~A" owner-id)))
                         ;; Click handler
                         (clog:on owner-circle :click
                                  (lambda (ev)
                                    (declare (ignore ev))
                                    (when on-click
                                      (funcall on-click owner-id (car stories)))))
                         (clog:append! stories-bar owner-circle))))
                     owners)))))
    (clog:append! container stories-bar)))

(defun render-stories-viewer (win container story on-next on-prev on-close on-react)
  "Render full-screen stories viewer.

   Args:
     win: CLOG window object
     container: Container element
     story: Current story object
     on-next: Callback for next story
     on-prev: Callback for previous story
     on-close: Callback for closing viewer
     on-react: Callback for sending reaction"
  ;; Progress bar
  (let ((progress-container (clog:create-element win "div" :class "story-progress"
                                                  :style "position: absolute; top: 0; left: 0; right: 0; height: 3px; background: rgba(255,255,255,0.3); z-index: 1000;")))
    (let ((progress-bar (clog:create-element win "div" :class "story-progress-bar"
                                              :style "height: 100%; background: white; width: 0%; transition: width 0.1s linear;")))
      (clog:append! progress-container progress-bar))
    (clog:append! container progress-container))

  ;; Story content
  (let ((story-content (clog:create-element win "div" :class "story-content"
                                             :style "position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: black; display: flex; align-items: center; justify-content: center;")))
    ;; Render media
    (clog:append! story-content
                  (clog:create-element win "img" :class "story-media"
                                       :style "max-width: 100%; max-height: 100%;"
                                       :alt "Story"))
    (clog:append! container story-content))

  ;; Header with owner and close button
  (let ((header (clog:create-element win "div" :class "story-header"
                                      :style "position: absolute; top: 20px; left: 20px; right: 20px; display: flex; justify-content: space-between; align-items: center; z-index: 1001; color: white;")))
    (clog:append! header
                  (clog:create-element win "div" :class "story-owner-info"
                                       :style "display: flex; align-items: center; gap: 10px;"
                                       (clog:create-element win "span" :class "owner-name"
                                                             :style "font-weight: bold;"
                                                             :text (format nil "~A" (story-owner story)))))
    (clog:append! header
                  (clog:create-element win "button" :class "close-btn"
                                       :style "background: none; border: none; color: white; font-size: 24px; cursor: pointer;"
                                       :text "✕"))
    (clog:on (clog:query-selector header ".close-btn") :click
             (lambda (ev)
               (declare (ignore ev))
               (when on-close
                 (funcall on-close))))
    (clog:append! container header))

  ;; Caption
  (when (story-caption story)
    (let ((caption (clog:create-element win "div" :class "story-caption"
                                         :style "position: absolute; bottom: 80px; left: 20px; right: 20px; color: white; font-size: 16px; text-shadow: 1px 1px 3px rgba(0,0,0,0.8);")))
      (setf (clog:text caption) (story-caption story))
      (clog:append! container caption)))

  ;; Navigation areas
  (let ((prev-area (clog:create-element win "div" :class "story-nav-prev"
                                         :style "position: absolute; top: 0; left: 0; width: 30%; height: 100%; z-index: 100; cursor: pointer;"))
        (next-area (clog:create-element win "div" :class "story-nav-next"
                                         :style "position: absolute; top: 0; right: 0; width: 30%; height: 100%; z-index: 100; cursor: pointer;")))
    (clog:on prev-area :click
             (lambda (ev)
               (declare (ignore ev))
               (when on-prev
                 (funcall on-prev))))
    (clog:on next-area :click
             (lambda (ev)
               (declare (ignore ev))
               (when on-next
                 (funcall on-next))))
    (clog:append! container prev-area)
    (clog:append! container next-area))

  ;; Reaction buttons
  (let ((reactions (clog:create-element win "div" :class "story-reactions"
                                         :style "position: absolute; bottom: 20px; right: 20px; display: flex; gap: 10px; z-index: 1001;")))
    (loop for emoji in '("❤️" "🔥" "👍" "😂")
          do (let ((btn (clog:create-element win "button" :class "reaction-btn"
                                              :style "font-size: 28px; background: rgba(0,0,0,0.3); border: none; border-radius: 50%; width: 50px; height: 50px; cursor: pointer;")))
               (setf (clog:text btn) emoji)
               (clog:on btn :click
                        (lambda (ev)
                          (declare (ignore ev))
                          (when on-react
                            (funcall on-react emoji))))
               (clog:append! reactions btn)))
    (clog:append! container reactions)))

(defun render-highlight (win container highlight on-click)
  "Render highlight item.

   Args:
     win: CLOG window object
     container: Container element
     highlight: Story-highlight object
     on-click: Callback when clicked"
  (let ((highlight-el (clog:create-element win "div" :class "highlight-item"
                                            :style "display: flex; flex-direction: column; align-items: center; cursor: pointer; padding: 10px;")))
    (clog:append! highlight_el
                  (clog:create-element win "div" :class "highlight-cover"
                                       :style "width: 70px; height: 70px; border-radius: 50%; background: #f0f0f0; display: flex; align-items: center; justify-content: center; border: 2px solid #ddd;"))
    (clog:append! highlight_el
                  (clog:create-element win "span" :class "highlight-title"
                                       :style "font-size: 12px; margin-top: 5px; color: #666;"
                                       :text (highlight-title highlight)))
    (clog:on highlight_el :click
             (lambda (ev)
               (declare (ignore ev))
               (when on-click
                 (funcall on-click highlight))))
    (clog:append! container highlight_el)))

(defun render-highlights-list (win container &key (on-click nil))
  "Render highlights list.

   Args:
     win: CLOG window object
     container: Container element
     on-click: Callback when highlight clicked"
  (let ((highlights (get-highlights)))
    (if (null highlights)
        (clog:append! container
                      (clog:create-element win "p" :text "No highlights" :style "color: #999;"))
        (let ((grid (clog:create-element win "div" :class "highlights-grid"
                                          :style "display: flex; gap: 15px; padding: 10px; overflow-x: auto;")))
          (loop for h in highlights
                do (render-highlight win grid h on-click))
          (clog:append! container grid)))))

;;; ### Utilities

(defun story-is-expired-p (story)
  "Check if story has expired.

   Args:
     story: Story object

   Returns:
     T if expired"
  (and (story-expiration-date story)
       (<= (story-expiration-date story) (get-universal-time))))

(defun story-time-remaining (story)
  "Get time remaining until story expires.

   Args:
     story: Story object

   Returns:
     Seconds remaining or NIL"
  (when (story-expiration-date story)
    (- (story-expiration-date story) (get-universal-time))))

(defun format-story-time (seconds)
  "Format story time remaining as human readable string.

   Args:
     seconds: Seconds remaining

   Returns:
     Formatted string"
  (cond
    ((null seconds) "Expired")
    ((< seconds 60) (format nil "~As" seconds))
    ((< seconds 3600) (format nil "~Am" (floor seconds 60)))
    ((< seconds 86400) (format nil "~Ah" (floor seconds 3600)))
    (t (format nil "~Ad" (floor seconds 86400)))))

(defun clear-stories-cache ()
  "Clear all stories cache.

   Returns:
     T on success"
  (clrhash *stories-cache*)
  t)

(defun clear-highlights-cache ()
  "Clear all highlights cache.

   Returns:
     T on success"
  (clrhash *highlights-cache*)
  t)
