import SwiftUI

struct ToolbarButton: View {
    var systemName: String
    var accessibilityLabel: String = ""
    var onTapGesture: (() -> Void)?

    var body: some View {
        Button {
            onTapGesture?()
        } label: {
            Circle()
                .fill(.clear)
                .frame(width: 33, height: 33)
                .overlay {
                    Image(systemName: systemName)
                        .font(.callout.weight(.semibold))
                        
                        .foregroundStyle(Color.SubtitleText)
                        .offset(y: 0.8)
                }
                .systemChip(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel.isEmpty ? systemName : accessibilityLabel)
    }
}
