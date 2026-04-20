;;; channel-advanced.lisp --- Channel advanced features: topics, statistics, sponsored messages
;;; Part of v0.21.0 - User Experience Enhancements

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Forum Topic Classes
;;; ======================================================================

(defclass forum-topic ()
  ((message-thread-id :initarg :message-thread-id :accessor forum-topic-message-thread-id
                      :initform 0 :documentation "Thread ID of the topic")
   (name :initarg :name :accessor forum-topic-name
         :initform "" :documentation "Topic name, 1-128 chars")
   (icon-color :initarg :icon-color :accessor forum-topic-icon-color
               :initform nil :documentation "Icon color in RGB format")
   (icon-custom-emoji-id :initarg :icon-custom-emoji-id
                         :accessor forum-topic-icon-custom-emoji-id
                         :initform nil :documentation "Custom emoji ID for icon")
   (is-closed :initarg :is-closed :accessor forum-topic-is-closed
              :initform nil :documentation "True if topic is closed")
   (is-hidden :initarg :is-hidden :accessor forum-topic-is-hidden
              :initform nil :documentation "True if topic is hidden")
   (creator-id :initarg :creator-id :accessor forum-topic-creator-id
               :initform 0 :documentation "Creator user ID")
   (date-created :initarg :date-created :accessor forum-topic-date-created
                 :initform 0 :documentation "Creation date (Unix time)")
   (last-message-id :initarg :last-message-id :accessor forum-topic-last-message-id
                    :initform 0 :documentation "Last message ID in topic")
   (unread-count :initarg :unread-count :accessor forum-topic-unread-count
                 :initform 0 :documentation "Unread message count")
   (is-pinned :initarg :is-pinned :accessor forum-topic-is-pinned
              :initform nil :documentation "True if topic is pinned")))

(defclass forum-topic-info ()
  ((total-count :initarg :total-count :accessor forum-total-count
                :initform 0 :documentation "Total topics in forum")
   (topics :initarg :topics :accessor forum-topics-list
           :initform nil :documentation "List of forum-topic objects")))

(defclass channel-statistics ()
  ((channel-id :initarg :channel-id :accessor stats-channel-id
               :initform 0 :documentation "Channel ID")
   (period-start :initarg :period-start :accessor stats-period-start
                 :initform 0 :documentation "Period start (Unix time)")
   (period-end :initarg :period-end :accessor stats-period-end
               :initform 0 :documentation "Period end (Unix time)")
   (member-count :initarg :member-count :accessor stats-member-count
                 :initform 0 :documentation "Current member count")
   (view-count :initarg :view-count :accessor stats-view-count
               :initform 0 :documentation "Total views in period")
   (share-count :initarg :share-count :accessor stats-share-count
                :initform 0 :documentation "Total shares in period")
   (new-members :initarg :new-members :accessor stats-new-members
                :initform 0 :documentation "New members in period")
   (left-members :initarg :left-members :accessor stats-left-members
                 :initform 0 :documentation "Members who left in period")
   (language-stats :initarg :language-stats :accessor stats-language-stats
                   :initform nil :documentation "Language distribution")
   (hourly-activity :initarg :hourly-activity :accessor stats-hourly-activity
                    :initform nil :documentation "Hourly activity data")
   (growth-graph :initarg :growth-graph :accessor stats-growth-graph
                 :initform nil :documentation "Member growth data points")))

(defclass message-statistics ()
  ((message-id :initarg :message-id :accessor msg-stats-message-id
               :initform 0 :documentation "Message ID")
  (view-count :initarg :view-count :accessor msg-stats-view-count
              :initform 0 :documentation "View count")
  (forward-count :initarg :forward-count :accessor msg-stats-forward-count
                 :initform 0 :documentation "Forward count")
  (reaction-count :initarg :reaction-count :accessor msg-stats-reaction-count
                  :initform 0 :documentation "Total reactions")
  (reactions :initarg :reactions :accessor msg-stats-reactions
             :initform nil :documentation "Reaction breakdown")
  (hourly-views :initarg :hourly-views :accessor msg-stats-hourly-views
                :initform nil :documentation "Views per hour")))

(defclass sponsored-message ()
  ((message-id :initarg :message-id :accessor sponsored-message-id
               :initform 0 :documentation "Message ID")
   (text :initarg :text :accessor sponsored-message-text
         :initform "" :documentation "Message text")
   (link-url :initarg :link-url :accessor sponsored-message-link-url
             :initform "" :documentation "Sponsored link URL")
   (link-name :initarg :link-name :accessor sponsored-message-link-name
              :initform "" :documentation "Link display name")
   (is-promoted :initarg :is-promoted :accessor sponsored-message-is-promoted
                :initform nil :documentation "True if promoted (not auto)")))

(defclass reaction-statistics ()
  ((message-id :initarg :message-id :accessor reaction-stats-message-id
               :initform 0 :documentation "Message ID")
   (total-reactions :initarg :total-reactions :accessor reaction-stats-total
                    :initform 0 :documentation "Total reaction count")
   (reaction-breakdown :initarg :reaction-breakdown :accessor reaction-stats-breakdown
                       :initform nil :documentation "Breakdown by reaction type")
   (recent-reactors :initarg :recent-reactors :accessor reaction-stats-reactors
                    :initform nil :documentation "Recent users who reacted")))

;;; ======================================================================
;;; Forum Topic Management
;;; ======================================================================

(defun create-forum-topic (chat-id name &key icon-color icon-custom-emoji-id)
  "Create a new forum topic in a supergroup or private chat.

   CHAT-ID: Target supergroup or private chat ID
   NAME: Topic name, 1-128 characters
   ICON-COLOR: Optional RGB color for topic icon
   ICON-CUSTOM-EMOJI-ID: Optional custom emoji ID for icon

   Returns forum-topic object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("name" . ,name))))
        (when icon-color
          (push (cons "icon_color" icon-color) params))
        (when icon-custom-emoji-id
          (push (cons "icon_custom_emoji_id" icon-custom-emoji-id) params))

        (let ((result (make-api-call connection "createForumTopic" params)))
          (if result
              (progn
                (log-message :info "Forum topic '~A' created in ~A" name chat-id)
                (parse-forum-topic result))
              nil)))
    (error (e)
      (log-message :error "Error creating forum topic: ~A" (princ-to-string e))
      nil)))

(defun parse-forum-topic (data)
  "Parse forum topic from API response."
  (make-instance 'forum-topic
                 :message-thread-id (gethash "message_thread_id" data 0)
                 :name (gethash "name" data "")
                 :icon-color (gethash "icon_color" data)
                 :icon-custom-emoji-id (gethash "icon_custom_emoji_id" data)
                 :is-closed (gethash "is_closed" data)
                 :is-hidden (gethash "is_hidden" data)
                 :creator-id (gethash "creator_id" data 0)
                 :date-created (gethash "date_created" data 0)))

(defun get-forum-topics (chat-id &key offset limit)
  "Get list of forum topics in a chat.

   CHAT-ID: Target forum chat ID
   OFFSET: Offset for pagination
   LIMIT: Maximum topics to return

   Returns forum-topic-info object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id))))
        (when offset
          (push (cons "offset" offset) params))
        (when limit
          (push (cons "limit" limit) params))

        (let ((result (make-api-call connection "getForumTopics" params)))
          (if result
              (make-instance 'forum-topic-info
                             :total-count (gethash "total_count" result 0)
                             :topics (loop for topic-data across (gethash "topics" result)
                                           collect (parse-forum-topic topic-data)))
              nil)))
    (error (e)
      (log-message :error "Error getting forum topics: ~A" (princ-to-string e))
      nil)))

(defun edit-forum-topic (chat-id message-thread-id &key name icon-color icon-custom-emoji-id)
  "Edit a forum topic.

   CHAT-ID: Target forum chat ID
   MESSAGE-THREAD-ID: Thread ID of topic to edit
   NAME: Optional new name
   ICON-COLOR: Optional new icon color
   ICON-CUSTOM-EMOJI-ID: Optional new custom emoji ID

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_thread_id" . ,message-thread-id))))
        (when name
          (push (cons "name" name) params))
        (when icon-color
          (push (cons "icon_color" icon-color) params))
        (when icon-custom-emoji-id
          (push (cons "icon_custom_emoji_id" icon-custom-emoji-id) params))

        (let ((result (make-api-call connection "editForumTopic" params)))
          (if result
              (progn
                (log-message :info "Forum topic ~A edited" message-thread-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error editing forum topic: ~A" (princ-to-string e))
      nil)))

(defun close-forum-topic (chat-id message-thread-id)
  "Close a forum topic.

   CHAT-ID: Target forum chat ID
   MESSAGE-THREAD-ID: Thread ID of topic to close

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_thread_id" . ,message-thread-id))))
        (let ((result (make-api-call connection "closeForumTopic" params)))
          (if result
              (progn
                (log-message :info "Forum topic ~A closed" message-thread-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error closing forum topic: ~A" (princ-to-string e))
      nil)))

(defun reopen-forum-topic (chat-id message-thread-id)
  "Reopen a closed forum topic.

   CHAT-ID: Target forum chat ID
   MESSAGE-THREAD-ID: Thread ID of topic to reopen

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_thread_id" . ,message-thread-id))))
        (let ((result (make-api-call connection "reopenForumTopic" params)))
          (if result
              (progn
                (log-message :info "Forum topic ~A reopened" message-thread-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error reopening forum topic: ~A" (princ-to-string e))
      nil)))

(defun delete-forum-topic (chat-id message-thread-id)
  "Delete a forum topic.

   CHAT-ID: Target forum chat ID
   MESSAGE-THREAD-ID: Thread ID of topic to delete

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_thread_id" . ,message-thread-id))))
        (let ((result (make-api-call connection "deleteForumTopic" params)))
          (if result
              (progn
                (log-message :info "Forum topic ~A deleted" message-thread-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error deleting forum topic: ~A" (princ-to-string e))
      nil)))

(defun pin-forum-topic (chat-id message-thread-id)
  "Pin a forum topic.

   CHAT-ID: Target forum chat ID
   MESSAGE-THREAD-ID: Thread ID of topic to pin

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_thread_id" . ,message-thread-id))))
        (let ((result (make-api-call connection "pinForumTopic" params)))
          (if result
              (progn
                (log-message :info "Forum topic ~A pinned" message-thread-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error pinning forum topic: ~A" (princ-to-string e))
      nil)))

(defun unpin-forum-topic (chat-id message-thread-id)
  "Unpin a forum topic.

   CHAT-ID: Target forum chat ID
   MESSAGE-THREAD-ID: Thread ID of topic to unpin

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,chat-id)
                       ("message_thread_id" . ,message-thread-id))))
        (let ((result (make-api-call connection "unpinForumTopic" params)))
          (if result
              (progn
                (log-message :info "Forum topic ~A unpinned" message-thread-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error unpinning forum topic: ~A" (princ-to-string e))
      nil)))

(defun get-forum-topic-icon-stickers ()
  "Get custom emoji stickers available for forum topic icons.

   Returns list of sticker objects that can be used as topic icons."
  (handler-case
      (let ((connection (get-current-connection)))
        (let ((result (make-api-call connection "getForumTopicIconStickers" nil)))
          (if result
              (gethash "stickers" result nil)
              nil)))
    (error (e)
      (log-message :error "Error getting forum topic icon stickers: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Channel Statistics
;;; ======================================================================

(defun get-channel-statistics (channel-id &key start-date end-date granular)
  "Get statistics for a channel.

   CHANNEL-ID: Target channel ID
   START-DATE: Optional period start (Unix time)
   END-DATE: Optional period end (Unix time)
   GRANULAR: Request granular data if T

   Returns channel-statistics object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,channel-id))))
        (when start-date
          (push (cons "start_date" start-date) params))
        (when end-date
          (push (cons "end_date" end-date) params))
        (when granular
          (push (cons "granular" "true") params))

        (let ((result (make-api-call connection "getChatStatistics" params)))
          (if result
              (make-instance 'channel-statistics
                             :channel-id channel-id
                             :period-start (gethash "period_start" result 0)
                             :period-end (gethash "period_end" result 0)
                             :member-count (gethash "member_count" result 0)
                             :view-count (gethash "view_count" result 0)
                             :share-count (gethash "share_count" result 0)
                             :new-members (gethash "new_members" result 0)
                             :left-members (gethash "left_members" result 0)
                             :language-stats (gethash "language_stats" result)
                             :hourly-activity (gethash "hourly_activity" result)
                             :growth-graph (gethash "growth_graph" result))
              nil)))
    (error (e)
      (log-message :error "Error getting channel statistics: ~A" (princ-to-string e))
      nil)))

(defun get-message-statistics (channel-id message-id)
  "Get statistics for a specific message.

   CHANNEL-ID: Target channel ID
   MESSAGE-ID: Target message ID

   Returns message-statistics object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,channel-id)
                       ("message_id" . ,message-id))))
        (let ((result (make-api-call connection "getMessageStatistics" params)))
          (if result
              (make-instance 'message-statistics
                             :message-id message-id
                             :view-count (gethash "view_count" result 0)
                             :forward-count (gethash "forward_count" result 0)
                             :reaction-count (gethash "reaction_count" result 0)
                             :reactions (gethash "reactions" result)
                             :hourly-views (gethash "hourly_views" result))
              nil)))
    (error (e)
      (log-message :error "Error getting message statistics: ~A" (princ-to-string e))
      nil)))

(defun get-reaction-statistics (channel-id message-id)
  "Get reaction statistics for a message.

   CHANNEL-ID: Target channel ID
   MESSAGE-ID: Target message ID

   Returns reaction-statistics object on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,channel-id)
                       ("message_id" . ,message-id))))
        (let ((result (make-api-call connection "getReactionStatistics" params)))
          (if result
              (make-instance 'reaction-statistics
                             :message-id message-id
                             :total-reactions (gethash "total_reactions" result 0)
                             :reaction-breakdown (gethash "reaction_breakdown" result)
                             :recent-reactors (gethash "recent_reactors" result))
              nil)))
    (error (e)
      (log-message :error "Error getting reaction statistics: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Sponsored Messages
;;; ======================================================================

(defun get-sponsored-messages (channel-id)
  "Get sponsored messages for a channel.

   CHANNEL-ID: Target channel ID

   Returns list of sponsored-message objects on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,channel-id))))
        (let ((result (make-api-call connection "getSponsoredMessages" params)))
          (if result
              (loop for msg-data across (gethash "messages" result)
                    collect (make-instance 'sponsored-message
                                           :message-id (gethash "message_id" msg-data 0)
                                           :text (gethash "text" msg-data "")
                                           :link-url (gethash "link_url" msg-data "")
                                           :link-name (gethash "link_name" msg-data "")
                                           :is-promoted (gethash "is_promoted" msg-data)))
              nil)))
    (error (e)
      (log-message :error "Error getting sponsored messages: ~A" (princ-to-string e))
      nil)))

(defun report-sponsored-message (channel-id message-id reason)
  "Report a sponsored message.

   CHANNEL-ID: Target channel ID
   MESSAGE-ID: Message ID to report
   REASON: Report reason string

   Returns T on success, NIL on failure."
  (handler-case
      (let* ((connection (get-current-connection))
             (params `(("chat_id" . ,channel-id)
                       ("message_id" . ,message-id)
                       ("reason" . ,reason))))
        (let ((result (make-api-call connection "reportSponsoredMessage" params)))
          (if result
              (progn
                (log-message :info "Sponsored message ~A reported" message-id)
                t)
              nil)))
    (error (e)
      (log-message :error "Error reporting sponsored message: ~A" (princ-to-string e))
      nil)))

;;; ======================================================================
;;; Global State
;;; ======================================================================

(defvar *forum-topics-cache* (make-hash-table :test 'equal)
  "Cache of forum topics by chat-id")

(defvar *channel-stats-cache* (make-hash-table :test 'equal)
  "Cache of channel statistics by channel-id")

(defvar *sponsored-messages-cache* (make-hash-table :test 'equal)
  "Cache of sponsored messages by channel-id")

(defvar *topic-icon-colors*
  '#(7220692 11381183 11958478 10700816 14491314 12927296 9447312)
  "Default topic icon colors (RGB integers)")
