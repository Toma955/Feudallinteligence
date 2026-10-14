//
//  AboutView.swift
//  Feudalism
//
//  About: podloge, sve građevine, svi vojnici — svaka stavka u 3D.
//

import SwiftUI

enum AboutGoodsKind: String, CaseIterable, Identifiable {
    case resources
    case food
    case weapons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resources: return "Resursi"
        case .food: return "Hrana"
        case .weapons: return "Oružje"
        }
    }

    var items: [AboutGoodKind] {
        switch self {
        case .resources: return [.plank, .iron, .stone]
        case .food: return [.appleBasket, .cheese, .meat, .bread, .eggBasket, .chicken, .corn, .grapes, .banana, .vegetables, .spices, .wine, .sausages]
        case .weapons: return [.sword, .shield, .spear, .bow, .arrow, .crossbow, .mace, .leather]
        }
    }
}

private enum AboutSection: String, CaseIterable, Identifiable {
    case pads
    case buildings
    case soldiers

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        let key: String
        switch self {
        case .pads: key = "about_section_pads"
        case .buildings: key = "about_section_buildings"
        case .soldiers: key = "about_section_soldiers"
        }
        return LocalizedStrings.string(for: key, language: language)
    }
}

/// Zajedničko stanje About zaslona i donjeg islanda.
final class AboutBrowser: ObservableObject {
    static let shared = AboutBrowser()

    @Published var category: ObjectCategory = .farme
    @Published var goodsKind: AboutGoodsKind = .resources
    @Published var showSoldiers = false

    private static let peopleCategories: Set<ObjectCategory> = [.vojnici, .radnici]

    var catalogBuildings: [GameObject] {
        var seen = Set<String>()
        var list: [GameObject] = []
        for cat in ObjectCategory.allCases where !Self.peopleCategories.contains(cat) {
            for obj in ObjectCatalog.shared.objects(in: cat) {
                if seen.insert(obj.id).inserted {
                    list.append(obj)
                }
            }
        }
        for type in PlaceableSceneKitTypes.all {
            if seen.insert(type.objectId).inserted,
               let obj = ObjectCatalog.shared.object(id: type.objectId) {
                list.append(obj)
            }
        }
        return list
    }

    var buildCategories: [ObjectCategory] {
        let buildings = catalogBuildings
        return ObjectCategory.allCases.filter { cat in
            !Self.peopleCategories.contains(cat) && buildings.contains { $0.category == cat }
        }
    }
}

struct AboutView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isPresented: Bool
    @Binding var showHowTo: Bool
    var infoTick: Int
    @ObservedObject private var browser = AboutBrowser.shared

    private var language: AppLanguage { gameState.appLanguage }

    private var catalogBuildings: [GameObject] { browser.catalogBuildings }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        if let build, !build.isEmpty, build != version {
            return "\(version) (\(build))"
        }
        return version
    }

    private var visibleCategories: [ObjectCategory] { browser.buildCategories }

    private var buildingsInCategory: [GameObject] {
        let chosen = visibleCategories.contains(browser.category) ? browser.category : (visibleCategories.first ?? .farme)
        return catalogBuildings.filter { $0.category == chosen }
    }

    private var pads: [PadBrush] {
        PadBrush.allCases.filter { $0 != .obrisi }
    }

    var body: some View {
        Group {
            if showHowTo {
                howToPlay
            } else {
                elementsList
            }
        }
    }

    private var elementsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionBlock(AboutSection.pads.title(language)) {
                        ForEach(Array(pads.enumerated()), id: \.element.id) { index, pad in
                            padCard(pad, slot: index)
                        }
                    }
                    itemsBlock
                    VStack(alignment: .leading, spacing: 10) {
                        Text(browser.showSoldiers ? AboutSection.soldiers.title(language) : AboutSection.buildings.title(language))
                            .font(.custom("Georgia", size: 20))
                            .foregroundStyle(.white.opacity(0.95))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                            if browser.showSoldiers {
                                ForEach(Array(SoldierType.allCases.enumerated()), id: \.element.id) { index, type in
                                    soldierCard(type, slot: index)
                                }
                            } else {
                                ForEach(Array(buildingsInCategory.enumerated()), id: \.element.id) { index, object in
                                    buildingCard(object, slot: index)
                                }
                            }
                        }
                    }
                    informationBlock
                        .id("about-info")
                }
                .padding(.bottom, 8)
            }
            .onChange(of: infoTick) { tick in
                guard tick > 0 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo("about-info", anchor: .top)
                }
            }
        }
    }

    private var howToPlay: some View {
        ScrollView {
            Text(LocalizedStrings.string(for: "about_how_to_body", language: language))
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var informationBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStrings.string(for: "about_info", language: language))
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(.white.opacity(0.95))
            Text("\(LocalizedStrings.string(for: "about_version", language: language)) \(appVersion)")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.65))
            Text(LocalizedStrings.string(for: "about_body", language: language))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Resursi, hrana i oružje: cijeli popis predmeta u igri, odvojen od građevina.
    private var itemsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Svi predmeti igre")
                .font(.custom("Georgia", size: 22))
                .foregroundStyle(.white.opacity(0.98))
            Text("Resursi, hrana i oružje. Ovo je cijeli popis predmeta u igri.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.yellow.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                ForEach(Array(browser.goodsKind.items.enumerated()), id: \.element.id) { index, item in
                    goodCard(item, slot: index)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
        )
    }

    private func goodCard(_ kind: AboutGoodKind, slot: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GoodPreviewView(kind: kind, slot: slot)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(kind.title)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func sectionBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(.white.opacity(0.95))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                content()
            }
        }
    }

    private func padCard(_ pad: PadBrush, slot: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PadPreviewView(pad: pad, slot: slot)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(pad.rawValue)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.95))
            Text(padDescription(pad))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func buildingCard(_ object: GameObject, slot: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ObjectPreviewView(objectId: object.id, slot: slot)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(object.name)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)
            Text("\(object.size.width)×\(object.size.height) · \(padNeed(object.id))")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func soldierCard(_ type: SoldierType, slot: Int) -> some View {
        let health = LocalizedStrings.string(for: "about_soldier_health", language: language)
        return VStack(alignment: .leading, spacing: 8) {
            SoldierPreviewView(type: type, slot: slot)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(type.displayName)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)
            Text(PriceList.soldierPrice(type).description)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(type.speedText) · \(health) \(type.health)")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func padDescription(_ pad: PadBrush) -> String {
        switch pad {
        case .trava:
            return LocalizedStrings.string(for: "about_pad_trava", language: language)
        case .plodna:
            return LocalizedStrings.string(for: "about_pad_plodna", language: language)
        case .kamen:
            return LocalizedStrings.string(for: "about_pad_kamen", language: language)
        case .zeljezo:
            return LocalizedStrings.string(for: "about_pad_zeljezo", language: language)
        case .rijeka:
            return LocalizedStrings.string(for: "about_pad_rijeka", language: language)
        case .jezero:
            return LocalizedStrings.string(for: "about_pad_rijeka", language: language)
        case .more:
            return LocalizedStrings.string(for: "about_pad_more", language: language)
        case .pijesak:
            return LocalizedStrings.string(for: "about_pad_pijesak", language: language)
        case .obicno:
            return LocalizedStrings.string(for: "about_pad_tlo", language: language)
        case .mocvara:
            return LocalizedStrings.string(for: "about_pad_mocvara", language: language)
        case .obrisi:
            return ""
        }
    }

    private func padNeed(_ objectId: String) -> String {
        switch BuildRules.requiredPad(for: objectId) {
        case .iron:
            return LocalizedStrings.string(for: "about_need_iron", language: language)
        case .stone:
            return LocalizedStrings.string(for: "about_need_stone", language: language)
        case .fertile:
            return LocalizedStrings.string(for: "about_need_farm", language: language)
        case .flat:
            return LocalizedStrings.string(for: "about_need_flat", language: language)
        case .none:
            return LocalizedStrings.string(for: "about_need_none", language: language)
        }
    }
}
