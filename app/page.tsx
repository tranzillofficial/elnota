import type { Metadata } from 'next';
import { Check, Cloud, ArrowLeft } from 'lucide-react';
import Image from 'next/image';
import Arrow from './landing-components/arrow';
import Downloads from './landing-components/downloads';

export const metadata: Metadata = {alternates:{canonical:'https://elnota.shop'},openGraph:{url:'https://elnota.shop',title:'النوتة | حسابات أوضح، وشغل أريح',locale:'ar_EG',type:'website'}};

const features = [
  ['01', 'كل عميل، حسابه واضح', 'بيانات العميل وفواتيره ودفعاته ورصيده المتبقي قدامك في شاشة واحدة.'],
  ['02', 'فاتورة على قد شغلك', 'بيع نقدي أو آجل أو بالأقساط، مع بنود وأسعار ودفعة مقدمة وجدول استحقاقات.'],
  ['03', 'الأقساط تحت عينك', 'اعرف المستحق والقريب والمتأخر، والدفعات تخصم من أقدم استحقاق أولًا.'],
  ['04', 'كشف حساب مفهوم', 'تابع حركة الحساب بالتاريخ، واطبع أو صدّر كشف الحساب PDF بالعربي.'],
  ['05', 'شغلك معاك', 'واجهة تناسب الموبايل والكمبيوتر، وتجربة ويب تدخلها بموافقة من موبايلك.'],
  ['06', 'طباعة تناسب محلك', 'إعدادات للفواتير والشعار والطابعة، ومقاسات ورق A4 و58 و80 مم.'],
];
const faq = [
  ['إيه الفرق بين الموقع ونسخة الويب؟', 'الموقع بيعرّفك بالنوتة ويساعدك تختار النسخة المناسبة. نسخة الويب هي التطبيق نفسه لإدارة الحسابات، وتفتحها من زر «دخول».'],
  ['بدخل من الكمبيوتر إزاي؟', 'افتح نسخة الويب، وامسح QR بكاميرا الموبايل. التطبيق يطلب منك مقارنة كود التأكيد والموافقة قبل فتح حسابك على الكمبيوتر. يلزم إصدار موبايل يدعم ربط الأجهزة ونفس بيئة الحساب.'],
  ['إزاي أنقل بيانات النسخة القديمة؟', 'من نفس المتصفح القديم افتح صفحة استرجاع البيانات وصدّر الملف، أو استخدم نسخة احتياطية محفوظة لديك. افتح إعدادات التطبيق الجديد واستورد الملف إلى دفتر فارغ، بعد مراجعة عدد السجلات والأرصدة.'],
  ['هل فيه نسخة Windows 32-bit؟', 'تطبيق Windows الأصلي متاح لمعمارية 64-bit عند نشر المثبّت. أجهزة 32-bit تستخدم نسخة الويب على متصفح مدعوم.'],
  ['إزاي أسجّل الدخول؟', 'استخدم نفس البريد وكلمة المرور على الويب أو التطبيق. الحسابات الجديدة تحتاج موافقة الإدارة بعد التحقق من الدفع؛ الدخول السريع برمز QR متاح من شاشة الدخول.'],
];

function Mark() { return <span className="brand"><Image src="/logo.png" alt="" width={42} height={42} /><b>النوتة<span>ElNota</span></b></span>; }

export default function Home() {
  return <div className="new-landing">
    <div className="preview-bar">مستخدم للنسخة السابقة؟ <a href="/recover">احفظ بياناتك القديمة واستوردها بأمان</a></div>
    <header className="nav wrap"><a href="/" aria-label="النوتة الرئيسية"><Mark /></a><nav aria-label="القائمة الرئيسية"><a href="#features">المميزات</a><a href="#how">إزاي تبدأ</a><a href="#pricing">الأسعار</a><a href="#downloads">التحميلات</a><a href="#faq">أسئلة شائعة</a></nav><a className="button small" href="/app/">دخول <Arrow direction="diagonal" /></a></header>
    <main>
      <section className="hero wrap">
        <div className="hero-copy"><span className="eyebrow"><i /> نوتة شغلك، بشكل جديد</span><h1>حسابات أوضح.<br /><em>وشغل أريح.</em></h1><p>عملاءك، فواتيرك، واللي ليك واللي عليك.<br />كل تفاصيل شغلك في نوتة واحدة، سهلة ومنظمة.</p><div className="hero-actions"><div className="actions"><a className="button" href="/app/">دخول لحسابك <Arrow /></a><a className="button secondary" href="#downloads">اختار نسختك <Arrow direction="down" /></a></div><a className="button demo-button" href="/demo">جرب حساب ديمو <Arrow /></a></div><div className="hero-notes"><span>✓ عربي من أول شاشة</span><span>✓ للموبايل والكمبيوتر</span><span>✓ نقدي، آجل، وأقساط</span></div></div>
        <div className="hero-visual"><div className="floating-note"><span className="note-icon">✓</span><div><b>كل دفعة في مكانها</b><small>ورصيد عميلك واضح دايمًا</small></div></div><div className="browser-card"><div className="browser-top"><span>elnota · مساحة شغلك</span><div><i /><i /><i /></div></div><Image className="dashboard-image" src="/dashboard.png" alt="معاينة واجهة النوتة العربية: ملخص المستحقات والعملاء وآخر العمليات وحركة التحصيل" width={1586} height={992} priority /></div><span className="visual-caption">نظرة واحدة، وتبقى عارف حساباتك واقفة فين.</span></div>
      </section>
      <section className="trust wrap"><span>مساحة واحدة لكل تفاصيل شغلك</span><div><b>العملاء</b><i>✦</i><b>الفواتير</b><i>✦</i><b>الدفعات</b><i>✦</i><b>الأقساط</b><i>✦</i><b>كشف الحساب</b></div></section>
      <section className="section wrap" id="features"><div className="section-heading"><span className="eyebrow">تفاصيل أقل تتوه منك</span><h2>ركّز في شغلك.<br />وسيّب الحسابات للنوتة.</h2><p>أدوات واضحة للي بتحتاجه كل يوم، من أول فاتورة لآخر دفعة.</p></div><div className="feature-grid">{features.map(([number,title,text])=><article className="feature" key={number}><span>{number}</span><h3>{title}</h3><p>{text}</p></article>)}</div></section>
      <section className="account-section"><div className="wrap account-grid"><div><span className="eyebrow">الصورة كاملة، من غير لف</span><h2>افتح حساب العميل.<br />هتلاقي كل إجاباتك.</h2><p>باع بكام؟ دفع كام؟ فاضل عليه إيه؟<br />الفواتير والدفعات والاستحقاقات جنب بعض، عشان كل تعامل يبقى واضح.</p><a className="text-link" href="/app/">شوف تجربة الويب <Arrow /></a></div><div className="image-panel"><Image src="/account.png" alt="واجهة حساب العميل موضحة إجمالي الفواتير والمدفوع والمتبقي والأقساط" width={1586} height={992} /></div></div></section>
      <section className="section wrap" id="how"><div className="section-heading centered"><span className="eyebrow">من الموبايل للكمبيوتر</span><h2>افتح الويب في ٣ خطوات.</h2><p>الدخول بيتم بموافقتك من التطبيق، من غير مشاركة كلمة السر.</p></div><div className="steps"><article><b>١</b><h3>افتح نسخة الويب</h3><p>من الكمبيوتر أو المتصفح، افتح شاشة ربط الأجهزة.</p></article><article><b>٢</b><h3>امسح رمز QR</h3><p>استخدم كاميرا موبايلك لفتح طلب الربط في التطبيق.</p></article><article><b>٣</b><h3>قارن الكود ووافق</h3><p>اتأكد من كود التأكيد، ووافق على الجهاز اللي قدامك.</p></article></div><div className="center"><a className="button" href="/app/">جرّب نسخة الويب <Arrow direction="diagonal" /></a></div></section>
<section id="pricing" className="wrap section legacy-pricing"><div className="section-heading centered"><span className="eyebrow">سعر واضح من البداية</span><h2>ادفع مرة. وابدأ شغلك.</h2><p>التفعيل الأساسي دائم. خدمات السحابة تضيفها وقت ما تحتاجها.</p></div><div className="pricing-grid"><article className="price-card"><span className="eyebrow">نوتتك الأساسية</span><h3>التفعيل الدائم</h3><div className="price">1,000 <span>جنيه / مرة واحدة</span></div><p>أساس شغلك، من غير اشتراك إجباري.</p><ul>{['إدارة العملاء والفواتير','دفعات وأقساط وسجل تحصيل','مشاركة الفواتير على واتساب والطباعة','حفظ محلي والعمل بدون اتصال بعد التجهيز','استيراد ملفات النسخ السابقة','تطبيق Android وWindows ونسخة ويب'].map(x=><li key={x}><Check size={17}/>{x}</li>)}</ul><a href="/app/#/auth/login" className="button full">ابدأ بالتفعيل الأساسي <ArrowLeft size={16}/></a><small>التفعيل يدوي بعد مراجعة الدفع.</small></article><article className="price-card featured"><span className="price-badge">إضافة اختيارية</span><span className="eyebrow">نوتتك معاك في كل مكان</span><h3>النوتة Cloud</h3><div className="price">500 <span>جنيه / سنة</span></div><p>أو 50 جنيه شهريًا. وفر 100 جنيه بالسنوي.</p><ul>{['كل مميزات التفعيل الأساسي','مزامنة الحسابات بين أجهزتك عند الاتصال','نسخ تلقائي أثناء استخدام التطبيق','استرجاع آخر 3 نسخ سحابية سابقة','حتى 10 MB لبيانات الحسابات والفواتير','تصدير بياناتك حتى بعد انتهاء الاشتراك'].map(x=><li key={x}><Check size={17}/>{x}</li>)}</ul><a href="/app/#/auth/login" className="button full">اختار السحابة لاحقًا <Cloud size={17}/></a><small>يتطلب التفعيل الأساسي. المنتجات متاحة لمشتركي الكلاود أو باستثناء من الإدارة.</small></article></div><p className="pricing-footnote">الحفظ المحلي يتبع مساحة وسياسة المتصفح. احتفظ بنسخة خارج الجهاز بانتظام. الاشتراك السحابي لا يُجدد تلقائيًا.</p></section>

      <Downloads />
      <section className="section wrap faq-section" id="faq"><div className="section-heading"><span className="eyebrow">قبل ما تبدأ</span><h2>أسئلة على بالك؟</h2><p>دي إجابات تساعدك تختار وتبدأ.</p></div><div className="faq-list">{faq.map(([q,a])=><details key={q}><summary>{q}<span>+</span></summary><p>{a}</p></details>)}</div></section>
      <section className="wrap final-cta"><div><span>دفتر جديد لشغل مرتب</span><h2>خلّي كل حساب، في مكانه.</h2></div><a className="button white" href="/app/">افتح النوتة <Arrow /></a></section>
    </main>
    <footer className="wrap"><Mark /><p>النوتة — شغلك منظم، وحساباتك واضحة.</p><a href="/privacy">الخصوصية</a><span>© {new Date().getFullYear()} النوتة</span></footer>
  </div>;
}
