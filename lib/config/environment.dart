class Environment {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://onboardx.jomcloud.com',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc1OTA3MzQ2MCwiZXhwIjo0OTE0NzQ3MDYwLCJyb2xlIjoiYW5vbiJ9.uwjzLVaB3pmtadpSjahKtCRdWGbvntFpFOBCSQLMkck',
  );
}
