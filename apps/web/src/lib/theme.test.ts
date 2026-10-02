import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { applyTheme, effectiveTheme, initTheme, toggleTheme } from './theme'

function mockMatchMedia(prefersDark: boolean) {
  window.matchMedia = vi.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-color-scheme: dark)' && prefersDark,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })) as unknown as typeof window.matchMedia
}

describe('theme', () => {
  beforeEach(() => {
    localStorage.clear()
    document.documentElement.classList.remove('dark')
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('falls back to the system preference when nothing is stored', () => {
    mockMatchMedia(true)
    expect(effectiveTheme()).toBe('dark')

    mockMatchMedia(false)
    expect(effectiveTheme()).toBe('light')
  })

  it('prefers a stored choice over the system preference', () => {
    mockMatchMedia(true)
    localStorage.setItem('keel-theme', 'light')
    expect(effectiveTheme()).toBe('light')
  })

  it('applyTheme toggles the dark class on the root element', () => {
    applyTheme('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(true)

    applyTheme('light')
    expect(document.documentElement.classList.contains('dark')).toBe(false)
  })

  it('initTheme applies the effective theme on load', () => {
    mockMatchMedia(true)
    initTheme()
    expect(document.documentElement.classList.contains('dark')).toBe(true)
  })

  it('toggleTheme flips the theme, persists it, and returns the new value', () => {
    mockMatchMedia(false)
    const next = toggleTheme()

    expect(next).toBe('dark')
    expect(localStorage.getItem('keel-theme')).toBe('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(true)

    const again = toggleTheme()
    expect(again).toBe('light')
    expect(localStorage.getItem('keel-theme')).toBe('light')
  })
})
