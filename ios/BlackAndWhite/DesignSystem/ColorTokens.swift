import SwiftUI

enum BWColor {
    static let black = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
    static let white = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
    static let gray = Color(
        .sRGB,
        red: 107.0 / 255.0,
        green: 107.0 / 255.0,
        blue: 107.0 / 255.0,
        opacity: 1
    )

    static func background(for verdict: Verdict) -> Color {
        switch verdict {
        case .white: white
        case .black: black
        case .gray: gray
        }
    }

    static func foreground(for verdict: Verdict) -> Color {
        verdict == .white ? black : white
    }
}
