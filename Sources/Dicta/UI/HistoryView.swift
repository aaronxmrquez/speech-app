import SwiftUI
import AppKit

@MainActor
final class HistoryWindowController {
    private var window: NSWindow?
    private let history: HistoryStore

    init(history: HistoryStore) {
        self.history = history
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered,
                             defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1)
            w.appearance = NSAppearance(named: .darkAqua)
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.moveToActiveSpace]
            w.contentView = NSHostingView(rootView: HistoryView(history: history))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct HistoryView: View {
    @ObservedObject var history: HistoryStore
    @State private var copiedId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Historial")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Spacer()
                if !history.records.isEmpty {
                    Button("Borrar todo") { history.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 16)

            if history.records.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                    Text("Aún no hay dictados")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(history.records) { record in
                            HistoryRow(record: record, copied: copiedId == record.id) {
                                copy(record)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                Text("Clic en un dictado para copiarlo")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 400, height: 500)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }

    private func copy(_ record: DictationRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.text, forType: .string)
        copiedId = record.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedId == record.id { copiedId = nil }
        }
    }
}

struct HistoryRow: View {
    let record: DictationRecord
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 6) {
                Text(record.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    Text(record.date, format: .relative(presentation: .named))
                    if let app = record.appName {
                        Text("·")
                        Text(app)
                    }
                    Spacer()
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? Theme.primary : Theme.tertiary)
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
