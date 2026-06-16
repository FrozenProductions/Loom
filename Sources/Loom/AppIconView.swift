import SwiftUI

struct AppIconView: View {
    let app: SpaceApp

    var body: some View {
        Image(nsImage: IconCache.shared.icon(for: app.bundleIdentifier))
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
