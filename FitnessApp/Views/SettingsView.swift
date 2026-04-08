//
//  SettingsView.swift
//  FitnessApp
//

import SwiftUI
import UserNotifications

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
    var units: String
}

// MARK: - SettingsView

struct SettingsView: View {

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    // MARK: Local-only preferences
    @AppStorage("settings_appearance") private var appearance: String = "Dark"
    @AppStorage("settings_week_start") private var weekStart: String = "Sunday"

    @AppStorage("settings_meal_reminders") private var mealReminders: Bool = true
    @AppStorage("settings_workout_reminder") private var workoutReminder: Bool = false
    @AppStorage("settings_streak_reminder") private var streakReminder: Bool = true

    @AppStorage("settings_meal_reminder_hour") private var mealReminderHour: Int = 12
    @AppStorage("settings_workout_reminder_hour") private var workoutReminderHour: Int = 18
    @AppStorage("settings_streak_reminder_hour") private var streakReminderHour: Int = 20

    // MARK: Custom macro overrides
    @AppStorage("useCustomMacros") private var useCustomMacros: Bool = false
    @AppStorage("customProtein") private var customProtein: Int = 150
    @AppStorage("customCarbs") private var customCarbs: Int = 250
    @AppStorage("customFat") private var customFat: Int = 65

    // MARK: Appearance local state
    @State private var appearanceLocal: String = "System"

    // MARK: Draft state
    @State private var draft: ProfileDraft = ProfileDraft(
        name: "",
        weightLbs: 150,
        heightFeet: 5,
        heightInches: 10,
        gender: "Male",
        birthDate: Date(),
        activityLevel: "Moderately Active",
        primaryGoal: "Lose Weight",
        calorieGoal: 2200,
        targetWeightLbs: 175,
        customCaloriesEnabled: false,
        units: "Imperial"
    )

    @State private var isSaving: Bool = false
    @State private var saveError: String = ""
    @State private var hasChanges: Bool = false
    @State private var notificationStatusText: String = "Checking..."

    // MARK: Navigation state
    @State private var showEditWeight: Bool = false
    @State private var showEditHeight: Bool = false
    @State private var showEditDOB: Bool = false
    @State private var showEditGender: Bool = false
    @State private var showGoalDialog: Bool = false
    @State private var showActivityDialog: Bool = false
    @State private var showUnitsDialog: Bool = false
    @State private var showAppearanceDialog: Bool = false
    @State private var showWeekStartDialog: Bool = false
    @State private var showCalorieSheet: Bool = false
    @State private var showTargetWeightSheet: Bool = false
    @State private var showMacroSheet: Bool = false

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

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }

    private func formattedHour(_ hour: Int) -> String {
        let safeHour = min(max(hour, 0), 23)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(bySettingHour: safeHour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    /// Keeping the same BMR idea you already had, just using the draft values.
    private var draftBMR: Double {
        let totalInches = Double(draft.heightFeet * 12 + draft.heightInches)
        let kg = Double(draft.weightLbs) * 0.453592
        let cm = totalInches * 2.54
        let age = Double(Calendar.current.dateComponents([.year], from: draft.birthDate, to: Date()).year ?? 0)

        switch draft.gender.lowercased() {
        case "male":
            return (10 * kg) + (6.25 * cm) - (5 * age) + 5
        case "female":
            return (10 * kg) + (6.25 * cm) - (5 * age) - 161
        default:
            let male = (10 * kg) + (6.25 * cm) - (5 * age) + 5
            let female = (10 * kg) + (6.25 * cm) - (5 * age) - 161
            return (male + female) / 2
        }
    }

    private var draftTDEE: Double {
        UserMetricsCalculator.tdee(bmr: draftBMR, activityLevel: draft.activityLevel)
    }

    private var recommendedCalories: Int {
        UserMetricsCalculator.recommendedCalorieGoal(
            bmr: draftBMR,
            activityLevel: draft.activityLevel,
            primaryGoal: draft.primaryGoal
        )
    }

    private var bodyWeightText: String {
        "\(draft.weightLbs) lbs"
    }

    private var heightText: String {
        formattedHeight(Double(draft.heightFeet * 12 + draft.heightInches))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileCard
                        profileSection
                        targetsSection
                        displaySection
                        notificationsSection
                        accountSection
                        footerText
                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                stickyFooter
            }
        }
        .background(Color.brandNavy.ignoresSafeArea())
        .onAppear {
            loadDraftFromCurrentUser()
            refreshNotificationStatus()
        }
        .onChange(of: mealReminders) { _, _ in
            syncNotificationSettings()
        }
        .onChange(of: workoutReminder) { _, _ in
            syncNotificationSettings()
        }
        .onChange(of: streakReminder) { _, _ in
            syncNotificationSettings()
        }
        .onChange(of: mealReminderHour) { _, _ in
            syncNotificationSettings()
        }
        .onChange(of: workoutReminderHour) { _, _ in
            syncNotificationSettings()
        }
        .onChange(of: streakReminderHour) { _, _ in
            syncNotificationSettings()
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
        .sheet(isPresented: $showMacroSheet) {
            MacroTargetsSheet(
                useCustomMacros: $useCustomMacros,
                customProtein: $customProtein,
                customCarbs: $customCarbs,
                customFat: $customFat,
                draft: draft
            )
        }
        .confirmationDialog("Primary Goal", isPresented: $showGoalDialog) {
            Button("Lose Weight") {
                draft.primaryGoal = "Lose Weight"
                hasChanges = true
            }
            Button("Maintain Weight") {
                draft.primaryGoal = "Maintain Weight"
                hasChanges = true
            }
            Button("Build Muscle") {
                draft.primaryGoal = "Build Muscle"
                hasChanges = true
            }
            Button("Improve Endurance") {
                draft.primaryGoal = "Improve Endurance"
                hasChanges = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Activity Level", isPresented: $showActivityDialog) {
            Button("Sedentary") {
                draft.activityLevel = "Sedentary"
                hasChanges = true
            }
            Button("Lightly Active") {
                draft.activityLevel = "Lightly Active"
                hasChanges = true
            }
            Button("Moderately Active") {
                draft.activityLevel = "Moderately Active"
                hasChanges = true
            }
            Button("Very Active") {
                draft.activityLevel = "Very Active"
                hasChanges = true
            }
            Button("Athlete") {
                draft.activityLevel = "Athlete"
                hasChanges = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Units", isPresented: $showUnitsDialog) {
            Button("Imperial") {
                draft.units = "Imperial"
                hasChanges = true
            }
            Button("Metric") {
                draft.units = "Metric"
                hasChanges = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Appearance", isPresented: $showAppearanceDialog) {
            Button("Dark") { appState.setAppearance("Dark"); appearanceLocal = "Dark" }
            Button("Light") { appState.setAppearance("Light"); appearanceLocal = "Light" }
            Button("System") { appState.setAppearance("System"); appearanceLocal = "System" }
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
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.brandCream)
            }

            Spacer()

            Text("Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.brandCream)

            Spacer()

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
                    value: bodyWeightText,
                    action: { showEditWeight = true }
                )

                sectionDivider

                settingsRow(
                    icon: "ruler.fill",
                    iconColor: profileIconColor,
                    label: "Height",
                    value: heightText,
                    action: { showEditHeight = true }
                )

                sectionDivider

                settingsRow(
                    icon: "calendar",
                    iconColor: profileIconColor,
                    label: "Date of Birth",
                    value: formattedDate(draft.birthDate),
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
                    icon: "bolt.fill",
                    iconColor: targetsIconColor,
                    label: "Your BMR",
                    subtitle: "Basal Metabolic Rate",
                    value: "\(Int(draftBMR.rounded())) kcal",
                    showChevron: false
                )

                sectionDivider

                settingsRow(
                    icon: "chart.bar.fill",
                    iconColor: targetsIconColor,
                    label: "Your TDEE",
                    subtitle: "Total Daily Energy Expenditure",
                    value: "\(Int(draftTDEE.rounded())) kcal",
                    showChevron: false
                )

                sectionDivider

                settingsRow(
                    icon: "sparkles",
                    iconColor: targetsIconColor,
                    label: "Recommended",
                    subtitle: "Based on goal & activity",
                    value: "\(recommendedCalories) kcal",
                    showChevron: false
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
                    subtitle: useCustomMacros ? "Custom" : "Protein / Carbs / Fat",
                    value: macroTargetSummary,
                    action: { showMacroSheet = true }
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

    private var macroTargetSummary: String {
        if useCustomMacros {
            return "\(customProtein)g · \(customCarbs)g · \(customFat)g"
        }

        let macros = UserMetricsCalculator.macroTargets(
            weightLbs: Double(draft.weightLbs),
            calorieGoal: draft.calorieGoal,
            primaryGoal: draft.primaryGoal
        )
        return "\(macros.protein)g · \(macros.carbs)g · \(macros.fat)g"
    }

    // MARK: - Display Section

    private var displaySection: some View {
        sectionBlock(label: "DISPLAY") {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "ruler",
                    iconColor: displayIconColor,
                    label: "Units",
                    value: draft.units,
                    action: { showUnitsDialog = true }
                )

                sectionDivider

                settingsRow(
                    icon: "moon.fill",
                    iconColor: displayIconColor,
                    label: "Appearance",
                    value: appearanceLocal,
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
                    icon: "bell.badge.fill",
                    iconColor: notificationsIconColor,
                    label: "Notification Access",
                    subtitle: notificationStatusText,
                    showChevron: false
                )

                sectionDivider

                settingsRow(
                    icon: "fork.knife",
                    iconColor: notificationsIconColor,
                    label: "Meal Reminders",
                    subtitle: mealReminders ? "Daily at \(formattedHour(mealReminderHour))" : "Off",
                    showChevron: false,
                    toggle: $mealReminders
                )

                if mealReminders {
                    hourStepperRow(title: "Meal Reminder Time", hour: $mealReminderHour)
                }

                sectionDivider

                settingsRow(
                    icon: "dumbbell.fill",
                    iconColor: notificationsIconColor,
                    label: "Workout Reminder",
                    subtitle: workoutReminder ? "Daily at \(formattedHour(workoutReminderHour))" : "Off",
                    showChevron: false,
                    toggle: $workoutReminder
                )

                if workoutReminder {
                    hourStepperRow(title: "Workout Reminder Time", hour: $workoutReminderHour)
                }

                sectionDivider

                settingsRow(
                    icon: "flame.fill",
                    iconColor: notificationsIconColor,
                    label: "Streak Reminder",
                    subtitle: streakReminder ? "Daily at \(formattedHour(streakReminderHour))" : "Off",
                    showChevron: false,
                    toggle: $streakReminder
                )

                if streakReminder {
                    hourStepperRow(title: "Streak Reminder Time", hour: $streakReminderHour)
                }

                sectionDivider

                Button {
                    // Just trying to help the user re-enable reminders fast.
                    syncNotificationSettings(forcePermissionPrompt: true)
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(notificationsIconColor)

                        Text("Refresh Notification Permission")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.brandCream)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
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
                    action: { }
                )

                sectionDivider

                settingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    iconColor: accountIconColor,
                    label: "Log Out",
                    labelColor: .brandOrange,
                    showChevron: false,
                    action: {
                        appState.signOut()
                    }
                )
            }
        }
    }

    // MARK: - Sticky Footer

    private var stickyFooter: some View {
        VStack(spacing: 6) {
            if !saveError.isEmpty {
                Text(saveError)
                    .font(.system(size: 12))
                    .foregroundColor(.brandOrange)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if hasChanges {
                Text("You have unsaved changes")
                    .font(.system(size: 11))
                    .foregroundColor(Color.brandLime.opacity(0.5))
            }

            Button {
                saveChanges()
            } label: {
                ZStack {
                    if isSaving {
                        ProgressView()
                            .tint(Color.brandNavy)
                    } else {
                        HStack(spacing: 8) {
                            if hasChanges {
                                Circle()
                                    .fill(Color.brandNavy)
                                    .frame(width: 7, height: 7)
                            }

                            Text("Save Changes")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(hasChanges ? .brandNavy : Color.brandCream.opacity(0.25))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    hasChanges
                    ? Color.brandLime
                    : Color.brandCream.opacity(0.06)
                )
                .cornerRadius(14)
            }
            .disabled(!hasChanges || isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.brandNavy
                .overlay(
                    Rectangle()
                        .fill(Color.brandCream.opacity(0.06))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }

    // MARK: - Footer

    private var footerText: some View {
        Text("FitnessApp v1.0")
            .font(.system(size: 12))
            .foregroundColor(Color.brandCream.opacity(0.2))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }

    // MARK: - Shared Helpers

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

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.brandCream.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

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

    @ViewBuilder
    private func hourStepperRow(title: String, hour: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color.brandCream.opacity(0.6))

            Spacer()

            Button {
                if hour.wrappedValue > 0 {
                    hour.wrappedValue -= 1
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }

            Text(formattedHour(hour.wrappedValue))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandCream)
                .frame(width: 76)

            Button {
                if hour.wrappedValue < 23 {
                    hour.wrappedValue += 1
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.brandLime)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Data / Notification Logic

    private func loadDraftFromCurrentUser() {
        guard let user = appState.currentUser else { return }

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
        draft.units = user.units
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    notificationStatusText = "Allowed"
                case .denied:
                    notificationStatusText = "Denied in device settings"
                case .notDetermined:
                    notificationStatusText = "Not requested yet"
                @unknown default:
                    notificationStatusText = "Unknown"
                }
            }
        }
    }

    private func syncNotificationSettings(forcePermissionPrompt: Bool = false) {
        Task {
            if forcePermissionPrompt {
                _ = await NotificationManager.shared.requestPermission()
            }
            NotificationManager.shared.syncNotifications(for: appState.currentUser)
            refreshNotificationStatus()
        }
    }

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
            custom_calories_enabled: draft.customCaloriesEnabled,
            units: draft.units
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
                    user.units = draft.units
                    appState.currentUser = user
                }

                hasChanges = false

                // Just making sure reminders stay synced with the latest user/settings info.
                NotificationManager.shared.syncNotifications(for: appState.currentUser)
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

    private var recommended: Int {
        let totalInches = Double(draft.heightFeet * 12 + draft.heightInches)
        let kg = Double(draft.weightLbs) * 0.453592
        let cm = totalInches * 2.54
        let age = Double(Calendar.current.dateComponents([.year], from: draft.birthDate, to: Date()).year ?? 0)

        let bmr: Double
        switch draft.gender.lowercased() {
        case "male":
            bmr = (10 * kg) + (6.25 * cm) - (5 * age) + 5
        case "female":
            bmr = (10 * kg) + (6.25 * cm) - (5 * age) - 161
        default:
            let m = (10 * kg) + (6.25 * cm) - (5 * age) + 5
            let f = (10 * kg) + (6.25 * cm) - (5 * age) - 161
            bmr = (m + f) / 2
        }

        return UserMetricsCalculator.recommendedCalorieGoal(
            bmr: bmr,
            activityLevel: draft.activityLevel,
            primaryGoal: draft.primaryGoal
        )
    }

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

                Button {
                    tempGoal = recommended
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Use Recommended: \(recommended) kcal")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.brandNavy)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.brandLime.opacity(0.85))
                    .cornerRadius(10)
                }

                Spacer()
            }
        }
        .onAppear {
            tempGoal = draft.calorieGoal
        }
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
        .onAppear {
            tempWeight = draft.targetWeightLbs
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Macro Targets Sheet

private struct MacroTargetsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var useCustomMacros: Bool
    @Binding var customProtein: Int
    @Binding var customCarbs: Int
    @Binding var customFat: Int
    let draft: ProfileDraft

    private var autoMacros: (protein: Int, carbs: Int, fat: Int) {
        UserMetricsCalculator.macroTargets(
            weightLbs: Double(draft.weightLbs),
            calorieGoal: draft.calorieGoal,
            primaryGoal: draft.primaryGoal
        )
    }

    private var customTotalCalories: Int {
        (customProtein * 4) + (customCarbs * 4) + (customFat * 9)
    }

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.brandLime)

                    Spacer()

                    Text("Macro Targets")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandCream)

                    Spacer()

                    Text("Done")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                HStack {
                    Text("Use custom macros")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brandCream)

                    Spacer()

                    Toggle("", isOn: $useCustomMacros)
                        .labelsHidden()
                        .tint(.brandLime)
                }
                .padding(.horizontal, 24)

                if useCustomMacros {
                    VStack(spacing: 16) {
                        macroStepper(label: "Protein", value: $customProtein, range: 50...400, step: 5, color: Color(hex: "48ACF0"))
                        macroStepper(label: "Carbs", value: $customCarbs, range: 0...600, step: 10, color: .green)
                        macroStepper(label: "Fat", value: $customFat, range: 20...250, step: 5, color: .orange)

                        HStack {
                            Text("Total")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.brandCream.opacity(0.5))

                            Spacer()

                            Text("\(customTotalCalories) kcal")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.brandLime)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                        if abs(customTotalCalories - draft.calorieGoal) > 100 {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 11))
                                Text("Macro total differs from your \(draft.calorieGoal) kcal goal by \(abs(customTotalCalories - draft.calorieGoal)) kcal")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.brandOrange)
                            .padding(.horizontal, 24)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        macroDisplay(label: "Protein", grams: autoMacros.protein, color: Color(hex: "48ACF0"))
                        macroDisplay(label: "Carbs", grams: autoMacros.carbs, color: .green)
                        macroDisplay(label: "Fat", grams: autoMacros.fat, color: .orange)

                        Text("Auto-calculated from your weight and calorie goal")
                            .font(.system(size: 11))
                            .foregroundColor(Color.brandCream.opacity(0.35))
                            .padding(.top, 4)
                    }
                }

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func macroStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 10, height: 10)
                .overlay(Circle().fill(color).frame(width: 6, height: 6))

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.brandCream)
                .frame(width: 60, alignment: .leading)

            Spacer()

            Button {
                if value.wrappedValue - step >= range.lowerBound {
                    value.wrappedValue -= step
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.brandCream.opacity(0.3))
            }

            Text("\(value.wrappedValue)g")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.brandCream)
                .frame(width: 60, alignment: .center)

            Button {
                if value.wrappedValue + step <= range.upperBound {
                    value.wrappedValue += step
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.brandLime)
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func macroDisplay(label: String, grams: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 10, height: 10)
                .overlay(Circle().fill(color).frame(width: 6, height: 6))

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.brandCream)

            Spacer()

            Text("\(grams)g")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 24)
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
                SheetHeader(title: "Weight") {
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
        .onAppear {
            weightLbs = draft.weightLbs
        }
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
                SheetHeader(title: "Height") {
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

// MARK: - Edit DOB Sheet

private struct EditDOBSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var draft: ProfileDraft
    @Binding var hasChanges: Bool

    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                SheetHeader(title: "Date of Birth") {
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
        .onAppear {
            birthDate = draft.birthDate
        }
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
                SheetHeader(title: "Gender") {
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
        .onAppear {
            gender = draft.gender
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Shared Sheet Header

private struct SheetHeader: View {
    let title: String
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 15))
            .foregroundColor(Color.brandCream.opacity(0.6))

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.brandCream)

            Spacer()

            Button("Save") {
                onSave()
            }
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

