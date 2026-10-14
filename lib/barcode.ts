/** Codes are treated as exact product identifiers, not URLs or remote lookups. */
export function normalizeScannedCode(value: string): string {
  const code = value.trim();
  if (!code || code.length > 100 || /[\u0000-\u001f\u007f]/.test(code)) return '';
  return code;
}
