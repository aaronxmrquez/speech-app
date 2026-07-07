import SwiftUI

struct HUDView: View {
    @ObservedObject var state: AppState
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack {
            Spacer()
            pill.padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pill: some View {
        HStack(spacing: 12) {
            languageBadge
            indicator
                .frame(width: 44, alignment: .center)
            content
        }
        .padding(.horizontal, 18)
        .frame(width: 410, height: 58)
        .background(
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.phase)
    }

    private var languageBadge: some View {
        Text(prefs.language.short)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var indicator: some View {
        switch state.phase {
        case .recording:
            WaveformView(level: CGFloat(state.audioLevel))
        case .transcribing, .inserting:
            PulsingDotsView()
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .transition(.scale.combined(with: .opacity))
        case .notice:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.secondary)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .recording:
            Text(state.partialText.isEmpty ? "Escuchando…" : state.partialText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(state.partialText.isEmpty ? Theme.tertiary : Theme.primary)
                .lineLimit(1)
                .truncationMode(.head) // se ve el final de la frase, lo recién dictado
                .frame(maxWidth: .infinity, alignment: .leading)
        case .transcribing:
            statusText("Transcribiendo…", style: Theme.secondary)
        case .inserting:
            statusText("Escribiendo…", style: Theme.secondary)
        case .done:
            statusText("Listo", style: Theme.primary)
        case .notice(let message):
            statusText(message, style: Theme.secondary)
        case .idle:
            EmptyView()
        }
    }

    private func statusText(_ text: String, style: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(style)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Barras blancas que reaccionan al nivel del micrófono.
struct WaveformView: View {
    var level: CGFloat
    private let barCount = 7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Theme.primary)
                        .frame(width: 3, height: barHeight(index: index, time: time))
                }
            }
        }
        .frame(height: 32)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = 0.5 + 0.5 * sin(time * 9 + Double(index) * 1.1)
        let mid = Double(barCount - 1) / 2
        let centerBias = 0.45 + 0.55 * (1 - abs(Double(index) - mid) / mid)
        let amplitude = max(0.08, level) * CGFloat(phase * centerBias)
        return 5 + amplitude * 25
    }
}

/// Tres puntos pulsantes para los estados de proceso.
struct PulsingDotsView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.primary)
                        .frame(width: 5, height: 5)
                        .opacity(0.25 + 0.75 * max(0, sin(time * 4 - Double(index) * 0.7)))
                }
            }
        }
        .frame(height: 32)
    }
}
