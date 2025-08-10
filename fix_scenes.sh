#!/usr/bin/env bash
set -euo pipefail

echo "➡️ Проект: $(pwd)"

# --- 1) Проверки путей
test -f ios/Runner/Info.plist || { echo "❌ Нет ios/Runner/Info.plist"; exit 1; }
test -f ios/Runner/AppDelegate.swift || { echo "❌ Нет ios/Runner/AppDelegate.swift"; exit 1; }

# --- 2) Обновляем Info.plist: добавляем UIScene-манифест с делегатом
python3 - <<'PY'
from pathlib import Path
from plistlib import load, dump

p = Path('ios/Runner/Info.plist')
with p.open('rb') as f:
    data = load(f)

manifest_key = 'UIApplicationSceneManifest'
need_write = False

if manifest_key not in data:
    data[manifest_key] = {
        'UIApplicationSupportsMultipleScenes': False,
        'UISceneConfigurations': {
            'UIWindowSceneSessionRoleApplication': [
                {
                    'UISceneConfigurationName': 'Default Configuration',
                    'UISceneDelegateClassName': '$(PRODUCT_MODULE_NAME).SceneDelegate',
                }
            ]
        }
    }
    need_write = True
else:
    # гарантируем наличие делегата
    confs = data[manifest_key].setdefault('UISceneConfigurations', {})
    app_list = confs.setdefault('UIWindowSceneSessionRoleApplication', [])
    if not app_list:
        app_list.append({
            'UISceneConfigurationName': 'Default Configuration',
            'UISceneDelegateClassName': '$(PRODUCT_MODULE_NAME).SceneDelegate',
        })
        need_write = True
    else:
        if 'UISceneDelegateClassName' not in app_list[0]:
            app_list[0]['UISceneDelegateClassName'] = '$(PRODUCT_MODULE_NAME).SceneDelegate'
            need_write = True

if need_write:
    with p.open('wb') as f:
        dump(data, f)
    print("📝 Info.plist: UIScene-манифест установлен/обновлён.")
else:
    print("ℹ️ Info.plist уже корректен.")
PY

# --- 3) Создаём SceneDelegate.swift (если нет)
if [ ! -f ios/Runner/SceneDelegate.swift ]; then
  cat > ios/Runner/SceneDelegate.swift <<'SWIFT'
import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {

    guard let windowScene = (scene as? UIWindowScene) else { return }

    // Создаём FlutterViewController как root
    let flutterVC = FlutterViewController(project: nil, nibName: nil, bundle: nil)

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterVC
    self.window = window
    window.makeKeyAndVisible()
  }
}
SWIFT
  echo "🧩 Создан ios/Runner/SceneDelegate.swift"
else
  echo "ℹ️ SceneDelegate.swift уже существует — пропускаем."
fi

# --- 4) Приводим AppDelegate.swift к сценам (оставляем FlutterAppDelegate)
# Ничего экзотического не делаем: просто убеждаемся, что это FlutterAppDelegate и @main
python3 - <<'PY'
from pathlib import Path, re
p = Path('ios/Runner/AppDelegate.swift')
txt = p.read_text(encoding='utf-8')

changed = False

# import Flutter обязательно
if 'import Flutter' not in txt:
    txt = txt.replace('import UIKit', 'import Flutter\nimport UIKit')
    changed = True

# класс должен наследоваться от FlutterAppDelegate и иметь @main
import re
txt2 = re.sub(r'@main\s+class\s+AppDelegate\s*:\s*[\w, ]+{',
              '@main class AppDelegate: FlutterAppDelegate {',
              txt)
if txt2 != txt:
    txt = txt2
    changed = True

# оставляем didFinishLaunching... как у Flutter-шаблона
if 'didFinishLaunchingWithOptions' not in txt:
    insert = '''
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
'''
    txt = re.sub(r'@main class AppDelegate: FlutterAppDelegate \{', 
                 r'@main class AppDelegate: FlutterAppDelegate {' + insert, txt)
    changed = True

if changed:
    p.write_text(txt, encoding='utf-8')
    print("📝 AppDelegate.swift обновлён.")
else:
    print("ℹ️ AppDelegate.swift без изменений.")
PY

# --- 5) Очистка и восстановление
echo "🧹 Чистим кэши и восстанавливаем зависимости…"
flutter precache --ios >/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData
flutter clean >/dev/null
flutter pub get >/dev/null
(cd ios && pod install >/dev/null)

# --- 6) Старт
echo "🚀 Запускаю flutter run (разблокируй iPhone, следи за правами Local Network)…"
flutter run
