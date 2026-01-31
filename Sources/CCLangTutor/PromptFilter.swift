import Foundation

struct PromptFilter {
    // MARK: - Patterns

    /// Standard URLs (http, https, ftp, file, ssh, git)
    static let urlPattern = #"(?:https?|ftp|file|ssh|git)://[^\s<>\"\'\]\)]+"#

    /// Bare www domains
    static let wwwPattern = #"\bwww\.[^\s<>\"\'\]\)]+"#

    /// Markdown links: [text](url)
    static let markdownLinkPattern = #"\[([^\]]+)\]\(((?:https?|ftp|file|ssh|git)://[^\)]+)\)"#

    /// Absolute Unix paths (/Users/..., /home/..., etc.)
    static let absolutePathPattern = #"(?<=^|[\s\(\[\"\'\`])(/(?:Users|home|var|tmp|etc|opt|usr|private|Applications|Library)[^\s\"\'\]\)]*)"#

    /// Relative paths (./path, ../path)
    static let relativePathPattern = #"(?<=^|[\s\(\[\"\'\`])(\.\.?/[^\s\"\'\]\)]+)"#

    // MARK: - Filtering

    static func filter(_ text: String) -> String {
        var result = text

        // Markdown links: [text](url) -> [text]([URL])
        result = result.replacingOccurrences(
            of: markdownLinkPattern,
            with: "[$1]([URL])",
            options: .regularExpression
        )

        // Standard URLs -> [URL]
        result = result.replacingOccurrences(
            of: urlPattern,
            with: "[URL]",
            options: .regularExpression
        )

        // www domains -> [URL]
        result = result.replacingOccurrences(
            of: wwwPattern,
            with: "[URL]",
            options: .regularExpression
        )

        // Absolute paths -> [path]
        result = result.replacingOccurrences(
            of: absolutePathPattern,
            with: "[path]",
            options: .regularExpression
        )

        // Relative paths -> [path]
        result = result.replacingOccurrences(
            of: relativePathPattern,
            with: "[path]",
            options: .regularExpression
        )

        return result
    }
}
