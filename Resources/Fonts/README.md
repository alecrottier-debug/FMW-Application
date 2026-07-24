# Fonts

The design tokens in `App/DesignSystem/DesignTokens.swift` reference two custom families:

- **Fraunces** (display) — headings, via `FMW.display(_:_:)`
- **Figtree** (UI) — body / labels, via `FMW.ui(_:_:)`

Until the `.ttf` files are added here, SwiftUI **silently falls back to the system font**
(no crash, no build failure) — which is why the scaffold builds today.

To bundle the real fonts:

1. Drop the `.ttf` files into this folder (e.g. `Fraunces-Regular.ttf`, `Figtree-Regular.ttf`,
   plus the weights you use).
2. Register each filename under `UIAppFonts` in the `info.properties` block of `project.yml`
   (which regenerates `Config/Info.plist`).
3. Run `xcodegen generate`.

Fonts are copied into the app bundle automatically — `Resources/` is a source path in
`project.yml` (only `*.md` files, like this one, are excluded).

- Fraunces: https://fonts.google.com/specimen/Fraunces
- Figtree:  https://fonts.google.com/specimen/Figtree
