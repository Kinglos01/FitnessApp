import SwiftUI

enum SocialTab: String, CaseIterable {
    case friends     = "Friends"
    case challenges  = "Challenges"
    case communities = "Communities"
    case messages    = "Messages"
}

struct SocialView: View {

    @Environment(AppState.self) var appState
    @State private var selectedTab: SocialTab = .friends

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Tab picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(SocialTab.allCases, id: \.self) { tab in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                                } label: {
                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: selectedTab == tab ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(selectedTab == tab ? .brandNavy : Color.brandCream.opacity(0.6))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(selectedTab == tab ? Color.brandLime : Color.brandCream.opacity(0.08)))
                                        .overlay(
                                            Capsule().stroke(
                                                selectedTab == tab ? Color.clear : Color.brandCream.opacity(0.12),
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }

                    Divider().background(Color.brandCream.opacity(0.1))

                    Group {
                        switch selectedTab {
                        case .friends:     FriendsView()
                        case .challenges:  ChallengesView()
                        case .communities: CommunitiesView()
                        case .messages:    MessagesView()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    SocialView().environment(AppState())
}
