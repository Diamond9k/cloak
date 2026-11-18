import SwiftUI

// MARK: - Score card (shared by Home and Harden)

struct HexShield: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for index in 0..<6 {
            let angle = (Double(index) * 60.0 - 90.0) * Double.pi / 180.0
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct ScoreCard: View {
    @EnvironmentObject var state: AppState

    private var fraction: Double {
        state.maxScore == 0 ? 0 : Double(state.score) / Double(state.maxScore)
    }

    private var buttonTitle: String {
        if state.nextSubject == nil { return "All subjects done" }
        return state.doneCount == 0 ? "Start guided setup" : "Continue setup"
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                HStack {
                    Text("Privacy score")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(state.score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(state.accent)
                    Text("/ \(state.maxScore)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.dim)
                }

                ZStack {
                    HexShield()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)
                    HexShield()
                        .trim(from: 0, to: fraction)
                        .stroke(state.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .shadow(color: state.accent.opacity(0.8), radius: 8)
                    HexShield()
                        .fill(
                            LinearGradient(colors: [Color(hex: 0x2A2A33), Color(hex: 0x131318)], startPoint: .top, endPoint: .bottom)
                        )
                        .padding(13)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(state.accent)
                        .shadow(color: state.accent.opacity(0.8), radius: 10)
                }
                .frame(width: 104, height: 104)
                .padding(.vertical, 2)

                Segmented(
                    values: Profile.allCases,
                    labels: Profile.allCases.map { $0.title },
                    selection: $state.profile,
                    accent: state.accent
                )

                Text(state.profile.blurb)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [state.accent.opacity(0.22), Theme.card],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))

            Button {
                if let next = state.nextSubject { state.openWizard(next) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: state.nextSubject == nil ? "checkmark.seal.fill" : "bolt.fill")
                    Text(buttonTitle)
                }
            }
            .buttonStyle(AccentButtonStyle(accent: state.accent))
            .disabled(state.nextSubject == nil)
        }
        .card(12)
    }
}

// MARK: - Harden screen

struct HardenView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ScoreCard()
                        .frame(width: 350)
                    CategoryCard(category: .network)
                    CategoryCard(category: .browser)
                }
                HStack(alignment: .top, spacing: 12) {
                    CategoryCard(category: .identity)
                    CategoryCard(category: .comms)
                    CategoryCard(category: .data)
                }
                HStack(alignment: .top, spacing: 12) {
                    CategoryCard(category: .system)
                    CategoryCard(category: .devices)
                    AuditSummaryCard()
                }
            }
            .padding(14)
        }
    }
}

struct CategoryCard: View {
    @EnvironmentObject var state: AppState
    let category: Area

    var body: some View {
        let subjects = Catalog.subjects(in: category)
        let counts = state.counts(for: category)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Chip(text: "\(counts.done) / \(counts.total)", color: counts.total > 0 && counts.done == counts.total ? state.accent : Theme.dim)
            }

            RailArt(
                symbol: category.symbol,
                leds: subjects.map { state.isActive($0) ? state.statusColor($0) : Color.white.opacity(0.05) },
                accent: state.accent
            )

            VStack(spacing: 6) {
                ForEach(subjects) { subject in
                    Button {
                        state.openWizard(subject)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(state.statusColor(subject))
                                .frame(width: 7, height: 7)
                            Text(subject.title)
                                .font(.system(size: 12))
                                .foregroundStyle(state.isActive(subject) ? Theme.text : Theme.faint)
                                .lineLimit(1)
                            Spacer()
                            Text(state.isActive(subject) ? state.status(subject).label : subject.tier.title)
                                .font(.system(size: 11))
                                .foregroundStyle(state.status(subject) == .done ? state.accent : Theme.dim)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.well))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)

            Button("Open") {
                state.hubFilter = category
                state.nav = .hub
            }
            .buttonStyle(FlatButtonStyle())
        }
        .card()
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .top)
    }
}

struct AuditSummaryCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let passed = state.auditResults.values.filter { $0 }.count

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("macOS Audit")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Chip(text: "\(passed) / \(Audit.checks.count)", color: passed == Audit.checks.count ? state.accent : Theme.amber)
            }

            RailArt(
                symbol: "gauge.with.dots.needle.67percent",
                leds: Audit.checks.map { state.auditColor($0.id) },
                accent: state.accent
            )

            VStack(spacing: 6) {
                ForEach(Audit.checks) { check in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(state.auditColor(check.id))
                            .frame(width: 7, height: 7)
                        Text(check.title)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer()
                        Text(state.auditLabel(check.id))
                            .font(.system(size: 11))
                            .foregroundStyle(state.auditResults[check.id] == true ? state.accent : Theme.dim)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.well))
                }
            }

            Spacer(minLength: 0)

            Button("Open") { state.nav = .audit }
                .buttonStyle(FlatButtonStyle())
        }
        .card()
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .top)
    }
}
