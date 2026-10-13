//
//  CompassCubeView.swift
//  Feudalism
//
//  Jedno slovo (N/E/S/W). Klik: rotacija kamere 90° + sljedeće slovo. 4 klika = 4 strane svijeta. Na početku S.
//

import SwiftUI
import AppKit
import QuartzCore

private let cardinals = ["N", "E", "S", "W"]
let compassCardinals = cardinals

/// Ease-in-out: lagano krene, ubrza u sredini, elegantno uspori pri kraju (cubic).
private func easeInOutCubic(_ t: CGFloat) -> CGFloat {
    if t <= 0 { return 0 }
    if t >= 1 { return 1 }
    if t < 0.5 {
        return 4 * t * t * t
    }
    let u = -2 * t + 2
    return 1 - (u * u * u) / 2
}

/// Indeks 0–3 iz mapRotation (0=N, π/2=E, π=S, 3π/2=W).
func compassCardinalIndex(from rotation: CGFloat) -> Int {
    let twoPi = 2 * CGFloat.pi
    var r = rotation
    while r < 0 { r += twoPi }
    if r >= twoPi { r = 0 }
    let idx = Int((r / (.pi / 2)).rounded(.down)) % 4
    return idx < 0 ? idx + 4 : idx
}

/// Kompas: prvi klik odmah pokreće rotaciju; klik tijekom animacije dodaje još jedan korak (nastavi bez stanka). Nema čekanja.
struct CompassCubeView: View {
    @Binding var mapRotation: CGFloat
    @Binding var panOffset: CGPoint
    /// Kad je postavljeno, dvoklik otvara padajući izbornik. Jedan klik i dalje okreće kameru.
    var onPress: (() -> Void)? = nil
    @State private var clickWait: DispatchWorkItem?
    @StateObject private var displayState = CompassDisplayState()
    @State private var isAnimating = false
    /// Klikovi tijekom animacije → još toliko rotacija nakon trenutnog koraka.
    @State private var queuedExtraRotations = 0

    private let viewWidth: CGFloat = 120
    private let height: CGFloat = 28
    private let cornerRadius: CGFloat = 6
    private let twoPi = 2 * CGFloat.pi
    private let animDuration: Double = 0.3
    private let oneStepDuration: TimeInterval = 0.35

    private var currentLetter: String {
        if let overrideIdx = displayState.overrideIndex {
            return cardinals[overrideIdx]
        }
        return cardinals[compassCardinalIndex(from: mapRotation)]
    }

    /// Jedna rotacija 90°. Kad gotovo: ako ima queued ili remaining, odmah sljedeća; inače kraj.
    private func performOneRotation(remainingSteps: Int, onAllComplete: @escaping () -> Void) {
        let currentIdx = compassCardinalIndex(from: mapRotation)
        let nextIdx = (currentIdx + 1) % 4
        withAnimation(.easeInOut(duration: animDuration)) {
            displayState.overrideIndex = nextIdx
        }
        var start = mapRotation
        while start < 0 { start += twoPi }
        if start >= twoPi { start = start.truncatingRemainder(dividingBy: twoPi) }
        let target = start + .pi / 2
        let startTime = CACurrentMediaTime()
        let state = displayState
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { t in
            let elapsed = CACurrentMediaTime() - startTime
            let ti = min(1.0, CGFloat(elapsed / oneStepDuration))
            let eased = easeInOutCubic(ti)
            var v = start + (target - start) * eased
            while v < 0 { v += twoPi }
            if v >= twoPi { v = v.truncatingRemainder(dividingBy: twoPi) }
            mapRotation = v
            if ti >= 1.0 {
                t.invalidate()
                let extra = queuedExtraRotations
                queuedExtraRotations = 0
                let next = max(0, remainingSteps - 1) + extra
                DispatchQueue.main.async {
                    if next > 0 {
                        performOneRotation(remainingSteps: next, onAllComplete: onAllComplete)
                    } else {
                        state.overrideIndex = nil
                        onAllComplete()
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func rotateOneStep() {
        if isAnimating {
            queuedExtraRotations = min(queuedExtraRotations + 1, 3)
        } else {
            isAnimating = true
            performOneRotation(remainingSteps: 1, onAllComplete: { isAnimating = false })
        }
    }

    private func handlePress() {
        guard onPress != nil else {
            rotateOneStep()
            return
        }
        if let clickWait {
            clickWait.cancel()
            self.clickWait = nil
            onPress?()
            return
        }
        let work = DispatchWorkItem { [self] in
            clickWait = nil
            rotateOneStep()
        }
        clickWait = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: work)
    }

    var body: some View {
        Button(action: handlePress) {
            Text(currentLetter)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: .red, location: 0),
                            .init(color: .red, location: 0.5),
                            .init(color: .white, location: 0.5),
                            .init(color: .white, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: viewWidth, height: height)
                .id(currentLetter)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .frame(width: viewWidth, height: height)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: animDuration), value: currentLetter)
        }
        .buttonStyle(.plain)
        .frame(width: viewWidth, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Glatko okrene kameru na stranu svijeta 0=N, 1=E, 2=S, 3=W.
func spinCamera(toCardinal index: Int, from rotation: CGFloat, apply: @escaping (CGFloat) -> Void) {
    CameraSpin.shared.go(to: index, from: rotation, apply: apply)
}

private final class CameraSpin {
    static let shared = CameraSpin()
    private var timer: Timer?

    func go(to index: Int, from rotation: CGFloat, apply: @escaping (CGFloat) -> Void) {
        timer?.invalidate()
        let twoPi = 2 * CGFloat.pi
        var start = rotation
        while start < 0 { start += twoPi }
        start = start.truncatingRemainder(dividingBy: twoPi)
        let targetBase = CGFloat(index) * .pi / 2
        var delta = targetBase - start
        while delta <= -.pi { delta += twoPi }
        while delta > .pi { delta -= twoPi }
        let target = start + delta
        let startTime = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { t in
            let p = min(1, CGFloat((CACurrentMediaTime() - startTime) / 0.35))
            let eased = easeInOutCubic(p)
            var value = start + (target - start) * eased
            while value < 0 { value += twoPi }
            if value >= twoPi { value = value.truncatingRemainder(dividingBy: twoPi) }
            apply(value)
            if p >= 1 { t.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

/// Override indeks da se slovo promijeni odmah pri kliku (animacija ulaz/izlaz preko .id(currentLetter)).
private final class CompassDisplayState: ObservableObject {
    @Published var overrideIndex: Int?
}

#Preview {
    CompassCubeView(
        mapRotation: .constant(.pi),
        panOffset: .constant(.zero)
    )
    .frame(width: 120, height: 28)
}
