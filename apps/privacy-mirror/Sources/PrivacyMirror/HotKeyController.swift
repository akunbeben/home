import Carbon
import Foundation
import PrivacyMirrorCore

final class HotKeyController {
    enum Action: UInt32 {
        case reloadConfiguration = 1
        case showOutput = 2
        case parkOutput = 3
    }

    private var hotKeys: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var actions: [Action: @MainActor () -> Void] = [:]

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let controller = Unmanaged<HotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return controller.handle(event: event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(shortcuts: AppConfiguration.Shortcuts, actions: [Action: @MainActor () -> Void]) throws {
        unregisterAll()
        self.actions = actions

        try register(shortcuts.reloadConfiguration, for: .reloadConfiguration)
        try register(shortcuts.showOutput, for: .showOutput)
        try register(shortcuts.parkOutput, for: .parkOutput)
    }

    private func register(_ shortcut: String, for action: Action) throws {
        let hotKey = try KeyboardShortcut.parse(shortcut)
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: fourCharacterCode("PMIR"),
            id: action.rawValue
        )

        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            throw HotKeyError.registrationFailed(shortcut)
        }
        hotKeys.append(hotKeyRef)
    }

    private func unregisterAll() {
        for hotKey in hotKeys {
            if let hotKey {
                UnregisterEventHotKey(hotKey)
            }
        }
        hotKeys.removeAll()
    }

    private func handle(event: EventRef?) -> OSStatus {
        guard let event else { return noErr }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr,
              let action = Action(rawValue: hotKeyID.id),
              let handler = actions[action]
        else { return noErr }

        Task { @MainActor in handler() }
        return noErr
    }
}

private struct KeyboardShortcut {
    let keyCode: UInt32
    let modifiers: UInt32

    static func parse(_ value: String) throws -> KeyboardShortcut {
        let parts = value
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard let key = parts.last,
              let keyCode = keyCodes[key],
              parts.count >= 2
        else {
            throw HotKeyError.invalidShortcut(value)
        }

        var modifiers: UInt32 = 0
        for part in parts.dropLast() {
            guard let modifier = modifierFlags[part] else {
                throw HotKeyError.invalidShortcut(value)
            }
            modifiers |= modifier
        }
        guard modifiers != 0 else {
            throw HotKeyError.invalidShortcut(value)
        }

        return KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    private static let modifierFlags: [String: UInt32] = [
        "cmd": UInt32(cmdKey),
        "command": UInt32(cmdKey),
        "control": UInt32(controlKey),
        "ctrl": UInt32(controlKey),
        "option": UInt32(optionKey),
        "alt": UInt32(optionKey),
        "shift": UInt32(shiftKey),
    ]

    private static let keyCodes: [String: UInt32] = [
        "a": UInt32(kVK_ANSI_A),
        "b": UInt32(kVK_ANSI_B),
        "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D),
        "e": UInt32(kVK_ANSI_E),
        "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G),
        "h": UInt32(kVK_ANSI_H),
        "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J),
        "k": UInt32(kVK_ANSI_K),
        "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M),
        "n": UInt32(kVK_ANSI_N),
        "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P),
        "q": UInt32(kVK_ANSI_Q),
        "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S),
        "t": UInt32(kVK_ANSI_T),
        "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V),
        "w": UInt32(kVK_ANSI_W),
        "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y),
        "z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0),
        "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4),
        "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6),
        "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9),
    ]
}

private enum HotKeyError: LocalizedError {
    case invalidShortcut(String)
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidShortcut(let shortcut):
            "Invalid keyboard shortcut: \(shortcut)"
        case .registrationFailed(let shortcut):
            "Could not register keyboard shortcut: \(shortcut)"
        }
    }
}

private func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
