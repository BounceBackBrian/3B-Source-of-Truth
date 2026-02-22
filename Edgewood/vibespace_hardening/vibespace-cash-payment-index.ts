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

    // IMPORTANT: ANON + forwarded JWT => RLS applies.
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

    const meta = (userData.user.app_metadata ?? {}) as JwtMeta;
    const tenant_id = meta.tenant_id;
    const business_id = meta.business_id;
    const created_by = userData.user.id;

    if (!tenant_id || !business_id) {
      return json(403, { error: "Missing tenant/business claims" });
    }

    const payload = await req.json();
    const unit_id = payload?.unit_id as string | undefined;
    const envelope_code = payload?.envelope_code as string | undefined;
    const request_id = payload?.request_id as string | undefined;
    const notes = payload?.notes as string | undefined;
    const amount = Number(payload?.amount);

    if (!unit_id || !envelope_code || !request_id || !isUuid(request_id) || !Number.isFinite(amount) || amount <= 0) {
      return json(400, { error: "Invalid input" });
    }

    // Envelope must be open (RLS scopes by tenant/business)
    const { data: env, error: envErr } = await supabase
      .from("cash_envelopes")
      .select("id,status")
      .eq("envelope_code", envelope_code)
      .eq("status", "open")
      .single();

    if (envErr || !env) return json(400, { error: "Invalid or closed envelope" });

    const { data: payment, error: payErr } = await supabase
      .from("payments")
      .insert({
        unit_id,
        amount,
        method: "cash",
        envelope_id: env.id,
        request_id,
        notes,
        immutable: true,
        created_by,
      })
      .select()
      .single();

    let resolvedPayment = payment;
    if (payErr) {
      // Postgres unique violation; treat as idempotent replay on request_id.
      if (payErr.code === "23505") {
        const { data: existing, error: existingErr } = await supabase
          .from("payments")
          .select("*")
          .eq("request_id", request_id)
          .maybeSingle();

        if (existingErr || !existing) return json(409, { error: "Duplicate request detected" });
        resolvedPayment = existing;
      } else {
        return json(400, { error: payErr.message });
      }
    }

    await supabase
      .from("cash_envelopes")
      .update({ status: "closed" })
      .eq("id", env.id);

    const channelName = `property-ops:${tenant_id}:${business_id}`;
    await supabase.channel(channelName).send({
      type: "broadcast",
      event: "cash_payment",
      payload: { payment: resolvedPayment, unit_id },
    });

    return json(payErr?.code === "23505" ? 200 : 201, resolvedPayment);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected error";
    return json(500, { error: message });
  }
});
