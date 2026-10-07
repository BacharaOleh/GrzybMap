import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      '/api/bdl': {
        target: 'https://mapserver.bdl.lasy.gov.pl',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/bdl/, ''),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        }
      }
    }
  }
});
