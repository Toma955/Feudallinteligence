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
}

struct AITrainingView: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var lords = AILordProfileStore.shared
    @ObservedObject private var session = TrainingSession.shared

    @State private var lessons: [AIMatchLesson] = []
    @State private var samples: [TrainSample] = []
    @State private var trained = false

    private var training: Bool {
        get { session.training }
        nonmutating set { session.training = newValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            lordPhase
            if !session.selectedLords.isEmpty {
                trainPhase
            }
        }
    }

    private var lordPhase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Označi jednog ili više AI lordova koje želiš trenirati.")
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
                            toggle(profile.id)
                        }
                    }
                }
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
                modePanel("Predviđanje", "Lord gleda situaciju i predviđa što slijedi.")
            case .decision:
                modePanel("Odlučivanje", "Lord iz predviđanja bira potez.")
            }
        }
    }

    private var analysisMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            actionButton("Analiziraj", enabled: !session.training && !session.selectedLords.isEmpty) { analyze() }
            if !lessons.isEmpty {
                Text("Što treba popraviti")
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.white.opacity(0.92))
                lessonList
            }
        }
    }

    private var learningMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            actionButton("Treniraj", enabled: !session.training && !lessons.isEmpty) { startTraining() }
            if lessons.isEmpty {
                Text("Prvo u analizi pokreni Analiziraj.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            } else if trained {
                Text("Trening je upisan")
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.white.opacity(0.92))
            }
            if !samples.isEmpty {
                trainingGraph
            }
        }
    }

    private var lessonList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lessons) { lesson in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        Text(lesson.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .frame(maxHeight: 180)
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

    private func toggle(_ id: String) {
        if session.selectedLords.contains(id) { session.selectedLords.remove(id) } else { session.selectedLords.insert(id) }
    }

    private func analyze() {
        let chosen = lords.profiles.filter { session.selectedLords.contains($0.id) }
        lessons = AIMatchReview.lessons(for: chosen, store: lords)
        samples = []
        trained = false
        session.setProgress(.analysis, lessons.isEmpty ? 0 : 1)
    }

    private func startTraining() {
        let ids = Array(session.selectedLords)
        let plan = lessons
        guard !ids.isEmpty, !plan.isEmpty else { return }
        training = true
        trained = false
        session.setProgress(.learning, 0)
        samples = [TrainSample(step: 0, loss: 1, strength: 0)]
        let steps = 28
        let fraction = 1 / Float(steps)
        Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: 70_000_000)
                let t = Double(step) / Double(steps)
                let loss = 1.02 * exp(-2.6 * t) + 0.035
                lords.absorb(profileIds: ids, lessons: plan, fraction: fraction, commit: step == steps)
                session.setProgress(.learning, t)
                samples.append(TrainSample(step: step, loss: loss, strength: min(1, 1 - loss + 0.04)))
            }
            training = false
            trained = true
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
