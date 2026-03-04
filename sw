// PeakDone Service Worker — offline support
const CACHE = 'peakdone-v1';

const STATIC = [
  '/',
  '/index.html',
  'https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,600;1,400&family=Inter:wght@300;400;500&display=swap',
  'https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hiJ-Ek-_EeA.woff2',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
  'https://unpkg.com/@supabase/supabase-js@2/dist/umd/supabase.js',
];

// Tile domains to cache on the fly
const TILE_ORIGINS = [
  'tile.opentopomap.org',
  'arcgisonline.com',
  'tile.openstreetmap.fr',
  'tile.openstreetmap.org',
];

// ── Install: cache static assets ──────────────────────
self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE).then(cache =>
      Promise.allSettled(STATIC.map(url => cache.add(url)))
    )
  );
});

// ── Activate: clean old caches ────────────────────────
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// ── Fetch: serve from cache, fallback to network ──────
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);

  // Skip Supabase API calls — always need network for auth/data
  if (url.hostname.includes('supabase.co')) return;

  // Map tiles — cache as they load, serve cached when offline
  const isTile = TILE_ORIGINS.some(o => url.hostname.includes(o));
  if (isTile) {
    e.respondWith(
      caches.open(CACHE).then(async cache => {
        const cached = await cache.match(e.request);
        if (cached) return cached;
        try {
          const res = await fetch(e.request);
          if (res.ok) cache.put(e.request, res.clone());
          return res;
        } catch {
          return cached || new Response('', { status: 503 });
        }
      })
    );
    return;
  }

  // Static assets — cache first
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(res => {
        if (res.ok) {
          caches.open(CACHE).then(c => c.put(e.request, res.clone()));
        }
        return res;
      }).catch(() => caches.match('/index.html'));
    })
  );
});
