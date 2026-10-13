//
//  MultiplayerSetupView.swift
//  Feudalism
//
//  Postava meča: mapa, prijatelj, AI lordovi (svatko svoga), pravila i snimanje.
//

import SwiftUI

struct MultiplayerSetupView: View {
    @EnvironmentObject private var gameState: GameState
    @ObservedObject private var friends = FriendBook.shared
    @ObservedObject private var lords = AILordProfileStore.shared

    @State private var mapSide = MapDimension.size200.side
    @State private var friendId: String?
    @State private var myLords: Set<String> = []
    @State private var friendLords: Set<String> = []
    @State private var military = true
    @State private var recordMatch = true
    @State private var readyNote = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                block("Mapa") {
                    HStack(spacing: 8) {
                        ForEach(MapDimension.allCases) { size in
                            choice("\(size.side)×\(size.side)", on: mapSide == size.side) {
                                mapSide = size.side
                            }
                        }
                    }
                }
                block("Prijatelj") {
                    if friends.friends.isEmpty {
                        Text("Nema prijatelja. Dodaj ih u Prijatelji.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.65))
                    } else {
                        HStack(spacing: 8) {
                            ForEach(friends.friends) { friend in
                                choice(friend.name, on: friendId == friend.id) {
                                    friendId = friend.id
                                }
                            }
                        }
                    }
                }
                block("AI lordovi — svatko stavlja svoga") {
                    HStack(alignment: .top, spacing: 16) {
                        lordColumn("Tvoji", selection: $myLords)
                        lordColumn("Prijateljevi", selection: $friendLords)
                    }
                }
                block("Pravila") {
                    HStack(spacing: 8) {
                        choice("Vojna", on: military) { military = true }
                        choice("Gospodarska", on: !military) { military = false }
                    }
                }
                block("Snimanje") {
                    choice(recordMatch ? "Snimanje uključeno" : "Snimi partiju", on: recordMatch) {
                        recordMatch.toggle()
                    }
                }
                Button(action: confirm) {
                    Text("Postavi meč")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                if !readyNote.isEmpty {
                    Text(readyNote)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lordColumn(_ title: String, selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(lords.profiles) { profile in
                let on = selection.wrappedValue.contains(profile.id)
                Button {
                    if on { selection.wrappedValue.remove(profile.id) }
                    else { selection.wrappedValue.insert(profile.id) }
                } label: {
                    HStack {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? .yellow : .white.opacity(0.45))
                        Text(profile.localizedName(language: gameState.appLanguage))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Georgia", size: 18))
                .foregroundStyle(.white)
            content()
        }
    }

    private func choice(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(on ? Color.yellow : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func confirm() {
        let friend = friends.friends.first { $0.id == friendId }?.name ?? "bez prijatelja"
        let rule = military ? "vojna" : "gospodarska"
        let film = recordMatch ? "snimanje uključeno" : "bez snimanja"
        readyNote = "Meč \(mapSide)×\(mapSide) s \(friend). Tvoji AI: \(myLords.count), prijateljevi: \(friendLords.count). Pravila: \(rule). \(film)."
        gameState.recordThisMatch = recordMatch
    }
}
