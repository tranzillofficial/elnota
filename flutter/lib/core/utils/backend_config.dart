/// Public client configuration shared by Android, Windows and Web.
/// The publishable key is designed for client distribution; RLS remains required.
abstract class BackendConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fsmoerttftxcuxpswufk.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Y_OAK5Un4D0ifGSXuezGrQ_gomzlmlQ',
  );
}
