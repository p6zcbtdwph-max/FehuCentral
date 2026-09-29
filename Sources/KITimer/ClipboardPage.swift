import SwiftUI

struct ClipboardPage: View {
    @EnvironmentObject var clip: ClipboardManager
    @State private var searchText   = ""
    @State private var tab: ClipTab = .favorites
    @State private var copiedID: UUID?
    @State private var editingEntry: ClipboardEntry?   // nil = neuer Eintrag
    @State private var showEditor   = false

    enum ClipTab { case favorites, history }

    var body: some View {
        VStack(spacing: 0) {
            if showEditor {
                SnippetEditorView(
                    entry: editingEntry,
                    onSave: { label, text in
                        if var e = editingEntry {
                            e.label = label.isEmpty ? nil : label
                            e.text  = text
                            clip.updateFavorite(e)
                        } else {
                            clip.addManualEntry(label: label, text: text)
                        }
                        showEditor = false
                    },
                    onCancel: { showEditor = false }
                )
            } else {
                mainView
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showEditor)
    }

    // MARK: - Hauptansicht
    private var mainView: some View {
        VStack(spacing: 0) {

            // ── Suchfeld ──────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).imageScale(.small)
                TextField("Suchen…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // ── Pause-Banner ───────────────────────────────────
            if clip.isPaused {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
                    Text("Aufzeichnung pausiert")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                    Spacer()
                    Button("Fortsetzen") { clip.isPaused = false }
                        .font(.caption).buttonStyle(.plain).foregroundStyle(.orange)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12).padding(.bottom, 4)
            }

            // ── Tab-Picker + Buttons ───────────────────────────
            HStack(spacing: 8) {
                Picker("", selection: $tab) {
                    Text("Snippets (\(clip.favorites.count))").tag(ClipTab.favorites)
                    Text("Verlauf (\(clip.history.count))").tag(ClipTab.history)
                }
                .pickerStyle(.segmented)

                // Neu anlegen (nur im Snippets-Tab)
                if tab == .favorites {
                    Button(action: { editingEntry = nil; showEditor = true }) {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.medium)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Neues Snippet anlegen")
                }

                // Pause-Toggle
                Button(action: { clip.isPaused.toggle() }) {
                    Image(systemName: clip.isPaused ? "record.circle" : "pause.circle")
                        .imageScale(.medium)
                        .foregroundStyle(clip.isPaused ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(clip.isPaused ? "Aufzeichnung fortsetzen" : "Aufzeichnung pausieren")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            Divider()

            // ── Inhalt ─────────────────────────────────────────
            if tab == .favorites { favoritesView } else { historyView }
        }
    }

    // MARK: - Snippets (Gespeichert)
    private var favoritesView: some View {
        Group {
            if filteredFavorites.isEmpty {
                emptyState(
                    icon: "star.slash",
                    text: searchText.isEmpty
                        ? "Noch keine Snippets.\nTippe auf + um einen Eintrag anzulegen\noder pinne Einträge aus dem Verlauf."
                        : "Keine Treffer für «\(searchText)»"
                )
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(filteredFavorites) { entry in
                            ClipRow(
                                entry: entry,
                                isFavorite: true,
                                justCopied: copiedID == entry.id,
                                onCopy:     { copy(entry) },
                                onEdit:     { editingEntry = entry; showEditor = true },
                                onFavorite: { clip.removeFromFavorites(id: entry.id) },
                                onDelete:   { clip.removeFromFavorites(id: entry.id) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    // MARK: - Verlauf
    private var historyView: some View {
        Group {
            if filteredHistory.isEmpty {
                emptyState(
                    icon: "clock.arrow.circlepath",
                    text: searchText.isEmpty
                        ? "Noch kein Verlauf.\nKopiere etwas und es erscheint hier."
                        : "Keine Treffer für «\(searchText)»"
                )
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(filteredHistory) { entry in
                                ClipRow(
                                    entry: entry,
                                    isFavorite: false,
                                    justCopied: copiedID == entry.id,
                                    onCopy:     { copy(entry) },
                                    onEdit:     nil,
                                    onFavorite: { clip.addToFavorites(entry) },
                                    onDelete:   { clip.removeFromHistory(id: entry.id) }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 250)

                    Divider()
                    Button("Verlauf löschen") { clip.clearHistory() }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Helpers
    private var filteredFavorites: [ClipboardEntry] {
        guard !searchText.isEmpty else { return clip.favorites }
        return clip.favorites.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            ($0.label ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    private var filteredHistory: [ClipboardEntry] {
        guard !searchText.isEmpty else { return clip.history }
        return clip.history.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    private func copy(_ entry: ClipboardEntry) {
        clip.copyToClipboard(entry)
        copiedID = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == entry.id { copiedID = nil }
        }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28).padding(.horizontal, 20)
    }
}

// MARK: - Einzelne Zeile
struct ClipRow: View {
    let entry: ClipboardEntry
    let isFavorite: Bool
    let justCopied: Bool
    let onCopy:     () -> Void
    let onEdit:     (() -> Void)?
    let onFavorite: () -> Void
    let onDelete:   () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                // Label (wenn vorhanden)
                if let label = entry.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(entry.shortPreview)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .foregroundStyle(justCopied ? .green : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Aktions-Buttons bei Hover
            if hovered || justCopied {
                HStack(spacing: 8) {
                    Button(action: onCopy) {
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                            .imageScale(.small)
                            .foregroundStyle(justCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain).help("Kopieren")

                    if let onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil").imageScale(.small).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain).help("Bearbeiten")
                    }

                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "star.slash" : "star")
                            .imageScale(.small)
                            .foregroundStyle(isFavorite ? .orange : .secondary)
                    }
                    .buttonStyle(.plain).help(isFavorite ? "Aus Snippets entfernen" : "Als Snippet speichern")

                    Button(action: onDelete) {
                        Image(systemName: "trash").imageScale(.small).foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain).help("Löschen")
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(hovered ? Color.secondary.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onCopy() }
    }
}

// MARK: - Snippet Editor
struct SnippetEditorView: View {
    @State private var label: String
    @State private var text:  String
    let isNew: Bool
    let onSave:   (String, String) -> Void
    let onCancel: () -> Void

    init(entry: ClipboardEntry?, onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        _label   = State(initialValue: entry?.label ?? "")
        _text    = State(initialValue: entry?.text  ?? "")
        isNew    = entry == nil
        self.onSave   = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("NAME (OPTIONAL)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                TextField("z.B. Firmenadresse, E-Mail, IBAN…", text: $label)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Divider()

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("INHALT").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.system(size: 12))
                    .frame(minHeight: 80, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    // Placeholder
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Text eingeben…")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .padding(6)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            // Buttons
            HStack {
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(isNew ? "Speichern" : "Aktualisieren") { onSave(label, text) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}
