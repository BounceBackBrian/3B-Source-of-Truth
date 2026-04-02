# SYSTEM_RECOVERY_MAP

## Recovery Locations
- Primary recovery vault: `E:\OneDrive - Bounce Back Coffee Beans Llc\Recovery`
- Pre-merge snapshots: `...\Recovery\PreMerge\YYYY-MM-DD`
- Legacy root snapshots: `...\Recovery\LegacyRoots\YYYY-MM-DD`

## Minimum Recovery Artifacts per Move
- Full source path list
- Destination mapping list
- Hash list (or at minimum size + modified time index)
- Rollback script or manual rollback steps
- Operator and approval record

## Rollback Rule
If post-merge validation fails, rollback to last successful checkpoint and freeze additional moves until discrepancy is resolved.
