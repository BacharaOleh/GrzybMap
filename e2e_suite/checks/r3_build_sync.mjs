import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const APP_DIR = path.join(REPO_ROOT, 'grzybmap_app');
const BUILD_WEB_DIR = path.join(APP_DIR, 'build', 'web');
const WEB_SRC_DIR = path.join(APP_DIR, 'web');
const ASSETS_MUSHROOMS_DIR = path.join(APP_DIR, 'assets', 'mushrooms');

function walkFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  const results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(full));
    } else if (entry.isFile()) {
      results.push(full);
    }
  }
  return results;
}

function sha256File(filePath) {
  const hash = crypto.createHash('sha256');
  hash.update(fs.readFileSync(filePath));
  return hash.digest('hex');
}

function assertNonZeroFile(filePath, label) {
  assert.ok(fs.existsSync(filePath), `Missing required artifact: ${label} (${filePath})`);
  const stat = fs.statSync(filePath);
  assert.ok(stat.isFile(), `Expected file but found non-file: ${label} (${filePath})`);
  assert.ok(stat.size > 0, `Artifact is empty (0 bytes): ${label} (${filePath})`);
}

function maxMtimeMs(targetPath) {
  if (!fs.existsSync(targetPath)) return 0;
  const st = fs.statSync(targetPath);
  if (st.isFile()) return st.mtimeMs;
  let max = st.mtimeMs;
  for (const file of walkFiles(targetPath)) {
    const fStat = fs.statSync(file);
    if (fStat.mtimeMs > max) max = fStat.mtimeMs;
  }
  return max;
}

describe('R3 Web Build Sync & Integrity Checks', () => {
  // -------------------------------------------------------------------------
  // Tier 1: Core Artifact Presence & Non-Zero Size (>= 5 tests)
  // -------------------------------------------------------------------------
  it('[Tier 1] R3: build/web directory exists and is non-empty', () => {
    assert.ok(fs.existsSync(BUILD_WEB_DIR), `Missing build/web directory at ${BUILD_WEB_DIR}`);
    const files = walkFiles(BUILD_WEB_DIR);
    assert.ok(files.length > 0, 'build/web directory contains zero files');
  });

  it('[Tier 1] R3: core HTML, manifest, lesnik.html, and favicon artifacts exist and are non-zero', () => {
    for (const rel of ['index.html', 'manifest.json', 'lesnik.html', 'favicon.png']) {
      assertNonZeroFile(path.join(BUILD_WEB_DIR, rel), rel);
    }
  });

  it('[Tier 1] R3: Flutter Web bootstrap and compiled main.dart.js exist and are non-zero', () => {
    for (const rel of ['flutter_bootstrap.js', 'main.dart.js']) {
      assertNonZeroFile(path.join(BUILD_WEB_DIR, rel), rel);
    }
  });

  it('[Tier 1] R3: Flutter asset and font manifests exist and are non-zero', () => {
    assertNonZeroFile(path.join(BUILD_WEB_DIR, 'assets', 'AssetManifest.bin'), 'assets/AssetManifest.bin');
    assertNonZeroFile(path.join(BUILD_WEB_DIR, 'assets', 'FontManifest.json'), 'assets/FontManifest.json');
  });

  it('[Tier 1] R3: CanvasKit WebAssembly runtime exists and is non-zero', () => {
    assertNonZeroFile(path.join(BUILD_WEB_DIR, 'canvaskit', 'canvaskit.wasm'), 'canvaskit/canvaskit.wasm');
  });

  it('[Tier 1] R3: PWA icons exist and are non-zero under build/web/icons/', () => {
    const iconsDir = path.join(BUILD_WEB_DIR, 'icons');
    assert.ok(fs.existsSync(iconsDir), `Missing icons directory at ${iconsDir}`);
    for (const iconName of [
      'Icon-192.png',
      'Icon-512.png',
      'Icon-maskable-192.png',
      'Icon-maskable-512.png',
    ]) {
      assertNonZeroFile(path.join(iconsDir, iconName), `icons/${iconName}`);
    }
  });

  // -------------------------------------------------------------------------
  // Tier 2: Hygiene, Format Validity & Boundary Conditions (>= 5 tests)
  // -------------------------------------------------------------------------
  it('[Tier 2] R3: zero *.apk files exist anywhere under grzybmap_app/build/web/', () => {
    const allFiles = walkFiles(BUILD_WEB_DIR);
    const apkFiles = allFiles.filter((f) => path.extname(f).toLowerCase() === '.apk');
    assert.equal(
      apkFiles.length,
      0,
      `Forbidden *.apk file(s) found in build/web/: ${apkFiles.map((f) => path.relative(BUILD_WEB_DIR, f)).join(', ')}`
    );
  });

  it('[Tier 2] R3: build/web/index.html references flutter_bootstrap.js and contains no literal $FLUTTER_BASE_HREF', () => {
    const indexPath = path.join(BUILD_WEB_DIR, 'index.html');
    const html = fs.readFileSync(indexPath, 'utf8');
    assert.ok(
      html.includes('flutter_bootstrap.js'),
      'build/web/index.html must reference flutter_bootstrap.js'
    );
    assert.ok(
      !html.includes('$FLUTTER_BASE_HREF'),
      'build/web/index.html still contains unexpanded $FLUTTER_BASE_HREF placeholder'
    );
  });

  it('[Tier 2] R3: build/web/manifest.json is valid JSON and all declared icons exist & are non-zero', () => {
    const manifestPath = path.join(BUILD_WEB_DIR, 'manifest.json');
    const raw = fs.readFileSync(manifestPath, 'utf8');
    let parsed;
    assert.doesNotThrow(() => {
      parsed = JSON.parse(raw);
    }, 'build/web/manifest.json is not valid JSON');
    assert.ok(typeof parsed.name === 'string' && parsed.name.length > 0, 'manifest.json missing non-empty name');
    assert.ok(Array.isArray(parsed.icons) && parsed.icons.length > 0, 'manifest.json missing icons array');
    for (const icon of parsed.icons) {
      assert.ok(typeof icon.src === 'string' && icon.src.length > 0, 'manifest.json icon missing src');
      const iconPath = path.join(BUILD_WEB_DIR, icon.src.replace(/^\/+/, ''));
      assertNonZeroFile(iconPath, `manifest icon ${icon.src}`);
    }
  });

  it('[Tier 2] R3: no duplicate mushroom .webp asset directories in build/web/', () => {
    const directDir = path.join(BUILD_WEB_DIR, 'assets', 'mushrooms');
    const nestedDir = path.join(BUILD_WEB_DIR, 'assets', 'assets', 'mushrooms');

    const directWebps = fs.existsSync(directDir)
      ? fs.readdirSync(directDir).filter((n) => n.endsWith('.webp'))
      : [];
    const nestedWebps = fs.existsSync(nestedDir)
      ? fs.readdirSync(nestedDir).filter((n) => n.endsWith('.webp'))
      : [];

    assert.ok(
      !(directWebps.length > 0 && nestedWebps.length > 0),
      `Duplicate mushroom .webp asset directories found: assets/mushrooms/ (${directWebps.length} files) AND assets/assets/mushrooms/ (${nestedWebps.length} files)`
    );
  });

  it('[Tier 2] R3: every mushroom asset in grzybmap_app/assets/mushrooms/ is present and non-zero in build/web/', () => {
    assert.ok(fs.existsSync(ASSETS_MUSHROOMS_DIR), `Missing source assets directory: ${ASSETS_MUSHROOMS_DIR}`);
    const sourceAssets = fs.readdirSync(ASSETS_MUSHROOMS_DIR).filter((n) => !n.startsWith('.'));
    assert.ok(sourceAssets.length > 0, 'grzybmap_app/assets/mushrooms/ is empty');

    const directDir = path.join(BUILD_WEB_DIR, 'assets', 'mushrooms');
    const nestedDir = path.join(BUILD_WEB_DIR, 'assets', 'assets', 'mushrooms');

    for (const assetName of sourceAssets) {
      const inNested = path.join(nestedDir, assetName);
      const inDirect = path.join(directDir, assetName);
      const target = fs.existsSync(inNested) ? inNested : inDirect;
      assert.ok(
        fs.existsSync(target) && fs.statSync(target).size > 0,
        `Missing or empty mushroom asset in build/web/: ${assetName}`
      );
    }
  });

  it('[Tier 2] R3: build/web/ contains no stray backup, temp, or mobile installer files', () => {
    const forbiddenExts = new Set(['.apk', '.aab', '.ipa', '.bak', '.tmp']);
    const offending = walkFiles(BUILD_WEB_DIR).filter((f) =>
      forbiddenExts.has(path.extname(f).toLowerCase())
    );
    assert.equal(
      offending.length,
      0,
      `Stray non-web artifact(s) found in build/web/: ${offending.map((f) => path.relative(BUILD_WEB_DIR, f)).join(', ')}`
    );
  });

  // -------------------------------------------------------------------------
  // Tier 3: Cross-Artifact SHA-256 Parity
  // -------------------------------------------------------------------------
  it('[Tier 3] R3: SHA-256 byte-for-byte parity between web/lesnik.html and build/web/lesnik.html', () => {
    const src = path.join(WEB_SRC_DIR, 'lesnik.html');
    const dst = path.join(BUILD_WEB_DIR, 'lesnik.html');
    assertNonZeroFile(src, 'web/lesnik.html');
    assertNonZeroFile(dst, 'build/web/lesnik.html');
    assert.equal(
      sha256File(dst),
      sha256File(src),
      'build/web/lesnik.html is out of sync with grzybmap_app/web/lesnik.html (SHA-256 mismatch)'
    );
  });

  it('[Tier 3] R3: SHA-256 parity for manifest.json, favicon.png, and all web/icons/* into build/web/', () => {
    for (const rel of ['manifest.json', 'favicon.png']) {
      const src = path.join(WEB_SRC_DIR, rel);
      const dst = path.join(BUILD_WEB_DIR, rel);
      assertNonZeroFile(src, `web/${rel}`);
      assertNonZeroFile(dst, `build/web/${rel}`);
      assert.equal(
        sha256File(dst),
        sha256File(src),
        `build/web/${rel} is out of sync with grzybmap_app/web/${rel}`
      );
    }

    const srcIconsDir = path.join(WEB_SRC_DIR, 'icons');
    const srcIcons = walkFiles(srcIconsDir);
    assert.ok(srcIcons.length > 0, 'grzybmap_app/web/icons/ is empty');
    for (const srcIcon of srcIcons) {
      const rel = path.relative(WEB_SRC_DIR, srcIcon);
      const dstIcon = path.join(BUILD_WEB_DIR, rel);
      assertNonZeroFile(dstIcon, `build/web/${rel}`);
      assert.equal(
        sha256File(dstIcon),
        sha256File(srcIcon),
        `build/web/${rel} is out of sync with grzybmap_app/web/${rel}`
      );
    }
  });

  // -------------------------------------------------------------------------
  // Tier 4: Build Freshness
  // -------------------------------------------------------------------------
  it('[Tier 4] R3: build/web/main.dart.js is at least as fresh as lib/**, pubspec.yaml, and web/index.html', () => {
    const mainJsPath = path.join(BUILD_WEB_DIR, 'main.dart.js');
    assertNonZeroFile(mainJsPath, 'build/web/main.dart.js');
    const buildMtime = fs.statSync(mainJsPath).mtimeMs;

    const latestSourceMtime = Math.max(
      maxMtimeMs(path.join(APP_DIR, 'lib')),
      maxMtimeMs(path.join(APP_DIR, 'pubspec.yaml')),
      maxMtimeMs(path.join(WEB_SRC_DIR, 'index.html'))
    );

    assert.ok(
      buildMtime >= latestSourceMtime,
      `build/web/main.dart.js (${new Date(buildMtime).toISOString()}) is older than source files (${new Date(latestSourceMtime).toISOString()}); rebuild required`
    );
  });
});
