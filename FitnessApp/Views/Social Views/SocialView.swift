//
//  SocialView.swift
//  FitnessApp
//
//  Social hub – the main container for the Social tab.
//

import SwiftUI

enum SocialTab: String, CaseIterable {
    case friends      = "Friends"
    case challenges   = "Challenges"
    case communities  = "Communities"
    case messages     = "Messages"
}

struct SocialView: View {

    @Environment(AppState.self) var appState
    @State private var selectedTab: SocialTab = .friends

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SocialTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .semibold, design: .rounded))
                                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Capsule().fill(selectedTab == tab ? Color.blue : Color(.systemGray5)))
                            }
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 8)
                }

                Group {
                    switch selectedTab {
                    case .friends:      FriendsView()
                    case .challenges:   ChallengesView()
                    case .communities:  CommunitiesView()
                    case .messages:     MessagesView()
                    }
                }.transition(.opacity)
            }
            .navigationTitle("Social")
        }
    }
}

#Preview {
    SocialView().environment(AppState())
}
