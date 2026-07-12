import Foundation

public enum PlaceholderStyle: String, Codable, Equatable, Sendable {
    case blur
    case solid
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public let excludedWorkspaces: [String]
    public let placeholderStyle: PlaceholderStyle
    public let showsCursor: Bool

    public init(
        excludedWorkspaces: [String],
        placeholderStyle: PlaceholderStyle,
        showsCursor: Bool = false
    ) throws {
        guard !excludedWorkspaces.isEmpty else {
            throw ConfigurationError.emptyExcludedWorkspaces
        }
        self.excludedWorkspaces = excludedWorkspaces
        self.placeholderStyle = placeholderStyle
        self.showsCursor = showsCursor
    }

    public static func decode(_ data: Data) throws -> AppConfiguration {
        let decoded = try JSONDecoder().decode(ConfigurationPayload.self, from: data)
        return try AppConfiguration(
            excludedWorkspaces: decoded.excludedWorkspaces,
            placeholderStyle: decoded.placeholderStyle,
            showsCursor: decoded.showsCursor ?? false
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
}

public enum ConfigurationError: LocalizedError {
    case emptyExcludedWorkspaces

    public var errorDescription: String? {
        switch self {
        case .emptyExcludedWorkspaces:
            "excludedWorkspaces must contain at least one workspace"
        }
    }
}
