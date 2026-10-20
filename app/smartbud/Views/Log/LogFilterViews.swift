import Foundation
import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
struct BackgroundBlurView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
#else
struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_: UIView, context _: Context) {}
}
#endif

struct NoResultsView: View {
    let fullscreen: Bool

    var body: some View {
        if fullscreen {
            VStack(spacing: 12) {
                Spacer()

                Image(systemName: "tray.full.fill")
                    .font(.largeTitle)

                    .foregroundStyle(Color.SubtitleText)

                Text(String.appLocalized("No entries found."))
                    .font(.title3.weight(.medium))

                    .foregroundStyle(Color.SubtitleText)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
        } else {
            VStack(spacing: 12) {
                Spacer()

                Image(systemName: "tray.full.fill")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(Color.SubtitleText)

                Text(String.appLocalized("No entries found."))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.SubtitleText)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .opacity(0.7)
            .padding(.top, 50)
        }
    }
}
