# VibeSpace Tax V1 — Deployment Handoff

This folder anchors the VibeSpace Tax V1 execution path under the 3B Source of Truth structure:

- Repo root: `3B-Source-of-Truth`
- Product lane: `20_Products/VibeSpace/Execution/VibeSpace-Tax-V1`

## Canonical backend artifact
Use the unified migration at:

- `supabase/migrations/20260227_3b_ecosystem_unification_v1.sql`

This migration now includes:

1. Unified identity (`profiles.users`, `profiles.businesses`) on 3B Id / 3B Business Id.
2. VibeSpace realtime room primitives (`vibe_space.rooms`, `vibe_space.room_members`).
3. Credit Builders + Vault + Dispute AI data model surfaces.
4. Data Core observability sink (`data_core.event_logs`).
5. Schema usage grants for authenticated users and blocked anonymous schema access.

## Governance hold (required)
Deployment is currently **BLOCKED** pending Oversight evidence review.

Do **not** run:
- `supabase db push`
- `supabase functions deploy ...`
- `vercel deploy ...`

until explicit approval is issued.

## Pre-deploy evidence checklist
1. Capture migration/RLS evidence queries for all unified schemas.
2. Validate SSO/JWT claims include `business_id`.
3. Prepare smoke test steps:
   - create business/profile
   - create room + member management by room owner
   - upload report into Vault bucket
   - create dispute AI draft row
4. Verify RLS denies `anon` access on all custom schemas and protected tables.
5. Attach rollback commands (DB, edge function, and Vercel preview teardown).

## Notes
- This handoff file exists to map Windows path expectations (`G:\My Drive\3B-Source-of-Truth\20_Products\VibeSpace\Execution\VibeSpace-Tax-V1`) to the repository structure in this environment.
- Oversight evidence package record: `docs/oversight/evidence_update_d05fd5a.md`.
- SQL rollback script for unification migration: `supabase/migrations/20260227_3b_ecosystem_unification_v1_rollback.sql`.
