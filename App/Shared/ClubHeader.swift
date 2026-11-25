import ClubKit
import SwiftUI

/// The club's logo and name in its brand.
struct ClubHeader: View {
    let club: Club
    let logoURL: URL?

    var body: some View {
        VStack(spacing: 24) {
            // shortcut: AsyncImage cannot draw SVG logos (they stay empty); add an SVG renderer or ask the club for PNG when it matters.
            AsyncImage(url: logoURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 120, height: 120)
            .accessibilityHidden(true)

            Text(club.name)
                .heading(.largeTitle)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
