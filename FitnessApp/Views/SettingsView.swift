//
//  SettingsView.swift
//  FitnessApp
//

import SwiftUI

// MARK: - Profile Draft

private struct ProfileDraft {
    var name: String
    var weightLbs: Int
    var heightFeet: Int
    var heightInches: Int
    var gender: String
    var birthDate: Date
    var activityLevel: String
    var primaryGoal: String
    var calorieGoal: Int
    var targetWeightLbs: Int
    var customCaloriesEnabled: Bool
}

// MARK: - SettingsView

struct SettingsView: View {

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    // MARK: Local-only preferences (Display & Notifications only)
    @AppStorage("settings_units") private var units: String = "Imperial"
    @AppStorage("settings_appearance") private var appearance: String = "Dark"
    @AppStorage("settings_week_start") private var weekStart: String = "Sunday"
    @AppStorage("settings_meal_reminders") private var mealReminders: Bool = true
    @AppStorage("settings_workout_reminder") private var workoutReminder: Bool = false
    @AppStorage("settings_streak_reminder") private var streakReminder: Bool = true

    // MARK: Draft state
    @State private var draft: ProfileDraft = ProfileDraft(
        name: "", weightLbs: 150, heightFeet: 5, heightInches: 10,
        gender: "Male", birthDate: Date(), activityLevel: "Moderately Active",
        primaryGoal: "Lose Weight", calorieGoal: 2200, targetWeightLbs: 175,
        customCaloriesEnabled: false
    )
    @State private var isSaving: Bool = false
    @State private var saveError: String = ""
    @State private var hasChanges: Bool = false

    // MARK: Navigation state
    @State private var showEditWeight: Bool = false
    @State private var showEditHeight: Bool = false
    @State private var showEditDOB: Bool = false
    @State private var showEditGender: Bool = false
    @State private var showTargets: Bool = false
    @State private var showGoalDialog: Bool = false
    @State private var showActivityDialog: Bool = false
    @State private var showUnitsDialog: Bool = false
    @State private var showAppearanceDialog: Bool = false
    @State private var showWeekStartDialog: Bool = false
    @State private var showCalorieSheet: Bool = false
    @State private var showTargetWeightSheet: Bool = false

    // MARK: Section icon colors
    private let profileIconColor = Color.brandLime
    private let targetsIconColor = Color(hex: "48ACF0")
    private let displayIconColor = Color(hex: "A082FF")
    private let notificationsIconColor = Color(hex: "50D2B4")
    private let accountIconColor = Color.brandOrange

    // MARK: Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    private func formattedHeight(_ totalInches: Double) -> String {
        let feet = Int(totalInches) / 12
        let inches = Int(totalInches) % 12
        return "\(feet)' \(inches)\""
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileCard
                        profileSection
                        targetsSection
                        displaySection
                        notificationsSection
                        accountSection
                        footerText
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            if let user = appState.currentUser {
                draft.name = user.name
                draft.weightLbs = Int(user.weight)
                draft.heightFeet = Int(user.height) / 12
                draft.heightInches = Int(user.height) % 12
                draft.gender = user.gender
                draft.birthDate = user.birthDate
                draft.activityLevel = user.activityLevel
                draft.primaryGoal = user.primaryGoal
                draft.calorieGoal = user.calorieGoal
                draft.targetWeightLbs = Int(user.targetWeightLbs ?? 175)
                draft.customCaloriesEnabled = user.customCaloriesEnabled
            }
        }
        .sheet(isPresented: $showEditWeight) {
            EditWeightSheet(draft: $draft, hasChanges: $hasChanges)
        }
        .sheet(isPresented: $showEditHeight) {
            EditHeightSheet(draft: $draft, hasChanges: $hasChanges)
        }
        .sheet(isPresented: $showEditDOB) {
            EditDOBSheet(draft: $draft, hasChanges: $hasChanges)
        }
        .sheet(isPresented: $showEditGender) {
            EditGenderSheet(draft: $draft, hasChanges: $hasChanges)
        }
        .sheet(isPresented: $showCalorieSheet) {
            CalorieGoalSheet(draft: $draft, hasChanges: $hasChanges)
        }
        .sheet(isPresented: $showTargetWeightSheet) {
            TargetWeightSheet(draft: $draft, hasChanges: $hasChanges)
        }
        .confirmationDialog("Primary Goal", isPresented: $showGoalDialog) {
            Button("Lose Weight") { draft.primaryGoal = "Lose Weight"; hasChanges = true }
            Button("Maintain Weight") { draft.primaryGoal = "Maintain Weight"; hasChanges = true }
            Button("Build Muscle") { draft.primaryGoal = "Build Muscle"; hasChanges = true }
            Button("Improve Endurance") { draft.primaryGoal = "Improve Endurance"; hasChanges = true }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Activity Level", isPresented: $showActivityDialog) {
            Button("Sedentary") { draft.activityLevel = "Sedentary"; hasChanges = true }
            Button("Lightly Active") { draft.activityLevel = "Lightly Active"; hasChanges = true }
            Button("Moderately Active") { draft.activityLevel = "Moderately Active"; hasChanges = true }
            Button("Very Active") { draft.activityLevel = "Very Active"; hasChanges = true }
            Button("Athlete") { draft.activityLevel = "Athlete"; hasChanges = true }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Units", isPresented: $showUnitsDialog) {
            Button("Imperial") { units = "Imperial" }
            Button("Metric") { units = "Metric" }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Appearance", isPresented: $showAppearanceDialog) {
            Button("Dark") { appearance = "Dark" }
            Button("Light") { appearance = "Light" }
            Button("System") { appearance = "System" }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Week Starts On", isPresented: $showWeekStartDialog) {
            Button("Sunday") { weekStart = "Sunday" }
            Button("Monday") { weekStart = "Monday" }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.brandCream)
            }

            Spacer()

            Text("Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.brandCream)

            Spacer()

            // Invisible spacer to balance the back button
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandLime)
                    .frame(width: 52, height: 52)
                Text(appState.currentUser.map { initials(from: $0.name) } ?? "?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brandNavy)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.currentUser?.name ?? "—")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.brandCream)
                Text(appState.currentUser?.email ?? "—")
                    .font(.system(size: 12))
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.brandLime.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brandLime.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        sectionBlock(label: "PROFILE") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "scalemass.fill",
                    iconColor: profileIconColor,
                    label: "Weight",
                    value: "\(draft.weightLbs) lbs",
                    action: { showEditWeight = true }
                )
                sectionDivider
                settingsRow(
                    icon: "ruler.fill",
                    iconColor: profileIconColor,
                    label: "Height",
                    value: "\(draft.heightFeet)' \(draft.heightInches)\"",
                    action: { showEditHeight = true }
                )
                sectionDivider
                settingsRow(
                    icon: "calendar",
                    iconColor: profileIconColor,
                    label: "Date of Birth",
                    value: {
                        let fmt = DateFormatter()
                        fmt.dateFormat = "MMM d, yyyy"
                        return fmt.string(from: draft.birthDate)
                    }(),
                    action: { showEditDOB = true }
                )
                sectionDivider
                settingsRow(
                    icon: "person.fill",
                    iconColor: profileIconColor,
                    label: "Gender",
                    value: draft.gender,
                    action: { showEditGender = true }
                )
                sectionDivider
                saveChangesRow
            }
        }
    }

    // MARK: - Save Changes Row

    private var saveChangesRow: some View {
        VStack(spacing: 6) {
            Button {
                saveChanges()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.brandLime)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(hasChanges ? .brandLime : Color.brandCream.opacity(0.25))
                    }
                    Text("Save Changes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hasChanges ? .brandLime : Color.brandCream.opacity(0.25))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hasChanges ? Color.brandLime.opacity(0.12) : Color.brandCream.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges || isSaving)

            if !saveError.isEmpty {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundColor(.brandOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
            }
        }
    }

    // MARK: - Targets Section

    private var targetsSection: some View {
        sectionBlock(label: "TARGETS") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "target",
                    iconColor: targetsIconColor,
                    label: "Primary Goal",
                    value: draft.primaryGoal,
                    action: { showGoalDialog = true }
                )
                sectionDivider
                settingsRow(
                    icon: "figure.walk",
                    iconColor: targetsIconColor,
                    label: "Activity Level",
                    value: draft.activityLevel,
                    action: { showActivityDialog = true }
                )
                sectionDivider
                settingsRow(
                    icon: "flame.fill",
                    iconColor: targetsIconColor,
                    label: "Daily Calorie Goal",
                    value: "\(draft.calorieGoal) kcal",
                    action: { showCalorieSheet = true }
                )
                sectionDivider
                settingsRow(
                    icon: "chart.pie.fill",
                    iconColor: targetsIconColor,
                    label: "Macro Targets",
                    subtitle: "Protein / Carbs / Fat",
                    value: "150g · 220g · 65g"
                )
                sectionDivider
                settingsRow(
                    icon: "scalemass.fill",
                    iconColor: targetsIconColor,
                    label: "Target Weight",
                    value: "\(draft.targetWeightLbs) lbs",
                    action: { showTargetWeightSheet = true }
                )
            }
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        sectionBlock(label: "DISPLAY") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "ruler",
                    iconColor: displayIconColor,
                    label: "Units",
                    value: units,
                    action: { showUnitsDialog = true }
                )
                sectionDivider
                settingsRow(
                    icon: "moon.fill",
                    iconColor: displayIconColor,
                    label: "Appearance",
                    value: appearance,
                    action: { showAppearanceDialog = true }
                )
                sectionDivider
                settingsRow(
                    icon: "calendar.badge.clock",
                    iconColor: displayIconColor,
                    label: "Week Starts On",
                    value: weekStart,
                    action: { showWeekStartDialog = true }
                )
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        sectionBlock(label: "NOTIFICATIONS") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "fork.knife",
                    iconColor: notificationsIconColor,
                    label: "Meal Reminders",
                    showChevron: false,
                    toggle: $mealReminders
                )
                sectionDivider
                settingsRow(
                    icon: "dumbbell.fill",
                    iconColor: notificationsIconColor,
                    label: "Workout Reminder",
                    showChevron: false,
                    toggle: $workoutReminder
                )
                sectionDivider
                settingsRow(
                    icon: "flame.fill",
                    iconColor: notificationsIconColor,
                    label: "Streak Reminder",
                    showChevron: false,
                    toggle: $streakReminder
                )
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        sectionBlock(label: "ACCOUNT") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "lock.fill",
                    iconColor: accountIconColor,
                    label: "Change Password",
                    action: { /* placeholder */ }
                )
                sectionDivider
                settingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    iconColor: accountIconColor,
                    label: "Log Out",
                    labelColor: .brandOrange,
                    showChevron: false,
                    action: { appState.signOut() }
                )
            }
        }
    }

    // MARK: - Footer

    private var footerText: some View {
        Text("FitnessApp v1.0")
            .font(.system(size: 12))
            .foregroundColor(Color.brandCream.opacity(0.2))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }

    // MARK: - Section Block Helper

    @ViewBuilder
    private func sectionBlock<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.brandLime.opacity(0.55))
                .tracking(1.5)

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandCream.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandCream.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.brandCream.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    // MARK: - Settings Row

    @ViewBuilder
    private func settingsRow(
        icon: String,
        iconColor: Color,
        label: String,
        subtitle: String? = nil,
        value: String? = nil,
        labelColor: Color? = nil,
        showChevron: Bool = true,
        action: (() -> Void)? = nil,
        toggle: Binding<Bool>? = nil
    ) -> some View {
        let rowContent = HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(labelColor ?? .brandCream)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color.brandCream.opacity(0.4))
                }
            }

            Spacer()

            if let value {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundColor(Color.brandCream.opacity(0.4))
            }

            if let toggle {
                Toggle("", isOn: toggle)
                    .labelsHidden()
                    .tint(.brandLime)
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.brandCream.opacity(0.25))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)

        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    // MARK: - Save Changes

    private func saveChanges() {
        guard let userId = appState.currentUser?.id else { return }
        isSaving = true
        saveError = ""

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let update = ProfileUpdate(
            name: draft.name,
            weight_lbs: Double(draft.weightLbs),
            height_in: Double(draft.heightFeet * 12 + draft.heightInches),
            birth_date: formatter.string(from: draft.birthDate),
            gender: draft.gender,
            activity_level: draft.activityLevel,
            primary_goal: draft.primaryGoal,
            calorie_goal: draft.calorieGoal,
            target_weight_lbs: Double(draft.targetWeightLbs),
            custom_calories_enabled: draft.customCaloriesEnabled
        )

        Task {
            do {
                try await ProfileService.shared.updateProfile(userId: userId, update: update)
                if var user = appState.currentUser {
                    user.name = draft.name
                    user.weight = Double(draft.weightLbs)
                    user.height = Double(draft.heightFeet * 12 + draft.heightInches)
                    user.birthDate = draft.birthDate
                    user.gender = draft.gender
                    user.activityLevel = draft.activityLevel
                    user.primaryGoal = draft.primaryGoal
                    user.calorieGoal = draft.calorieGoal
                    user.targetWeightLbs = Double(draft.targetWeightLbs)
                    user.customCaloriesEnabled = draft.customCaloriesEnabled
                    appState.currentUser = user
                }
                hasChanges = false
            } catch {
                saveError = "Failed to save. Please try again."
                print("Settings save error: \(error)")
            }
            isSaving = false
        }
    }
}

// MARK: - Calorie Goal Sheet

private struct CalorieGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var draft: ProfileDraft
    @Binding var hasChanges: Bool

    @State private var tempGoal: Int = 2200

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(Color.brandCream.opacity(0.6))
                    Spacer()
                    Text("Daily Calorie Goal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandCream)
                    Spacer()
                    Button("Save") {
                        draft.calorieGoal = tempGoal
                        hasChanges = true
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.brandLime)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                Text("\(tempGoal)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(.brandLime)
                Text("kcal / day")
                    .font(.system(size: 14))
                    .foregroundColor(Color.brandCream.opacity(0.4))

                HStack(spacing: 32) {
                    Button {
                        if tempGoal > 1200 { tempGoal -= 50 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color.brandCream.opacity(0.3))
                    }

                    Button {
                        if tempGoal < 5000 { tempGoal += 50 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.brandLime)
                    }
                }

                Spacer()
            }
        }
        .onAppear { tempGoal = draft.calorieGoal }
        .presentationDetents([.medium])
    }
}

// MARK: - Target Weight Sheet

private struct TargetWeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var draft: ProfileDraft
    @Binding var hasChanges: Bool

    @State private var tempWeight: Int = 175

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundColor(Color.brandCream.opacity(0.6))
                    Spacer()
                    Text("Target Weight")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandCream)
                    Spacer()
                    Button("Save") {
                        draft.targetWeightLbs = tempWeight
                        hasChanges = true
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.brandLime)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                Text("\(tempWeight)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(.brandLime)
                Text("lbs")
                    .font(.system(size: 14))
                    .foregroundColor(Color.brandCream.opacity(0.4))

                HStack(spacing: 32) {
                    Button {
                        if tempWeight > 80 { tempWeight -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color.brandCream.opacity(0.3))
                    }

                    Button {
                        if tempWeight < 400 { tempWeight += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.brandLime)
                    }
                }

                Spacer()
            }
        }
        .onAppear { tempWeight = draft.targetWeightLbs }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Weight Sheet

private struct EditWeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var draft: ProfileDraft
    @Binding var hasChanges: Bool

    @State private var weightLbs: Int = 150

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                sheetHeader(title: "Weight") {
                    draft.weightLbs = weightLbs
                    hasChanges = true
                    dismiss()
                }

                Spacer()

                HStack {
                    Picker("", selection: $weightLbs) {
                        ForEach(80...500, id: \.self) { lbs in
                            Text("\(lbs)").tag(lbs)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .colorScheme(.dark)

                    Text("lbs")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.brandCream.opacity(0.5))
                        .padding(.trailing, 12)
                }
                .background(Color.brandCream.opacity(0.07))
                .cornerRadius(12)
                .clipped()
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear { weightLbs = draft.weightLbs }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Height Sheet

private struct EditHeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var draft: ProfileDraft
    @Binding var hasChanges: Bool

    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 0

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                sheetHeader(title: "Height") {
                    draft.heightFeet = heightFeet
                    draft.heightInches = heightInches
                    hasChanges = true
                    dismiss()
                }

                Spacer()

                HStack(spacing: 0) {
                    Picker("", selection: $heightFeet) {
                        ForEach(4...7, id: \.self) { ft in
                            Text("\(ft) ft").tag(ft)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .colorScheme(.dark)

                    Picker("", selection: $heightInches) {
                        ForEach(0...11, id: \.self) { inch in
                            Text("\(inch) in").tag(inch)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .colorScheme(.dark)
                }
                .background(Color.brandCream.opacity(0.07))
                .cornerRadius(12)
                .clipped()
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear {
            heightFeet = draft.heightFeet
            heightInches = draft.heightInches
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Date of Birth Sheet

private struct EditDOBSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var draft: ProfileDraft
    @Binding var hasChanges: Bool

    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                sheetHeader(title: "Date of Birth") {
                    draft.birthDate = birthDate
                    hasChanges = true
                    dismiss()
                }

                Spacer()

                DatePicker(
                    "",
                    selection: $birthDate,
                    in: ...Calendar.current.date(byAdding: .year, value: -16, to: Date())!,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 150)
                .clipped()
                .colorScheme(.dark)
                .background(Color.brandCream.opacity(0.07))
                .cornerRadius(12)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear { birthDate = draft.birthDate }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Gender Sheet

private struct EditGenderSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var draft: ProfileDraft
    @Binding var hasChanges: Bool

    @State private var gender: String = "Male"
    private let genders = ["Male", "Female", "Other", "Prefer Not To Say"]

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                sheetHeader(title: "Gender") {
                    draft.gender = gender
                    hasChanges = true
                    dismiss()
                }

                Spacer()

                Picker("", selection: $gender) {
                    ForEach(genders, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .colorScheme(.dark)
                .background(Color.brandCream.opacity(0.07))
                .cornerRadius(12)
                .clipped()
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear { gender = draft.gender }
        .presentationDetents([.medium])
    }
}

// MARK: - Shared Sheet Header

private struct sheetHeader: View {
    let title: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 15))
                .foregroundColor(Color.brandCream.opacity(0.6))
            Spacer()
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.brandCream)
            Spacer()
            Button("Save") { onSave() }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.brandLime)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState())
}
