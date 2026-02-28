#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <evidence_pack_dir>" >&2
  exit 1
fi

PACK_DIR="$1"

required=(
  "B_LEADS_RLS_PROOF/B1_client_isolation_clientA_attempt.png"
  "B_LEADS_RLS_PROOF/B1_client_isolation_clientB_success.png"
  "B_LEADS_RLS_PROOF/B2_boost_gate_inactive_denied.png"
  "B_LEADS_RLS_PROOF/B3_admin_update_success.png"
  "B_LEADS_RLS_PROOF/B3_client_update_denied.png"
  "C_API_LEADS_HARDENING/C1_rejected_submission.txt"
  "C_API_LEADS_HARDENING/C2_notification_server_log.txt"
  "C_API_LEADS_HARDENING/C3_boost_events_row.png"
  "E_SUPABASE_POLICY_SNAPSHOTS/E1_leads_rls_policies.png"
  "E_SUPABASE_POLICY_SNAPSHOTS/E2_tables_leads_boost_events.png"
)

missing=0
for file in "${required[@]}"; do
  if [[ ! -s "$PACK_DIR/$file" ]]; then
    echo "MISSING: $PACK_DIR/$file"
    missing=1
  else
    echo "OK: $PACK_DIR/$file"
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "\nEvidence pack validation FAILED"
  exit 2
fi

echo "\nEvidence pack validation PASSED"
