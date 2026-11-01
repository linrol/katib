import SwiftUI
import AppKit
import KatibKit

@main
struct KatibApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Katib MenuBar Daemon")
        ProcessInfo.processInfo.disableSuddenTermination()

        // Configure Creem Pro License SDK for Katib
        CreemLicenseManager.shared.configure(
            CreemLicenseConfig(
                appName: "Katib",
                productId: "prod_7QcjNL9GaMP6RCGo3NNENp",
                purchaseURL: URL(string: "https://www.creem.io/payment/prod_7QcjNL9GaMP6RCGo3NNENp")!,
                displayPrice: "$9.99",
                proxyBaseURL: URL(string: "https://mac-license.linrol.workers.dev")!,
                storageKey: "katib_license_info",
                isEnabled: true,
                features: [
                    ProFeatureItem(icon: "waveform.badge.magnifyingglass", color: .blue, title: "无限长时双向会议实时听写", subtitle: "突破免费会话时长限制，支持数小时高强度连续会议双向转录"),
                    ProFeatureItem(icon: "doc.text.badge.plus", color: .purple, title: "一键导出会议纪要与双语字幕", subtitle: "支持将会话导出为标准 TXT 会议纪要与 SRT 双语时间轴字幕文件"),
                    ProFeatureItem(icon: "macbook.and.iphone", color: .indigo, title: "多台 Mac 授权与终身换机迁移", subtitle: "一次买断永久授权，支持多台个人 Mac 绑定与随时解绑迁移，享受终身免费升级")
                ]
            )
        )

        Task {
            await CreemLicenseManager.shared.validateInBackground()
        }

        KatibUpdateManager.shared.startBackgroundCheck()

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: KatibMenuBarView())
        self.popover = popover

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Katib")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

struct KatibMenuBarView: View {
    @ObservedObject var manager = KatibManager.shared
    @ObservedObject var updateManager = KatibUpdateManager.shared
    @State private var isVersionCopied: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                    Text("Katib")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()

                // Pro Upgrade Pill
                CreemUpgradePill()

                Circle()
                    .fill(manager.isRunning ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(manager.isRunning ? "Listening" : "Idle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Update Banner
            if updateManager.hasUpdate || updateManager.isDownloading || updateManager.updateError != nil {
                updateBanner
            }

            Divider()

            // Settings Card
            KatibSettingsView(isCollapsible: false)

            // Live HUD Toggle
            Button(action: {
                KatibFloatingHUD.shared.toggle()
            }) {
                HStack {
                    Image(systemName: KatibFloatingHUD.shared.isVisible ? "captions.bubble.fill" : "captions.bubble")
                    Text(KatibFloatingHUD.shared.isVisible ? "Hide Live Subtitles HUD" : "Show Live Subtitles HUD")
                }
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            // Recent Transcriptions
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Recent Sentences")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !manager.recentSentences.isEmpty {
                        Button("Copy All") {
                            let text = manager.recentSentences.map { "[\($0.source.rawValue)] \($0.text)" }.joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if manager.recentSentences.isEmpty {
                            Text("No sentences recorded yet.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(manager.recentSentences) { sentence in
                                HStack(alignment: .top, spacing: 4) {
                                    Text("[\(sentence.source.rawValue)]")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(sentence.source == .remote ? .blue : .green)
                                    Text(sentence.text)
                                        .font(.system(size: 11))
                                        .lineLimit(nil)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: 110)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                )
            }

            Divider()
                .opacity(0.5)

            // Bottom Actions (Version, Check Update, Quit)
            bottomActions
        }
        .padding(14)
        .frame(width: 320)
    }

    private var appVersionString: String {
        let version = updateManager.localVersion
        let commit = updateManager.localCommit
        if !commit.isEmpty {
            return "v\(version) (\(commit))"
        }
        return "v\(version)"
    }

    private var updateBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: updateManager.hasUpdate ? "arrow.down.circle.fill" : "info.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))

                if let info = updateManager.remoteInfo {
                    Text("New update: v\(info.version)\(info.commit.isEmpty ? "" : " (\(info.commit))")")
                        .font(.system(size: 11, weight: .semibold))
                } else if let err = updateManager.updateError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if updateManager.isDownloading {
                    ProgressView()
                        .scaleEffect(0.65)
                        .frame(width: 16, height: 16)
                } else if updateManager.hasUpdate {
                    Button(action: {
                        updateManager.downloadAndInstallUpdate()
                    }) {
                        Text("Update & Restart")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                } else {
                    Button(action: {
                        updateManager.updateError = nil
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if updateManager.isDownloading {
                ProgressView(value: updateManager.downloadProgress, total: 1.0)
                    .progressViewStyle(.linear)
            } else if let msg = updateManager.remoteInfo?.message, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))
        )
    }

    private var bottomActions: some View {
        HStack(spacing: 8) {
            // Version with copy button
            Button(action: {
                let textToCopy = appVersionString
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToCopy, forType: .string)
                isVersionCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isVersionCopied = false
                }
            }) {
                Text(isVersionCopied ? "Copied!" : appVersionString)
                    .font(.system(size: 11))
                    .foregroundColor(isVersionCopied ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Click to copy version")

            // Check for updates button
            Button(action: {
                Task {
                    await updateManager.checkForUpdates(silent: false)
                }
            }) {
                if updateManager.isChecking {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(updateManager.isChecking || updateManager.isDownloading)
            .help("Check for updates")

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
}
