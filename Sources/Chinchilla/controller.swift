import InputMethodKit

class ChinchillaInputController: IMKInputController {
  private var sessionId: UInt = 0
  private var lastModifiers: NSEvent.ModifierFlags = .init()

  override func recognizedEvents(_ sender: Any!) -> Int {
    let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
    return Int(events.rawValue)
  }

  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
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

        let keyChars = event.characters
        let unicode = keyChars?.first?.unicodeScalars.first?.value ?? 0
        handled = processKey(keyCode: keyCode, modifiers: modifiers, unicode: unicode, release: false)

        if !handled {
          // 自动切换到 ascii 模式
          let escape = keyCode == kVK_Escape || (modifiers.contains(.control) && keyCode == kVK_ANSI_LeftBracket)
          if escape && !AppDelegate.rime.getOption(sessionId, "ascii_mode") {
            AppDelegate.rime.setOption(sessionId, "ascii_mode", true)
          }
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

    let schemasItem = NSMenuItem(title: "方案", action: nil, keyEquivalent: "")
    let schemaMenu = NSMenu()
    let schemaList = AppDelegate.rime.schemaList().sorted { $0.key < $1.key };
    let currentSchema = AppDelegate.rime.currentSchema(sessionId) ?? ""
    for schema in schemaList {
      let item = NSMenuItem(title: schema.value, action: #selector(handleMenuClick), keyEquivalent: "")
      item.representedObject = [
        "action": "selectSchema",
        "schema": schema.key,
      ]
      if currentSchema == schema.key {
        item.state = .on
      }
      schemaMenu.addItem(item)

      NSLog("SelectSchema schema2=\(schema.key) \(schema.value)")
    }
    menu.addItem(schemasItem)
    menu.setSubmenu(schemaMenu, for: schemasItem)

    menu.addItem(NSMenuItem.separator())

    menu.addItem(withTitle: "重新部署", action: #selector(redeploy(_:)), keyEquivalent: "")
    menu.addItem(withTitle: "重新启动", action: #selector(restart(_:)), keyEquivalent: "")

    // 检查更新
    let checkForUpdateItem = NSMenuItem(title: "检查更新", action: #selector(handleMenuClick), keyEquivalent: "")
    checkForUpdateItem.representedObject = ["action": "checkForUpdate"]
    menu.addItem(checkForUpdateItem)

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

    // NSLog("processKey: keyCode: \(keyCode), modifiers: \(modifiers), unicode: \(unicode), rimeKeyCode: \(rimeKeyCode), rimeMask: \(rimeMask)")
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

  @objc private func redeploy(_: Any? = nil) {
    NSLog("Redeploy rime...")
    AppDelegate.rime.stop()
    AppDelegate.rime.start(true)
  }

  @objc private func restart(_: Any? = nil) {
    NSApp.terminate(nil)
  }

  @objc private func about(_: Any? = nil) {
    NSLog("About Chinchilla")
  }

  @objc private func handleMenuClick(sender: Any?) {
    if let sender = sender as? NSMutableDictionary {
      if let menuItem = sender[kIMKCommandMenuItemName] as? NSMenuItem {
        if let item = menuItem.representedObject as? Dictionary<String, String> {
          let action = item["action"] ?? ""
          switch(action) {
            case "checkForUpdate":
              NSLog("Check for update...")
            case "selectSchema":
              if let schema = item["schema"] {
                AppDelegate.rime.selectSchema(sessionId, schema: schema)
              }
            default:
              NSLog("Unknown action: \(action)")
          }
        }
      }
    }
  }
}
