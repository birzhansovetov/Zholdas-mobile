import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        ZStack {
            ZholdasTheme.appBackground.ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(ZholdasTheme.accent)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(ZholdasTheme.accent.opacity(0.16)))

                    Text("Сброс пароля")
                        .font(.title2.weight(.bold))
                        .foregroundColor(ZholdasTheme.textPrimary)

                    Text("Введите email аккаунта. Мы отправим ссылку для создания нового пароля.")
                        .font(.subheadline)
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Электронная почта")
                        .font(.caption.weight(.bold))
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .tracking(1)

                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(isEmailFocused ? ZholdasTheme.accent : ZholdasTheme.textSecondary)
                            .frame(width: 24)
                        TextField("user@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled()
                            .foregroundColor(ZholdasTheme.textPrimary)
                            .focused($isEmailFocused)
                    }
                    .modernFieldSurface(isFocused: isEmailFocused)
                }
                .modernCard()

                if let message = authViewModel.passwordResetMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    isEmailFocused = false
                    Task {
                        await authViewModel.sendPasswordResetEmail(email: email)
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Отправить ссылку")
                                .font(.headline.weight(.bold))
                        }
                    }
                    .primaryActionSurface()
                }
                .buttonStyle(SpringButtonStyle())
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authViewModel.isLoading)

                Button("Вернуться ко входу") {
                    dismiss()
                }
                .font(.footnote.weight(.bold))
                .foregroundColor(ZholdasTheme.accent)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResetPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var localError: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case password
        case confirmPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZholdasTheme.appBackground.ignoresSafeArea()

                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(ZholdasTheme.accent)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(ZholdasTheme.accent.opacity(0.16)))

                        Text("Новый пароль")
                            .font(.title2.weight(.bold))
                            .foregroundColor(ZholdasTheme.textPrimary)

                        Text("Придумайте новый пароль для аккаунта.")
                            .font(.subheadline)
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        passwordField(
                            title: "Новый пароль",
                            placeholder: "Минимум 6 символов",
                            text: $password,
                            field: .password
                        )

                        passwordField(
                            title: "Повторите пароль",
                            placeholder: "Введите пароль еще раз",
                            text: $confirmPassword,
                            field: .confirmPassword
                        )
                    }
                    .modernCard()

                    if let error = localError ?? authViewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        focusedField = nil
                        guard password.count >= 6 else {
                            localError = "Пароль должен быть минимум 6 символов"
                            return
                        }
                        guard password == confirmPassword else {
                            localError = "Пароли не совпадают"
                            return
                        }

                        localError = nil
                        Task {
                            _ = await authViewModel.resetPassword(newPassword: password)
                        }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Сохранить пароль")
                                    .font(.headline.weight(.bold))
                            }
                        }
                        .primaryActionSurface()
                    }
                    .buttonStyle(SpringButtonStyle())
                    .disabled(password.isEmpty || confirmPassword.isEmpty || authViewModel.isLoading)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
            }
        }
    }

    private func passwordField(title: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(ZholdasTheme.textSecondary)
                .tracking(1)

            HStack {
                Image(systemName: "lock")
                    .foregroundColor(focusedField == field ? ZholdasTheme.accent : ZholdasTheme.textSecondary)
                    .frame(width: 24)
                SecureField(placeholder, text: text)
                    .foregroundColor(ZholdasTheme.textPrimary)
                    .focused($focusedField, equals: field)
            }
            .modernFieldSurface(isFocused: focusedField == field)
        }
    }
}
