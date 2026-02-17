import SwiftUI
import ReveryParallaxViewer

/// Persistent parallax background — load once, never recreated.
/// Place this ABOVE any navigation/tab switching so SwiftUI never destroys it.
struct ParallaxBackgroundView: View {
    @State private var bgImage: UIImage? = nil
    @State private var depthImage: UIImage? = nil
    @State private var parallaxReady = false
    @State private var shouldCreateParallax = false

    private let zoom: Float = 1.08

    var body: some View {
        GeometryReader { _ in
            // Static image at zoom level — visible immediately on first frame
            if let staticImage = bgImage {
                Image(uiImage: staticImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(CGFloat(zoom))
                    .ignoresSafeArea()
                    // Parallax overlay fades in once depth is ready
                    .overlay {
                        if shouldCreateParallax {
                            ParallaxImageView(
                                image: staticImage,
                                depthImage: depthImage,
                                isReady: $parallaxReady,
                                zoom: zoom,
                                contrast: .moderate,
                                parallaxIntensityX: 0.35,
                                parallaxIntensityY: 0.35,
                                blurStrength: 0.0,
                                smoothingMode: .auto,
                                depthSmoothing: 0.5
                            )
                            .ignoresSafeArea()
                            .opacity(parallaxReady ? 1.0 : 0.0)
                            .animation(.easeIn(duration: 0.4), value: parallaxReady)
                            .transition(.identity)
                        }
                    }
                    .task {
                        // Defer Metal view creation by one frame so static image paints first
                        parallaxReady = false
                        shouldCreateParallax = false
                        try? await Task.sleep(for: .milliseconds(1))
                        withAnimation(.none) { shouldCreateParallax = true }
                    }
            }
        }
        .ignoresSafeArea()
        .onAppear { loadImages() }
    }

    private func loadImages() {
        Task.detached {
            let img = UIImage(named: "mars")
            let depth = UIImage(named: "mars.depth")
            await MainActor.run {
                bgImage = img
                depthImage = depth
            }
        }
    }
}
