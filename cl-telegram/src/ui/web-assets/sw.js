/* cl-telegram Service Worker */
/* Version: 0.24.0 */

const CACHE_NAME = 'cl-telegram-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/styles/main.css',
  '/styles/mobile.css',
  '/js/app.js',
  '/js/events.js',
  '/manifest.json'
];

/* ============================================================================
   Install Event - Cache static assets
   ============================================================================ */

self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('[SW] Installation complete, skipping waiting');
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('[SW] Cache installation failed:', error);
      })
  );
});

/* ============================================================================
   Activate Event - Clean old caches
   ============================================================================ */

self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name !== CACHE_NAME)
            .map((name) => {
              console.log('[SW] Deleting old cache:', name);
              return caches.delete(name);
            })
        );
      })
      .then(() => {
        console.log('[SW] Activation complete, claiming clients');
        return self.clients.claim();
      })
  );
});

/* ============================================================================
   Fetch Event - Network first, fallback to cache
   ============================================================================ */

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip cross-origin requests
  if (url.origin !== location.origin) {
    return;
  }

  // API requests - network only
  if (request.url.includes('/api/') || request.url.includes('/ws')) {
    event.respondWith(
      fetch(request)
        .catch((error) => {
          console.error('[SW] API fetch failed:', error);
          return new Response(
            JSON.stringify({ error: 'Offline', message: 'No network connection' }),
            {
              status: 503,
              headers: { 'Content-Type': 'application/json' }
            }
          );
        })
    );
    return;
  }

  // Static assets - network first, fallback to cache
  event.respondWith(
    fetch(request)
      .then((response) => {
        // Clone the response for caching
        const responseClone = response.clone();

        // Cache successful responses
        if (response.ok) {
          caches.open(CACHE_NAME)
            .then((cache) => {
              cache.put(request, responseClone);
            });
        }

        return response;
      })
      .catch((error) => {
        console.log('[SW] Fetch failed, trying cache:', request.url);

        return caches.match(request)
          .then((cachedResponse) => {
            if (cachedResponse) {
              console.log('[SW] Serving from cache:', request.url);
              return cachedResponse;
            }

            // Fallback to offline page for navigation requests
            if (request.mode === 'navigate') {
              return caches.match('/index.html');
            }

            console.log('[SW] No cached response for:', request.url);
            return new Response('Offline', { status: 503 });
          });
      })
  );
});

/* ============================================================================
   Push Notification Event
   ============================================================================ */

self.addEventListener('push', (event) => {
  console.log('[SW] Push notification received');

  let data = {};

  try {
    data = event.data ? event.data.json() : {};
  } catch (error) {
    console.error('[SW] Error parsing push data:', error);
    data = { title: 'New Message', body: 'You have a new message' };
  }

  const title = data.title || 'cl-telegram';
  const options = {
    body: data.body || 'New notification',
    icon: '/icons/icon-192x192.png',
    badge: '/icons/icon-72x72.png',
    data: {
      chatId: data.chat_id,
      messageId: data.message_id,
      url: data.url || '/'
    },
    tag: data.tag || 'cl-telegram-message',
    requireInteraction: data.require_interaction || false,
    actions: [
      { action: 'open', title: 'Open' },
      { action: 'mark-read', title: 'Mark as Read' }
    ],
    silent: data.silent || false,
    vibrate: data.vibrate || [100, 50, 100],
    timestamp: data.timestamp ? new Date(data.timestamp).getTime() : Date.now()
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

/* ============================================================================
   Notification Click Event
   ============================================================================ */

self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event.action);

  event.notification.close();

  if (event.action === 'mark-read') {
    // Mark as read action
    event.waitUntil(
      fetch('/api/mark-read', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: event.notification.data.chatId,
          message_id: event.notification.data.messageId
        })
      })
    );
  } else {
    // Open action (default)
    event.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true })
        .then((windowClients) => {
          // Check if there's already a window open
          for (let client of windowClients) {
            if (client.url === event.notification.data.url && 'focus' in client) {
              return client.focus();
            }
          }

          // Open new window
          if (clients.openWindow) {
            return clients.openWindow(event.notification.data.url);
          }
        })
    );
  }
});

/* ============================================================================
   Message from Client (Web App)
   ============================================================================ */

self.addEventListener('message', (event) => {
  console.log('[SW] Message from client:', event.data);

  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(CACHE_NAME)
        .then((cache) => cache.addAll(event.data.urls))
    );
  }

  if (event.data && event.data.type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.keys()
        .then((cacheNames) => Promise.all(
          cacheNames.map((name) => caches.delete(name))
        ))
        .then(() => self.registration.unregister())
    );
  }
});

/* ============================================================================
   Background Sync (for offline message queue)
   ============================================================================ */

self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync triggered:', event.tag);

  if (event.tag === 'sync-messages') {
    event.waitUntil(
      // Get pending messages from IndexedDB and send them
      syncPendingMessages()
    );
  }
});

async function syncPendingMessages() {
  // This would integrate with IndexedDB for offline message queue
  console.log('[SW] Syncing pending messages...');

  // Placeholder - actual implementation would:
  // 1. Open IndexedDB
  // 2. Get pending messages
  // 3. Send to server via fetch
  // 4. Remove successfully sent messages
}

/* ============================================================================
   Periodic Background Sync (for message pre-fetching)
   ============================================================================ */

self.addEventListener('periodicsync', (event) => {
  console.log('[SW] Periodic sync triggered:', event.tag);

  if (event.tag === 'fetch-latest-messages') {
    event.waitUntil(
      fetchLatestMessages()
    );
  }
});

async function fetchLatestMessages() {
  // Pre-fetch latest messages in background
  console.log('[SW] Fetching latest messages in background...');

  // Placeholder - actual implementation would:
  // 1. Call API to get latest messages
  // 2. Cache the responses
  // 3. Optionally notify the client
}

console.log('[SW] Service worker loaded');
