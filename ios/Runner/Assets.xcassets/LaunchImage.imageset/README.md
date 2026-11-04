# NOVA native launch artwork

`NovaLaunch@1x.png`, `@2x.png` and `@3x.png` contain the centered red mark and
original white wordmark on a transparent 288pt canvas. The storyboard supplies
the Nova Ink background. These are generated from the supplied SVG paths by
`tool/generate_nova_launch.cjs`, alongside the matching Android vector and
`assets/brand/splash/nova_launch.svg`.

The native screen stays visible through Flutter initialization using
`deferFirstFrame` / `allowFirstFrame`. There is no Flutter splash route or fixed
animation delay. Initialization failures release it into the localized retry UI.

Launch artwork intentionally uses the same Ink canvas in all OS themes. The
first Flutter screen restores the user's saved app theme, including OLED.
