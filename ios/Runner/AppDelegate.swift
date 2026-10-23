import Flutter
import UIKit

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
    let channel = FlutterMethodChannel(
      name: "hris_mobile/sensitive_screen",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setSensitive" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let enabled = call.arguments as? Bool else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Expected a boolean value.",
            details: nil
          )
        )
        return
      }
      SensitiveScreenProtection.shared.isEnabled = enabled
      result(nil)
    }
  }
}

final class SensitiveScreenProtection {
  static let shared = SensitiveScreenProtection()

  var isEnabled = false {
    didSet { updateCaptureCover() }
  }

  private weak var window: UIWindow?
  private var cover: UIView?
  private var sceneInactive = false

  private init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }

  func bind(window: UIWindow?) {
    self.window = window
    updateCaptureCover()
  }

  func setSceneInactive(_ value: Bool) {
    sceneInactive = value
    updateCaptureCover()
  }

  @objc private func captureStateChanged() {
    updateCaptureCover()
  }

  private func updateCaptureCover() {
    let shouldCover = isEnabled && (sceneInactive || UIScreen.main.isCaptured)
    if shouldCover {
      guard cover == nil, let window else { return }
      let privacyCover = UIView(frame: window.bounds)
      privacyCover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      privacyCover.backgroundColor = .systemBackground

      let label = UILabel()
      label.text = "Konten sensitif dilindungi"
      label.textAlignment = .center
      label.textColor = .label
      label.translatesAutoresizingMaskIntoConstraints = false
      privacyCover.addSubview(label)
      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: privacyCover.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: privacyCover.centerYAnchor),
      ])
      window.addSubview(privacyCover)
      cover = privacyCover
    } else {
      cover?.removeFromSuperview()
      cover = nil
    }
  }
}
