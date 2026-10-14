import type { Metadata, Viewport } from 'next';
import './globals.css';
import { PWA,PWAProvider } from '@/components/pwa';
export const metadata: Metadata = {metadataBase:new URL(process.env.NEXT_PUBLIC_SITE_URL || 'https://elnota.shop'),title:{default:'النوتة | حساباتك في نوتة واحدة',template:'%s | النوتة'},description:'إدارة العملاء والفواتير والأقساط والتحصيل. تفعيل مرة واحدة وحفظ على جهازك، مع سحابة اختيارية.',manifest:'/manifest.webmanifest',appleWebApp:{capable:true,statusBarStyle:'default',title:'النوتة'},icons:{icon:'/icon-192.png',apple:'/icon-192.png'}};
export const viewport: Viewport = {themeColor:'#087b53',width:'device-width',initialScale:1};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="ar" dir="rtl"><body><PWAProvider>{children}<PWA/></PWAProvider></body></html>}
