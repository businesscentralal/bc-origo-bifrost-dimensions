# Changelog

All notable changes to Bifrost Dimensions are documented here.

## [Unreleased]

### Fixed
- Ordered the permission-test variables in codeunit 98320 to remove CodeCop warning AA0021.
- Setup messages read Microsoft dimension tables through scoped indirect permissions without extending foreign table grants. Threshold numbers outside the Decimal range return `InvalidParameterFormat` without saving changes.

### Added
- Dimensions.Setup.Get / Dimensions.Setup.Set (#2, story D6): per-company dimension correction setup through message types only. Get returns `backgroundThreshold` (default 500), `requireReason` (default true) and the union of blocked dimensions with `source` `bifrost` or `microsoft` (Microsoft's Base App table 2580 "Dim Correction Blocked Setup", read only). Set changes only the values sent, validates every code before writing, replaces the whole Bifrost blocked list, never writes Microsoft's list and is idempotent. Get is in BIFROST DIMRead ori, Set in BIFROST DIMFull ori. Objects: table 10076495 "Dimension Corr. Setup ori", table 10076496 "Dim. Corr. Blocked Dim. ori", codeunit 10076497 "Dim Setup Get Impl ori", codeunit 10076498 "Dim Setup Set Impl ori", codeunit 10076499 "Dim Setup Msg Mgt ori", enum values 10076495-10076496 on "Message Type ori"; test codeunit 98320 "Dim Setup Msg Tst ori".
- `Dimensions.Entries.Find` (read): finds posted ledger entries and posted documents by target, document no., posting date, source no., current dimensions (`value: ""` = missing) or explicit keys, with `maxRows`, `truncated`, document lines through `includeLines`, and a no-target search by document no. grouped by table; typed errors with next steps; help with Icelandic keywords. Objects: enum extension value 10076492, codeunits 10076493 (Dim Target Registry) and 10076494 (Dimensions Find Impl), enum and interface `Dim. Correction Target ori` (10076492), tests 98302 (issue #1).
- Supported-table registry `Dim. Correction Target ori`: 17 ledgers and 17 posted document types (header and lines); a table of an absent optional app is skipped silently.
- Repository scaffold: app registration with Bifröst Foundation, Bifrost Dimensions permission sets wired into the Foundation Full and Read roles, an empty message type enum extension, AL-Go CI/CD and source guards (epic businesscentralal/bifrost-support#44).
