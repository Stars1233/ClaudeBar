import Foundation

/// Errors that can occur when probing a CLI
public enum ProbeError: Error, Equatable, LocalizedError, Sendable {
    /// The CLI binary was not found on the system
    case cliNotFound(String)

    /// The CLI requires authentication/login
    case authenticationRequired

    /// The CLI requires trusting the current folder
    case folderTrustRequired(String)

    /// The CLI command timed out
    case timeout

    /// Failed to parse the CLI output
    case parseFailed(String)

    /// Generic execution error
    case executionFailed(String)

    /// CLI update is required before usage can be checked
    case updateRequired(String)

    public var errorDescription: String? {
        switch self {
        case .cliNotFound(let cli):
            "CLI '\(cli)' not found. Please install it and ensure it's on your PATH."
        case .authenticationRequired:
            "Authentication required. Please run the CLI and log in."
        case .folderTrustRequired(let folder):
            "Please trust the folder '\(folder)' by running the CLI manually."
        case .timeout:
            "CLI command timed out. Please try again."
        case .parseFailed(let reason):
            "Failed to parse CLI output: \(reason)"
        case .executionFailed(let reason):
            "CLI execution failed: \(reason)"
        case .updateRequired(let reason):
            "CLI update required: \(reason)"
        }
    }
}
