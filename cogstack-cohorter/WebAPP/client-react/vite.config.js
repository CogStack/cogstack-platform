import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Express server port (same origin in production; proxied in dev)
const API_ORIGIN = 'http://localhost:3000';

// Point Vite at the cogstack-cohorter/ root so that it reads the same .env
// as docker-compose, eliminating the need for a separate client-react/.env.
// Both `npm run dev` (Vite) and `docker-compose build` resolve vars from one file.
const ENV_DIR = '../../';

export default defineConfig({
  plugins: [react()],
  envDir: ENV_DIR,

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
