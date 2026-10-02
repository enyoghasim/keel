// The agent conversation the command bar had open, remembered per company
// so a page refresh brings the thread back (the runs themselves are saved
// server-side; only which conversation to show lives here).
const key = (companyId: string) => `keel-agent-conversation:${companyId}`

export function getStoredConversationId(companyId: string): string | null {
  try {
    return localStorage.getItem(key(companyId))
  } catch {
    return null
  }
}

export function setStoredConversationId(companyId: string, conversationId: string | null) {
  try {
    if (conversationId) localStorage.setItem(key(companyId), conversationId)
    else localStorage.removeItem(key(companyId))
  } catch {
    // ignore — the conversation just won't survive a refresh for this viewer
  }
}
