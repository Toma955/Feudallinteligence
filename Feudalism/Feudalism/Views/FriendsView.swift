//
//  FriendsView.swift
//  Feudalism
//
//  Popis prijatelja i chat. Isti popis koristi multiplayer.
//

import SwiftUI

struct FriendEntry: Identifiable, Codable, Hashable {
    var id: String
    var name: String
}

struct FriendChatLine: Identifiable, Codable, Equatable {
    var id: String
    var friendId: String
    var mine: Bool
    var text: String
}

final class FriendBook: ObservableObject {
    static let shared = FriendBook()

    @Published var friends: [FriendEntry] = []
    @Published var lines: [FriendChatLine] = []

    private let friendsKey = "Feudalism.friends"
    private let linesKey = "Feudalism.friendChat"

    private init() {
        if let data = UserDefaults.standard.data(forKey: friendsKey),
           let list = try? JSONDecoder().decode([FriendEntry].self, from: data) {
            friends = list
        }
        if let data = UserDefaults.standard.data(forKey: linesKey),
           let list = try? JSONDecoder().decode([FriendChatLine].self, from: data) {
            lines = list
        }
    }

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        friends.append(FriendEntry(id: UUID().uuidString, name: trimmed))
        save()
    }

    func send(_ text: String, to friendId: String, mine: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append(FriendChatLine(id: UUID().uuidString, friendId: friendId, mine: mine, text: trimmed))
        save()
    }

    func chat(with friendId: String) -> [FriendChatLine] {
        lines.filter { $0.friendId == friendId }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(data, forKey: friendsKey)
        }
        if let data = try? JSONEncoder().encode(lines) {
            UserDefaults.standard.set(data, forKey: linesKey)
        }
    }
}

struct FriendsView: View {
    @ObservedObject private var book = FriendBook.shared
    @State private var selectedId: String?
    @State private var draftName = ""
    @State private var draftMessage = ""

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Ime prijatelja", text: $draftName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    Button("Dodaj") { addFriend() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.yellow, in: Capsule())
                }
                if book.friends.isEmpty {
                    Text("Popis je prazan.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(book.friends) { friend in
                                Button {
                                    selectedId = friend.id
                                } label: {
                                    Text(friend.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(selectedId == friend.id ? Color.yellow.opacity(0.22) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(width: 280)
            chatPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var chatPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let friend = book.friends.first(where: { $0.id == selectedId }) {
                Text(friend.name)
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(.white)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(book.chat(with: friend.id)) { line in
                            Text(line.text)
                                .font(.system(size: 14))
                                .foregroundStyle(line.mine ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(line.mine ? Color.yellow : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                .frame(maxWidth: .infinity, alignment: line.mine ? .trailing : .leading)
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Poruka", text: $draftMessage)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .onSubmit { send(to: friend.id) }
                    Button("Pošalji") { send(to: friend.id) }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.yellow, in: Capsule())
                }
            } else {
                Spacer()
                Text("Odaberi prijatelja za chat.")
                    .font(.custom("Georgia", size: 18))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
        }
    }

    private func addFriend() {
        book.add(name: draftName)
        draftName = ""
        selectedId = book.friends.last?.id
    }

    private func send(to friendId: String) {
        book.send(draftMessage, to: friendId, mine: true)
        draftMessage = ""
    }
}
