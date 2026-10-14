//
//  AILordInference.swift
//  Feudalism
//
//  Forward pass i jednostavno imitacijsko učenje politike (policy / value).
//

import Foundation

extension AILordWeights {
    /// Ulaz: 64 state značajke → logits po akciji i value.
    func forward(stateFeatures: [Float]) -> (logits: [Float], value: Float, hidden: [Float]) {
        precondition(stateFeatures.count == Self.stateFeatures)
        let e = Self.embeddingDim
        let h = Self.hiddenSize
        // Bez tokena: embedding dio = 0.
        var input = stateFeatures
        input.append(contentsOf: [Float](repeating: 0, count: e))

        let h1 = relu(affine(input, weight: "state_in", bias: "state_in.bias", out: h))
        let h2 = relu(affine(h1, weight: "hidden", bias: "hidden.bias", out: h))
        let logits = affine(h2, weight: "policy", bias: "policy.bias", out: actionCount)
        let value = affine(h2, weight: "value", bias: "value.bias", out: 1).first ?? 0
        return (logits, value, h2)
    }

    func softmax(_ logits: [Float]) -> [Float] {
        guard let m = logits.max() else { return [] }
        let exps = logits.map { exp($0 - m) }
        let sum = exps.reduce(0, +)
        guard sum > 0 else { return logits.map { _ in 0 } }
        return exps.map { $0 / sum }
    }

    func bestActionIndex(stateFeatures: [Float]) -> Int {
        let logits = forward(stateFeatures: stateFeatures).logits
        return logits.indices.max(by: { logits[$0] < logits[$1] }) ?? 0
    }

    /// Negativni log-vjerojatnost odabrane akcije (za graf greške).
    func nll(stateFeatures: [Float], actionIndex: Int) -> Float {
        let probs = softmax(forward(stateFeatures: stateFeatures).logits)
        guard actionIndex >= 0, actionIndex < probs.count else { return 5 }
        return -log(max(1e-6, probs[actionIndex]))
    }

    /// Jedan korak imitacije: ojačaj težine prema (stanje → akcija). Dobra odluka.
    mutating func imitate(stateFeatures: [Float], actionIndex: Int, learningRate: Float = 0.04) -> Float {
        guard actionIndex >= 0, actionIndex < actionCount else { return 0 }
        let pass = forward(stateFeatures: stateFeatures)
        let probs = softmax(pass.logits)
        let loss = -log(max(1e-6, probs[actionIndex]))

        // Hebb: ΔW_policy[:,a] += lr * hidden * (1 - p_a)
        let boost = learningRate * (1 - probs[actionIndex])
        bumpMatrix("policy", column: actionIndex, by: pass.hidden.map { $0 * boost })
        bumpBias("policy.bias", index: actionIndex, by: boost)

        // Lagano povuci value prema 0.7 (dobra odluka ≈ bolja procjena).
        let valueErr = 0.7 - pass.value
        bumpMatrix("value", column: 0, by: pass.hidden.map { $0 * learningRate * valueErr * 0.25 })
        bumpBias("value.bias", index: 0, by: learningRate * valueErr * 0.25)

        bumpStateIn(stateFeatures: stateFeatures, hidden: pass.hidden, rate: learningRate * 0.15)
        return loss
    }

    /// Predviđanje ishoda: povuci value head prema cilju (1 pobjeda / 0 poraz).
    mutating func fitValue(stateFeatures: [Float], target: Float, learningRate: Float = 0.03) -> Float {
        let pass = forward(stateFeatures: stateFeatures)
        let err = target - pass.value
        let loss = err * err
        bumpMatrix("value", column: 0, by: pass.hidden.map { $0 * learningRate * err })
        bumpBias("value.bias", index: 0, by: learningRate * err)
        bumpStateIn(stateFeatures: stateFeatures, hidden: pass.hidden, rate: learningRate * 0.1)
        return loss
    }

    /// Loša odluka: smanji vjerojatnost te akcije u tom stanju.
    mutating func reject(stateFeatures: [Float], actionIndex: Int, learningRate: Float = 0.035) -> Float {
        guard actionIndex >= 0, actionIndex < actionCount else { return 0 }
        let pass = forward(stateFeatures: stateFeatures)
        let probs = softmax(pass.logits)
        let loss = -log(max(1e-6, 1 - probs[actionIndex]))

        let penalize = -learningRate * probs[actionIndex]
        bumpMatrix("policy", column: actionIndex, by: pass.hidden.map { $0 * penalize })
        bumpBias("policy.bias", index: actionIndex, by: penalize)

        let valueErr = 0.25 - pass.value
        bumpMatrix("value", column: 0, by: pass.hidden.map { $0 * learningRate * valueErr * 0.2 })
        bumpBias("value.bias", index: 0, by: learningRate * valueErr * 0.2)
        return loss
    }

    private func affine(_ x: [Float], weight: String, bias: String, out: Int) -> [Float] {
        guard let w = block(weight), let b = block(bias) else {
            return [Float](repeating: 0, count: out)
        }
        var y = [Float](repeating: 0, count: out)
        for j in 0..<out {
            var s = b.values[j]
            for i in 0..<min(x.count, w.rows) {
                s += x[i] * w.value(row: i, col: j)
            }
            y[j] = s
        }
        return y
    }

    private func relu(_ x: [Float]) -> [Float] { x.map { max(0, $0) } }

    private mutating func bumpBias(_ name: String, index: Int, by delta: Float) {
        guard let bi = blocks.firstIndex(where: { $0.name == name }),
              blocks[bi].values.indices.contains(index) else { return }
        blocks[bi].values[index] += delta
    }

    private mutating func bumpMatrix(_ name: String, column: Int, by deltas: [Float]) {
        guard let bi = blocks.firstIndex(where: { $0.name == name }) else { return }
        let cols = blocks[bi].cols
        guard column >= 0, column < cols else { return }
        for row in 0..<min(deltas.count, blocks[bi].rows) {
            blocks[bi].values[row * cols + column] += deltas[row]
        }
    }

    private mutating func bumpStateIn(stateFeatures: [Float], hidden: [Float], rate: Float) {
        guard let bi = blocks.firstIndex(where: { $0.name == "state_in" }) else { return }
        let cols = blocks[bi].cols
        let rows = min(stateFeatures.count, blocks[bi].rows)
        for i in 0..<rows {
            let xi = stateFeatures[i]
            for j in 0..<min(hidden.count, cols) {
                blocks[bi].values[i * cols + j] += rate * xi * hidden[j]
            }
        }
    }
}
