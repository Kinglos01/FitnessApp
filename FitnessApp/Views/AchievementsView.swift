//
//  AchievementsView.swift
//  FitnessApp
//
 
import SwiftUI
 
// MARK: - AchievementsView
 
struct AchievementsView: View {
 
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
 
    @State private var unlocked: [UnlockedAchievement] = []
    @State private var isLoading = true
    @State private var selectedCategory: AchievementCategory? = nil
 
    private var userId: String { appState.currentUser?.id ?? "" }
 
    private var unlockedIds: Set<String> { Set(unlocked.map { $0.id }) }
 
    private var filteredDefinitions: [AchievementDefinition] {
        if let cat = selectedCategory {
            return AchievementDefinition.all.filter { $0.category == cat }
        }
        return AchievementDefinition.all
    }
 
    private var unlockedCount: Int { unlocked.count }
    private var totalCount: Int { AchievementDefinition.all.count }
 
    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
 
            VStack(spacing: 0) {
                header
                progressBanner
                categoryFilter
                ScrollView(showsIndicators: false) {
                    if isLoading {
                        ProgressView()
                            .tint(.brandLime)
                            .padding(.top, 60)
                            .frame(maxWidth: .infinity)
                    } else {
                        badgeGrid
                    }
                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear { Task { await load() } }
    }
 
    // MARK: - Header
 
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.brandCream)
            }
            Spacer()
            Text("Achievements")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.brandCream)
            Spacer()
            Image(systemName: "chevron.left").foregroundColor(.clear)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
 
    // MARK: - Progress Banner
 
    private var progressBanner: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(unlockedCount) / \(totalCount) Earned")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.brandCream)
                    Text("Keep training to unlock more")
                        .font(.system(size: 12))
                        .foregroundColor(Color.brandCream.opacity(0.5))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.brandCream.opacity(0.1), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: totalCount > 0 ? CGFloat(unlockedCount) / CGFloat(totalCount) : 0)
                        .stroke(Color.brandLime, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(totalCount > 0 ? Int((Double(unlockedCount) / Double(totalCount)) * 100) : 0)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.brandLime)
                }
            }
 
            // progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brandCream.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brandLime)
                        .frame(width: totalCount > 0
                               ? geo.size.width * CGFloat(unlockedCount) / CGFloat(totalCount)
                               : 0,
                               height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color.brandCream.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.08), lineWidth: 0.5))
        .cornerRadius(14)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
 
    // MARK: - Category Filter
 
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", icon: "square.grid.2x2.fill", color: .brandLime, selected: selectedCategory == nil) {
                    withAnimation { selectedCategory = nil }
                }
                ForEach(AchievementCategory.allCases, id: \.self) { cat in
                    filterChip(label: cat.rawValue, icon: cat.icon, color: cat.color, selected: selectedCategory == cat) {
                        withAnimation { selectedCategory = selectedCategory == cat ? nil : cat }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
 
    private func filterChip(label: String, icon: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(selected ? .brandNavy : Color.brandCream.opacity(0.7))
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Capsule().fill(selected ? color : Color.brandCream.opacity(0.07)))
            .overlay(Capsule().stroke(selected ? Color.clear : Color.brandCream.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
 
    // MARK: - Badge Grid
 
    private var badgeGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 14
        ) {
            ForEach(filteredDefinitions) { def in
                BadgeCell(
                    definition: def,
                    unlockedAt: unlocked.first(where: { $0.id == def.id })?.unlockedAt
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
 
    // MARK: - Load
 
    private func load() async {
        isLoading = true
        do {
            unlocked = try await AchievementService.shared.fetchUnlocked(userId: userId)
        } catch {
            print("AchievementsView load error: \(error)")
        }
        isLoading = false
    }
}
 
// MARK: - BadgeCell
 
private struct BadgeCell: View {
    let definition: AchievementDefinition
    let unlockedAt: Date?
 
    private var isUnlocked: Bool { unlockedAt != nil }
 
    private var formattedDate: String {
        guard let date = unlockedAt else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
 
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked
                          ? definition.tierColor.opacity(0.18)
                          : Color.brandCream.opacity(0.04))
                    .frame(width: 62, height: 62)
 
                Circle()
                    .stroke(isUnlocked
                            ? definition.tierColor.opacity(0.5)
                            : Color.brandCream.opacity(0.1),
                            lineWidth: isUnlocked ? 2 : 1)
                    .frame(width: 62, height: 62)
 
                Image(systemName: definition.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isUnlocked
                                     ? definition.tierColor
                                     : Color.brandCream.opacity(0.18))
 
                // lock overlay
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.brandCream.opacity(0.25))
                        .offset(x: 18, y: 18)
                }
 
                // tier crown for gold
                if isUnlocked && definition.tier == 3 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                        .offset(x: 18, y: -18)
                }
            }
 
            VStack(spacing: 3) {
                Text(definition.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isUnlocked ? .brandCream : Color.brandCream.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
 
                if isUnlocked {
                    Text(formattedDate)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(definition.tierColor.opacity(0.8))
                } else {
                    Text(definition.description)
                        .font(.system(size: 9))
                        .foregroundColor(Color.brandCream.opacity(0.2))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isUnlocked
                      ? definition.tierColor.opacity(0.06)
                      : Color.brandCream.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isUnlocked
                        ? definition.tierColor.opacity(0.2)
                        : Color.brandCream.opacity(0.06),
                        lineWidth: 0.5)
        )
    }
}
 
// MARK: - Preview
 
#Preview {
    AchievementsView()
        .environment(AppState())
}
