import ClubKit
import SwiftUI

struct LoginView: View {
    let club: Club
    let logoURL: URL?
    let signIn: @MainActor (_ email: String, _ password: String) async throws -> Void
    let resetPassword: @MainActor (_ email: String) async throws -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: Error?
    @State private var forgot = false

    var body: some View {
        Form {
            Section {
                ClubHeader(club: club, logoURL: logoURL)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            Section {
                TextField("E-Mail", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Passwort", text: $password)
                    .textContentType(.password)
                    .onSubmit(submit)
            } footer: {
                if let error { Text(AuthMessage.text(for: error)).foregroundStyle(.red) }
            }

            Section {
                Button(action: submit) {
                    if busy { ProgressView() } else { Text("Anmelden") }
                }
                .disabled(busy || email.isEmpty || password.isEmpty)
                Button("Passwort vergessen?") { forgot = true }
            }
        }
        .brandSurface()
        .sheet(isPresented: $forgot) {
            ForgotPasswordView(email: email, send: resetPassword)
        }
    }

    private func submit() {
        guard !busy, !email.isEmpty, !password.isEmpty else { return }
        busy = true
        error = nil
        Task {
            do { try await signIn(email.trimmingCharacters(in: .whitespaces), password) } catch { self.error = error }
            busy = false
        }
    }
}
