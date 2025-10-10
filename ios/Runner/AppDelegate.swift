import Flutter
import UIKit
import GoogleMaps
import FirebaseAuth
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API Key
    GMSServices.provideAPIKey("AIzaSyDCGHaPLh0xtssZETBIq6MnyQbwV0rzKVM")
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    GeneratedPluginRegistrant.register(with: self)
    
    // APNs kaydı (Phone Auth için) - Simulator'da başarısız olabilir ama crash olmaz
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // APNs token başarıyla alındığında
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("✅ APNs token alındı")
    // Firebase Auth'a token'ı ver (sadece token varsa)
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // APNs kayıt başarısız olduğunda (Simulator'da normal)
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("⚠️ APNs kayıt başarısız (Simulator?): \(error.localizedDescription)")
    // Simulator'da veya APNs olmadan - Firebase test phone numbers kullanılabilir
    // Burada crash olmamalı, sadece log
  }
  
  // Firebase Auth için remote notification handling
  override func application(_ application: UIApplication,
                            didReceiveRemoteNotification notification: [AnyHashable : Any],
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Firebase Auth'un notification'ı handle etmesine izin ver
    if Auth.auth().canHandleNotification(notification) {
      completionHandler(.noData)
      return
    }
    // Diğer notification'lar için parent'a devret
    super.application(application, didReceiveRemoteNotification: notification, fetchCompletionHandler: completionHandler)
  }
}
