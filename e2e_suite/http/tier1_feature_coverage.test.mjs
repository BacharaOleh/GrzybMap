import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {
  DEFAULT_WEB_DIR,
  DEFAULT_LESNIK_PATH,
  DEFAULT_REPORTS_FILE,
  ROOT_SERVER_PATH,
  MUSHROOM_ASSETS_DIR,
  startServer,
  httpRequest,
  decompressBody,
  backupReportsJson,
  restoreReportsJson
} from '../lib/server_harness.mjs';

describe('Tier 1 — Feature Coverage (F1–F7)', () => {
  let srv;

  before(async () => {
    srv = await startServer();
  });

  after(async () => {
    if (srv) await srv.stop();
  });

  // =========================================================================
  // F1: HTTP Compression & Content Negotiation
  // =========================================================================
  describe('F1: HTTP Compression & Content Negotiation', () => {
    it('F1.1 negotiates Brotli (br) on /main.dart.js with Vary: Accept-Encoding', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'br, gzip, deflate' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], 'br');
      assert.match(String(res.headers['vary'] || ''), /Accept-Encoding/i);
      assert.ok(res.rawBody.length < diskBuf.length, 'compressed wire bytes should be smaller than raw');
      const decompressed = decompressBody(res.rawBody, res.headers['content-encoding']);
      assert.equal(Buffer.compare(decompressed, diskBuf), 0);
    });

    it('F1.2 negotiates gzip on /main.dart.js when client accepts gzip only', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'gzip' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], 'gzip');
      assert.match(String(res.headers['vary'] || ''), /Accept-Encoding/i);
      const decompressed = decompressBody(res.rawBody, res.headers['content-encoding']);
      assert.equal(Buffer.compare(decompressed, diskBuf), 0);
    });

    it('F1.3 compresses /lesnik.html with br/gzip and matches disk bytes after decompression', async () => {
      const diskBuf = fs.readFileSync(DEFAULT_LESNIK_PATH);
      const res = await httpRequest(srv.baseUrl, '/lesnik.html', {
        headers: { 'Accept-Encoding': 'br, gzip' }
      });
      assert.equal(res.status, 200);
      assert.ok(['br', 'gzip'].includes(res.headers['content-encoding']));
      assert.match(String(res.headers['vary'] || ''), /Accept-Encoding/i);
      const decompressed = decompressBody(res.rawBody, res.headers['content-encoding']);
      assert.equal(Buffer.compare(decompressed, diskBuf), 0);
    });

    it('F1.4 compresses /api/reports JSON response when >= 256 bytes', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports', {
        headers: { 'Accept-Encoding': 'br, gzip' }
      });
      assert.equal(res.status, 200);
      assert.match(String(res.headers['content-type']), /application\/json/i);
      assert.ok(['br', 'gzip'].includes(res.headers['content-encoding']));
      assert.match(String(res.headers['vary'] || ''), /Accept-Encoding/i);
      const decompressed = decompressBody(res.rawBody, res.headers['content-encoding']);
      const parsed = JSON.parse(decompressed.toString('utf8'));
      assert.ok(Array.isArray(parsed));
      assert.ok(parsed.length >= 4);
    });

    it('F1.5 serves uncompressed identity HTML on / when Accept-Encoding is omitted', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'index.html'));
      const res = await httpRequest(srv.baseUrl, '/');
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], undefined);
      assert.equal(Buffer.compare(res.rawBody, diskBuf), 0);
    });

    it('F1.6 compresses /canvaskit/canvaskit.wasm with br', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'canvaskit', 'canvaskit.wasm'));
      const res = await httpRequest(srv.baseUrl, '/canvaskit/canvaskit.wasm', {
        headers: { 'Accept-Encoding': 'br, gzip' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-type'], 'application/wasm');
      assert.equal(res.headers['content-encoding'], 'br');
      assert.ok(res.rawBody.length < diskBuf.length);
      const decompressed = decompressBody(res.rawBody, 'br');
      assert.equal(Buffer.compare(decompressed, diskBuf), 0);
    });
  });

  // =========================================================================
  // F2: HTTP Caching (ETag, 304, Cache-Control)
  // =========================================================================
  describe('F2: HTTP Caching (ETag, 304, Cache-Control)', () => {
    it('F2.1 returns ETag and Cache-Control: no-cache on / and /lesnik', async () => {
      for (const route of ['/', '/lesnik']) {
        const res = await httpRequest(srv.baseUrl, route);
        assert.equal(res.status, 200);
        assert.ok(res.headers['etag'], `${route} must include ETag`);
        assert.match(String(res.headers['cache-control']), /no-cache/i);
      }
    });

    it('F2.2 returns ETag and Cache-Control: no-cache on entry/mutable web files', async () => {
      for (const route of ['/main.dart.js', '/flutter_bootstrap.js', '/manifest.json']) {
        const res = await httpRequest(srv.baseUrl, route);
        assert.equal(res.status, 200);
        assert.ok(res.headers['etag'], `${route} must include ETag`);
        assert.match(String(res.headers['cache-control']), /no-cache/i);
      }
    });

    it('F2.3 returns ETag and long-lived public max-age Cache-Control on static canvaskit/mushroom assets', async () => {
      for (const route of ['/canvaskit/canvaskit.wasm', '/assets/assets/mushrooms/borowik_szlachetny.webp']) {
        const res = await httpRequest(srv.baseUrl, route);
        assert.equal(res.status, 200);
        assert.ok(res.headers['etag'], `${route} must include ETag`);
        const cc = String(res.headers['cache-control'] || '');
        assert.match(cc, /public/i);
        const match = /max-age=(\d+)/i.exec(cc);
        assert.ok(match && Number(match[1]) >= 86400, `${route} expected max-age >= 86400, got ${cc}`);
      }
    });

    it('F2.4 returns 304 Not Modified with zero body when If-None-Match matches /lesnik ETag', async () => {
      const first = await httpRequest(srv.baseUrl, '/lesnik', {
        headers: { 'Accept-Encoding': 'br' }
      });
      assert.equal(first.status, 200);
      assert.ok(first.headers['etag']);

      const second = await httpRequest(srv.baseUrl, '/lesnik', {
        headers: {
          'Accept-Encoding': 'br',
          'If-None-Match': first.headers['etag']
        }
      });
      assert.equal(second.status, 304);
      assert.equal(second.rawBody.length, 0);
      assert.equal(second.headers['etag'], first.headers['etag']);
    });

    it('F2.5 returns ETag and Cache-Control: no-cache on /api/reports and 304 on If-None-Match', async () => {
      const first = await httpRequest(srv.baseUrl, '/api/reports', {
        headers: { 'Accept-Encoding': 'gzip' }
      });
      assert.equal(first.status, 200);
      assert.ok(first.headers['etag']);
      assert.match(String(first.headers['cache-control']), /no-cache/i);

      const second = await httpRequest(srv.baseUrl, '/api/reports', {
        headers: {
          'Accept-Encoding': 'gzip',
          'If-None-Match': first.headers['etag']
        }
      });
      assert.equal(second.status, 304);
      assert.equal(second.rawBody.length, 0);
    });
  });

  // =========================================================================
  // F3: Range (206) & HEAD Requests
  // =========================================================================
  describe('F3: Range (206) & HEAD Requests', () => {
    it('F3.1 serves 206 Partial Content for byte range on /main.dart.js', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { Range: 'bytes=0-63' }
      });
      assert.equal(res.status, 206);
      assert.equal(res.headers['accept-ranges'], 'bytes');
      assert.equal(res.headers['content-range'], `bytes 0-63/${diskBuf.length}`);
      assert.equal(res.headers['content-length'], '64');
      assert.equal(Buffer.compare(res.rawBody, diskBuf.subarray(0, 64)), 0);
    });

    it('F3.2 serves mid-file 206 Partial Content on /canvaskit/canvaskit.wasm', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'canvaskit', 'canvaskit.wasm'));
      const res = await httpRequest(srv.baseUrl, '/canvaskit/canvaskit.wasm', {
        headers: { Range: 'bytes=100-227' }
      });
      assert.equal(res.status, 206);
      assert.equal(res.headers['content-range'], `bytes 100-227/${diskBuf.length}`);
      assert.equal(res.rawBody.length, 128);
      assert.equal(Buffer.compare(res.rawBody, diskBuf.subarray(100, 228)), 0);
    });

    it('F3.3 serves suffix byte range (bytes=-32) on /main.dart.js', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { Range: 'bytes=-32' }
      });
      assert.equal(res.status, 206);
      assert.equal(
        res.headers['content-range'],
        `bytes ${diskBuf.length - 32}-${diskBuf.length - 1}/${diskBuf.length}`
      );
      assert.equal(Buffer.compare(res.rawBody, diskBuf.subarray(diskBuf.length - 32)), 0);
    });

    it('F3.4 HEAD / returns 200 with zero body and matching headers', async () => {
      const getRes = await httpRequest(srv.baseUrl, '/');
      const headRes = await httpRequest(srv.baseUrl, '/', { method: 'HEAD' });
      assert.equal(headRes.status, 200);
      assert.equal(headRes.rawBody.length, 0);
      assert.equal(headRes.headers['content-type'], getRes.headers['content-type']);
      assert.equal(headRes.headers['etag'], getRes.headers['etag']);
      assert.equal(headRes.headers['cache-control'], getRes.headers['cache-control']);
    });

    it('F3.5 HEAD /api/reports and HEAD /lesnik return 200 with zero body and matching ETag', async () => {
      for (const route of ['/api/reports', '/lesnik']) {
        const getRes = await httpRequest(srv.baseUrl, route, {
          headers: { 'Accept-Encoding': 'gzip' }
        });
        const headRes = await httpRequest(srv.baseUrl, route, {
          method: 'HEAD',
          headers: { 'Accept-Encoding': 'gzip' }
        });
        assert.equal(headRes.status, 200);
        assert.equal(headRes.rawBody.length, 0);
        assert.equal(headRes.headers['content-type'], getRes.headers['content-type']);
        assert.equal(headRes.headers['etag'], getRes.headers['etag']);
      }
    });
  });

  // =========================================================================
  // F4: /lesnik & /lesnik.html Serving & DOM/Optimization Parity
  // =========================================================================
  describe('F4: /lesnik & /lesnik.html Serving & Landmark Parity', () => {
    it('F4.1 serves both /lesnik and /lesnik.html with 200 text/html matching web/lesnik.html', async () => {
      const diskBuf = fs.readFileSync(DEFAULT_LESNIK_PATH);
      for (const route of ['/lesnik', '/lesnik.html']) {
        const res = await httpRequest(srv.baseUrl, route);
        assert.equal(res.status, 200);
        assert.equal(res.headers['content-type'], 'text/html; charset=utf-8');
        assert.equal(Buffer.compare(res.rawBody, diskBuf), 0);
      }
    });

    it('F4.2 contains all required Forester Dashboard DOM landmarks', async () => {
      const res = await httpRequest(srv.baseUrl, '/lesnik');
      const html = res.text();
      const requiredIds = [
        'id="map"',
        'id="reports-container"',
        'id="search-query"',
        'id="photo-modal"',
        'id="new-report-modal"',
        'id="pill-filter-all"',
        'id="pill-filter-pending"',
        'id="pill-filter-in_progress"',
        'id="pill-filter-resolved"',
        'id="bdl-checkbox"',
        'id="zones-checkbox"',
        'id="coords-display"',
        'id="toast"',
        'id="header-sync-time"'
      ];
      for (const landmark of requiredIds) {
        assert.ok(html.includes(landmark), `lesnik.html missing landmark ${landmark}`);
      }
    });

    it('F4.3 includes GPX/CSV export and incident/note modal controls', async () => {
      const html = (await httpRequest(srv.baseUrl, '/lesnik')).text();
      for (const token of [
        'exportGPX',
        'exportCSV',
        'saveModalNote',
        'submitNewReport',
        'modal-notes-input',
        'new-category',
        'new-lat',
        'new-lng'
      ]) {
        assert.ok(html.includes(token), `lesnik.html missing ${token}`);
      }
    });

    it('F4.4 <head> includes preconnect hint and deferred Leaflet script with DOMContentLoaded boot', async () => {
      const html = (await httpRequest(srv.baseUrl, '/lesnik')).text();
      const headEnd = html.indexOf('</head>');
      assert.ok(headEnd > 0);
      const head = html.slice(0, headEnd);
      assert.match(head, /<link\s+rel=["']preconnect["']/i);
      assert.match(head, /<script[^>]+defer[^>]+leaflet\.js/i);
      assert.match(html, /DOMContentLoaded/);
    });

    it('F4.5 includes visibilitychange, escapeHtml, rAF coords throttling, and AudioContext reuse', async () => {
      const html = (await httpRequest(srv.baseUrl, '/lesnik')).text();
      assert.match(html, /visibilitychange/);
      assert.match(html, /function\s+escapeHtml\b/);
      assert.match(html, /requestAnimationFrame/);
      assert.match(html, /sharedAudioCtx|AudioContext/);
    });
  });

  // =========================================================================
  // F5: /api/reports CRUD & Root Delegation
  // =========================================================================
  describe('F5: /api/reports Contract & Root Delegation', () => {
    it('F5.1 GET /api/reports returns valid JSON array with canonical schema fields', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(res.status, 200);
      const data = res.json();
      assert.ok(Array.isArray(data));
      assert.ok(data.length >= 4);
      for (const rep of data) {
        assert.equal(typeof rep.id, 'string');
        assert.equal(typeof rep.category, 'string');
        assert.equal(typeof rep.latitude, 'number');
        assert.equal(typeof rep.longitude, 'number');
        assert.equal(typeof rep.status, 'string');
        assert.equal(typeof rep.description, 'string');
        assert.equal(typeof rep.createdAt, 'string');
      }
    });

    it('F5.2 POST /api/reports creates report with canonical fields and returns 201', async () => {
      const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
      let mutSrv;
      try {
        mutSrv = await startServer();
        const payload = {
          category: 'fallen_tree',
          latitude: 52.0612,
          longitude: 21.3811,
          nadlesnictwo: 'Chojnów',
          oddzial: '140a',
          description: 'Tier1 test fallen pine',
          notes: 'Test dispatcher note'
        };
        const res = await httpRequest(mutSrv.baseUrl, '/api/reports', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        assert.equal(res.status, 201);
        const body = res.json();
        assert.equal(body.success, true);
        assert.ok(body.report.id);
        assert.equal(body.report.latitude, 52.0612);
        assert.equal(body.report.longitude, 21.3811);
        assert.equal(body.report.notes, 'Test dispatcher note');
        assert.equal(body.report.status, 'pending');
        assert.equal(body.report.confirmationsCount, 1);
      } finally {
        if (mutSrv) await mutSrv.stop();
        restoreReportsJson(snapshot);
      }
    });

    it('F5.3 PATCH /api/reports/:id updates notes and assignedZul', async () => {
      const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
      let mutSrv;
      try {
        mutSrv = await startServer();
        const res = await httpRequest(mutSrv.baseUrl, '/api/reports/rep-001', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            status: 'in_progress',
            notes: 'Przekazano do ZUL',
            assignedZul: 'ZUL Chojnów'
          })
        });
        assert.equal(res.status, 200);
        const body = res.json();
        assert.equal(body.success, true);
        assert.equal(body.report.status, 'in_progress');
        assert.equal(body.report.notes, 'Przekazano do ZUL');
        assert.equal(body.report.assignedZul, 'ZUL Chojnów');
      } finally {
        if (mutSrv) await mutSrv.stop();
        restoreReportsJson(snapshot);
      }
    });

    it('F5.4 PATCH /api/reports/:id setting status=resolved populates ISO-8601 resolvedAt', async () => {
      const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
      let mutSrv;
      try {
        mutSrv = await startServer();
        const res = await httpRequest(mutSrv.baseUrl, '/api/reports/rep-001', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'resolved' })
        });
        assert.equal(res.status, 200);
        const body = res.json();
        assert.equal(body.report.status, 'resolved');
        assert.ok(body.report.resolvedAt, 'resolvedAt must be set when resolved');
        assert.ok(!Number.isNaN(Date.parse(body.report.resolvedAt)), 'resolvedAt must be valid ISO date');
      } finally {
        if (mutSrv) await mutSrv.stop();
        restoreReportsJson(snapshot);
      }
    });

    it('F5.5 root server.cjs delegates cleanly and serves /api/reports and /', async () => {
      if (process.env.E2E_SKIP_ROOT_SERVER === '1') return;
      const rootSrv = await startServer({ serverPath: ROOT_SERVER_PATH });
      try {
        const apiRes = await httpRequest(rootSrv.baseUrl, '/api/reports');
        assert.equal(apiRes.status, 200);
        assert.ok(Array.isArray(apiRes.json()));
        const rootRes = await httpRequest(rootSrv.baseUrl, '/');
        assert.equal(rootRes.status, 200);
        assert.match(String(rootRes.headers['content-type']), /text\/html/i);
      } finally {
        await rootSrv.stop();
      }
    });
  });

  // =========================================================================
  // F6: SPA Fallback, COOP/COEP, CORS
  // =========================================================================
  describe('F6: SPA Fallback, COOP/COEP & CORS Headers', () => {
    it('F6.1 GET / includes COOP same-origin and COEP credentialless', async () => {
      const res = await httpRequest(srv.baseUrl, '/');
      assert.equal(res.status, 200);
      assert.equal(res.headers['cross-origin-opener-policy'], 'same-origin');
      assert.equal(res.headers['cross-origin-embedder-policy'], 'credentialless');
    });

    it('F6.2 extensionless SPA routes (/map, /journal) fall back to 200 index.html', async () => {
      const indexBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'index.html'));
      for (const route of ['/map', '/journal']) {
        const res = await httpRequest(srv.baseUrl, route);
        assert.equal(res.status, 200);
        assert.equal(res.headers['content-type'], 'text/html; charset=utf-8');
        assert.equal(Buffer.compare(res.rawBody, indexBuf), 0);
      }
    });

    it('F6.3 responses include CORS wildcard origin, headers, and methods', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(res.headers['access-control-allow-origin'], '*');
      assert.equal(res.headers['access-control-allow-headers'], '*');
      const methods = String(res.headers['access-control-allow-methods'] || '');
      for (const m of ['GET', 'POST', 'PATCH', 'OPTIONS']) {
        assert.ok(methods.includes(m), `ACAM missing ${m}: ${methods}`);
      }
    });

    it('F6.4 OPTIONS /api/reports returns 204 No Content with zero body and CORS headers', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports', { method: 'OPTIONS' });
      assert.equal(res.status, 204);
      assert.equal(res.rawBody.length, 0);
      assert.equal(res.headers['access-control-allow-origin'], '*');
    });

    it('F6.5 static image assets also include COOP, COEP, and CORS headers', async () => {
      const res = await httpRequest(srv.baseUrl, '/assets/assets/mushrooms/borowik_szlachetny.webp');
      assert.equal(res.status, 200);
      assert.equal(res.headers['cross-origin-opener-policy'], 'same-origin');
      assert.equal(res.headers['cross-origin-embedder-policy'], 'credentialless');
      assert.equal(res.headers['access-control-allow-origin'], '*');
    });
  });

  // =========================================================================
  // F7: build/web/ Core Assets & Routes
  // =========================================================================
  describe('F7: build/web/ Core Assets & Routes', () => {
    it('F7.1 GET /index.html serves build/web/index.html byte-exact', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'index.html'));
      const res = await httpRequest(srv.baseUrl, '/index.html');
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-type'], 'text/html; charset=utf-8');
      assert.equal(Buffer.compare(res.rawBody, diskBuf), 0);
    });

    it('F7.2 GET /manifest.json serves valid manifest and declared icons resolve 200', async () => {
      const res = await httpRequest(srv.baseUrl, '/manifest.json');
      assert.equal(res.status, 200);
      assert.match(String(res.headers['content-type']), /application\/json/i);
      const manifest = res.json();
      assert.equal(manifest.display, 'standalone');
      assert.ok(Array.isArray(manifest.icons) && manifest.icons.length >= 4);
      for (const icon of manifest.icons) {
        const iconRes = await httpRequest(srv.baseUrl, `/${icon.src.replace(/^\/+/, '')}`);
        assert.equal(iconRes.status, 200, `Missing manifest icon: ${icon.src}`);
        assert.equal(iconRes.headers['content-type'], 'image/png');
      }
    });

    it('F7.3 GET /flutter_bootstrap.js serves 200 application/javascript', async () => {
      const res = await httpRequest(srv.baseUrl, '/flutter_bootstrap.js');
      assert.equal(res.status, 200);
      assert.match(String(res.headers['content-type']), /application\/javascript/i);
      assert.ok(res.text().includes('main.dart.js'));
    });

    it('F7.4 GET /main.dart.js and /canvaskit/canvaskit.wasm serve with exact MIME types', async () => {
      const jsRes = await httpRequest(srv.baseUrl, '/main.dart.js');
      assert.equal(jsRes.status, 200);
      assert.match(String(jsRes.headers['content-type']), /application\/javascript/i);

      const wasmRes = await httpRequest(srv.baseUrl, '/canvaskit/canvaskit.wasm');
      assert.equal(wasmRes.status, 200);
      assert.equal(wasmRes.headers['content-type'], 'application/wasm');
    });

    it('F7.5 all mushroom .webp assets serve 200 image/webp at /assets/assets/mushrooms/*', async () => {
      const files = fs.readdirSync(MUSHROOM_ASSETS_DIR).filter((f) => f.endsWith('.webp'));
      assert.ok(files.length >= 23, `Expected >=23 mushroom WebPs, found ${files.length}`);
      for (const name of files) {
        const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'assets', 'assets', 'mushrooms', name));
        const res = await httpRequest(srv.baseUrl, `/assets/assets/mushrooms/${name}`);
        assert.equal(res.status, 200, `Failed serving ${name}`);
        assert.equal(res.headers['content-type'], 'image/webp');
        assert.equal(Buffer.compare(res.rawBody, diskBuf), 0);
      }
    });
  });
});
