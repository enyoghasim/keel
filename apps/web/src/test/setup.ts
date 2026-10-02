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

// jsdom doesn't implement ResizeObserver, which React Flow (OrgCanvas) uses
// to measure its viewport — stub a no-op so it mounts instead of throwing.
if (!window.ResizeObserver) {
  window.ResizeObserver = class ResizeObserver {
    observe() {}
    unobserve() {}
    disconnect() {}
  }
}

// jsdom doesn't implement scrollIntoView, which cmdk (CommandBar) calls to
// keep the selected item visible.
if (!Element.prototype.scrollIntoView) {
  Element.prototype.scrollIntoView = () => {}
}

// jsdom lacks the pointer-capture APIs Radix Select (the shadcn Select) uses
// when opened with a click.
if (!Element.prototype.hasPointerCapture) {
  Element.prototype.hasPointerCapture = () => false
  Element.prototype.setPointerCapture = () => {}
  Element.prototype.releasePointerCapture = () => {}
}
