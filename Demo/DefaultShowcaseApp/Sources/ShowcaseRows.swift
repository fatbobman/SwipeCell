import SwiftUI
import SwipeCell

struct ShowcaseMessageRow: View {
    let message: ShowcaseMessage
    var accessory: String?

    @Environment(\.swipeCellNormalOpenProgress) private var normalOpenProgress

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(message.tint.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(initials)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(message.sender)
                        .font(.subheadline.weight(.semibold))
                    if message.unread {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                    if message.archived {
                        stateIndicator("archivebox.fill", tint: .blue)
                    }
                    if message.flagged {
                        stateIndicator("flag.fill", tint: .yellow)
                    }
                    if message.pinned {
                        stateIndicator("pin.fill", tint: .indigo)
                    }
                    if message.snoozed {
                        stateIndicator("clock.fill", tint: .orange)
                    }
                }

                Text(message.subject)
                    .font(.body.weight(.semibold))

                Text(message.preview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let accessory {
                Text(accessory)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(minHeight: 92)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Rectangle().fill(.background)
                Rectangle().fill(message.tint.opacity(0.14 * normalOpenProgress))
            }
        }
    }

    private var initials: String {
        String(message.sender.prefix(1))
    }

    // Caption-sized so the sender line keeps its height; tints mirror the matching action tints.
    private func stateIndicator(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
    }
}

struct ShowcaseHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ShowcaseStatusBar: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
    }
}

struct ProgressBadgeLabel: View {
    let title: String
    let systemImage: String
    let context: SwipeActionContext

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolVariant(context.isArmed ? .fill : .none)
            Text(title)
                .font(.caption2.weight(.semibold))
            Capsule()
                .fill(.white.opacity(0.72))
                .frame(width: 24 + 18 * context.normalOpenProgress, height: 3)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SoftSwipeActionStyle: SwipeActionStyle {
    func makeBody(configuration: SwipeActionStyleConfiguration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.tint)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .opacity(0.72 + 0.28 * configuration.context.normalOpenProgress)
            }
    }
}
