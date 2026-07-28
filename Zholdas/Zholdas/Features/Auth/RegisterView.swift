import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @Environment(\.dismiss) var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedGender = "Не указывать"
    @State private var selectedAge = 20
    @State private var bio = ""
    @State private var selectedCategories: Set<String> = []
    @State private var emailCode = ""

    @State private var currentStep: RegistrationStep = .userInfo
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var localError: String?
    @State private var animateBackground = false

    private enum RegistrationStep: Int, CaseIterable {
        case userInfo = 1
        case interests
        case emailCode
    }

    enum Field {
        case fullName, email, password, confirmPassword, bio, emailCode
    }

    @FocusState private var focusedField: Field?

    private let interestCategories = [
        (value: "hiking", titleKey: "cat_mountains", icon: "mountain.2.fill"),
        (value: "walk", titleKey: "cat_walks", icon: "tree.fill"),
        (value: "sports", titleKey: "cat_sports", icon: "soccerball"),
        (value: "theater", titleKey: "cat_theater", icon: "theatermasks.fill"),
        (value: "restaurant", titleKey: "cat_restaurant", icon: "fork.knife"),
        (value: "board_games", titleKey: "cat_games", icon: "dice.fill"),
        (value: "networking", titleKey: "cat_networking", icon: "person.2.wave.2.fill"),
        (value: "other", titleKey: "cat_other", icon: "sparkles")
    ]

    var body: some View {
        ZStack {
            ZholdasTheme.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    progressHeader

                    switch currentStep {
                    case .userInfo:
                        userInfoStep
                    case .interests:
                        interestsStep
                    case .emailCode:
                        emailCodeStep
                    }

                    if let error = localError ?? authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let info = authViewModel.infoMessage {
                        Text(info)
                            .font(.caption)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: primaryAction) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(primaryButtonTitle)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .primaryActionSurface()
                    }
                    .buttonStyle(SpringButtonStyle())
                    .disabled(isPrimaryDisabled)

                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Text("reg_already_have_account".localized)
                                .foregroundColor(.gray)
                            Text("reg_login_link".localized)
                                .fontWeight(.bold)
                                .foregroundColor(ZholdasTheme.accent)
                        }
                        .font(.footnote)
                    }
                    .buttonStyle(SpringButtonStyle())
                    .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: backAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("reg_back".localized)
                    }
                    .foregroundColor(ZholdasTheme.accent)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateBackground = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: ZholdasTheme.accent.opacity(0.35), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.2)
                )

            Text("reg_title".localized)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.top, 24)
    }

    private var progressHeader: some View {
        HStack(spacing: 10) {
            stepChip(.userInfo, title: "reg_step_user_info".localized)
            stepLine(active: currentStep.rawValue > RegistrationStep.userInfo.rawValue)
            stepChip(.interests, title: "reg_step_interests".localized)
            stepLine(active: currentStep.rawValue > RegistrationStep.interests.rawValue)
            stepChip(.emailCode, title: "reg_step_email".localized)
        }
        .padding(.horizontal, 4)
    }

    private var userInfoStep: some View {
        VStack(spacing: 20) {
            inputField(
                title: "reg_name_label".localized,
                icon: "person",
                placeholder: "reg_name_placeholder".localized,
                text: $fullName,
                field: .fullName
            )

            inputField(
                title: "reg_email_label".localized,
                icon: "envelope",
                placeholder: "reg_email_placeholder".localized,
                text: $email,
                field: .email,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            passwordField(
                title: "reg_password_label".localized,
                icon: "lock",
                placeholder: "reg_password_placeholder".localized,
                text: $password,
                field: .password,
                isVisible: $showPassword
            )

            passwordField(
                title: "reg_confirm_password_label".localized,
                icon: "lock.shield",
                placeholder: "********",
                text: $confirmPassword,
                field: .confirmPassword,
                isVisible: $showConfirmPassword
            )

            genderSection
            ageSection

            inputField(
                title: "reg_bio_label".localized,
                icon: "bubble.left.and.bubble.right",
                placeholder: "reg_bio_placeholder".localized,
                text: $bio,
                field: .bio
            )
        }
        .modernCard()
    }

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("reg_interests_title".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("reg_interests_subtitle".localized)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(interestCategories, id: \.value) { category in
                    categoryButton(
                        title: category.titleKey.localized,
                        icon: category.icon,
                        isSelected: selectedCategories.contains(category.value)
                    ) {
                        if selectedCategories.contains(category.value) {
                            selectedCategories.remove(category.value)
                        } else {
                            selectedCategories.insert(category.value)
                        }
                    }
                }
            }
        }
        .modernCard()
    }

    private var emailCodeStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(ZholdasTheme.accent)
                .frame(width: 72, height: 72)
                .background(Circle().fill(ZholdasTheme.accent.opacity(0.14)))

            VStack(spacing: 6) {
                Text("reg_check_email_title".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\("reg_check_email_subtitle".localized) \(normalizedEmail)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            inputField(
                title: "reg_email_code_label".localized,
                icon: "number",
                placeholder: "reg_email_code_placeholder".localized,
                text: $emailCode,
                field: .emailCode,
                keyboardType: .numberPad
            )

            Button {
                Task {
                    await authViewModel.resendEmailConfirmation(email: normalizedEmail)
                }
            } label: {
                Text("reg_resend_code".localized)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(ZholdasTheme.accent)
            }
            .disabled(authViewModel.isLoading)
        }
        .modernCard()
    }

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("reg_gender_label".localized)
                .formLabelStyle()

            HStack(spacing: 12) {
                genderCard(title: "reg_gender_male".localized, symbol: "♂", selected: selectedGender == "Мужской") {
                    selectedGender = "Мужской"
                }
                genderCard(title: "reg_gender_female".localized, symbol: "♀", selected: selectedGender == "Женский") {
                    selectedGender = "Женский"
                }
                genderCard(title: "reg_gender_none".localized, symbol: "—", selected: selectedGender == "Не указывать") {
                    selectedGender = "Не указывать"
                }
            }
        }
    }

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("reg_birth_year_label".localized)
                .formLabelStyle()

            HStack {
                Image(systemName: "birthday.cake")
                    .foregroundColor(ZholdasTheme.accent)
                    .frame(width: 24)

                Text("\(selectedAge)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("reg_age_suffix".localized)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()

                Stepper("", value: $selectedAge, in: 13...80)
                    .labelsHidden()
            }
            .padding()
            .glassBackground(cornerRadius: 12, strokeColor: ZholdasTheme.border)
        }
    }

    private var primaryButtonTitle: String {
        switch currentStep {
        case .userInfo:
            return "reg_next".localized
        case .interests:
            return "reg_send_code".localized
        case .emailCode:
            return "reg_verify_code".localized
        }
    }

    private var isPrimaryDisabled: Bool {
        if authViewModel.isLoading { return true }

        switch currentStep {
        case .userInfo:
            return fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || password.isEmpty
                || confirmPassword.isEmpty
        case .interests:
            return selectedCategories.isEmpty
        case .emailCode:
            return emailCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var profileBioForSignup: String {
        var parts: [String] = []
        let cleanBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanBio.isEmpty {
            parts.append(cleanBio)
        }

        if !selectedCategories.isEmpty {
            let interests = selectedCategories.sorted().joined(separator: ",")
            parts.append("[interests:\(interests)]")
        }

        return parts.joined(separator: "\n")
    }

    private func primaryAction() {
        focusedField = nil
        localError = nil

        switch currentStep {
        case .userInfo:
            guard validateUserInfo() else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .interests
            }
        case .interests:
            Task {
                await startSignup()
            }
        case .emailCode:
            Task {
                await verifyEmailCode()
            }
        }
    }

    private func backAction() {
        switch currentStep {
        case .userInfo:
            dismiss()
        case .interests:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .userInfo
            }
        case .emailCode:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .interests
            }
        }
    }

    private func validateUserInfo() -> Bool {
        if password != confirmPassword {
            localError = "reg_err_mismatch".localized
            return false
        }

        if password.count < 6 {
            localError = "reg_err_short".localized
            return false
        }

        return true
    }

    private func startSignup() async {
        let username = normalizedEmail.components(separatedBy: "@").first ?? "user_\(UUID().uuidString.prefix(6))"
        let profileGender = selectedGender == "Не указывать" ? nil : selectedGender
        let birthYear = currentYear - selectedAge

        await authViewModel.signUp(
            email: normalizedEmail,
            password: password,
            username: username,
            fullName: fullName,
            avatarURL: "",
            bio: profileBioForSignup,
            city: "Алматы",
            gender: profileGender,
            birthYear: birthYear
        )

        if authViewModel.errorMessage == nil && !authViewModel.isAuthenticated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                currentStep = .emailCode
            }
        }
    }

    private func verifyEmailCode() async {
        let profileGender = selectedGender == "Не указывать" ? nil : selectedGender
        let birthYear = currentYear - selectedAge

        await authViewModel.verifySignupCode(
            email: normalizedEmail,
            code: emailCode.trimmingCharacters(in: .whitespacesAndNewlines),
            fullName: fullName,
            avatarURL: "",
            bio: profileBioForSignup,
            city: "Алматы",
            gender: profileGender,
            birthYear: birthYear
        )
    }

    @ViewBuilder
    private func stepChip(_ step: RegistrationStep, title: String) -> some View {
        let active = currentStep == step
        let completed = currentStep.rawValue > step.rawValue

        HStack(spacing: 6) {
            Text(completed ? "✓" : "\(step.rawValue)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 22, height: 22)
                .foregroundColor(.white)
                .background(Circle().fill(active || completed ? ZholdasTheme.accent : Color.white.opacity(0.12)))

            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(active ? .white : .gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func stepLine(active: Bool) -> some View {
        Capsule()
            .fill(active ? ZholdasTheme.accent : Color.white.opacity(0.12))
            .frame(width: 18, height: 2)
    }

    @ViewBuilder
    private func inputField(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .formLabelStyle()

            HStack {
                Image(systemName: icon)
                    .foregroundColor(focusedField == field ? ZholdasTheme.accent : .gray)
                    .frame(width: 24)

                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(field == .email || field == .emailCode)
                    .foregroundColor(.white)
                    .focused($focusedField, equals: field)
            }
            .padding()
            .glassBackground(cornerRadius: 12, strokeColor: focusedField == field ? ZholdasTheme.accent : .white.opacity(0.1))
            .animation(.easeOut(duration: 0.2), value: focusedField)
        }
    }

    @ViewBuilder
    private func passwordField(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isVisible: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .formLabelStyle()

            HStack {
                Image(systemName: icon)
                    .foregroundColor(focusedField == field ? ZholdasTheme.accent : .gray)
                    .frame(width: 24)

                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                        .foregroundColor(.white)
                        .focused($focusedField, equals: field)
                } else {
                    SecureField(placeholder, text: text)
                        .foregroundColor(.white)
                        .focused($focusedField, equals: field)
                }

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Text(isVisible.wrappedValue ? "reg_hide".localized : "reg_show".localized)
                        .font(.caption)
                        .foregroundColor(ZholdasTheme.accent)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .glassBackground(cornerRadius: 12, strokeColor: focusedField == field ? ZholdasTheme.accent : .white.opacity(0.1))
            .animation(.easeOut(duration: 0.2), value: focusedField)
        }
    }

    @ViewBuilder
    private func genderCard(title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(symbol)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .frame(width: 44, height: 44)
                    .foregroundColor(selected ? .white : ZholdasTheme.accent)
                    .background(
                        Circle()
                            .fill(selected ? ZholdasTheme.accent : ZholdasTheme.accent.opacity(0.14))
                    )

                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? ZholdasTheme.accent : Color.white.opacity(0.06), lineWidth: selected ? 2 : 1)
            )
            .foregroundColor(selected ? .white : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func categoryButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.callout)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isSelected ? ZholdasTheme.accent.opacity(0.28) : Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? ZholdasTheme.accent : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private extension Text {
    func formLabelStyle() -> some View {
        self
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray)
            .tracking(1.5)
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
        .environmentObject(LocalizationManager.shared)
}
