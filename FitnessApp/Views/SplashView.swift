//
//  SplashView.swift
//  FitnessApp
//

import SwiftUI

struct SplashView: View {

    @State private var isActive = false        // triggers swap to RootView
    @State private var overlayOpacity = 1.0    // white fade-out overlay
    @State private var logoScale = 0.75
    @State private var logoOpacity = 0.0

    var body: some View {
        ZStack {
            // MARK: - App Content (always underneath)
            RootView()
                .opacity(isActive ? 1.0 : max(0.0, min(1.0, 1.0 - overlayOpacity)))

            // MARK: - White Fade Overlay
            if !isActive {
                Color.white
                    .ignoresSafeArea()
                    .opacity(overlayOpacity)

                // Logo on top of the white screen
                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    Text("FitnessApp")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(logoOpacity)
                }
            }
        }
        .onAppear {
            // 1. Pop logo in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            // 2. After a short hold, fade the whole white overlay out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    overlayOpacity = 0.0
                }
            }

            // 2b. Fade the logo/text out slightly earlier so it reaches 0 before removal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    logoOpacity = 0.0
                }
            }

            // 3. Remove overlay view from hierarchy once invisible
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                isActive = true
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(AppState())
}
