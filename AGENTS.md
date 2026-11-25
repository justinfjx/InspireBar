# Repository Guidelines

## Project layout

- `Sources/CodexBar`: Swift 6 macOS menu bar app. Use AppKit for the status item and screen-bounded drop-down window, and SwiftUI for its content. Keep the CodexBar card and chart helpers where they fit InspireBar.
- `Sources/CodexBarCore`: Point balances, billing snapshots, and weekly pace. Store ledgers in integer hundredths of a point and calculate reset windows in UTC+8.
- `Sources/CodexBar/Resources/InspireReader`: Read-only Inspire SDK collector. Pin the active CLI account for each refresh and keep archives isolated by account.
- `Tests`: Swift Testing cases and Python standard-library tests. Keep fixtures synthetic and names fictitious.

## Build, run, and verify

- `make start` builds and opens this checkout's `InspireBar.app`. `make stop` targets that executable path only. Leave any existing CodexBar installation running.
- `make test-fast FILTER=InspireQuotaTests` runs focused Swift tests; `make test` runs the offline Swift and Python suites. Reuse incremental builds.
- Run `make check` after changes, using the pinned repository-local SwiftFormat and SwiftLint from `Scripts/install_lint_tools.sh`.
- `Scripts/package_app.sh release` creates the locally signed bundle. GitHub CI builds/tests; generated upstream release artifacts are kept as historical files.
- Exercise AppKit wiring against the freshly built bundle when the change requires it. Confirm the status item is onscreen before trying a menu-bar click.
- Use an existing authorized Inspire CLI session only for requested live checks. Never trigger a macOS Keychain prompt or copy CLI credentials into app data.
- See [development notes](docs/DEVELOPMENT.md) for an isolated live probe and archive import.

## Style and changes

- Swift: four spaces, 120 columns, explicit `self`, concise typed declarations, `@Observable` models and Swift Testing sentence-style names. Avoid adding dependencies without confirmation.
- Keep balance, billed usage, and instance rate separate. Apply the weekly forecast to the public research project only.
- Keep checks scoped to the consequences of the change. PRs should list the evidence and include a screenshot when the UI changes.
