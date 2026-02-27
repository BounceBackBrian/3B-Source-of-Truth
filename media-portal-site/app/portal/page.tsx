import Link from 'next/link';

export default function PortalHome() {
  return (
    <main className="container">
      <section className="glass">
        <p className="kicker">Secure Workspace</p>
        <h1>Client Access Portal</h1>
        <p>Secure, 3Boost-gated project environment for milestones, files, and delivery updates.</p>
        <div className="card-grid">
          <article className="feature-card"><h3>Projects</h3><p>Track status, milestones, and approvals.</p><Link className="btn btn-secondary" href="/portal/projects">Open Projects</Link></article>
          <article className="feature-card"><h3>Files</h3><p>Upload brand assets and download deliverables.</p><Link className="btn btn-secondary" href="/portal/files">Manage Files</Link></article>
          <article className="feature-card"><h3>Tickets</h3><p>Submit requests and review threaded responses.</p><Link className="btn btn-secondary" href="/portal/tickets">Open Tickets</Link></article>
        </div>
      </section>
    </main>
  );
}
