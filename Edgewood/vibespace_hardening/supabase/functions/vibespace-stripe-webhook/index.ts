// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@16?deno-std=0.224.0";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const stripeKey = Deno.env.get("STRIPE_SECRET_KEY")!;
    const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

    const stripe = new Stripe(stripeKey, { apiVersion: "2024-06-20" } as any);

    const body = await req.text();
    const sig = req.headers.get("stripe-signature");
    if (!sig) return new Response("Missing signature", { status: 400 });

    const event = stripe.webhooks.constructEvent(body, sig, webhookSecret);

    const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

    const obj: any = event.data.object;
    const md = obj?.metadata ?? {};
    const tenant_id = md.tenant_id;
    const business_id = md.business_id;
    const unit_id = md.unit_id ?? null;

    if (!tenant_id || !business_id) {
      return new Response("Missing tenant/business metadata", { status: 400 });
    }

    const { data: receipt, error: rerr } = await supabase
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
      .select()
      .single();

    if (rerr) throw rerr;

    await supabase.from("oversight_logs").insert({
      tenant_id,
      business_id,
      actor_id: Deno.env.get("SYSTEM_USER_ID") ?? null,
      event_type: "stripe_webhook_received",
      entity_id: receipt.id,
      request_id: `stripe-${event.id}`,
      success: true,
      reason: null,
      payload: { stripe_event_id: event.id, stripe_type: event.type },
    });

    if (event.type === "payment_intent.succeeded") {
      const amount = (obj.amount_received ?? obj.amount ?? 0) / 100;
      const createdBy = Deno.env.get("SYSTEM_USER_ID");

      if (!createdBy) {
        return new Response("Missing SYSTEM_USER_ID", { status: 400 });
      }

      const { data: payment, error: perr } = await supabase.from("payments").upsert(
        {
          tenant_id,
          business_id,
          unit_id,
          receipt_id: receipt.id,
          amount,
          method: "card",
          stripe_id: obj.id,
          request_id: `stripe-${event.id}`,
          immutable: true,
          created_by: createdBy,
        },
        { onConflict: "tenant_id,business_id,request_id" },
      ).select("id,created_at").single();

      if (perr) throw perr;

      await supabase.from("oversight_logs").insert({
        tenant_id,
        business_id,
        actor_id: createdBy,
        event_type: "stripe_payment_recorded",
        entity_id: payment?.id ?? null,
        request_id: `stripe-${event.id}`,
        success: true,
        reason: null,
        payload: {
          receipt_id: receipt.id,
          stripe_id: obj.id,
        },
      });

      const channelName = `property-ops:payments:${tenant_id}:${business_id}`;
      await supabase.channel(channelName).send({
        type: "broadcast",
        event: "ledger_append",
        payload: {
          tenant_id,
          business_id,
          event_type: "stripe_payment_recorded",
          entity_id: payment?.id ?? null,
          created_at: payment?.created_at ?? new Date().toISOString(),
        },
      });
    }

    return new Response("OK", { status: 200 });
  } catch (e) {
    return new Response(`Webhook error: ${String(e?.message ?? e)}`, { status: 400 });
  }
});
