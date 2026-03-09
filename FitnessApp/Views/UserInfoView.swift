//  Untitled.swift
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
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()

    let genders = ["Male", "Female", "Other", "Prefer Not To Say"]

    private var totalHeightInInches: Int {
        heightFeet * 12 + heightInches
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("Tell Us About You")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 40)

                Text("We'll use this to personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Form {
                    Section(header: Text("Personal")) {
                        TextField("Full Name", text: $name)

                        Picker("Gender", selection: $gender) {
                            ForEach(genders, id: \.self) { Text($0) }
                        }
                    }

                    Section(header: Text("Date of Birth")) {
                        DatePicker(
                            "Date of Birth",
                            selection: $birthDate,
                            in: ...Calendar.current.date(byAdding: .year, value: -16, to: Date())!,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 100)
                        .clipped()
                    }

                    Section(header: Text("Weight (lbs)")) {
                        Picker("Weight", selection: $weightLbs) {
                            ForEach(80...999, id: \.self) { lbs in
                                Text("\(lbs) lbs").tag(lbs)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 80)
                        .clipped()
                    }

                    Section(header: Text("Height")) {
                        HStack {
                            Picker("Feet", selection: $heightFeet) {
                                ForEach(3...7, id: \.self) { ft in
                                    Text("\(ft) ft").tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Inches", selection: $heightInches) {
                                ForEach(0...11, id: \.self) { inch in
                                    Text("\(inch) in").tag(inch)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 80)
                        .clipped()
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { savePressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeInOut(duration: 0.2)) { savePressed = false }
                    }
                    saveUserInfo()
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save & Continue")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .padding()
                .background(savePressed ? Color.blue.opacity(0.65) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(savePressed ? 0.96 : 1.0)
                .padding(.horizontal)
                .disabled(name.isEmpty || isSaving)

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private func saveUserInfo() {
        let uid = appState.pendingUserId ?? appState.currentUser?.id ?? UUID().uuidString
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
