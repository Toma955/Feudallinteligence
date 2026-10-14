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

    @State private var search = ""
    @State private var selectedId: String?
    @State private var loaded: MatchHistoryRecord?
    @State private var pendingDelete: MatchHistorySummary?
    @State private var infoSummary: MatchHistorySummary?
    @ObservedObject var playback: RecordingPlayback = .shared

    private var language: AppLanguage { gameState.appLanguage }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if playback.showMatchList {
                matchListPanel
                    .frame(width: 360)
                    .frame(maxHeight: .infinity)
            }
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
        .alert(L("history_delete_title"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(L("history_delete_cancel"), role: .cancel) {
                pendingDelete = nil
            }
            Button(L("history_delete_confirm"), role: .destructive) {
                if let item = pendingDelete {
                    deleteMatch(item)
                    pendingDelete = nil
                }
            }
        } message: {
            if let item = pendingDelete {
                Text(String(format: L("history_delete_message"), item.title))
            }
        }
        .sheet(item: $infoSummary) { item in
            matchInfoSheet(item)
        }
    }

    // MARK: - Lijevo

    private var matchListPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                TextField(L("history_search"), text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                Button {
                    playback.showMatchList = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))

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

            if playback.filterOpen {
                listFilterChoices
            }
            Button {
                playback.filterOpen.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Filter")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(L(playback.matchFilter.localeKey))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(playback.filterOpen ? .black.opacity(0.7) : .white.opacity(0.7))
                }
                .foregroundStyle(playback.filterOpen ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(playback.filterOpen ? Color.yellow : Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private var listFilterChoices: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HistoryFilter.allCases) { item in
                    Button {
                        playback.matchFilter = item
                    } label: {
                        Text(L(item.localeKey))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(playback.matchFilter == item ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(playback.matchFilter == item ? Color.yellow : Color.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func matchRow(_ item: MatchHistorySummary) -> some View {
        let selected = item.id == selectedId
        return HStack(alignment: .top, spacing: 6) {
            Button {
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
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Button {
                    infoSummary = item
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .help(L("history_info"))

                Button {
                    pendingDelete = item
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .help(L("history_delete"))
            }
            .padding(.trailing, 6)
            .padding(.top, 6)
        }
        .background(
            selected ? Color.green.opacity(0.22) : Color.white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.green.opacity(0.85) : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1)
        )
    }

    private func matchInfoSheet(_ item: MatchHistorySummary) -> some View {
        let record = store.record(id: item.id)
        let duration = durationLabel(started: item.startedAt, ended: item.endedAt ?? record?.endedAt)
        let size = store.recordFileSize(id: item.id).map(byteSizeLabel)
        let players = item.players.map { p in
            p.isHuman ? "\(p.name) (\(L("history_player_human")))" : "\(p.name) (\(L("history_player_ai")))"
        }.joined(separator: "\n")
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("history_info_title"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    infoSummary = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            infoRow(L("history_info_name"), item.title)
            infoRow(L("history_info_kind"), L(item.kind.localeKey))
            infoRow(L("history_info_map"), item.mapLabel)
            infoRow(L("history_info_started"), fullDateTimeLabel(item.startedAt))
            if let ended = item.endedAt ?? record?.endedAt {
                infoRow(L("history_info_ended"), fullDateTimeLabel(ended))
            } else {
                infoRow(L("history_info_ended"), L("history_in_progress"))
            }
            infoRow(L("history_info_duration"), duration)
            infoRow(L("history_info_frames"), "\(item.frameCount)")
            infoRow(L("history_info_turn"), "\(item.lastTurn)")
            if let result = item.result, !result.isEmpty {
                infoRow(L("history_result"), result)
            }
            if let size {
                infoRow(L("history_info_size"), size)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("history_parties"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(players.isEmpty ? "—" : players)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                infoSummary = nil
                pendingDelete = item
            } label: {
                Label(L("history_delete"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(20)
        .frame(minWidth: 360, idealWidth: 400, minHeight: 420)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func deleteMatch(_ item: MatchHistorySummary) {
        let wasSelected = selectedId == item.id
        store.deleteRecord(id: item.id)
        if wasSelected {
            selectedId = store.summaries.first?.id
            loadSelected()
        }
        if infoSummary?.id == item.id {
            infoSummary = nil
        }
    }

    private func fullDateTimeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: language.rawValue == "hr" ? "hr_HR" : language.rawValue)
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func durationLabel(started: Date, ended: Date?) -> String {
        guard let ended else { return L("history_in_progress") }
        let seconds = max(0, Int(ended.timeIntervalSince(started)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func byteSizeLabel(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Desno

    private var rightColumn: some View {
        Group {
            if let record = loaded, let frame = currentFrame(in: record), playback.pane == .graph {
                resourceGraph(record: record)
            } else if let record = loaded, let frame = currentFrame(in: record), playback.pane == .resources {
                resourceBoard(frame: frame)
            } else {
                recordingForm
            }
        }
    }

    /// Tri prikaza situacije i početak vremenske crte. Ostaje i kad nema nijedne partije.
    private var recordingForm: some View {
        let record = loaded
        let frame = record.flatMap { currentFrame(in: $0) }
        let actors = record.map(recordingActors) ?? [RecordingActor(name: "", kind: "")]
        let decisions = record.map(recordingDecisions) ?? []
        let end = record.map(timelineEnd) ?? 30
        return VStack(alignment: .leading, spacing: 10) {
            if let record, let frame {
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
                    Button {
                        TrainingSession.shared.selectMatchForTraining(id: record.id)
                    } label: {
                        Text(L("history_train_match"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.9), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    if let result = record.result {
                        Text(result)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.yellow.opacity(0.9))
                    }
                }
                frameControls(record: record, frame: frame)
                let people = frame.timeline.split(separator: "\n").map(String.init).filter { $0.contains("populacija") }
                if !people.isEmpty {
                    Text(people.joined(separator: "   "))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    mapPane(title: L("history_map_main"), grid: frame?.main ?? "", layer: .main, colored: playback.gui)
                    mapPane(title: L("history_map_underground"), grid: frame?.underground ?? "", layer: .underground, colored: playback.gui)
                }
                HStack(spacing: 10) {
                    mapPane(title: L("history_map_army"), grid: frame?.army ?? "", layer: .army, colored: playback.gui)
                    if playback.gui {
                        decisionLanes(actors: actors, decisions: decisions, end: end)
                    } else {
                        logPane(logText(record: record, frame: frame))
                    }
                }
                if playback.gui {
                    heightMapPane(frame?.heightMap ?? "")
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func timelineEnd(_ record: MatchHistoryRecord) -> Int {
        let decisions = recordingDecisions(record)
        let last = record.frames.map { max(0, $0.turn - 1) }.max() ?? 0
        return max(30, last, decisions.map(\.second).max() ?? 0)
    }

    private func frameControls(record: MatchHistoryRecord, frame: MatchHistoryFrame) -> some View {
        HStack(spacing: 10) {
            Text("\(L("history_frame")) \(playback.frameIndex + 1)/\(max(record.frames.count, 1))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
            Text("\(L("history_turn")) \(frame.turn)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func rawMapPane(title: String, grid: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Text(grid.isEmpty ? " " : grid)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            if let note {
                Text(note)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(3)
            }
        }
        .frame(minHeight: 90)
    }

    private func logText(record: MatchHistoryRecord?, frame: MatchHistoryFrame?) -> String {
        let timeline = frame?.timeline ?? ""
        let second = frame.map { max(0, $0.turn - 1) } ?? Int.max
        let decisions = (record?.decisions ?? []).filter { $0.second <= second }
        if decisions.isEmpty { return timeline }
        let header = timeline.split(separator: "\n").map(String.init).filter { line in
            !line.contains("s (") && !line.hasPrefix("  ") && line != "Nema poteza do ove sekunde."
        }
        var lines = header
        for decision in decisions {
            var line = "\(decision.second)s (\(decision.row), \(decision.col)) \(decision.actor): \(decision.action)"
            if let pop = decision.population, let happy = decision.happiness, !decision.action.contains("populacija") {
                line += " · populacija \(pop) · sreća \(happy)%"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private func decisionHelp(_ decision: MatchDecision, actor: String) -> String {
        var line = "\(decision.second)s  \(actor): \(decision.action)"
        if let pop = decision.population, let happy = decision.happiness, !decision.action.contains("populacija") {
            line += " · populacija \(pop) · sreća \(happy)%"
        }
        return line
    }

    private func heightMapPane(_ grid: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Visinska mapa")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            ScrollView([.vertical, .horizontal]) {
                Text(grid.isEmpty ? "0" : grid)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
            Text("samo GUI · visina točke sjecišta u metrima, nije za trening")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func logPane(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Log")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            ScrollView {
                Text(text.isEmpty ? "Nema loga." : text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func mapPane(title: String, grid: String, layer: HistoryMapLayer, colored: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Group {
                if layer == .main || layer == .army || layer == .underground {
                    RecordingMatrixView(grid: grid, layer: layer, colored: colored)
                } else {
                    RecordingMapBoard(grid: grid, layer: layer)
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
            Text(layer.legend)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func decisionLanes(actors: [RecordingActor], decisions: [MatchDecision], end: Int) -> some View {
        let step = end <= 180 ? 1 : 5
        return VStack(alignment: .leading, spacing: 6) {
            Text("Odluke")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("s")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: Self.laneGutter, alignment: .leading)
                        ForEach(Array(actors.enumerated()), id: \.element.name) { index, actor in
                            VStack(spacing: 1) {
                                Text(actor.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Self.laneColor(index))
                                    .lineLimit(1)
                                Text(actor.kind)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .frame(width: Self.laneWidth)
                        }
                    }
                    .padding(.bottom, 6)
                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            RecordingTimeRuler(end: end, step: step, pixelsPerSecond: Self.pixelsPerSecond)
                                .frame(width: Self.laneGutter, height: Self.laneHeight(end))
                            ForEach(Array(actors.enumerated()), id: \.element.name) { index, actor in
                                decisionLane(
                                    actor: actor.name,
                                    color: Self.laneColor(index),
                                    decisions: decisions.filter { $0.actor == actor.name },
                                    end: end
                                )
                            }
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func decisionLane(actor: String, color: Color, decisions: [MatchDecision], end: Int) -> some View {
        let height = Self.laneHeight(end)
        return ZStack(alignment: .top) {
            Rectangle()
                .fill(color.opacity(0.9))
                .frame(width: 2, height: height)
            ForEach(Array(decisions.enumerated()), id: \.element.id) { index, decision in
                let sameSecond = decisions.prefix(index).filter { $0.second == decision.second }.count
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                    .position(
                        x: Self.laneWidth / 2 + CGFloat(sameSecond) * 14,
                        y: CGFloat(decision.second) * Self.pixelsPerSecond + 6
                    )
                    .help(decisionHelp(decision, actor: actor))
            }
        }
        .frame(width: Self.laneWidth, height: height)
    }

    private func recordingActors(_ record: MatchHistoryRecord) -> [RecordingActor] {
        var actors: [RecordingActor] = record.players.map {
            RecordingActor(name: $0.name, kind: $0.isHuman ? "igrač" : "AI")
        }
        let known = Set(actors.map(\.name))
        for decision in recordingDecisions(record) where !known.contains(decision.actor) {
            actors.append(RecordingActor(name: decision.actor, kind: "snimka"))
        }
        if actors.isEmpty {
            actors = [RecordingActor(name: "Snimka", kind: "")]
        }
        return actors
    }

    private func recordingDecisions(_ record: MatchHistoryRecord) -> [MatchDecision] {
        if let stored = record.decisions, !stored.isEmpty { return stored }
        return MatchDecision.parse(frames: record.frames, players: record.players)
    }

    private static let laneGutter: CGFloat = 52
    private static let laneWidth: CGFloat = 150
    private static let pixelsPerSecond: CGFloat = 18

    private static func laneHeight(_ end: Int) -> CGFloat {
        CGFloat(end) * pixelsPerSecond + 16
    }

    private static func laneColor(_ index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.95, green: 0.82, blue: 0.25),
            Color(red: 0.45, green: 0.75, blue: 0.95),
            Color(red: 0.95, green: 0.45, blue: 0.35),
            Color(red: 0.45, green: 0.82, blue: 0.45),
            Color(red: 0.75, green: 0.55, blue: 0.95),
            Color(red: 0.95, green: 0.65, blue: 0.30)
        ]
        return palette[index % palette.count]
    }

    private func resourceBoard(frame: MatchHistoryFrame) -> some View {
        let line = RecordingResources.parse(frame.timeline)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Resursi u ovom trenutku")
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(.white)
            Text("\(frame.turn > 0 ? frame.turn - 1 : 0) s · potez \(frame.turn)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            if let line {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    resourceChip("Zlato", line.gold)
                    resourceChip("Drvo", line.wood)
                    resourceChip("Kamen", line.stone)
                    resourceChip("Željezo", line.iron)
                    resourceChip("Hrana", line.food)
                }
            } else {
                Text(frame.timeline.isEmpty ? "Nema resursa u ovom okviru." : frame.timeline)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func resourceChip(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(.yellow)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func resourceGraph(record: MatchHistoryRecord) -> some View {
        let series = record.frames.compactMap { RecordingResources.parse($0.timeline) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Graf resursa kroz snimku")
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(.white)
            if series.count < 2 {
                Text("Treba barem dva okvira s resursima da se nacrta graf.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                HStack(spacing: 12) {
                    graphKey(.yellow, "Zlato")
                    graphKey(Color(red: 0.55, green: 0.36, blue: 0.18), "Drvo")
                    graphKey(.gray, "Kamen")
                    graphKey(Color(red: 0.65, green: 0.68, blue: 0.72), "Željezo")
                    graphKey(Color(red: 0.45, green: 0.75, blue: 0.35), "Hrana")
                }
                RecordingResourceGraph(series: series)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func graphKey(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Podaci

    private var filteredGroups: [DayGroup] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let week = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let items = store.summaries.filter { item in
            switch playback.matchFilter {
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
        playback.frameCount = max(1, loaded?.frames.count ?? 1)
        playback.frameIndex = 0
        playback.pane = .maps
    }

    private func currentFrame(in record: MatchHistoryRecord) -> MatchHistoryFrame? {
        guard !record.frames.isEmpty else { return nil }
        let i = min(max(playback.frameIndex, 0), record.frames.count - 1)
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

    private func L(_ key: String) -> String {
        LocalizedStrings.string(for: key, language: language)
    }
}

enum HistoryFilter: String, CaseIterable, Identifiable {
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

private struct RecordingMatrixView: View {
    var grid: String
    var layer: HistoryMapLayer
    var colored: Bool

    private static let cellWidth: CGFloat = 72
    private static let cellHeight: CGFloat = 48

    /// Redovi i stupci mape. Svaki zapis "a,b,c,d" je jedna kućica.
    private var table: [[String]] {
        let raw = grid.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let filled = raw.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if filled.isEmpty {
            return [["0,0,0,0", "0,0,0,0"], ["0,0,0,0", "0,0,0,0"]]
        }
        return filled.map { line in
            if line.contains(",") {
                return line.split(separator: " ").map(String.init)
            }
            return line.map { String($0) }
        }
    }

    var body: some View {
        let rows = table
        let columns = rows.map(\.count).max() ?? 1
        let width = CGFloat(columns) * Self.cellWidth
        let height = CGFloat(rows.count) * Self.cellHeight
        HStack(spacing: 6) {
            MatrixBracket(leading: true)
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows.indices, id: \.self) { row in
                        MatrixLineCanvas(
                            tokens: rows[row],
                            columns: columns,
                            layer: layer,
                            colored: colored,
                            cellWidth: Self.cellWidth,
                            cellHeight: Self.cellHeight
                        )
                    }
                }
                .frame(width: width, height: height, alignment: .topLeading)
            }
            MatrixBracket(leading: false)
        }
        .padding(6)
        .background(Color.black)
    }
}

/// Jedan red: onoliko kocki koliko stupaca, svaka je matrica 2×2.
private struct MatrixLineCanvas: View {
    var tokens: [String]
    var columns: Int
    var layer: HistoryMapLayer
    var colored: Bool
    var cellWidth: CGFloat
    var cellHeight: CGFloat

    var body: some View {
        Canvas { context, _ in
            for column in 0..<columns {
                let token = column < tokens.count ? tokens[column] : "0,0,0,0"
                let rect = CGRect(
                    x: CGFloat(column) * cellWidth + 1,
                    y: 1,
                    width: cellWidth - 2,
                    height: cellHeight - 2
                )
                drawCell(context, token: token, rect: rect)
            }
        }
        .frame(width: CGFloat(columns) * cellWidth, height: cellHeight, alignment: .leading)
    }

    private func drawCell(_ context: GraphicsContext, token: String, rect: CGRect) {
        let parts = token.split(separator: ",").map(String.init)
        let fill = colored ? MatrixRow.cubeColor(token, layer: layer) : Color.white.opacity(0.08)
        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(fill))
        var bracket = Path()
        let arm: CGFloat = 5
        bracket.move(to: CGPoint(x: rect.minX + arm + 3, y: rect.minY + 3))
        bracket.addLine(to: CGPoint(x: rect.minX + 3, y: rect.minY + 3))
        bracket.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        bracket.addLine(to: CGPoint(x: rect.minX + arm + 3, y: rect.maxY - 3))
        bracket.move(to: CGPoint(x: rect.maxX - arm - 3, y: rect.minY + 3))
        bracket.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 3))
        bracket.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.maxY - 3))
        bracket.addLine(to: CGPoint(x: rect.maxX - arm - 3, y: rect.maxY - 3))
        context.stroke(bracket, with: .color(.white), lineWidth: 1)
        let font = Font.system(size: 9, weight: .bold, design: .monospaced)
        let numbers = Self.fourNumbers(parts: parts, token: token)
        let spots = [
            CGPoint(x: rect.minX + 22, y: rect.minY + 15),
            CGPoint(x: rect.minX + 48, y: rect.minY + 15),
            CGPoint(x: rect.minX + 22, y: rect.minY + 32),
            CGPoint(x: rect.minX + 48, y: rect.minY + 32)
        ]
        for index in 0..<4 {
            let label = Text(numbers[index]).font(font).foregroundColor(.white)
            context.draw(label, at: spots[index], anchor: .center)
        }
    }

    /// Uvijek četiri broja. Ako zapisa nema, ostali su 0.
    private static func fourNumbers(parts: [String], token: String) -> [String] {
        if parts.count >= 4 { return Array(parts.prefix(4)) }
        var values = parts
        if values.isEmpty || (values.count == 1 && values[0].count > 1 && Int(values[0]) == nil) {
            values = [surfaceNumber(token)]
        } else if values.count == 1, Int(values[0]) == nil {
            values = [surfaceNumber(values[0])]
        }
        while values.count < 4 { values.append("0") }
        return Array(values.prefix(4))
    }

    private static func surfaceNumber(_ token: String) -> String {
        switch token.first {
        case "D": return "0"
        case "S", "+": return "1"
        case "G", "T", "R": return "3"
        case "F": return "4"
        case "M": return "5"
        case "B": return "6"
        case "W": return "7"
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            return String(token.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" }))
        default:
            return "0"
        }
    }
}

private enum MatrixRow {
    static func cubeColor(_ token: String, layer: HistoryMapLayer) -> Color {
        let parts = token.split(separator: ",")
        let red = Color(red: 0.72, green: 0.12, blue: 0.12)
        let green = Color(red: 0.10, green: 0.48, blue: 0.22)
        if layer == .army {
            let count = Int(parts.dropFirst().first ?? "0") ?? 0
            let occupied = Int(parts.dropFirst(2).first ?? "0") ?? 0
            return (count > 0 || occupied > 0) ? red : green
        }
        let build = Int(parts.dropFirst(3).first ?? "0") ?? 0
        return build == 1 ? green : red
    }
}

private struct MatrixBracket: View {
    var leading: Bool

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let arm: CGFloat = 8
            Path { path in
                if leading {
                    path.move(to: CGPoint(x: arm, y: 1))
                    path.addLine(to: CGPoint(x: 1, y: 1))
                    path.addLine(to: CGPoint(x: 1, y: max(height - 1, 1)))
                    path.addLine(to: CGPoint(x: arm, y: max(height - 1, 1)))
                } else {
                    path.move(to: CGPoint(x: 0, y: 1))
                    path.addLine(to: CGPoint(x: arm, y: 1))
                    path.addLine(to: CGPoint(x: arm, y: max(height - 1, 1)))
                    path.addLine(to: CGPoint(x: 0, y: max(height - 1, 1)))
                }
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
        }
        .frame(width: 12)
        .frame(maxHeight: .infinity)
    }
}

private struct RecordingMapBoard: View {
    var grid: String
    var layer: HistoryMapLayer

    /// Glavna mapa: boja po prohodnosti. Vojska: boja po vrsti, sudar je svjetliji.
    static func matrixColor(_ token: String, layer: HistoryMapLayer) -> Color {
        let parts = token.split(separator: ",").map(String.init)
        if layer == .army {
            let type = Int(parts.first ?? "0") ?? 0
            let count = Int(parts.dropFirst().first ?? "0") ?? 0
            let building = Int(parts.dropFirst(3).first ?? "0") ?? 0
            if count >= 2 { return Color(red: 0.95, green: 0.35, blue: 0.22) }
            if type > 0 { return Color(red: 0.92, green: 0.78, blue: 0.28) }
            if building > 0 { return Color(red: 0.45, green: 0.52, blue: 0.62) }
            return Color.white.opacity(0.06)
        }
        let walk = parts.dropFirst(2).first ?? "1"
        switch walk {
        case "0": return Color(red: 0.25, green: 0.32, blue: 0.42)
        case "0.5": return Color(red: 0.55, green: 0.48, blue: 0.28)
        case "1.5": return Color(red: 0.85, green: 0.62, blue: 0.22)
        case "2": return Color(red: 0.95, green: 0.45, blue: 0.18)
        default: return Color(red: 0.38, green: 0.68, blue: 0.32)
        }
    }

    var body: some View {
        Canvas { context, size in
            let lines = grid.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let empty = grid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let matrix = lines.contains { $0.contains(",") }
            let rowCount = max(empty ? 12 : lines.count, 1)
            let colCount = max(empty ? 16 : (matrix ? (lines.map { $0.split(separator: " ").count }.max() ?? 1) : (lines.map(\.count).max() ?? 1)), 1)
            let cell = min(size.width / CGFloat(colCount), size.height / CGFloat(rowCount))
            let originX = (size.width - cell * CGFloat(colCount)) / 2
            let originY = (size.height - cell * CGFloat(rowCount)) / 2
            for row in 0..<rowCount {
                let line = empty || row >= lines.count ? "" : lines[row]
                let tokens = matrix ? line.split(separator: " ").map(String.init) : []
                for col in 0..<colCount {
                    let rect = CGRect(
                        x: originX + CGFloat(col) * cell + 0.4,
                        y: originY + CGFloat(row) * cell + 0.4,
                        width: max(cell - 0.8, 1),
                        height: max(cell - 0.8, 1)
                    )
                    let color: Color
                    if empty {
                        color = Color.white.opacity(0.06)
                    } else if matrix {
                        let token = col < tokens.count ? tokens[col] : "1,0,1,1"
                        color = Self.matrixColor(token, layer: layer)
                    } else {
                        let ch: Character = col < line.count ? line[line.index(line.startIndex, offsetBy: col)] : "."
                        color = layer.color(for: ch)
                    }
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
                }
            }
        }
    }
}

private enum HistoryMapLayer {
    case main, underground, buildings, army

    var legend: String {
        switch self {
        case .main:
            return "površina 0 pustinja 1 kamen 2 željezo 3 tlo obično 4 plodna ravnica 5 more 6 močvara 7 voda · visina u m · prohodnost 0 0.5 1 1.5 2 · gradnja 1 ili 0 · trava je tekstura, put nije površina"
        case .underground:
            return "ista četiri broja kao glavna: površina,visina,prohodnost,gradnja · 0 ako kućica nema podatak"
        case .buildings:
            return "C dvorac  Z zid  H kuća  A farma  N rudnik  K hrana  L industrija  W oružje  = put"
        case .army:
            return "ćelija vrsta,broj,okupirano,građevina · vrsta 0 nema 1 strijelac 2 strijelac u oklopu 3 kopljanik 4 kopljanik sa štitom 5 mačevalac 6 mačevalac sa štitom 7 teški pješak 8 konjanik strijelac 9 konjanik s kopljem 10 vitez · broj najviše 2 i samo suparnici · okupirano 1 da 0 ne · građevina 0 nema, inače šifra"
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

enum RecordingPane {
    case maps
    case graph
    case resources
}

struct RecordingSample {
    var gold: Int
    var wood: Int
    var stone: Int
    var iron: Int
    var food: Int
}

enum RecordingResources {
    static func parse(_ timeline: String) -> RecordingSample? {
        let line = timeline.split(separator: "\n").first { $0.contains("zlato") && $0.contains("drvo") }
        guard let line else { return nil }
        func number(after word: String) -> Int {
            let parts = line.split(separator: " ")
            guard let index = parts.firstIndex(of: Substring(word)), index + 1 < parts.endIndex else { return 0 }
            return Int(parts[index + 1]) ?? 0
        }
        return RecordingSample(
            gold: number(after: "zlato"),
            wood: number(after: "drvo"),
            stone: number(after: "kamen"),
            iron: number(after: "željezo"),
            food: number(after: "hrana")
        )
    }
}

struct RecordingActor: Hashable {
    var name: String
    var kind: String
}

private struct RecordingTimeRuler: View {
    var end: Int
    var step: Int
    var pixelsPerSecond: CGFloat

    var body: some View {
        Canvas { context, size in
            let stride = max(1, step)
            var second = 0
            while second <= end {
                let y = CGFloat(second) * pixelsPerSecond + 6
                let label = Text("\(second)s")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.55))
                context.draw(label, at: CGPoint(x: 0, y: y), anchor: .leading)
                second += stride
            }
        }
    }
}

extension MatchDecision {
    /// Stare snimke drže odluke samo u tekstu vremenske crte.
    static func parse(frames: [MatchHistoryFrame], players: [MatchHistoryPlayer]) -> [MatchDecision] {
        let human = players.first(where: \.isHuman)?.name ?? players.first?.name ?? "Igrač"
        var seen = Set<String>()
        var found: [MatchDecision] = []
        for frame in frames {
            for raw in frame.timeline.split(separator: "\n") {
                guard let decision = parseLine(String(raw), human: human) else { continue }
                let key = "\(decision.second)|\(decision.actor)|\(decision.action)"
                guard seen.insert(key).inserted else { continue }
                found.append(decision)
            }
        }
        return found.sorted { $0.second < $1.second }
    }

    private static func parseLine(_ line: String, human: String) -> MatchDecision? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.range(of: "s (") else { return nil }
        guard let second = Int(trimmed[..<marker.lowerBound]) else { return nil }
        let rest = trimmed[marker.upperBound...]
        guard let close = rest.firstIndex(of: ")") else { return nil }
        let coords = rest[..<close].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard coords.count == 2, let row = Int(coords[0]), let col = Int(coords[1]) else { return nil }
        var action = rest[rest.index(after: close)...].trimmingCharacters(in: .whitespaces)
        var actor = human
        if let colon = action.firstIndex(of: ":"), action.distance(from: action.startIndex, to: colon) < 40 {
            actor = String(action[..<colon])
            action = action[action.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return MatchDecision(
            id: "\(second)-\(row)-\(col)-\(actor)-\(action)",
            second: second,
            actor: actor,
            action: action,
            row: row,
            col: col
        )
    }
}

final class RecordingPlayback: ObservableObject {
    static let shared = RecordingPlayback()
    @Published var frameIndex = 0
    @Published var frameCount = 1
    @Published var pane: RecordingPane = .maps
    /// Uključeno gumbom Prikaz: polja mape i vremenska crta umjesto sirovog teksta.
    @Published var gui = false
    @Published var showMatchList = true
    @Published var filterOpen = false
    @Published var matchFilter: HistoryFilter = .all

    func previous() { frameIndex = max(0, frameIndex - 1) }
    func next() { frameIndex = min(max(0, frameCount - 1), frameIndex + 1) }
}

private struct RecordingResourceGraph: View {
    var series: [RecordingSample]

    var body: some View {
        Canvas { context, size in
            let pad = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16)
            var grid = Path()
            for i in 0...4 {
                let y = pad.minY + pad.height * CGFloat(i) / 4
                grid.move(to: CGPoint(x: pad.minX, y: y))
                grid.addLine(to: CGPoint(x: pad.maxX, y: y))
            }
            context.stroke(grid, with: .color(.white.opacity(0.12)), lineWidth: 1)
            stroke(context, series.map(\.gold), .yellow, pad)
            stroke(context, series.map(\.wood), Color(red: 0.55, green: 0.36, blue: 0.18), pad)
            stroke(context, series.map(\.stone), .gray, pad)
            stroke(context, series.map(\.iron), Color(red: 0.65, green: 0.68, blue: 0.72), pad)
            stroke(context, series.map(\.food), Color(red: 0.45, green: 0.75, blue: 0.35), pad)
        }
    }

    private func stroke(_ context: GraphicsContext, _ values: [Int], _ color: Color, _ pad: CGRect) {
        guard values.count > 1, let maxValue = values.max(), maxValue > 0 else { return }
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = pad.minX + pad.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = pad.maxY - pad.height * CGFloat(value) / CGFloat(maxValue)
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 2)
    }
}

/// Gumb prije početka: uključi snimanje tekstualnih mapa i otvori snimku.
struct MatchRecordBar: View {
    @EnvironmentObject private var gameState: GameState
    var onView: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                gameState.recordThisMatch.toggle()
            } label: {
                Label(gameState.recordThisMatch ? "Snimanje uključeno" : "Snimi", systemImage: gameState.recordThisMatch ? "record.circle.fill" : "record.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(gameState.recordThisMatch ? .black : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(gameState.recordThisMatch ? Color.yellow : Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            Button(action: onView) {
                Label("Pogledaj snimku", systemImage: "text.alignleft")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
