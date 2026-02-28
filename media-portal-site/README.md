# 3B Media Group Website + Client Portal + Admin Portal

## 1) Architecture summary
- **Frontend:** Next.js App Router with grouped routes for `(public)`, `(auth)`, `portal`, and `admin`.
- **Backend:** Supabase (Auth, Postgres, RLS, Storage).
- **Payments/Gating:** Stripe webhook is sole source for subscription and boost status transitions.
- **Security model:** Middleware for UX redirects + RLS as true data enforcement.

## 2) Repo structure tree
```text
media-portal-site/
├─ app/
│  ├─ (public)/{page.tsx,services,portfolio,about,contact,pricing}
│  ├─ (auth)/auth/{login,signup,subscribe}/page.tsx
│  ├─ portal/{page.tsx,projects/[id],files,tickets/[id],profile}
│  ├─ admin/{page.tsx,clients,projects,tickets,leads,portfolio}
│  └─ api/webhooks/stripe/route.ts
├─ components/{Nav.tsx,Footer.tsx}
├─ lib/{env.ts,supabase.ts}
├─ middleware.ts
├─ supabase/{schema.sql,storage.sql}
├─ .env.example
└─ .github/workflows/ci.yml
```

## 3) Supabase schema SQL + functions
- Full schema in `supabase/schema.sql`.
- Required function included:
  - `public.is_boost_active(uid uuid) returns boolean`.
- Admin helper function:
  - `public.is_admin(uid uuid) returns boolean`.

## 4) Full RLS policies per table
- RLS enabled on all required tables.
- Clients constrained to own records **and** `is_boost_active(auth.uid())` for client-facing tables.
- Admin role has full CRUD/read where applicable.
- Public lead insert and public portfolio read implemented with strict scoped policies.

## 5) Storage bucket + policies
- Bucket: `project-files`.
- Path convention enforced: `client/<client_user_id>/project/<project_id>/<filename>`.
- Policies in `supabase/storage.sql`:
  - Admin full access.
  - Client scoped access to own path + active boost required.

## 6) Stripe webhook handler (complete code)
- Route: `POST /api/webhooks/stripe`.
- Signature verified with `STRIPE_WEBHOOK_SECRET`.
- Handles:
  - `checkout.session.completed`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `invoice.payment_failed`
- Writes:
  - `boost_events` append-only ledger.
  - `subscriptions` upsert.
  - `profiles.boost_status` update.
  - `audit_log` record.

## 7) Route map
- Public: `/`, `/features`, `/services`, `/portfolio`, `/about`, `/contact`, `/pricing`, `/start`
- Auth: `/auth/login`, `/auth/signup`, `/auth/subscribe`
- Client portal: `/portal`, `/portal/projects`, `/portal/projects/[id]`, `/portal/files`, `/portal/tickets`, `/portal/tickets/[id]`, `/portal/profile`
- Admin portal: `/admin`, `/admin/clients`, `/admin/clients/[id]`, `/admin/projects`, `/admin/tickets`, `/admin/leads`, `/admin/portfolio`
- API: `/api/webhooks/stripe`, `/api/leads`, `/api/admin/leads/update`

## 8) UI components list
- `components/Nav.tsx`
- `components/Footer.tsx` (includes Core Footer V1.1 marker)
- Homepage modules: `components/home/Hero.tsx`, `PlatformGrid.tsx`, `SystemDiagram.tsx`, `FinalCta.tsx`
- Shared classes in `app/globals.css` for brand colors, glass cards, and responsive forms.

## 9) Setup instructions
1. `npm install`
2. Copy `.env.example` to `.env.local` and fill values.
3. Run SQL in order:
   - `supabase/schema.sql`
   - `supabase/storage.sql`
4. `npm run dev`
5. Configure Stripe webhook endpoint:
   - `https://<your-domain>/api/webhooks/stripe`
6. Deploy:
   - `dev` branch → staging on Vercel
   - `main` branch → production on Vercel

## 10) Testing checklist
- RLS: client cannot read/write other client data.
- Boost gating: non-active boost cannot access portal data.
- Admin-only portal routes blocked for non-admin.
- Storage path policy enforces client path ownership.
- Stripe webhook signature verification rejects invalid signatures.
- Webhook updates `subscriptions`, `profiles.boost_status`, `boost_events`, `audit_log`.

## 11) Definition of Done
- ✅ RLS policies authored for all required tables.
- ✅ `is_boost_active(uid)` used in client-facing policies.
- ✅ Admin restrictions and middleware routing implemented.
- ✅ Stripe webhook endpoint implemented with signature verification.
- ✅ Storage bucket policies authored.
- ✅ CI pipeline includes lint, typecheck, build.


## 12) Phase 1 entitlement spine artifacts
- Idempotent migration bundle: `supabase/migrations/20260227_3boost_spine_phase1.sql`
  - Adds `businesses`, `memberships`, and `admin_override_log`.
  - Adds business scoping columns on core portal tables.
  - Adds policy/trigger hardening so `boost_status` cannot be client-mutated.
  - Adds webhook-event idempotency index (`boost_events_stripe_event_id_uq`).
- Binary acceptance test script: `docs/PHASE1_RLS_TESTS.sql`.


## 13) Leads intake API hardening
- Public `/start` form posts to `POST /api/leads` (server-side insert only).
- Anti-spam controls: hidden honeypot field, basic IP-window rate limiting, and hashed IP storage.
- Lead reads/updates/deletes are admin-only via RLS, public role cannot read or insert rows directly.
- Apply migration: `supabase/migrations/20260301_leads_intake_hardening.sql`.


## 14) Admin leads + notifications
- `/admin/leads` is server-rendered and requires `session` + `role=admin` cookies before loading lead data.
- `/api/admin/leads/update` performs server-side admin cookie verification, updates lead status/notes, and logs `lead_updated_admin` into `boost_events`.
- New lead submissions notify Slack (`SLACK_WEBHOOK_URL`) and Resend (`RESEND_API_KEY`, `RESEND_TO_EMAIL`) from the server route only.
- Additional SQL artifacts: `supabase/schema_leads_v1.sql` and `supabase/schema_observability_v1.sql`.
- Apply observability migration: `supabase/migrations/20260302_observability_lead_events.sql`.

---
Core Footer V1.1


## 15) Evidence pack commands (binary gate)
- Generate local CI artifacts + required runtime placeholders:
  - `scripts/capture_phase1_evidence.sh <commit_sha>`
- Validate required runtime filenames exist before uploading a pack:
  - `scripts/validate_phase1_evidence.sh ops/governance_v1_3/evidence/3B-MG_PHASE1_EVIDENCE_PACK_<commit_sha>`
- Required runtime files (must be replaced with real screenshots/logs before seal):
  - `B_LEADS_RLS_PROOF/B1_client_isolation_clientA_attempt.png`
  - `B_LEADS_RLS_PROOF/B1_client_isolation_clientB_success.png`
  - `B_LEADS_RLS_PROOF/B2_boost_gate_inactive_denied.png`
  - `B_LEADS_RLS_PROOF/B3_admin_update_success.png`
  - `B_LEADS_RLS_PROOF/B3_client_update_denied.png`
  - `C_API_LEADS_HARDENING/C1_rejected_submission.txt`
  - `C_API_LEADS_HARDENING/C2_notification_server_log.txt`
  - `C_API_LEADS_HARDENING/C3_boost_events_row.png`
  - `E_SUPABASE_POLICY_SNAPSHOTS/E1_leads_rls_policies.png`
  - `E_SUPABASE_POLICY_SNAPSHOTS/E2_tables_leads_boost_events.png`
