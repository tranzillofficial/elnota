import styles from './DownloadsSection.module.css';

type Release = { url: string; version: string; sha256: string; size: number };
type Releases = { android?: Release; windowsX64?: Release };

/** Server component: import into the existing landing only after approval.
 * No Flutter bundle, browser auth state, or client-side rendering is required. */
export default function DownloadsSection({ releases = {} }: { releases?: Releases }) {
  const webUrl = 'https://app.elnota.shop';
  const cards = [
    { title: 'Android', subtitle: 'تطبيق النوتة للموبايل', release: releases.android, label: 'تحميل APK', note: 'ثبّت النسخة على موبايلك وسجّل الدخول لربط المتصفح.' },
    { title: 'Windows 64-bit', subtitle: 'تطبيق النوتة للكمبيوتر', release: releases.windowsX64, label: 'تحميل المثبّت', note: 'Windows 10 أو 11 بمعمارية x64.' },
  ];
  function safeRelease(release: Release | undefined) {
    if (!release || !/^[a-f0-9]{64}$/i.test(release.sha256) || release.size <= 0) return undefined;
    try {
      const url = new URL(release.url);
      return url.protocol === 'https:' && ['elnota.shop', 'downloads.elnota.shop', 'github.com'].includes(url.hostname) ? release : undefined;
    } catch { return undefined; }
  }
  return <section id="downloads" className={styles.section} dir="rtl" aria-labelledby="downloads-title">
    <div className={styles.heading}><span>النوتة معاك على أجهزتك</span><h2 id="downloads-title">اختار النسخة المناسبة لشغلك</h2><p>نزّل التطبيق، أو افتح النوتة من المتصفح واربطه بموافقة من الموبايل.</p></div>
    <div className={styles.grid}>
      {cards.map(card => {
        const release = safeRelease(card.release);
        return <article className={styles.card} key={card.title}>
          <span className={styles.tag}>تطبيق الجهاز</span><h3 dir="ltr">{card.title}</h3><p>{card.subtitle}</p>
          {release ? <><a className={styles.button} href={release.url}>{card.label}</a><small>الإصدار {release.version} · {(release.size / 1048576).toFixed(1)} MB</small><details><summary>التحقق من الملف</summary><code className={styles.hash} dir="ltr">SHA-256: {release.sha256}</code></details></> : <span className={styles.pending}>التحميل متاح بعد نشر الإصدار</span>}
          <small>{card.note}</small>
        </article>;
      })}
      <article className={`${styles.card} ${styles.web}`}><span className={styles.tag}>من غير تثبيت</span><h3>نسخة الويب</h3><p>افتح رمز QR على الكمبيوتر، ووافق على الدخول من موبايلك.</p><a className={styles.button} href={webUrl}>افتح النوتة Web</a><small>للأجهزة التي تدعم المتصفحات الحديثة، ومنها أجهزة Windows 32-bit. نسخة Flutter الأصلية لـWindows تتطلب 64-bit.</small></article>
    </div>
    <p className={styles.note}>روابط التحميل تظهر عند توفر ملف إصدار حقيقي مع بصمته. موقع النوتة الأساسي يظل على elnota.shop.</p>
  </section>;
}
