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

    var body: some View {
        NavigationStack {
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
                        .foregroundStyle(.red)
                }

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
                .foregroundStyle(.white)
                .cornerRadius(10)
                .disabled(isLoading)

                Button {
                    createAccountQuick()
                } label: {
                    Text("Create Account (for testing)")
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func login() {
        message = ""
        isLoading = true
        Task {
            do {
                let user = try await AuthService.shared.signIn(email: email, password: password)
                message = "Signed in: \(user.uid)"
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
