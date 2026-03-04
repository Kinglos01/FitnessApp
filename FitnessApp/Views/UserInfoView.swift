//  Untitled.swift
//  FitnessApp
//
//  Created by Yohangel Adames on 3/4/26.
//

import SwiftUI

struct UserInfoView: View {

    @Environment(AppState.self) var appState

    @State private var name = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var gender = "Male"
    @State private var savePressed = false
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()

    let genders = ["Male", "Female", "Other", "Prefer Not To Say"]

    var maxBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
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
                        
                        // DatePicker restricted to 16 years ago or earlier
                        DatePicker(
                            "Birth Month & Year",
                            selection: $birthDate,
                            in: ...Calendar.current.date(byAdding: .year, value: -16, to: Date())!,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        // This environment call helps force the pop-up to focus on Month/Year in many locales
                        .environment(\.locale, Locale(identifier: "en_US")) 
                    }

                    Section(header: Text("Body Metrics")) {
                        TextField("Weight (lbs)", text: $weight)
                            .keyboardType(.decimalPad)
                        TextField("Height (inches)", text: $height)
                            .keyboardType(.decimalPad)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { savePressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeInOut(duration: 0.2)) { savePressed = false }
                    }
                    saveUserInfo()
                } label: {
                    Text("Save & Continue")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .padding()
                .background(savePressed ? Color.blue.opacity(0.65) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(savePressed ? 0.96 : 1.0)
                .padding(.horizontal)
                .disabled(name.isEmpty || weight.isEmpty || height.isEmpty)

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private func saveUserInfo() {
        let uid = appState.currentUser?.id ?? UUID().uuidString
        let email = appState.currentUser?.email ?? ""
        
        // Calculate age as an Integer from the selected birthDate
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        let calculatedAge = ageComponents.year ?? 0

        appState.currentUser = User(
            id: uid,
            email: email,
            name: name,
            weight: Double(weight) ?? 0,
            height: Double(height) ?? 0,
            age: calculatedAge,
            gender: gender
        )
    }
}