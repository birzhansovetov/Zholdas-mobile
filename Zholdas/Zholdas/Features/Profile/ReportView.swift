import SwiftUI

struct ReportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var langManager: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    let reportedUserID: String?
    let eventID: Int32?
    let messageID: Int32?
    
    @State private var selectedReason: String = "spam"
    @State private var descriptionText: String = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    
    private let reasons = [
        ("spam", "rep_reason_spam", "bubble.left.and.bubble.right.fill"),
        ("harassment", "rep_reason_harassment", "exclamationmark.bubble.fill"),
        ("violence", "rep_reason_violence", "hand.raised.fill"),
        ("inappropriate", "rep_reason_inappropriate", "eye.slash.fill"),
        ("other", "rep_reason_other", "questionmark.circle.fill")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Sleek Dark Background
                ZholdasTheme.appBackground
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("rep_info_text".localized)
                        .font(.footnote)
                        .foregroundColor(ZholdasTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    // Reasons List
                    VStack(spacing: 10) {
                        ForEach(reasons, id: \.0) { reasonKey, reasonTitle, iconName in
                            Button {
                                selectedReason = reasonKey
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: iconName)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedReason == reasonKey ? ZholdasTheme.accent : ZholdasTheme.textSecondary)
                                        .frame(width: 24)
                                    
                                    Text(reasonTitle.localized)
                                        .font(.body)
                                        .foregroundColor(ZholdasTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    if selectedReason == reasonKey {
                                        Circle()
                                            .fill(ZholdasTheme.accent)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .padding()
                                .background(selectedReason == reasonKey ? ZholdasTheme.accent.opacity(0.10) : ZholdasTheme.surface.opacity(0.66))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedReason == reasonKey ? ZholdasTheme.accent.opacity(0.45) : ZholdasTheme.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("rep_details_title".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(ZholdasTheme.textSecondary)
                            .tracking(1.0)
                        
                        TextField("rep_details_placeholder".localized, text: $descriptionText, axis: .vertical)
                            .lineLimit(3...5)
                            .foregroundColor(ZholdasTheme.textPrimary)
                            .modernFieldSurface()
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Submit Button
                    if isSubmitting {
                        ProgressView()
                            .tint(ZholdasTheme.accent)
                            .padding(.bottom, 24)
                    } else {
                        Button {
                            submitReport()
                        } label: {
                            Text("rep_submit_btn".localized)
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("rep_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("btn_cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
            .alert("rep_alert_title".localized, isPresented: $showSuccessAlert) {
                Button("btn_ok".localized) {
                    dismiss()
                }
            } message: {
                Text("rep_alert_message".localized)
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        Task {
            let success = await authViewModel.sendReport(
                reportedUserID: reportedUserID,
                eventID: eventID,
                messageID: messageID,
                reason: selectedReason,
                description: descriptionText
            )
            isSubmitting = false
            if success {
                showSuccessAlert = true
            } else {
                // If it fails, still show alert or dismiss to avoid locking
                showSuccessAlert = true
            }
        }
    }
}
