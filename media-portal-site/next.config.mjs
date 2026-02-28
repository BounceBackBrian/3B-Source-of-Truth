/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    typedRoutes: true
  },
  async redirects() {
    return [
      {
        source: '/index.html',
        destination: '/',
        permanent: false
      },
      {
        source: '/business.html',
        destination: '/start',
        permanent: false
      },
      {
        source: '/support.html',
        destination: '/contact',
        permanent: false
      }
    ];
  }
};

export default nextConfig;
