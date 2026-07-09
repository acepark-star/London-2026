/* 런던 여행 오프라인 캐시 서비스워커
   - 앱 셸(index.html) + 아이콘 + 모든 예약 바우처를 미리 캐시
   - 오프라인(기내 등)에서도 홈 화면 아이콘으로 열림
   - 앱 내용을 바꿔 재배포하면 아래 VERSION 숫자만 올리면 갱신됨 */
const VERSION = 'london-2026-v1';

const PRECACHE = [
  './',
  'index.html',
  'manifest.webmanifest',
  'favicon-192.png',
  'apple-touch-icon.png',
  'vouchers/E-receipt.pdf',
  'vouchers/ETA_Kim%20Soojin.jpeg',
  'vouchers/ETA_Park%20Yongjun.jpeg',
  'vouchers/ETKT_KIMSOOJINMS.pdf',
  'vouchers/ETKT_PARKYONGJUNMR.pdf',
  'vouchers/GWR_1_LON-BTH_1.pdf',
  'vouchers/GWR_1_LON-BTH_2.pdf',
  'vouchers/GWR_2_BTH-LON_1%202.pdf',
  'vouchers/GWR_2_BTH-LON_2.pdf',
  'vouchers/kakaopayinscorp-20260603232946.pdf',
  'vouchers/reservation_Bounce.jpeg',
  'vouchers/ticket_natural_history.pdf',
  'vouchers/ticket_paddington.pdf',
  'vouchers/voucher_Bounce.jpeg',
  'vouchers/voucher_Crown%20%26%20Anchor.pdf',
  'vouchers/voucher_Ham_Yard_Hotel.pdf',
  'vouchers/voucher_hotel_strand.pdf',
  'vouchers/voucher_hyde_park_garden.pdf',
  'vouchers/voucher_mr_foggs.pdf',
  'vouchers/voucher_national_gallery.pdf',
  'vouchers/voucher_natural_history.pdf',
  'vouchers/voucher_promenade.pdf',
  'vouchers/voucher_st_pauls.pdf',
  'vouchers/voucher_tate_modern.pdf',
  'vouchers/voucher_westminster.pdf'
];

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
