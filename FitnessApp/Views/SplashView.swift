//
//  SplashView.swift
//  SimplyFit
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

                    Text("SimplyFit")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    overlayOpacity = 0.0
                }
            }

            // 3. Remove overlay view from hierarchy once invisible
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isActive = true
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(AppState())
}