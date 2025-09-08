import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Общий Flutter-движок, разделяемый между сценами
  lazy var flutterEngine = FlutterEngine(name: "primary_engine")
  private var flutterEngineHasRun = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Сначала запускаем движок!
    if !flutterEngineHasRun {
      flutterEngine.run()
      flutterEngineHasRun = true
    }
    // Затем регистрируем плагины
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene lifecycle (iOS 13+)
  @available(iOS 13.0, *)
  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let config = UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
    config.delegateClass = SceneDelegate.self
    return config
  }
}

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = UIWindow(windowScene: windowScene)
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    // Здесь движок уже запущен, повторно run не вызываем!
    let flutterVC = FlutterViewController(
      engine: appDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )

    window.rootViewController = flutterVC
    self.window = window
    window.makeKeyAndVisible()
  }
}
