import Stripe from 'stripe';
import { headers } from 'next/headers';
import { NextResponse } from 'next/server';
import { env } from '@/lib/env';
import { getSupabaseServiceClient } from '@/lib/supabase';

function mapBoostStatus(status: string): 'active' | 'paused' | 'inactive' {
  if (status === 'active' || status === 'trialing') return 'active';
  if (status === 'past_due' || status === 'paused' || status === 'unpaid') return 'paused';
  return 'inactive';
}


function asUuidOrNull(value: string | null | undefined): string | null {
  if (!value) return null;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value
    : null;
}

function mapSubscriptionStatus(status: string): 'active' | 'paused' | 'cancelled' | 'past_due' {
  if (status === 'active' || status === 'trialing') return 'active';
  if (status === 'paused' || status === 'unpaid') return 'paused';
  if (status === 'past_due') return 'past_due';
  return 'cancelled';
}

export async function POST(req: Request) {
  if (!env.stripeSecret || !env.stripeWebhookSecret || !env.supabaseUrl || !env.supabaseServiceRole) {
    return NextResponse.json({ error: 'Required server env vars missing' }, { status: 500 });
  }

  const stripe = new Stripe(env.stripeSecret, { apiVersion: '2024-06-20' });
  const supabase = getSupabaseServiceClient();
  const rawBody = await req.text();
  const sig = headers().get('stripe-signature');

  if (!sig) return NextResponse.json({ error: 'Missing signature' }, { status: 400 });

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, env.stripeWebhookSecret);
  } catch {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  const knownEvent = ['checkout.session.completed', 'customer.subscription.updated', 'customer.subscription.deleted', 'invoice.payment_failed'];
  if (!knownEvent.includes(event.type)) {
    return NextResponse.json({ received: true, ignored: event.type });
  }

  const customerId = (event.data.object as { customer?: string }).customer ?? null;
  const subscriptionId =
    (event.data.object as { subscription?: string; id?: string }).subscription ??
    (event.type.includes('subscription') ? (event.data.object as { id?: string }).id : null);

  if (!customerId || !subscriptionId) {
    return NextResponse.json({ received: true, ignored: 'missing customer/subscription' });
  }

  const nextSubscriptionStatus = (() => {
    if (event.type === 'checkout.session.completed') return 'active';
    if (event.type === 'customer.subscription.updated') return (event.data.object as Stripe.Subscription).status;
    if (event.type === 'customer.subscription.deleted') return 'cancelled';
    if (event.type === 'invoice.payment_failed') return 'past_due';
    return 'paused';
  })();

  const { data: profile } = await supabase
    .from('profiles')
    .select('id,threeb_business_id')
    .eq('stripe_customer_id', customerId)
    .maybeSingle();

  const insertEvent = await supabase.from('boost_events').insert({
    stripe_event_id: event.id,
    stripe_event_type: event.type,
    payload: event as unknown as Record<string, unknown>,
    user_id: profile?.id ?? null,
    business_id: asUuidOrNull(profile?.threeb_business_id ?? null),
    event_type: 'webhook',
    detail: {
      nextSubscriptionStatus,
      stripeSubscriptionId: subscriptionId,
      stripeCustomerId: customerId
    }
  });

  if (insertEvent.error && !insertEvent.error.message.toLowerCase().includes('duplicate key')) {
    return NextResponse.json({ error: insertEvent.error.message }, { status: 500 });
  }

  if (insertEvent.error && insertEvent.error.message.toLowerCase().includes('duplicate key')) {
    return NextResponse.json({ received: true, duplicate: true });
  }

  const normalizedStatus = mapSubscriptionStatus(nextSubscriptionStatus);

  await supabase.from('subscriptions').upsert(
    {
      stripe_subscription_id: subscriptionId,
      stripe_customer_id: customerId,
      status: normalizedStatus,
      current_period_start: new Date().toISOString(),
      current_period_end: new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString(),
      user_id: profile?.id ?? null
    },
    { onConflict: 'stripe_subscription_id' }
  );

  if (profile?.id) {
    const boostStatus = mapBoostStatus(nextSubscriptionStatus);
    await supabase.from('profiles').update({ boost_status: boostStatus }).eq('id', profile.id);
    await supabase.from('audit_log').insert({
      actor_user_id: null,
      action: 'stripe_webhook_boost_status_update',
      target_table: 'profiles',
      target_id: profile.id,
      metadata: { eventType: event.type, boostStatus, stripeEventId: event.id }
    });
  }

  return NextResponse.json({ received: true });
}
