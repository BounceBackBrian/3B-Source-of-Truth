import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { getSupabaseServiceClient } from '@/lib/supabase';

const allowedStatuses = new Set(['new', 'triaged', 'contacted', 'won', 'lost']);

export async function POST(req: NextRequest) {
  const cookieStore = cookies();
  const role = cookieStore.get('role')?.value;
  const session = cookieStore.get('session')?.value;
  if (!session || role !== 'admin') {
    return NextResponse.json({ ok: false, error: 'Forbidden' }, { status: 403 });
  }

  const form = await req.formData();
  const id = String(form.get('id') || '');
  const status = String(form.get('status') || '').trim();
  const notes = String(form.get('notes') || '').trim();

  if (!id || !allowedStatuses.has(status)) {
    return NextResponse.json({ ok: false, error: 'Invalid payload' }, { status: 400 });
  }

  const supabase = getSupabaseServiceClient();
  const { error } = await supabase.from('leads').update({ status, notes }).eq('id', id);
  if (error) {
    return NextResponse.json({ ok: false, error: 'Update failed' }, { status: 500 });
  }

  await supabase.from('boost_events').insert({
    stripe_event_id: `lead-admin-${id}-${Date.now()}`,
    stripe_event_type: 'lead_updated_admin',
    payload: { lead_id: id, status, notes_updated: Boolean(notes) }
  });

  return NextResponse.redirect(new URL('/admin/leads', req.url), 303);
}
