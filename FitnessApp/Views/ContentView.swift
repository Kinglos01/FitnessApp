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
    @State private var isLoggedIn = false
    @State private var signInPressed = false
    @State private var continuePressed = false

    var body: some View {
        if isLoggedIn {
            MainTabView()
        } else {
            VStack(spacing: 16) {

                Spacer()

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
                    withAnimation(.easeInOut(duration: 0.12)) { signInPressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeInOut(duration: 0.2)) { signInPressed = false }
                    }
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
                .background(signInPressed ? Color.blue.opacity(0.65) : Color.blue)
                .animation(.easeInOut(duration: 0.15), value: signInPressed)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(signInPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: signInPressed)
                .disabled(isLoading)

                // MARK: - Create Account Button
                Button {
                    createAccountQuick()
                } label: {
                    Text("Create Account (for testing)")
                        .font(.footnote)
                }

                // MARK: - Continue as Test User Button
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) { continuePressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeInOut(duration: 0.2)) { continuePressed = false }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isLoggedIn = true
                    }
                } label: {
                    Text("Continue as Test User")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(continuePressed ? Color.green.opacity(0.65) : Color.green)
                        .animation(.easeInOut(duration: 0.15), value: continuePressed)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .scaleEffect(continuePressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: continuePressed)

                Spacer()
                Spacer()
            }
            .padding()
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
                isLoggedIn = true
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
