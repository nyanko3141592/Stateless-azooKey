# v8 bounded verb-modifier candidate

Baseline: v7 matching website JS port, native inference 0aff807 / fork baseline45e8da8. No native or website source was edited; the JS module was modified only in memory.

## Exact two-part change

1. In `strongJapanesePhrase`, replace the suffix predicate's `particles.contains` with `particles.union(["ta", "ru", "te", "nai"]).contains`. Only change the `supported` predicate. Keep `knownBoundary` on the original particles, the complete-romaji stem condition, the >=6 length, >=0.995 probability, and the crossing-English-word guard unchanged.
2. Move the existing `japanesePrefix` local above anchor score, and use:

```swift
let score = lexical ? 3 + Double(anchor.text.count)*0.2
    : (afterParticle || strongJapanesePhrase(japanesePrefix, endingAt:start))
        ? 1.5 + Double(anchor.text.count)*0.12
        : 1 - Double(anchor.text.count)*0.06
```

These predicates extend established evidence to verb-modifier endings. They do not add vocabulary, alter the statistical model, remove English protection, or broaden short unknown anchors.

## Validation

`verb.mjs` reproduces the candidate against 11 fixture sets. `verb.json` contains the first 10 comparisons; `verb-final.json` contains corrected v7 final48 (now development). Set `ONLY_FINAL=1` for only the latter; omit it for all 11.

- Older 10 sets: exact, English damage and reversal counts are unchanged for every individual case.
- Corrected v7 development48: exact32→37, completed-English damage203→145, reversals243→236.
- Improved final cases: checkbox, regression, milestone, workspace, newsletter after Japanese modifiers.
- One local stability cost: the shortcut case has one additional reversal, but unchanged final correctness and English damage; aggregate reversals improve.

## Known remaining issues

`deadline` still loses to `adline` under the character model's probabilities when both boundaries have similar evidence. Past-tense stems with doubled consonants (`tsukutta`, `itta`) are not complete romaji after removing `ta`, so checklist/chapter modifiers remain outside the added evidence. watermark/shortcut have pJapanese slightly above the existing .02 nonparticle-anchor eligibility threshold. These were not further tuned; the recommendation is to adopt the verified bounded candidate and evaluate the combined root changes before a new final set.
