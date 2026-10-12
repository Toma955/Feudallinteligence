//
//  MatchHistoryView.swift
//  Feudalism
//
//  Lijevo: popis partija po datumu + filter. Desno: četiri tekstualne mape jednog okvira.
//

import SwiftUI

struct MatchHistoryView: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var store = MatchHistoryStore.shared

    @State private var filter: HistoryFilter = .all
    @State private var search = ""
    @State private var selectedId: String?
    @State private var loaded: MatchHistoryRecord?
    @State private var frameIndex = 0

    private var language: AppLanguage { gameState.appLanguage }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leftColumn
                .frame(width: 300)
            rightColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedId == nil {
                selectedId = store.summaries.first?.id
            }
            loadSelected()
        }
        .onChange(of: selectedId) { _ in
            loadSelected()
        }
    }

    // MARK: - Lijevo

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            filterBar
            TextField(L("history_search"), text: $search)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
            if filteredGroups.isEmpty {
                Text(L("history_empty"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(filteredGroups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(dateHeading(group.day))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .textCase(.uppercase)
                                ForEach(group.items) { item in
                                    matchRow(item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("history_filter"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(HistoryFilter.allCases) { item in
                        Button {
                            filter = item
                        } label: {
                            Text(L(item.localeKey))
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    filter == item ? Color.green.opacity(0.35) : Color.white.opacity(0.08),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(
                                        filter == item ? Color.green.opacity(0.8) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                                )
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func matchRow(_ item: MatchHistorySummary) -> some View {
        let selected = item.id == selectedId
        return Button {
            selectedId = item.id
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
                Text("\(item.mapLabel) · \(L(item.kind.localeKey))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 6) {
                    Text(timeLabel(item.startedAt))
                    Text("·")
                    Text("\(item.frameCount) \(L("history_frames"))")
                    if let result = item.result, !result.isEmpty {
                        Text("·")
                        Text(result)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.42))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? Color.green.opacity(0.22) : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.green.opacity(0.85) : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Desno

    private var rightColumn: some View {
        Group {
            if let record = loaded, let frame = currentFrame(in: record) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title)
                                .font(.custom("Georgia", size: 18))
                                .foregroundStyle(.white)
                            Text("\(record.mapLabel) · \(L("history_parties")): \(record.summary.partyLabel)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        if let result = record.result {
                            Text(result)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.yellow.opacity(0.9))
                        }
                    }

                    frameControls(record: record, frame: frame)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        textMapPane(title: L("history_map_main"), grid: frame.main, layer: .main)
                        textMapPane(title: L("history_map_underground"), grid: frame.underground, layer: .underground)
                        textMapPane(title: L("history_map_buildings"), grid: frame.buildings, layer: .buildings)
                        textMapPane(title: L("history_map_army"), grid: frame.army, layer: .army)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(L("history_no_selection"))
                        .font(.custom("Georgia", size: 18))
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func frameControls(record: MatchHistoryRecord, frame: MatchHistoryFrame) -> some View {
        HStack(spacing: 10) {
            Text("\(L("history_frame")) \(frameIndex + 1)/\(max(record.frames.count, 1))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
            Text("\(L("history_turn")) \(frame.turn)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            if record.frames.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(frameIndex) },
                        set: { frameIndex = Int($0.rounded()) }
                    ),
                    in: 0...Double(record.frames.count - 1),
                    step: 1
                )
            }
        }
    }

    private func textMapPane(title: String, grid: String, layer: HistoryMapLayer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Text(coloredGrid(grid, layer: layer))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            Text(layer.legend)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(2)
        }
        .frame(minHeight: 220)
    }

    // MARK: - Podaci

    private var filteredGroups: [DayGroup] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let week = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let items = store.summaries.filter { item in
            switch filter {
            case .all: break
            case .today:
                if calendar.startOfDay(for: item.startedAt) != today { return false }
            case .week:
                if item.startedAt < week { return false }
            case .sandbox:
                if item.kind != .sandbox { return false }
            case .military:
                if item.kind != .military { return false }
            case .economic:
                if item.kind != .economic { return false }
            }
            if query.isEmpty { return true }
            let hay = "\(item.title) \(item.partyLabel) \(item.mapLabel) \(item.result ?? "")".lowercased()
            return hay.contains(query)
        }

        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.startedAt) }
        return grouped.keys.sorted(by: >).map { DayGroup(day: $0, items: grouped[$0] ?? []) }
    }

    private func loadSelected() {
        guard let selectedId else {
            loaded = nil
            return
        }
        loaded = store.record(id: selectedId)
        frameIndex = 0
    }

    private func currentFrame(in record: MatchHistoryRecord) -> MatchHistoryFrame? {
        guard !record.frames.isEmpty else { return nil }
        let i = min(max(frameIndex, 0), record.frames.count - 1)
        return record.frames[i]
    }

    private func dateHeading(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: language.rawValue == "hr" ? "hr_HR" : language.rawValue)
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: day)
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func coloredGrid(_ grid: String, layer: HistoryMapLayer) -> AttributedString {
        var result = AttributedString()
        let font = Font.system(size: 8, weight: .regular, design: .monospaced)
        result.font = font
        for ch in grid {
            var piece = AttributedString(String(ch))
            piece.font = font
            piece.foregroundColor = layer.color(for: ch)
            result.append(piece)
        }
        return result
    }

    private func L(_ key: String) -> String {
        LocalizedStrings.string(for: key, language: language)
    }
}

private enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case week
    case sandbox
    case military
    case economic

    var id: String { rawValue }

    var localeKey: String {
        switch self {
        case .all: return "history_filter_all"
        case .today: return "history_filter_today"
        case .week: return "history_filter_week"
        case .sandbox: return "history_filter_sandbox"
        case .military: return "history_filter_military"
        case .economic: return "history_filter_economic"
        }
    }
}

private struct DayGroup {
    var day: Date
    var items: [MatchHistorySummary]
}

private enum HistoryMapLayer {
    case main, underground, buildings, army

    var legend: String {
        switch self {
        case .main:
            return "G tlo  F plodna  T trava  W voda  M more  S kamen  i željezo  + ruda  ^ stablo  @ start"
        case .underground:
            return ". prazno  O ulaz  ~ voda  C/Z/# građevina"
        case .buildings:
            return "C dvorac  Z zid  H kuća  A farma  N rudnik  K hrana  L industrija  W oružje  = put"
        case .army:
            return "K/k kralj  V/v vojnik  R/r radnik  P/p seljak  @/a dvorac  veliko=ti"
        }
    }

    func color(for ch: Character) -> Color {
        if ch == "\n" { return .white }
        switch self {
        case .main:
            switch ch {
            case "W", "M": return Color(red: 0.35, green: 0.62, blue: 0.95)
            case "F": return Color(red: 0.45, green: 0.82, blue: 0.38)
            case "G": return Color(red: 0.55, green: 0.68, blue: 0.32)
            case "T": return Color(red: 0.38, green: 0.62, blue: 0.28)
            case "D": return Color(red: 0.82, green: 0.68, blue: 0.32)
            case "S", "+": return Color(red: 0.72, green: 0.72, blue: 0.72)
            case "i": return Color(red: 0.75, green: 0.45, blue: 0.28)
            case "B": return Color(red: 0.28, green: 0.45, blue: 0.32)
            case "R": return Color(red: 0.72, green: 0.55, blue: 0.28)
            case "^": return Color(red: 0.18, green: 0.48, blue: 0.18)
            case "@", "a": return Color(red: 0.95, green: 0.82, blue: 0.25)
            default: return Color.white.opacity(0.28)
            }
        case .underground:
            switch ch {
            case "O": return Color(red: 0.75, green: 0.55, blue: 0.25)
            case "~": return Color(red: 0.30, green: 0.55, blue: 0.90)
            case ".": return Color.white.opacity(0.18)
            default: return Color(red: 0.70, green: 0.70, blue: 0.78)
            }
        case .buildings:
            switch ch {
            case "C": return Color(red: 0.95, green: 0.82, blue: 0.28)
            case "Z": return Color.white.opacity(0.88)
            case "H": return Color(red: 0.78, green: 0.55, blue: 0.32)
            case "A": return Color(red: 0.45, green: 0.80, blue: 0.35)
            case "N": return Color(red: 0.72, green: 0.48, blue: 0.28)
            case "K": return Color(red: 0.90, green: 0.62, blue: 0.28)
            case "L": return Color(red: 0.55, green: 0.62, blue: 0.78)
            case "W": return Color(red: 0.82, green: 0.32, blue: 0.28)
            case "=": return Color(red: 0.70, green: 0.58, blue: 0.32)
            case "O": return Color(red: 0.75, green: 0.55, blue: 0.25)
            default: return Color.white.opacity(0.22)
            }
        case .army:
            switch ch {
            case "K": return Color(red: 0.98, green: 0.85, blue: 0.25)
            case "k": return Color(red: 0.85, green: 0.55, blue: 0.20)
            case "V": return Color(red: 0.92, green: 0.28, blue: 0.22)
            case "v": return Color(red: 0.75, green: 0.22, blue: 0.35)
            case "R": return Color(red: 0.35, green: 0.65, blue: 0.95)
            case "r": return Color(red: 0.45, green: 0.50, blue: 0.85)
            case "P": return Color(red: 0.55, green: 0.82, blue: 0.42)
            case "p": return Color(red: 0.40, green: 0.62, blue: 0.38)
            case "@": return Color(red: 0.95, green: 0.82, blue: 0.25)
            case "a": return Color(red: 0.80, green: 0.60, blue: 0.25)
            default: return Color.white.opacity(0.18)
            }
        }
    }
}
