import SwiftUI

struct RateParticipantsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    let eventID: Int32
    let participants: [Participant]
    
    @State private var ratedUserIDs: Set<String> = []
    @State private var selectedParticipant: Participant? = nil
    
    // Rating Form State
    @State private var selectedRating: Int = 5
    @State private var reviewComment: String = ""
    @State private var isSubmitting = false
    @State private var showFormSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sleek Dark Background
                ZholdasTheme.appBackground
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Text("Поделитесь впечатлениями о других участниках события")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                    
                    let targetParticipants = participants.filter { $0.id != authViewModel.currentUserProfile?.id }
                    
                    if targetParticipants.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Нет других участников")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Вы были единственным участником этого события.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(targetParticipants) { participant in
                                    participantRow(for: participant)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("Оценить участников")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundColor(ZholdasTheme.accent)
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showFormSheet, onDismiss: resetForm) {
                if let p = selectedParticipant {
                    ratingFormSheet(for: p)
                }
            }
        }
    }
    
    // MARK: - Row View
    
    @ViewBuilder
    private func participantRow(for participant: Participant) -> some View {
        HStack(spacing: 16) {
            // Avatar
            avatarView(for: participant)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.fullName)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("@\(participant.username)")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            let hasRated = ratedUserIDs.contains(participant.id)
            
            if hasRated {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Оценено")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            } else {
                Button {
                    selectedParticipant = participant
                    showFormSheet = true
                } label: {
                    Text("Оценить")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - Avatar
    
    @ViewBuilder
    private func avatarView(for participant: Participant) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.15, blue: 0.45), Color(red: 0.15, green: 0.08, blue: 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
            
            if let avatarURL = participant.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .frame(width: 48, height: 48)
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            } else {
                Text(getInitials(from: participant.fullName))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Rating Form Sheet
    
    @ViewBuilder
    private func ratingFormSheet(for participant: Participant) -> some View {
        ZStack {
            // Dark Background
            ZholdasTheme.appBackground
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Оценка участника")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 24)
                    
                    Text(participant.fullName)
                        .font(.headline)
                        .foregroundColor(ZholdasTheme.accent)
                    
                    Text("@\(participant.username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Star Selector
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                selectedRating = star
                            }
                        } label: {
                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundColor(star <= selectedRating ? Color(red: 1.0, green: 0.8, blue: 0.0) : .gray)
                                .scaleEffect(star == selectedRating ? 1.25 : 1.0)
                        }
                    }
                }
                .padding(.vertical, 10)
                
                // Dynamic Text Description
                Text(getRatingDescription(for: selectedRating))
                    .font(.headline)
                    .foregroundColor(ZholdasTheme.accent)
                    .fontWeight(.bold)
                    .id(selectedRating)
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    .padding(.top, -8)
                
                // Comment Text Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("ОТЗЫВ (НЕОБЯЗАТЕЛЬНО)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .tracking(1.0)
                    
                    TextField("Напишите пару слов о вашем впечатлении...", text: $reviewComment, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Submit Button
                if isSubmitting {
                    ProgressView()
                        .tint(ZholdasTheme.accent)
                        .padding(.bottom, 30)
                } else {
                    Button {
                        submitRating(for: participant.id)
                    } label: {
                        Text("Отправить оценку")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [ZholdasTheme.accent, ZholdasTheme.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func submitRating(for rateeID: String) {
        isSubmitting = true
        Task {
            let success = await authViewModel.rateParticipant(
                eventID: eventID,
                rateeID: rateeID,
                rating: selectedRating,
                comment: reviewComment
            )
            if success {
                ratedUserIDs.insert(rateeID)
                showFormSheet = false
            }
            isSubmitting = false
        }
    }
    
    private func resetForm() {
        selectedRating = 5
        reviewComment = ""
        selectedParticipant = nil
    }
    
    private func getInitials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "👤"
    }
    
    private func getRatingDescription(for rating: Int) -> String {
        switch rating {
        case 1: return "Ужасно 😟"
        case 2: return "Плохо 🙁"
        case 3: return "Нормально 😐"
        case 4: return "Хорошо 🙂"
        case 5: return "Отлично! 🤩"
        default: return ""
        }
    }
}
