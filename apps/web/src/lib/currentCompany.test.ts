import { beforeEach, describe, expect, it } from 'vitest'
import { getCurrentCompanyId, setCurrentCompanyId } from './currentCompany'

describe('currentCompany', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('returns null when nothing is stored', () => {
    expect(getCurrentCompanyId()).toBeNull()
  })

  it('persists and returns the id that was set', () => {
    setCurrentCompanyId('42')
    expect(getCurrentCompanyId()).toBe('42')
  })
})
