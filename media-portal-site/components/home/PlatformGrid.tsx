export function PlatformGrid() {
  const modules = [
    ['Website Builder', 'Brand-forward pages engineered for lead conversion.'],
    ['Client Portal', 'Milestones, files, and requests in one controlled lane.'],
    ['Admin Dashboard', 'Operational oversight for clients, projects, and audit flow.'],
    ['3Boost Gating', 'Payment-gated access enforced from Stripe to DB to RLS.'],
    ['Ticketing + Files', 'Threaded communication and secure project assets.'],
    ['Audit Visibility', 'Immutable activity trace for governance readiness.']
  ];

  return (
    <section className="glass">
      <h2 className="section-title">Modules You Can Scale With</h2>
      <div className="card-grid">
        {modules.map(([title, copy]) => (
          <article key={title} className="feature-card">
            <h3>{title}</h3>
            <p>{copy}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
