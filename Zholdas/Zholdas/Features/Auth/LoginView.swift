import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var showRegisterScreen = false
    @State private var showForgotPasswordScreen = false
    @State private var animateBackground = false
    
    enum Field {
        case email, password
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationStack {
            ZStack {
                ZholdasTheme.appBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Логотип и Приветствие
                        VStack(spacing: 14) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 86, height: 86)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: ZholdasTheme.accent.opacity(0.20), radius: 22, x: 0, y: 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(ZholdasTheme.border, lineWidth: 1.5)
                                )
                            
                            Text("Жолдас")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundColor(ZholdasTheme.textPrimary)
                            
                            Text("login_subtitle".localized)
                                .font(.subheadline)
                                .foregroundColor(ZholdasTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 46)
                        
                        // Поля ввода внутри матовой стеклянной карточки
                        VStack(spacing: 18) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("login_email_label".localized)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(ZholdasTheme.textSecondary)
                                    .tracking(1.0)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(focusedField == .email ? ZholdasTheme.accent : ZholdasTheme.textSecondary)
                                        .frame(width: 24)
                                    TextField("user@example.com", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .foregroundColor(ZholdasTheme.textPrimary)
                                        .focused($focusedField, equals: .email)
                                }
                                .modernFieldSurface(isFocused: focusedField == .email)
                                .animation(.easeOut(duration: 0.2), value: focusedField)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("login_password_label".localized)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(ZholdasTheme.textSecondary)
                                        .tracking(1.0)

                                    Spacer()

                                    Button {
                                        showForgotPasswordScreen = true
                                    } label: {
                                        Text("Забыли пароль?")
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(ZholdasTheme.accent)
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(focusedField == .password ? ZholdasTheme.accent : ZholdasTheme.textSecondary)
                                        .frame(width: 24)
                                    SecureField("login_password_placeholder".localized, text: $password)
                                        .foregroundColor(ZholdasTheme.textPrimary)
                                        .focused($focusedField, equals: .password)
                                }
                                .modernFieldSurface(isFocused: focusedField == .password)
                                .animation(.easeOut(duration: 0.2), value: focusedField)
                            }
                        }
                        .modernCard()
                        
                        // Вывод ошибки
                        if let error = authViewModel.errorMessage {
                            VStack(spacing: 10) {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                if error.localizedCaseInsensitiveContains("email") || error.localizedCaseInsensitiveContains("почт") {
                                    Button {
                                        Task {
                                            await authViewModel.resendEmailConfirmation(email: email)
                                        }
                                    } label: {
                                        Text("Отправить письмо еще раз")
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(ZholdasTheme.accent)
                                    }
                                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authViewModel.isLoading)
                                }
                            }
                        }

                        if let info = authViewModel.infoMessage {
                            Text(info)
                                .font(.caption)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Кнопка входа
                        Button {
                            focusedField = nil
                            Task {
                                await authViewModel.signIn(email: email, password: password)
                            }
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("login_btn".localized)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .primaryActionSurface()
                        }
                        .buttonStyle(SpringButtonStyle())
                        .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                        
                        // Переход на регистрацию
                        HStack {
                            Text("login_no_account".localized)
                                .foregroundColor(ZholdasTheme.textSecondary)
                            Button {
                                showRegisterScreen = true
                            } label: {
                                Text("login_register_link".localized)
                                    .fontWeight(.bold)
                                    .foregroundColor(ZholdasTheme.accent)
                            }
                        }
                        .font(.footnote)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                }
                
                // Кнопка выбора языка в правом верхнем углу (Floating on top!)
                VStack {
                    HStack {
                        Spacer()
                        Menu {
                            Button("RU - Русский") {
                                langManager.currentLanguage = "ru"
                            }
                            Button("KK - Қазақша") {
                                langManager.currentLanguage = "kk"
                            }
                            Button("EN - English") {
                                langManager.currentLanguage = "en"
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(langManager.currentLanguage.uppercased())
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(ZholdasTheme.textPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(ZholdasTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ZholdasTheme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(ZholdasTheme.border, lineWidth: 1)
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                    }
                    Spacer()
                }
            }
            .navigationDestination(isPresented: $showRegisterScreen) {
                RegisterView()
                    .environmentObject(authViewModel)
                    .environmentObject(langManager)
            }
            .navigationDestination(isPresented: $showForgotPasswordScreen) {
                ForgotPasswordView()
                    .environmentObject(authViewModel)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animateBackground = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
        .environmentObject(LocalizationManager.shared)
}
