/* 런던 여행 오프라인 캐시 서비스워커
   - 앱 셸(index.html) + 아이콘 + 모든 예약 바우처를 미리 캐시
   - 오프라인(기내 등)에서도 홈 화면 아이콘으로 열림
   - 앱 내용을 바꿔 재배포하면 VERSION 이 자동으로 올라가 사용자 기기가 다시 캐시함
   - 바우처 목록은 vouchers-precache.js 에서 불러옴 (배포 스크립트가 vouchers/ 폴더로 자동 생성) */
const VERSION = 'london-2026-v3';

// 배포 스크립트가 만드는 바우처 파일명 목록(원본 이름). 없거나 실패하면 빈 목록.
try { importScripts('vouchers-precache.js'); } catch (e) { self.VOUCHER_FILES = []; }

// 앱이 vouchers/ 를 encodeURIComponent 로 요청하므로 여기서도 동일하게 인코딩
const SHELL = [
  './',
  'index.html',
  'manifest.webmanifest',
  'vouchers-precache.js',
  'favicon-192.png',
  'apple-touch-icon.png'
];
const PRECACHE = SHELL.concat((self.VOUCHER_FILES || []).map(function (f) {
  return 'vouchers/' + encodeURIComponent(f);
}));

self.addEventListener('install', (e) => {
  e.waitUntil((async () => {
    const c = await caches.open(VERSION);
    // 일부 파일이 실패해도 설치는 계속되도록 allSettled 사용
    await Promise.allSettled(PRECACHE.map((u) => c.add(new Request(u, { cache: 'reload' }))));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // 페이지(내비게이션) 요청: 온라인이면 최신, 오프라인이면 캐시된 index.html
  if (req.mode === 'navigate') {
    e.respondWith((async () => {
      const c = await caches.open(VERSION);
      try {
        const net = await fetch(req);
        c.put('index.html', net.clone());
        return net;
      } catch (_) {
        return (await c.match('index.html')) || (await c.match('./')) || (await c.match(req)) || Response.error();
      }
    })());
    return;
  }

  // 같은 출처(앱 자원·바우처): 캐시 우선, 없으면 네트워크 후 캐시 저장
  if (url.origin === self.location.origin) {
    e.respondWith((async () => {
      const c = await caches.open(VERSION);
      const hit = await c.match(req);
      if (hit) return hit;
      try {
        const net = await fetch(req);
        if (net && net.ok) c.put(req, net.clone());
        return net;
      } catch (_) {
        return hit || Response.error();
      }
    })());
    return;
  }

  // 외부 출처(폰트 등): 캐시 우선, 온라인일 때 기회적으로 저장 (오프라인이면 무시)
  e.respondWith((async () => {
    const c = await caches.open(VERSION);
    const hit = await c.match(req);
    if (hit) return hit;
    try {
      const net = await fetch(req);
      if (net && (net.ok || net.type === 'opaque')) c.put(req, net.clone());
      return net;
    } catch (_) {
      return hit || Response.error();
    }
  })());
});
