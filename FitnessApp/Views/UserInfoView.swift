//
//  UserInfoView.swift
//  FitnessApp
//
//  Created by Yohangel Adames on 3/4/26.
//

import SwiftUI

struct UserInfoView: View {

    @Environment(AppState.self) var appState

    @State private var name = ""
    @State private var weightLbs = 150
    @State private var heightFeet = 5
    @State private var heightInches = 0
    @State private var gender = "Male"
    @State private var savePressed = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var appeared = false
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()

    let genders = ["Male", "Female", "Other", "Prefer Not To Say"]

    private var totalHeightInInches: Int { heightFeet * 12 + heightInches }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                // .ignoresSafeArea(edges: .top) on the gradient covers the Dynamic Island gap
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [Color.brandLimeDark, Color.brandLime],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .top)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Set Up Profile")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.brandNavy)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.06), value: appeared)

                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.brandNavy)
                            Text("We'll use this to personalize your experience")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.brandNavy.opacity(0.65))
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.12), value: appeared)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                .frame(height: 160)

                // MARK: - Form
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Name
                        formSection(label: "FULL NAME", delay: 0.22) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Full Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ZStack(alignment: .leading) {
                                    if name.isEmpty {
                                        Text("Your full name")
                                            .foregroundColor(Color(.placeholderText))
                                            .padding(.horizontal, 14)
                                    }
                                    TextField("", text: $name)
                                        .foregroundColor(.primary)
                                        .textInputAutocapitalization(.words)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                }
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }

                        // Gender
                        formSection(label: "GENDER", delay: 0.27) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Gender")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(genders, id: \.self) { option in
                                            Button {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    gender = option
                                                }
                                            } label: {
                                                Text(option)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(gender == option ? .brandNavy : .primary)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        Capsule()
                                                            .fill(gender == option ? Color.brandLime : Color(.systemBackground))
                                                    )
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(
                                                                gender == option ? Color.clear : Color(.systemGray4),
                                                                lineWidth: 1
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }

                        // Date of Birth
                        formSection(label: "DATE OF BIRTH", delay: 0.32) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Date of Birth")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                DatePicker(
                                    "",
                                    selection: $birthDate,
                                    in: ...Calendar.current.date(byAdding: .year, value: -16, to: Date())!,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(height: 120)
                                .clipped()
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }

                        // Weight
                        formSection(label: "WEIGHT", delay: 0.37) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(alignment: .center) {
                                    Picker("", selection: $weightLbs) {
                                        ForEach(80...999, id: \.self) { lbs in
                                            Text("\(lbs)").tag(lbs)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)

                                    Text("lbs")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.trailing, 6)
                                }
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }

                        // Height
                        formSection(label: "HEIGHT", delay: 0.42) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Height")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 0) {
                                    Picker("", selection: $heightFeet) {
                                        ForEach(3...7, id: \.self) { ft in
                                            Text("\(ft) ft").tag(ft)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)

                                    Picker("", selection: $heightInches) {
                                        ForEach(0...11, id: \.self) { inch in
                                            Text("\(inch) in").tag(inch)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                }
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }

                        // Error
                        if !errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill").font(.caption)
                                Text(errorMessage).font(.caption)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Save Button
                        Button {
                            withAnimation(.easeInOut(duration: 0.1)) { savePressed = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.15)) { savePressed = false }
                            }
                            saveUserInfo()
                        } label: {
                            ZStack {
                                if isSaving {
                                    ProgressView().tint(.brandNavy)
                                } else {
                                    Text("Save & Continue")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.brandNavy)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(height: 56)
                        .background(
                            name.isEmpty || isSaving
                                ? Color.brandLime.opacity(0.45)
                                : Color.brandLime
                        )
                        .shadow(color: Color.brandLime.opacity(name.isEmpty ? 0 : 0.4), radius: 10, x: 0, y: 6)
                        .cornerRadius(14)
                        .scaleEffect(savePressed ? 0.97 : 1.0)
                        .animation(.easeInOut(duration: 0.12), value: savePressed)
                        .disabled(name.isEmpty || isSaving)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.48), value: appeared)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
        }
    }

    // MARK: - Section Builder
    @ViewBuilder
    private func formSection<Content: View>(label: String, delay: Double, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(1.2)
            content()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay), value: appeared)
    }

    // MARK: - Save
    private func saveUserInfo() {
        guard let uid = appState.pendingUserId ?? appState.currentUser?.id else {
            errorMessage = "Session error. Please log in again."
            return
        }
        let email = appState.pendingEmail ?? appState.currentUser?.email ?? ""

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let profileUpdate = ProfileUpdate(
            name: name,
            weight_lbs: Double(weightLbs),
            height_in: Double(totalHeightInInches),
            birth_date: formatter.string(from: birthDate),
            gender: gender,
            activity_level: "Moderately Active",
            primary_goal: "Lose Weight",
            calorie_goal: 2200,
            target_weight_lbs: nil,
            custom_calories_enabled: false,
            units: "Imperial"
        )

        isSaving = true
        errorMessage = ""

        Task {
            do {
                try await ProfileService.shared.updateProfile(userId: uid, update: profileUpdate)
                let user = User(
                    id: uid,
                    email: email,
                    name: name,
                    weight: Double(weightLbs),
                    height: Double(totalHeightInInches),
                    birthDate: birthDate,
                    gender: gender,
                    activityLevel: "Moderately Active",
                    primaryGoal: "Lose Weight",
                    calorieGoal: 2200,
                    targetWeightLbs: nil,
                    customCaloriesEnabled: false
                )
                appState.completeOnboarding(user: user)
            } catch {
                errorMessage = "Failed to save profile. Please try again."
                print("Supabase profile update error: \(error)")
            }
            isSaving = false
        }
    }
}

#Preview {
    UserInfoView()
        .environment(AppState())
}
