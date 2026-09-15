import CoreLocation
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var externalUriChannel: FlutterMethodChannel?
  private var emergencyLocationHandler: EmergencyLocationHandler?
  private var activitySharePosterHandler: ActivitySharePosterHandler?
  private var backgroundMediaUploadHandler: BackgroundMediaUploadHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.good.pet.hospital/external_uri",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard
          let arguments = call.arguments as? [String: Any],
          let rawUri = arguments["uri"] as? String,
          let uri = URL(string: rawUri),
          let scheme = uri.scheme?.lowercased(),
          ["http", "https", "tel"].contains(scheme)
        else {
          result(false)
          return
        }

        switch call.method {
        case "canLaunchUri":
          result(UIApplication.shared.canOpenURL(uri))
        case "launchUri":
          UIApplication.shared.open(uri, options: [:]) { success in
            result(success)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      externalUriChannel = channel
      emergencyLocationHandler = EmergencyLocationHandler(
        binaryMessenger: controller.binaryMessenger
      )
      activitySharePosterHandler = ActivitySharePosterHandler(
        binaryMessenger: controller.binaryMessenger
      )
      backgroundMediaUploadHandler = BackgroundMediaUploadHandler(
        binaryMessenger: controller.binaryMessenger
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    if backgroundMediaUploadHandler?.handlesBackgroundEvents(for: identifier) == true {
      backgroundMediaUploadHandler?.setBackgroundEventsCompletionHandler(completionHandler)
      return
    }
    super.application(
      application,
      handleEventsForBackgroundURLSession: identifier,
      completionHandler: completionHandler
    )
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    // Tobias 会在 super 中解析支付结果，但对 Universal Link 固定返回 false。
    let handled = super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )

    guard
      userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let url = userActivity.webpageURL,
      url.host?.lowercased() == "gudeapi.zuoyongyoubao.com",
      url.path.hasPrefix("/alipay/")
    else {
      return handled
    }

    return true
  }
}

private final class ActivitySharePosterHandler {
  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.good.pet.hospital/activity_share_poster",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "savePng" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let typedData = arguments["bytes"] as? FlutterStandardTypedData,
        let image = UIImage(data: typedData.data)
      else {
        result(FlutterError(
          code: "invalid_image",
          message: "活动海报数据无效",
          details: nil
        ))
        return
      }

      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }) { saved, error in
        DispatchQueue.main.async {
          if saved {
            result(true)
          } else {
            result(FlutterError(
              code: "save_failed",
              message: error?.localizedDescription ?? "活动海报保存失败",
              details: nil
            ))
          }
        }
      }
    }
  }
}

private final class EmergencyLocationHandler: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let channel: FlutterMethodChannel
  private var permissionResult: FlutterResult?
  private var locationResult: FlutterResult?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.good.pet.hospital/emergency_location",
      binaryMessenger: binaryMessenger
    )
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkPermission":
      result(permissionStatus())
    case "requestPermission":
      requestPermission(result)
    case "getCurrentLocation":
      getCurrentLocation(result)
    case "cancelCurrentLocation":
      cancelCurrentLocation(result)
    case "openSettings":
      openSettings(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func permissionStatus() -> String {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse:
      return "granted"
    case .denied, .restricted:
      return "blocked"
    case .notDetermined:
      return "denied"
    @unknown default:
      return "denied"
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    let status = permissionStatus()
    guard status == "denied" else {
      result(status)
      return
    }
    guard permissionResult == nil else {
      result(FlutterError(
        code: "permission_request_busy",
        message: "位置权限请求正在进行",
        details: nil
      ))
      return
    }
    permissionResult = result
    manager.requestWhenInUseAuthorization()
  }

  private func getCurrentLocation(_ result: @escaping FlutterResult) {
    guard permissionStatus() == "granted" else {
      result(FlutterError(
        code: "permission_denied",
        message: "位置权限未授予",
        details: nil
      ))
      return
    }
    guard CLLocationManager.locationServicesEnabled() else {
      result(FlutterError(
        code: "location_disabled",
        message: "系统定位服务未开启",
        details: nil
      ))
      return
    }
    guard locationResult == nil else {
      result(FlutterError(
        code: "location_request_busy",
        message: "正在获取当前位置",
        details: nil
      ))
      return
    }
    locationResult = result
    manager.requestLocation()
  }

  private func cancelCurrentLocation(_ result: @escaping FlutterResult) {
    let pendingResult = locationResult
    locationResult = nil
    manager.stopUpdatingLocation()
    pendingResult?(FlutterError(
      code: "location_cancelled",
      message: "定位请求已取消",
      details: nil
    ))
    result(nil)
  }

  private func openSettings(_ result: @escaping FlutterResult) {
    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(settingsUrl, options: [:]) { opened in
      result(opened)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    completePermissionRequestIfNeeded()
  }

  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    completePermissionRequestIfNeeded()
  }

  private func completePermissionRequestIfNeeded() {
    guard CLLocationManager.authorizationStatus() != .notDetermined,
          let result = permissionResult else {
      return
    }
    permissionResult = nil
    result(permissionStatus())
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let result = locationResult else { return }
    locationResult = nil
    guard let location = locations.last else {
      result(FlutterError(
        code: "location_failed",
        message: "系统未返回当前位置",
        details: nil
      ))
      return
    }
    result([
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard let result = locationResult else { return }
    locationResult = nil
    result(FlutterError(
      code: "location_failed",
      message: error.localizedDescription,
      details: nil
    ))
  }
}
