# v7 final48: independent authored evaluation fixture

Created 2026-09-23 after recording the exact SHA-256 values of both native inference Swift files and the model in `final-source.sha256`. This author did not run inference on these cases, inspect their predicted labels, or read the model vocabulary when writing them. Examples were checked only for wording, label consistency, and duplication. The fixture is now fixed; do not tune v7 using its results.

## Composition

| IDs | Category | Count |
| --- | --- | ---: |
| v7-final-001–016 | Longer Japanese noun/modifier phrase before English | 16 |
| v7-final-017–026 | Multiple Japanese/English switches | 10 |
| v7-final-027–032 | English phrases with their internal spaces preserved | 6 |
| v7-final-033–038 | Uppercase acronyms | 6 |
| v7-final-039–044 | Single language: Japanese 3, English 3 | 6 |
| v7-final-045–048 | TeX 2, inline code 1, URL 1 | 4 |

Topics include reading, images, meetings, email, work planning, device connections, and programming. Words were chosen from ordinary author knowledge rather than the model dictionary; whether each word is in or out of vocabulary was deliberately not checked. Consequently no precise OOV count is claimed.

English technical nouns within Japanese follow the product's intended mixed-writing use. Japanese/English boundaries have no inserted helper spaces. Spaces occur only inside intended English spans (multiword phrases or full English sentences). The final URL ends at the end of the input, so the fixture does not require guessing an unmarked URL/Japanese boundary.

## Gold labels and checks

The JSON schema is `id`, `raw`, `japaneseRanges`, `englishRanges`, using zero-based half-open character ranges. Every raw string is ASCII, so byte/code-point/Swift-character offsets agree. Japanese ranges specify romaji that should be converted. English ranges specify literal English, acronyms, English-internal spaces/punctuation, or protected TeX/code/URL syntax. Protected syntax is never Japanese.

`diagnosis/create-final-fixture.py` records the authored segments and creates ranges mechanically. Its checks verify:

- Exactly 48 unique cases with the requested category counts.
- Every range is nonempty, in bounds, and does not overlap a range of the other class.
- Japanese segments contain only lowercase roman letters.
- Spaces appear only inside authored English spans.
- No raw string matches any of 554 distinct prior raw strings found recursively in existing LocalModel JSON artifacts outside accuracy-v7 (including all earlier fixture sets).

Fixture SHA-256: `69e80c4c802e2666b5a9f3802559a10b0fde8a473d4a0161741d02fa801957e4`.

## Limits and reporting

This is a small manually authored set, not a representative population benchmark or a corpus of real user keystrokes. The author knows the task's historical failure categories, so it is independent of predictions on these new cases but not blind to the general problem. Report exact segmentation, English damage during typing, and label reversals separately; a better final score does not prove more stable live input. This fixture does not measure Zenzai's final kanji conversion accuracy, editing/deletion behavior, app compatibility, or latency.

After one frozen-model evaluation, publish the full result, including failures. Any later use to guide fixes turns it into development data and requires a separately authored future final set. Do not present its pass rate as general product accuracy.
