import Link from 'next/link';

export default function Projects() {
  return (
    <main className="container">
      <section className="glass">
        <h1>Your Projects</h1>
        <p>All projects tied to your 3B identity and active 3Boost entitlement.</p>
        <Link className="btn btn-secondary" href="/portal/projects/demo">Open Demo Project</Link>
      </section>
    </main>
  );
}
