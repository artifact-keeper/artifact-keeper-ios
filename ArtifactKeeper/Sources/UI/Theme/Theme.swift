import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let primary = Color.blue
    static let secondary = Color.indigo
    #if os(iOS)
    static let background = Color(.systemBackground)
    static let surface = Color(.secondarySystemBackground)
    #else
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    #endif
    static let error = Color.red
    static let warning = Color.orange
    static let success = Color.green

    // MARK: - Severity Colors
    static let critical = Color.red
    static let high = Color.orange
    static let medium = Color.yellow
    static let low = Color.blue
    static let info = Color.gray

    // MARK: - Spacing
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
}
