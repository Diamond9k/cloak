import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum Theme {
    static let bg = Color(hex: 0x09090C)
    static let sidebar = Color(hex: 0x0D0D11)
    static let card = Color(hex: 0x15151B)
    static let cardHi = Color(hex: 0x1F1F27)
    static let well = Color(hex: 0x0F0F14)
    static let stroke = Color.white.opacity(0.07)
    static let text = Color.white.opacity(0.92)
    static let dim = Color.white.opacity(0.55)
    static let faint = Color.white.opacity(0.32)
    static let amber = Color(hex: 0xF5A623)
    static let red = Color(hex: 0xFF4D5E)
    static let good = Color(hex: 0x2EE6A6)

    struct Accent: Identifiable {
        let id: String
        let name: String
        let color: Color
    }

    static let accents: [Accent] = [
        Accent(id: "magenta", name: "Magenta", color: Color(hex: 0xFF2E97)),
        Accent(id: "violet", name: "Violet", color: Color(hex: 0x9B6BFF)),
        Accent(id: "cyan", name: "Cyan", color: Color(hex: 0x2ED3FF)),
        Accent(id: "green", name: "Green", color: Color(hex: 0x2EE6A6)),
        Accent(id: "amber", name: "Amber", color: Color(hex: 0xF5A623))
    ]

    static func accent(_ key: String) -> Color {
        accents.first { $0.id == key }?.color ?? accents[0].color
    }
}

// MARK: - Card container

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var fill: Color = Theme.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}

extension View {
    func card(_ padding: CGFloat = 16, fill: Color = Theme.card) -> some View {
        modifier(CardModifier(padding: padding, fill: fill))
    }
}

// MARK: - Buttons

/// The wide dark "Open" button.
struct FlatButtonStyle: ButtonStyle {
    var wide: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.text)
            .padding(.vertical, 10)
            .padding(.horizontal, wide ? 0 : 16)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.cardHi.opacity(configuration.isPressed ? 0.6 : 1))
            )
            .contentShape(Rectangle())
    }
}

/// The glowing primary button (the "Boost" button).
struct AccentButtonStyle: ButtonStyle {
    let accent: Color
    var wide: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .padding(.horizontal, wide ? 0 : 20)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.55), accent.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: accent.opacity(configuration.isPressed ? 0.15 : 0.35), radius: 12, y: 2)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}

// MARK: - Small parts

struct Chip: View {
    let text: String
    var color: Color = Theme.dim
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(filled ? color.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(filled ? Color.clear : Theme.stroke, lineWidth: 1)
            )
    }
}

/// Segmented switch with an outlined active segment (Off / Smart / High look).
struct Segmented<T: Hashable>: View {
    let values: [T]
    let labels: [String]
    @Binding var selection: T
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<values.count, id: \.self) { index in
                let active = values[index] == selection
                Button {
                    selection = values[index]
                } label: {
                    Text(labels[index])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(active ? accent : Theme.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(active ? accent.opacity(0.14) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(active ? accent.opacity(0.8) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
    }
}

/// Card art: a device block on a rail, with one LED per subject.
struct RailArt: View {
    let symbol: String
    let leds: [Color]
    let accent: Color
    var size: CGFloat = 104

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.05))
                .frame(height: 6)
            HStack {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.10)).frame(width: 10, height: 22)
                Spacer()
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.10)).frame(width: 10, height: 22)
            }
            .padding(.horizontal, 26)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x2A2A33), Color(hex: 0x121217)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.28), radius: 22)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: accent.opacity(0.7), radius: 10)
                )
                .overlay(alignment: .bottom) {
                    HStack(spacing: 5) {
                        ForEach(0..<leds.count, id: \.self) { index in
                            Capsule()
                                .fill(leds[index])
                                .frame(width: 9, height: 3)
                                .shadow(color: leds[index].opacity(0.9), radius: 3)
                        }
                    }
                    .padding(.bottom, 9)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: size + 24)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
    }
}

func openURL(_ url: URL) {
    NSWorkspace.shared.open(url)
}

func perform(_ action: StepAction) {
    switch action {
    case .open(let url):
        openURL(url)
    case .settings(let string):
        if let url = URL(string: string) { openURL(url) }
    }
}
