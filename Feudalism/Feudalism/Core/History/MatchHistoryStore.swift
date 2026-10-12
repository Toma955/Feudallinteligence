//
//  MatchHistoryStore.swift
//  Feudalism
//
//  Snima okvire partije na disk i drži popis za History of matches.
//

import Foundation
import Combine

final class MatchHistoryStore: ObservableObject {
    static let shared = MatchHistoryStore()

    @Published private(set) var summaries: [MatchHistorySummary] = []

    private var draft: MatchHistoryRecord?
    private let frameInterval = 5
    private let maxStoredMatches = 80
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        summaries = loadIndex()
    }

    func record(id: String) -> MatchHistoryRecord? {
        if let draft, draft.id == id { return draft }
        return loadRecord(id: id)
    }

    func beginRecording(from state: GameState) {
        guard !state.isMapEditorMode, state.isLevelReady, !state.isShowingMainMenu else { return }
        guard state.gameMap.rows > 0, state.gameMap.cols > 0 else { return }
        guard draft == nil else { return }

        let players = makePlayers(from: state)
        let kind = matchKind(from: state)
        let title = makeTitle(players: players, kind: kind, map: state.gameMap.displayDimensionString)
        let block = TextMapCapture.blockSize(rows: state.gameMap.rows, cols: state.gameMap.cols)
        let visionRows = max(1, (state.gameMap.rows + block - 1) / block)
        let visionCols = max(1, (state.gameMap.cols + block - 1) / block)
        let id = UUID().uuidString
        draft = MatchHistoryRecord(
            id: id,
            startedAt: Date(),
            endedAt: nil,
            title: title,
            kind: kind,
            mapLabel: state.gameMap.displayDimensionString,
            mapRows: state.gameMap.rows,
            mapCols: state.gameMap.cols,
            block: block,
            visionRows: visionRows,
            visionCols: visionCols,
            players: players,
            result: nil,
            frames: []
        )
        appendFrame(from: state)
        persistDraft()
    }

    func recordTick(from state: GameState) {
        guard draft != nil else { return }
        let turn = state.currentTurn
        if turn == 1 || turn % frameInterval == 0 {
            appendFrame(from: state)
            persistDraft()
        }
    }

    func finishRecording(from state: GameState) {
        guard var record = draft else { return }
        if record.frames.last?.turn != state.currentTurn {
            appendFrame(from: state)
        }
        record = draft ?? record
        record.endedAt = Date()
        record.result = resultText(from: state)
        record.players = makePlayers(from: state)
        record.title = makeTitle(players: record.players, kind: record.kind, map: record.mapLabel)
        draft = nil
        guard !record.frames.isEmpty else { return }
        save(record)
    }

    // MARK: - Disk

    private func folder() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = root.appendingPathComponent("Feudalism/match-history", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func indexURL() -> URL { folder().appendingPathComponent("index.json") }

    private func recordURL(id: String) -> URL { folder().appendingPathComponent("\(id).json") }

    private func loadIndex() -> [MatchHistorySummary] {
        guard let data = try? Data(contentsOf: indexURL()),
              let list = try? decoder.decode([MatchHistorySummary].self, from: data) else {
            return []
        }
        return list.sorted { $0.startedAt > $1.startedAt }
    }

    private func loadRecord(id: String) -> MatchHistoryRecord? {
        guard let data = try? Data(contentsOf: recordURL(id: id)) else { return nil }
        return try? decoder.decode(MatchHistoryRecord.self, from: data)
    }

    private func persistDraft() {
        guard let draft else { return }
        upsertSummary(draft.summary)
        saveFile(draft)
        writeIndex()
    }

    private func save(_ record: MatchHistoryRecord) {
        upsertSummary(record.summary)
        saveFile(record)
        trimOldMatches()
        writeIndex()
    }

    private func saveFile(_ record: MatchHistoryRecord) {
        guard let data = try? encoder.encode(record) else { return }
        try? data.write(to: recordURL(id: record.id), options: .atomic)
    }

    private func upsertSummary(_ summary: MatchHistorySummary) {
        if let i = summaries.firstIndex(where: { $0.id == summary.id }) {
            summaries[i] = summary
        } else {
            summaries.insert(summary, at: 0)
        }
        summaries.sort { $0.startedAt > $1.startedAt }
    }

    private func writeIndex() {
        guard let data = try? encoder.encode(summaries) else { return }
        try? data.write(to: indexURL(), options: .atomic)
    }

    private func trimOldMatches() {
        guard summaries.count > maxStoredMatches else { return }
        let extra = summaries.suffix(from: maxStoredMatches)
        for item in extra {
            try? FileManager.default.removeItem(at: recordURL(id: item.id))
        }
        summaries = Array(summaries.prefix(maxStoredMatches))
    }

    private func appendFrame(from state: GameState) {
        guard var record = draft else { return }
        if record.frames.last?.turn == state.currentTurn { return }
        record.frames.append(TextMapCapture.captureFrame(from: state))
        draft = record
    }

    private func makePlayers(from state: GameState) -> [MatchHistoryPlayer] {
        if !state.realms.isEmpty {
            return state.realms.map { MatchHistoryPlayer(name: $0.name, isHuman: $0.isPlayerControlled) }
        }
        return state.realmSeats.seats.map { MatchHistoryPlayer(name: $0.displayName, isHuman: $0.isPlayerFaction) }
    }

    private func matchKind(from state: GameState) -> MatchHistoryKind {
        if state.isSandboxPlay { return .sandbox }
        switch state.campaign.type {
        case .military: return .military
        case .economic: return .economic
        }
    }

    private func makeTitle(players: [MatchHistoryPlayer], kind: MatchHistoryKind, map: String) -> String {
        let names = players.map(\.name)
        if names.isEmpty { return map }
        if names.count == 1 { return "\(names[0]) · \(map)" }
        return names.joined(separator: " vs ")
    }

    private func resultText(from state: GameState) -> String {
        if state.isSandboxPlay { return "Solo graditelj" }
        if let result = state.campaignResult {
            return result.title
        }
        if let id = state.winningRealmId {
            let name = state.realms.first { $0.id == id }?.name
                ?? state.realmSeats.seats.first { $0.id == id }?.displayName
            if let name { return name }
        }
        return "Prekinuto"
    }
}
