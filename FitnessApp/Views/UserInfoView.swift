//  Untitled.swift
//  FitnessApp
//
//  Created by Yohangel Adames on 3/4/26.
//

import SwiftUI

struct UserInfoView: View {

    @Environment(AppState.self) var appState

    @State private var name = ""

    // Wheel picker state
    @State private var heightFeet = 5
    @State private var heightInches = 8
    @State private var birthMonth = 1
    @State private var birthYear = Calendar.current.component(.year, from: Date()) - 25
    @State private var weightLbs = 170
    
    @State private var gender = "Male"
    @State private var savePressed = false
    @State private var showValidationErrors = false

    let genders = ["Male", "Female", "Other"]
    private var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Please enter your full name.")
        }
        return errors
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

                if showValidationErrors && !validationErrors.isEmpty {
                    Text("Please complete all required fields.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }

                Form {
                    Section(header: Text("Personal")) {
                        TextField("Full Name", text: $name)
                        Picker("Gender", selection: $gender) {
                            ForEach(genders, id: \.self) { Text($0) }
                        }
                        // Date of Birth (Month / Year)
                        HStack {
                            Text("Birth Month")
                            Spacer()
                            Picker("Birth Month", selection: $birthMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 100)
                            .clipped()
                        }
                        HStack {
                            Text("Birth Year")
                            Spacer()
                            Picker("Birth Year", selection: $birthYear) {
                                let current = Calendar.current.component(.year, from: Date())
                                ForEach((1900...current).reversed(), id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 120, height: 100)
                            .clipped()
                        }
                    }

                    Section(header: Text("Body Metrics")) {
                        // Height (ft / in)
                        HStack {
                            Text("Height")
                            Spacer()
                            Picker("Feet", selection: $heightFeet) {
                                ForEach(3...7, id: \.self) { ft in
                                    Text("\(ft) ft").tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 90, height: 100)
                            .clipped()
                            Picker("Inches", selection: $heightInches) {
                                ForEach(0...11, id: \.self) { inch in
                                    Text("\(inch) in").tag(inch)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 90, height: 100)
                            .clipped()
                        }
                        // Weight (lbs)
                        HStack {
                            Text("Weight")
                            Spacer()
                            Picker("Weight (lbs)", selection: $weightLbs) {
                                ForEach(60...400, id: \.self) { w in
                                    Text("\(w) lb").tag(w)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 140, height: 100)
                            .clipped()
                        }
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
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: savePressed)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(savePressed ? 0.1 : 0.2), radius: savePressed ? 2 : 6, y: savePressed ? 1 : 4)
                .scaleEffect(savePressed ? 0.96 : 1.0)
                .sensoryFeedback(.impact, trigger: savePressed)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: savePressed)
                .padding(.horizontal)
                .disabled(false)

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private func saveUserInfo() {
        showValidationErrors = true
        guard validationErrors.isEmpty else { return }

        let uid = appState.currentUser?.id ?? UUID().uuidString
        let email = appState.currentUser?.email ?? ""

        // Compute derived values
        let totalInches = (heightFeet * 12) + heightInches
        let heightInchesDouble = Double(totalInches)
        let weightDouble = Double(weightLbs)

        // Compute age from month/year
        let now = Date()
        var components = DateComponents()
        components.year = birthYear
        components.month = birthMonth
        components.day = 1
        let calendar = Calendar.current
        let birthDate = calendar.date(from: components) ?? now
        let ageYears = calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0

        appState.currentUser = User(
            id: uid,
            email: email,
            name: name,
            weight: weightDouble,
            height: heightInchesDouble,
            age: ageYears,
            gender: gender,
            heightFeet: heightFeet,
            heightInches: heightInches,
            birthMonth: birthMonth,
            birthYear: birthYear,
            weightLbs: weightLbs
        )
    }
}

#Preview {
    UserInfoView()
        .environment(AppState())
}

