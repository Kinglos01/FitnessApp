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
    @State private var isGenderDropdownOpen = false
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
    
    let genders = ["Male", "Female", "Other", "Prefer Not To Say"]
    
    private var totalHeightInInches: Int {
        heightFeet * 12 + heightInches
    }
    
    private var latestAllowedBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
    }
    
    private let pickerFieldHeight: CGFloat = 100
    private let textFieldHeight: CGFloat = 58
    
    private var genderDropdownHeight: CGFloat {
        CGFloat(genders.count * 44) + CGFloat(max(genders.count - 1, 0) * 6) + 16
    }
    
    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.brandLime)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05), value: appeared)

                        Text("Set Up Profile")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.brandCream)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: appeared)
                    }

                    Text("We'll use this to personalize your experience")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.brandCream.opacity(0.55))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.16), value: appeared)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 16)

                // MARK: - Form
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {

                        // Name
                        formSection(label: "FULL NAME", delay: 0.22) {
                            ZStack(alignment: .leading) {
                                if name.isEmpty {
                                    Text("Your full name")
                                        .foregroundColor(Color.brandCream.opacity(0.35))
                                        .padding(.horizontal, 16)
                                }

                                TextField("", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(true)
                                    .foregroundColor(.brandCream)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 16)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: textFieldHeight)
                            .background(Color.brandCream.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.brandCream.opacity(0.16), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Gender
                        formSection(label: "GENDER", delay: 0.27) {
                            VStack(spacing: 8) {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                        isGenderDropdownOpen.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text(gender)
                                            .font(.system(size: 16, weight: .semibold, design: .default))
                                            .foregroundColor(.brandCream)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.brandCream.opacity(0.55))
                                            .rotationEffect(.degrees(isGenderDropdownOpen ? 180 : 0))
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: textFieldHeight)
                                    .background(Color.brandCream.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.brandCream.opacity(0.16), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)

                                VStack(spacing: 6) {
                                    ForEach(genders, id: \.self) { option in
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                                gender = option
                                                isGenderDropdownOpen = false
                                            }
                                        } label: {
                                            HStack {
                                                Text(option)
                                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                                    .foregroundColor(gender == option ? .brandNavy : .brandCream)

                                                Spacer()

                                                if gender == option {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 13, weight: .black))
                                                        .foregroundColor(.brandNavy)
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .frame(height: 44)
                                            .background(
                                                gender == option
                                                ? Color.brandLime
                                                : Color.brandCream.opacity(0.06)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(8)
                                .background(Color.brandCream.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.brandCream.opacity(0.16), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .scaleEffect(x: 1, y: isGenderDropdownOpen ? 1 : 0.92, anchor: .top)
                                .frame(height: isGenderDropdownOpen ? genderDropdownHeight : 0, alignment: .top)
                                .clipped()
                                .allowsHitTesting(isGenderDropdownOpen)
                                .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isGenderDropdownOpen)
                            }
                        }

                        // Date of Birth
                        formSection(label: "DATE OF BIRTH", delay: 0.32) {
                            ZStack {
                                DatePicker(
                                    "",
                                    selection: $birthDate,
                                    in: ...latestAllowedBirthDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .frame(height: pickerFieldHeight)
                                .colorScheme(.dark)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: pickerFieldHeight)
                            .background(Color.brandCream.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.brandCream.opacity(0.16), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Weight
                        formSection(label: "WEIGHT", delay: 0.37) {
                            HStack(spacing: 0) {
                                Picker("", selection: $weightLbs) {
                                    ForEach(80...999, id: \.self) { lbs in
                                        Text("\(lbs)")
                                            .tag(lbs)
                                            .foregroundColor(.brandCream)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .frame(height: pickerFieldHeight)
                                .colorScheme(.dark)

                                Text("lbs")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.brandCream.opacity(0.6))
                                    .padding(.trailing, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: pickerFieldHeight)
                            .background(Color.brandCream.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.brandCream.opacity(0.16), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Height
                        formSection(label: "HEIGHT", delay: 0.42) {
                            HStack(spacing: 0) {
                                Picker("", selection: $heightFeet) {
                                    ForEach(3...7, id: \.self) { ft in
                                        Text("\(ft) ft").tag(ft)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .frame(height: pickerFieldHeight)
                                .colorScheme(.dark)

                                Divider()
                                    .frame(width: 1)
                                    .background(Color.brandCream.opacity(0.12))

                                Picker("", selection: $heightInches) {
                                    ForEach(0...11, id: \.self) { inch in
                                        Text("\(inch) in").tag(inch)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .frame(height: pickerFieldHeight)
                                .colorScheme(.dark)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: pickerFieldHeight)
                            .background(Color.brandCream.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.brandCream.opacity(0.16), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Error
                        if !errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)

                                Text(errorMessage)
                                    .font(.caption)
                            }
                            .foregroundColor(.brandOrange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Save Button
                        Button {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                savePressed = true
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    savePressed = false
                                }
                            }

                            saveUserInfo()
                        } label: {
                            ZStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.brandNavy)
                                } else {
                                    Text("Save & Continue")
                                        .font(.system(size: 16, weight: .black, design: .default))
                                        .foregroundColor(.brandNavy)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(height: 54)
                        .background(
                            (name.isEmpty || isSaving)
                            ? Color.brandLime.opacity(0.4)
                            : (savePressed ? Color.brandLime.opacity(0.85) : Color.brandLime)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .scaleEffect(savePressed ? 0.97 : 1.0)
                        .animation(.easeInOut(duration: 0.12), value: savePressed)
                        .disabled(name.isEmpty || isSaving)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.48), value: appeared)

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
    }
    
    // MARK: - Section Builder
    @ViewBuilder
    private func formSection<Content: View>(
        label: String,
        delay: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color.brandLime)
                .tracking(1.2)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        
        let initialEntry = WeightHistoryEntry(
            date: Date(),
            weight_lbs: Double(weightLbs)
        )
        
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
            units: "Imperial",
            weight_history: [initialEntry]
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
