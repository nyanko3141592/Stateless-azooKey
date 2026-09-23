// Frozen 2108a60 inference; test target only.
@testable import Core
import Foundation

extension AccuracyV6BaselineRouter {
    /// Refine a lexer word only when alternating literal words and plausible romaji explain it.
    /// Source characters are sliced verbatim; no generated text or persistent language state.
    func mixedSegments(_ word: String) -> [(text: String, japanese: Bool)]? {
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
                        || (candidate.count >= 5 && probability(candidate) < 0.1) else { continue }
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
                    && !isRomaji(candidate) && probability(candidate) < 0.02 && afterJapaneseParticle
                let unknown = !lexical && (candidate.count >= 4 || shortEnglishPrefix) && candidate.count <= 20
                    && beforeJapanese && tail.count >= 2
                    && (start > 0 || ((isRomaji(tail) || isRomajiPrefix(tail)) && probability(tail,context:true) >= 0.88))
                    && (afterJapaneseParticle || (start == 0 && candidate.first?.isUppercase == true)
                        || (!isRomaji(candidate) && probability(candidate) < 0.02))
                    && probability(candidate) < (lexicalJapanesePrefix ? 0.7 : 0.4)
                    && !crossesLexicalWord && !swallowsBoundary && !hasJapaneseSuffix()
                if lexical || partialEnglish || unknown { anchors[start,default:[]].append((end+1,candidate)) }
            }
        }
        guard !anchors.isEmpty else { return nil }
        if isRomaji(word) || isRomajiPrefix(word) {
            // A long completed English word after a Japanese particle can itself look like
            // unfinished romaji ("meeting"). Short substrings such as "was" remain Japanese.
            let completedEnglish = anchors.contains { start, values in
                let prefix = String(characters.prefix(start))
                return start >= 2 && isRomaji(prefix) && probability(prefix,context:true) >= 0.95
                    && values.contains { anchor in
                        anchor.text.count >= 5 && (knownEnglish.contains(anchor.text.lowercased())
                            || (knownJapanese.contains(prefix) && !isRomaji(anchor.text)
                                && probability(anchor.text) < 0.1 && anchor.end < characters.count))
                    }
            }
            let leadingEnglish = anchors[0]?.contains { anchor in
                anchor.text.first?.isUppercase == true && knownEnglish.contains(anchor.text.lowercased())
            } == true
            guard completedEnglish || leadingEnglish else { return nil }
        }
        let particles: Set<String> = ["no","ni","de","wo","ha","ga","to","mo","kara","made"]
        var jpScores: [String:Double] = [:]
        func japaneseScore(_ text: String, final: Bool) -> Double? {
            guard text.first?.isUppercase != true, isRomaji(text) || (final && isRomajiPrefix(text)) else { return nil }
            if final && ["n","d","w","h","g","t","k"].contains(text) { return 0 }
            if particles.contains(text) { return 0.5 }
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
        func offer(_ path: Path, end: Int, text: String, japanese: Bool, score: Double) {
            var next = path
            next.pieces.append((text,japanese)); next.score += score - 0.8
            next.hasEnglish = next.hasEnglish || !japanese; next.hasJapanese = next.hasJapanese || japanese
            let key = "\(japanese)-\(next.hasEnglish)-\(next.hasJapanese)-\(min(next.pieces.count,3))"
            if paths[end]?[key]?.score ?? -Double.infinity < next.score { paths[end,default:[:]][key] = next }
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
                        // A very short unknown can only follow an already established
                        // English + particle run, not peel a fragment off a longer word.
                        if !lexical && anchor.text.count == 3
                            && !(path.hasEnglish && path.pieces.last?.japanese == true
                                && particles.contains(path.pieces.last!.text)) { continue }
                        let preceding = String(characters.prefix(start))
                        let afterParticle = ["no","ni","de","wo","ha","ga","to","mo","kara","made"].contains(where:preceding.hasSuffix)
                        let score = lexical ? 3 + Double(anchor.text.count)*0.2
                            : afterParticle ? 1.5 + Double(anchor.text.count)*0.12 : 1 - Double(anchor.text.count)*0.06
                        // Strong Japanese morphology helps locate an uncertain English word,
                        // but must not bias Japanese suffixes after an already identified word.
                        let japanesePrefix = path.pieces.last?.japanese == true ? path.pieces.last!.text : ""
                        var boundaryEvidence = 0.0
                        if lexical && japanesePrefix.count >= 3 && !knownJapanese.contains(japanesePrefix)
                            && !particles.contains(where:japanesePrefix.hasSuffix) {
                            boundaryEvidence -= 3
                        }
                        if !lexical && anchor.end < characters.count && japanesePrefix.count >= 4 {
                            if knownJapanese.contains(japanesePrefix) { boundaryEvidence = 2.5 }
                            else if particles.contains(where: { japanesePrefix.hasSuffix($0) && knownJapanese.contains(String(japanesePrefix.dropLast($0.count))) }) {
                                boundaryEvidence = 2.0
                            }
                        }
                        offer(path,end:anchor.end,text:anchor.text,japanese:false,score:score + boundaryEvidence)
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
        guard let best = paths[characters.count]?.values.filter({ $0.hasEnglish && $0.hasJapanese && ($0.pieces.count >= 3 || $0.pieces.first?.japanese == true) }).max(by: { a,b in
            if a.score != b.score { return a.score < b.score }
            return a.pieces.map { $0.text }.joined(separator:"|") < b.pieces.map { $0.text }.joined(separator:"|")
        }), best.score > 0 else { return nil }
        return best.pieces
    }
}
