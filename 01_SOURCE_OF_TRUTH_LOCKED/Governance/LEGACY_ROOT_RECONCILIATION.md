# LEGACY_ROOT_RECONCILIATION

## Decision Record
- **Approved canonical root:** `E:\OneDrive - Bounce Back Coffee Beans Llc`
- **Prohibited parallel roots:** `E:\3B_ECOSYSTEM_V1.1_CLEAN`, `E:\AGENT-ORCHESTRATION`
- **Allowed mirrors:** only under canonical root with explicit mirror labeling.

## Legacy Handling
1. `E:\3B_ECOSYSTEM_V1.1_CLEAN` → classify each subtree:
   - KEEP if active + unique.
   - MERGE into canonical equivalent if duplicate.
   - ARCHIVE if stale.
2. `E:\AGENT-ORCHESTRATION` → preserve only governed automation components; relocate into `...\Operations\Agent-Orchestration`.
3. Any duplicate E:\ root discovered during scan → REDIRECT marker + archive after recovery checkpoint.

## Safety Gate
No deletion is permitted before:
- content hash/duplicate verification,
- backup checkpoint,
- move log entry (source, destination, operator, datetime UTC).
