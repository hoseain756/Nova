# Stage 4 — media detail functional chrome

Source snapshot: `feature/player-reengineering` at `2ec313bfd18dc72de3281c999ab5207c3cd23d38` before Stage 4 edits, 2026-10-23. The worktree already contained Stage 1–3 and unrelated changes. No commit or push was made. This record is source-level evidence only: **IOS BUILD PENDING CODEMAGIC** and **IOS RUNTIME PENDING**.

## Detail audit and decision

| Detail surface | Current owner and behavior | Class | Stage 4 result |
|---|---|---|---|
| Back | `DetailBackPill` calls Flutter `Navigator.maybePop` | NATIVE | iOS 26 phone gets a system glass button that reports `detail.back`; Flutter still decides whether to pop. Flutter pill remains for every fallback and until native presentation succeeds. |
| Share | `DetailActionRow` calls `_share`, which uses `share_plus` and its existing clipboard fallback | NATIVE | Top native button reports `detail.share`; `_share` and share payload remain Flutter-owned. Disabled while the item has no title. |
| More menu | `DetailActionRow` has a Flutter `PopupMenuButton` with `sources`, `list`, and conditional `track` | NATIVE | A bounded native `UIMenu` reports `detail.sources`, `detail.list`, or `detail.track`. Labels and enabled state are supplied by Flutter. Selection opens the existing Flutter flow. |
| Favorite/watchlist | In-content `OutlinedButton` toggles `AppState.toggleWatchlist` | KEEP | Remains in the content row with Flutter persistence and state. |
| Play/resume | In-content primary button invokes `_play` | KEEP | Player entry and source selection remain Flutter. |
| Download | In-content icon starts `_download`, hidden in Kids mode | KEEP | Download flow remains Flutter. |
| Trailer | No separate top-level trailer control in this detail implementation | KEEP | No new action invented. |
| Episode long press | `_showEpisodeActions` Flutter sheet | DEFER | Episode state and sheet remain Flutter. |
| Source, custom list, anime tracker flows | `_play`, `showCustomListPicker`, `showAnimeTrackerSheet` | KEEP | Native menu only chooses a stable intent; these workflows stay Flutter. |
| Artwork, metadata, synopsis, episodes, similar content | `DetailHero`, `CinematicCoverScroll`, detail slivers | KEEP | Flutter content and layout unchanged. |

## Presentation and action contract

The existing `nova/ios_chrome/v1` snapshot gains one optional `detail` object with localized back/share/more labels, `shareEnabled`, and a bounded list of menu IDs, labels and enabled flags. No arbitrary callback or widget description crosses the channel. `MainShell` still owns the sole `IosChromeBridge`; `DetailChromeRegistry` holds route-keyed Flutter handlers and presentation data. The same monotonically increasing snapshot revision covers tabs, Home search and detail. Dart rejects old revisions, unknown IDs and disabled actions. Swift creates actions only for its explicit ID-to-SF-Symbol map. Swift does not pop a route, construct share data, select sources, write watchlist state, or open a Flutter sheet.

| Stable ID | Flutter owner | Native presentation | Behavior |
|---|---|---|---|
| `detail.back` | `Navigator.maybePop` in `MediaDetailPage` | Leading glass button, `chevron.backward` | Ask Flutter to pop current detail. |
| `detail.share` | `_share` in `MediaDetailPage` | Trailing glass button, `square.and.arrow.up` | Existing `share_plus` flow; disabled without title. |
| `detail.sources` | `_play` in `MediaDetailPage` | `UIMenu` action, `square.stack` | Opens existing Flutter source/play flow; disabled during stream load or without title. |
| `detail.list` | `showCustomListPicker` | `UIMenu` action, `list.bullet` | Opens existing Flutter picker. |
| `detail.track` | `showAnimeTrackerSheet` | Conditional `UIMenu` action, `chart.line.uptrend.xyaxis` | Present only when item IDs and a linked AniList/MAL account permit it. |

The native `detail.more` accessibility identifier names the button, not an action intent. The existing `search` intent and five tab IDs are unchanged.

## Route, scene and fallback behavior

The shell's `NavigatorObserver` tracks the top route. Each detail page registers against its own `ModalRoute`; only an entry matching the current top route can appear or dispatch. A pushed player, another detail, or a Flutter modal removes detail chrome in the next snapshot; popping restores the appropriate registered route. Item replacement refreshes the detail data and registration. The shell publishes inactive state on app backgrounding and republishes on resume. Scene disconnect removes the UIKit overlay; scene state and buttons remain in the existing `SceneDelegate`, not a global native singleton.

On a detail route the snapshot hides the Stage 2 tab bar and Stage 3 Home search entry. The native detail buttons use the same sibling overlay over the existing `FlutterViewController`; their Auto Layout constraints use the overlay's `safeAreaLayoutGuide`, leading/trailing anchors, and a 48-point touch area. UIKit receives explicit RTL and light/dark state. Standard buttons and menu actions provide system accessibility and material behavior, subject to runtime proof. The Flutter back/share/more controls stay visible until the native snapshot succeeds, and return if publishing fails.

iOS 15–17, iOS 18–25, Android and iPad keep the Flutter controls. At Stage 4, iOS 26 native detail chrome required the existing phone capability, a width below 840 dp, and the app's Reduce Transparency preference to be off. **Stage 6 superseded the width rule:** a confirmed UIKit phone idiom now keeps phone chrome in wide iPhone landscape, while iPad still uses Flutter. The preference retains Flutter detail controls. No PlatformView, native navigation controller, second Flutter engine, third-party material package, player code, source picker implementation or settings migration was added. The deployment target stays iOS 15.0. `codemagic.yaml` is unchanged.

## Remaining proof

Compile with the pinned Codemagic/Xcode 26 SDK after the approved migration stages. On actual iOS 26 phones verify portrait/landscape, notch/Dynamic Island, Arabic/English and in-app language changes, light/dark, VoiceOver order and disabled menu semantics, Dynamic Type, Increase Contrast, Reduce Motion/Transparency, native menu dismissal on route change, nested details, deep links, app background/resume, scene reconnect, share sheet and Flutter modal layering, and tab/search absence on detail. Run older iOS and iPad fallback checks and Android regression checks. These are **IOS BUILD PENDING CODEMAGIC** and **IOS RUNTIME PENDING**; no native success or performance improvement is claimed.

## Windows verification

The final full-project analyzer passed with no issues (58.2 s). The focused bridge/widget suite passed 12/12. Formatting, source-level Swift/API/availability inspection, Stage 4 trailing-whitespace scan and `git diff --check` passed. Exact commands and limits are in `09_TESTING_STRATEGY.md`. No Codemagic workflow, native iOS compiler, simulator or physical iOS device was used.
