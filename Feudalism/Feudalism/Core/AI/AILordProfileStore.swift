//
//  AILordProfileStore.swift
//  Feudalism
//
//  Spremište profila AI lordova – perzistentno; profili uče i postaju bolji kroz partije.
//

import Foundation

/// Spremište profila AI lordova. Kasnije: SwiftData / CloudKit za sync.
final class AILordProfileStore: ObservableObject {
    static let shared = AILordProfileStore()

    @Published private(set) var notebook: AILordNotebook = .emptyShared
    @Published private(set) var levels: [AILordLevel] = []
    @Published private(set) var profiles: [AILordProfile] = []
    /// Matrice levela po levelId; svaki level ima svoju datoteku.
    private(set) var weights: [String: AILordWeights] = [:]

    private let storageKey = "Feudalism.AILordRoster"
    private let versionKey = "Feudalism.AILordRosterVersion"
    /// 1 = 16 lordova, jedna prazna bilježnica, leveli na 0.0.
    private let rosterVersion = 1

    private struct RosterSave: Codable {
        var notebook: AILordNotebook
        var levels: [AILordLevel]
        var profiles: [AILordProfile]
    }

    private init() {
        let savedVersion = UserDefaults.standard.integer(forKey: versionKey)
        if savedVersion >= rosterVersion {
            load()
        }
        if profiles.isEmpty {
            installDefaultRoster()
        }
        if notebook.peoplePerHouse <= 0 {
            notebook.peoplePerHouse = GameState.peoplePerHouse
        }
        save()
        loadWeights()
    }

    private func loadWeights() {
        let vocabulary = notebook.vocabulary
        for levelId in Set(profiles.map(\.levelId)) {
            weights[levelId] = AILordWeightsStore.loadOrCreate(levelId: levelId, vocabulary: vocabulary)
        }
    }

    func weights(for profile: AILordProfile) -> AILordWeights? {
        weights[profile.levelId]
    }

    /// Učitaj sa diska (UserDefaults za sada; kasnije SwiftData).
    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(RosterSave.self, from: data) else {
            return
        }
        notebook = decoded.notebook
        levels = decoded.levels
        profiles = migrateIconsAndColorsIfNeeded(decoded.profiles)
    }

    func level(for profile: AILordProfile) -> AILordLevel {
        levels.first { $0.id == profile.levelId } ?? .empty(id: profile.levelId)
    }

    /// Ako su stari profili bez ikone/boje, dodaj im zadane vrijednosti.
    private func migrateIconsAndColorsIfNeeded(_ list: [AILordProfile]) -> [AILordProfile] {
        let defaults: [(String, String)] = [
            ("flame.fill", "E74C3C"),
            ("shield.fill", "7F8C8D"),
            ("dollarsign.circle.fill", "F1C40F"),
            ("scale.3d", "3498DB"),
            ("theatermasks.fill", "D35400"),
            ("person.3.fill", "27AE60"),
            ("bolt.fill", "F39C12"),
            ("ant.fill", "B7950B"),
            ("moon.fill", "8E44AD"),
            ("link", "1ABC9C")
        ]
        return list.enumerated().map { index, p in
            guard p.iconName == nil || p.colorHex == nil else { return p }
            let (icon, color) = index < defaults.count ? defaults[index] : ("person.fill", "808080")
            var copy = p
            copy.iconName = copy.iconName ?? icon
            copy.colorHex = copy.colorHex ?? color
            return copy
        }
    }

    /// Spremi – profili, bilježnica i leveli ostaju kroz partije.
    func save() {
        let payload = RosterSave(notebook: notebook, levels: levels, profiles: profiles)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        UserDefaults.standard.set(rosterVersion, forKey: versionKey)
    }

    /// Dohvati profil po id.
    func profile(id: String) -> AILordProfile? {
        profiles.first { $0.id == id }
    }

    /// Ažuriraj profil (npr. nakon partije – recordGame).
    func updateProfile(_ profile: AILordProfile) {
        guard let i = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[i] = profile
        save()
    }

    /// Zabilježi rezultat partije za profil – učenje, postaje bolji.
    func recordGameResult(profileId: String, won: Bool) {
        guard var p = profile(id: profileId) else { return }
        p.recordGame(won: won)
        updateProfile(p)
    }

    /// Svaki odabrani lord pročita iste lekcije i upiše ih u svoj level.
    @discardableResult
    func train(profileIds: [String], lessons: [AIMatchLesson], matchIds: [String]) -> [AITrainingNote] {
        var notes: [AITrainingNote] = []
        var pages = notebook.pages
        for lesson in lessons {
            pages.append(AILordNotebookPage(
                title: lesson.title,
                note: lesson.detail,
                matchId: matchIds.joined(separator: ",")
            ))
        }
        notebook.pages = Array(pages.suffix(80))

        for id in profileIds {
            guard var profile = profile(id: id), var levelWeights = weights[profile.levelId] else { continue }
            for lesson in lessons {
                let applied = lesson.delta * styleScale(profile, trait: lesson.trait)
                levelWeights.nudgeTrait(lesson.trait, by: applied)
                notes.append(AITrainingNote(lordId: profile.id, lordName: profile.name, lesson: lesson, applied: applied))
            }
            weights[profile.levelId] = levelWeights
            AILordWeightsStore.save(levelWeights)
            profile.modelVersion += 1
            profile.experienceLevel = min(99, profile.experienceLevel + 1)
            if let index = levels.firstIndex(where: { $0.id == profile.levelId }) {
                levels[index].value = min(100, levels[index].value + Double(lessons.count) * 0.4)
            }
            updateProfile(profile)
        }
        save()
        return notes
    }

    /// Jedan korak treninga. Zadnji korak upiše inačicu, level i bilježnicu.
    func absorb(profileIds: [String], lessons: [AIMatchLesson], fraction: Float, commit: Bool) {
        if commit {
            var pages = notebook.pages
            for lesson in lessons {
                pages.append(AILordNotebookPage(title: lesson.title, note: lesson.detail, matchId: ""))
            }
            notebook.pages = Array(pages.suffix(80))
        }
        for id in profileIds {
            guard var profile = profile(id: id), var levelWeights = weights[profile.levelId] else { continue }
            for lesson in lessons {
                let step = lesson.delta * styleScale(profile, trait: lesson.trait) * fraction
                levelWeights.nudgeTrait(lesson.trait, by: step)
            }
            weights[profile.levelId] = levelWeights
            if commit {
                AILordWeightsStore.save(levelWeights)
                profile.modelVersion += 1
                profile.experienceLevel = min(99, profile.experienceLevel + 1)
                if let index = levels.firstIndex(where: { $0.id == profile.levelId }) {
                    levels[index].value = min(100, levels[index].value + Double(lessons.count) * 0.4)
                }
                updateProfile(profile)
            }
        }
        if commit { save() }
    }

    private func styleScale(_ profile: AILordProfile, trait: String) -> Float {
        switch (profile.fightingStyle, trait) {
        case (.aggressive, "aggression"), (.aggressive, "army_size"), (.raider, "army_size"), (.raider, "aggression"):
            return 1.45
        case (.defensive, "defense"), (.defensive, "patience"):
            return 1.45
        case (.economic, "economy"), (.economic, "food_reserve"), (.economic, "expansion"):
            return 1.45
        case (.diplomat, "diplomacy"), (.diplomat, "patience"):
            return 1.35
        default:
            return 1
        }
    }

    /// Dodaj novi profil (npr. custom bot).
    func addProfile(_ profile: AILordProfile) {
        guard !profiles.contains(where: { $0.id == profile.id }) else { return }
        profiles.append(profile)
        if weights[profile.levelId] == nil {
            weights[profile.levelId] = AILordWeightsStore.loadOrCreate(levelId: profile.levelId, vocabulary: notebook.vocabulary)
        }
        save()
    }

    /// 16 lordova, jedna prazna bilježnica, svaki sa svojim levelom na 0.0.
    private func installDefaultRoster() {
        notebook = AILordRoster.makeNotebook()
        levels = AILordRoster.makeLevels()
        profiles = AILordRoster.makeProfiles()
        save()
    }
}
