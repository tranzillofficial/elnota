export default function Arrow({ direction = 'left' }: { direction?: 'left' | 'down' | 'diagonal' }) {
  const path = direction === 'down' ? 'M12 4v16m-6-6 6 6 6-6' : direction === 'diagonal' ? 'M6 18 18 6M6 6h12v12' : 'M20 12H4m6-6-6 6 6 6';
  return <svg className="arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={path}/></svg>;
}
