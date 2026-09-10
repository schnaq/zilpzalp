# Kids Category — App Review Guidelines Research

Reference document for issue #19. Answers the five open questions from
[docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md](superpowers/specs/2026-08-01-zilpzalp-v1-design.md)
§7 against current primary sources. All quotes retrieved 2026-08-02 by
fetching the live pages directly (curl) or via their JSON data endpoint,
not from search-result summaries, unless noted otherwise.

## 1. Guideline 1.3 (Kids Category) and 5.1.4 (Kids) — exact wording

**Finding.** Both sections are short and both are currently in force as
quoted below. 1.3 is the operative section for Kids-Category-specific
behavior (parental gates, no third-party analytics/ads, no PII to third
parties). 5.1.4 is about *personal data from minors* generally — it
applies to any app that touches children's data, not only Kids Category
apps — and cross-references 1.3 for its own third-party carve-outs. Two
adjacent guidelines matter too: 2.3.8 (metadata) and the note in 5.1.4(b)
that the parental-gate requirement is a different thing from COPPA/GDPR
consent.

**Guideline 1.3 — Kids Category** (verbatim):

> "The Kids Category is a great way for people to easily find apps that
> are designed for children. If you want to participate in the Kids
> Category, you should focus on creating a great experience specifically
> for younger users. These apps must not include links out of the app,
> purchasing opportunities, or other distractions to kids unless
> reserved for a designated area behind a parental gate. […] You must
> comply with applicable privacy laws around the world relating to the
> collection of data from children online. […] Kids Category apps may
> not send personally identifiable information or device information to
> third parties. Apps in the Kids Category should not include
> third-party analytics or third-party advertising. This provides a
> safer experience for kids. In limited cases, third-party analytics may
> be permitted provided that the services do not collect or transmit
> the IDFA or any identifiable information about children […] Third-party
> contextual advertising may also be permitted in limited cases provided
> that the services have publicly documented practices and policies for
> Kids Category apps that include human review of ad creatives for age
> appropriateness."

Source: [App Review Guidelines §1.3](https://developer.apple.com/app-store/review/guidelines/#kids-category), retrieved 2026-08-02.

**Guideline 5.1.4 — Kids** (verbatim):

> "(a) […] Apps intended primarily for kids should not include
> third-party analytics or third-party advertising. This provides a
> safer experience for kids.
>
> (b) In limited cases, third-party analytics and third-party
> advertising may be permitted provided that the services adhere to the
> same terms set forth in Guideline 1.3. Moreover, apps in the Kids
> Category or those that collect, transmit, or have the capability to
> share personal information […] from a minor must include a privacy
> policy and must comply with all applicable children's privacy
> statutes. For the sake of clarity, the parental gate requirement for
> the Kid's Category is generally not the same as securing parental
> consent to collect personal data under these privacy statutes.
>
> As a reminder, Guideline 2.3.8 requires that use of terms like 'For
> Kids' and 'For Children' in app metadata is reserved for the Kids
> Category."

Source: [App Review Guidelines §5.1.4](https://developer.apple.com/app-store/review/guidelines/#kids), retrieved 2026-08-02.

**Guideline 2.3.8** (verbatim, the metadata point 5.1.4 refers to):

> "Metadata should be appropriate for all audiences, so make sure your
> app and in-app purchase icons, screenshots, and previews adhere to a
> 4+ age rating even if your app is rated higher. […] Use of terms like
> 'For Kids' and 'For Children' in app metadata is reserved in the App
> Store for the Kids Category."

Source: [App Review Guidelines §2.3.8](https://developer.apple.com/app-store/review/guidelines/#metadata), retrieved 2026-08-02.

**Consequence for ZilpZalp.** Nothing here contradicts the repo's stance
of zero third-party SDKs — ZilpZalp is already stricter than the
guideline requires (it bans third-party analytics/ads outright, where
1.3/5.1.4 would even tolerate narrowly-scoped ones). The 5.1.4(b) note
that the parental gate is *not* the same as COPPA/GDPR consent is largely
moot for us: ZilpZalp collects no personal data at all (#37), so no
consent flow is needed in the first place — only the 1.3 parental gate
for link-outs applies. 2.3.8 is a direct requirement for store assets
(#41): icons/screenshots must already read as 4+-appropriate, which they
will by construction given the target audience.

---

## 2. Parental gate for external links — what must be gated, what counts

**Finding.** The canonical page is `/kids/` (the guideline's own "Learn
more about parental gates" link at `/app-store/kids-apps/` 301-redirects
there — verified via `curl -I`). It defines a parental gate as a
**task**, not an authentication check:

> "Provide parental gates: These are adult-level tasks that must be
> completed in order to continue using your app or game. Parental gates
> aim to prevent kids from engaging in certain activities without their
> parent's knowledge — such as buying In-App Purchases without
> permission, or following link outs to content outside of your app or
> game (such as external websites, social networks, or other apps). If
> your app is intended for pre-literate children, consider using a
> voiceover prompt to help kids know that they need to involve their
> parent."

The only two gate mechanisms the page illustrates (image alt text,
extracted verbatim from the page source):

> "Example of a parental gate task." / "An example of a parental gate
> task that requires math." / "An example of a parental gate task that
> requires answering a question."

Source: [The Kids Category](https://developer.apple.com/kids/), retrieved 2026-08-02.

**What must be gated**, per the same page and 1.3: link-outs and
in-app-purchase opportunities. (An earlier search-engine snippet also
listed "request permissions" as gated behind a parental gate; that
phrase does **not** appear in the live `/kids/` page text, so it is not
used here as a citable requirement. Moot for ZilpZalp regardless — no
camera, microphone, location, or notification permissions are requested.)

**Is Face ID / `LAContext` an acceptable gate?** This is genuinely
ambiguous, and the ambiguity is load-bearing for #37:

- Apple's documentation never mentions Face ID, Touch ID, biometrics, or
  a device passcode anywhere on `/kids/` or in Guideline 1.3 (checked by
  full-text search of the fetched page; the string does not occur).
- This is an **absence of documentation, not a stated prohibition** — no
  primary source says "biometrics are disallowed."
- Conceptually, the two mechanisms test different things. A math or
  question-answer task tests whether the person attempting it is
  cognitively an adult — the thing Apple is trying to gate on. Device
  owner authentication (`LAContext` with `deviceOwnerAuthentication`,
  as already chosen for the app in §5 of the spec) tests whether the
  person is *the enrolled device owner* — on a shared family iPad, that
  is frequently also the child, or a child old enough to know the
  passcode fallback. Apple explicitly anticipates pre-literate children
  on this same page and still prescribes a task (with a voiceover
  prompt) rather than offering biometrics as the accessible alternative.

**Consequence for ZilpZalp (#37).** The current plan — "Parental Gate
vor jedem externen Link. Umsetzung über dasselbe `LAContext`-Schloss wie
der Elternbereich" — reuses one mechanism for two different jobs and
should be split:

- **Keep** the `LAContext` lock on the Elternbereich itself (settings,
  package management, time budget). Guideline 1.3 requires gating
  link-outs, purchases, and "other distractions" — it does not require
  gating a settings area, so this is an unobjectionable access-control
  choice either way.
- **At the moment an external URL is about to open** (the public „Über
  ZilpZalp" screen — privacy policy, website, support address — and the
  credits it pushes, with their source and licence links), add a
  task-based gate — a short math or question-answer challenge, with a
  voiceover prompt, matching the documented pattern exactly. Do not
  rely on `LAContext` alone to satisfy 1.3 for this specific action;
  treat it as unverified against App Review until tested, and design
  the cheap fallback (task gate) in from the start rather than
  retrofitting it after a rejection.

---

## 3. `PrivacyInfo.xcprivacy` for a first-party-only, no-collection app

**Finding.** Three separate declarations are involved; ZilpZalp's answer
differs per declaration and depends partly on implementation details
still to be written (#33).

**a) Is fetching your own content "data collection"?** No — the
manifest documentation defines collection directionally, about the
*person*, not about content flowing to the device:

> "Record the categories of data that your app or third-party SDK
> collects **about the person using the app**, and the reasons it
> collects the data."

Source: [Describing data use in privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests), retrieved 2026-08-02 (via page's JSON data endpoint, since the rendered HTML is a client-side SPA shell).

Downloading `packs/index.json`, images, and audio from `zilpzalp-media`
is content moving *to* the device, carrying no user- or device-derived
data in the request beyond what any HTTPS GET implies. Concretely:
`NSPrivacyTracking = false`, `NSPrivacyTrackingDomains = []`,
`NSPrivacyCollectedDataTypes = []`.

**b) Required Reason APIs.** There are exactly five categories (verified
by counting the enum's `possibleValues` in the live doc — no sixth
category exists as of this retrieval). Networking via `URLSession` is
not one of them, so the download itself needs no declaration. Two of the
five are realistic for `PackDownloader`, and both are conditional on
what the implementation actually does:

> `NSPrivacyAccessedAPICategoryFileTimestamp`, reason **`C617.1`**:
> "Declare this reason to access the timestamps, size, or other metadata
> of files inside the app container, app group container, or the app's
> CloudKit container."

> `NSPrivacyAccessedAPICategoryDiskSpace`, reason **`E174.1`**: "Declare
> this reason to check whether there is sufficient disk space to write
> files, or to check whether the disk space is low […] There is an
> exception that allows the app to avoid downloading files from a
> server when disk space is insufficient."

Source: [`NSPrivacyAccessedAPIType`](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), retrieved 2026-08-02 (via JSON data endpoint).

If `PackDownloader` verifies files purely by SHA-256 content hash (as
the spec describes — §3, "prüft jede Datei gegen ihren SHA-256"), no
`FileTimestamp` declaration is needed. It becomes necessary only if
resume/cache logic later reads `contentModificationDateKey` or
`FileManager.attributesOfItem` timestamps. Likewise, `DiskSpace`/
`E174.1` is needed only if the downloader checks free space before
writing — a real possibility for a bounded-size device. Both are a
one-line manifest addition to make **when and if the code does that**,
not something to pre-declare speculatively.

**c) UserDefaults.** Not currently planned (spec §3 uses a Codable-JSON
store behind an actor, not `UserDefaults`). If that changes, reason
`CA92.1` ("access user defaults to read and write information that is
only accessible to the app itself") applies.

**Consequence for ZilpZalp (#33, #37).** `PrivacyInfo.xcprivacy` can
truthfully declare zero data collection and zero tracking regardless of
the S3 downloads — "fetching content is not data collection" is
supported by the primary source, not just plausible. The
`NSPrivacyAccessedAPITypes` array is not decidable in the abstract; write
it against the actual `PackDownloader`/`ProfileStore` code once built,
using the two conditional reasons above as the checklist. The separate
App Store Connect "privacy nutrition label" (App Privacy Details) should
also come out empty, and Xcode's generated privacy report (Product ▸
Archive ▸ Generate Privacy Report) is the tool to cross-check it against
the manifest before submission (#41).

---

## 4. Age rating system after the 2025 changes

**Finding.** Two distinct settings exist, and issue #41 needs both.

**a) Store-wide age rating bands** were expanded from four to five in
2025:

> "The updated age rating system adds 13+, 16+, and 18+ to the existing
> 4+ and 9+ ratings. […] Please provide responses to the updated age
> rating questions for each of your apps by January 31, 2026, to avoid
> an interruption when submitting your app updates in App Store
> Connect."

Source: [Updated age ratings in App Store Connect](https://developer.apple.com/news/?id=ks775ehf) (published 2025-07-24), retrieved 2026-08-02. The January 31, 2026 deadline has already passed as of this writing — the new questionnaire is simply part of ordinary submission now, not an upcoming change.

**b) To display in the Kids Category**, the calculated rating must land
on 4+ or 9+, then be explicitly overridden to "Made for Kids":

> "If your calculated rating is 4+ or 9+ and you want your app to also
> display in the Kids category on the App Store, under Age Categories
> and Override, choose Made for Kids and from the menu, select the
> appropriate age range for your app. You can't change this selection
> once your app is approved by App Review. The app and all subsequent
> updates will need to follow the Kids category guidelines. Note: You
> can't select the Made for Kids option for visionOS apps, and apps in
> the Kids category can't be made available on visionOS apps."

Source: [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/), retrieved 2026-08-02.

**c) A second, Kids-Category-specific age band** is set separately in
App Store Connect, independent of the 4+/9+/13+/16+/18+ store-wide
scale:

> "Select an age band in App Store Connect: Choose whether your app or
> game is appropriate for ages 5 and under, 6-8, or 9-11."

Source: [The Kids Category](https://developer.apple.com/kids/), retrieved 2026-08-02.

**Consequence for ZilpZalp (#41).** Two settings to configure, not one:
answer the age-rating questionnaire (expect a calculated 4+ given no
objectionable content), then apply the "Made for Kids" override, then
separately pick the Kids-category age band — most plausibly "6-8" given
that ZilpZalp targets pre-reading children who are nonetheless old
enough to operate a touchscreen quiz unassisted. The "can't change this
selection once approved" line means this choice should be deliberate
before the first submission, not iterated on. No visionOS build is
possible while in the Kids Category — consistent with the spec's
existing macOS-via-"Designed for iPad" plan, which doesn't touch
visionOS anyway.

---

## 5. Is MetricKit acceptable in the Kids Category?

**Finding — this is an inference, not a quotation.** No primary source
names MetricKit, or any first-party framework, in relation to the Kids
Category. The reasoning chain, built from what *is* documented:

- 1.3 and 5.1.4 restrict **third-party** analytics/advertising and
  **transmission to third parties** — they do not restrict analytics or
  diagnostics as such (§1 above, verbatim).
- `MetricKit` is a first-party Apple framework. Its payloads
  (`MXMetricManagerSubscriber`) are delivered directly to the app's own
  code, once daily, on-device — there is no embedded third-party SDK and
  no default off-device transmission at all; what the app does with the
  payload afterward is the app's own choice.
- Crash reports visible in Xcode Organizer arrive through a separate,
  also first-party path: Apple's own device-level "Share With App
  Developers" analytics opt-in, symbolicated against dSYMs the developer
  uploads to App Store Connect. No SDK is embedded in the app for this
  either.

**Consequence for ZilpZalp.** The spec's existing plan ("Abstürze werden
ausschließlich über Apples eigenes MetricKit und den Xcode Organizer
sichtbar") fits the letter of 1.3/5.1.4 as written — both mechanisms are
first-party with no data going to a third party. The one residual
condition, not covered by any source above: if ZilpZalp's own code ever
took a `MetricKit` payload and forwarded it somewhere off-device (e.g. to
a self-hosted backend), *that* transmission would need its own privacy
assessment — MetricKit's first-party status doesn't launder a
subsequent third-party hop. Not a concern for the app as currently
planned, since no such forwarding exists.
