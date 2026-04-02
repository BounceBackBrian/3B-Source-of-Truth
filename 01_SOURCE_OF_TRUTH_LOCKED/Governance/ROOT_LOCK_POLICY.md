# ROOT_LOCK_POLICY

## Canonical Root (Locked)
- **Canonical execution root:** `E:\OneDrive - Bounce Back Coffee Beans Llc`
- **Canonical authority layer:** `E:\OneDrive - Bounce Back Coffee Beans Llc\01_SOURCE_OF_TRUTH_LOCKED`
- **Primary business Source of Truth:** `E:\OneDrive - Bounce Back Coffee Beans Llc\3B Source of Truth -SharePoint Truth - Documents`

## Prohibited Parallel Roots
- `E:\3B_ECOSYSTEM_V1.1_CLEAN`
- `E:\AGENT-ORCHESTRATION`
- Any new top-level root under `E:\` that is treated as official.

## Allowed Exceptions
- Local mirrors and repo working copies are allowed only if they contain an explicit pointer to the canonical root.
- Recovery snapshots are allowed under `E:\OneDrive - Bounce Back Coffee Beans Llc\Recovery`.

## Enforcement Rules
1. One root only for active execution.
2. One product = one Space path.
3. Any duplicate official workspace is immediately reclassified as mirror/archive/deprecated.
4. No destructive deletion until duplicate status is verified and recoverable backup exists.
