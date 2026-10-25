type Release = { platform: string; version: string; distribution: string; url: string; notes?: string; assets?: Record<string, unknown> };

function safeUrl(release: Release): boolean {
  try {
    const url = new URL(release.url);
    if (url.protocol !== 'https:') return false;
    if (release.distribution === 'store') return release.platform === 'android'
      ? url.hostname === 'play.google.com' && url.pathname === '/store/apps/details'
      : release.platform === 'ios' && url.hostname === 'apps.apple.com';
    return (url.hostname === 'github.com' && (url.pathname.startsWith('/tranzillofficial/elnotaapp/releases/download/') || url.pathname.startsWith('/tranzillofficial/elnota/releases/download/'))) ||
      (url.hostname === 'fsmoerttftxcuxpswufk.supabase.co' && url.pathname.startsWith('/storage/v1/object/public/elnota-app-releases/'));
  } catch { return false; }
}

async function releases(): Promise<Release[]> {
  const base = (process.env.RELEASE_SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL);
  const key = (process.env.RELEASE_SUPABASE_PUBLISHABLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
  if (!base || !key) return [];
  try {
    const response = await fetch(`${base}/rest/v1/elnota_app_releases?published=eq.true&select=platform,version,distribution,url,notes,assets`, {
      headers: { apikey: key }, next: { revalidate: 60 }, signal: AbortSignal.timeout(4000),
    });
    if (!response.ok) return [];
    const rows: unknown = await response.json();
    return Array.isArray(rows) ? rows.filter((row): row is Release => row && typeof row.platform === 'string' && typeof row.version === 'string' && typeof row.url === 'string' && safeUrl(row)) : [];
  } catch { return []; }
}

export default async function Downloads() {
  const rows = await releases();
  return <section className="downloads-section" id="downloads"><div className="wrap">
    <div className="section-heading centered"><span className="eyebrow">النوتة على جهازك</span><h2>اختار اللي يريحك في الشغل.</h2><p>نزّل التطبيق، أو ادخل لحسابك من المتصفح.</p></div>
    <div className="download-grid">{[
      { id: 'android', name: 'Android', icon: '◉', description: 'حساباتك معاك، أينما كنت.', label: 'تحميل APK' },
      { id: 'windows', name: 'Windows', icon: '⊞', description: 'مساحة أكبر لشغل يومك.', label: 'تحميل مثبّت Windows 64-bit' },
      { id: 'ios', name: 'iOS', icon: '◎', description: 'النوتة على iPhone وiPad.', label: 'App Store' },
    ].map(platform => {
      const release = rows.find(row => row.platform === platform.id);
      const variants = platform.id === 'android' && release?.distribution === 'file' ? Object.entries(release.assets ?? {}).filter(([arch, url]) => ['arm32', 'arm64'].includes(arch) && typeof url === 'string' && safeUrl({ ...release, url })).map(([arch, url]) => ({ arch, url: url as string })) : [];
      return <article className="download" key={platform.id}><span className="platform" aria-hidden="true">{platform.icon}</span><h3>{platform.name}</h3><p>{platform.description}</p>
        {release ? <>{variants.length ? variants.map(variant => <a className="button" key={variant.arch} href={variant.url} rel="noopener noreferrer" style={{ marginBottom: 8 }}>تحميل Android {variant.arch === 'arm32' ? '32-bit' : '64-bit'}</a>) : <a className="button" href={release.url} rel="noopener noreferrer">{release.distribution === 'store' ? 'افتح صفحة التطبيق في المتجر' : platform.label}</a>}<small>الإصدار {release.version}</small>{release.notes && <small>{release.notes}</small>}</> : <><span className="pending">{platform.id === 'ios' ? 'قريبًا' : 'ملف الإصدار قيد التجهيز'}</span><small>{platform.id === 'ios' ? 'هنعلن هنا بمجرد توفر التطبيق على App Store.' : 'رابط التحميل يظهر هنا بعد نشر الإصدار من الإدارة.'}</small></>}
        {platform.id === 'windows' && <small>يتطلب Windows 64-bit. أجهزة 32-bit تستخدم نسخة الويب.</small>}
      </article>;
    })}</div></div></section>;
}
