export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function sha256(input: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input)));
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
}
export function randomSecret(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), b => b.toString(16).padStart(2, '0')).join('');
}
export function isExpired(expiresAt: string, now = Date.now()): boolean {
  return !Number.isFinite(Date.parse(expiresAt)) || Date.parse(expiresAt) <= now;
}
