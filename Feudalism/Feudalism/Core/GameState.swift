//
//  GameState.swift
//  Feudallinteligence
//
//  Globalno stanje igre – krajevi (realmi), resursi, potezi. Jedan kralj = solo; više = dok zadnji ne ostane.
//

extension Notification.Name {
    /// Mapa mora stati s crtanjem prije nego se vrati glavni izbornik.
    static let feudalismStopMapScene = Notification.Name("Feudalism.stopMapScene")
}
import SwiftUI
import AppKit
import Combine

/// Jedna narudžba koja stiže u gornji desni kut: ikona u krugu i iznos.
struct SupplyDrop: Identifiable, Equatable {
    let id = UUID()
    var icon: String
    var fallback: String
    var amount: Int
    var good: Good
}

/// Označeni kvadrat na karti. Jedan kut je početak, suprotni kut je kraj.
struct GroundMark: Equatable {
    var originRow: Int
    var originCol: Int
    var farRow: Int
    var farCol: Int
}

/// Osoba uhvaćena oznakom. Ostaje u donjem baru dok oznaka ima fokus.
struct MarkedPerson: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
}

/// Ulazni uređaj za upravljanje – u General postavkama; kasnije posebne funkcije za trackpad i miš.

enum InputDevice: String, CaseIterable {
    case trackpad = "trackpad"
    case mouse = "mouse"
    var displayName: String {
        switch self {
        case .trackpad: return "Trackpad"
        case .mouse: return "Miš"
        }
    }
}

/// Jezik sučelja – lokalizacija preko Locales mape (hr, en, de, fr, it, es).
enum AppLanguage: String, CaseIterable, Identifiable {
    case croatian = "hr"
    case english = "en"
    case german = "de"
    case french = "fr"
    case italian = "it"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .croatian: return "Hrvatski"
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .spanish: return "Español"
        }
    }

    /// Lokalni identifikator za učitavanje iz Locales/{rawValue}/.
    var localeIdentifier: String { rawValue }
}

/// Amblem igrača – Postavke → Profil. Kasnije se može proširiti s vlastitim slikama.
enum PlayerEmblem: String, CaseIterable, Identifiable {
    case shield = "shield"
    case crown = "crown"
    case star = "star"
    case flag = "flag"
    case castle = "castle"
    case lion = "lion"

    var id: String { rawValue }

    var sfSymbolName: String {
        switch self {
        case .shield: return "shield.fill"
        case .crown: return "crown.fill"
        case .star: return "star.fill"
        case .flag: return "flag.fill"
        case .castle: return "building.2.fill"
        case .lion: return "pawprint.fill"
        }
    }

    var displayName: String {
        switch self {
        case .shield: return "Štit"
        case .crown: return "Kruna"
        case .star: return "Zvijezda"
        case .flag: return "Zastava"
        case .castle: return "Dvorac"
        case .lion: return "Lav"
        }
    }
}

enum GraphicsQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case ultra
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .low: return "Nisko"
        case .medium: return "Srednje"
        case .high: return "Visoko"
        case .ultra: return "Ultra"
        }
    }
}

enum GameDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .easy: return "Lako"
        case .normal: return "Normalno"
        case .hard: return "Teško"
        }
    }
}

enum SubtitleSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .small: return "Malo"
        case .medium: return "Srednje"
        case .large: return "Veliko"
        }
    }
}

/// Island: eco štedi, normalno je trenutni plamen, crveno diže postavke na maksimum.
enum IslandPowerMode: String, CaseIterable {
    case eco
    case normal
    case red

    var next: IslandPowerMode {
        switch self {
        case .eco: return .normal
        case .normal: return .red
        case .red: return .eco
        }
    }

    var title: String {
        switch self {
        case .eco: return "Eco"
        case .normal: return "Normalno"
        case .red: return "Max"
        }
    }

    var accent: Color {
        switch self {
        case .eco: return Color(red: 0.22, green: 0.82, blue: 0.34)
        case .normal: return .orange
        case .red: return Color(red: 0.92, green: 0.16, blue: 0.14)
        }
    }

    /// Pomak nijanse narančastog plamena.
    var hueDegrees: Double {
        switch self {
        case .eco: return 108
        case .normal: return 0
        case .red: return -32
        }
    }
}

/// Kako se partija prikazuje. Simulacija teče u oba slučaja; grafika je samo sloj iznad.
enum MatchPresentation: String {
    /// Mapa, animacije, kralj koji hoda.
    case graphics
    /// Bez mape i UI-ja: AI protiv AI, samo tekst.
    case simulator
}

/// Način igre: jedan kraj = solo; više = natjecateljski (pobijedi onaj koji zadnji ostane).
enum GameMode {
    /// Jedan realm na mapi – solo igra.
    case solo
    /// Više realmova – igra dok ne ostane samo jedan (ili jedna grupa).
    case lastStanding
}

/// Globalno stanje srednjovjekovne strateške igre.
final class GameState: ObservableObject {
    /// true = glavni izbornik (Nova igra / Postavke / Izlaz), false = igra (karta).
    @Published var isShowingMainMenu: Bool = true
    /// Uključeno gumbom Snimi prije solo graditelja, kampanje ili međusobne partije.
    @Published var recordThisMatch: Bool = false
    /// true = Map Editor (uređivanje mape), ne igra.
    @Published var isMapEditorMode: Bool = false
    /// Solo graditelj: nema vojne/ekonomske pobjede. Građevine ostaju.
    @Published var isSandboxPlay: Bool = false
    /// false dok se level (mapa, teren) ne učita; tek onda se prikaže igra (bez overlay-a).
    @Published var isLevelReady: Bool = false

    /// Poruka tijekom učitavanja mape (npr. "Učitavanje mape (200×200)…", "Generiranje mape (200×200)…"). Nil kad je level spreman.
    @Published var levelLoadingMessage: String?

    /// Krajevi (kraljevstva) na mapi – jedan ili više. Jedan = solo, više = last standing.
    @Published var realms: [Realm] = []
    /// Poruka kad kralj padne i grupa ispadne. Nil dok se to ne dogodi.
    @Published var factionDefeatNotice: String?
    /// Grafika = čovjek u partiji. Simulator/tekst = samo AI lordovi.
    @Published var matchPresentation: MatchPresentation = .graphics
    @Published var isGamePaused = false
    private var matchClock: Timer?
    private var lastAutoSaveTurn = 0
    /// Dvorac (kocka) i kralj koji hoda, po jedan na frakciju.
    let realmSeats = RealmSeatRuntime()
    /// Osobe (seljaci, radnici, vojnici) svih frakcija.
    let people = PeopleRuntime()
    /// Do kojih ćelija se može doći pješice od vatre igrača.
    let reachability = ReachabilityCache()
    /// Oznake iznad građevina (nema radnika, nema puta, spava) za 3D prikaz.
    let buildingAlerts = BuildingAlertsRuntime()
    /// Po frakciji (RealmSeat.id): koliko je porcija falilo za zadnji obrok (0 = pojedeno, 1 = smočnica prazna).
    @Published var foodShortfall: [String: Int] = [:]
    /// Redoslijed ulaska hrane po frakciji. Prva stavka je prva koja izlazi.
    var foodArrival: [String: [Good]] = [:]
    /// Naručeni resursi koji još nisu stigli. Prvi u redu je sljedeći.
    @Published var supplyQueue: [SupplyDrop] = []
    /// Krug koji upravo ulazi s desne strane.
    @Published var activeSupplyDrop: SupplyDrop?
    private var supplyClock: Timer?
    /// Roba naručena prije partije. Ulazi tek kad postoji skladište i slobodno polje. Zlato ne čeka.
    private var pendingStartGoods: [Good: Int] = [:]
    /// Brojač za 3D hrpe na skladištu. Raste pri svakoj kupnji/prodaji/trošenju.
    @Published var warehouseGoodsEpoch: Int = 0
    /// Redoslijed nastanka građevine. Manji broj = starija. Radnik ide prvo u najstariju.
    private var buildingBirth: [String: Int] = [:]
    private var nextBuildingBirth = 0
    /// Po frakciji: sreća 0–100 %. Nema zapisa = 100 %.
    @Published var happiness: [String: Double] = [:]
    /// Brojač prstena iznad vatre: + dolazak, − odlazak; ±1 = jedna osoba.
    var populationProgress: [String: Double] = [:]
    let populationRing = PopulationRingRuntime()
    let pathFinder = PathFinder()
    let oxen = TransportRuntime()
    /// Prijevozne linije (kola): mini-skladište, dozvole i ruta.
    @Published var transportLines: [String: TransportLine] = [:]
    @Published var editingTransportId: String?
    @Published var transportRouteVersion: Int = 0
    @Published var warehouseLayouts: [String: WarehouseLayout] = [:]
    @Published var editingWarehouseRoute: WarehouseRouteEdit?
    @Published var warehouseRouteVersion: Int = 0
    let enclosure = EnclosureCache()
    /// Je li dvorac frakcije opasan (zidovi/voda/vrata) – nitko ne može ući ni izaći osim kroz vrata.
    @Published var castleEnclosed: [String: Bool] = [:]
    /// Odabire se prije partije (postavke); ne briše se novom partijom.
    @Published var campaign = CampaignSettings.standard
    /// Odnos svakog para dvoraca ("a|b"); nema zapisa = neprijatelji.
    @Published var relations: [String: FactionRelation] = [:]
    /// Tajna riznica: koliko je zlata koja frakcija uplatila (ekonomska kampanja).
    @Published var treasury: [String: Int] = [:]
    @Published var campaignResult: CampaignResult?
    /// Tekstualni zapis partije (cijeli prikaz kad igraju samo AI lordovi).
    @Published var matchLog: [MatchLogLine] = []
    /// Frakcije koje su na početku imale neprijatelja (bez toga nema vojne pobjede, npr. solo).
    var hadEnemiesAtStart: [String: Bool] = [:]
    /// Po frakciji: razina poreza (0 = bez poreza). Svaka razina spušta sreću.
    @Published var taxLevels: [String: Int] = [:]
    /// Zalihe AI frakcija. Igračeve su u `resources`, `food` i `goods` (njih čita HUD).
    @Published var factionStocks: [String: [Good: Int]] = [:]
    /// Živi ljudi na karti. Za sada kraljevi; kasnije i oni koji se okupe kod vatre.
    @Published var peopleCount: Int = 0
    /// Učvršćeni kvadrat oznake. Nil dok Olovka ne potvrdi drugi klik.
    @Published var groundMark: GroundMark?
    /// Osobe unutar oznake. Prazno čim oznaka izgubi fokus.
    @Published var markedPeople: [MarkedPerson] = []
    /// Podzemni pogled: ista mapa, `Underground.depthMeters` ispod tla.
    @Published private(set) var isUndergroundView = false
    /// Ime objekta kroz koji se ušlo u podzemlje.
    @Published private(set) var undergroundEntryName: String?

    /// Podzemna mapa istih dimenzija kao površina. Ima svoje građevine.
    private(set) var undergroundMap = GameMap(rows: 0, cols: 0, cells: [:], vertexHeights: [:])

    /// Mapa na kojoj se trenutno gradi: površina ili podzemlje.
    var activeMap: GameMap { isUndergroundView ? undergroundMap : gameMap }

    private var mapLogicCache: (key: String, logic: MapLogic)?

    /// Logička mapa: nadzemna + podzemna kao goli podaci. Simulator i AI lordovi koriste samo nju.
    var mapLogic: MapLogic {
        ensureUndergroundMap()
        let terrainKey = "\(ObjectIdentifier(gameMap).hashValue)_\(editorCellsVersion)"
        let key = "\(terrainKey)_\(ObjectIdentifier(undergroundMap).hashValue)_\(placementsVersion)_\(gameMap.placements.count)_\(undergroundMap.placements.count)"
        if let cache = mapLogicCache, cache.key == key { return cache.logic }
        let logic = MapLogic(surface: gameMap, underground: undergroundMap, terrainKey: terrainKey, previous: mapLogicCache?.logic)
        mapLogicCache = (key, logic)
        return logic
    }

    /// Građevine podzemne mape za spremanje (nil kad ih nema).
    private var savedUndergroundPlacements: [Placement]? {
        guard undergroundMap.rows == gameMap.rows, undergroundMap.cols == gameMap.cols, !undergroundMap.placements.isEmpty else { return nil }
        return undergroundMap.placements
    }

    private func ensureUndergroundMap() {
        guard undergroundMap.rows != gameMap.rows || undergroundMap.cols != gameMap.cols else { return }
        undergroundMap = GameMap(rows: gameMap.rows, cols: gameMap.cols, cells: [:], vertexHeights: [:])
    }

    /// Raste kad editor promijeni teren, naslage, podloge ili kretanje ćelija (za osvježavanje prikaza).
    @Published var editorCellsVersion = 0

    private var groundwaterCache: (map: ObjectIdentifier, water: GroundwaterMap)?

    /// Podzemne vode površinske mape (ne podzemnog sloja).
    var groundwater: GroundwaterMap {
        let id = ObjectIdentifier(gameMap)
        if let cache = groundwaterCache, cache.map == id, cache.water.rows == gameMap.rows, cache.water.cols == gameMap.cols {
            return cache.water
        }
        let water = GroundwaterMap(gameMap: gameMap)
        groundwaterCache = (id, water)
        return water
    }

    /// Bunar i izvor prikazuju podzemne vode na mapi.
    var showsGroundwater: Bool {
        guard !isUndergroundView, let id = selectedPlacementObjectId else { return false }
        return id == Well.objectId || id == Spring.objectId
    }

    /// Zakon podloga: isti u map editoru i u igri. Ne može se isključiti.
    func buildRuleViolation(objectId: String, row: Int, col: Int, width: Int, height: Int) -> String? {
        if isUndergroundView {
            return BuildRules.undergroundViolation(objectId: objectId)
        }
        return BuildRules.violation(objectId: objectId, row: row, col: col, width: width, height: height, map: gameMap, groundwater: groundwater)
    }

    /// Ima li bunar vodu (barem dio tlocrta iznad podzemne vode).
    func wellHasWater(_ placement: Placement) -> Bool {
        groundwater.touchesWater(row: placement.row, col: placement.col, width: placement.width, height: placement.height)
    }

    func undergroundEntrance(row: Int, col: Int) -> Placement? {
        guard let p = gameMap.placement(at: MapCoordinate(row: row, col: col)),
              Underground.entranceObjectIds.contains(p.objectId) else { return nil }
        return p
    }

    func enterUnderground(through placement: Placement) {
        enterUnderground(entryName: Underground.entranceName(objectId: placement.objectId))
    }

    func enterUnderground(entryName: String? = nil) {
        guard !isMapEditorMode, !isGamePaused, !isUndergroundView else { return }
        ensureUndergroundMap()
        selectedPlacementObjectId = nil
        inspectedBuildingTitle = nil
        undergroundEntryName = entryName
        isUndergroundView = true
        if let faction = playerSeat?.id, !CandleRules.hasCandles(self, faction) {
            placementError = "Podzemlje treba svijeću (košnica → vosak → svijeća)."
        }
        placementsVersion += 1
    }

    func leaveUnderground() {
        guard isUndergroundView else { return }
        selectedPlacementObjectId = nil
        isUndergroundView = false
        undergroundEntryName = nil
        placementsVersion += 1
    }

    func toggleUnderground() {
        if isUndergroundView {
            leaveUnderground()
        } else {
            enterUnderground()
        }
    }

    /// Kvadrat hvata samo vojsku. Seljak kod vatre i radnik u zgradi se ne označavaju.
    func people(inside mark: GroundMark) -> [MarkedPerson] {
        soldiers(inside: mark)
    }
    /// Grupe (savezi) – realmi s istim groupId dijele pobjedu.
    @Published var realmGroups: [RealmGroup] = []
    /// Realm kojim igrač upravlja (nil u solo ako nema „protivnika”).
    @Published var playerRealmId: String?

    @Published var food: Int = 80
    /// Jedini izvor istine za kamen, drvo, željezo – sve davanja/trošenja/prodaja idu preko ovoga.
    let resources: GameResources
    private var resourcesCancellable: AnyCancellable?
    private var mapEditorStateCancellable: AnyCancellable?
    @Published var hay: Int = 0
    @Published var hop: Int = 0

    @Published var selectedRegionId: String?
    @Published var selectedMapCoordinate: MapCoordinate?
    @Published var currentTurn: Int = 1

    /// Postavke kamere na mapi (zoom, nagib, brzina pomicanja) – mijenjaju se u Postavkama.
    @Published var mapCameraSettings: MapCameraSettings = MapCameraSettings()

    /// Odabrani objekt za postavljanje (npr. HugeWall.objectId); nil = ništa odabrano.
    @Published var selectedPlacementObjectId: String?
    /// Natpis zgrade u donjem baru. Nil = obična traka alata. Za sada samo dvorac.
    @Published var inspectedBuildingTitle: String? {
        didSet {
            if inspectedBuildingTitle == nil {
                inspectedPlacementId = nil
                editingTransportId = nil
                editingWarehouseRoute = nil
            }
        }
    }
    /// Građevina čije se stanje prikazuje u donjem baru (radnik, ciklus, zdravlje, vatra).
    @Published var inspectedPlacementId: String?

    func inspectPlacement(_ placement: Placement) {
        inspectedPlacementId = placement.id
        inspectedBuildingTitle = ObjectCatalog.shared.object(id: placement.objectId)?.name ?? placement.objectId
        editingTransportId = placement.objectId == Carriage.objectId ? placement.id : nil
        editingWarehouseRoute = nil
        if placement.objectId == Carriage.objectId { ensureTransportLine(for: placement) }
        if StorageKind.of(buildingId: placement.objectId) != nil { ensureWarehouseLayout(for: placement) }
    }

    /// Odabrani alat u panelu Alati: "sword", "mace", "report", "shovel", "pen". Nil = mač (zadano). Utječe na kursor i oznaku u panelu.
    @Published var selectedToolsPanelItem: String?

    /// Nadzemna mapa – grid u 1×1 jedinicama (100×100, 200×200 ili 1000×1000).
    /// Nova nadzemna mapa dobiva novu, praznu podzemnu mapu istih dimenzija.
    @Published var gameMap: GameMap {
        didSet {
            guard gameMap !== oldValue else { return }
            undergroundMap = GameMap(rows: gameMap.rows, cols: gameMap.cols, cells: [:], vertexHeights: [:])
        }
    }

    /// Ime levela za učitavanje iz .scn (bez ekstenzije). Npr. "Level" ili "Maps/Level". Nil = proceduralni teren.
    @Published var currentLevelName: String?
    /// true kad je solo pokrenut s mapom učitanoj iz datoteke (Maps/…); scena gradi teren iz gameMap umjesto Level.scn/SoloLevel.scn.
    @Published var soloMapLoadedFromFile: Bool = false
    /// Povećava se kad se mapa učita, da se teren iznova izgradi.
    @Published var mapSceneEpoch: Int = 0

    /// Povećava se pri svakom place/remove da SwiftUI sigurno ažurira prikaz mape.
    @Published private(set) var placementsVersion: Int = 0

    /// Stanje građevina u partiji (radnik, ciklus, vatra) po placement id.
    @Published var buildingStates: [String: BuildingState] = [:]
    /// Roba koja nije u GameResources ni u `food` (brašno, jaja, oružje…).
    @Published var goods: [Good: Int] = [:]

    func bumpPlacementsVersion() {
        placementsVersion += 1
    }

    /// Broj tickova akumuliranih po placementu za transformere (pivovara: nakon N tickova uzme hmelj, stvori pivo).
    private var transformerTicksAccumulated: [String: Int] = [:]

    /// Ako postavljanje objekta ne uspije, poruka ide u gornji island (HUD).
    @Published var placementError: String? {
        didSet {
            guard let text = placementError, !text.isEmpty, text != oldValue else { return }
            postHUD(HUDMessageKind.inferred(from: text), text)
        }
    }
    /// Poruke i upozorenja u gornjem islandu (podloga, resursi, neprijatelj, igra, multiplayer).
    @Published private(set) var hudMessages: [HUDMessage] = []
    /// Građevina se ne može postaviti jer fali roba. Island tada pokazuje samo tu poruku.
    @Published var buildShortage: BuildShortage?

    func presentBuildShortage(objectId: String, price: Price) {
        var lacks: [Good: Int] = [:]
        for item in price.sortedItems {
            let lack = item.amount - goodAmount(item.good)
            if lack > 0 { lacks[item.good] = lack }
        }
        guard !lacks.isEmpty else {
            buildShortage = nil
            return
        }
        let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
        buildShortage = BuildShortage(objectId: objectId, name: name, lacks: lacks)
        placementDebugLog("FAIL insufficient resources object=\(objectId) missing=\(buildShortage?.lackText ?? "")")
    }

    /// Kupi zlatom samo resurse koji fale za trenutnu građevinu. Radi samo dok tržnica radi.
    func buyShortageMaterials() {
        guard marketIsWorking(), let offer = buildShortage, offer.buyCost > 0, goodAmount(.gold) >= offer.buyCost else { return }
        addGood(.gold, -offer.buyCost)
        for item in offer.materials { addGood(item.good, item.amount) }
        buildShortage = nil
    }

    func clearBuildShortage() {
        buildShortage = nil
    }

    func postHUD(_ kind: HUDMessageKind, _ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if hudMessages.first?.text == trimmed { return }
        hudMessages.insert(HUDMessage(kind: kind, text: trimmed), at: 0)
        if hudMessages.count > 6 { hudMessages = Array(hudMessages.prefix(6)) }
    }

    func dismissHUD(_ id: UUID) {
        hudMessages.removeAll { $0.id == id }
    }

    /// Status učitavanja teksture zida (prikazuje se u Map Editoru). nil = još nije provjereno.
    @Published var wallTextureStatus: String?

    /// Trenutni slot u Map Editoru (postavlja se pri učitavanju; nil kad je Create map).
    @Published var mapEditorCurrentSlot: MapEditorSlot?
    /// Ime trenutne mape (obavezno za spremanje); postavlja se pri učitavanju ili kad korisnik upiše.
    @Published var mapEditorMapName: String = ""
    /// Datum izgradnje mape (postavlja se pri kreiranju; pri učitavanju iz datoteke).
    @Published var mapEditorCreatedDate: Date?
    /// Editor-only stanje (selected, hovered, brushPreview, undo/redo) – generira se pri uključivanju editora, ne spremaju se u datoteku.
    @Published var mapEditorState: MapEditorState?
    /// Povećava se kad se kreira ili učitava mapa – forsira ponovnu izgradnju scene u Map Editoru da se prikaže trenutna mapa.
    @Published private(set) var mapEditorSceneVersion: Int = 0

    /// Trackpad ili miš – u Postavkama → General; kasnije posebne funkcije po uređaju.
    @Published var inputDevice: InputDevice {
        didSet { UserDefaults.standard.set(inputDevice.rawValue, forKey: Self.inputDeviceKey) }
    }

    /// Glasnoća muzike mape (0...1). Postavke → Audio.
    @Published var audioMusicVolume: Double {
        didSet {
            UserDefaults.standard.set(audioMusicVolume, forKey: Self.audioMusicVolumeKey)
            AudioManager.shared.updateMapMusicVolume(volume: effectiveMusicVolume)
        }
    }
    /// Glasnoća zvukova (0...1). Postavke → Audio.
    @Published var audioSoundsVolume: Double {
        didSet { UserDefaults.standard.set(audioSoundsVolume, forKey: Self.audioSoundsVolumeKey) }
    }
    /// Glasnoća govora (0...1). Postavke → Audio.
    @Published var audioSpeechVolume: Double {
        didSet { UserDefaults.standard.set(audioSpeechVolume, forKey: Self.audioSpeechVolumeKey) }
    }

    /// Jezik sučelja (hr, en, de, fr). Postavke → General; priprema za lokalizaciju.
    @Published var appLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.appLanguageKey) }
    }

    /// Naziv profila igrača. Postavke → Profil.
    @Published var playerProfileName: String {
        didSet { UserDefaults.standard.set(playerProfileName, forKey: Self.playerProfileNameKey) }
    }

    /// Amblem profila (shield, crown, …). Postavke → Profil.
    @Published var playerEmblemId: String {
        didSet { UserDefaults.standard.set(playerEmblemId, forKey: Self.playerEmblemIdKey) }
    }
    /// Putanja slike korisnika (krug na početnom zaslonu).
    @Published var playerAvatarPath: String {
        didSet { UserDefaults.standard.set(playerAvatarPath, forKey: Self.playerAvatarPathKey) }
    }
    /// Sekunde provedene u partijama. Postavke → Profil.
    @Published var profilePlaySeconds: Int {
        didSet { UserDefaults.standard.set(profilePlaySeconds, forKey: Self.profilePlaySecondsKey) }
    }
    /// Koliko je partija završeno povratkom u izbornik.
    @Published var profileMatchesPlayed: Int {
        didSet { UserDefaults.standard.set(profileMatchesPlayed, forKey: Self.profileMatchesPlayedKey) }
    }
    /// Koliko je građevina igrač postavio.
    @Published var profileBuildingsPlaced: Int {
        didSet { UserDefaults.standard.set(profileBuildingsPlaced, forKey: Self.profileBuildingsPlacedKey) }
    }
    private var profileStatsNoted = false

    var profilePlayTimeLabel: String {
        let hours = profilePlaySeconds / 3600
        let minutes = (profilePlaySeconds % 3600) / 60
        return "\(hours) h \(minutes) min"
    }

    var playerDisplayName: String {
        let trimmed = playerProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Igrač" : trimmed
    }

    var playerGivenName: String {
        playerDisplayName.split(separator: " ").first.map(String.init) ?? playerDisplayName
    }

    var playerFamilyName: String {
        let parts = playerDisplayName.split(separator: " ").map(String.init)
        return parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
    }

    /// true = prikaži početnu animaciju pri pokretanju igre. Postavke → General.
    @Published var showStartupAnimation: Bool {
        didSet { UserDefaults.standard.set(showStartupAnimation, forKey: Self.showStartupAnimationKey) }
    }

    /// true = prikaži nazive ispod ikona u donjem izborniku (solo). Postavke → General.
    @Published var showBottomBarLabels: Bool {
        didSet { UserDefaults.standard.set(showBottomBarLabels, forKey: Self.showBottomBarLabelsKey) }
    }

    /// true = pri reprodukciji zvuka pri postavljanju objekta (place.wav). Postavke → Audio.
    @Published var playPlacementSound: Bool {
        didSet { UserDefaults.standard.set(playPlacementSound, forKey: Self.playPlacementSoundKey) }
    }

    /// true = reproduciraj transition.wav kad se u donjem baru mijenja kategorija (npr. Dvor → Farma). Postavke → Audio.
    @Published var playBarTransitionSound: Bool {
        didSet { UserDefaults.standard.set(playBarTransitionSound, forKey: Self.playBarTransitionSoundKey) }
    }

    @Published var bleEnabled: Bool {
        didSet { UserDefaults.standard.set(bleEnabled, forKey: Self.bleEnabledKey) }
    }
    @Published var powerMode: Bool {
        didSet { UserDefaults.standard.set(powerMode, forKey: Self.powerModeKey) }
    }
    /// Eco (zeleno), normalno (narančasto) ili crveno (sve postavke na maksimum).
    @Published var islandPowerMode: IslandPowerMode {
        didSet { UserDefaults.standard.set(islandPowerMode.rawValue, forKey: Self.islandPowerModeKey) }
    }
    @Published var fastGame: Bool {
        didSet { UserDefaults.standard.set(fastGame, forKey: Self.fastGameKey) }
    }
    @Published var showLogPanel: Bool {
        didSet { UserDefaults.standard.set(showLogPanel, forKey: Self.showLogPanelKey) }
    }

    @Published var graphicsQuality: GraphicsQuality {
        didSet { UserDefaults.standard.set(graphicsQuality.rawValue, forKey: Self.graphicsQualityKey) }
    }
    @Published var fullscreenEnabled: Bool {
        didSet {
            UserDefaults.standard.set(fullscreenEnabled, forKey: Self.fullscreenEnabledKey)
            applyFullscreenPreference()
        }
    }
    @Published var vsyncEnabled: Bool {
        didSet { UserDefaults.standard.set(vsyncEnabled, forKey: Self.vsyncEnabledKey) }
    }
    @Published var showFPS: Bool {
        didSet { UserDefaults.standard.set(showFPS, forKey: Self.showFPSKey) }
    }
    @Published var gameDifficulty: GameDifficulty {
        didSet { UserDefaults.standard.set(gameDifficulty.rawValue, forKey: Self.gameDifficultyKey) }
    }
    @Published var autoSaveEnabled: Bool {
        didSet { UserDefaults.standard.set(autoSaveEnabled, forKey: Self.autoSaveEnabledKey) }
    }
    @Published var autoSaveIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(autoSaveIntervalMinutes, forKey: Self.autoSaveIntervalMinutesKey) }
    }
    @Published var showTutorialHints: Bool {
        didSet { UserDefaults.standard.set(showTutorialHints, forKey: Self.showTutorialHintsKey) }
    }
    @Published var cameraSensitivity: Double {
        didSet { UserDefaults.standard.set(cameraSensitivity, forKey: Self.cameraSensitivityKey) }
    }
    @Published var invertYAxis: Bool {
        didSet { UserDefaults.standard.set(invertYAxis, forKey: Self.invertYAxisKey) }
    }
    @Published var reduceMotion: Bool {
        didSet { UserDefaults.standard.set(reduceMotion, forKey: Self.reduceMotionKey) }
    }
    @Published var subtitlesEnabled: Bool {
        didSet { UserDefaults.standard.set(subtitlesEnabled, forKey: Self.subtitlesEnabledKey) }
    }
    @Published var subtitleSize: SubtitleSize {
        didSet { UserDefaults.standard.set(subtitleSize.rawValue, forKey: Self.subtitleSizeKey) }
    }
    @Published var highContrastUI: Bool {
        didSet { UserDefaults.standard.set(highContrastUI, forKey: Self.highContrastUIKey) }
    }
    @Published var audioMuted: Bool {
        didSet {
            UserDefaults.standard.set(audioMuted, forKey: Self.audioMutedKey)
            AudioManager.shared.updateMapMusicVolume(volume: effectiveMusicVolume)
        }
    }
    @Published var invertScrollZoom: Bool {
        didSet { UserDefaults.standard.set(invertScrollZoom, forKey: Self.invertScrollZoomKey) }
    }
    /// AI lordovi smiju odlučivati. Isključeno = grade i rade po istim pravilima, ali ne biraju poteze.
    @Published var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: Self.aiEnabledKey) }
    }
    /// Sekunde između razmišljanja jednog lorda.
    @Published var aiThinkIntervalSeconds: Double {
        didSet { UserDefaults.standard.set(aiThinkIntervalSeconds, forKey: Self.aiThinkIntervalKey) }
    }
    /// 0 = oprezan, 1 = agresivan. Množi se s osobinama lorda.
    @Published var aiAggression: Double {
        didSet { UserDefaults.standard.set(aiAggression, forKey: Self.aiAggressionKey) }
    }
    /// 0 = vojska, 1 = gospodarstvo.
    @Published var aiEconomyFocus: Double {
        didSet { UserDefaults.standard.set(aiEconomyFocus, forKey: Self.aiEconomyFocusKey) }
    }
    /// Veličina ikona donjeg bara (0.75…1.5).
    @Published var bottomBarIconScale: Double {
        didSet { UserDefaults.standard.set(bottomBarIconScale, forKey: Self.bottomBarIconScaleKey) }
    }
    /// Područje / širina donjeg islanda (0.8…1.35).
    @Published var bottomBarAreaScale: Double {
        didSet { UserDefaults.standard.set(bottomBarAreaScale, forKey: Self.bottomBarAreaScaleKey) }
    }
    /// Prozirnost donjeg bara (0.35…1).
    @Published var bottomBarOpacity: Double {
        didSet { UserDefaults.standard.set(bottomBarOpacity, forKey: Self.bottomBarOpacityKey) }
    }

    var effectiveMusicVolume: Double { audioMuted ? 0 : audioMusicVolume }
    var effectiveSoundsVolume: Double { audioMuted ? 0 : audioSoundsVolume }
    var effectiveSpeechVolume: Double { audioMuted ? 0 : audioSpeechVolume }

    func applyFullscreenPreference() {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible })
                ?? NSApplication.shared.keyWindow else { return }
        let isFull = window.styleMask.contains(.fullScreen)
        if fullscreenEnabled != isFull {
            window.toggleFullScreen(nil)
        }
    }

    /// Eco štedi, normalno ostavlja sredinu, crveno diže glasnoću, grafiku i donji bar na vrh.
    func cycleIslandPowerMode() {
        let next = islandPowerMode.next
        islandPowerMode = next
        switch next {
        case .eco:
            powerMode = true
            graphicsQuality = .low
            showFPS = false
        case .normal:
            powerMode = false
            graphicsQuality = .medium
            showFPS = false
        case .red:
            powerMode = false
            graphicsQuality = .ultra
            audioMuted = false
            audioMusicVolume = 1
            audioSoundsVolume = 1
            audioSpeechVolume = 1
            vsyncEnabled = false
            showFPS = true
        }
    }

    func resetUserSettings() {
        appLanguage = .croatian
        showStartupAnimation = true
        showBottomBarLabels = true
        inputDevice = .trackpad
        cameraSensitivity = 1
        invertYAxis = false
        invertScrollZoom = false
        audioMuted = false
        audioMusicVolume = 0.6
        audioSoundsVolume = 0.8
        audioSpeechVolume = 0.8
        playPlacementSound = true
        playBarTransitionSound = true
        graphicsQuality = .medium
        fullscreenEnabled = false
        vsyncEnabled = true
        showFPS = false
        powerMode = true
        islandPowerMode = .eco
        gameDifficulty = .normal
        autoSaveEnabled = true
        autoSaveIntervalMinutes = 10
        showTutorialHints = true
        fastGame = false
        showLogPanel = false
        reduceMotion = false
        subtitlesEnabled = false
        subtitleSize = .medium
        highContrastUI = false
        aiEnabled = true
        aiThinkIntervalSeconds = 2
        aiAggression = 0.5
        aiEconomyFocus = 0.5
        bleEnabled = false
        bottomBarIconScale = 1
        bottomBarAreaScale = 1
        bottomBarOpacity = 0.88
    }

    init(mapSize: MapSizePreset = .size200) {
        self.gameMap = mapSize.makeGameMap()
        let res = GameResources()
        self.resources = res
        let raw = UserDefaults.standard.string(forKey: Self.inputDeviceKey) ?? InputDevice.trackpad.rawValue
        self.inputDevice = InputDevice(rawValue: raw) ?? .trackpad
        let langRaw = UserDefaults.standard.string(forKey: Self.appLanguageKey) ?? AppLanguage.croatian.rawValue
        self.appLanguage = AppLanguage(rawValue: langRaw) ?? .croatian
        self.playerProfileName = UserDefaults.standard.string(forKey: Self.playerProfileNameKey) ?? ""
        let emblemRaw = UserDefaults.standard.string(forKey: Self.playerEmblemIdKey) ?? PlayerEmblem.shield.rawValue
        self.playerEmblemId = PlayerEmblem(rawValue: emblemRaw)?.rawValue ?? PlayerEmblem.shield.rawValue
        self.playerAvatarPath = UserDefaults.standard.string(forKey: Self.playerAvatarPathKey) ?? ""
        self.profilePlaySeconds = UserDefaults.standard.object(forKey: Self.profilePlaySecondsKey) as? Int ?? 0
        self.profileMatchesPlayed = UserDefaults.standard.object(forKey: Self.profileMatchesPlayedKey) as? Int ?? 0
        self.profileBuildingsPlaced = UserDefaults.standard.object(forKey: Self.profileBuildingsPlacedKey) as? Int ?? 0
        self.showStartupAnimation = UserDefaults.standard.object(forKey: Self.showStartupAnimationKey) as? Bool ?? true
        self.showBottomBarLabels = UserDefaults.standard.object(forKey: Self.showBottomBarLabelsKey) as? Bool ?? true
        self.playPlacementSound = UserDefaults.standard.object(forKey: Self.playPlacementSoundKey) as? Bool ?? true
        self.playBarTransitionSound = UserDefaults.standard.object(forKey: Self.playBarTransitionSoundKey) as? Bool ?? true
        self.bleEnabled = UserDefaults.standard.object(forKey: Self.bleEnabledKey) as? Bool ?? false
        self.powerMode = UserDefaults.standard.object(forKey: Self.powerModeKey) as? Bool ?? true
        let powerRaw = UserDefaults.standard.string(forKey: Self.islandPowerModeKey) ?? IslandPowerMode.eco.rawValue
        self.islandPowerMode = IslandPowerMode(rawValue: powerRaw) ?? .eco
        self.fastGame = UserDefaults.standard.object(forKey: Self.fastGameKey) as? Bool ?? false
        self.showLogPanel = UserDefaults.standard.object(forKey: Self.showLogPanelKey) as? Bool ?? false
        let gqRaw = UserDefaults.standard.string(forKey: Self.graphicsQualityKey) ?? GraphicsQuality.medium.rawValue
        self.graphicsQuality = GraphicsQuality(rawValue: gqRaw) ?? .medium
        self.fullscreenEnabled = UserDefaults.standard.object(forKey: Self.fullscreenEnabledKey) as? Bool ?? false
        self.vsyncEnabled = UserDefaults.standard.object(forKey: Self.vsyncEnabledKey) as? Bool ?? true
        self.showFPS = UserDefaults.standard.object(forKey: Self.showFPSKey) as? Bool ?? false
        let diffRaw = UserDefaults.standard.string(forKey: Self.gameDifficultyKey) ?? GameDifficulty.normal.rawValue
        self.gameDifficulty = GameDifficulty(rawValue: diffRaw) ?? .normal
        self.autoSaveEnabled = UserDefaults.standard.object(forKey: Self.autoSaveEnabledKey) as? Bool ?? true
        var interval = UserDefaults.standard.integer(forKey: Self.autoSaveIntervalMinutesKey)
        if interval <= 0 { interval = 10 }
        self.autoSaveIntervalMinutes = interval
        self.showTutorialHints = UserDefaults.standard.object(forKey: Self.showTutorialHintsKey) as? Bool ?? true
        var sensitivity = UserDefaults.standard.object(forKey: Self.cameraSensitivityKey) as? Double ?? 1.0
        if sensitivity <= 0 { sensitivity = 1.0 }
        self.cameraSensitivity = sensitivity
        self.invertYAxis = UserDefaults.standard.object(forKey: Self.invertYAxisKey) as? Bool ?? false
        self.reduceMotion = UserDefaults.standard.object(forKey: Self.reduceMotionKey) as? Bool ?? false
        self.subtitlesEnabled = UserDefaults.standard.object(forKey: Self.subtitlesEnabledKey) as? Bool ?? false
        let ssRaw = UserDefaults.standard.string(forKey: Self.subtitleSizeKey) ?? SubtitleSize.medium.rawValue
        self.subtitleSize = SubtitleSize(rawValue: ssRaw) ?? .medium
        self.highContrastUI = UserDefaults.standard.object(forKey: Self.highContrastUIKey) as? Bool ?? false
        self.audioMusicVolume = UserDefaults.standard.object(forKey: Self.audioMusicVolumeKey) as? Double ?? 0.6
        self.audioSoundsVolume = UserDefaults.standard.object(forKey: Self.audioSoundsVolumeKey) as? Double ?? 0.8
        self.audioSpeechVolume = UserDefaults.standard.object(forKey: Self.audioSpeechVolumeKey) as? Double ?? 0.8
        self.audioMuted = UserDefaults.standard.object(forKey: Self.audioMutedKey) as? Bool ?? false
        self.invertScrollZoom = UserDefaults.standard.object(forKey: Self.invertScrollZoomKey) as? Bool ?? false
        self.aiEnabled = UserDefaults.standard.object(forKey: Self.aiEnabledKey) as? Bool ?? true
        var think = UserDefaults.standard.object(forKey: Self.aiThinkIntervalKey) as? Double ?? 2
        if think < 0.5 { think = 2 }
        self.aiThinkIntervalSeconds = min(10, max(0.5, think))
        var aggression = UserDefaults.standard.object(forKey: Self.aiAggressionKey) as? Double ?? 0.5
        self.aiAggression = min(1, max(0, aggression))
        var economy = UserDefaults.standard.object(forKey: Self.aiEconomyFocusKey) as? Double ?? 0.5
        self.aiEconomyFocus = min(1, max(0, economy))
        var iconScale = UserDefaults.standard.object(forKey: Self.bottomBarIconScaleKey) as? Double ?? 1
        var areaScale = UserDefaults.standard.object(forKey: Self.bottomBarAreaScaleKey) as? Double ?? 1
        var barOpacity = UserDefaults.standard.object(forKey: Self.bottomBarOpacityKey) as? Double ?? 0.88
        if iconScale == 1.5, areaScale == 1.35, barOpacity == 1 {
            iconScale = 1
            areaScale = 1
            barOpacity = 0.88
        }
        self.bottomBarIconScale = min(1.5, max(0.75, iconScale))
        self.bottomBarAreaScale = min(1.35, max(0.8, areaScale))
        self.bottomBarOpacity = min(1, max(0.35, barOpacity))
        self.currentLevelName = "Level"  // učitaj Level.scn ako postoji; inače proceduralni teren
        self.resourcesCancellable = res.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    /// Proslijedi promjene iz mapEditorState (npr. selectedCells) da se SwiftUI i overlay odabira osvježe.
    private func bindMapEditorStateChanges() {
        mapEditorStateCancellable?.cancel()
        mapEditorStateCancellable = mapEditorState?.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Način igre

    /// Jedan kralj na mapi = solo; više = last standing.
    var gameMode: GameMode {
        realms.isEmpty ? .solo : (realms.count == 1 ? .solo : .lastStanding)
    }

    var isSoloMode: Bool { gameMode == .solo }

    var showsGraphics: Bool { matchPresentation == .graphics }

    /// Solo: pogled na geometrijsku sredinu mape, gdje stoje dvorac i kralj.
    func focusSoloCameraOnCenter() {
        guard isSoloMode else { return }
        var camera = mapCameraSettings
        camera.panOffset = .zero
        camera.setZoomPhase(1)
        mapCameraSettings = camera
    }

    /// Grafika: 1, 2 ili 3 koraka u sekundi. Simulator: 10 koraka u sekundi, bez crtanja.
    var matchTicksPerSecond: Double { showsGraphics ? Double(min(3, max(1, gameSpeed))) : 10 }

    /// 1 = normalno, 2 = dvostruko, 3 = trostruko. Mijenja se trokutima na satu.
    @Published var gameSpeed: Int = 1

    func setGameSpeed(_ speed: Int) {
        let next = min(3, max(1, speed))
        gameSpeed = next
        let scale = Double(next)
        people.timeScale = scale
        oxen.timeScale = scale
        realmSeats.timeScale = scale
        guard matchClock != nil else { return }
        startMatchTimer()
    }

    func beginMatchClock() {
        startMatchTimer()
        MatchHistoryStore.shared.beginRecording(from: self)
    }

    private func startMatchTimer() {
        matchClock?.invalidate()
        let interval = 1.0 / max(0.25, matchTicksPerSecond)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.stepMatch()
        }
        RunLoop.main.add(timer, forMode: .common)
        matchClock = timer
    }

    func endMatchClock() {
        matchClock?.invalidate()
        matchClock = nil
    }

    /// Jedan korak pravila. Ne ovisi o mapi ni o animaciji.
    func pauseGame() {
        guard !isGamePaused, !isShowingMainMenu else { return }
        isGamePaused = true
        endMatchClock()
        realmSeats.pauseWalking()
        people.stopTimer()
        oxen.stopTimer()
        AudioManager.shared.stopMapMusic()
    }

    func resumeGame() {
        guard isGamePaused else { return }
        isGamePaused = false
        guard isLevelReady, !isShowingMainMenu else { return }
        beginMatchClock()
        if showsGraphics {
            realmSeats.resumeWalking(rows: gameMap.rows, cols: gameMap.cols)
            people.startTimer()
            oxen.startTimer()
        }
        AudioManager.shared.playMapMusicIfAvailable(volume: effectiveMusicVolume)
    }

    func stepMatch() {
        guard !isGamePaused, !isMapEditorMode, isLevelReady, !isShowingMainMenu else { return }
        tickProduction()
        currentTurn += 1
        tickMatchLog()
        checkCampaignVictory()
        maybeAutoSave()
        MatchHistoryStore.shared.recordTick(from: self)
        if activeRealms.isEmpty || (!isSoloMode && !isSandboxPlay && hasWinner) {
            endMatchClock()
            MatchHistoryStore.shared.finishRecording(from: self)
        }
    }

    /// Vrijednost resursa za HUD (id iz HUDResourceCatalog). Koristi za prikaz trake iz kataloga.
    func resourceValue(for resourceId: String) -> Int {
        switch resourceId {
        case "gold": return resources.gold
        case "wood": return resources.wood
        case "stone": return resources.stone
        case "iron": return resources.iron
        case "hop": return resources.hop
        case "beer": return resources.beer
        case "food": return food
        case "hay": return hay
        default: return Good(rawValue: resourceId).map { goodAmount($0) } ?? 0
        }
    }

    /// Prilagodi resurs za delta (+/-); za HUD gumbe +1, +5, … -500. Vrijednost ne ide ispod 0.
    func adjustResource(id resourceId: String, delta: Int) {
        let current = resourceValue(for: resourceId)
        let newValue = max(0, current + delta)
        let diff = newValue - current
        if diff == 0 { return }
        switch resourceId {
        case "gold":
            if diff > 0 { resources.add(gold: diff) } else { resources.subtract(gold: -diff) }
        case "wood", "stone", "iron", "hop", "beer", "hay":
            if let good = Good(rawValue: resourceId) { addGood(good, diff) }
        case "food":
            addGood(.food, diff)
        default:
            if let good = Good(rawValue: resourceId) { addGood(good, diff) }
        }
    }

    /// Aktivni krajevi (nisu poraženi).
    var activeRealms: [Realm] {
        realms.filter { !$0.isDefeated }
    }

    /// Human lords – igrač kontrolira igru (ovi krajevi).
    var humanLords: [Realm] { realms.filter { $0.lordType == .human } }

    /// Computer lords – AI kontrolira ove krajeve.
    var computerLords: [Realm] { realms.filter { $0.lordType == .computer } }

    /// Frakcija = jedan realm (ako nema grupe) ili grupa. Preostale frakcije = različiti groupId ili nil.
    private var remainingFactionIds: Set<String> {
        let active = activeRealms
        return Set(active.map { $0.groupId ?? $0.id })
    }

    /// Ima li samo jedna frakcija preostala (jedan realm ili jedna grupa)?
    var hasSingleRemainingFaction: Bool {
        remainingFactionIds.count == 1
    }

    /// Pobjednik: jedan preostali realm ili jedna preostala grupa. Nil = igra nije gotova.
    var winningRealmId: String? {
        let active = activeRealms
        guard !active.isEmpty, hasSingleRemainingFaction else { return nil }
        return active.first?.id
    }

    /// Pobjednička grupa (ako je pobjeda saveza). Nil ako je pobjednik pojedinačni realm (nema grupe).
    var winningGroupId: String? {
        let active = activeRealms
        guard active.count > 1, hasSingleRemainingFaction,
              let gid = active.first?.groupId, !gid.isEmpty else { return nil }
        return gid
    }

    /// Je li igra gotova (ima pobjednika)?
    var hasWinner: Bool { winningRealmId != nil }

    /// Označi kraj kao poražen (nema teritorija / kralj pao).
    func defeatRealm(id: String) {
        guard let i = realms.firstIndex(where: { $0.id == id }) else { return }
        realms[i].isDefeated = true
    }

    /// Dodaj kraj na mapu.
    func addRealm(_ realm: Realm) {
        guard !realms.contains(where: { $0.id == realm.id }) else { return }
        realms.append(realm)
        if realm.isPlayerControlled { playerRealmId = realm.id }
    }

    /// Postavi listu kraljevstava (nova igra).
    func setRealms(_ newRealms: [Realm]) {
        realms = newRealms
        playerRealmId = newRealms.first { $0.isPlayerControlled }?.id
    }

    /// Prikaži glavni izbornik (nazad iz igre).
    func showMainMenu() {
        noteProfileMatch()
        NotificationCenter.default.post(name: .feudalismStopMapScene, object: nil)
        MatchHistoryStore.shared.finishRecording(from: self)
        isGamePaused = false
        leaveUnderground()
        endMatchClock()
        clearRealmSeats()
        isShowingMainMenu = true
        isSandboxPlay = false
        cancelOpeningSupplies()
    }

    /// Jednom po partiji zapiše sate i broj partija na profil.
    private func noteProfileMatch() {
        guard !isMapEditorMode, !isShowingMainMenu, !profileStatsNoted, currentTurn > 1 else { return }
        profilePlaySeconds += max(0, currentTurn - 1)
        profileMatchesPlayed += 1
        profileStatsNoted = true
    }

    /// Ista partija ispočetka: prazna mapa, resursi na početak, kralj opet u sredini.
    func restartCurrentMatch() {
        MatchHistoryStore.shared.finishRecording(from: self)
        isGamePaused = false
        leaveUnderground()
        endMatchClock()
        clearRealmSeats()
        gameMap.replacePlacements([])
        undergroundMap.replacePlacements([])
        placementsVersion += 1
        currentTurn = 1
        food = 80
        hay = 0
        hop = 0
        transformerTicksAccumulated = [:]
        buildingStates = [:]
        goods = [:]
        foodArrival = [:]
        foodShortfall = [:]
        happiness = [:]
        populationProgress = [:]
        castleEnclosed = [:]
        taxLevels = [:]
        factionStocks = [:]
        transportLines = [:]
        editingTransportId = nil
        warehouseLayouts = [:]
        editingWarehouseRoute = nil
        oxen.reset()
        matchLog = []
        lastAutoSaveTurn = 0
        gameSpeed = 1
        people.timeScale = 1
        oxen.timeScale = 1
        realmSeats.timeScale = 1
        if isSoloMode {
            resources.resetForNewSoloGame()
        }
        spawnRealmSeatsIfNeeded(animated: showsGraphics)
        beginMatchClock()
        AudioManager.shared.playMapMusicIfAvailable(volume: effectiveMusicVolume)
    }

    func captureMatchRecording() -> String {
        MatchHistoryStore.shared.captureNow(from: self)
    }

    /// Zadnje auto-spremanje (Application Support/Feudalism/saves/auto.json).
    func saveMatch(elapsedSeconds: Int) -> String {
        do {
            return try writeMatch(makeMatchSave(elapsedSeconds: elapsedSeconds), to: Self.matchSaveURL())
        } catch {
            return "Spremanje nije uspjelo."
        }
    }

    func saveMatch(to fileURL: URL, elapsedSeconds: Int) -> String {
        var url = fileURL
        if url.pathExtension.lowercased() != "json" {
            url = url.appendingPathExtension("json")
        }
        do {
            return try writeMatch(makeMatchSave(elapsedSeconds: elapsedSeconds), to: url)
        } catch {
            return "Spremanje nije uspjelo."
        }
    }

    func loadMatch() -> (message: String, elapsedSeconds: Int?) {
        do {
            return applyMatchFile(at: try Self.matchSaveURL())
        } catch CocoaError.fileReadNoSuchFile {
            if let legacy = Self.legacyMatchSaveURL(), FileManager.default.fileExists(atPath: legacy.path) {
                return applyMatchFile(at: legacy)
            }
            return ("Nema spremljene igre.", nil)
        } catch {
            return ("Učitavanje nije uspjelo.", nil)
        }
    }

    func loadMatch(from fileURL: URL) -> (message: String, elapsedSeconds: Int?) {
        applyMatchFile(at: fileURL)
    }

    static func matchSavesDirectory() -> URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Feudalism/saves", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func savedMatchEntries() -> [SavedMatchEntry] {
        guard let folder = Self.matchSavesDirectory() else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
            .compactMap { url -> SavedMatchEntry? in
                guard let data = try? Data(contentsOf: url),
                      let save = try? JSONDecoder().decode(SoloMatchSave.self, from: data) else { return nil }
                let fileName = url.deletingPathExtension().lastPathComponent
                let name = (save.mapName?.isEmpty == false ? save.mapName! : (fileName == "auto" ? "Automatska" : fileName))
                let marks = save.placements.map { placement in
                    CGPoint(
                        x: Double(placement.col) / Double(max(1, save.cols)),
                        y: Double(placement.row) / Double(max(1, save.rows))
                    )
                }
                return SavedMatchEntry(url: url, name: name, rows: save.rows, cols: save.cols, marks: marks)
            }
    }

    func continueSavedMatch(at url: URL) {
        let result = loadMatch(from: url)
        guard result.message == "Partija je učitana." else { return }
        isMapEditorMode = false
        isLevelReady = false
        isShowingMainMenu = false
    }

    private func makeMatchSave(elapsedSeconds: Int) -> SoloMatchSave {
        let king = realmSeats.seats.first(where: { $0.isPlayerFaction }) ?? realmSeats.seats.first
        let vertexHeights = gameMap.vertexHeights.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: gameMap.vertexHeights.map { ($0.key, Double($0.value)) })
        return SoloMatchSave(
            rows: gameMap.rows,
            cols: gameMap.cols,
            placements: gameMap.placements,
            undergroundPlacements: savedUndergroundPlacements,
            buildingStates: buildingStates,
            transportLines: transportLines,
            warehouseLayouts: warehouseLayouts,
            goods: Dictionary(uniqueKeysWithValues: goods.map { ($0.key.rawValue, $0.value) }),
            people: people.people,
            happiness: happiness,
            taxLevels: taxLevels,
            factionStocks: factionStocks.mapValues { stock in Dictionary(uniqueKeysWithValues: stock.map { ($0.key.rawValue, $0.value) }) },
            campaign: campaign,
            relations: relations,
            treasury: treasury,
            stone: resources.stone,
            wood: resources.wood,
            iron: resources.iron,
            hop: resources.hop,
            beer: resources.beer,
            gold: resources.gold,
            food: food,
            hay: hay,
            playerHop: hop,
            currentTurn: currentTurn,
            elapsedSeconds: max(0, elapsedSeconds),
            kingRow: king?.kingRow ?? 0,
            kingCol: king?.kingCol ?? 0,
            kingHealth: king?.kingHealthPercent ?? 100,
            kingAlive: king?.kingAlive ?? true,
            oxen: oxen.oxen,
            seats: realmSeats.seats,
            transformerTicks: transformerTicksAccumulated,
            populationProgress: populationProgress,
            foodShortfall: foodShortfall,
            hadEnemiesAtStart: hadEnemiesAtStart,
            mapName: mapEditorMapName.isEmpty ? currentLevelName : mapEditorMapName,
            cells: gameMap.cells,
            vertexHeights: vertexHeights,
            vertexOffsets: MapEditorSaveData.encodeOffsets(gameMap.vertexOffsets),
            lordStarts: MapEditorSaveData.encodeLordStarts(gameMap.lordStarts),
            originOffsetX: Double(gameMap.originOffsetX),
            originOffsetZ: Double(gameMap.originOffsetZ),
            currentLevelName: currentLevelName,
            soloMapLoadedFromFile: soloMapLoadedFromFile,
            isUndergroundView: isUndergroundView,
            isSandboxPlay: isSandboxPlay
        )
    }

    private func writeMatch(_ save: SoloMatchSave, to url: URL) throws -> String {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(save)
        try data.write(to: url, options: .atomic)
        lastAutoSaveTurn = currentTurn
        return "Partija je spremljena."
    }

    private func applyMatchFile(at url: URL) -> (message: String, elapsedSeconds: Int?) {
        do {
            let data = try Data(contentsOf: url)
            let save = try JSONDecoder().decode(SoloMatchSave.self, from: data)
            if let error = applyMatchSave(save) {
                return (error, nil)
            }
            return ("Partija je učitana.", save.elapsedSeconds)
        } catch CocoaError.fileReadNoSuchFile {
            return ("Nema spremljene igre.", nil)
        } catch {
            return ("Učitavanje nije uspjelo.", nil)
        }
    }

    private func applyMatchSave(_ save: SoloMatchSave) -> String? {
        let hasTerrain = save.cells != nil
        if !hasTerrain, (save.rows != gameMap.rows || save.cols != gameMap.cols) {
            return "Spremljena igra je za drugu veličinu mape."
        }
        if hasTerrain {
            applyLoadedMapDataForSolo(MapEditorSaveData(
                mapName: save.mapName ?? mapEditorMapName,
                rows: save.rows,
                cols: save.cols,
                placements: save.placements,
                cells: save.cells,
                originOffsetX: save.originOffsetX,
                originOffsetZ: save.originOffsetZ,
                vertexHeights: save.vertexHeights,
                vertexOffsets: save.vertexOffsets,
                lordStarts: save.lordStarts,
                undergroundPlacements: save.undergroundPlacements
            ))
            if let name = save.mapName, !name.isEmpty { mapEditorMapName = name }
            if let level = save.currentLevelName { currentLevelName = level }
            if let fromFile = save.soloMapLoadedFromFile { soloMapLoadedFromFile = fromFile }
            mapSceneEpoch += 1
        } else {
            gameMap.replacePlacements(save.placements)
            ensureUndergroundMap()
            undergroundMap.replacePlacements(save.undergroundPlacements ?? [])
        }
        isSandboxPlay = save.isSandboxPlay ?? false
        buildingStates = save.buildingStates ?? [:]
        transportLines = save.transportLines ?? [:]
        warehouseLayouts = save.warehouseLayouts ?? [:]
        transformerTicksAccumulated = save.transformerTicks ?? [:]
        populationProgress = save.populationProgress ?? [:]
        foodShortfall = save.foodShortfall ?? [:]
        hadEnemiesAtStart = save.hadEnemiesAtStart ?? [:]
        if let saved = save.people { people.restore(saved) }
        oxen.restore(save.oxen ?? [])
        happiness = save.happiness ?? [:]
        taxLevels = save.taxLevels ?? [:]
        if let saved = save.campaign { campaign = saved }
        if let saved = save.relations { relations = saved }
        treasury = save.treasury ?? [:]
        campaignResult = nil
        factionStocks = (save.factionStocks ?? [:]).mapValues { stock in
            Dictionary(uniqueKeysWithValues: stock.compactMap { key, value in Good(rawValue: key).map { ($0, value) } })
        }
        goods = Dictionary(uniqueKeysWithValues: (save.goods ?? [:]).compactMap { key, value in Good(rawValue: key).map { ($0, value) } })
        foodArrival = [:]
        resources.setStock(stone: save.stone, wood: save.wood, iron: save.iron, hop: save.hop, beer: save.beer, gold: save.gold)
        food = save.food
        hay = save.hay
        hop = save.playerHop
        currentTurn = save.currentTurn
        lastAutoSaveTurn = currentTurn
        if let seats = save.seats, !seats.isEmpty {
            realmSeats.restoreSeats(seats)
        } else {
            realmSeats.restorePlayerKing(row: save.kingRow, col: save.kingCol, health: save.kingHealth, alive: save.kingAlive)
        }
        if let underground = save.isUndergroundView, underground != isUndergroundView {
            isUndergroundView = underground
            if !underground { undergroundEntryName = nil }
        }
        bindMatchRuntimes()
        people.mapVersion += 1
        reachability.reset()
        refreshPeopleCount()
        refreshBuildingAlerts()
        placementsVersion += 1
        objectWillChange.send()
        return nil
    }

    private func maybeAutoSave() {
        guard autoSaveEnabled, !isMapEditorMode, isLevelReady, !isShowingMainMenu else { return }
        let intervalTurns = max(1, autoSaveIntervalMinutes) * 60 * max(1, Int(matchTicksPerSecond.rounded()))
        guard currentTurn - lastAutoSaveTurn >= intervalTurns else { return }
        _ = saveMatch(elapsedSeconds: max(0, currentTurn - 1))
    }

    private static func matchSaveURL() throws -> URL {
        guard let folder = matchSavesDirectory() else {
            throw CocoaError(.fileNoSuchFile)
        }
        return folder.appendingPathComponent("auto.json")
    }

    private static func legacyMatchSaveURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Feudalism/solo-match.json")
    }

    /// Pokreni novu igru – skriva izbornik, prikazuje karticu. Resursi se u solo modu animiraju 0→100 kad se level učita.
    func startNewGame() {
        endMatchClock()
        clearRealmSeats()
        isLevelReady = false
        isShowingMainMenu = false
        profileStatsNoted = false
        if showsGraphics {
            levelLoadingMessage = "Učitavanje mape (\(gameMap.displayDimensionString))…"
            if isSoloMode { focusSoloCameraOnCenter() }
        } else {
            levelLoadingMessage = nil
            isLevelReady = true
            spawnRealmSeatsIfNeeded(animated: false)
            beginMatchClock()
        }
        buildingStates = [:]
        goods = [:]
        foodShortfall = [:]
        happiness = [:]
        populationProgress = [:]
        castleEnclosed = [:]
        taxLevels = [:]
        factionStocks = [:]
        transportLines = [:]
        editingTransportId = nil
        warehouseLayouts = [:]
        editingWarehouseRoute = nil
        oxen.reset()
        matchLog = []
        foodArrival = [:]
        cancelOpeningSupplies()
        pendingStartGoods = [:]
        food = 0
        hay = 0
        hop = 0
        seedBuildingBirth()
        if isSoloMode {
            resources.resetForNewSoloGame()
            transformerTicksAccumulated = [:]
        }
    }

    /// Dodaj sebe (human lord) i odabrane AI lordove, pa pokreni igru. Solo = samo ti; mapSize određuje veličinu mape.
    /// Početni resursi: mogu doći iz datoteke (StartingResourcesLoader / starting_resources.json) ili iz UI overridea u SoloSetupView.
    /// initialGold/Wood/Iron/Stone: vrijednosti koje igrač dobiva na početku (pročitane iz filea ili odabrane strelicama).
    /// soloLevelName: ime levela iz bundlea (npr. "Level") ili nil za proceduralnu mapu.
    func startNewGameWithSetup(
        humanName: String,
        humanColorHex: String = "2E86AB",
        selectedAIProfileIds: [String],
        mapSize: MapSizePreset = .size200,
        initialGold: Int = 0,
        initialWood: Int = 0,
        initialIron: Int = 0,
        initialStone: Int = 0,
        initialFood: Int = 0,
        initialHop: Int = 0,
        initialHay: Int = 0,
        soloLevelName: String? = "Level",
        includeHuman: Bool = true,
        presentation: MatchPresentation? = nil,
        sandboxPlay: Bool = false
    ) {
        isSandboxPlay = sandboxPlay
        let store = AILordProfileStore.shared
        var newRealms: [Realm] = []
        if includeHuman {
            newRealms.append(Realm(
                name: humanName.isEmpty ? "Igrač" : humanName,
                colorHex: humanColorHex,
                lordType: .human
            ))
        }
        for profileId in selectedAIProfileIds {
            guard let p = store.profile(id: profileId) else { continue }
            let computer = Realm(
                name: p.name,
                colorHex: p.displayColorHex,
                lordType: .computer,
                aiProfileId: p.id
            )
            newRealms.append(computer)
        }
        setRealms(newRealms)
        if selectedAIProfileIds.count >= 2 {
            recordThisMatch = true
        }
        matchPresentation = presentation ?? (includeHuman ? .graphics : .simulator)
        setMapSize(mapSize)
        currentLevelName = soloLevelName
        soloMapLoadedFromFile = false
        if isSoloMode, soloLevelName == nil {
            SceneKitLevelLoader.deleteSoloLevelFiles()
        }
        startNewGame()
        if isSoloMode {
            resources.setStock(stone: 0, wood: 0, iron: 0, gold: max(0, initialGold))
            queueStartGoods([
                (.stone, initialStone), (.wood, initialWood), (.iron, initialIron),
                (.food, initialFood), (.hop, initialHop), (.hay, initialHay)
            ])
            grantSandboxOpening()
        }
    }

    /// Solo: pokreni igru s mapom učitanoj iz kataloškog unosa (datoteka iz Maps/200x200/, …). Teren i placements dolaze iz te datoteke.
    func startSoloWithMapEntry(
        entry: MapCatalogEntry,
        initialGold: Int = 0,
        initialWood: Int = 0,
        initialIron: Int = 0,
        initialStone: Int = 0,
        initialFood: Int = 0,
        initialHop: Int = 0,
        initialHay: Int = 0,
        sandboxPlay: Bool = false
    ) {
        isSandboxPlay = sandboxPlay
        matchPresentation = .graphics
        setRealms([Realm(name: "Igrač", colorHex: "2E86AB", lordType: .human)])
        guard let root = MapStorage.mapsRoot() else { return }
        let fileURL = root.appendingPathComponent(entry.path)
        guard let data = MapFileManager.load(from: fileURL) else { return }
        applyLoadedMapDataForSolo(data)
        currentLevelName = nil
        soloMapLoadedFromFile = true
        startNewGame()
        resources.setStock(stone: 0, wood: 0, iron: 0, gold: max(0, initialGold))
        queueStartGoods([
            (.stone, initialStone), (.wood, initialWood), (.iron, initialIron),
            (.food, initialFood), (.hop, initialHop), (.hay, initialHay)
        ])
        grantSandboxOpening()
    }

    /// Solo graditelj: kreni s već pripremljenom mapom (učitanom u izborniku).
    func startSandboxWithPreparedMap(
        map: GameMap,
        loadedFromFile: Bool,
        undergroundPlacements: [Placement] = [],
        initialGold: Int = 0,
        initialWood: Int = 0,
        initialIron: Int = 0,
        initialStone: Int = 0,
        initialFood: Int = 0,
        initialHop: Int = 0,
        initialHay: Int = 0
    ) {
        isSandboxPlay = true
        matchPresentation = .graphics
        setRealms([Realm(
            name: playerProfileName.isEmpty ? "Igrač" : playerProfileName,
            colorHex: "2E86AB",
            lordType: .human
        )])
        gameMap = map
        ensureUndergroundMap()
        undergroundMap.replacePlacements(undergroundPlacements)
        currentLevelName = nil
        soloMapLoadedFromFile = loadedFromFile
        if !loadedFromFile {
            SceneKitLevelLoader.deleteSoloLevelFiles()
        }
        startNewGame()
        food = 0
        hay = 0
        hop = 0
    }

    /// Naručene zalihe stižu jedna po jedna. Zlato je uvijek prvo.
    /// Ostalo stoji u redu dok skladište nema mjesta.
    func enqueueOpeningSupplies(_ items: [SupplyDrop]) {
        supplyQueue.append(contentsOf: items.filter { $0.amount > 0 })
        putGoldFirstInSupplyQueue()
        presentNextSupplyIfNeeded()
    }

    func presentNextSupplyIfNeeded() {
        guard isLevelReady, !isShowingMainMenu, !supplyQueue.isEmpty else {
            supplyClock?.invalidate()
            supplyClock = nil
            return
        }
        guard supplyClock == nil else { return }
        let timer = Timer(timeInterval: 1.15, repeats: true) { [weak self] _ in
            self?.tryDeliverFrontSupply()
        }
        RunLoop.main.add(timer, forMode: .common)
        supplyClock = timer
    }

    private func putGoldFirstInSupplyQueue() {
        let gold = supplyQueue.filter { $0.good == .gold }
        let rest = supplyQueue.filter { $0.good != .gold }
        supplyQueue = gold + rest
    }

    /// Prednji u redu ide u inventar kad može. Ako ne može, cijeli red i dalje stoji.
    private func tryDeliverFrontSupply() {
        guard isLevelReady, !isShowingMainMenu, !supplyQueue.isEmpty else {
            supplyClock?.invalidate()
            supplyClock = nil
            return
        }
        putGoldFirstInSupplyQueue()
        var front = supplyQueue[0]
        let fit: Int
        if front.good == .gold {
            fit = front.amount
        } else if let faction = playerSeat?.id {
            fit = unitsThatFit(front.good, adding: front.amount, faction: faction)
        } else {
            fit = 0
        }
        guard fit > 0 else { return }
        addGood(front.good, fit)
        if fit >= front.amount {
            supplyQueue.removeFirst()
        } else {
            var waiting = supplyQueue[0]
            waiting.amount = front.amount - fit
            supplyQueue[0] = waiting
        }
        if supplyQueue.isEmpty {
            supplyClock?.invalidate()
            supplyClock = nil
        }
    }

    func queueStartGoods(_ items: [(Good, Int)]) {
        for (good, amount) in items where good != .gold && amount > 0 {
            pendingStartGoods[good, default: 0] += amount
        }
    }

    /// Upiše naručenu robu u vidljivi red. Zlato je već u kesi; ostalo čeka dok ima mjesta.
    func applyPendingStartGoods() {
        let waiting = pendingStartGoods.sorted { $0.key.rawValue < $1.key.rawValue }
        pendingStartGoods = [:]
        let drops = waiting.map { good, amount in
            SupplyDrop(icon: supplyIconName(good), fallback: "shippingbox.fill", amount: amount, good: good)
        }
        enqueueOpeningSupplies(drops)
    }

    private func supplyIconName(_ good: Good) -> String {
        switch good {
        case .wood: return "wood_resource"
        case .stone: return "stone_resource"
        case .iron: return "iron_resource"
        case .hop: return "hop_resource"
        case .beer: return "beer_resource"
        case .food, .wheat, .flour: return "food"
        case .bread: return "bread_resource"
        case .hay: return "hay_resource"
        case .apple: return "apple_resource"
        case .cheese: return "cheese_resource"
        case .meat: return "meat_resouce"
        case .sausages: return "sosages_resouce"
        case .vegetables: return "vegetables_resource"
        case .wine: return "vine_resources"
        case .candle: return "candle_resource"
        case .corn: return "corn_resource"
        case .eggs: return "eggs_resouce"
        case .grapes: return "grapes_resource"
        case .flowers: return "flowers_resoiurce"
        case .spices: return "spices_resources"
        case .leather: return "leather_resources"
        case .shield: return "shield_resource"
        case .spear: return "spear_resource"
        case .sword: return "sword_resource"
        case .bow: return "bow_and_sparrow_resouce"
        case .gold: return "gold"
        default: return good.rawValue
        }
    }

    func cancelOpeningSupplies() {
        supplyClock?.invalidate()
        supplyClock = nil
        supplyQueue = []
        activeSupplyDrop = nil
        pendingStartGoods = [:]
    }

    /// Postojeće građevine dobivaju redoslijed kakav imaju na mapi. Nove dobivaju sljedeći broj.
    func seedBuildingBirth() {
        buildingBirth = [:]
        nextBuildingBirth = 0
        for (_, placement) in mapLogic.allPlacements {
            noteBuildingBorn(placement.id)
        }
    }

    func ensureBuildingBirth(for ids: [String]) {
        for id in ids where buildingBirth[id] == nil {
            noteBuildingBorn(id)
        }
    }

    func noteBuildingBorn(_ id: String) {
        guard buildingBirth[id] == nil else { return }
        buildingBirth[id] = nextBuildingBirth
        nextBuildingBirth += 1
    }

    func buildingBirthRank(_ id: String) -> Int {
        if let known = buildingBirth[id] { return known }
        noteBuildingBorn(id)
        return buildingBirth[id] ?? 0
    }

    /// Solo graditelj dobiva do 100 zlatnika. Jabuke stižu samo ako imaju polje u skladištu.
    private func grantSandboxOpening() {
        guard isSandboxPlay else { return }
        let missingGold = max(0, 100 - resources.gold)
        if missingGold > 0 { resources.add(gold: missingGold) }
        queueStartGoods([(.apple, 100)])
    }

    /// Spremi trenutnu mapu (teren, visine, građevine) u odabranu datoteku.
    func savePlayMap(to fileURL: URL) -> String {
        var url = fileURL
        if url.pathExtension.lowercased() != "json" {
            url = url.appendingPathExtension("json")
        }
        let name = url.deletingPathExtension().lastPathComponent
        guard !name.isEmpty else { return "Unesite naziv mape." }
        let vertexHeightsDouble = gameMap.vertexHeights.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: gameMap.vertexHeights.map { ($0.key, Double($0.value)) })
        let data = MapEditorSaveData(
            mapName: name,
            rows: gameMap.rows,
            cols: gameMap.cols,
            placements: gameMap.placements,
            cells: gameMap.cells,
            createdDate: Date(),
            originOffsetX: Double(gameMap.originOffsetX),
            originOffsetZ: Double(gameMap.originOffsetZ),
            vertexHeights: vertexHeightsDouble,
            vertexOffsets: MapEditorSaveData.encodeOffsets(gameMap.vertexOffsets), lordStarts: MapEditorSaveData.encodeLordStarts(gameMap.lordStarts), undergroundPlacements: savedUndergroundPlacements
        )
        let (saved, saveError) = MapFileManager.save(data: data, to: url)
        guard saved else { return saveError ?? "Spremanje mape nije uspjelo." }
        registerPlayMapInCatalog(fileURL: url, data: data)
        mapEditorMapName = name
        return "Mapa „\(name)“ je spremljena."
    }

    /// Učitaj mapu iz datoteke i prikaži je. Igra ostaje u pauzi ako je pauza bila uključena.
    func loadPlayMap(from fileURL: URL) -> String {
        guard let data = MapFileManager.load(from: fileURL) else {
            return "Učitavanje mape nije uspjelo."
        }
        let wasPaused = isGamePaused
        applyLoadedMapDataForSolo(data)
        placementsVersion += 1
        soloMapLoadedFromFile = true
        currentLevelName = nil
        mapEditorMapName = data.mapName
        focusSoloCameraOnCenter()
        clearRealmSeats()
        mapSceneEpoch += 1
        spawnRealmSeatsIfNeeded(animated: showsGraphics && !wasPaused)
        if wasPaused {
            realmSeats.pauseWalking()
            people.stopTimer()
            oxen.stopTimer()
            endMatchClock()
        }
        let title = data.mapName.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : data.mapName
        return "Mapa „\(title)“ je učitana."
    }

    private func registerPlayMapInCatalog(fileURL: URL, data: MapEditorSaveData) {
        guard let root = MapStorage.mapsRoot() else { return }
        let rootPath = root.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else { return }
        let rel = String(filePath.dropFirst(rootPath.count + 1))
        let slot = MapEditorSlot.solo
        let entry = MapCatalogEntry(
            path: rel,
            rows: data.rows,
            cols: data.cols,
            slot: slot.rawValue,
            displayName: data.mapName,
            sizeCategory: MapSizeCategory.from(rows: data.rows, cols: data.cols).rawValue,
            suggestedPlayers: slot.defaultSuggestedPlayers,
            tags: slot.defaultTags
        )
        MapCatalog.addOrUpdate(entry: entry)
    }

    /// Primijeni učitane podatke na gameMap (solo – bez editor state).
    private func applyLoadedMapDataForSolo(_ data: MapEditorSaveData) {
        let newMap = GameMap(rows: data.rows, cols: data.cols)
        newMap.replacePlacements(data.placements)
        if let cells = data.cells { newMap.replaceCells(cells) }
        if let vh = data.vertexHeights { newMap.replaceVertexHeights(Dictionary(uniqueKeysWithValues: vh.map { ($0.key, CGFloat($0.value)) })) }
        newMap.replaceVertexOffsets(data.vertexOffsetPoints)
        newMap.replaceLordStarts(data.lordStartSlots)
        newMap.originOffsetX = CGFloat(data.originOffsetX ?? 0)
        newMap.originOffsetZ = CGFloat(data.originOffsetZ ?? 0)
        gameMap = newMap
        undergroundMap.replacePlacements(data.undergroundPlacements ?? [])
    }

    /// Promijeni veličinu mape (nova igra).
    func setMapSize(_ preset: MapSizePreset) {
        gameMap = preset.makeGameMap()
    }
}

// MARK: - Placement
extension GameState {
    /// Postavi trenutno odabrani objekt na (row, col). Vraća true ako je uspjelo. U igri (ne Map Editor) troši resurse prema BuildCosts.
    func placeSelectedObjectAt(row: Int, col: Int, playSound: Bool = true) -> Bool {
        guard !isGamePaused else { return false }
        placementError = nil
        buildShortage = nil
        placementDebugLog("GameState.placeSelectedObjectAt row=\(row) col=\(col) selected=\(selectedPlacementObjectId ?? "nil")")
        guard let objectId = selectedPlacementObjectId else {
            let msg = "Nije odabran objekt za postavljanje. Prvo odaberi Zid (Dvor → Zid)."
            placementError = msg
            placementDebugLog("FAIL no selected object")
            return false
        }
        if !isMapEditorMode, WallParent.isWall(objectId: objectId), !WallBuildConditions.wallBuildConditionsMet(gameState: self, objectId: objectId, cells: [(row, col)]) {
            placementDebugLog("FAIL wall build conditions not met row=\(row) col=\(col)")
            return false
        }
        let price = PriceList.price(for: objectId)
        if !isMapEditorMode, !canAfford(price) {
            presentBuildShortage(objectId: objectId, price: price)
            return false
        }
        let obj = ObjectCatalog.shared.object(id: objectId)
        let width = obj?.size.width ?? 1
        let height = obj?.size.height ?? 1
        placementDebugLog("object=\(objectId) size=\(width)x\(height)")
        if let reason = buildRuleViolation(objectId: objectId, row: row, col: col, width: width, height: height) {
            placementError = reason
            placementDebugLog("FAIL build rule object=\(objectId) row=\(row) col=\(col): \(reason)")
            return false
        }
        let owner = isMapEditorMode ? nil : playerSeat?.id
        guard let placed = activeMap.place(objectId: objectId, width: width, height: height, atRow: row, col: col, ownerId: owner) else {
            let msg = "Ne može se staviti na (\(row), \(col)) – ćelija zauzeta ili izvan mape \(activeMap.displayDimensionString)."
            placementError = msg
            placementDebugLog("FAIL map.place returned nil object=\(objectId) row=\(row) col=\(col)")
            return false
        }
        if !isMapEditorMode {
            pay(price)
            if objectId == Carriage.objectId { ensureTransportLine(for: placed) }
        }
        noteBuildingBorn(placed.id)
        placementsVersion += 1
        objectWillChange.send()
        if playSound && playPlacementSound {
            AudioManager.shared.playSound(named: "place", volume: effectiveSoundsVolume)
        }
        placementDebugLog("SUCCESS object=\(objectId) row=\(row) col=\(col)")
        if !isMapEditorMode {
            let name = ObjectCatalog.shared.object(id: objectId)?.name ?? objectId
            MatchHistoryStore.shared.noteBuild(from: self, name: name, row: row, col: col)
            profileBuildingsPlaced += 1
        }
        return true
    }

    /// Vlasnik ruši građevinu: radnik se oslobađa i vraća vatri, stanje građevine nestaje.
    func demolishPlacement(id: String) {
        guard let (layer, placement) = locatePlacement(id: id) else { return }
        releaseWorker(of: id)
        (layer == .surface ? gameMap : undergroundMap).removePlacement(id: id)
        buildingStates[id] = nil
        transformerTicksAccumulated[id] = nil
        if placement.objectId == Carriage.objectId || transportLines[id] != nil { removeTransportLine(depotId: id) }
        warehouseLayouts[id] = nil
        if editingWarehouseRoute?.storeId == id { editingWarehouseRoute = nil }
        if inspectedPlacementId == id { inspectedPlacementId = nil }
        placementsVersion += 1
        refreshBuildingAlerts()
        objectWillChange.send()
    }

    /// Ukloni placement koji pokriva danu koordinatu (Map Editor – alat za brisanje).
    func removePlacement(at coordinate: MapCoordinate) {
        guard let p = activeMap.placement(at: coordinate) else { return }
        activeMap.removePlacement(id: p.id)
        placementsVersion += 1
        objectWillChange.send()
    }

    func notePlacementsChanged() {
        placementsVersion += 1
        objectWillChange.send()
    }

    /// Jedan production tick: proizvođači dodaju na stockpile; transformeri (pivovara, krčma, hotel) nakon vremena uzimaju input i dodaju output.
    func tickProduction() {
        guard !isGamePaused, !isMapEditorMode, isLevelReady, !isShowingMainMenu else { return }
        tickPeople()
        tickAILords()
        tickFood()
        tickHappiness()
        tickBuildings()
        tickTransport()
        for (_, placement) in mapLogic.allPlacements where !WorkCycleCatalog.isWorkplace(placement.objectId) {
            guard !placement.isDestroyed, let faction = owner(of: placement) else { continue }
            let behavior = ObjectBehaviorRegistry.behavior(for: placement.objectId)
            let inputs = behavior.consumptionPerTick.goods
            let outputs = behavior.productionPerTick.goods

            if behavior.isCraftTransformer {
                let acc = (transformerTicksAccumulated[placement.id] ?? 0) + 1
                transformerTicksAccumulated[placement.id] = acc
                if acc >= behavior.craftDurationTicks, inputs.allSatisfy({ goodAmount($0.key, of: faction) >= $0.value }) {
                    for (good, amount) in inputs { addGood(good, -amount, to: faction) }
                    for (good, amount) in outputs { addGood(good, amount, to: faction) }
                    transformerTicksAccumulated[placement.id] = 0
                }
            } else {
                for (good, amount) in outputs { addGood(good, amount, to: faction) }
            }
        }
    }
}

// MARK: - Map Editor
/// Slot za spremanje/učitavanje mape u Map Editoru (solo, dual, …).
enum MapEditorSlot: String, CaseIterable, Identifiable {
    case solo
    case dual
    case trio
    case quatro
    case five
    case six

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solo: return "Solo"
        case .dual: return "Dual"
        case .trio: return "Trio"
        case .quatro: return "Quatro"
        case .five: return "5"
        case .six: return "6"
        }
    }

    var fileName: String { "map_editor_\(rawValue).json" }
}

extension GameState {
    /// Kreira mapu na pozadinskom threadu (igra ne zastaje), sprema je u Maps/side×side/ i otvori Map Editor. Na main thread pozove completion(success).
    /// Map Editor se prikazuje samo kad mapa postoji; pričekaj da se sve učita (isLevelReady) prije uređivanja.
    func createMapAndOpenEditor(name: String, side: Int, completion: @escaping (Bool) -> Void) {
        MapGenerator.createAndSaveMapAsync(name: name, side: side, slot: .solo) { [weak self] newMap in
            guard let self = self, let newMap = newMap else { completion(false); return }
            self.gameMap = newMap
            self.mapEditorCurrentSlot = .solo
            self.mapEditorMapName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            self.mapEditorCreatedDate = Date()
            self.mapEditorState = MapEditorState()
            self.bindMapEditorStateChanges()
            self.mapEditorSceneVersion += 1
            self.selectedPlacementObjectId = nil
            self.isShowingMainMenu = false
            self.isMapEditorMode = true
            self.isLevelReady = false
            self.levelLoadingMessage = "Kreiranje i učitavanje mape (\(newMap.displayDimensionString))…"
            self.objectWillChange.send()
            completion(true)
        }
    }

    /// Otvori Map Editor s postojećom mapom zadane veličine (npr. nakon učitavanja). Ne kreira novu datoteku.
    func openMapEditor(withPreset preset: MapSizePreset) {
        setMapSize(preset)
        mapEditorCurrentSlot = .solo
        mapEditorState = MapEditorState()
        bindMapEditorStateChanges()
        selectedPlacementObjectId = nil
        isShowingMainMenu = false
        isMapEditorMode = true
        isLevelReady = false
        levelLoadingMessage = "Učitavanje mape (\(gameMap.displayDimensionString))…"
        _ = saveEditorMap(toSlot: .solo)
    }

    /// Otvori Map Editor nakon učitavanja mape (mapa je već postavljena). Generira editor-only stanje i veže na mapu.
    func openMapEditorAfterLoad() {
        mapEditorState = MapEditorState()
        bindMapEditorStateChanges()
        selectedPlacementObjectId = nil
        isShowingMainMenu = false
        isMapEditorMode = true
        isLevelReady = false
        levelLoadingMessage = "Učitavanje mape (\(gameMap.displayDimensionString))…"
    }

    /// Zatvori Map Editor i vrati se na izbornik. Očisti editor-only stanje.
    func closeMapEditor() {
        mapEditorStateCancellable?.cancel()
        mapEditorStateCancellable = nil
        mapEditorState?.clear()
        mapEditorState = nil
        isMapEditorMode = false
        isShowingMainMenu = true
    }

    /// Spremi trenutnu mapu u slot (Maps/200x200/, …) preko MapFileManager. Sprema samo unutar projekta. Vraća (uspjeh, poruka greške za prikaz).
    func saveEditorMap(toSlot slot: MapEditorSlot? = nil) -> (success: Bool, errorMessage: String?) {
        let targetSlot = slot ?? mapEditorCurrentSlot ?? .solo
        let name = mapEditorMapName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return (false, "Unesite naziv mape.") }
        MapStorage.createSizeFoldersIfNeeded()
        guard MapStorage.isMapsRootInProject() else {
            FeudalismLog.log("Save map: ODBIJENO – mape se moraju spremati u projekt. Trenutni Maps root=\(MapStorage.mapsRootPath()). Postavite Working Directory = $(PROJECT_DIR).")
            return (false, "Mape se moraju spremati unutar projekta. Postavite Xcode → Edit Scheme → Run → Options → Working Directory = $(PROJECT_DIR).")
        }
        let fileName = MapStorage.fileName(forMapName: name, slotFallback: targetSlot)
        let vertexHeightsDouble = gameMap.vertexHeights.isEmpty ? nil : Dictionary(uniqueKeysWithValues: gameMap.vertexHeights.map { ($0.key, Double($0.value)) })
        let data = MapEditorSaveData(mapName: name, rows: gameMap.rows, cols: gameMap.cols, placements: gameMap.placements, cells: gameMap.cells, createdDate: mapEditorCreatedDate ?? Date(), originOffsetX: Double(gameMap.originOffsetX), originOffsetZ: Double(gameMap.originOffsetZ), vertexHeights: vertexHeightsDouble, vertexOffsets: MapEditorSaveData.encodeOffsets(gameMap.vertexOffsets), lordStarts: MapEditorSaveData.encodeLordStarts(gameMap.lordStarts), undergroundPlacements: savedUndergroundPlacements)
        guard let fileURL = MapStorage.fileURL(rows: gameMap.rows, cols: gameMap.cols, fileName: fileName) else {
            let side = gameMap.rows * MapScale.smallCellsPerObjectCubeSide
            return (false, "Nije moguće odrediti putanju za spremanje. Veličina mape \(gameMap.displayDimensionString) možda nije dopuštena (200, 400, 600, 800, 1000). Putanja: \(MapStorage.mapsRootPath())")
        }
        let (saved, saveError) = MapFileManager.save(data: data, to: fileURL)
        FeudalismLog.log("Save map: success=\(saved), error=\(saveError ?? "—"), path=\(fileURL.path), mapsInProject=\(MapStorage.isMapsRootInProject())")
        guard saved else { return (false, saveError ?? "Spremanje nije uspjelo.") }
        if let rel = MapStorage.relativePath(rows: gameMap.rows, cols: gameMap.cols, fileName: fileName) {
            let category = MapSizeCategory.from(rows: gameMap.rows, cols: gameMap.cols)
            let entry = MapCatalogEntry(
                path: rel,
                rows: gameMap.rows,
                cols: gameMap.cols,
                slot: targetSlot.rawValue,
                displayName: name,
                sizeCategory: category.rawValue,
                suggestedPlayers: targetSlot.defaultSuggestedPlayers,
                tags: targetSlot.defaultTags
            )
            MapCatalog.addOrUpdate(entry: entry)
        }
        return (true, nil)
    }

    /// Učitaj mapu iz kataloškog unosa preko MapFileManager. Vraća true ako je uspjelo.
    func loadEditorMap(entry: MapCatalogEntry) -> Bool {
        guard let root = MapStorage.mapsRoot() else { return false }
        let fileURL = root.appendingPathComponent(entry.path)
        guard let data = MapFileManager.load(from: fileURL) else { return false }
        applyLoadedMapData(data)
        mapEditorCurrentSlot = MapEditorSlot(rawValue: entry.slot) ?? .solo
        mapEditorMapName = data.mapName
        mapEditorCreatedDate = data.createdDate
        mapEditorSceneVersion += 1
        objectWillChange.send()
        return true
    }

    /// Učitaj mapu iz danog slota i veličine: prvo iz kataloga (prvi unos za slot i dimenzije), inače legacy datoteka slot.fileName.
    func loadEditorMap(fromSlot slot: MapEditorSlot, rows: Int, cols: Int) -> Bool {
        let fromCatalog = MapCatalog.entries(forSlot: slot).first { $0.rows == rows && $0.cols == cols }
        if let entry = fromCatalog { return loadEditorMap(entry: entry) }
        guard let fileURL = MapStorage.fileURL(rows: rows, cols: cols, fileName: slot.fileName) else { return false }
        guard let data = MapFileManager.load(from: fileURL) else { return false }
        applyLoadedMapData(data)
        mapEditorCurrentSlot = slot
        mapEditorMapName = data.mapName
        mapEditorCreatedDate = data.createdDate
        mapEditorSceneVersion += 1
        objectWillChange.send()
        return true
    }

    /// Primijeni učitane podatke na gameMap (koristi Map Editor nakon load).
    private func applyLoadedMapData(_ data: MapEditorSaveData) {
        let newMap = GameMap(rows: data.rows, cols: data.cols)
        newMap.replacePlacements(data.placements)
        if let cells = data.cells { newMap.replaceCells(cells) }
        if let vh = data.vertexHeights { newMap.replaceVertexHeights(Dictionary(uniqueKeysWithValues: vh.map { ($0.key, CGFloat($0.value)) })) }
        newMap.replaceVertexOffsets(data.vertexOffsetPoints)
        newMap.replaceLordStarts(data.lordStartSlots)
        newMap.originOffsetX = CGFloat(data.originOffsetX ?? 0)
        newMap.originOffsetZ = CGFloat(data.originOffsetZ ?? 0)
        gameMap = newMap
        undergroundMap.replacePlacements(data.undergroundPlacements ?? [])
    }

    /// Učitaj prvu dostupnu mapu za dani slot (bilo koja veličina iz kataloga). Vraća true ako je uspjelo.
    func loadEditorMap(fromSlot slot: MapEditorSlot) -> Bool {
        guard let first = MapCatalog.entries(forSlot: slot).first else { return false }
        return loadEditorMap(entry: first)
    }

    /// Postoji li barem jedna spremljena mapa za dani slot (bilo koja veličina)?
    func hasEditorMap(inSlot slot: MapEditorSlot) -> Bool {
        MapCatalog.hasAnyMap(forSlot: slot)
    }

    /// Map Editor: obriši datoteku mape i unos iz kataloga. Vraća true ako je unos uklonjen iz kataloga.
    func deleteEditorMap(entry: MapCatalogEntry) -> Bool {
        if let root = MapStorage.mapsRoot() {
            let fileURL = root.appendingPathComponent(entry.path)
            try? FileManager.default.removeItem(at: fileURL)
        }
        MapCatalog.remove(path: entry.path)
        objectWillChange.send()
        return true
    }

    /// Map Editor: preimenuj mapu (nova datoteka, brisanje stare, ažuriranje kataloga). Vraća (uspjeh, poruka greške).
    func renameEditorMap(entry: MapCatalogEntry, newName: String) -> (success: Bool, errorMessage: String?) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return (false, "Unesite naziv mape.") }
        guard let root = MapStorage.mapsRoot() else { return (false, "Mape nisu dostupne.") }
        let fileURL = root.appendingPathComponent(entry.path)
        guard let data = MapFileManager.load(from: fileURL) else { return (false, "Učitavanje mape nije uspjelo.") }
        let slot = MapEditorSlot(rawValue: entry.slot) ?? .solo
        let fileName = MapStorage.fileName(forMapName: name, slotFallback: slot)
        guard let newURL = MapStorage.fileURL(rows: data.rows, cols: data.cols, fileName: fileName) else {
            return (false, "Neispravna veličina mape.")
        }
        let newData = MapEditorSaveData(mapName: name, rows: data.rows, cols: data.cols, placements: data.placements, cells: data.cells, createdDate: data.createdDate, originOffsetX: data.originOffsetX, originOffsetZ: data.originOffsetZ, vertexHeights: data.vertexHeights, vertexOffsets: data.vertexOffsets)
        let (saved, saveError) = MapFileManager.save(data: newData, to: newURL)
        guard saved else { return (false, saveError ?? "Spremanje nije uspjelo.") }
        if let rel = MapStorage.relativePath(rows: data.rows, cols: data.cols, fileName: fileName) {
            let category = MapSizeCategory.from(rows: data.rows, cols: data.cols)
            let newEntry = MapCatalogEntry(path: rel, rows: data.rows, cols: data.cols, slot: entry.slot, displayName: name, sizeCategory: category.rawValue, suggestedPlayers: entry.suggestedPlayers, tags: entry.tags)
            MapCatalog.addOrUpdate(entry: newEntry)
        }
        try? FileManager.default.removeItem(at: fileURL)
        MapCatalog.remove(path: entry.path)
        objectWillChange.send()
        return (true, nil)
    }

    /// Map Editor: obriši sve objekte s mape.
    func clearEditorMap() {
        gameMap.replacePlacements([])
        objectWillChange.send()
    }
}

// MARK: - Terrain elevation (Map Editor – alat Teren)
enum TerrainToolOption: String, CaseIterable {
    case raise1 = "Podigni za 1"
    case raise5 = "Podigni za 5"
    case raise10 = "Podigni za 10"
    case lower1 = "Spusti za 1"
    case lower5 = "Spusti za 5"
    case lower10 = "Spusti za 10"
    case flatten = "Izravnaj"

    var systemImage: String {
        switch self {
        case .raise1, .raise5, .raise10: return "arrow.up.circle.fill"
        case .lower1, .lower5, .lower10: return "arrow.down.circle.fill"
        case .flatten: return "rectangle.compress.vertical"
        }
    }

    /// Broj na ikoni (metri); nil za izravnaj.
    var badge: String? {
        switch self {
        case .raise1, .lower1: return "1"
        case .raise5, .lower5: return "5"
        case .raise10, .lower10: return "10"
        case .flatten: return nil
        }
    }

    /// Promjena visine u metrima; nil = izravnaj.
    var heightDelta: CGFloat? {
        let step = MapScale.worldUnitsPerElevationStep
        switch self {
        case .raise1: return step
        case .raise5: return 5 * step
        case .raise10: return 10 * step
        case .lower1: return -step
        case .lower5: return -5 * step
        case .lower10: return -10 * step
        case .flatten: return nil
        }
    }
}

/// Što četkica u map editoru (kategorija Teren) radi na kliknutim ćelijama.
enum MapEditorPaintMode: String, CaseIterable, Identifiable {
    case visina = "Visina"
    case teren = "Teren"
    case podloge = "Podloge"
    case naslage = "Naslage"
    case gradnja = "Gradnja"
    case kretanje = "Kretanje"
    case precizno = "Precizno"

    var id: String { rawValue }
}

/// Podloga tla: zelena zemlja za farme, kamena ruda, željezna ruda.
enum PadBrush: String, CaseIterable, Identifiable {
    case trava = "Trava"
    case plodna = "Zelena zemlja"
    case kamen = "Kamena ruda"
    case zeljezo = "Željezna ruda"
    case rijeka = "Rijeka"
    case more = "More"
    case pijesak = "Pijesak"
    case obicno = "Obično tlo"
    case mocvara = "Močvara"
    case obrisi = "Obriši"

    var id: String { rawValue }
}

/// Naslaga koju četkica postavlja (ili briše).
enum DepositBrush: String, CaseIterable, Identifiable {
    case nema = "Bez naslage"
    case kamen = "Kamen"
    case zeljezo = "Željezo"

    var id: String { rawValue }

    var resource: ResourceType? {
        switch self {
        case .nema: return nil
        case .kamen: return .stone
        case .zeljezo: return .iron
        }
    }
}

/// Četkica terena: kvadrat 1×1, 3×3, 5×5, 7×7. Stranica = 2*radius+1.
enum TerrainBrushOption: String, CaseIterable {
    case size1
    case size3
    case size5
    case size7

    var radius: Int {
        switch self {
        case .size1: return 0
        case .size3: return 1
        case .size5: return 2
        case .size7: return 3
        }
    }

    var isSquare: Bool { true }

    var displayLabel: String {
        switch self {
        case .size1: return "1×1"
        case .size3: return "3×3"
        case .size5: return "5×5"
        case .size7: return "7×7"
        }
    }
}

extension GameState {
    /// Ćelije pod četkicom oko (centerRow, centerCol), samo unutar mape.
    func brushCoordinates(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption) -> [MapCoordinate] {
        let r = brushOption.radius
        var result: [MapCoordinate] = []
        for dr in -r...r {
            for dc in -r...r {
                if !brushOption.isSquare, dr * dr + dc * dc > r * r { continue }
                let coord = MapCoordinate(row: centerRow + dr, col: centerCol + dc)
                if gameMap.isValid(coord) { result.append(coord) }
            }
        }
        return result
    }

    /// Visina se mijenja samo na gornjoj mapi; podzemlje je uvijek ravno, 10 m ispod.
    private var canEditSurfaceTerrain: Bool { isMapEditorMode && !isUndergroundView }

    /// Podigni / spusti / izravnaj ćelije: mijenjaju se kutovi ploča (teren se crta iz njih) i visina ćelija.
    private func applyElevation(to coords: [MapCoordinate], tool: TerrainToolOption, flattenTo: CGFloat) {
        guard canEditSurfaceTerrain, !coords.isEmpty else { return }
        var vertices: Set<MapCoordinate> = []
        for coord in coords {
            for dr in 0...1 {
                for dc in 0...1 {
                    vertices.insert(MapCoordinate(row: coord.row + dr, col: coord.col + dc))
                }
            }
        }
        for v in vertices {
            let current = gameMap.vertexHeightAt(vertexRow: v.row, vertexCol: v.col)
            let value = tool.heightDelta.map { current + $0 } ?? flattenTo
            gameMap.setVertexHeight(vertexRow: v.row, vertexCol: v.col, value)
        }
        for coord in coords {
            if tool == .flatten {
                gameMap.setCenterPoint(row: coord.row, col: coord.col, nil)
            } else if let center = gameMap.cell(at: coord)?.center, let delta = tool.heightDelta {
                gameMap.setCenterPoint(row: coord.row, col: coord.col, CellCenterPoint(dx: center.dx, dz: center.dz, height: center.height + delta))
            }
            let corners = gameMap.surface(row: coord.row, col: coord.col).corners
            gameMap.setHeight(at: coord, corners.map(\.height).reduce(0, +) / 4)
        }
        objectWillChange.send()
    }

    /// Primijeni alat za teren na ćelije oko (centerRow, centerCol).
    func applyTerrainElevation(centerRow: Int, centerCol: Int, tool: TerrainToolOption, brushOption: TerrainBrushOption) {
        let coords = brushCoordinates(centerRow: centerRow, centerCol: centerCol, brushOption: brushOption)
        let target = gameMap.surface(row: centerRow, col: centerCol).center.height
        applyElevation(to: coords, tool: tool, flattenTo: target)
    }

    /// Primijeni alat za teren samo na označene ćelije (Map Editor – mod „Odabir ćelija”).
    func applyTerrainElevationToSelectedCells(tool: TerrainToolOption) {
        guard let editorState = mapEditorState, let first = editorState.selectedCells.first else { return }
        let target = gameMap.surface(row: first.row, col: first.col).center.height
        applyElevation(to: Array(editorState.selectedCells), tool: tool, flattenTo: target)
    }

    /// Oboji teren (pustinja, plodna, put, …) pod četkicom.
    func paintSurface(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption, surface: PovrsinaType) {
        guard canEditSurfaceTerrain else { return }
        for coord in brushCoordinates(centerRow: centerRow, centerCol: centerCol, brushOption: brushOption) {
            gameMap.setSurface(at: coord, surface)
        }
        editorCellsVersion += 1
        objectWillChange.send()
    }

    /// Podloga: plodno tlo, kamena ruda ili željezna ruda.
    func paintPad(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption, pad: PadBrush) {
        guard canEditSurfaceTerrain else { return }
        for coord in brushCoordinates(centerRow: centerRow, centerCol: centerCol, brushOption: brushOption) {
            switch pad {
            case .trava:
                gameMap.setSurface(at: coord, .tlo)
                gameMap.setDeposit(at: coord, nil)
            case .plodna:
                gameMap.setSurface(at: coord, .plodna)
            case .kamen:
                gameMap.setDeposit(at: coord, .stone)
            case .zeljezo:
                gameMap.setSurface(at: coord, .zeljezo)
                gameMap.setDeposit(at: coord, .iron)
            case .rijeka:
                gameMap.setSurface(at: coord, .voda)
                gameMap.setDeposit(at: coord, nil)
            case .more:
                gameMap.setSurface(at: coord, .more)
                gameMap.setDeposit(at: coord, nil)
            case .pijesak:
                gameMap.setSurface(at: coord, .pustinja)
                gameMap.setDeposit(at: coord, nil)
            case .obicno:
                gameMap.setSurface(at: coord, .tlo)
                gameMap.setDeposit(at: coord, nil)
            case .mocvara:
                gameMap.setSurface(at: coord, .mocvara)
                gameMap.setDeposit(at: coord, nil)
            case .obrisi:
                gameMap.setDeposit(at: coord, nil)
                if let surface = gameMap.cell(row: coord.row, col: coord.col)?.povrsina,
                   surface == .plodna || surface == .zeljezo || surface == .more || surface == .voda || surface == .pustinja || surface == .mocvara {
                    gameMap.setSurface(at: coord, .tlo)
                }
            }
        }
        editorCellsVersion += 1
        objectWillChange.send()
    }

    /// Postavi ili obriši naslagu (kamen, željezo) pod četkicom.
    func paintDeposit(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption, deposit: DepositBrush) {
        guard canEditSurfaceTerrain else { return }
        for coord in brushCoordinates(centerRow: centerRow, centerCol: centerCol, brushOption: brushOption) {
            gameMap.setDeposit(at: coord, deposit.resource)
        }
        editorCellsVersion += 1
        objectWillChange.send()
    }

    /// Dozvoli ili zabrani gradnju na ćelijama pod četkicom.
    func paintBuildable(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption, buildable: Bool) {
        guard canEditSurfaceTerrain else { return }
        for coord in brushCoordinates(centerRow: centerRow, centerCol: centerCol, brushOption: brushOption) {
            gameMap.setBuildable(at: coord, buildable)
        }
        editorCellsVersion += 1
        objectWillChange.send()
    }

    /// Postavi indeks kretanja pod četkicom.
    func paintMovementIndex(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption, index: Double) {
        guard canEditSurfaceTerrain else { return }
        for coord in brushCoordinates(centerRow: centerRow, centerCol: centerCol, brushOption: brushOption) {
            gameMap.setMovementIndex(at: coord, index)
        }
        editorCellsVersion += 1
        objectWillChange.send()
    }

    /// Precizno: točka ploče (0–3 kutovi: gornji lijevi, gornji desni, donji desni, donji lijevi; 4 = sredina).
    func nudgeSurfacePoint(row: Int, col: Int, point: Int, dx: CGFloat = 0, dz: CGFloat = 0, dHeight: CGFloat = 0) {
        guard canEditSurfaceTerrain, gameMap.isValid(MapCoordinate(row: row, col: col)) else { return }
        if point == 4 {
            let current = gameMap.surface(row: row, col: col).center
            gameMap.setCenterPoint(row: row, col: col, CellCenterPoint(
                dx: current.x - CGFloat(col) - 0.5 + dx,
                dz: current.z - CGFloat(row) - 0.5 + dz,
                height: current.height + dHeight
            ))
        } else {
            let corners = [(row, col), (row, col + 1), (row + 1, col + 1), (row + 1, col)]
            guard corners.indices.contains(point) else { return }
            let (vr, vc) = corners[point]
            if dHeight != 0 {
                let h = gameMap.vertexHeightAt(vertexRow: vr, vertexCol: vc)
                gameMap.setVertexHeight(vertexRow: vr, vertexCol: vc, h + dHeight)
            }
            if dx != 0 || dz != 0 {
                let o = gameMap.vertexOffset(vertexRow: vr, vertexCol: vc)
                gameMap.setVertexOffset(vertexRow: vr, vertexCol: vc, CGPoint(x: o.x + dx, y: o.y + dz))
            }
        }
        objectWillChange.send()
    }

    /// Vrati sredinu ploče na automatsku i makni pomake kutova te ćelije.
    func resetSurfacePoints(row: Int, col: Int) {
        guard canEditSurfaceTerrain else { return }
        gameMap.setCenterPoint(row: row, col: col, nil)
        for (vr, vc) in [(row, col), (row, col + 1), (row + 1, col + 1), (row + 1, col)] {
            gameMap.setVertexOffset(vertexRow: vr, vertexCol: vc, .zero)
        }
        objectWillChange.send()
    }

    /// Postavi visinu svih označenih ćelija na zadanu vrijednost.
    func setHeightForSelectedCells(_ height: CGFloat) {
        guard let editorState = mapEditorState else { return }
        for coord in editorState.selectedCells {
            guard gameMap.isValid(coord) else { continue }
            gameMap.setHeight(at: coord, height)
        }
        objectWillChange.send()
    }

    /// Primijeni alat za teren samo na jedan vrh (točku sjecišta). Map Editor – odabrana kugla.
    func applyVertexElevation(vertexRow: Int, vertexCol: Int, tool: TerrainToolOption) {
        guard canEditSurfaceTerrain, gameMap.isValidVertex(vertexRow: vertexRow, vertexCol: vertexCol) else { return }
        let current = gameMap.vertexHeightAt(vertexRow: vertexRow, vertexCol: vertexCol)
        gameMap.setVertexHeight(vertexRow: vertexRow, vertexCol: vertexCol, current + (tool.heightDelta ?? 0))
        objectWillChange.send()
    }

    /// Dodaj u odabir sve ćelije u obliku četkice (1×1, 3×3, 5×5 ili 7×7).
    func addBrushRegionToSelection(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption) {
        guard let editorState = mapEditorState else { return }
        let r = brushOption.radius
        for dr in -r...r {
            for dc in -r...r {
                let row = centerRow + dr
                let col = centerCol + dc
                guard gameMap.isValid(MapCoordinate(row: row, col: col)) else { continue }
                if !brushOption.isSquare, dr * dr + dc * dc > r * r { continue }
                editorState.selectedCells.insert(MapCoordinate(row: row, col: col))
            }
        }
        editorState.objectWillChange.send()
        objectWillChange.send()
    }
}

struct SavedMatchEntry: Identifiable, Equatable {
    var id: String { url.path }
    var url: URL
    var name: String
    var rows: Int
    var cols: Int
    /// Točke građevina, 0…1 po širini i visini.
    var marks: [CGPoint]
}

private struct SoloMatchSave: Codable {
    var rows: Int
    var cols: Int
    var placements: [Placement]
    var undergroundPlacements: [Placement]?
    var buildingStates: [String: BuildingState]?
    var transportLines: [String: TransportLine]?
    var warehouseLayouts: [String: WarehouseLayout]?
    var goods: [String: Int]?
    var people: [Person]?
    var happiness: [String: Double]?
    var taxLevels: [String: Int]?
    var factionStocks: [String: [String: Int]]?
    var campaign: CampaignSettings?
    var relations: [String: FactionRelation]?
    var treasury: [String: Int]?
    var stone: Int
    var wood: Int
    var iron: Int
    var hop: Int
    var beer: Int
    var gold: Int
    var food: Int
    var hay: Int
    var playerHop: Int
    var currentTurn: Int
    var elapsedSeconds: Int
    var kingRow: Double
    var kingCol: Double
    var kingHealth: Double
    var kingAlive: Bool
    var oxen: [OxCart]?
    var seats: [RealmSeat]?
    var transformerTicks: [String: Int]?
    var populationProgress: [String: Double]?
    var foodShortfall: [String: Int]?
    var hadEnemiesAtStart: [String: Bool]?
    var mapName: String?
    var cells: [String: MapCell]?
    var vertexHeights: [String: Double]?
    var vertexOffsets: [String: [Double]]?
    var lordStarts: [String: MapCoordinate]?
    var originOffsetX: Double?
    var originOffsetZ: Double?
    var currentLevelName: String?
    var soloMapLoadedFromFile: Bool?
    var isUndergroundView: Bool?
    var isSandboxPlay: Bool?
}

// MARK: - Settings (UserDefaults keys)
private extension GameState {
    static let inputDeviceKey = "Feudalism.inputDevice"
    static let appLanguageKey = "Feudalism.appLanguage"
    static let playerProfileNameKey = "Feudalism.playerProfileName"
    static let playerEmblemIdKey = "Feudalism.playerEmblemId"
    static let playerAvatarPathKey = "Feudalism.playerAvatarPath"
    static let profilePlaySecondsKey = "Feudalism.profilePlaySeconds"
    static let profileMatchesPlayedKey = "Feudalism.profileMatchesPlayed"
    static let profileBuildingsPlacedKey = "Feudalism.profileBuildingsPlaced"
    static let showStartupAnimationKey = "Feudalism.showStartupAnimation"
    static let showBottomBarLabelsKey = "Feudalism.showBottomBarLabels"
    static let playPlacementSoundKey = "Feudalism.playPlacementSound"
    static let playBarTransitionSoundKey = "Feudalism.playBarTransitionSound"
    static let audioMusicVolumeKey = "Feudalism.audioMusicVolume"
    static let audioSoundsVolumeKey = "Feudalism.audioSoundsVolume"
    static let audioSpeechVolumeKey = "Feudalism.audioSpeechVolume"
    static let bleEnabledKey = "Feudalism.bleEnabled"
    static let powerModeKey = "Feudalism.powerMode"
    static let islandPowerModeKey = "Feudalism.islandPowerMode"
    static let fastGameKey = "Feudalism.fastGame"
    static let showLogPanelKey = "Feudalism.showLogPanel"
    static let graphicsQualityKey = "Feudalism.graphicsQuality"
    static let fullscreenEnabledKey = "Feudalism.fullscreenEnabled"
    static let vsyncEnabledKey = "Feudalism.vsyncEnabled"
    static let showFPSKey = "Feudalism.showFPS"
    static let gameDifficultyKey = "Feudalism.gameDifficulty"
    static let autoSaveEnabledKey = "Feudalism.autoSaveEnabled"
    static let autoSaveIntervalMinutesKey = "Feudalism.autoSaveIntervalMinutes"
    static let showTutorialHintsKey = "Feudalism.showTutorialHints"
    static let cameraSensitivityKey = "Feudalism.cameraSensitivity"
    static let invertYAxisKey = "Feudalism.invertYAxis"
    static let reduceMotionKey = "Feudalism.reduceMotion"
    static let subtitlesEnabledKey = "Feudalism.subtitlesEnabled"
    static let subtitleSizeKey = "Feudalism.subtitleSize"
    static let highContrastUIKey = "Feudalism.highContrastUI"
    static let audioMutedKey = "Feudalism.audioMuted"
    static let invertScrollZoomKey = "Feudalism.invertScrollZoom"
    static let aiEnabledKey = "Feudalism.aiEnabled"
    static let aiThinkIntervalKey = "Feudalism.aiThinkInterval"
    static let aiAggressionKey = "Feudalism.aiAggression"
    static let aiEconomyFocusKey = "Feudalism.aiEconomyFocus"
    static let bottomBarIconScaleKey = "Feudalism.bottomBarIconScale"
    static let bottomBarAreaScaleKey = "Feudalism.bottomBarAreaScale"
    static let bottomBarOpacityKey = "Feudalism.bottomBarOpacity"
}
