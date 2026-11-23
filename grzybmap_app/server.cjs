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
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.apk': 'application/vnd.android.package-archive'
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

  // Proxy for BDL Export Tiles (Clean boundaries without text labels)
  if (pathname.startsWith('/api/bdl-tiles')) {
    const rawBbox = parsedUrl.searchParams.get('bbox') || parsedUrl.searchParams.get('BBOX') || '';
    const dynLayers = JSON.stringify([{
      id: 5,
      source: { type: 'mapLayer', mapLayerId: 5 },
      drawingInfo: { showLabels: false }
    }]);

    const targetUrl = `https://mapserver.bdl.lasy.gov.pl/ArcGIS/rest/services/WMS_BDL/MapServer/export?bbox=${encodeURIComponent(rawBbox)}&bboxSR=3857&imageSR=3857&size=256,256&format=png32&transparent=true&f=image&dynamicLayers=${encodeURIComponent(dynLayers)}`;

    https.get(targetUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': 'image/png',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=86400'
      });
      proxyRes.pipe(res);
    }).on('error', (err) => {
      console.error('[BDL TILES ERROR]', err.message);
      res.writeHead(502);
      res.end();
    });
    return;
  }

  // Proxy for BDL ArcGIS REST Query (Mushroom radar parcels)
  if (pathname.startsWith('/api/bdl-query')) {
    const targetUrl = `https://mapserver.bdl.lasy.gov.pl/ArcGIS/rest/services/WMS_BDL/MapServer/5/query${parsedUrl.search}`;
    https.get(targetUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      });
      proxyRes.pipe(res);
    }).on('error', (err) => {
      console.error('[BDL QUERY ERROR]', err.message);
      res.writeHead(502);
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

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

  // Proxy for Geocoding via /api/search
  if (pathname.startsWith('/api/search')) {
    const q = parsedUrl.searchParams.get('q') || '';
    const targetUrl = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&countrycodes=pl&format=json&limit=6&addressdetails=1`;
    const options = {
      headers: {
        'User-Agent': 'GrzybMap-App/1.0 (contact: grzybmap@lasy.pl)'
      }
    };
    https.get(targetUrl, options, (proxyRes) => {
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
        console.log(`[SEARCH RES ${proxyRes.statusCode}] found for query: ${q}`);
      });
    }).on('error', (err) => {
      console.error('[SEARCH PROXY ERROR]', err.message);
      res.writeHead(502);
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  // Serve Forester Dashboard at /lesnik or /lesnik.html
  if (pathname === '/lesnik' || pathname === '/lesnik.html') {
    const lesnikPath = path.join(__dirname, 'web', 'lesnik.html');
    fs.readFile(lesnikPath, (err, data) => {
      if (err) {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('Forester Dashboard Not Found');
      } else {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(data);
      }
    });
    return;
  }

  // Forest Reports API endpoints (/api/reports)
  const REPORTS_FILE = path.join(__dirname, 'data', 'reports.json');

  function getReports() {
    try {
      if (fs.existsSync(REPORTS_FILE)) {
        return JSON.parse(fs.readFileSync(REPORTS_FILE, 'utf8'));
      }
    } catch (e) {
      console.error('[REPORTS READ ERROR]', e.message);
    }
    return [];
  }

  function saveReports(reports) {
    try {
      const dataDir = path.dirname(REPORTS_FILE);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }
      fs.writeFileSync(REPORTS_FILE, JSON.stringify(reports, null, 2), 'utf8');
      return true;
    } catch (e) {
      console.error('[REPORTS WRITE ERROR]', e.message);
      return false;
    }
  }

  if (pathname === '/api/reports' && req.method === 'GET') {
    const reports = getReports();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(reports));
    return;
  }

  if (pathname === '/api/reports' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const newReport = JSON.parse(body);
        if (!newReport.id) {
          newReport.id = 'rep-' + Date.now();
        }
        if (!newReport.createdAt) {
          newReport.createdAt = new Date().toISOString();
        }
        if (!newReport.status) {
          newReport.status = 'pending';
        }
        if (typeof newReport.confirmationsCount !== 'number') {
          newReport.confirmationsCount = 1;
        }

        const reports = getReports();
        reports.unshift(newReport);
        saveReports(reports);

        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, report: newReport }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON payload' }));
      }
    });
    return;
  }

  if (pathname.startsWith('/api/reports/') && req.method === 'PATCH') {
    const reportId = pathname.replace('/api/reports/', '');
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const updates = JSON.parse(body);
        const reports = getReports();
        const target = reports.find(r => r.id === reportId);
        if (!target) {
          res.writeHead(404, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Report not found' }));
          return;
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

        saveReports(reports);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, report: target }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON' }));
      }
    });
    return;
  }

  if (pathname === '/' || pathname === '') {
    pathname = '/index.html';
  }

  const filePath = path.join(WEB_DIR, pathname);

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      // If request has a static file extension (e.g. .js, .wasm, .png), return 404 rather than corrupting with HTML
      const ext = path.extname(pathname);
      if (ext && ext !== '.html') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end(`File Not Found: ${pathname}`);
        return;
      }

      // Fallback to index.html for SPA client-side routing
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
    const responseHeaders = {
      'Content-Type': contentType,
      'Content-Length': stats.size,
      'Accept-Ranges': 'bytes'
    };
    if (ext === '.apk') {
      responseHeaders['Content-Disposition'] = 'attachment; filename="grzybmap.apk"';
    }

    res.writeHead(200, responseHeaders);
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`GrzybMap Flutter Web Server running at http://127.0.0.1:${PORT}`);
  console.log(`Serving static files from: ${WEB_DIR}`);
});
