import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {
  DEFAULT_WEB_DIR,
  DEFAULT_REPORTS_FILE,
  startServer,
  httpRequest,
  rawTcpRequest,
  decompressBody,
  backupReportsJson,
  restoreReportsJson
} from '../lib/server_harness.mjs';

describe('Tier 2 — Boundary, Corner & Error Handling (F1–F7)', () => {
  let srv;

  before(async () => {
    srv = await startServer();
  });

  after(async () => {
    if (srv) await srv.stop();
  });

  // =========================================================================
  // F1: Compression Boundaries
  // =========================================================================
  describe('F1: Compression Boundaries', () => {
    it('F1.B1 Accept-Encoding: identity returns uncompressed payload without Content-Encoding', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'identity' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], undefined);
      assert.equal(Buffer.compare(res.rawBody, diskBuf), 0);
    });

    it('F1.B2 unknown encodings (zstd, deflate) fall back to uncompressed identity cleanly', async () => {
      const res = await httpRequest(srv.baseUrl, '/flutter_bootstrap.js', {
        headers: { 'Accept-Encoding': 'zstd, deflate' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], undefined);
      assert.ok(res.text().includes('main.dart.js'));
    });

    it('F1.B3 respects quality weight q=0 rejecting br and falling back to gzip', async () => {
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'br;q=0, gzip;q=0.8' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], 'gzip');
      const decompressed = decompressBody(res.rawBody, 'gzip');
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      assert.equal(Buffer.compare(decompressed, diskBuf), 0);
    });

    it('F1.B4 does not compress already-compressed .webp images even when br/gzip accepted', async () => {
      const res = await httpRequest(srv.baseUrl, '/assets/assets/mushrooms/borowik_szlachetny.webp', {
        headers: { 'Accept-Encoding': 'br, gzip' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], undefined);
      assert.equal(res.headers['content-type'], 'image/webp');
    });

    it('F1.B5 does not compress tiny responses (<256 bytes) such as /version.json', async () => {
      const versionBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'version.json'));
      assert.ok(versionBuf.length < 256);
      const res = await httpRequest(srv.baseUrl, '/version.json', {
        headers: { 'Accept-Encoding': 'br, gzip' }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], undefined);
      assert.equal(Buffer.compare(res.rawBody, versionBuf), 0);
    });
  });

  // =========================================================================
  // F2: Caching Boundaries
  // =========================================================================
  describe('F2: Caching Boundaries', () => {
    it('F2.B1 If-None-Match mismatch returns 200 with full body and current ETag', async () => {
      const res = await httpRequest(srv.baseUrl, '/lesnik', {
        headers: { 'If-None-Match': '"nonexistent-etag-value"' }
      });
      assert.equal(res.status, 200);
      assert.ok(res.rawBody.length > 1000);
      assert.ok(res.headers['etag']);
    });

    it('F2.B2 If-None-Match: * matches any resource and returns 304', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports', {
        headers: { 'If-None-Match': '*' }
      });
      assert.equal(res.status, 304);
      assert.equal(res.rawBody.length, 0);
    });

    it('F2.B3 weak ETag prefix W/<etag> matches under If-None-Match and returns 304', async () => {
      const first = await httpRequest(srv.baseUrl, '/manifest.json');
      assert.equal(first.status, 200);
      assert.ok(first.headers['etag']);
      const second = await httpRequest(srv.baseUrl, '/manifest.json', {
        headers: { 'If-None-Match': `W/${first.headers['etag']}` }
      });
      assert.equal(second.status, 304);
      assert.equal(second.rawBody.length, 0);
    });

    it('F2.B4 comma-separated If-None-Match list matches valid ETag and returns 304', async () => {
      const first = await httpRequest(srv.baseUrl, '/flutter_bootstrap.js');
      assert.equal(first.status, 200);
      const second = await httpRequest(srv.baseUrl, '/flutter_bootstrap.js', {
        headers: { 'If-None-Match': `"stale-1", ${first.headers['etag']}, "stale-2"` }
      });
      assert.equal(second.status, 304);
    });

    it('F2.B5 encoding-specific ETag from br does not cause 304 when requesting identity', async () => {
      const brRes = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'br' }
      });
      assert.equal(brRes.status, 200);
      assert.equal(brRes.headers['content-encoding'], 'br');

      const idRes = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: {
          'Accept-Encoding': 'identity',
          'If-None-Match': brRes.headers['etag']
        }
      });
      assert.equal(idRes.status, 200);
      assert.equal(idRes.headers['content-encoding'], undefined);
      assert.notEqual(idRes.headers['etag'], brRes.headers['etag']);
    });
  });

  // =========================================================================
  // F3: Range & HEAD Boundaries
  // =========================================================================
  describe('F3: Range & HEAD Boundaries', () => {
    it('F3.B1 unsatisfiable Range (bytes=999999999-) returns 416 with Content-Range: bytes */total', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { Range: 'bytes=999999999-' }
      });
      assert.equal(res.status, 416);
      assert.equal(res.headers['content-range'], `bytes */${diskBuf.length}`);
    });

    it('F3.B2 malformed Range (bytes=abc) returns 416 with Content-Range: bytes */total', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { Range: 'bytes=abc' }
      });
      assert.equal(res.status, 416);
      assert.equal(res.headers['content-range'], `bytes */${diskBuf.length}`);
    });

    it('F3.B3 reversed Range (bytes=50-10) returns 416 with Content-Range: bytes */total', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { Range: 'bytes=50-10' }
      });
      assert.equal(res.status, 416);
      assert.equal(res.headers['content-range'], `bytes */${diskBuf.length}`);
    });

    it('F3.B4 open-ended Range near EOF clamps cleanly to file end', async () => {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const start = diskBuf.length - 40;
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { Range: `bytes=${start}-` }
      });
      assert.equal(res.status, 206);
      assert.equal(res.headers['content-range'], `bytes ${start}-${diskBuf.length - 1}/${diskBuf.length}`);
      assert.equal(Buffer.compare(res.rawBody, diskBuf.subarray(start)), 0);
    });

    it('F3.B5 HEAD with Range returns 206 with zero body; HEAD on missing asset returns 404 with zero body', async () => {
      const rangeHead = await httpRequest(srv.baseUrl, '/main.dart.js', {
        method: 'HEAD',
        headers: { Range: 'bytes=0-15' }
      });
      assert.equal(rangeHead.status, 206);
      assert.equal(rangeHead.headers['content-length'], '16');
      assert.equal(rangeHead.rawBody.length, 0);

      const missingHead = await httpRequest(srv.baseUrl, '/missing-asset-xyz.js', {
        method: 'HEAD'
      });
      assert.equal(missingHead.status, 404);
      assert.equal(missingHead.rawBody.length, 0);
    });
  });

  // =========================================================================
  // F4: /lesnik & HTML Edge Cases
  // =========================================================================
  describe('F4: /lesnik & HTML Edge Cases', () => {
    it('F4.B1 GET /lesnik?cachebust=1 serves 200 lesnik.html ignoring query params', async () => {
      const res = await httpRequest(srv.baseUrl, '/lesnik?cachebust=1&zone=chojnow');
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-type'], 'text/html; charset=utf-8');
      assert.ok(res.text().includes('id="map"'));
    });

    it('F4.B2 HEAD /lesnik.html returns 200 text/html with ETag and zero body', async () => {
      const res = await httpRequest(srv.baseUrl, '/lesnik.html', { method: 'HEAD' });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-type'], 'text/html; charset=utf-8');
      assert.ok(res.headers['etag']);
      assert.equal(res.rawBody.length, 0);
    });

    it('F4.B3 lesnik.html contains image URI sanitizer rejecting javascript: schemes', async () => {
      const html = (await httpRequest(srv.baseUrl, '/lesnik')).text();
      assert.match(html, /sanitizeImageSrc/);
      assert.match(html, /toSafeCoord/);
    });

    it('F4.B4 lesnik.html reuses single sharedAudioCtx instead of allocating per chime', async () => {
      const html = (await httpRequest(srv.baseUrl, '/lesnik')).text();
      const matches = html.match(/new\s+AudioCtx|new\s+AudioContext/g) || [];
      assert.equal(matches.length, 1, 'Expected single guarded AudioContext instantiation site');
      assert.match(html, /if\s*\(\s*!sharedAudioCtx/);
    });

    it('F4.B5 /lesnik If-None-Match mismatch returns 200 compressed HTML when br accepted', async () => {
      const res = await httpRequest(srv.baseUrl, '/lesnik', {
        headers: {
          'Accept-Encoding': 'br',
          'If-None-Match': '"wrong-etag"'
        }
      });
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-encoding'], 'br');
    });
  });

  // =========================================================================
  // F5: /api/reports Boundary & Error Cases
  // =========================================================================
  describe('F5: /api/reports Boundary & Error Handling', () => {
    it('F5.B1 POST /api/reports with invalid JSON returns 400 and preserves reports.json', async () => {
      const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
      let mutSrv;
      try {
        mutSrv = await startServer();
        const res = await httpRequest(mutSrv.baseUrl, '/api/reports', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: '{invalid-json'
        });
        assert.equal(res.status, 400);
        assert.ok(res.json().error);
      } finally {
        if (mutSrv) await mutSrv.stop();
        restoreReportsJson(snapshot);
      }
    });

    it('F5.B2 POST /api/reports with empty body or JSON array returns 400', async () => {
      const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
      let mutSrv;
      try {
        mutSrv = await startServer();
        for (const badBody of ['', '[]']) {
          const res = await httpRequest(mutSrv.baseUrl, '/api/reports', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: badBody
          });
          assert.equal(res.status, 400, `Expected 400 for body ${JSON.stringify(badBody)}`);
        }
      } finally {
        if (mutSrv) await mutSrv.stop();
        restoreReportsJson(snapshot);
      }
    });

    it('F5.B3 POST /api/reports with >10MB JSON payload returns 413 without crashing server', async () => {
      const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
      let mutSrv;
      try {
        mutSrv = await startServer();
        const oversized = Buffer.alloc(10 * 1024 * 1024 + 512, 'a');
        const res = await httpRequest(mutSrv.baseUrl, '/api/reports', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: oversized
        });
        assert.equal(res.status, 413);
        const health = await httpRequest(mutSrv.baseUrl, '/api/reports');
        assert.equal(health.status, 200);
      } finally {
        if (mutSrv) await mutSrv.stop();
        restoreReportsJson(snapshot);
      }
    });

    it('F5.B4 PATCH /api/reports/nonexistent-id-999 returns 404 JSON error', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports/nonexistent-id-999', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'resolved' })
      });
      assert.equal(res.status, 404);
      assert.ok(res.json().error);
    });

    it('F5.B5 PATCH /api/reports/rep-001 with malformed JSON returns 400 and preserves rep-001', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports/rep-001', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: '{"status": '
      });
      assert.equal(res.status, 400);
      const list = (await httpRequest(srv.baseUrl, '/api/reports')).json();
      const rep1 = list.find((r) => r.id === 'rep-001');
      assert.equal(rep1.status, 'pending');
    });

    it('F5.B6 unsupported HTTP method DELETE /api/reports returns 405/404 (not 200 SPA fallback)', async () => {
      const before = (await httpRequest(srv.baseUrl, '/api/reports')).json();
      const res = await httpRequest(srv.baseUrl, '/api/reports', {
        method: 'DELETE'
      });
      assert.ok(
        res.status === 405 || res.status === 404,
        `Expected 405 or 404 for DELETE /api/reports, got ${res.status} (${res.headers['content-type']})`
      );
      const after = (await httpRequest(srv.baseUrl, '/api/reports')).json();
      assert.equal(after.length, before.length);
    });

    it('F5.B7 boundary JSON fields (extreme coords, empty notes, Polish diacritics) roundtrip cleanly', async () => {
      const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
      let mutSrv;
      try {
        mutSrv = await startServer();
        const payload = {
          category: 'fire_hazard',
          latitude: -90,
          longitude: 180,
          nadlesnictwo: 'Żółć-Źdźbło',
          oddzial: '001a',
          description: 'Zażółć gęślą jaźń — boundary test',
          notes: ''
        };
        const postRes = await httpRequest(mutSrv.baseUrl, '/api/reports', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        assert.equal(postRes.status, 201);
        const created = postRes.json().report;
        assert.equal(created.latitude, -90);
        assert.equal(created.longitude, 180);
        assert.equal(created.notes, '');
        assert.equal(created.nadlesnictwo, 'Żółć-Źdźbło');

        const patchRes = await httpRequest(mutSrv.baseUrl, `/api/reports/${created.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ latitude: 90, notes: 'Zażółć 🌲' })
        });
        assert.equal(patchRes.status, 200);
        assert.equal(patchRes.json().report.notes, 'Zażółć 🌲');
      } finally {
        if (mutSrv) await mutSrv.stop();
        restoreReportsJson(snapshot);
      }
    });
  });

  // =========================================================================
  // F6: Malformed URLs, Path Traversal & Security Boundaries
  // =========================================================================
  describe('F6: Malformed URLs, Path Traversal & Security Boundaries', () => {
    it('F6.B1 malformed percent-encoding (/bad%url) returns 400 without crashing server', async () => {
      const res = await httpRequest(srv.baseUrl, '/bad%url');
      assert.equal(res.status, 400);
      const health = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(health.status, 200);
    });

    it('F6.B2 protocol-relative path (//evil.com) does not redirect externally', async () => {
      const res = await rawTcpRequest(
        srv.port,
        'GET //evil.com HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n'
      );
      assert.ok(res.status === 200 || res.status === 400 || res.status === 404);
      assert.ok(!res.raw.toLowerCase().includes('location:'));
    });

    it('F6.B3 raw HTTP/1.1 with invalid Host: [bad returns 400 cleanly', async () => {
      const res = await rawTcpRequest(
        srv.port,
        'GET / HTTP/1.1\r\nHost: [bad\r\nConnection: close\r\n\r\n'
      );
      assert.equal(res.status, 400);
      const health = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(health.status, 200);
    });

    it('F6.B4 raw HTTP/1.0 without Host header returns 400 cleanly', async () => {
      const res = await rawTcpRequest(srv.port, 'GET / HTTP/1.0\r\n\r\n');
      assert.equal(res.status, 400);
      const health = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(health.status, 200);
    });

    it('F6.B5 path traversal payloads never leak files outside build/web/', async () => {
      const payloads = [
        '/../../package.json',
        '/%2e%2e/%2e%2e/package.json',
        '/..%5c..%5cpackage.json',
        '/../data/reports.json',
        '/..%5cdata%5creports.json',
        '/%00index.html'
      ];
      for (const p of payloads) {
        const res = await httpRequest(srv.baseUrl, p);
        assert.ok(
          res.status === 404 || res.status === 400 || res.status === 403,
          `Path traversal ${p} returned unexpected status ${res.status}`
        );
        const body = res.text();
        assert.ok(!body.includes('"rep-001"'), `Path traversal ${p} leaked reports.json!`);
        assert.ok(!body.includes('"dependencies"'), `Path traversal ${p} leaked package.json!`);
      }
    });

    it('F6.B6 missing asset extensions (.js/.wasm/.webp/.css) return 404 while /missing and /missing.html use SPA fallback', async () => {
      for (const missingAsset of ['/missing.js', '/missing.wasm', '/missing.webp', '/missing.css']) {
        const res = await httpRequest(srv.baseUrl, missingAsset);
        assert.equal(res.status, 404, `${missingAsset} should return 404`);
      }
      const indexBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'index.html'));
      for (const spaPath of ['/missing', '/missing.html']) {
        const res = await httpRequest(srv.baseUrl, spaPath);
        assert.equal(res.status, 200, `${spaPath} should use SPA fallback`);
        assert.equal(Buffer.compare(res.rawBody, indexBuf), 0);
      }
    });
  });

  // =========================================================================
  // F7: build/web/ & Asset Serving Boundaries
  // =========================================================================
  describe('F7: build/web/ & Asset Boundaries', () => {
    it('F7.B1 normalized traversal inside /assets/../data/reports.json returns 404', async () => {
      const res = await httpRequest(srv.baseUrl, '/assets/../data/reports.json');
      assert.equal(res.status, 404);
      assert.ok(!res.text().includes('rep-001'));
    });

    it('F7.B2 directory paths (/assets, /canvaskit/) never expose directory listings', async () => {
      for (const dirRoute of ['/assets', '/canvaskit/']) {
        const res = await httpRequest(srv.baseUrl, dirRoute);
        assert.ok(res.status === 200 || res.status === 404);
        assert.ok(!res.text().includes('Index of'));
      }
    });

    it('F7.B3 extensionless /assets/NOTICES serves 200 text/plain and compresses', async () => {
      const res = await httpRequest(srv.baseUrl, '/assets/NOTICES', {
        headers: { 'Accept-Encoding': 'br, gzip' }
      });
      assert.equal(res.status, 200);
      assert.match(String(res.headers['content-type']), /text\/plain/i);
      assert.ok(['br', 'gzip'].includes(res.headers['content-encoding']));
    });

    it('F7.B4 /favicon.png serves 200 image/png with public max-age Cache-Control', async () => {
      const res = await httpRequest(srv.baseUrl, '/favicon.png');
      assert.equal(res.status, 200);
      assert.equal(res.headers['content-type'], 'image/png');
      assert.match(String(res.headers['cache-control']), /public,\s*max-age=\d+/i);
    });

    it('F7.B5 server remains healthy and responsive after all Tier 2 boundary & adversarial inputs', async () => {
      const res = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(res.status, 200);
      const data = res.json();
      assert.ok(Array.isArray(data) && data.length >= 4);
    });
  });
});
