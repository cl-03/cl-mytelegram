;;; utilities.lisp --- Utility functions and helpers
;;; Part of v0.22.0 - Notification System, Contacts, and Utilities

(in-package #:cl-telegram/api)

;;; ======================================================================
;;; Message Formatting Utilities
;;; ======================================================================

(defun format-message-text (text &key bold italic underline strikethrough
                                 code pre language link url mention)
  "Format message text with Markdown or HTML entities.
   TEXT: Base text to format
   BOLD: Wrap in bold if T
   ITALIC: Wrap in italic if T
   UNDERLINE: Wrap in underline if T
   STRIKETHROUGH: Wrap in strikethrough if T
   CODE: Wrap as inline code if T
   PRE: Wrap as preformatted block if T
   LANGUAGE: Programming language for pre blocks
   LINK: URL for hyperlink (requires URL)
   URL: URL for link or link text
   MENTION: User ID for mention (requires URL as mention text)
   Returns formatted text string."
  (let ((result text))
    ;; Apply formatting
    (when bold
      (setq result (format nil "**~A**" result)))
    (when italic
      (setq result (format nil "_~A_" result)))
    (when underline
      (setq result (format nil "__~A__" result)))
    (when strikethrough
      (setq result (format nil "~~~A~~" result)))
    (when code
      (setq result (format nil "`~A`" result)))
    (when pre
      (if language
          (setq result (format nil "```~A~%~A```" language result))
          (setq result (format nil "```~%~A```" result))))
    ;; Links and mentions
    (when link
      (setq result (format nil "[~A](~A)" (or url result) link)))
    (when mention
      (setq result (format nil "[~A](tg://user?id=~A)" (or url result) mention)))
    result))

(defun parse-message-entities (text entities)
  "Parse message entities and return formatted text.
   TEXT: Original message text
   ENTITIES: List of entity plists from Telegram API
   Returns formatted text string."
  (let ((result text)
        (sorted-entities (sort (copy-list entities) #'> :key #'cdr)))
    ;; Sort by offset descending to apply from end to start
    (dolist (entity sorted-entities)
      (let* ((offset (car entity))
             (length (cdr entity))
             (type (getf (cdr entity) :type))
             (substring (subseq result offset (+ offset length))))
        (cond
          ((eq type :bold)
           (setf result (concatenate 'string
                                     (subseq result 0 offset)
                                     (format nil "**~A**" substring)
                                     (subseq result (+ offset length)))))
          ((eq type :italic)
           (setf result (concatenate 'string
                                     (subseq result 0 offset)
                                     (format nil "_~A_" substring)
                                     (subseq result (+ offset length)))))
          ((eq type :code)
           (setf result (concatenate 'string
                                     (subseq result 0 offset)
                                     (format nil "`~A`" substring)
                                     (subseq result (+ offset length)))))
          ((eq type :pre)
           (setf result (concatenate 'string
                                     (subseq result 0 offset)
                                     (format nil "```~A```" substring)
                                     (subseq result (+ offset length))))))))
    result))

(defun strip-markdown (text)
  "Strip Markdown formatting from text.
   TEXT: Text with Markdown formatting
   Returns plain text string."
  (let ((result text))
    ;; Remove bold
    (setq result (cl-ppcre:regex-replace-all "\\*\\*(.+?)\\*\\*" result "\\1"))
    ;; Remove italic
    (setq result (cl-ppcre:regex-replace-all "_(.+?)_" result "\\1"))
    ;; Remove underline
    (setq result (cl-ppcre:regex-replace-all "__(.+?)__" result "\\1"))
    ;; Remove strikethrough
    (setq result (cl-ppcre:regex-replace-all "~~(.+?)~~" result "\\1"))
    ;; Remove code
    (setq result (cl-ppcre:regex-replace-all "`(.+?)`" result "\\1"))
    ;; Remove pre blocks
    (setq result (cl-ppcre:regex-replace-all "```[\\s\\S]*?```" result ""))
    ;; Remove links
    (setq result (cl-ppcre:regex-replace-all "\\[(.+?)\\]\\(.+?\\)" result "\\1"))
    result))

(defun truncate-text (text max-length &key suffix)
  "Truncate text to maximum length.
   TEXT: Text to truncate
   MAX-LENGTH: Maximum character count
   SUFFIX: Suffix to add if truncated (default: \"...\")
   Returns truncated text string."
  (let ((suffix (or suffix "...")))
    (if (<= (length text) max-length)
        text
        (concatenate 'string
                     (subseq text 0 (- max-length (length suffix)))
                     suffix))))

(defun escape-markdown (text)
  "Escape special Markdown characters in text.
   TEXT: Text to escape
   Returns escaped text string."
  (let ((chars '("*" "_" "[" "]" "(" ")" "~" "`" ">" "#" "+" "-" "=" "|" "{" "}" "." "!")))
    (let ((result text))
      (dolist (char chars result)
        (setq result (cl-ppcre:regex-replace-all
                      (format nil "\\~A" char) result
                      (format nil "\\\\$A" char)))))))

;;; ======================================================================
;;; Date/Time Helpers
;;; ======================================================================

(defun format-relative-time (timestamp)
  "Format a timestamp as relative time string.
   TIMESTAMP: Unix timestamp
   Returns relative time string (e.g., \"5 minutes ago\")."
  (let* ((now (get-universal-time))
         (diff (- now timestamp))
         (minutes (/ diff 60))
         (hours (/ diff 3600))
         (days (/ diff 86400)))
    (cond
      ((< diff 60) "just now")
      ((< minutes 2) "1 minute ago")
      ((< minutes 60) (format nil "~A minutes ago" (floor minutes)))
      ((< hours 2) "1 hour ago")
      ((< hours 24) (format nil "~A hours ago" (floor hours)))
      ((< days 2) "yesterday")
      ((< days 7) (format nil "~A days ago" (floor days)))
      ((< days 30) (format nil "~A weeks ago" (floor (/ days 7))))
      ((< days 365) (format nil "~A months ago" (floor (/ days 30))))
      (t (format nil "~A years ago" (floor (/ days 365)))))))

(defun format-datetime (timestamp &key format timezone)
  "Format a timestamp with custom format.
   TIMESTAMP: Unix timestamp
   FORMAT: Format string (default: ISO 8601)
   TIMEZONE: Timezone offset in hours
   Returns formatted datetime string."
  (let* ((decoded (decode-universal-time timestamp (or timezone 0)))
         (year (nth 5 decoded))
         (month (nth 4 decoded))
         (day (nth 3 decoded))
         (hour (nth 2 decoded))
         (minute (nth 1 decoded))
         (second (nth 0 decoded)))
    (case format
      (:iso-8601
       (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0D"
               year month day hour minute second))
      (:date
       (format nil "~4,'0D-~2,'0D-~2,'0D" year month day))
      (:time
       (format nil "~2,'0D:~2,'0D:~2,'0D" hour minute second))
      (:human
       (format nil "~A ~A, ~A at ~A:~2,'0D"
               (aref #("Jan" "Feb" "Mar" "Apr" "May" "Jun"
                       "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
                     (1- month))
               day year hour minute))
      (otherwise
       (format nil "~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D"
               year month day hour minute)))))

(defun parse-datetime (string)
  "Parse a datetime string to universal time.
   STRING: Datetime string (ISO 8601 format)
   Returns universal time or NIL on parse error."
  (handler-case
      (let* ((parts (cl-ppcre:split-string "[T :\\-]" string))
             (year (parse-integer (car parts)))
             (month (parse-integer (cadr parts)))
             (day (parse-integer (caddr parts)))
             (hour (parse-integer (or (fourth parts) "0")))
             (minute (parse-integer (or (fifth parts) "0")))
             (second (parse-integer (or (sixth parts) "0"))))
        (encode-universal-time second minute hour day month year 0))
    (error () nil)))

(defun time-to-minutes (hours minutes)
  "Convert time to minutes since midnight.
   HOURS: Hour (0-23)
   MINUTES: Minutes (0-59)
   Returns minutes since midnight (0-1439)."
  (+ (* hours 60) minutes))

(defun minutes-to-time (minutes)
  "Convert minutes since midnight to hours and minutes.
   MINUTES: Minutes since midnight (0-1439)
   Returns (hours minutes) list."
  (list (floor (/ minutes 60)) (mod minutes 60)))

;;; ======================================================================
;;; Chat/User Mention Helpers
;;; ======================================================================

(defun make-mention (user-id &key text)
  "Create a Telegram mention link for a user.
   USER-ID: Telegram user ID
   TEXT: Optional display text (default: user's first name)
   Returns mention markup string."
  (let ((display-text (or text (let ((user (get-user user-id)))
                                 (when user
                                   (format nil "~A ~A"
                                           (gethash "first_name" user "")
                                           (gethash "last_name" user "")))))))
    (format nil "[~A](tg://user?id=~A)" (or display-text "User") user-id)))

(defun parse-mention (text)
  "Parse a mention link and extract user ID.
   TEXT: Text containing mention link
   Returns user ID or NIL if no mention found."
  (let ((match (cl-ppcre:scan-to-strings "tg://user\\?id=(\\d+)" text)))
    (when match
      (parse-integer (aref match 0)))))

(defun extract-mentions (text)
  "Extract all mention links from text.
   TEXT: Text to search
   Returns list of user IDs."
  (let ((matches (cl-ppcre:all-matches-as-strings "tg://user\\?id=(\\d+)" text)))
    (mapcar #'parse-integer matches)))

(defun make-chat-link (chat-id)
  "Create a deep link to a chat.
   CHAT-ID: Telegram chat ID
   Returns deep link URL string."
  (format nil "https://t.me/c/~A/~A"
          (abs chat-id)
          chat-id))

(defun parse-chat-link (url)
  "Parse a Telegram chat link and extract chat ID.
   URL: Telegram chat URL
   Returns chat ID or NIL on parse error."
  (handler-case
      (cond
        ((cl-ppcre:scan "^https?://t\\.me/([^/]+)" url)
         (let ((match (cl-ppcre:scan-to-strings "^https?://t\\.me/([^/]+)" url)))
           (when match
             (let ((username (aref match 0)))
               ;; For username links, we can't get the numeric ID directly
               (list :username username)))))
        ((cl-ppcre:scan "^https?://t\\.me/c/(\\d+)" url)
         (let ((match (cl-ppcre:scan-to-strings "^https?://t\\.me/c/(\\d+)" url)))
           (when match
             (parse-integer (aref match 0)))))
        (t nil))
    (error () nil)))

;;; ======================================================================
;;; Rate Limiting Helpers
;;; ======================================================================

(defclass rate-limiter ()
  ((requests :initarg :requests :accessor rate-limiter-requests
             :initform nil :documentation "List of request timestamps")
   (max-requests :initarg :max-requests :accessor rate-limiter-max-requests
                 :initform 30 :documentation "Maximum requests per window")
   (window-seconds :initarg :window-seconds :accessor rate-limiter-window-seconds
                   :initform 1 :documentation "Time window in seconds")))

(defun make-rate-limiter (&key max-requests window-seconds)
  "Create a rate limiter.
   MAX-REQUESTS: Maximum requests per window
   WINDOW-SECONDS: Time window in seconds
   Returns rate-limiter object."
  (make-instance 'rate-limiter
                 :max-requests (or max-requests 30)
                 :window-seconds (or window-seconds 1)))

(defun rate-limit-try (limiter)
  "Try to make a request through the rate limiter.
   LIMITER: rate-limiter object
   Returns T if allowed, NIL if rate limited."
  (let* ((now (get-universal-time))
         (window-start (- now (rate-limiter-window-seconds limiter)))
         (requests (rate-limiter-requests limiter))
         ;; Filter to requests within window
         (recent-requests (remove-if-not (lambda (ts) (> ts window-start)) requests)))
    (if (< (length recent-requests) (rate-limiter-max-requests limiter))
        (progn
          ;; Add current request
          (setf (rate-limiter-requests limiter) (cons now recent-requests))
          t)
        (progn
          ;; Update list to remove old requests
          (setf (rate-limiter-requests limiter) recent-requests)
          nil))))

(defun rate-limit-wait (limiter)
  "Wait until rate limiter allows a request.
   LIMITER: rate-limiter object
   Returns T when ready."
  (loop until (rate-limit-try limiter)
        do (sleep 0.1))
  t)

(defun rate-limit-status (limiter)
  "Get rate limiter status.
   LIMITER: rate-limiter object
   Returns plist with status information."
  (let* ((now (get-universal-time))
         (window-start (- now (rate-limiter-window-seconds limiter)))
         (requests (remove-if-not (lambda (ts) (> ts window-start))
                                  (rate-limiter-requests limiter))))
    `(:current-requests ,(length requests)
      :max-requests ,(rate-limiter-max-requests limiter)
      :window-seconds ,(rate-limiter-window-seconds limiter)
      :remaining ,(- (rate-limiter-max-requests limiter) (length requests))
      :reset-in ,(rate-limiter-window-seconds limiter))))

;;; ======================================================================
;;; Logging and Debugging Utilities
;;; ======================================================================

(defparameter *log-level* :info
  "Current logging level")

(defparameter *log-output* *standard-output*
  "Log output stream")

(defparameter *log-prefix* "[cl-telegram]"
  "Log message prefix")

(defun set-log-level (level)
  "Set the current logging level.
   LEVEL: One of :debug, :info, :warning, :error
   Returns previous level."
  (let ((old *log-level*))
    (setq *log-level* level)
    old))

(defun log-message (level format-string &rest args)
  "Log a message with level filtering.
   LEVEL: Message level (:debug, :info, :warning, :error)
   FORMAT-STRING: Format string
   ARGS: Format arguments
   Returns NIL."
  (let ((levels '(:debug 0 :info 1 :warning 2 :error 3)))
    (when (>= (getf levels level 0) (getf levels *log-level* 0))
      (let* ((timestamp (format-datetime (get-universal-time) :format :iso-8601))
             (prefix (format nil "~A [~A] ~A:" *log-prefix* level timestamp)))
        (format *log-output* "~A ~A~%" prefix (apply #'format format-string args))
        (finish-output *log-output*)))))

(defun enable-debug-logging ()
  "Enable debug level logging.
   Returns previous level."
  (set-log-level :debug))

(defun disable-debug-logging ()
  "Disable debug logging (set to info level).
   Returns previous level."
  (set-log-level :info))

(defun with-logging (level format-string &body body)
  "Macro to log execution of a code block.
   LEVEL: Logging level
   FORMAT-STRING: Format string for entry message
   BODY: Code to execute
   Returns result of BODY."
  `(progn
     (log-message ,level "ENTER: ~A" ,format-string)
     (let ((start-time (get-universal-time))
           (result (progn ,@body)))
       (log-message ,level "EXIT: ~A (~A ms)"
                    ,format-string
                    (* (- (get-universal-time) start-time) 1000))
       result)))

(defmacro debug-time (&body body)
  "Measure and print execution time of body.
   BODY: Code to measure
   Returns result of BODY."
  `(let ((start (get-universal-time)))
     (let ((result (progn ,@body)))
       (format t "~&Execution time: ~A ms~%" (* (- (get-universal-time) start) 1000))
       result)))

;;; ======================================================================
;;; Configuration Management
;;; ======================================================================

(defclass config-manager ()
  ((config :initarg :config :accessor config-manager-config
           :initform (make-hash-table :test 'equal)
           :documentation "Configuration hash table")
   (file-path :initarg :file-path :accessor config-manager-file-path
              :initform "" :documentation "Configuration file path")
   (auto-save :initarg :auto-save :accessor config-manager-auto-save
               :initform t :documentation "Auto-save on changes")))

(defun make-config-manager (&key file-path auto-save)
  "Create a configuration manager.
   FILE-PATH: Optional path to config file
   AUTO-SAVE: Auto-save on changes if T
   Returns config-manager object."
  (let ((config (make-instance 'config-manager
                               :file-path (or file-path "")
                               :auto-save (or auto-save t))))
    (when file-path
      (load-config config file-path))
    config))

(defun get-config (manager key &optional default)
  "Get a configuration value.
   MANAGER: config-manager object
   KEY: Configuration key
   DEFAULT: Default value if not found
   Returns configuration value."
  (let ((value (gethash (format nil "~A" key) (config-manager-config manager))))
    (if value value default)))

(defun set-config (manager key value)
  "Set a configuration value.
   MANAGER: config-manager object
   KEY: Configuration key
   VALUE: Configuration value
   Returns T on success."
  (setf (gethash (format nil "~A" key) (config-manager-config manager)) value)
  (when (config-manager-auto-save manager)
    (save-config manager))
  t)

(defun load-config (manager file-path)
  "Load configuration from file.
   MANAGER: config-manager object
   FILE-PATH: Path to configuration file
   Returns T on success, NIL on failure."
  (handler-case
      (with-open-file (in file-path :direction :input)
        (let ((data (json:decode-json in)))
          (maphash (lambda (k v)
                     (setf (gethash k (config-manager-config manager)) v))
                   data))
        (setf (config-manager-file-path manager) file-path)
        t))
    (error (e)
      (log-message :error "Error loading config: ~A" e)
      nil)))

(defun save-config (manager &optional file-path)
  "Save configuration to file.
   MANAGER: config-manager object
   FILE-PATH: Optional path (uses stored path if not provided)
   Returns T on success, NIL on failure."
  (let ((path (or file-path (config-manager-file-path manager))))
    (when (string= path "")
      (log-message :error "No config file path specified")
      (return-from save-config nil))
    (handler-case
        (with-open-file (out path :direction :output
                                   :if-exists :supersede)
          (json:encode-json (config-manager-config manager) out)
          (log-message :info "Configuration saved to ~A" path)
          t))
    (error (e)
      (log-message :error "Error saving config: ~A" e)
      nil)))

(defun delete-config (manager key)
  "Delete a configuration value.
   MANAGER: config-manager object
   KEY: Configuration key
   Returns T on success, NIL if key not found."
  (let ((found (remhash (format nil "~A" key) (config-manager-config manager))))
    (when (and found (config-manager-auto-save manager))
      (save-config manager))
    found))

;;; ======================================================================
;;; Helper Macros
;;; ======================================================================

(defmacro with-connection ((conn) &body body)
  "Execute body with a connection, ensuring it's returned to pool.
   CONN: Connection variable name
   BODY: Code to execute
   Returns result of BODY."
  `(let ((,conn (get-connection-from-pool)))
     (unwind-protect
         (progn ,@body)
       (return-connection-to-pool ,conn))))

(defmacro with-retry ((&key max-retries delay on-error)
                      &body body)
  "Execute body with retry logic.
   MAX-RETRIES: Maximum retry attempts (default: 3)
   DELAY: Delay between retries in seconds (default: 1)
   ON-ERROR: Optional error handler function
   BODY: Code to execute
   Returns result of BODY or NIL after all retries fail."
  `(let ((max-retries (or ,max-retries 3))
         (delay (or ,delay 1))
         (attempts 0)
         (success nil)
         (result nil))
     (loop while (and (not success) (< attempts max-retries))
           do
           (handler-case
               (progn
                 (setq result (progn ,@body))
                 (setq success t))
             (error (e)
              (incf attempts)
              (when ,on-error
                (funcall ,on-error e attempts))
              (when (< attempts max-retries)
                (sleep delay)))))
     (if success result nil)))

(defmacro define-api-function (name args &body body)
  "Define an API function with standard error handling.
   NAME: Function name
   ARGS: Function arguments
   BODY: Function body
   Returns function definition."
  `(defun ,name ,args
     (handler-case
         (progn ,@body)
       (error (e)
         (log-message :error "Error in ~A: ~A" (symbol-name ',name) e)
         nil))))
