# 3B Ecosystem Unification — Master Review & Merge Plan

## Task Summary
Reviewed the repository artifacts and merged current V1 direction into a single ecosystem plan anchored on **3B Id** and **3B Business Id** with Supabase as backend system-of-record.

## Files Scanned
- `Edgewood/vibespace_hardening/001_hardened_v1.sql`
- `Edgewood/vibespace_hardening/supabase/migrations/001_hardened_v1.sql`
- `Edgewood/vibespace_hardening/FLUTTER_3B_RENTAL_PRO_V1_FACEPLATES.md`
- `Edgewood/vibespace_hardening/FLUTTER_IMPLEMENTATION_GUIDE.md`
- `Edgewood/vibespace_hardening/DEPLOY_CUTOVER_CHECKLIST_2026-02-20.md`
- `Edgewood/vibespace_hardening/PROD_SHIP_RUNBOOK_2026-02-20.md`
- `Edgewood/vibespace_hardening/VIBESPACE_REPO_DEPLOY_RUNBOOK.md`
- `Edgewood/vibespace_hardening/STABILIZATION_PROTOCOL_2026-02-20.md`
- `V1-FULL-Execution-Pack/Docs/*.md`
- `V1-FULL-Execution-Pack/Execution/*.md`

## Drift Report

### ✅ Aligned
- Supabase-first backend and RLS-heavy design are already present in hardened SQL.
- VibeSpace is treated as the front-door product with production hardening guidance.
- Payment/ledger and oversight audit logging patterns are established and reusable in the unified model.

### ❌ Misalignments flagged (resolved in unified migration)
- Existing schema is optimized for Rental Pro lane (`tenant_id` + `business_id`) but does not define canonical **profiles.users** / **profiles.businesses** as central 3B identity tables.
- Credit Builders + Vault + Dispute AI tables are missing from current migrations.
- Domain-level routing standards are not codified as one deploy contract across all lanes.
- Observability exists for payment lane (`oversight_logs`) but not as ecosystem-wide event sink.

### 🔄 Merge proposals
- Introduce canonical schemas: `profiles`, `vibe_space`, `credit_builders`, `data_core`.
- Keep strict RLS keyed by authenticated **3B Id** and **3B Business Id** claim.
- Add Vault storage buckets and storage policies for private reports + dispute artifacts.
- Normalize event logging into `data_core.event_logs` for all subdomains and products.

## Unified Schema (Deploy Artifact)
- Added migration: `supabase/migrations/20260227_3b_ecosystem_unification_v1.sql`.
- Includes:
  - Core identity tables (`profiles.users`, `profiles.businesses`)
  - Program state (`public.boosts`)
  - VibeSpace rooms + room memberships
  - Credit Builders reports + Dispute AI outputs
  - Ecosystem observability sink (`data_core.event_logs`)
  - Vault buckets + storage object RLS policies

## Domain & Deploy Alignment
| Subdomain | Purpose | Runtime |
|---|---|---|
| `vibe.bouncebackbrian.com` | VibeSpace front door (Flutter + PWA) | Flutter + Vercel + Supabase |
| `credit.bouncebackbrian.com` | Credit Builders workflows + Dispute AI | Vercel + Supabase Edge Functions |
| `vault.bouncebackbrian.com` | Secure document access + retrieval | Supabase Storage + Vercel proxy |
| `api.bouncebackbrian.com` | Unified API surface | Supabase Edge Functions |
| `id.bouncebackbrian.com` | 3B Id / 3B Business Id SSO | Supabase Auth |
| `obs.bouncebackbrian.com` | Metrics/log sink | Supabase Postgres + Realtime |

## GitHub Structure (Target)
```text
3b-ecosystem/
├── supabase/
│   ├── migrations/
│   └── functions/
├── vibe-space/         # Flutter app + PWA support assets
├── credit-builders/    # Next.js + dispute AI workflows
├── vault/              # Storage policies + access proxy
└── docs/               # Unification plans/runbooks
```

- Execution handoff path added for VibeSpace Tax V1: `20_Products/VibeSpace/Execution/VibeSpace-Tax-V1/DEPLOYMENT_HANDOFF.md`

## Deploy Plan (Governance-Aware)
1. Freeze execution (no merge/deploy) until evidence package is complete.
2. Produce PR evidence + migration diff evidence + RLS/role-grant evidence.
3. Produce edge function auth/config evidence for `dispute-ai-analyzer`.
4. Produce Vercel preview-target evidence (preview only, no production flag).
5. Submit E2E acceptance plan and rollback scripts to Oversight.
6. Execute deployment only after explicit Oversight APPROVAL.

## Evidence Package Checklist (A-F)

### A) PR/Code Evidence
- PR URL and branch name.
- Commit SHA for this migration series.
- Changed-files summary for:
  - `supabase/migrations/20260227_3b_ecosystem_unification_v1.sql`
  - `docs/3b_ecosystem_unification_master_review.md`
  - `20_Products/VibeSpace/Execution/VibeSpace-Tax-V1/DEPLOYMENT_HANDOFF.md`

### B) Database/RLS Evidence
- `supabase db diff` output.
- `SELECT schemaname, tablename, rowsecurity,forcerowsecurity FROM pg_tables WHERE schemaname IN ('profiles','vibe_space','credit_builders','data_core','public') ORDER BY schemaname, tablename;`
- `SELECT schemaname, tablename, policyname, permissive, roles, cmd FROM pg_policies WHERE schemaname IN ('profiles','vibe_space','credit_builders','data_core') ORDER BY schemaname, tablename, policyname;`

### C) Role Grant/Revoke Evidence
- `SELECT grantee, table_schema, table_name, privilege_type FROM information_schema.role_table_grants WHERE grantee IN ('anon','authenticated','service_role') AND table_schema IN ('profiles','vibe_space','credit_builders','data_core','public') ORDER BY grantee, table_schema, table_name, privilege_type;`
- Explicit verification that `anon` has no privileges on unified custom schemas/tables.

### D) Edge Function Evidence (`dispute-ai-analyzer`)
- Auth method documented (JWT required or service key only).
- Environment variable list with secrets redacted.
- Deploy command (held until approval): `supabase functions deploy dispute-ai-analyzer --project-ref dev-3b`.

### E) Vercel Preview Evidence
- Branch targets and expected preview URLs for `vibe` + `credit`.
- Command proof that preview-only deploys are used (no `--prod`).

### F) E2E Test Plan
- Path: 3B Id login → business creation → report upload → dispute generation → vault retrieval.
- Pass/fail criteria per step.
- Screenshot placeholders for each checkpoint.

## Scope Clarification (for Oversight)
- Business objective: unify identity, RLS, and storage controls across VibeSpace + Credit Builders V1.
- V1 coverage: supports **both** VibeSpace and Credit Builders lanes.
- New tables introduced: `profiles.users`, `profiles.businesses`, `public.boosts`, `vibe_space.rooms`, `vibe_space.room_members`, `credit_builders.reports`, `credit_builders.disputes`, `data_core.event_logs`.
- 3B Entertainment relation: none; excluded from this V1 change.

## Regression/Risk Surface
- Modified surface is limited to new schemas/tables listed above.
- Event sink (`data_core.event_logs`) remains insert-only for `service_role`; authenticated users have read-only access.
- `anon` remains blocked from custom schemas and unified tables.

## Rollback Plan
1. Revert migration commit in git and generate reverse migration for all introduced objects.
2. Remove added policies/tables/buckets in reverse dependency order (disputes → reports → room_members → rooms → boosts → users/businesses → event_logs).
3. Re-deploy prior edge function version for `dispute-ai-analyzer`.
4. Remove preview deployments (`vercel remove <preview-url>`).
5. Maximum allowable downtime target: 15 minutes in dev preview environments.

## Next Action (Single Ticket)
**Assemble and submit full evidence package A-F to Perplexity Oversight; do not deploy before explicit approval.**

## Evidence Artifacts Added
- `docs/oversight/evidence_update_d05fd5a.md`
- `supabase/migrations/20260227_3b_ecosystem_unification_v1_rollback.sql`

**Accomplishments**
- Completed master review pass across available V1 artifacts.
- Produced unified Supabase migration and deployment blueprint.

**Drift Fixed**
- Governance gap closed: deployment status corrected from implicit execute posture to evidence-first gate.

**Progress** [████████░░] 80%

**3B Alignment**
- Consolidates all lanes on a single identity + business context while preserving VibeSpace-first product flow.

**Action Items**
- Submit evidence package sections A-F.
- Complete scope clarification + regression statement in Oversight format.
- Submit rollback script and wait for explicit approval before any deploy activity.

Status: BLOCKED (awaiting Oversight evidence review). @BounceBackBrian – READY FOR RESUBMISSION.
