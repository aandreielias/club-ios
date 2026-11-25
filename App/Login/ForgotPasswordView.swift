import SwiftUI

/// Sends Supabase's reset mail; its link opens the web app, where the new password is set.
struct ForgotPasswordView: View {
    @State var email: String
    let send: @MainActor (_ email: String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var sent = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Text("Wenn es zu dieser Adresse ein Konto gibt, kommt gleich eine E-Mail mit einem Link.")
                } else {
                    Section {
                        TextField("E-Mail", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        if let error { Text(AuthMessage.text(for: error)).foregroundStyle(.red) }
                    }
                    Button(action: submit) {
                        if busy { ProgressView() } else { Text("Link senden") }
                    }
                    .disabled(busy || email.isEmpty)
                }
            }
            .navigationTitle("Passwort vergessen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sent {
                    Button("Fertig") { dismiss() }
                } else {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        busy = true
        error = nil
        Task {
            do {
                try await send(email.trimmingCharacters(in: .whitespaces))
                sent = true
            } catch {
                self.error = error
            }
            busy = false
        }
    }
}
