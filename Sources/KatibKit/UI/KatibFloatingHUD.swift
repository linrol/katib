import SwiftUI
import AppKit

/// Floating Real-time Subtitles Window Controller (YouTube / Tencent Meeting style)
public final class KatibFloatingHUD: NSObject {
    public static let shared = KatibFloatingHUD()

    private var window: NSPanel?
    private var hostingView: NSHostingView<KatibFloatingHUDView>?

    public private(set) var isVisible: Bool = false

    private override init() {
        super.init()
    }

    public func show() {
        if window == nil {
            createWindow()
        }
        window?.orderFront(nil)
        isVisible = true
    }

    public func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 160),
            styleMask: [.nonactivatingPanel, .borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = NSSize(width: 320, height: 100)
        panel.maxSize = NSSize(width: 800, height: 400)

        // Center on screen bottom
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - 240
            let y = screenRect.minY + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let view = KatibFloatingHUDView { [weak self] in
            self?.hide()
        }
        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting

        self.hostingView = hosting
        self.window = panel
    }
}

public struct KatibFloatingHUDView: View {
    @ObservedObject var manager = KatibManager.shared
    var onClose: () -> Void

    public var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                // Top bar: Drag hint, status badge, copy all, close
                HStack(spacing: 6) {
                    Circle()
                        .fill(manager.isRunning ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)

                    Text("Katib Live Captions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.8))

                    Spacer()

                    if !manager.recentSentences.isEmpty {
                        Button(action: {
                            let text = manager.recentSentences.map { "[\($0.source.rawValue)] \($0.text)" }.joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Copy all subtitles")
                    }

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Close HUD")
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                Divider().opacity(0.3)

                // Subtitle content list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            if manager.recentSentences.isEmpty {
                                HStack {
                                    Spacer()
                                    Text(manager.isRunning ? "Listening for speech..." : "Turn on Voice Monitor to start")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 24)
                                    Spacer()
                                }
                            } else {
                                ForEach(manager.recentSentences) { sentence in
                                    HStack(alignment: .top, spacing: 6) {
                                        HStack(spacing: 3) {
                                            Image(systemName: sentence.source.icon)
                                                .font(.system(size: 8))
                                            Text(sentence.source.rawValue)
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background((sentence.source == .remote ? Color.blue : Color.green).opacity(0.18))
                                        .foregroundColor(sentence.source == .remote ? .blue : .green)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(.top, 1)

                                        Text(sentence.text)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(.primary)
                                            .lineSpacing(2)
                                            .textSelection(.enabled)
                                    }
                                    .id(sentence.id)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                        .background(HideScrollerBackground())
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: manager.recentSentences.count) { _, _ in
                        if let last = manager.recentSentences.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

public struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct HideScrollerBackground: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                scrollView.drawsBackground = false
                scrollView.backgroundColor = .clear
                scrollView.scrollerStyle = .overlay
                scrollView.hasVerticalScroller = false
                scrollView.verticalScroller?.isHidden = true
                scrollView.autohidesScrollers = true
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                scrollView.drawsBackground = false
                scrollView.backgroundColor = .clear
                scrollView.scrollerStyle = .overlay
                scrollView.hasVerticalScroller = false
                scrollView.verticalScroller?.isHidden = true
                scrollView.autohidesScrollers = true
            }
        }
    }
}

