import InputMethodKit

class ChinchillaInputController: IMKInputController {
  private var sessionId: UInt = 0
  private var lastModifiers: NSEvent.ModifierFlags = .init()

  override func recognizedEvents(_ sender: Any!) -> Int {
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    NSLog("processKey: type=\(event.type), keyCode=\(event.keyCode), modifiers=\(event.modifierFlags)")
    if (sessionId == 0 || !AppDelegate.rime.isSessionValid(sessionId)) {
      // 如果当前 sessionId 不可用则新创建一个
      sessionId = AppDelegate.rime.createSession()
      if sessionId == 0 {
        return false
      }
    }

    let keyCode = event.keyCode
    let modifiers = event.modifierFlags
    var handled = false

    switch event.type {
      case .keyDown:
        if modifiers.contains(.command) {
          break
        }

        var keyChars = event.characters
        if !(keyChars?.first?.isLetter ?? false) {
          keyChars = event.charactersIgnoringModifiers
        }

        if let unicode = keyChars?.first?.unicodeScalars.first?.value {
          handled = processKey(keyCode: keyCode, modifiers: modifiers, unicode: unicode, release: false)
        }
      case .flagsChanged:
        if lastModifiers == modifiers {
          handled = true
          break
        }

        let change = lastModifiers.symmetricDifference(modifiers)
        if change.contains(.shift) || change.contains(.control) || change.contains(.command) || change.contains(.option) || change.contains(.capsLock) {
          let isRelease = (modifiers.rawValue & change.rawValue) == 0
          _ = processKey(keyCode: keyCode, modifiers: modifiers, unicode: 0, release: isRelease)
        }

        lastModifiers = modifiers
      default:
        break
    }

    return handled
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

  private func processKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, unicode: UInt32,  release: Bool) -> Bool {
    let rimeKeyCode = RimeKeyboardEvent.toRimeKeyCode(keyCode: keyCode, unicode: unicode)
    let rimeMask = RimeKeyboardEvent.toRimeMask(flags: modifiers, release: release)
    var handled = false

    if rimeKeyCode != 0xffffff {
      handled = AppDelegate.rime.processKey(sessionId: sessionId, keyCode: rimeKeyCode, mask: rimeMask)
    }

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
