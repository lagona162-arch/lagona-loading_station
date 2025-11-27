class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://lpcjaxssqvgvgtvwabkv.supabase.co');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwY2pheHNzcXZndmd0dndhYmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNzk4NzAsImV4cCI6MjA3NTg1NTg3MH0.P8bMu0__Y2tYaE0kbHnpDHPMAQ421gCeHSIEaURLR2Q');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

class SupabaseConfigMissingException implements Exception {
  const SupabaseConfigMissingException();

  @override
  String toString() => 'Supabase credentials are missing. '
      'Pass SUPABASE_URL and SUPABASE_ANON_KEY using --dart-define.';
}

