import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './index.css';
import '@cogstack/frontend-common-react/style.css';

const root = createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
