import ClubKit
import SwiftUI

/// Asks for what the server lists in `Me.missing` (today the birth date) before anything else works.
struct OnboardingView: View {
    let me: Me
    let save: @MainActor (_ birthDate: Date) async throws -> Void
    let signOut: () -> Void

    @State private var birthDate = Date()
    @State private var picked = false
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // The server wants a date in the past: today is refused.
                    DatePicker("Geburtsdatum", selection: $birthDate, in: ...Date().addingTimeInterval(-86_400), displayedComponents: .date)
                        .onChange(of: birthDate) { picked = true }
                } header: {
                    Text("Willkommen, \(me.member.firstName)")
                } footer: {
                    if failed {
                        // shortcut: one text for every error; map ProblemError codes to error-codes.json texts with the first form that needs them.
                        Text("Das Speichern hat nicht geklappt. Bitte versuche es noch einmal.").foregroundStyle(.red)
                    } else {
                        Text("Wird für Altersklassen und Einverständnisse gebraucht. Sichtbar nur für dich, deine Erziehungsberechtigten, deine Trainer:innen und Admins.")
                    }
                }
                Button(action: submit) {
                    if busy { ProgressView() } else { Text("Weiter") }
                }
                .disabled(busy || !picked)
            }
            .navigationTitle("Geburtsdatum")
            .toolbar {
                Button("Abmelden", action: signOut)
            }
        }
    }

    private func submit() {
        busy = true
        failed = false
        Task {
            do { try await save(birthDate) } catch { failed = true }
            busy = false
        }
    }
}
