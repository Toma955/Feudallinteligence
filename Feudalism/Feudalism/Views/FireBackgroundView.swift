//
//  FireBackgroundView.swift
//  Feudalism
//
//  Veliki plamen u sredini: tamno narančasta atmosfera, jezgra, jezici, iskre.
//

import SwiftUI

struct FireBackgroundView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    Color.black
                    FireAtmosphere(time: t, width: geo.size.width, height: geo.size.height)
                    FlameCluster(time: t, size: side * 0.88)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                    ForEach(0..<68, id: \.self) { i in
                        RisingSpark(time: t, index: i, width: geo.size.width, height: geo.size.height)
                    }
                    EdgeVignette(width: geo.size.width, height: geo.size.height)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct FireAtmosphere: View {
    let time: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let pulse = 0.82 + 0.18 * sin(time * 1.15)
        let reach = max(width, height) * 0.92
        RadialGradient(
            colors: [
                Color(red: 0.98, green: 0.38, blue: 0.06).opacity(0.58 * pulse),
                Color(red: 0.86, green: 0.26, blue: 0.04).opacity(0.52),
                Color(red: 0.62, green: 0.16, blue: 0.03).opacity(0.48),
                Color(red: 0.36, green: 0.10, blue: 0.02).opacity(0.32),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.5),
            startRadius: 12,
            endRadius: reach
        )
        .blur(radius: 22)
        .allowsHitTesting(false)
    }
}

private struct FlameCluster: View {
    let time: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            EmberBed(time: time, size: size)
            OuterBloom(time: time, size: size)
            ForEach(0..<10, id: \.self) { i in
                FlamePetal(time: time, index: i, size: size)
            }
            InnerCore(time: time, size: size)
        }
        .frame(width: size, height: size * 1.28)
        .allowsHitTesting(false)
    }
}

private struct EmberBed: View {
    let time: Double
    let size: CGFloat

    var body: some View {
        let glow = 0.55 + 0.18 * sin(time * 1.7)
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.42, blue: 0.08).opacity(0.55 * glow),
                        Color(red: 0.82, green: 0.22, blue: 0.04).opacity(0.38),
                        Color(red: 0.38, green: 0.10, blue: 0.02).opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.55
                )
            )
            .frame(width: size * 1.05, height: size * 0.42)
            .offset(y: size * 0.1)
            .blur(radius: 22)
    }
}

private struct OuterBloom: View {
    let time: Double
    let size: CGFloat

    var body: some View {
        let pulse = 0.7 + 0.3 * sin(time * 1.35)
        Ellipse()
            .fill(Color(red: 0.78, green: 0.22, blue: 0.04).opacity(0.40 * pulse))
            .frame(width: size * 1.22, height: size * 1.28)
            .offset(y: -size * 0.04)
            .blur(radius: 28)
    }
}

private struct InnerCore: View {
    let time: Double
    let size: CGFloat

    var body: some View {
        let sway = sin(time * 3.4)
        let pulse = 0.86 + 0.14 * sin(time * 7.2)
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.96, blue: 0.78),
                        Color(red: 1.0, green: 0.62, blue: 0.16).opacity(0.92),
                        Color(red: 0.95, green: 0.22, blue: 0.12).opacity(0.55),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.62),
                    startRadius: 0,
                    endRadius: size * 0.26
                )
            )
            .frame(width: size * 0.36, height: size * 0.62)
            .offset(x: size * 0.016 * CGFloat(sway), y: size * 0.02)
            .opacity(pulse)
            .blur(radius: 3)
    }
}

private struct FlamePetal: View {
    let time: Double
    let index: Int
    let size: CGFloat

    var body: some View {
        let sway = sin(time * (1.35 + Double(index) * 0.19) + Double(index) * 0.85)
        let pulse = 0.78 + 0.22 * sin(time * (1.9 + Double(index) * 0.16) + Double(index))
        let xOff = CGFloat(index - 4) * size * 0.055 + CGFloat(sway) * size * 0.045
        let tall = size * (0.62 + CGFloat(index % 4) * 0.09) * CGFloat(pulse)
        let wide = size * (0.2 + CGFloat((index + 2) % 4) * 0.035)
        let yOff = -size * (0.08 + CGFloat(index % 3) * 0.02) * CGFloat(pulse)
        let hot = index % 3 == 0
        let mid = index % 3 == 1
        let c0 = hot
            ? Color(red: 1.0, green: 0.58, blue: 0.12).opacity(0.82)
            : (mid
                ? Color(red: 0.98, green: 0.28, blue: 0.08).opacity(0.78)
                : Color(red: 0.82, green: 0.12, blue: 0.04).opacity(0.72))
        let c1 = hot
            ? Color(red: 0.88, green: 0.16, blue: 0.06).opacity(0.5)
            : (mid
                ? Color(red: 0.7, green: 0.12, blue: 0.03).opacity(0.48)
                : Color(red: 0.42, green: 0.08, blue: 0.02).opacity(0.42))
        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [c0, c1, Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.74),
                    startRadius: 0,
                    endRadius: tall * 0.58
                )
            )
            .frame(width: wide, height: tall)
            .offset(x: xOff, y: yOff)
            .blur(radius: hot ? 2.5 : 4.5)
    }
}

private struct EdgeVignette: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.clear,
                Color.black.opacity(0.28),
                Color.black
            ],
            center: .center,
            startRadius: min(width, height) * 0.52,
            endRadius: hypot(width, height) * 0.58
        )
        .allowsHitTesting(false)
    }
}

/// Iskre od dna / šireg plamena prema vrhu, cijelom visinom ekrana.
private struct RisingSpark: View {
    let time: Double
    let index: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let cycle = 2.6 + Double(index % 8) * 0.38
        let phase = (time + Double(index) * 0.17).truncatingRemainder(dividingBy: cycle)
        let n = min(1, phase / cycle)
        let fade = n < 0.07 ? n / 0.07 : max(0, 1 - (n - 0.78) / 0.22)
        let originX = width * (0.5 + 0.26 * CGFloat(sin(Double(index) * 1.37)) + 0.08 * CGFloat(sin(Double(index) * 2.9)))
        let originY = height * (0.48 + 0.44 * CGFloat((index * 7) % 13) / 12)
        let destY = height * (0.02 + 0.08 * CGFloat(index % 5) / 4)
        let drift = width * 0.045 * CGFloat(sin(n * .pi * 2.2 + Double(index)))
        let x = originX + drift
        let y = originY + (destY - originY) * n * n
        let kind = index % 4
        let color = kind == 0
            ? Color(red: 1.0, green: 0.92, blue: 0.45)
            : (kind == 1
                ? Color(red: 1.0, green: 0.52, blue: 0.12)
                : (kind == 2
                    ? Color(red: 1.0, green: 0.32, blue: 0.06)
                    : Color(red: 0.92, green: 0.22, blue: 0.04)))
        let sparkSize: CGFloat = index % 5 == 0 ? 4.6 : (index % 2 == 0 ? 2.9 : 1.9)
        return Circle()
            .fill(color)
            .frame(width: sparkSize, height: sparkSize)
            .position(x: x, y: y)
            .opacity(fade * 0.92)
            .blur(radius: kind == 3 ? 0.7 : 0.15)
    }
}

#Preview {
    FireBackgroundView()
        .frame(width: 400, height: 300)
}
