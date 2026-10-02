import type { PromptVersion } from 'api-types'

/** One bar per evaluated version of a prompt, oldest first (SPEC.md section 12's chart across prompt versions). */
export function versionAccuracyPoints(versions: PromptVersion[], promptKey: string) {
  return versions
    .filter((version) => version.key === promptKey && version.latest_run?.accuracy != null)
    .sort((a, b) => a.version - b.version)
    .map((version) => ({ label: `v${version.version}`, accuracy: version.latest_run!.accuracy as number }))
}
