# v8 final48 — fixed after candidate freeze

The current two native inference Swift files and model were hashed to `final-source.sha256` before these examples were authored. All three hashes were verified unchanged after authoring and gold review. No inference, model vocabulary lookup, or predicted-label inspection was performed for this fixture. The author only used natural-language intent, raw text, and gold spans.

## Composition

| IDs | Category | Count |
| --- | --- | ---: |
| v8-final-001–012 | Japanese verb-ending modifier + English | 12 |
| v8-final-013–024 | English phrases retaining internal spaces | 12 |
| v8-final-025–036 | Multiple Japanese/English switches | 12 |
| v8-final-037–042 | Pure Japanese 3, pure English 3 | 6 |
| v8-final-043–048 | TeX 2, inline code 2, URLs 2 | 6 |

Topics include travel reservations, home devices, photography, reading, work communication, and programming. English vocabulary was chosen without checking whether it exists in the model dictionary. No OOV percentage is claimed. No spaces were added at Japanese/English boundaries; spaces inside English phrases, full English sentences, TeX, and code are intentional. Both URLs end at the end of the raw input, avoiding an undefined URL/JP boundary.

## Gold authoring and second review

`diagnosis/create-final-fixture.py` contains all 48 intended Japanese/mixed sentences and their individually authored Japanese/English segments. It generates the existing `id/raw/japaneseRanges/englishRanges` schema. Ranges are zero-based half-open character intervals; every raw string is ASCII, so Swift grapheme, Unicode code-point, and byte offsets coincide.

After the first generation, the author reread all 48 intended sentences and every Japanese and English segment, independently of inference. In particular, English spellings were checked against the Japanese spans to avoid repeating the previous `source` annotation error. No such English-spelling contamination was identified. Awkward wording about a refund inquiry and music volume was clarified before any inference or handoff. This was a second pass by the same author, not an independent human annotator.

The checks cover:

- Exactly 48 cases and the requested category counts.
- Unique IDs and raw strings, with no duplicate among 602 prior distinct raw strings collected from existing LocalModel JSON artifacts outside accuracy-v8.
- All ranges are nonempty and in bounds; JP/EN ranges never overlap and together cover the whole raw input.
- Japanese segments contain only lowercase roman letters and were manually read as intended Japanese.
- Literal English words, phrases, acronyms, syntax, spaces, and punctuation are in English/preserved ranges.
- No space occurs outside an authored English/preserved range.
- TeX, code, and URL boundaries match the intended syntax; the square-root example begins with exactly one backslash.

Readable second-review material is saved in `diagnosis/final-authored-segments.json` and `diagnosis/final-authoring-validation.txt`. The latter prints every intended sentence and every gold segment, alongside the machine-check summary.

Final fixture SHA-256: `a3c55b06c6db618096784fb5d69e2510fa75251649c38988f6cca52aad7718a5`.

## Evaluation discipline and limitations

This fixture is frozen at handoff. Evaluate the frozen candidate and baseline against the same unchanged gold. Preserve all failures; do not revise examples or labels after seeing predictions to improve a score. A genuine annotation error must be documented in a separate review artifact while retaining the original raw, fixture, and evaluation.

This is a small authored challenge set, not a representative sample of real user input. The author knows the product's general failure categories and helped diagnose earlier versions. Although these new predictions were not observed, the set is not fully blind to task history. Report final exact segmentation, completed-English damage during typing, and label reversals separately. Do not call its pass rate general conversion accuracy: it does not evaluate Zenzai's kanji choices, deletions or cursor edits, arbitrary application behavior, or inference latency.

Once this set informs future implementation changes, it becomes development data and a separately authored final set is required for that future version.
