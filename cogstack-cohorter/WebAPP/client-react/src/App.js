import { useEffect, useRef } from 'react';
import { mountCohorterApp } from './alpine-runtime';

function App() {
  const rootRef = useRef(null);

  useEffect(() => {
    if (!rootRef.current) return undefined;
    let dispose = () => {};
    let cancelled = false;

    mountCohorterApp(rootRef.current).then((cleanup) => {
      if (!cancelled) {
        dispose = cleanup;
      }
    }).catch((err) => {
      console.error(err);
      if (rootRef.current) {
        rootRef.current.innerHTML =
          '<div class=\"p-4 text-red-700\">Failed to load app template.</div>';
      }
    });

    return () => {
      cancelled = true;
      dispose();
    };
  }, []);

  return <div ref={rootRef} />;
}

export default App;
