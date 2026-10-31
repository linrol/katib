import SwiftUI

/// Settings Card View for Katib - Can be embedded into any host app (e.g. TeamsWake)
public struct KatibSettingsView: View {
    @ObservedObject var manager = KatibManager.shared
    public var isCollapsible: Bool
    @State private var isExpanded: Bool

    public init(isCollapsible: Bool = false, defaultExpanded: Bool = false) {
        self.isCollapsible = isCollapsible
        self._isExpanded = State(initialValue: isCollapsible ? defaultExpanded : true)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: manager.isRunning ? "waveform.circle.fill" : "waveform.circle")
                        .font(.system(size: 13))
                        .foregroundColor(manager.isRunning ? .green : .accentColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Voice Monitor (Katib)")
                            .font(.system(size: 12, weight: .medium))
                        Text(manager.isRunning ? manager.listenMode.runningStatusText : "Inactive (Toggle switch on right to start)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { manager.isRunning },
                    set: { _ in manager.toggleCapture() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
                .controlSize(.mini)

                if isCollapsible {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isCollapsible || isExpanded {
                // Listening Mode Selector: Remote Only, Local Mic, Both
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Listening Mode", selection: $manager.listenMode) {
                        ForEach(KatibListenMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .disabled(manager.isRunning)

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                        Text(manager.listenMode.tipText)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.top, 2)

                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text("SenseVoice CoreML local model ready (Auto ZH/EN/YUE/JA/KO, on-device)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                if let err = manager.errorMessage {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        )
    }
}
