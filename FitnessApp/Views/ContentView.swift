//
//  ContentView.swift
//  FitnessApp
//
//  Created by Carlos Berio on 2/11/26.
//

import SwiftUI

struct ContentView: View {

    @Environment(AppState.self) var appState
    @State private var showingSignUp = false

    var body: some View {
        if showingSignUp {
            SignUpView(showingSignUp: $showingSignUp)
        } else {
            LoginView(showingSignUp: $showingSignUp)
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {

    @Environment(AppState.self) var appState
    @Binding var showingSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var createPressed = false

    var body: some View {
        VStack(spacing: 20) {

            Spacer()

            // MARK: - Header
            VStack(spacing: 8) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)

                Text("Create Account")
                    .font(.largeTitle)
                    .bold()

                Text("Start your fitness journey today")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer().frame(height: 10)

            // MARK: - Fields
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            // MARK: - Create Account Button
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { createPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeInOut(duration: 0.2)) { createPressed = false }
                }
                createAccount()
            } label: {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
            }
            .padding()
            .background(createPressed ? Color.green.opacity(0.65) : Color.green)
            .animation(.easeInOut(duration: 0.15), value: createPressed)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(createPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: createPressed)
            .disabled(isLoading)

            // MARK: - Login Link
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                Button("Login") {
                    withAnimation(.easeInOut) { showingSignUp = false }
                }
                .font(.subheadline)
                .bold()
                .foregroundColor(.blue)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func createAccount() {
        message = ""
        guard password == confirmPassword else {
            message = "Passwords do not match."
            return
        }
        guard password.count >= 6 else {
            message = "Password must be at least 6 characters."
            return
        }
        isLoading = true
        Task {
            do {
                let userId = try await AuthService.shared.signUp(email: email, password: password)
                appState.isLoggedIn = true
                appState.hasCompletedOnboarding = false
                // Pre-fill ID and email for UserInfoView
                appState.currentUser = User(
                    id: userId,
                    email: email,
                    name: "",
                    weight: 0,
                    height: 0,
                    age: 0,
                    gender: ""
                )
                appState.hasCompletedOnboarding = false
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Login View
struct LoginView: View {

    @Environment(AppState.self) var appState
    @Binding var showingSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var signInPressed = false

    var body: some View {
        VStack(spacing: 20) {

            Spacer()

            // MARK: - Header
            VStack(spacing: 8) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)

                Text("Welcome Back")
                    .font(.largeTitle)
                    .bold()

                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer().frame(height: 10)

            // MARK: - Fields
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            // MARK: - Sign In Button
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { signInPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeInOut(duration: 0.2)) { signInPressed = false }
                }
                login()
            } label: {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
            }
            .padding()
            .background(signInPressed ? Color.blue.opacity(0.65) : Color.blue)
            .animation(.easeInOut(duration: 0.15), value: signInPressed)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(signInPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: signInPressed)
            .disabled(isLoading)

            // MARK: - Back to Sign Up
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                Button("Sign Up") {
                    withAnimation(.easeInOut) { showingSignUp = true }
                }
                .font(.subheadline)
                .bold()
                .foregroundColor(.green)
            }

            // MARK: - Guest Bypass (temp)
            Button {
                appState.isLoggedIn = true
                appState.hasCompletedOnboarding = true
            } label: {
                Text("Continue as Guest")
                    .frame(maxWidth: .infinity)
                    .bold()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(10)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func login() {
        message = ""
        isLoading = true
        Task {
            do {
                let userId = try await AuthService.shared.signIn(email: email, password: password)
                appState.isLoggedIn = true
                // If no saved profile, go to onboarding
                if appState.currentUser == nil {
                    appState.currentUser = User(
                        id: userId,
                        email: email,
                        name: "",
                        weight: 0,
                        height: 0,
                        age: 0,
                        gender: ""
                    )
                    appState.hasCompletedOnboarding = false
                }
            } catch {
                message = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
