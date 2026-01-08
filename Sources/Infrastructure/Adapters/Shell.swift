import Foundation

/// Represents different shell types with their specific command syntax.
///
/// The user's login shell determines how commands like `which` and environment
/// variable access work. This enum encapsulates shell-specific behavior so
/// `BinaryLocator` can work correctly across different shells.
///
/// ## Adding a New Shell
///
/// 1. Add a new case to the enum
/// 2. Update `detect(from:)` to recognize the shell name
/// 3. Implement `whichArguments(for:)` with the correct syntax
/// 4. Implement `pathArguments()` with the correct syntax
/// 5. Update `parseWhichOutput(_:)` if the shell has non-standard output
///
/// ## Supported Shells
///
/// - **POSIX**: bash, zsh, sh, dash, and other POSIX-compatible shells
/// - **Fish**: The fish shell (has some syntax differences but `which` works)
/// - **Nushell**: Modern shell with structured data; `which` outputs tables
///
enum Shell: Sendable, Equatable {
    /// POSIX-compatible shells: bash, zsh, sh, dash, etc.
    case posix
    /// Fish shell - mostly POSIX-like for our purposes
    case fish
    /// Nushell - structured data shell with different syntax
    case nushell

    // MARK: - Detection

    /// Detects the shell type from a shell executable path.
    ///
    /// - Parameter shellPath: Full path to the shell (e.g., "/bin/zsh", "/opt/homebrew/bin/nu")
    /// - Returns: The detected shell type, defaults to `.posix` for unknown shells
    static func detect(from shellPath: String) -> Shell {
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()

        switch shellName {
        case "nu", "nushell":
            return .nushell
        case "fish":
            return .fish
        default:
            // bash, zsh, sh, dash, ksh, etc. are all POSIX-compatible
            return .posix
        }
    }

    /// Returns the current user's shell type based on the `SHELL` environment variable.
    static var current: Shell {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        return detect(from: shellPath)
    }

    // MARK: - Command Generation

    /// Returns the arguments to run a `which` command for finding a tool's path.
    ///
    /// - Parameter tool: The name of the CLI tool to find (e.g., "claude", "codex")
    /// - Returns: Arguments to pass to the shell executable
    func whichArguments(for tool: String) -> [String] {
        switch self {
        case .posix, .fish:
            // Standard: which outputs plain path
            return ["-l", "-c", "which \(tool)"]
        case .nushell:
            // Use ^which to call the external which binary, avoiding Nushell's built-in
            // which returns a table and doesn't find external paths for shadowed commands
            return ["-l", "-c", "^which \(tool)"]
        }
    }

    /// Returns the arguments to get the PATH environment variable.
    ///
    /// - Returns: Arguments to pass to the shell executable
    func pathArguments() -> [String] {
        switch self {
        case .posix, .fish:
            // Standard: $PATH is colon-separated string
            return ["-l", "-c", "echo $PATH"]
        case .nushell:
            // Nushell: $env.PATH is a list, join with colons for compatibility
            return ["-l", "-c", "$env.PATH | str join ':'"]
        }
    }

    // MARK: - Output Parsing

    /// Parses the output of the `which` command to extract the binary path.
    ///
    /// - Parameter output: Raw output from the shell command
    /// - Returns: The clean path to the binary, or `nil` if not found/parseable
    func parseWhichOutput(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch self {
        case .posix, .fish:
            // Simple path output, possibly with trailing newline
            return trimmed

        case .nushell:
            // With `get path.0`, output should be clean path
            // But if table output leaked through (edge case), reject it
            if trimmed.contains("│") || trimmed.contains("╭") || trimmed.contains("╰") {
                return nil
            }
            return trimmed
        }
    }

    /// Parses the output of the PATH command.
    ///
    /// - Parameter output: Raw output from the shell command
    /// - Returns: The PATH string (colon-separated)
    func parsePathOutput(_ output: String) -> String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
