import AppKit
import Foundation
import SwiftUI

enum Shell {
    /// Runs a command and returns (exit code, combined output). Never throws.
    static func run(_ path: String, _ args: [String]) -> (code: Int32, output: String) {
        guard FileManager.default.isExecutableFile(atPath: path) else { return (-1, "") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    static var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    static func findBinary(_ name: String) -> String? {
        ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func appExists(_ name: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/Applications/\(name).app", "\(home)/Applications/\(name).app"]
            .contains { FileManager.default.fileExists(atPath: $0) }
    }

    static func openApp(_ name: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for path in ["/Applications/\(name).app", "\(home)/Applications/\(name).app"]
        where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            return
        }
    }

    /// Opens Terminal and runs one command there. Used when an installer needs the admin password,
    /// so the password is typed into Terminal and never into Cloak.
    static func runInTerminal(_ command: String) {
        let name = "cloak-\(UUID().uuidString.prefix(8)).command"
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let script = """
        #!/bin/zsh
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
        echo "Cloak is running: \(command)"
        echo
        \(command)
        echo
        echo "Finished. Go back to Cloak and click Check again. You can close this window."
        """
        do {
            try script.write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
            NSWorkspace.shared.open(file)
        } catch {
            NSSound.beep()
        }
    }
}

/// Streams a Homebrew command into the install console.
final class BrewRunner: ObservableObject {
    @Published var output: String = ""
    @Published var running: Bool = false
    @Published var exitCode: Int32? = nil

    private var process: Process?

    func run(brew: String, args: [String], completion: @escaping (Bool) -> Void) {
        guard !running else { return }
        output = "$ brew \(args.joined(separator: " "))\n"
        running = true
        exitCode = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brew)
        process.arguments = args
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["NONINTERACTIVE"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.output += text }
        }
        process.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            let status = finished.terminationStatus
            DispatchQueue.main.async {
                self?.running = false
                self?.exitCode = status
                completion(status == 0)
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            running = false
            exitCode = -1
            output += "Could not start Homebrew: \(error.localizedDescription)\n"
            completion(false)
        }
    }

    func stop() {
        process?.terminate()
    }
}

// MARK: - System audit (the "Benchmark" tab)

struct AuditCheck: Identifiable {
    let id: String
    let title: String
    let detail: String
    let command: String
    let args: [String]
    let passTokens: [String]
    let fix: StepAction
    let fixLabel: String
}

enum Audit {
    static let points = 15

    static let checks: [AuditCheck] = [
        AuditCheck(
            id: "filevault", title: "FileVault",
            detail: "The internal disk is encrypted at rest.",
            command: "/usr/bin/fdesetup", args: ["status"], passTokens: ["FileVault is On"],
            fix: .settings("x-apple.systempreferences:com.apple.preference.security?FileVault"),
            fixLabel: "Open FileVault"
        ),
        AuditCheck(
            id: "firewall", title: "macOS Firewall",
            detail: "Incoming connections are filtered.",
            command: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"],
            passTokens: ["is enabled", "State = 1", "State = 2"],
            fix: .settings("x-apple.systempreferences:com.apple.Network-Settings.extension?Firewall"),
            fixLabel: "Open Firewall"
        ),
        AuditCheck(
            id: "stealth", title: "Stealth Mode",
            detail: "The Mac does not answer network probes such as ping.",
            command: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"],
            passTokens: ["is on", "mode enabled"],
            fix: .settings("x-apple.systempreferences:com.apple.Network-Settings.extension?Firewall"),
            fixLabel: "Firewall > Options"
        ),
        AuditCheck(
            id: "gatekeeper", title: "Gatekeeper",
            detail: "Only signed and notarized apps can run.",
            command: "/usr/sbin/spctl", args: ["--status"], passTokens: ["assessments enabled"],
            fix: .settings("x-apple.systempreferences:com.apple.preference.security"),
            fixLabel: "Open Security"
        ),
        AuditCheck(
            id: "sip", title: "System Integrity Protection",
            detail: "System files are protected, even from the admin user.",
            command: "/usr/bin/csrutil", args: ["status"], passTokens: ["status: enabled"],
            fix: .open(URL(string: "https://support.apple.com/102149")!),
            fixLabel: "Apple guide"
        )
    ]

    static func run(_ check: AuditCheck) -> Bool {
        let result = Shell.run(check.command, check.args)
        return check.passTokens.contains { result.output.localizedCaseInsensitiveContains($0) }
    }
}
