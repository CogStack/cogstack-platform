import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Express server port (same origin in production; proxied in dev)
const API_ORIGIN = 'http://localhost:3000';

// Share the named environment file with Compose; image builds can omit it.
const ENV_FILE = new URL('../../env/cohorter.env', import.meta.url);
if (existsSync(ENV_FILE)) loadEnvFile(ENV_FILE);

export default defineConfig({
  plugins: [react()],
  envDir: false,

  build: {
    outDir: 'dist',
    // Express serves dist/ as static files — keep the output structure flat
    emptyOutDir: true,
  },

  server: {
    port: 5173,
    // During development, forward API and auth calls to the Express backend.
    // In production the Express server serves the built dist/ directly, so
    // no proxy is involved.
    proxy: {
      '/oauth2':        { target: API_ORIGIN, changeOrigin: true },
      '/query':         { target: API_ORIGIN, changeOrigin: true },
      '/compare_query': { target: API_ORIGIN, changeOrigin: true },
      '/nl2dsl':        { target: API_ORIGIN, changeOrigin: true },
      '/admin_login':   { target: API_ORIGIN, changeOrigin: true },
      '/admin_logout':  { target: API_ORIGIN, changeOrigin: true },
      '/export':        { target: API_ORIGIN, changeOrigin: true },
      // Alpine.js fetches app-template and component HTML at runtime.
      // These are static files in public/ — served by Vite directly, no proxy needed.
    },
  },
});
