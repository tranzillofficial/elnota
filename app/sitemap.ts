import type { MetadataRoute } from 'next';
export default function sitemap():MetadataRoute.Sitemap{return ['','/privacy','/terms'].map(path=>({url:`https://elnota.shop${path}`,changeFrequency:path?'monthly':'weekly',priority:path?0.3:1}))}
