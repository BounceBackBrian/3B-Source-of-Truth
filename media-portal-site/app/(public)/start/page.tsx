import { StartProjectForm } from './StartProjectForm';

export default function StartProjectPage() {
  return (
    <main className="container homepage-stack">
      <section className="glass">
        <p className="kicker">Start Project</p>
        <h1>Intake + Booking</h1>
        <p>Submit your project scope and optionally book a call for live planning.</p>
      </section>

      <section className="start-grid">
        <article className="glass">
          <h2 className="section-title">Project Intake</h2>
          <StartProjectForm />
        </article>

        <article className="glass">
          <h2 className="section-title">Book a Call</h2>
          <p>Need speed? Schedule a strategy call and scope the build live.</p>
          <a href="#" className="btn btn-secondary">Book a Call</a>
          <ul>
            <li>• Scope + timeline</li>
            <li>• Portal requirements</li>
            <li>• 3Boost gate fit</li>
            <li>• Launch sequence</li>
          </ul>
        </article>
      </section>
    </main>
  );
}
