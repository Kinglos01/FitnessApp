//
//  ContentView.swift
//  FitnessApp
//
//  Created by Carlos Berio on 2/11/26.
//

import SwiftUI

struct ContentView: View {
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Text("Create Account")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 30)
                
                // Username
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                
                // Password
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                // Confirm Password
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                
                // Login Button
                Button(action: {
                    print("Login tapped")
                }) {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Login")
        }
    }
}

#Preview {
    ContentView()
}
