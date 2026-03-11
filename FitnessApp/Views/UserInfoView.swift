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
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        Path { path in
                            let w = geo.size.width + 60
                            let h = geo.size.height
                            path.move(to: CGPoint(x: -30, y: 0))
                            path.addLine(to: CGPoint(x: w, y: 0))
                            path.addLine(to: CGPoint(x: w, y: h * 0.72))
                            path.addLine(to: CGPoint(x: -30, y: h))
                            path.closeSubpath()
                        }
                        .fill(Color.brandLime)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundColor(.brandNavy)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05), value: appeared)

                        Text("Set Up Profile")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.brandNavy)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 8)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.12), value: appeared)

                        Text("We'll use this to personalize your experience")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.brandNavy.opacity(0.6))
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.18), value: appeared)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
                .frame(height: 210)
                .clipped()

                // MARK: - Form
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Name
                        formSection(label: "FULL NAME", delay: 0.22) {
                            ZStack(alignment: .leading) {
                                if name.isEmpty {
                                    Text("Your full name")
                                        .foregroundColor(Color.brandCream.opacity(0.35))
                                        .padding(.horizontal, 16)
                                }
                                TextField("", text: $name)
                                    .foregroundColor(.brandCream)
                                    .padding(.horizontal, 16)
                            }
                            .frame(height: 52)
                            .background(Color.brandCream.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
                            .cornerRadius(12)
                        }

                        // Gender
                        formSection(label: "GENDER", delay: 0.27) {
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
                                                .foregroundColor(gender == option ? .brandNavy : Color.brandCream.opacity(0.6))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    gender == option
                                                        ? Color.brandLime
                                                        : Color.brandCream.opacity(0.07)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(
                                                            gender == option
                                                                ? Color.clear
                                                                : Color.brandCream.opacity(0.18),
                                                            lineWidth: 1
                                                        )
                                                )
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }

                        // Date of Birth
                        formSection(label: "DATE OF BIRTH", delay: 0.32) {
                            DatePicker(
                                "",
                                selection: $birthDate,
                                in: ...Calendar.current.date(byAdding: .year, value: -16, to: Date())!,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 100)
                            .clipped()
                            .colorScheme(.dark)
                            .background(Color.brandCream.opacity(0.07))
                            .cornerRadius(12)
                        }

                        // Weight
                        formSection(label: "WEIGHT", delay: 0.37) {
                            HStack {
                                Picker("", selection: $weightLbs) {
                                    ForEach(80...999, id: \.self) { lbs in
                                        Text("\(lbs)").tag(lbs)
                                            .foregroundColor(.brandCream)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .colorScheme(.dark)

                                Text("lbs")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.brandCream.opacity(0.5))
                                    .padding(.trailing, 12)
                            }
                            .background(Color.brandCream.opacity(0.07))
                            .cornerRadius(12)
                            .clipped()
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
                                .frame(height: 80)
                                .colorScheme(.dark)

                                Picker("", selection: $heightInches) {
                                    ForEach(0...11, id: \.self) { inch in
                                        Text("\(inch) in").tag(inch)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .colorScheme(.dark)
                            }
                            .background(Color.brandCream.opacity(0.07))
                            .cornerRadius(12)
                            .clipped()
                        }

                        // Error
                        if !errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill").font(.caption)
                                Text(errorMessage).font(.caption)
                            }
                            .foregroundColor(.brandOrange)
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
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundColor(.brandNavy)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(height: 54)
                        .background(
                            (name.isEmpty || isSaving)
                                ? Color.brandLime.opacity(0.4)
                                : (savePressed ? Color.brandLime.opacity(0.8) : Color.brandLime)
                        )
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
                .foregroundColor(Color.brandLime.opacity(0.75))
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
            gender: gender
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
                    gender: gender
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