// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
      "access-control-allow-methods": "POST, OPTIONS",
    },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });

  try {
    const authHeader = req.headers.get("authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "Missing bearer token" }, 401);

    // Verify JWT with anon client (no raw JWT parsing)
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: u, error: uerr } = await supabaseUser.auth.getUser();
    if (uerr || !u?.user) return json({ error: "Unauthorized" }, 401);

    const tenant_id = u.user.app_metadata?.tenant_id;
    const business_id = u.user.app_metadata?.business_id;
    const actor_id = u.user.id;

    if (!tenant_id || !business_id || !actor_id) {
      return json({ error: "JWT missing tenant_id/business_id/sub" }, 403);
    }

    const payload = await req.json();
    const { unit_id, amount, envelope_code, request_id, notes } = payload ?? {};

    if (!unit_id || typeof amount !== "number" || amount <= 0 || !envelope_code || !request_id) {
      return json({ error: "Required: unit_id, amount>0, envelope_code, request_id" }, 400);
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 1) Verify envelope is open (scoped)
    const { data: env, error: envErr } = await supabaseAdmin
      .from("envelopes")
      .select("id,status")
      .eq("tenant_id", tenant_id)
      .eq("business_id", business_id)
      .eq("envelope_code", envelope_code)
      .maybeSingle();

    if (envErr) throw envErr;
    if (!env || env.status !== "open") {
      await supabaseAdmin.from("oversight_logs").insert({
        tenant_id,
        business_id,
        actor_id,
        event_type: "cash_payment_rejected",
        entity_table: "envelopes",
        entity_id: env?.id ?? null,
        request_id,
        success: false,
        reason: "Envelope not open / not found",
        payload: { unit_id, amount, envelope_code },
      });
      return json({ error: "Envelope not open / not found" }, 409);
    }

    // 2) Idempotent insert into payments
    const { data: payment, error: payErr } = await supabaseAdmin
      .from("payments")
      .insert({
        tenant_id,
        business_id,
        user_id: actor_id,
        unit_id,
        amount,
        method: "cash",
        envelope_id: env.id,
        status: "confirmed",
        request_id,
        notes: notes ?? null,
        confirmed_at: new Date().toISOString(),
        created_by: actor_id,
      })
      .select("*")
      .single();

    if (payErr) {
      const msg = String(payErr.message ?? "").toLowerCase();
      if (payErr.code === "23505" || msg.includes("duplicate") || msg.includes("unique")) {
        const { data: existing } = await supabaseAdmin
          .from("payments")
          .select("*")
          .eq("tenant_id", tenant_id)
          .eq("business_id", business_id)
          .eq("request_id", request_id)
          .single();

        await supabaseAdmin.from("oversight_logs").insert({
          tenant_id,
          business_id,
          actor_id,
          event_type: "cash_payment_idempotent_return",
          entity_table: "payments",
          entity_id: existing?.id ?? null,
          request_id,
          success: true,
          payload: { envelope_code, envelope_id: env.id },
        });

        return json({ ok: true, payment: existing, idempotent: true });
      }
      throw payErr;
    }

    // 3) Close envelope
    const { error: closeErr } = await supabaseAdmin
      .from("envelopes")
      .update({
        status: "closed",
        closed_by: actor_id,
        closed_at: new Date().toISOString(),
      })
      .eq("tenant_id", tenant_id)
      .eq("business_id", business_id)
      .eq("envelope_code", envelope_code)
      .eq("status", "open");

    if (closeErr) throw closeErr;

    // 4) Oversight log
    await supabaseAdmin.from("oversight_logs").insert({
      tenant_id,
      business_id,
      actor_id,
      event_type: "cash_payment_created",
      entity_table: "payments",
      entity_id: payment.id,
      request_id,
      success: true,
      payload: { unit_id, amount, envelope_code },
    });

    // 5) Realtime broadcast
    const channelName = `property-ops:payments:${tenant_id}:${business_id}`;
    await supabaseAdmin.channel(channelName).send({
      type: "broadcast",
      event: "ledger_append",
      payload: {
        tenant_id,
        business_id,
        event_type: "cash_payment_created",
        entity_id: payment.id,
        created_at: payment.created_at,
      },
    });

    return json({ ok: true, payment });
  } catch (e) {
    return json({ error: "Server error", details: String(e?.message ?? e) }, 500);
  }
});
