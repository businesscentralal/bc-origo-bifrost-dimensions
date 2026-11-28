# Changelog

All notable changes to Bifrost Dimensions are documented here.

## [Unreleased]

### Added
- `Dimensions.Entries.Find` (read): finds posted ledger entries and posted documents by target, document no., posting date, source no., current dimensions (`value: ""` = missing) or explicit keys, with `maxRows`, `truncated`, document lines through `includeLines`, and a no-target search by document no. grouped by table; typed errors with next steps; help with Icelandic keywords. Objects: enum extension value 10076492, codeunits 10076493 (Dim Target Registry) and 10076494 (Dimensions Find Impl), enum and interface `Dim. Correction Target ori` (10076492), tests 98302 (issue #1).
- Supported-table registry `Dim. Correction Target ori`: 17 ledgers and 17 posted document types (header and lines); a table of an absent optional app is skipped silently.
- Repository scaffold: app registration with Bifröst Foundation, Bifrost Dimensions permission sets wired into the Foundation Full and Read roles, an empty message type enum extension, AL-Go CI/CD and source guards (epic businesscentralal/bifrost-support#44).
