import Cocoa
import InputMethodKit
import UserNotifications

class NSManualApplication: NSApplication {
  private let appDelegate = AppDelegate()

  override init() {
    super.init()
    self.delegate = appDelegate
  }

  required init?(coder: NSCoder) {
    fatalError("Unreachable path")
  }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  static var server = IMKServer()
  static var candidates = IMKCandidates()
  static let rime = Rime()

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.server = IMKServer(
      name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
      bundleIdentifier: Bundle.main.bundleIdentifier)
    AppDelegate.candidates = IMKCandidates(
      server: AppDelegate.server,
      panelType: kIMKSingleRowSteppingCandidatePanel)
    NSLog("Chinchilla started...")

    AppDelegate.rime.setup(Unmanaged.passUnretained(self).toOpaque())
    AppDelegate.rime.start(false)
  }

  func applicationWillTerminate(_ notification: Notification) {
    AppDelegate.rime.stop()
  }

  static func showNotification(_ message: String, identifier: String) {
    let notification = UNUserNotificationCenter.current()
    notification.requestAuthorization(options: [.alert, .provisional]) { (granted, error) in
      if !granted {
        NSLog("User notification authorization error: \(error?.localizedDescription ?? "Unknown")")
      }
    }

    notification.getNotificationSettings { settings in
    if (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) && settings.alertSetting == .enabled {
        let content = UNMutableNotificationContent()
        content.title = "Chinchilla"
        content.subtitle = message
        content.interruptionLevel = .active
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        notification.add(request) { error in
          NSLog("User notification request error: \(error?.localizedDescription ?? "Unknown")")
        }
      }
    }
  }
}
