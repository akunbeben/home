import Foundation

public enum PlaceholderStyle: String, Codable, Equatable, Sendable {
    case blur
    case solid
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public let excludedWorkspaces: [String]
    public let placeholderStyle: PlaceholderStyle

    public init(excludedWorkspaces: [String], placeholderStyle: PlaceholderStyle) throws {
        guard !excludedWorkspaces.isEmpty else {
            throw ConfigurationError.emptyExcludedWorkspaces
        }
        self.excludedWorkspaces = excludedWorkspaces
        self.placeholderStyle = placeholderStyle
    }

    public static func decode(_ data: Data) throws -> AppConfiguration {
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: data)
        return try AppConfiguration(
            excludedWorkspaces: decoded.excludedWorkspaces,
            placeholderStyle: decoded.placeholderStyle
        )
    }

    public static func load(from url: URL) throws -> AppConfiguration {
        try decode(Data(contentsOf: url))
    }
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
