//
//  WeightTrackerView.swift
//  FitnessApp
//
//  Opens from the weight row inside DashboardView's quickStatsBar.
//  No calendar integration needed.
//
//  Storage : UserDefaults key "weightLog_<userId>"
//  BMI     : (lbs / in²) × 703  — matches UserMetricsCalculator exactly
//  Colors  : systemGray6 cards, orange accents, teal for gain/healthy,
//            red for lose direction, cyan water ring hue in confetti
//
 
import SwiftUI
import Charts
 
// MARK: - Model ─────────────────────────────────────────────────────────────
 
struct WeightEntry: Identifiable, Codable, Equatable {
    var id        : UUID   = UUID()
    var date      : Date
    var weightLbs : Double
 
    var chartLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
 
// MARK: - Motivation state ───────────────────────────────────────────────────
 
enum MotivationKind: Equatable {
    case celebrateLose(delta: Double)
    case celebrateGain(delta: Double)
    case noProgress(delta: Double)
    case dangerLow(bmi: Double, minLbs: Double)
    case dangerHigh(bmi: Double, targetLbs: Double)
    case passedHealthyMin(bmi: Double, minLbs: Double)
}
 
// MARK: - ViewModel ──────────────────────────────────────────────────────────
 
@Observable
final class WeightTrackerViewModel {
 
    // ── persisted ──
    private(set) var entries: [WeightEntry] = []
 
    // ── UI ──
    var inputText      : String          = ""
    var motivationKind : MotivationKind? = nil
    var fireConfetti   : Bool            = false
 
    // ── user ──
    let user: User
 
    // ── derived ──────────────────────────────────
 
    var currentWeight : Double { entries.last?.weightLbs  ?? user.weightLbs }
    var startWeight   : Double { user.weightLbs }
    var totalDelta    : Double { currentWeight - startWeight }
 
    var toGoal: Double {
        guard let t = user.targetWeightLbs else { return 0 }
        return isLoseGoal ? currentWeight - t : t - currentWeight
    }
 
    var isLoseGoal: Bool { user.primaryGoal == "Lose Weight" }
 
    // BMI — (lbs / in²) × 703, identical to UserMetricsCalculator
    var currentBMI: Double {
        guard user.height > 0 else { return 0 }
        return r1((currentWeight / (user.height * user.height)) * 703)
    }
 
    var currentBMICategory: String {
        UserMetricsCalculator.bmiCategory(bmi: currentBMI)
    }
 
    var healthyMinLbs : Double { r1((18.5 / 703) * user.height * user.height) }
    var healthyMaxLbs : Double { r1((24.9 / 703) * user.height * user.height) }
 
    var nextCheckInLabel: String {
        let last = entries.last?.date ?? Date()
        let next = Calendar.current.date(byAdding: .day, value: 14, to: last) ?? Date()
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: next)
    }
 
    var initials: String {
        user.name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined().uppercased()
    }
 
    var heightLabel: String { "\(Int(user.height) / 12)'\(Int(user.height) % 12)\"" }
 
    var userAge: Int {
        Calendar.current.dateComponents([.year], from: user.birthDate, to: Date()).year ?? 0
    }
 
    private var storageKey: String { "weightLog_\(user.id)" }
 
    // ── init ─────────────────────────────────────
 
    init(user: User) {
        self.user = user
        load()
        if entries.isEmpty {
            entries.append(WeightEntry(date: Date(), weightLbs: user.weightLbs))
            save()
        }
    }
 
    // ── log ──────────────────────────────────────
 
    func logWeight() {
        guard let val = Double(inputText), val >= 50, val <= 600 else { return }
 
        let rounded = r1(val)
        let prev    = currentWeight
        let b       = r1((rounded / (user.height * user.height)) * 703)
        let delta   = r1(abs(rounded - prev))
 
        entries.append(WeightEntry(date: Date(), weightLbs: rounded))
        save()
        inputText = ""
        Task { try? await WeightLogService.shared.insertEntry(weightLbs: rounded) }
 
        // Choose motivation
        if rounded < healthyMinLbs - 10 {
            motivationKind = .dangerLow(bmi: b, minLbs: healthyMinLbs)
            fireConfetti   = false
        } else if b >= 35 {
            motivationKind = .dangerHigh(
                bmi: b,
                targetLbs: r1(user.targetWeightLbs ?? healthyMaxLbs)
            )
            fireConfetti = false
        } else if rounded < healthyMinLbs && isLoseGoal {
            motivationKind = .passedHealthyMin(bmi: b, minLbs: healthyMinLbs)
            fireConfetti   = false
        } else {
            let improved = isLoseGoal ? rounded < prev : rounded > prev
            motivationKind = improved
                ? (isLoseGoal ? .celebrateLose(delta: delta) : .celebrateGain(delta: delta))
                : .noProgress(delta: delta)
            if improved {
                fireConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.fireConfetti = false
                }
            } else {
                fireConfetti = false
            }
        }
    }
 
    // ── delete ────────────────────────────────────

    func deleteEntry(_ entry: WeightEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
        Task {
            try? await WeightLogService.shared.deleteEntry(id: entry.id)
        }
    }

    // ── persistence ──────────────────────────────
 
    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
 
    func loadFromRemote() async {
        do {
            let remote = try await WeightLogService.shared.fetchEntries()
            await MainActor.run {
                entries = remote.sorted { $0.date < $1.date }
                save()
            }
        } catch {
            print("Weight log fetch error: \(error)")
        }
    }
 
    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([WeightEntry].self, from: data)
        else { return }
        entries = decoded.sorted { $0.date < $1.date }
    }
 
    // ── helpers ──────────────────────────────────
 
    private func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}
 
// MARK: - Entry point ────────────────────────────────────────────────────────
 
struct WeightTrackerSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
 
    @State private var vm            : WeightTrackerViewModel? = nil
    @State private var confettiCount : Int = 0
 
    var body: some View {
        Group {
            if let vm {
                WeightTrackerContent(vm: vm, confettiCount: $confettiCount)
                    .onChange(of: vm.fireConfetti) { _, fired in
                        if fired { confettiCount += 1 }
                    }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .onAppear {
            if let user = appState.currentUser {
                vm = WeightTrackerViewModel(user: user)
                Task { await vm?.loadFromRemote() }
            }
        }
    }
}
 
// MARK: - Main content ───────────────────────────────────────────────────────
 
private struct WeightTrackerContent: View {
    @Bindable var vm: WeightTrackerViewModel
    @Binding   var confettiCount: Int
    @Environment(\.dismiss) private var dismiss
 
    // line / fill driven by goal direction
    private var lineColor: Color {
        vm.isLoseGoal ? .red : Color(red: 0.25, green: 0.72, blue: 0.55)
    }
    private var fillColor: Color {
        vm.isLoseGoal
            ? .red.opacity(0.07)
            : Color(red: 0.25, green: 0.72, blue: 0.55).opacity(0.09)
    }
 
    var body: some View {
        NavigationView {
            ZStack {
                // Confetti sits above everything
                if confettiCount > 0 {
                    ConfettiView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .zIndex(99)
                }
 
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        userCard
                        nextBadge
                        statsStrip
                        legendRow
                        chartSection
                        bmiSection
                        if vm.motivationKind != nil { motivationSection }
                        inputSection
                        historySection
                        Spacer(minLength: 40)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weight tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
        }
    }
 
    // MARK: User card ─────────────────────────────
 
    private var userCard: some View {
        HStack(spacing: 12) {
            // Lime avatar — same style as Settings / onboarding
            ZStack {
                Circle()
                    .fill(Color(red: 0.86, green: 1.0, blue: 0.53))
                    .frame(width: 48, height: 48)
                Text(vm.initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 0.016, blue: 0.067))
            }
 
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.user.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
 
                Text("\(vm.userAge) y/o · \(vm.heightLabel) · \(vm.user.gender)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
 
                // Goal pill — ↓ red for lose, ↑ teal for gain
                Label(
                    vm.isLoseGoal ? "Goal: lose weight" : "Goal: gain weight",
                    systemImage: vm.isLoseGoal ? "arrow.down" : "arrow.up"
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(lineColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(lineColor.opacity(0.12))
                .clipShape(Capsule())
            }
 
            Spacer()
 
            // Live BMI chip
            VStack(spacing: 2) {
                Text(String(format: "%.1f", vm.currentBMI))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(bmiColor(vm.currentBMI))
                Text("BMI")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
 
    // MARK: Next check-in badge ───────────────────
 
    private var nextBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .semibold))
            Text("Next check-in: \(vm.nextCheckInLabel)")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
 
    // MARK: Stats strip ───────────────────────────
 
    private var statsStrip: some View {
        HStack(spacing: 8) {
            stat("Start",   String(format: "%.1f lb", vm.startWeight),   .primary)
            stat("Current", String(format: "%.1f lb", vm.currentWeight), .primary)
            stat("Change",
                 (vm.totalDelta >= 0 ? "+" : "") + String(format: "%.1f lb", vm.totalDelta),
                 changeColor)
            stat("To goal",
                 vm.toGoal <= 0 ? "Done!" : String(format: "%.1f lb", vm.toGoal),
                 vm.toGoal <= 0 ? Color(red: 0.25, green: 0.72, blue: 0.55) : .orange)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
 
    private var changeColor: Color {
        if abs(vm.totalDelta) < 0.05 { return .secondary }
        let good = vm.isLoseGoal ? vm.totalDelta < 0 : vm.totalDelta > 0
        return good ? Color(red: 0.25, green: 0.72, blue: 0.55) : .red
    }
 
    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(11)
    }
 
    // MARK: Legend ────────────────────────────────
 
    private var legendRow: some View {
        HStack(spacing: 12) {
            legItem(lineColor,            "Weight",        dashed: false)
            legItem(.orange,              "Target",        dashed: true)
            legItem(Color(.systemGray3),  "Healthy range", dashed: true)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
 
    private func legItem(_ c: Color, _ label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            if dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(c).frame(width: 4, height: 2)
                    }
                }.frame(width: 16)
            } else {
                Rectangle().fill(c).frame(width: 16, height: 2.5).cornerRadius(1)
            }
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
 
    // MARK: Chart ─────────────────────────────────
 
    private var chartSection: some View {
        let ws     = vm.entries.map { $0.weightLbs }
        let target = vm.user.targetWeightLbs ?? vm.startWeight
        let yMin   = ([vm.healthyMinLbs, target] + ws).min().map { $0 - 4 } ?? 100
        let yMax   = ([vm.healthyMaxLbs] + ws).max().map { $0 + 4 } ?? 200
 
        return Chart {
            // Healthy range bands
            RuleMark(y: .value("Min", vm.healthyMinLbs))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Color(.systemGray3))
            RuleMark(y: .value("Max", vm.healthyMaxLbs))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Color(.systemGray3))
            // Target
            RuleMark(y: .value("Target", target))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color.orange.opacity(0.7))
            // Area
            ForEach(vm.entries) { e in
                AreaMark(
                    x: .value("Date", e.chartLabel),
                    y: .value("Weight", e.weightLbs)
                )
                .foregroundStyle(fillColor)
                .interpolationMethod(.catmullRom)
            }
            // Line
            ForEach(vm.entries) { e in
                LineMark(
                    x: .value("Date", e.chartLabel),
                    y: .value("Weight", e.weightLbs)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }
            // Points
            ForEach(vm.entries) { e in
                PointMark(
                    x: .value("Date", e.chartLabel),
                    y: .value("Weight", e.weightLbs)
                )
                .foregroundStyle(
                    e.id == vm.entries.last?.id ? lineColor : lineColor.opacity(0.6)
                )
                .symbolSize(e.id == vm.entries.last?.id ? 64 : 28)
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel().font(.system(size: 10)).foregroundStyle(Color.secondary)
                AxisGridLine().foregroundStyle(Color(.systemGray5))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { v in
                AxisValueLabel {
                    if let n = v.as(Double.self) {
                        Text("\(Int(n)) lb")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                }
                AxisGridLine().foregroundStyle(Color(.systemGray5))
            }
        }
        .frame(height: 210)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
 
    // MARK: BMI bar ───────────────────────────────
 
    private var bmiSection: some View {
        let b   = vm.currentBMI
        let pct = min(max((b - 12.0) / 28.0, 0.0), 1.0)
 
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BMI zone")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", b)) · \(vm.currentBMICategory)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(bmiColor(b))
            }
 
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            .blue,
                            Color(red: 0.25, green: 0.72, blue: 0.55),
                            Color(red: 0.25, green: 0.72, blue: 0.55),
                            .orange,
                            .red
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 7)
                    .cornerRadius(4)
 
                    // pointer
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary)
                        .frame(width: 3, height: 15)
                        .offset(x: geo.size.width * CGFloat(pct) - 1.5)
                        .animation(.easeInOut(duration: 0.6), value: pct)
                }
            }
            .frame(height: 15)
 
            HStack {
                Text("Underweight").font(.system(size: 9)).foregroundColor(.blue)
                Spacer()
                Text("Normal").font(.system(size: 9))
                    .foregroundColor(Color(red: 0.25, green: 0.72, blue: 0.55))
                Spacer()
                Text("Overweight").font(.system(size: 9)).foregroundColor(.orange)
                Spacer()
                Text("Obese").font(.system(size: 9)).foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
 
    // MARK: Motivation card ───────────────────────
 
    @ViewBuilder
    private var motivationSection: some View {
        if let kind = vm.motivationKind {
            MotivationCard(kind: kind, isLoseGoal: vm.isLoseGoal)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.4), value: vm.motivationKind != nil)
        }
    }
 
    // MARK: Input ─────────────────────────────────
 
    private var inputSection: some View {
        HStack(spacing: 10) {
            TextField("Log today's weight (lbs)", text: $vm.inputText)
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(11)
                .background(Color(.systemGray6))
                .cornerRadius(11)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
 
            Button(action: vm.logWeight) {
                Text("Log")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(11)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
 
    // MARK: History ───────────────────────────────
 
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Check-in history")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)
 
            VStack(spacing: 5) {
                ForEach(vm.entries.reversed().prefix(8)) { entry in
                    historyRow(entry)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 14)
    }
 
    private func historyRow(_ entry: WeightEntry) -> some View {
        let idx    = vm.entries.firstIndex(where: { $0.id == entry.id }) ?? 0
        let prev   = idx > 0 ? vm.entries[idx - 1].weightLbs : nil as Double?
        let diff   = prev.map { entry.weightLbs - $0 }
        let isFirst = idx == 0
 
        let diffColor: Color = {
            guard let d = diff, abs(d) > 0.05 else { return .secondary }
            return (vm.isLoseGoal ? d < 0 : d > 0)
                ? Color(red: 0.25, green: 0.72, blue: 0.55) : .red
        }()
 
        return HStack {
            Button {
                vm.deleteEntry(entry)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)

            Text(entry.chartLabel)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f lbs", entry.weightLbs))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
            if isFirst {
                Text("start")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 56, alignment: .trailing)
            } else if let d = diff {
                Text((d >= 0 ? "+" : "") + String(format: "%.1f lb", d))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(diffColor)
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
 
    // MARK: BMI color helper ──────────────────────
    // Mirrors UserMetricsCalculator.bmiColor exactly
 
    private func bmiColor(_ b: Double) -> Color {
        switch b {
        case ..<18.5 : return .blue
        case 18.5..<25: return Color(red: 0.25, green: 0.72, blue: 0.55)
        case 25..<30  : return .orange
        default       : return .red
        }
    }
}
 
// MARK: - Motivation card view ───────────────────────────────────────────────
 
private struct MotivationCard: View {
    let kind      : MotivationKind
    let isLoseGoal: Bool
 
    private struct MC {
        var icon: String; var title: String; var body: String
        var badge: String; var accent: Color; var bg: Color
    }
 
    private let loseMsgs: [(String, String, String)] = [
        ("party.popper.fill",  "Woohoo! Down again!",   "Every pound dropped is a win. Consistency is building real results!"),
        ("trophy.fill",        "Another win!",           "You're trending the right way — don't stop now!"),
        ("bolt.fill",          "Crushing the goal!",     "Losing at a healthy pace. Keep fuelling right and moving!"),
        ("figure.run",         "That's real progress!",  "Hard work is paying off. Keep showing up every two weeks!"),
    ]
    private let gainMsgs: [(String, String, String)] = [
        ("dumbbell.fill",                       "Gains incoming!",   "Up in weight — exactly the plan. Keep lifting and fuelling!"),
        ("flame.fill",                          "Building strong!",  "Consistency with nutrition and training is everything. Keep it up!"),
        ("figure.strengthtraining.traditional", "Up we go!",         "Every check-in closer to your target. You're doing great!"),
    ]
 
    private var c: MC {
        let teal = Color(red: 0.25, green: 0.72, blue: 0.55)
        switch kind {
 
        case .celebrateLose(let d):
            let m = loseMsgs[Int.random(in: 0..<loseMsgs.count)]
            return MC(icon: m.0, title: m.1, body: m.2,
                      badge: "▼ \(f1(d)) lb this check-in",
                      accent: .red, bg: .red.opacity(0.07))
 
        case .celebrateGain(let d):
            let m = gainMsgs[Int.random(in: 0..<gainMsgs.count)]
            return MC(icon: m.0, title: m.1, body: m.2,
                      badge: "▲ \(f1(d)) lb this check-in",
                      accent: teal, bg: teal.opacity(0.08))
 
        case .noProgress(let d):
            return MC(
                icon: "chart.bar.fill",
                title: "Logged — stay consistent.",
                body: "Weight \(isLoseGoal ? "went up" : "went down") by \(f1(d)) lbs. Progress isn't always linear — keep your habits strong.",
                badge: "Keep showing up",
                accent: Color(.systemGray2), bg: Color(.systemGray6))
 
        case .dangerLow(let b, let minLbs):
            return MC(
                icon: "exclamationmark.triangle.fill",
                title: "Health concern — weight too low",
                body: "At BMI \(f1(b)) (Underweight) you're below the safe minimum of \(f0(minLbs)) lbs for your height. This can affect bone density, hormones, and immune function. Please speak with your doctor.",
                badge: "BMI \(f1(b)) · Consult a doctor",
                accent: .blue, bg: .blue.opacity(0.08))
 
        case .dangerHigh(let b, let targetLbs):
            return MC(
                icon: "exclamationmark.triangle.fill",
                title: "Health concern — high BMI range",
                body: "BMI \(f1(b)) (Obese) carries elevated cardiovascular risk. Your target of \(f0(targetLbs)) lbs would move you into a much healthier zone. A healthcare provider can help build a safe plan.",
                badge: "BMI \(f1(b)) · Consult a healthcare provider",
                accent: .red, bg: .red.opacity(0.07))
 
        case .passedHealthyMin(let b, let minLbs):
            return MC(
                icon: "hand.raised.fill",
                title: "Passed the healthy minimum",
                body: "At BMI \(f1(b)) you've dropped below the healthy minimum of \(f0(minLbs)) lbs for your height. Consider switching to a maintenance goal to protect your health.",
                badge: "Consider switching to maintenance",
                accent: .orange, bg: .orange.opacity(0.08))
        }
    }
 
    private func f1(_ v: Double) -> String { String(format: "%.1f", v) }
    private func f0(_ v: Double) -> String { String(format: "%.0f", v) }
 
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(c.accent.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: c.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(c.accent)
                }
                Text(c.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            Text(c.body)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
            Text(c.badge)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(c.accent)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(c.accent.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(c.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(c.accent.opacity(0.2), lineWidth: 0.5)
        )
        .cornerRadius(12)
    }
}
 
// MARK: - Confetti ───────────────────────────────────────────────────────────
 
struct ConfettiView: View {
    @State private var pieces: [Piece] = []
 
    struct Piece: Identifiable {
        let id       = UUID()
        var x        : CGFloat
        var y        : CGFloat
        var rotation : Double
        var size     : CGFloat
        var color    : Color
        var isCircle : Bool
    }
 
    // Brand palette + fun extras
    private let colors: [Color] = [
        Color(red: 0.86, green: 1.0, blue: 0.53),   // lime
        .orange,
        Color(red: 0.25, green: 0.72, blue: 0.55),  // teal
        .cyan, .red, .purple, .pink,
        Color(red: 1.0, green: 0.84, blue: 0.14)    // gold
    ]
 
    var body: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(pieces) { p in
                    Group {
                        if p.isCircle {
                            Circle()
                                .fill(p.color)
                                .frame(width: p.size, height: p.size)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(p.color)
                                .frame(width: p.size, height: p.size)
                        }
                    }
                    .position(x: p.x, y: p.y)
                    .rotationEffect(.degrees(p.rotation))
                }
            }
        }
        .onAppear { spawn() }
    }
 
    private func spawn() {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        pieces = (0..<75).map { _ in
            Piece(
                x:        .random(in: 0...w),
                y:        -20,
                rotation: .random(in: 0...360),
                size:     .random(in: 6...13),
                color:    colors.randomElement()!,
                isCircle: Bool.random()
            )
        }
        withAnimation(.linear(duration: 3.5)) {
            for i in pieces.indices {
                pieces[i].y        = h + 40
                pieces[i].rotation += .random(in: 400...1200)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { pieces = [] }
    }
}
 
