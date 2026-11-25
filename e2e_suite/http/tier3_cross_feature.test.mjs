import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import {
  DEFAULT_WEB_DIR,
  DEFAULT_SRC_WEB_DIR,
  DEFAULT_LESNIK_PATH,
  DEFAULT_REPORTS_FILE,
  ROOT_SERVER_PATH,
  startServer,
  httpRequest,
  decompressBody,
  backupReportsJson,
  restoreReportsJson,
  sha256File
} from '../lib/server_harness.mjs';

describe('Tier 3 — Cross-Feature Interactions', () => {
  it('T3.01 POST -> GET new ETag -> If-None-Match 304 -> PATCH -> GET updated payload & rotated ETag', async () => {
    const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
    let srv;
    try {
      srv = await startServer();

      const initialGet = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(initialGet.status, 200);
      const initialEtag = initialGet.headers['etag'];
      assert.ok(initialEtag);

      const postRes = await httpRequest(srv.baseUrl, '/api/reports', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'trash',
          latitude: 52.055,
          longitude: 21.375,
          nadlesnictwo: 'Chojnów',
          oddzial: '141b',
          description: 'Tier3 ETag rotation test',
          notes: 'Initial note'
        })
      });
      assert.equal(postRes.status, 201);
      const createdId = postRes.json().report.id;

      const afterPostGet = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(afterPostGet.status, 200);
      const etagAfterPost = afterPostGet.headers['etag'];
      assert.notEqual(etagAfterPost, initialEtag, 'ETag must rotate after POST');

      // Revalidating with old ETag must return 200, while new ETag returns 304
      const staleCheck = await httpRequest(srv.baseUrl, '/api/reports', {
        headers: { 'If-None-Match': initialEtag }
      });
      assert.equal(staleCheck.status, 200);

      const fresh304 = await httpRequest(srv.baseUrl, '/api/reports', {
        headers: { 'If-None-Match': etagAfterPost }
      });
      assert.equal(fresh304.status, 304);

      const patchRes = await httpRequest(srv.baseUrl, `/api/reports/${createdId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: 'in_progress',
          notes: 'Updated note',
          assignedZul: 'ZUL Las'
        })
      });
      assert.equal(patchRes.status, 200);

      const afterPatchGet = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(afterPatchGet.status, 200);
      const etagAfterPatch = afterPatchGet.headers['etag'];
      assert.notEqual(etagAfterPatch, etagAfterPost, 'ETag must rotate after PATCH');

      const updatedRecord = afterPatchGet.json().find((r) => r.id === createdId);
      assert.ok(updatedRecord);
      assert.equal(updatedRecord.status, 'in_progress');
      assert.equal(updatedRecord.notes, 'Updated note');
      assert.equal(updatedRecord.assignedZul, 'ZUL Las');

      const oldPostEtagCheck = await httpRequest(srv.baseUrl, '/api/reports', {
        headers: { 'If-None-Match': etagAfterPost }
      });
      assert.equal(oldPostEtagCheck.status, 200);
    } finally {
      if (srv) await srv.stop();
      restoreReportsJson(snapshot);
    }
  });

  it('T3.02 Persistence across server restart preserves POST + PATCH mutations', async () => {
    const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
    let srv1;
    let srv2;
    try {
      srv1 = await startServer();
      const postRes = await httpRequest(srv1.baseUrl, '/api/reports', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'vandalism',
          latitude: 52.049,
          longitude: 21.371,
          nadlesnictwo: 'Chojnów',
          oddzial: '149a',
          description: 'Restart persistence test'
        })
      });
      assert.equal(postRes.status, 201);
      const createdId = postRes.json().report.id;

      await httpRequest(srv1.baseUrl, `/api/reports/${createdId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: 'resolved',
          notes: 'Persisted across restart',
          assignedZul: 'ZUL Ekipa 2'
        })
      });
      await srv1.stop();
      srv1 = null;

      srv2 = await startServer();
      const list = (await httpRequest(srv2.baseUrl, '/api/reports')).json();
      const persisted = list.find((r) => r.id === createdId);
      assert.ok(persisted, 'Created report must survive server restart');
      assert.equal(persisted.status, 'resolved');
      assert.equal(persisted.notes, 'Persisted across restart');
      assert.equal(persisted.assignedZul, 'ZUL Ekipa 2');
      assert.ok(persisted.resolvedAt);
    } finally {
      if (srv1) await srv1.stop();
      if (srv2) await srv2.stop();
      restoreReportsJson(snapshot);
    }
  });

  it('T3.03 Concurrent POST /api/reports burst (10 parallel requests) preserves atomic JSON integrity', async () => {
    const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
    let srv;
    try {
      srv = await startServer();
      const initial = (await httpRequest(srv.baseUrl, '/api/reports')).json();

      const requests = Array.from({ length: 10 }, (_, idx) =>
        httpRequest(srv.baseUrl, '/api/reports', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: `burst-rep-${idx}-${Date.now()}`,
            category: 'fallen_tree',
            latitude: 52.05 + idx * 0.001,
            longitude: 21.37 + idx * 0.001,
            nadlesnictwo: 'Chojnów',
            oddzial: `10${idx}a`,
            description: `Concurrent burst #${idx}`
          })
        })
      );

      const results = await Promise.all(requests);
      for (const r of results) {
        assert.equal(r.status, 201);
        assert.equal(r.json().success, true);
      }

      const after = (await httpRequest(srv.baseUrl, '/api/reports')).json();
      assert.equal(after.length, initial.length + 10);

      // Verify disk file is valid JSON with all 10 records and no leftover .tmp files
      const diskParsed = JSON.parse(fs.readFileSync(DEFAULT_REPORTS_FILE, 'utf8'));
      assert.equal(diskParsed.length, initial.length + 10);
      const dataDirFiles = fs.readdirSync(path.dirname(DEFAULT_REPORTS_FILE));
      const leftoverTmp = dataDirFiles.filter((f) => f.includes('.tmp.'));
      assert.equal(leftoverTmp.length, 0, `Leftover tmp files: ${leftoverTmp.join(', ')}`);
    } finally {
      if (srv) await srv.stop();
      restoreReportsJson(snapshot);
    }
  });

  it('T3.04 grzybmap_app/web/lesnik.html SHA-256 matches grzybmap_app/build/web/lesnik.html', async () => {
    const buildLesnik = path.join(DEFAULT_WEB_DIR, 'lesnik.html');
    assert.ok(fs.existsSync(DEFAULT_LESNIK_PATH), 'web/lesnik.html must exist');
    assert.ok(fs.existsSync(buildLesnik), 'build/web/lesnik.html must exist');
    assert.equal(
      sha256File(DEFAULT_LESNIK_PATH),
      sha256File(buildLesnik),
      'build/web/lesnik.html must be synced with web/lesnik.html'
    );
  });

  it('T3.05 Compression + ETag + If-None-Match interaction across br, gzip, and identity', async () => {
    const srv = await startServer();
    try {
      const brRes = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'br' }
      });
      const gzRes = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'gzip' }
      });
      const idRes = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'identity' }
      });

      assert.equal(brRes.headers['content-encoding'], 'br');
      assert.equal(gzRes.headers['content-encoding'], 'gzip');
      assert.equal(idRes.headers['content-encoding'], undefined);

      assert.notEqual(brRes.headers['etag'], gzRes.headers['etag']);
      assert.notEqual(brRes.headers['etag'], idRes.headers['etag']);

      for (const [enc, etag] of [
        ['br', brRes.headers['etag']],
        ['gzip', gzRes.headers['etag']],
        ['identity', idRes.headers['etag']]
      ]) {
        const reval = await httpRequest(srv.baseUrl, '/main.dart.js', {
          headers: { 'Accept-Encoding': enc, 'If-None-Match': etag }
        });
        assert.equal(reval.status, 304, `Expected 304 for encoding=${enc}`);
        assert.equal(reval.rawBody.length, 0);
      }
    } finally {
      await srv.stop();
    }
  });

  it('T3.06 HEAD + Compression negotiation returns compressed metadata with zero body bytes', async () => {
    const srv = await startServer();
    try {
      const getBr = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'br' }
      });
      const headBr = await httpRequest(srv.baseUrl, '/main.dart.js', {
        method: 'HEAD',
        headers: { 'Accept-Encoding': 'br' }
      });
      assert.equal(headBr.status, 200);
      assert.equal(headBr.rawBody.length, 0);
      assert.equal(headBr.headers['content-encoding'], 'br');
      assert.equal(headBr.headers['etag'], getBr.headers['etag']);
      assert.equal(headBr.headers['content-length'], getBr.headers['content-length']);
      assert.match(String(headBr.headers['vary'] || ''), /Accept-Encoding/i);
    } finally {
      await srv.stop();
    }
  });

  it('T3.07 Range + Accept-Encoding: br returns 206 uncompressed slice matching raw file bytes', async () => {
    const srv = await startServer();
    try {
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      const res = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: {
          'Accept-Encoding': 'br, gzip',
          Range: 'bytes=0-31'
        }
      });
      assert.equal(res.status, 206);
      assert.equal(res.headers['content-encoding'], undefined);
      assert.equal(res.headers['content-range'], `bytes 0-31/${diskBuf.length}`);
      assert.equal(Buffer.compare(res.rawBody, diskBuf.subarray(0, 32)), 0);
    } finally {
      await srv.stop();
    }
  });

  it('T3.08 CORS preflight OPTIONS + PATCH cross-feature workflow', async () => {
    const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
    let srv;
    try {
      srv = await startServer();
      const optRes = await httpRequest(srv.baseUrl, '/api/reports/rep-001', {
        method: 'OPTIONS',
        headers: {
          Origin: 'https://example.local',
          'Access-Control-Request-Method': 'PATCH'
        }
      });
      assert.equal(optRes.status, 204);
      assert.equal(optRes.headers['access-control-allow-origin'], '*');
      assert.match(String(optRes.headers['access-control-allow-methods']), /PATCH/);

      const patchRes = await httpRequest(srv.baseUrl, '/api/reports/rep-001', {
        method: 'PATCH',
        headers: {
          Origin: 'https://example.local',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ notes: 'CORS verified' })
      });
      assert.equal(patchRes.status, 200);
      assert.equal(patchRes.headers['access-control-allow-origin'], '*');
      assert.equal(patchRes.json().report.notes, 'CORS verified');
    } finally {
      if (srv) await srv.stop();
      restoreReportsJson(snapshot);
    }
  });

  it('T3.09 web/index.html preserves $FLUTTER_BASE_HREF and manifest.json icon paths exist on disk', async () => {
    const srcIndex = fs.readFileSync(path.join(DEFAULT_SRC_WEB_DIR, 'index.html'), 'utf8');
    assert.ok(srcIndex.includes('$FLUTTER_BASE_HREF'), 'web/index.html must keep $FLUTTER_BASE_HREF');
    assert.ok(srcIndex.includes('flutter_bootstrap.js'), 'web/index.html must load flutter_bootstrap.js');
    assert.ok(srcIndex.includes('manifest.json'), 'web/index.html must link manifest.json');

    const manifest = JSON.parse(fs.readFileSync(path.join(DEFAULT_SRC_WEB_DIR, 'manifest.json'), 'utf8'));
    assert.ok(Array.isArray(manifest.icons) && manifest.icons.length >= 4);
    for (const icon of manifest.icons) {
      const p = path.join(DEFAULT_SRC_WEB_DIR, icon.src);
      assert.ok(fs.existsSync(p), `Source web icon missing: ${p}`);
    }
  });

  it('T3.10 Proxy routes handle empty queries and client aborts gracefully without crashing server', async () => {
    const srv = await startServer();
    try {
      // Empty /api/search?q= returns immediate 200 [] without external network call
      const emptySearch = await httpRequest(srv.baseUrl, '/api/search?q=');
      assert.equal(emptySearch.status, 200);
      assert.deepEqual(emptySearch.json(), []);

      // Aborted proxy request mid-flight via raw TCP must not crash server
      await new Promise((resolve) => {
        const sock = net.connect({ host: '127.0.0.1', port: srv.port }, () => {
          sock.write('GET /api/bdl?SERVICE=WMS&REQUEST=GetMap HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n');
          setTimeout(() => {
            sock.destroy();
            resolve();
          }, 25);
        });
        sock.on('error', () => resolve());
      });

      const health = await httpRequest(srv.baseUrl, '/api/reports');
      assert.equal(health.status, 200);
    } finally {
      await srv.stop();
    }
  });

  it('T3.11 Concurrent POST + PATCH serialization preserves resolvedAt and final state', async () => {
    const snapshot = backupReportsJson(DEFAULT_REPORTS_FILE);
    let srv;
    try {
      srv = await startServer();
      const postRes = await httpRequest(srv.baseUrl, '/api/reports', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: 'race-test-1',
          category: 'fire_hazard',
          latitude: 52.055,
          longitude: 21.366,
          description: 'Race condition guard test'
        })
      });
      assert.equal(postRes.status, 201);

      // Fire 3 concurrent PATCHes on the same ID
      const [p1, p2, p3] = await Promise.all([
        httpRequest(srv.baseUrl, '/api/reports/race-test-1', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ notes: 'Step 1' })
        }),
        httpRequest(srv.baseUrl, '/api/reports/race-test-1', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ assignedZul: 'ZUL Gamma' })
        }),
        httpRequest(srv.baseUrl, '/api/reports/race-test-1', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'resolved' })
        })
      ]);
      assert.equal(p1.status, 200);
      assert.equal(p2.status, 200);
      assert.equal(p3.status, 200);

      const finalList = (await httpRequest(srv.baseUrl, '/api/reports')).json();
      const rec = finalList.find((r) => r.id === 'race-test-1');
      assert.equal(rec.notes, 'Step 1');
      assert.equal(rec.assignedZul, 'ZUL Gamma');
      assert.equal(rec.status, 'resolved');
      assert.ok(rec.resolvedAt);
    } finally {
      if (srv) await srv.stop();
      restoreReportsJson(snapshot);
    }
  });

  it('T3.12 Root server.cjs matches grzybmap_app/server.cjs compression, ETag, and Range behavior', async () => {
    if (process.env.E2E_SKIP_ROOT_SERVER === '1') return;
    const srv = await startServer({ serverPath: ROOT_SERVER_PATH });
    try {
      const brRes = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { 'Accept-Encoding': 'br' }
      });
      assert.equal(brRes.status, 200);
      assert.equal(brRes.headers['content-encoding'], 'br');
      assert.ok(brRes.headers['etag']);
      const diskBuf = fs.readFileSync(path.join(DEFAULT_WEB_DIR, 'main.dart.js'));
      assert.equal(Buffer.compare(decompressBody(brRes.rawBody, 'br'), diskBuf), 0);

      const rangeRes = await httpRequest(srv.baseUrl, '/main.dart.js', {
        headers: { Range: 'bytes=0-15' }
      });
      assert.equal(rangeRes.status, 206);
      assert.equal(Buffer.compare(rangeRes.rawBody, diskBuf.subarray(0, 16)), 0);
    } finally {
      await srv.stop();
    }
  });
});
