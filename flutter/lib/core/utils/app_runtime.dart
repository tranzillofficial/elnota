/// Separate builds: the demo never initializes a Supabase client.
abstract class AppRuntime {
  static const demo = bool.fromEnvironment('ELNOTA_DEMO', defaultValue: false);
  static const demoDatabase = 'elnota_demo_v1.db';
}
