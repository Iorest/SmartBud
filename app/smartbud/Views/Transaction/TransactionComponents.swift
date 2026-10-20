import Foundation
import SwiftUI

struct NumPadButton: ButtonStyle {
    public func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.3), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct NoteView: View {
    @Binding var note: String
    @Binding var focused: Bool

    @FocusState private var textFocused: Bool
    let characterLimit = 50

    // Must match the rendered .body size, including any dynamicTypeSize cap
    // applied by the parent, or the pill is measured too narrow and the
    // placeholder truncates at accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17

    var noteWidth: CGFloat {
        let systemFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let roundedFont: UIFont
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            let rounded: UIFont? = UIFont(descriptor: descriptor, size: fontSize)
            roundedFont = rounded ?? systemFont
        } else {
            roundedFont = systemFont
        }

        let attributes = [NSAttributedString.Key.font: roundedFont]

        let size = (note as NSString).size(withAttributes: attributes)

        let placeholder = String.appLocalized("Add Note")
        let placeholderSize = (placeholder as NSString).size(withAttributes: attributes)

        if !note.isEmpty {
            return size.width + 2
        } else {
            // CJK placeholders measure to the exact glyph width, which then
            // truncates to "…" once rounded — leave a hair of slack.
            return placeholderSize.width + 4
        }

    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "text.alignleft")
                .font(.subheadline.weight(.semibold))

                .foregroundStyle(Color.SubtitleText)

            ZStack(alignment: .leading) {
                TextField("", text: $note)
                    .onChange(of: note) { _, new in
                        if new.count > characterLimit {
                            note = String(new.prefix(characterLimit))
                        }
                    }
                    .focused($textFocused)
                    .foregroundStyle(Color.PrimaryText)

                if note.isEmpty {
                    Text(String.appLocalized("Add Note"))
                        .foregroundStyle(Color.SubtitleText)
                        // Measured and rendered text width can differ by a
                        // hair at large sizes; shrink instead of truncating.
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .font(.body.weight(.semibold))

            .frame(maxWidth: noteWidth, alignment: .center)
        }
        .onTapGesture {
            textFocused = true
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.input, style: .continuous)
                .stroke(Color.Outline, lineWidth: 1.5)
        )
        .onChange(of: textFocused) { _, newValue in
            focused = newValue
        }
    }
}
