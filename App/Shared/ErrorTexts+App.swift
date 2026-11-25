import ClubKit
import Foundation

extension ErrorTexts {
    /// The texts bundled with the app (`ClubKit/Contract/error-texts.json`, see project.yml).
    static let app: ErrorTexts = {
        guard let url = Bundle.main.url(forResource: "error-texts", withExtension: "json"),
              let texts = try? ErrorTexts(json: Data(contentsOf: url))
        else { preconditionFailure("error-texts.json is missing from the app bundle") }
        return texts
    }()
}
