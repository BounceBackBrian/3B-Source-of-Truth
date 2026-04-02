# OFFICIAL_FILE_MERGE_RUNBOOK

This runbook is for executing your requested merge of official clean files into:
`E:\OneDrive - Bounce Back Coffee Beans Llc\01_SOURCE_OF_TRUTH_LOCKED`

## PowerShell Execution Steps (Windows host)

```powershell
$canonical = 'E:\OneDrive - Bounce Back Coffee Beans Llc\01_SOURCE_OF_TRUTH_LOCKED'
$legacyRoots = @(
  'E:\01_SOURCE_OF_TRUTH_LOCKED',
  'E:\3B Source of Truth -SharePoint Truth - Documents - Copy',
  'E:\3B_ECOSYSTEM_V1.1_CLEAN',
  'E:\AGENT-ORCHESTRATION'
)

New-Item -ItemType Directory -Force -Path "$canonical\_merge_logs" | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

foreach ($root in $legacyRoots) {
  if (Test-Path $root) {
    $name = Split-Path $root -Leaf
    robocopy $root "$canonical\_staging\$name" /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /XJ /NFL /NDL /NP /LOG+:"$canonical\_merge_logs\${timestamp}_$name.log"
  }
}
```

## Post-Copy Triage
1. Classify copied folders as Tier 1/2/3/Deprecated.
2. Keep one canonical file per policy/plan.
3. Move superseded items to `...\Archives\Superseded`.
4. Leave redirect notes in old locations.

## Validation Checklist
- No required file missing.
- Canonical path references updated.
- Duplicate official workspaces removed from active use.
- Recovery snapshot exists before deletions.
