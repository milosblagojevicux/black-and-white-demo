import SwiftUI

struct MonochromeActionButtonStyle<ActionShape: Shape>: ButtonStyle {
    let shape: ActionShape
    let fill: Color
    let foreground: Color
    var border: Color?
    var becomesOutlineWhenPressed = true
    var pressedFill: Color?
    var pressedForeground: Color?

    func makeBody(configuration: Configuration) -> some View {
        let showsOutline = becomesOutlineWhenPressed && configuration.isPressed
        let currentFill = configuration.isPressed
            ? (pressedFill ?? (showsOutline ? Color.clear : fill))
            : fill
        let currentForeground = configuration.isPressed
            ? (pressedForeground ?? (showsOutline ? fill : foreground))
            : foreground

        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(currentForeground)
            .background {
                shape
                    .fill(currentFill)
            }
            .overlay {
                shape
                    .stroke(border ?? fill, lineWidth: 2)
            }
            .contentShape(shape)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BWType.button)
        }
        .frame(height: BWLayout.bottomActionHeight)
        .buttonStyle(
            MonochromeActionButtonStyle(
                shape: SplashActionSurface(),
                fill: background,
                foreground: foreground,
                border: nil,
                pressedFill: nil,
                pressedForeground: nil
            )
        )
        .accessibilityIdentifier(title.lowercased().replacingOccurrences(of: " ", with: "-"))
    }
}
