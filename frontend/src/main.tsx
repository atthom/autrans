import { StrictMode, useState, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import { MantineProvider, createTheme } from '@mantine/core'
import '@mantine/core/styles.css'
import '@mantine/dates/styles.css'
import './index.css'
import App from './App.tsx'

const theme = createTheme({
  primaryColor: 'teal',
  respectReducedMotion: false,
});

function Root() {
  const [colorScheme, setColorScheme] = useState<'light' | 'dark'>(
    document.documentElement.classList.contains('dark') ? 'dark' : 'light'
  );

  useEffect(() => {
    // Watch for changes to the 'dark' class on document.documentElement
    const observer = new MutationObserver(() => {
      const isDark = document.documentElement.classList.contains('dark');
      setColorScheme(isDark ? 'dark' : 'light');
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    });

    return () => observer.disconnect();
  }, []);

  return (
    <StrictMode>
      <MantineProvider key={colorScheme} theme={theme} forceColorScheme={colorScheme}>
        <App />
      </MantineProvider>
    </StrictMode>
  );
}

createRoot(document.getElementById('root')!).render(<Root />)
