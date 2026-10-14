'use client';

import { useEffect, useRef, useState } from 'react';
import { Camera, ScanLine, X } from 'lucide-react';
import { normalizeScannedCode } from '@/lib/barcode';

type DetectedBarcode = { rawValue?: string };
type Detector = { detect: (video: HTMLVideoElement) => Promise<DetectedBarcode[]> };
type DetectorConstructor = new () => Detector;

export function BarcodeScanner({ onScan, onClose }: { onScan: (code: string) => void; onClose: () => void }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const onScanRef = useRef(onScan);
  const [manual, setManual] = useState('');
  const [error, setError] = useState('');
  const [active, setActive] = useState(false);
  onScanRef.current = onScan;

  useEffect(() => {
    let stopped = false;
    let frame = 0;
    let stream: MediaStream | null = null;

    async function openCamera() {
      const BarcodeDetectorClass = (globalThis as typeof globalThis & {
        BarcodeDetector?: DetectorConstructor;
      }).BarcodeDetector;

      if (!BarcodeDetectorClass) {
        setError('المتصفح ده مش بيدعم قراءة الباركود بالكاميرا. اكتب الكود يدويًا، أو استخدم متصفح بيدعم BarcodeDetector.');
        return;
      }
      if (!navigator.mediaDevices?.getUserMedia) {
        setError('الكاميرا غير متاحة. افتح التطبيق من اتصال HTTPS واسمح للمتصفح باستخدام الكاميرا.');
        return;
      }
      try {
        const detector = new BarcodeDetectorClass();
        const media = await navigator.mediaDevices.getUserMedia({
          audio: false,
          video: { facingMode: { ideal: 'environment' } },
        });
        stream = media;
        if (stopped) {
          media.getTracks().forEach(track => track.stop());
          return;
        }
        const video = videoRef.current;
        if (!video) return;
        video.srcObject = media;
        await video.play();
        if (stopped) return;
        setActive(true);
        let detecting = false;

        const loop = async () => {
          if (stopped) return;
          if (!detecting && video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
            detecting = true;
            try {
              const codes = await detector.detect(video);
              const code = codes.map(item => normalizeScannedCode(item.rawValue || '')).find(Boolean);
              if (code && !stopped) {
                stopped = true;
                media.getTracks().forEach(track => track.stop());
                onScanRef.current(code);
                return;
              }
            } catch {
              // A frame can fail detection without ending the camera session.
            } finally {
              detecting = false;
            }
          }
          frame = requestAnimationFrame(loop);
        };
        frame = requestAnimationFrame(loop);
      } catch (cause) {
        if (stopped) return;
        const name = (cause as Error)?.name;
        setError(name === 'NotAllowedError'
          ? 'اسمح للتطبيق باستخدام الكاميرا من إعدادات المتصفح وحاول تاني.'
          : 'تعذر تشغيل الكاميرا. تأكد إنها مش مستخدمة في تطبيق تاني.');
      }
    }

    void openCamera();
    return () => {
      stopped = true;
      cancelAnimationFrame(frame);
      stream?.getTracks().forEach(track => track.stop());
      if (videoRef.current) videoRef.current.srcObject = null;
    };
  }, []);

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
        <video ref={videoRef} playsInline muted autoPlay aria-label="معاينة الكاميرا الخلفية"/>
        <div className="scanner-guide" aria-hidden="true"/>
        {!active && <div className="scanner-loading"><Camera size={24}/><span>جارٍ تجهيز الماسح…</span></div>}
      </div>
      {error && <p className="notice error" role="alert">{error}</p>}
      <div className="scanner-manual">
        <label htmlFor="scanner-manual-code">أو اكتب رقم الباركود / QR يدويًا</label>
        <div>
          <input id="scanner-manual-code" dir="ltr" autoComplete="off" inputMode="text" maxLength={100} value={manual} placeholder="رقم أو كود المنتج" onChange={event => setManual(event.target.value)} onKeyDown={event => { if (event.key === 'Enter') submitManual(); }}/>
          <button className="button" type="button" onClick={submitManual}>بحث بالكود</button>
        </div>
      </div>
    </section>
  </div>;
}
