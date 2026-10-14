//
//  LiveTextMapPanel.swift
//  Feudalism
//
//  Tekstualne mape uživo (bez snimanja) + zadnjih 25 odluka. Svaki prozor se može pomaknuti i zatvoriti (X).
//

import SwiftUI

private enum LiveMapWindowId: String, CaseIterable, Identifiable {
    case main, underground, buildings, army, decisions
    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        let key: String
        switch self {
        case .main: key = "history_map_main"
        case .underground: key = "history_map_underground"
        case .buildings: key = "history_map_buildings"
        case .army: key = "history_map_army"
        case .decisions: key = "history_map_decisions"
        }
        return LocalizedStrings.string(for: key, language: language)
    }

    var defaultOffset: CGSize {
        switch self {
        case .main: return CGSize(width: -280, height: -160)
        case .underground: return CGSize(width: 280, height: -160)
        case .buildings: return CGSize(width: -280, height: 160)
        case .army: return CGSize(width: 280, height: 160)
        case .decisions: return CGSize(width: 0, height: 320)
        }
    }
}

struct LiveTextMapPanel: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var partyLog = LivePartyLog.shared
    /// Kad se poveća, svi prozori se zatvore i otvore ispočetka.
    var session: Int
    var onCloseAll: () -> Void

    @State private var openIds: Set<LiveMapWindowId> = Set(LiveMapWindowId.allCases)
    @State private var offsets: [LiveMapWindowId: CGSize] = [:]
    @State private var dragOrigins: [LiveMapWindowId: CGSize] = [:]

    var body: some View {
        // currentTurn + placementsVersion: mape se osvježavaju kako se partija mijenja.
        let maps = TextMapCapture.captureMaps(from: gameState)
        let _ = gameState.currentTurn
        let _ = gameState.placementsVersion
        ZStack {
            ForEach(LiveMapWindowId.allCases) { id in
                if openIds.contains(id) {
                    floatingWindow(id: id, bodyText: text(for: id, maps: maps))
                        .offset(offsets[id] ?? id.defaultOffset)
                        .zIndex(zIndex(for: id))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { resetWindows() }
        .onChange(of: session) { _ in resetWindows() }
        .onChange(of: openIds) { ids in
            if ids.isEmpty { onCloseAll() }
        }
    }

    private func text(
        for id: LiveMapWindowId,
        maps: (main: String, underground: String, buildings: String, army: String)
    ) -> String {
        switch id {
        case .main: return maps.main
        case .underground: return maps.underground
        case .buildings: return maps.buildings
        case .army: return maps.army
        case .decisions:
            if partyLog.decisions.isEmpty {
                return LocalizedStrings.string(
                    for: "history_map_decisions_empty",
                    language: gameState.appLanguage
                )
            }
            let cap = LivePartyLog.maxDecisions
            let header = LocalizedStrings.string(
                for: "history_map_decisions_cap",
                language: gameState.appLanguage
            )
            let lines = partyLog.decisions.map { d in
                "\(d.second)s (\(d.row),\(d.col)) \(d.actor): \(d.action)"
            }
            return "\(String(format: header, partyLog.decisions.count, cap))\n" + lines.joined(separator: "\n")
        }
    }

    private func floatingWindow(id: LiveMapWindowId, bodyText: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: id == .decisions ? "list.bullet.rectangle" : "macwindow")
                    .font(.system(size: 13, weight: .semibold))
                Text(id.title(language: gameState.appLanguage))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if id != .decisions {
                    Text("· \(gameState.currentTurn)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 8)
                Button {
                    openIds.remove(id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .gesture(dragGesture(for: id))

            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Text(bodyText.isEmpty ? "—" : bodyText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.opacity(0.55))
        }
        .frame(width: id == .decisions ? 520 : 420, height: id == .decisions ? 220 : 280)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }

    private func dragGesture(for id: LiveMapWindowId) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let origin = dragOrigins[id] ?? offsets[id] ?? id.defaultOffset
                if dragOrigins[id] == nil { dragOrigins[id] = origin }
                offsets[id] = CGSize(
                    width: origin.width + value.translation.width,
                    height: origin.height + value.translation.height
                )
            }
            .onEnded { _ in
                dragOrigins[id] = nil
            }
    }

    private func zIndex(for id: LiveMapWindowId) -> Double {
        switch id {
        case .decisions: return 5
        case .army: return 4
        case .buildings: return 3
        case .underground: return 2
        case .main: return 1
        }
    }

    private func resetWindows() {
        openIds = Set(LiveMapWindowId.allCases)
        offsets = Dictionary(uniqueKeysWithValues: LiveMapWindowId.allCases.map { ($0, $0.defaultOffset) })
        dragOrigins = [:]
    }
}
