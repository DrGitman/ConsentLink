# Loading skeletons (Figma row 11)

Figma Screen Artboards 11.1–11.8 (`3:14790` … `3:15623`).

- `skeleton.dart`: `Bone`, `BoneCard` (Figma positions in a 350 dp card),
  `SkeletonShimmer` (1.3 s band, 140 dp, tilted 12°), `SkeletonSwitch`
  (300 ms delay, 3 s "why" note, 200 ms fade to content, one screen-reader
  announcement) and `PreviewLoad`.
- `screen_skeletons.dart`: one layout per screen — Dashboard, Projects,
  Project detail, Review AI draft, Insights, Template library, Consent
  record, Me.

Headers, back buttons, chips, footers and the tab bar stay real and usable.
Reduce motion: static blocks, no shimmer. Field capture never shows
skeletons (forms are already on the phone).

Data on the phone loads instantly, so skeletons only show when something is
slow. To check them: `--dart-define=LOADING_PREVIEW=true` (each screen
pretends to load for `LOADING_MS`, default 2000; use 4000 to see the 3 s
note).
