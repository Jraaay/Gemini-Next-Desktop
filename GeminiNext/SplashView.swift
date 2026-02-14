//
//  SplashView.swift
//  GeminiNext
//
//  Created by Jray on 2026/2/14.
//

import SwiftUI

/// Branded splash screen displayed during initial page load.
/// Shows the app icon, title, and an animated progress bar with a shimmer effect.
struct SplashView: View {

    /// Whether the content is still loading
    var isLoading: Bool

    /// Controls the fade-out / scale transition when loading completes
    @State private var isVisible: Bool = true

    /// Drives the infinite shimmer animation on the progress bar
    @State private var shimmerOffset: CGFloat = -1.0

    // MARK: - Constants

    private enum Layout {
        static let iconSize: CGFloat = 96
        static let iconCornerRadius: CGFloat = 22
        static let barWidth: CGFloat = 200
        static let barHeight: CGFloat = 4
        static let barCornerRadius: CGFloat = 2
    }

    // MARK: - Gradient

    /// Brand gradient inspired by Gemini's blue-to-purple palette
    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.50, blue: 0.98),   // Blue
                Color(red: 0.58, green: 0.40, blue: 0.98),   // Purple
                Color(red: 0.82, green: 0.35, blue: 0.85)    // Pink
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // App icon
                appIcon

                // App title with gradient
                Text("GeminiNext")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(brandGradient)

                // Animated progress bar
                progressBar
                    .padding(.top, 8)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .onChange(of: isLoading) { _, newValue in
            if !newValue {
                withAnimation(.easeOut(duration: 0.4)) {
                    isVisible = false
                }
            }
        }
        .allowsHitTesting(isVisible)
        .onAppear {
            startShimmerAnimation()
        }
    }

    // MARK: - Subviews

    /// App icon loaded from the system application icon
    private var appIcon: some View {
        Group {
            if let nsImage = NSApp.applicationIconImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.iconCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }
        }
    }

    /// Custom capsule-shaped progress bar with a shimmer animation
    private var progressBar: some View {
        RoundedRectangle(cornerRadius: Layout.barCornerRadius)
            .fill(Color.primary.opacity(0.08))
            .frame(width: Layout.barWidth, height: Layout.barHeight)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: Layout.barCornerRadius)
                    .fill(brandGradient)
                    .frame(width: Layout.barWidth * 0.4, height: Layout.barHeight)
                    .offset(x: shimmerOffset * (Layout.barWidth * 0.6))
            }
            .clipShape(RoundedRectangle(cornerRadius: Layout.barCornerRadius))
    }

    // MARK: - Animation

    /// Start the infinite left-to-right shimmer loop
    private func startShimmerAnimation() {
        shimmerOffset = -0.2
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            shimmerOffset = 1.0
        }
    }
}

#Preview {
    SplashView(isLoading: true)
        .frame(width: 800, height: 600)
}
