import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServiceClient } from '@/lib/supabase';
import { escapeHtml, notifyEmail, notifySlack } from '@/lib/notifyLeads';

const RATE_LIMIT_MAX = 6;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000;

type RateWindow = { count: number; resetAt: number };
const rateWindowByIp = new Map<string, RateWindow>();

type LeadPayload = {
  name?: string;
  email?: string;
  phone?: string;
  business_name?: string;
  website?: string;
  need?: string;
  timeline?: string;
  budget_range?: string;
  domain_help?: boolean;
  domain_name?: string;
  business_context?: string;
  message?: string;
  source?: string;
  company?: string;
};

function getClientIp(req: NextRequest) {
  const xForwardedFor = req.headers.get('x-forwarded-for');
  return xForwardedFor?.split(',')[0]?.trim() || '0.0.0.0';
}

function hashIp(ip: string) {
  const secret = process.env.LEADS_HMAC_SECRET || 'replace_me';
  return crypto.createHmac('sha256', secret).update(ip).digest('hex');
}

function withinRateLimit(ipHash: string) {
  const now = Date.now();
  const existing = rateWindowByIp.get(ipHash);
  if (!existing || existing.resetAt < now) {
    rateWindowByIp.set(ipHash, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return true;
  }
  if (existing.count >= RATE_LIMIT_MAX) {
    return false;
  }
  existing.count += 1;
  rateWindowByIp.set(ipHash, existing);
  return true;
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function sendLeadNotifications(input: {
  name: string;
  email: string;
  phone?: string;
  business_name?: string;
  need: string;
  timeline: string;
  domain_help: boolean;
  domain_name?: string;
  message: string;
  business_context?: string;
  source: string;
}) {
  const slackMsg =
    `🟣 New Lead — 3B Media Group\n` +
    `Name: ${input.name}\n` +
    `Need: ${input.need}\n` +
    `Timeline: ${input.timeline}\n` +
    `Domain help: ${input.domain_help ? 'Yes' : 'No'}\n` +
    `Source: ${input.source}`;

  await notifySlack(slackMsg);

  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.5">
      <h2>New Lead — 3B Media Group</h2>
      <p><b>Name:</b> ${escapeHtml(input.name)}<br/>
      <b>Email:</b> ${escapeHtml(input.email)}<br/>
      <b>Phone:</b> ${escapeHtml(input.phone || '—')}<br/>
      <b>Business:</b> ${escapeHtml(input.business_name || '—')}<br/>
      <b>Need:</b> ${escapeHtml(input.need)}<br/>
      <b>Timeline:</b> ${escapeHtml(input.timeline)}<br/>
      <b>Domain help:</b> ${input.domain_help ? 'Yes' : 'No'}<br/>
      <b>Domain:</b> ${escapeHtml(input.domain_name || '—')}</p>
      <hr/>
      <p><b>Message</b><br/>${escapeHtml(input.message).replace(/\n/g, '<br/>')}</p>
      <hr/>
      <p><b>Context</b><br/>${escapeHtml(input.business_context || '—').replace(/\n/g, '<br/>')}</p>
    </div>`;

  await notifyEmail('New Lead — 3B Media Group', html);
}

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as LeadPayload;

    if (body.company && body.company.trim().length > 0) {
      return NextResponse.json({ ok: true });
    }

    const ipHash = hashIp(getClientIp(req));
    if (!withinRateLimit(ipHash)) {
      return NextResponse.json({ ok: false, error: 'Too many requests. Try again later.' }, { status: 429 });
    }

    const name = body.name?.trim() || '';
    const email = body.email?.trim().toLowerCase() || '';
    const message = body.message?.trim() || '';
    const need = body.need?.trim() || '';
    const timeline = body.timeline?.trim() || '';

    if (!name || !email || !message || !need || !timeline) {
      return NextResponse.json({ ok: false, error: 'Missing required fields.' }, { status: 400 });
    }

    if (!isValidEmail(email)) {
      return NextResponse.json({ ok: false, error: 'Invalid email.' }, { status: 400 });
    }

    const supabase = getSupabaseServiceClient();
    const userAgent = req.headers.get('user-agent') || null;

    const { error } = await supabase.from('leads').insert({
      name,
      email,
      phone: body.phone?.trim() || null,
      business_name: body.business_name?.trim() || null,
      website: body.website?.trim() || null,
      need,
      timeline,
      budget_range: body.budget_range?.trim() || null,
      domain_help: Boolean(body.domain_help),
      domain_name: body.domain_name?.trim() || null,
      business_context: body.business_context?.trim() || null,
      message,
      source: body.source?.trim() || 'start',
      user_agent: userAgent,
      ip_hash: ipHash,
      status: 'new'
    });

    if (error) {
      return NextResponse.json({ ok: false, error: 'Database insert failed.' }, { status: 500 });
    }

    await supabase.from('boost_events').insert({
      stripe_event_id: `lead-submit-${Date.now()}-${ipHash.slice(0, 12)}`,
      stripe_event_type: 'lead_submitted',
      payload: {
        source: body.source?.trim() || 'start',
        need,
        timeline,
        domain_help: Boolean(body.domain_help)
      }
    });

    await sendLeadNotifications({
      name,
      email,
      phone: body.phone?.trim(),
      business_name: body.business_name?.trim(),
      need,
      timeline,
      domain_help: Boolean(body.domain_help),
      domain_name: body.domain_name?.trim(),
      message,
      business_context: body.business_context?.trim(),
      source: body.source?.trim() || 'start'
    });

    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ ok: false, error: 'Invalid request.' }, { status: 400 });
  }
}
