import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.tsx';
import Terms from './components/pages/Terms.tsx'
import './index.css';

// Render the appropriate component based on the path
const path = window.location.pathname;
const Component = path === '/terms' ? Terms : App;

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Component />
  </StrictMode>
);
