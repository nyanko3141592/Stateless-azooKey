# English at composition start — native v8 diagnosis

Baseline: website JS port of native 055b8a4. Only files in this diagnostic directory were written; native/site source and model were not edited. `development28.json` contains 28 authored beginning-English mixed sentences; `safety18.json` covers full English, standalone words, ambiguous English phrases, and pure Japanese. These are development diagnostics, not held-out accuracy evidence.

## Root cause and minimal recommendation

v8 only permits certain lowercase lexical English → Japanese paths when a preceding English word plus whitespace supplies phrase context. Thus a whole sentence may eventually be correct through a fallback, while intermediate prefixes repeatedly lose the English boundary. Input-start English needs the same permission without inventing a remembered language mode.

Change only `englishPhrase` in `LocalLanguageRouter.classify`:

```swift
let englishPhrase = spans.isEmpty || (
    spans.count >= 2 && spans.last!.protected
    && spans.last!.text.allSatisfy(\.isWhitespace)
    && knownEnglish.contains(spans[spans.count-2].text.lowercased())
    && !ambiguous.contains(spans[spans.count-2].text.lowercased())
)
```

Keep the segmenter unchanged. Its existing guards still require lexical English, a Japanese suffix of at least four characters beginning with a supported particle/verb prefix, complete or partial romaji, and Japanese probability >=.88. The added context is computed from the same input, not earlier conversions or committed text.

## Diagnostic result

`start-only-new.json` records full-prefix comparisons on all 28 + 18 new cases:

- Mixed 28: final exact23→24; completed-English damage58→21; reversal frames124→82.
- Safety18: exact18→18, damage0→0, reversals3→3.
- `download...`: reversals18→2; `calendar...`:12→1; `code...`:9→2; `file...`:9→5.
- `mode...` becomes finally correct, but its own reversals3→4; aggregate stability improves, not every individual example.

The remaining four completed failures involve Docker followed by Japanese `settei`, low-confidence Japanese `nooutou...`, and unknown English deadline/playlist. This recommendation does not claim to solve all leading-English cases.

## Regression coverage and proof boundary

`start-only-targeted.json` is the targeted full-prefix comparison for the existing 540 + 96 cases, followed by the new diagnostics. The comparison explicitly distinguishes fully tested cases and structurally unchanged cases; it must not be described as executing all 636 old cases through both models.

Only the first lexer span can see the added flag. Every newly enabled segmenter path starts with an existing, nonambiguous English word of length>=4. Therefore a raw input that does not begin with any such known word cannot reach an added path at any prefix. The test conservatively selects 72 of the existing636 cases by that condition;564 are outside the code change's reach. Exactness, damage and reversals must match on the72 full-prefix checks. The main agent's full Swift regression remains the final native verification.

For the 96 original evaluation cases, the script evaluates final JP labels and reversals; English damage is not compared because that fixture lacks `englishRanges`. Its zero damage values are placeholders, not evidence of zero English damage.

## Rejected broader variants

Removing the phrase-context guard globally also changes English after Japanese + whitespace: `ato meetingmadeniagendawookurimasu` retains final correctness but gains two English-damage frames. That broader variant was rejected; its full run was stopped after the regression was identified.

A separate exploratory extension admitted strongly English unknown words in two-piece paths. It fixed playlist, giving25/28 and damage14 on the new set, but was not fully regression-validated and is NOT recommended in this change. Prefer the single-site input-start context addition.
