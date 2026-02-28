import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(req: NextRequest) {
  const role = req.cookies.get('role')?.value;
  const boostStatus = req.cookies.get('boost_status')?.value;
  const path = req.nextUrl.pathname;

  if (path.startsWith('/portal')) {
    if (!req.cookies.get('session')) return NextResponse.redirect(new URL('/auth/login', req.url));
    if (boostStatus !== 'active') return NextResponse.redirect(new URL('/auth/subscribe', req.url));
  }

  if (path.startsWith('/admin') && role !== 'admin') {
    return NextResponse.redirect(new URL('/auth/login', req.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/portal/:path*', '/admin/:path*']
};
