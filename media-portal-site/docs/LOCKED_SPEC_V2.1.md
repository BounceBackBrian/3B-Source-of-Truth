# 3B Media Group – LOCKED BUILD SPEC (V2.1)

Status: **LOCKED**  
Changes require Founder + Oversight approval. Unauthorized edits void PR.

UI and middleware checks are convenience layers only. All enforcement must still hold when bypassing UI.

## Definition of Done (Binary)
- [ ] RLS verified via SQL-level role simulation.
- [ ] Stripe webhook replay validated.
- [ ] Cross-client access attempt fails.
- [ ] Admin override logs created.
- [ ] Build passes lint + typecheck + build.
