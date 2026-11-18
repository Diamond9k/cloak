import SwiftUI

// MARK: - Categories (the "hardware cards" on the Harden screen)

enum Area: String, CaseIterable, Identifiable, Codable {
    case network, browser, identity, comms, data, system, devices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network:  return "Network Shield"
        case .browser:  return "Browser & Search"
        case .identity: return "Identity & Accounts"
        case .comms:    return "Communications"
        case .data:     return "Data Encryption"
        case .system:   return "System Hardening"
        case .devices:  return "Other Devices"
        }
    }

    var symbol: String {
        switch self {
        case .network:  return "network.badge.shield.half.filled"
        case .browser:  return "globe"
        case .identity: return "key.horizontal.fill"
        case .comms:    return "bubble.left.and.bubble.right.fill"
        case .data:     return "lock.doc.fill"
        case .system:   return "cpu.fill"
        case .devices:  return "iphone.gen3"
        }
    }

    /// Hero gradient for Tool Hub cards (like Hypertune's game art headers).
    var hero: [Color] {
        switch self {
        case .network:  return [Color(hex: 0x3A1061), Color(hex: 0xB0157A)]
        case .browser:  return [Color(hex: 0x0E3A5C), Color(hex: 0x1F8FBF)]
        case .identity: return [Color(hex: 0x4A2A05), Color(hex: 0xD98A12)]
        case .comms:    return [Color(hex: 0x0B2E6B), Color(hex: 0x3A76F0)]
        case .data:     return [Color(hex: 0x123F2A), Color(hex: 0x2FB57A)]
        case .system:   return [Color(hex: 0x3B0F14), Color(hex: 0xD2354A)]
        case .devices:  return [Color(hex: 0x23233A), Color(hex: 0x7A7AA8)]
        }
    }
}

// MARK: - Profiles (like Stock / Tuned: how far the guided run goes)

enum Profile: String, CaseIterable, Codable, Identifiable {
    case essential, hardened, maximum
    var id: String { rawValue }
    var title: String {
        switch self {
        case .essential: return "Essential"
        case .hardened: return "Hardened"
        case .maximum: return "Maximum"
        }
    }
    var rank: Int {
        switch self {
        case .essential: return 0
        case .hardened: return 1
        case .maximum: return 2
        }
    }
    var blurb: String {
        switch self {
        case .essential: return "The 7 steps that stop most real attacks."
        case .hardened: return "Adds VPN, private email, firewall and encryption."
        case .maximum: return "Every subject, including Tor, Tails and GrapheneOS."
        }
    }
}

// MARK: - How a tool exists on macOS

enum MacSupport {
    case native            // .app for macOS
    case appStore          // Mac App Store
    case browserExtension  // lives inside a browser
    case cli               // command-line tool
    case web               // a website or a setting, nothing to install
    case external(String)  // installed on another device, the Mac only helps
    case notOnMac(String)  // no macOS build; reason

    var label: String {
        switch self {
        case .native: return "macOS app"
        case .appStore: return "App Store"
        case .browserExtension: return "Extension"
        case .cli: return "CLI"
        case .web: return "Web / setting"
        case .external: return "Other device"
        case .notOnMac: return "Not on Mac"
        }
    }

    var isAvailable: Bool {
        if case .notOnMac = self { return false }
        return true
    }
}

enum Brew {
    case cask(String)
    case formula(String)

    var command: String {
        switch self {
        case .cask(let n): return "brew install --cask \(n)"
        case .formula(let n): return "brew install \(n)"
        }
    }
    var args: [String] {
        switch self {
        case .cask(let n): return ["install", "--cask", n]
        case .formula(let n): return ["install", n]
        }
    }
    var uninstallArgs: [String] {
        switch self {
        case .cask(let n): return ["uninstall", "--cask", n]
        case .formula(let n): return ["uninstall", n]
        }
    }
}

/// How Cloak detects that a tool is in place.
enum Probe {
    case app([String])                       // bundle names in /Applications or ~/Applications
    case binary([String])                    // executables in common bin paths
    case shell(String, [String], String)     // run command, success if output contains token
    case manual                              // user confirms
}

enum StepAction {
    case open(URL)
    case settings(String) // x-apple.systempreferences URL
}

struct GuideStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    var action: StepAction? = nil
    var actionLabel: String? = nil
}

struct ToolOption: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let support: MacSupport
    var probe: Probe = .manual
    var brew: Brew? = nil
    /// Installer asks for the admin password, so it must run in Terminal.
    var needsTerminal: Bool = false
    let url: URL
    var verify: String = "Download only from the official link above. When macOS opens the app the first time, confirm the developer name in the Gatekeeper prompt."
    var configure: [GuideStep] = []
}

struct Topic: Identifiable {
    let id: String
    let title: String
    let category: Area
    let tier: Profile
    let symbol: String
    let summary: String
    let why: String
    var cautions: [String] = []
    let weight: Int
    let recommended: String   // ToolOption.id
    let options: [ToolOption]

    var recommendedOption: ToolOption? { options.first { $0.id == recommended } }
}

// MARK: - Progress state (persisted)

enum SubjectStatus: String, Codable {
    case notStarted, inProgress, done, skipped

    var label: String {
        switch self {
        case .notStarted: return "Not started"
        case .inProgress: return "In progress"
        case .done: return "Protected"
        case .skipped: return "Skipped"
        }
    }
}

struct SubjectProgress: Codable {
    var status: SubjectStatus = .notStarted
    var chosenOption: String? = nil
    var completedSteps: Set<Int> = []
    var updated: Date = .now
}

struct LogEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let title: String
    let detail: String
    /// If set, Restore can undo this with `brew uninstall`.
    var brewUninstall: [String]? = nil
}

enum NavItem: String, CaseIterable, Identifiable {
    case home, harden, audit, cleanup, customize, hub, restore, help, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .harden: return "Harden"
        case .audit: return "Audit"
        case .cleanup: return "Cleanup"
        case .customize: return "Customize"
        case .hub: return "Tool Hub"
        case .restore: return "Restore"
        case .help: return "Help"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .harden: return "bolt.shield"
        case .audit: return "gauge.with.dots.needle.33percent"
        case .cleanup: return "internaldrive"
        case .customize: return "square.and.pencil"
        case .hub: return "square.grid.2x2"
        case .restore: return "clock.arrow.circlepath"
        case .help: return "headphones"
        case .settings: return "gearshape"
        }
    }

    static var top: [NavItem] { [.home, .harden, .audit, .cleanup, .customize, .hub] }
    static var bottom: [NavItem] { [.restore, .help, .settings] }
}
