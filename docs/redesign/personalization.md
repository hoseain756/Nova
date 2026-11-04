# Card and artwork personalization

## Settings contract

All new values live in the existing `AppState.webSettings` bucket and use
`AppState.setSetting`, so account sync and local persistence follow the same
path as earlier display preferences. Existing `posterRadius` remains the
single radius key. Missing or invalid new values resolve to the prior medium,
vertical card shape and automatic image quality.

| Key | Values | Default | Use |
| --- | --- | --- | --- |
| `cardSize` | `small`, `medium`, `large` | `medium` | Shared rail and grid geometry |
| `cardOrientation` | `vertical`, `horizontal` | `vertical` | Shared card composition |
| `posterRadius` | 0–28 | 12 | Artwork corners; Sharp sets 0, Rounded sets 18 |
| `heroImageQuality` | `auto`, `low`, `medium`, `high`, `original` | `auto` | Hero and detail artwork |
| `cardImageQuality` | same | `auto` | Posters and direct card thumbnails |
| `heroTrailerAutoplay` | `always`, `wifi`, `never` | `wifi` | Featured trailer policy |

`CardPreferences` and `CardDimensions` in
`lib/core/models/visual_preferences.dart` are immutable. Rails, ranked rows,
catalog grids, Library, Kids, Anime, and Search read their dimensions from the
same helper. The horizontal card puts artwork at the logical start, so it
reverses naturally in Arabic. Grid columns may reduce to one on narrow phones
for horizontal or large cards. `horizontalExtent` includes a scalable text
budget. The settings preview uses `PosterCard` itself and stays above the
scrolling controls. It displays a saved poster when available.

The Card Customization page is linked from Appearance and Display and is a
searchable Settings destination. Its size, orientation, corner presets, radius
slider, and reset act through the existing settings API. The Display page also
offers separate Hero and Card artwork quality selectors and the trailer
autoplay selector. The prior dock auto-hide control is absent because the
redesigned dock remains visible; its persisted key is retained for older data.

## Artwork pipeline

`providerSizedImageUrl` rewrites only HTTPS
`image.tmdb.org/t/p/<known size>/...` URLs. Poster and backdrop roles have
their own valid TMDB size ladders; other add-on, signed, and unrecognized URLs
remain unchanged. `imageCacheWidthForQuality` bounds decode pixels for both
roles, including Original source images, so high source quality does not leave
unbounded textures in memory. `NovaNetworkImage` keeps its stable loading and
error placeholders and disables its fade when MediaQuery disables animations.
Callers pass explicit quality and provider kind for hero/backdrop art; direct
posters use card quality.

An optional `saveCellularData` field exists in the pure preference model for a
future reliable network signal. No cellular switch is shown: the current app
does not yet expose one app-wide to every card consumer.

## Verification boundary

`test/visual_preferences_test.dart` covers defaults, invalid/legacy values,
grid sizes, provider URL boundaries, independent quality values, persistence,
and card direction in light/dark themes. Source checks and widget tests do not
prove CDN bandwidth, physical-device memory use, or visual quality on a device.

Kids defaults to the shared size. Because older data stored `medium` even when
the user never chose it, that legacy value now means inherit; a new explicit
Medium override stores `mediumOverride`. Existing Small/Large overrides remain.
The grid and PosterCard receive the same resolved preferences, including global
orientation/radius. Horizontal watchlist cards receive finite grid-cell widths.
The radius slider updates the live preview during dragging and uses localized
units. Navigation previews use the actual platform Flutter dock; wide sidebars
and native iPhone tabs retain their platform presentation.
