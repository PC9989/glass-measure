import Foundation
import SwiftData

@Model
final class MeasureJob {
    var uuid: UUID
    var createdAt: Date
    var updatedAt: Date
    var customerName: String
    var notes: String
    @Relationship(deleteRule: .cascade, inverse: \GlassPane.job)
    var panes: [GlassPane]

    init(customerName: String, notes: String) {
        self.uuid = UUID()
        self.createdAt = .now
        self.updatedAt = .now
        self.customerName = customerName
        self.notes = notes
        self.panes = []
    }

    var displayName: String {
        let trimmed = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Copy.unnamedSite : trimmed
    }

    var orderedPanes: [GlassPane] {
        panes.sorted { $0.createdAt < $1.createdAt }
    }
}

enum ComposerRoute {
    case ar
    case photo
    case manual
}
