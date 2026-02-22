// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type JwtMeta = { tenant_id?: string; business_id?: string };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json(401, { error: "Unauthorized" });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );

    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData.user) return json(401, { error: "Unauthorized" });

    const user = userData.user;
    const md = (user.app_metadata ?? {}) as JwtMeta;
    if (!md.tenant_id || !md.business_id) {
      return json(403, { error: "Missing tenant/business claims" });
    }

    const payload = await req.json();
    const unit_id = payload?.unit_id as string | undefined;
    const envelope_code = payload?.envelope_code as string | undefined;
    const request_id = payload?.request_id as string | undefined;
    const notes = payload?.notes as string | undefined;
    const amount = Number(payload?.amount);

    if (!request_id || !isUuid(request_id)) return json(400, { error: "Missing request_id" });
    if (!unit_id) return json(400, { error: "Missing unit_id" });
    if (!envelope_code) return json(400, { error: "Missing envelope_code" });
    if (!Number.isFinite(amount) || amount <= 0) return json(400, { error: "Invalid amount" });

    const { data: env, error: envErr } = await supabase
      .from("cash_envelopes")
      .select("id,status")
      .eq("envelope_code", envelope_code)
      .eq("status", "open")
      .single();

    if (envErr || !env) return json(400, { error: "Invalid or closed envelope" });

    const ins = await supabase
      .from("payments")
      .insert({
        unit_id,
        amount,
        method: "cash",
        envelope_id: env.id,
        notes,
        immutable: true,
        request_id,
        created_by: user.id,
      })
      .select()
      .single();

    let payment = ins.data;
    if (ins.error) {
      const msg = String(ins.error.message || "").toLowerCase();
      const isDup = msg.includes("duplicate") || msg.includes("unique") || ins.error.code === "23505";
      if (!isDup) return json(400, { error: ins.error.message });

      const { data: existing, error: exErr } = await supabase
        .from("payments")
        .select("*")
        .eq("request_id", request_id)
        .single();

      if (exErr || !existing) return json(409, { error: "Duplicate request detected" });
      payment = existing;
    }

    await supabase.from("cash_envelopes").update({ status: "closed" }).eq("id", env.id);

    await supabase.from("oversight_logs").insert({
      tenant_id: md.tenant_id,
      business_id: md.business_id,
      actor_id: user.id,
      event_type: "cash_payment_created",
      entity_id: payment?.id ?? null,
      request_id,
      success: true,
      reason: null,
      payload: {
        unit_id,
        envelope_id: env.id,
        method: "cash",
      },
    });

    const channelName = `property-ops:payments:${md.tenant_id}:${md.business_id}`;
    await supabase.channel(channelName).send({
      type: "broadcast",
      event: "ledger_append",
      payload: {
        tenant_id: md.tenant_id,
        business_id: md.business_id,
        event_type: "cash_payment_created",
        entity_id: payment?.id ?? null,
        created_at: payment?.created_at ?? new Date().toISOString(),
      },
    });

    return json(200, payment);
  } catch (e) {
    return json(401, { error: String(e?.message ?? e) });
  }
});
