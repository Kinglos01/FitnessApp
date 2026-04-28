//
//  ThemeManager.swift
//  FitnessApp
//
//  Created by Carlos Berio 
//
//
//  ThemeManager.swift
//  FitnessApp
//

import SwiftUI

// MARK: - Theme

enum AppTheme: String, CaseIterable {
    case dark    = "Dark"
    case light   = "Light"
    case vibrant = "Vibrant"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .dark:    return "moon.fill"
        case .light:   return "sun.max.fill"
        case .vibrant: return "sparkles"
        }
    }

    // MARK: - Background (brandNavy equivalent)
    var navy: Color {
        switch self {
        case .dark:    return Color(hex: "000411")
        case .light:   return Color(hex: "F2F4EF")
        case .vibrant: return Color(hex: "1E0A3C")
        }
    }

    // MARK: - Primary accent (brandLime equivalent)
    var lime: Color {
        switch self {
        case .dark:    return Color(hex: "DBFE87")
        case .light:   return Color(hex: "5A9E00")
        case .vibrant: return Color(hex: "C8FF00")
        }
    }

    // MARK: - Secondary accent (brandOrange equivalent)
    var orange: Color {
        switch self {
        case .dark:    return Color(hex: "D74E09")
        case .light:   return Color(hex: "C44000")
        case .vibrant: return Color(hex: "FF6B1A")
        }
    }

    // MARK: - Blue accent (brandBlue equivalent)
    var blue: Color {
        switch self {
        case .dark:    return Color(hex: "48ACF0")
        case .light:   return Color(hex: "1A7FCC")
        case .vibrant: return Color(hex: "00CFFF")
        }
    }

    // MARK: - Text / cream (brandCream equivalent)
    var cream: Color {
        switch self {
        case .dark:    return Color(hex: "E9EDDE")
        case .light:   return Color(hex: "1A1A2E")
        case .vibrant: return Color(hex: "F0EAFF")
        }
    }

    // MARK: - Color scheme for SwiftUI
    var colorScheme: ColorScheme {
        switch self {
        case .dark:    return .dark
        case .light:   return .light
        case .vibrant: return .dark
        }
    }
}

// MARK: - ThemeManager

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "appTheme")
            applyUIKitTheme()
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.dark.rawValue
        self.current = AppTheme(rawValue: saved) ?? .dark
    }

    func applyUIKitTheme() {
        let theme = current
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(theme.navy)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(theme.cream)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(theme.cream)]
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(theme.lime)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(theme.navy)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
