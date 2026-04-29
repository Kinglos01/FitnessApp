//
//  MainTabView.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/19/26.
//

import SwiftUI

struct MainTabView: View {

    @State private var nutritionManager = NutritionManager()
    @Environment(AppState.self) var appState

    private let tabs: [(label: String, icon: String)] = [
        ("Dashboard", "house.fill"),
        ("Nutrition",  "fork.knife"),
        ("Activity",   "figure.run"),
        ("Social",     "person.2.fill"),
        ("Calendar",   "calendar")
    ]

    private var selectedTab: Binding<Int> {
        Binding(
            get: { appState.selectedTab },
            set: { appState.selectedTab = $0 }
        )
    }

    var body: some View {
        TabView(selection: selectedTab) {
            DashboardView()
                .id(appState.currentUser?.id ?? "")
                .tag(0)

            NutritionView()
                .tag(1)

            ActivityLogView(userId: appState.currentUser?.id ?? "")
                .id(appState.currentUser?.id ?? "")
                .tag(2)

            SocialView()
                .tag(3)

            CalendarView()
                .id(appState.currentUser?.id ?? "")
                .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.brandNavy)
        .preferredColorScheme(.dark)
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount   = value.translation.height
                    guard abs(horizontalAmount) > abs(verticalAmount) else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if horizontalAmount < 0 {
                            appState.selectedTab = min(appState.selectedTab + 1, 4)
                        } else {
                            appState.selectedTab = max(appState.selectedTab - 1, 0)
                        }
                    }
                }
        )
        .environment(nutritionManager)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customTabBar
        }
        .toolbarBackground(Color.brandNavy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithOpaqueBackground()
            navAppearance.backgroundColor = UIColor(Color.brandNavy)
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.brandCream)]
            navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.brandCream)]
            navAppearance.shadowColor = .clear
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            UINavigationBar.appearance().compactAppearance = navAppearance
            UINavigationBar.appearance().barTintColor = UIColor(Color.brandNavy)
            UINavigationBar.appearance().tintColor = UIColor(Color.brandLime)
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.brandCream.opacity(0.1))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    tabButton(index: index)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 28)
            .background(Color.brandNavy)
        }
        .background(Color.brandNavy)
    }

    private func tabButton(index: Int) -> some View {
        let tab      = tabs[index]
        let isActive = appState.selectedTab == index

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.selectedTab = index
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .top) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .brandLime : Color.brandCream.opacity(0.4))
                        .frame(height: 24)

                    if isActive {
                        Circle()
                            .fill(Color.brandLime)
                            .frame(width: 4, height: 4)
                            .offset(y: -6)
                    }
                }

                Text(tab.label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isActive ? .brandLime : Color.brandCream.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Populated") {
    MainTabView()
        .environment(AppState())
}

#Preview("Empty State") {
    MainTabView()
        .environment(AppState())
}
