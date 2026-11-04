# Media detail and player presentation

Media detail keeps its cinematic artwork and one scrolling page. At widths of at least 1000 logical pixels, its action and rating block sits alongside the synopsis and linked review section; enlarged text returns to the single-column layout. Similar titles use the shared MediaRail and PosterCard preferences. The detail hero reads the hero image-quality preference, resizing recognized TMDB artwork and bounding decoded texture width. Unknown or signed provider URLs are preserved by the shared image helper.

The source picker retains all stream-selection and sorting callbacks. Its filter controls grow with text, and rows use flatter tonal surfaces. Anchored detail/source menus now clamp to safe-area and keyboard bounds, limit their width and scrollable height, and use their measured height to flip above an anchor when the lower space is insufficient. Escape and outside dismissal remain available.

Player side-panel headers separate title/close from navigation actions on narrow widths and allow actions to wrap. Player sheet dialogs bound their size to the visible viewport and keyboard. Theme surfaces and typography are shared with the rest of Cinema; the video canvas, transport control semantics, player engines and callbacks are unchanged.

Widget checks cover directional and enlarged-text menu geometry and the existing episode, source and player panels. Physical-device behavior, native iOS presentation and visual acceptance remain unverified.
