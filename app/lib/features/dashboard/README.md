# Dashboard UI

Home replaces the shell placeholder. Mobile reference: Figma Screen Artboards
03.1 (NUST) and 03.2 (default), 390 x 844. Header and cards use logical pixels;
the OS supplies its own status/navigation bars. The existing app navbar stays in place.
Other institutions use the selected institution theme. Quick-action cards share
the tallest card's height; with larger text or touch targets the row scrolls
sideways instead of clipping their contents.

`DASHBOARD_PREVIEW=true` enables the Figma sample name, chart, counts and project.
An entry dialog identifies this as sample data. The sync bar follows the Figma
"Offline / back online banner" frame: the offline bar drops in on entry; tap it to
simulate reconnecting (turns green, spinner, "All synced · just now" check pop,
then folds away and the content moves up). It drops back in 2 s later so it can be
replayed. `SyncBanner` only draws a phase, so the real sync layer can drive it later.
Reduce motion turns all of this into 150 ms fades with no spinner. Nothing is uploaded.

Add `DASHBOARD_LOADING_PREVIEW=true` to inspect the 1.3-second loading shimmer.
It is static with Reduce motion enabled and stops when its tab is inactive.
Neither preview flag is enabled by default. Normal mode shows disconnected/empty
states; no backend data, real search, notifications or consent creation is wired.
Field capture and See all use the existing shell routes.

Icons were exported directly from Figma. The chart (`dashboard_chart.dart`) is
drawn from a list of values in the institution primary colour. Preview mode feeds
it `dashboardSampleActivity` (the Figma bar heights); normal mode shows an empty
state until a consent data source exists. Device screenshot comparison is still
required before declaring visual parity. Desktop retains the existing side rail;
the separate desktop Dashboard artboard is not implemented in this mobile pass.
