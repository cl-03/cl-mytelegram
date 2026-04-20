;;; stories.lisp --- Telegram Stories support
;;;
;;; Provides support for:
;;; - Stories viewing and posting
;;; - Stories list and highlights
;;; - Story privacy settings
;;; - Story reactions and views
;;; - Story expiration handling
;;; - Story animations and visual effects (v0.13.0)
;;; - Story filters and stickers (v0.13.0)
;;; - Story music and audio overlay (v0.13.0)

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
  (let ((key (format nil "~A" owner-id)))
    (let ((cached (gethash key *stories-cache*)))
      (if cached
          (subseq cached 0 (min limit (length cached)))
          ;; Fetch from API
          (handler-case
              (let* ((connection (get-connection))
                     (peer (make-tl-object 'inputPeerUser :user-id owner-id :access-hash 0))
                     (request (make-tl-object 'stories.getUserStories
                                              :peer peer
                                              :offset-id 0
                                              :limit limit)))
                (multiple-value-bind (result error)
                    (rpc-handler-case (rpc-call connection request :timeout 10000)
                      (tl-rpc-error (e) (values nil (error-message e)))
                      (timeout-error (e) (values nil :timeout))
                      (network-error (e) (values nil :network-error)))
                  (if error
                      (progn
                        (log:error "Failed to get stories: ~A" error)
                        nil)
                      (let ((stories (parse-stories-from-tl result)))
                        (setf (gethash key *stories-cache*) stories)
                        (subseq stories 0 (min limit (length stories)))))))
            (error (e)
              (log:error "Exception in get-stories: ~A" e)
              nil)
            ;; Return nil on API failure
            nil))))))

(defun get-all-stories (&key (limit 100))
  "Get all available stories from all contacts.

   Args:
     limit: Maximum total stories to return

   Returns:
     List of story objects grouped by owner"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.getAllStories
                                      :offset 0
                                      :limit limit)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 15000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get all stories: ~A" error)
                nil)
              (let ((all-stories (parse-stories-from-tl result)))
                ;; Cache by owner
                (loop for story in all-stories
                      for key = (format nil "~A" (story-owner story))
                      do (let ((existing (gethash key *stories-cache*)))
                           (if existing
                               (pushnew story existing :key #'story-id)
                               (setf (gethash key *stories-cache*) (list story)))))
                all-stories))))
    (error (e)
      (log:error "Exception in get-all-stories: ~A" e)
      nil)))

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
  (handler-case
      (let* ((connection (get-connection))
             (media-input (if (typep media 'string)
                              (make-tl-object 'inputMediaUploadedPhoto
                                              :file (parse-file-id media)
                                              :ttl-self-destruct 0)
                              media))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'stories.sendStory
                                      :media media-input
                                      :caption (or caption "")
                                      :entities nil
                                      :privacy (make-privacy-settings privacy)
                                      :can-reply can-reply
                                      :can-reshare can-reshare
                                      :random-id random-id)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to post story: ~A" error)
                nil)
              (let ((story (parse-story-from-tl result)))
                (when story
                  (let ((key (format nil "~A" (story-owner story))))
                    (let ((existing (gethash key *stories-cache*)))
                      (if existing
                          (push story existing)
                          (setf (gethash key *stories-cache*) (list story)))))
                  story)))))
    (error (e)
      (log:error "Exception in post-story: ~A" e)
      nil)))

(defun post-story-photo (photo-file-id &key (caption nil) (duration 24))
  "Post a photo story.

   Args:
     photo-file-id: Photo file ID
     caption: Optional caption
     duration: Story duration in hours (default 24)

   Returns:
     Story object on success"
  (handler-case
      (let* ((connection (get-connection))
             (media (make-tl-object 'inputMediaUploadedPhoto
                                    :file (parse-file-id photo-file-id)
                                    :ttl-self-destruct 0))
             (random-id (random (expt 2 63)))
             (expiration-date (+ (get-universal-time) (* duration 3600)))
             (request (make-tl-object 'stories.sendStory
                                      :media media
                                      :caption (or caption "")
                                      :entities nil
                                      :privacy (make-privacy-settings 'everybody)
                                      :can-reply t
                                      :can-reshare t
                                      :random-id random-id
                                      :expire-date expiration-date)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to post story photo: ~A" error)
                nil)
              (let ((story (parse-story-from-tl result)))
                (when story
                  (let ((key (format nil "~A" (story-owner story))))
                    (let ((existing (gethash key *stories-cache*)))
                      (if existing
                          (push story existing)
                          (setf (gethash key *stories-cache*) (list story)))))
                  story)))))
    (error (e)
      (log:error "Exception in post-story-photo: ~A" e)
      nil)))

(defun post-story-video (video-file-id &key (caption nil) (duration 24))
  "Post a video story.

   Args:
     video-file-id: Video file ID
     caption: Optional caption
     duration: Story duration in hours

   Returns:
     Story object on success"
  (handler-case
      (let* ((connection (get-connection))
             (media (make-tl-object 'inputMediaUploadedDocument
                                    :file (parse-file-id video-file-id)
                                    :mime-type "video/mp4"
                                    :attributes nil))
             (random-id (random (expt 2 63)))
             (expiration-date (+ (get-universal-time) (* duration 3600)))
             (request (make-tl-object 'stories.sendStory
                                      :media media
                                      :caption (or caption "")
                                      :entities nil
                                      :privacy (make-privacy-settings 'everybody)
                                      :can-reply t
                                      :can-reshare t
                                      :random-id random-id
                                      :expire-date expiration-date)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to post story video: ~A" error)
                nil)
              (let ((story (parse-story-from-tl result)))
                (when story
                  (let ((key (format nil "~A" (story-owner story))))
                    (let ((existing (gethash key *stories-cache*)))
                      (if existing
                          (push story existing)
                          (setf (gethash key *stories-cache*) (list story)))))
                  story)))))
    (error (e)
      (log:error "Exception in post-story-video: ~A" e)
      nil)))

(defun delete-story (story-id)
  "Delete a story.

   Args:
     story-id: Story ID to delete

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerSelf))
             (request (make-tl-object 'stories.deleteStories
                                      :id (list story-id))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to delete story: ~A" error)
                nil)
              (progn
                ;; Remove from cache
                (maphash (lambda (key stories)
                           (setf (gethash key *stories-cache*)
                                 (remove-if (lambda (s) (= (story-id s) story-id)) stories)))
                         *stories-cache*)
                t))))
    (error (e)
      (log:error "Exception in delete-story: ~A" e)
      nil)))

(defun edit-story (story-id &key (caption nil) (privacy nil))
  "Edit story properties.

   Args:
     story-id: Story ID to edit
     caption: New caption
     privacy: New privacy setting

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerSelf))
             (request (make-tl-object 'stories.editStory
                                      :id story-id
                                      :caption (or caption "")
                                      :entities nil
                                      :privacy (when privacy (make-privacy-settings privacy)))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to edit story: ~A" error)
                nil)
              (progn
                ;; Update cache
                (maphash (lambda (key stories)
                           (loop for story in stories
                                 when (= (story-id story) story-id)
                                 do (when caption
                                      (setf (slot-value story 'caption) caption))
                                 when privacy
                                 do (setf (slot-value story 'privacy) privacy)))
                         *stories-cache*)
                t))))
    (error (e)
      (log:error "Exception in edit-story: ~A" e)
      nil)))

(defun pin-story (story-id)
  "Pin story to profile.

   Args:
     story-id: Story ID to pin

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerSelf))
             (request (make-tl-object 'stories.togglePinned
                                      :id (list story-id))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to pin story: ~A" error)
                nil)
              (progn
                ;; Update cache
                (maphash (lambda (key stories)
                           (loop for story in stories
                                 when (= (story-id story) story-id)
                                 do (setf (slot-value story 'is-pinned) t)))
                         *stories-cache*)
                t))))
    (error (e)
      (log:error "Exception in pin-story: ~A" e)
      nil)))

(defun unpin-story (story-id)
  "Unpin story from profile.

   Args:
     story-id: Story ID to unpin

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerSelf))
             (request (make-tl-object 'stories.togglePinned
                                      :id (list story-id))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to unpin story: ~A" error)
                nil)
              (progn
                ;; Update cache
                (maphash (lambda (key stories)
                           (loop for story in stories
                                 when (= (story-id story) story-id)
                                 do (setf (slot-value story 'is-pinned) nil)))
                         *stories-cache*)
                t))))
    (error (e)
      (log:error "Exception in unpin-story: ~A" e)
      nil)))

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
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.getPrivacy
                                      :key (make-tl-object 'privacyKeyStory))))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (t (c)
            (log-error "Failed to get story privacy: ~A" c)
            (make-instance 'story-privacy :type 'everybody))))
    (t (c)
      (log-error "Error getting story privacy: ~A" c)
      (make-instance 'story-privacy :type 'everybody))))

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
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id 0 :access-hash 0)) ; Owner ID needed
             (request (make-tl-object 'stories.sendReaction
                                      :peer peer
                                      :story-id story-id
                                      :reaction (make-tl-object 'messageReactionEmoji :emoji emoji))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to send story reaction: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in send-story-reaction: ~A" e)
      nil)))

(defun get-story-views (story-id &key (limit 100))
  "Get users who viewed the story.

   Args:
     story-id: Story ID
     limit: Maximum users to return

   Returns:
     List of user objects"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id 0 :access-hash 0)) ; Owner ID needed
             (request (make-tl-object 'stories.getStoryViews
                                      :peer peer
                                      :id story-id
                                      :offset 0
                                      :limit limit)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to get story views: ~A" error)
                nil)
              (parse-story-viewers-from-tl result))))
    (error (e)
      (log:error "Exception in get-story-views: ~A" e)
      nil)))

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
  (handler-case
      (let* ((connection (get-connection))
             (from-peer (make-tl-object 'inputPeerUser :user-id 0 :access-hash 0)) ; Owner ID needed
             (to-peer (make-tl-object 'inputPeerUser :user-id to-chat-id :access-hash 0))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'messages.forwardMessages
                                      :from-peer from-peer
                                      :to-peer to-peer
                                      :id (list story-id)
                                      :random-id (list random-id)
                                      :as-story t
                                      :drop-author nil
                                      :drop-media-captions nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to forward story: ~A" error)
                nil)
              (parse-message-from-tl result))))
    (error (e)
      (log:error "Exception in forward-story: ~A" e)
      nil)))

(defun reply-to-story (story-id text &key (media nil))
  "Send reply to a story.

   Args:
     story-id: Story ID
     text: Reply text
     media: Optional media attachment

   Returns:
     Message object on success"
  (handler-case
      (let* ((connection (get-connection))
             (peer (make-tl-object 'inputPeerUser :user-id 0 :access-hash 0)) ; Owner ID needed
             (message (if media
                          (make-media-message media text)
                          (make-tl-object 'inputMessageText
                                          :message text
                                          :entities nil
                                          :clear-draft nil)))
             (random-id (random (expt 2 63)))
             (reply-to (make-tl-object 'inputMessageReplyToStory
                                       :peer peer
                                       :story-id story-id))
             (request (make-tl-object 'messages.sendMessage
                                      :peer peer
                                      :message message
                                      :random-id random-id
                                      :schedule-date 0
                                      :reply-to reply-to
                                      :reply-markup nil)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 30000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to reply to story: ~A" error)
                nil)
              (parse-message-from-tl result))))
    (error (e)
      (log:error "Exception in reply-to-story: ~A" e)
      nil)))

;;; ### Story Highlights

(defun create-highlight (title &key (cover-media nil) (story-ids nil))
  "Create a new story highlight.

   Args:
     title: Highlight title
     cover-media: Optional cover media
     story-ids: List of story IDs to include

   Returns:
     Story-highlight object on success"
  (handler-case
      (let* ((connection (get-connection))
             (random-id (random (expt 2 63)))
             (request (make-tl-object 'stories.createHighlight
                                      :title title
                                      :cover (when cover-media
                                               (make-tl-object 'inputChatPhotoUploaded
                                                               :file (parse-file-id cover-media)))
                                      :stories (or story-ids nil)
                                      :random-id random-id)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to create highlight: ~A" error)
                nil)
              (let ((highlight (parse-highlight-from-tl result)))
                (when highlight
                  (let ((key (format nil "~A" (highlight-id highlight))))
                    (setf (gethash key *highlights-cache*) (list highlight)))
                  highlight)))))
    (error (e)
      (log:error "Exception in create-highlight: ~A" e)
      nil)))

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
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.editHighlight
                                      :id highlight-id
                                      :title (or title "")
                                      :cover (when cover-media
                                               (make-tl-object 'inputChatPhotoUploaded
                                                               :file (parse-file-id cover-media))))))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to edit highlight: ~A" error)
                nil)
              (progn
                ;; Update cache
                (loop for key being the hash-keys of *highlights-cache*
                      for highlights = (gethash key *highlights-cache*)
                      do (loop for h in highlights
                               when (= (highlight-id h) highlight-id)
                               do (when title
                                    (setf (slot-value h 'title) title))
                                  (when cover-media
                                    (setf (slot-value h 'cover-media) cover-media))))
                t))))
    (error (e)
      (log:error "Exception in edit-highlight: ~A" e)
      nil)))

(defun add-stories-to-highlight (highlight-id story-ids)
  "Add stories to highlight.

   Args:
     highlight-id: Highlight ID
     story-ids: List of story IDs to add

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.addHighlightStory
                                      :id highlight-id
                                      :id-story story-ids)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to add stories to highlight: ~A" error)
                nil)
              t)))
    (error (e)
      (log:error "Exception in add-stories-to-highlight: ~A" e)
      nil)))

(defun remove-highlight (highlight-id)
  "Remove a highlight.

   Args:
     highlight-id: Highlight ID

   Returns:
     T on success"
  (handler-case
      (let* ((connection (get-connection))
             (request (make-tl-object 'stories.deleteHighlight
                                      :id highlight-id)))
        (multiple-value-bind (result error)
            (rpc-handler-case (rpc-call connection request :timeout 10000)
              (tl-rpc-error (e) (values nil (error-message e)))
              (timeout-error (e) (values nil :timeout))
              (network-error (e) (values nil :network-error)))
          (if error
              (progn
                (log:error "Failed to remove highlight: ~A" error)
                nil)
              (progn
                ;; Remove from cache
                (loop for key being the hash-keys of *highlights-cache*
                      do (setf (gethash key *highlights-cache*)
                               (remove-if (lambda (h) (= (highlight-id h) highlight-id))
                                          (gethash key *highlights-cache*))))
                t))))
    (error (e)
      (log:error "Exception in remove-highlight: ~A" e)
      nil)))

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

;;; ### Story Animations and Visual Effects (v0.13.0)

;;; Story Animation Types

(defclass story-animation ()
  ((animation-type :initarg :type :initform nil :reader story-animation-type)
   (animation-id :initarg :id :initform nil :reader story-animation-id)
   (duration :initarg :duration :initform 3000 :reader story-animation-duration)
   (delay :initarg :delay :initform 0 :reader story-animation-delay)
   (intensity :initarg :intensity :initform 1.0 :reader story-animation-intensity)))

(defclass story-filter ()
  ((filter-type :initarg :type :initform :normal :reader story-filter-type)
   (filter-intensity :initarg :intensity :initform 1.0 :reader story-filter-intensity)
   (filter-settings :initarg :settings :initform nil :reader story-filter-settings)))

(defclass story-music ()
  ((music-title :initarg :title :reader story-music-title)
   (music-artist :initarg :artist :reader story-music-artist)
   (music-url :initarg :url :reader story-music-url)
   (music-duration :initarg :duration :initform 30 :reader story-music-duration)
   (music-start-time :initarg :start-time :initform 0 :reader story-music-start-time)))

(defclass story-drawing ()
  ((drawing-color :initarg :color :initform "#FFFFFF" :reader story-drawing-color)
   (drawing-strokes :initarg :strokes :initform nil :reader story-drawing-strokes)
   (drawing-tool :initarg :tool :initform :pen :reader story-drawing-tool)))

(defclass story-text-style ()
  ((text-font :initarg :font :initform "sans-serif" :reader story-text-font)
   (text-size :initarg :size :initform 24 :reader story-text-size)
   (text-color :initarg :color :initform "#FFFFFF" :reader story-text-color)
   (text-background :initarg :background :initform nil :reader story-text-background)
   (text-alignment :initarg :alignment :initform :center :reader story-text-alignment)))

;;; Available Animations

(defparameter *available-story-animations*
  '(:fade-in         ; 淡入
    :zoom-in         ; 放大
    :slide-left      ; 左滑入
    :slide-right     ; 右滑入
    :slide-up        ; 上滑入
    :slide-down      ; 下滑入
    :bounce          ; 弹跳
    :rotate          ; 旋转
    :flip            ; 翻转
    :typewriter      ; 打字机效果
    :glitch          ; 故障效果
    :sparkle         ; 闪光效果
    :pulse           ; 脉冲效果
    :shake           ; 震动效果
    :pan             ; 平移效果
    :morph           ; 变形效果
    )
  "Available story animation types")

(defparameter *available-story-filters*
  '(:normal          ; 正常
    :vintage         ; 复古
    :bw              ; 黑白
    :sepia           ; 棕褐色
    :warm            ; 暖色
    :cool            ; 冷色
    :vivid           ; 鲜艳
    :fade            ; 褪色
    :dramatic        ; 戏剧
    :soft            ; 柔和
    :noir            ; 黑色电影
    :cyberpunk       ; 赛博朋克
    :golden          ; 金色时光
    :blue-hour       ; 蓝色时刻
    :cinematic       ; 电影感
    )
  "Available story filter types")

;;; Global State for Effects

(defvar *story-effects-cache* (make-hash-table :test 'equal)
  "Cache for story effects and animations")

(defvar *active-story-animation* nil
  "Currently active story animation")

;;; Animation Creation

(defun make-story-animation (animation-type &key (duration 3000) (delay 0) (intensity 1.0))
  "Create story animation.

   Args:
     animation-type: Animation type keyword
     duration: Animation duration in ms (default: 3000)
     delay: Delay before starting in ms (default: 0)
     intensity: Animation intensity 0.0-1.0 (default: 1.0)

   Returns:
     Story-animation object"
  (make-instance 'story-animation
                 :type animation-type
                 :duration duration
                 :delay delay
                 :intensity intensity))

(defun make-story-filter (filter-type &key (intensity 1.0) settings)
  "Create story filter.

   Args:
     filter-type: Filter type keyword
     intensity: Filter intensity 0.0-1.0 (default: 1.0)
     settings: Additional filter settings plist

   Returns:
     Story-filter object"
  (make-instance 'story-filter
                 :type filter-type
                 :intensity intensity
                 :settings settings))

(defun make-story-music (title artist url &key (duration 30) (start-time 0))
  "Create story music overlay.

   Args:
     title: Music title
     artist: Artist name
     url: Music URL or file ID
     duration: Clip duration in seconds (default: 30)
     start-time: Start time in seconds (default: 0)

   Returns:
     Story-music object"
  (make-instance 'story-music
                 :title title
                 :artist artist
                 :url url
                 :duration duration
                 :start-time start-time))

(defun make-story-drawing (&key (color "#FFFFFF") (tool :pen) strokes)
  "Create story drawing.

   Args:
     color: Drawing color (hex)
     tool: Drawing tool (:pen :marker :highlighter)
     strokes: List of stroke data

   Returns:
     Story-drawing object"
  (make-instance 'story-drawing
                 :color color
                 :tool tool
                 :strokes strokes))

(defun make-story-text-style (&key (font "sans-serif") (size 24) (color "#FFFFFF")
                                    (background nil) (alignment :center))
  "Create story text style.

   Args:
     font: Font family
     size: Font size in pixels
     color: Text color (hex)
     background: Background color or NIL
     alignment: Text alignment (:left :center :right)

   Returns:
     Story-text-style object"
  (make-instance 'story-text-style
                 :font font
                 :size size
                 :color color
                 :background background
                 :alignment alignment))

;;; Applying Effects to Stories

(defun apply-animation-to-story (story animation)
  "Apply animation to story.

   Args:
     story: Story object
     animation: Story-animation object

   Returns:
     Story with animation applied"
  (let ((story-id (story-id story)))
    ;; Cache animation
    (setf (gethash (format nil "~A:animation" story-id) *story-effects-cache*) animation)
    story))

(defun apply-filter-to-story (story filter)
  "Apply filter to story.

   Args:
     story: Story object
     filter: Story-filter object

   Returns:
     Story with filter applied"
  (let ((story-id (story-id story)))
    (setf (gethash (format nil "~A:filter" story-id) *story-effects-cache*) filter)
    story))

(defun apply-music-to-story (story music)
  "Apply music overlay to story.

   Args:
     story: Story object
     music: Story-music object

   Returns:
     Story with music applied"
  (let ((story-id (story-id story)))
    (setf (gethash (format nil "~A:music" story-id) *story-effects-cache*) music)
    story))

(defun apply-drawing-to-story (story drawing)
  "Apply drawing to story.

   Args:
     story: Story object
     drawing: Story-drawing object

   Returns:
     Story with drawing applied"
  (let ((story-id (story-id story)))
    (setf (gethash (format nil "~A:drawing" story-id) *story-effects-cache*) drawing)
    story))

(defun apply-text-style-to-story (story text style)
  "Apply text style to story text.

   Args:
     story: Story object
     text: Text string to style
     style: Story-text-style object

   Returns:
     Styled text object"
  (list :text text
        :style style))

;;; Post Story with Effects

(defun post-story-with-animation (media animation &key (caption nil) (privacy 'everybody))
  "Post story with animation.

   Args:
     media: Media object
     animation: Story-animation or animation keyword
     caption: Optional caption
     privacy: Privacy setting

   Returns:
     Story object"
  (let ((anim-obj (if (typep animation 'story-animation)
                      animation
                      (make-story-animation animation))))
    ;; Post story first
    (let ((story (post-story media :caption caption :privacy privacy)))
      (when story
        (apply-animation-to-story story anim-obj)
        story))))

(defun post-story-with-filter (media filter &key (caption nil) (privacy 'everybody))
  "Post story with filter.

   Args:
     media: Media object
     filter: Story-filter or filter keyword
     caption: Optional caption
     privacy: Privacy setting

   Returns:
     Story object"
  (let ((filter-obj (if (typep filter 'story-filter)
                        filter
                        (make-story-filter filter))))
    (let ((story (post-story media :caption caption :privacy privacy)))
      (when story
        (apply-filter-to-story story filter-obj)
        story))))

(defun post-story-with-music (media music &key (caption nil) (privacy 'everybody))
  "Post story with music overlay.

   Args:
     media: Media object (photo or video)
     music: Story-music object or music info plist
     caption: Optional caption
     privacy: Privacy setting

   Returns:
     Story object"
  (let ((music-obj (if (typep music 'story-music)
                       music
                       (make-story-music (getf music :title)
                                         (getf music :artist)
                                         (getf music :url)))))
    (let ((story (post-story media :caption caption :privacy privacy)))
      (when story
        (apply-music-to-story story music-obj)
        story))))

(defun post-story-with-drawing (media drawing &key (caption nil) (privacy 'everybody))
  "Post story with drawing.

   Args:
     media: Media object
     drawing: Story-drawing or drawing data
     caption: Optional caption
     privacy: Privacy setting

   Returns:
     Story object"
  (let ((drawing-obj (if (typep drawing 'story-drawing)
                         drawing
                         (make-story-drawing))))
    (let ((story (post-story media :caption caption :privacy privacy)))
      (when story
        (apply-drawing-to-story story drawing-obj)
        story))))

;;; Effect Presets

(defparameter *story-effect-presets*
  '((:cinematic . (:filter :cinematic
                 :animation :fade-in
                 :text-style (:font "Georgia" :size 28 :color "#F0E6D2")))
    (:vlog . (:filter :warm
            :animation :slide-up
            :music (:title "Upbeat" :artist "Vlog Music" :url "vlog-theme")))
    (:dramatic . (:filter :dramatic
                :animation :zoom-in
                :text-style (:font "Impact" :size 32 :color "#FFFFFF" :background "#000000")))
    (:minimal . (:filter :normal
               :animation :fade-in
               :text-style (:font "Helvetica" :size 24 :color "#333333")))
    (:party . (:filter :vivid
             :animation :bounce
             :music (:title "Party Mix" :artist "DJ" :url "party-theme")))
    (:nostalgic . (:filter :vintage
                 :animation :slide-left
                 :text-style (:font "Courier" :size 20 :color "#8B7355"))))
  "Preset story effect combinations")

(defun apply-story-preset (story preset-keyword)
  "Apply preset effect combination to story.

   Args:
     story: Story object
     preset-keyword: Preset keyword (:cinematic :vlog :dramatic :minimal :party :nostalgic)

   Returns:
     Story with effects applied"
  (let ((preset (cdr (assoc preset-keyword *story-effect-presets*))))
    (unless preset
      (error "Unknown preset: ~A" preset-keyword))

    ;; Apply filter
    (when (getf preset :filter)
      (apply-filter-to-story story (make-story-filter (getf preset :filter))))

    ;; Apply animation
    (when (getf preset :animation)
      (apply-animation-to-story story (make-story-animation (getf preset :animation))))

    ;; Apply music if present
    (when (getf preset :music)
      (let ((music-info (getf preset :music)))
        (apply-music-to-story story
                              (make-story-music (getf music-info :title)
                                                (getf music-info :artist)
                                                (getf music-info :url)))))

    story))

;;; Story Drawing Tools

(defun create-drawing-stroke (points &key (color "#FFFFFF") (width 3) (tool :pen))
  "Create drawing stroke for story.

   Args:
     points: List of (x y) coordinate pairs
     color: Stroke color
     width: Stroke width in pixels
     tool: Tool type

   Returns:
     Stroke data plist"
  (list :points points
        :color color
        :width width
        :tool tool))

(defun create-emoji-sticker (emoji x y &key (size 48) (rotation 0))
  "Create emoji sticker for story.

   Args:
     emoji: Emoji character
     x: X position (0-100 percentage)
     y: Y position (0-100 percentage)
     size: Sticker size in pixels
     rotation: Rotation in degrees

   Returns:
     Sticker data plist"
  (list :type :emoji
        :emoji emoji
        :x x
        :y y
        :size size
        :rotation rotation))

(defun create-text-overlay (text x y &key (style nil) (background nil))
  "Create text overlay for story.

   Args:
     text: Text string
     x: X position (0-100 percentage)
     y: Y position (0-100 percentage)
     style: Text style object or plist
     background: Background color or NIL

   Returns:
     Text overlay data plist"
  (list :type :text
        :text text
        :x x
        :y y
        :style style
        :background background))

;;; Animation Rendering (CLOG)

(defun render-story-animation (win container story)
  "Render story with animation in CLOG.

   Args:
     win: CLOG window
     container: Container element
     story: Story object

   Returns:
     Animation elements"
  (let ((story-id (story-id story))
        (animation (gethash (format nil "~A:animation" story-id) *story-effects-cache*)))

    ;; Get media element
    (let ((media-el (clog:create-element win "div" :class "story-media-container"
                                         :style "width: 100%; height: 100%; position: relative; overflow: hidden;")))
      ;; Apply animation class based on type
      (when animation
        (let ((anim-type (story-animation-type animation))
              (duration (story-animation-duration animation)))
          ;; Create style for animation
          (let ((anim-style (clog:create-element win "style"))
                (anim-keyframes (case anim-type
                                  (:fade-in "@keyframes fadeIn{from{opacity:0}to{opacity:1}}")
                                  (:zoom-in "@keyframes zoomIn{from{transform:scale(0.5)}to{transform:scale(1)}}")
                                  (:slide-up "@keyframes slideUp{from{transform:translateY(100%)}to{transform:translateY(0)}}")
                                  (:slide-down "@keyframes slideDown{from{transform:translateY(-100%)}to{transform:translateY(0)}}")
                                  (:bounce "@keyframes bounce{0%,100%{transform:translateY(0)}50%{transform:translateY(-20px)}}")
                                  (otherwise ""))))
            (setf (clog:html anim-style) anim-keyframes)
            (clog:append! (clog:body win) anim-style)

            ;; Apply to media element
            (let ((anim-name (case anim-type
                               (:fade-in "fadeIn")
                               (:zoom-in "zoomIn")
                               (:slide-up "slideUp")
                               (:slide-down "slideDown")
                               (:bounce "bounce")
                               (otherwise "")))
              (clog:set-css media-el "animation"
                            (format nil "~A ~Ams ease-out"
                                    anim-name duration))))))

      (clog:append! container media-el))))

;;; Utilities

(defun get-story-effects (story)
  "Get all effects applied to story.

   Args:
     story: Story object

   Returns:
     Plist of effects"
  (let ((story-id (story-id story)))
    (list :animation (gethash (format nil "~A:animation" story-id) *story-effects-cache*)
          :filter (gethash (format nil "~A:filter" story-id) *story-effects-cache*)
          :music (gethash (format nil "~A:music" story-id) *story-effects-cache*)
          :drawing (gethash (format nil "~A:drawing" story-id) *story-effects-cache*))))

(defun remove-story-effects (story)
  "Remove all effects from story.

   Args:
     story: Story object

   Returns:
     T on success"
  (let ((story-id (story-id story)))
    (remhash (format nil "~A:animation" story-id) *story-effects-cache*)
    (remhash (format nil "~A:filter" story-id) *story-effects-cache*)
    (remhash (format nil "~A:music" story-id) *story-effects-cache*)
    (remhash (format nil "~A:drawing" story-id) *story-effects-cache*)
    t))

(defun preview-story-effect (effect-type)
  "Preview story effect.

   Args:
     effect-type: Effect keyword

   Returns:
     Preview data"
  (case effect-type
    (:filter (list :type :filter
                   :name effect-type
                   :preview-url (format nil "https://telegram.org/stories/filters/~A.jpg" effect-type)))
    (:animation (list :type :animation
                      :name effect-type
                      :duration 3000))
    (otherwise (list :type :unknown
                     :name effect-type))))

(defun clear-story-effects-cache ()
  "Clear story effects cache.

   Returns:
     T on success"
  (clrhash *story-effects-cache*)
  t)
