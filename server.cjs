const http = require('http');
const https = require('https');
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');
const { promisify } = require('util');

const brotliCompressAsync = promisify(zlib.brotliCompress);
const gzipAsync = promisify(zlib.gzip);

const PORT = process.env.PORT || 8088;
function resolveExisting(paths, fallback) {
  for (const p of paths) {
    if (fs.existsSync(p)) return p;
  }
  return fallback;
}

const CANDIDATE_WEB_DIRS = [
  path.resolve(__dirname, 'build', 'web'),
  path.resolve(__dirname, 'grzybmap_app', 'build', 'web'),
];
const WEB_DIR = resolveExisting(CANDIDATE_WEB_DIRS, CANDIDATE_WEB_DIRS[0]);
const WEB_PREFIX = WEB_DIR.endsWith(path.sep) ? WEB_DIR : WEB_DIR + path.sep;

const CANDIDATE_LESNIK = [
  path.resolve(WEB_DIR, 'lesnik.html'),
  path.resolve(__dirname, 'web', 'lesnik.html'),
  path.resolve(__dirname, 'grzybmap_app', 'web', 'lesnik.html'),
];
const LESNIK_PATH = resolveExisting(CANDIDATE_LESNIK, path.resolve(WEB_DIR, 'lesnik.html'));

const CANDIDATE_REPORTS = [
  path.resolve(__dirname, 'data', 'reports.json'),
  path.resolve(__dirname, 'grzybmap_app', 'data', 'reports.json'),
];
const REPORTS_FILE = resolveExisting(CANDIDATE_REPORTS, path.resolve(__dirname, 'data', 'reports.json'));

const MIN_COMPRESS_BYTES = 256;
const MAX_CACHEABLE_FILE_BYTES = 16 * 1024 * 1024; // 16 MB
const MAX_STATIC_CACHE_BYTES = 48 * 1024 * 1024; // 48 MB
const MAX_JSON_BODY_BYTES = 10 * 1024 * 1024; // 10 MB

const BROTLI_OPTIONS = {
  params: {
    [zlib.constants.BROTLI_PARAM_QUALITY]: 4
  }
};
const GZIP_OPTIONS = { level: 6 };

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.apk': 'application/vnd.android.package-archive',
  '.symbols': 'text/plain; charset=utf-8',
  '.frag': 'text/plain; charset=utf-8',
  '.bin': 'application/octet-stream',
  '.last_build_id': 'text/plain; charset=utf-8'
};

const COMPRESSIBLE_EXTS = new Set([
  '.html',
  '.js',
  '.mjs',
  '.css',
  '.json',
  '.svg',
  '.wasm',
  '.symbols',
  '.frag'
]);

const NO_CACHE_BASENAMES = new Set([
  'index.html',
  'lesnik.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'flutter_service_worker.js',
  'version.json',
  'manifest.json',
  '.last_build_id',
  'main.dart.js'
]);

function isCompressibleFile(filePath) {
  const base = path.basename(filePath);
  if (base === 'NOTICES' || base === '.last_build_id') return true;
  const ext = path.extname(filePath).toLowerCase();
  return COMPRESSIBLE_EXTS.has(ext);
}

function getContentType(filePath) {
  const base = path.basename(filePath);
  if (base === 'NOTICES') return 'text/plain; charset=utf-8';
  if (base === '.last_build_id') return 'text/plain; charset=utf-8';
  const ext = path.extname(filePath).toLowerCase();
  return MIME_TYPES[ext] || 'application/octet-stream';
}

function getStaticCacheControl(relPath, filePath) {
  const normalized = relPath.replace(/\\/g, '/').replace(/^\/+/, '');
  const base = path.basename(filePath);
  const ext = path.extname(filePath).toLowerCase();

  if (ext === '.html' || ext === '.apk' || NO_CACHE_BASENAMES.has(base)) {
    return 'no-cache';
  }
  if (normalized.startsWith('canvaskit/') || normalized.startsWith('assets/')) {
    return 'public, max-age=604800';
  }
  if (normalized.startsWith('icons/') || normalized === 'favicon.png') {
    return 'public, max-age=86400';
  }
  return 'no-cache';
}

function negotiateEncoding(req) {
  const header = req.headers['accept-encoding'];
  if (!header || typeof header !== 'string') return 'identity';

  let brQ = 0;
  let gzipQ = 0;
  const parts = header.split(',');
  for (let i = 0; i < parts.length; i++) {
    const rawPart = parts[i].trim();
    if (!rawPart) continue;
    const segments = rawPart.split(';');
    const name = segments[0].trim().toLowerCase();
    let q = 1;
    for (let j = 1; j < segments.length; j++) {
      const param = segments[j].trim().toLowerCase();
      if (param.startsWith('q=')) {
        const parsed = parseFloat(param.slice(2));
        if (!Number.isNaN(parsed)) {
          q = Math.max(0, Math.min(1, parsed));
        }
      }
    }
    if (name === 'br' && q > brQ) brQ = q;
    else if (name === 'gzip' && q > gzipQ) gzipQ = q;
  }

  if (brQ > 0 && brQ >= gzipQ) return 'br';
  if (gzipQ > 0) return 'gzip';
  return 'identity';
}

function makeEtag(baseEtag, encoding) {
  if (encoding === 'br') return `"${baseEtag}-br"`;
  if (encoding === 'gzip') return `"${baseEtag}-gzip"`;
  return `"${baseEtag}"`;
}

function isNotModified(req, etag, mtimeMs) {
  const inm = req.headers['if-none-match'];
  if (typeof inm === 'string' && inm.trim() !== '') {
    const tokens = inm.split(',');
    for (let i = 0; i < tokens.length; i++) {
      let token = tokens[i].trim();
      if (token === '*') return true;
      if (token.startsWith('W/')) token = token.slice(2).trim();
      if (token === etag) return true;
    }
    return false;
  }

  const ims = req.headers['if-modified-since'];
  if (typeof ims === 'string' && ims.trim() !== '') {
    const imsMs = Date.parse(ims);
    if (!Number.isNaN(imsMs) && Math.floor(mtimeMs / 1000) * 1000 <= imsMs) {
      return true;
    }
  }
  return false;
}

function parseByteRange(rangeHeader, totalSize) {
  if (!rangeHeader || typeof rangeHeader !== 'string') return { kind: 'none' };
  const trimmed = rangeHeader.trim();
  if (!trimmed.toLowerCase().startsWith('bytes=')) return { kind: 'none' };
  const spec = trimmed.slice(6).trim();
  if (spec.includes(',')) return { kind: 'none' }; // multi-range falls back to 200 full body

  if (totalSize <= 0) return { kind: 'invalid' };

  const match = /^(\d*)-(\d*)$/.exec(spec);
  if (!match) return { kind: 'invalid' };

  const startStr = match[1];
  const endStr = match[2];
  if (startStr === '' && endStr === '') return { kind: 'invalid' };

  if (startStr === '') {
    const suffixLen = Number(endStr);
    if (!Number.isSafeInteger(suffixLen) || suffixLen <= 0) return { kind: 'invalid' };
    const start = Math.max(0, totalSize - suffixLen);
    const end = totalSize - 1;
    return { kind: 'range', start, end };
  }

  const start = Number(startStr);
  if (!Number.isSafeInteger(start) || start < 0 || start >= totalSize) {
    return { kind: 'invalid' };
  }

  if (endStr === '') {
    return { kind: 'range', start, end: totalSize - 1 };
  }

  const end = Math.min(Number(endStr), totalSize - 1);
  if (!Number.isSafeInteger(end) || end < start) {
    return { kind: 'invalid' };
  }
  return { kind: 'range', start, end };
}

async function compressBuffer(rawBuf, encoding) {
  if (encoding === 'br') return brotliCompressAsync(rawBuf, BROTLI_OPTIONS);
  if (encoding === 'gzip') return gzipAsync(rawBuf, GZIP_OPTIONS);
  return rawBuf;
}

// --- Bounded LRU Static File Cache ---
const staticCache = new Map();
let totalStaticCacheBytes = 0;

function touchStaticEntry(key, entry) {
  staticCache.delete(key);
  staticCache.set(key, entry);
}

function evictStaticCache(protectedKey) {
  while (totalStaticCacheBytes > MAX_STATIC_CACHE_BYTES && staticCache.size > 0) {
    let evicted = false;
    for (const [key, entry] of staticCache) {
      if (key === protectedKey && staticCache.size > 1) continue;
      staticCache.delete(key);
      totalStaticCacheBytes -= entry.totalBytes;
      evicted = true;
      break;
    }
    if (!evicted) break;
  }
}

async function getCachedStaticBuffer(filePath, stats, encoding) {
  let entry = staticCache.get(filePath);
  if (entry && (entry.mtimeMs !== stats.mtimeMs || entry.size !== stats.size)) {
    staticCache.delete(filePath);
    totalStaticCacheBytes -= entry.totalBytes;
    entry = null;
  }

  if (!entry) {
    entry = {
      mtimeMs: stats.mtimeMs,
      size: stats.size,
      baseEtag: `${stats.size.toString(16)}-${Math.floor(stats.mtimeMs).toString(16)}`,
      lastModified: stats.mtime.toUTCString(),
      buffers: {},
      inflight: {},
      totalBytes: 0
    };
    staticCache.set(filePath, entry);
  } else {
    touchStaticEntry(filePath, entry);
  }

  if (entry.buffers[encoding]) {
    return entry.buffers[encoding];
  }

  if (entry.inflight[encoding]) {
    return entry.inflight[encoding];
  }

  const task = (async () => {
    let rawBuf = entry.buffers.identity;
    if (!rawBuf) {
      if (!entry.inflight.identity) {
        entry.inflight.identity = fsp.readFile(filePath).then((buf) => {
          if (!entry.buffers.identity) {
            entry.buffers.identity = buf;
            entry.totalBytes += buf.length;
            totalStaticCacheBytes += buf.length;
            touchStaticEntry(filePath, entry);
            evictStaticCache(filePath);
          }
          delete entry.inflight.identity;
          return buf;
        }, (err) => {
          delete entry.inflight.identity;
          throw err;
        });
      }
      rawBuf = await entry.inflight.identity;
    }

    if (encoding === 'identity') {
      return rawBuf;
    }

    const compressed = await compressBuffer(rawBuf, encoding);
    if (!entry.buffers[encoding]) {
      entry.buffers[encoding] = compressed;
      entry.totalBytes += compressed.length;
      totalStaticCacheBytes += compressed.length;
      touchStaticEntry(filePath, entry);
      evictStaticCache(filePath);
    }
    return compressed;
  })().finally(() => {
    delete entry.inflight[encoding];
  });

  entry.inflight[encoding] = task;
  return task;
}

async function serveStaticFile(req, res, filePath, relPath, cacheControlOverride) {
  let stats;
  try {
    stats = await fsp.stat(filePath);
  } catch {
    return false;
  }

  if (!stats.isFile()) return false;

  const isHead = req.method === 'HEAD';
  const ext = path.extname(filePath).toLowerCase();
  const contentType = getContentType(filePath);
  const cacheControl = cacheControlOverride || getStaticCacheControl(relPath, filePath);
  const compressible = isCompressibleFile(filePath) && stats.size >= MIN_COMPRESS_BYTES;
  const baseEtag = `${stats.size.toString(16)}-${Math.floor(stats.mtimeMs).toString(16)}`;
  const lastModified = stats.mtime.toUTCString();

  // Handle Range requests (always uncompressed identity)
  if (req.headers.range && (req.method === 'GET' || isHead)) {
    const parsedRange = parseByteRange(req.headers.range, stats.size);
    if (parsedRange.kind === 'invalid') {
      const headers = {
        'Content-Range': `bytes */${stats.size}`,
        'Accept-Ranges': 'bytes',
        'Cache-Control': cacheControl
      };
      if (compressible) headers['Vary'] = 'Accept-Encoding';
      res.writeHead(416, headers);
      res.end();
      return true;
    }

    if (parsedRange.kind === 'range') {
      const { start, end } = parsedRange;
      const chunkLen = end - start + 1;
      const headers = {
        'Content-Type': contentType,
        'Content-Range': `bytes ${start}-${end}/${stats.size}`,
        'Content-Length': chunkLen,
        'Accept-Ranges': 'bytes',
        'ETag': makeEtag(baseEtag, 'identity'),
        'Last-Modified': lastModified,
        'Cache-Control': cacheControl
      };
      if (compressible) headers['Vary'] = 'Accept-Encoding';
      if (ext === '.apk') {
        headers['Content-Disposition'] = 'attachment; filename="grzybmap.apk"';
      }

      res.writeHead(206, headers);
      if (isHead) {
        res.end();
        return true;
      }

      const cached = staticCache.get(filePath);
      if (cached && cached.mtimeMs === stats.mtimeMs && cached.size === stats.size && cached.buffers.identity) {
        touchStaticEntry(filePath, cached);
        res.end(cached.buffers.identity.subarray(start, end + 1));
        return true;
      }

      const stream = fs.createReadStream(filePath, { start, end });
      stream.on('error', () => {
        if (!res.headersSent) res.writeHead(500);
        if (!res.writableEnded) res.end();
      });
      res.on('close', () => {
        if (!res.writableEnded) stream.destroy();
      });
      stream.pipe(res);
      return true;
    }
  }

  const encoding = compressible ? negotiateEncoding(req) : 'identity';
  const etag = makeEtag(baseEtag, encoding);

  if (isNotModified(req, etag, stats.mtimeMs)) {
    const headers304 = {
      'ETag': etag,
      'Last-Modified': lastModified,
      'Cache-Control': cacheControl
    };
    if (compressible) headers304['Vary'] = 'Accept-Encoding';
    res.writeHead(304, headers304);
    res.end();
    return true;
  }

  // Large files (> 16 MB) stream directly from disk
  if (stats.size > MAX_CACHEABLE_FILE_BYTES) {
    const headers = {
      'Content-Type': contentType,
      'Accept-Ranges': 'bytes',
      'ETag': etag,
      'Last-Modified': lastModified,
      'Cache-Control': cacheControl
    };
    if (compressible) headers['Vary'] = 'Accept-Encoding';
    if (encoding !== 'identity') {
      headers['Content-Encoding'] = encoding;
    } else {
      headers['Content-Length'] = stats.size;
    }
    if (ext === '.apk') {
      headers['Content-Disposition'] = 'attachment; filename="grzybmap.apk"';
    }

    res.writeHead(200, headers);
    if (isHead) {
      res.end();
      return true;
    }

    const fileStream = fs.createReadStream(filePath);
    if (encoding === 'identity') {
      fileStream.on('error', () => {
        if (!res.writableEnded) res.end();
      });
      res.on('close', () => {
        if (!res.writableEnded) fileStream.destroy();
      });
      fileStream.pipe(res);
    } else {
      const compressor = encoding === 'br'
        ? zlib.createBrotliCompress(BROTLI_OPTIONS)
        : zlib.createGzip(GZIP_OPTIONS);
      fileStream.on('error', () => {
        compressor.destroy();
        if (!res.writableEnded) res.end();
      });
      compressor.on('error', () => {
        fileStream.destroy();
        if (!res.writableEnded) res.end();
      });
      res.on('close', () => {
        if (!res.writableEnded) {
          fileStream.destroy();
          compressor.destroy();
        }
      });
      fileStream.pipe(compressor).pipe(res);
    }
    return true;
  }

  // Cached static asset path (<= 16 MB)
  let payload;
  try {
    payload = await getCachedStaticBuffer(filePath, stats, encoding);
  } catch (err) {
    console.error('[STATIC READ ERROR]', filePath, err.message);
    return false;
  }

  const headers = {
    'Content-Type': contentType,
    'Content-Length': payload.length,
    'Accept-Ranges': 'bytes',
    'ETag': etag,
    'Last-Modified': lastModified,
    'Cache-Control': cacheControl
  };
  if (compressible) headers['Vary'] = 'Accept-Encoding';
  if (encoding !== 'identity') headers['Content-Encoding'] = encoding;
  if (ext === '.apk') {
    headers['Content-Disposition'] = 'attachment; filename="grzybmap.apk"';
  }

  res.writeHead(200, headers);
  if (isHead) {
    res.end();
  } else {
    res.end(payload);
  }
  return true;
}

// --- Async Atomic /api/reports Store ---
const reportsStore = {
  initialized: false,
  initPromise: null,
  writeQueue: Promise.resolve(),
  tmpSeq: 0,
  reports: [],
  rawBuffer: Buffer.from('[]', 'utf8'),
  brBuffer: null,
  gzipBuffer: null,
  etagBase: 'empty',
  lastModified: new Date().toUTCString()
};

async function rebuildReportsBuffers() {
  const jsonStr = JSON.stringify(reportsStore.reports);
  const rawBuf = Buffer.from(jsonStr, 'utf8');
  const hash = crypto.createHash('sha1').update(rawBuf).digest('hex').slice(0, 16);
  let brBuf = null;
  let gzipBuf = null;
  if (rawBuf.length >= MIN_COMPRESS_BYTES) {
    [brBuf, gzipBuf] = await Promise.all([
      brotliCompressAsync(rawBuf, BROTLI_OPTIONS),
      gzipAsync(rawBuf, GZIP_OPTIONS)
    ]);
  }
  reportsStore.rawBuffer = rawBuf;
  reportsStore.brBuffer = brBuf;
  reportsStore.gzipBuffer = gzipBuf;
  reportsStore.etagBase = hash;
  reportsStore.lastModified = new Date().toUTCString();
}

function initReportsStore() {
  if (reportsStore.initPromise) return reportsStore.initPromise;
  reportsStore.initPromise = (async () => {
    try {
      const content = await fsp.readFile(REPORTS_FILE, 'utf8');
      const parsed = JSON.parse(content);
      reportsStore.reports = Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      if (err.code !== 'ENOENT') {
        console.error('[REPORTS READ ERROR]', err.message);
      }
      reportsStore.reports = [];
    }
    await rebuildReportsBuffers();
    reportsStore.initialized = true;
  })();
  return reportsStore.initPromise;
}

function enqueueReportsMutation(mutatorFn) {
  const run = reportsStore.writeQueue.then(async () => {
    await initReportsStore();
    const result = mutatorFn(reportsStore.reports);
    if (!result || result.persist === false) {
      return result;
    }
    await rebuildReportsBuffers();
    const dataDir = path.dirname(REPORTS_FILE);
    await fsp.mkdir(dataDir, { recursive: true });
    const tmpPath = `${REPORTS_FILE}.tmp.${process.pid}.${++reportsStore.tmpSeq}`;
    try {
      await fsp.writeFile(tmpPath, JSON.stringify(reportsStore.reports, null, 2), 'utf8');
      try {
        await fsp.rename(tmpPath, REPORTS_FILE);
      } catch (renameErr) {
        if (process.platform === 'win32' || renameErr.code === 'EPERM' || renameErr.code === 'EBUSY') {
          await fsp.copyFile(tmpPath, REPORTS_FILE);
          try { await fsp.unlink(tmpPath); } catch {}
        } else {
          throw renameErr;
        }
      }
    } catch (err) {
      try { await fsp.unlink(tmpPath); } catch {}
      throw err;
    }
    return result;
  });

  reportsStore.writeQueue = run.catch(() => {});
  return run;
}

function readJsonBody(req, maxBytes = MAX_JSON_BODY_BYTES) {
  return new Promise((resolve, reject) => {
    const clHeader = req.headers['content-length'];
    if (clHeader !== undefined) {
      const declaredLen = Number(clHeader);
      if (Number.isFinite(declaredLen) && declaredLen > maxBytes) {
        req.resume();
        const err = new Error('Payload too large');
        err.status = 413;
        reject(err);
        return;
      }
    }

    const chunks = [];
    let total = 0;
    let settled = false;

    req.on('data', (chunk) => {
      if (settled) return;
      total += chunk.length;
      if (total > maxBytes) {
        settled = true;
        req.pause();
        const err = new Error('Payload too large');
        err.status = 413;
        reject(err);
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      if (settled) return;
      settled = true;
      try {
        const text = Buffer.concat(chunks, total).toString('utf8');
        const parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
          const err = new Error('Invalid JSON payload');
          err.status = 400;
          reject(err);
          return;
        }
        resolve(parsed);
      } catch {
        const err = new Error('Invalid JSON payload');
        err.status = 400;
        reject(err);
      }
    });

    req.on('aborted', () => {
      if (settled) return;
      settled = true;
      const err = new Error('Request aborted');
      err.status = 400;
      reject(err);
    });

    req.on('error', () => {
      if (settled) return;
      settled = true;
      const err = new Error('Request read error');
      err.status = 400;
      reject(err);
    });
  });
}

// --- Shared HTTPS Agent & Bounded TTL/LRU Proxy Cache ---
const upstreamAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 32,
  maxFreeSockets: 16,
  timeout: 15000
});

class TtlLruCache {
  constructor({ maxEntries, maxBytes, ttlMs, maxItemBytes = 2 * 1024 * 1024 }) {
    this.maxEntries = maxEntries;
    this.maxBytes = maxBytes;
    this.ttlMs = ttlMs;
    this.maxItemBytes = maxItemBytes;
    this.map = new Map();
    this.totalBytes = 0;
  }

  get(key) {
    const entry = this.map.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.map.delete(key);
      this.totalBytes -= entry.size;
      return null;
    }
    this.map.delete(key);
    this.map.set(key, entry);
    return entry;
  }

  set(key, { statusCode, contentType, body, cacheControl, brBody = null, gzipBody = null, ttlMs }) {
    if (!body || body.length > this.maxItemBytes) return;
    const existing = this.map.get(key);
    if (existing) {
      this.map.delete(key);
      this.totalBytes -= existing.size;
    }
    const size = body.length + (brBody ? brBody.length : 0) + (gzipBody ? gzipBody.length : 0);
    const entry = {
      statusCode,
      contentType,
      body,
      brBody,
      gzipBody,
      cacheControl,
      size,
      expiresAt: Date.now() + (ttlMs || this.ttlMs)
    };
    this.map.set(key, entry);
    this.totalBytes += size;

    while ((this.map.size > this.maxEntries || this.totalBytes > this.maxBytes) && this.map.size > 0) {
      const oldestKey = this.map.keys().next().value;
      const oldest = this.map.get(oldestKey);
      this.map.delete(oldestKey);
      this.totalBytes -= oldest.size;
    }
  }
}

const bdlTilesCache = new TtlLruCache({
  maxEntries: 300,
  maxBytes: 12 * 1024 * 1024,
  ttlMs: 24 * 60 * 60 * 1000
});
const bdlQueryCache = new TtlLruCache({
  maxEntries: 100,
  maxBytes: 16 * 1024 * 1024,
  ttlMs: 10 * 60 * 1000
});
const bdlWmsCache = new TtlLruCache({
  maxEntries: 300,
  maxBytes: 12 * 1024 * 1024,
  ttlMs: 24 * 60 * 60 * 1000,
  maxItemBytes: 512 * 1024
});
const geoCache = new TtlLruCache({
  maxEntries: 8,
  maxBytes: 256 * 1024,
  ttlMs: 5 * 60 * 1000
});
const searchCache = new TtlLruCache({
  maxEntries: 200,
  maxBytes: 4 * 1024 * 1024,
  ttlMs: 15 * 60 * 1000
});

async function sendJsonBufferWithNegotiation(req, res, statusCode, rawBuf, extraHeaders = {}, precompressed = null) {
  const compressible = rawBuf.length >= MIN_COMPRESS_BYTES;
  const encoding = compressible ? negotiateEncoding(req) : 'identity';
  let payload = rawBuf;
  if (encoding === 'br') {
    payload = (precompressed && precompressed.brBody) || await brotliCompressAsync(rawBuf, BROTLI_OPTIONS);
  } else if (encoding === 'gzip') {
    payload = (precompressed && precompressed.gzipBody) || await gzipAsync(rawBuf, GZIP_OPTIONS);
  }

  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': payload.length,
    ...extraHeaders
  };
  if (compressible) headers['Vary'] = 'Accept-Encoding';
  if (encoding !== 'identity') headers['Content-Encoding'] = encoding;

  res.writeHead(statusCode, headers);
  if (req.method === 'HEAD') {
    res.end();
  } else {
    res.end(payload);
  }
}

function proxyBinaryOrCached({ req, res, targetUrl, headers = {}, timeoutMs = 10000, cache, cacheKey, cacheControl, forceContentType, isJson = false, ttlMsOverride }) {
  const isHead = req.method === 'HEAD';
  if (!isHead && cache && cacheKey) {
    const hit = cache.get(cacheKey);
    if (hit) {
      if (isJson) {
        sendJsonBufferWithNegotiation(req, res, hit.statusCode, hit.body, {
          'Cache-Control': hit.cacheControl || cacheControl || 'no-cache'
        }, hit).catch(() => {
          if (!res.writableEnded) res.end();
        });
      } else {
        const resHeaders = {
          'Content-Type': hit.contentType,
          'Content-Length': hit.body.length
        };
        if (hit.cacheControl || cacheControl) {
          resHeaders['Cache-Control'] = hit.cacheControl || cacheControl;
        }
        res.writeHead(hit.statusCode, resHeaders);
        res.end(hit.body);
      }
      return;
    }
  }

  const proxyReq = https.request(targetUrl, {
    method: isHead ? 'HEAD' : 'GET',
    agent: upstreamAgent,
    timeout: timeoutMs,
    headers
  }, (proxyRes) => {
    const statusCode = proxyRes.statusCode || 502;
    const contentType = forceContentType || proxyRes.headers['content-type'] || 'application/octet-stream';
    const isImageOrGetMap = contentType.startsWith('image/') ||
      (targetUrl.includes('WMSServer') && /request=getmap/i.test(targetUrl));
    const effectiveCacheControl = statusCode === 200
      ? (cacheControl || (isImageOrGetMap ? 'public, max-age=86400' : undefined))
      : undefined;

    if (isHead) {
      const headHeaders = { 'Content-Type': contentType };
      if (effectiveCacheControl) headHeaders['Cache-Control'] = effectiveCacheControl;
      if (proxyRes.headers['content-length']) headHeaders['Content-Length'] = proxyRes.headers['content-length'];
      res.writeHead(statusCode, headHeaders);
      res.end();
      proxyRes.resume();
      return;
    }

    if (isJson && statusCode === 200) {
      const chunks = [];
      let total = 0;
      proxyRes.on('data', (chunk) => {
        total += chunk.length;
        chunks.push(chunk);
      });
      proxyRes.on('end', async () => {
        if (res.writableEnded) return;
        const rawBuf = Buffer.concat(chunks, total);
        let brBody = null;
        let gzipBody = null;
        if (rawBuf.length >= MIN_COMPRESS_BYTES && rawBuf.length <= (cache ? cache.maxItemBytes : 2 * 1024 * 1024)) {
          try {
            [brBody, gzipBody] = await Promise.all([
              brotliCompressAsync(rawBuf, BROTLI_OPTIONS),
              gzipAsync(rawBuf, GZIP_OPTIONS)
            ]);
          } catch {}
        }
        if (cache && cacheKey) {
          cache.set(cacheKey, {
            statusCode,
            contentType,
            body: rawBuf,
            brBody,
            gzipBody,
            cacheControl: effectiveCacheControl,
            ttlMs: ttlMsOverride
          });
        }
        try {
          await sendJsonBufferWithNegotiation(req, res, statusCode, rawBuf, effectiveCacheControl ? { 'Cache-Control': effectiveCacheControl } : {}, { brBody, gzipBody });
        } catch {
          if (!res.writableEnded) res.end();
        }
      });
      proxyRes.on('error', () => {
        if (!res.headersSent) res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' });
        if (!res.writableEnded) res.end(JSON.stringify({ error: 'Upstream stream error' }));
      });
      return;
    }

    const resHeaders = { 'Content-Type': contentType };
    if (effectiveCacheControl) resHeaders['Cache-Control'] = effectiveCacheControl;
    if (proxyRes.headers['content-length'] && !isJson) {
      resHeaders['Content-Length'] = proxyRes.headers['content-length'];
    }
    res.writeHead(statusCode, resHeaders);

    // Stream directly while teeing chunks for cache on 200 responses
    const shouldCache = Boolean(cache && cacheKey && statusCode === 200);
    const chunks = shouldCache ? [] : null;
    let total = 0;
    let cacheAborted = false;

    if (shouldCache) {
      proxyRes.on('data', (chunk) => {
        if (cacheAborted) return;
        total += chunk.length;
        if (total > cache.maxItemBytes) {
          cacheAborted = true;
          chunks.length = 0;
          return;
        }
        chunks.push(chunk);
      });
      proxyRes.on('end', () => {
        if (!cacheAborted && total > 0) {
          cache.set(cacheKey, {
            statusCode,
            contentType,
            body: Buffer.concat(chunks, total),
            cacheControl: effectiveCacheControl,
            ttlMs: ttlMsOverride
          });
        }
      });
    }

    proxyRes.on('error', () => {
      if (!res.writableEnded) res.end();
    });
    proxyRes.pipe(res);
  });

  proxyReq.on('timeout', () => {
    proxyReq.destroy(Object.assign(new Error('Upstream timeout'), { isTimeout: true }));
  });

  proxyReq.on('error', (err) => {
    if (res.headersSent || res.writableEnded) return;
    const status = err && err.isTimeout ? 504 : 502;
    if (isJson) {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ error: err.message }));
    } else {
      res.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(`Proxy Error: ${err.message}`);
    }
  });

  res.on('close', () => {
    if (!res.writableEnded) {
      proxyReq.destroy();
    }
  });

  proxyReq.end();
}

function sendTextError(res, statusCode, message) {
  res.writeHead(statusCode, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(message);
}

function sendJsonResponse(res, statusCode, data) {
  const body = JSON.stringify(data);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body, 'utf8')
  });
  res.end(body);
}

const server = http.createServer(async (req, res) => {
  // CORS & WASM threading headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Safe URL & Host validation
  const hostHeader = req.headers.host;
  if (!hostHeader || typeof hostHeader !== 'string' || !hostHeader.trim()) {
    sendTextError(res, 400, 'Bad Request: Missing Host header');
    return;
  }

  let parsedUrl;
  let pathname;
  try {
    const rawUrl = req.url || '/';
    const safeUrl = rawUrl.startsWith('//') ? '/' + rawUrl.replace(/^\/+/, '') : rawUrl;
    parsedUrl = new URL(safeUrl, `http://${hostHeader}`);
    pathname = decodeURIComponent(parsedUrl.pathname);
  } catch {
    sendTextError(res, 400, 'Bad Request');
    return;
  }

  if (pathname.includes('\0')) {
    sendTextError(res, 400, 'Bad Request');
    return;
  }

  // Health check endpoint
  if (pathname === '/api/health') {
    sendJsonResponse(res, 200, {
      status: 'ok',
      service: 'grzybmap',
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString()
    });
    return;
  }

  // Proxy 1: BDL Export Tiles
  if (pathname.startsWith('/api/bdl-tiles')) {
    const rawBbox = parsedUrl.searchParams.get('bbox') || parsedUrl.searchParams.get('BBOX') || '';
    const dynLayers = JSON.stringify([{
      id: 5,
      source: { type: 'mapLayer', mapLayerId: 5 },
      drawingInfo: { showLabels: false }
    }]);
    const targetUrl = `https://mapserver.bdl.lasy.gov.pl/ArcGIS/rest/services/WMS_BDL/MapServer/export?bbox=${encodeURIComponent(rawBbox)}&bboxSR=3857&imageSR=3857&size=256,256&format=png32&transparent=true&f=image&dynamicLayers=${encodeURIComponent(dynLayers)}`;
    proxyBinaryOrCached({
      req,
      res,
      targetUrl,
      headers: { 'User-Agent': 'Mozilla/5.0' },
      timeoutMs: 10000,
      cache: bdlTilesCache,
      cacheKey: rawBbox,
      cacheControl: 'public, max-age=86400',
      forceContentType: 'image/png'
    });
    return;
  }

  // Proxy 2: BDL ArcGIS REST Query (Mushroom radar parcels)
  if (pathname.startsWith('/api/bdl-query')) {
    const targetUrl = `https://mapserver.bdl.lasy.gov.pl/ArcGIS/rest/services/WMS_BDL/MapServer/5/query${parsedUrl.search}`;
    proxyBinaryOrCached({
      req,
      res,
      targetUrl,
      headers: { 'User-Agent': 'Mozilla/5.0' },
      timeoutMs: 10000,
      cache: bdlQueryCache,
      cacheKey: parsedUrl.search,
      cacheControl: 'public, max-age=300',
      forceContentType: 'application/json; charset=utf-8',
      isJson: true
    });
    return;
  }

  // Proxy 3: BDL WMS (/api/bdl) - direct binary stream pass-through
  if (pathname.startsWith('/api/bdl')) {
    const targetUrl = `https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_BDL/MapServer/WMSServer${parsedUrl.search}`;
    const isGetMap = (parsedUrl.searchParams.get('REQUEST') || parsedUrl.searchParams.get('request') || '').toLowerCase() === 'getmap';
    proxyBinaryOrCached({
      req,
      res,
      targetUrl,
      timeoutMs: 10000,
      cache: bdlWmsCache,
      cacheKey: parsedUrl.search,
      cacheControl: isGetMap ? 'public, max-age=86400' : undefined,
      ttlMsOverride: isGetMap ? 24 * 60 * 60 * 1000 : 10 * 60 * 1000
    });
    return;
  }

  // Proxy 4: IP Geolocation (/api/geo)
  if (pathname.startsWith('/api/geo')) {
    proxyBinaryOrCached({
      req,
      res,
      targetUrl: 'https://get.geojs.io/v1/ip/geo.json',
      timeoutMs: 5000,
      cache: geoCache,
      cacheKey: 'geo',
      cacheControl: 'public, max-age=300',
      forceContentType: 'application/json; charset=utf-8',
      isJson: true
    });
    return;
  }

  // Proxy 5: Geocoding (/api/search)
  if (pathname.startsWith('/api/search')) {
    const q = parsedUrl.searchParams.get('q') || '';
    const trimmed = q.trim();
    if (!trimmed) {
      sendJsonResponse(res, 200, []);
      return;
    }
    const targetUrl = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(trimmed)}&countrycodes=pl&format=json&limit=6&addressdetails=1`;
    proxyBinaryOrCached({
      req,
      res,
      targetUrl,
      headers: {
        'User-Agent': 'GrzybMap-App/1.0 (contact: grzybmap@lasy.pl)'
      },
      timeoutMs: 7000,
      cache: searchCache,
      cacheKey: trimmed.toLowerCase(),
      cacheControl: 'public, max-age=900',
      forceContentType: 'application/json; charset=utf-8',
      isJson: true
    });
    return;
  }

  // Serve Forester Dashboard at /lesnik or /lesnik.html
  if (pathname === '/lesnik' || pathname === '/lesnik.html') {
    const served = await serveStaticFile(req, res, LESNIK_PATH, 'lesnik.html', 'no-cache');
    if (!served) {
      sendTextError(res, 404, 'Forester Dashboard Not Found');
    }
    return;
  }

  // Forest Reports API endpoints (/api/reports)
  if (pathname === '/api/reports' && (req.method === 'GET' || req.method === 'HEAD')) {
    await initReportsStore();
    const compressible = reportsStore.rawBuffer.length >= MIN_COMPRESS_BYTES;
    const encoding = compressible ? negotiateEncoding(req) : 'identity';
    const etag = makeEtag(reportsStore.etagBase, encoding);

    if (isNotModified(req, etag, Date.parse(reportsStore.lastModified))) {
      const headers304 = {
        'ETag': etag,
        'Last-Modified': reportsStore.lastModified,
        'Cache-Control': 'no-cache'
      };
      if (compressible) headers304['Vary'] = 'Accept-Encoding';
      res.writeHead(304, headers304);
      res.end();
      return;
    }

    let payload = reportsStore.rawBuffer;
    if (encoding === 'br' && reportsStore.brBuffer) payload = reportsStore.brBuffer;
    else if (encoding === 'gzip' && reportsStore.gzipBuffer) payload = reportsStore.gzipBuffer;

    const headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': payload.length,
      'ETag': etag,
      'Last-Modified': reportsStore.lastModified,
      'Cache-Control': 'no-cache'
    };
    if (compressible) headers['Vary'] = 'Accept-Encoding';
    if (encoding !== 'identity' && payload !== reportsStore.rawBuffer) {
      headers['Content-Encoding'] = encoding;
    }

    res.writeHead(200, headers);
    if (req.method === 'HEAD') {
      res.end();
    } else {
      res.end(payload);
    }
    return;
  }

  if (pathname === '/api/reports' && req.method === 'POST') {
    let newReport;
    try {
      newReport = await readJsonBody(req);
    } catch (err) {
      if (err.status === 413) res.setHeader('Connection', 'close');
      sendJsonResponse(res, err.status || 400, { error: err.message || 'Invalid JSON payload' });
      return;
    }

    if (!newReport.id) newReport.id = 'rep-' + Date.now();
    if (!newReport.createdAt) newReport.createdAt = new Date().toISOString();
    if (!newReport.status) newReport.status = 'pending';
    if (typeof newReport.confirmationsCount !== 'number') {
      newReport.confirmationsCount = 1;
    }

    try {
      await enqueueReportsMutation((reports) => {
        reports.unshift(newReport);
        return { persist: true };
      });
      sendJsonResponse(res, 201, { success: true, report: newReport });
    } catch (err) {
      console.error('[REPORTS WRITE ERROR]', err.message);
      sendJsonResponse(res, 500, { error: 'Failed to persist report' });
    }
    return;
  }

  if (pathname.startsWith('/api/reports/') && req.method === 'PATCH') {
    const reportId = pathname.slice('/api/reports/'.length);
    if (!reportId || reportId.includes('/')) {
      sendJsonResponse(res, 404, { error: 'Report not found' });
      return;
    }

    let updates;
    try {
      updates = await readJsonBody(req);
    } catch (err) {
      if (err.status === 413) res.setHeader('Connection', 'close');
      sendJsonResponse(res, err.status || 400, { error: err.message || 'Invalid JSON' });
      return;
    }

    try {
      const outcome = await enqueueReportsMutation((reports) => {
        const target = reports.find((r) => r.id === reportId);
        if (!target) {
          return { persist: false, found: false };
        }
        if (updates.status) target.status = updates.status;
        if (typeof updates.confirmationsCount === 'number') {
          target.confirmationsCount = updates.confirmationsCount;
        }
        if (updates.notes !== undefined) target.notes = updates.notes;
        if (updates.assignedZul !== undefined) target.assignedZul = updates.assignedZul;
        if (updates.status === 'resolved' && !target.resolvedAt) {
          target.resolvedAt = new Date().toISOString();
        }
        return { persist: true, found: true, report: target };
      });

      if (!outcome.found) {
        sendJsonResponse(res, 404, { error: 'Report not found' });
        return;
      }
      sendJsonResponse(res, 200, { success: true, report: outcome.report });
    } catch (err) {
      console.error('[REPORTS WRITE ERROR]', err.message);
      sendJsonResponse(res, 500, { error: 'Failed to update report' });
    }
    return;
  }

  // Catch unhandled /api/ routes so they return JSON 404/405 instead of falling through to SPA HTML
  if (pathname.startsWith('/api/')) {
    if (pathname === '/api/reports') {
      res.setHeader('Allow', 'GET, POST, HEAD');
      sendJsonResponse(res, 405, { error: `Method ${req.method} not allowed on /api/reports` });
      return;
    }
    sendJsonResponse(res, 404, { error: 'API endpoint not found' });
    return;
  }

  // Static files & SPA fallback
  const relPath = (pathname === '/' || pathname === '') ? 'index.html' : pathname.replace(/^\/+/, '');
  const resolvedPath = path.resolve(WEB_DIR, relPath);

  if (resolvedPath !== WEB_DIR && !resolvedPath.startsWith(WEB_PREFIX)) {
    sendTextError(res, 404, 'Not Found');
    return;
  }

  const served = await serveStaticFile(req, res, resolvedPath, relPath);
  if (served) return;

  const ext = path.extname(relPath);
  if (ext && ext !== '.html') {
    sendTextError(res, 404, `File Not Found: ${pathname}`);
    return;
  }

  const indexPath = path.join(WEB_DIR, 'index.html');
  const fallbackServed = await serveStaticFile(req, res, indexPath, 'index.html', 'no-cache');
  if (!fallbackServed) {
    sendTextError(res, 404, 'Not Found');
  }
});

server.on('clientError', (err, socket) => {
  if (err.code === 'ECONNRESET' || !socket.writable) return;
  socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
});

server.on('error', (err) => {
  console.error('[SERVER ERROR]', err.message);
});

initReportsStore().catch((err) => {
  console.error('[REPORTS INIT ERROR]', err.message);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`GrzybMap Flutter Web Server running at http://127.0.0.1:${PORT}`);
  console.log(`Serving static files from: ${WEB_DIR}`);

  // Optional Render / Cloud Keepalive Self-Ping (10 minutes)
  const externalUrl = process.env.RENDER_EXTERNAL_URL || process.env.APP_URL;
  if (externalUrl) {
    const PING_INTERVAL_MS = 10 * 60 * 1000;
    setInterval(() => {
      try {
        const pingUrl = new URL('/api/health', externalUrl);
        const client = pingUrl.protocol === 'https:' ? https : http;
        client.get(pingUrl.href, (res) => {
          res.resume();
        }).on('error', (err) => {
          console.warn('[SELF-PING]', err.message);
        });
      } catch (err) {
        console.warn('[SELF-PING ERROR]', err.message);
      }
    }, PING_INTERVAL_MS).unref();
    console.log(`[SELF-PING] Render keepalive active for: ${externalUrl} every 10m`);
  }
});
