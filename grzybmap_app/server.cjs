const http = require('http');
const fs = require('fs');
const path = require('path');
const https = require('https');

const PORT = 8088;
const WEB_DIR = path.join(__dirname, 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

const server = http.createServer((req, res) => {
  // CORS & WASM threading headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Parse URL
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  let pathname = parsedUrl.pathname;

  // Proxy for BDL WMS if requested via /api/bdl
  if (pathname.startsWith('/api/bdl')) {
    const targetUrl = `https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_BDL/MapServer/WMSServer${parsedUrl.search}`;
    console.log('[BDL REQ]', targetUrl);
    https.get(targetUrl, (proxyRes) => {
      let body = '';
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': proxyRes.headers['content-type'] || 'text/html',
        'Access-Control-Allow-Origin': '*'
      });
      proxyRes.on('data', chunk => {
        body += chunk;
        res.write(chunk);
      });
      proxyRes.on('end', () => {
        res.end();
        console.log(`[BDL RES ${proxyRes.statusCode}] ${body.slice(0, 300).replace(/\s+/g, ' ')}`);
      });
    }).on('error', (err) => {
      console.error('[BDL PROXY ERROR]', err.message);
      res.writeHead(502);
      res.end(`Proxy Error: ${err.message}`);
    });
    return;
  }

  // Proxy for IP Geolocation fallback via /api/geo
  if (pathname.startsWith('/api/geo')) {
    https.get('https://get.geojs.io/v1/ip/geo.json', (proxyRes) => {
      let body = '';
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      });
      proxyRes.on('data', chunk => {
        body += chunk;
        res.write(chunk);
      });
      proxyRes.on('end', () => {
        res.end();
        console.log(`[GEO RES ${proxyRes.statusCode}] ${body.slice(0, 100)}`);
      });
    }).on('error', (err) => {
      console.error('[GEO PROXY ERROR]', err.message);
      res.writeHead(502);
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  if (pathname === '/' || pathname === '') {
    pathname = '/index.html';
  }

  const filePath = path.join(WEB_DIR, pathname);

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // Fallback to index.html for SPA routing
      const indexPath = path.join(WEB_DIR, 'index.html');
      fs.readFile(indexPath, (err, data) => {
        if (err) {
          res.writeHead(404);
          res.end('Not Found');
        } else {
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
          res.end(data);
        }
      });
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, { 'Content-Type': contentType });
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`GrzybMap Flutter Web Server running at http://127.0.0.1:${PORT}`);
});
