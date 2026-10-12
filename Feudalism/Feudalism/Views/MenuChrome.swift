//
//  MenuChrome.swift
//  Feudalism
//
//  Zajednički zaglavlje podizbornika (Nazad + naslov) preko Locales.
//

import SwiftUI

struct MenuBackHeader: View {
    let title: String
    let backTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Label(backTitle, systemImage: "chevron.backward")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Text(title)
                .font(.custom("Georgia", size: 22))
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.98))
            Spacer(minLength: 0)
            Color.clear.frame(width: 80, height: 24)
        }
    }
}

func menuBackHeader(titleKey: String, language: AppLanguage, action: @escaping () -> Void) -> MenuBackHeader {
    MenuBackHeader(
        title: LocalizedStrings.string(for: titleKey, language: language),
        backTitle: LocalizedStrings.string(for: "menu_back", language: language),
        action: action
    )
}
