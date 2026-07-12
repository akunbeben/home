import Foundation

public enum PlaceholderStyle: String, Codable, Equatable, Sendable {
    case blur
    case solid
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public struct Shortcuts: Codable, Equatable, Sendable {
        public let reloadConfiguration: String
        public let showOutput: String
        public let parkOutput: String

        public init(
            reloadConfiguration: String = "option+shift+r",
            showOutput: String = "option+shift+s",
            parkOutput: String = "option+shift+p"
        ) {
            self.reloadConfiguration = reloadConfiguration
            self.showOutput = showOutput
            self.parkOutput = parkOutput
        }
    }

    public let excludedWorkspaces: [String]
    public let placeholderStyle: PlaceholderStyle
    public let showsCursor: Bool
    public let captureFrameRate: Int
    public let captureMaxWidth: Int
    public let shortcuts: Shortcuts

    public init(
        excludedWorkspaces: [String],
        placeholderStyle: PlaceholderStyle,
        showsCursor: Bool = false,
        captureFrameRate: Int = 10,
        captureMaxWidth: Int = 1920,
        shortcuts: Shortcuts = Shortcuts()
    ) throws {
        guard !excludedWorkspaces.isEmpty else {
            throw ConfigurationError.emptyExcludedWorkspaces
        }
        guard (1...60).contains(captureFrameRate) else {
            throw ConfigurationError.invalidCaptureFrameRate
        }
        guard (640...8192).contains(captureMaxWidth) else {
            throw ConfigurationError.invalidCaptureMaxWidth
        }
        self.excludedWorkspaces = excludedWorkspaces
        self.placeholderStyle = placeholderStyle
        self.showsCursor = showsCursor
        self.captureFrameRate = captureFrameRate
        self.captureMaxWidth = captureMaxWidth
        self.shortcuts = shortcuts
    }

    public static func decode(_ data: Data) throws -> AppConfiguration {
        let decoded = try JSONDecoder().decode(ConfigurationPayload.self, from: data)
        return try AppConfiguration(
            excludedWorkspaces: decoded.excludedWorkspaces,
            placeholderStyle: decoded.placeholderStyle,
            showsCursor: decoded.showsCursor ?? false,
            captureFrameRate: decoded.captureFrameRate ?? 10,
            captureMaxWidth: decoded.captureMaxWidth ?? 1920,
            shortcuts: decoded.shortcuts ?? Shortcuts()
        )
    }

    public static func load(from url: URL) throws -> AppConfiguration {
        try decode(Data(contentsOf: url))
    }
}

private struct ConfigurationPayload: Decodable {
    let excludedWorkspaces: [String]
    let placeholderStyle: PlaceholderStyle
    let showsCursor: Bool?
    let captureFrameRate: Int?
    let captureMaxWidth: Int?
    let shortcuts: AppConfiguration.Shortcuts?
}

public enum ConfigurationError: LocalizedError {
    case emptyExcludedWorkspaces
    case invalidCaptureFrameRate
    case invalidCaptureMaxWidth

    public var errorDescription: String? {
        switch self {
        case .emptyExcludedWorkspaces:
            "excludedWorkspaces must contain at least one workspace"
        case .invalidCaptureFrameRate:
            "captureFrameRate must be between 1 and 60"
        case .invalidCaptureMaxWidth:
            "captureMaxWidth must be between 640 and 8192"
        }
    }
}
