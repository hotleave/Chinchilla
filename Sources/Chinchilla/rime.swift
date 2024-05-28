import Cocoa
import Carbon
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

  private static let key_map: Dictionary<Int, Int32> = [
    // modifiers
    kVK_CapsLock: 0xffe5,
    kVK_Command: 0xffeb,
    kVK_Control: 0xffe3,
    kVK_Function: 0xffed,
    kVK_Option: 0xffe9,
    kVK_RightCommand: 0xffec,
    kVK_RightControl: 0xffe4,
    kVK_RightOption: 0xffea,
    kVK_RightShift: 0xffe2,
    kVK_Shift: 0xffe1,

    // special
    kVK_Delete: 0xff08,
    kVK_Escape: 0xff1b,
    kVK_ForwardDelete: 0xffff,
    kVK_Help: 0xff6a,
    kVK_Return: 0xff0d,
    kVK_Space: 0x0020,
    kVK_Tab: 0xff09,

    // cursor
    kVK_UpArrow: 0xff52,
    kVK_DownArrow: 0xff54,
    kVK_LeftArrow: 0xff51,
    kVK_RightArrow: 0xff53,
    kVK_PageUp: 0xff55,
    kVK_PageDown: 0xff56,
    kVK_Home: 0xff50,
    kVK_End: 0xff57,

    // function
    kVK_F1: 0xffbe,
    kVK_F2: 0xffbf,
    kVK_F3: 0xffc0,
    kVK_F4: 0xffc1,
    kVK_F5: 0xffc2,
    kVK_F6: 0xffc3,
    kVK_F7: 0xffc4,
    kVK_F8: 0xffc5,
    kVK_F9: 0xffc6,
    kVK_F10: 0xffc7,
    kVK_F11: 0xffc8,
    kVK_F12: 0xffc9,

    // keypad
    kVK_ANSI_Keypad0: 0xffb0,
    kVK_ANSI_Keypad1: 0xffb1,
    kVK_ANSI_Keypad2: 0xffb2,
    kVK_ANSI_Keypad3: 0xffb3,
    kVK_ANSI_Keypad4: 0xffb4,
    kVK_ANSI_Keypad5: 0xffb5,
    kVK_ANSI_Keypad6: 0xffb6,
    kVK_ANSI_Keypad7: 0xffb7,
    kVK_ANSI_Keypad8: 0xffb8,
    kVK_ANSI_Keypad9: 0xffb9,
    kVK_ANSI_KeypadClear: 0xff0b,
    kVK_ANSI_KeypadDecimal: 0xffae,
    kVK_ANSI_KeypadEquals: 0xffbd,
    kVK_ANSI_KeypadMinus: 0xffad,
    kVK_ANSI_KeypadMultiply: 0xffaa,
    kVK_ANSI_KeypadPlus: 0xffab,
    kVK_ANSI_KeypadDivide: 0xffaf,
    kVK_ANSI_KeypadEnter: 0xff8d,
    
    // other
    kVK_ISO_Section: 0x00a7,
    kVK_JIS_Yen: 0x00a5,
    kVK_JIS_Underscore: 0x005f,
    kVK_JIS_KeypadComma: 0x002c,
    kVK_JIS_Eisu: 0xff2f,
    kVK_JIS_Kana: 0xff2e,
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

  static func toRimeKeyCode(keyCode: UInt16, unicode: UInt32) -> Int32 {
    if let mapped = key_map[Int(keyCode)] {
      return mapped
    }

    switch unicode {
      case 0x20...0x7e:
        return Int32(unicode)
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

  func getOption(_ sessionId: RimeSessionId, _ optionName: UnsafePointer<CChar>) -> Swift.Bool {
    let result = api.get_option(sessionId, optionName)
    return result == True
  }

  func setOption(_ sessionId: RimeSessionId, _ optionName: UnsafePointer<CChar>, _ optionValue: Swift.Bool) {
    api.set_option(sessionId, optionName, optionValue ? True : False)
  }

  func schemaList() -> Dictionary<String, String> {
    var list = RimeSchemaList()
    var result = Dictionary<String, String>()
    if api.get_schema_list(&list) == True {
      for i in 0..<list.size {
        let schema = list.list[i]
        let name = String(cString: schema.name)
        let id = String(cString: schema.schema_id)

        result[id] = name
      }
    }
    return result
  }

  func currentSchema(_ sessionId: RimeSessionId) -> String? {
    let current = UnsafeMutablePointer<CChar>.allocate(capacity: 100)
    if api.get_current_schema(sessionId, current, 100) == True {
      return String(cString: current)
    } else {
      return nil
    }
  }

  func selectSchema(_ sessionId: RimeSessionId, schema: String) {
    if api.select_schema(sessionId, schema) == True {
      NSLog("Schame successfully change to \(schema)")
    }
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
