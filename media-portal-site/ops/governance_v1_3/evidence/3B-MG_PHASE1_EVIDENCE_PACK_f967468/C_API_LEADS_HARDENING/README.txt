API hardening proof extraction commands:
1) rg -n "company|rateLimit|hashIp|notifySlack|notifyEmail|lead_submitted" app/api/leads/route.ts
2) rg -n "allowedStatuses|Forbidden|lead_updated_admin" app/api/admin/leads/update/route.ts
3) Execute POST /api/leads with honeypot/rate-limit payloads in deployed environment.
