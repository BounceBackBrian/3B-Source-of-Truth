import Link from 'next/link';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { getSupabaseServiceClient } from '@/lib/supabase';

type LeadRow = {
  id: string;
  created_at: string;
  threeb_id: string;
  threeb_business_id: string;
  name: string;
  email: string;
  phone: string | null;
  business_name: string | null;
  need: string;
  timeline: string;
  domain_help: boolean;
  domain_name: string | null;
  business_context: string | null;
  message: string;
  status: 'new' | 'triaged' | 'contacted' | 'won' | 'lost';
  notes: string | null;
};

export default async function AdminLeadsPage() {
  const cookieStore = cookies();
  const role = cookieStore.get('role')?.value;
  const session = cookieStore.get('session')?.value;
  if (!session || role !== 'admin') {
    redirect('/auth/login');
  }

  let leads: LeadRow[] = [];
  let error: string | null = null;

  try {
    const supabase = getSupabaseServiceClient();
    const { data, error: queryError } = await supabase
      .from('leads')
.select('id,created_at,threeb_id,threeb_business_id,name,email,phone,business_name,need,timeline,domain_help,domain_name,business_context,message,status,notes')
      .order('created_at', { ascending: false })
      .limit(200);

    leads = (data || []) as LeadRow[];
    error = queryError?.message || null;
  } catch (err) {
    error = err instanceof Error ? err.message : 'Unable to initialize Supabase service client.';
  }

  return (
    <main className="container homepage-stack">
      <section className="glass">
        <h1>Admin Leads</h1>
        <p>Server-rendered intake queue with status and notes updates for admin operators.</p>
        <Link className="btn btn-secondary" href="/admin">Back to Admin Home</Link>
      </section>

      <section className="glass">
        {error ? (
          <p className="submit-error">Failed to load leads: {error}</p>
        ) : leads.length === 0 ? (
          <p>No leads yet.</p>
        ) : (
          <div className="table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Created</th>
                  <th>Lead</th>
                  <th>Need</th>
                  <th>Timeline</th>
                  <th>Status + Notes</th>
                  <th>Message</th>
                </tr>
              </thead>
              <tbody>
                {leads.map((lead) => (
                  <tr key={lead.id}>
                    <td>{new Date(lead.created_at).toLocaleString()}</td>
                    <td>
                      <strong>{lead.name}</strong>
                      <div>{lead.email}</div>
                      {lead.phone ? <div>{lead.phone}</div> : null}
                      <div>{lead.business_name || '—'}</div>
                      <div>3B ID: {lead.threeb_id}</div>
                      <div>3B Business ID: {lead.threeb_business_id}</div>
                      <div>Domain help: {lead.domain_help ? 'Yes' : 'No'} {lead.domain_name ? `(${lead.domain_name})` : ''}</div>
                    </td>
                    <td>{lead.need}</td>
                    <td>{lead.timeline}</td>
                    <td>
                      <form action="/api/admin/leads/update" method="post" className="table-form">
                        <input type="hidden" name="id" value={lead.id} />
                        <select name="status" defaultValue={lead.status}>
                          <option value="new">new</option>
                          <option value="triaged">triaged</option>
                          <option value="contacted">contacted</option>
                          <option value="won">won</option>
                          <option value="lost">lost</option>
                        </select>
                        <textarea name="notes" defaultValue={lead.notes || ''} rows={4} placeholder="Internal notes" />
                        <button className="btn btn-primary" type="submit">Save</button>
                      </form>
                    </td>
                    <td>
                      <p>{lead.message}</p>
                      {lead.business_context ? <p><strong>Context:</strong> {lead.business_context}</p> : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
