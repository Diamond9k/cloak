import Foundation

private func u(_ string: String) -> URL { URL(string: string)! }

private let paneSecurity = "x-apple.systempreferences:com.apple.preference.security"
private let paneFileVault = "x-apple.systempreferences:com.apple.preference.security?FileVault"
private let paneNetwork = "x-apple.systempreferences:com.apple.Network-Settings.extension"
private let paneAnalytics = "x-apple.systempreferences:com.apple.preference.security?Privacy_Analytics"

/// Every subject from the stack, in the order the guided setup runs them.
/// Order = highest protection for least effort first.
enum Catalog {

    // MARK: 1. Password manager
    private static let passwordsTopic: Topic = Topic(
            id: "passwords",
            title: "Password Manager",
            category: .identity,
            tier: .essential,
            symbol: "key.horizontal.fill",
            summary: "One strong, unique password per account.",
            why: "Reused passwords are the most common way accounts get taken over. A manager makes every password unique and fills them for you.",
            cautions: ["Write the master password on paper and keep it somewhere safe. If you lose it, no one can recover the vault."],
            weight: 30,
            recommended: "bitwarden",
            options: [
                ToolOption(
                    id: "bitwarden", name: "Bitwarden",
                    tagline: "Cloud sync across Mac, phone and browser. Open source.",
                    support: .native, probe: .app(["Bitwarden"]), brew: .cask("bitwarden"),
                    url: u("https://bitwarden.com/download/"),
                    configure: [
                        GuideStep(title: "Create the account", detail: "Use a long passphrase (4 or more random words) as the master password."),
                        GuideStep(title: "Add the browser extension", detail: "Install the Bitwarden extension in the browser you use each day.", action: .open(u("https://bitwarden.com/download/#downloads-web-browser")), actionLabel: "Get extension"),
                        GuideStep(title: "Import old passwords", detail: "Export from Safari or Chrome, import into Bitwarden, then delete the export file."),
                        GuideStep(title: "Turn on two-step login", detail: "Settings > Security > Two-step login. Use the authenticator from the next subject.")
                    ]
                ),
                ToolOption(
                    id: "keepassxc", name: "KeePassXC",
                    tagline: "Fully offline. The vault is one encrypted file that you control.",
                    support: .native, probe: .app(["KeePassXC"]), brew: .cask("keepassxc"),
                    url: u("https://keepassxc.org/download/"),
                    configure: [
                        GuideStep(title: "Create a database", detail: "Pick a long passphrase. Keep the default encryption settings."),
                        GuideStep(title: "Back up the .kdbx file", detail: "Store a copy on a second drive. There is no cloud recovery."),
                        GuideStep(title: "Connect the browser", detail: "Tools > Settings > Browser Integration, then install the KeePassXC-Browser extension.")
                    ]
                )
            ]
    )

    // MARK: 2. 2FA
    private static let twofaTopic: Topic = Topic(
            id: "twofa",
            title: "2FA Authenticator",
            category: .identity,
            tier: .essential,
            symbol: "lock.rotation",
            summary: "A second code that a stolen password cannot pass.",
            why: "With 2FA on, a leaked password is not enough to sign in. App codes are much safer than SMS codes.",
            cautions: ["Save the backup codes for each account inside your password manager."],
            weight: 25,
            recommended: "ente",
            options: [
                ToolOption(
                    id: "ente", name: "Ente Auth",
                    tagline: "Encrypted sync, with a native Mac app and phone apps.",
                    support: .native, probe: .app(["Ente Auth"]), brew: .cask("ente-auth"),
                    url: u("https://ente.io/auth/"),
                    configure: [
                        GuideStep(title: "Install on your phone too", detail: "Sign in with the same account so codes sync to both devices."),
                        GuideStep(title: "Move your key accounts first", detail: "Email, password manager, Apple ID, GitHub, bank. Scan each QR code in the account security page."),
                        GuideStep(title: "Remove SMS 2FA where possible", detail: "After the app code works, remove the phone number as a sign-in method.")
                    ]
                ),
                ToolOption(
                    id: "twofas", name: "2FAS",
                    tagline: "Phone app. The Mac only gets a browser extension that asks the phone.",
                    support: .browserExtension, probe: .manual,
                    url: u("https://2fas.com/"),
                    configure: [
                        GuideStep(title: "Install 2FAS on your phone", detail: "The codes live on the phone. There is no Mac app."),
                        GuideStep(title: "Pair the browser extension", detail: "Install the 2FAS extension and scan its QR code with the phone app.", action: .open(u("https://2fas.com/browser-extension/")), actionLabel: "Get extension"),
                        GuideStep(title: "Turn on backup", detail: "Enable the encrypted backup in the phone app so a lost phone does not lock you out.")
                    ]
                )
            ]
    )

    // MARK: 3. Encrypted DNS
    private static let dnsTopic: Topic = Topic(
            id: "dns",
            title: "Encrypted DNS",
            category: .network,
            tier: .essential,
            symbol: "server.rack",
            summary: "Hide the list of sites you look up from the network.",
            why: "Normal DNS sends every domain you visit in plain text. Encrypted DNS hides it from the Wi-Fi owner and can block trackers for every app.",
            cautions: ["A VPN uses its own DNS while connected. That is normal and not a leak."],
            weight: 20,
            recommended: "nextdns",
            options: [
                ToolOption(
                    id: "nextdns", name: "NextDNS",
                    tagline: "Encrypted DNS with blocklists and a dashboard that you control.",
                    support: .web, probe: .app(["NextDNS"]),
                    url: u("https://my.nextdns.io/"),
                    verify: "Open test.nextdns.io after setup. It must show \"status: ok\" and your profile ID.",
                    configure: [
                        GuideStep(title: "Create a profile", detail: "Sign up, then copy your profile ID from the Setup tab.", action: .open(u("https://my.nextdns.io/")), actionLabel: "Open NextDNS"),
                        GuideStep(title: "Install the Apple profile", detail: "Generate a signed configuration profile, download it, then approve it in System Settings > General > Device Management.", action: .open(u("https://apple.nextdns.io/")), actionLabel: "Profile generator"),
                        GuideStep(title: "Add blocklists", detail: "Privacy tab: add the OISD and the NextDNS Ads & Trackers lists. Do not add many lists; that causes site breakage."),
                        GuideStep(title: "Test it", detail: "The test page must show status ok.", action: .open(u("https://test.nextdns.io/")), actionLabel: "Run test")
                    ]
                ),
                ToolOption(
                    id: "quad9", name: "Quad9",
                    tagline: "No account. Blocks known malware domains. Non-profit.",
                    support: .web, probe: .manual,
                    url: u("https://docs.quad9.net/"),
                    verify: "Open on.quad9.net after setup. It must say YES, you are using Quad9.",
                    configure: [
                        GuideStep(title: "Install the Quad9 profile", detail: "Download the macOS configuration profile from the Quad9 setup guide, then approve it in System Settings > General > Device Management.", action: .open(u("https://docs.quad9.net/")), actionLabel: "Setup guide"),
                        GuideStep(title: "Test it", detail: "The test page must confirm Quad9.", action: .open(u("https://on.quad9.net/")), actionLabel: "Run test")
                    ]
                )
            ]
    )

    // MARK: 4. Hardened browser
    private static let browserTopic: Topic = Topic(
            id: "browser",
            title: "Hardened Browser",
            category: .browser,
            tier: .essential,
            symbol: "globe",
            summary: "A browser that blocks tracking by default.",
            why: "The browser is where most tracking happens. A hardened browser blocks trackers, fingerprinting and cross-site cookies without extra work.",
            weight: 25,
            recommended: "brave",
            options: [
                ToolOption(
                    id: "brave", name: "Brave",
                    tagline: "Best for daily use. Chromium-based, so all sites work.",
                    support: .native, probe: .app(["Brave Browser"]), brew: .cask("brave-browser"),
                    url: u("https://brave.com/download/"),
                    configure: [
                        GuideStep(title: "Set Shields to Aggressive", detail: "Settings > Shields > Trackers & ads blocking: Aggressive."),
                        GuideStep(title: "Turn off the extras", detail: "Disable Brave Rewards, Wallet, Leo and usage pings in Settings."),
                        GuideStep(title: "Make it the default", detail: "Settings > Get started > Make default.")
                    ]
                ),
                ToolOption(
                    id: "mullvad-browser", name: "Mullvad Browser",
                    tagline: "Tor Browser without Tor. Strongest anti-fingerprinting. No saved logins.",
                    support: .native, probe: .app(["Mullvad Browser"]), brew: .cask("mullvad-browser"),
                    url: u("https://mullvad.net/browser"),
                    configure: [
                        GuideStep(title: "Do not change the settings", detail: "It protects you by making all users look the same. Extra extensions or settings make you stand out."),
                        GuideStep(title: "Use it with a VPN", detail: "It hides the browser fingerprint. A VPN hides the IP address. Use both together.")
                    ]
                ),
                ToolOption(
                    id: "librewolf", name: "LibreWolf",
                    tagline: "Firefox with telemetry removed and privacy settings preset.",
                    support: .native, probe: .app(["LibreWolf"]), brew: .cask("librewolf"),
                    url: u("https://librewolf.net/installation/macos/"),
                    configure: [
                        GuideStep(title: "Keep uBlock Origin on", detail: "LibreWolf ships with uBlock Origin installed."),
                        GuideStep(title: "Plan the updates", detail: "LibreWolf does not update itself. Update it with Homebrew: brew upgrade --cask librewolf.")
                    ]
                )
            ]
    )

    // MARK: 5. Content blocker
    private static let blockerTopic: Topic = Topic(
            id: "blocker",
            title: "Content Blocker",
            category: .browser,
            tier: .essential,
            symbol: "hand.raised.fill",
            summary: "Block ads, trackers and malicious scripts.",
            why: "Ads and trackers are a main channel for profiling and malware. One good blocker is enough.",
            cautions: ["Use one blocker only. Two blockers conflict and make the browser easier to fingerprint."],
            weight: 15,
            recommended: "ublock",
            options: [
                ToolOption(
                    id: "ublock", name: "uBlock Origin",
                    tagline: "The standard. Built into LibreWolf and Mullvad Browser.",
                    support: .browserExtension, probe: .manual,
                    url: u("https://ublockorigin.com/"),
                    verify: "Install only from the official Firefox add-ons page or the link on ublockorigin.com. Copies with similar names are common.",
                    configure: [
                        GuideStep(title: "LibreWolf or Mullvad Browser", detail: "It is already installed. Do nothing."),
                        GuideStep(title: "Brave", detail: "Brave Shields does the same job. Do not add a second blocker."),
                        GuideStep(title: "Firefox", detail: "Install uBlock Origin from the Mozilla add-ons page.", action: .open(u("https://addons.mozilla.org/firefox/addon/ublock-origin/")), actionLabel: "Mozilla add-ons"),
                        GuideStep(title: "Chrome", detail: "Chrome now only allows uBlock Origin Lite, which is weaker. Change browser instead.")
                    ]
                )
            ]
    )

    // MARK: 6. Messaging
    private static let messagingTopic: Topic = Topic(
            id: "messaging",
            title: "Encrypted Messaging",
            category: .comms,
            tier: .essential,
            symbol: "bubble.left.and.bubble.right.fill",
            summary: "Messages and calls that only you and the other person can read.",
            why: "Signal encrypts messages, calls and attachments end to end and keeps almost no metadata.",
            weight: 20,
            recommended: "signal",
            options: [
                ToolOption(
                    id: "signal", name: "Signal",
                    tagline: "End-to-end encrypted by default. The Mac app links to your phone.",
                    support: .native, probe: .app(["Signal"]), brew: .cask("signal"),
                    url: u("https://signal.org/download/"),
                    configure: [
                        GuideStep(title: "Install Signal on your phone first", detail: "The account is made on the phone. The Mac app is a linked device."),
                        GuideStep(title: "Link the Mac", detail: "Open Signal on the Mac and scan the QR code from the phone: Settings > Linked devices."),
                        GuideStep(title: "Set a username and hide your number", detail: "Settings > Privacy > Phone number: Nobody can see or find me by number."),
                        GuideStep(title: "Turn on disappearing messages", detail: "Settings > Privacy > Default timer. Four weeks is a good default.")
                    ]
                )
            ]
    )

    // MARK: 7. Disk encryption
    private static let diskTopic: Topic = Topic(
            id: "disk",
            title: "Disk Encryption",
            category: .data,
            tier: .essential,
            symbol: "internaldrive.fill",
            summary: "A lost or stolen Mac shows nothing without your password.",
            why: "Without disk encryption, anyone with the hardware can read the files. On a Mac the correct tool for the internal disk is FileVault. VeraCrypt is for external drives and containers.",
            cautions: ["VeraCrypt cannot encrypt the macOS system disk. Use FileVault for that."],
            weight: 30,
            recommended: "filevault",
            options: [
                ToolOption(
                    id: "filevault", name: "FileVault (built in)",
                    tagline: "Apple full-disk encryption. Free, fast, and tied to the Secure Enclave.",
                    support: .web, probe: .shell("/usr/bin/fdesetup", ["status"], "FileVault is On"),
                    url: u("https://support.apple.com/guide/mac-help/protect-data-on-your-mac-with-filevault-mh11785/mac"),
                    verify: "Cloak reads the FileVault state directly from macOS.",
                    configure: [
                        GuideStep(title: "Turn on FileVault", detail: "System Settings > Privacy & Security > FileVault > Turn On.", action: .settings(paneFileVault), actionLabel: "Open settings"),
                        GuideStep(title: "Save the recovery key", detail: "Choose a recovery key and not iCloud unlock. Store the key in your password manager and on paper.")
                    ]
                ),
                ToolOption(
                    id: "veracrypt", name: "VeraCrypt",
                    tagline: "Encrypted containers and USB drives that also open on Windows and Linux.",
                    support: .native, probe: .app(["VeraCrypt"]), brew: .cask("veracrypt"), needsTerminal: true,
                    url: u("https://veracrypt.io/en/Downloads.html"),
                    configure: [
                        GuideStep(title: "Install macFUSE first", detail: "VeraCrypt needs macFUSE on a Mac. macOS will ask you to allow a system extension and restart.", action: .open(u("https://macfuse.github.io/")), actionLabel: "Get macFUSE"),
                        GuideStep(title: "Create a volume", detail: "Create Volume > encrypted file container. Use AES and a long passphrase."),
                        GuideStep(title: "Always dismount", detail: "Dismount the volume before you remove the drive or sleep the Mac.")
                    ]
                )
            ]
    )

    // MARK: 8. VPN
    private static let vpnTopic: Topic = Topic(
            id: "vpn",
            title: "VPN",
            category: .network,
            tier: .hardened,
            symbol: "network.badge.shield.half.filled",
            summary: "Hide your IP address from sites and your traffic from the network.",
            why: "A VPN moves trust from the Wi-Fi owner and internet provider to the VPN company. It hides your IP address from websites. It does not make you anonymous.",
            cautions: ["Run one VPN at a time.", "A VPN does not stop tracking by cookies, logins or browser fingerprint."],
            weight: 25,
            recommended: "mullvad",
            options: [
                ToolOption(
                    id: "mullvad", name: "Mullvad VPN",
                    tagline: "No email, no name. A fixed price. You can pay in cash.",
                    support: .native, probe: .app(["Mullvad VPN"]), brew: .cask("mullvad-vpn"), needsTerminal: true,
                    url: u("https://mullvad.net/download/vpn/macos"),
                    configure: [
                        GuideStep(title: "Create an account number", detail: "Mullvad gives you a 16-digit number. Store it in your password manager.", action: .open(u("https://mullvad.net/account/create")), actionLabel: "Create account"),
                        GuideStep(title: "Turn on Lockdown mode", detail: "Settings > VPN settings > Lockdown mode. It blocks all traffic if the VPN drops."),
                        GuideStep(title: "Turn on DNS content blockers", detail: "Settings > DNS content blockers: Ads, Trackers, Malware."),
                        GuideStep(title: "Check the connection", detail: "The check page must show that you use Mullvad with no leaks.", action: .open(u("https://mullvad.net/check")), actionLabel: "Run check")
                    ]
                ),
                ToolOption(
                    id: "proton-vpn", name: "Proton VPN",
                    tagline: "Has a free plan. One account also covers Proton Mail.",
                    support: .native, probe: .app(["ProtonVPN", "Proton VPN"]), brew: .cask("protonvpn"),
                    url: u("https://protonvpn.com/download-macos"),
                    configure: [
                        GuideStep(title: "Sign in", detail: "Use the same Proton account as your email if you choose Proton Mail."),
                        GuideStep(title: "Turn on Kill Switch", detail: "Settings > Connection > Kill Switch."),
                        GuideStep(title: "Turn on NetShield", detail: "Blocks malware, ads and trackers at DNS level (paid plans)."),
                        GuideStep(title: "Check for leaks", detail: "Your real IP and DNS servers must not show.", action: .open(u("https://dnsleaktest.com/")), actionLabel: "Run check")
                    ]
                )
            ]
    )

    // MARK: 9. Encrypted email
    private static let emailTopic: Topic = Topic(
            id: "email",
            title: "Encrypted Email",
            category: .comms,
            tier: .hardened,
            symbol: "envelope.badge.shield.half.filled.fill",
            summary: "A mailbox that the provider cannot read.",
            why: "Most providers can read and scan your mail. These providers store it encrypted with a key that only you hold.",
            cautions: ["Mail to a normal address (Gmail, Outlook) is still readable on the other side."],
            weight: 20,
            recommended: "proton-mail",
            options: [
                ToolOption(
                    id: "proton-mail", name: "Proton Mail",
                    tagline: "Largest private mail service. Mac app, calendar, drive and VPN.",
                    support: .native, probe: .app(["Proton Mail"]), brew: .cask("proton-mail"),
                    url: u("https://proton.me/mail/download"),
                    configure: [
                        GuideStep(title: "Create the address", detail: "Do not put your full name in the address if you want it to stay unlinked."),
                        GuideStep(title: "Turn on 2FA", detail: "Settings > Account and password > Two-factor authentication."),
                        GuideStep(title: "Move accounts in order", detail: "Bank and password manager first, then the rest over a few weeks. Keep the old mailbox open for a while.")
                    ]
                ),
                ToolOption(
                    id: "tuta", name: "Tuta",
                    tagline: "Encrypts subject lines too. Simple and lower cost.",
                    support: .native, probe: .app(["Tuta Mail"]), brew: .cask("tuta-mail"),
                    url: u("https://tuta.com/"),
                    configure: [
                        GuideStep(title: "Create the address", detail: "Save the recovery code in your password manager. Tuta cannot reset the password without it."),
                        GuideStep(title: "Turn on 2FA", detail: "Settings > Login > Second factor authentication.")
                    ]
                )
            ]
    )

    // MARK: 10. Email aliases
    private static let aliasesTopic: Topic = Topic(
            id: "aliases",
            title: "Email Aliases",
            category: .identity,
            tier: .hardened,
            symbol: "at.badge.plus",
            summary: "A different address for each site, all sent to one inbox.",
            why: "Your email address is the key that data brokers use to join your accounts. Aliases break that link, and you can turn off one alias when it gets spam.",
            weight: 15,
            recommended: "simplelogin",
            options: [
                ToolOption(
                    id: "simplelogin", name: "SimpleLogin",
                    tagline: "Owned by Proton. Included with paid Proton plans.",
                    support: .web, probe: .manual,
                    url: u("https://simplelogin.io/"),
                    configure: [
                        GuideStep(title: "Create the account", detail: "Sign in with Proton if you use Proton Mail.", action: .open(u("https://app.simplelogin.io/")), actionLabel: "Open SimpleLogin"),
                        GuideStep(title: "Add the browser extension", detail: "It makes a new alias from any sign-up form."),
                        GuideStep(title: "Use a new alias for each new account", detail: "Change old accounts over time. Start with shops and newsletters.")
                    ]
                ),
                ToolOption(
                    id: "addy", name: "Addy.io",
                    tagline: "Independent and open source. Generous free plan.",
                    support: .web, probe: .manual,
                    url: u("https://addy.io/"),
                    configure: [
                        GuideStep(title: "Create the account", detail: "Add your real mailbox as the recipient and verify it.", action: .open(u("https://app.addy.io/")), actionLabel: "Open Addy.io"),
                        GuideStep(title: "Add the browser extension", detail: "It makes a new alias from any sign-up form.")
                    ]
                )
            ]
    )

    // MARK: 11. Application firewall
    private static let firewallTopic: Topic = Topic(
            id: "firewall",
            title: "Application Firewall",
            category: .network,
            tier: .hardened,
            symbol: "flame.fill",
            summary: "See and control which apps connect to the internet.",
            why: "The built-in macOS firewall only filters incoming connections. An application firewall shows each outgoing connection and lets you block it.",
            cautions: ["Portmaster and Simplewall have no macOS version. LuLu is the free open source Mac equivalent, so Cloak adds it.", "Run one application firewall only."],
            weight: 20,
            recommended: "lulu",
            options: [
                ToolOption(
                    id: "lulu", name: "LuLu",
                    tagline: "Free and open source, from Objective-See. Simple allow or block prompts.",
                    support: .native, probe: .app(["LuLu"]), brew: .cask("lulu"),
                    url: u("https://objective-see.org/products/lulu.html"),
                    configure: [
                        GuideStep(title: "Allow the system extension", detail: "macOS asks you to allow LuLu in System Settings > General > Login Items & Extensions > Network Extensions.", action: .settings(paneSecurity), actionLabel: "Open settings"),
                        GuideStep(title: "Keep the default rules", detail: "Allow Apple programs and already installed apps. This keeps the first day quiet."),
                        GuideStep(title: "Answer prompts for a week", detail: "Block what you do not recognize. You can change any rule later.")
                    ]
                ),
                ToolOption(
                    id: "little-snitch", name: "Little Snitch",
                    tagline: "Paid. Most detail: live traffic map, rule groups, blocklists.",
                    support: .native, probe: .app(["Little Snitch"]), brew: .cask("little-snitch"), needsTerminal: true,
                    url: u("https://obdev.at/products/littlesnitch/"),
                    configure: [
                        GuideStep(title: "Allow the network extension", detail: "Approve it in System Settings when macOS asks."),
                        GuideStep(title: "Start in Silent Mode: Allow", detail: "Let it record for a few days, then review the connections and make rules."),
                        GuideStep(title: "Add a blocklist", detail: "Rules > Blocklists. Add one tracker list.")
                    ]
                ),
                ToolOption(
                    id: "portmaster", name: "Portmaster",
                    tagline: "Windows and Linux only.",
                    support: .notOnMac("Safing states that Portmaster is not available for macOS. Use LuLu or Little Snitch."),
                    url: u("https://docs.safing.io/portmaster/install/status/mac")
                ),
                ToolOption(
                    id: "simplewall", name: "Simplewall",
                    tagline: "Windows only.",
                    support: .notOnMac("Simplewall configures the Windows Filtering Platform. It cannot run on macOS. Use LuLu or Little Snitch."),
                    url: u("https://github.com/henrypp/simplewall")
                )
            ]
    )

    // MARK: 12. Private search
    private static let searchTopic: Topic = Topic(
            id: "search",
            title: "Private Search",
            category: .browser,
            tier: .hardened,
            symbol: "magnifyingglass",
            summary: "Search that does not build a profile on you.",
            why: "Search history shows health, money and plans. A private engine does not tie searches to an identity.",
            weight: 10,
            recommended: "brave-search",
            options: [
                ToolOption(
                    id: "brave-search", name: "Brave Search",
                    tagline: "Its own index. No account. Works in any browser.",
                    support: .web, probe: .manual,
                    url: u("https://search.brave.com/"),
                    configure: [
                        GuideStep(title: "Set it as the default engine", detail: "In your browser settings, go to Search engine and choose Brave. In other browsers, add search.brave.com.", action: .open(u("https://search.brave.com/")), actionLabel: "Open Brave Search"),
                        GuideStep(title: "Turn off usage metrics", detail: "Search settings > Anonymous usage metrics: off.")
                    ]
                ),
                ToolOption(
                    id: "searxng", name: "SearXNG",
                    tagline: "Open source metasearch. Best when you host it yourself.",
                    support: .web, probe: .manual,
                    url: u("https://searx.space/"),
                    verify: "A public instance can see your searches. Pick one with a good rating on searx.space, or host your own.",
                    configure: [
                        GuideStep(title: "Pick an instance", detail: "Choose a public instance with an A grade and low response time.", action: .open(u("https://searx.space/")), actionLabel: "Instance list"),
                        GuideStep(title: "Or host your own", detail: "If you have a home server, run the official Docker image. Then only you can see the queries.", action: .open(u("https://docs.searxng.org/admin/installation-docker.html")), actionLabel: "Docker guide"),
                        GuideStep(title: "Set it as the default engine", detail: "Add the instance URL as a custom search engine in your browser.")
                    ]
                )
            ]
    )

    // MARK: 13. Cloud encryption
    private static let cloudTopic: Topic = Topic(
            id: "cloud",
            title: "Cloud Encryption",
            category: .data,
            tier: .hardened,
            symbol: "lock.icloud.fill",
            summary: "Encrypt files before they reach iCloud, Drive or Dropbox.",
            why: "Cloud providers can read what you store. Cryptomator encrypts each file on the Mac, so the provider only holds scrambled data.",
            weight: 15,
            recommended: "cryptomator",
            options: [
                ToolOption(
                    id: "cryptomator", name: "Cryptomator",
                    tagline: "Open source vaults that work with any cloud folder.",
                    support: .native, probe: .app(["Cryptomator"]), brew: .cask("cryptomator"),
                    url: u("https://cryptomator.org/downloads/"),
                    configure: [
                        GuideStep(title: "Create a vault in your cloud folder", detail: "Add Vault > Create New Vault. Put it inside the iCloud Drive, Google Drive or Dropbox folder."),
                        GuideStep(title: "Save the recovery key", detail: "Store it in your password manager. Without it a forgotten password loses the vault."),
                        GuideStep(title: "Move sensitive files in", detail: "Tax files, IDs, contracts. Unlock the vault and drag the files to the mounted drive.")
                    ]
                )
            ]
    )

    // MARK: 14. Metadata removal
    private static let metadataTopic: Topic = Topic(
            id: "metadata",
            title: "Metadata Removal",
            category: .data,
            tier: .hardened,
            symbol: "doc.badge.gearshape.fill",
            summary: "Remove hidden location, device and author data from files.",
            why: "Photos and documents carry GPS position, device model, names and edit history. Remove them before you share a file.",
            weight: 10,
            recommended: "exiftool",
            options: [
                ToolOption(
                    id: "exiftool", name: "ExifTool",
                    tagline: "Command-line tool. Cloak gives it a button in the Cleanup tab.",
                    support: .cli, probe: .binary(["exiftool"]), brew: .formula("exiftool"),
                    url: u("https://exiftool.org/"),
                    configure: [
                        GuideStep(title: "Use it from Cloak", detail: "Cleanup tab > Strip metadata. Pick files and Cloak runs ExifTool on them. The original stays next to the cleaned file."),
                        GuideStep(title: "Or from Terminal", detail: "exiftool -all= photo.jpg removes all metadata from one file.")
                    ]
                ),
                ToolOption(
                    id: "dangerzone", name: "Dangerzone",
                    tagline: "Turns a risky PDF or Office file into a safe, clean PDF.",
                    support: .native, probe: .app(["Dangerzone"]), brew: .cask("dangerzone"),
                    url: u("https://dangerzone.rocks/"),
                    configure: [
                        GuideStep(title: "Finish the first launch", detail: "Dangerzone runs conversions in a sandbox. On first launch it tells you if it needs a container runtime and sets it up."),
                        GuideStep(title: "Convert before you open", detail: "Drop any document from an unknown sender on Dangerzone. Open the safe PDF, not the original.")
                    ]
                )
            ]
    )

    // MARK: 15. Telemetry & hardening
    private static let telemetryTopic: Topic = Topic(
            id: "telemetry",
            title: "Telemetry & System Hardening",
            category: .system,
            tier: .hardened,
            symbol: "cpu.fill",
            summary: "Turn off data collection and tighten macOS defaults.",
            why: "macOS and its apps send usage data by default. privacy.sexy gives reviewed scripts that turn this off, and each one has a revert script.",
            cautions: ["Read each script before you run it. Apply a few at a time so you know what caused a change."],
            weight: 15,
            recommended: "privacy-sexy",
            options: [
                ToolOption(
                    id: "privacy-sexy", name: "privacy.sexy",
                    tagline: "Open source script library for macOS. Every change can be reverted.",
                    support: .native, probe: .app(["privacy.sexy"]),
                    url: u("https://privacy.sexy/"),
                    configure: [
                        GuideStep(title: "Turn off Apple analytics first", detail: "System Settings > Privacy & Security > Analytics & Improvements: all off.", action: .settings(paneAnalytics), actionLabel: "Open settings"),
                        GuideStep(title: "Start with the Standard set", detail: "In privacy.sexy pick macOS > Standard. Read the script it builds.", action: .open(u("https://privacy.sexy/")), actionLabel: "Open privacy.sexy"),
                        GuideStep(title: "Save the revert script", detail: "Turn on the revert switch for the same selection and save that file. It is your undo."),
                        GuideStep(title: "Run the Audit tab", detail: "Cloak checks FileVault, firewall, Gatekeeper and System Integrity Protection.")
                    ]
                )
            ]
    )

    // MARK: 16. Tor
    private static let torTopic: Topic = Topic(
            id: "tor",
            title: "Onion Routing",
            category: .network,
            tier: .maximum,
            symbol: "circle.hexagongrid.fill",
            summary: "Anonymous browsing through three encrypted relays.",
            why: "Tor hides who you are from the site and what you visit from the network. Use it for tasks that need anonymity, not for daily browsing.",
            cautions: ["Do not sign in to personal accounts in Tor Browser.", "Do not add extensions or change the window size.", "Tor over a VPN is fine. Do not route a VPN through Tor."],
            weight: 15,
            recommended: "tor-browser",
            options: [
                ToolOption(
                    id: "tor-browser", name: "Tor Browser",
                    tagline: "The only supported way to browse over Tor.",
                    support: .native, probe: .app(["Tor Browser"]), brew: .cask("tor-browser"),
                    url: u("https://www.torproject.org/download/"),
                    verify: "Download only from torproject.org. The download page shows how to verify the signature.",
                    configure: [
                        GuideStep(title: "Connect", detail: "Open Tor Browser and click Connect. Use a bridge only if Tor is blocked on your network."),
                        GuideStep(title: "Set the security level", detail: "Shield icon > Settings. Safer is a good balance. Safest turns off JavaScript."),
                        GuideStep(title: "Confirm it works", detail: "The check page must say that the browser is configured to use Tor.", action: .open(u("https://check.torproject.org/")), actionLabel: "Open check (use Tor Browser)")
                    ]
                )
            ]
    )

    // MARK: 17. System cleaner
    private static let cleanerTopic: Topic = Topic(
            id: "cleaner",
            title: "System Cleaner",
            category: .system,
            tier: .maximum,
            symbol: "sparkles",
            summary: "Clear caches, logs and browser traces.",
            why: "Caches and logs keep a record of what you did. Clearing them removes traces and frees disk space.",
            cautions: ["BleachBit support for macOS is new. There is no Mac installer yet, only the command line built from source. Cloak has a built-in cleaner for the same job."],
            weight: 5,
            recommended: "cloak-cleanup",
            options: [
                ToolOption(
                    id: "cloak-cleanup", name: "Cloak Cleanup (built in)",
                    tagline: "Scans browser caches, logs and build caches. Moves them to the Trash, so you can undo.",
                    support: .web, probe: .manual,
                    url: u("https://www.bleachbit.org/download/mac"),
                    verify: "Nothing to install. It is the Cleanup tab in this app.",
                    configure: [
                        GuideStep(title: "Open the Cleanup tab", detail: "Click Scan, select what to remove, then Clean."),
                        GuideStep(title: "Check, then empty the Trash", detail: "Cleaned items go to the Trash. Empty it after you confirm that your apps still work.")
                    ]
                ),
                ToolOption(
                    id: "bleachbit", name: "BleachBit",
                    tagline: "Early macOS support. Command line from source. No installer yet.",
                    support: .cli, probe: .binary(["bleachbit"]),
                    url: u("https://www.bleachbit.org/download/mac"),
                    verify: "Follow the build steps on the official macOS page. Do not use third-party BleachBit downloads for Mac.",
                    configure: [
                        GuideStep(title: "Build from source", detail: "The official page lists the Python steps. It needs Terminal skills.", action: .open(u("https://www.bleachbit.org/download/mac")), actionLabel: "Official steps"),
                        GuideStep(title: "Preview first", detail: "Run with --preview before --clean to see what it will delete.")
                    ]
                )
            ]
    )

    // MARK: 18. Tails
    private static let tailsTopic: Topic = Topic(
            id: "tails",
            title: "Amnesic OS",
            category: .devices,
            tier: .maximum,
            symbol: "externaldrive.fill.badge.questionmark",
            summary: "A USB system that forgets everything at shutdown.",
            why: "Tails runs from a USB stick, sends all traffic through Tor and leaves no trace on the computer.",
            cautions: ["Tails does not start on Apple silicon Macs (M1 and later). Your Mac can make the USB stick, but you must start it on an Intel or AMD computer."],
            weight: 10,
            recommended: "tails",
            options: [
                ToolOption(
                    id: "tails", name: "Tails",
                    tagline: "Made on this Mac, used on another computer.",
                    support: .external("Runs from a USB stick on an Intel or AMD computer. It does not start on this Mac."),
                    url: u("https://tails.net/install/"),
                    verify: "Download from tails.net and use the verification tool on the download page before you write the USB stick.",
                    configure: [
                        GuideStep(title: "Get a USB stick", detail: "8 GB or more. All data on it is erased."),
                        GuideStep(title: "Download and verify Tails", detail: "Follow the macOS install path on the official site.", action: .open(u("https://tails.net/install/mac/")), actionLabel: "Official guide"),
                        GuideStep(title: "Write the image", detail: "The guide uses balenaEtcher to write the image to the USB stick."),
                        GuideStep(title: "Start it on a PC", detail: "Plug the stick into an Intel or AMD computer and choose it in the boot menu.")
                    ]
                )
            ]
    )

    // MARK: 19. GrapheneOS
    private static let grapheneTopic: Topic = Topic(
            id: "graphene",
            title: "Mobile OS",
            category: .devices,
            tier: .maximum,
            symbol: "iphone.gen3",
            summary: "A hardened Android for Google Pixel phones.",
            why: "GrapheneOS removes Google from the system, hardens the phone against exploits and lets you sandbox the apps that need Google services.",
            cautions: ["It installs only on supported Google Pixel phones. It cannot be installed on an iPhone.", "Installing erases the phone."],
            weight: 10,
            recommended: "grapheneos",
            options: [
                ToolOption(
                    id: "grapheneos", name: "GrapheneOS",
                    tagline: "Installed on a Pixel from this Mac with the web installer.",
                    support: .external("Installs on a supported Google Pixel. This Mac only runs the web installer over USB."),
                    url: u("https://grapheneos.org/install/web"),
                    verify: "Use only grapheneos.org. Buy the Pixel unlocked: carrier-locked phones cannot unlock the bootloader.",
                    configure: [
                        GuideStep(title: "Check the phone", detail: "See the list of supported Pixels. Back up the phone. It will be erased.", action: .open(u("https://grapheneos.org/faq#supported-devices")), actionLabel: "Supported devices"),
                        GuideStep(title: "Use a supported browser", detail: "The web installer needs WebUSB. Use one of the browsers the install page lists. Safari and Firefox do not work."),
                        GuideStep(title: "Run the web installer", detail: "Follow each step in order: unlock bootloader, flash, lock bootloader.", action: .open(u("https://grapheneos.org/install/web")), actionLabel: "Web installer"),
                        GuideStep(title: "Lock the bootloader", detail: "Do not skip this last step. It is what makes verified boot work.")
                    ]
                )
            ]
    )
    static let subjects: [Topic] = [
        passwordsTopic, twofaTopic, dnsTopic, browserTopic,
        blockerTopic, messagingTopic, diskTopic, vpnTopic,
        emailTopic, aliasesTopic, firewallTopic, searchTopic,
        cloudTopic, metadataTopic, telemetryTopic, torTopic,
        cleanerTopic, tailsTopic, grapheneTopic
    ]

    static func subject(_ id: String) -> Topic? {
        subjects.first { $0.id == id }
    }

    static func subjects(in category: Area) -> [Topic] {
        subjects.filter { $0.category == category }
    }
}
