import SwiftUI
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// "Unser Schwarm" — screen 1h: everybody who plays on this iPad, with their
/// stars.
///
/// **Nobody comes last here.** No position, no numbers 1-2-3, no podium, no
/// medal, no arrow, no difference to the child above. Each row says what one
/// child has collected and nothing about anybody else, and the motto under the
/// heading says what the list is for: the stars belong to the swarm.
///
/// The rows do stand in order of stars, which is the one comparison the design
/// keeps — a sibling can see who has been playing longest — but it is never
/// named, and the child reading it is the row that is lit up rather than the
/// row at the top.
///
/// **Hidden while one child plays alone.** A swarm of one is not a swarm, and
/// a list with a single row invites a second child to be measured against it
/// the moment one exists. This is the plan's open decision 5; flipping it is
/// deleting the `guard`.
struct SwarmList: View {
    /// The avatar disc in a row, and in a compact width.
    private static let discDiameter: CGFloat = 72
    private static let compactDiscDiameter: CGFloat = 56

    let profiles: [Profile]
    /// The child whose album this is. Its row is lit; it is not moved.
    let activeProfileID: Profile.ID?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    /// Most stars first, and ties in the order the profiles were created —
    /// `sorted(by:)` is not stable, so the tie-break is spelled out rather
    /// than left to shuffle from one draw to the next.
    private var swarm: [Profile] {
        profiles.enumerated().sorted { left, right in
            if left.element.totalStars != right.element.totalStars {
                return left.element.totalStars > right.element.totalStars
            }
            return left.offset < right.offset
        }.map(\.element)
    }

    var body: some View {
        if profiles.count > 1 {
            VStack(spacing: ZSpacing.step4) {
                VStack(spacing: ZSpacing.step2) {
                    Text("leaderboard.title")
                        .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
                        .foregroundStyle(ZColor.textStrong)

                    Text("leaderboard.motto")
                        .typeStyle(.body, .body, weight: .regular)
                        .foregroundStyle(ZColor.textBody)
                }
                .multilineTextAlignment(.center)

                ForEach(swarm) { profile in
                    row(profile)
                }
            }
        }
    }

    /// One child: the avatar, the name, and under it the rank and the stars.
    ///
    /// The design puts the star badge at the right edge of the row. It does
    /// not fit there on a phone — `Badge` never wraps and never shrinks, so
    /// "142 Sterne" ate the column and left "Joha…" beside it — and a name a
    /// child cannot read in full is the one thing a row like this must not
    /// do. One arrangement for both widths rather than two: the badge sits
    /// under the name, where it has the room.
    private func row(_ profile: Profile) -> some View {
        ZCard(tone: profile.id == activeProfileID ? .sun : .paper) {
            HStack(spacing: ZSpacing.step4) {
                AvatarDisc(
                    style: .avatar(profile.avatar),
                    diameter: isCompact ? Self.compactDiscDiameter : Self.discDiameter,
                )

                VStack(alignment: .leading, spacing: ZSpacing.step2) {
                    Text(verbatim: profile.name)
                        .typeStyle(isCompact ? .label : .headline, .display, weight: .bold)
                        .foregroundStyle(ZColor.textStrong)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: ZSpacing.step3) {
                        Badge(
                            String(
                                format: String(localized: "collection.stars"),
                                profile.totalStars,
                            ),
                            tone: .sun,
                            icon: .star,
                        )

                        Text(verbatim: RankLadder.rank(forStars: profile.totalStars).displayName)
                            .typeStyle(.caption, .body, weight: .semibold)
                            .foregroundStyle(ZColor.textMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

private func swarmProfiles() -> [Profile] {
    [
        Profile(id: UUID(), name: "Johanna", avatar: "feather", totalStars: 142),
        Profile(id: UUID(), name: "Papa", avatar: "house", totalStars: 98),
        Profile(id: UUID(), name: "Mia", avatar: "star", totalStars: 57),
    ]
}

#Preview("Three in the swarm", traits: .fixedLayout(width: 900, height: 700)) {
    let profiles = swarmProfiles()
    return ScrollView {
        SwarmList(profiles: profiles, activeProfileID: profiles[2].id)
            .padding(ZSpacing.gutterScreen)
    }
    .background(ZColor.surfacePage)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("One child — nothing at all", traits: .fixedLayout(width: 900, height: 300)) {
    SwarmList(
        profiles: [Profile(id: UUID(), name: "Mia", avatar: "star", totalStars: 57)],
        activeProfileID: nil,
    )
    .padding(ZSpacing.gutterScreen)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
