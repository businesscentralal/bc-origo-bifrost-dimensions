# Extension: Bifrost Dimensions

## Customer
Origo / AppSource

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.Dimensions` namespace)

## Namespace
Origo.Bifrost.Dimensions (tests: Origo.Bifrost.Dimensions.Test)

## Object ID Range
App:   10076485-10076534
Tests: 98300-98399

| Type | ID | Name |
| --- | --- | --- |
| Codeunit | 10076485 | Dimensions Registration ori |
| Permission set | 10076486 | BIFROST DIM ori |
| Permission set | 10076487 | BIFROST DIMFull ori |
| Permission set | 10076488 | BIFROST DIMRead ori |
| Permission set extension | 10076489 | Dimensions Full Role ori |
| Permission set extension | 10076490 | Dimensions Read Role ori |
| Enum extension | 10076491 | Dimensions Message Type ori |
| Test codeunit | 98300 | Dimensions Scaffold Tst ori |
| Test permission set | 98301 | Dim Setup Test ori |

Every new object is added to this table in the same PR.

## Product scope (epic businesscentralal/bifrost-support#44, Gunnar's request 27.11.2026)
- Correct dimensions on posted entries and documents through Bifröst message types: find posted entries and documents
  by their dimensions, preview a correction with validation, run it with a correction log, and undo it.
- Combines two sources: Origo Dimension Correction and Microsoft Dimension Correction.
- **Message types only, no pages or other UI in the product app.** A future setup is a message type, not a page.
  The test app may keep test-only helpers.

## Setup Notifications
Setup notifications live **only** on Bifröst Foundation's `Setup ori` page. This app never raises a `Notification` of its own.
It registers with Foundation through `App Registry ori.OnRegisterApps` (`app/src/Common/DimensionsRegistration.Codeunit.al`).

## Target BC Version
28.0 (application 28.0.0.0, platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-dimensions
Default branch: main

## Dependencies
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.16.0)

App ID `a28df59b-665a-4e29-a84b-8fa4de15eec1`, test app ID `b5c614e9-7a4c-4a12-a568-57aeb3f9ee50`.

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix), max 30 characters; permission set names max 20.
- Message type names have three parts: `Domain.Entity.Action`, domain `Dimensions`.
- Icelandic captions use "Bifröst" and "víddir" for dimensions.

## Development Standards
This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
Before writing any AL code, load `origo-bc-al-coding-standards`, `origo-bc-test-writer`, `origo-bc-documentation-writer`.
- Namespace at the top of every file; XML documentation on every object and non-local procedure
- Bilingual captions (en-US + is-IS) via `Comment = 'is-IS=...'`; regenerate `app/Translations/Bifrost Dimensions.is-IS.xlf` with `tools/Update-IcelandicXlf.ps1`; no en-US XLF
- Implementation = code + tests + documentation (contract chapters of `Msg Contract ori`)

## Message Type Conventions
- One enum extension of Foundation's `Message Type ori`; keys are the published API contract and are never renamed.
- Each type has an Impl codeunit implementing `Msg Interface ori`, `Msg Discovery ori` and `Msg Contract ori`.
- Help text is public: no customer names, tenant ids, internal hosts or credentials.

## Test App Rules
- Unit tests never need credentials.
- Every message type is tested in languages 1033 and 1039.
