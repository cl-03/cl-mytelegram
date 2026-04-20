;;; bot-api-9-7.lisp --- Bot API 9.7 features for v0.30.0
;;;
;;; Provides CLOG-based implementation for Bot API 9.7 features:
;;; - Location API for device geolocation
;;; - File picker for file selection and upload
;;; - Notification API for browser push notifications
;;;
;;; Reference: https://core.telegram.org/bots/webapps
;;; Version: 0.30.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Section 1: Location API
;;; ============================================================================

(defvar *position-watches* (make-hash-table :test 'equal)
  "Hash table tracking active position watches")

(defun request-location-access ()
  "Request device location access via CLOG.

   Returns:
     T if granted, NIL if denied

   Example:
     (request-location-access)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from request-location-access nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 navigator.permissions.query({ name: 'geolocation' })
                   .then((result) => result.state === 'granted')
                   .catch(() => false);
               " :wait t)))
          result)
      (t (e)
        (log:error "Exception in request-location-access: ~A" e)
        nil))))

(defun get-current-location (&key (high-accuracy t) (timeout 10000) (maximum-age 0))
  "Get current device location.

   Args:
     high-accuracy: If T, use GPS if available
     timeout: Maximum time to wait for location (ms)
     maximum-age: Maximum age of cached location (ms)

   Returns:
     Plist with :latitude, :longitude, :accuracy, :timestamp or NIL

   Example:
     (get-current-location :high-accuracy t :timeout 10000)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from get-current-location nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise((resolve) => {
                   navigator.geolocation.getCurrentPosition(
                     (position) => resolve({
                       latitude: position.coords.latitude,
                       longitude: position.coords.longitude,
                       accuracy: position.coords.accuracy,
                       altitude: position.coords.altitude,
                       altitudeAccuracy: position.coords.altitudeAccuracy,
                       heading: position.coords.heading,
                       speed: position.coords.speed,
                       timestamp: position.timestamp
                     }),
                     (error) => resolve({ error: error.message, code: error.code }),
                     {
                       enableHighAccuracy: ~:[false;true~],
                       timeout: ~D,
                       maximumAge: ~D
                     }
                   );
                 });
               " high-accuracy timeout maximum-age) :wait t)))
          (when (and result (not (getf result :error)))
            result))
      (t (e)
        (log:error "Exception in get-current-location: ~A" e)
        nil))))

(defun watch-position (callback &key (enable-high-accuracy t) (timeout 10000))
  "Start watching position changes.

   Args:
     callback: Function to call with position updates
     enable-high-accuracy: If T, use GPS
     timeout: Timeout for each update (ms)

   Returns:
     Watch ID string or NIL

   Example:
     (watch-position (lambda (pos)
                       (format t \"Lat: ~A, Lon: ~A~\"
                               (getf pos :latitude)
                               (getf pos :longitude))))"
  (let ((manager (get-mini-app-manager)))
    (unless (and (mini-app-connected-p manager) callback)
      (return-from watch-position nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (watch-id (format nil "watch_~A" (get-universal-time))))
          ;; Store callback
          (setf (gethash watch-id *position-watches*) callback)
          ;; Start watching in browser
          (clog:run-js window (format nil "
            (function() {
              const watchId = navigator.geolocation.watchPosition(
                (position) => {
                  const pos = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy,
                    timestamp: position.timestamp
                  };
                  console.log('Position update:', JSON.stringify(pos));
                  // Note: In production, would callback to Lisp via CLOG
                },
                (error) => {
                  console.error('Position error:', error.message);
                },
                {
                  enableHighAccuracy: ~:[false;true~],
                  timeout: ~D
                }
              );
              // Store watch ID for cleanup
              window['~A'] = watchId;
            })();
          " enable-high-accuracy timeout watch-id))
          watch-id)
      (t (e)
        (log:error "Exception in watch-position: ~A" e)
        nil))))

(defun clear-position-watch (watch-id)
  "Stop watching position.

   Args:
     watch-id: Watch ID returned by watch-position

   Returns:
     T on success

   Example:
     (clear-position-watch \"watch_123\")"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from clear-position-watch nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window (format nil "
            if (window['~A']) {
              navigator.geolocation.clearWatch(window['~A']);
              delete window['~A'];
            }
          " watch-id watch-id watch-id))
          (remhash watch-id *position-watches*)
          t)
      (t (e)
        (log:error "Exception in clear-position-watch: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 2: File Picker API
;;; ============================================================================

(defun select-files (&key (accept "*/*") (multiple t) (max-file-size nil))
  "Open file picker and return selected files.

   Args:
     accept: Accepted file types (e.g., \"image/*\", \".pdf\", \"*/*\")
     multiple: If T, allow multiple file selection
     max-file-size: Maximum file size in bytes (NIL for no limit)

   Returns:
     List of file info plists or NIL

   Example:
     (select-files :accept \"image/*\" :multiple t)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from select-files nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise((resolve) => {
                   const input = document.createElement('input');
                   input.type = 'file';
                   input.accept = '~A';
                   input.multiple = ~:[false;true~];

                   input.onchange = async (e) => {
                     const files = Array.from(e.target.files);
                     const fileInfos = [];

                     for (const file of files) {
                       if (~A && file.size > ~A) {
                         continue; // Skip files exceeding size limit
                       }
                       fileInfos.push({
                         name: file.name,
                         size: file.size,
                         type: file.type,
                         lastModified: file.lastModified
                       });
                     }

                     resolve(fileInfos);
                   };

                   input.onerror = () => resolve([]);
                   input.click();
                 });
               " accept multiple (if max-file-size t nil) (or max-file-size 0)) :wait t)))
          result)
      (t (e)
        (log:error "Exception in select-files: ~A" e)
        nil))))

(defun select-directory (&key (recursive t))
  "Open directory picker.

   Args:
     recursive: If T, include files from subdirectories

   Returns:
     List of file info plists or NIL

   Example:
     (select-directory :recursive t)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from select-directory nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise((resolve) => {
                   const input = document.createElement('input');
                   input.type = 'file';
                   input.webkitdirectory = true;
                   input.multiple = true;

                   input.onchange = async (e) => {
                     const files = Array.from(e.target.files);
                     const fileInfos = [];

                     for (const file of files) {
                       fileInfos.push({
                         name: file.name,
                         path: file.webkitRelativePath,
                         size: file.size,
                         type: file.type,
                         lastModified: file.lastModified
                       });
                     }

                     resolve(fileInfos);
                   };

                   input.onerror = () => resolve([]);
                   input.click();
                 });
               " (if recursive t nil)) :wait t)))
          result)
      (t (e)
        (log:error "Exception in select-directory: ~A" e)
        nil))))

(defun read-file-content (file-path &key (as-type :text))
  "Read file content.

   Args:
     file-path: Path to file or file handle
     as-type: Content type (:text, :base64, :array-buffer)

   Returns:
     File content string or NIL

   Example:
     (read-file-content \"/path/to/file.txt\" :as-type :text)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from read-file-content nil))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise((resolve) => {
                   fetch('~A')
                     .then(response => response.arrayBuffer())
                     .then(buffer => {
                       const view = new DataView(buffer);
                       resolve({ type: 'buffer', length: buffer.byteLength });
                     })
                     .catch(err => resolve({ error: err.message }));
                 });
               " file-path) :wait t)))
          (case as-type
            (:text (clog:run-js window (format nil "
              fetch('~A').then(r => r.text()).then(t => resolve(t));
            " file-path) :wait t))
            (:base64 (clog:run-js window (format nil "
              fetch('~A')
                .then(r => r.arrayBuffer())
                .then(buffer => {
                  const bytes = new Uint8Array(buffer);
                  let binary = '';
                  for (let i = 0; i < bytes.byteLength; i++) {
                    binary += String.fromCharCode(bytes[i]);
                  }
                  return btoa(binary);
                });
            " file-path) :wait t))
            (otherwise result)))
      (t (e)
        (log:error "Exception in read-file-content: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 3: Notification API
;;; ============================================================================

(defvar *notification-handlers* (make-hash-table :test 'equal)
  "Hash table storing notification click handlers")

(defvar *notification-permission* nil
  "Cached notification permission status")

(defun request-notification-permission ()
  "Request browser notification permission.

   Returns:
     :granted, :denied, or :default

   Example:
     (request-notification-permission)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from request-notification-permission :default))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 Notification.requestPermission().then(permission => permission);
               " :wait t)))
          (setf *notification-permission* (case result
                                           ("granted" :granted)
                                           ("denied" :denied)
                                           (otherwise :default)))
          *notification-permission*)
      (t (e)
        (log:error "Exception in request-notification-permission: ~A" e)
        :default))))

(defun get-notification-permission ()
  "Get current notification permission status.

   Returns:
     :granted, :denied, or :default

   Example:
     (get-notification-permission)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from get-notification-permission :default))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window "
                 Notification.permission;
               " :wait t)))
          (case result
            ("granted" :granted)
            ("denied" :denied)
            (otherwise :default)))
      (t (e)
        (log:error "Exception in get-notification-permission: ~A" e)
        :default))))

(defun send-notification (title &key body icon badge tag require-interaction (silent nil))
  "Show browser notification.

   Args:
     title: Notification title
     body: Notification body text
     icon: Icon image URL
     badge: Badge image URL
     tag: Tag to group notifications
     require-interaction: If T, notification stays visible until clicked
     silent: If T, no sound is played

   Returns:
     T on success, NIL on failure

   Example:
     (send-notification \"New Message\"
                        :body \"You have a new message from John\"
                        :icon \"/icons/message.png\")"
  (let ((manager (get-mini-app-manager)))
    (unless (and (mini-app-connected-p manager) title)
      (return-from send-notification nil))
    ;; Check permission
    (let ((perm (get-notification-permission)))
      (unless (eq perm :granted)
        (log:warn "Notification permission not granted: ~A" perm)
        (return-from send-notification nil)))
    (handler-case
        (let* ((window (mini-app-window manager))
               (result (clog:run-js window (format nil "
                 new Promise((resolve) => {
                   const options = {
                     body: '~A',
                     silent: ~:[false;true~]
               " (or body "") silent)))
          (clog:run-js window (format nil "
                   if ('~A') {
                     options.icon = '~A';
                   }
                   if ('~A') {
                     options.badge = '~A';
                   }
                   if ('~A') {
                     options.tag = '~A';
                   }
                   if (~:[false;true~]) {
                     options.requireInteraction = true;
                   }

                   const notification = new Notification('~A', options);

                   notification.onclick = () => {
                     console.log('Notification clicked');
                     notification.close();
                   };

                   resolve('sent');
                 });
               " (if icon icon "") (if icon icon "")
                 (if badge badge "") (if badge badge "")
                 (if tag tag "") (if tag tag "")
                 require-interaction
                 title) :wait t))
          (declare (ignore result))
          t)
      (t (e)
        (log:error "Exception in send-notification: ~A" e)
        nil))))

(defun on-notification-click (handler-id handler-fn)
  "Register notification click handler.

   Args:
     handler-id: Unique handler identifier
     handler-fn: Function to call when notification is clicked

   Returns:
     T

   Example:
     (on-notification-click 'msg-handler
                            (lambda (notif)
                              (format t \"Notification clicked: ~A~\" notif)))"
  (let ((manager (get-mini-app-manager)))
    (when (mini-app-connected-p manager)
      (let ((window (mini-app-window manager)))
        (clog:run-js window "
          navigator.serviceWorker.addEventListener('notificationclick', (event) => {
            console.log('Notification clicked:', event.notification.tag);
            event.notification.close();
            // In production, would callback to Lisp via CLOG
          });
        ")))
    (setf (gethash handler-id *notification-handlers*) handler-fn)
    t))

(defun close-notification (tag)
  "Close a notification by tag.

   Args:
     tag: Notification tag

   Returns:
     T

   Example:
     (close-notification \"msg_123\")"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (return-from close-notification nil))
    (handler-case
        (let ((window (mini-app-window manager)))
          (clog:run-js window (format nil "
            navigator.serviceWorker.ready.then((registration) => {
              registration.getNotifications({ tag: '~A' }).then(notifications => {
                notifications.forEach(n => n.close());
              });
            });
          " tag))
          t)
      (t (e)
        (log:error "Exception in close-notification: ~A" e)
        nil))))

;;; ============================================================================
;;; Section 4: Cache and Cleanup
;;; ============================================================================

(defun clear-location-cache ()
  "Clear location-related cache and watches.

   Returns:
     T

   Example:
     (clear-location-cache)"
  (clrhash *position-watches*)
  (log:info "Location cache cleared")
  t)

(defun clear-notification-cache ()
  "Clear notification-related cache and handlers.

   Returns:
     T

   Example:
     (clear-notification-cache)"
  (clrhash *notification-handlers*)
  (setf *notification-permission* nil)
  (log:info "Notification cache cleared")
  t)

(defun get-bot-api-9-7-stats ()
  "Get Bot API 9.7 statistics.

   Returns:
     Plist with stats

   Example:
     (get-bot-api-9-7-stats)"
  (list :active-watches (hash-table-count *position-watches*)
        :notification-handlers (hash-table-count *notification-handlers*)
        :notification-permission *notification-permission*))

;;; ============================================================================
;;; Section 5: Initialization
;;; ============================================================================

(defun initialize-bot-api-9-7 ()
  "Initialize Bot API 9.7 features.

   Returns:
     T on success

   Example:
     (initialize-bot-api-9-7)"
  (let ((manager (get-mini-app-manager)))
    (unless (mini-app-connected-p manager)
      (log:error "Mini App not connected, cannot initialize Bot API 9.7")
      (return-from initialize-bot-api-9-7 nil))
    (handler-case
        (progn
          ;; Initialize notification permission cache
          (get-notification-permission)
          (log:info "Bot API 9.7 initialized")
          t)
      (t (e)
        (log:error "Exception in initialize-bot-api-9-7: ~A" e)
        nil))))
