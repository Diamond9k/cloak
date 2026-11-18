# Cloak

A native macOS app that guides you through the install and setup of a full privacy stack, one subject at a time.

Cloak is a setup guide with a dashboard. You get a privacy score, one main button, and a five-stage wizard for each subject: password manager, 2FA, encrypted DNS, browser, VPN, disk encryption and 13 more. It installs apps with Homebrew or sends you to the official download, then gives you the setup steps that make each tool do its job.

- Built with SwiftUI. No dependencies.
- Runs on your Mac only. No account, no server, no analytics.
- Never asks for a password.
- Builds with the Xcode Command Line Tools. Full Xcode is not necessary.

## Status

Version 1.0. It builds and runs on macOS 27 with the Command Line Tools (Swift 6.4). It is new software. Read the "What Cloak does and does not do" section before you rely on it.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools: `xcode-select --install`
- Optional: [Homebrew](https://brew.sh) for one-click installs

## Build

```sh
git clone https://github.com/Diamond9k/cloak.git
cd cloak
./build.sh            # build and open Cloak.app
./build.sh install    # build, copy to /Applications, open
```

The script compiles a release build, makes the app bundle and the icon, and signs it ad hoc for your Mac.

To work on the code in Xcode: `open Package.swift`.

## The app

| Tab       | What it does |
|-----------|--------------|
| Home      | Score, next step, coverage for each area, recent activity |
| Harden    | Privacy score, profile switch, Start guided setup, one card for each area |
| Audit     | Reads FileVault, firewall, stealth mode, Gatekeeper and SIP. Links to leak tests |
| Cleanup   | Scans caches and logs and moves them to the Trash. Strips file metadata with ExifTool |
| Customize | Accent color, profile, your tool choices |
| Tool Hub  | All 19 subjects as cards with status |
| Restore   | Activity log, Homebrew uninstall, Time Machine, reset |

### The guided setup

Each subject runs the same five stages: Overview, Choose, Install, Configure, Finish.

- **Install** uses Homebrew (one click, live log) or the official download link.
- Installers that need the admin password run in Terminal, so Cloak never sees the password.
- Cloak finds installed apps in `/Applications` and marks them.
- **Finish** adds the subject weight to the score and opens the next subject.

### Profiles

| Profile   | Subjects |
|-----------|----------|
| Essential | Password manager, 2FA, encrypted DNS, hardened browser, content blocker, encrypted messaging, disk encryption |
| Hardened  | Essential, plus VPN, encrypted email, email aliases, application firewall, private search, cloud encryption, metadata removal, telemetry and system hardening |
| Maximum   | Hardened, plus onion routing, system cleaner, amnesic OS, mobile OS |

## The stack

| Subject | Tools |
|---------|-------|
| Password manager | Bitwarden, KeePassXC |
| 2FA authenticator | Ente Auth, 2FAS |
| Encrypted DNS | NextDNS, Quad9 |
| Hardened browser | Brave, Mullvad Browser, LibreWolf |
| Content blocker | uBlock Origin |
| Encrypted messaging | Signal |
| Disk encryption | FileVault, VeraCrypt |
| VPN | Mullvad VPN, Proton VPN |
| Encrypted email | Proton Mail, Tuta |
| Email aliases | SimpleLogin, Addy.io |
| Application firewall | LuLu, Little Snitch |
| Private search | Brave Search, SearXNG |
| Cloud encryption | Cryptomator |
| Metadata removal | ExifTool, Dangerzone |
| Telemetry and system hardening | privacy.sexy |
| Onion routing | Tor Browser |
| System cleaner | Cloak Cleanup (built in), BleachBit |
| Amnesic OS | Tails |
| Mobile OS | GrapheneOS |

Notes for a Mac:

- Portmaster and Simplewall have no macOS version. Cloak lists them as not available and offers LuLu and Little Snitch.
- VeraCrypt cannot encrypt the macOS system disk. Cloak uses FileVault for that and keeps VeraCrypt for containers and USB drives.
- BleachBit has early macOS support and no installer. The Cleanup tab does that job.
- Tails does not start on Apple silicon. GrapheneOS needs a Google Pixel. Cloak guides both as "other device" subjects.

## What Cloak does and does not do

- It reads system state with `fdesetup`, `socketfilterfw`, `spctl` and `csrutil`. It does not change system settings.
- It runs `brew install` only when you click the button, and it shows the command first.
- It links only to the official site of each tool.
- Cleanup moves files to the Trash. It does not delete them.
- It keeps its progress in `~/Library/Application Support/Cloak/state.json`.
- The score is a progress counter. It is not a security audit and it does not guarantee that you are safe.

## Project layout

```
Package.swift
build.sh                         build, bundle, sign
Resources/AppIcon.png
Sources/Cloak/
  CloakApp.swift                 app entry
  Theme.swift                    colors, buttons, card art
  Models/Models.swift            data types
  Models/Catalog.swift           all subjects, tools, links, Homebrew names, steps
  Services/AppState.swift        progress, score, scan, persistence
  Services/Shell.swift           process runner, Homebrew, audit checks
  Views/                         one file for each screen group
```

## Contributing

Issues and pull requests are welcome.

- To add or change a tool, edit `Sources/Cloak/Models/Catalog.swift`. Each tool needs an official URL, a detection probe and its setup steps.
- Do not use `@State`. In the macOS 27 SDK it is a macro, and its plugin comes only with full Xcode. Use an `ObservableObject` with `@StateObject`, as the views in this repo do. This keeps the build possible with the Command Line Tools alone.
- Check Homebrew cask names before you add them.
- Keep the rule that Cloak never asks for a password and never changes system settings by itself.

## Credits and disclaimer

The dashboard layout is inspired by PC tuning tools such as Hypertune. Cloak is an independent project. It is not affiliated with Hypertune, Compready, or any tool or company in the stack. All product names are the property of their owners.

## License

MIT. See [LICENSE](LICENSE).
