import SwiftUI

extension Color {
    /// The club's 8 colour names (types, categories) as iOS system colours, which adapt to dark mode.
    init(hue: String) {
        switch hue {
        case "gray": self = .gray
        case "brown": self = .brown
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "green": self = .green
        case "purple": self = .purple
        case "red": self = .red
        default: self = .blue
        }
    }
}
