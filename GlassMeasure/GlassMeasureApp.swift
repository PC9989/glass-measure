import SwiftData
import SwiftUI

@main
struct GlassMeasureApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.teal)
        }
        .modelContainer(for: [MeasureJob.self, GlassPane.self])
    }
}
