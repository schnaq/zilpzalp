import SwiftUI
import ZilpZalpUI

/// The grown-ups' door in the home screen's corner, wearing a sparkle once a
/// child has collected most of the birds on the device (#262).
///
/// The sparkle has no words: the child is told nothing, and a grown-up sees
/// that something waits behind the door. VoiceOver reads "neue Vögel" along
/// with the door's name.
struct GrownUpsButton: View {
    let newBirds: Bool
    let action: () -> Void

    var body: some View {
        IconButton(
            .userRoundCog,
            label: String(localized: newBirds ? "parents.newBirds.accessibility" : "parents.title"),
            tone: .clay,
            diameter: ZSpacing.touchMinimum,
            action: action,
        )
        .overlay(alignment: .topTrailing) {
            if newBirds {
                Icon(.sparkles, size: .small)
                    .foregroundStyle(ZColor.textOnReward)
                    .padding(ZSpacing.step1)
                    .background(Circle().fill(ZColor.reward))
                    .offset(x: ZSpacing.step1, y: -ZSpacing.step1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
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

#Preview("Door with sparkle, and the hint") {
    VStack(spacing: ZSpacing.step6) {
        GrownUpsButton(newBirds: true) {}
        PacksHint(open: {}, dismiss: {})
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
