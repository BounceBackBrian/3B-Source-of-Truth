// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16?deno-std=0.224.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "content-type, stripe-signature",
      "access-control-allow-methods": "POST, OPTIONS",
    },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });

  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: "2024-06-20" } as any);

    const rawBody = await req.text();
    const sig = req.headers.get("stripe-signature") ?? "";

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(rawBody, sig, STRIPE_WEBHOOK_SECRET);
    } catch (_) {
      return json({ error: "Invalid signature" }, 400);
    }

    const eventId = event?.id as string | undefined;
    const eventType = event?.type as string | undefined;
    const obj: any = event?.data?.object ?? {};

    const tenant_id = obj?.metadata?.tenant_id;
    const business_id = obj?.metadata?.business_id;
    const unit_id = obj?.metadata?.unit_id ?? null;

    if (!eventId || !eventType) return json({ error: "Invalid Stripe event" }, 400);
    if (!tenant_id || !business_id) return json({ error: "Missing metadata tenant_id/business_id" }, 400);

    const request_id = `stripe:${eventId}`;

    // 1) Replay gate insert (duplicate => ignore and 200)
    const { error: gateErr } = await supabaseAdmin.from("stripe_events").insert({
      tenant_id,
      business_id,
      stripe_event_id: eventId,
      status: "received",
      processed_at: null,
      created_at: new Date().toISOString(),
    });

    if (gateErr) {
      const msg = String(gateErr.message ?? "").toLowerCase();
      if (gateErr.code === "23505" || msg.includes("duplicate") || msg.includes("unique")) {
        await supabaseAdmin.from("oversight_logs").insert({
          tenant_id,
          business_id,
          actor_id: null,
          event_type: "stripe_duplicate_event_ignored",
          entity_table: "stripe_events",
          entity_id: null,
          request_id,
          success: true,
          payload: { eventId, eventType },
        });
        return json({ ok: true, duplicate: true });
      }
      throw gateErr;
    }

    const shouldWrite =
      eventType === "checkout.session.completed" ||
      eventType === "payment_intent.succeeded" ||
      eventType === "charge.succeeded";

    if (!shouldWrite) {
      await supabaseAdmin.from("stripe_events").update({
        status: "processed",
        processed_at: new Date().toISOString(),
      })
      .eq("tenant_id", tenant_id)
      .eq("business_id", business_id)
      .eq("stripe_event_id", eventId);

      await supabaseAdmin.from("oversight_logs").insert({
        tenant_id,
        business_id,
        actor_id: null,
        event_type: "stripe_webhook_ignored",
        entity_table: "stripe",
        entity_id: null,
        request_id,
        success: true,
        payload: { eventId, eventType },
      });

      return json({ ok: true, ignored: true });
    }

    const cents = obj?.amount_total ?? obj?.amount_received ?? obj?.amount ?? null;
    const amount = cents !== null ? Number(cents) / 100 : null;
    if (amount === null || !Number.isFinite(amount)) {
      await supabaseAdmin.from("stripe_events").update({
        status: "failed",
        processed_at: new Date().toISOString(),
      })
      .eq("tenant_id", tenant_id)
      .eq("business_id", business_id)
      .eq("stripe_event_id", eventId);
      return json({ error: "Could not derive amount" }, 400);
    }

    const { data: payment, error: payErr } = await supabaseAdmin
      .from("payments")
      .insert({
        tenant_id,
        business_id,
        user_id: null,
        unit_id,
        amount,
        method: "stripe",
        provider_payment_id: obj?.id ?? null,
        provider_customer_id: obj?.customer ?? null,
        provider_invoice_id: obj?.invoice ?? null,
        envelope_id: null,
        status: "confirmed",
        request_id,
        notes: `Stripe ${eventType}`,
        confirmed_at: new Date().toISOString(),
        created_by: null,
      })
      .select("*")
      .single();

    if (payErr) {
      const msg = String(payErr.message ?? "").toLowerCase();
      if (!(payErr.code === "23505" || msg.includes("duplicate") || msg.includes("unique"))) {
        await supabaseAdmin.from("stripe_events").update({
          status: "failed",
          processed_at: new Date().toISOString(),
        })
        .eq("tenant_id", tenant_id)
        .eq("business_id", business_id)
        .eq("stripe_event_id", eventId);
        throw payErr;
      }
    }

    await supabaseAdmin.from("stripe_events").update({
      status: "processed",
      processed_at: new Date().toISOString(),
    })
    .eq("tenant_id", tenant_id)
    .eq("business_id", business_id)
    .eq("stripe_event_id", eventId);

    await supabaseAdmin.from("oversight_logs").insert({
      tenant_id,
      business_id,
      actor_id: null,
      event_type: "stripe_payment_recorded",
      entity_table: "payments",
      entity_id: payment?.id ?? null,
      request_id,
      success: true,
      payload: { eventId, eventType, amount, unit_id },
    });

    const channelName = `property-ops:payments:${tenant_id}:${business_id}`;
    await supabaseAdmin.channel(channelName).send({
      type: "broadcast",
      event: "stripe_payment_confirmed",
      payload: {
        tenant_id,
        business_id,
        event_type: "stripe_payment_recorded",
        entity_id: payment?.id ?? null,
        created_at: payment?.created_at ?? new Date().toISOString(),
      },
    });

    // valid event handled => return 2xx so Stripe stops retries
    return json({ ok: true });
  } catch (e) {
    return json({ error: "Webhook error", details: String(e?.message ?? e) }, 500);
  }
});
