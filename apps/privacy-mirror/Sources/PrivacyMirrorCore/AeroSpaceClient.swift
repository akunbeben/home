import Foundation

public struct AeroSpaceClient: Sendable {
    private let executableURL: URL

    public init(executableURL: URL? = nil) throws {
        self.executableURL = try executableURL ?? Self.findExecutable()
    }

    public func windowIDs(in workspaces: [String]) throws -> Set<UInt32> {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()

        process.executableURL = executableURL
        process.arguments = ["list-windows", "--workspace"]
            + workspaces
            + ["--format", "%{window-id}", "--json"]
        process.standardOutput = output
        process.standardError = errors

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(
                data: errors.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "unknown AeroSpace error"
            throw AeroSpaceError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return try Self.decodeWindowIDs(outputData)
    }

    public static func decodeWindowIDs(_ data: Data) throws -> Set<UInt32> {
        Set(try JSONDecoder().decode([WindowRecord].self, from: data).map(\.windowID))
    }

    public func makeSubscription() -> AeroSpaceSubscription {
        AeroSpaceSubscription(executableURL: executableURL)
    }

    private static func findExecutable() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/aerospace",
            "/usr/local/bin/aerospace",
        ]
        if let path = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) {
            return URL(fileURLWithPath: path)
        }
        throw AeroSpaceError.executableNotFound
    }
}

public enum AeroSpaceEvent: Equatable, Sendable {
    case stateChanged
    case windowMoveBinding
}

public final class AeroSpaceSubscription: @unchecked Sendable {
    private let executableURL: URL
    private let process = Process()
    private let output = Pipe()
    private let lock = NSLock()
    private var bufferedData = Data()
    private var stopping = false

    fileprivate init(executableURL: URL) {
        self.executableURL = executableURL
    }

    public func start(
        onEvent: @escaping @Sendable (AeroSpaceEvent) -> Void,
        onFailure: @escaping @Sendable () -> Void
    ) throws {
        process.executableURL = executableURL
        process.arguments = [
            "subscribe",
            "--no-send-initial",
            "focused-workspace-changed",
            "window-detected",
            "binding-triggered",
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            for event in self.consume(data) {
                onEvent(event)
            }
        }
        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            let shouldReport = !self.stopping
            self.lock.unlock()
            if shouldReport { onFailure() }
        }

        try process.run()
    }

    public func stop() {
        lock.lock()
        stopping = true
        lock.unlock()
        output.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
        if process.isRunning { process.terminate() }
    }

    public static func decodeEvent(_ data: Data) -> AeroSpaceEvent? {
        guard let event = try? JSONDecoder().decode(EventRecord.self, from: data) else { return nil }
        switch event.event {
        case "focused-workspace-changed", "window-detected":
            return .stateChanged
        case "binding-triggered":
            guard let binding = event.binding else { return nil }
            let parts = binding.split(separator: "-")
            return parts.count == 3
                && parts[0] == "alt"
                && parts[1] == "shift"
                && Int(parts[2]) != nil
                ? .windowMoveBinding
                : nil
        default:
            return nil
        }
    }

    private func consume(_ data: Data) -> [AeroSpaceEvent] {
        lock.lock()
        defer { lock.unlock() }
        bufferedData.append(data)

        var events: [AeroSpaceEvent] = []
        while let newline = bufferedData.firstIndex(of: 0x0A) {
            let line = bufferedData[..<newline]
            bufferedData.removeSubrange(...newline)
            if let event = Self.decodeEvent(Data(line)) {
                events.append(event)
            }
        }
        return events
    }
}

private struct EventRecord: Decodable {
    let event: String
    let binding: String?

    enum CodingKeys: String, CodingKey {
        case event = "_event"
        case binding
    }
}

private struct WindowRecord: Decodable {
    let windowID: UInt32

    enum CodingKeys: String, CodingKey {
        case windowID = "window-id"
    }
}

public enum AeroSpaceError: LocalizedError {
    case executableNotFound
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "aerospace executable not found"
        case .commandFailed(let message):
            "aerospace command failed: \(message)"
        }
    }
}
