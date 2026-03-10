////
//  ContentView.swift
//  FitnessApp
//
//  Created by Carlos Berio on 2/11/26.
//

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

// MARK: - Auth Error Helper
private func friendlyAuthError(_ error: Error) -> String {
    let msg = error.localizedDescription.lowercased()
    if msg.contains("email address is badly formatted") || msg.contains("invalid email") {
        return "That email address doesn't look right. Please check the format."
    }
    if msg.contains("there is no user record") || msg.contains("user not found") || msg.contains("no user record") {
        return "No account found with that email. Please sign up first."
    }
    if msg.contains("password is invalid") || msg.contains("wrong password") || msg.contains("incorrect password") {
        return "Incorrect password. Please try again."
    }
    if msg.contains("email address is already in use") || msg.contains("already in use") {
        return "An account with this email already exists. Try logging in instead."
    }
    if msg.contains("too many requests") || msg.contains("too many unsuccessful") {
        return "Too many failed attempts. Please wait a moment and try again."
    }
    if msg.contains("network") || msg.contains("connection") {
        return "Network error. Please check your internet connection."
    }
    if msg.contains("user disabled") {
        return "This account has been disabled. Please contact support."
    }
    return error.localizedDescription
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
            VStack(spacing: 8) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 70)).foregroundColor(.green)
                Text("Create Account").font(.largeTitle).bold()
                Text("Start your fitness journey today").font(.subheadline).foregroundColor(.gray)
            }
            Spacer().frame(height: 10)
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder).keyboardType(.emailAddress).autocapitalization(.none)
                SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
                SecureField("Confirm Password", text: $confirmPassword).textFieldStyle(.roundedBorder)
            }
            if !message.isEmpty {
                Text(message).foregroundColor(.red).font(.caption).multilineTextAlignment(.center)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { createPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeInOut(duration: 0.2)) { createPressed = false }
                }
                createAccount()
            } label: {
                if isLoading { ProgressView().tint(.white) }
                else { Text("Create Account").frame(maxWidth: .infinity).bold() }
            }
            .padding()
            .background(createPressed ? Color.green.opacity(0.65) : Color.green)
            .animation(.easeInOut(duration: 0.15), value: createPressed)
            .foregroundColor(.white).cornerRadius(10)
            .scaleEffect(createPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: createPressed)
            .disabled(isLoading)
            HStack(spacing: 4) {
                Text("Already have an account?").foregroundColor(.gray).font(.subheadline)
                Button("Login") { withAnimation(.easeInOut) { showingSignUp = false } }
                    .font(.subheadline).bold().foregroundColor(.blue)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func createAccount() {
        message = ""
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty || !password.isEmpty else {
            message = "Please enter your email and password."; return
        }
        if !email.trimmingCharacters(in: .whitespaces).isEmpty && password.isEmpty {
            message = "Please enter a password to go with your email."; return
        }
        if email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty {
            message = "Please enter your email address."; return
        }
        let emailTrimmed = email.trimmingCharacters(in: .whitespaces)
        guard emailTrimmed.contains("@") && emailTrimmed.contains(".") else {
            message = "That doesn't look like a valid email address."; return
        }
        guard password.count >= 6 else { message = "Password must be at least 6 characters."; return }
        guard !confirmPassword.isEmpty else { message = "Please confirm your password."; return }
        guard password == confirmPassword else { message = "Passwords do not match. Please try again."; return }

        isLoading = true
        Task {
            do {
                let userId = try await AuthService.shared.signUp(email: emailTrimmed, password: password)
                appState.pendingUserId = userId
                appState.pendingEmail = emailTrimmed
                appState.isLoggedIn = true
                appState.hasCompletedOnboarding = false
            } catch {
                message = friendlyAuthError(error)
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
            VStack(spacing: 8) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 70)).foregroundColor(.blue)
                Text("Welcome Back").font(.largeTitle).bold()
                Text("Sign in to continue").font(.subheadline).foregroundColor(.gray)
            }
            Spacer().frame(height: 10)
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder).keyboardType(.emailAddress).autocapitalization(.none)
                SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
            }
            if !message.isEmpty {
                Text(message).foregroundColor(.red).font(.caption).multilineTextAlignment(.center)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { signInPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeInOut(duration: 0.2)) { signInPressed = false }
                }
                login()
            } label: {
                if isLoading { ProgressView().tint(.white) }
                else { Text("Sign In").frame(maxWidth: .infinity).bold() }
            }
            .padding()
            .background(signInPressed ? Color.blue.opacity(0.65) : Color.blue)
            .animation(.easeInOut(duration: 0.15), value: signInPressed)
            .foregroundColor(.white).cornerRadius(10)
            .scaleEffect(signInPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: signInPressed)
            .disabled(isLoading)
            HStack(spacing: 4) {
                Text("Don't have an account?").foregroundColor(.gray).font(.subheadline)
                Button("Sign Up") { withAnimation(.easeInOut) { showingSignUp = true } }
                    .font(.subheadline).bold().foregroundColor(.green)
            }
            // MARK: - Guest Bypass (temp)
            Button {
                appState.isLoggedIn = true
                appState.hasCompletedOnboarding = true
            } label: {
                Text("Continue as Guest").frame(maxWidth: .infinity).bold()
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
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty || !password.isEmpty else {
            message = "Please enter your email and password."; return
        }
        if !email.trimmingCharacters(in: .whitespaces).isEmpty && password.isEmpty {
            message = "Please enter your password."; return
        }
        if email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty {
            message = "Please enter your email address."; return
        }
        let emailTrimmed = email.trimmingCharacters(in: .whitespaces)
        guard emailTrimmed.contains("@") && emailTrimmed.contains(".") else {
            message = "That doesn't look like a valid email address."; return
        }

        isLoading = true
        Task {
            do {
                let userId = try await AuthService.shared.signIn(email: emailTrimmed, password: password)

                // Try to fetch their existing profile from Supabase
                do {
                    let user = try await ProfileService.shared.fetchProfile(userId: userId)
                    // Profile exists — log them straight in
                    appState.completeOnboarding(user: user)
                    appState.isLoggedIn = true
                } catch {
                    // No profile yet — this is their first time, send to onboarding
                    appState.pendingUserId = userId
                    appState.pendingEmail = emailTrimmed
                    appState.isLoggedIn = true
                    appState.hasCompletedOnboarding = false
                }
            } catch {
                message = friendlyAuthError(error)
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
