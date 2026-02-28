import './globals.css';
import { Footer } from '@/components/Footer';
import { SiteNav } from '@/components/Nav';

export const metadata = {
  title: '3B Media Group',
  description: '3B Media Group website, client portal, and admin portal.'
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="site-shell">
          <SiteNav />
          <div className="site-content">{children}</div>
          <Footer />
        </div>
      </body>
    </html>
  );
}
