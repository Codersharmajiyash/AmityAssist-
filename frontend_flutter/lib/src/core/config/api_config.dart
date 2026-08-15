class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'UNIASSIST_API_BASE',
    defaultValue: 'http://localhost:8000',
  );
}
