import { useEffect, useRef, useState } from 'react';
import { Sun, Moon, Settings } from 'lucide-react';

// ── Component ─────────────────────────────────────────────────────────────────

/**
 * App-specific controls rendered in the Header's rightSlot.
 *
 * Delegates actions to the Alpine.js reactive state (via stateRef) so that
 * the rest of the app stays in sync without duplicating any logic here.
 */
export function HeaderControls({ stateRef }) {
  // Mirror isDark from localStorage so the icon renders correctly on load.
  const [isDark, setIsDark] = useState(() => localStorage.getItem('theme') === 'dark');
  const [settingsOpen, setSettingsOpen] = useState(false);
  const settingsRef = useRef(null);

  // Version links derived from the current URL (matches alpine-data.js logic).
  const url = new URL(window.location.href);
  const isV1 = url.searchParams.get('version') === '1';
  const v1Href     = (() => { const u = new URL(window.location.href); u.searchParams.set('version', '1'); return u.pathname + u.search + u.hash; })();
  const latestHref = (() => { const u = new URL(window.location.href); u.searchParams.delete('version'); return u.pathname + u.search + u.hash; })();

  // Safely call a method on the Alpine.js state.
  // Logs a warning when the Alpine.js app is not yet mounted (stateRef.current
  // is null) or the requested method does not exist on the state object.
  const call = (method) => {
    if (!stateRef.current) {
      console.warn(`HeaderControls: Alpine.js state not ready (tried to call "${method}")`);
      return;
    }
    if (typeof stateRef.current[method] !== 'function') {
      console.warn(`HeaderControls: "${method}" is not a function on Alpine.js state`);
      return;
    }
    stateRef.current[method]();
  };

  const handleTheme = () => { call('toggleTheme'); setIsDark(d => !d); };
  const handleSave    = () => { call('save_query');      setSettingsOpen(false); };
  const handleLoad    = () => { call('load_query');      setSettingsOpen(false); };
  const handleExport  = () => { call('export_patients'); setSettingsOpen(false); };
  const handleAdminLogin  = () => { call('admin_login');  setSettingsOpen(false); };
  const handleAdminLogout = () => { call('admin_logout'); setSettingsOpen(false); };

  // Close settings on outside click or Escape.
  useEffect(() => {
    if (!settingsOpen) return;
    const onMouse = (e) => {
      if (settingsRef.current && !settingsRef.current.contains(e.target)) {
        setSettingsOpen(false);
      }
    };
    const onKey = (e) => { if (e.key === 'Escape') setSettingsOpen(false); };
    document.addEventListener('mousedown', onMouse);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onMouse);
      document.removeEventListener('keydown', onKey);
    };
  }, [settingsOpen]);

  return (
    <div className="flex items-center gap-2">

      {/* Theme toggle — sun shown in light mode, moon in dark mode */}
      <button onClick={handleTheme} className="p-2 rounded" title="Toggle theme">
        {isDark ? <Moon className="w-5 h-5" /> : <Sun className="w-5 h-5" />}
      </button>

      {/* Settings dropdown
          .header-dropdown on the <ul> lets index.css give dropdown items
          normal dark text instead of the header's white override. */}
      <div className="relative" ref={settingsRef}>
        <button
          onClick={() => setSettingsOpen(o => !o)}
          className="p-2 rounded"
          title="Settings"
          aria-haspopup="true"
          aria-expanded={settingsOpen}
          aria-label="Settings"
        >
          <Settings className="w-5 h-5" />
        </button>

        {settingsOpen && (() => {
          // Re-read admin_logged_in each time the dropdown opens so we pick up
          // any login / logout that happened since the component last rendered.
          const adminLoggedIn = !!stateRef.current?.admin_logged_in;
          return (
            <ul
              className="header-dropdown absolute right-0 mt-2 w-48 p-2 space-y-1 bg-white border border-gray-200 rounded-md shadow-lg z-50"
              role="menu"
              aria-label="Settings menu"
            >
              <li>
                <a
                  href={isV1 ? latestHref : v1Href}
                  className="cursor-pointer inline-flex items-center w-full px-2 py-1 text-sm rounded-md text-gray-700 hover:bg-gray-100"
                >
                  {isV1 ? 'Go to latest (NL)' : 'Go to old version'}
                </a>
              </li>
              <li role="none">
                <button onClick={handleSave} role="menuitem" className="w-full text-left px-2 py-1 text-sm rounded">
                  Save Query
                </button>
              </li>
              <li role="none">
                <button onClick={handleLoad} role="menuitem" className="w-full text-left px-2 py-1 text-sm rounded">
                  Load Query
                </button>
              </li>
              {!adminLoggedIn && (
                <li role="none">
                  <button onClick={handleAdminLogin} role="menuitem" className="w-full text-left px-2 py-1 text-sm rounded">
                    Admin Login
                  </button>
                </li>
              )}
              {adminLoggedIn && (
                <>
                  <li role="none">
                    <button onClick={handleExport} role="menuitem" className="w-full text-left px-2 py-1 text-sm rounded">
                      Export patients
                    </button>
                  </li>
                  <li role="none">
                    <button onClick={handleAdminLogout} role="menuitem" className="w-full text-left px-2 py-1 text-sm rounded">
                      Admin Logout
                    </button>
                  </li>
                </>
              )}
            </ul>
          );
        })()}
      </div>

    </div>
  );
}
