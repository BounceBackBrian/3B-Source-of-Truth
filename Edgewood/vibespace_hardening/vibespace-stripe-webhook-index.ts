// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16?deno-std=0.224.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, stripe-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });

    const signature = req.headers.get("stripe-signature");
    if (!signature) return json(400, { error: "Missing stripe-signature" });

    const body = await req.text();

    const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, { apiVersion: "2024-06-20" } as any);

    const endpointSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(body, signature, endpointSecret);
    } catch (e) {
      const message = e instanceof Error ? e.message : "Invalid signature";
      return json(400, { error: message });
    }

    // service role is okay here: server-to-server webhook path
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    if (event.type === "payment_intent.succeeded") {
      const obj: any = event.data.object;
      const md = obj?.metadata ?? {};

      const tenant_id = md.tenant_id;
      const business_id = md.business_id;
      const unit_id = md.unit_id ?? null;
      const created_by = md.created_by_user_id ?? Deno.env.get("SYSTEM_USER_ID");

      if (!tenant_id || !business_id) {
        return json(400, { error: "Missing metadata tenant_id/business_id" });
      }
      if (!created_by) {
        return json(400, { error: "Missing created_by_user_id metadata or SYSTEM_USER_ID env" });
      }

      const amount = Number((obj?.amount_received ?? obj?.amount ?? 0) / 100);

      if (!Number.isFinite(amount) || amount <= 0) {
        return json(400, { error: "Invalid amount" });
      }

      // 1) Immutable receipt first (idempotent on stripe_event_id)
      const { data: insertedReceipt, error: recErr } = await admin
        .from("payment_receipts")
        .upsert(
          {
            tenant_id,
            business_id,
            stripe_event_id: event.id,
            stripe_payment_intent_id: obj?.id ?? null,
            data: obj,
          },
          { onConflict: "stripe_event_id" },
        )
        .select("id")
        .single();

      if (recErr) return json(400, { error: recErr.message });

      const receipt_id = insertedReceipt.id as string;

      // 2) Ledger insert referencing receipt_id (idempotent via payments_receipt_id_uq)
      const { data: payment, error: payErr } = await admin
        .from("payments")
        .upsert(
          {
            tenant_id,
            business_id,
            unit_id,
            receipt_id,
            amount,
            method: "card",
            stripe_id: obj?.id ?? null,
            request_id: `stripe-${event.id}`,
            immutable: true,
            created_by,
          },
          { onConflict: "tenant_id,business_id,request_id" },
        )
        .select()
        .single();

      if (payErr) return json(400, { error: payErr.message });

      // 3) Broadcast
      const channelName = `property-ops:${tenant_id}:${business_id}`;
      await admin.channel(channelName).send({
        type: "broadcast",
        event: "stripe_payment",
        payload: { receipt_id },
      });
    }

    return json(200, { received: true, event_type: event.type, event_id: event.id });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected error";
    return json(500, { error: message });
  }
});
