import SwiftUI

/// Local state of one wizard sheet.
/// Cloak does not use @State: in the macOS 27 SDK it is a macro that needs Xcode.
/// An ObservableObject builds with the Command Line Tools alone.
final class WizardModel: ObservableObject {
    @Published var stage: Int = 0
    @Published var optionID: String
    @Published var found: Bool = false
    @Published var checked: Bool = false

    init(optionID: String) {
        self.optionID = optionID
    }
}

/// The guided install: Overview > Choose > Install > Configure > Finish.
struct WizardView: View {
    @EnvironmentObject var state: AppState
    let subject: Topic

    @StateObject private var ui: WizardModel
    @StateObject private var runner = BrewRunner()

    private var stage: Int {
        get { ui.stage }
        nonmutating set { ui.stage = newValue }
    }
    private var optionID: String {
        get { ui.optionID }
        nonmutating set { ui.optionID = newValue }
    }
    private var found: Bool {
        get { ui.found }
        nonmutating set { ui.found = newValue }
    }
    private var checked: Bool {
        get { ui.checked }
        nonmutating set { ui.checked = newValue }
    }

    private let stages = ["Overview", "Choose", "Install", "Configure", "Finish"]

    init(subject: Topic, initialOption: String) {
        self.subject = subject
        _ui = StateObject(wrappedValue: WizardModel(optionID: initialOption))
    }

    private var option: ToolOption {
        subject.options.first { $0.id == optionID } ?? subject.options[0]
    }

    private func dotFill(_ index: Int) -> Color {
        if index < stage { return state.accent }
        if index == stage { return state.accent.opacity(0.18) }
        return Color.white.opacity(0.06)
    }

    private func stageWeight(_ index: Int) -> Font.Weight {
        index == stage ? Font.Weight.semibold : Font.Weight.regular
    }

    private var positionText: String {
        let list = state.activeSubjects
        if let index = list.firstIndex(where: { $0.id == subject.id }) {
            return "Subject \(index + 1) of \(list.count)"
        }
        return "\(subject.tier.title) profile"
    }

    var body: some View {
        HStack(spacing: 0) {
            rail
                .frame(width: 210)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        stageContent
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
            .background(Theme.bg)
        }
        .frame(width: 900, height: 640)
        .background(Theme.sidebar)
        .preferredColorScheme(.dark)
        .onAppear { recheck() }
    }

    // MARK: Left rail

    private var rail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: subject.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: subject.category.hero, startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .padding(.bottom, 6)
            Text(subject.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(positionText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
                .padding(.bottom, 14)

            ForEach(0..<stages.count, id: \.self) { index in
                Button {
                    stage = index
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(dotFill(index))
                                .frame(width: 22, height: 22)
                            if index < stage {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(index == stage ? state.accent : Theme.dim)
                            }
                        }
                        Text(stages[index])
                            .font(.system(size: 13, weight: stageWeight(index)))
                            .foregroundStyle(index == stage ? Theme.text : Theme.dim)
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Skip this subject") {
                state.setStatus(.skipped, for: subject)
                advance()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Theme.dim)
        }
        .padding(18)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Close") { state.wizardSubjectID = nil }
                .buttonStyle(FlatButtonStyle(wide: false))
            Spacer()
            if stage > 0 {
                Button("Back") { stage -= 1 }
                    .buttonStyle(FlatButtonStyle(wide: false))
            }
            if stage < stages.count - 1 {
                Button(stage == 0 ? "Begin" : "Next") {
                    if stage == 1 { state.choose(option, for: subject) }
                    stage += 1
                    if stage == 2 { recheck() }
                }
                .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
                .disabled(stage == 1 && !option.support.isAvailable)
            } else {
                Button(state.subjectAfter(subject) == nil ? "Done" : "Next subject") {
                    state.setStatus(.done, for: subject)
                    advance()
                }
                .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
            }
        }
        .padding(14)
        .background(Theme.sidebar)
    }

    private func advance() {
        if let next = state.subjectAfter(subject) {
            state.wizardSubjectID = next.id
        } else {
            state.wizardSubjectID = nil
        }
    }

    private func recheck() {
        let probe = option.probe
        let id = option.id
        DispatchQueue.global(qos: .userInitiated).async {
            let result = AppState.probe(probe)
            DispatchQueue.main.async {
                found = result
                checked = true
                if result { state.detected.insert(id) }
            }
        }
    }

    // MARK: Stage content

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case 0: overview
        case 1: choose
        case 2: install
        case 3: configure
        default: finish
        }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func note(_ text: String, symbol: String = "exclamationmark.triangle.fill", color: Color = Theme.amber) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(0.10)))
    }

    // 0. Overview
    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading(subject.title, subject.summary)
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "Why it matters")
                Text(subject.why)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
            ForEach(subject.cautions, id: \.self) { caution in
                note(caution)
            }
            HStack(spacing: 8) {
                Chip(text: "+\(subject.weight) score", color: state.accent, filled: true)
                Chip(text: subject.category.title)
                Chip(text: "\(subject.tier.title) profile")
                Chip(text: "\(subject.options.count) option" + (subject.options.count == 1 ? "" : "s"))
            }
        }
    }

    // 1. Choose
    private var choose: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Choose a tool", "Pick one. Cloak marks the option that fits a Mac best.")
            ForEach(subject.options) { item in
                let selected = item.id == optionID
                Button {
                    optionID = item.id
                    checked = false
                    found = false
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(selected ? state.accent : Theme.faint)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(item.support.isAvailable ? Theme.text : Theme.dim)
                                if item.id == subject.recommended {
                                    Chip(text: "Recommended", color: state.accent, filled: true)
                                }
                                Chip(text: item.support.label, color: item.support.isAvailable ? Theme.dim : Theme.red)
                                if state.detected.contains(item.id) {
                                    Chip(text: "Installed", color: Theme.good, filled: true)
                                }
                            }
                            Text(item.tagline)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.dim)
                                .fixedSize(horizontal: false, vertical: true)
                            if case .notOnMac(let reason) = item.support {
                                Text(reason)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? state.accent.opacity(0.8) : Theme.stroke, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // 2. Install
    private var install: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Install \(option.name)", option.tagline)

            switch option.support {
            case .notOnMac(let reason):
                note(reason, symbol: "xmark.octagon.fill", color: Theme.red)
                Button("Choose another tool") { stage = 1 }
                    .buttonStyle(FlatButtonStyle(wide: false))

            case .external(let reason):
                note(reason, symbol: "arrow.up.forward.app.fill", color: state.accent)
                note(option.verify, symbol: "checkmark.shield.fill", color: Theme.good)
                Button("Open the official guide") { openURL(option.url) }
                    .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
                Text("The steps are on the next page.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)

            case .web, .browserExtension:
                detectionRow
                note(option.verify, symbol: "checkmark.shield.fill", color: Theme.good)
                Button("Open the official page") { openURL(option.url) }
                    .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
                Text("There is no Mac app to install. The steps are on the next page.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)

            case .native, .appStore, .cli:
                detectionRow
                note(option.verify, symbol: "checkmark.shield.fill", color: Theme.good)
                installButtons
                if !runner.output.isEmpty {
                    console
                }
            }
        }
    }

    private var detectionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: found ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 18))
                .foregroundStyle(found ? Theme.good : Theme.dim)
            VStack(alignment: .leading, spacing: 2) {
                Text(found ? "\(option.name) is on this Mac" : (checked ? "Not found yet" : "Checking"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(detectionHint)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
            }
            Spacer()
            Button("Check again") { recheck() }
                .buttonStyle(FlatButtonStyle(wide: false))
        }
        .card(12)
    }

    private var detectionHint: String {
        if case .manual = option.probe {
            return "Cloak cannot detect this one. Confirm it yourself on the next page."
        }
        return found ? "You can go to the next page." : "Install it, then click Check again."
    }

    @ViewBuilder
    private var installButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let brew = option.brew {
                if let brewPath = state.brewPath {
                    HStack(spacing: 10) {
                        if option.needsTerminal {
                            Button {
                                Shell.runInTerminal(brew.command)
                                state.addLog("Install started: \(option.name)", brew.command, brewUninstall: brew.uninstallArgs)
                            } label: {
                                Label("Install in Terminal", systemImage: "terminal.fill")
                            }
                            .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
                        } else {
                            Button {
                                let name = option.name
                                let undo = brew.uninstallArgs
                                runner.run(brew: brewPath, args: brew.args) { success in
                                    if success {
                                        state.addLog("Installed: \(name)", brew.command, brewUninstall: undo)
                                    }
                                    recheck()
                                    state.scan()
                                }
                            } label: {
                                Label(runner.running ? "Installing" : "Install with Homebrew", systemImage: "shippingbox.fill")
                            }
                            .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
                            .disabled(runner.running)

                            Button {
                                Shell.runInTerminal(brew.command)
                            } label: {
                                Label("Run in Terminal", systemImage: "terminal")
                            }
                            .buttonStyle(FlatButtonStyle(wide: false))
                        }
                        Button {
                            openURL(option.url)
                        } label: {
                            Label("Official download", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(FlatButtonStyle(wide: false))
                    }
                    Text(option.needsTerminal
                         ? "This installer needs your Mac password. Terminal asks for it, so Cloak never sees it."
                         : "Command: \(brew.command)")
                        .font(option.needsTerminal ? Font.system(size: 11) : Font.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .textSelection(.enabled)
                } else {
                    note("Homebrew is not installed, so one-click install is off. Use the official download, or install Homebrew from brew.sh and click Scan.", symbol: "shippingbox.fill")
                    HStack(spacing: 10) {
                        Button {
                            openURL(option.url)
                        } label: {
                            Label("Official download", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
                        Button("Get Homebrew") { openURL(URL(string: "https://brew.sh")!) }
                            .buttonStyle(FlatButtonStyle(wide: false))
                    }
                }
            } else {
                Button {
                    openURL(option.url)
                } label: {
                    Label("Official download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(AccentButtonStyle(accent: state.accent, wide: false))
            }
        }
    }

    private var console: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Install log")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                Spacer()
                if runner.running {
                    ProgressView().controlSize(.small)
                } else if let code = runner.exitCode {
                    Chip(text: code == 0 ? "Finished" : "Failed (\(code))", color: code == 0 ? Theme.good : Theme.red, filled: true)
                }
            }
            ScrollView {
                Text(runner.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .defaultScrollAnchor(.bottom)
            .frame(height: 150)
            if let code = runner.exitCode, code != 0 {
                Text("If Homebrew asked for a password or the name was not found, use Run in Terminal or the official download.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.amber)
            }
        }
        .card(12, fill: Theme.well)
    }

    // 3. Configure
    private var configure: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Set up \(option.name)", "Do each step, then tick it. An app that is installed but not set up gives little protection.")

            if option.configure.isEmpty {
                note("No setup steps for this tool.", symbol: "info.circle.fill", color: Theme.dim)
            }

            if case .app(let names) = option.probe, found, let name = names.first(where: { Shell.appExists($0) }) {
                Button {
                    Shell.openApp(name)
                } label: {
                    Label("Open \(option.name)", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(FlatButtonStyle(wide: false))
            }

            ForEach(0..<option.configure.count, id: \.self) { index in
                let step = option.configure[index]
                let done = state.stepDone(index, for: subject)
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        state.toggleStep(index, for: subject)
                    } label: {
                        Image(systemName: done ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(done ? state.accent : Theme.faint)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(index + 1). \(step.title)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(step.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if let action = step.action {
                        Button(step.actionLabel ?? "Open") { perform(action) }
                            .buttonStyle(FlatButtonStyle(wide: false))
                    }
                }
                .card(12)
            }
        }
    }

    // 4. Finish
    private var finish: some View {
        let total = option.configure.count
        let done = (0..<total).filter { state.stepDone($0, for: subject) }.count

        return VStack(alignment: .leading, spacing: 14) {
            heading("Finish", "Confirm, then go to the next subject.")

            VStack(alignment: .leading, spacing: 10) {
                summaryRow("Tool", option.name)
                summaryRow("Detected on this Mac", found ? "Yes" : (isManual ? "Cannot be detected" : "No"))
                summaryRow("Setup steps ticked", "\(done) of \(total)")
                summaryRow("Score for this subject", "+\(subject.weight)")
            }
            .card()

            if !found && !isManual && option.support.isAvailable {
                note("Cloak did not find \(option.name) on this Mac. Go back to Install, or continue if you installed it in a different place.")
            }
            if done < total {
                note("\(total - done) setup step(s) are not ticked. You can finish them later from the Tool Hub.", symbol: "info.circle.fill", color: Theme.dim)
            }
            if let next = state.subjectAfter(subject) {
                Text("Next: \(next.title)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(state.accent)
            }
        }
    }

    private var isManual: Bool {
        if case .manual = option.probe { return true }
        return false
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.dim)
            Spacer()
            Text(value).foregroundStyle(Theme.text)
        }
        .font(.system(size: 13))
    }
}
