import { useEffect, useRef, useState } from 'react';
import { Header, UserSection } from '@cogstack/frontend-common-react';
import { PanelLeftOpen } from 'lucide-react';
import { mountCohorterApp } from './alpine-runtime';
import { HeaderControls } from './HeaderControls';
import { FilterSidebar } from './FilterSidebar';
import { AdminLoginDialog } from './AdminLoginDialog';
import { LoadQueryDialog } from './LoadQueryDialog';

// Fixed header height
const HEADER_HEIGHT = 80;

const runtimeConfig = (typeof window !== 'undefined' && window.__RUNTIME_CONFIG__) || {};
const USERINFO_PATH = runtimeConfig.OAUTH2_USERINFO_PATH || '/oauth2/userinfo';
const LOGIN_PATH    = runtimeConfig.OAUTH2_LOGIN_PATH    || '/oauth2/sign_in';
const LOGOUT_PATH   = runtimeConfig.OAUTH2_LOGOUT_PATH   || '/oauth2/sign_out?rd=/';

function App() {
  const rootRef  = useRef(null);
  // stateRef holds the Alpine.js reactive state once mountCohorterApp resolves.
  const stateRef = useRef(null);

  // subscribe is the function returned by mountCohorterApp that lets React
  // components listen to Alpine.js state changes. Stored as () => fn so that
  // React's useState does not treat the function itself as an updater.
  const [subscribe, setSubscribe] = useState(null);

  // Sidebar is shown by default; the Filters button in the content area toggles it.
  const [sidebarOpen, setSidebarOpen] = useState(true);

  // Admin login dialog — opened by the Settings menu in HeaderControls.
  const [adminLoginOpen, setAdminLoginOpen] = useState(false);

  // Load query dialog — opened by the Settings menu in HeaderControls.
  const [loadQueryOpen, setLoadQueryOpen] = useState(false);

  useEffect(() => {
    if (!rootRef.current) return undefined;
    let dispose = () => {};
    let cancelled = false;

    mountCohorterApp(rootRef.current).then(({ cleanup, state, subscribe: sub }) => {
      if (!cancelled) {
        dispose = cleanup;
        stateRef.current = state;
        // Wrap in arrow fn so useState doesn't invoke it as an updater.
        setSubscribe(() => sub);
      }
    }).catch((err) => {
      console.error(err);
      if (rootRef.current) {
        rootRef.current.innerHTML =
          '<div class="p-4 text-red-700">Failed to load app template.</div>';
      }
    });

    return () => {
      cancelled = true;
      dispose();
    };
  }, []);

  return (
    <div>
      <Header
        applicationName="Cohorter"
        rightSlot={
          <div className="flex items-center gap-2">
            <HeaderControls
              stateRef={stateRef}
              onAdminLogin={() => setAdminLoginOpen(true)}
              onLoadQuery={() => setLoadQueryOpen(true)}
            />
            <UserSection
              applicationName="cohorter"
              userInfoPath={USERINFO_PATH}
              loginPath={LOGIN_PATH}
              logoutPath={LOGOUT_PATH}
            />
          </div>
        }
      />

      {/* Content area: sidebar + Alpine.js app side by side */}
      <div style={{ paddingTop: HEADER_HEIGHT }} className="flex min-h-screen bg-gray-50 dark:bg-gray-900">
        <FilterSidebar
          stateRef={stateRef}
          subscribe={subscribe}
          isOpen={sidebarOpen}
          onToggle={() => setSidebarOpen((o) => !o)}
        />
        {/* Alpine.js app root — flex-1 so it fills remaining width */}
        <div className="flex flex-col flex-1 min-w-0">
          {/* Show-filters button — only visible when the sidebar is collapsed */}
          {!sidebarOpen && (
            <div className="px-4 pt-4">
              <button
                type="button"
                onClick={() => setSidebarOpen(true)}
                className="inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm border
                           border-gray-300 bg-white dark:bg-gray-800 dark:border-gray-600
                           text-gray-700 dark:text-gray-200
                           hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm"
                aria-label="Show filters"
              >
                <PanelLeftOpen className="w-4 h-4" />
                <span>Filters</span>
              </button>
            </div>
          )}
          <div ref={rootRef} className="flex flex-col flex-1 min-w-0" />
        </div>
      </div>
      <AdminLoginDialog
        isOpen={adminLoginOpen}
        onClose={() => setAdminLoginOpen(false)}
        stateRef={stateRef}
      />
      <LoadQueryDialog
        isOpen={loadQueryOpen}
        onClose={() => setLoadQueryOpen(false)}
        stateRef={stateRef}
      />
    </div>
  );
}

export default App;
