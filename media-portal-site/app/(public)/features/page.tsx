import { PlatformGrid } from '@/components/home/PlatformGrid';
import { SystemDiagram } from '@/components/home/SystemDiagram';

export default function FeaturesPage() {
  return (
    <main className="container homepage-stack">
      <section className="glass">
        <p className="kicker">Platform Features</p>
        <h1>Authority Front-End. SaaS-Ready Infrastructure.</h1>
        <p>Each capability is designed to sell services now and support software workflows as you expand.</p>
      </section>
      <SystemDiagram />
      <PlatformGrid />
    </main>
  );
}
