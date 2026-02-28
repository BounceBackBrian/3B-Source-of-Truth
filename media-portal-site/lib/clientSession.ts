export type PortalRole = 'client' | 'admin';

const ONE_WEEK_SECONDS = 60 * 60 * 24 * 7;

function setCookie(name: string, value: string, maxAgeSeconds = ONE_WEEK_SECONDS) {
  if (typeof document === 'undefined') {
    return;
  }

  document.cookie = `${name}=${encodeURIComponent(value)}; Path=/; Max-Age=${maxAgeSeconds}; SameSite=Lax`;
}

export function setPortalSession(role: PortalRole) {
  const sessionValue = `demo-${Date.now()}`;
  setCookie('session', sessionValue);
  setCookie('role', role);
  setCookie('boost_status', 'active');
}
