import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var filled: Color = Theme.teal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, 12)
            .background(filled.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.95 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.primary)
    }
}

struct StatusBadge: View {
    var text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
            .accessibilityLabel(text)
    }
}

struct WarningNote: View {
    var text: String
    var tint: Color = Theme.estimate

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct MetricBlock: View {
    var title: String
    var value: String
    var caption: String?
    var secondary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let secondary {
                Text(secondary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let caption {
                Text(caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.estimate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension DimensionRole {
    var tint: Color {
        switch self {
        case .measured: return Theme.measured
        case .tape, .scaled: return Theme.amber
        case .known: return Theme.measured
        case .estimated: return Theme.estimate
        case .manual: return .secondary
        }
    }
}

extension PaneSizing {
    var badgeText: String? {
        switch self {
        case .pending: return Copy.pendingSize
        case .sized(let pane): return pane.badge
        case .unavailable: return nil
        }
    }

    var badgeTint: Color {
        switch self {
        case .pending: return Theme.pending
        case .sized(let pane):
            switch pane.bucket {
            case .measured: return pane.badge == "已拉尺校正" ? Theme.amber : Theme.measured
            case .manual: return .secondary
            case .estimate: return Theme.estimate
            }
        case .unavailable: return .secondary
        }
    }
}
