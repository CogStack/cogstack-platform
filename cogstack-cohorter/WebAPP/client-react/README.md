# Cohorter Client (React Shell)

This folder contains the React-based frontend shell for Cohorter.

It keeps the existing Alpine-style template/data model behaviour, while using React for mounting, app lifecycle, and the top-level UI chrome (header, auth).

## What this app is

- React 18 app built with **Vite**
- `@cogstack/frontend-common-react` — provides `Header`, `UserSection`, `UserModal`, `Login`, and `AccessDenied` components
- Custom lightweight Alpine-like runtime (`src/alpine-runtime.js`)
- Data/state layer in `src/alpine-data.js`)
- HTML template composition using reusable partials in `public/components/`

## Requirements

- Node.js 18+
- npm
- A GitHub Packages token with `read:packages` scope (to install `@cogstack/frontend-common-react`)
- Cohorter backend server running at `http://localhost:3000` (proxied automatically in dev)

## Environment variables

A single `.env` file at the **`cogstack-cohorter/` root** (one level up from `WebAPP/`) is shared between Vite and `docker-compose`. Copy `.env.example` there and fill in values:

```bash
cp ../../.env.example ../../.env
```

| Variable | Required | Description |
|---|---|---|
| `NPM_TOKEN` | Yes | GitHub Packages token (`read:packages`) for installing the library |
| `VITE_OAUTH2_USERINFO_PATH` | No | Override the `/oauth2/userinfo` path |
| `VITE_OAUTH2_LOGIN_PATH` | No | Override the `/oauth2/sign_in` path |
| `VITE_OAUTH2_LOGOUT_PATH` | No | Override the `/oauth2/sign_out?rd=/` path |

`VITE_*` variables are baked into the client bundle at build time.

## Install

```bash
export NPM_TOKEN=ghp_your_token_here   # or set in your shell profile
npm install
```

## Run in development

```bash
npm run dev
```

Vite serves on `http://localhost:5173` and proxies all API and auth routes (`/oauth2`, `/query`, `/nl2dsl`, `/export`, etc.) to the Express backend at `http://localhost:3000`.

## Build for production

```bash
npm run build
```

Output goes to `dist/`. The Express server in `WebAPP/server/` serves this folder as static files.

## Project structure

```text
client-react/
├── index.html                  
├── public/
│   ├── app-template.html
│   ├── components/
│   │   ├── topbar.html         
│   │   ├── sidebar-desktop.html
│   │   ├── sidebar-mobile.html
│   │   ├── query-v1.html
│   │   ├── query-nl.html
│   │   ├── results-main.html
│   │   ├── overlays.html
│   │   └── busy-pill.html
│   └── assets/
├── src/
│   ├── main.jsx               
│   ├── App.jsx                
│   ├── alpine-runtime.js
│   ├── alpine-data.js
│   └── template-components.js
├── tailwind.config.js
├── vite.config.js
├── package.json
└── dist/                       
```

## Runtime flow

1. `src/main.jsx` mounts the React app and imports the library CSS (`@cogstack/frontend-common-react/style.css`).
2. `src/App.jsx` renders the `Header` (with `UserSection`) and calls `mountCohorterApp()`.
3. The runtime fetches `public/app-template.html`.
4. `coh-include` nodes are expanded from `public/components/*.html`.
5. Alpine-like directives are compiled and bound to state from `createAppState()`.
6. Initial query submission runs automatically.

## Authentication

`UserSection` fetches `/oauth2/userinfo` on mount. Before oauth2-proxy is deployed, the Express server returns a configurable default user from environment variables (`DEFAULT_USER_*`). Once oauth2-proxy is deployed it intercepts `/oauth2/*` before Express, so the stub has no effect.

## Backend API endpoints used

| Method | Path | Description |
|---|---|---|
| `GET` | `/oauth2/userinfo` | Current user info (stub or oauth2-proxy) |
| `POST` | `/keywords` | Keyword suggestions |
| `POST` | `/nl2dsl` | Natural language → DSL compilation |
| `POST` | `/get_query_result` | Execute a cohort query |
| `POST` | `/get_filter_result` | Apply filters to a query result |
| `POST` | `/get_age` | Age distribution for a cohort |
| `POST` | `/get_top_terms` | Top clinical terms for a cohort |
| `POST` | `/compare_query` | Compare two queries |
| `POST` | `/export` | Export patient list |
| `POST` | `/admin_login` | Admin session login (pre-oauth2-proxy) |
| `POST` | `/admin_logout` | Admin session logout (pre-oauth2-proxy) |

## Notes

- This is an incremental migration: React hosts the app and renders the top chrome, while template behaviour is still Alpine-style.
- Reusable UI sections are maintained as HTML partials in `public/components/`.
- Tailwind `preflight` is disabled in `tailwind.config.js` to avoid conflicts with the Alpine.js Tailwind CSS loaded via `public/assets/css/tailwind.output.css`.
