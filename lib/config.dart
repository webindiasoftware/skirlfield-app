/// Build-time settings. Override without editing code:
///   flutter run --dart-define=API_BASE=http://192.168.1.20/skirlfield/api/v1
class Config {
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://softskirl.co.in/skirlfield/api/v1',
  );

  /// Shown on the login screen and in the "On duty" notification.
  static const appName = 'SkirlField';
}
