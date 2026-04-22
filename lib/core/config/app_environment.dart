import 'package:package_info_plus/package_info_plus.dart';

/// Build-time app environment from `--dart-define=ENV=dev` or `ENV=prod`.
///
/// Defaults to `prod` so CI or scripts that do not pass `ENV` keep production
/// behavior. You can also run the **Android `dev` flavor** (`com.shinrinyoku.glimpse
/// .dev`); [initPackageInfo] marks that as a dev client so dev-only tools
/// (e.g. local Pro override) are available without a matching `--dart-define`.
class AppEnvironment {
  AppEnvironment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'prod');

  /// Android `dev` product flavor (see [initPackageInfo]).
  static const String _devClientPackageName = 'com.shinrinyoku.glimpse.dev';

  static bool _isDevClientPackage = false;

  static bool get isDev => _env == 'dev';
  static bool get isProd => _env == 'prod';

  static String get name => isDev ? 'dev' : 'prod';

  /// `true` when running a dev *build* (`ENV=dev`) or the dev *Android install*.
  /// Use for banners and the Force Pro toggle. Never true for the Play store
  /// `com.shinrinyoku.glimpse` production install.
  static bool get isDevContext => isDev || _isDevClientPackage;

  /// Same as [isDevContext] — when local Pro override is allowed to apply.
  static bool get allowsLocalProOverride => isDevContext;

  /// Use for dev-only logging or diagnostics (e.g. verbose network logging).
  static bool get useVerboseDebug => isDev;

  /// Call from [main] after [WidgetsFlutterBinding.ensureInitialized] so the
  /// `dev` applicationId is detected and [isDevContext] works without `ENV=dev`.
  static Future<void> initPackageInfo() async {
    final n = (await PackageInfo.fromPlatform()).packageName;
    _isDevClientPackage = n == _devClientPackageName;
  }
}
