'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { Camera, ScanLine, X } from 'lucide-react';
import type { Html5Qrcode } from 'html5-qrcode';
import { normalizeScannedCode } from '@/lib/barcode';

export function BarcodeScanner({ onScan, onClose }: { onScan: (code: string) => void; onClose: () => void }) {
  const scannerId = 'elnota-scanner-' + useId().replace(/[^a-zA-Z0-9_-]/g, '');
  const onScanRef = useRef(onScan);
  const [manual, setManual] = useState('');
  const [error, setError] = useState('');
  const [active, setActive] = useState(false);
  onScanRef.current = onScan;

  useEffect(() => {
    let disposed = false;
    let scanner: Html5Qrcode | null = null;
    const cleanup = async () => {
      if (!scanner) return;
      try { if (scanner.isScanning) await scanner.stop(); } catch { /* The camera may already be stopped. */ }
      try { scanner.clear(); } catch { /* The element may have been removed. */ }
    };

    async function openCamera() {
      if (!navigator.mediaDevices?.getUserMedia) {
        setError('الكاميرا غير متاحة. افتح التطبيق على HTTPS واسمح للمتصفح باستخدام الكاميرا.');
        return;
      }
      try {
        // Loaded only when the scanner opens. The built-in ZXing fallback also works
        // in browsers without the experimental native BarcodeDetector API (e.g. iOS).
        const { Html5Qrcode } = await import('html5-qrcode');
        if (disposed) return;
        scanner = new Html5Qrcode(scannerId, { verbose: false, useBarCodeDetectorIfSupported: true });
        await scanner.start({ facingMode: 'environment' }, { fps: 10 }, decodedText => {
          if (disposed) return;
          const code = normalizeScannedCode(decodedText);
          if (!code) return;
          disposed = true;
          onScanRef.current(code);
        }, () => { /* No barcode detected in this frame. */ });
        if (disposed) { await cleanup(); return; }
        setActive(true);
      } catch (cause) {
        if (disposed) { await cleanup(); return; }
        const name = (cause as Error)?.name;
        setError(name === 'NotAllowedError' || String(cause).includes('Permission')
          ? 'اسمح للتطبيق باستخدام الكاميرا من إعدادات المتصفح وحاول تاني.'
          : 'تعذر تشغيل الكاميرا. تأكد إنها مش مستخدمة في تطبيق تاني.');
      }
    }

    void openCamera();
    return () => { disposed = true; void cleanup(); };
  }, [scannerId]);

  const submitManual = () => {
    const code = normalizeScannedCode(manual);
    if (!code) {
      setError('اكتب كود صالح من 1 إلى 100 حرف.');
      return;
    }
    onScanRef.current(code);
  };

  return <div className="modal-overlay scanner-overlay" onClick={onClose}>
    <section className="scanner-dialog" role="dialog" aria-modal="true" aria-label="مسح باركود أو QR" onClick={event => event.stopPropagation()}>
      <div className="scanner-heading">
        <div><h2><ScanLine size={22}/> مسح باركود أو QR</h2><p>وجّه الكاميرا على الكود الموجود على المنتج</p></div>
        <button type="button" className="icon-button" aria-label="إغلاق الماسح" onClick={onClose}><X size={22}/></button>
      </div>
      <div className="scanner-preview">
        <div id={scannerId} className="scanner-reader"/>
        {!active && !error && <div className="scanner-loading"><Camera size={24}/><span>جارٍ تجهيز الماسح…</span></div>}
      </div>
      {error && <p className="notice error" role="alert">{error}</p>}
      <div className="scanner-manual">
        <label htmlFor="scanner-manual-code">أو اكتب رقم الباركود / QR يدويًا</label>
        <div>
          <input id="scanner-manual-code" dir="ltr" autoComplete="off" inputMode="text" maxLength={100} value={manual} placeholder="رقم أو كود المنتج" onChange={event => setManual(event.target.value)} onKeyDown={event => { if (event.key === 'Enter') { event.preventDefault(); submitManual(); } }}/>
          <button className="button" type="button" onClick={submitManual}>بحث بالكود</button>
        </div>
      </div>
    </section>
  </div>;
}
