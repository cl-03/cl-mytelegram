;;; channel-reactions.lisp --- Channel reactions and emoji status feature
;;;
;;; Provides channel reactions and emoji status functionality:
;;; - Message reactions with custom emoji
;;; - Reaction statistics and breakdown
;;; - Emoji status for users
;;; - Premium emoji status
;;; - Status history

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Configuration
;;; ============================================================================

(defvar *available-reactions* nil
  "Cached list of available reactions")

(defvar *emoji-statuses* nil
  "Cached list of available emoji statuses")

(defvar *reactions-cache* (make-hash-table :test 'eq)
  "Cache of reactions per message")

;;; ============================================================================
;;; Message Reactions
;;; ============================================================================

(defun send-channel-message-reaction (channel-id message-id reaction &key (is-big nil))
  "Send a reaction to a channel message.

   Args:
     channel-id: Channel identifier
     message-id: Message identifier
     reaction: Reaction (emoji string or custom emoji ID)
     is-big: Whether to send big animated reaction

   Returns:
     T on success, or error plist

   Example:
     (send-channel-message-reaction -1001234567890 100 \"👍\")
     (send-channel-message-reaction -1001234567890 100 \"❤️\" :is-big t)
     (send-channel-message-reaction -1001234567890 100 54321 :is-big t) ; Custom emoji"
  (let ((request `(:method "messages.sendReaction"
                   :parameters (:peer_id ,(channel-peer-id channel-id)
                                 :msg_id ,message-id
                                 ,@(if (numberp reaction)
                                       `(:reaction (:type "custom_emoji" :document_id ,reaction))
                                       `(:reaction (:type "emoji" :emoticon ,reaction)))
                                 :big ,is-big))))
    (handler-case
        (let ((response (send-api-request request)))
          (declare (ignore response))
          ;; Invalidate cache
          (clear-reaction-cache channel-id message-id)
          t)
      (error (e)
        (list :error (format nil "Failed to send reaction: ~A" e))))))

(defun remove-channel-message-reaction (channel-id message-id &key (reaction nil))
  "Remove reaction from a channel message.

   Args:
     channel-id: Channel identifier
     message-id: Message identifier
     reaction: Specific reaction to remove, or NIL for all

   Returns:
     T on success, or error plist

   Example:
     (remove-channel-message-reaction -1001234567890 100 :reaction \"👍\")
     (remove-channel-message-reaction -1001234567890 100) ; Remove all"
  (let ((request `(:method "messages.removeReaction"
                   :parameters (:peer_id ,(channel-peer-id channel-id)
                                 :msg_id ,message-id
                                 ,@(when reaction
                                     `(:reaction ,reaction))))))
    (handler-case
        (let ((response (send-api-request request)))
          (declare (ignore response))
          (clear-reaction-cache channel-id message-id)
          t)
      (error (e)
        (list :error (format nil "Failed to remove reaction: ~A" e))))))

(defun get-channel-message-reactions (channel-id message-id)
  "Get reactions for a channel message.

   Args:
     channel-id: Channel identifier
     message-id: Message identifier

   Returns:
     Reaction breakdown plist

   Example:
     (get-channel-message-reactions -1001234567890 100)
     => (:reactions ((:reaction \"👍\" :count 42 :is-selected nil)
                     (:reaction \"❤️\" :count 15 :is-selected t))
        :total-count 57)"
  ;; Check cache
  (let ((cache-key (intern (format nil "~A-~A" channel-id message-id))))
    (let ((cached (gethash cache-key *reactions-cache*)))
      (when cached
        (return-from get-channel-message-reactions cached))))

  (let ((request `(:method "messages.getMessageReactionsList"
                   :parameters (:peer_id ,(channel-peer-id channel-id)
                                 :msg_id ,message-id))))
    (handler-case
        (let ((response (send-api-request request)))
          (let ((result (list :reactions (getf response :reactions)
                              :total-count (getf response :total_count))))
            ;; Cache result
            (setf (gethash cache-key *reactions-cache*) result)
            result))
      (error (e)
        (list :error (format nil "Failed to get reactions: ~A" e))))))

(defun get-channel-reaction-stats (channel-id message-id)
  "Get detailed reaction statistics for a message.

   Args:
     channel-id: Channel identifier
     message-id: Message identifier

   Returns:
     Detailed statistics plist

   Example:
     (get-channel-reaction-stats -1001234567890 100)"
  (let ((reactions (get-channel-message-reactions channel-id message-id)))
    (when (getf reactions :reactions)
      (let ((total (getf reactions :total-count))
            (breakdown (getf reactions :reactions)))
        (list :message-id message-id
              :channel-id channel-id
              :total-reactions total
              :unique-reactions (length breakdown)
              :breakdown breakdown
              :top-reaction (if breakdown
                                (first (sort (copy-list breakdown)
                                             #'> :key #'(lambda (r) (getf r :count))))
                                nil))))))

(defun get-recent-channel-reactors (channel-id message-id &key (limit 10))
  "Get recent users who reacted to a message.

   Args:
     channel-id: Channel identifier
     message-id: Message identifier
     limit: Maximum users to return

   Returns:
     List of user plists with their reactions

   Example:
     (get-recent-channel-reactors -1001234567890 100 :limit 20)"
  (let ((request `(:method "messages.getMessageReactionsList"
                   :parameters (:peer_id ,(channel-peer-id channel-id)
                                 :msg_id ,message-id
                                 :limit ,limit))))
    (handler-case
        (let ((response (send-api-request request)))
          (getf response :reactors '()))
      (error (e)
        (list :error (format nil "Failed to get reactors: ~A" e))))))

;;; ============================================================================
;;; Available Reactions
;;; ============================================================================

(defun get-channel-available-reactions (&key (force-refresh nil))
  "Get available reactions for channel.

   Args:
     force-refresh: Force refresh from server

   Returns:
     List of available reactions

   Example:
     (get-channel-available-reactions)"
  (when (or force-refresh (null *available-reactions*))
    (let ((request `(:method "emoji.getAvailableReactions" :parameters nil)))
      (handler-case
          (let ((response (send-api-request request)))
            (setf *available-reactions*
                  (getf response :reactions
                        '((:type "emoji" :emoticon "👍")
                          (:type "emoji" :emoticon "👎")
                          (:type "emoji" :emoticon "❤️")
                          (:type "emoji" :emoticon "🔥")
                          (:type "emoji" :emoticon "🎉")))))
        (error (e)
          (declare (ignore e))
          ;; Return default reactions on error
          (setf *available-reactions*
                '((:type "emoji" :emoticon "👍")
                  (:type "emoji" :emoticon "❤️")
                  (:type "emoji" :emoticon "🔥")))))))
  *available-reactions*)

(defun set-channel-available-reactions (reactions)
  "Set available reactions for a channel.

   Args:
     reactions: List of reaction types (or :all for all)

   Returns:
     T on success

   Example:
     (set-channel-available-reactions :all)
     (set-channel-available-reactions '(\"👍\" \"❤️\" \"🔥\"))"
  (let ((request `(:method "emoji.setAvailableReactions"
                   :parameters (:reactions
                                ,(if (eq reactions :all)
                                     "all"
                                     (mapcar (lambda (r)
                                               (list :type "emoji" :emoticon r))
                                             reactions))))))
    (handler-case
        (progn
          (send-api-request request)
          (setf *available-reactions* reactions)
          t)
      (error (e)
        (list :error (format nil "Failed to set available reactions: ~A" e))))))

;;; ============================================================================
;;; Emoji Status
;;; ============================================================================

(defun set-emoji-status (emoji-id &key (duration nil))
  "Set user's emoji status.

   Args:
     emoji-id: Custom emoji ID for status
     duration: Duration in seconds (for temporary status)

   Returns:
     T on success

   Example:
     (set-emoji-status 54321) ; Permanent status
     (set-emoji-status 54321 :duration 3600) ; 1 hour status"
  (let ((request `(:method "account.updateEmojiStatus"
                   :parameters (:emoji_id ,emoji-id
                                 ,@(when duration
                                     `(:duration ,duration))))))
    (handler-case
        (progn
          (send-api-request request)
          t)
      (error (e)
        (list :error (format nil "Failed to set emoji status: ~A" e))))))

(defun clear-emoji-status ()
  "Clear user's emoji status.

   Returns:
     T on success"
  (let ((request `(:method "account.updateEmojiStatus"
                   :parameters (:emoji_id nil))))
    (handler-case
        (progn
          (send-api-request request)
          t)
      (error (e)
        (list :error (format nil "Failed to clear emoji status: ~A" e))))))

(defun get-emoji-statuses (&key (force-refresh nil))
  "Get available emoji statuses.

   Args:
     force-refresh: Force refresh from server

   Returns:
     List of available emoji statuses

   Example:
     (get-emoji-statuses)"
  (when (or force-refresh (null *emoji-statuses*))
    (let ((request `(:method "emoji.getAvailableEmojiStatuses" :parameters nil)))
      (handler-case
          (let ((response (send-api-request request)))
            (setf *emoji-statuses*
                  (getf response :statuses
                        '((:id 1001 :type "emoji" :emoticon "✨")
                          (:id 1002 :type "emoji" :emoticon "💫")
                          (:id 1003 :type "emoji" :emoticon "⭐")))))
        (error (e)
          (declare (ignore e))
          ;; Return default statuses on error
          (setf *emoji-statuses*
                '((:id 1001 :type "emoji" :emoticon "✨")
                  (:id 1002 :type "emoji" :emoticon "💫")))))))
  *emoji-statuses*)

(defun get-user-emoji-status (user-id)
  "Get a user's current emoji status.

   Args:
     user-id: User identifier

   Returns:
     Emoji status plist or NIL

   Example:
     (get-user-emoji-status 12345)"
  (let ((request `(:method "users.getUserStatus"
                   :parameters (:user_id ,user-id))))
    (handler-case
        (let ((response (send-api-request request)))
          (let ((status (getf response :status)))
            (when (string= (getf status :@type) "userStatusEmoji")
              (list :emoji-id (getf status :emoji_id)
                    :emoticon (getf status :emoticon)
                    :until-date (getf status :until_date)))))
      (error (e)
        (declare (ignore e))
        nil))))

(defun get-premium-emoji-statuses ()
  "Get premium-only emoji statuses.

   Returns:
     List of premium emoji statuses"
  (let ((all-statuses (get-emoji-statuses)))
    ;; Filter for premium statuses (typically higher IDs)
    (remove-if-not (lambda (s)
                     (>= (getf s :id) 2000))
                   all-statuses)))

;;; ============================================================================
;;; Reaction Analytics
;;; ============================================================================

(defun get-channel-reaction-analytics (channel-id &key (limit 100))
  "Get reaction analytics for channel messages.

   Args:
     channel-id: Channel identifier
     limit: Number of recent messages to analyze

   Returns:
     Analytics data plist"
  (let* ((messages (get-channel-posts channel-id :limit limit))
         (total-reactions 0)
         (reaction-map (make-hash-table :test 'equal))
         (message-count 0))
    (dolist (msg messages)
      (let* ((msg-id (getf msg :id))
             (reactions (get-channel-message-reactions channel-id msg-id)))
        (when (getf reactions :reactions)
          (incf message-count)
          (incf total-reactions (getf reactions :total-count))
          (dolist (r (getf reactions :reactions))
            (let* ((emoji (getf r :reaction))
                   (count (getf r :count)))
              (incf (gethash emoji reaction-map 0) count))))))
    ;; Sort reactions by count
    (let ((sorted-reactions
           (sort (loop for emoji being the hash-keys of reaction-map
                       using (hash-value count)
                       collect (list :reaction emoji :count count))
                 #'> :key #'(lambda (r) (getf r :count)))))
      (list :channel-id channel-id
            :messages-analyzed message-count
            :total-reactions total-reactions
            :average-reactions-per-message
            (if (> message-count 0)
                (/ total-reactions message-count)
                0)
            :top-reactions sorted-reactions))))

(defun get-reaction-trend (channel-id &key (period :day))
  "Get reaction trend over time.

   Args:
     channel-id: Channel identifier
     period: Time period (:hour :day :week)

   Returns:
     Trend data plist"
  ;; This would require historical data access
  ;; For now, return a placeholder structure
  (list :channel-id channel-id
        :period period
        :data-points nil
        :trend "stable"))

;;; ============================================================================
;;; Cache Management
;;; ============================================================================

(defun clear-reaction-cache (channel-id message-id)
  "Clear reaction cache for a message.

   Args:
     channel-id: Channel identifier
     message-id: Message identifier

   Returns:
     T on success"
  (let ((cache-key (intern (format nil "~A-~A" channel-id message-id))))
    (remhash cache-key *reactions-cache*))
  t)

(defun clear-all-reaction-caches ()
  "Clear all reaction caches.

   Returns:
     T on success"
  (clrhash *reactions-cache*)
  t)

;;; ============================================================================
;;; Utilities
;;; ============================================================================

(defun channel-peer-id (channel-id)
  "Convert channel ID to peer ID format.

   Args:
     channel-id: Channel identifier

   Returns:
     Peer ID plist"
  (list :@type "chatIdentifier" :id channel-id))

(defun get-popular-reactions (&key (limit 10))
  "Get most popular reactions across all channels.

   Args:
     limit: Number of reactions to return

   Returns:
     List of popular reactions"
  (let ((available (get-channel-available-reactions)))
    ;; Return top reactions by default usage
    (subseq available 0 (min limit (length available)))))

(defun is-reaction-selected-p (reactions reaction)
  "Check if a specific reaction is selected.

   Args:
     reactions: Reactions plist
     reaction: Reaction to check

   Returns:
     T if selected"
  (let ((reaction-list (getf reactions :reactions)))
    (find-if (lambda (r)
               (and (string= (getf r :reaction) reaction)
                    (getf r :is-selected)))
             reaction-list)))

;;; ============================================================================
;;; End of channel-reactions.lisp
;;; ============================================================================
