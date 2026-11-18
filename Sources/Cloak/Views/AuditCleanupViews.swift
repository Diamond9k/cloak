import AppKit
import SwiftUI

// MARK: - Audit (the "Benchmark" tab)

struct AuditView: View {
    @EnvironmentObject var state: AppState

    private struct LeakTest: Identifiable {
        let id: String
        let title: String
        let detail: String
        let url: String
    }

    private let tests: [LeakTest] = [
        LeakTest(id: "mullvad", title: "Connection check", detail: "Shows IP address, DNS servers and WebRTC leaks on one page.", url: "https://mullvad.net/check"),
        LeakTest(id: "dns", title: "DNS leak test", detail: "Run the extended test. Only your VPN or DNS provider must show.", url: "https://dnsleaktest.com/"),
        LeakTest(id: "eff", title: "Browser fingerprint", detail: "EFF Cover Your Tracks tests tracker blocking and how unique the browser is.", url: "https://coveryourtracks.eff.org/"),
        LeakTest(id: "nextdns", title: "NextDNS status", detail: "Confirms that this Mac uses your NextDNS profile.", url: "https://test.nextdns.io/")
    ]

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionTitle(text: "macOS security checks")
                        Spacer()
                        Chip(text: "+\(Audit.points) score each", color: state.accent, filled: true)
                    }
                    Text("Cloak reads these settings from macOS. It does not change them. Use the button to open the right settings page.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Audit.checks) { check in
                        let result = state.auditResults[check.id]
                        HStack(spacing: 12) {
                            Image(systemName: result == true ? "checkmark.shield.fill" : (result == false ? "xmark.shield.fill" : "shield"))
                                .font(.system(size: 20))
                                .foregroundStyle(result == true ? state.accent : (result == false ? Theme.red : Theme.dim))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(check.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text(check.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.dim)
                            }
                            Spacer()
                            if result == true {
                                Chip(text: "On", color: state.accent, filled: true)
                            } else {
                                if result == false { Chip(text: "Off", color: Theme.red, filled: true) }
                                Button(check.fixLabel) { perform(check.fix) }
                                    .buttonStyle(FlatButtonStyle(wide: false))
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
                    }

                    Button {
                        state.scan()
                    } label: {
                        Label(state.scanning ? "Scanning" : "Run audit again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(AccentButtonStyle(accent: state.accent))
                    .disabled(state.scanning)
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Leak tests")
                    Text("These open in your browser. Run them after you set up the VPN, DNS and browser.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(tests) { test in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(test.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text(test.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.dim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Button("Open") {
                                if let url = URL(string: test.url) { openURL(url) }
                            }
                            .buttonStyle(FlatButtonStyle(wide: false))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
                    }
                }
                .card()
                .frame(width: 400)
            }
            .padding(14)
        }
    }
}

// MARK: - Cleanup (the "Disk Tools" tab)

struct CleanTarget: Identifiable {
    let id: String
    let group: String
    let name: String
    let relativePath: String

    var url: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
    }
}

final class CleanupModel: ObservableObject {
    static let targets: [CleanTarget] = [
        CleanTarget(id: "brave", group: "Browser caches", name: "Brave cache", relativePath: "Library/Caches/BraveSoftware/Brave-Browser"),
        CleanTarget(id: "chrome", group: "Browser caches", name: "Chrome cache", relativePath: "Library/Caches/Google/Chrome"),
        CleanTarget(id: "firefox", group: "Browser caches", name: "Firefox cache", relativePath: "Library/Caches/Firefox"),
        CleanTarget(id: "librewolf", group: "Browser caches", name: "LibreWolf cache", relativePath: "Library/Caches/LibreWolf"),
        CleanTarget(id: "edge", group: "Browser caches", name: "Edge cache", relativePath: "Library/Caches/Microsoft Edge"),
        CleanTarget(id: "logs", group: "System traces", name: "User logs", relativePath: "Library/Logs"),
        CleanTarget(id: "quicklook", group: "System traces", name: "Saved application state", relativePath: "Library/Saved Application State"),
        CleanTarget(id: "brew", group: "Developer caches", name: "Homebrew downloads", relativePath: "Library/Caches/Homebrew"),
        CleanTarget(id: "xcode", group: "Developer caches", name: "Xcode DerivedData", relativePath: "Library/Developer/Xcode/DerivedData"),
        CleanTarget(id: "npm", group: "Developer caches", name: "npm cache", relativePath: ".npm/_cacache")
    ]

    @Published var sizes: [String: Int64] = [:]
    @Published var selected: Set<String> = []
    @Published var scanning = false
    @Published var progressText = "Ready"
    @Published var lastFreed: Int64? = nil
    @Published var freeSpace: Int64? = nil
    @Published var metadataMessage: String? = nil

    static func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            if let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    func scan() {
        guard !scanning else { return }
        scanning = true
        lastFreed = nil
        DispatchQueue.global(qos: .userInitiated).async {
            var result: [String: Int64] = [:]
            for target in CleanupModel.targets {
                DispatchQueue.main.async { self.progressText = "Scanning \(target.name)" }
                if FileManager.default.fileExists(atPath: target.url.path) {
                    result[target.id] = CleanupModel.size(of: target.url)
                }
            }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let free = (try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
            let sizeResult = result
            DispatchQueue.main.async {
                self.sizes = sizeResult
                self.freeSpace = free
                self.scanning = false
                self.progressText = "Scan complete"
            }
        }
    }

    /// Moves the contents of each selected folder to the Trash. Returns bytes moved.
    func clean(completion: @escaping (Int64, [String]) -> Void) {
        guard !scanning else { return }
        scanning = true
        let chosen = CleanupModel.targets.filter { selected.contains($0.id) }
        let known = sizes
        DispatchQueue.global(qos: .userInitiated).async {
            var freed: Int64 = 0
            var names: [String] = []
            for target in chosen {
                DispatchQueue.main.async { self.progressText = "Cleaning \(target.name)" }
                let children = (try? FileManager.default.contentsOfDirectory(at: target.url, includingPropertiesForKeys: nil)) ?? []
                var moved = false
                for child in children {
                    if (try? FileManager.default.trashItem(at: child, resultingItemURL: nil)) != nil {
                        moved = true
                    }
                }
                if moved {
                    freed += known[target.id] ?? 0
                    names.append(target.name)
                }
            }
            let freedTotal = freed
            let cleanedNames = names
            DispatchQueue.main.async {
                self.scanning = false
                self.selected = []
                self.lastFreed = freedTotal
                self.progressText = "Moved to Trash"
                completion(freedTotal, cleanedNames)
                self.scan()
            }
        }
    }
}

func byteString(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
}

struct CleanupView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var model = CleanupModel()

    private var groups: [String] {
        var seen: [String] = []
        for target in CleanupModel.targets where !seen.contains(target.group) {
            seen.append(target.group)
        }
        return seen
    }

    private var selectedBytes: Int64 {
        model.selected.reduce(0) { $0 + (model.sizes[$1] ?? 0) }
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Scans caches, logs and build files. Selected items go to the Trash, so you can put them back. Quit your browsers before you clean their caches.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(state.accent)
                            .shadow(color: state.accent.opacity(0.7), radius: 8)
                        Text(model.progressText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                        HStack(spacing: 3) {
                            ForEach(0..<36, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(barColor(index))
                                    .frame(width: 4, height: 22)
                            }
                        }
                        if let freed = model.lastFreed {
                            Text("\(byteString(freed)) moved to the Trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.good)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.well))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.stroke, lineWidth: 1))

                    HStack(spacing: 10) {
                        Button {
                            model.scan()
                        } label: {
                            Label(model.scanning ? "Working" : "Scan", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(FlatButtonStyle())
                        .disabled(model.scanning)

                        Button {
                            model.clean { freed, names in
                                guard !names.isEmpty else { return }
                                state.addLog("Cleanup: \(byteString(freed)) moved to Trash", names.joined(separator: ", ") + ". Use Put Back in the Trash to undo.")
                            }
                        } label: {
                            Label(model.selected.isEmpty ? "Clean" : "Clean \(byteString(selectedBytes))", systemImage: "trash")
                        }
                        .buttonStyle(AccentButtonStyle(accent: state.accent))
                        .disabled(model.scanning || model.selected.isEmpty)
                    }

                    metadataCard
                }
                .card()
                .frame(width: 400)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            ForEach(CleanupModel.targets.filter { $0.group == group }) { target in
                                targetRow(target)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        statTile("Free space", model.freeSpace.map { byteString($0) } ?? "Scan first", "externaldrive")
                        statTile("FileVault", state.auditResults["filevault"] == true ? "On" : "Off", "lock.fill")
                        statTile("Selected", byteString(selectedBytes), "checkmark.square")
                    }
                }
                .card()
            }
            .padding(14)
        }
        .onAppear { if model.sizes.isEmpty { model.scan() } }
    }

    private func barColor(_ index: Int) -> Color {
        if model.scanning {
            return index % 3 == 0 ? state.accent : state.accent.opacity(0.35)
        }
        return model.sizes.isEmpty ? Color.white.opacity(0.08) : state.accent.opacity(0.8)
    }

    private func targetRow(_ target: CleanTarget) -> some View {
        let size = model.sizes[target.id]
        let exists = size != nil
        let on = model.selected.contains(target.id)
        return Button {
            guard exists else { return }
            if on { model.selected.remove(target.id) } else { model.selected.insert(target.id) }
        } label: {
            HStack(spacing: 10) {
                Text(target.name)
                    .font(.system(size: 12))
                    .foregroundStyle(exists ? Theme.text : Theme.faint)
                Spacer()
                Text(size.map { byteString($0) } ?? "Not present")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(exists ? state.accent : Theme.faint)
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(on ? state.accent : Theme.faint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(on ? state.accent.opacity(0.10) : Theme.well)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statTile(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(state.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
    }

    // Strip metadata with ExifTool
    private var metadataCard: some View {
        let exiftool = Shell.findBinary("exiftool")
        return VStack(alignment: .leading, spacing: 8) {
            Text("Strip metadata")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(exiftool == nil
                 ? "Install ExifTool in the Metadata Removal subject to turn this on."
                 : "Pick photos or documents. ExifTool removes GPS, device and author data. A copy named _original stays next to each file.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
            if let path = exiftool {
                Button {
                    stripMetadata(path)
                } label: {
                    Label("Choose files", systemImage: "doc.badge.gearshape")
                }
                .buttonStyle(FlatButtonStyle())
            } else {
                Button("Open Metadata Removal") {
                    if let subject = Catalog.subject("metadata") { state.openWizard(subject) }
                }
                .buttonStyle(FlatButtonStyle())
            }
            if let message = model.metadataMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.good)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
    }

    private func stripMetadata(_ exiftool: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose the files to clean"
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        let paths = panel.urls.map { $0.path }
        model.metadataMessage = "Working"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Shell.run(exiftool, ["-all="] + paths)
            DispatchQueue.main.async {
                if result.code == 0 {
                    model.metadataMessage = "Cleaned \(paths.count) file(s). Originals kept as _original."
                    state.addLog("Metadata removed", "\(paths.count) file(s) cleaned with ExifTool.")
                } else {
                    model.metadataMessage = "ExifTool reported a problem. Some file types are not writable."
                }
            }
        }
    }
}
