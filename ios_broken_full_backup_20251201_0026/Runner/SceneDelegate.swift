import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    var flutterEngine: FlutterEngine {
        return (UIApplication.shared.delegate as! AppDelegate).flutterEngine
    }

    @available(iOS 13.0, *)
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        // Основной Flutter-контроллер на движке
        let flutterVC = FlutterViewController(
            engine: flutterEngine,
            nibName: nil,
            bundle: nil
        )

        // Создаём окно и показываем
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = flutterVC
        self.window = window
        window.makeKeyAndVisible()

        //-------------------------------------------------------------
        // MethodChannel — ПРАВИЛЬНОЕ место (здесь controller = не nil)
        //-------------------------------------------------------------
        let probeChannel = FlutterMethodChannel(
            name: "irida.camera/probe",
            binaryMessenger: flutterVC.binaryMessenger
        )

        probeChannel.setMethodCallHandler { call, result in
            if call.method == "runProbe" {
                result(CameraProbe.run())
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    @available(iOS 13.0, *)
    func sceneDidDisconnect(_ scene: UIScene) {}

    @available(iOS 13.0, *)
    func sceneDidBecomeActive(_ scene: UIScene) {}

    @available(iOS 13.0, *)
    func sceneWillResignActive(_ scene: UIScene) {}

    @available(iOS 13.0, *)
    func sceneWillEnterForeground(_ scene: UIScene) {}

    @available(iOS 13.0, *)
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
