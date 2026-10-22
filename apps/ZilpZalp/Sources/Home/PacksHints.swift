import SwiftUI
import ZilpZalpUI

/// The grown-ups' door in the home screen's corner, wearing a sparkle once a
/// child has collected most of the birds on the device (#262), or a dot while
/// the bucket has a pack the grown-ups have not seen or an update (#334).
///
/// Neither has words: the child is told nothing, and a grown-up sees that
/// something waits behind the door. One badge at a time, in the same corner —
/// the sparkle wins, since it leads to the same gallery and says more. VoiceOver
/// reads what the badge stands for along with the door's name.
struct GrownUpsButton: View {
    let newBirds: Bool
    var packNews = false
    let action: () -> Void

    private var label: String {
        if newBirds {
            String(localized: "parents.newBirds.accessibility")
        } else if packNews {
            String(localized: "parents.packNews.accessibility")
        } else {
            String(localized: "parents.title")
        }
    }

    var body: some View {
        IconButton(
            .userRoundCog,
            label: label,
            tone: .clay,
            diameter: ZSpacing.touchMinimum,
            action: action,
        )
        .overlay(alignment: .topTrailing) {
            Group {
                if newBirds {
                    Icon(.sparkles, size: .small)
                        .foregroundStyle(ZColor.textOnReward)
                        .padding(ZSpacing.step1)
                        .background(Circle().fill(ZColor.reward))
                } else if packNews {
                    // Ringed in the page colour so it stands off the clay.
                    Circle()
                        .fill(ZColor.reward)
                        .frame(width: ZSpacing.step3, height: ZSpacing.step3)
                        .padding(ZBorder.width)
                        .background(Circle().fill(ZColor.surfacePage))
                }
            }
            .offset(x: ZSpacing.step1, y: -ZSpacing.step1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// One line for grown-ups on the home screen, shown once after the first
/// profile exists: more birds live in the grown-ups' area (#262).
///
/// Words, because it is addressed to whoever can read them; a child who taps
/// it lands in front of the lock, which is where the line points anyway. It
/// never touches the network, and it goes for good when it is closed or the
/// grown-ups' area is opened.
struct PacksHint: View {
    let open: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: ZSpacing.step2) {
            Button(action: open) {
                HStack(spacing: ZSpacing.step2) {
                    Icon(.sparkles, size: .small)
                        .foregroundStyle(ZColor.olive600)
                    Text("home.packsHint")
                        .typeStyle(.caption, .body, weight: .bold)
                        .foregroundStyle(ZColor.textBody)
                        .multilineTextAlignment(.leading)
                }
                .frame(minHeight: ZSpacing.touchMinimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            IconButton(
                .close,
                label: String(localized: "home.packsHint.dismiss"),
                diameter: ZSpacing.touchMinimum,
                action: dismiss,
            )
        }
        .padding(.leading, ZSpacing.step4)
        .background(Capsule().fill(ZColor.surfaceCard))
        .overlay(Capsule().strokeBorder(ZColor.borderCard, lineWidth: ZBorder.width))
    }
}

#Preview("Door with sparkle, with dot, and the hint") {
    VStack(spacing: ZSpacing.step6) {
        GrownUpsButton(newBirds: true) {}
        GrownUpsButton(newBirds: false, packNews: true) {}
        PacksHint(open: {}, dismiss: {})
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
