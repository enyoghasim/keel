import '@testing-library/jest-dom/vitest'

// jsdom doesn't implement matchMedia — stub a "light, no preference" default
// so components that read the system theme don't crash. Tests that care about
// a specific value (see src/lib/theme.test.ts) override this per-test.
if (!window.matchMedia) {
  window.matchMedia = (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  })
}
