//
//  AILordRulebook.swift
//  Feudalism
//
//  Opća pravila igre u bilježnici AI lordova: građevine, recepti, ograničenja i cjenik.
//  Ista su za sve lordove i za igrača. Ne spremaju se – uvijek se slažu iz kataloga igre,
//  pa prate svaku promjenu cjenika, recepata ili dimenzija. Format je JSON (Swift i Python).
//

import Foundation

struct AILordRulebook: Codable, Equatable {
    var buildings: [BuildingRule]
    var goods: [GoodRule]
    var seasons: SeasonRules
    var storage: [StorageRule]
    var population: PopulationRules
    var army: ArmyRules
    var happiness: HappinessRule
    var match: MatchRules
    var workplaces: WorkplaceRules
    var campaigns: [CampaignRule]
    /// Svi potezi koje lord može odigrati: sagradi kuću/farmu/oružarnicu, obuci, porez, savez…
    var actions: [ActionRule]

    struct BuildingRule: Codable, Equatable, Identifiable {
        var id: String { objectId }
        let objectId: String
        let name: String
        let category: String
        let width: Int
        let height: Int
        let isFlammable: Bool
        /// Roba → količina. Prazno = besplatno.
        let price: [String: Int]
        /// nil = nije radno mjesto.
        let work: WorkRule?
        /// "armory" / "pantry" / "warehouse" / nil.
        let storageKind: String?
        let storageCapacity: Int
        /// Koliko novih ljudi građevina omogućuje. Za kuću je to `peoplePerHouse` iz bilježnice.
        let housing: Int
        /// Naslaga koju građevina traži: "iron" / "stone" / nil.
        let requiredDeposit: String?
        let allowedOnWater: Bool
        let farmlandOnly: Bool
        /// Ostale građevine idu na ravnu podlogu.
        let requiresFlatPad: Bool
        /// Najmanji dio tlocrta na traženoj podlozi (zakon, 0.8).
        let minPadCoverage: Double
        let needsGroundwater: Bool
    }

    struct WorkRule: Codable, Equatable {
        /// field / animal / food / resource / weapon – određuje utjecaj godišnjeg doba.
        let kind: String
        let durationTicks: Int
        let inputs: [String: Int]
        let outputs: [String: Int]
    }

    struct GoodRule: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// "armory" / "pantry" / "warehouse" / nil (bez ograničenja).
        let storedIn: String?
        let producedBy: [String]
        let consumedBy: [String]
        /// Proizvodi se bez ulaza (farma, rudnik, štala…).
        let raw: Bool
        /// Građevine redom od sirovine do ove robe, npr. kruh: farma → mlin → pekara.
        let chain: [String]
    }

    struct MatchRules: Codable, Equatable {
        /// Početne zalihe svake frakcije (iz starting_resources.json).
        let startingStock: [String: Int]
        /// Ljudi na početku; dolaze jedan po jedan do kapaciteta.
        let startingPeople: Int
        /// Sreća na početku je uvijek ista i ne može se mijenjati.
        let startingHappinessFixed: Bool
        let ticksPerSecond: Int
    }

    struct CampaignRule: Codable, Equatable, Identifiable {
        /// "military" / "economic".
        let id: String
        let name: String
        let goal: String
        /// Odnos dva dvorca na početku partije.
        let startingRelation: String
        let relationsChangeable: Bool
        /// "enemies_dead" ili "treasury_paid".
        let winCondition: String
        /// Ponuđeni iznosi riznice (ekonomska); stvarni se bira prije partije.
        let treasuryTargets: [Int]
        /// Nitko ne vidi koliko je drugi uplatio.
        let treasurySecret: Bool
        /// Pao kralj = poraz u obje kampanje.
        let kingDeathLoses: Bool
    }

    struct ActionRule: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// wait / build / train / workplace / economy / diplomacy
        let kind: String
        /// Građevina ili vojnik na kojeg se odnosi; prazno = opći potez.
        let target: String
        /// "military" / "economic" / prazno = obje kampanje.
        let campaign: String
    }

    struct WorkplaceRules: Codable, Equatable {
        let workersPerBuilding: Int
        /// Radnik dolazi samo ako postoji put od vatre vlasnika do građevine.
        let needsPathFromHearth: Bool
        /// Ciklus ne počinje (ulaz se ne troši) dok ne postoji skladište za izlaz s mjestom.
        let needsStorageForOutputs: Bool
        /// Ulaz se uzima iz zaliha vlasnika (skladišta).
        let inputsFromStorage: Bool
        /// Uspavana ili srušena građevina pušta radnika natrag vatri.
        let sleepOrDemolishFreesWorker: Bool
        let burningBuildingStops: Bool
    }

    struct SeasonRules: Codable, Equatable {
        let turnsPerSeason: Int
        let order: [String]
        /// WorkKind → godišnje doba → brzina ciklusa (0 = stoji, 1 = puna).
        let factors: [String: [String: Double]]
    }

    struct StorageRule: Codable, Equatable, Identifiable {
        let id: String
        let building: String
        let capacityPerBuilding: Int
        let goods: [String]
    }

    struct PopulationRules: Codable, Equatable {
        let baseCapacity: Int
        let maxAtFire: Int
        /// Isti broj koji je zapisan u bilježnici (`AILordNotebook.peoplePerHouse`).
        let peoplePerHouse: Int
        let immigrationEveryTicks: Int
        let walkSpeedCellsPerTick: Double
        let ticksPerMeal: Int
        let portionPerPerson: Int
        /// Što se jede, redom.
        let edible: [String]
        /// Novi ljudi dolaze samo dok je sreća barem ovoliko.
        let growsWhenHappinessAtLeast: Double
        /// Kad ljudi ima više nego mjesta (srušena kuća), višak odlazi istim ritmom.
        let overCapacityLeaves: Bool
        /// Tko prvi odlazi; vojnici ostaju.
        let leaveOrder: [String]
    }

    struct HappinessRule: Codable, Equatable {
        let start: Double
        let leaveBelow: Double
        let stepPerMeal: Double
        let hungerPenalty: Double
        let taxPenaltyPerLevel: Double
        let maxTaxLevel: Int
        let leaveEveryTicks: Int
    }

    struct ArmyRules: Codable, Equatable {
        let trainingBuilding: String
        let peoplePerSoldier: Int
        let soldiers: [SoldierRule]
    }

    struct SoldierRule: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// Oprema + zlato.
        let price: [String: Int]
        let speedFactor: Double
        let health: Int
        let mainWeapon: String
        let shield: Bool
        let armor: Bool
        let mounted: Bool
        /// Građevine koje moraju postojati: Trening + gdje se drži oprema (oružarnica, štala).
        let requiredBuildings: [String]
    }
}

extension AILordRulebook {
    static let current = build()

    private static let workKinds: [WorkKind] = [.field, .animal, .food, .resource, .weapon]

    private static func goodsMap(_ items: [Good: Int]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.key.rawValue, $0.value) })
    }

    static func build() -> AILordRulebook {
        let buildings = PlaceableSceneKitTypes.all.map { type -> BuildingRule in
            let id = type.objectId
            let object = ObjectCatalog.shared.object(id: id)
            let cycle = WorkCycleCatalog.cycle(for: id)
            let storage = StorageKind.of(buildingId: id)
            return BuildingRule(
                objectId: id,
                name: object?.name ?? id,
                category: object?.category.key ?? ObjectCategory.ostali.key,
                width: object?.size.width ?? 1,
                height: object?.size.height ?? 1,
                isFlammable: ObjectBehaviorRegistry.behavior(for: id).isFlammable,
                price: goodsMap(PriceList.price(for: id).items),
                work: cycle.map {
                    WorkRule(kind: $0.kind.rawValue, durationTicks: $0.durationTicks, inputs: goodsMap($0.inputs), outputs: goodsMap($0.outputs))
                },
                storageKind: storage?.rawValue,
                storageCapacity: storage?.capacityPerBuilding ?? 0,
                housing: id == House.objectId ? GameState.peoplePerHouse : 0,
                requiredDeposit: BuildRules.requiredDeposit(for: id)?.rawValue,
                allowedOnWater: BuildRules.waterObjectIds.contains(id),
                farmlandOnly: BuildRules.isFarm(id),
                requiresFlatPad: BuildRules.requiredPad(for: id) == .flat,
                minPadCoverage: BuildRules.minPadCoverage,
                needsGroundwater: id == Spring.objectId
            )
        }

        let goods = Good.allCases.map { good in
            let producers = buildings.filter { $0.work?.outputs[good.rawValue] != nil }
            return GoodRule(
                id: good.rawValue,
                name: good.displayName,
                storedIn: StorageKind.of(good)?.rawValue,
                producedBy: producers.map(\.objectId),
                consumedBy: buildings.filter { $0.work?.inputs[good.rawValue] != nil }.map(\.objectId),
                raw: producers.contains { $0.work?.inputs.isEmpty == true },
                chain: chain(for: good.rawValue, buildings: buildings, visited: [])
            )
        }
        let start = StartingResourcesLoader.startingResources()

        let factors = Dictionary(uniqueKeysWithValues: workKinds.map { kind in
            (kind.rawValue, Dictionary(uniqueKeysWithValues: Season.cycle.map { ($0.rawValue, kind.seasonFactor($0)) }))
        })

        return AILordRulebook(
            buildings: buildings,
            goods: goods,
            seasons: SeasonRules(turnsPerSeason: Season.turnsPerSeason, order: Season.cycle.map(\.rawValue), factors: factors),
            storage: StorageKind.allCases.map { kind in
                StorageRule(
                    id: kind.rawValue,
                    building: kind.buildingId,
                    capacityPerBuilding: kind.capacityPerBuilding,
                    goods: kind.goods.map { $0.rawValue }.sorted()
                )
            },
            population: PopulationRules(
                baseCapacity: GameState.baseCapacity,
                maxAtFire: GameState.maxAtFire,
                peoplePerHouse: GameState.peoplePerHouse,
                immigrationEveryTicks: GameState.immigrationEveryTicks,
                walkSpeedCellsPerTick: PeopleRuntime.speedCellsPerSecond,
                ticksPerMeal: FoodRules.ticksPerMeal,
                portionPerPerson: FoodRules.portionPerPerson,
                edible: FoodRules.edible.map { $0.rawValue },
                growsWhenHappinessAtLeast: HappinessRules.leaveBelow,
                overCapacityLeaves: true,
                leaveOrder: [PersonRole.peasant.rawValue, PersonRole.worker.rawValue]
            ),
            army: ArmyRules(
                trainingBuilding: Training.objectId,
                peoplePerSoldier: 1,
                soldiers: SoldierType.allCases.map {
                    SoldierRule(id: $0.rawValue, name: $0.displayName, price: goodsMap(PriceList.soldierPrice($0).items),
                                speedFactor: $0.speedFactor, health: $0.health,
                                mainWeapon: $0.mainWeapon.rawValue, shield: $0.hasShield, armor: $0.hasArmor, mounted: $0.isMounted,
                                requiredBuildings: [Training.objectId] + Set($0.equipment.keys.compactMap { StorageKind.of($0)?.buildingId }).sorted())
                }
            ),
            happiness: HappinessRule(
                start: HappinessRules.start,
                leaveBelow: HappinessRules.leaveBelow,
                stepPerMeal: HappinessRules.stepPerMeal,
                hungerPenalty: HappinessRules.hungerPenalty,
                taxPenaltyPerLevel: HappinessRules.taxPenaltyPerLevel,
                maxTaxLevel: HappinessRules.maxTaxLevel,
                leaveEveryTicks: HappinessRules.leaveEveryTicks
            ),
            match: MatchRules(
                startingStock: [
                    Good.gold.rawValue: start.gold, Good.wood.rawValue: start.wood, Good.iron.rawValue: start.iron,
                    Good.stone.rawValue: start.stone, Good.food.rawValue: start.food, Good.hop.rawValue: start.hop, "hay": start.hay
                ],
                startingPeople: 0,
                startingHappinessFixed: true,
                ticksPerSecond: 1
            ),
            workplaces: WorkplaceRules(
                workersPerBuilding: 1,
                needsPathFromHearth: true,
                needsStorageForOutputs: true,
                inputsFromStorage: true,
                sleepOrDemolishFreesWorker: true,
                burningBuildingStops: true
            ),
            campaigns: CampaignType.allCases.map { type in
                CampaignRule(
                    id: type.rawValue,
                    name: type.displayName,
                    goal: type.goalText,
                    startingRelation: FactionRelation.enemy.rawValue,
                    relationsChangeable: type == .economic,
                    winCondition: type == .military ? "enemies_dead" : "treasury_paid",
                    treasuryTargets: type == .economic ? CampaignSettings.targetOptions : [],
                    treasurySecret: true,
                    kingDeathLoses: true
                )
            },
            actions: makeActions(buildings: buildings, soldiers: SoldierType.allCases)
        )
    }

    private static func makeActions(buildings: [BuildingRule], soldiers: [SoldierType]) -> [ActionRule] {
        func action(_ id: String, _ name: String, kind: String, target: String = "", campaign: String = "") -> ActionRule {
            ActionRule(id: id, name: name, kind: kind, target: target, campaign: campaign)
        }
        var list: [ActionRule] = [
            action("action:wait", "Čekaj", kind: "wait"),
            action("action:tax_up", "Digni porez", kind: "economy"),
            action("action:tax_down", "Spusti porez", kind: "economy"),
            action("action:sleep", "Uspavaj građevinu", kind: "workplace"),
            action("action:wake", "Probudi građevinu", kind: "workplace"),
            action("action:demolish", "Sruši građevinu", kind: "workplace"),
            action("action:deposit_gold", "Uplati zlato u riznicu", kind: "economy", campaign: "economic"),
            action("action:declare_war", "Objavi rat", kind: "diplomacy", campaign: "economic"),
            action("action:make_peace", "Sklopi mir", kind: "diplomacy", campaign: "economic"),
            action("action:make_alliance", "Sklopi savez", kind: "diplomacy", campaign: "economic")
        ]
        for building in buildings where building.objectId != Castle.objectId {
            list.append(action("action:build:\(building.objectId)", "Sagradi \(building.name)", kind: "build", target: building.objectId))
        }
        for type in soldiers {
            list.append(action("action:train:\(type.id)", "Obuči: \(type.displayName)", kind: "train", target: type.id))
        }
        return list
    }

    /// Prvi proizvođač robe, a prije njega lanci njegovih ulaza (bez ponavljanja).
    private static func chain(for good: String, buildings: [BuildingRule], visited: Set<String>) -> [String] {
        guard !visited.contains(good),
              let producer = buildings.first(where: { $0.work?.outputs[good] != nil && $0.work?.inputs.isEmpty == true })
                ?? buildings.first(where: { $0.work?.outputs[good] != nil }),
              let work = producer.work else { return [] }
        var steps: [String] = []
        for input in work.inputs.keys.sorted() {
            for step in chain(for: input, buildings: buildings, visited: visited.union([good])) where !steps.contains(step) {
                steps.append(step)
            }
        }
        if !steps.contains(producer.objectId) { steps.append(producer.objectId) }
        return steps
    }

    func building(_ objectId: String) -> BuildingRule? {
        buildings.first { $0.objectId == objectId }
    }

    func toJSONData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }
}
