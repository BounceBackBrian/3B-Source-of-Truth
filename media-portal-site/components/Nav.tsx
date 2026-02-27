import Link from 'next/link';

export function SiteNav() {
  return (
    <nav className="container">
      <div className="nav-group">
        <Link href="/" className="nav-link">Home</Link>
        <Link href="/features" className="nav-link">Features</Link>
        <Link href="/services" className="nav-link">Services</Link>
        <Link href="/portfolio" className="nav-link">Work</Link>
        <Link href="/about" className="nav-link">About</Link>
      </div>
      <div className="nav-group">
        <Link href="/auth/login" className="nav-link">Sign In</Link>
        <Link href="/portal" className="nav-link">Client Portal</Link>
        <Link href="/admin" className="nav-link">Admin Portal</Link>
        <Link href="/start" className="nav-link nav-link-cta">Start Project</Link>
      </div>
    </nav>
  );
}
