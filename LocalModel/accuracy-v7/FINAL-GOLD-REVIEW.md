# v7 final48 gold review (original fixture retained)

The fixture author independently reviewed the raw text and gold spans of all 48 cases after a suspected annotation error was reported. No inference was run and no predicted labels or per-case evaluation results were consulted. No model vocabulary was read. The original fixture, source hash manifest, creation notes, and raw strings were not modified.

## Confirmed annotation error: v7-final-031

Raw: `kaishanosourcenohozonbashohaprivate repositorydesu`

Intended wording: 「会社のsourceの保存場所はprivate repositoryです」. The fixture author mistakenly placed the English spelling `source` inside the Japanese prefix. Even if the intended displayed word had been Japanese 「ソース」, that would require romaji such as `so-su` / `soosu`, not `source`. This is an invalid original language label, not a genuinely ambiguous Japanese/English phrase.

Proposed correction changes only the label on `[8, 14)` (`source`):

| Field | Original | Proposed |
| --- | --- | --- |
| japaneseRanges | `[[0,28],[46,50]]` | `[[0,8],[14,28],[46,50]]` |
| englishRanges | `[[28,46]]` | `[[8,14],[28,46]]` |

The new segments are `kaishano` / `source` / `nohozonbashoha` / `private repository` / `desu`. No character of the raw input changes. Keep the case in the English-phrase category and in the denominator of 48.

## Full-set review outcome

- One confirmed English-spelling contamination in Japanese gold spans, as above.
- No additional such contamination identified in the remaining 47 cases.
- Japanese loanwords typed as Japanese romaji (for example `pasokonn`) remain Japanese. Short substrings such as `no`, `to`, or `made` inside a Japanese sentence are not English simply because an English word has the same spelling.
- English words, multiword phrases, acronyms, full English sentences, and TeX/code/URL spans elsewhere are intentionally labeled as preserved text.
- `v7-final-040` has an apparent wording typo: `kaemono` likely intended `kaimono` (買い物). The text is still Japanese-intended romaji, so no language-label change or exclusion is justified. The original raw is retained.
- Zero cases are excluded. No ambiguous or difficult case was removed to change the result.

All original and proposed ranges were checked mechanically for nonempty, in-bounds half-open intervals and Japanese/English nonoverlap. `final-gold-review.json` contains the exact correction and a review status for all 48 IDs.

## Reporting

Original fixture SHA-256 remains `69e80c4c802e2666b5a9f3802559a10b0fde8a473d4a0161741d02fa801957e4`.

Retain the originally committed evaluation. Report corrected-gold metrics separately, with the one annotation correction disclosed. Apply the same correction to every compared frozen model; do not retrain or tune inference using these cases. This review does not establish whether the correction raises or lowers any model's score; predictions were not inspected.
