import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 216)

            VStack(spacing: 0) {
                HeaderBar()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.well.opacity(0.6))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(
            ZStack {
                Theme.bg
                RadialGradient(
                    colors: [state.accent.opacity(0.10), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 20,
                    endRadius: 700
                )
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: wizardBinding) {
            if let id = state.wizardSubjectID, let subject = Catalog.subject(id) {
                WizardView(subject: subject, initialOption: state.chosenOption(subject)?.id ?? subject.recommended)
                    .environmentObject(state)
                    .id(id)
            }
        }
    }

    private var wizardBinding: Binding<Bool> {
        Binding(
            get: { state.wizardSubjectID != nil },
            set: { if !$0 { state.wizardSubjectID = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch state.nav {
        case .home: HomeView()
        case .harden: HardenView()
        case .audit: AuditView()
        case .cleanup: CleanupView()
        case .customize: CustomizeView()
        case .hub: HubView()
        case .restore: RestoreView()
        case .help: HelpView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - Header

struct HeaderBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Text(state.nav.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)

            HStack(spacing: 5) {
                Image(systemName: "clock")
                if state.scanning {
                    Text("Scanning")
                } else if let date = state.lastScan {
                    Text("Scanned")
                    Text(date, style: .relative)
                    Text("ago")
                } else {
                    Text("Not scanned")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.dim)

            Spacer()

            Button {
                state.scan()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan")
                }
            }
            .buttonStyle(FlatButtonStyle(wide: false))
            .disabled(state.scanning)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .frame(height: 54)
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Space for the window traffic lights.
            Color.clear.frame(height: 30)

            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(state.accent)
                Text("CLOAK")
                    .font(.system(size: 19, weight: .heavy))
                    .tracking(2.5)
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 14)

            Button {
                state.showNotifications.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell")
                        .frame(width: 18)
                    Text("Notifications")
                    Spacer()
                    Text("\(state.notices.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(state.notices.isEmpty ? Theme.dim : state.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.dim)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.card))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $state.showNotifications, arrowEdge: .trailing) {
                NotificationsPanel()
                    .environmentObject(state)
            }
            .padding(.bottom, 12)

            ForEach(NavItem.top) { item in
                SidebarRow(item: item)
            }

            Spacer()

            ForEach(NavItem.bottom) { item in
                SidebarRow(item: item)
            }

            HStack(spacing: 8) {
                Text(NSFullUserName().isEmpty ? NSUserName() : NSFullUserName())
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.dim)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.card))
            .padding(.top, 8)
            .onTapGesture { state.nav = .settings }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }
}

struct SidebarRow: View {
    @EnvironmentObject var state: AppState
    let item: NavItem

    var body: some View {
        let active = state.nav == item
        Button {
            state.nav = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(item.title)
                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(active ? state.accent : Theme.dim)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? state.accent.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct NotificationsPanel: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(.system(size: 14, weight: .semibold))
            if state.notices.isEmpty {
                Text("Nothing needs your attention.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.notices) { notice in
                        Button {
                            state.showNotifications = false
                            if let id = notice.subjectID {
                                state.wizardSubjectID = id
                            } else if let nav = notice.nav {
                                state.nav = nav
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: notice.symbol)
                                    .foregroundStyle(notice.color)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(notice.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(notice.detail)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.dim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.cardHi))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .padding(14)
        .frame(width: 340)
    }
}
