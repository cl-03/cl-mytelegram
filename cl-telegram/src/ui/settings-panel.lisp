;;; settings-panel.lisp --- Settings panel for Web UI
;;;
;;; Provides settings functionality for the web interface:
;;; - Account settings (username, bio, profile photo)
;;; - Notification preferences
;;; - Privacy controls
;;; - Theme selection
;;; - Language settings

(in-package #:cl-telegram/ui)

;;; ============================================================================
;;; Settings State
;;; ============================================================================

(defvar *user-settings* (make-hash-table :test 'eq)
  "User settings storage")

(defvar *settings-defaults*
  '(:theme :dark
    :language :en
    :notifications-enabled t
    :notification-sound t
    :desktop-notifications t
    :message-preview t
    :privacy-phone :contacts
    :privacy-last-seen :everybody
    :privacy-profile-photo :everybody
    :auto-download-media :wifi
    :auto-download-max-size 10485760) ; 10MB
  "Default settings values")

;;; ============================================================================
;;; Settings Management
;;; ============================================================================

(defun initialize-user-settings (&optional (user-id nil))
  "Initialize user settings with defaults.

   Args:
     user-id: Optional user identifier for multi-user support

   Returns:
     Settings plist"
  (let ((settings (copy-list *settings-defaults*)))
    (when user-id
      (setf (gethash (intern (format nil "USER-~A" user-id)) *user-settings*)
            settings))
    settings))

(defun get-user-setting (key &optional (default nil))
  "Get a user setting value.

   Args:
     key: Setting keyword
     default: Default value if not set

   Returns:
     Setting value"
  (let ((settings (initialize-user-settings)))
    (getf settings key default)))

(defun set-user-setting (key value)
  "Set a user setting value.

   Args:
     key: Setting keyword
     value: New value

   Returns:
     T on success"
  (let ((settings (initialize-user-settings)))
    (setf (getf settings key) value)
    t))

(defun get-all-settings ()
  "Get all user settings.

   Returns:
     Settings plist"
  (initialize-user-settings))

(defun save-settings-to-storage (&optional (user-id nil))
  "Save settings to persistent storage.

   Args:
     user-id: Optional user identifier

   Returns:
     T on success"
  (let ((settings (get-all-settings)))
    (when user-id
      (setf (gethash (intern (format nil "USER-~A" user-id)) *user-settings*)
            settings))
    ;; TODO: Save to database
    t))

(defun load-settings-from-storage (&optional (user-id nil))
  "Load settings from persistent storage.

   Args:
     user-id: Optional user identifier

   Returns:
     Settings plist"
  (when user-id
    (let ((stored (gethash (intern (format nil "USER-~A" user-id)) *user-settings*)))
      (when stored
        (return-from load-settings-from-storage stored))))
  (initialize-user-settings))

;;; ============================================================================
;;; HTML Generation for Settings Panel
;;; ============================================================================

(defun generate-settings-panel-html ()
  "Generate HTML for settings panel.

   Returns:
     HTML string"
  (let ((settings (get-all-settings)))
    (format nil
"<div class=\"settings-panel\">
  <div class=\"settings-header\">
    <h3>Settings</h3>
    <button class=\"close-settings\" onclick=\"closeSettingsPanel()\">✕</button>
  </div>

  <div class=\"settings-content\">
    ~A
    ~A
    ~A
    ~A
    ~A
  </div>

  <div class=\"settings-footer\">
    <button class=\"save-settings-btn\" onclick=\"saveSettings()\">Save Changes</button>
  </div>
</div>"
            (generate-account-settings-html settings)
            (generate-appearance-settings-html settings)
            (generate-notification-settings-html settings)
            (generate-privacy-settings-html settings)
            (generate-advanced-settings-html settings))))

(defun generate-account-settings-html (settings)
  "Generate account settings section HTML.

   Args:
     settings: Settings plist

   Returns:
     HTML string"
  (format nil
"<section class=\"settings-section\">
  <h4 class=\"section-title\">👤 Account</h4>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Username</label>
    <input type=\"text\" class=\"setting-input\" id=\"setting-username\"
           placeholder=\"@username\" value=\"~A\">
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Display Name</label>
    <input type=\"text\" class=\"setting-input\" id=\"setting-display-name\"
           placeholder=\"Your name\" value=\"~A\">
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Bio</label>
    <textarea class=\"setting-textarea\" id=\"setting-bio\"
              placeholder=\"Tell us about yourself\" rows=\"3\">~A</textarea>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Profile Photo</label>
    <div class=\"profile-photo-upload\">
      <button class=\"upload-btn\" onclick=\"uploadProfilePhoto()\">
        📷 Upload Photo
      </button>
      <div class=\"current-photo\" id=\"current-photo\">
        <img src=\"/assets/default-avatar.png\" alt=\"Profile\">
      </div>
    </div>
  </div>
</section>"
          "" ; username placeholder
          "" ; display name placeholder
          "")) ; bio placeholder

(defun generate-appearance-settings-html (settings)
  "Generate appearance settings section HTML.

   Args:
     settings: Settings plist

   Returns:
     HTML string"
  (let ((theme (getf settings :theme :dark))
        (language (getf settings :language :en)))
    (format nil
"<section class=\"settings-section\">
  <h4 class=\"section-title\">🎨 Appearance</h4>

  <div class=\"setting-item">
    <label class=\"setting-label\">Theme</label>
    <div class=\"theme-selector\">
      <button class=\"theme-option ~:[~;active~]\" data-theme=\"dark\" onclick=\"selectTheme('dark')\">
        🌙 Dark
      </button>
      <button class=\"theme-option ~:[~;active~]\" data-theme=\"light\" onclick=\"selectTheme('light')\">
        ☀️ Light
      </button>
      <button class=\"theme-option ~:[~;active~]\" data-theme=\"auto\" onclick=\"selectTheme('auto')\">
        🔄 Auto
      </button>
    </div>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Language</label>
    <select class=\"setting-select\" id=\"setting-language\">
      <option value=\"en\" ~:[~;selected~]>English</option>
      <option value=\"zh\" ~:[~;selected~]>中文</option>
      <option value=\"es\" ~:[~;selected~]>Español</option>
      <option value=\"ru\" ~:[~;selected~]>Русский</option>
      <option value=\"de\" ~:[~;selected~]>Deutsch</option>
      <option value=\"fr\" ~:[~;selected~]>Français</option>
      <option value=\"ja\" ~:[~;selected~]>日本語</option>
    </select>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Message Text Size</label>
    <input type=\"range\" class=\"setting-range\" id=\"setting-font-size\"
           min=\"12\" max=\"24\" value=\"16\">
    <div class=\"range-labels\">
      <span>Small</span>
      <span>Medium</span>
      <span>Large</span>
    </div>
  </div>
</section>"
            (eq theme :dark)
            (eq theme :light)
            (eq theme :auto)
            (eq language :en)
            (eq language :zh)
            (eq language :es)
            (eq language :ru)
            (eq language :de)
            (eq language :fr)
            (eq language :ja))))

(defun generate-notification-settings-html (settings)
  "Generate notification settings section HTML.

   Args:
     settings: Settings plist

   Returns:
     HTML string"
  (let ((enabled (getf settings :notifications-enabled t))
        (sound (getf settings :notification-sound t))
        (desktop (getf settings :desktop-notifications t))
        (preview (getf settings :message-preview t)))
    (format nil
"<section class=\"settings-section\">
  <h4 class=\"section-title\">🔔 Notifications</h4>

  <div class=\"setting-item">
    <label class=\"setting-label\">
      <span>Enable Notifications</span>
      <label class=\"toggle-switch\">
        <input type=\"checkbox\" id=\"setting-notifications-enabled\" ~:[~;checked~]>
        <span class=\"toggle-slider\"></span>
      </label>
    </label>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Notification Sound</span>
      <label class=\"toggle-switch\">
        <input type=\"checkbox\" id=\"setting-notification-sound\" ~:[~;checked~]>
        <span class=\"toggle-slider\"></span>
      </label>
    </label>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Desktop Notifications</span>
      <label class=\"toggle-switch\">
        <input type=\"checkbox\" id=\"setting-desktop-notifications\" ~:[~;checked~]>
        <span class=\"toggle-slider\"></span>
      </label>
    </label>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Show Message Preview</span>
      <label class=\"toggle-switch\">
        <input type=\"checkbox\" id=\"setting-message-preview\" ~:[~;checked~]>
        <span class=\"toggle-slider\"></span>
      </label>
    </label>
  </div>

  <div class=\"setting-item">
    <label class=\"setting-label\">Notification Sound</label>
    <select class=\"setting-select\" id=\"setting-sound\">
      <option value=\"default\">Default</option>
      <option value=\"chime\">Chime</option>
      <option value=\"bell\">Bell</option>
      <option value=\"silent\">Silent</option>
    </select>
  </div>
</section>"
            enabled
            sound
            desktop
            preview))))

(defun generate-privacy-settings-html (settings)
  "Generate privacy settings section HTML.

   Args:
     settings: Settings plist

   Returns:
     HTML string"
  (let ((phone (getf settings :privacy-phone :contacts))
        (last-seen (getf settings :privacy-last-seen :everybody))
        (profile-photo (getf settings :privacy-profile-photo :everybody)))
    (format nil
"<section class=\"settings-section\">
  <h4 class=\"section-title\">🔒 Privacy & Security</h4>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Phone Number</label>
    <select class=\"setting-select\" id=\"setting-privacy-phone\">
      <option value=\"everybody\" ~:[~;selected~]>Everybody</option>
      <option value=\"contacts\" ~:[~;selected~]>My Contacts</option>
      <option value=\"nobody\" ~:[~;selected~]>Nobody</option>
    </select>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Last Seen & Online</label>
    <select class=\"setting-select\" id=\"setting-privacy-last-seen\">
      <option value=\"everybody\" ~:[~;selected~]>Everybody</option>
      <option value=\"contacts\" ~:[~;selected~]>My Contacts</option>
      <option value=\"nobody\" ~:[~;selected~]>Nobody</option>
    </select>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Profile Photos</label>
    <select class=\"setting-select\" id=\"setting-privacy-profile-photo\">
      <option value=\"everybody\" ~:[~;selected~]>Everybody</option>
      <option value=\"contacts\" ~:[~;selected~]>My Contacts</option>
      <option value=\"nobody\" ~:[~;selected~]>Nobody</option>
    </select>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Two-Factor Authentication</span>
      <button class=\"secondary-btn\" onclick=\"setup2FA()\">Setup</button>
    </label>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Active Sessions</span>
      <button class=\"secondary-btn\" onclick=\"showActiveSessions()\">View</button>
    </label>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Blocked Users</span>
      <button class=\"secondary-btn\" onclick=\"showBlockedUsers()\">Manage</button>
    </label>
  </div>
</section>"
            (eq phone :everybody)
            (eq phone :contacts)
            (eq phone :nobody)
            (eq last-seen :everybody)
            (eq last-seen :contacts)
            (eq last-seen :nobody)
            (eq profile-photo :everybody)
            (eq profile-photo :contacts)
            (eq profile-photo :nobody))))

(defun generate-advanced-settings-html (settings)
  "Generate advanced settings section HTML.

   Args:
     settings: Settings plist

   Returns:
     HTML string"
  (let ((auto-download (getf settings :auto-download-media :wifi))
        (max-size (getf settings :auto-download-max-size 10485760)))
    (format nil
"<section class=\"settings-section\">
  <h4 class=\"section-title\">⚙️ Advanced</h4>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Auto-Download Media</label>
    <select class=\"setting-select\" id=\"setting-auto-download\">
      <option value=\"wifi\" ~:[~;selected~]>Wi-Fi Only</option>
      <option value=\"always\" ~:[~;selected~]>Always</option>
      <option value=\"never\" ~:[~;selected~]>Never</option>
    </select>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">Max Auto-Download Size</label>
    <select class=\"setting-select\" id=\"setting-max-size\">
      <option value=\"1048576\" ~:[~;selected~]>1 MB</option>
      <option value=\"5242880\" ~:[~;selected~]>5 MB</option>
      <option value=\"10485760\" ~:[~;selected~]>10 MB</option>
      <option value=\"20971520\" ~:[~;selected~]>20 MB</option>
      <option value=\"52428800\" ~:[~;selected~]>50 MB</option>
    </select>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Clear Cache</span>
      <button class=\"danger-btn\" onclick=\"clearCache()\">Clear</button>
    </label>
  </div>

  <div class=\"setting-item">
    <label class=\"setting-label\">
      <span>Export Chat History</span>
      <button class=\"secondary-btn\" onclick=\"exportData()\">Export</button>
    </label>
  </div>

  <div class=\"setting-item\">
    <label class=\"setting-label\">
      <span>Delete Account</span>
      <button class=\"danger-btn\" onclick=\"deleteAccount()\">Delete</button>
    </label>
  </div>

  <div class=\"setting-item info\">
    <div class=\"info-label\">cl-telegram Version</div>
    <div class=\"info-value\">v0.24.0</div>
  </div>

  <div class=\"setting-item info\">
    <div class=\"info-label\">Build</div>
    <div class=\"info-value\">~A</div>
  </div>
</section>"
            (eq auto-download :wifi)
            (eq auto-download :always)
            (eq auto-download :never)
            (= max-size 1048576)
            (= max-size 5242880)
            (= max-size 10485760)
            (= max-size 20971520)
            (= max-size 52428800)
            "2026-04-20")))

;;; ============================================================================
;;; JavaScript for Settings Panel
;;; ============================================================================

(defun generate-settings-javascript ()
  "Generate JavaScript for settings panel.

   Returns:
     JavaScript string"
  "
/**
 * Settings Panel Functions
 */

/**
 * Open settings panel
 */
function openSettingsPanel() {
  const overlay = document.createElement('div');
  overlay.className = 'settings-overlay';
  overlay.id = 'settings-overlay';
  overlay.onclick = (e) => {
    if (e.target === overlay) closeSettingsPanel();
  };

  const panel = document.createElement('div');
  panel.className = 'settings-panel';
  panel.innerHTML = window.settingsHtml || '<div>Loading...</div>';

  overlay.appendChild(panel);
  document.body.appendChild(overlay);

  // Initialize settings values
  initSettingsValues();
}

/**
 * Close settings panel
 */
function closeSettingsPanel() {
  const overlay = document.getElementById('settings-overlay');
  if (overlay) {
    overlay.remove();
  }
}

/**
 * Initialize settings values from backend
 */
function initSettingsValues() {
  if (window.clogEval) {
    window.clogEval('(cl-telegram/ui::get-settings-web *current-window*)');
  }
}

/**
 * Select theme
 * @param {string} theme - Theme name ('dark', 'light', 'auto')
 */
function selectTheme(theme) {
  // Update active state
  document.querySelectorAll('.theme-option').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.theme === theme);
  });

  // Apply theme
  if (theme === 'auto') {
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');
  } else {
    document.documentElement.setAttribute('data-theme', theme);
  }

  localStorage.setItem('cl-telegram-theme', theme);
}

/**
 * Save settings
 */
function saveSettings() {
  const settings = {
    username: document.getElementById('setting-username')?.value || '',
    displayName: document.getElementById('setting-display-name')?.value || '',
    bio: document.getElementById('setting-bio')?.value || '',
    theme: document.querySelector('.theme-option.active')?.dataset.theme || 'dark',
    language: document.getElementById('setting-language')?.value || 'en',
    fontSize: document.getElementById('setting-font-size')?.value || 16,
    notificationsEnabled: document.getElementById('setting-notifications-enabled')?.checked ?? true,
    notificationSound: document.getElementById('setting-notification-sound')?.checked ?? true,
    desktopNotifications: document.getElementById('setting-desktop-notifications')?.checked ?? true,
    messagePreview: document.getElementById('setting-message-preview')?.checked ?? true,
    privacyPhone: document.getElementById('setting-privacy-phone')?.value || 'contacts',
    privacyLastSeen: document.getElementById('setting-privacy-last-seen')?.value || 'everybody',
    privacyProfilePhoto: document.getElementById('setting-privacy-profile-photo')?.value || 'everybody',
    autoDownload: document.getElementById('setting-auto-download')?.value || 'wifi',
    maxSize: parseInt(document.getElementById('setting-max-size')?.value || '10485760', 10)
  };

  console.log('Saving settings:', settings);

  if (window.clogEval) {
    const settingsJson = JSON.stringify(settings);
    window.clogEval(`(cl-telegram/ui::save-settings-web *current-window* '${settingsJson})`);
  }

  // Show success message
  showNotification('Settings saved successfully!', 'success');

  // Close panel
  setTimeout(() => {
    closeSettingsPanel();
  }, 1000);
}

/**
 * Upload profile photo
 */
function uploadProfilePhoto() {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.onchange = (e) => {
    const file = e.target.files[0];
    if (file) {
      console.log('Uploading profile photo:', file.name);
      // Upload logic would go here
      showNotification('Profile photo upload not yet implemented', 'info');
    }
  };
  input.click();
}

/**
 * Setup two-factor authentication
 */
function setup2FA() {
  showNotification('Two-factor authentication setup coming soon', 'info');
}

/**
 * Show active sessions
 */
function showActiveSessions() {
  if (window.clogEval) {
    window.clogEval('(cl-telegram/ui::show-active-sessions-web *current-window*)');
  }
}

/**
 * Show blocked users
 */
function showBlockedUsers() {
  if (window.clogEval) {
    window.clogEval('(cl-telegram/ui::show-blocked-users-web *current-window*)');
  }
}

/**
 * Clear cache
 */
function clearCache() {
  if (confirm('Are you sure you want to clear the cache?')) {
    if (window.clogEval) {
      window.clogEval('(cl-telegram/ui::clear-cache-web *current-window*)');
    }
    showNotification('Cache cleared', 'success');
  }
}

/**
 * Export data
 */
function exportData() {
  showNotification('Export feature coming soon', 'info');
}

/**
 * Delete account
 */
function deleteAccount() {
  if (confirm('Are you sure you want to delete your account? This action cannot be undone.')) {
    if (window.clogEval) {
      window.clogEval('(cl-telegram/ui::delete-account-web *current-window*)');
    }
  }
}

/**
 * Show notification
 * @param {string} message - Notification message
 * @param {string} type - Notification type ('success', 'error', 'info')
 */
function showNotification(message, type = 'info') {
  const notification = document.createElement('div');
  notification.className = `toast toast-${type}`;
  notification.textContent = message;
  document.body.appendChild(notification);

  setTimeout(() => {
    notification.classList.add('toast-hide');
    setTimeout(() => notification.remove(), 300);
  }, 3000);
}
"))

;;; ============================================================================
;;; CLOG Integration
;;; ============================================================================

(defun render-settings-panel (win)
  "Render settings panel in CLOG window.

   Args:
     win: CLOG window object

   Returns:
     Panel element"
  (let ((settings-html (generate-settings-panel-html))
        (css (generate-settings-css)))

    ;; Add CSS
    (clog:append! (clog:head win)
                  (format nil "<style>~A</style>" css))

    ;; Add settings HTML
    (let ((overlay (clog:create-element win "div"
                                        :class "settings-overlay"
                                        :style "display: none;")))
      (clog:append! overlay
                    (clog:create-element win "div"
                                         :class "settings-panel"
                                         :inner-html settings-html))
      (clog:append! (clog:body win) overlay)

      ;; Add JavaScript
      (clog:run-script win (generate-settings-javascript))

      overlay)))

(defun show-settings-panel-web (win)
  "Show settings panel via web interface.

   Args:
     win: CLOG window object

   Returns:
     T on success"
  (clog:eval-in-window win
    '(progn
       (setf (clog:style (clog:get-element-by-id "settings-overlay")) "display: flex;")
       (init-settings-values)))
  t)

(defun get-settings-web (win)
  "Get settings for web interface.

   Args:
     win: CLOG window object

   Returns:
     JSON settings"
  (let ((settings (get-all-settings)))
    (clog:eval-in-window win
      `(progn
         ,@(loop for (key value) on settings by #'cddr
                 collect
                   (let ((element-id (format nil "setting-~A" (string-downcase key))))
                     `(when-let ((el (clog:get-element-by-id ,element-id)))
                        (case (clog:tag-name el)
                          (:input (setf (clog:value el) ,value))
                          (:select (setf (clog:value el) ,value))
                          (:textarea (setf (clog:value el) ,value))
                          (:checkbox (setf (clog:checked el) ,value))))))))
    t))

(defun save-settings-web (win settings-json)
  "Save settings from web interface.

   Args:
     win: CLOG window object
     settings-json: JSON string of settings

   Returns:
     T on success"
  (handler-case
      (let ((data (jonathan:json-read settings-json)))
        (maphash (lambda (key value)
                   (set-user-setting key value))
                 data)
        (save-settings-to-storage)
        (clog:eval-in-window win
          '(show-notification "Settings saved successfully!" "success")))
    (error (e)
      (clog:eval-in-window win
        `(show-notification ,(format nil "Error: ~A" e) "error"))))
  t)

;;; ============================================================================
;;; Settings CSS
;;; ============================================================================

(defun generate-settings-css ()
  "Generate CSS for settings panel.

   Returns:
     CSS string"
  "
/* Settings Panel */
.settings-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.7);
  z-index: 10000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.settings-panel {
  background: var(--bg-secondary);
  border-radius: var(--radius-lg);
  width: 100%;
  max-width: 600px;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.settings-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-lg);
  border-bottom: 1px solid var(--border);
}

.settings-header h3 {
  font-size: var(--font-size-lg);
  font-weight: 600;
  margin: 0;
}

.close-settings {
  background: transparent;
  border: none;
  color: var(--text-secondary);
  font-size: 24px;
  cursor: pointer;
  padding: var(--space-sm);
  line-height: 1;
}

.close-settings:hover {
  color: var(--text-primary);
}

.settings-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--space-lg);
}

.settings-section {
  margin-bottom: var(--space-xl);
}

.section-title {
  font-size: var(--font-size-md);
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: var(--space-md);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.setting-item {
  margin-bottom: var(--space-md);
  padding: var(--space-md);
  background: var(--bg-tertiary);
  border-radius: var(--radius-md);
}

.setting-label {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: var(--font-size-sm);
  font-weight: 500;
}

.setting-input,
.setting-select,
.setting-textarea {
  width: 100%;
  padding: var(--space-sm) var(--space-md);
  background: var(--bg-primary);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  color: var(--text-primary);
  font-size: var(--font-size-sm);
  margin-top: var(--space-sm);
}

.setting-input:focus,
.setting-select:focus,
.setting-textarea:focus {
  outline: none;
  border-color: var(--accent);
}

.setting-textarea {
  resize: vertical;
  font-family: inherit;
}

.setting-range {
  width: 100%;
  margin-top: var(--space-sm);
}

.range-labels {
  display: flex;
  justify-content: space-between;
  font-size: var(--font-size-xs);
  color: var(--text-secondary);
  margin-top: var(--space-xs);
}

/* Toggle Switch */
.toggle-switch {
  position: relative;
  width: 50px;
  height: 26px;
}

.toggle-switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.toggle-slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: var(--text-secondary);
  transition: 0.3s;
  border-radius: 26px;
}

.toggle-slider:before {
  position: absolute;
  content: \"\";
  height: 20px;
  width: 20px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: 0.3s;
  border-radius: 50%;
}

.toggle-switch input:checked + .toggle-slider {
  background-color: var(--accent);
}

.toggle-switch input:checked + .toggle-slider:before {
  transform: translateX(24px);
}

/* Theme Selector */
.theme-selector {
  display: flex;
  gap: var(--space-sm);
  margin-top: var(--space-sm);
}

.theme-option {
  flex: 1;
  padding: var(--space-md);
  background: var(--bg-primary);
  border: 2px solid var(--border);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: var(--font-size-sm);
  transition: all var(--transition-fast);
}

.theme-option:hover {
  border-color: var(--accent);
}

.theme-option.active {
  border-color: var(--accent);
  background: var(--accent);
  color: white;
}

/* Profile Photo Upload */
.profile-photo-upload {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  margin-top: var(--space-sm);
}

.upload-btn {
  background: var(--accent);
  border: none;
  color: white;
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: var(--font-size-sm);
}

.current-photo img {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  object-fit: cover;
}

/* Buttons */
.save-settings-btn {
  width: 100%;
  padding: var(--space-md);
  background: var(--accent);
  border: none;
  color: white;
  border-radius: var(--radius-md);
  font-size: var(--font-size-md);
  font-weight: 500;
  cursor: pointer;
}

.secondary-btn {
  background: var(--bg-tertiary);
  border: 1px solid var(--border);
  color: var(--text-primary);
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: var(--font-size-sm);
}

.danger-btn {
  background: #e74c3c;
  border: none;
  color: white;
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: var(--font-size-sm);
}

/* Info Items */
.setting-item.info {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.info-label {
  color: var(--text-secondary);
  font-size: var(--font-size-sm);
}

.info-value {
  color: var(--text-primary);
  font-size: var(--font-size-sm);
  font-weight: 500;
}

.settings-footer {
  padding: var(--space-lg);
  border-top: 1px solid var(--border);
}

/* Toast Notifications */
.toast {
  position: fixed;
  bottom: 20px;
  right: 20px;
  background: var(--bg-primary);
  color: var(--text-primary);
  padding: var(--space-md) var(--space-lg);
  border-radius: var(--radius-md);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  z-index: 10001;
  animation: slideIn 0.3s ease;
}

.toast-success {
  border-left: 4px solid #27ae60;
}

.toast-error {
  border-left: 4px solid #e74c3c;
}

.toast-info {
  border-left: 4px solid #3498db;
}

.toast-hide {
  animation: slideOut 0.3s ease forwards;
}

@keyframes slideIn {
  from {
    transform: translateX(100%);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

@keyframes slideOut {
  from {
    transform: translateX(0);
    opacity: 1;
  }
  to {
    transform: translateX(100%);
    opacity: 0;
  }
}

/* Responsive */
@media (max-width: 768px) {
  .settings-panel {
    max-width: 100%;
    max-height: 100vh;
    border-radius: 0;
  }

  .profile-photo-upload {
    flex-direction: column;
    align-items: flex-start;
  }
}
"))

;;; ============================================================================
;;; End of settings-panel.lisp
;;; ============================================================================
