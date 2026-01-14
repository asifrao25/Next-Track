//
//  FeedbackFormView.swift
//  Been There
//
//  User feedback and suggestions form
//

import SwiftUI
import MessageUI

struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var thoughts: String = ""
    @State private var starRating: Int = 0
    @State private var lowRatingReason: String = ""
    @State private var suggestion: String = ""

    // UI State
    @State private var showMailComposer = false
    @State private var showMailError = false
    @State private var showValidationError = false
    @State private var showSuccessAlert = false
    @State private var mailResult: MFMailComposeResult?

    private var isFormValid: Bool {
        starRating > 0
    }

    private var needsLowRatingReason: Bool {
        starRating > 0 && starRating < 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Star Rating (Required)
                    starRatingSection

                    // Low Rating Reason (if stars < 3)
                    if needsLowRatingReason {
                        lowRatingSection
                    }

                    // Your Thoughts
                    thoughtsSection

                    // Name (Optional)
                    nameSection

                    // Email (Optional)
                    emailSection

                    // Suggestion (Optional)
                    suggestionSection

                    // Submit Button
                    submitButton

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposeView(
                    result: $mailResult,
                    recipients: ["mail@asifrao.com"],
                    subject: "Been There App Feedback",
                    body: composeEmailBody()
                )
            }
            .alert("Email Not Available", isPresented: $showMailError) {
                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = composeEmailBody()
                    HapticManager.shared.success()
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Mail is not configured on this device. You can copy the feedback to clipboard and send it manually to mail@asifrao.com")
            }
            .alert("Rating Required", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please select a star rating before submitting your feedback.")
            }
            .alert("Thank You!", isPresented: $showSuccessAlert) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your feedback has been sent. We appreciate you taking the time to help improve Been There!")
            }
            .onChange(of: mailResult) { _, result in
                if let result = result {
                    handleMailResult(result)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 35))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("We'd Love Your Feedback")
                .font(.title2)
                .fontWeight(.bold)

            Text("Help us improve Been There by sharing your thoughts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Star Rating Section

    private var starRatingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rate Your Experience")
                    .font(.headline)
                Text("*")
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            starRating = star
                        }
                        HapticManager.shared.light()
                    } label: {
                        Image(systemName: star <= starRating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundStyle(
                                star <= starRating ?
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(star <= starRating ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            if starRating > 0 {
                Text(ratingDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private var ratingDescription: String {
        switch starRating {
        case 1: return "We're sorry to hear that. Please tell us what went wrong."
        case 2: return "We can do better. Your feedback helps us improve."
        case 3: return "Thanks! What can we do to make it even better?"
        case 4: return "Great! We're glad you're enjoying the app."
        case 5: return "Awesome! We're thrilled you love Been There!"
        default: return ""
        }
    }

    // MARK: - Low Rating Section

    private var lowRatingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("What could be improved?")
                    .font(.headline)
            }

            TextEditor(text: $lowRatingReason)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )

            Text("Your honest feedback helps us understand what needs improvement")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Thoughts Section

    private var thoughtsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Thoughts")
                .font(.headline)

            TextEditor(text: $thoughts)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)

            Text("Share your overall experience with the app")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Name")
                    .font(.headline)
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Email Section

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Email")
                    .font(.headline)
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField("your@email.com", text: $email)
                .textFieldStyle(.plain)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .padding(12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)

            Text("We'll only use this if we need to follow up on your feedback")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Suggestion Section

    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Suggestions")
                    .font(.headline)
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $suggestion)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)

            Text("Any features or improvements you'd like to see?")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            submitFeedback()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                Text("Send Feedback")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isFormValid ? [.cyan, .purple] : [.gray, .gray.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: isFormValid ? .cyan.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func submitFeedback() {
        HapticManager.shared.medium()

        guard isFormValid else {
            showValidationError = true
            return
        }

        // Check if mail is available
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailError = true
        }
    }

    private func composeEmailBody() -> String {
        var body = """
        === Been There App Feedback ===

        RATING: \(String(repeating: "⭐", count: starRating)) (\(starRating)/5)

        """

        if needsLowRatingReason && !lowRatingReason.isEmpty {
            body += """
            IMPROVEMENT FEEDBACK:
            \(lowRatingReason)

            """
        }

        if !thoughts.isEmpty {
            body += """
            THOUGHTS:
            \(thoughts)

            """
        }

        if !name.isEmpty {
            body += """
            NAME: \(name)

            """
        }

        if !email.isEmpty {
            body += """
            EMAIL: \(email)

            """
        }

        if !suggestion.isEmpty {
            body += """
            SUGGESTIONS:
            \(suggestion)

            """
        }

        body += """

        ---
        Sent from Been There App
        """

        return body
    }

    private func handleMailResult(_ result: MFMailComposeResult) {
        switch result {
        case .sent:
            HapticManager.shared.success()
            showSuccessAlert = true
        case .saved:
            HapticManager.shared.light()
        case .cancelled:
            HapticManager.shared.light()
        case .failed:
            HapticManager.shared.error()
        @unknown default:
            break
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var result: MFMailComposeResult?

    let recipients: [String]
    let subject: String
    let body: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.result = result
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    FeedbackFormView()
}
