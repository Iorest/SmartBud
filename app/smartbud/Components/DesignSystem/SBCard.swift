//
//  SBCard.swift
//  smartbud
//
//  Grouped content surface: system background, hairline border, no glass.
//

import SwiftUI

struct SBCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SBSpace.s) {
            if let title {
                Text(title)
                    .font(.sbSectionHeader)
                    .foregroundStyle(Color.SubtitleText)
            }
            content
        }
        .padding(SBSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.SecondaryBackground,
            in: RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .strokeBorder(Color.Outline.opacity(0.6), lineWidth: 0.5)
        }
    }
}
