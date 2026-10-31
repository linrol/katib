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

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 380)
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
                    Text("كَاتِب")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .foregroundColor(.secondary)
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
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                )
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}

