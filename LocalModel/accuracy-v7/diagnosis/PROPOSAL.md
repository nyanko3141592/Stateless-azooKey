# Long Japanese phrase boundary evidence

Frozen native inference: ef66a1e (fork ab8bc42). Diagnostic JS loaded the matching website port; no native/site source was edited.

Insert immediately before `let uncertaintyPenalty` in the English-anchor offer block. `japanesePrefix`, `boundaryEvidence`, `particles`, `start`, `anchor` are existing local variables.

```swift
let knownBoundary = knownJapanese.contains(japanesePrefix)
    || particles.contains { particle in
        guard japanesePrefix.hasSuffix(particle) else { return false }
        let stem = String(japanesePrefix.dropLast(particle.count))
        return knownJapanese.contains(stem) || particles.contains { previous in
            stem.hasSuffix(previous)
                && knownJapanese.contains(String(stem.dropLast(previous.count)))
        }
    }
if !knownBoundary, anchor.end < characters.count, japanesePrefix.count >= 6,
   particles.contains(where: { particle in
       japanesePrefix.hasSuffix(particle)
           && isRomaji(String(japanesePrefix.dropLast(particle.count)))
   }), probability(japanesePrefix, context: true) >= 0.995 {
    let japaneseStart = start - japanesePrefix.count
    let crossesEnglish = (japaneseStart..<start).contains { lexicalStart in
        (compoundEnds[lexicalStart] ?? []).contains { lexicalEnd in
            guard lexicalEnd - lexicalStart >= 4 else { return false }
            let text = String(characters[lexicalStart..<lexicalEnd]).lowercased()
            return knownEnglish.contains(text) && !knownJapanese.contains(text)
        }
    }
    if !crossesEnglish { boundaryEvidence = max(boundaryEvidence, 2.5) }
}
```

This applies to lexical AND nonlexical English anchors. The existing known-Japanese phrase+one/two-particle evidence is unchanged. A new long Japanese phrase must end in a particle on a valid romaji syllable boundary and have very high Japanese probability. Existing English lexical words overlapping the proposed Japanese phrase block its promotion. Compound-only lexical joins are deliberately excluded from this guard.

## Results

Run `node LocalModel/accuracy-v7/diagnosis/phrase3.mjs phrase3` from the outer workspace (script uses workspace-relative fixture paths). `phrase3.json` records all ten fixture comparisons, including every per-case metric change.

All nine older sets: exact, completed-English damage, and reversal metrics unchanged on every individual case. Former v6 final48 (now development): exact 27→34, completed-English damage117→117, reversals194→192. This is development evidence, not fresh holdout accuracy.

Fixed seven cases: long Japanese phrase before roadmap/background/default/spreadsheet/code/diff/checksum. No dictionary additions.

Initial variants rejected: generic high-JP bonus allowed English words (`feature`, `token`, `node`, etc.) into Japanese spans; unrestricted particle endings also allowed `cha` to be treated as particle `ha`. The final guards address these general errors.
