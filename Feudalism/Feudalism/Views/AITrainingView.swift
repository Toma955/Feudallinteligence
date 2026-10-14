//
//  AITrainingView.swift
//  Feudalism
//
//  1. Odaberi lordove. 2. Jedan od četiri moda: analiza, učenje, predviđanje, odlučivanje.
//

import SwiftUI

enum TrainingMode: String, CaseIterable, Identifiable {
    case analysis
    case learning
    case prediction
    case decision

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analysis: return "Analiza"
        case .learning: return "Učenje"
        case .prediction: return "Predviđanje"
        case .decision: return "Odlučivanje"
        }
    }

    var icon: String {
        switch self {
        case .analysis: return "magnifyingglass"
        case .learning: return "graduationcap"
        case .prediction: return "eye"
        case .decision: return "arrow.triangle.branch"
        }
    }
}

private struct TrainSample: Identifiable {
    let step: Int
    let loss: Double
    let strength: Double
    var id: Int { step }
}

final class TrainingSession: ObservableObject {
    static let shared = TrainingSession()
    @Published var phase = 0
    @Published var mode: TrainingMode = .analysis
    @Published var selectedLords: Set<String> = []
    /// Snimke partija za trening (MatchHistoryRecord.id).
    @Published var selectedMatchIds: Set<String> = []
    @Published var training = false
    /// 0…1 po modu. Gumb na islandu čita postotak.
    @Published var progress: [TrainingMode: Double] = [:]

    func percent(for mode: TrainingMode) -> Int {
        Int(((progress[mode] ?? 0) * 100).rounded())
    }

    func setProgress(_ mode: TrainingMode, _ value: Double) {
        var next = progress
        next[mode] = min(1, max(0, value))
        progress = next
    }

    func selectMatchForTraining(id: String) {
        selectedMatchIds = [id]
        mode = .analysis
        jumpToTraining = true
    }

    /// MainMenu otvara island Trening kad je true.
    @Published var jumpToTraining = false
    /// Rezultat Analize: dobre / loše odluke (Učenje ih koristi).
    @Published var judgments: [JudgedDecision] = []
    /// Rezultat Predviđanja: pogodci / promašaji.
    @Published var predictionReport: AIPredictionReport?
    /// Koliko sekundi snimke lord smije vidjeti (ostatak mu je skriven).
    @Published var predictionSightSeconds: Int = 30
}

struct AITrainingView: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var lords = AILordProfileStore.shared
    @ObservedObject private var history = MatchHistoryStore.shared
    @ObservedObject private var session = TrainingSession.shared

    @State private var samples: [TrainSample] = []
    @State private var trained = false
    @State private var statusLine = ""
    @State private var analyzed = false

    private var training: Bool {
        get { session.training }
        nonmutating set { session.training = newValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            lordPhase
            matchPhase
            if !session.selectedLords.isEmpty {
                trainPhase
            }
        }
    }

    private var lordPhase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("1. Označi AI lordove koje želiš trenirati.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 8)], spacing: 8) {
                    ForEach(lords.profiles) { profile in
                        toggleRow(
                            title: profile.localizedName(language: gameState.appLanguage),
                            detail: "inačica \(profile.modelVersion) · level \(String(format: "%.1f", lords.level(for: profile).value))",
                            on: session.selectedLords.contains(profile.id)
                        ) {
                            toggleLord(profile.id)
                        }
                    }
                }
            }
            .frame(maxHeight: 160)
        }
    }

    private var matchPhase: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("2. Označi snimljene partije.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
            Text(matchModeHint)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
            if history.summaries.isEmpty {
                Text("Nema snimki. Uključi Snimi u partiji, odigraj, pa se vrati ovdje.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], spacing: 8) {
                        ForEach(history.summaries.prefix(24)) { summary in
                            toggleRow(
                                title: summary.title,
                                detail: "\(summary.mapLabel) · \(summary.frameCount) okvira · \(summary.partyLabel)",
                                on: session.selectedMatchIds.contains(summary.id)
                            ) {
                                toggleMatch(summary.id)
                            }
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }

    private var trainPhase: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch session.mode {
            case .analysis:
                analysisMode
            case .learning:
                learningMode
            case .prediction:
                predictionMode
            case .decision:
                modePanel("Odlučivanje", "Lord iz predviđanja bira potez.")
            }
        }
    }

    private var matchModeHint: String {
        switch session.mode {
        case .analysis:
            return "Analiza: ocjenjuje je li svaka odluka bila dobra ili loša."
        case .learning:
            return "Učenje: lord trenira na označenim partijama (koristi ocjene iz Analize)."
        case .prediction:
            return "Predviđanje: lord gleda situaciju i pogađa što slijedi (potez + ishod)."
        case .decision:
            return "Odlučivanje: lord iz predviđanja bira potez."
        }
    }

    private var analysisMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Analiza nije trening — lord uči koje su odluke bile dobre, a koje loše.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            actionButton(
                "Ocijeni odluke",
                enabled: !session.training && !session.selectedMatchIds.isEmpty
            ) { analyze() }
            if session.selectedMatchIds.isEmpty {
                Text("Odaberi barem jednu snimljenu partiju.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
            if analyzed {
                judgmentSummary
                judgmentList
            }
            if !statusLine.isEmpty {
                Text(statusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    private var learningMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Učenje upisuje težine: dobre odluke se jačaju, loše se kažnjavaju.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            actionButton(
                "Treniraj lordove",
                enabled: canTrain
            ) { startTraining() }
            if session.selectedLords.isEmpty {
                Text("Označi lordove (korak 1).")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            } else if session.selectedMatchIds.isEmpty {
                Text("Označi snimljene partije (korak 2).")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            } else if !analyzed && session.judgments.isEmpty {
                Text("Preporuka: prvo Analiza → Ocijeni odluke, pa Učenje.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            } else if trained {
                Text("Trening je upisan u težine lordova.")
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.white.opacity(0.92))
            }
            if !statusLine.isEmpty {
                Text(statusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if !samples.isEmpty {
                trainingGraph
            }
        }
    }

    private var predictionMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lord ne vidi cijelu partiju — samo onoliko sekundi koliko mu daš. Iz toga pogađa što slijedi.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            sightSlider
            HStack(spacing: 10) {
                actionButton(
                    "Pokreni predviđanje",
                    enabled: canPredict
                ) { runPrediction() }
                actionButton(
                    "Treniraj predviđanje",
                    enabled: canTrain
                ) { startPredictionTraining() }
            }
            if session.selectedLords.isEmpty {
                Text("Označi lordove (korak 1).")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            } else if session.selectedMatchIds.isEmpty {
                Text("Označi snimljene partije (korak 2).")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if let report = session.predictionReport {
                predictionSummary(report)
                predictionList(report)
            }
            if !statusLine.isEmpty {
                Text(statusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if !samples.isEmpty {
                trainingGraph
            }
        }
    }

    private var sightMaxSeconds: Int {
        let records = session.selectedMatchIds.compactMap { history.record(id: $0) }
        return AIMatchPrediction.maxSeconds(in: records)
    }

    private var sightSlider: some View {
        let maxS = max(10, sightMaxSeconds)
        let clamped = min(max(5, session.predictionSightSeconds), maxS)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Vid lorda")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(clamped) s od \(maxS) s")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.9))
            }
            Slider(
                value: Binding(
                    get: { Double(min(max(5, session.predictionSightSeconds), maxS)) },
                    set: { session.predictionSightSeconds = Int($0.rounded()) }
                ),
                in: 5...Double(maxS),
                step: 1
            )
            .tint(.yellow)
            Text("Sve nakon \(clamped)s ostaje skriveno; lord predviđa upravo to.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .onAppear {
            session.predictionSightSeconds = min(max(5, session.predictionSightSeconds), maxS)
        }
        .onChange(of: session.selectedMatchIds) { _ in
            let m = max(10, sightMaxSeconds)
            session.predictionSightSeconds = min(max(5, session.predictionSightSeconds), m)
        }
    }

    private func predictionSummary(_ report: AIPredictionReport) -> some View {
        let pct = Int((report.actionAccuracy * 100).rounded())
        let valueText: String = {
            guard let err = report.meanValueError else { return "ishod ?" }
            return String(format: "ishod ±%.2f", err)
        }()
        return HStack(spacing: 12) {
            Text("Potez \(report.actionHits)/\(report.actionTotal) (\(pct)%)")
                .foregroundStyle(pct >= 50
                                 ? Color(red: 0.45, green: 0.82, blue: 0.45)
                                 : Color(red: 0.95, green: 0.55, blue: 0.35))
            Text(valueText)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
    }

    private func predictionList(_ report: AIPredictionReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(report.trials.prefix(40)) { trial in
                    predictionRow(trial)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    private func predictionRow(_ trial: AIPredictionTrial) -> some View {
        let color: Color = trial.actionHit
            ? Color(red: 0.45, green: 0.82, blue: 0.45)
            : Color(red: 0.95, green: 0.4, blue: 0.35)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(trial.actionHit ? "✔" : "✘")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text("vid \(trial.visibleThroughSecond)s → \(trial.second)s")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Text(shortAction(trial.predictedActionId))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("→")
                    .foregroundStyle(.white.opacity(0.35))
                Text(shortAction(trial.actualActionId))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(String(format: "v %.2f", trial.predictedValue))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(trial.note)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func shortAction(_ id: String) -> String {
        if id.hasPrefix("action:build:") { return String(id.dropFirst("action:build:".count)) }
        if id.hasPrefix("action:") { return String(id.dropFirst("action:".count)) }
        return id
    }

    private var judgmentSummary: some View {
        let good = session.judgments.filter { $0.quality == .good }.count
        let bad = session.judgments.filter { $0.quality == .bad }.count
        let mid = session.judgments.filter { $0.quality == .neutral }.count
        return HStack(spacing: 12) {
            Text("✔ \(good)")
                .foregroundStyle(Color(red: 0.45, green: 0.82, blue: 0.45))
            Text("✘ \(bad)")
                .foregroundStyle(Color(red: 0.95, green: 0.4, blue: 0.35))
            Text("· \(mid)")
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
    }

    private var judgmentList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(session.judgments.prefix(40)) { item in
                    judgmentRow(item)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    private func judgmentRow(_ item: JudgedDecision) -> some View {
        let color: Color = {
            switch item.quality {
            case .good: return Color(red: 0.45, green: 0.82, blue: 0.45)
            case .bad: return Color(red: 0.95, green: 0.4, blue: 0.35)
            case .neutral: return .white.opacity(0.55)
            }
        }()
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(LocalizedStrings.string(for: item.quality.localeKey, language: gameState.appLanguage))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text("\(item.decision.second)s · \(item.decision.actor)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                // Ručna korekcija ocjene.
                ForEach(DecisionQuality.allCases, id: \.rawValue) { q in
                    Button {
                        setJudgment(item.id, quality: q)
                    } label: {
                        Text(q == .good ? "✔" : q == .bad ? "✘" : "·")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(item.quality == q ? color : .white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(item.decision.action)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
            Text(item.reason)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var canTrain: Bool {
        !session.training
            && !session.selectedLords.isEmpty
            && !session.selectedMatchIds.isEmpty
    }

    private var canPredict: Bool {
        !session.training
            && !session.selectedLords.isEmpty
            && !session.selectedMatchIds.isEmpty
    }

    private func modePanel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Georgia", size: 18))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
            Text(selectedLordNames)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedLordNames: String {
        let names = lords.profiles
            .filter { session.selectedLords.contains($0.id) }
            .map { $0.localizedName(language: gameState.appLanguage) }
        return names.isEmpty ? "Nije odabran lord." : names.joined(separator: " · ")
    }

    private var trainingGraph: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                legendDot(.yellow, "Greška")
                legendDot(Color(red: 0.45, green: 0.82, blue: 0.45), "Snaga")
                Spacer()
                Text(session.training ? "Treniram…" : "Gotovo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            TrainingGraph(samples: samples)
                .frame(height: 220)
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func toggleRow(title: String, detail: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? .yellow : .white.opacity(0.45))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(on ? Color.yellow.opacity(0.12) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? .black : .white.opacity(0.4))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(enabled ? Color.yellow.opacity(0.9) : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func toggleLord(_ id: String) {
        if session.selectedLords.contains(id) { session.selectedLords.remove(id) } else { session.selectedLords.insert(id) }
    }

    private func toggleMatch(_ id: String) {
        if session.selectedMatchIds.contains(id) { session.selectedMatchIds.remove(id) } else { session.selectedMatchIds.insert(id) }
        trained = false
        analyzed = false
        samples = []
        session.judgments = []
        session.predictionReport = nil
    }

    private func setJudgment(_ id: String, quality: DecisionQuality) {
        guard let i = session.judgments.firstIndex(where: { $0.id == id }) else { return }
        session.judgments[i].quality = quality
        session.judgments[i].reason = "Ručna ocjena."
        AIMatchDecisionAnalysis.persistJudgments(session.judgments, into: history)
    }

    private func analyze() {
        let matchIds = Array(session.selectedMatchIds)
        let records = matchIds.compactMap { history.record(id: $0) }
        let judged = AIMatchDecisionAnalysis.judge(records: records)
        session.judgments = judged
        AIMatchDecisionAnalysis.persistJudgments(judged, into: history)
        let good = judged.filter { $0.quality == .good }.count
        let bad = judged.filter { $0.quality == .bad }.count
        let mid = judged.filter { $0.quality == .neutral }.count
        statusLine = "Odluka: \(judged.count) · dobre \(good) · loše \(bad) · neutralne \(mid)"
        analyzed = true
        samples = []
        trained = false
        session.setProgress(.analysis, judged.isEmpty ? 0 : 1)
    }

    private func startTraining() {
        let ids = Array(session.selectedLords)
        let matchIds = Array(session.selectedMatchIds)
        guard !ids.isEmpty, !matchIds.isEmpty else { return }
        var judgments = session.judgments
        if judgments.isEmpty {
            let records = matchIds.compactMap { history.record(id: $0) }
            judgments = AIMatchDecisionAnalysis.judge(records: records)
            session.judgments = judgments
            AIMatchDecisionAnalysis.persistJudgments(judgments, into: history)
            analyzed = true
        }
        training = true
        trained = false
        session.setProgress(.learning, 0)
        samples = [TrainSample(step: 0, loss: 1, strength: 0)]
        statusLine = "Treniram s ocjenama (\(judgments.count) odluka)…"
        let epochs = 16
        Task { @MainActor in
            _ = lords.trainFromMatches(
                profileIds: ids,
                matchIds: matchIds,
                judgments: judgments,
                epochs: epochs
            ) { step, loss01 in
                let t = Double(step) / Double(epochs)
                session.setProgress(.learning, t)
                samples.append(TrainSample(
                    step: step,
                    loss: loss01,
                    strength: min(1, max(0, 1 - loss01))
                ))
            }
            training = false
            trained = true
            statusLine = "Gotovo: dobre↗ loše↘ u težinama."
            session.setProgress(.learning, 1)
        }
    }

    private func runPrediction() {
        let ids = Array(session.selectedLords)
        let matchIds = Array(session.selectedMatchIds)
        guard let first = ids.first, !matchIds.isEmpty else { return }
        let sight = min(max(5, session.predictionSightSeconds), sightMaxSeconds)
        session.predictionSightSeconds = sight
        let report = lords.evaluatePrediction(profileId: first, matchIds: matchIds, sightSeconds: sight)
        session.predictionReport = report
        let pct = Int((report.actionAccuracy * 100).rounded())
        statusLine = "Vid \(sight)s → \(report.actionHits)/\(report.actionTotal) (\(pct)%)"
        session.setProgress(.prediction, report.actionTotal == 0 ? 0 : report.actionAccuracy)
        samples = []
        trained = false
    }

    private func startPredictionTraining() {
        let ids = Array(session.selectedLords)
        let matchIds = Array(session.selectedMatchIds)
        guard !ids.isEmpty, !matchIds.isEmpty else { return }
        let sight = min(max(5, session.predictionSightSeconds), sightMaxSeconds)
        session.predictionSightSeconds = sight
        training = true
        trained = false
        session.setProgress(.prediction, 0)
        samples = [TrainSample(step: 0, loss: 1, strength: 0)]
        statusLine = "Treniram predviđanje (vid \(sight)s)…"
        let epochs = 12
        Task { @MainActor in
            let report = lords.trainPrediction(
                profileIds: ids,
                matchIds: matchIds,
                sightSeconds: sight,
                epochs: epochs
            ) { step, loss01, live in
                let t = Double(step) / Double(epochs)
                session.setProgress(.prediction, max(t, live.actionAccuracy))
                session.predictionReport = live
                samples.append(TrainSample(
                    step: step,
                    loss: loss01,
                    strength: live.actionAccuracy
                ))
            }
            session.predictionReport = report
            training = false
            trained = true
            let pct = Int((report.actionAccuracy * 100).rounded())
            statusLine = "Gotovo (vid \(sight)s): točnost \(pct)%."
            session.setProgress(.prediction, max(report.actionAccuracy, 0.01))
        }
    }
}

private struct TrainingGraph: View {
    var samples: [TrainSample]

    var body: some View {
        Canvas { context, size in
            let pad = CGRect(x: 28, y: 8, width: size.width - 36, height: size.height - 24)
            var grid = Path()
            for i in 0...4 {
                let y = pad.minY + pad.height * CGFloat(i) / 4
                grid.move(to: CGPoint(x: pad.minX, y: y))
                grid.addLine(to: CGPoint(x: pad.maxX, y: y))
            }
            context.stroke(grid, with: .color(.white.opacity(0.12)), lineWidth: 1)
            guard samples.count > 1 else { return }
            context.stroke(line(samples.map(\.loss), in: pad), with: .color(.yellow), lineWidth: 2)
            context.stroke(line(samples.map(\.strength), in: pad), with: .color(Color(red: 0.45, green: 0.82, blue: 0.45)), lineWidth: 2)
        }
    }

    private func line(_ values: [Double], in pad: CGRect) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = pad.minX + pad.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
            let y = pad.maxY - pad.height * CGFloat(min(1, max(0, value)))
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}
