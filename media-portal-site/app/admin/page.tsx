import Link from 'next/link';

export default function AdminHome() {
  return (
    <main className="container">
      <section className="glass">
        <p className="kicker">Oversight Console</p>
        <h1>Admin Command Center</h1>
        <p>Manage clients, intake, projects, and governance artifacts from one operational surface.</p>
        <div className="card-grid">
          <article className="feature-card"><h3>Client Ops</h3><p>Review client accounts and entitlement state.</p><Link className="btn btn-secondary" href="/admin/clients">Open Clients</Link></article>
          <article className="feature-card"><h3>Project Ops</h3><p>Track workstreams, milestones, and blockers.</p><Link className="btn btn-secondary" href="/admin/projects">Open Projects</Link></article>
          <article className="feature-card"><h3>Leads + Portfolio</h3><p>Maintain pipeline and social proof content.</p><Link className="btn btn-secondary" href="/admin/leads">Open Leads</Link></article>
        </div>
      </section>
    </main>
  );
}
