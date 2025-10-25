//
//  MainTabView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            CirclesView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "person.3.fill" : "person.3")
                    Text("Circles")
                }
                .tag(1)
            
            LeaderboardView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "trophy.fill" : "trophy")
                    Text("Leaderboard")
                }
                .tag(2)
            
            ChallengesView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "target" : "target")
                    Text("Challenges")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.primary)
        .onAppear {
            // Configure tab bar appearance for Apple-style look
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Views are now in separate files
// HomeView, CirclesView, LeaderboardView, ChallengesView, ProfileView

#Preview {
    MainTabView()
}
