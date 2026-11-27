# Bifröst Dimensions

**App name:** Bifrost Dimensions
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.0, runtime 17.0)
**App ID:** `a28df59b-665a-4e29-a84b-8fa4de15eec1` — **Test app ID:** `b5c614e9-7a4c-4a12-a568-57aeb3f9ee50`
**Object ID range:** 10076485–10076534 (tests 98300–98399) — **Namespace:** `Origo.Bifrost.Dimensions`

Bifrost Dimensions corrects dimensions on posted entries and documents through Bifröst message types. The message types
find posted entries and documents by their dimensions, preview a dimension correction with validation, run it with a
correction log, and undo it. It combines the two Business Central sources for this work: Origo Dimension Correction and
Microsoft Dimension Correction. **Message types only, no UI:** the app has no pages, and assistants and integrations
use the message types.

**Status:** scaffold. The message types are built under epic businesscentralal/bifrost-support#44.

Foundation discovers this app on **Bifrost Setup** through its application registry. Assign `BIFROST DIM ori`,
`BIFROST DIMFull ori` or `BIFROST DIMRead ori` alongside the appropriate Foundation role. The object allocation is
recorded in [.claude/CLAUDE.md](.claude/CLAUDE.md).
