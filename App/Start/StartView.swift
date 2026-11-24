import ClubKit
import SwiftUI

/// The club's logo and name in its brand.
struct StartView: View {
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

            // shortcut: brand primary as is, also in dark mode; port club-client's lib/theme/contrast.ts when a dark brand colour reads poorly.
            Text(club.name)
                .font(.largeTitle.bold())
                .textCase(club.brand.headingCaps ? .uppercase : nil)
                .foregroundStyle(.tint)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
