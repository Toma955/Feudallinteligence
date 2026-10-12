//
//  AboutView.swift
//  Feudalism
//
//  About: podloge, sve građevine, svi vojnici — svaka stavka u 3D.
//

import SwiftUI

private enum AboutGoodsKind: String, CaseIterable, Identifiable {
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
        case .weapons: return []
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

struct AboutView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isPresented: Bool
    @Binding var showHowTo: Bool
    var infoTick: Int
    @State private var category: ObjectCategory = .farme
    @State private var goodsKind: AboutGoodsKind?

    private var language: AppLanguage { gameState.appLanguage }

    private static let peopleCategories: Set<ObjectCategory> = [.vojnici, .radnici]

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        if let build, !build.isEmpty, build != version {
            return "\(version) (\(build))"
        }
        return version
    }

    /// Sve građevine iz kataloga (bez ljudi) plus placeable tipovi koji možda nisu u katalogu.
    private var catalogBuildings: [GameObject] {
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

    private var visibleCategories: [ObjectCategory] {
        ObjectCategory.allCases.filter { cat in
            !Self.peopleCategories.contains(cat) && catalogBuildings.contains { $0.category == cat }
        }
    }

    private var buildingsInCategory: [GameObject] {
        let chosen = visibleCategories.contains(category) ? category : (visibleCategories.first ?? .farme)
        return catalogBuildings.filter { $0.category == chosen }
    }

    private var pads: [PadBrush] {
        PadBrush.allCases.filter { $0 != .obrisi }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            menuBackHeader(titleKey: "menu_about", language: language) {
                isPresented = false
            }

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
                        ForEach(pads) { pad in
                            padCard(pad)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AboutSection.buildings.title(language))
                            .font(.custom("Georgia", size: 20))
                            .foregroundStyle(.white.opacity(0.95))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(AboutGoodsKind.allCases) { kind in
                                    goodsButton(kind)
                                }
                                ForEach(visibleCategories) { cat in
                                    categoryButton(cat)
                                }
                            }
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                            if let goodsKind {
                                if goodsKind.items.isEmpty {
                                    Text("Za sada prazno.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                }
                                ForEach(goodsKind.items) { item in
                                    goodCard(item)
                                }
                            } else {
                                ForEach(buildingsInCategory, id: \.id) { object in
                                    buildingCard(object)
                                }
                            }
                        }
                    }
                    sectionBlock(AboutSection.soldiers.title(language)) {
                        ForEach(SoldierType.allCases) { type in
                            soldierCard(type)
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

    private func goodsButton(_ kind: AboutGoodsKind) -> some View {
        let selected = goodsKind == kind
        return Button {
            goodsKind = kind
        } label: {
            Text(kind.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .yellow : .white.opacity(0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.white.opacity(0.2) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func goodCard(_ kind: AboutGoodKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GoodPreviewView(kind: kind)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(kind.title)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func categoryButton(_ cat: ObjectCategory) -> some View {
        let selected = goodsKind == nil && (visibleCategories.contains(category) ? category == cat : cat == visibleCategories.first)
        return Button {
            goodsKind = nil
            category = cat
        } label: {
            Text(cat.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .yellow : .white.opacity(0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.white.opacity(0.2) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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

    private func padCard(_ pad: PadBrush) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PadPreviewView(pad: pad)
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

    private func buildingCard(_ object: GameObject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ObjectPreviewView(objectId: object.id)
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

    private func soldierCard(_ type: SoldierType) -> some View {
        let health = LocalizedStrings.string(for: "about_soldier_health", language: language)
        return VStack(alignment: .leading, spacing: 8) {
            SoldierPreviewView(type: type)
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
