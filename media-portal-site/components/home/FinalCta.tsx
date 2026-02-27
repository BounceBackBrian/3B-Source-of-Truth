import Link from 'next/link';

export function FinalCta() {
  return (
    <section className="glass final-cta">
      <h2 className="section-title">Stop Renting Platforms. Start Owning Systems.</h2>
      <p>Lead with authority now, then expand into SaaS-style onboarding as you scale.</p>
      <div className="button-row">
        <Link href="/start" className="btn btn-primary">Start Project</Link>
        <Link href="/features" className="btn btn-secondary">See Features</Link>
      </div>
    </section>
  );
}
