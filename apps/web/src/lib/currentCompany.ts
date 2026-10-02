// No page builds a company yet beyond Assemble's upload flow (itself still
// a stub), and there's no "list companies" endpoint — the API only supports
// create/show by id. Until Assemble wires up and calls setCurrentCompanyId
// on a fresh upload, pages that need a company fall back to an empty state.
const STORAGE_KEY = 'keel-company-id'

export function getCurrentCompanyId(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY)
  } catch {
    return null
  }
}

export function setCurrentCompanyId(id: string) {
  try {
    localStorage.setItem(STORAGE_KEY, id)
  } catch {
    // ignore — current company just won't persist for this viewer
  }
}
