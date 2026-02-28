import Image from 'next/image';
import Link from 'next/link';

export function Hero() {
  return (
    <section className="hero-grid">
      <article className="glass hero-copy">
        <p className="kicker">3B Media Group Platform</p>
        <h1>Build Websites. Run Platforms. Own the System.</h1>
        <p>
          3B Media Group is a platform-first website system with client portals, admin control,
          and payment-gated access for businesses that have outgrown page builders.
        </p>
        <div className="button-row">
          <Link href="/start" className="btn btn-primary">Launch Your Platform</Link>
          <Link href="/features" className="btn btn-secondary">View the System</Link>
        </div>
        <p className="micro-copy">Start with a project. Upgrade into a platform.</p>
      </article>

      <article className="glass premier-logo">
        <Image
          className="logo-image"
          src="/assets/3b-media-group-logo.svg"
          alt="3B Media Group logo"
          width={380}
          height={380}
          priority
        />
      </article>
    </section>
  );
}
