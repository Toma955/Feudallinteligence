//
//  PopulationFlow.swift
//  Feudalism
//
//  Brojač dolaska i odlaska ljudi, na krugu oko vatre ispred dvorca.
//  Partija (ne uređivač mape) prima 10 osoba, plus 10 za svaku kuću.
//  Jedna osoba svakih 30 s. Sreća to ne prekida dok ima mjesta.
//  Dok netko dolazi: krug je proziran i puni se od 0° do 360°.
//  Kad nitko ne dolazi: cijeli krug je pun i zelen.
//  Pada (sreća ispod 50 % kad je dvorac pun, ili ljudi više od kapaciteta): puni se ulijevo (crveno).
//

import Foundation
import QuartzCore

enum PopulationTrend: Equatable {
    case steady
    case growing
    case shrinking
}

struct PopulationRingSnapshot: Equatable {
    let trend: PopulationTrend
    /// 0...1 nakon zadnjeg poteza.
    let progress: Double
    /// Vrijednost prije zadnjeg poteza, za glatki prijelaz.
    let previous: Double
    let changedAt: CFTimeInterval
    let interval: CFTimeInterval
    /// Polumjer kruga oko vatre – računa se prema broju mjesta.
    let radius: Double

    func shown(at now: CFTimeInterval) -> Double {
        let t = interval > 0 ? min(1, max(0, (now - changedAt) / interval)) : 1
        return previous + (progress - previous) * t
    }
}

final class PopulationRingRuntime {
    private let lock = NSLock()
    private var rings: [String: PopulationRingSnapshot] = [:]

    func set(_ values: [String: (trend: PopulationTrend, progress: Double, radius: Double)]) {
        let now = CACurrentMediaTime()
        lock.lock()
        var next: [String: PopulationRingSnapshot] = [:]
        for (id, value) in values {
            let old = rings[id]
            let continues = old.map { $0.trend == value.trend && $0.progress <= value.progress + 1e-6 } ?? false
            next[id] = PopulationRingSnapshot(
                trend: value.trend,
                progress: value.progress,
                previous: continues ? old!.progress : 0,
                changedAt: now,
                interval: old.map { min(3, max(0.05, now - $0.changedAt)) } ?? 1,
                radius: value.radius
            )
        }
        rings = next
        lock.unlock()
    }

    func copySnapshots() -> [String: PopulationRingSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return rings
    }

    func reset() {
        lock.lock()
        rings = [:]
        lock.unlock()
    }
}

extension GameState {
    /// Polumjer kruga na samoj vatri, ne krug na kojem stoje ljudi.
    static let hearthRingRadius = 1.08

    func populationTrend(of seat: RealmSeat) -> PopulationTrend {
        let present = peopleOf(faction: seat.id)
        let capacity = populationCapacity(of: seat.id)
        if present.count < capacity {
            return .growing
        }
        let unhappy = happinessPercent(of: seat.id) < HappinessRules.leaveBelow
        if present.count > capacity || unhappy {
            return present.contains { $0.role != .soldier } ? .shrinking : .steady
        }
        return .steady
    }

    /// Svaki potez pomakne brojač; puni krug = osoba dođe ili ode.
    func tickPopulationFlow() {
        var rings: [String: (trend: PopulationTrend, progress: Double, radius: Double)] = [:]
        for seat in realmSeats.seats where seat.kingAlive {
            refreshFireCircle(of: seat)
            let trend = populationTrend(of: seat)
            var progress = populationProgress[seat.id] ?? 0
            var shown: Double
            switch trend {
            case .growing:
                let step = 1 / Double(Self.immigrationEveryTicks)
                progress = max(0, progress) + step
                shown = progress
                if progress + 1e-6 >= 1 {
                    immigrate(seat: seat)
                    progress = 0
                    shown = 1
                }
            case .shrinking:
                progress = min(0, progress) - 1 / Double(HappinessRules.leaveEveryTicks)
                shown = -progress
                if progress <= -1 + 1e-9 {
                    sendAwayOne(from: seat)
                    progress = 0
                    shown = 1
                }
            case .steady:
                progress = 0
                shown = 0
            }
            populationProgress[seat.id] = progress
            rings[seat.id] = (trend, min(1, shown), Self.hearthRingRadius)
        }
        if showsGraphics { populationRing.set(rings) }
    }

    /// Čim partija krene, krug na vatri je vidljiv: proziran dok prvih 10 još dolazi.
    func presentOpeningPopulationRing() {
        guard showsGraphics else { return }
        var rings: [String: (trend: PopulationTrend, progress: Double, radius: Double)] = [:]
        for seat in realmSeats.seats where seat.kingAlive {
            let trend = populationTrend(of: seat)
            let shown = trend == .growing ? (populationProgress[seat.id] ?? 0) : (trend == .steady ? 1 : 0)
            rings[seat.id] = (trend, min(1, max(0, shown)), Self.hearthRingRadius)
        }
        populationRing.set(rings)
    }
}
