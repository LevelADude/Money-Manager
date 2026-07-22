'use strict';

// Eigener Service-Worker.
//
// Warum selbst geschrieben: Flutter erzeugt seit Version 3.35 keinen
// cachenden Service-Worker mehr (flutter/flutter#156910). `--pwa-strategy`
// legt heute nur noch einen "Grabstein" an, der sich selbst wieder
// abmeldet. Wer Caching will, muss es selbst mitbringen — genau das hier.
//
// Ziel: die grossen, bei jedem Kaltstart erneut geladenen Brocken
// (main.dart.js ~5 MB, canvaskit.wasm ~7 MB, Schriften) lokal halten, ohne
// jemals einen veralteten Build festzuhalten. Das Festhalten alter Builds
// war der Grund, warum der Service-Worker urspruenglich abgeschaltet wurde.
//
// Der Trick dagegen ist der Build-Stempel im Cache-Namen:
//   * Jeder Deploy ersetzt __BUILD_ID__ durch die Commit-SHA.
//   * Neuer Build -> neuer Cache-Name -> alte Dateien werden verworfen und
//     genau einmal neu geladen. Ein "ewiger" Altstand ist damit unmoeglich.
//   * index.html laeuft zusaetzlich immer ueber das Netz (network-first),
//     damit ein neuer Build sofort bemerkt wird und nicht erst nach Ablauf
//     irgendeines Caches.

const BUILD = '__BUILD_ID__';
const CACHE = 'money-manager-' + BUILD;

self.addEventListener('install', (event) => {
  // Sofort uebernehmen statt auf das Schliessen aller Tabs zu warten —
  // sonst haengt die iOS-WebApp beliebig lange im alten Stand fest.
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Caches aller frueheren Builds loeschen.
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((n) => n.startsWith('money-manager-') && n !== CACHE)
          .map((n) => caches.delete(n)),
      );
      await self.clients.claim();
    })(),
  );
});

/// Immer frisch aus dem Netz holen: alles, was auf einen neuen Build
/// verweist. Nur so wird ein Update ueberhaupt bemerkt.
function alwaysFromNetwork(url) {
  return (
    url.pathname.endsWith('/') ||
    url.pathname.endsWith('index.html') ||
    url.pathname.endsWith('flutter_bootstrap.js') ||
    url.pathname.endsWith('version.json') ||
    url.pathname.endsWith('manifest.json')
  );
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  // Fremde Hosts (v. a. Supabase) gehen den Service-Worker nichts an —
  // Kontostaende duerfen niemals aus einem Cache kommen.
  if (url.origin !== self.location.origin) return;

  if (alwaysFromNetwork(url)) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res && res.ok) {
            const copy = res.clone();
            caches.open(CACHE).then((c) => c.put(req, copy));
          }
          return res;
        })
        // Offline: notfalls die letzte bekannte Fassung zeigen.
        .catch(() => caches.match(req).then((hit) => hit || Response.error())),
    );
    return;
  }

  // Alles Uebrige (main.dart.js, canvaskit/*, Schriften, Icons): erst Cache,
  // sonst Netz. Der Build-Stempel im Cache-Namen sorgt dafuer, dass das je
  // Build genau einmal ueber die Leitung geht.
  event.respondWith(
    caches.match(req).then((hit) => {
      if (hit) return hit;
      return fetch(req).then((res) => {
        if (res && res.ok && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      });
    }),
  );
});
