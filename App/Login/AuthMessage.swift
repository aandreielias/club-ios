import ClubKit
import Foundation

/// German texts for login errors, as the web shows them.
enum AuthMessage {
    static func text(for error: Error) -> LocalizedStringResource {
        switch error as? Auth.Failure {
        case .invalidCredentials: "E-Mail oder Passwort ist falsch."
        case .rateLimited: "Zu viele Versuche. Bitte warte kurz."
        default: "Die Anmeldung hat nicht geklappt. Bitte versuche es noch einmal."
        }
    }
}
