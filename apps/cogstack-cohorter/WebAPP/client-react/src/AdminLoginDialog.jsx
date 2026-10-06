import { useState, useEffect, useRef } from 'react';
import { X, Shield } from 'lucide-react';

/**
 * AdminLoginDialog
 *
 * A controlled modal dialog for admin password entry.
 *
 * Props:
 *   isOpen   – whether the dialog is visible
 *   onClose  – called when the dialog should close (cancel or successful login)
 *   stateRef – ref to the Alpine.js reactive state; on success, sets
 *              stateRef.current.admin_logged_in = true so the rest of the app
 *              (HeaderControls admin menu, export button, etc.) updates.
 */
export function AdminLoginDialog({ isOpen, onClose, stateRef }) {
  const [password, setPassword]   = useState('');
  const [message,  setMessage]    = useState('');
  const [loading,  setLoading]    = useState(false);
  const inputRef = useRef(null);

  // Reset form and focus password field every time the dialog opens.
  useEffect(() => {
    if (isOpen) {
      setPassword('');
      setMessage('');
      // Small delay so the element is mounted before focus.
      setTimeout(() => inputRef.current?.focus(), 0);
    }
  }, [isOpen]);

  // Close on Escape.
  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [isOpen, onClose]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!password) return;
    setLoading(true);
    setMessage('');
    try {
      const resp = await fetch('/admin_login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password }),
      });
      const data = await resp.json();
      if (data.msg === 'ok') {
        // Push the logged-in flag into Alpine.js reactive state so that
        // HeaderControls re-reads it on next dropdown open and the rest
        // of the Alpine.js bindings that depend on admin_logged_in update.
        if (stateRef.current) {
          stateRef.current.admin_logged_in = true;
        }
        onClose();
      } else {
        setMessage('Password incorrect. Please try again.');
        setPassword('');
        inputRef.current?.focus();
      }
    } catch {
      setMessage('Something went wrong. Please try again later.');
      setPassword('');
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    /* Backdrop — click outside to close */
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="admin-login-title"
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
          <Shield className="w-5 h-5 text-purple-600 flex-shrink-0" />
          <h2 id="admin-login-title" className="text-lg font-semibold text-gray-900 dark:text-white">
            Admin Login
          </h2>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label
              htmlFor="admin-password"
              className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1"
            >
              Password
            </label>
            <input
              ref={inputRef}
              id="admin-password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter admin password"
              disabled={loading}
              autoComplete="current-password"
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md
                         text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white
                         placeholder-gray-400 dark:placeholder-gray-500
                         focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent
                         disabled:opacity-50"
            />
          </div>

          {/* Error / status message */}
          {message && (
            <p className="text-sm text-orange-600 dark:text-orange-400" role="alert">
              {message}
            </p>
          )}

          {/* Actions */}
          <div className="flex gap-3 pt-2">
            <button
              type="submit"
              disabled={loading || !password}
              className="flex-1 px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-md
                         hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed
                         focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2
                         transition-colors"
            >
              {loading ? 'Logging in…' : 'Login'}
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
        </form>

      </div>
    </div>
  );
}
