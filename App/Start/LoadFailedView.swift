import SwiftUI

struct LoadFailedView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Keine Verbindung", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Der Server des Vereins ist gerade nicht erreichbar.")
        } actions: {
            Button("Erneut versuchen", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
