import SwiftUI
import UIKit

/// What a swipe in from the left edge does on one screen.
///
/// Every screen in this app hides the system navigation bar and draws its own
/// ``TopBar``, and a hidden bar takes the stack's swipe back with it —
/// measured in the simulator on the album *and* on the grown-ups' area, which
/// never hid a back button of its own. So the gesture has to be asked back
/// for, and wherever it is asked back for, it is said out loud (#150).
enum SwipeBack {
    /// Back, the way iOS goes back everywhere else: the screen follows the
    /// finger and a swipe let go halfway puts it down again.
    ///
    /// For every screen whose ``TopBar`` has a back chevron and nothing to
    /// ask before it is left.
    case pops

    /// Not back — the closure instead, which is what that screen's back
    /// button does. The quiz's: a round under way is not thrown away by a
    /// gesture, it asks first (#146).
    ///
    /// Nothing moves under the finger, because nothing is going anywhere.
    case asks(@MainActor () -> Void)

    /// Nothing at all, for the screens that deliberately have no way back:
    /// the round end, the rank ascent, "Zeit fürs Nest".
    ///
    /// The rank ascent is the one screen that carries a back chevron and still
    /// says this. It is left on purpose and deliberately, by that chevron or
    /// by "Weiter", and not by a gesture — the decision #150 records.
    case disabled
}

extension View {
    /// Says what a swipe in from the left edge does on this screen.
    ///
    /// Per screen and never for the stack: the policy is installed while the
    /// screen is on top and taken down again when it is not, so the screen
    /// underneath is never left with somebody else's answer.
    func swipesBack(_ policy: SwipeBack) -> some View {
        background {
            SwipeBackHook(policy: policy)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - The hook

/// The one piece of UIKit this needs: a controller inside the screen, from
/// which the `UINavigationController` behind the `NavigationStack` — and with
/// it the recognizers that pop it — can be reached.
///
/// SwiftUI has no public way to bring that gesture back once the navigation
/// bar is hidden. Taking over the recognizer's delegate is the way there is,
/// and the alternative — an `extension UINavigationController` overriding
/// `viewDidLoad` — would be exactly the blanket switch this must not be.
private struct SwipeBackHook: UIViewControllerRepresentable {
    let policy: SwipeBack

    func makeUIViewController(context _: Context) -> SwipeBackController {
        SwipeBackController(policy: policy)
    }

    func updateUIViewController(_ controller: SwipeBackController, context _: Context) {
        // On every pass of the screen's body, because the closure of
        // ``SwipeBack/asks(_:)`` captures what the screen knows now — the
        // quiz's round is nil on the first pass and a session on the next.
        controller.policy = policy
    }

    /// The screen can also go without UIKit ever saying goodbye — a changed
    /// view identity takes the controller apart with no `viewWillDisappear`.
    /// The delegates would then point at nothing, and a recognizer with no
    /// delegate answers "yes" to everything.
    static func dismantleUIViewController(_ controller: SwipeBackController, coordinator _: ()) {
        controller.restore()
    }
}

/// Carries one screen's ``SwipeBack`` to the navigation controller's back
/// gestures, and hands them back as it found them.
///
/// The delegates are swapped rather than the recognizers replaced: what makes
/// the screen follow the finger, and snap back when the swipe is let go
/// halfway, is UIKit's own interactive transition. Only two answers are ours —
/// whether the gesture may begin, and what happens when it does.
private final class SwipeBackController: UIViewController, UIGestureRecognizerDelegate {
    /// How far in from the edge a swipe may start. `UIScreenEdgePanGesture`
    /// works with about twenty points, and this is that with a child's aim
    /// added.
    ///
    /// The band is ours to draw, because the recognizer is not: a
    /// `NavigationStack` pops through UIKit's *content* swipe, which takes a
    /// drag anywhere on the screen — measured, by dragging across the middle
    /// of the album and watching it leave. Left at that, a finger drawn over a
    /// page of stickers would close the page, and a finger drawn over the quiz
    /// would ask whether to stop playing. What was asked for is the swipe in
    /// from the left, so that is what this lets through.
    ///
    /// The left and not the leading edge: the app ships in German and in no
    /// other direction. A right-to-left language would have to mirror this
    /// along with everything else.
    private static let edgeWidth: CGFloat = 24

    var policy: SwipeBack

    /// The navigation controller this is installed on, remembered so its
    /// recognizers can still be found on the way out, when
    /// `navigationController` is already nil.
    private weak var installedOn: UINavigationController?

    /// The recognizers taken over, each with what it looked like before.
    private var taken: [Taken] = []

    /// Whether the finger now on the screen came down in the band at the left
    /// edge.
    private var startedAtTheEdge = false

    /// One recognizer and the delegate it had before.
    private struct Taken {
        let recognizer: UIGestureRecognizer
        let delegate: (any UIGestureRecognizerDelegate)?
    }

    init(policy: SwipeBack) {
        self.policy = policy
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        // Nothing to draw and nothing to hit: this controller is here for its
        // place in the hierarchy and for nothing else.
        view = UIView()
        view.isUserInteractionEnabled = false
    }

    /// Twice on purpose: under SwiftUI the navigation controller is not always
    /// reachable yet when the view is about to appear, and installing again
    /// costs nothing.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        install()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        install()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restore()
    }

    // MARK: - Taking the gestures over and giving them back

    /// Takes over every back gesture of the navigation controller, and
    /// remembers what each of them was.
    ///
    /// Every one of them, because the public `interactivePopGestureRecognizer`
    /// is not the one that pops a `NavigationStack`: UIKit keeps a second
    /// recognizer of the same kind beside it, and under SwiftUI it is that one
    /// which asks and acts. They are found by their class rather than by their
    /// private name, so nothing here depends on what UIKit calls them.
    ///
    /// The screen being pushed and the screen being left both run this around
    /// the same moment, and UIKit does not promise which first. Two details
    /// make the order not matter: a hook that finds another hook in place
    /// inherits *its* memory of the system delegate rather than remembering
    /// the hook, and a hook only gives back what it is still holding — see
    /// ``restore()``.
    private func install() {
        guard let navigation = navigationController,
              let pop = navigation.interactivePopGestureRecognizer,
              let recognizers = navigation.view.gestureRecognizers
        else { return }

        let backGestures = recognizers.filter { type(of: $0) == type(of: pop) }
        guard backGestures.contains(where: { $0.delegate !== self }) else { return }

        installedOn = navigation
        taken = backGestures.map(asFound(_:))
        for recognizer in backGestures {
            recognizer.delegate = self
        }
    }

    /// Which delegate this recognizer had before any screen had an opinion
    /// about it.
    private func asFound(_ recognizer: UIGestureRecognizer) -> Taken {
        if let hook = recognizer.delegate as? SwipeBackController,
           let inherited = hook.taken.first(where: { $0.recognizer === recognizer })
        {
            return inherited
        }
        return Taken(recognizer: recognizer, delegate: recognizer.delegate)
    }

    /// Gives the gestures back — each one only if it is still ours, because a
    /// screen pushed on top may have taken it over already, and then it is
    /// theirs to give back.
    ///
    /// Only the delegate is ever swapped, never `isEnabled`. Disabling a
    /// recognizer that is at that moment recognizing cancels the swipe, and
    /// the two moments this runs at — a screen appearing, a screen leaving —
    /// are exactly the moments an interactive pop is under way. Saying no in
    /// ``gestureRecognizerShouldBegin(_:)`` is the whole of ``SwipeBack``'s
    /// authority, and it needs no second switch.
    fileprivate func restore() {
        for entry in taken where entry.recognizer.delegate === self {
            entry.recognizer.delegate = entry.delegate
        }
        taken = []
        installedOn = nil
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Where the finger came down. Noted here because this is the only moment
    /// it is known: by the time the gesture is allowed to begin, the finger
    /// has moved, and the recognizers are UIKit's own — nothing here may
    /// assume what kind they are or ask them for a translation.
    ///
    /// The *first* finger of the sequence, and no other: a hand resting on the
    /// far side of an iPad while the other hand swipes in from the edge must
    /// not turn that swipe into a touch that started in the middle.
    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch,
    ) -> Bool {
        guard recognizer.numberOfTouches == 0 else { return true }
        // In the navigation controller's own view, so a stack that does not
        // fill the display — an iPad in Slide Over — measures from its own
        // left edge rather than the screen's.
        startedAtTheEdge = touch.location(in: installedOn?.view).x <= Self.edgeWidth
        return true
    }

    /// Asked once per swipe, at the moment the finger has moved far enough for
    /// UIKit to call it a gesture — not when it touches down. That is what
    /// makes ``SwipeBack/asks(_:)`` safe to hang off this: a hand resting on
    /// the edge asks nothing.
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        // Nothing to pop, or a push or pop already under way: starting a
        // second transition inside the first is the classic way to wedge a
        // navigation stack.
        guard let navigation = installedOn,
              navigation.viewControllers.count > 1,
              navigation.transitionCoordinator == nil,
              startedAtTheEdge
        else { return false }

        switch policy {
        case .pops:
            return true
        case let .asks(ask):
            ask()
            return false
        case .disabled:
            return false
        }
    }
}
