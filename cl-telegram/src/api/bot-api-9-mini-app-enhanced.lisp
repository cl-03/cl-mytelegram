;;; bot-api-9-mini-app-enhanced.lisp --- Enhanced Mini App features for v0.30.0
;;;
;;; Provides CLOG-based implementation for enhanced Mini App features:
;;; - Haptic Feedback API
;;; - Clipboard API
;;; - Share Target API
;;;
;;; Reference: https://core.telegram.org/bots/webapps
;;; Version: 0.30.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Haptic Feedback API
;;; ============================================================================

(defun haptic-feedback-impact (&optional (impact-level :medium))
  "Trigger impact haptic feedback.

   Args:
     impact-level: One of :light, :medium, :heavy, :rigid, :soft

   Returns:
     T on success

   Example:
     (haptic-feedback-impact :heavy)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from haptic-feedback-impact nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window (format nil "
            Telegram.WebApp.HapticFeedback.impactOccurred('~A');
          " (case impact-level
              (:light "light")
              (:medium "medium")
              (:heavy "heavy")
              (:rigid "rigid")
              (:soft "soft")
              (otherwise "medium"))))
          t)
      (t (e)
        (log:error "Exception in haptic-feedback-impact: ~A" e)
        nil))))

(defun haptic-feedback-notification (&optional (type :success))
  "Trigger notification haptic feedback.

   Args:
     type: One of :error, :success, :warning

   Returns:
     T on success

   Example:
     (haptic-feedback-notification :error)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from haptic-feedback-notification nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window (format nil "
            Telegram.WebApp.HapticFeedback.notificationOccurred('~A');
          " (case type
              (:error "error")
              (:success "success")
              (:warning "warning")
              (otherwise "success"))))
          t)
      (t (e)
        (log:error "Exception in haptic-feedback-notification: ~A" e)
        nil))))

(defun haptic-feedback-selection-change ()
  "Trigger selection change haptic feedback.

   Returns:
     T on success

   Example:
     (haptic-feedback-selection-change)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from haptic-feedback-selection-change nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window "
            Telegram.WebApp.HapticFeedback.selectionChanged();
          ")
          t)
      (t (e)
        (log:error "Exception in haptic-feedback-selection-change: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 2: Clipboard API
;;; ============================================================================

(defun read-clipboard-text ()
  "Read text from clipboard.

   Returns:
     Clipboard text string or NIL

   Example:
     (read-clipboard-text)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from read-clipboard-text nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 navigator.clipboard.readText()
                   .then(text => text)
                   .catch(err => null);
               " :wait t)))
          result)
      (t (e)
        (log:error "Exception in read-clipboard-text: ~A" e)
        nil))))

(defun write-clipboard-text (text)
  "Write text to clipboard.

   Args:
     text: Text to write to clipboard

   Returns:
     T on success

   Example:
     (write-clipboard-text \"Hello, World!\")"
  (let ((manager (get-mini-app-manager)))
    (unless (and (mini-app-connected-p manager) text)
      (return-from write-clipboard-text nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window (format nil "
            navigator.clipboard.writeText('~A')
              .then(() => true)
              .catch(err => false);
          " (escape-js-string text)) :wait t))
      (t (e)
        (log:error "Exception in write-clipboard-text: ~A" e)
        nil))))

(defun read-clipboard-files ()
  "Read files from clipboard.

   Returns:
     List of file info plists or NIL

   Example:
     (read-clipboard-files)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from read-clipboard-files nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 navigator.clipboard.read()
                   .then(items => {
                     const files = [];
                     for (const item of items) {
                       for (const type of item.types) {
                         if (type.startsWith('image/')) {
                           item.getType(type).then(blob => {
                             files.push({
                               name: 'clipboard_' + Date.now() + '.' + type.split('/')[1],
                               size: blob.size,
                               type: type
                             });
                           });
                         }
                       }
                     }
                     return files;
                   })
                   .catch(err => null);
               " :wait t)))
          result)
      (t (e)
        (log:error "Exception in read-clipboard-files: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 3: Share Target API
;;; ============================================================================

(defvar *share-target-handlers* (make-hash-table :test 'equal)
  "Hash table storing share target handlers")

(defun on-share-target-received (handler-id handler-fn)
  "Register handler for share target events.

   Args:
     handler-id: Unique handler identifier
     handler-fn: Function to call with shared data

   Returns:
     T

   Example:
     (on-share-target-received 'share-handler
                               (lambda (data)
                                 (format t \"Shared: ~A~\" (getf data :text))))"
  (let ((manager (get-mini-app-manager)))
    (when (mini-app-connected-p manager)
      (let ((window (mini-app-window manager)))
        (clog:run-js window "
          // Register service worker for share target
          if ('serviceWorker' in navigator) {
            navigator.serviceWorker.ready.then((registration) => {
              console.log('Share target service worker ready');
            });
          }
        ")))
    (setf (gethash handler-id *share-target-handlers*) handler-fn)
    t))

(defun get-shared-data ()
  "Get data shared via Share Target API.

   Returns:
     Plist with :title, :text, :url, :files or NIL

   Example:
     (get-shared-data)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from get-shared-data nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 new Promise((resolve) => {
                   const shareData = {
                     title: document.title,
                     text: '',
                     url: window.location.href
                   };

                   // Check for shared data in URL params
                   const params = new URLSearchParams(window.location.search);
                   if (params.has('title')) {
                     shareData.title = params.get('title');
                   }
                   if (params.has('text')) {
                     shareData.text = params.get('text');
                   }
                   if (params.has('url')) {
                     shareData.url = params.get('url');
                   }

                   resolve(shareData);
                 });
               " :wait t)))
          result)
      (t (e)
        (log:error "Exception in get-shared-data: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 4: Share API (Active Sharing)
;;; ============================================================================

(defun share-text (text &key title url)
  "Share text via Web Share API.

   Args:
     text: Text to share
     title: Optional share title
     url: Optional URL to share

   Returns:
     T on success, NIL on failure

   Example:
     (share-text \"Check this out!\" :title \"My Share\" :url \"https://example.com\")"
  (let ((manager (get-mini-app-manager)))
    (unless (and (mini-app-connected-p manager) text)
      (return-from share-text nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 navigator.share({
                   title: '~A',
                   text: '~A',
                   url: '~A'
                 })
                 .then(() => true)
                 .catch(err => false);
               " (or title "") text (or url "")) :wait t)))
          result)
      (t (e)
        (log:error "Exception in share-text: ~A" e)
        nil))))

(defun share-file (file-path &key title description)
  "Share a file via Web Share API.

   Args:
     file-path: Path to file to share
     title: Optional share title
     description: Optional file description

   Returns:
     T on success, NIL on failure

   Example:
     (share-file \"/path/to/image.jpg\" :title \"My Photo\")"
  (let ((manager (get-mini-app-manager)))
    (unless (and (mini-app-connected-p manager) file-path)
      (return-from share-file nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 fetch('~A')
                   .then(response => response.blob())
                   .then(blob => {
                     const file = new File([blob], '~A', { type: blob.type });
                     return navigator.share({
                       title: '~A',
                       text: '~A',
                       files: [file]
                     });
                   })
                   .then(() => true)
                   .catch(err => false);
               " file-path (file-namestring file-path) (or title "") (or description "")) :wait t)))
          result)
      (t (e)
        (log:error "Exception in share-file: ~A" e)
        nil))))

(defun can-share-p (&key text url files)
  "Check if Web Share API can share the given content.

   Args:
     text: Text to check
     url: URL to check
     files: List of files to check

   Returns:
     T if shareable, NIL otherwise

   Example:
     (can-share-p :text \"Hello\" :url \"https://example.com\")"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from can-share-p nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 navigator.canShare({
                   ~@[text: '~A',~]
                   ~@[url: '~A',~]
                   ~@[files: ~A~]
                 });
               " (if text text "") (if url url "") (if files "[]" nil)) :wait t)))
          result)
      (t (e)
        (log:error "Exception in can-share-p: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 5: Utility Functions
;;; ============================================================================

(defun escape-js-string (string)
  "Escape string for safe use in JavaScript.

   Args:
     string: String to escape

   Returns:
     Escaped string

   Example:
     (escape-js-string \"Hello 'World'!\")"
  (when string
    (string-replace
     (string-replace
      (string-replace
       (string-replace string "\\" "\\\\")
       "'" "\\'")
      "\"" "\\\"")
     #\Newline "\\n")))

(defun string-replace (string old new)
  "Replace all occurrences of OLD with NEW in STRING.

   Args:
     string: Source string
     old: Substring to replace
     new: Replacement string

   Returns:
     Modified string"
  (let ((result (copy-seq string))
        (old-len (length old))
        (new-len (length new))
        (pos 0))
    (loop
       for found-pos = (search old result :start2 pos)
       while found-pos
       do
         (setf result (concatenate 'string
                                   (subseq result 0 found-pos)
                                   new
                                   (subseq result (+ found-pos old-len))))
         (setf pos (+ found-pos new-len)))
    result))

;;; ============================================================================
;;; Section 6: Cache and Cleanup
;;; ============================================================================

(defun clear-mini-app-enhanced-cache ()
  "Clear enhanced Mini App cache.

   Returns:
     T

   Example:
     (clear-mini-app-enhanced-cache)"
  (log:info "Enhanced Mini App cache cleared")
  t)

(defun get-mini-app-enhanced-stats ()
  "Get enhanced Mini App statistics.

   Returns:
     Plist with stats

   Example:
     (get-mini-app-enhanced-stats)"
  (list :haptic-feedback-supported t
        :clipboard-supported t
        :share-supported t))

;;; ============================================================================
;;; Section 7: Initialization
;;; ============================================================================

(defun initialize-mini-app-enhanced ()
  "Initialize enhanced Mini App features.

   Returns:
     T on success

   Example:
     (initialize-mini-app-enhanced)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (log:error "Mini App not connected, cannot initialize enhanced features")
      (return-from initialize-mini-app-enhanced nil))
    (handler-case
        (progn
          (log:info "Enhanced Mini App features initialized")
          t)
      (t (e)
        (log:error "Exception in initialize-mini-app-enhanced: ~A" e)
        nil))))
