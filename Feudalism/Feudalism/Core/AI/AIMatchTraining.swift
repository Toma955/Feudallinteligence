//
//  AIMatchTraining.swift
//  Feudalism
//
//  Jedan ili više lordova čita jednu ili više partija, vidi što je falilo
//  i to upisuje u svoje težine i u zajedničku bilježnicu.
//

import Foundation

struct AIMatchLesson: Identifiable, Equatable {
    let id: String
    var title: String
    var detail: String
    /// Osobina u bloku `traits`.
    var trait: String
    var delta: Float
}

struct AITrainingNote: Identifiable, Equatable {
    var id: String { lordId + lesson.id }
    var lordId: String
    var lordName: String
    var lesson: AIMatchLesson
    var applied: Float
}

enum AIMatchReview {
    static func lessons(in records: [MatchHistoryRecord]) -> [AIMatchLesson] {
        var found: [String: AIMatchLesson] = [:]
        for record in records {
            for lesson in lessons(in: record) {
                if let old = found[lesson.id] {
                    var merged = old
                    merged.delta = max(old.delta, lesson.delta)
                    merged.detail = old.detail
                    found[lesson.id] = merged
                } else {
                    found[lesson.id] = lesson
                }
            }
        }
        return found.values.sorted { $0.title < $1.title }
    }

    static func lessons(in record: MatchHistoryRecord) -> [AIMatchLesson] {
        guard let last = record.frames.last else { return [] }
        let first = record.frames.first ?? last
        let buildings = last.buildings
        let army = last.army
        let earlyArmy = first.army
        var list: [AIMatchLesson] = []

        if count("K", in: buildings) == 0 {
            list.append(AIMatchLesson(
                id: "no-food",
                title: "Nema hrane",
                detail: "U \(record.title) nema mlina, pekare ni smočnice. Glad ruši sreću.",
                trait: "food_reserve",
                delta: 0.12
            ))
        }
        if count("A", in: buildings) == 0 {
            list.append(AIMatchLesson(
                id: "no-farms",
                title: "Nema farmi",
                detail: "U \(record.title) nema polja. Nema odakle puniti smočnicu.",
                trait: "economy",
                delta: 0.1
            ))
        }
        if count("H", in: buildings) == 0 {
            list.append(AIMatchLesson(
                id: "no-houses",
                title: "Nema kuća",
                detail: "U \(record.title) nema kuća, pa novi ljudi nemaju krov.",
                trait: "expansion",
                delta: 0.1
            ))
        }
        if count("L", in: buildings) == 0 {
            list.append(AIMatchLesson(
                id: "no-store",
                title: "Nema skladišta",
                detail: "U \(record.title) nema skladišta. Sirovine nemaju kamo.",
                trait: "economy",
                delta: 0.08
            ))
        }
        if count("W", in: buildings) == 0 {
            list.append(AIMatchLesson(
                id: "no-weapons",
                title: "Nema oružja",
                detail: "U \(record.title) nema oružarnice ni radionica. Vojska ostaje prazna.",
                trait: "army_size",
                delta: 0.1
            ))
        }
        if count("Z", in: buildings) == 0 {
            list.append(AIMatchLesson(
                id: "no-walls",
                title: "Nema zidina",
                detail: "U \(record.title) dvorac nije ograđen.",
                trait: "defense",
                delta: 0.08
            ))
        }
        // Army matrica je numerička (tip,broj,…); stari glifovi V/P i dalje se broje ako postoje.
        let soldiersNow = armySoldierCount(army)
        let peopleThen = max(armySoldierCount(earlyArmy), count("P", in: earlyArmy) + count("p", in: earlyArmy))
        if soldiersNow == 0 && (peopleThen > 0 || count("H", in: first.buildings) > 0) {
            list.append(AIMatchLesson(
                id: "no-army",
                title: "Nitko nije vojnik",
                detail: "U \(record.title) ljudi su ostali seljaci. Nema tko da brani dvorac.",
                trait: "aggression",
                delta: 0.08
            ))
        }
        if list.isEmpty {
            list.append(AIMatchLesson(
                id: "steady",
                title: "Partija je bila uredna",
                detail: "U \(record.title) ima hrane, kuća i rada. Lord samo malo uspori i drži zalihu.",
                trait: "patience",
                delta: 0.04
            ))
        }
        return list
    }

    /// Bez partija: gleda osobine odabranih lordova i kaže što im fali za njihov stil.
    static func lessons(for profiles: [AILordProfile], store: AILordProfileStore) -> [AIMatchLesson] {
        var found: [String: AIMatchLesson] = [:]
        for profile in profiles {
            guard let weights = store.weights(for: profile) else { continue }
            for aim in aims(profile.fightingStyle) {
                let now = weights.traitValue(aim.trait)
                let gap = aim.target - now
                guard gap > 0.04 else { continue }
                let lesson = AIMatchLesson(
                    id: aim.trait,
                    title: aim.title,
                    detail: "\(profile.name): \(aim.detail) Sada \(Int(now * 100)) %, cilj \(Int(aim.target * 100)) %.",
                    trait: aim.trait,
                    delta: min(0.16, gap * 0.55)
                )
                if let old = found[lesson.id] {
                    var merged = old
                    merged.delta = max(old.delta, lesson.delta)
                    merged.detail = old.detail + " " + lesson.detail
                    found[lesson.id] = merged
                } else {
                    found[lesson.id] = lesson
                }
            }
        }
        if found.isEmpty {
            return [AIMatchLesson(
                id: "steady",
                title: "Već su jaki",
                detail: "Odabrani lordovi su blizu svog stila. Trening ih samo malo učvrsti.",
                trait: "patience",
                delta: 0.03
            )]
        }
        return found.values.sorted { $0.title < $1.title }
    }

    private struct Aim {
        var trait: String
        var target: Float
        var title: String
        var detail: String
    }

    private static func aims(_ style: AIFightingStyle) -> [Aim] {
        switch style {
        case .aggressive:
            return [
                Aim(trait: "aggression", target: 0.78, title: "Preslab napad", detail: "Agresivni stil treba jači prvi udar."),
                Aim(trait: "army_size", target: 0.72, title: "Premala vojska", detail: "Nema dovoljno ljudi pod oružjem.")
            ]
        case .defensive:
            return [
                Aim(trait: "defense", target: 0.8, title: "Slaba obrana", detail: "Zidine i štitovi su mu preniski."),
                Aim(trait: "patience", target: 0.7, title: "Prenagli", detail: "Brani se prije nego što juri.")
            ]
        case .economic:
            return [
                Aim(trait: "economy", target: 0.8, title: "Slabo gospodarstvo", detail: "Treba više graditi i puniti zalihe."),
                Aim(trait: "food_reserve", target: 0.74, title: "Tanka hrana", detail: "Smočnica mu je premala za njegov stil.")
            ]
        case .raider:
            return [
                Aim(trait: "aggression", target: 0.74, title: "Meki napad", detail: "Pljačkaš mora udariti i otići."),
                Aim(trait: "risk", target: 0.7, title: "Premalo rizika", detail: "Čeka predugo prije kratkog udara.")
            ]
        case .diplomat:
            return [
                Aim(trait: "diplomacy", target: 0.78, title: "Slabi savezi", detail: "Diplomata treba jače pregovore."),
                Aim(trait: "patience", target: 0.68, title: "Prenagli dogovor", detail: "Savez se ne sklapa u prvom potezu.")
            ]
        case .balanced:
            return [
                Aim(trait: "economy", target: 0.62, title: "Tanka baza", detail: "Uravnotežen lord treba čvršću privredu."),
                Aim(trait: "defense", target: 0.6, title: "Tanka obrana", detail: "I miran stil treba zid.")
            ]
        }
    }

    private static func count(_ mark: Character, in text: String) -> Int {
        text.reduce(0) { $0 + ($1 == mark ? 1 : 0) }
    }

    private static func armySoldierCount(_ army: String) -> Int {
        var n = 0
        for token in army.split(whereSeparator: { $0 == " " || $0 == "\n" }) {
            let parts = token.split(separator: ",")
            guard parts.count >= 2, let type = Int(parts[0]), let count = Int(parts[1]), type > 0 else { continue }
            n += count
        }
        return n + count("V", in: army) + count("v", in: army)
    }
}
