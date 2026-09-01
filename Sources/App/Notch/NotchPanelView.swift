import SwiftUI
import Domain

/// The panel that hangs below the notch on hover.
///
/// Themed, unlike the notch bar above it: the bar is simulating physical glass
/// and stays black, while this is ordinary app surface.
struct NotchPanelView: View {
    let activity: NotchActivity

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch activity {
            case .working(let session),
                 .agentsWorking(let session),
                 .awaitingInput(let session),
                 .finished(let session):
                sessionDetail(session)
            case .quotaThreshold(let quota):
                quotaDetail(quota)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Session

    private func sessionDetail(_ session: ClaudeSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Text("Claude Code")
                    .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(.white)

                Text(session.phase.label)
                    .font(.system(size: 9.5, weight: .bold, design: theme.fontDesign))
                    .textCase(.uppercase)
                    .kerning(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(session.phase.color.opacity(0.18)))
                    .foregroundStyle(session.phase.color)

                Spacer()

                Text(session.durationDescription)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                Text(session.repoName)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer()
            }

            if let prompt = session.pendingPrompt {
                Text(prompt)
                    .font(.system(size: 11.5, design: theme.fontDesign))
                    .foregroundStyle(.yellow.opacity(0.95))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(.yellow.opacity(0.1))
                            .strokeBorder(.yellow.opacity(0.3))
                    )
            }

            HStack(spacing: 14) {
                if session.completedTaskCount > 0 {
                    statistic("\(session.completedTaskCount)", label: "tasks")
                }
                if session.activeSubagentCount > 0 {
                    statistic("\(session.activeSubagentCount)", label: "agents")
                }
                Spacer()
            }
        }
    }

    // MARK: - Quota

    private func quotaDetail(_ quota: UsageQuota) -> some View {
        let status = QuotaStatus.from(percentRemaining: quota.percentRemaining)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Text(quota.quotaType.displayName)
                    .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(quota.percentRemaining))%")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.statusColor(for: status))
            }

            Capsule()
                .fill(.white.opacity(0.14))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        Capsule()
                            .fill(theme.statusColor(for: status))
                            .frame(width: geometry.size.width * max(0, min(1, quota.percentRemaining / 100)))
                    }
                }

            if let reset = quota.resetText ?? quota.compactResetTime {
                Text(reset)
                    .font(.system(size: 11, design: theme.fontDesign))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func statistic(_ value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 10.5, design: theme.fontDesign))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
