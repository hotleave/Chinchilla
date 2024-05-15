import InputMethodKit

class ChinchillaInputController: IMKInputController {
  var sessionId: UInt = 0
  var lastModifiers = NSEvent.ModifierFlags(rawValue: 0)

  override func recognizedEvents(_ sender: Any!) -> Int {
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    guard let event = event, let _ = sender as? IMKTextInput else {
      return false
    }

    if (sessionId == 0 || !AppDelegate.rime.isSessionValid(sessionId)) {
      // 如果当前 sessionId 不可用则新创建一个
      sessionId = AppDelegate.rime.createSession()
    }

    let keyCode = event.keyCode
    let modifiers = event.modifierFlags

    switch event.type {
      case .keyDown:
        var unicode: UInt32 = 0
        if let characters = event.characters {
          let scalars = characters.unicodeScalars
          unicode = scalars[scalars.startIndex].value
        }

        return processKey(unicode, modifiers, keyCode, false)
      case .flagsChanged:
        let change = NSEvent.ModifierFlags(rawValue: modifiers.rawValue ^ lastModifiers.rawValue)
        lastModifiers = modifiers

        if change.contains(.shift) || change.contains(.control) || change.contains(.command) || change.contains(.option) || change.contains(.capsLock) {
          let isRelease = (lastModifiers.rawValue & change.rawValue) == 0
          return processKey(0, modifiers, keyCode, isRelease)
        } else {
          return false
        }
      default:
        return false
    }
  }

  override func menu() -> NSMenu! {
    let menu = NSMenu()

    menu.addItem(withTitle: "重新部署", action: #selector(redeploy), keyEquivalent: "")
    menu.addItem(withTitle: "重新启动", action: #selector(restart), keyEquivalent: "")
    menu.addItem(withTitle: "检查更新", action: #selector(checkForUpdate), keyEquivalent: "")
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "关于", action: #selector(about), keyEquivalent: "")

    return menu
  }

  override func candidates(_ sender: Any!) -> [Any]! {
    let candidates = AppDelegate.rime.withContext(sessionId: sessionId) { context in 
      let menu = context.menu
      var result: [Any] = []

      for  i in 0..<menu.num_candidates {
        let candidate = menu.candidates[Int(i)]
        var text = String(cString: candidate.text)
        if let comment = candidate.comment {
          text.append("[")
          text.append(String(cString: comment))
          text.append("]")
        }
        result.append(text)
      }

      return result
    }

    return candidates
  }

  private func processKey(_ unicode: UInt32, _ modifiers: NSEvent.ModifierFlags, _ code: UInt16, _ release: Bool) -> Bool {
    let keyCode = RimeKeyboardEvent.toRimeKeyCode(keyCode: code, char: CChar(unicode))
    let mask = RimeKeyboardEvent.toRimeMask(flags: modifiers, release: release)
    let handled = AppDelegate.rime.processKey(sessionId: sessionId, keyCode: keyCode, mask: mask)

    if unicode == 0 || handled {
      rimeUpdate()
    }

    return handled
  }

  private func rimeUpdate() {
    // 提交已转换的文字
    AppDelegate.rime.withCommittedText(sessionId: sessionId) {text in
      client().insertText(text, replacementRange: NSMakeRange(NSNotFound, NSNotFound))
    }

    // 显示待转换的编码
    AppDelegate.rime.withContext(sessionId: sessionId) { context in
      let composition = context.composition
      if let preedit = composition.preedit {
        let content = String(cString: preedit)

        var unicodeIndice = Dictionary<Int, Int>()
        var pos = 0
        for (index, ch) in content.enumerated() {
          unicodeIndice[index] = pos
          pos += ch.utf8.count
        }
        let cursor = unicodeIndice[Int(composition.cursor_pos)] ?? content.count - 1
        // let start = unicodeIndice[Int(composition.sel_start)] ?? 0
        // let end = unicodeIndice[Int(composition.sel_end)] ?? 0

        client().setMarkedText(content, selectionRange: NSMakeRange(cursor, 0), replacementRange: NSMakeRange(NSNotFound, 0))
      } else {
        client().setMarkedText("", selectionRange: NSMakeRange(NSNotFound, 0), replacementRange: NSMakeRange(NSNotFound, 0))
      }

      if (context.menu.num_candidates > 0) {
        AppDelegate.candidates.update()
        AppDelegate.candidates.show()
      } else {
        AppDelegate.candidates.hide()
      }
    }
  }

  @objc private func redeploy() {
    NSLog("Redeploy rime...")
    AppDelegate.rime.stop()
    AppDelegate.rime.start(true)
  }

  @objc private func restart() {
    NSApp.terminate(nil)
  }

  @objc private func about() {
    NSLog("About Chinchilla")
  }

  @objc private func checkForUpdate() {
    NSLog("Check for update...")
  }
}
