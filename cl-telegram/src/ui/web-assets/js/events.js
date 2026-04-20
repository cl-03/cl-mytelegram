/**
 * cl-telegram Web UI - Event Handlers
 * Version: 0.24.0
 *
 * JavaScript event handlers for the CLOG-based web interface
 */

/* ============================================================================
 * Chat List Events
 * ============================================================================ */

/**
 * Initialize chat list interactions
 */
function initChatList() {
  const chatList = document.getElementById('chat-list');

  if (!chatList) {
    console.error('Chat list element not found');
    return;
  }

  // Delegate click events for chat items
  chatList.addEventListener('click', (e) => {
    const chatItem = e.target.closest('.chat-item');

    if (chatItem) {
      const chatId = chatItem.dataset.chatId;

      if (chatId) {
        selectChat(chatId);

        // Update active state
        document.querySelectorAll('.chat-item').forEach(item => {
          item.classList.remove('active');
        });
        chatItem.classList.add('active');

        // On mobile, close sidebar after selection
        if (window.innerWidth <= 768) {
          closeSidebar();
        }
      }
    }
  });

  // Infinite scroll for chat list
  chatList.addEventListener('scroll', (e) => {
    const target = e.target;
    const scrollTop = target.scrollTop;
    const scrollHeight = target.scrollHeight;
    const clientHeight = target.clientHeight;

    // Load more when near bottom (within 100px)
    if (scrollTop + clientHeight >= scrollHeight - 100) {
      loadMoreChats();
    }
  });
}

/**
 * Select a chat to view
 * @param {string} chatId - Chat identifier
 */
function selectChat(chatId) {
  console.log('Selecting chat:', chatId);

  // Send to Lisp backend via CLOG
  if (window.clogEval) {
    window.clogEval(`(cl-telegram/ui::select-chat-web *current-window* "${chatId}")`);
  }

  // Update UI state
  window.currentChatId = chatId;

  // Load messages for this chat
  loadMessages(chatId);
}

/**
 * Load more chats (infinite scroll)
 */
function loadMoreChats() {
  console.log('Loading more chats...');

  // Debounce to prevent multiple rapid loads
  if (window.loadingChats) return;
  window.loadingChats = true;

  // Request more chats from backend
  if (window.clogEval) {
    window.clogEval('(cl-telegram/ui::load-more-chats *current-window*)');
  }

  setTimeout(() => {
    window.loadingChats = false;
  }, 500);
}

/**
 * Load messages for a chat
 * @param {string} chatId - Chat identifier
 */
function loadMessages(chatId) {
  console.log('Loading messages for chat:', chatId);

  const messagesContainer = document.getElementById('messages-container');

  if (messagesContainer) {
    messagesContainer.innerHTML = '<div class="loading">Loading messages...</div>';
  }

  // Request messages from backend
  if (window.clogEval) {
    window.clogEval(`(cl-telegram/ui::load-messages-web *current-window* "${chatId}")`);
  }
}

/* ============================================================================
 * Message Input Events
 * ============================================================================ */

/**
 * Initialize message input handlers
 */
function initMessageInput() {
  const messageInput = document.getElementById('message-input');
  const sendButton = document.getElementById('send-button');

  if (!messageInput || !sendButton) {
    console.error('Message input or send button not found');
    return;
  }

  // Auto-resize textarea
  messageInput.addEventListener('input', function() {
    this.style.height = 'auto';
    this.style.height = Math.min(this.scrollHeight, 120) + 'px';
  });

  // Send on Enter (Shift+Enter for new line)
  messageInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  // Send button click
  sendButton.addEventListener('click', () => {
    sendMessage();
    messageInput.focus();
  });

  // Typing indicator
  let typingTimeout;
  messageInput.addEventListener('input', () => {
    // Send typing indicator
    if (window.currentChatId) {
      sendTypingIndicator(window.currentChatId);
    }

    // Clear previous timeout
    clearTimeout(typingTimeout);

    // Stop typing after 2 seconds
    typingTimeout = setTimeout(() => {
      stopTypingIndicator();
    }, 2000);
  });
}

/**
 * Send message from input
 */
function sendMessage() {
  const messageInput = document.getElementById('message-input');

  if (!messageInput) return;

  const text = messageInput.value.trim();

  if (!text) return;

  console.log('Sending message:', text);

  // Send to backend
  if (window.clogEval && window.currentChatId) {
    window.clogEval(`(cl-telegram/api:send-message "${window.currentChatId}" "${escapeString(text)}")`);
  }

  // Clear input
  messageInput.value = '';
  messageInput.style.height = 'auto';

  // Scroll to bottom
  scrollToBottom();
}

/**
 * Send typing indicator
 * @param {string} chatId - Chat identifier
 */
function sendTypingIndicator(chatId) {
  if (window.clogEval) {
    window.clogEval(`(cl-telegram/api:send-typing "${chatId}")`);
  }
}

/**
 * Stop typing indicator
 */
function stopTypingIndicator() {
  if (window.clogEval && window.currentChatId) {
    window.clogEval(`(cl-telegram/api:stop-typing "${window.currentChatId}")`);
  }
}

/**
 * Scroll messages to bottom
 */
function scrollToBottom() {
  const messagesContainer = document.getElementById('messages-container');

  if (messagesContainer) {
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }
}

/* ============================================================================
 * Search Functionality
 * ============================================================================ */

/**
 * Initialize search box
 */
function initSearch() {
  const searchInput = document.querySelector('.search-input');

  if (!searchInput) return;

  // Debounced search
  let searchTimeout;

  searchInput.addEventListener('input', (e) => {
    clearTimeout(searchTimeout);

    const query = e.target.value.trim();

    searchTimeout = setTimeout(() => {
      filterChatList(query);
    }, 300);
  });

  // Focus with Ctrl+K
  document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.key === 'k') {
      e.preventDefault();
      searchInput.focus();
    }
  });
}

/**
 * Filter chat list by search query
 * @param {string} query - Search query
 */
function filterChatList(query) {
  console.log('Filtering chat list:', query);

  const chatItems = document.querySelectorAll('.chat-item');

  chatItems.forEach((item) => {
    const nameElement = item.querySelector('.chat-name');
    const name = nameElement ? nameElement.textContent.toLowerCase() : '';

    if (query === '' || name.includes(query.toLowerCase())) {
      item.style.display = 'flex';
    } else {
      item.style.display = 'none';
    }
  });
}

/* ============================================================================
 * Mobile Navigation
 * ============================================================================ */

/**
 * Initialize mobile navigation
 */
function initMobileNav() {
  const hamburger = document.querySelector('.hamburger');
  const sidebar = document.querySelector('.sidebar');
  const overlay = document.querySelector('.sidebar-overlay');

  if (hamburger) {
    hamburger.addEventListener('click', () => {
      toggleSidebar();
    });
  }

  if (overlay) {
    overlay.addEventListener('click', () => {
      closeSidebar();
    });
  }

  // Handle window resize
  window.addEventListener('resize', () => {
    if (window.innerWidth > 768) {
      closeSidebar();
    }
  });
}

/**
 * Toggle sidebar visibility
 */
function toggleSidebar() {
  const sidebar = document.querySelector('.sidebar');
  const overlay = document.querySelector('.sidebar-overlay');
  const hamburger = document.querySelector('.hamburger');

  if (sidebar) {
    sidebar.classList.toggle('open');
  }

  if (overlay) {
    overlay.classList.toggle('visible');
  }

  if (hamburger) {
    hamburger.classList.toggle('active');
  }
}

/**
 * Close sidebar
 */
function closeSidebar() {
  const sidebar = document.querySelector('.sidebar');
  const overlay = document.querySelector('.sidebar-overlay');
  const hamburger = document.querySelector('.hamburger');

  if (sidebar) {
    sidebar.classList.remove('open');
  }

  if (overlay) {
    overlay.classList.remove('visible');
  }

  if (hamburger) {
    hamburger.classList.remove('active');
  }
}

/* ============================================================================
 * Media Viewer
 * ============================================================================ */

/**
 * Initialize media viewer
 */
function initMediaViewer() {
  // Delegate clicks on media thumbnails
  document.addEventListener('click', (e) => {
    const thumbnail = e.target.closest('.message-media-thumbnail');

    if (thumbnail) {
      const fileId = thumbnail.dataset.fileId;
      const mediaType = thumbnail.dataset.mediaType;

      if (fileId) {
        openMediaViewer(fileId, mediaType);
      }
    }

    // Close media viewer on overlay click
    if (e.target.classList.contains('media-gallery-overlay')) {
      closeMediaViewer();
    }

    // Close on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closeMediaViewer();
      }
    });
  });
}

/**
 * Open media viewer
 * @param {string} fileId - File identifier
 * @param {string} mediaType - Media type (photo, video, etc.)
 */
function openMediaViewer(fileId, mediaType) {
  console.log('Opening media viewer:', fileId, mediaType);

  if (window.clogEval) {
    window.clogEval(`(cl-telegram/ui::open-media-viewer-web *current-window* "${fileId}" "${mediaType}")`);
  }
}

/**
 * Close media viewer
 */
function closeMediaViewer() {
  const overlay = document.querySelector('.media-gallery-overlay');

  if (overlay) {
    overlay.remove();
  }
}

/* ============================================================================
 * Theme Switching
 * ============================================================================ */

/**
 * Initialize theme
 */
function initTheme() {
  // Check for saved theme preference
  const savedTheme = localStorage.getItem('cl-telegram-theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

  const theme = savedTheme || (prefersDark ? 'dark' : 'light');
  setTheme(theme);

  // Listen for system theme changes
  window.matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', (e) => {
      if (!localStorage.getItem('cl-telegram-theme')) {
        setTheme(e.matches ? 'dark' : 'light');
      }
    });
}

/**
 * Set theme
 * @param {string} theme - 'dark' or 'light'
 */
function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('cl-telegram-theme', theme);

  // Update theme switcher button if exists
  const themeSwitcher = document.querySelector('.theme-switcher');

  if (themeSwitcher) {
    themeSwitcher.textContent = theme === 'dark' ? '☀️ Light' : '🌙 Dark';
  }
}

/**
 * Toggle theme
 */
function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
  setTheme(newTheme);
}

/* ============================================================================
 * Keyboard Shortcuts
 * ============================================================================ */

/**
 * Initialize keyboard shortcuts
 */
function initKeyboardShortcuts() {
  document.addEventListener('keydown', (e) => {
    // Ctrl+R: Refresh
    if (e.ctrlKey && e.key === 'r') {
      e.preventDefault();
      location.reload();
    }

    // Ctrl+K: Focus search (handled in initSearch)

    // Ctrl+N: New message/chat
    if (e.ctrlKey && e.key === 'n') {
      e.preventDefault();
      // Open new chat dialog
      console.log('New chat shortcut triggered');
    }

    // Ctrl+,: Open settings
    if (e.ctrlKey && e.key === ',') {
      e.preventDefault();
      console.log('Settings shortcut triggered');
    }

    // Escape: Close modals/sidebars
    if (e.key === 'Escape') {
      closeSidebar();
      closeMediaViewer();
    }
  });
}

/* ============================================================================
 * Utilities
 * ============================================================================ */

/**
 * Escape string for safe use in Lisp code
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
function escapeString(str) {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r');
}

/**
 * Format timestamp for display
 * @param {number} timestamp - Unix timestamp
 * @returns {string} Formatted time string
 */
function formatTime(timestamp) {
  if (!timestamp) return '';

  const date = new Date(timestamp * 1000);
  const now = new Date();

  // Today: Show time
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  // Yesterday
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);

  if (date.toDateString() === yesterday.toDateString()) {
    return 'Yesterday';
  }

  // This week: Show day name
  if (now.getTime() - date.getTime() < 7 * 24 * 60 * 60 * 1000) {
    return date.toLocaleDateString([], { weekday: 'short' });
  }

  // Older: Show date
  return date.toLocaleDateString();
}

/**
 * Format file size for display
 * @param {number} bytes - File size in bytes
 * @returns {string} Formatted size string
 */
function formatFileSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
}

/* ============================================================================
 * Initialization
 * ============================================================================ */

/**
 * Initialize all event handlers
 */
function init() {
  console.log('Initializing cl-telegram web UI...');

  initChatList();
  initMessageInput();
  initSearch();
  initMobileNav();
  initMediaViewer();
  initTheme();
  initKeyboardShortcuts();

  // Set up global state
  window.currentChatId = null;
  window.clogEval = window.clogEval || function(code) {
    console.log('CLOG eval (mock):', code);
  };

  console.log('cl-telegram web UI initialized');
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}

// Register Service Worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then((registration) => {
        console.log('SW registered:', registration.scope);
      })
      .catch((error) => {
        console.error('SW registration failed:', error);
      });
  });
}
