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
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: BrandWindow.height),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered,
                             defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.backgroundColor = BrandWindow.backgroundColor
            w.appearance = NSAppearance(named: .darkAqua)
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.moveToActiveSpace]
            BrandWindow.applyChrome(to: w)
            w.contentView = NSHostingView(rootView: HistoryView(history: history))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}

struct HistoryView: View {
    @ObservedObject var history: HistoryStore
    @State private var copiedId: UUID?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            historyBody
            VersionTag()
                .padding(.top, 14)
                .padding(.trailing, 20)
        }
        .frame(width: 560, height: BrandWindow.height)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "en_US"))
        .ignoresSafeArea()
    }

    private var historyBody: some View {
        VStack(spacing: 0) {
            BrandHeader(section: "HISTORY")
                .padding(.top, 56)
                .padding(.bottom, 8)

            if history.records.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Text("NOTHING DICTATED YET")
                        .font(Theme.mono(15, .medium))
                        .tracking(3)
                        .foregroundStyle(Theme.secondary)
                    Text("Hold your key and start talking.")
                        .font(Theme.sans(12.5))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
            } else {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "RECENT")
                    Spacer()
                    Button {
                        history.clear()
                    } label: {
                        Text("CLEAR ALL")
                            .font(Theme.mono(11, .medium))
                            .tracking(1.5)
                            .foregroundStyle(Theme.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.top, 24)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(history.records) { record in
                            HistoryRow(record: record, copied: copiedId == record.id) {
                                copy(record)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }

            BrandFooter()
                .padding(.top, 16)
                .padding(.bottom, 16)
        }
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
            VStack(alignment: .leading, spacing: 10) {
                Text(record.text)
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Text(meta)
                        .font(Theme.mono(10.5, .medium))
                        .tracking(1.2)
                        .foregroundStyle(Theme.tertiary)
                    Spacer()
                    if copied {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("COPIED")
                                .font(Theme.mono(10, .semibold))
                                .tracking(1.5)
                        }
                        .foregroundStyle(Theme.accent)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }
                }
            }
            .padding(18)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(copied ? Theme.accent.opacity(0.4) : Theme.cardBorder, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: copied)
    }

    private var meta: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        var text = formatter.localizedString(for: record.date, relativeTo: Date()).uppercased()
        if let app = record.appName {
            text += " · \(app.uppercased())"
        }
        return text
    }
}
