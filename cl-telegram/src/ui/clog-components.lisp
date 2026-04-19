;;; clog-components.lisp --- Reusable CLOG UI components
;;;
;;; Provides reusable UI components for the Telegram GUI:
;;; - Group chat panels
;;; - Media viewer enhancements
;;; - Call interface
;;; - Settings panels

(in-package #:cl-telegram/ui)

;;; ### Group Chat Components

(defun render-group-members-list (win chat-id container)
  "Render list of group members.

   Args:
     win: CLOG window object
     chat-id: Group chat ID
     container: Container element"
  (clog:clear! container)

  (let* ((members (cl-telegram/api:get-cached-chat-members chat-id :limit 100))
         (admins (remove-if-not (lambda (m) (getf m :is-administrator)) members))
         (regular (remove-if (lambda (m) (getf m :is-administrator)) members)))

    (if (null members)
        (clog:append! container
                      (clog:create-element win "div" :class "empty-state"
                        (clog:create-element win "p" :text "No members yet")))
        (progn
          ;; Admins section
          (when admins
            (clog:append! container
                          (clog:create-element win "div" :class "members-section-header"
                            :text "Administrators"))
            (dolist (member admins)
              (render-group-member-item win container member :admin t)))

          ;; Regular members section
          (when regular
            (clog:append! container
                          (clog:create-element win "div" :class "members-section-header"
                            :text "Members"))
            (dolist (member regular)
              (render-group-member-item win container member)))))))

(defun render-group-member-item (win container member &key (admin nil))
  "Render a single group member item.

   Args:
     win: CLOG window object
     container: Container element
     member: Member plist
     admin: Whether this is an admin"
  (let* ((user (getf member :user))
         (user-id (getf user :id))
         (name (format nil "~A ~A"
                       (getf user :first-name "")
                       (getf user :last-name "")))
         (status (getf member :status))
         (item-el (clog:create-element win "div"
                                       :class (if admin "member-item member-item-admin" "member-item")
                                       :data-user-id (format nil "~A" user-id))))
    (clog:append! item-el
                  (clog:create-element win "div" :class "member-avatar"
                    :text (subseq name 0 (min 2 (length name))))
                  (clog:create-element win "div" :class "member-info"
                    (clog:create-element win "div" :class "member-name" :text name)
                    (when status
                      (clog:create-element win "div" :class "member-status" :text (format nil "~A" status))))
                  (clog:create-element win "div" :class "member-actions"
                    (let ((kick-btn (clog:create-element win "button"
                                                         :class "kick-member-btn"
                                                         :text "Remove")))
                      (clog:on kick-btn :click
                               (lambda (ev)
                                 (declare (ignore ev))
                                 (kick-member-confirm win (getf member :chat-id) user-id)))
                      kick-btn)))
    (clog:append! container item-el)))

(defun show-group-info-panel (win chat-id)
  "Show group info panel.

   Args:
     win: CLOG window object
     chat-id: Group chat ID"
  (let* ((chat (cl-telegram/api:get-cached-chat chat-id))
         (title (getf chat :title))
         (description (getf chat :description ""))
         (member-count (getf chat :member-count 0))
         (photo (getf chat :photo)))

    ;; Create overlay
    (let* ((overlay (clog:create-element win "div"
                                         :class "info-panel-overlay"
                                         :style "position: fixed; top: 0; right: -400px; width: 400px; height: 100vh; background: var(--bg-secondary); border-left: 1px solid var(--border); z-index: 1000; transition: right 0.3s ease;"))
           (header (clog:create-element win "div" :class "info-panel-header"))
           (content (clog:create-element win "div" :class "info-panel-content")))

      ;; Header with close button
      (clog:append! header
                    (clog:create-element win "h2" :text "Group Info")
                    (let ((close-btn (clog:create-element win "button"
                                                          :class "close-panel-btn"
                                                          :text "✕")))
                      (clog:on close-btn :click
                               (lambda (ev)
                                 (declare (ignore ev))
                                 (setf (clog:style overlay "right") "-400px")))
                      close-btn))

      ;; Group photo and title
      (clog:append! content
                    (clog:create-element win "div" :class "group-info-avatar"
                      :style "width: 100px; height: 100px; border-radius: 50%; background: var(--accent); display: flex; align-items: center; justify-content: center; font-size: 2em; margin: 20px auto;"
                      :text (subseq title 0 (min 2 (length title))))
                    (clog:create-element win "h2" :class "group-info-title" :text title)
                    (clog:create-element win "p" :class "group-info-members"
                                         :text (format nil "~A members" member-count)))

      ;; Description
      (when (and description (> (length description) 0))
        (clog:append! content
                      (clog:create-element win "div" :class "info-section"
                        (clog:create-element win "h3" :text "Description")
                        (clog:create-element win "p" :text description))))

      ;; Members list
      (clog:append! content
                    (clog:create-element win "div" :class "info-section"
                      (clog:create-element win "h3" :text "Members")
                      (clog:create-element win "div" :id "members-list-container"
                                           :class "members-list-container")))

      ;; Actions
      (clog:append! content
                    (clog:create-element win "div" :class "info-section"
                      (clog:create-element win "h3" :text "Actions")
                      (let ((invite-btn (clog:create-element win "button"
                                                             :class "action-btn"
                                                             :text "Create Invite Link")))
                        (clog:on invite-btn :click
                                 (lambda (ev)
                                   (declare (ignore ev))
                                   (create-group-invite-link-ui win chat-id)))
                        invite-btn)
                      (let ((leave-btn (clog:create-element win "button"
                                                            :class "action-btn danger"
                                                            :text "Leave Group")))
                        (clog:on leave-btn :click
                                 (lambda (ev)
                                   (declare (ignore ev))
                                   (leave-group-confirm win chat-id)))
                        leave-btn)))

      (clog:append! overlay header content)
      (clog:append! (clog:body win) overlay)

      ;; Slide in panel
      (clog:run-script win
        (format nil "setTimeout(function() {
          document.querySelector('.info-panel-overlay').style.right = '0';
          var membersContainer = document.querySelector('#members-list-container');
          if (membersContainer) {
            // Trigger members list render
            window.renderMembersList && window.renderMembersList('~A');
          }
        }, 100);" chat-id)))))

(defun create-group-invite-link-ui (win chat-id)
  "Create invite link UI.

   Args:
     win: CLOG window object
     chat-id: Chat ID"
  (handler-case
      (let* ((link-data (cl-telegram/api:create-chat-invite-link chat-id))
             (invite-link (getf link-data :invite-link)))
        (if invite-link
            ;; Show link dialog
            (let* ((dialog (clog:create-element win "div"
                                                :class "dialog-overlay"
                                                :style "position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); z-index: 10000; display: flex; align-items: center; justify-content: center;"))
                   (dialog-content (clog:create-element win "div"
                                                        :class "dialog-content"
                                                        :style "background: var(--bg-secondary); padding: 30px; border-radius: 12px; max-width: 400px; width: 90%;")))
              (clog:append! dialog-content
                            (clog:create-element win "h3" :text "Invite Link Created")
                            (clog:create-element win "div" :class "invite-link-box"
                              :style "background: var(--bg-tertiary); padding: 15px; border-radius: 8px; margin: 15px 0; word-break: break-all; font-family: monospace;"
                              :text invite-link)
                            (let ((copy-btn (clog:create-element win "button"
                                                                 :class "action-btn"
                                                                 :text "Copy Link")))
                              (clog:on copy-btn :click
                                       (lambda (ev)
                                         (declare (ignore ev))
                                         (clog:run-script win
                                           (format nil "navigator.clipboard.writeText('~A');"
                                                   invite-link))
                                         (setf (clog:text copy-btn) "✓ Copied!")))
                              copy-btn)
                            (let ((close-btn (clog:create-element win "button"
                                                                  :class "action-btn"
                                                                  :text "Close")))
                              (clog:on close-btn :click
                                       (lambda (ev)
                                         (declare (ignore ev))
                                         (clog:remove! dialog)))
                              close-btn))
              (clog:append! (clog:body win) dialog))
            (clog:run-script win "alert('Failed to create invite link');")))
    (error (e)
      (format t "Error creating invite link: ~A~%" e))))

;;; ### Call UI Components

(defun show-call-panel (win call-id)
  "Show individual call panel.

   Args:
     win: CLOG window object
     call-id: Call ID"
  (let* ((call (cl-telegram/api:get-call call-id))
         (peer-id (when call (cl-telegram/api::call-peer-user-id call)))
         (peer (when peer-id (cl-telegram/api:get-cached-user peer-id)))
         (peer-name (if peer
                        (format nil "~A ~A" (getf peer :first-name) (getf peer :last-name))
                        "Unknown"))
         (is-video (when call (cl-telegram/api::call-is-video call)))
         (state (when call (cl-telegram/api::call-state call))))

    ;; Create fullscreen call overlay
    (let* ((overlay (clog:create-element win "div"
                                         :class "call-overlay"
                                         :style (if is-video
                                                   "position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: #000; z-index: 10000;"
                                                   "position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: var(--bg-secondary); border-radius: 20px; padding: 40px; min-width: 400px; z-index: 10000; box-shadow: 0 20px 60px rgba(0,0,0,0.5);")))
           (avatar (clog:create-element win "div"
                                        :class "call-avatar"
                                        :style "width: 120px; height: 120px; border-radius: 50%; background: var(--accent); display: flex; align-items: center; justify-content: center; font-size: 3em; margin: 0 auto 20px;"
                                        :text (subseq peer-name 0 (min 2 (length peer-name)))))
           (name (clog:create-element win "h2" :class "call-name" :text peer-name))
           (status (clog:create-element win "p" :class "call-status"
                                        :style "color: var(--text-secondary); margin: 10px 0 30px;"
                                        :text (format nil "~A" (or state :connecting))))
           (controls (clog:create-element win "div" :class "call-controls"
                                          :style "display: flex; gap: 20px; justify-content: center; margin-top: 30px;")))

      ;; Video preview for video calls
      (when is-video
        (clog:append! overlay
                      (clog:create-element win "div" :class "video-grid"
                        :style "display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 20px;")
                      (clog:create-element win "div" :class "remote-video"
                        :style "background: #222; aspect-ratio: 16/9; border-radius: 12px;")
                      (clog:create-element win "div" :class "local-video"
                        :style "background: #222; aspect-ratio: 16/9; border-radius: 12px;"))))

      ;; Call control buttons
      (let ((mute-btn (clog:create-element win "button"
                                           :class "call-control-btn"
                                           :style "width: 60px; height: 60px; border-radius: 50%; background: var(--bg-tertiary); border: none; color: white; font-size: 24px; cursor: pointer;")
                                           :text "🎤"))
            (clog:on mute-btn :click
                     (lambda (ev)
                       (declare (ignore ev))
                       (cl-telegram/api:toggle-call-mute call-id :muted t)
                       (setf (clog:text mute-btn) "🔇")))
            (clog:append! controls mute-btn))

      (let ((video-btn (clog:create-element win "button"
                                            :class "call-control-btn"
                                            :style "width: 60px; height: 60px; border-radius: 50%; background: var(--bg-tertiary); border: none; color: white; font-size: 24px; cursor: pointer;"
                                            :text "📹")))
        (clog:on video-btn :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (cl-telegram/api:toggle-call-video call-id :enabled t)
                   (setf (clog:text video-btn) "📷")))
        (clog:append! controls video-btn))

      (let ((end-btn (clog:create-element win "button"
                                          :class "call-control-btn end-call"
                                          :style "width: 60px; height: 60px; border-radius: 50%; background: #ff4444; border: none; color: white; font-size: 24px; cursor: pointer;"
                                          :text "📞")))
        (clog:on end-btn :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (cl-telegram/api:end-call call)
                   (clog:remove! overlay)))
        (clog:append! controls end-btn))

      (clog:append! overlay avatar name status controls)
      (clog:append! (clog:body win) overlay)

      ;; Auto-connect WebRTC
      (when call
        (bt:make-thread
         (lambda ()
           (handler-case
               (progn
                 (multiple-value-bind (sdp error)
                     (cl-telegram/api:start-webrtc-call call-id :is-video is-video)
                   (when sdp
                     ;; Send SDP via Telegram signaling
                     (cl-telegram/api::send-call-signaling call-id sdp)))
                 ;; Update UI state
                 (clog:eval-in-window win
                   (setf (clog:text status) "Connected")))
             (error (e)
               (format t "WebRTC error: ~A~%" e)
               (clog:eval-in-window win
                 (setf (clog:text status) (format nil "Error: ~A" e)))))))))))

(defun show-group-call-panel (win group-call-id)
  "Show group call panel.

   Args:
     win: CLOG window object
     group-call-id: Group call ID"
  (let* ((group-call (cl-telegram/api:get-group-call group-call-id))
         (title (when group-call (cl-telegram/api::group-call-title group-call-id)))
         (participant-count (when group-call (cl-telegram/api::group-call-participant-count group-call-id)))
         (is-video-chat (when group-call (cl-telegram/api::group-call-is-video-chat group-call-id))))

    ;; Create group call overlay
    (let* ((overlay (clog:create-element win "div"
                                         :class "group-call-overlay"
                                         :style "position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: var(--bg-primary); z-index: 10000; display: flex; flex-direction: column;"))
           (header (clog:create-element win "div" :class "group-call-header"
                                        :style "padding: 20px; background: var(--bg-secondary); border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center;"))
           (main-area (clog:create-element win "div" :class "group-call-main"
                                           :style "flex: 1; display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; padding: 20px; overflow-y: auto;"))
           (controls (clog:create-element win "div" :class "group-call-controls"
                                          :style "padding: 20px; background: var(--bg-secondary); border-top: 1px solid var(--border); display: flex; gap: 15px; justify-content: center;"))))

      ;; Header
      (clog:append! header
                    (clog:create-element win "h2" :text (or title "Group Call"))
                    (clog:create-element win "span" :text (format nil "~A participants" (or participant-count 0)))
                    (let ((close-btn (clog:create-element win "button" :text "✕")))
                      (clog:on close-btn :click
                               (lambda (ev)
                                 (declare (ignore ev))
                                 (cl-telegram/api:leave-group-call group-call)
                                 (clog:remove! overlay)))
                      close-btn))

      ;; Video grid for participants
      (clog:append! main-area
                    (clog:create-element win "div" :class "participant-tile"
                      :style "background: #222; border-radius: 12px; display: flex; align-items: center; justify-content: center; min-height: 150px;"
                      :text "You"))

      ;; Controls
      (let ((mute-btn (clog:create-element win "button"
                                           :class "call-control-btn"
                                           :text "🎤 Mute")))
        (clog:on mute-btn :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (cl-telegram/api:toggle-group-call-mute group-call-id :muted t)
                   (setf (clog:text mute-btn) "🔇 Unmute")))
        (clog:append! controls mute-btn))

      (let ((video-btn (clog:create-element win "button"
                                            :class "call-control-btn"
                                            :text "📹 Video")))
        (clog:on video-btn :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (cl-telegram/api:toggle-group-call-video group-call-id :enabled t)
                   (setf (clog:text video-btn) "📷 Off")))
        (clog:append! controls video-btn))

      (let ((leave-btn (clog:create-element win "button"
                                            :class "call-control-btn leave"
                                            :style "background: #ff4444;"
                                            :text "Leave")))
        (clog:on leave-btn :click
                 (lambda (ev)
                   (declare (ignore ev))
                   (cl-telegram/api:leave-group-call group-call)
                   (clog:remove! overlay)))
        (clog:append! controls leave-btn))

      (clog:append! overlay header main-area controls)
      (clog:append! (clog:body win) overlay))))

(defun render-call-controls (win call-id container)
  "Render call control buttons.

   Args:
     win: CLOG window object
     call-id: Call ID
     container: Container element"
  (clog:clear! container)

  (let ((controls-row (clog:create-element win "div" :class "call-controls-row"
                                           :style "display: flex; gap: 15px; justify-content: center; padding: 20px;")))

    ;; Mute toggle
    (let ((mute-btn (clog:create-element win "button"
                                         :class "control-btn"
                                         :style "padding: 12px 24px; border-radius: 24px; background: var(--bg-tertiary); border: none; color: white; cursor: pointer;"
                                         :text "🎤 Mute")))
      (clog:on mute-btn :click
               (lambda (ev)
                 (declare (ignore ev))
                 (cl-telegram/api:toggle-call-mute call-id :muted t)
                 (setf (clog:text mute-btn) "🔇 Unmute")))
      (clog:append! controls-row mute-btn))

    ;; Video toggle
    (let ((video-btn (clog:create-element win "button"
                                          :class "control-btn"
                                          :style "padding: 12px 24px; border-radius: 24px; background: var(--bg-tertiary); border: none; color: white; cursor: pointer;"
                                          :text "📹 Video")))
      (clog:on video-btn :click
               (lambda (ev)
                 (declare (ignore ev))
                 (cl-telegram/api:toggle-call-video call-id :enabled t)
                 (setf (clog:text video-btn) "📷 Off")))
      (clog:append! controls-row video-btn))

    ;; End call
    (let ((end-btn (clog:create-element win "button"
                                        :class "control-btn end"
                                        :style "padding: 12px 24px; border-radius: 24px; background: #ff4444; border: none; color: white; cursor: pointer;"
                                        :text "📞 End")))
      (clog:on end-btn :click
               (lambda (ev)
                 (declare (ignore ev))
                 (cl-telegram/api:end-call
                  (cl-telegram/api:get-call call-id))
                 (clog:remove! (clog:parent container))))
      (clog:append! controls-row end-btn))

    (clog:append! container controls-row)))

(defun update-call-state (win call-id state)
  "Update call state display.

   Args:
     win: CLOG window object
     call-id: Call ID
     state: New state keyword"
  (let ((status-el (clog:query-selector win ".call-status")))
    (when status-el
      (setf (clog:text status-el)
            (case state
              (:pending "Connecting...")
              (:active "Connected")
              (:ended "Call ended")
              (otherwise (format nil "~A" state)))))))

;;; ### Media Viewer Enhancements

(defun render-media-gallery (win chat-id container)
  "Render media gallery for a chat.

   Args:
     win: CLOG window object
     chat-id: Chat ID
     container: Container element"
  (clog:clear! container)

  (let ((media-messages (cl-telegram/ui:find-messages-with-media chat-id)))
    (if (null media-messages)
        (clog:append! container
                      (clog:create-element win "div" :class "empty-state"
                        (clog:create-element win "p" :text "No media in this chat")))
        (let ((gallery-grid (clog:create-element win "div" :class "media-gallery-grid"
                                                 :style "display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px;")))
          (dolist (msg media-messages)
            (let* ((media (getf msg :media))
                   (media-type (getf media :@type))
                   (thumb-el (cond
                              ((or (eq media-type :photo) (eq media-type :messageMediaPhoto))
                               (clog:create-element win "div" :class "media-item photo"
                                 :style "aspect-ratio: 1; background: var(--bg-tertiary); border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 2em;"
                                 :text "📷")))
                              ((or (eq media-type :video) (eq media-type :messageMediaVideo))
                               (clog:create-element win "div" :class "media-item video"
                                 :style "aspect-ratio: 16/9; background: var(--bg-tertiary); border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 2em;"
                                 :text "🎬"))
                              ((or (eq media-type :document) (eq media-type :messageMediaDocument))
                               (clog:create-element win "div" :class "media-item document"
                                 :style "aspect-ratio: 1; background: var(--bg-tertiary); border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 2em;"
                                 :text "📎"))
                              (t nil))))
              (when thumb-el
                (clog:on thumb-el :click
                         (lambda (ev)
                           (declare (ignore ev))
                           (open-media-viewer-from-file-id win (getf media :file-id) msg)))
                (clog:append! gallery-grid thumb-el))))
          (clog:append! container gallery-grid)))))

;;; ### Settings Panel

(defun show-settings-panel (win)
  "Show settings panel.

   Args:
     win: CLOG window object"
  (let* ((overlay (clog:create-element win "div"
                                       :class "settings-overlay"
                                       :style "position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); z-index: 10000; display: flex; align-items: center; justify-content: center;"))
         (panel (clog:create-element win "div"
                                     :class "settings-panel"
                                     :style "background: var(--bg-secondary); border-radius: 12px; padding: 30px; max-width: 500px; width: 90%; max-height: 80vh; overflow-y: auto;")))

    (clog:append! panel
                  (clog:create-element win "h2" :text "Settings")

                  ;; Profile section
                  (clog:create-element win "div" :class "settings-section"
                    (clog:create-element win "h3" :text "Profile")
                    (let ((user (cl-telegram/api:get-me)))
                      (when user
                        (clog:append! panel
                                      (clog:create-element win "div" :class "profile-info"
                                        (clog:create-element win "p" :text (format nil "Name: ~A ~A"
                                                                                   (getf user :first-name)
                                                                                   (getf user :last-name)))
                                        (clog:create-element win "p" :text (format nil "Username: ~A"
                                                                                   (getf user :username "N/A")))))))))

                  ;; Notifications
                  (clog:create-element win "div" :class "settings-section"
                    (clog:create-element win "h3" :text "Notifications")
                    (let ((notify-checkbox (clog:create-element win "input"
                                                                :type "checkbox"
                                                                :checked t)))
                      (clog:append! panel
                                    (clog:create-element win "label"
                                      :style "display: flex; align-items: center; gap: 10px;"
                                      notify-checkbox
                                      (clog:create-element win "span" :text "Enable notifications")))))

                  ;; Privacy
                  (clog:create-element win "div" :class "settings-section"
                    (clog:create-element win "h3" :text "Privacy")
                    (clog:create-element win "p" :text "Privacy settings coming soon..."))

                  ;; Close button
                  (let ((close-btn (clog:create-element win "button"
                                                        :class "action-btn"
                                                        :text "Close")))
                    (clog:on close-btn :click
                             (lambda (ev)
                               (declare (ignore ev))
                               (clog:remove! overlay)))
                    close-btn))

    (clog:append! (clog:body win) overlay)))
