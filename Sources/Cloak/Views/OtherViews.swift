import SwiftUI

// MARK: - Customize

struct CustomizeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Accent color")
                    HStack(spacing: 12) {
                        ForEach(Theme.accents) { accent in
                            Button {
                                state.accentKey = accent.id
                            } label: {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 34, height: 34)
                                        .shadow(color: accent.color.opacity(0.7), radius: state.accentKey == accent.id ? 10 : 0)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(state.accentKey == accent.id ? 0.9 : 0), lineWidth: 2)
                                                .padding(-4)
                                        )
                                    Text(accent.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(state.accentKey == accent.id ? Theme.text : Theme.dim)
                                }
                                .frame(width: 74)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Profile")
                    Text("The profile sets which subjects the guided setup runs and which ones count for the score.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                    Segmented(
                        values: Profile.allCases,
                        labels: Profile.allCases.map { $0.title },
                        selection: $state.profile,
                        accent: state.accent
                    )
                    .frame(maxWidth: 420)
                    ForEach(Profile.allCases) { profile in
                        HStack(alignment: .top, spacing: 10) {
                            Text(profile.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(state.profile == profile ? state.accent : Theme.text)
                                .frame(width: 80, alignment: .leading)
                            Text(Catalog.subjects.filter { $0.tier == profile }.map { $0.title }.joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Your tool choices")
                    Text("Change a choice by opening the subject.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 8)], spacing: 8) {
                        ForEach(Catalog.subjects) { subject in
                            Button {
                                state.openWizard(subject)
                            } label: {
                                HStack {
                                    Text(subject.title)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.dim)
                                    Spacer()
                                    Text(state.chosenOption(subject)?.name ?? "")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.well))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .card()
            }
            .padding(14)
        }
    }
}

// MARK: - Restore

final class RestoreModel: ObservableObject {
    @Published var pendingUndo: LogEntry? = nil
    @Published var confirmReset: Bool = false
}

struct LogIcon: View {
    let isInstall: Bool
    let accent: Color

    var body: some View {
        Image(systemName: isInstall ? "shippingbox.fill" : "circle.fill")
            .font(.system(size: isInstall ? 12 : 6))
            .foregroundStyle(accent)
            .frame(width: 18)
            .padding(.top, 3)
    }
}

struct RestoreView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var runner = BrewRunner()
    @StateObject private var ui = RestoreModel()

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Activity log")
                    Text("Each change Cloak made, newest first. Apps installed with Homebrew have an Uninstall button.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)

                    if state.log.isEmpty {
                        Text("Nothing here yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                            .padding(.vertical, 20)
                    }

                    ForEach(state.log) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            LogIcon(isInstall: entry.brewUninstall != nil, accent: state.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Text(entry.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.dim)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(formatter.string(from: entry.date))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.faint)
                            }
                            Spacer()
                            if entry.brewUninstall != nil {
                                Button("Uninstall") { ui.pendingUndo = entry }
                                    .buttonStyle(FlatButtonStyle(wide: false))
                                    .disabled(runner.running || state.brewPath == nil)
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Restore point")
                    Text("Make a Time Machine backup before you run system scripts or encrypt a disk. It is the only full undo for a Mac.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Time Machine settings") {
                        perform(.settings("x-apple.systempreferences:com.apple.Time-Machine-Settings.extension"))
                    }
                    .buttonStyle(FlatButtonStyle())

                    Divider().overlay(Theme.stroke)

                    SectionTitle(text: "Reset Cloak")
                    Text("Sets all subjects back to Not started. It does not remove any app or change any setting.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Reset progress") { ui.confirmReset = true }
                        .buttonStyle(FlatButtonStyle())

                    if !runner.output.isEmpty {
                        ScrollView {
                            Text(runner.output)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.dim)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 120)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.well))
                    }
                }
                .card()
                .frame(width: 340)
            }
            .padding(14)
        }
        .confirmationDialog(
            "Uninstall this app?",
            isPresented: Binding(get: { ui.pendingUndo != nil }, set: { if !$0 { ui.pendingUndo = nil } }),
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                if let entry = ui.pendingUndo, let args = entry.brewUninstall, let brew = state.brewPath {
                    let title = entry.title
                    let id = entry.id
                    runner.run(brew: brew, args: args) { success in
                        if success {
                            if let index = state.log.firstIndex(where: { $0.id == id }) {
                                state.log.remove(at: index)
                            }
                            state.addLog("Uninstalled", title.replacingOccurrences(of: "Installed: ", with: "").replacingOccurrences(of: "Install started: ", with: ""))
                        }
                        state.scan()
                    }
                }
                ui.pendingUndo = nil
            }
            Button("Cancel", role: .cancel) { ui.pendingUndo = nil }
        } message: {
            Text("Homebrew removes the app. Your account and data in the app are not deleted. If Homebrew needs a password, run the command in Terminal.")
        }
        .confirmationDialog("Reset all progress?", isPresented: $ui.confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { state.resetAll() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Help

struct HelpView: View {
    @EnvironmentObject var state: AppState

    private let rules: [(String, String)] = [
        ("Order matters", "Password manager, 2FA and disk encryption stop the most common attacks. Do them before the VPN or Tor."),
        ("One tool per job", "Run one VPN, one application firewall and one content blocker. Two of the same kind conflict."),
        ("Tor and VPN", "Tor Browser over a VPN is fine. Do not sign in to personal accounts in Tor Browser."),
        ("FileVault and VeraCrypt", "FileVault encrypts the Mac. VeraCrypt is for USB drives and containers that other systems must open."),
        ("A VPN is not anonymity", "It hides your IP address from sites and your traffic from the network. Sites still know you by login and cookies."),
        ("Tools not on this Mac", "Portmaster and Simplewall have no macOS version. Tails does not start on Apple silicon. GrapheneOS needs a Google Pixel."),
        ("Downloads", "Cloak links only to each official site or uses Homebrew. Do not use other download sites for security tools.")
    ]

    private let links: [(String, String)] = [
        ("Privacy Guides", "https://www.privacyguides.org/"),
        ("EFF Surveillance Self-Defense", "https://ssd.eff.org/"),
        ("Apple Platform Security", "https://support.apple.com/guide/security/welcome/web"),
        ("Homebrew", "https://brew.sh/")
    ]

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Rules that keep the stack sane")
                    ForEach(0..<rules.count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rules[index].0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text(rules[index].1)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Trusted references")
                    ForEach(0..<links.count, id: \.self) { index in
                        Button {
                            if let url = URL(string: links[index].1) { openURL(url) }
                        } label: {
                            HStack {
                                Text(links[index].0)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.well))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    SectionTitle(text: "Shortcuts")
                        .padding(.top, 6)
                    Text("Command-R scans this Mac again.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                }
                .card()
                .frame(width: 340)
            }
            .padding(14)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Homebrew")
                    HStack {
                        Image(systemName: state.brewPath == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(state.brewPath == nil ? Theme.red : Theme.good)
                        Text(state.brewPath ?? "Not installed. One-click installs are off.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                        Spacer()
                        if state.brewPath == nil {
                            Button("Get Homebrew") { openURL(URL(string: "https://brew.sh")!) }
                                .buttonStyle(FlatButtonStyle(wide: false))
                        }
                    }
                    Text("Cloak uses Homebrew to install apps with one click. Homebrew downloads each app from its vendor and checks the file hash.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "What Cloak does and does not do")
                    bullet("It runs on this Mac only. It has no account, no server and no analytics.")
                    bullet("It reads system state with fdesetup, socketfilterfw, spctl and csrutil. It does not change system settings.")
                    bullet("It never asks for a password. Installers that need one run in Terminal.")
                    bullet("Its progress file is in ~/Library/Application Support/Cloak/state.json.")
                }
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "This Mac")
                    infoRow("User", NSFullUserName().isEmpty ? NSUserName() : NSFullUserName())
                    infoRow("Computer", Host.current().localizedName ?? "Mac")
                    infoRow("macOS", ProcessInfo.processInfo.operatingSystemVersionString)
                    infoRow("Cloak", "1.0")
                }
                .card()
            }
            .padding(14)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(state.accent).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.dim)
            Spacer()
            Text(value).foregroundStyle(Theme.text)
        }
        .font(.system(size: 12))
    }
}
