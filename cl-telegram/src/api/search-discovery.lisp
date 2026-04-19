;;; search-discovery.lisp --- Search and Discovery features
;;;
;;; Provides comprehensive search functionality:
;;; - Chat search (public, private, recently found)
;;; - Message search with filters
;;; - Member search in chats
;;; - Search filters (19 types)

(in-package #:cl-telegram/api)

;;; ### Search Filters

(defstruct search-filter
  "Search filter for message filtering"
  (type :empty :type keyword)
  (params nil :type list))

(defun make-search-filter (type &rest params)
  "Create a search filter.

   Args:
     type: Filter type keyword
     params: Optional filter parameters

   Filter types:
     :empty - No filtering
     :photo - Photos only
     :video - Videos only
     :audio - Audio files only
     :document - Documents only
     :animation - Animations/GIFs only
     :voice-note - Voice messages only
     :video-note - Video notes only
     :photo-and-video - Photos and videos
     :url - Messages with links
     :poll - Polls only
     :mention - Messages mentioning you
     :unread-mention - Unread mentions
     :unread-reaction - Unread reactions
     :unread-poll-vote - Unread poll votes
     :chat-photo - Chat photo changes
     :pinned - Pinned messages
     :failed-to-send - Failed to send messages

   Returns:
     Search filter structure"
  (make-search-filter :type type :params params))

(defun filter-to-tl-object (filter)
  "Convert search filter to TL object.

   Args:
     filter: Search filter structure

   Returns:
     TL object for API request"
  (let ((type (search-filter-type filter)))
    (case type
      (:empty (make-tl-object 'searchMessagesFilterEmpty))
      (:photo (make-tl-object 'searchMessagesFilterPhoto))
      (:video (make-tl-object 'searchMessagesFilterVideo))
      (:audio (make-tl-object 'searchMessagesFilterAudio))
      (:document (make-tl-object 'searchMessagesFilterDocument))
      (:animation (make-tl-object 'searchMessagesFilterAnimation))
      (:voice-note (make-tl-object 'searchMessagesFilterVoiceNote))
      (:video-note (make-tl-object 'searchMessagesFilterVideoNote))
      (:photo-and-video (make-tl-object 'searchMessagesFilterPhotoAndVideo))
      (:url (make-tl-object 'searchMessagesFilterUrl))
      (:poll (make-tl-object 'searchMessagesFilterPoll))
      (:mention (make-tl-object 'searchMessagesFilterMention))
      (:unread-mention (make-tl-object 'searchMessagesFilterUnreadMention))
      (:unread-reaction (make-tl-object 'searchMessagesFilterUnreadReaction))
      (:unread-poll-vote (make-tl-object 'searchMessagesFilterUnreadPollVote))
      (:chat-photo (make-tl-object 'searchMessagesFilterChatPhoto))
      (:pinned (make-tl-object 'searchMessagesFilterPinned))
      (:failed-to-send (make-tl-object 'searchMessagesFilterFailedToSend))
      (otherwise (make-tl-object 'searchMessagesFilterEmpty)))))

;;; ### Chat Search

(defun search-public-chats (query &key limit)
  "Search public chats by username.

   Args:
     query: Username or search query string
     limit: Maximum number of results (1-100, default 100)

   Returns:
     (values chats error)
     - chats: List of chat objects
     - error: Error message or NIL

   Example:
     (search-public-chats \"telegram\" :limit 10)"
  (unless (authorized-p)
    (return-from search-public-chats
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))
  (setf query (or query ""))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-public-chats
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.searchPublicChat
                    :username query)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (or (eq (getf result :@type) :chat)
                  (eq (getf result :@type) :chatAlreadyJoined))
              (values (list (getf result :chat)) nil)
              (values nil nil)))
        (:timeout ()
          (values nil :timeout "Search timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun search-public-chats-multi (query &key limit)
  "Search multiple public chats.

   Args:
     query: Search query string
     limit: Maximum number of results (1-100)

   Returns:
     (values chats error)"
  (unless (authorized-p)
    (return-from search-public-chats-multi
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-public-chats-multi
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.searchPublicChats
                    :query query
                    :limit limit
                    :offset-id 0)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chats)
              (values (getf result :list) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Search timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun search-chats (query &key limit)
  "Search chats locally.

   Args:
     query: Search query string
     limit: Maximum number of results (1-100)

   Returns:
     (values chats error)

   Searches in locally cached chats."
  (unless (authorized-p)
    (return-from search-chats
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))
  (setf query (or query ""))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-chats
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.searchChats
                    :query query
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chats)
              (values (getf result :list) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Search timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun search-chats-on-server (query &key limit offset)
  "Search chats on server.

   Args:
     query: Search query string
     limit: Maximum number of results (1-100)
     offset: Offset for pagination

   Returns:
     (values chats error)

   Searches across all accessible chats on the server."
  (unless (authorized-p)
    (return-from search-chats-on-server
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))
  (setf offset (max (or offset 0) 0))
  (setf query (or query ""))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-chats-on-server
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.searchChatsOnServer
                    :query query
                    :limit limit
                    :offset-id offset)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chats)
              (values (getf result :list) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Search timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

(defun search-recently-found-chats (query &key limit)
  "Search recently found chats.

   Args:
     query: Search query string
     limit: Maximum number of results (1-100)

   Returns:
     (values chats error)"
  (unless (authorized-p)
    (return-from search-recently-found-chats
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))
  (setf query (or query ""))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-recently-found-chats
        (values nil :no-connection "No active connection")))

    (let ((request (make-tl-object
                    'messages.searchRecentlyFoundChats
                    :query query
                    :limit limit)))
      (rpc-handler-case (rpc-call connection request :timeout 10000)
        (:ok (result)
          (if (eq (getf result :@type) :chats)
              (values (getf result :list) nil)
              (values nil :unexpected-response result)))
        (:timeout ()
          (values nil :timeout "Search timeout"))
        (:error (err)
          (values nil :rpc-error err))))))

;;; ### Message Search

(defun search-messages (query &key chat-list filter offset limit
                             chat-type-filter min-date max-date)
  "Search messages globally.

   Args:
     query: Search query string
     chat-list: Chat list to search in (:main :archive)
     filter: Search filter (keyword or search-filter struct)
     offset: Offset for pagination
     limit: Maximum number of results (1-100)
     chat-type-filter: Filter by chat type (:private :group :channel)
     min-date: Minimum message date (Unix timestamp)
     max-date: Maximum message date (Unix timestamp)

   Returns:
     (values found-messages total-count error)

   Example:
     (search-messages \"hello\" :filter :photo :limit 20)
     (search-messages \"\" :filter :url :chat-type-filter :channel)"
  (unless (authorized-p)
    (return-from search-messages
      (values nil nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))
  (setf query (or query ""))
  (setf offset (or offset ""))
  (setf min-date (or min-date 0))
  (setf max-date (or max-date (get-universal-time)))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-messages
        (values nil nil :no-connection "No active connection")))

    ;; Convert filter keyword to struct if needed
    (let ((filter-obj (if (typep filter 'search-filter)
                          filter
                          (make-search-filter (or filter :empty)))))
      (let ((request (make-tl-object
                      'messages.searchMessages
                      :peer nil  ; Global search
                      :query query
                      :filter (filter-to-tl-object filter-obj)
                      :min-date min-date
                      :max-date max-date
                      :offset offset
                      :limit limit)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:ok (result)
            (if (eq (getf result :@type) :messages)
                (values (getf result :messages)
                        (getf result :count)
                        nil)
                (values nil nil :unexpected-response result)))
          (:timeout ()
            (values nil nil :timeout "Search timeout"))
          (:error (err)
            (values nil nil :rpc-error err)))))))

(defun search-chat-messages (chat-id query &key topic-id sender-id
                                          from-message-id offset limit filter)
  "Search messages within a specific chat.

   Args:
     chat-id: Chat ID to search in
     query: Search query string
     topic-id: Optional topic ID (for forum chats)
     sender-id: Optional sender ID to filter by
     from-message-id: Start search from this message
     offset: Offset for pagination
     limit: Maximum number of results (1-100)
     filter: Search filter type

   Returns:
     (values found-messages total-count error)

   Example:
     (search-chat-messages 123456 \"hello\" :filter :photo :limit 50)"
  (unless (authorized-p)
    (return-from search-chat-messages
      (values nil nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))
  (setf query (or query ""))
  (setf offset (or offset 0))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-chat-messages
        (values nil nil :no-connection "No active connection")))

    (let ((filter-obj (if (typep filter 'search-filter)
                          filter
                          (make-search-filter (or filter :empty)))))
      (let ((request (make-tl-object
                      'messages.searchChatMessages
                      :chat-id chat-id
                      :topic-id (or topic-id 0)
                      :sender-id (or sender-id 0)
                      :query query
                      :from-message-id (or from-message-id 0)
                      :filter (filter-to-tl-object filter-obj)
                      :offset offset
                      :limit limit)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:ok (result)
            (if (eq (getf result :@type) :foundChatMessages)
                (values (getf result :messages)
                        (getf result :count)
                        nil)
                (values nil nil :unexpected-response result)))
          (:timeout ()
            (values nil nil :timeout "Search timeout"))
          (:error (err)
            (values nil nil :rpc-error err)))))))

(defun search-secret-messages (chat-id query &key offset limit filter)
  "Search messages in secret chats.

   Args:
     chat-id: Secret chat ID
     query: Search query string
     offset: Offset for pagination
     limit: Maximum number of results (1-100)
     filter: Search filter

   Returns:
     (values found-messages error)

   Note: Search is performed locally on encrypted messages
   after decryption."
  (let ((chat (get-secret-chat chat-id)))
    (unless chat
      (return-from search-secret-messages
        (values nil :not-found "Secret chat not found"))))

  ;; Secret chat search is local-only
  ;; Would decrypt and search locally stored messages
  (let ((messages (search-local-secret-messages chat-id query filter limit offset)))
    (values messages nil)))

(defun search-local-secret-messages (chat-id query filter limit offset)
  "Search local secret chat messages.

   Args:
     chat-id: Secret chat ID
     query: Search query
     filter: Filter type
     limit: Max results
     offset: Offset

   Returns:
     List of matching messages"
  (declare (ignore chat-id query filter limit offset))
  ;; Placeholder - would search local encrypted message store
  nil)

;;; ### Member Search

(defun search-chat-members (chat-id query &key filter limit)
  "Search members in a chat.

   Args:
     chat-id: Chat ID
     query: Search query (name/username)
     filter: Member filter type
            (:all :administrators :restricted :banned :can-mention)
     limit: Maximum number of results (1-100)

   Returns:
     (values members error)

   Example:
     (search-chat-members 123456 \"john\" :filter :administrators :limit 10)"
  (unless (authorized-p)
    (return-from search-chat-members
      (values nil :not-authorized "User not authenticated")))

  (setf limit (min (max (or limit 100) 1) 100))
  (setf query (or query ""))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from search-chat-members
        (values nil :no-connection "No active connection")))

    ;; Convert filter to TL object
    (let ((member-filter (case filter
                           (:administrators
                            (make-tl-object 'channelParticipantsAdmins))
                           (:restricted
                            (make-tl-object 'channelParticipantsKicked
                                            :query query))
                           (:banned
                            (make-tl-object 'channelParticipantsBanned
                                            :query query))
                           (:can-mention
                            (make-tl-object 'channelParticipantsMentions
                                            :query query))
                           (otherwise
                            (make-tl-object 'channelParticipantsSearch
                                            :query query)))))
      (let ((request (make-tl-object
                      'channels.getParticipants
                      :channel (make-tl-object 'inputChannel
                                               :channel-id chat-id
                                               :access-hash 0)
                      :filter member-filter
                      :offset 0
                      :limit limit)))
        (rpc-handler-case (rpc-call connection request :timeout 10000)
          (:ok (result)
            (if (eq (getf result :@type) :channelParticipants)
                (values (getf result :participants) nil)
                (values nil :unexpected-response result)))
          (:timeout ()
            (values nil :timeout "Search timeout"))
          (:error (err)
            (values nil :rpc-error err)))))))

;;; ### Search Helpers

(defun get-search-query-suggestions (query &key limit)
  "Get search query suggestions.

   Args:
     query: Current query string
     limit: Maximum suggestions (1-20)

   Returns:
     List of suggested queries"
  (setf limit (min (max (or limit 10) 1) 20))
  (setf query (or query ""))

  ;; Generate suggestions based on search history and trending
  ;; This is a placeholder for more sophisticated suggestion logic
  (let ((suggestions nil))
    ;; Add query variations
    (when (> (length query) 2)
      (push query suggestions))
    ;; Add common completions
    suggestions))

(defun clear-search-history ()
  "Clear local search history.

   Returns:
     T on success"
  ;; Clear search cache
  (clrhash *search-cache*)
  t)

(defun get-search-history (&key limit)
  "Get recent search history.

   Args:
     limit: Maximum entries (1-50)

   Returns:
     List of recent searches"
  (setf limit (min (max (or limit 20) 1) 50))
  ;; Return recent searches from history
  (declare (ignore limit))
  nil)

;;; ### Search Cache

(defvar *search-cache* (make-hash-table :test 'equal)
  "Cache for search results")

(defun cache-search-result (key result &key ttl)
  "Cache search result.

   Args:
     key: Cache key
     result: Search result to cache
     ttl: Time to live in seconds"
  (setf (gethash key *search-cache*)
        (list :result result
              :expires (+ (get-universal-time) (or ttl 300)))))

(defun get-cached-search (key)
  "Get cached search result.

   Args:
     key: Cache key

   Returns:
     Cached result or NIL"
  (let ((entry (gethash key *search-cache*)))
    (when entry
      (if (> (getf entry :expires) (get-universal-time))
          (getf entry :result)
          ;; Expired - remove
          (remhash key *search-cache*)))))

;;; ### Global Search

(defun global-search (query &key types limit)
  "Perform global search across all content types.

   Args:
     query: Search query
     types: Types to search (:chats :messages :users :bots)
     limit: Maximum results per type

   Returns:
     plist with results by type

   Example:
     (global-search \"telegram\" :types '(:chats :users) :limit 10)"
  (setf types (or types '(:chats :messages :users)))
  (setf limit (or limit 20))

  (let ((results nil))
    ;; Search each type
    (when (member :chats types)
      (multiple-value-bind (chats error)
          (search-chats query :limit limit)
        (setf (getf results :chats) (unless error chats))))
    (when (member :users types)
      (multiple-value-bind (users error)
          (search-users query :limit limit)
        (setf (getf results :users) (unless error users))))
    (when (member :messages types)
      (multiple-value-bind (messages count error)
          (search-messages query :limit limit)
        (declare (ignore count))
        (setf (getf results :messages) (unless error messages))))
    results))
