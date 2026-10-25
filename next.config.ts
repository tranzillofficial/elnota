import type { NextConfig } from 'next';
const nextConfig: NextConfig = {
 poweredByHeader: false,
 async rewrites(){return {beforeFiles:[{source:'/app',destination:'/app/index.html'},{source:'/app/',destination:'/app/index.html'}],afterFiles:[],fallback:[{source:'/app/:path*',destination:'/app/index.html'}]}},
 async headers(){return [
 {source:'/sw.js',headers:[{key:'Cache-Control',value:'no-cache, no-store, must-revalidate'},{key:'Service-Worker-Allowed',value:'/'}]},
 {source:'/app/:path*',headers:[{key:'X-Robots-Tag',value:'noindex, nofollow'}]},
 {source:'/app/index.html',headers:[{key:'Cache-Control',value:'no-store'}]},
 {source:'/(.*)',headers:[{key:'X-Content-Type-Options',value:'nosniff'},{key:'Referrer-Policy',value:'strict-origin-when-cross-origin'},{key:'X-Frame-Options',value:'DENY'}]}]
 }
};
export default nextConfig;
