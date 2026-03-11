import SwiftUI

// MARK: - Brand Colors
extension Color {
    static let brandNavy      = Color(hex: "000411")
    static let brandLime      = Color(hex: "DBFE87")
    static let brandOrange    = Color(hex: "D74E09")
    static let brandBlue      = Color(hex: "48ACF0")
    static let brandCream     = Color(hex: "E9EDDE")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Styled Text Field
struct BrandTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color.brandCream.opacity(0.35))
                    .padding(.horizontal, 16)
            }
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 16)
            .foregroundColor(.brandCream)
        }
        .frame(height: 52)
        .background(Color.brandCream.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brandCream.opacity(0.18), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Auth Error Helper
private func friendlyAuthError(_ error: Error) -> String {
    let msg = error.localizedDescription.lowercased()
    if msg.contains("email address is badly formatted") || msg.contains("invalid email") {
        return "That email address doesn't look right."
    }
    if msg.contains("there is no user record") || msg.contains("user not found") || msg.contains("no user record") {
        return "No account found with that email. Sign up first."
    }
    if msg.contains("password is invalid") || msg.contains("wrong password") || msg.contains("incorrect password") {
        return "Incorrect password. Please try again."
    }
    if msg.contains("email address is already in use") || msg.contains("already in use") {
        return "An account with this email already exists."
    }
    if msg.contains("too many requests") || msg.contains("too many unsuccessful") {
        return "Too many attempts. Wait a moment and try again."
    }
    if msg.contains("network") || msg.contains("connection") {
        return "Network error. Check your connection."
    }
    if msg.contains("user disabled") {
        return "This account has been disabled. Contact support."
    }
    return error.localizedDescription
}

// MARK: - Content View
struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var showingSignUp = false

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
            if showingSignUp {
                SignUpView(showingSignUp: $showingSignUp)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else {
                LoginView(showingSignUp: $showingSignUp)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSignUp)
    }
}

// MARK: - Diagonal Slash Header
private struct SlashHeader: View {
    let iconName: String
    let title: String
    let subtitle: String
    var appeared: Bool

    var body: some View {
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

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.brandNavy)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05), value: appeared)

                Text(title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.brandNavy)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.12), value: appeared)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.brandNavy.opacity(0.65))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.18), value: appeared)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .frame(height: 220)
        .clipped()
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
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                SlashHeader(
                    iconName: "figure.run.circle.fill",
                    title: "Create Account",
                    subtitle: "Start your fitness journey today",
                    appeared: appeared
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        VStack(spacing: 12) {
                            BrandTextField(placeholder: "Email address", text: $email, keyboardType: .emailAddress)
                            BrandTextField(placeholder: "Password", text: $password, isSecure: true)
                            BrandTextField(placeholder: "Confirm password", text: $confirmPassword, isSecure: true)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.22), value: appeared)

                        if !message.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill").font(.caption)
                                Text(message).font(.caption).multilineTextAlignment(.leading)
                            }
                            .foregroundColor(.brandOrange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.1)) { createPressed = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.15)) { createPressed = false }
                            }
                            createAccount()
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.brandNavy)
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundColor(.brandNavy)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(height: 54)
                        .background(createPressed ? Color.brandLime.opacity(0.8) : Color.brandLime)
                        .cornerRadius(14)
                        .scaleEffect(createPressed ? 0.97 : 1.0)
                        .animation(.easeInOut(duration: 0.12), value: createPressed)
                        .disabled(isLoading)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.3), value: appeared)

                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(Color.brandCream.opacity(0.5))
                                .font(.subheadline)
                            Button("Sign In") {
                                withAnimation(.easeInOut(duration: 0.3)) { showingSignUp = false }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.brandBlue)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.36), value: appeared)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    private func createAccount() {
        message = ""
        let emailTrimmed = email.trimmingCharacters(in: .whitespaces)

        guard !emailTrimmed.isEmpty || !password.isEmpty else {
            message = "Please enter your email and password."; return
        }
        if !emailTrimmed.isEmpty && password.isEmpty {
            message = "Please enter a password."; return
        }
        if emailTrimmed.isEmpty && !password.isEmpty {
            message = "Please enter your email address."; return
        }
        guard emailTrimmed.contains("@") && emailTrimmed.contains(".") else {
            message = "That doesn't look like a valid email."; return
        }
        guard password.count >= 6 else {
            message = "Password must be at least 6 characters."; return
        }
        guard !confirmPassword.isEmpty else {
            message = "Please confirm your password."; return
        }
        guard password == confirmPassword else {
            message = "Passwords do not match."; return
        }

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
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                SlashHeader(
                    iconName: "figure.run.circle.fill",
                    title: "Welcome Back",
                    subtitle: "Sign in to continue",
                    appeared: appeared
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        VStack(spacing: 12) {
                            BrandTextField(placeholder: "Email address", text: $email, keyboardType: .emailAddress)
                            BrandTextField(placeholder: "Password", text: $password, isSecure: true)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.22), value: appeared)

                        if !message.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill").font(.caption)
                                Text(message).font(.caption).multilineTextAlignment(.leading)
                            }
                            .foregroundColor(.brandOrange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.1)) { signInPressed = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.15)) { signInPressed = false }
                            }
                            login()
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(.brandNavy)
                                } else {
                                    Text("Sign In")
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundColor(.brandNavy)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(height: 54)
                        .background(signInPressed ? Color.brandLime.opacity(0.8) : Color.brandLime)
                        .cornerRadius(14)
                        .scaleEffect(signInPressed ? 0.97 : 1.0)
                        .animation(.easeInOut(duration: 0.12), value: signInPressed)
                        .disabled(isLoading)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.3), value: appeared)

                        HStack {
                            Rectangle().frame(height: 1).foregroundColor(Color.brandCream.opacity(0.1))
                            Text("or").font(.caption).foregroundColor(Color.brandCream.opacity(0.3))
                            Rectangle().frame(height: 1).foregroundColor(Color.brandCream.opacity(0.1))
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.34), value: appeared)

                        Button {
                            appState.isLoggedIn = true
                            appState.hasCompletedOnboarding = true
                        } label: {
                            Text("Continue as Guest")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.brandCream.opacity(0.7))
                                .frame(maxWidth: .infinity)
                        }
                        .frame(height: 50)
                        .background(Color.brandCream.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.brandCream.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(14)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.38), value: appeared)

                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(Color.brandCream.opacity(0.5))
                                .font(.subheadline)
                            Button("Sign Up") {
                                withAnimation(.easeInOut(duration: 0.3)) { showingSignUp = true }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.brandBlue)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.42), value: appeared)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    private func login() {
        message = ""
        let emailTrimmed = email.trimmingCharacters(in: .whitespaces)

        guard !emailTrimmed.isEmpty || !password.isEmpty else {
            message = "Please enter your email and password."; return
        }
        if !emailTrimmed.isEmpty && password.isEmpty {
            message = "Please enter your password."; return
        }
        if emailTrimmed.isEmpty && !password.isEmpty {
            message = "Please enter your email address."; return
        }
        guard emailTrimmed.contains("@") && emailTrimmed.contains(".") else {
            message = "That doesn't look like a valid email."; return
        }

        isLoading = true
        Task {
            do {
                let userId = try await AuthService.shared.signIn(email: emailTrimmed, password: password)
                // Fetch profile from Supabase to determine if onboarding is needed
                do {
                    let user = try await ProfileService.shared.fetchProfile(userId: userId)
                    // Profile exists — go straight to dashboard
                    appState.completeOnboarding(user: user)
                    appState.isLoggedIn = true
                } catch {
                    // No profile yet — route to onboarding
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
