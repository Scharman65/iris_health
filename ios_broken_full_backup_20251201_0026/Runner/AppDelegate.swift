import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Один общий движок для всего приложения
  lazy var flutterEngine = FlutterEngine(name: "irida_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
  ) -> Bool {

    // Стартуем движок
    flutterEngine.run()

    // Регистрируем плагины ИМЕННО НА ЭТОМ движке
    GeneratedPluginRegistrant.register(with: flutterEngine)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Поддержка UIScene
  @available(iOS 13.0, *)
  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let config = UISceneConfiguration(name: "Default Configuration",
                                     sessionRole: connectingSceneSession.role)
    
    return config
  }
}
