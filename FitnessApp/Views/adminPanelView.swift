//
//  adminPanelView.swift
//  FitnessApp
//
//  Created by Carlos Berio on 4/8/26.
//
//


import SwiftUI

// MARK: - Admin User Result

struct AdminUserResult: Identifiable {
    var id: String { profile.id }
    let profile: ProfileResponse
}

// MARK: - Admin Panel View

struct AdminPanelView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var searchEmail: String = ""
    @State private var searchResult: AdminUserResult? = nil
    @State private var isSearching: Bool = false
    @State private var searchError: String = ""
    @State private var selectedUser: AdminUserResult? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerBanner
                        searchSection
                        if let result = searchResult {
                            userResultCard(result)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedUser) { user in
            AdminUserDetailView(profile: user.profile)
                .environment(appState)
        }
    }

    // MARK: - Header

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandLime.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "shield.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.brandLime)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Admin Panel")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brandCream)
                Text("Logged in as \(appState.currentUser?.name ?? "Admin")")
                    .font(.system(size: 12))
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.brandCream.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color.brandLime.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandLime.opacity(0.2), lineWidth: 1))
        .cornerRadius(14)
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FIND USER")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.brandLime.opacity(0.55))
                .tracking(1.5)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.brandCream.opacity(0.4))

                TextField("", text: $searchEmail)
                    .placeholder(when: searchEmail.isEmpty) {
                        Text("Search by email address")
                            .foregroundColor(Color.brandCream.opacity(0.3))
                    }
                    .foregroundColor(.brandCream)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await searchUser() } }

                if !searchEmail.isEmpty {
                    Button { searchEmail = ""; searchResult = nil; searchError = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.brandCream.opacity(0.4))
                    }
                }
            }
            .padding(14)
            .background(Color.brandCream.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
            .cornerRadius(12)

            Button {
                Task { await searchUser() }
            } label: {
                ZStack {
                    if isSearching {
                        ProgressView().tint(.brandNavy)
                    } else {
                        Text("Search")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.brandNavy)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(searchEmail.isEmpty ? Color.brandLime.opacity(0.4) : Color.brandLime)
                .cornerRadius(12)
            }
            .disabled(searchEmail.isEmpty || isSearching)

            if !searchError.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").font(.caption)
                    Text(searchError).font(.caption)
                }
                .foregroundColor(.brandOrange)
            }
        }
    }

    // MARK: - User Result Card

    private func userResultCard(_ result: AdminUserResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RESULT")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.brandLime.opacity(0.55))
                .tracking(1.5)

            Button {
                selectedUser = result
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.brandLime)
                            .frame(width: 44, height: 44)
                        Text(initials(from: result.profile.name ?? "?"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.brandNavy)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.profile.name ?? "Unknown")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.brandCream)
                        Text(result.profile.email ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(Color.brandCream.opacity(0.5))
                        HStack(spacing: 8) {
                            if let weight = result.profile.weight_lbs {
                                Label(String(format: "%.1f lbs", weight), systemImage: "scalemass.fill")
                                    .font(.caption)
                                    .foregroundColor(Color.brandLime.opacity(0.8))
                            }
                            if result.profile.is_admin == true {
                                Label("Admin", systemImage: "shield.fill")
                                    .font(.caption)
                                    .foregroundColor(.brandOrange)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.brandCream.opacity(0.3))
                }
                .padding(14)
                .background(Color.brandCream.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandLime.opacity(0.2), lineWidth: 1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined().uppercased()
    }

    private func searchUser() async {
        let email = searchEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        isSearching = true
        searchError = ""
        searchResult = nil
        do {
            let profile = try await ProfileService.shared.fetchProfileByEmail(email: email)
            await MainActor.run {
                searchResult = AdminUserResult(profile: profile)
            }
        } catch {
            await MainActor.run {
                searchError = "No user found with that email."
            }
        }
        isSearching = false
    }
}

// MARK: - Admin User Detail View

struct AdminUserDetailView: View {
    let profile: ProfileResponse
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var weightHistory: [WeightHistoryEntry] = []
    @State private var workouts: [ActivityEntry] = []
    @State private var dailyLogs: [DailyLogResponse] = []
    @State private var isLoading: Bool = true
    @State private var selectedTab: AdminTab = .weight
    @State private var errorMessage: String = ""

    // Weight editing
    @State private var showAddWeight: Bool = false
    @State private var newWeightText: String = ""
    @State private var newWeightDate: Date = Date()
    @State private var isSavingWeight: Bool = false

    // Daily log editing
    @State private var selectedLog: DailyLogResponse? = nil
    @State private var showEditLog: Bool = false
    @State private var showCreateLog: Bool = false
    @State private var newLogDate: Date = Date()

    // Workout editing
    @State private var showAddWorkout: Bool = false
    @State private var editingWorkout: ActivityEntry? = nil

    enum AdminTab: String, CaseIterable {
        case weight  = "Weight"
        case water   = "Water & Cals"
        case workouts = "Workouts"

        var icon: String {
            switch self {
            case .weight:   return "scalemass.fill"
            case .water:    return "drop.fill"
            case .workouts: return "dumbbell.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.brandLime)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        userHeader
                        tabPicker
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                switch selectedTab {
                                case .weight:   weightSection
                                case .water:    dailyLogSection
                                case .workouts: workoutsSection
                                }
                                Spacer(minLength: 40)
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { Task { await loadAllData() } }
        .sheet(isPresented: $showAddWeight) { addWeightSheet }
        .sheet(isPresented: $showEditLog) {
            if let log = selectedLog {
                AdminEditDailyLogSheet(log: log) { updated in
                    Task { await saveDailyLog(updated) }
                }
            }
        }
        .sheet(isPresented: $showAddWorkout) {
            AdminAddWorkoutSheet(userId: profile.id) { entry in
                Task { await saveWorkout(entry) }
            }
        }
        .sheet(item: $editingWorkout) { workout in
            AdminAddWorkoutSheet(userId: profile.id, existing: workout) { entry in
                Task { await saveWorkout(entry) }
            }
        }
        .sheet(isPresented: $showCreateLog) {
            createLogSheet
        }
    }

    // MARK: - User Header

    private var userHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.brandCream)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name ?? "Unknown User")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.brandCream)
                Text(profile.email ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }
            Spacer()
            if !errorMessage.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.brandOrange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation { selectedTab = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .brandNavy : Color.brandCream.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.brandLime : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.brandCream.opacity(0.06))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Weight Section

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight History")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.brandCream.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
                Button {
                    newWeightText = ""
                    newWeightDate = Date()
                    showAddWeight = true
                } label: {
                    Label("Add Entry", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandLime)
                }
            }

            if weightHistory.isEmpty {
                emptyState(message: "No weight entries found for this user.")
            } else {
                VStack(spacing: 8) {
                    ForEach(weightHistory.reversed()) { entry in
                        AdminWeightRow(
                            entry: entry,
                            onDelete: { Task { await deleteWeightEntry(entry) } }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Daily Log Section

    private var dailyLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Logs")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.brandCream.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
                Button {
                    newLogDate = Date()
                    showCreateLog = true
                } label: {
                    Label("Add Day", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandLime)
                }
            }

            if dailyLogs.isEmpty {
                emptyState(message: "No daily logs found. Tap Add Day to create one.")
            } else {
                VStack(spacing: 8) {
                    ForEach(dailyLogs.sorted { $0.date > $1.date }) { log in
                        AdminDailyLogRow(log: log) {
                            selectedLog = log
                            showEditLog = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Workouts Section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workouts")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.brandCream.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
                Button {
                    showAddWorkout = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandLime)
                }
            }

            if workouts.isEmpty {
                emptyState(message: "No workouts found for this user.")
            } else {
                VStack(spacing: 8) {
                    ForEach(workouts.sorted { $0.date > $1.date }) { workout in
                        AdminWorkoutRow(
                            workout: workout,
                            onEdit: { editingWorkout = workout },
                            onDelete: { Task { await deleteWorkout(workout) } }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Add Weight Sheet

    private var addWeightSheet: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button("Cancel") { showAddWeight = false }
                        .foregroundColor(Color.brandCream.opacity(0.6))
                    Spacer()
                    Text("Add Weight Entry")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandCream)
                    Spacer()
                    Button("Save") { Task { await addWeightEntry() } }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.brandLime)
                        .disabled(isSavingWeight)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (lbs)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.brandLime.opacity(0.75))
                            .tracking(1.2)
                        TextField("e.g. 185.5", text: $newWeightText)
                            .keyboardType(.decimalPad)
                            .foregroundColor(.brandCream)
                            .padding(14)
                            .background(Color.brandCream.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.brandLime.opacity(0.75))
                            .tracking(1.2)
                        DatePicker("", selection: $newWeightDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(height: 120)
                            .clipped()
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Empty State

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundColor(Color.brandCream.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.brandCream.opacity(0.04))
            .cornerRadius(12)
    }

    // MARK: - Data Loading

    private func loadAllData() async {
        isLoading = true
        async let wh  = ProfileService.shared.fetchWeightHistory(userId: profile.id)
        async let wks = WorkoutService.shared.fetchWorkouts(userId: profile.id)
        async let dl  = DailyLogService.shared.fetchLogs(
            userId: profile.id,
            from: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(),
            to: Date()
        )
        weightHistory = (try? await wh)  ?? []
        workouts      = (try? await wks) ?? []
        dailyLogs     = (try? await dl)  ?? []
        isLoading = false
    }

    // MARK: - Weight Actions

    private func addWeightEntry() async {
        guard let value = Double(newWeightText), value > 0 else { return }
        isSavingWeight = true
        var updated = weightHistory
        updated.append(WeightHistoryEntry(date: newWeightDate, weight_lbs: value))
        updated.sort { $0.date < $1.date }
        do {
            try await ProfileService.shared.updateWeightHistory(userId: profile.id, history: updated)
            await MainActor.run {
                weightHistory = updated
                showAddWeight = false
            }
        } catch {
            await MainActor.run { errorMessage = "Failed to save weight entry." }
        }
        isSavingWeight = false
    }

    private func deleteWeightEntry(_ entry: WeightHistoryEntry) async {
        var updated = weightHistory.filter { $0.id != entry.id }
        updated.sort { $0.date < $1.date }
        do {
            try await ProfileService.shared.updateWeightHistory(userId: profile.id, history: updated)
            await MainActor.run { weightHistory = updated }
        } catch {
            await MainActor.run { errorMessage = "Failed to delete weight entry." }
        }
    }

    // MARK: - Daily Log Actions

    private func saveDailyLog(_ log: DailyLogResponse) async {
        do {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let date = f.date(from: log.date) ?? Date()
            try await DailyLogService.shared.upsertLog(
                userId: profile.id,
                date: date,
                waterConsumed: log.water_consumed,
                waterGoal: log.water_goal,
                caloriesEaten: log.calories_eaten,
                caloriesBurned: log.calories_burned,
                workoutsCompleted: log.workouts_completed
            )
            await MainActor.run {
                if let idx = dailyLogs.firstIndex(where: { $0.date == log.date }) {
                    dailyLogs[idx] = log
                }
                showEditLog = false
            }
        } catch {
            await MainActor.run { errorMessage = "Failed to save daily log." }
        }
    }

    // MARK: - Workout Actions

    private func saveWorkout(_ entry: ActivityEntry) async {
        do {
            try await WorkoutService.shared.upsertWorkout(entry, userId: profile.id)
            await MainActor.run {
                if let idx = workouts.firstIndex(where: { $0.id == entry.id }) {
                    workouts[idx] = entry
                } else {
                    workouts.append(entry)
                }
                showAddWorkout = false
                editingWorkout = nil
            }
        } catch {
            await MainActor.run { errorMessage = "Failed to save workout." }
        }
    }

    private func deleteWorkout(_ entry: ActivityEntry) async {
        do {
            try await WorkoutService.shared.deleteWorkout(id: entry.id)
            await MainActor.run { workouts.removeAll { $0.id == entry.id } }
        } catch {
            await MainActor.run { errorMessage = "Failed to delete workout." }
        }
    }
    
    private var createLogSheet: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button("Cancel") { showCreateLog = false }
                        .foregroundColor(Color.brandCream.opacity(0.6))
                    Spacer()
                    Text("Create Daily Log")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandCream)
                    Spacer()
                    Button("Create") { Task { await createBlankLog() } }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.brandLime)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Text("Select a date to create a blank log you can then edit.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.brandCream.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                DatePicker("", selection: $newLogDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(height: 150).clipped()

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    private func createBlankLog() async {
        do {
            try await DailyLogService.shared.upsertLog(
                userId: profile.id,
                date: newLogDate,
                waterConsumed: 0,
                waterGoal: 8,
                caloriesEaten: 0,
                caloriesBurned: 0,
                workoutsCompleted: 0
            )
            if let log = try? await DailyLogService.shared.fetchLog(userId: profile.id, date: newLogDate) {
                await MainActor.run {
                    if !dailyLogs.contains(where: { $0.date == log.date }) {
                        dailyLogs.append(log)
                    }
                    showCreateLog = false
                }
            }
        } catch {
            await MainActor.run { errorMessage = "Failed to create log." }
        }
    }
}

// MARK: - Row Components

struct AdminWeightRow: View {
    let entry: WeightHistoryEntry
    let onDelete: () -> Void

    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: entry.date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "%.1f lbs", entry.weight_lbs))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
                Text(dateLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Color.brandCream.opacity(0.4))
            }
            Spacer()
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.brandOrange.opacity(0.7))
            }
        }
        .padding(12)
        .background(Color.brandCream.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.08), lineWidth: 0.5))
        .cornerRadius(10)
    }
}

struct AdminDailyLogRow: View {
    let log: DailyLogResponse
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.date)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.brandCream)
                    HStack(spacing: 10) {
                        Label("\(log.water_consumed)/\(log.water_goal)", systemImage: "drop.fill")
                            .font(.caption).foregroundColor(.cyan)
                        Label("\(Int(log.calories_eaten)) kcal", systemImage: "fork.knife")
                            .font(.caption).foregroundColor(.orange)
                        Label("\(log.calories_burned) burned", systemImage: "flame.fill")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                Spacer()
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(Color.brandLime.opacity(0.6))
            }
            .padding(12)
            .background(Color.brandCream.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.08), lineWidth: 0.5))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct AdminWorkoutRow: View {
    let workout: ActivityEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: workout.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(workout.category.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: workout.category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(workout.category.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.brandCream)
                HStack(spacing: 8) {
                    Text(dateLabel).font(.caption).foregroundColor(Color.brandCream.opacity(0.4))
                    if workout.isCompleted {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundColor(.green)
                    }
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Button { onEdit() } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(Color.brandLime.opacity(0.7))
                }
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.brandOrange.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(Color.brandCream.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.08), lineWidth: 0.5))
        .cornerRadius(10)
    }
}

// MARK: - Admin Edit Daily Log Sheet

struct AdminEditDailyLogSheet: View {
    let log: DailyLogResponse
    let onSave: (DailyLogResponse) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var waterConsumed: Int
    @State private var waterGoal: Int
    @State private var caloriesEaten: Double
    @State private var caloriesBurned: Int
    @State private var workoutsCompleted: Int

    init(log: DailyLogResponse, onSave: @escaping (DailyLogResponse) -> Void) {
        self.log    = log
        self.onSave = onSave
        _waterConsumed    = State(initialValue: log.water_consumed)
        _waterGoal        = State(initialValue: log.water_goal)
        _caloriesEaten    = State(initialValue: log.calories_eaten)
        _caloriesBurned   = State(initialValue: log.calories_burned)
        _workoutsCompleted = State(initialValue: log.workouts_completed)
    }

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.brandCream.opacity(0.6))
                    Spacer()
                    Text(log.date)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandCream)
                    Spacer()
                    Button("Save") {
                        var updated = log
                        updated.water_consumed     = waterConsumed
                        updated.water_goal         = waterGoal
                        updated.calories_eaten     = caloriesEaten
                        updated.calories_burned    = caloriesBurned
                        updated.workouts_completed = workoutsCompleted
                        onSave(updated)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.brandLime)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 16) {
                        adminStepper(label: "Water Consumed", value: $waterConsumed, range: 0...30, unit: "glasses")
                        adminStepper(label: "Water Goal",     value: $waterGoal,     range: 1...30, unit: "glasses")
                        adminDoubleStepper(label: "Calories Eaten",  value: $caloriesEaten,  step: 50, unit: "kcal")
                        adminStepper(label: "Calories Burned", value: $caloriesBurned, range: 0...5000, unit: "kcal", step: 50)
                        adminStepper(label: "Workouts Completed", value: $workoutsCompleted, range: 0...20, unit: "workouts")
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func adminStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, step: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.brandLime.opacity(0.6))
                .tracking(1.2)
            HStack {
                Button {
                    if value.wrappedValue - step >= range.lowerBound { value.wrappedValue -= step }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.brandCream.opacity(0.3))
                }
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
                Spacer()
                Button {
                    if value.wrappedValue + step <= range.upperBound { value.wrappedValue += step }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.brandLime)
                }
            }
            .padding(12)
            .background(Color.brandCream.opacity(0.06))
            .cornerRadius(12)
        }
    }

    private func adminDoubleStepper(label: String, value: Binding<Double>, step: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.brandLime.opacity(0.6))
                .tracking(1.2)
            HStack {
                Button {
                    if value.wrappedValue - step >= 0 { value.wrappedValue -= step }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.brandCream.opacity(0.3))
                }
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
                Spacer()
                Button {
                    value.wrappedValue += step
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.brandLime)
                }
            }
            .padding(12)
            .background(Color.brandCream.opacity(0.06))
            .cornerRadius(12)
        }
    }
}

// MARK: - Admin Add Workout Sheet

struct AdminAddWorkoutSheet: View {
    let userId: String
    var existing: ActivityEntry? = nil
    let onSave: (ActivityEntry) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var category: ExerciseCategory = .strength
    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var weight: String = ""
    @State private var duration: String = ""
    @State private var calories: String = ""
    @State private var notes: String = ""
    @State private var date: Date = Date()
    @State private var isCompleted: Bool = false
    
    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.brandCream.opacity(0.6))
                    Spacer()
                    Text(existing == nil ? "Add Workout" : "Edit Workout")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandCream)
                    Spacer()
                    Button("Save") { save() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.brandLime)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Date picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.brandLime.opacity(0.6))
                                .tracking(1.2)
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(height: 100).clipped()
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.brandLime.opacity(0.6))
                                .tracking(1.2)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                                        Button { category = cat } label: {
                                            Text(cat.rawValue)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(category == cat ? .brandNavy : cat.color)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(Capsule().fill(category == cat ? cat.color : cat.color.opacity(0.12)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // Name
                        adminTextField(label: "WORKOUT NAME", text: $name, placeholder: "e.g. Bench Press")
                        
                        // Stats
                        if category.usesDuration {
                            adminTextField(label: "DURATION (mins)", text: $duration, placeholder: "e.g. 30", keyboard: .numberPad)
                        } else {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SETS").font(.system(size: 10, weight: .bold)).foregroundColor(Color.brandLime.opacity(0.6)).tracking(1.2)
                                    Stepper("\(sets)", value: $sets, in: 1...20)
                                        .foregroundColor(.brandCream).colorScheme(.dark)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("REPS").font(.system(size: 10, weight: .bold)).foregroundColor(Color.brandLime.opacity(0.6)).tracking(1.2)
                                    Stepper("\(reps)", value: $reps, in: 1...100)
                                        .foregroundColor(.brandCream).colorScheme(.dark)
                                }
                            }
                        }
                        
                        adminTextField(label: "CALORIES BURNED", text: $calories, placeholder: "e.g. 300", keyboard: .numberPad)
                        adminTextField(label: "NOTES", text: $notes, placeholder: "Optional")
                        
                        // Completed toggle
                        HStack {
                            Text("MARK AS COMPLETED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.brandLime.opacity(0.6))
                                .tracking(1.2)
                            Spacer()
                            Toggle("", isOn: $isCompleted)
                                .tint(.brandLime)
                                .labelsHidden()
                        }
                    }
                    .padding(20)
                }
            }
        }
        .onAppear { populate() }
    }
    
    private func adminTextField(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.brandLime.opacity(0.6))
                .tracking(1.2)
            TextField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder).foregroundColor(Color.brandCream.opacity(0.3))
                }
                .foregroundColor(.brandCream)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.brandCream.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
                .cornerRadius(10)
        }
    }
    
    private func populate() {
        guard let e = existing else { return }
        name      = e.name
        category  = e.category
        sets      = e.sets
        reps      = e.reps
        weight    = e.weight.map { String(Int($0)) } ?? ""
        duration  = e.duration.map { String($0) } ?? ""
        calories  = String(e.caloriesBurned)
        notes     = e.notes
        date      = e.date
        isCompleted = e.isCompleted
    }
    
    private func save() {
        let entry = ActivityEntry(
            id:             existing?.id ?? UUID(),
            name:           name.trimmingCharacters(in: .whitespacesAndNewlines),
            category:       category,
            sets:           category.usesDuration ? 0 : sets,
            reps:           category.usesDuration ? 0 : reps,
            weight:         category.usesDuration ? nil : Double(weight),
            duration:       category.usesDuration ? Int(duration) : nil,
            caloriesBurned: Int(calories) ?? 0,
            notes:          notes,
            date:           date,
            completedDates: isCompleted ? (existing?.completedDates ?? [date]) : (existing?.completedDates ?? [])
        )
        onSave(entry)
        dismiss()
    }
}
