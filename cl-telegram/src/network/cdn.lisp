;;; cdn.lisp --- CDN and datacenter management

(in-package #:cl-telegram/network)

;;; ### Datacenter Definitions

;; Telegram Production Datacenters
(defparameter *production-dcs*
  '((:dc-id 1 :hostname "149.154.167.50" :port 443 :location "Zug, Switzerland" :priority 1)
    (:dc-id 2 :hostname "149.154.167.51" :port 443 :location "Amsterdam, Netherlands" :priority 2)
    (:dc-id 3 :hostname "149.154.175.52" :port 443 :location "Singapore" :priority 3)
    (:dc-id 4 :hostname "149.154.167.91" :port 443 :location "London, UK" :priority 2)
    (:dc-id 5 :hostname "149.154.171.5" :port 443 :location "New York, USA" :priority 3))
  "Production Telegram datacenters")

;; Test Datacenters
(defparameter *test-dcs*
  '((:dc-id 1 :hostname "149.154.167.40" :port 443 :location "Test DC 1" :priority 1)
    (:dc-id 2 :hostname "149.154.167.41" :port 443 :location "Test DC 2" :priority 2))
  "Test Telegram datacenters")

;;; ### DC Manager

(defclass dc-manager ()
  ((current-dc :initarg :current-dc :initform nil
               :accessor dc-manager-current-dc
               :documentation "Current active DC")
   (dc-pool :initform (make-hash-table) :accessor dc-manager-pool
            :documentation "Pool of connections by DC ID")
   (dc-latencies :initform (make-hash-table) :accessor dc-manager-latencies
                 :documentation "Measured latencies to each DC")
   (preferred-dc :initarg :preferred-dc :initform nil
                 :accessor dc-manager-preferred-dc
                 :documentation "User preferred DC")
   (lock :initform (bt:make-lock "dc-manager")
         :accessor dc-manager-lock
         :documentation "Lock for thread-safe access"))
  (:documentation "Datacenter connection manager"))

(defun make-dc-manager (&key (preferred-dc nil) (test-mode nil))
  "Create DC manager.

   Args:
     preferred-dc: Preferred DC ID (nil for auto-select)
     test-mode: Use test DCs

   Returns:
     DC manager instance"
  (let ((mgr (make-instance 'dc-manager
                            :preferred-dc preferred-dc)))
    ;; Initialize DC pool
    (let ((dcs (if test-mode *test-dcs* *production-dcs*)))
      (dolist (dc-info dcs)
        (let ((dc-id (getf dc-info :dc-id))
              (conn (make-connection :host (getf dc-info :hostname)
                                     :port (getf dc-info :port))))
          (setf (gethash dc-id (dc-manager-pool mgr))
                (list :connection conn
                      :info dc-info
                      :status :disconnected)))))
    mgr))

(defun get-dc-connection (mgr dc-id)
  "Get connection for specific DC.

   Args:
     mgr: DC manager instance
     dc-id: Datacenter ID

   Returns:
     Connection instance"
  (bt:with-lock-held ((dc-manager-lock mgr))
    (let ((entry (gethash dc-id (dc-manager-pool mgr))))
      (when entry
        (let ((conn (getf entry :connection)))
          (unless (connected-p conn)
            (connect conn)
            (setf (getf entry :status) :connected))
          conn)))))

(defun get-current-connection (mgr)
  "Get current active connection.

   Args:
     mgr: DC manager instance

   Returns:
     Connection instance"
  (let ((current-dc (dc-manager-current-dc mgr)))
    (if current-dc
        (get-dc-connection mgr current-dc)
        ;; Auto-select best DC
        (let ((best-dc (select-best-dc mgr)))
          (setf (dc-manager-current-dc mgr) best-dc)
          (get-dc-connection mgr best-dc)))))

(defun select-best-dc (mgr)
  "Select best DC based on latency and preference.

   Args:
     mgr: DC manager instance

   Returns:
     Best DC ID"
  (let ((preferred (dc-manager-preferred-dc mgr)))
    (if preferred
        preferred
        ;; Select by lowest latency
        (let ((best-dc nil)
              (best-latency most-positive-fixnum))
          (maphash (lambda (dc-id latency)
                     (when (< latency best-latency)
                       (setf best-latency latency)
                       (setf best-dc dc-id)))
                   (dc-manager-latencies mgr))
          (or best-dc 1)))))

(defun switch-dc (mgr new-dc-id)
  "Switch to different datacenter.

   Args:
     mgr: DC manager instance
     new-dc-id: Target DC ID

   Returns:
     New connection"
  (let ((old-dc (dc-manager-current-dc mgr)))
    (setf (dc-manager-current-dc mgr) new-dc-id)
    (let ((new-conn (get-dc-connection mgr new-dc-id)))
      ;; Migrate session if needed
      (when old-dc
        (let ((old-conn (get-dc-connection mgr old-dc)))
          ;; Transfer auth key
          (when (conn-auth-key old-conn)
            (setf (conn-auth-key new-conn) (conn-auth-key old-conn)
                  (conn-auth-key-id new-conn) (conn-auth-key-id old-conn)))))
      new-conn)))

(defun measure-dc-latency (mgr dc-id)
  "Measure latency to a datacenter.

   Args:
     mgr: DC manager instance
     dc-id: DC ID to measure

   Returns:
     Latency in milliseconds"
  (let ((conn (get-dc-connection mgr dc-id))
        (start (get-internal-real-time)))
    (handler-case
        (progn
          (send-ping conn)
          (let ((end (get-internal-real-time)))
            (let ((latency (/ (* (- end start) 1000) internal-time-units-per-second)))
              (setf (gethash dc-id (dc-manager-latencies mgr)) latency)
              latency)))
      (error (e)
        (declare (ignore e))
        most-positive-fixnum))))

(defun measure-all-dc-latencies (mgr)
  "Measure latencies to all DCs.

   Args:
     mgr: DC manager instance

   Returns:
     alist of (dc-id . latency)"
  (let ((results nil))
    (maphash (lambda (dc-id info)
               (declare (ignore info))
               (let ((latency (measure-dc-latency mgr dc-id)))
                 (push (cons dc-id latency) results)))
             (dc-manager-pool mgr))
    results))

(defun get-dc-info (mgr dc-id)
  "Get information about a DC.

   Args:
     mgr: DC manager instance
     dc-id: DC ID

   Returns:
     DC info plist"
  (let ((entry (gethash dc-id (dc-manager-pool mgr))))
    (when entry
      (getf entry :info))))

(defun dc-manager-stats (mgr)
  "Get DC manager statistics.

   Returns:
     plist with statistics"
  (let ((current (dc-manager-current-dc mgr))
        (preferred (dc-manager-preferred-dc mgr)))
    (list :current-dc current
          :preferred-dc preferred
          :latencies (loop for dc-id being the hash-keys of (dc-manager-latencies mgr)
                           for latency = (gethash dc-id (dc-manager-latencies mgr))
                           collect (list dc-id latency))
          :pool-size (hash-table-count (dc-manager-pool mgr)))))

;;; ### CDN Configuration

(defstruct cdn-config
  "CDN configuration for file downloads"
  (enabled t :type boolean)
  (base-url "https://cdn.telegram.org" :type string)
  (fallback-dcs '(1 2 3 4 5) :type list)
  (max-concurrent-downloads 4 :type integer)
  (chunk-size 1048576 :type integer))  ; 1MB default

(defvar *cdn-config* (make-cdn-config)
  "Global CDN configuration")

(defun configure-cdn (&key enabled base-url fallback-dcs max-concurrent chunk-size)
  "Configure CDN settings.

   Args:
     enabled: Enable CDN downloads
     base-url: CDN base URL
     fallback-dcs: List of fallback DC IDs
     max-concurrent: Maximum concurrent downloads
     chunk-size: Download chunk size in bytes"
  (setf (cdn-config-enabled *cdn-config*) (or enabled t))
  (when base-url
    (setf (cdn-config-base-url *cdn-config*) base-url))
  (when fallback-dcs
    (setf (cdn-config-fallback-dcs *cdn-config*) fallback-dcs))
  (when max-concurrent
    (setf (cdn-config-max-concurrent-downloads *cdn-config*) max-concurrent))
  (when chunk-size
    (setf (cdn-config-chunk-size *cdn-config*) chunk-size)))

;;; ### DC Migration

(defun export-auth (conn)
  "Export authorization for DC migration.

   Args:
     conn: Connection instance

   Returns:
     Auth data plist"
  (list :auth-key (conn-auth-key conn)
        :auth-key-id (conn-auth-key-id conn)
        :server-salt (conn-server-salt conn)
        :session-id (conn-session-id conn)))

(defun import-auth (conn auth-data)
  "Import authorization to new DC.

   Args:
     conn: Connection instance
     auth-data: Auth data from export-auth

   Returns:
     T on success"
  (setf (conn-auth-key conn) (getf auth-data :auth-key)
        (conn-auth-key-id conn) (getf auth-data :auth-key-id)
        (conn-server-salt conn) (getf auth-data :server-salt)
        (conn-session-id conn) (getf auth-data :session-id))
  t)

(defun migrate-to-dc (mgr target-dc-id)
  "Migrate session to different DC.

   Args:
     mgr: DC manager instance
     target-dc-id: Target DC ID

   Returns:
     New connection"
  (let* ((current-dc (dc-manager-current-dc mgr))
         (old-conn (when current-dc (get-dc-connection mgr current-dc)))
         (auth-data (when old-conn (export-auth old-conn)))
         (new-conn (get-dc-connection mgr target-dc-id)))
    (when auth-data
      (import-auth new-conn auth-data))
    (setf (dc-manager-current-dc mgr) target-dc-id)
    new-conn))

;;; ### Helper Functions

(defun dc-id-from-phone (phone-number)
  "Suggest DC ID based on phone number country code.

   Args:
     phone-number: Phone number string (e.g., \"+1234567890\")

   Returns:
     Suggested DC ID

   DC assignment by region:
   - 1: DC1 (Switzerland) - Default
   - 2: DC2 (Netherlands) - Europe
   - 3: DC3 (Singapore) - Asia
   - 4: DC4 (UK) - Europe fallback
   - 5: DC5 (USA) - Americas"
  (let ((country-code (when (and phone-number (>= (length phone-number) 3))
                        (subseq phone-number 1 3))))
    (cond
      ;; Americas
      ((member country-code '("1" "52" "55" "54" "56" "57" "58") :test #'string=) 5)
      ;; Europe
      ((member country-code '("30" "31" "32" "33" "34" "39" "40" "41" "42" "43" "44" "45" "46" "47" "48" "49") :test #'string=) 2)
      ;; Asia
      ((member country-code '("60" "62" "63" "65" "66" "81" "82" "84" "86" "90" "91" "92" "93" "94" "95" "98") :test #'string=) 3)
      ;; Default
      (t 1))))
