'use strict';

const http = require('http');
const net = require('net');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');
const vm = require('vm');
const assert = require('assert');
const { spawn } = require('child_process');

const APP_DIR = path.resolve(__dirname, '..');
const WEB_DIR = path.join(APP_DIR, 'build', 'web');
const DATA_DIR = path.join(APP_DIR, 'data');
const REPORTS_PATH = path.join(DATA_DIR, 'reports.json');
const LESNIK_PATH = path.join(APP_DIR, 'web', 'lesnik.html');
const SERVER_PATH = path.join(APP_DIR, 'server.cjs');

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function getFreePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address();
      const port = addr && addr.port;
      srv.close((err) => {
        if (err) reject(err);
        else if (!port || port === 8088) reject(new Error(`Invalid ephemeral port: ${port}`));
        else resolve(port);
      });
    });
  });
}

function startServer(port) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [SERVER_PATH], {
      cwd: APP_DIR,
      env: { ...process.env, PORT: String(port) },
      stdio: ['ignore', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';
    let settled = false;

    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        reject(new Error(`Server failed to start within 5000ms.\nstdout: ${stdout}\nstderr: ${stderr}`));
      }
    }, 5000);

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString('utf8');
      if (!settled && stdout.includes('running at')) {
        settled = true;
        clearTimeout(timer);
        resolve(child);
      }
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString('utf8');
    });

    child.on('exit', (code, signal) => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        reject(new Error(`Server exited prematurely (code=${code}, signal=${signal}).\nstdout: ${stdout}\nstderr: ${stderr}`));
      }
    });
  });
}

function stopServer(child) {
  return new Promise((resolve) => {
    if (!child || child.exitCode !== null || child.signalCode !== null) {
      resolve();
      return;
    }
    const killTimer = setTimeout(() => {
      try { child.kill('SIGKILL'); } catch {}
    }, 2000);

    child.once('exit', () => {
      clearTimeout(killTimer);
      resolve();
    });

    try {
      child.kill('SIGTERM');
    } catch {
      clearTimeout(killTimer);
      resolve();
    }
  });
}

function requestHttp(port, { method = 'GET', path: reqPath = '/', headers = {}, body = null }) {
  return new Promise((resolve, reject) => {
    const startNs = process.hrtime.bigint();
    let ttfbNs = null;

    const req = http.request({
      host: '127.0.0.1',
      port,
      method,
      path: reqPath,
      headers
    }, (res) => {
      ttfbNs = process.hrtime.bigint();
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const endNs = process.hrtime.bigint();
        const buf = Buffer.concat(chunks);
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: buf,
          ttfbMs: Number(ttfbNs - startNs) / 1e6,
          totalMs: Number(endNs - startNs) / 1e6
        });
      });
    });

    req.on('error', reject);
    if (body !== null) {
      req.write(body);
    }
    req.end();
  });
}

function rawTcpRequest(port, rawPayload) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: '127.0.0.1', port }, () => {
      socket.write(rawPayload);
    });
    const chunks = [];
    socket.on('data', (c) => chunks.push(c));
    socket.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf8');
      const statusMatch = /^HTTP\/\d\.\d\s+(\d+)/.exec(text);
      resolve({
        raw: text,
        status: statusMatch ? Number(statusMatch[1]) : null
      });
    });
    socket.on('error', reject);
  });
}

function decodePayload(res) {
  const enc = (res.headers['content-encoding'] || '').toLowerCase();
  if (enc === 'br') return zlib.brotliDecompressSync(res.body);
  if (enc === 'gzip') return zlib.gunzipSync(res.body);
  return res.body;
}

function assertSecurityAndCorsHeaders(headers, label) {
  assert.strictEqual(
    headers['cross-origin-opener-policy'],
    'same-origin',
    `${label}: missing COOP same-origin`
  );
  assert.strictEqual(
    headers['cross-origin-embedder-policy'],
    'credentialless',
    `${label}: missing COEP credentialless`
  );
  assert.strictEqual(
    headers['access-control-allow-origin'],
    '*',
    `${label}: missing ACAO *`
  );
}

async function runSuiteA(port) {
  console.log('\n=== Suite A: Compression, Byte Counts & Cold/Warm Benchmarks ===');

  const routeDiskMap = {
    '/': path.join(WEB_DIR, 'index.html'),
    '/lesnik': LESNIK_PATH,
    '/lesnik.html': LESNIK_PATH,
    '/flutter_bootstrap.js': path.join(WEB_DIR, 'flutter_bootstrap.js'),
    '/main.dart.js': path.join(WEB_DIR, 'main.dart.js'),
    '/canvaskit/canvaskit.wasm': path.join(WEB_DIR, 'canvaskit', 'canvaskit.wasm'),
    '/assets/NOTICES': path.join(WEB_DIR, 'assets', 'NOTICES'),
    '/manifest.json': path.join(WEB_DIR, 'manifest.json'),
    '/version.json': path.join(WEB_DIR, 'version.json'),
    '/assets/mushrooms/borowik_szlachetny.webp': path.join(WEB_DIR, 'assets', 'mushrooms', 'borowik_szlachetny.webp'),
    '/icons/Icon-192.png': path.join(WEB_DIR, 'icons', 'Icon-192.png')
  };

  const compressibleRoutes = [
    '/',
    '/lesnik',
    '/lesnik.html',
    '/api/reports',
    '/flutter_bootstrap.js',
    '/main.dart.js',
    '/canvaskit/canvaskit.wasm',
    '/assets/NOTICES',
    '/manifest.json'
  ];

  const benchRows = [];

  for (const route of compressibleRoutes) {
    let expectedRaw;
    if (route === '/api/reports') {
      const reportsArr = JSON.parse(fs.readFileSync(REPORTS_PATH, 'utf8'));
      expectedRaw = Buffer.from(JSON.stringify(reportsArr), 'utf8');
    } else {
      expectedRaw = fs.readFileSync(routeDiskMap[route]);
    }
    const expectedHash = sha256(expectedRaw);

    // Cold br
    const coldRes = await requestHttp(port, {
      path: route,
      headers: { 'Accept-Encoding': 'br, gzip, deflate' }
    });
    assert.strictEqual(coldRes.status, 200, `${route} cold status`);
    assert.strictEqual(coldRes.headers['content-encoding'], 'br', `${route} expected br encoding`);
    assert.ok(String(coldRes.headers['vary'] || '').toLowerCase().includes('accept-encoding'), `${route} missing Vary: Accept-Encoding`);
    assert.strictEqual(sha256(decodePayload(coldRes)), expectedHash, `${route} br decompressed hash mismatch`);
    assert.ok(coldRes.body.length < expectedRaw.length, `${route} br wireBytes (${coldRes.body.length}) not < rawBytes (${expectedRaw.length})`);

    // Warm br
    const warmRes = await requestHttp(port, {
      path: route,
      headers: { 'Accept-Encoding': 'br, gzip, deflate' }
    });
    assert.strictEqual(warmRes.status, 200, `${route} warm status`);
    assert.strictEqual(warmRes.headers['content-encoding'], 'br', `${route} warm br encoding`);

    // Gzip
    const gzipRes = await requestHttp(port, {
      path: route,
      headers: { 'Accept-Encoding': 'gzip' }
    });
    assert.strictEqual(gzipRes.status, 200, `${route} gzip status`);
    assert.strictEqual(gzipRes.headers['content-encoding'], 'gzip', `${route} expected gzip encoding`);
    assert.strictEqual(sha256(decodePayload(gzipRes)), expectedHash, `${route} gzip decompressed hash mismatch`);

    // Identity
    const idRes = await requestHttp(port, {
      path: route,
      headers: { 'Accept-Encoding': 'identity' }
    });
    assert.strictEqual(idRes.status, 200, `${route} identity status`);
    assert.strictEqual(idRes.headers['content-encoding'], undefined, `${route} identity must omit Content-Encoding`);
    assert.strictEqual(idRes.body.length, expectedRaw.length, `${route} identity wireBytes mismatch`);

    const savedPct = ((1 - coldRes.body.length / expectedRaw.length) * 100).toFixed(1);
    benchRows.push({
      route,
      enc: 'br',
      rawBytes: expectedRaw.length,
      wireBytes: coldRes.body.length,
      savedPct: `${savedPct}%`,
      coldTtfbMs: coldRes.ttfbMs.toFixed(2),
      coldTotalMs: coldRes.totalMs.toFixed(2),
      warmTtfbMs: warmRes.ttfbMs.toFixed(2),
      warmTotalMs: warmRes.totalMs.toFixed(2)
    });
  }

  // Small payload < 256 B (/version.json) must skip compression
  const versionRaw = fs.readFileSync(routeDiskMap['/version.json']);
  assert.ok(versionRaw.length < 256, '/version.json expected < 256 B');
  const versionRes = await requestHttp(port, {
    path: '/version.json',
    headers: { 'Accept-Encoding': 'br, gzip, deflate' }
  });
  assert.strictEqual(versionRes.status, 200);
  assert.strictEqual(versionRes.headers['content-encoding'], undefined, '/version.json (<256B) must NOT be compressed');
  assert.strictEqual(versionRes.body.length, versionRaw.length, '/version.json byte count mismatch');
  benchRows.push({
    route: '/version.json',
    enc: 'identity (<256B)',
    rawBytes: versionRaw.length,
    wireBytes: versionRes.body.length,
    savedPct: '0.0%',
    coldTtfbMs: versionRes.ttfbMs.toFixed(2),
    coldTotalMs: versionRes.totalMs.toFixed(2),
    warmTtfbMs: '-',
    warmTotalMs: '-'
  });

  // Pre-compressed binary assets must skip compression
  const binaryRoutes = ['/assets/mushrooms/borowik_szlachetny.webp', '/icons/Icon-192.png'];
  for (const route of binaryRoutes) {
    const raw = fs.readFileSync(routeDiskMap[route]);
    const res = await requestHttp(port, {
      path: route,
      headers: { 'Accept-Encoding': 'br, gzip, deflate' }
    });
    assert.strictEqual(res.status, 200, `${route} status`);
    assert.strictEqual(res.headers['content-encoding'], undefined, `${route} binary must NOT have Content-Encoding`);
    assert.strictEqual(res.body.length, raw.length, `${route} binary wireBytes mismatch`);
    benchRows.push({
      route,
      enc: 'identity (binary)',
      rawBytes: raw.length,
      wireBytes: res.body.length,
      savedPct: '0.0%',
      coldTtfbMs: res.ttfbMs.toFixed(2),
      coldTotalMs: res.totalMs.toFixed(2),
      warmTtfbMs: '-',
      warmTotalMs: '-'
    });
  }

  // Parallel 5-request burst
  const burstStart = process.hrtime.bigint();
  const burstResults = await Promise.all([
    requestHttp(port, { path: '/lesnik', headers: { 'Accept-Encoding': 'br, gzip' } }),
    requestHttp(port, { path: '/api/reports', headers: { 'Accept-Encoding': 'br, gzip' } }),
    requestHttp(port, { path: '/api/reports', headers: { 'Accept-Encoding': 'br, gzip' } }),
    requestHttp(port, { path: '/main.dart.js', headers: { 'Accept-Encoding': 'br, gzip' } }),
    requestHttp(port, { path: '/flutter_bootstrap.js', headers: { 'Accept-Encoding': 'br, gzip' } })
  ]);
  const burstMs = (Number(process.hrtime.bigint() - burstStart) / 1e6).toFixed(2);
  for (const r of burstResults) {
    assert.strictEqual(r.status, 200, 'Burst request failed');
  }

  console.table(benchRows);
  console.log(`Parallel 5-request burst wall time: ${burstMs} ms`);
  console.log('Suite A PASSED');
}

async function runSuiteB(port) {
  console.log('\n=== Suite B: Caching, 304, Security Headers, HEAD, Range & Hardening ===');

  // 1. Cache-Control & ETag policy
  const noCacheRoutes = [
    '/',
    '/lesnik',
    '/lesnik.html',
    '/flutter_bootstrap.js',
    '/flutter_service_worker.js',
    '/version.json',
    '/manifest.json',
    '/main.dart.js',
    '/api/reports'
  ];
  for (const route of noCacheRoutes) {
    const res = await requestHttp(port, { path: route, headers: { 'Accept-Encoding': 'br, gzip' } });
    assert.strictEqual(res.status, 200, `${route} status`);
    assert.ok(String(res.headers['cache-control'] || '').includes('no-cache'), `${route} expected no-cache, got ${res.headers['cache-control']}`);
    assert.ok(res.headers['etag'], `${route} missing ETag`);
    assert.ok(res.headers['last-modified'], `${route} missing Last-Modified`);
    assertSecurityAndCorsHeaders(res.headers, route);
  }

  const longCacheRoutes = [
    { path: '/canvaskit/canvaskit.wasm', minMaxAge: 604800 },
    { path: '/assets/NOTICES', minMaxAge: 604800 },
    { path: '/assets/mushrooms/borowik_szlachetny.webp', minMaxAge: 604800 },
    { path: '/icons/Icon-192.png', minMaxAge: 86400 }
  ];
  for (const item of longCacheRoutes) {
    const res = await requestHttp(port, { path: item.path, headers: { 'Accept-Encoding': 'br, gzip' } });
    assert.strictEqual(res.status, 200, `${item.path} status`);
    const cc = String(res.headers['cache-control'] || '');
    assert.ok(cc.includes('public'), `${item.path} Cache-Control missing public: ${cc}`);
    const match = /max-age=(\d+)/.exec(cc);
    assert.ok(match && Number(match[1]) >= item.minMaxAge, `${item.path} max-age < ${item.minMaxAge}: ${cc}`);
    assert.ok(res.headers['etag'], `${item.path} missing ETag`);
    assert.ok(res.headers['last-modified'], `${item.path} missing Last-Modified`);
  }

  // 2. Encoding-qualified ETag & 304 Not Modified
  const etagRoutes = ['/', '/lesnik', '/main.dart.js', '/canvaskit/canvaskit.wasm', '/api/reports'];
  for (const route of etagRoutes) {
    const brRes = await requestHttp(port, { path: route, headers: { 'Accept-Encoding': 'br' } });
    const gzRes = await requestHttp(port, { path: route, headers: { 'Accept-Encoding': 'gzip' } });
    const idRes = await requestHttp(port, { path: route, headers: { 'Accept-Encoding': 'identity' } });
    assert.notStrictEqual(brRes.headers['etag'], gzRes.headers['etag'], `${route} br and gzip ETags must differ`);
    assert.notStrictEqual(brRes.headers['etag'], idRes.headers['etag'], `${route} br and identity ETags must differ`);

    const condRes = await requestHttp(port, {
      path: route,
      headers: {
        'Accept-Encoding': 'br, gzip',
        'If-None-Match': brRes.headers['etag']
      }
    });
    assert.strictEqual(condRes.status, 304, `${route} expected 304`);
    assert.strictEqual(condRes.body.length, 0, `${route} 304 must have 0 body bytes`);
    assertSecurityAndCorsHeaders(condRes.headers, `${route} 304`);
  }

  // 3. OPTIONS preflight
  const optRes = await requestHttp(port, { method: 'OPTIONS', path: '/api/reports' });
  assert.strictEqual(optRes.status, 204, 'OPTIONS expected 204');
  assert.strictEqual(optRes.body.length, 0, 'OPTIONS expected 0 bytes');
  assertSecurityAndCorsHeaders(optRes.headers, 'OPTIONS /api/reports');
  assert.ok(String(optRes.headers['access-control-allow-methods'] || '').includes('PATCH'), 'OPTIONS missing PATCH');

  // 4. HEAD requests
  for (const route of ['/main.dart.js', '/lesnik', '/api/reports']) {
    const getRes = await requestHttp(port, { path: route, headers: { 'Accept-Encoding': 'br' } });
    const headRes = await requestHttp(port, { method: 'HEAD', path: route, headers: { 'Accept-Encoding': 'br' } });
    assert.strictEqual(headRes.status, 200, `HEAD ${route} expected 200`);
    assert.strictEqual(headRes.body.length, 0, `HEAD ${route} must return 0 body bytes`);
    assert.strictEqual(headRes.headers['content-type'], getRes.headers['content-type'], `HEAD ${route} Content-Type mismatch`);
    assert.strictEqual(Number(headRes.headers['content-length']), getRes.body.length, `HEAD ${route} Content-Length mismatch`);
  }

  // 5. Range requests (206 & 416)
  const mainJsRaw = fs.readFileSync(path.join(WEB_DIR, 'main.dart.js'));
  const rangeMain = await requestHttp(port, {
    path: '/main.dart.js',
    headers: { 'Accept-Encoding': 'br, gzip', 'Range': 'bytes=0-1023' }
  });
  assert.strictEqual(rangeMain.status, 206, 'Range main.dart.js expected 206');
  assert.strictEqual(rangeMain.headers['content-encoding'], undefined, 'Range response must be uncompressed identity');
  assert.strictEqual(rangeMain.headers['content-range'], `bytes 0-1023/${mainJsRaw.length}`);
  assert.strictEqual(rangeMain.body.length, 1024);
  assert.ok(rangeMain.body.equals(mainJsRaw.subarray(0, 1024)), 'Range main.dart.js bytes mismatch');

  const webpRaw = fs.readFileSync(path.join(WEB_DIR, 'assets', 'mushrooms', 'borowik_szlachetny.webp'));
  const rangeWebp = await requestHttp(port, {
    path: '/assets/mushrooms/borowik_szlachetny.webp',
    headers: { 'Accept-Encoding': 'identity', 'Range': 'bytes=0-1023' }
  });
  assert.strictEqual(rangeWebp.status, 206);
  assert.strictEqual(rangeWebp.headers['content-range'], `bytes 0-1023/${webpRaw.length}`);
  assert.ok(rangeWebp.body.equals(webpRaw.subarray(0, 1024)), 'Range webp bytes mismatch');

  const rangeSuffix = await requestHttp(port, {
    path: '/assets/mushrooms/borowik_szlachetny.webp',
    headers: { 'Accept-Encoding': 'identity', 'Range': 'bytes=-128' }
  });
  assert.strictEqual(rangeSuffix.status, 206);
  assert.strictEqual(rangeSuffix.body.length, 128);
  assert.ok(rangeSuffix.body.equals(webpRaw.subarray(webpRaw.length - 128)), 'Suffix range bytes mismatch');

  const rangeOob = await requestHttp(port, {
    path: '/main.dart.js',
    headers: { 'Accept-Encoding': 'identity', 'Range': 'bytes=99999999-' }
  });
  assert.strictEqual(rangeOob.status, 416, 'Out-of-bounds Range expected 416');
  assert.strictEqual(rangeOob.headers['content-range'], `bytes */${mainJsRaw.length}`);

  // 6. Routing & Security Hardening
  const missingJs = await requestHttp(port, { path: '/nonexistent.js' });
  assert.strictEqual(missingJs.status, 404);
  assert.ok(String(missingJs.headers['content-type'] || '').includes('text/plain'));
  assertSecurityAndCorsHeaders(missingJs.headers, '404 /nonexistent.js');

  const indexRaw = fs.readFileSync(path.join(WEB_DIR, 'index.html'));
  const spaRes = await requestHttp(port, { path: '/some-spa-route', headers: { 'Accept-Encoding': 'identity' } });
  assert.strictEqual(spaRes.status, 200);
  assert.ok(String(spaRes.headers['content-type'] || '').includes('text/html'));
  assert.strictEqual(sha256(spaRes.body), sha256(indexRaw), 'SPA fallback body mismatch');

  for (const trav of ['/%2e%2e/%2e%2e/package.json', '/..%5c..%5cpackage.json', '/assets/..%2f..%2fserver.cjs']) {
    const r = await requestHttp(port, { path: trav });
    assert.ok(r.status === 400 || r.status === 404, `Traversal ${trav} returned ${r.status}`);
  }
  const rawTrav = await rawTcpRequest(port, 'GET /../../package.json HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
  assert.ok(rawTrav.status === 400 || rawTrav.status === 404, `Raw TCP traversal returned ${rawTrav.status}`);

  // Malformed & missing Host headers -> 400 without crashing server
  const badHost = await rawTcpRequest(port, 'GET / HTTP/1.1\r\nHost: bad host:!!\r\nConnection: close\r\n\r\n');
  assert.strictEqual(badHost.status, 400, `Malformed Host expected 400, got ${badHost.status}`);
  const missingHost = await rawTcpRequest(port, 'GET / HTTP/1.1\r\nConnection: close\r\n\r\n');
  assert.strictEqual(missingHost.status, 400, `Missing Host expected 400, got ${missingHost.status}`);

  const badPercent = await requestHttp(port, { path: '/%ZZ' });
  assert.strictEqual(badPercent.status, 400, 'Malformed URI encoding expected 400');
  assertSecurityAndCorsHeaders(badPercent.headers, '400 /%ZZ');

  // Invalid JSON
  const badPost = await requestHttp(port, {
    method: 'POST',
    path: '/api/reports',
    headers: { 'Content-Type': 'application/json' },
    body: '{bad'
  });
  assert.strictEqual(badPost.status, 400);

  const badPatch = await requestHttp(port, {
    method: 'PATCH',
    path: '/api/reports/rep-001',
    headers: { 'Content-Type': 'application/json' },
    body: '{bad'
  });
  assert.strictEqual(badPatch.status, 400);

  // Oversized body (> 10 MB) -> 413
  const bigStr = 'a'.repeat(Math.floor(10.5 * 1024 * 1024));
  const bigPayload = Buffer.from(`{"description":"${bigStr}"}`, 'utf8');
  let bigStatus = null;
  try {
    const bigRes = await requestHttp(port, {
      method: 'POST',
      path: '/api/reports',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': bigPayload.length
      },
      body: bigPayload
    });
    bigStatus = bigRes.status;
  } catch (err) {
    // If server closed socket immediately after sending 413 while writing body, retry reading response
    throw err;
  }
  assert.strictEqual(bigStatus, 413, `Oversized body expected 413, got ${bigStatus}`);

  // Confirm server still healthy
  const healthRes = await requestHttp(port, { path: '/api/reports' });
  assert.strictEqual(healthRes.status, 200, 'Server unhealthy after 400/413 probes');

  console.log('Suite B PASSED');
}

async function runSuiteC(port) {
  console.log('\n=== Suite C: /api/reports Roundtrip & Concurrency ===');

  const r0 = await requestHttp(port, { path: '/api/reports', headers: { 'Accept-Encoding': 'br' } });
  assert.strictEqual(r0.status, 200);
  const etag0 = r0.headers['etag'];
  const list0 = JSON.parse(decodePayload(r0).toString('utf8'));
  assert.ok(Array.isArray(list0));
  const baseCount = list0.length;

  // POST new report
  const postRes = await requestHttp(port, {
    method: 'POST',
    path: '/api/reports',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      category: 'fallen_tree',
      latitude: 52.05,
      longitude: 21.37,
      nadlesnictwo: 'Test',
      oddzial: '1a',
      description: 'Verify M1'
    })
  });
  assert.strictEqual(postRes.status, 201);
  const postJson = JSON.parse(postRes.body.toString('utf8'));
  assert.strictEqual(postJson.success, true);
  assert.ok(postJson.report && postJson.report.id);
  assert.ok(postJson.report.createdAt);
  assert.strictEqual(postJson.report.status, 'pending');
  assert.strictEqual(postJson.report.confirmationsCount, 1);

  const r1 = await requestHttp(port, { path: '/api/reports', headers: { 'Accept-Encoding': 'br' } });
  assert.strictEqual(r1.status, 200);
  const etag1 = r1.headers['etag'];
  assert.notStrictEqual(etag1, etag0, 'ETag must change after POST');
  const list1 = JSON.parse(decodePayload(r1).toString('utf8'));
  assert.strictEqual(list1.length, baseCount + 1);
  assert.strictEqual(list1[0].id, postJson.report.id);

  // PATCH report
  const patchRes = await requestHttp(port, {
    method: 'PATCH',
    path: `/api/reports/${encodeURIComponent(postJson.report.id)}`,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      status: 'resolved',
      notes: 'Cleared',
      confirmationsCount: 2
    })
  });
  assert.strictEqual(patchRes.status, 200);
  const patchJson = JSON.parse(patchRes.body.toString('utf8'));
  assert.strictEqual(patchJson.success, true);
  assert.strictEqual(patchJson.report.status, 'resolved');
  assert.strictEqual(patchJson.report.notes, 'Cleared');
  assert.strictEqual(patchJson.report.confirmationsCount, 2);
  assert.ok(patchJson.report.resolvedAt);

  const r2 = await requestHttp(port, { path: '/api/reports', headers: { 'Accept-Encoding': 'br' } });
  assert.notStrictEqual(r2.headers['etag'], etag1, 'ETag must change after PATCH');

  // PATCH nonexistent -> 404
  const patchMissing = await requestHttp(port, {
    method: 'PATCH',
    path: '/api/reports/nonexistent-id-999',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status: 'resolved' })
  });
  assert.strictEqual(patchMissing.status, 404);

  // 10 concurrent POSTs
  const concPayloads = Array.from({ length: 10 }, (_, i) => ({
    id: `conc-${i}`,
    category: 'trash',
    latitude: 52.05 + i * 0.001,
    longitude: 21.37 + i * 0.001,
    nadlesnictwo: 'Test',
    oddzial: `${i}b`,
    description: `Concurrent ${i}`
  }));

  const concResponses = await Promise.all(
    concPayloads.map((p) => requestHttp(port, {
      method: 'POST',
      path: '/api/reports',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(p)
    }))
  );
  for (const res of concResponses) {
    assert.strictEqual(res.status, 201, 'Concurrent POST failed');
  }

  const r3 = await requestHttp(port, { path: '/api/reports', headers: { 'Accept-Encoding': 'identity' } });
  const list3 = JSON.parse(r3.body.toString('utf8'));
  assert.strictEqual(list3.length, baseCount + 11, 'Concurrent POST count mismatch');
  for (let i = 0; i < 10; i++) {
    assert.ok(list3.some((item) => item.id === `conc-${i}`), `Missing conc-${i} in GET`);
  }

  const diskArr = JSON.parse(fs.readFileSync(REPORTS_PATH, 'utf8'));
  assert.strictEqual(diskArr.length, baseCount + 11, 'Disk reports.json count mismatch');

  const tmpFiles = fs.readdirSync(DATA_DIR).filter((f) => f.includes('.tmp'));
  assert.strictEqual(tmpFiles.length, 0, `Stray .tmp files found: ${tmpFiles.join(', ')}`);

  console.log('Suite C PASSED');
}

function runSuiteD() {
  console.log('\n=== Suite D: grzybmap_app/web/lesnik.html Syntax, Parity, Security & Optimizations ===');
  const html = fs.readFileSync(LESNIK_PATH, 'utf8');

  // 1. Inline <script> vm.Script syntax check
  const scriptRegex = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
  let scriptCount = 0;
  let match;
  while ((match = scriptRegex.exec(html)) !== null) {
    scriptCount++;
    new vm.Script(match[1], { filename: `lesnik.html#inline-${scriptCount}` });
  }
  assert.ok(scriptCount >= 1, 'Expected at least 1 inline <script> in lesnik.html');

  // 2. DOM & Functional Parity
  const requiredIds = [
    'header-sync-time', 'map', 'btn-layer-osm', 'btn-layer-satellite', 'btn-layer-topo',
    'bdl-checkbox', 'zones-checkbox', 'coords-display', 'results-count-label',
    'pill-filter-all', 'pill-filter-pending', 'pill-filter-in_progress', 'pill-filter-resolved',
    'stat-total', 'stat-pending', 'stat-in_progress', 'stat-resolved',
    'search-query', 'reports-container', 'photo-modal', 'modal-title', 'modal-img',
    'modal-meta-info', 'modal-notes-input', 'new-report-modal', 'new-category',
    'new-nadlesnictwo', 'new-oddzial', 'new-lat', 'new-lng', 'new-desc', 'toast', 'toast-msg'
  ];
  for (const id of requiredIds) {
    assert.ok(html.includes(`id="${id}"`), `Missing DOM id="${id}"`);
  }

  assert.ok(html.includes('integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="'), 'Missing Leaflet CSS SRI');
  assert.ok(html.includes('integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="'), 'Missing Leaflet JS SRI');
  for (const color of ['#060C08', '#0D1711', '#34D399']) {
    assert.ok(html.includes(color), `Missing palette color ${color}`);
  }
  for (const hook of ['openNewReportModal', 'fitAllMarkers', 'exportGPX', 'exportCSV', 'href="/"']) {
    assert.ok(html.includes(hook), `Missing functional hook ${hook}`);
  }

  // 3. XSS Security Checks (static + live vm execution of card/popup/sanitizer functions)
  assert.ok(!html.includes('${r.nadlesnictwo}'), 'Unescaped ${r.nadlesnictwo} found');
  assert.ok(!html.includes('${r.oddzial}'), 'Unescaped ${r.oddzial} found');
  assert.ok(html.includes('escapeHtml(r.nadlesnictwo'), 'Missing escapeHtml(r.nadlesnictwo)');
  assert.ok(html.includes('escapeHtml(r.oddzial'), 'Missing escapeHtml(r.oddzial)');
  assert.ok(html.includes('escapeHtml(r.id)'), 'Missing escapeHtml(r.id)');
  assert.ok(html.includes('sanitizeImageSrc('), 'Missing sanitizeImageSrc');
  assert.ok(html.includes('rel="noopener noreferrer"'), 'Missing rel="noopener noreferrer"');

  // Execute inline script in a lightweight DOM-stubbed vm context to verify XSS escaping
  const inlineScripts = [];
  let m;
  const re2 = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
  while ((m = re2.exec(html)) !== null) inlineScripts.push(m[1]);
  const sandbox = {
    window: { addEventListener: () => {} },
    document: { addEventListener: () => {} },
    L: { divIcon: (opts) => opts },
    console
  };
  vm.runInNewContext(inlineScripts.join('\n'), sandbox);

  const xssReport = {
    id: 'x" onclick="alert(1)',
    category: 'fallen_tree',
    nadlesnictwo: '<img src=x onerror=alert(1)>',
    oddzial: '<script>evil()</script>',
    status: '"><svg onload=alert(1)>',
    description: '<b>desc</b>',
    notes: '<script>n</script>',
    photoUrl: 'javascript:alert(1)',
    latitude: 'bad',
    longitude: null,
    confirmationsCount: '<script>9</script>',
    createdAt: '2026-11-25T10:00:00.000Z'
  };
  const cardHtml = sandbox.buildCardInnerHtml(xssReport);
  const popupHtml = sandbox.buildMarkerPopupHtml(xssReport);
  const iconSpec = sandbox.buildMarkerIcon(xssReport);
  for (const out of [cardHtml, popupHtml, iconSpec.html]) {
    assert.ok(!out.includes('<img '), 'Unescaped <img tag rendered');
    assert.ok(!out.includes('<script>'), 'Unescaped <script> tag rendered');
    assert.ok(!out.includes('<svg onload'), 'Unescaped <svg onload rendered');
    assert.ok(!out.includes('onclick="alert'), 'Unescaped onclick handler rendered');
  }
  assert.ok(cardHtml.includes('&lt;img src=x onerror=alert(1)&gt;'), 'Expected escaped nadlesnictwo in cardHtml');
  assert.ok(cardHtml.includes('&lt;script&gt;evil()&lt;/script&gt;'), 'Expected escaped oddzial in cardHtml');
  assert.ok(popupHtml.includes('&lt;img src=x onerror=alert(1)&gt;'), 'Expected escaped nadlesnictwo in popupHtml');
  assert.ok(!sandbox.sanitizeImageSrc('javascript:alert(1)').startsWith('javascript:'), 'sanitizeImageSrc allowed javascript: URL');
  assert.strictEqual(sandbox.sanitizeImageSrc('data:image/png;base64,AAAA'), 'data:image/png;base64,AAAA');
  assert.strictEqual(sandbox.sanitizeStatusClass('"><svg onload=alert(1)>'), 'status-pending');

  // 4. Optimization Checks
  assert.ok(html.includes('<link rel="preconnect" href="https://unpkg.com" crossorigin>'), 'Missing preconnect');
  assert.ok(/<script\s+defer\s+src="https:\/\/unpkg\.com\/leaflet@1\.9\.4/.test(html), 'Missing defer on Leaflet script');
  assert.ok(html.includes('DOMContentLoaded'), 'Missing DOMContentLoaded bootstrap');
  assert.ok(html.includes('document.hidden'), 'Missing document.hidden check');
  assert.ok(html.includes('visibilitychange'), 'Missing visibilitychange listener');
  assert.ok(html.includes('AbortController'), 'Missing AbortController');
  assert.ok(html.includes('If-None-Match'), 'Missing If-None-Match');
  assert.ok(html.includes('res.status === 304'), 'Missing 304 handling');
  assert.ok(html.includes('searchDebounceTimer'), 'Missing search debounce');
  assert.ok(html.includes('markerById') && !html.includes('markersGroup.clearLayers()'), 'Expected incremental marker reconciliation without markersGroup.clearLayers()');
  assert.ok(html.includes('cardById'), 'Missing incremental cardById reconciliation');
  assert.ok(html.includes('sharedAudioCtx'), 'Missing single reused AudioContext');
  assert.ok(html.includes('requestAnimationFrame'), 'Missing requestAnimationFrame mousemove throttle');

  const styleMatch = /<style>([\s\S]*?)<\/style>/i.exec(html);
  assert.ok(styleMatch, 'Missing <style> block');
  assert.ok(!/transition\s*:\s*all\b/i.test(styleMatch[1]), 'Found forbidden transition: all in <style>');
  assert.ok(styleMatch[1].includes('visibility: hidden'), 'Missing visibility: hidden on .modal-overlay');
  assert.ok(!/reports\.filter\([^)]*status\s*===/.test(html), 'Expected single-pass renderMetrics() without triple reports.filter');

  console.log(`Suite D PASSED (${scriptCount} inline script parsed cleanly)`);
}

async function main() {
  const reportsOriginal = fs.existsSync(REPORTS_PATH) ? fs.readFileSync(REPORTS_PATH) : null;
  const origSha256 = reportsOriginal ? sha256(reportsOriginal) : null;
  const port = await getFreePort();
  let child = null;

  try {
    console.log(`Starting verify_m1 against ephemeral port ${port}...`);
    child = await startServer(port);
    await runSuiteA(port);
    await runSuiteB(port);
    await runSuiteC(port);
    runSuiteD();
    console.log('\nALL M1 VERIFICATION SUITES (A, B, C, D) PASSED');
  } finally {
    await stopServer(child);

    if (fs.existsSync(DATA_DIR)) {
      for (const name of fs.readdirSync(DATA_DIR)) {
        if (name.includes('.tmp')) {
          try { fs.unlinkSync(path.join(DATA_DIR, name)); } catch {}
        }
      }
    }

    if (reportsOriginal !== null) {
      fs.writeFileSync(REPORTS_PATH, reportsOriginal);
      const restoredHash = sha256(fs.readFileSync(REPORTS_PATH));
      assert.strictEqual(restoredHash, origSha256, 'Failed to restore reports.json cleanly!');
    } else if (fs.existsSync(REPORTS_PATH)) {
      fs.unlinkSync(REPORTS_PATH);
    }
  }
}

main().catch((err) => {
  console.error('\nVERIFY_M1 FAILED:', err);
  process.exitCode = 1;
});
