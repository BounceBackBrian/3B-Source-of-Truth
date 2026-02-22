# 3Boost Payment Rules — LOCKED

**STATUS:** LOCKED  
**OWNER:** Brian  
**DATE:** 2026-02-20

1. Stripe webhooks → **SERVER-SIDE** validate signature
2. Payment success → `3Boost.activate()` API call **only**
3. 3Boost = **STATE ONLY** (never holds money)
4. Refund → `3Boost.pause()` **via Stripe webhook**
5. Client **NEVER** triggers Boost changes
