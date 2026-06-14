import Flutter
import UIKit
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GlimpseStableId") {
      StableIdChannel.register(messenger: registrar.messenger())
    }
  }
}

/// Durable, reinstall-surviving storage for the stable install id, backed by the
/// iOS Keychain. Keychain items persist across app uninstall/reinstall, so the
/// server-side AI quota keyed on this id cannot be reset by reinstalling.
///
/// Bridges the `com.shinrinyoku.glimpse/stable_id` MethodChannel (see
/// `DurableIdStore` on the Dart side) with `read` / `write` methods.
enum StableIdChannel {
  private static let channelName = "com.shinrinyoku.glimpse/stable_id"
  private static let service = "com.shinrinyoku.glimpse.stable_id"
  private static let account = "glimpse_stable_install_id"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "read":
        result(read())
      case "write":
        guard
          let args = call.arguments as? [String: Any],
          let id = args["id"] as? String,
          !id.isEmpty
        else {
          result(FlutterError(code: "bad_args", message: "missing id", details: nil))
          return
        }
        write(id)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func baseQuery() -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }

  private static func read() -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard
      status == errSecSuccess,
      let data = item as? Data,
      let value = String(data: data, encoding: .utf8),
      !value.isEmpty
    else {
      return nil
    }
    return value
  }

  private static func write(_ id: String) {
    guard let data = id.data(using: .utf8) else { return }
    // Idempotent upsert: delete any existing entry then add fresh.
    SecItemDelete(baseQuery() as CFDictionary)

    var attributes = baseQuery()
    attributes[kSecValueData as String] = data
    // Device-bound (no iCloud Keychain sync) but available after first unlock,
    // which is enough for a background-launched app to read it.
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(attributes as CFDictionary, nil)
  }
}
