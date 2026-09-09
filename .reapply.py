def edit(path, pairs):
    s = open(path, encoding="utf-8").read()
    for old, new in pairs:
        n = s.count(old)
        assert n == 1, f"{path}: {n} matches for {old[:70]!r}"
        s = s.replace(old, new)
    open(path, "w", encoding="utf-8").write(s)
    print("ok", path)


edit(
    "apps/ZilpZalp/Sources/RootView.swift",
    [
        (
            """                            openCollection: { path.append(.collection) },
                            // Only while the celebration is still on top:
                            // the ascent arrives 2.2 s after the round was
                            // booked, and a child who has gone home inside
                            // those seconds would otherwise be pushed onto
                            // the rank it earned — the way out has to be a
                            // way out (#175). The screen's own `.task` is
                            // cancelled too late to answer this, because a
                            // pop cancels it when the transition ends.
                            showAscent: {
                                guard case .roundEnd = path.last else { return }
                                path.append(.rankAscent($0))
                            },
                            // All the way home, as "Zeit fürs Nest" goes:""",
            """                            openCollection: { path.append(.collection) },
                            // All the way home, as "Zeit fürs Nest" goes:""",
        ),
        (
            """                    case .collection: collection
                    case .ladder: ladder
                    case let .rankAscent(ascent):
                        RankAscentScreen(
                            ascent: ascent,
                            photos: photos,
                            catalog: model.catalog,
                            goBack: { path.removeLast() },
                            openLadder: { path.append(.ladder) },
                        )
""",
            """                    case .collection: collection
""",
        ),
        (
            """    /// The album, the ladder and the ascent all draw pages of stickers, and
    /// each of them is rebuilt on every layout pass. Opening the files here
    /// means the three screens are handed pictures rather than a directory.""",
            """    /// The album draws a whole page of stickers, and a `View` is rebuilt on
    /// every layout pass. Opening the files here means the screen is handed
    /// pictures rather than a directory.""",
        ),
        (
            """                profiles: model.profiles,
                openLadder: { path.append(.ladder) },
                goBack: { path.removeLast() },""",
            """                profiles: model.profiles,
                goBack: { path.removeLast() },""",
        ),
        (
            """    /// The ladder without a child reads as a ladder nobody is on, which is
    /// exactly what it is: eight rungs, none of them current. No failure
    /// screen for that.
    private var ladder: some View {
        RankLadderScreen(
            stars: model.activeProfile?.totalStars ?? 0,
            photos: photos,
            catalog: model.catalog,
            goBack: { path.removeLast() },
        )
    }

""",
            "",
        ),
        (
            """            QuizScreen(
                game: game,
                catalog: catalog,
                askedFor: roundsAskedFor,
                onFinished: { path.append(.roundEnd($0)) },
            )""",
            """            QuizScreen(
                game: game,
                catalog: catalog,
                askedFor: roundsAskedFor,
                recognitions: { model.activeProfile?.recognitions ?? [:] },
                onFinished: { path.append(.roundEnd($0)) },
            )""",
        ),
    ],
)

edit(
    "apps/ZilpZalp/Sources/RoundEnd/RoundEndScreen.swift",
    [
        (
            """/// ``AppModel/record(_:)`` before it says anything about it, and every claim
/// it makes — a first find, a new rank — is read off the profile written.""",
            """/// ``AppModel/record(_:)`` before it says anything about it, and every claim
/// it makes — a sticker earned above all — is read off the profile written.""",
        ),
        (
            """    /// How long the celebration keeps the screen before the rank ascent
    /// arrives over it: long enough for the sticker to land and the praise to
    /// be said, short enough to still read as one moment. A judgement call
    /// rather than a token — 1e replaces this screen in the design.
    private static let ascentDelay: TimeInterval = 2.2

""",
            "",
        ),
        (
            """    /// Opens the sticker album, and pushes the rank ascent over this screen.
    let openCollection: () -> Void
    let showAscent: (RankAscent) -> Void""",
            """    /// Opens the sticker album.
    let openCollection: () -> Void""",
        ),
        (
            """    /// The ascent has been pushed for this round. `.task` runs again when
    /// the child comes back from the album, and a second "Du bist jetzt eine
    /// Amsel!" would be a second promotion.
    @State private var ascentShown = false

""",
            "",
        ),
        (
            """            // cancellation is what stops the ascent from arriving behind a
            // child who has already tapped on.""",
            """            // cancellation is what stops the praise from landing behind a
            // child who has already tapped on.""",
        ),
        (
            """        RoundEndReward(
            sticker: sticker,
            isFirstFind: isFirstFind,
            isTight: isTight,
            settled: settled,
        )""",
            """        RoundEndReward(
            sticker: sticker,
            earnedSticker: earnedSticker,
            progress: outcome.map { $0.stickerProgress(for: result.celebratedSpecies) },
            isTight: isTight,
            settled: settled,
        )""",
        ),
        (
            """    /// Whether the round put this bird in the album for the first time: read
    /// off the profile as it stood before the round was booked. `false` until
    /// then — one frame of silence beats a claim that was not checked.
    private var isFirstFind: Bool {
        outcome?.isFirstFind(of: result.celebratedSpecies) ?? false
    }

    /// The one sentence this screen says out loud, for the child who cannot
    /// read it. A first find gets its own, so the news is heard as well.
    private var spokenPraise: SpokenLine {
        guard isFirstFind, let sticker else { return .fixed("roundEnd.title") }
        return sticker.praise
    }""",
            """    /// Whether the round earned this bird's sticker — its fifth recognition.
    /// Read off the profiles either side of the write. `false` until then —
    /// one frame of silence beats a claim that was not checked.
    private var earnedSticker: Bool {
        outcome?.earnedSticker(for: result.celebratedSpecies) ?? false
    }

    /// The one sentence this screen says out loud, for the child who cannot
    /// read it. A sticker just earned gets its own, so the news is heard as
    /// well as seen.
    private var spokenPraise: SpokenLine {
        guard earnedSticker, let sticker else { return .fixed("roundEnd.title") }
        return sticker.praise
    }""",
        ),
        (
            """    /// Books the round, then celebrates it: the sticker, the motion, the
    /// sentence said out loud, and — when the round carried the child onto a
    /// new rung — the ascent over the top of it.
    ///
    /// The order matters. Being a first find decides both the caption and the
    /// sentence, so nothing is drawn as new before the profile is written.""",
            """    /// Books the round, then celebrates it: the sticker, the motion and the
    /// sentence said out loud.
    ///
    /// The order matters. A sticker just earned decides both the caption and
    /// the sentence, so nothing is drawn as new before the profile is written.""",
        ),
        (
            """            voice.announce(spokenPraise)
        }

        guard !ascentShown, let ascent = outcome?.ascent else { return }
        // The stars and the sticker get the screen to themselves first: a new
        // rank on top of the praise would take the round away mid-look.
        try? await Task.sleep(for: .seconds(Self.ascentDelay))
        // Flagged only once it is shown: set before the wait, a child who
        // opened the album inside those seconds would have turned "once"
        // into "never".
        guard !Task.isCancelled else { return }
        ascentShown = true
        showAscent(ascent)
    }""",
            """            voice.announce(spokenPraise)
        }
    }""",
        ),
    ],
)

edit(
    "apps/ZilpZalp/Sources/RoundEnd/RoundEndReward.swift",
    [
        (
            """/// The name and the credit are drawn here rather than passed into""",
            """/// Under the name stand the progress markers, so the bird, what it is
/// called and how far it has come are one block that pops in together.
///
/// The name and the credit are drawn here rather than passed into""",
        ),
        (
            """    /// Whether the round put this bird in the album for the first time. Read
    /// off the profile the round was booked onto, so it is `false` until the
    /// screen has written the round down.
    let isFirstFind: Bool""",
            """    /// Whether the round earned this bird's sticker — its fifth recognition
    /// (#177). Read off the profiles either side of the write, so it is
    /// `false` until the screen has written the round down.
    let earnedSticker: Bool

    /// How often this bird has been recognised now that the round is booked,
    /// for the markers under it. `nil` until then, and for a round that could
    /// not be written down — the screen makes no claim it cannot back up, and
    /// a row that filled in a moment later would be a second, quieter reward.
    let progress: Int?""",
        ),
        (
            """                Text(verbatim: caption(for: sticker))
                    .typeStyle(isTight ? .body : .bodyLarge, .display, weight: .bold)
                    .foregroundStyle(ZColor.white)

                Text(verbatim: sticker.credit)""",
            """                Text(verbatim: caption(for: sticker))
                    .typeStyle(isTight ? .body : .bodyLarge, .display, weight: .bold)
                    .foregroundStyle(ZColor.white)

                if let progress {
                    StickerMarkers(
                        count: progress,
                        markerSize: isTight ? Self.compactMarker : Self.regularMarker,
                    )
                }

                Text(verbatim: sticker.credit)""",
        ),
        (
            """    /// The sticker on iPad, the 200 pt of screen 1e and `RewardScreen.jsx`.
    private static let regularSticker: CGFloat = 200""",
            """    /// The sticker on iPad, the 200 pt of screen 1e and `RewardScreen.jsx`.
    private static let regularSticker: CGFloat = 200

    /// The progress markers under it, sized against the disc they belong to:
    /// five markers and their gaps measure about six markers across.
    private static let regularMarker: CGFloat = 24
    private static let compactMarker: CGFloat = 20""",
        ),
        (
            """    /// The pop belongs to a bird met for the first time. One already in the
    /// album is simply there: still shown, still named, but the arrival is
    /// the reward for finding something new.
    private var popped: Bool {
        settled || !isFirstFind
    }""",
            """    /// The pop belongs to a sticker just earned. A bird whose sticker is
    /// already in the album is simply there: still shown, still named, but the
    /// arrival is the reward for having earned it.
    private var popped: Bool {
        settled || !earnedSticker
    }""",
        ),
        (
            """    /// "Amsel gesammelt" for a first find, the bare name otherwise.
    private func caption(for sticker: RoundEndSticker) -> String {
        guard isFirstFind else { return sticker.name }""",
            """    /// "Amsel gesammelt" for a sticker just earned, the bare name otherwise.
    private func caption(for sticker: RoundEndSticker) -> String {
        guard earnedSticker else { return sticker.name }""",
        ),
    ],
)
