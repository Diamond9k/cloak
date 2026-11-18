import SwiftUI

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    ScoreCard()
                    quickFacts
                }
                .frame(width: 350)

                VStack(spacing: 12) {
                    nextCard
                    categoryProgress
                    recentActivity
                }
            }
            .padding(14)
        }
    }

    private var quickFacts: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "This Mac")
            factRow("Subjects protected", "\(state.doneCount) of \(state.activeSubjects.count)")
            factRow("Privacy apps found", "\(state.detected.count)")
            factRow("macOS checks passed", "\(state.auditResults.values.filter { $0 }.count) of \(Audit.checks.count)")
            factRow("Homebrew", state.brewPath == nil ? "Not installed" : "Ready")
        }
        .card()
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.dim)
            Spacer()
            Text(value).foregroundStyle(Theme.text)
        }
        .font(.system(size: 12))
    }

    private var nextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "Next step")
                Spacer()
                Chip(text: state.profile.title, color: state.accent, filled: true)
            }
            if let next = state.nextSubject {
                HStack(spacing: 14) {
                    Image(systemName: next.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 58, height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: next.category.hero, startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(next.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(next.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.dim)
                        if let option = state.chosenOption(next) {
                            Text("Recommended: \(option.name)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(state.accent)
                        }
                    }
                    Spacer()
                    Button(state.status(next) == .inProgress ? "Continue" : "Start") {
                        state.openWizard(next)
                    }
                    .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
                }
            } else {
                Text("All subjects in this profile are done. Run a scan from time to time to confirm that nothing changed.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
            }
        }
        .card()
    }

    private var categoryProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Coverage")
            ForEach(Area.allCases) { category in
                let counts = state.counts(for: category)
                let fraction = counts.total == 0 ? 0.0 : Double(counts.done) / Double(counts.total)
                HStack(spacing: 10) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .frame(width: 20)
                    Text(category.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text)
                        .frame(width: 150, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(state.accent)
                                .frame(width: max(0, proxy.size.width * CGFloat(fraction)))
                                .shadow(color: state.accent.opacity(0.6), radius: 4)
                        }
                    }
                    .frame(height: 6)
                    Text("\(counts.done)/\(counts.total)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
        .card()
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "Recent activity")
                Spacer()
                Button("View all") { state.nav = .restore }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(state.accent)
            }
            if state.log.isEmpty {
                Text("No activity yet. Start the guided setup.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
            }
            ForEach(state.log.prefix(5)) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(state.accent).frame(width: 6, height: 6).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                        Text(entry.detail).font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                    Spacer()
                    Text(entry.date, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
        .card()
    }
}

// MARK: - Tool Hub (the "Game Hub" grid)

struct HubView: View {
    @EnvironmentObject var state: AppState

    private var visible: [Topic] {
        Catalog.subjects.filter { subject in
            let matchCategory = state.hubFilter == nil || subject.category == state.hubFilter
            let text = state.hubSearch.trimmingCharacters(in: .whitespaces)
            let matchText = text.isEmpty
                || subject.title.localizedCaseInsensitiveContains(text)
                || subject.options.contains { $0.name.localizedCaseInsensitiveContains(text) }
            return matchCategory && matchText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                filterChip(title: "All", category: nil)
                ForEach(Area.allCases) { category in
                    filterChip(title: category.title, category: category)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.dim)
                    TextField("Search tools", text: $state.hubSearch)
                        .textFieldStyle(.plain)
                        .frame(width: 150)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.cardHi))
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 12)], spacing: 12) {
                    ForEach(visible) { subject in
                        SubjectCard(subject: subject)
                    }
                }
            }
        }
        .padding(14)
    }

    private func filterChip(title: String, category: Area?) -> some View {
        let active = state.hubFilter == category
        return Button {
            state.hubFilter = category
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? state.accent : Theme.dim)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(active ? state.accent.opacity(0.14) : Theme.card)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SubjectCard: View {
    @EnvironmentObject var state: AppState
    let subject: Topic

    var body: some View {
        let status = state.status(subject)
        let option = state.chosenOption(subject)

        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: subject.category.hero, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: subject.symbol)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.16))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)
                    .offset(y: 10)
                HStack {
                    Chip(text: subject.category.title, color: Color.white.opacity(0.9), filled: true)
                    Spacer()
                    if !state.isActive(subject) {
                        Chip(text: subject.tier.title + " profile", color: Color.white.opacity(0.9), filled: true)
                    }
                }
                .padding(10)
            }
            .frame(height: 88)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: subject.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(subject.category.hero.last ?? state.accent))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(subject.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(option?.name ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.dim)
                            .lineLimit(1)
                    }
                    Spacer()
                    statusBadge(status)
                }

                Text(subject.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)

                Button(status == .done ? "Review" : "Open") {
                    state.openWizard(subject)
                }
                .buttonStyle(FlatButtonStyle())
            }
            .padding(12)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private func statusBadge(_ status: SubjectStatus) -> some View {
        switch status {
        case .done:
            Chip(text: "Protected", color: state.accent, filled: true)
        case .inProgress:
            Chip(text: "In progress", color: Theme.amber, filled: true)
        case .skipped:
            Chip(text: "Skipped", color: Theme.dim)
        case .notStarted:
            if state.isDetected(subject) {
                Chip(text: "App found", color: Theme.amber)
            } else {
                Chip(text: "Not started", color: Theme.dim)
            }
        }
    }
}
