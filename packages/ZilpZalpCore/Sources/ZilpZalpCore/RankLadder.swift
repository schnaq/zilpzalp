/// A rank a profile reaches by collecting stars.
///
/// The order runs from the species every child already knows to the rare one,
/// which is also the order of the star thresholds. The raw values are stable
/// identifiers, not display text: the German names live in the app's String
/// Catalog, because this module holds no product strings.
public enum Rank: String, CaseIterable, Hashable, Sendable, Codable {
    case kohlmeise
    case amsel
    case blaumeise
    case rotkehlchen
    case star
    case buntspecht
    case eisvogel
    case wiedehopf

    /// The number of stars from which this rank is reached.
    public var threshold: Int {
        switch self {
        case .kohlmeise: 0
        case .amsel: 25
        case .blaumeise: 60
        case .rotkehlchen: 100
        case .star: 150
        case .buntspecht: 220
        case .eisvogel: 300
        case .wiedehopf: 400
        }
    }
}

/// The ladder of ranks over a profile's collected stars.
///
/// A profile's current rank is not stored anywhere, it is derived from its
/// star count on every read. That way it cannot drift away from the stars that
/// earned it. Both lookups below read `Rank.allCases` as the ladder, so they
/// rely on the thresholds rising strictly with the case order — which a test
/// pins.
public enum RankLadder {
    /// The rank a profile with `stars` stars holds: the highest one whose
    /// threshold it has reached, and `.kohlmeise` below the first threshold.
    public static func rank(forStars stars: Int) -> Rank {
        Rank.allCases.last { $0.threshold <= stars } ?? .kohlmeise
    }

    /// The rank above `rank`, or `nil` for the highest one.
    public static func next(after rank: Rank) -> Rank? {
        Rank.allCases.first { $0.threshold > rank.threshold }
    }

    /// The stars still missing for the next rank, or `nil` once the highest
    /// rank is reached.
    ///
    /// A negative star count counts as none, as it does everywhere else in this
    /// module. Without that the subtraction below would overflow on `Int.min`.
    public static func starsMissing(from stars: Int) -> Int? {
        let stars = max(stars, 0)
        return next(after: rank(forStars: stars)).map { $0.threshold - stars }
    }
}
