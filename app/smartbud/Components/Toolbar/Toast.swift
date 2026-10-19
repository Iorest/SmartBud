import SwiftUI

struct Toast: View {
    @Binding var showToast: Bool
    @Binding var toastTitle: String
    @Binding var toastImage: String
    @Binding var toastColor: Color

    var body: some View {
        if showToast {
            HStack(spacing: 6.5) {
                Image(systemName: toastImage)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    
                    .foregroundStyle(toastColor)

                Text(toastTitle)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    
                    .lineLimit(1)
                    .foregroundStyle(toastColor)
            }
            .padding(8)
            .background(
                toastColor.opacity(0.23), in: RoundedRectangle(cornerRadius: GlassRadius.chip, style: .continuous)
            )
            .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
            .frame(maxWidth: 250)
            .frame(height: 35)
            .padding(20)
        }
    }
}
