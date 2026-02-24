//
//  ContentView.swift
//  FitnessApp
//
//  Created by Carlos Berio on 2/11/26.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {

    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var navigationPath = NavigationPath() 

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 16) {

                Text("Login")
                    .font(.largeTitle)
                    .bold()

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(.red)
                }

                // MARK: - Sign In Button
                Button {
                    login()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoading)

                // MARK: - Create Account Button
                Button {
                    createAccountQuick()
                } label: {
                    Text("Create Account (for testing)")
                        .font(.footnote)
                }

                // MARK: - Workaround Test Button
                Button {
                    navigationPath.append("WorkoutSelectionView")
                } label: {
                    Text("Continue as Test User")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationDestination(for: String.self) { destination in
                if destination == "WorkoutSelectionView" {
                    WorkoutSelectionView()
                }
            }
        }
    }

    // MARK: - Login Functions
    private func login() {
        message = ""
        isLoading = true
        Task {
            do {
                let user = try await AuthService.shared.signIn(email: email, password: password)
                message = "Signed in: \(user.uid)"
                navigationPath.append("WorkoutSelectionView")
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func createAccountQuick() {
        message = ""
        isLoading = true
        Task {
            do {
                let user = try await AuthService.shared.signUp(email: email, password: password)
                message = "Created: \(user.uid)"
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
