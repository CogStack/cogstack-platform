import { useState, useEffect, useRef } from 'react';
import { X, FolderOpen, FileText } from 'lucide-react';

/**
 * LoadQueryDialog
 *
 * A controlled modal dialog for loading a saved query from a .txt file.
 *
 * Props:
 *   isOpen   – whether the dialog is visible
 *   onClose  – called when the dialog should close
 *   stateRef – ref to the Alpine.js reactive state; on load, writes
 *              query / filter / compare_query back into Alpine.js and calls
 *              submit_query() so the results refresh automatically.
 */
export function LoadQueryDialog({ isOpen, onClose, stateRef }) {
  const [file,    setFile]    = useState(null);
  const [error,   setError]   = useState('');
  const [loading, setLoading] = useState(false);
  const inputRef = useRef(null);

  // Reset state every time the dialog opens.
  useEffect(() => {
    if (isOpen) {
      setFile(null);
      setError('');
      setLoading(false);
    }
  }, [isOpen]);

  // Close on Escape.
  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [isOpen, onClose]);

  const handleFileChange = (e) => {
    const selected = e.target.files?.[0] ?? null;
    setFile(selected);
    setError('');
  };

  const handleLoad = () => {
    if (!file) return;
    setLoading(true);
    setError('');

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const loaded = JSON.parse(e.target.result);
        const s = stateRef.current;
        if (!s) throw new Error('App state not ready.');

        // Write the loaded values back into the Alpine.js reactive proxy.
        // Each assignment goes through the proxy set trap and schedules a
        // DOM update, exactly as the original handle_load_query() did.
        s.query         = loaded.query;
        s.filter        = loaded.filter;
        s.compare_query = loaded.compare_query;

        // Re-run the query so results update immediately.
        if (typeof s.submit_query === 'function') s.submit_query();

        onClose();
      } catch {
        setError('Invalid file — please select a valid query .txt file.');
      } finally {
        setLoading(false);
      }
    };
    reader.onerror = () => {
      setError('Could not read the file. Please try again.');
      setLoading(false);
    };
    reader.readAsText(file);
  };

  if (!isOpen) return null;

  return (
    /* Backdrop — click outside to close */
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="load-query-title"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
      onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      <div className="relative bg-white dark:bg-gray-800 rounded-lg shadow-xl w-full max-w-sm mx-4 p-6">

        {/* Close ✕ */}
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute top-4 right-4 p-1 rounded-sm text-gray-400 hover:text-gray-600
                     dark:text-gray-500 dark:hover:text-gray-300 transition-colors"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Title */}
        <div className="flex items-center gap-3 mb-6">
          <FolderOpen className="w-5 h-5 text-purple-600 flex-shrink-0" />
          <h2 id="load-query-title" className="text-lg font-semibold text-gray-900 dark:text-white">
            Load Query
          </h2>
        </div>

        <div className="space-y-4">
          {/* File picker */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Select a saved query file (.txt)
            </label>

            {/* Styled drop-zone / file button */}
            <div
              onClick={() => inputRef.current?.click()}
              className="flex flex-col items-center justify-center gap-2 w-full px-4 py-6
                         border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-md
                         cursor-pointer hover:border-purple-400 dark:hover:border-purple-500
                         hover:bg-purple-50 dark:hover:bg-purple-900/20 transition-colors"
            >
              {file ? (
                <>
                  <FileText className="w-6 h-6 text-purple-600" />
                  <span className="text-sm font-medium text-gray-700 dark:text-gray-300 text-center break-all">
                    {file.name}
                  </span>
                  <span className="text-xs text-gray-400">Click to choose a different file</span>
                </>
              ) : (
                <>
                  <FolderOpen className="w-6 h-6 text-gray-400" />
                  <span className="text-sm text-gray-500 dark:text-gray-400">
                    Click to browse
                  </span>
                </>
              )}
            </div>

            {/* Hidden native file input */}
            <input
              ref={inputRef}
              type="file"
              accept=".txt"
              onChange={handleFileChange}
              className="hidden"
            />
          </div>

          {/* Error message */}
          {error && (
            <p className="text-sm text-red-600 dark:text-red-400" role="alert">
              {error}
            </p>
          )}

          {/* Actions */}
          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={handleLoad}
              disabled={!file || loading}
              className="flex-1 px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-md
                         hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed
                         focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2
                         transition-colors"
            >
              {loading ? 'Loading…' : 'Load'}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 bg-gray-100 dark:bg-gray-700
                         text-gray-700 dark:text-gray-300 text-sm font-medium rounded-md
                         hover:bg-gray-200 dark:hover:bg-gray-600
                         focus:outline-none focus:ring-2 focus:ring-gray-400 focus:ring-offset-2
                         transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}
