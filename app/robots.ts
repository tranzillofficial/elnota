import type { MetadataRoute } from 'next';
export default function robots():MetadataRoute.Robots{return {rules:{userAgent:'*',allow:'/',disallow:['/app/','/admin','/legacy-admin','/dashboard','/recover','/login','/register','/demo']},sitemap:'https://elnota.shop/sitemap.xml'}}
