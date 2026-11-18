import SwiftUI

private struct SavedState: Codable {
    var progress: [String: SubjectProgress] = [:]
    var log: [LogEntry] = []
    var profile: Profile = .maximum
    var accentKey: String = "magenta"
    var showUnavailable: Bool = true
}

final class AppState: ObservableObject {
    // Navigation
    @Published var nav: NavItem = .home
    @Published var hubFilter: Area? = nil
    @Published var hubSearch: String = ""
    @Published var wizardSubjectID: String? = nil
    @Published var showNotifications: Bool = false

    // Persisted
    @Published var progress: [String: SubjectProgress] = [:] { didSet { save() } }
    @Published var log: [LogEntry] = [] { didSet { save() } }
    @Published var profile: Profile = .maximum { didSet { save() } }
    @Published var accentKey: String = "magenta" { didSet { save() } }
    @Published var showUnavailable: Bool = true { didSet { save() } }

    // Live scan results
    @Published var detected: Set<String> = []
    @Published var auditResults: [String: Bool] = [:]
    @Published var scanning: Bool = false
    @Published var lastScan: Date? = nil
    @Published var brewPath: String? = Shell.brewPath

    private var loading = true

    var accent: Color { Theme.accent(accentKey) }

    init() {
        load()
        loading = false
        scan()
    }

    // MARK: Persistence

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("Cloak", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("state.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        progress = saved.progress
        log = saved.log
        profile = saved.profile
        accentKey = saved.accentKey
        showUnavailable = saved.showUnavailable
    }

    private func save() {
        guard !loading else { return }
        let saved = SavedState(progress: progress, log: log, profile: profile, accentKey: accentKey, showUnavailable: showUnavailable)
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Subjects

    /// Subjects included in the current profile, in guided order.
    var activeSubjects: [Topic] {
        Catalog.subjects.filter { $0.tier.rank <= profile.rank }
    }

    func isActive(_ subject: Topic) -> Bool {
        subject.tier.rank <= profile.rank
    }

    func status(_ subject: Topic) -> SubjectStatus {
        progress[subject.id]?.status ?? .notStarted
    }

    func chosenOption(_ subject: Topic) -> ToolOption? {
        let id = progress[subject.id]?.chosenOption ?? subject.recommended
        return subject.options.first { $0.id == id } ?? subject.options.first
    }

    func isDetected(_ subject: Topic) -> Bool {
        subject.options.contains { detected.contains($0.id) }
    }

    func statusColor(_ subject: Topic) -> Color {
        switch status(subject) {
        case .done: return accent
        case .inProgress: return Theme.amber
        case .skipped: return Theme.faint
        case .notStarted: return isDetected(subject) ? Theme.amber.opacity(0.6) : Color.white.opacity(0.14)
        }
    }

    var nextSubject: Topic? {
        activeSubjects.first { status($0) == .inProgress }
            ?? activeSubjects.first { status($0) == .notStarted }
    }

    func subjectAfter(_ subject: Topic) -> Topic? {
        let list = activeSubjects
        guard let index = list.firstIndex(where: { $0.id == subject.id }) else { return nextSubject }
        let later = list[(index + 1)...].first { status($0) != .done && status($0) != .skipped }
        return later ?? list[..<index].first { status($0) != .done && status($0) != .skipped }
    }

    func openWizard(_ subject: Topic) {
        wizardSubjectID = subject.id
    }

    // MARK: Progress mutations

    func choose(_ option: ToolOption, for subject: Topic) {
        var item = progress[subject.id] ?? SubjectProgress()
        if item.chosenOption != option.id {
            item.chosenOption = option.id
            item.completedSteps = []
        }
        if item.status == .notStarted { item.status = .inProgress }
        item.updated = .now
        progress[subject.id] = item
    }

    func toggleStep(_ index: Int, for subject: Topic) {
        var item = progress[subject.id] ?? SubjectProgress()
        if item.completedSteps.contains(index) {
            item.completedSteps.remove(index)
        } else {
            item.completedSteps.insert(index)
        }
        if item.status == .notStarted { item.status = .inProgress }
        item.updated = .now
        progress[subject.id] = item
    }

    func stepDone(_ index: Int, for subject: Topic) -> Bool {
        progress[subject.id]?.completedSteps.contains(index) ?? false
    }

    func setStatus(_ status: SubjectStatus, for subject: Topic) {
        var item = progress[subject.id] ?? SubjectProgress()
        guard item.status != status else { return }
        item.status = status
        item.updated = .now
        progress[subject.id] = item
        let option = chosenOption(subject)?.name ?? subject.title
        switch status {
        case .done: addLog("Protected: \(subject.title)", "Set up with \(option).")
        case .skipped: addLog("Skipped: \(subject.title)", "You can open it again from the Tool Hub.")
        case .notStarted: addLog("Reset: \(subject.title)", "Progress cleared.")
        case .inProgress: break
        }
    }

    func addLog(_ title: String, _ detail: String, brewUninstall: [String]? = nil) {
        log.insert(LogEntry(date: .now, title: title, detail: detail, brewUninstall: brewUninstall), at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
    }

    func resetAll() {
        progress = [:]
        addLog("Progress reset", "All subjects set back to Not started. Installed apps were not removed.")
    }

    // MARK: Audit display helpers

    func auditColor(_ id: String) -> Color {
        guard let result = auditResults[id] else { return Color.white.opacity(0.14) }
        return result ? accent : Theme.red
    }

    func auditLabel(_ id: String) -> String {
        guard let result = auditResults[id] else { return "..." }
        return result ? "On" : "Off"
    }

    // MARK: Score

    var score: Int {
        let subjects = activeSubjects.filter { status($0) == .done }.reduce(0) { $0 + $1.weight }
        let audit = auditResults.values.filter { $0 }.count * Audit.points
        return subjects + audit
    }

    var maxScore: Int {
        activeSubjects.reduce(0) { $0 + $1.weight } + Audit.checks.count * Audit.points
    }

    var doneCount: Int { activeSubjects.filter { status($0) == .done }.count }

    func counts(for category: Area) -> (done: Int, total: Int) {
        let list = Catalog.subjects(in: category).filter { isActive($0) }
        return (list.filter { status($0) == .done }.count, list.count)
    }

    // MARK: Notifications

    struct Notice: Identifiable {
        let id: String
        let symbol: String
        let color: Color
        let title: String
        let detail: String
        let subjectID: String?
        let nav: NavItem?
    }

    var notices: [Notice] {
        var list: [Notice] = []
        for check in Audit.checks where auditResults[check.id] == false {
            list.append(Notice(id: "audit-\(check.id)", symbol: "exclamationmark.triangle.fill", color: Theme.red,
                               title: "\(check.title) is off", detail: check.detail, subjectID: nil, nav: .audit))
        }
        if brewPath == nil {
            list.append(Notice(id: "brew", symbol: "shippingbox.fill", color: Theme.amber,
                               title: "Homebrew is not installed",
                               detail: "One-click installs need Homebrew. Official downloads still work.",
                               subjectID: nil, nav: .settings))
        }
        for subject in activeSubjects where status(subject) == .inProgress {
            list.append(Notice(id: "progress-\(subject.id)", symbol: "clock.fill", color: Theme.amber,
                               title: "\(subject.title) is not finished", detail: "Open it to continue the steps.",
                               subjectID: subject.id, nav: nil))
        }
        for subject in activeSubjects where status(subject) == .notStarted && isDetected(subject) {
            list.append(Notice(id: "found-\(subject.id)", symbol: "checkmark.seal.fill", color: accent,
                               title: "\(subject.title): app found on this Mac",
                               detail: "Run the setup steps to finish and get the score.",
                               subjectID: subject.id, nav: nil))
        }
        return list
    }

    // MARK: Scan

    func scan() {
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            var found: Set<String> = []
            for subject in Catalog.subjects {
                for option in subject.options where AppState.probe(option.probe) {
                    found.insert(option.id)
                }
            }
            var audit: [String: Bool] = [:]
            for check in Audit.checks {
                audit[check.id] = Audit.run(check)
            }
            let brew = Shell.brewPath
            let foundResult = found
            let auditResult = audit
            DispatchQueue.main.async {
                self.detected = foundResult
                self.auditResults = auditResult
                self.brewPath = brew
                self.lastScan = .now
                self.scanning = false
            }
        }
    }

    static func probe(_ probe: Probe) -> Bool {
        switch probe {
        case .app(let names):
            return names.contains { Shell.appExists($0) }
        case .binary(let names):
            return names.contains { Shell.findBinary($0) != nil }
        case .shell(let path, let args, let token):
            return Shell.run(path, args).output.localizedCaseInsensitiveContains(token)
        case .manual:
            return false
        }
    }
}
