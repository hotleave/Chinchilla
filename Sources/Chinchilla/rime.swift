import Cocoa
import CRime

private func nofificationHandler(contextObject: UnsafeMutableRawPointer?, sessionId: RimeSessionId, messageType: UnsafePointer<CChar>?, messageValue: UnsafePointer<CChar>?) {
  // let delegate: AppDelegate = Unmanaged<AppDelegate>.fromOpaque(contextObject!).takeUnretainedValue()
  let messageType = messageType.map { String(cString: $0 )}
  let messageValue = messageValue.map { String(cString: $0 )}

  if messageType == "deploy" {
    switch messageValue {
      case "start":
        AppDelegate.showNotification("Start to deploy...", identifier: messageType!)
      case "success":
        AppDelegate.showNotification("Deploy success", identifier: messageType!)
      case "failure":
        AppDelegate.showNotification("Deploy fail, check log file for detail infomation", identifier: messageType!)
      default:
        break
    }
  }

  if messageType == "option" {
    var optionName = messageValue ?? ""
    if optionName.count == 0 {
      return
    }

    let state = optionName.first != "!"
    if !state {
      optionName = String(optionName.dropFirst())
    }

    let label = AppDelegate.rime.getStateLabel(sessionId: sessionId, name: optionName, state: state ? True : False, abbreviated: False)
    let abbr = AppDelegate.rime.getStateLabel(sessionId: sessionId, name: optionName, state: state ? True : False, abbreviated: False)
    NSLog("Option change: \(label ?? "") - \(abbr ?? "")")
  }
}

class RimeKeyboardEvent {
  static let kShiftMask: Int32 = 1 << 0
  static let kLockMask: Int32 = 1 << 1
  static let kControlMask: Int32 = 1 << 2
  static let kMod1Mask: Int32 = 1 << 3
  static let kAltMask: Int32 = kMod1Mask
  static let kMod2Mask: Int32 = 1 << 4
  static let kMod3Mask: Int32 = 1 << 5
  static let kMod4Mask: Int32 = 1 << 6
  static let kMod5Mask: Int32 = 1 << 7
  static let kButton1Mask: Int32 = 1 << 8
  static let kButton2Mask: Int32 = 1 << 9
  static let kButton3Mask: Int32 = 1 << 10
  static let kButton4Mask: Int32 = 1 << 11
  static let kButton5Mask: Int32 = 1 << 12
  static let kHandledMask: Int32 = 1 << 24
  static let kForwardMask: Int32 = 1 << 25
  static let kIgnoredMask: Int32 = kForwardMask
  static let kSuperMask: Int32 = 1 << 26
  static let kHyperMask: Int32 = 1 << 27
  static let kMetaMask: Int32 = 1 << 28
  static let kReleaseMask: Int32 = 1 << 30
  static let kModifierMask: Int32 = 0x5f001fff

  private static let key_map = [
    // Delete -> Backspace
    0x33: 0xff08,
    // Delete -> Delete
    0x75: 0xffff,
    // Tab
    0x30: 0xff09,
    // Return
    0x24: 0xff0d,
    // Enter
    0x4c: 0xff8d,
    // Escape
    0x35: 0xff1b,
    // Space
    0x31: 0x0020,

    // CapsLock
    0x39: 0xffe5,
    // Command_L
    0x37: 0xffeb,
    // Command_R
    0x36: 0xffec,
    // Ctrl_L
    0x3b: 0xffe3,
    // Ctrl_R
    0x3e: 0xffe4,
    // Fn
    0x3f: 0xffed,
    // Option_L
    0x3a: 0xffe9,
    // Option_R
    0x3d: 0xffea,
    // Shift_L
    0x38: 0xffe1,
    // Shift_R
    0x3c: 0xffe2,

    // Up
    0x7e: 0xff52,
    // Down
    0x7d: 0xff54,
    // Left
    0x7b: 0xff51,
    // Right
    0x7c: 0xff53,
    // PageUp
    0x74: 0xff55,
    // PageDown
    0x79: 0xff56,
    // Home
    0x73: 0xff50,
    // End
    0x77: 0xff57,
  ]

  static func toRimeMask(flags: NSEvent.ModifierFlags, release: Swift.Bool) -> Int32 {
    var mask: Int32 = 0
    
    if flags.contains(.capsLock) {
      mask |= kLockMask
    }
    if flags.contains(.shift) {
      mask |= kShiftMask
    }
    if flags.contains(.control) {
      mask |= kControlMask
    }
    if flags.contains(.option) {
      mask |= kAltMask
    }
    if flags.contains(.command) {
      mask |= kSuperMask
    }

    if release {
      mask |= kReleaseMask
    }

    return mask
  }

  static func toRimeKeyCode(keyCode: UInt16, char: CChar) -> Int32 {
    if let mapped = key_map[Int(keyCode)] {
      return Int32(mapped)
    }

    if (char >= 0x20 && char <= 0x7e) {
      return Int32(char)
    }

    switch keyCode {
      case 0x1b:
        // ^[
        return 0x5b
      case 0x1c:
        // ^\
        return 0x5c
      case 0x1d:
        // ^]
        return 0x5d
      case 0x1f:
        // ^_
        return 0x2d
      default:
        return 0xffffff
    }
  }
}

class Rime {
  var api: RimeApi

  init() {
    self.api = rime_get_api().pointee
  }

  func setup(_ contextObject: UnsafeMutableRawPointer) {
    NSLog("Setup rime...")
    let name = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Chinchilla"
    let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0.0.1"

    let fileManager = FileManager.default
    let appSupport = try! fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Chinchilla")
    let userDataDir = appSupport.appendingPathComponent("Rime")
    let logDir = appSupport.appendingPathComponent("logs")
    try! fileManager.createDirectory(at: userDataDir, withIntermediateDirectories: true, attributes: nil)
    try! fileManager.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
    let sharedDataDir = Bundle.main.sharedSupportPath!

    NSLog("RIME_INIT shared=\(sharedDataDir), user = \(userDataDir.path(percentEncoded: false)), log = \(logDir.path(percentEncoded: false))")

    var traits = newRimeTraits(
      name: name,
      version: version,
      appName: "rime.chinchilla",
      sharedDataDir: sharedDataDir,
      userDataDir: userDataDir,
      logDir: logDir
    )

    api.set_notification_handler(nofificationHandler, contextObject)
    api.setup(&traits)
  }

  func start(_ fullCheck: Swift.Bool) {
    NSLog("Initializing rime...")
    api.initialize(nil)

    if api.start_maintenance(fullCheck ? True : False) == True {
      api.join_maintenance_thread()
    }
  }

  func stop() {
    NSLog("Stopping rime...")
    api.cleanup_all_sessions()
    api.finalize()
  }

  func createSession() -> RimeSessionId {
    return api.create_session()
  }

  func isSessionValid(_ sessionId: RimeSessionId) -> Swift.Bool {
    return api.find_session(sessionId) == True
  }

  func withContext<T>(sessionId: RimeSessionId, consumer: (_: RimeContext) -> T) -> T? {
    var context: RimeContext = newRimeStructs { size in
      var result = RimeContext()
      result.data_size = size
      return result
    }

    var result: T? = nil
    if api.get_context(sessionId, &context) == True {
      result =  consumer(context)
    }

    if api.free_context(&context) == False {
      NSLog("Failed to free context")
    }

    return result
  }

  func withCommittedText(sessionId: RimeSessionId, consumer: (_: String) -> Void) {
    var commit: RimeCommit = newRimeStructs { size in
      var result = RimeCommit()
      result.data_size = size
      return result
    }

    if api.get_commit(sessionId, &commit) == True {
      if let text = commit.text {
        consumer(String(cString: text))
      }
    }

    if api.free_commit(&commit) == False {
      NSLog("Failed to free commit")
    }
  }
  
  func processKey(sessionId: RimeSessionId, keyCode: Int32, mask: Int32) -> Swift.Bool {
    return api.process_key(sessionId, keyCode, mask) == True
  }

  func getStateLabel(sessionId: RimeSessionId, name: String, state: Bool, abbreviated: Bool) -> String? {
    let result = api.get_state_label_abbreviated(sessionId, toCString(name), state, abbreviated)
    return result.str.map({ String(cString: $0) })
  }

  private func newRimeStructs<T>(initializer: (_: Int32) -> T) -> T {
    let dataSize = Int32(MemoryLayout<T>.size - MemoryLayout<Int32>.size)
    return initializer(dataSize)
  }

  private func toCString(_ input: String) -> UnsafePointer<CChar>? {
    return (input as NSString).utf8String
  }

  private func newRimeTraits(
    name: String,
    version: String,
    appName: String,
    sharedDataDir: String,
    userDataDir: URL,
    logDir: URL? 
  ) -> RimeTraits {
    return newRimeStructs { size in
      var result = RimeTraits()
      result.data_size = size
      result.app_name = toCString(appName)
      result.distribution_code_name = toCString(name)
      result.distribution_name = toCString(name)
      result.distribution_version = toCString(version)
      result.shared_data_dir = toCString(sharedDataDir)
      result.user_data_dir = toCString(userDataDir.path(percentEncoded: false))
      if let logPath = logDir {
        result.log_dir = toCString(logPath.path(percentEncoded: false))
      }

      return result
    }
  }
}
