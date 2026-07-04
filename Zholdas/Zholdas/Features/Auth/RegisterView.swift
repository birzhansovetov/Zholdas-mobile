import SwiftUI
import PhotosUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedAvatarEmoji = "asset:memoji_1"
    @State private var selectedGender = "Не указывать" // Internal db representation: "Мужской", "Женский", "Не указывать"
    @State private var selectedAge = 20
    @State private var bio = ""
    
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var localError: String?
    @State private var animateBackground = false
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedPhotoData: Data? = nil
    
    let avatarAssets = [
        "memoji_1",
        "memoji_2",
        "memoji_3",
        "memoji_4",
        "memoji_5",
        "memoji_6"
    ]
    
    enum Field {
        case fullName, email, password, confirmPassword, bio
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        ZStack {
            // Sleek Dark Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Logo and Title
                    VStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
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
                    
                    // Main Glass Card for Inputs
                    VStack(spacing: 20) {
                        // 1. Avatar Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_choose_avatar".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Custom Photo Picker Button
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        VStack {
                                            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 50, height: 50)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(ZholdasTheme.accent)
                                                    .frame(width: 50, height: 50)
                                                    .background(Color.white.opacity(0.05))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(selectedPhotoData != nil ? ZholdasTheme.accent : Color.white.opacity(0.1), lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(SpringButtonStyle())
                                    .onChange(of: selectedPhotoItem) { newItem in
                                        Task {
                                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                                await MainActor.run {
                                                    selectedPhotoData = data
                                                    selectedAvatarEmoji = "" // clear symbol
                                                }
                                            }
                                        }
                                    }
                                    
                                    ForEach(avatarAssets, id: \.self) { asset in
                                        Button {
                                            selectedAvatarEmoji = "asset:\(asset)"
                                            selectedPhotoData = nil
                                        } label: {
                                            Image(asset)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .background(selectedAvatarEmoji == "asset:\(asset)" ? ZholdasTheme.accent.opacity(0.2) : Color.white.opacity(0.05))
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedAvatarEmoji == "asset:\(asset)" ? ZholdasTheme.accent : Color.white.opacity(0.1), lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(SpringButtonStyle())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // 2. Full Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_name_label".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(focusedField == .fullName ? ZholdasTheme.accent : .gray)
                                    .frame(width: 24)
                                TextField("reg_name_placeholder".localized, text: $fullName)
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .fullName)
                            }
                            .padding()
                            .glassBackground(cornerRadius: 12, strokeColor: focusedField == .fullName ? ZholdasTheme.accent : .white.opacity(0.1))
                            .animation(.easeOut(duration: 0.2), value: focusedField)
                        }
                        
                        // 3. Email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_email_label".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(focusedField == .email ? ZholdasTheme.accent : .gray)
                                    .frame(width: 24)
                                TextField("reg_email_placeholder".localized, text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .email)
                            }
                            .padding()
                            .glassBackground(cornerRadius: 12, strokeColor: focusedField == .email ? ZholdasTheme.accent : .white.opacity(0.1))
                            .animation(.easeOut(duration: 0.2), value: focusedField)
                        }
                        
                        // 4. Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_password_label".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(focusedField == .password ? ZholdasTheme.accent : .gray)
                                    .frame(width: 24)
                                
                                if showPassword {
                                    TextField("reg_password_placeholder".localized, text: $password)
                                        .foregroundColor(.white)
                                        .focused($focusedField, equals: .password)
                                } else {
                                    SecureField("reg_password_placeholder".localized, text: $password)
                                        .foregroundColor(.white)
                                        .focused($focusedField, equals: .password)
                                }
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Text(showPassword ? "reg_hide".localized : "reg_show".localized)
                                        .font(.caption)
                                        .foregroundColor(ZholdasTheme.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding()
                            .glassBackground(cornerRadius: 12, strokeColor: focusedField == .password ? ZholdasTheme.accent : .white.opacity(0.1))
                            .animation(.easeOut(duration: 0.2), value: focusedField)
                        }
                        
                        // 5. Confirm Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_confirm_password_label".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
                            HStack {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(focusedField == .confirmPassword ? ZholdasTheme.accent : .gray)
                                    .frame(width: 24)
                                
                                if showConfirmPassword {
                                    TextField("********", text: $confirmPassword)
                                        .foregroundColor(.white)
                                        .focused($focusedField, equals: .confirmPassword)
                                } else {
                                    SecureField("********", text: $confirmPassword)
                                        .foregroundColor(.white)
                                        .focused($focusedField, equals: .confirmPassword)
                                }
                                
                                Button {
                                    showConfirmPassword.toggle()
                                } label: {
                                    Text(showConfirmPassword ? "reg_hide".localized : "reg_show".localized)
                                        .font(.caption)
                                        .foregroundColor(ZholdasTheme.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding()
                            .glassBackground(cornerRadius: 12, strokeColor: focusedField == .confirmPassword ? ZholdasTheme.accent : .white.opacity(0.1))
                            .animation(.easeOut(duration: 0.2), value: focusedField)
                        }
                        
                        // 6. Gender Selector (Мужской, Женский, Не указывать)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_gender_label".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
                            HStack(spacing: 12) {
                                genderCard(title: "reg_gender_male".localized, icon: "asset:gender_male", selected: selectedGender == "Мужской") {
                                    selectedGender = "Мужской"
                                }
                                genderCard(title: "reg_gender_female".localized, icon: "asset:gender_female", selected: selectedGender == "Женский") {
                                    selectedGender = "Женский"
                                }
                                genderCard(title: "reg_gender_none".localized, icon: "asset:gender_other", selected: selectedGender == "Не указывать") {
                                    selectedGender = "Не указывать"
                                }
                            }
                        }
                        
                        // 7. Age
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_birth_year_label".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
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
                        
                        // 8. About me (bio)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reg_bio_label".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .tracking(1.5)
                            
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .foregroundColor(focusedField == .bio ? ZholdasTheme.accent : .gray)
                                    .frame(width: 24)
                                TextField("reg_bio_placeholder".localized, text: $bio)
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .bio)
                            }
                            .padding()
                            .glassBackground(cornerRadius: 12, strokeColor: focusedField == .bio ? ZholdasTheme.accent : .white.opacity(0.1))
                            .animation(.easeOut(duration: 0.2), value: focusedField)
                        }
                    }
                    .modernCard()
                    
                    // 9. Live Preview Card
                    HStack(spacing: 16) {
                        Group {
                            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else if selectedAvatarEmoji.hasPrefix("symbol:") {
                                Image(systemName: String(selectedAvatarEmoji.dropFirst(7)))
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            } else {
                                Text(selectedAvatarEmoji)
                                    .font(.system(size: 36))
                                    .frame(width: 60, height: 60)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                        }
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fullName.isEmpty ? "reg_preview_name".localized : fullName)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(email.isEmpty ? "email@example.com" : email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .glassBackground(cornerRadius: 16)
                    
                    // Error message
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
                    
                    // Submit button
                    Button {
                        focusedField = nil
                        if password != confirmPassword {
                            localError = "reg_err_mismatch".localized
                        } else if password.count < 6 {
                            localError = "reg_err_short".localized
                        } else {
                            localError = nil
                            
                            // Generate unique username from email
                            let cleanUsername = email.components(separatedBy: "@").first ?? "user_\(UUID().uuidString.prefix(6))"
                            let cleanAvatarURL = selectedPhotoData != nil ? "" : selectedAvatarEmoji
                            
                            let birthYear = currentYear - selectedAge
                            let profileGender = selectedGender == "Не указывать" ? nil : selectedGender
                            
                            Task {
                                await authViewModel.signUp(
                                    email: email,
                                    password: password,
                                    username: cleanUsername,
                                    fullName: fullName,
                                    avatarURL: cleanAvatarURL,
                                    bio: bio,
                                    city: "Алматы",
                                    gender: profileGender,
                                    birthYear: birthYear
                                )
                                
                                // Upload custom photo if selected and signup succeeded
                                if let photoData = selectedPhotoData, authViewModel.errorMessage == nil {
                                    if let uploadedPath = await authViewModel.uploadImage(data: photoData, fileName: "avatar.jpg") {
                                        let finalAvatarURL = AppConfig.backendAbsoluteURL(for: uploadedPath)
                                        
                                        struct UpdateAvatarBody: Codable {
                                            let fullName: String
                                            let bio: String
                                            let city: String
                                            let avatarURL: String
                                            let gender: String?
                                            let birthYear: Int
                                            
                                            enum CodingKeys: String, CodingKey {
                                                case fullName = "full_name"
                                                case bio
                                                case city
                                                case avatarURL = "avatar_url"
                                                case gender
                                                case birthYear = "birth_year"
                                            }
                                        }
                                        let updateBody = UpdateAvatarBody(
                                            fullName: fullName,
                                            bio: bio,
                                            city: "Алматы",
                                            avatarURL: finalAvatarURL,
                                            gender: profileGender,
                                            birthYear: birthYear
                                        )
                                        if let updateData = try? JSONEncoder().encode(updateBody) {
                                            let _: [String: String]? = try? await APIClient.shared.request(
                                                "/auth/profile",
                                                method: "PUT",
                                                body: updateData,
                                                requiresAuth: true
                                            )
                                            await authViewModel.fetchUserProfile()
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("reg_title".localized)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .primaryActionSurface()
                    }
                    .buttonStyle(SpringButtonStyle())
                    .disabled(fullName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || authViewModel.isLoading)
                    
                    // Back to login link
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
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
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

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    @ViewBuilder
    private func genderCard(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if icon.hasPrefix("asset:") {
                    Image(icon.replacingOccurrences(of: "asset:", with: ""))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else if icon.hasPrefix("symbol:") {
                    Image(systemName: String(icon.dropFirst(7)))
                        .font(.system(size: 18))
                        .frame(height: 36)
                } else {
                    Text(icon)
                        .font(.title3)
                        .frame(height: 36)
                }
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
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
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
        .environmentObject(LocalizationManager.shared)
}
