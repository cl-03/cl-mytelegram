;;; global-search.lisp --- Global search functionality for cl-telegram
;;;
;;; Provides cross-chat message search capabilities:
;;; - Search across all chats
;;; - Filter by sender, date, media type
;;; - Search result highlighting
;;; - Search suggestions
;;;
;;; Version: 0.27.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Search Result Classes
;;; ============================================================================

(defclass search-result ()
  ((message :initarg :message :reader search-message)
   (chat-id :initarg :chat-id :accessor search-chat-id)
   (chat-title :initarg :chat-title :accessor search-chat-title)
   (score :initform 0 :accessor search-score) ; relevance score
   (match-text :initform nil :accessor search-match-text) ; highlighted text
   (match-position :initform nil :accessor search-match-position)))

(defmethod print-object ((result search-result) stream)
  (print-unreadable-object (result stream :type t)
    (format stream "~A in ~A (score: ~D)"
            (search-message result)
            (search-chat-title result)
            (search-score result))))

(defclass search-filters ()
  ((sender-id :initform nil :initarg :sender-id :accessor filter-sender-id)
   (date-from :initform nil :initarg :date-from :accessor filter-date-from)
   (date-to :initform nil :initarg :date-to :accessor filter-date-to)
   (chat-ids :initform nil :initarg :chat-ids :accessor filter-chat-ids)
   (media-type :initform nil :initarg :media-type :accessor filter-media-type)
   (has-media :initform nil :initarg :has-media :accessor filter-has-media)
   (message-type :initform nil :initarg :message-type :accessor filter-message-type))) ; :text, :photo, :video, etc.

(defmethod print-object ((filters search-filters) stream)
  (print-unreadable-object (filters stream :type t)
    (format stream "sender=~A chats=~A media=~A"
            (filter-sender-id filters)
            (filter-chat-ids filters)
            (filter-media-type filters))))

;;; ============================================================================
;;; Search Manager
;;; ============================================================================

(defclass search-manager ()
  ((search-history :initform '() :accessor manager-search-history)
   (recent-queries :initform '() :accessor manager-recent-queries)
   (search-cache :initform (make-hash-table :test 'equal :size 100)
                 :accessor manager-search-cache)
   (cache-ttl :initform 300 :accessor manager-cache-ttl))) ; 5 minutes

(defvar *search-manager* nil
  "Global search manager instance")

(defun make-search-manager ()
  "Create a new search manager instance."
  (make-instance 'search-manager))

(defun init-search-manager ()
  "Initialize search manager subsystem."
  (unless *search-manager*
    (setf *search-manager* (make-search-manager)))
  t)

(defun get-search-manager ()
  "Get the global search manager."
  (unless *search-manager*
    (init-search-manager))
  *search-manager*)

;;; ============================================================================
;;; Core Search Functions
;;; ============================================================================

(defun global-search-messages (query &key
                               (sender-id nil)
                               (date-from nil)
                               (date-to nil)
                               (chat-ids nil)
                               (media-type nil)
                               (has-media nil)
                               (message-type nil)
                               (limit 50)
                               (offset 0)
                               (use-cache t))
  "Search messages across all chats.

   QUERY: Search query string (empty string for media-only search)
   SENDER-ID: Filter by sender user ID
   DATE-FROM: Filter messages from this date (universal-time)
   DATE-TO: Filter messages until this date
   CHAT-IDS: List of chat IDs to search in (NIL for all chats)
   MEDIA-TYPE: Filter by media type (:photo, :video, :document, :audio)
   HAS-MEDIA: If T, only return messages with media
   MESSAGE-TYPE: Filter by message type
   LIMIT: Maximum results to return
   OFFSET: Pagination offset
   USE-CACHE: Whether to use search cache

   Returns:
     (values results total-count error)"
  (let ((manager (get-search-manager)))
    ;; Check cache
    (when use-cache
      (let ((cache-key (format nil "~A:~A:~A:~A" query sender-id chat-ids media-type)))
        (let ((cached (gethash cache-key (manager-search-cache manager))))
          (when cached
            (let ((cached-time (getf cached :time))
                  (cached-results (getf cached :results)))
              (when (< (- (get-universal-time) cached-time) (manager-cache-ttl manager))
                (return-from global-search-messages
                  (values cached-results (length cached-results) nil))))))))

    ;; Build filters
    (let ((filters (make-instance 'search-filters
                                  :sender-id sender-id
                                  :date-from date-from
                                  :date-to date-to
                                  :chat-ids chat-ids
                                  :media-type media-type
                                  :has-media has-media
                                  :message-type message-type)))
      (format t "Searching for '~A' with filters: ~A~%" query filters)

      ;; Get chats to search
      (let ((chats-to-search (if chat-ids
                                 (mapcar (lambda (id) (list :id id)) chat-ids)
                                 (get-chats :limit 100))))
        (when (null chats-to-search)
          (return-from global-search-messages
            (values nil 0 :no-chats "No chats to search in")))

        ;; Search in each chat
        (let ((all-results '())
              (total-count 0))
          (dolist (chat chats-to-search)
            (let ((chat-id (getf chat :id))
                  (chat-title (getf chat :title (format nil "Chat ~A" chat-id))))
              (handler-case
                  (progn
                    ;; Search in chat
                    (multiple-value-bind (messages count)
                        (search-in-chat chat-id query
                                        :sender-id sender-id
                                        :date-from date-from
                                        :date-to date-to
                                        :media-type media-type
                                        :has-media has-media
                                        :limit limit)
                      (when (and messages (> (length messages) 0))
                        ;; Create search results
                        (dolist (msg messages)
                          (let* ((text (getf msg :text ""))
                                 (match-pos (when (> (length query) 0)
                                              (search query text :test #'char-equal)))
                                 (result (make-instance 'search-result
                                                      :message msg
                                                      :chat-id chat-id
                                                      :chat-title chat-title
                                                      :score (calculate-relevance-score query text match-pos)
                                                      :match-text text
                                                      :match-position match-pos)))
                            (push result all-results)))
                        (incf total-count count)))
                    (sleep 0.05)) ; Rate limiting
                (error (e)
                  (format t "Error searching chat ~A: ~A~%" chat-title e))))))

          ;; Sort by relevance score
          (setf all-results (sort all-results #'> :key #'search-score))

          ;; Apply pagination
          (let ((paginated-results (subseq all-results offset (min (+ offset limit) (length all-results)))))
            ;; Cache results
            (when use-cache
              (let ((cache-key (format nil "~A:~A:~A:~A" query sender-id chat-ids media-type)))
                (setf (gethash cache-key (manager-search-cache manager))
                      (list :time (get-universal-time)
                            :results paginated-results))))

            ;; Add to search history
            (push (list :query query
                        :time (get-universal-time)
                        :result-count (length paginated-results))
                  (manager-search-history manager))
            (when (> (length (manager-search-history manager)) 50)
              (setf (manager-search-history manager)
                    (subseq (manager-search-history manager) 0 50)))

            (format t "Found ~D results~%" (length paginated-results))
            (values paginated-results total-count nil)))))

(defun search-in-chat (chat-id query &key
                       (sender-id nil)
                       (date-from nil)
                       (date-to nil)
                       (media-type nil)
                       (has-media nil)
                       (limit 50))
  "Search within a specific chat.

   CHAT-ID: The chat to search in
   QUERY: Search query string
   SENDER-ID: Filter by sender
   DATE-FROM: Filter by date from
   DATE-TO: Filter by date to
   MEDIA-TYPE: Filter by media type
   HAS-MEDIA: Only messages with media
   LIMIT: Maximum results

   Returns:
     (values results count)"
  (let ((messages '())
        (count 0))
    ;; Get message history
    (let ((offset 0)
          (more t))
      (loop while (and more (< count limit)) do
        (multiple-value-bind (batch has-more)
            (get-message-history chat-id :limit 100 :offset offset)
          (if (null batch)
              (setf more nil)
              (progn
                ;; Filter messages
                (dolist (msg batch)
                  (when (and
                         ;; Text match
                         (or (= (length query) 0)
                             (search query (getf msg :text "") :test #'char-equal))
                         ;; Sender filter
                         (or (null sender-id)
                             (eql (getf msg :from-id) sender-id))
                         ;; Date filters
                         (or (null date-from)
                             (>= (getf msg :date) date-from))
                         (or (null date-to)
                             (<= (getf msg :date) date-to))
                         ;; Media filters
                         (or (null has-media)
                             (getf msg :media))
                         (or (null media-type)
                             (eq (getf (getf msg :media) :type) media-type)))
                    (push msg messages)
                    (incf count)
                    (when (>= count limit)
                      (return))))
                (setf offset (+ offset 100))
                (setf more has-more))))))

    (setf messages (nreverse messages))
    (values messages count)))

;;; ============================================================================
;;; Relevance Scoring
;;; ============================================================================

(defun (private) calculate-relevance-score (query text match-position)
  "Calculate relevance score for search result.

   QUERY: Search query
   TEXT: Message text
   MATCH-POSITION: Position of match in text

   Returns:
     Relevance score (higher is better)"
  (declare (ignorable query text match-position))
  (let ((score 100))
    ;; Exact match bonus
    (when (search query text :test #'string-equal)
      (incf score 50))

    ;; Position bonus (earlier is better)
    (when match-position
      (decf score (/ match-position 10)))

    ;; Length bonus (shorter messages with match are more relevant)
    (when (> (length text) 0)
      (let ((ratio (/ (length query) (length text))))
        (when (> ratio 0.5)
          (incf score 20))))

    ;; Case-sensitive match bonus
    (when (search query text)
      (incf score 10))

    (max 0 score)))

;;; ============================================================================
;;; Search Suggestions
;;; ============================================================================

(defun get-search-suggestions (query &key (limit 5))
  "Get search suggestions based on query.

   QUERY: Partial search query
   LIMIT: Maximum suggestions to return

   Returns:
     List of suggestion strings"
  (let ((manager (get-search-manager))
        (suggestions '()))
    ;; Get recent queries as suggestions
    (dolist (recent (manager-recent-queries manager))
      (let ((recent-query (getf recent :query)))
        (when (and (> (length recent-query) 0)
                   (search query recent-query :test #'char-equal)
                   (not (member recent-query suggestions :test #'string=)))
          (push recent-query suggestions))
        (when (>= (length suggestions) limit)
          (return))))

    ;; If not enough suggestions, search chat titles
    (when (< (length suggestions) limit)
      (let ((chats (get-chats :limit 100)))
        (dolist (chat chats)
          (let ((title (getf chat :title)))
            (when (and title
                       (search query title :test #'char-equal)
                       (not (member title suggestions :test #'string=)))
              (push title suggestions))))))

    ;; Add to recent queries
    (when (> (length query) 0)
      (push (list :query query :time (get-universal-time))
            (manager-recent-queries manager))
      (when (> (length (manager-recent-queries manager)) 20)
        (setf (manager-recent-queries manager)
              (subseq (manager-recent-queries manager) 0 20))))

    (nreverse (subseq suggestions 0 (min limit (length suggestions))))))

;;; ============================================================================
;;; Highlight and Formatting
;;; ============================================================================

(defun highlight-search-result (text query &key (max-length 200))
  "Highlight search query in text.

   TEXT: Original text
   QUERY: Search query to highlight
   MAX-LENGTH: Maximum length of returned text

   Returns:
     Highlighted text snippet"
  (when (null text)
    (return-from highlight-search-result ""))

  (let ((pos (search query text :test #'char-equal)))
    (if (null pos)
        ;; No match, return truncated text
        (if (> (length text) max-length)
            (format nil "...~A..." (subseq text 0 max-length))
            text)
        ;; Found match, return context around match
        (let* ((start (max 0 (- pos 50)))
               (end (min (length text) (+ pos (length query) 50)))
               (snippet (subseq text start end)))
          (format nil "~A~A~A"
                  (if (> start 0) "..." "")
                  snippet
                  (if (< end (length text)) "..." "")))))))

(defun format-search-results (results &key (format :text))
  "Format search results for display.

   RESULTS: List of search-result objects
   FORMAT: Output format (:text, :html, :json)

   Returns:
     Formatted results"
  (case format
    (:text
     (with-output-to-string (s)
       (format s "Search Results (~D results)~%" (length results))
       (format s "~A~%" (make-string 50 :initial-element #\-))
       (dolist (result results)
         (format s "[~A]~%" (search-chat-title result))
         (format s "  ~A~%" (search-match-text result))
         (format s "  Score: ~D~%" (search-score result))
         (format s "~%"))))
    (:html
     (with-output-to-string (s)
       (format s "<div class=\"search-results\">~%")
       (dolist (result results)
         (format s "  <div class=\"search-result\">~%")
         (format s "    <div class=\"chat-title\">~A</div>~%" (search-chat-title result))
         (format s "    <div class=\"match-text\">~A</div>~%" (search-match-text result))
         (format s "  </div>~%")
         (format s "~%")))
       (format s "</div>~%")))
    (:json
     (jonathan:to-json
      (mapcar (lambda (result)
                (list :chat-id (search-chat-id result)
                      :chat-title (search-chat-title result)
                      :text (search-match-text result)
                      :score (search-score result)
                      :match-position (search-match-position result)))
              results)
      :pretty t))
    (otherwise
     (error "Unknown format: ~A" format)))

;;; ============================================================================
;;; Advanced Search Features
;;; ============================================================================

(defun search-messages-by-sender (sender-id &key (chat-ids nil) (limit 50))
  "Search all messages from a specific sender.

   SENDER-ID: User ID of sender
   CHAT-IDS: Optional list of chat IDs to search
   LIMIT: Maximum results

   Returns:
     (values results count)"
  (global-search-messages ""
                          :sender-id sender-id
                          :chat-ids chat-ids
                          :limit limit))

(defun search-messages-by-date-range (date-from date-to &key (chat-ids nil) (limit 50))
  "Search messages within a date range.

   DATE-FROM: Start date (universal-time)
   DATE-TO: End date (universal-time)
   CHAT-IDS: Optional list of chat IDs
   LIMIT: Maximum results

   Returns:
     (values results count)"
  (global-search-messages ""
                          :date-from date-from
                          :date-to date-to
                          :chat-ids chat-ids
                          :limit limit))

(defun search-messages-by-media-type (media-type &key (chat-ids nil) (limit 50))
  "Search messages containing specific media type.

   MEDIA-TYPE: Media type (:photo, :video, :document, :audio)
   CHAT-IDS: Optional list of chat IDs
   LIMIT: Maximum results

   Returns:
     (values results count)"
  (global-search-messages ""
                          :media-type media-type
                          :chat-ids chat-ids
                          :has-media t
                          :limit limit))

;;; ============================================================================
;;; Cache Management
;;; ============================================================================

(defun clear-search-cache ()
  "Clear all search cache.

   Returns:
     T on success"
  (let ((manager (get-search-manager)))
    (clrhash (manager-search-cache manager))
    (format t "Cleared search cache~%")
    t))

(defun get-search-cache-stats ()
  "Get search cache statistics.

   Returns:
     Plist with cache stats"
  (let ((manager (get-search-manager)))
    (list :cache-size (hash-table-count (manager-search-cache manager))
          :cache-ttl (manager-cache-ttl manager)
          :search-history-length (length (manager-search-history manager))
          :recent-queries-length (length (manager-recent-queries manager)))))

(defun set-search-cache-ttl (seconds)
  "Set search cache TTL.

   SECONDS: Cache TTL in seconds

   Returns:
     T on success"
  (let ((manager (get-search-manager)))
    (setf (manager-cache-ttl manager) seconds)
    (format t "Set search cache TTL to ~D seconds~%" seconds)
    t))

;;; ============================================================================
;;; Search History
;;; ============================================================================

(defun get-search-history (&key (limit 10))
  "Get recent search history.

   LIMIT: Maximum history items to return

   Returns:
     List of search history entries"
  (let ((manager (get-search-manager)))
    (subseq (manager-search-history manager) 0 (min limit (length (manager-search-history manager))))))

(defun clear-search-history ()
  "Clear search history.

   Returns:
     T on success"
  (let ((manager (get-search-manager)))
    (setf (manager-search-history manager) '())
    (format t "Cleared search history~%")
    t))

;;; ============================================================================
;;; Utility Functions
;;; ============================================================================

(defun search-contains-url-p (text)
  "Check if text contains URL.

   TEXT: Text to check

   Returns:
     T if URL found"
  (when text
    (cl-ppcre:scan "https?://[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=%]+" text)))

(defun search-contains-mention-p (text)
  "Check if text contains mention.

   TEXT: Text to check

   Returns:
     T if mention found"
  (when text
    (cl-ppcre:scan "@[\\w_]+" text)))

(defun search-contains-hashtag-p (text)
  "Check if text contains hashtag.

   TEXT: Text to check

   Returns:
     T if hashtag found"
  (when text
    (cl-ppcre:scan "#[\\w_]+" text)))

(defun extract-urls-from-text (text)
  "Extract URLs from text.

   TEXT: Text to extract from

   Returns:
     List of URLs"
  (when text
    (cl-ppcre:all-matches-as-strings "https?://[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=%]+" text)))

(defun extract-mentions-from-text (text)
  "Extract mentions from text.

   TEXT: Text to extract from

   Returns:
     List of mentions"
  (when text
    (cl-ppcre:all-matches-as-strings "@[\\w_]+" text)))

(defun extract-hashtags-from-text (text)
  "Extract hashtags from text.

   TEXT: Text to extract from

   Returns:
     List of hashtags"
  (when text
    (cl-ppcre:all-matches-as-strings "#[\\w_]+" text)))
