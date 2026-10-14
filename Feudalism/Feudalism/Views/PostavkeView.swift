//
//  PostavkeView.swift
//  Feudalism
//
//  Postavke na početnom zaslonu: kontrola, slika, zvuk, igra, AI i pristupačnost.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PostavkeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameState: GameState
    @State private var selectedSection: PostavkeSection = .general
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        NavigationSplitView {
            List(PostavkeSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Postavke")
            .frame(minWidth: 200)
        } detail: {
            PostavkeSectionContent(section: selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
        }
        .frame(minWidth: 560, minHeight: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Zatvori") {
                    if let onDismiss { onDismiss() }
                    else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
            }
        }
    }
}

enum PostavkeSection: String, CaseIterable, Identifiable {
    case general
    case controls
    case audio
    case video
    case gameplay
    case ai
    case pristupacnost
    case profil
    case ble

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Općenito"
        case .controls: return "Kontrola"
        case .audio: return "Zvuk"
        case .video: return "Slika"
        case .gameplay: return "Igra"
        case .ai: return "AI"
        case .pristupacnost: return "Pristupačnost"
        case .profil: return "Profil"
        case .ble: return "Bluetooth"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .controls: return "keyboard"
        case .audio: return "speaker.wave.2"
        case .video: return "display"
        case .gameplay: return "gamecontroller"
        case .ai: return "brain"
        case .pristupacnost: return "accessibility"
        case .profil: return "person.crop.circle.fill"
        case .ble: return "antenna.radiowaves.left.and.right"
        }
    }

    var previous: PostavkeSection? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i > 0 else { return nil }
        return all[i - 1]
    }

    var next: PostavkeSection? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i < all.count - 1 else { return nil }
        return all[i + 1]
    }
}

/// Sadržaj jedne kategorije – koristi se i u glavnom izborniku i u zasebnom prozoru.
struct PostavkeSectionContent: View {
    @EnvironmentObject private var gameState: GameState
    let section: PostavkeSection
    @State private var showFirstLaunchSlot = false

    var body: some View {
        Group {
            switch section {
            case .general: generalContent
            case .controls: controlsContent
            case .audio: audioContent
            case .video: videoContent
            case .gameplay: gameplayContent
            case .ai: aiContent
            case .pristupacnost: pristupacnostContent
            case .profil: profilContent
            case .ble: bleContent
            }
        }
    }

    private var generalContent: some View {
        Form {
            Section {
                Picker("Jezik", selection: $gameState.appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                Text("Tekstovi su u mapi Locales (hr, en, de, fr, it, es).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Jezik") }
            Section {
                Toggle("Početna animacija", isOn: $gameState.showStartupAnimation)
                Toggle("Nazivi u donjem izborniku", isOn: $gameState.showBottomBarLabels)
            } header: { Text("Sučelje") }
            Section {
                Button("Simulator prvog paljenja") {
                    showFirstLaunchSlot = true
                }
                if showFirstLaunchSlot {
                    Text("Ovdje će ići kako se aplikacija ponaša kad se prvi put upali.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: { Text("Prvo paljenje") }
            Section {
                Button("Vrati tvorničke postavke") {
                    gameState.resetUserSettings()
                }
                Text("Vraća kontrolu, sliku, zvuk, igru i AI. Ime profila ostaje.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Reset") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var controlsContent: some View {
        Form {
            Section {
                Picker("Ulazni uređaj", selection: $gameState.inputDevice) {
                    ForEach(InputDevice.allCases, id: \.self) { device in
                        Text(device.displayName).tag(device)
                    }
                }
                .pickerStyle(.segmented)
                Text("Trackpad: gestama. Miš: srednja tipka za pomak mape.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Uređaj") }
            Section {
                sliderRow(title: "Osjetljivost kamere", value: $gameState.cameraSensitivity, range: 0.5...2.0, step: 0.1) {
                    String(format: "%.1f×", gameState.cameraSensitivity)
                }
                Toggle("Invertirana Y os (nagib)", isOn: $gameState.invertYAxis)
                Toggle("Invertirani zoom kotačićem", isOn: $gameState.invertScrollZoom)
            } header: { Text("Kamera") }
            Section {
                keyRow("Pomak mape", "W A S D / strelice / povuci")
                keyRow("Zoom", "kotačić ili gestu stezanja")
                keyRow("Nagib", "desni klik + povuci (miš) / dva prsta")
                keyRow("Pauza", "Esc")
                keyRow("Odabir vojnika", "povuci kvadrat na karti")
            } header: { Text("Tipke") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var audioContent: some View {
        Form {
            Section {
                Toggle("Utišaj sve", isOn: $gameState.audioMuted)
                volumeRow(title: "Muzika", icon: "music.note", value: $gameState.audioMusicVolume)
                volumeRow(title: "Zvukovi", icon: "speaker.wave.2.fill", value: $gameState.audioSoundsVolume)
                volumeRow(title: "Govor", icon: "person.wave.2.fill", value: $gameState.audioSpeechVolume)
            } header: { Text("Glasnoće") }
            .disabled(false)
            Section {
                Toggle("Zvuk postavljanja", isOn: $gameState.playPlacementSound)
                Toggle("Zvuk izbornika", isOn: $gameState.playBarTransitionSound)
                Text("Muzika mape: map_music. Intro: soundtrack. Vatra: Core/Audio/Fire (fire_start, fire_loop).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Efekti") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var videoContent: some View {
        Form {
            DisplaySettingsSection()
            Section {
                sliderRow(title: "Veličina ikona", value: $gameState.bottomBarIconScale, range: 0.75...1.5, step: 0.05) {
                    "\(Int((gameState.bottomBarIconScale * 100).rounded())) %"
                }
                sliderRow(title: "Područje bara", value: $gameState.bottomBarAreaScale, range: 0.8...1.35, step: 0.05) {
                    "\(Int((gameState.bottomBarAreaScale * 100).rounded())) %"
                }
                sliderRow(title: "Prozirnost", value: $gameState.bottomBarOpacity, range: 0.35...1, step: 0.05) {
                    "\(Int((gameState.bottomBarOpacity * 100).rounded())) %"
                }
                Text("Gornji island ostaje isti. Ove postavke mijenjaju samo donji bar – za MacBook i prilagođene zaslone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Donji bar") }
            Section {
                Picker("Kvaliteta grafike", selection: $gameState.graphicsQuality) {
                    ForEach(GraphicsQuality.allCases) { q in
                        Text(q.displayName).tag(q)
                    }
                }
                .pickerStyle(.menu)
                Text(graphicsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Ušteda energije (30 fps)", isOn: $gameState.powerMode)
                Toggle("VSync", isOn: $gameState.vsyncEnabled)
                Toggle("Puni zaslon", isOn: $gameState.fullscreenEnabled)
                Toggle("Prikaži FPS i performanse", isOn: $gameState.showFPS)
            } header: { Text("Grafika") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var graphicsHint: String {
        switch gameState.graphicsQuality {
        case .low: return "Bez antialiasinga, 30 sličica. Za slabije strojeve."
        case .medium: return "Blagi antialiasing, 60 sličica."
        case .high: return "Jači antialiasing, 60 sličica."
        case .ultra: return "Jači antialiasing. Bez VSync-a ide do 120 sličica."
        }
    }

    private var gameplayContent: some View {
        Form {
            Section {
                Picker("Težina", selection: $gameState.gameDifficulty) {
                    ForEach(GameDifficulty.allCases) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Brza igra", isOn: $gameState.fastGame)
                Toggle("Savjeti i tutorial", isOn: $gameState.showTutorialHints)
                Toggle("Panel dnevnika", isOn: $gameState.showLogPanel)
            } header: { Text("Partija") }
            Section {
                Toggle("Auto-spremanje", isOn: $gameState.autoSaveEnabled)
                Picker("Interval", selection: $gameState.autoSaveIntervalMinutes) {
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                }
                .pickerStyle(.menu)
                .disabled(!gameState.autoSaveEnabled)
                Text("Sprema se u Application Support/Feudalism/saves/auto.json.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Spremanje") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aiContent: some View {
        let rules = AILordRulebook.current
        let store = AILordProfileStore.shared
        return Form {
            Section {
                Toggle("AI lordovi odlučuju", isOn: $gameState.aiEnabled)
                Text("Isključeno: lordovi i dalje imaju iste zalihe i rad, ali ne biraju nove poteze. Uključeno: čekaju interval pa odlučuju.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                sliderRow(title: "Interval razmišljanja", value: $gameState.aiThinkIntervalSeconds, range: 0.5...10, step: 0.5) {
                    String(format: "%.1f s", gameState.aiThinkIntervalSeconds)
                }
            } header: { Text("Ponašanje") }
            Section {
                sliderRow(title: "Agresija", value: $gameState.aiAggression, range: 0...1, step: 0.05) {
                    aiAggressionLabel
                }
                sliderRow(title: "Gospodarstvo / vojska", value: $gameState.aiEconomyFocus, range: 0...1, step: 0.05) {
                    aiEconomyLabel
                }
                Text("Množi se s osobinama svakog lorda iz bilježnice. Pravila rada i cijena ostaju ista kao kod igrača.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Stil svih lordova") }
            Section {
                LabeledContent("Lordovi") { Text("\(store.profiles.count)") }
                LabeledContent("Građevine u pravilima") { Text("\(rules.buildings.count)") }
                LabeledContent("Roba") { Text("\(rules.goods.count)") }
                LabeledContent("Potezi") { Text("\(rules.actions.count)") }
                LabeledContent("Leveli") { Text("\(store.levels.count)") }
                Text("Ista pravila za igrača i AI: skladišta, hrana, sreća, svijeće, prijevoz. Profile lordova uređuješ u izborniku AI lordovi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Bilježnica") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aiAggressionLabel: String {
        switch gameState.aiAggression {
        case ..<0.34: return "Oprezan"
        case ..<0.67: return "Uravnotežen"
        default: return "Agresivan"
        }
    }

    private var aiEconomyLabel: String {
        switch gameState.aiEconomyFocus {
        case ..<0.34: return "Vojska"
        case ..<0.67: return "Mješovito"
        default: return "Gospodarstvo"
        }
    }

    private var pristupacnostContent: some View {
        Form {
            Section {
                Toggle("Smanji animacije", isOn: $gameState.reduceMotion)
                Toggle("Visoki kontrast sučelja", isOn: $gameState.highContrastUI)
            } header: { Text("Prikaz") }
            Section {
                Toggle("Titlovi", isOn: $gameState.subtitlesEnabled)
                Picker("Veličina titlova", selection: $gameState.subtitleSize) {
                    ForEach(SubtitleSize.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!gameState.subtitlesEnabled)
            } header: { Text("Tekst") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var profilContent: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    profileAvatar
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Ime", text: profileGivenName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Prezime", text: profileFamilyName)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 8) {
                            Button("Učitaj sliku") { loadProfileImage() }
                            if !gameState.playerAvatarPath.isEmpty {
                                Button("Makni sliku") { gameState.playerAvatarPath = "" }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: { Text("Osoba") }
            Section {
                Picker("Amblem", selection: $gameState.playerEmblemId) {
                    ForEach(PlayerEmblem.allCases) { emblem in
                        Label(emblem.displayName, systemImage: emblem.sfSymbolName)
                            .tag(emblem.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } header: { Text("Amblem") }
            Section {
                LabeledContent("Sati igranja", value: gameState.profilePlayTimeLabel)
                LabeledContent("Partije", value: "\(gameState.profileMatchesPlayed)")
                LabeledContent("Postavljene građevine", value: "\(gameState.profileBuildingsPlaced)")
            } header: { Text("Mjere") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var profileAvatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
            if let image = profileImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: PlayerEmblem(rawValue: gameState.playerEmblemId)?.sfSymbolName ?? "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1))
    }

    private var profileImage: NSImage? {
        let path = gameState.playerAvatarPath
        guard !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private var profileGivenName: Binding<String> {
        Binding(
            get: { gameState.playerGivenName },
            set: { gameState.playerProfileName = Self.joinName($0, gameState.playerFamilyName) }
        )
    }

    private var profileFamilyName: Binding<String> {
        Binding(
            get: { gameState.playerFamilyName },
            set: { gameState.playerProfileName = Self.joinName(gameState.playerGivenName, $0) }
        )
    }

    private static func joinName(_ given: String, _ family: String) -> String {
        [given, family]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func loadProfileImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Učitaj sliku"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Feudalism", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder ?? URL(fileURLWithPath: NSTemporaryDirectory()), withIntermediateDirectories: true)
        let dest = (folder ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("avatar.png")
        if let image = NSImage(contentsOf: url),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dest)
            gameState.playerAvatarPath = dest.path
        }
    }

    private var bleContent: some View {
        Form {
            Section {
                Toggle("Bluetooth Low Energy", isOn: $gameState.bleEnabled)
                Text("Za kasnije povezivanje s mobitelom ili satom (obavijesti, upravljanje).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Uređaji") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func volumeRow(title: String, icon: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24, alignment: .center)
                .foregroundStyle(.secondary)
            Text(title)
            Slider(value: value, in: 0...1, step: 0.05)
                .disabled(gameState.audioMuted)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: () -> String) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Slider(value: value, in: range, step: step)
            Text(label())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 72, alignment: .trailing)
        }
    }

    private func keyRow(_ action: String, _ keys: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(keys)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DisplaySettingsSection: View {
    @State private var probe = DisplayProbe.current()

    var body: some View {
        Section {
            LabeledContent("Zaslon") { Text(probe.recognizedName) }
            LabeledContent("Točke (x × y)") { Text(probe.pointsLabel) }
            LabeledContent("Pikseli (x × y)") { Text(probe.pixelsLabel) }
            LabeledContent("Omjer") { Text(probe.ratioLabel) }
            LabeledContent("Dijagonala") { Text(probe.inchesLabel) }
            LabeledContent("Skala") { Text(String(format: "%.0f×", probe.scale)) }
            VStack(alignment: .leading, spacing: 6) {
                Text("Uobičajeni omjeri")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(DisplayProbe.commonRatios, id: \.2) { item in
                    let current = closestCommonRatio(to: probe) == (item.0, item.1)
                    HStack {
                        Text("\(item.0)∶\(item.1)")
                            .font(.body.monospacedDigit())
                        Text(item.2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if current {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(.top, 4)
            Text(probe.isCustom
                 ? "Ovo nije standardni MacBook zaslon – mjere su izračunate s trenutnog monitora."
                 : "Prepoznat je MacBook zaslon. Ako priključiš drugi ekran, brojke se osvježe same.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Zaslon")
        }
        .onAppear { probe = DisplayProbe.current() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            probe = DisplayProbe.current()
        }
    }

    private func closestCommonRatio(to snap: DisplaySnapshot) -> (Int, Int) {
        let value = Double(snap.pixelWidth) / Double(max(1, snap.pixelHeight))
        return DisplayProbe.commonRatios.min { a, b in
            abs(Double(a.0) / Double(a.1) - value) < abs(Double(b.0) / Double(b.1) - value)
        }.map { ($0.0, $0.1) } ?? (snap.ratioW, snap.ratioH)
    }
}

#Preview {
    PostavkeView()
        .environmentObject(GameState())
}
