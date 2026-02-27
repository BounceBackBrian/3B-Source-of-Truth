import { Hero } from '@/components/home/Hero';
import { PlatformGrid } from '@/components/home/PlatformGrid';
import { SystemDiagram } from '@/components/home/SystemDiagram';
import { FinalCta } from '@/components/home/FinalCta';

export default function HomePage() {
  return (
    <main className="container homepage-stack">
      <Hero />
      <section className="glass compare-grid">
        <article className="feature-card">
          <h3>Not a Page Builder</h3>
          <p>Templates are easy. Control and ownership are what scale.</p>
          <ul>
            <li>❌ Platform lock-in</li>
            <li>❌ Shared control</li>
            <li>✅ Full ownership</li>
            <li>✅ Client + admin portals</li>
          </ul>
        </article>
        <article className="feature-card">
          <h3>How It Works</h3>
          <ol>
            <li>1) Start Project</li>
            <li>2) Build + Control</li>
            <li>3) Launch + Scale</li>
          </ol>
        </article>
      </section>
      <SystemDiagram />
      <PlatformGrid />
      <FinalCta />
    </main>
  );
}
