import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { killProcessTree, killProcessTreeSync } from './server_harness.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const LEAFLET_DIST_DIR = path.join(REPO_ROOT, 'node_modules', 'leaflet', 'dist');

export const ONE_BY_ONE_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  'base64'
);

const activeBrowsers = new Set();
let browserExitHookRegistered = false;

function ensureBrowserExitHook() {
  if (browserExitHookRegistered) return;
  browserExitHookRegistered = true;
  process.on('exit', () => {
    for (const entry of Array.from(activeBrowsers)) {
      try {
        killProcessTreeSync(entry.child);
      } catch {
        // ignore
      }
      for (const dir of entry.tempDirs) {
        try {
          fs.rmSync(dir, { recursive: true, force: true });
        } catch {
          // ignore
        }
      }
      activeBrowsers.delete(entry);
    }
  });
}

export function findBrowserExecutable() {
  const candidates = [
    process.env.E2E_BROWSER_PATH,
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  throw new Error(
    `No supported Chromium/Edge executable found. Checked: ${candidates.join(', ')}`
  );
}

function rmDirWithRetry(dirPath, attempts = 6) {
  for (let i = 0; i < attempts; i++) {
    try {
      if (fs.existsSync(dirPath)) {
        fs.rmSync(dirPath, { recursive: true, force: true });
      }
      return;
    } catch {
      if (i === attempts - 1) return;
      const waitUntil = Date.now() + 150;
      while (Date.now() < waitUntil) {
        // brief synchronous backoff for Windows handle release
      }
    }
  }
}

class CdpConnection {
  constructor(wsUrl) {
    this.wsUrl = wsUrl;
    this.ws = null;
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
  }

  async connect(timeoutMs = 10000) {
    await new Promise((resolve, reject) => {
      const ws = new WebSocket(this.wsUrl);
      this.ws = ws;

      const timer = setTimeout(() => {
        reject(new Error(`CDP WebSocket connection timed out: ${this.wsUrl}`));
      }, timeoutMs);

      ws.addEventListener('open', () => {
        clearTimeout(timer);
        resolve();
      });
      ws.addEventListener('error', (err) => {
        clearTimeout(timer);
        reject(new Error(`CDP WebSocket error: ${err?.message || 'connection failed'}`));
      });
      ws.addEventListener('message', (event) => {
        let msg;
        try {
          msg = JSON.parse(typeof event.data === 'string' ? event.data : event.data.toString());
        } catch {
          return;
        }
        if (msg.id !== undefined) {
          const entry = this.pending.get(msg.id);
          if (entry) {
            this.pending.delete(msg.id);
            clearTimeout(entry.timer);
            if (msg.error) {
              entry.reject(new Error(`CDP ${entry.method}: ${msg.error.message} (${msg.error.code})`));
            } else {
              entry.resolve(msg.result || {});
            }
          }
        } else if (msg.method) {
          const set = this.listeners.get(msg.method);
          if (set) {
            for (const fn of Array.from(set)) {
              try {
                fn(msg.params || {});
              } catch {
                // listener error isolated
              }
            }
          }
        }
      });
      ws.addEventListener('close', () => {
        for (const [id, entry] of this.pending.entries()) {
          clearTimeout(entry.timer);
          entry.reject(new Error(`CDP connection closed while awaiting ${entry.method}`));
          this.pending.delete(id);
        }
      });
    });
  }

  send(method, params = {}, timeoutMs = 15000) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      return Promise.reject(new Error(`CDP WebSocket not open for ${method}`));
    }
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP command timed out (${timeoutMs}ms): ${method}`));
      }, timeoutMs);
      this.pending.set(id, { method, resolve, reject, timer });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  on(eventName, handler) {
    let set = this.listeners.get(eventName);
    if (!set) {
      set = new Set();
      this.listeners.set(eventName, set);
    }
    set.add(handler);
    return () => set.delete(handler);
  }

  close() {
    try {
      if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
        this.ws.close();
      }
    } catch {
      // ignore
    }
  }
}

export async function launchBrowser(options = {}) {
  ensureBrowserExitHook();
  const {
    width = 1280,
    height = 800,
    browserPath = findBrowserExecutable(),
    downloadPath: customDownloadPath
  } = options;

  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'grzybmap-cdp-profile-'));
  const downloadDir = customDownloadPath || fs.mkdtempSync(path.join(os.tmpdir(), 'grzybmap-cdp-dl-'));
  const tempDirs = customDownloadPath ? [userDataDir] : [userDataDir, downloadDir];

  const args = [
    '--headless=new',
    '--remote-debugging-port=0',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-gpu',
    '--disable-background-networking',
    '--disable-extensions',
    '--disable-sync',
    '--metrics-recording-only',
    '--mute-audio',
    `--window-size=${width},${height}`,
    `--user-data-dir=${userDataDir}`,
    'about:blank'
  ];

  const child = spawn(browserPath, args, {
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true
  });

  const tracked = { child, tempDirs };
  activeBrowsers.add(tracked);

  let stderr = '';
  let debugWsUrl = null;

  try {
    debugWsUrl = await new Promise((resolve, reject) => {
      let settled = false;
      const timer = setTimeout(() => {
        if (settled) return;
        settled = true;
        reject(new Error(`Browser DevTools WS URL timeout.\nstderr: ${stderr}`));
      }, 15000);

      child.stderr.on('data', (chunk) => {
        stderr += chunk.toString('utf8');
        const match = /DevTools listening on (ws:\/\/[^\s]+)/.exec(stderr);
        if (match && !settled) {
          settled = true;
          clearTimeout(timer);
          resolve(match[1]);
        }
      });

      child.once('exit', (code) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(new Error(`Browser exited early (${code}).\nstderr: ${stderr}`));
        }
      });
    });

    const parsedDebug = new URL(debugWsUrl);
    const listRes = await fetch(`http://127.0.0.1:${parsedDebug.port}/json/list`);
    const targets = await listRes.json();
    let pageTarget = targets.find((t) => t.type === 'page' && t.webSocketDebuggerUrl);
    if (!pageTarget) {
      const newRes = await fetch(`http://127.0.0.1:${parsedDebug.port}/json/new?about:blank`, {
        method: 'PUT'
      });
      pageTarget = await newRes.json();
    }
    if (!pageTarget?.webSocketDebuggerUrl) {
      throw new Error(`Unable to obtain CDP page target from ${debugWsUrl}`);
    }

    const cdp = new CdpConnection(pageTarget.webSocketDebuggerUrl);
    await cdp.connect();

    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('DOM.enable');
    await cdp.send('Network.enable');

    try {
      await cdp.send('Browser.setDownloadBehavior', {
        behavior: 'allow',
        downloadPath: downloadDir,
        eventsEnabled: true
      });
    } catch {
      await cdp.send('Page.setDownloadBehavior', {
        behavior: 'allow',
        downloadPath: downloadDir
      });
    }

    const pageErrors = [];
    const consoleErrors = [];
    let unsubFetch = null;

    cdp.on('Runtime.exceptionThrown', (params) => {
      const details = params?.exceptionDetails;
      const msg =
        details?.exception?.description ||
        details?.text ||
        'Unknown runtime exception';
      pageErrors.push(msg);
    });

    cdp.on('Runtime.consoleAPICalled', (params) => {
      if (params?.type === 'error') {
        const text = (params.args || [])
          .map((a) => a.value ?? a.description ?? '')
          .join(' ')
          .trim();
        consoleErrors.push(text || 'console.error');
      }
    });

    const page = {
      cdp,
      downloadDir,
      pageErrors,
      consoleErrors,

      clearErrors() {
        pageErrors.length = 0;
        consoleErrors.length = 0;
      },

      async addScriptOnNewDocument(source) {
        return cdp.send('Page.addScriptToEvaluateOnNewDocument', { source });
      },

      async setViewport(w, h) {
        await cdp.send('Emulation.setDeviceMetricsOverride', {
          width: w,
          height: h,
          deviceScaleFactor: 1,
          mobile: w <= 900
        });
      },

      async navigate(url, { timeoutMs = 15000 } = {}) {
        const loaded = new Promise((resolve, reject) => {
          const timer = setTimeout(() => {
            unsub();
            reject(new Error(`Page.loadEventFired timed out after ${timeoutMs}ms for ${url}`));
          }, timeoutMs);
          const unsub = cdp.on('Page.loadEventFired', () => {
            clearTimeout(timer);
            unsub();
            resolve();
          });
        });
        await cdp.send('Page.navigate', { url });
        await loaded;
      },

      async reload({ ignoreCache = true, timeoutMs = 15000 } = {}) {
        const loaded = new Promise((resolve, reject) => {
          const timer = setTimeout(() => {
            unsub();
            reject(new Error(`Page reload timed out after ${timeoutMs}ms`));
          }, timeoutMs);
          const unsub = cdp.on('Page.loadEventFired', () => {
            clearTimeout(timer);
            unsub();
            resolve();
          });
        });
        await cdp.send('Page.reload', { ignoreCache });
        await loaded;
      },

      async evaluate(expression, { awaitPromise = true } = {}) {
        const res = await cdp.send('Runtime.evaluate', {
          expression,
          returnByValue: true,
          awaitPromise
        });
        if (res.exceptionDetails) {
          const errMsg =
            res.exceptionDetails.exception?.description ||
            res.exceptionDetails.text ||
            'Evaluation failed';
          throw new Error(`Page evaluate error: ${errMsg}`);
        }
        return res.result?.value;
      },

      async waitFor(expression, { timeoutMs = 10000, intervalMs = 50 } = {}) {
        const deadline = Date.now() + timeoutMs;
        let lastErr = null;
        while (Date.now() < deadline) {
          try {
            const val = await page.evaluate(expression);
            if (val) return val;
          } catch (err) {
            lastErr = err;
          }
          await new Promise((r) => setTimeout(r, intervalMs));
        }
        throw new Error(
          `waitFor timed out after ${timeoutMs}ms: ${expression}${lastErr ? ` (${lastErr.message})` : ''}`
        );
      },

      async click(selector) {
        const clicked = await page.evaluate(`(() => {
          const el = document.querySelector(${JSON.stringify(selector)});
          if (!el) return false;
          el.scrollIntoView({ block: 'center', inline: 'center' });
          el.click();
          return true;
        })()`);
        if (!clicked) {
          throw new Error(`click: element not found for selector "${selector}"`);
        }
      },

      async mouseClickSelector(selector) {
        const box = await page.evaluate(`(() => {
          const el = document.querySelector(${JSON.stringify(selector)});
          if (!el) return null;
          el.scrollIntoView({ block: 'center', inline: 'center' });
          const r = el.getBoundingClientRect();
          return { x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width, h: r.height };
        })()`);
        if (!box || box.w === 0 || box.h === 0) {
          throw new Error(`mouseClickSelector: visible element not found for "${selector}"`);
        }
        await cdp.send('Input.dispatchMouseEvent', {
          type: 'mouseMoved',
          x: box.x,
          y: box.y
        });
        await cdp.send('Input.dispatchMouseEvent', {
          type: 'mousePressed',
          x: box.x,
          y: box.y,
          button: 'left',
          clickCount: 1
        });
        await cdp.send('Input.dispatchMouseEvent', {
          type: 'mouseReleased',
          x: box.x,
          y: box.y,
          button: 'left',
          clickCount: 1
        });
      },

      async dispatchMouseMove(x, y) {
        await cdp.send('Input.dispatchMouseEvent', {
          type: 'mouseMoved',
          x,
          y
        });
      },

      async pressKey(key, code = key) {
        await cdp.send('Input.dispatchKeyEvent', {
          type: 'keyDown',
          key,
          code,
          windowsVirtualKeyCode: key === 'Escape' ? 27 : 0
        });
        await cdp.send('Input.dispatchKeyEvent', {
          type: 'keyUp',
          key,
          code,
          windowsVirtualKeyCode: key === 'Escape' ? 27 : 0
        });
      },

      async setInputValue(selector, value) {
        const ok = await page.evaluate(`(() => {
          const el = document.querySelector(${JSON.stringify(selector)});
          if (!el) return false;
          el.focus();
          el.value = ${JSON.stringify(String(value))};
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
          return true;
        })()`);
        if (!ok) {
          throw new Error(`setInputValue: element not found for selector "${selector}"`);
        }
      },

      async enableFetchInterception(patterns, handler) {
        if (unsubFetch) {
          unsubFetch();
          unsubFetch = null;
        }
        await cdp.send('Fetch.enable', { patterns });
        unsubFetch = cdp.on('Fetch.requestPaused', async (ev) => {
          const { requestId } = ev;
          const actions = {
            async continue(overrides = {}) {
              await cdp.send('Fetch.continueRequest', { requestId, ...overrides });
            },
            async fulfill({ status = 200, headers = {}, body = '' } = {}) {
              const bodyBuf = Buffer.isBuffer(body)
                ? body
                : Buffer.from(String(body), 'utf8');
              const responseHeaders = Object.entries(headers).map(([name, value]) => ({
                name,
                value: String(value)
              }));
              await cdp.send('Fetch.fulfillRequest', {
                requestId,
                responseCode: status,
                responseHeaders,
                body: bodyBuf.toString('base64')
              });
            },
            async fail(errorReason = 'Failed') {
              await cdp.send('Fetch.failRequest', { requestId, errorReason });
            }
          };
          try {
            await handler(ev, actions);
          } catch {
            try {
              await cdp.send('Fetch.continueRequest', { requestId });
            } catch {
              // ignore if request already handled/aborted
            }
          }
        });
      },

      async disableFetchInterception() {
        if (unsubFetch) {
          unsubFetch();
          unsubFetch = null;
        }
        try {
          await cdp.send('Fetch.disable');
        } catch {
          // ignore
        }
      },

      async installLesnikInterception({
        interceptBdl = true,
        customApiHandler = null,
        recordedRequests = []
      } = {}) {
        const leafletCss = fs.readFileSync(path.join(LEAFLET_DIST_DIR, 'leaflet.css'));
        const leafletJs = fs.readFileSync(path.join(LEAFLET_DIST_DIR, 'leaflet.js'));
        const patterns = [
          { urlPattern: 'https://unpkg.com/*' },
          { urlPattern: 'https://tile.openstreetmap.org/*' },
          { urlPattern: 'https://server.arcgisonline.com/*' },
          { urlPattern: 'https://*.tile.opentopomap.org/*' },
          { urlPattern: 'https://images.unsplash.com/*' }
        ];
        if (interceptBdl) {
          patterns.push({ urlPattern: '*/api/bdl*' });
        }
        if (customApiHandler) {
          patterns.push({ urlPattern: '*/api/reports*' });
        }

        await page.enableFetchInterception(patterns, async (ev, actions) => {
          const reqUrl = ev.request.url;
          recordedRequests.push({ url: reqUrl, method: ev.request.method, headers: ev.request.headers });

          if (reqUrl.startsWith('https://unpkg.com/leaflet@1.9.4/dist/leaflet.css')) {
            await actions.fulfill({
              status: 200,
              headers: {
                'Content-Type': 'text/css; charset=utf-8',
                'Access-Control-Allow-Origin': '*'
              },
              body: leafletCss
            });
            return;
          }
          if (reqUrl.startsWith('https://unpkg.com/leaflet@1.9.4/dist/leaflet.js')) {
            await actions.fulfill({
              status: 200,
              headers: {
                'Content-Type': 'application/javascript; charset=utf-8',
                'Access-Control-Allow-Origin': '*'
              },
              body: leafletJs
            });
            return;
          }
          if (reqUrl.startsWith('https://unpkg.com/leaflet@1.9.4/dist/images/')) {
            const imgName = path.basename(new URL(reqUrl).pathname);
            const imgPath = path.join(LEAFLET_DIST_DIR, 'images', imgName);
            const body = fs.existsSync(imgPath) ? fs.readFileSync(imgPath) : ONE_BY_ONE_PNG;
            await actions.fulfill({
              status: 200,
              headers: {
                'Content-Type': 'image/png',
                'Access-Control-Allow-Origin': '*'
              },
              body
            });
            return;
          }
          if (
            reqUrl.startsWith('https://tile.openstreetmap.org/') ||
            reqUrl.startsWith('https://server.arcgisonline.com/') ||
            reqUrl.includes('.tile.opentopomap.org/') ||
            reqUrl.startsWith('https://images.unsplash.com/') ||
            (interceptBdl && reqUrl.includes('/api/bdl'))
          ) {
            await actions.fulfill({
              status: 200,
              headers: {
                'Content-Type': 'image/png',
                'Access-Control-Allow-Origin': '*'
              },
              body: ONE_BY_ONE_PNG
            });
            return;
          }
          if (customApiHandler && reqUrl.includes('/api/reports')) {
            const handled = await customApiHandler(ev, actions);
            if (handled) return;
          }
          await actions.continue();
        });
      },

      async waitForDownload(triggerFn, { timeoutMs = 8000 } = {}) {
        const beforeFiles = new Set(fs.readdirSync(downloadDir));
        let suggestedFilename = null;
        let completedGuid = null;

        const dlPromise = new Promise((resolve, reject) => {
          const timer = setTimeout(() => {
            unsubBegin();
            unsubProgress();
            reject(new Error(`Timed out waiting for download after ${timeoutMs}ms`));
          }, timeoutMs);

          const unsubBegin = cdp.on('Browser.downloadWillBegin', (ev) => {
            suggestedFilename = ev.suggestedFilename;
          });
          const unsubProgress = cdp.on('Browser.downloadProgress', (ev) => {
            if (ev.state === 'completed') {
              completedGuid = ev.guid;
              clearTimeout(timer);
              unsubBegin();
              unsubProgress();
              resolve();
            } else if (ev.state === 'canceled') {
              clearTimeout(timer);
              unsubBegin();
              unsubProgress();
              reject(new Error('Browser download canceled'));
            }
          });
        });

        await triggerFn();
        await dlPromise;

        // Wait briefly for filesystem flush if needed
        const deadline = Date.now() + 2000;
        let targetFile = null;
        while (Date.now() < deadline) {
          if (suggestedFilename && fs.existsSync(path.join(downloadDir, suggestedFilename))) {
            targetFile = suggestedFilename;
            break;
          }
          const afterFiles = fs.readdirSync(downloadDir).filter((f) => !f.endsWith('.crdownload'));
          const added = afterFiles.find((f) => !beforeFiles.has(f));
          if (added) {
            targetFile = added;
            break;
          }
          await new Promise((r) => setTimeout(r, 30));
        }

        if (!targetFile) {
          throw new Error(`Download completed (${completedGuid}) but file not found in ${downloadDir}`);
        }
        const fullPath = path.join(downloadDir, targetFile);
        const buffer = fs.readFileSync(fullPath);
        return {
          filename: targetFile,
          buffer,
          text: buffer.toString('utf8')
        };
      },

      async close() {
        activeBrowsers.delete(tracked);
        if (unsubFetch) unsubFetch();
        cdp.close();
        await killProcessTree(child, 1500);
        for (const dir of tempDirs) {
          rmDirWithRetry(dir);
        }
      }
    };

    return page;
  } catch (err) {
    activeBrowsers.delete(tracked);
    await killProcessTree(child, 1500);
    for (const dir of tempDirs) {
      rmDirWithRetry(dir);
    }
    throw err;
  }
}
