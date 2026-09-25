import Foundation

extension LocalLanguageRouter {
    /// Refine a lexer word only when alternating literal words and plausible romaji explain it.
    /// Source characters are sliced verbatim; no generated text or persistent language state.
    func mixedSegments(_ word: String, englishPhrase: Bool = false) -> [(text: String, japanese: Bool)]? {
        let characters = Array(word)
        guard characters.count >= 7, characters.count <= 160,
              characters.allSatisfy({ $0.isASCII && $0.isLetter }),
              !knownEnglish.contains(word.lowercased()), !englishPrefixes.contains(word.lowercased()) else { return nil }
        // Memoization is scoped to this input; it carries no language state across edits.
        var probabilities: [String:Double] = [:]
        func probability(_ text: String, context: Bool = false) -> Double {
            let key = (context ? "1:" : "0:") + text
            if let value = probabilities[key] { return value }
            let value = self.japaneseProbability(text,context:context)
            probabilities[key] = value
            return value
        }
        // Recognize compound English anchors using the existing lexicon, without adding
        // evaluation words to it. Every component must be a non-ambiguous word.
        var compoundEnds: [Int:Set<Int>] = [:]
        for start in 0..<characters.count {
            var ends: Set<Int> = [start]
            let limit = min(characters.count,start+32)
            for cursor in start..<limit where ends.contains(cursor) {
                for end in (cursor+1)...limit {
                    let part = String(characters[cursor..<end]).lowercased()
                    if part.count >= 3 && knownEnglish.contains(part) && !ambiguous.contains(part) {
                        ends.insert(end)
                    }
                }
            }
            ends.remove(start); compoundEnds[start] = ends
        }
        // Do not invent a Japanese particle inside concatenated English words, e.g. notificationworkflow.
        var englishEnds: Set<Int> = [0]
        for start in 0..<characters.count where englishEnds.contains(start) {
            for end in (start+1)...min(characters.count,start+32) {
                let part = String(characters[start..<end]).lowercased()
                if part.count >= 3 && knownEnglish.contains(part) && !ambiguous.contains(part) {
                    englishEnds.insert(end)
                }
            }
        }
        if englishEnds.contains(characters.count) { return nil }
        // A compound still being typed is English too; do not reinterpret its last
        // completed word as an English/Japanese switch (notification + workfl...).
        if englishEnds.contains(where: { end in
            end > 0 && end < characters.count && englishPrefixes.contains(String(characters.dropFirst(end)).lowercased())
        }) { return nil }
        struct Path {
            var pieces: [(text: String, japanese: Bool)]
            var score: Double
            var hasEnglish: Bool
            var hasJapanese: Bool
        }
        // A lexical word followed by whitespace in this same composition supplies
        // English-phrase context. A Japanese suffix may still have a trailing consonant
        // while typing; requiring complete romaji would flip the boundary every key.
        func strongJapaneseTail(after end: Int) -> Bool {
            guard englishPhrase else { return false }
            let suffix = String(characters.dropFirst(end))
            return suffix.count >= 4 && !knownEnglish.contains(suffix.lowercased())
                && ["no","ni","de","wo","ha","ga","to","mo","kara","made","shite","shita","shimas","sare","suru"].contains(where:suffix.hasPrefix)
                && (isRomaji(suffix) || isRomajiPrefix(suffix)) && probability(suffix,context:true) >= 0.88
        }
        let mixedBoundaryParticles = ["no","ni","de","wo","ha","ga","to","mo","kara","made"]
        let mixedBoundaryTailParticles = mixedBoundaryParticles + ["shite","shita","shimas","sare","suru"]
        func hasMixedParticleSuffix(_ text: String) -> Bool {
            mixedBoundaryParticles.contains { text.hasSuffix($0) }
        }
        func hasMixedParticleTailPrefix(_ text: String) -> Bool {
            mixedBoundaryTailParticles.contains { text.hasPrefix($0) }
        }
        // Unknown romaji-looking anchors with English -ise/-ize morphology can be
        // English when a Japanese particle and a strong Japanese tail establish both
        // boundaries. This is structural, not a word-specific exception.
        func isMorphologicalRomajiEnglish(_ text: String) -> Bool {
            guard text.count >= 5, text.count <= 20, isRomaji(text) else { return false }
            let lower = text.lowercased()
            return lower.hasSuffix("ize") || lower.hasSuffix("ise")
        }
        // Use lexical words, trailing lexical prefixes, and unknown words supported by both boundaries.
        var anchors: [Int:[(end: Int,text: String)]] = [:]
        for start in 0..<characters.count {
            var candidate = ""
            for end in start..<min(characters.count,start+32) {
                candidate.append(characters[end])
                let lexical = compoundEnds[start]?.contains(end+1) == true
                let partialEnglish = end+1 == characters.count && englishPrefixes.contains(candidate.lowercased())
                guard candidate.count >= 3, !ambiguous.contains(candidate.lowercased()),
                      !knownJapanese.contains(candidate.lowercased()),
                      !isRomaji(candidate) || candidate.first?.isUppercase == true || (lexical && candidate.count >= 5)
                        || (candidate.count >= 5 && probability(candidate) < 0.1)
                        || (lexical && candidate.count == 4
                            && ((start > 0 && probability(candidate) < 0.12
                                && ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where:String(characters.prefix(start)).hasSuffix))
                                || (start == 0 && strongJapaneseTail(after:end+1))))
                        || (isMorphologicalRomajiEnglish(candidate)
                            && !knownEnglish.contains(candidate.lowercased())
                            && !knownJapanese.contains(candidate.lowercased())
                            && hasMixedParticleSuffix(String(characters.prefix(start)))
                            && hasMixedParticleTailPrefix(String(characters.dropFirst(end+1)))
                            && probability(String(characters.dropFirst(end+1)),context:true) >= 0.88)
                        || (start == 0 && englishPhrase && candidate.count == 4
                            && isRomaji(candidate) && !knownEnglish.contains(candidate.lowercased())
                            && probability(candidate) < 0.9 && strongJapaneseTail(after:end+1)) else { continue }
                let tail = String(characters.dropFirst(end+1))
                let beforeJapanese = ["no","ni","de","wo","ha","ga","to","kara","shite","shita","shimas","sare","suru"].contains(where:tail.hasPrefix)
                    || ["n","d","w","h","g","t","k","sh","shi","sa","sar"].contains(tail)
                let preceding = String(characters.prefix(start))
                let afterJapaneseParticle = ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where:preceding.hasSuffix)
                // An unknown anchor needs evidence on both sides; arbitrary substrings inside
                // Japanese words must not become English simply because their score is low.
                func hasJapaneseSuffix() -> Bool {
                    candidate.count >= 5 && (3...(candidate.count-2)).contains { split in
                        let head = String(candidate.prefix(split))
                        let rest = String(candidate.dropFirst(split))
                        return ["no","ni","de","wo","ha","ga","to","shite","shita","shimas","sare","suru"].contains(where:rest.hasPrefix)
                            && isRomaji(rest) && probability(head) < 0.4
                            && (probability(rest,context:true) > 0.8 || ["shite","shita","shimasu","saremasu","suru"].contains(where: { $0.hasPrefix(rest) }))
                    }
                }
                let lexicalJapanesePrefix = knownJapanese.contains(preceding)
                    || ["no","ni","de","wo","ha","ga","to"].contains { particle in
                        preceding.hasSuffix(particle) && knownJapanese.contains(String(preceding.dropLast(particle.count)))
                    }
                var glued = false
                if candidate.count >= 8 {
                    for split in 4...(candidate.count - 4) {
                        let head = String(candidate.prefix(split))
                        let tail = String(candidate.dropFirst(split))
                        if isRomaji(head) && probability(head,context:true) >= 0.88
                            && (knownEnglish.contains(tail.lowercased())
                                || (!isRomaji(tail) && probability(tail) < 0.1)) {
                            glued = true
                            break
                        }
                    }
                }
                // Do not end an uncertain word inside a longer lexical word:
                // e.g. an unknown prefix must not peel "co" off "code" as Japanese "de".
                let crossesLexicalWord = ((start+1)...end).contains { lexicalStart in
                    (compoundEnds[lexicalStart] ?? []).contains { lexicalEnd in
                        lexicalEnd > end+1 && lexicalEnd-lexicalStart >= 4
                            && knownEnglish.contains(String(characters[lexicalStart..<lexicalEnd]).lowercased())
                    }
                }
                // Do not merge an identifiable English word plus a Japanese particle
                // into a longer unknown English anchor (preview + de, ni + review).
                let swallowsBoundary = (compoundEnds[start] ?? []).contains { middle in
                    guard middle < end+1 else { return false }
                    let rest = String(characters[middle...end])
                    return ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where:rest.hasPrefix)
                } || ((start+1)...end).contains { middle in
                    let head = String(characters[start..<middle])
                    return ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(head)
                        && (compoundEnds[middle] ?? []).contains(where: { $0 <= end+1 })
                }
                let shortEnglishPrefix = candidate.count == 3 && englishPrefixes.contains(candidate.lowercased())
                    && !isRomaji(candidate) && afterJapaneseParticle
                    && (probability(candidate) < 0.02
                        || (probability(candidate) >= 0.5
                            && ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where:tail.hasPrefix)))
                let romajiEnglishCandidate = isMorphologicalRomajiEnglish(candidate)
                    && !knownEnglish.contains(candidate.lowercased())
                    && !knownJapanese.contains(candidate.lowercased())
                    && hasMixedParticleSuffix(preceding)
                    && hasMixedParticleTailPrefix(tail)
                    && probability(tail,context:true) >= 0.88
                let unknown = !lexical && (candidate.count >= 4 || shortEnglishPrefix) && candidate.count <= 20
                    && ((beforeJapanese && tail.count >= 2) || (end+1 == characters.count && start > 0
                        && !isRomaji(candidate) && probability(candidate) < 0.02
                        && isRomaji(preceding) && probability(preceding,context:true) >= 0.88)
                        || (end+1 == characters.count && start > 0 && candidate.count >= 5
                            && !isRomaji(candidate) && candidate.lowercased().hasSuffix("ing")
                            && probability(candidate) < 0.4 && isRomaji(preceding)
                            && probability(preceding,context:true) >= 0.88))
                    && (start > 0 || ((isRomaji(tail) || isRomajiPrefix(tail)) && probability(tail,context:true) >= 0.88))
                    && (romajiEnglishCandidate || afterJapaneseParticle || (start == 0 && candidate.first?.isUppercase == true)
                        || (start == 0 && englishPhrase && candidate.count == 4
                            && isRomaji(candidate) && !knownEnglish.contains(candidate.lowercased())
                            && probability(candidate) < 0.9 && strongJapaneseTail(after:end+1))
                        || (!isRomaji(candidate) && probability(candidate) < ((start == 0 && englishPhrase) ? 0.4 : 0.06)))
                    && (romajiEnglishCandidate || shortEnglishPrefix || probability(candidate) < ((start == 0 && englishPhrase && candidate.count == 4
                        && isRomaji(candidate) && !knownEnglish.contains(candidate.lowercased())
                        && strongJapaneseTail(after:end+1)) ? 0.9 : (lexicalJapanesePrefix ? 0.7 : 0.4)))
                    && !glued && !crossesLexicalWord && !swallowsBoundary
                    && (!hasJapaneseSuffix() || (candidate.count == 5 && !isRomaji(candidate) && probability(candidate) < 0.001))
                if lexical || partialEnglish || unknown { anchors[start,default:[]].append((end+1,candidate)) }
            }
        }
        guard !anchors.isEmpty else { return nil }
        func stronglyRomajiLeading(_ text: String) -> Bool {
            let lower = text.lowercased()
            return englishPhrase && text.count == 4
                && !ambiguous.contains(lower) && !knownJapanese.contains(lower)
                && !knownEnglish.contains(lower) && isRomaji(text)
                && probability(text) < 0.9 && strongJapaneseTail(after:text.count)
        }
        if isRomaji(word) || isRomajiPrefix(word) {
            // A long completed English word after a Japanese particle can itself look like
            // unfinished romaji ("meeting"). Short substrings such as "was" remain Japanese.
            let completedEnglish = anchors.contains { start, values in
                let prefix = String(characters.prefix(start))
                return start >= 2 && isRomaji(prefix) && probability(prefix,context:true) >= 0.95
                    && values.contains { anchor in
                        anchor.text.count >= 5 && (knownEnglish.contains(anchor.text.lowercased())
                            || (!isRomaji(anchor.text)
                                && probability(anchor.text) < 0.1 && anchor.end < characters.count)
                            || (anchor.end == characters.count && !isRomaji(anchor.text)
                                && anchor.text.lowercased().hasSuffix("ing")
                                && probability(anchor.text) < 0.4))
                    }
            }
            let morphologicallyCompletedEnglish = anchors.contains { start, values in
                let prefix = String(characters.prefix(start))
                guard start > 0, hasMixedParticleSuffix(prefix) else { return false }
                return values.contains { anchor in
                    let tail = String(characters.dropFirst(anchor.end))
                    return isMorphologicalRomajiEnglish(anchor.text)
                        && !knownEnglish.contains(anchor.text.lowercased())
                        && !knownJapanese.contains(anchor.text.lowercased())
                        && hasMixedParticleTailPrefix(tail)
                        && probability(tail,context:true) >= 0.88
                }
            }
            let leadingEnglish = anchors[0]?.contains { anchor in
                knownEnglish.contains(anchor.text.lowercased())
                    && (anchor.text.first?.isUppercase == true || (anchor.text.count >= 4 && strongJapaneseTail(after:anchor.end)))
            } == true || anchors[0]?.contains { stronglyRomajiLeading($0.text) } == true
            let strongUnknownLeading = anchors[0]?.contains { anchor in
                let lower = anchor.text.lowercased()
                return !ambiguous.contains(lower) && !knownJapanese.contains(lower)
                    && !isRomaji(anchor.text)
                    && probability(anchor.text) < (englishPhrase ? 0.4 : 0.02)
                    && anchor.text.count >= 4
                    && strongJapaneseTail(after:anchor.end)
                    && (anchor.text.first?.isUppercase != true
                        || !isRomaji(String(anchor.text.drop(while: { $0.isUppercase }))))
            } == true
            guard completedEnglish || morphologicallyCompletedEnglish || leadingEnglish || strongUnknownLeading else { return nil }
        }
        let particles: Set<String> = ["no","ni","de","wo","ha","ga","to","mo","kara","made"]
        // Give a complete, high-confidence Japanese phrase the same boundary
        // evidence as a short dictionary word. Otherwise a known prefix such as
        // "kono" can win by swallowing the rest of the Japanese phrase into English.
        var phraseEvidence: [String:Bool] = [:]
        func strongJapanesePhrase(_ text: String, endingAt end: Int) -> Bool {
            let key = "\(end):\(text)"
            if let cached = phraseEvidence[key] { return cached }
            let knownBoundary = knownJapanese.contains(text) || particles.contains { particle in
                guard text.hasSuffix(particle) else { return false }
                let stem = String(text.dropLast(particle.count))
                return knownJapanese.contains(stem) || particles.contains {
                    stem.hasSuffix($0) && knownJapanese.contains(String(stem.dropLast($0.count)))
                }
            }
            var supported = !knownBoundary && text.count >= 6
                && particles.union(["ta","ru","te","nai","tta","nda"]).contains { text.hasSuffix($0) && isRomaji(String(text.dropLast($0.count))) }
                && probability(text,context:true) >= 0.995
            if supported {
                // Do not gain Japanese evidence by swallowing an English word,
                // including a lexical word crossing this proposed boundary.
                supported = !compoundEnds.contains { start, ends in
                    start >= end-text.count && start < end && ends.contains { lexicalEnd in
                        let word = String(characters[start..<lexicalEnd]).lowercased()
                        return lexicalEnd-start >= 4 && knownEnglish.contains(word) && !knownJapanese.contains(word)
                    }
                }
            }
            phraseEvidence[key] = supported
            return supported
        }
        var jpScores: [String:Double] = [:]
        func japaneseScore(_ text: String, final: Bool) -> Double? {
            guard text.first?.isUppercase != true, isRomaji(text) || (final && isRomajiPrefix(text)) else { return nil }
            if final && ["n","d","w","h","g","t","k"].contains(text) { return 0 }
            if particles.contains(text) { return 0.5 }
            // A short, unambiguous dictionary word is positive Japanese evidence even
            // when the statistical model is weak (for example "ano" before playlist).
            if text.count >= 3 && knownJapanese.contains(text.lowercased())
                && !knownEnglish.contains(text.lowercased()) && !ambiguous.contains(text.lowercased()) {
                return Double(text.count) * 0.12
            }
            if final && text.count >= 2 && ["shite","shita","shimasu","saremasu","suru"].contains(where: { $0.hasPrefix(text) }) {
                return Double(text.count)*0.12
            }
            if final && !knownEnglish.contains(text.lowercased()) && particles.contains(where:text.hasPrefix) { return Double(text.count)*0.12 }
            if let score = jpScores[text] { return score >= 0 ? score : nil }
            let p = probability(text,context:true)
            let score = text.count >= 4 && p >= 0.88 && !knownEnglish.contains(text.lowercased()) ? Double(text.count) * 0.12 : -1
            jpScores[text] = score
            return score >= 0 ? score : nil
        }
        // Keep alternatives by last language and whether both languages occurred; do not greedily take
        // the first substring ("log" inside a larger English word is not automatically a boundary).
        var paths: [Int:[String:Path]] = [0:["start":Path(pieces:[],score:0,hasEnglish:false,hasJapanese:false)]]
        func englishCharacterCount(_ path: Path) -> Int {
            path.pieces.reduce(0) { $0 + ($1.japanese ? 0 : $1.text.count) }
        }
        func offer(_ path: Path, end: Int, text: String, japanese: Bool, score: Double) {
            var next = path
            next.pieces.append((text,japanese)); next.score += score - 0.8
            next.hasEnglish = next.hasEnglish || !japanese; next.hasJapanese = next.hasJapanese || japanese
            let key = "\(japanese)-\(next.hasEnglish)-\(next.hasJapanese)-\(min(next.pieces.count,3))"
            let shouldReplace: Bool
            if let existing = paths[end]?[key] {
                shouldReplace = existing.score < next.score
                    || (existing.score == next.score
                        && englishCharacterCount(next) < englishCharacterCount(existing))
            } else {
                shouldReplace = true
            }
            if shouldReplace { paths[end,default:[:]][key] = next }
        }
        for start in 0..<characters.count {
            guard let choices = paths[start] else { continue }
            for key in choices.keys.sorted() {
                let path = choices[key]!
                if path.pieces.last?.japanese == true {
                    // A growing English word may not be a full lexical anchor yet. Preserve a
                    // plausible literal tail so the preceding Japanese run does not disappear.
                    let tail = String(characters[start...])
                    let lower = tail.lowercased()
                    let stem = tail.count > 4 && (4..<tail.count).contains {
                        let prefix = String(tail.prefix($0))
                        return knownEnglish.contains(prefix.lowercased()) && !isRomaji(prefix)
                    }
                    let pendingJapanese = tail.count < 3 && isRomajiPrefix(tail)
                        && tail.first?.isUppercase != true && particles.contains(path.pieces.last!.text)
                    if !pendingJapanese && !knownJapanese.contains(lower) && !ambiguous.contains(lower)
                        && (englishPrefixes.contains(lower) || (stem && probability(tail) < 0.4) || (!isRomaji(tail) && probability(tail) < (particles.contains(path.pieces.last!.text) ? 0.4 : 0.02))) {
                        let evidence = knownEnglish.contains(lower) && particles.contains(path.pieces.last!.text)
                            ? 3 + Double(tail.count)*0.2 : min(0.8,Double(tail.count)*0.15)
                        offer(path,end:characters.count,text:tail,japanese:false,score:evidence)
                    }
                }
                if path.pieces.last?.japanese != false {
                    for anchor in anchors[start] ?? [] {
                        let lexical = compoundEnds[start]?.contains(anchor.end) == true
                        // Four-letter English words can also be complete romaji. Require
                        // a real Japanese boundary, rather than a particle-like substring
                        // inside a phrase (e.g. ...mono desu must not expose English node).
                        if lexical && anchor.text.count == 4 && isRomaji(anchor.text)
                            && anchor.text.first?.isUppercase != true {
                            let prefix = path.pieces.last?.japanese == true ? path.pieces.last!.text : ""
                            let boundary = particles.contains(prefix) || knownJapanese.contains(prefix)
                                || particles.contains { prefix.hasSuffix($0) && knownJapanese.contains(String(prefix.dropLast($0.count))) }
                            if !boundary && !(start == 0 && strongJapaneseTail(after:anchor.end)) { continue }
                        }
                        // A very short unknown can only follow an already established
                        // English + particle run, not peel a fragment off a longer word.
                        let confidentPrefixParticle = anchor.text.count == 3
                            && englishPrefixes.contains(anchor.text.lowercased())
                            && !isRomaji(anchor.text)
                            && probability(anchor.text) >= 0.5
                            && ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where: String(characters.dropFirst(anchor.end)).hasPrefix)
                            && ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where: String(characters.prefix(start)).hasSuffix)
                            && path.pieces.last?.japanese == true
                            && particles.contains(path.pieces.last!.text)
                        if !lexical && anchor.text.count == 3
                            && !((path.hasEnglish && path.pieces.last?.japanese == true
                                && particles.contains(path.pieces.last!.text)) || confidentPrefixParticle) { continue }
                        // A three-letter lexicon word is not a boundary when the rest of the
                        // token is one strong romaji Japanese run without a particle boundary
                        // (herashimasu, settei, wasuretekita); "log" + "wo..." keeps its boundary.
                        if lexical && anchor.text.count == 3 && anchor.text.first?.isUppercase != true {
                            let rest = String(characters.dropFirst(anchor.end))
                            if rest.count >= 4
                                && !["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where:rest.hasPrefix)
                                && isRomaji(rest) && probability(rest,context:true) >= 0.88 { continue }
                        }
                        let preceding = String(characters.prefix(start))
                        let afterParticle = ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where:preceding.hasSuffix)
                        let japanesePrefix = path.pieces.last?.japanese == true ? path.pieces.last!.text : ""
                        let englishTailBonus = !lexical && anchor.end == characters.count
                            && anchor.text.count >= 6 && anchor.text.lowercased().hasSuffix("ing") ? 0.8 : 0
                        let romajiEnglishCandidate = isMorphologicalRomajiEnglish(anchor.text)
                            && !knownEnglish.contains(anchor.text.lowercased())
                            && !knownJapanese.contains(anchor.text.lowercased())
                            && hasMixedParticleSuffix(preceding)
                            && hasMixedParticleTailPrefix(String(characters.dropFirst(anchor.end)))
                            && probability(String(characters.dropFirst(anchor.end)),context:true) >= 0.88
                        let score = (lexical ? 3 + Double(anchor.text.count)*0.2
                            : (afterParticle || strongJapanesePhrase(japanesePrefix,endingAt:start))
                                ? 1.5 + Double(anchor.text.count)*0.12 : 1 - Double(anchor.text.count)*0.06)
                            + englishTailBonus + (confidentPrefixParticle && !lexical ? 0.6 : 0)
                            + (romajiEnglishCandidate && !lexical ? 0.3 : 0)
                        // Strong Japanese morphology helps locate an uncertain English word,
                        // but must not bias Japanese suffixes after an already identified word.
                        var boundaryEvidence = 0.0
                        if lexical && japanesePrefix.count >= 3 && !knownJapanese.contains(japanesePrefix)
                            && !particles.contains(where:japanesePrefix.hasSuffix) {
                            boundaryEvidence -= 3
                        }
                        if !lexical && anchor.end < characters.count && japanesePrefix.count >= 4 {
                            if knownJapanese.contains(japanesePrefix) { boundaryEvidence = 2.5 }
                            else if particles.contains(where: { particle in
                                guard japanesePrefix.hasSuffix(particle) else { return false }
                                let stem = String(japanesePrefix.dropLast(particle.count))
                                return knownJapanese.contains(stem) || particles.contains { previous in
                                    stem.hasSuffix(previous) && knownJapanese.contains(String(stem.dropLast(previous.count)))
                                }
                            }) {
                                boundaryEvidence = 2.0
                            }
                        }
                        if anchor.end < characters.count && strongJapanesePhrase(japanesePrefix,endingAt:start) {
                            boundaryEvidence = max(boundaryEvidence,2.5)
                            if !lexical && japanesePrefix.range(of: #"(?:ta|ru|te|nai)$"#, options: .regularExpression) != nil
                                && probability(japanesePrefix,context:true) >= 0.995 {
                                boundaryEvidence += 0.18
                            }
                        }
                        // Limit classifier influence to a small tie-break between
                        // uncertain boundaries; do not overwhelm morphological evidence.
                        let uncertaintyPenalty = lexical ? 0 : 0.5 * min(0.02,probability(anchor.text))
                        offer(path,end:anchor.end,text:anchor.text,japanese:false,score:score + boundaryEvidence - uncertaintyPenalty)
                    }
                }
                if path.pieces.last?.japanese != true {
                    let particleEnds = particles.compactMap { particle -> Int? in
                        let end = start + particle.count
                        return end < characters.count && String(characters[start..<end]) == particle ? end : nil
                    }
                    let ends = Set(anchors.keys.filter { $0 > start } + particleEnds + [characters.count])
                    for end in ends.sorted() {
                        let text = String(characters[start..<end])
                        if let score = japaneseScore(text,final:end == characters.count) { offer(path,end:end,text:text,japanese:true,score:score) }
                    }
                }
            }
        }
        // A non-lexicon but strongly English leading piece (playlist, Docker) may head a
        // two-piece path when a strong Japanese tail follows. A capitalized piece is only
        // admissible when the part after the leading uppercase run is not romaji, so an
        // acronym-led piece cannot swallow a Japanese tail (PDFwobetsu...).
        func stronglyUnknownLeading(_ text: String) -> Bool {
            let lower = text.lowercased()
            guard !ambiguous.contains(lower), !knownJapanese.contains(lower),
                  !isRomaji(text), probability(text) < (englishPhrase ? 0.4 : 0.02), text.count >= 4,
                  strongJapaneseTail(after:text.count) else { return false }
            return text.first?.isUppercase == false || !isRomaji(String(text.drop(while: { $0.isUppercase })))
        }
        guard let best = paths[characters.count]?.values.filter({ $0.hasEnglish && $0.hasJapanese && ($0.pieces.count >= 3
                && !(knownEnglish.contains($0.pieces.first!.text.lowercased())
                    && $0.pieces.first!.text.count <= 3
                    && $0.pieces.first!.text.first?.isUppercase != true)
                || $0.pieces.first?.japanese == true
                || (knownEnglish.contains($0.pieces.first!.text.lowercased())
                    && ($0.pieces.first?.text.first?.isUppercase == true
                        || ($0.pieces.first!.text.count >= 4 && strongJapaneseTail(after:$0.pieces.first!.text.count))))
                || stronglyRomajiLeading($0.pieces.first!.text)
                || stronglyUnknownLeading($0.pieces.first!.text)) }).max(by: { a,b in
            if a.score != b.score { return a.score < b.score }
            let aEnglish = englishCharacterCount(a), bEnglish = englishCharacterCount(b)
            if aEnglish != bEnglish { return aEnglish > bEnglish }
            return a.pieces.map { $0.text }.joined(separator:"|") < b.pieces.map { $0.text }.joined(separator:"|")
        }), best.score > 0 else { return nil }
        return best.pieces
    }
}
