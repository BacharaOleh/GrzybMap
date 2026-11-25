import http from 'node:http';
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const REPO_ROOT = path.resolve(__dirname, '..', '..');
export const APP_ROOT = path.join(REPO_ROOT, 'grzybmap_app');
export const ROOT_SERVER_PATH = path.join(REPO_ROOT, 'server.cjs');
export const DEFAULT_SERVER_PATH = process.env.E2E_SERVER_PATH || path.join(APP_ROOT, 'server.cjs');
export const DEFAULT_REPORTS_FILE = process.env.E2E_REPORTS_FILE || path.join(APP_ROOT, 'data', 'reports.json');
export const DEFAULT_WEB_DIR = process.env.E2E_WEB_DIR || path.join(APP_ROOT, 'build', 'web');
export const DEFAULT_SRC_WEB_DIR = process.env.E2E_SRC_WEB_DIR || path.join(APP_ROOT, 'web');
export const DEFAULT_LESNIK_PATH = process.env.E2E_LESNIK_PATH || path.join(APP_ROOT, 'web', 'lesnik.html');
export const MUSHROOM_ASSETS_DIR = path.join(APP_ROOT, 'assets', 'mushrooms');

const activeChildren = new Set();
const activeBackups = new Set();
let hooksRegistered = false;

function ensureGlobalCleanupHooks() {
  if (hooksRegistered) return;
  hooksRegistered = true;

  const syncCleanup = () => {
    for (const child of Array.from(activeChildren)) {
      killProcessTreeSync(child);
      activeChildren.delete(child);
    }
    for (const snapshot of Array.from(activeBackups)) {
      try {
        restoreReportsJsonSync(snapshot);
      } catch {
        // best effort on abnormal exit
      }
      activeBackups.delete(snapshot);
    }
  };

  process.on('exit', syncCleanup);
  process.on('SIGINT', () => {
    syncCleanup();
    process.exit(130);
  });
  process.on('SIGTERM', () => {
    syncCleanup();
    process.exit(143);
  });
}

export function sha256Buffer(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

export function sha256File(filePath) {
  return sha256Buffer(fs.readFileSync(filePath));
}

export async function allocatePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address();
      const port = addr && typeof addr === 'object' ? addr.port : 0;
      srv.close((err) => {
        if (err) reject(err);
        else resolve(port);
      });
    });
  });
}

export function backupReportsJson(filePath = DEFAULT_REPORTS_FILE) {
  ensureGlobalCleanupHooks();
  const existed = fs.existsSync(filePath);
  const buffer = existed ? fs.readFileSync(filePath) : null;
  const snapshot = {
    filePath,
    existed,
    buffer,
    sha256: buffer ? sha256Buffer(buffer) : null,
    restored: false
  };
  activeBackups.add(snapshot);
  return snapshot;
}

export function restoreReportsJsonSync(snapshot) {
  if (!snapshot || snapshot.restored) return;
  const { filePath, existed, buffer } = snapshot;
  if (existed && buffer !== null) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, buffer);
  } else if (!existed && fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
  }
  snapshot.restored = true;
  activeBackups.delete(snapshot);
}

export function restoreReportsJson(snapshot) {
  restoreReportsJsonSync(snapshot);
}

export function killProcessTreeSync(child) {
  if (!child || !child.pid) return;
  if (child.exitCode !== null || child.signalCode !== null) return;
  if (process.platform === 'win32') {
    try {
      execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], {
        stdio: 'ignore',
        windowsHide: true
      });
    } catch {
      // process may already have exited
    }
  } else {
    try {
      child.kill('SIGKILL');
    } catch {
      // ignore
    }
  }
}

export async function killProcessTree(child, timeoutMs = 1500) {
  if (!child || !child.pid) return;
  activeChildren.delete(child);
  if (child.exitCode !== null || child.signalCode !== null) return;

  const exitPromise = new Promise((resolve) => {
    const onExit = () => {
      clearTimeout(timer);
      resolve();
    };
    child.once('exit', onExit);
    const timer = setTimeout(() => {
      child.removeListener('exit', onExit);
      resolve();
    }, timeoutMs);
  });

  try {
    child.kill('SIGTERM');
  } catch {
    // ignore
  }

  await exitPromise;

  if (child.exitCode === null && child.signalCode === null) {
    killProcessTreeSync(child);
    await new Promise((resolve) => {
      if (child.exitCode !== null || child.signalCode !== null) {
        resolve();
        return;
      }
      const timer = setTimeout(resolve, 1000);
      child.once('exit', () => {
        clearTimeout(timer);
        resolve();
      });
    });
  }
}

export function httpRequest(baseUrl, pathOrUrl = '/', options = {}) {
  const {
    method = 'GET',
    headers = {},
    body = null,
    timeoutMs = 10000
  } = options;

  const target = new URL(pathOrUrl, baseUrl);
  const finalHeaders = {
    Connection: 'close',
    ...headers
  };

  let bodyBuf = null;
  if (body !== null && body !== undefined) {
    bodyBuf = Buffer.isBuffer(body) ? body : Buffer.from(String(body), 'utf8');
    if (!Object.keys(finalHeaders).some((k) => k.toLowerCase() === 'content-length')) {
      finalHeaders['Content-Length'] = String(bodyBuf.length);
    }
  }

  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: target.hostname,
        port: target.port,
        path: `${target.pathname}${target.search}`,
        method,
        headers: finalHeaders,
        agent: false
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const rawBody = Buffer.concat(chunks);
          resolve({
            status: res.statusCode ?? 0,
            headers: res.headers,
            rawBody,
            text(encoding = 'utf8') {
              return rawBody.toString(encoding);
            },
            json() {
              return JSON.parse(rawBody.toString('utf8'));
            }
          });
        });
        res.on('error', reject);
      }
    );

    req.setTimeout(timeoutMs, () => {
      req.destroy(new Error(`HTTP request timed out after ${timeoutMs}ms: ${method} ${target.href}`));
    });
    req.on('error', reject);

    if (bodyBuf !== null) {
      req.write(bodyBuf);
    }
    req.end();
  });
}

export function rawTcpRequest(port, rawPayload, host = '127.0.0.1', timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const socket = net.connect({ host, port });
    const chunks = [];
    let settled = false;

    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      socket.destroy();
      reject(new Error(`Raw TCP request timed out after ${timeoutMs}ms`));
    }, timeoutMs);

    socket.on('connect', () => {
      socket.write(rawPayload);
    });
    socket.on('data', (chunk) => chunks.push(chunk));
    socket.on('end', () => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      const raw = Buffer.concat(chunks).toString('latin1');
      const statusMatch = /^HTTP\/1\.[01]\s+(\d{3})\s+([^\r\n]*)/i.exec(raw);
      resolve({
        raw,
        status: statusMatch ? Number(statusMatch[1]) : 0,
        statusText: statusMatch ? statusMatch[2].trim() : ''
      });
    });
    socket.on('error', (err) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      reject(err);
    });
  });
}

export function decompressBody(rawBody, contentEncoding) {
  if (!contentEncoding || contentEncoding === 'identity') {
    return rawBody;
  }
  const enc = String(contentEncoding).toLowerCase().trim();
  if (enc === 'br') return zlib.brotliDecompressSync(rawBody);
  if (enc === 'gzip') return zlib.gunzipSync(rawBody);
  if (enc === 'deflate') return zlib.inflateSync(rawBody);
  throw new Error(`Unsupported Content-Encoding: ${contentEncoding}`);
}

export async function startServer(options = {}) {
  ensureGlobalCleanupHooks();
  const {
    serverPath = DEFAULT_SERVER_PATH,
    port: requestedPort,
    env = {},
    timeoutMs = 10000
  } = options;

  const port = requestedPort || (await allocatePort());
  const baseUrl = `http://127.0.0.1:${port}`;
  let stdout = '';
  let stderr = '';
  let exited = false;
  let exitCode = null;

  const child = spawn(process.execPath, [serverPath], {
    cwd: path.dirname(serverPath),
    env: {
      ...process.env,
      PORT: String(port),
      ...env
    },
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true
  });

  activeChildren.add(child);
  child.stdout?.on('data', (chunk) => {
    stdout += chunk.toString('utf8');
  });
  child.stderr?.on('data', (chunk) => {
    stderr += chunk.toString('utf8');
  });
  child.once('exit', (code) => {
    exited = true;
    exitCode = code;
    activeChildren.delete(child);
  });

  const deadline = Date.now() + timeoutMs;
  let lastError = null;

  while (Date.now() < deadline) {
    if (exited) {
      throw new Error(
        `Server exited early with code ${exitCode}.\nstdout: ${stdout}\nstderr: ${stderr}`
      );
    }
    try {
      const res = await httpRequest(baseUrl, '/api/reports', { timeoutMs: 800 });
      if (res.status === 200) {
        return {
          port,
          baseUrl,
          child,
          getStdout: () => stdout,
          getStderr: () => stderr,
          stop: () => killProcessTree(child)
        };
      }
      lastError = new Error(`Readiness check returned HTTP ${res.status}`);
    } catch (err) {
      lastError = err;
    }
    await new Promise((r) => setTimeout(r, 80));
  }

  await killProcessTree(child);
  throw new Error(
    `Server failed to become ready within ${timeoutMs}ms on ${baseUrl}: ${lastError?.message}\nstdout: ${stdout}\nstderr: ${stderr}`
  );
}
