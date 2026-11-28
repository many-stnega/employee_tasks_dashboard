/// Values injected at build time by build_with_env.sh from the repo's .env.
///
/// Empty when the app is built with a plain `flutter build` command, in which
/// case the user can still type the values in Settings.
const String defaultServerUrl = String.fromEnvironment('DEFAULT_SERVER_URL');
const String defaultMobileToken = String.fromEnvironment('DEFAULT_MOBILE_TOKEN');
const String defaultAdminToken = String.fromEnvironment('DEFAULT_ADMIN_TOKEN');
