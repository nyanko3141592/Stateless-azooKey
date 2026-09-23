import Foundation

extension LocalLanguageRouter {
    /// Refine a lexer word only when alternating literal words and plausible romaji explain it.
    /// Source characters are sliced verbatim; no generated text or persistent language state.
    func mixedSegments(_ word: String) -> [(text: String, japanese: Bool)]? {
        let characters = Array(word)
        guard characters.count >= 9, characters.count <= 160,
              characters.allSatisfy({ $0.isASCII && $0.isLetter }),
              !knownEnglish.contains(word.lowercased()), !englishPrefixes.contains(word.lowercased()), !isRomaji(word) else { return nil }
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
        struct Path {
            var pieces: [(text: String, japanese: Bool)]
            var score: Double
            var hasEnglish: Bool
            var hasJapanese: Bool
        }
        // Boundaries occur only around a full lexical English anchor, never arbitrary English fragments.
        var anchors: [Int:[(end: Int,text: String)]] = [:]
        for start in 0..<characters.count {
            var candidate = ""
            for end in start..<min(characters.count,start+32) {
                candidate.append(characters[end])
                let lexical = compoundEnds[start]?.contains(end+1) == true
                guard candidate.count >= 3, !ambiguous.contains(candidate.lowercased()),
                      !knownJapanese.contains(candidate.lowercased()),
                      !isRomaji(candidate) || candidate.first?.isUppercase == true || (lexical && candidate.count >= 5) else { continue }
                let tail = String(characters.dropFirst(end+1))
                let beforeJapanese = ["no","ni","de","wo","ha","ga","to","kara"].contains(where:tail.hasPrefix)
                    || ["n","d","w","h","g","t","k"].contains(tail)
                let englishStem = candidate.count > 4 && (4..<candidate.count).contains {
                    let prefix = String(candidate.prefix($0))
                    return knownEnglish.contains(prefix.lowercased()) && !isRomaji(prefix)
                }
                let unknown = !lexical && candidate.count >= 4 && candidate.count <= 20 && beforeJapanese
                    && !isRomaji(candidate) && japaneseProbability(candidate) < (englishStem ? 0.4 : 0.02)
                if lexical || unknown { anchors[start,default:[]].append((end+1,candidate)) }
            }
        }
        guard !anchors.isEmpty else { return nil }
        if isRomajiPrefix(word) {
            // A long completed English word after a Japanese particle can itself look like
            // unfinished romaji ("meeting"). Short substrings such as "was" remain Japanese.
            let completedEnglish = anchors.contains { start, values in
                let prefix = String(characters.prefix(start))
                return start >= 2 && ["no","ni","de","wo","ha","ga","to"].contains(where:prefix.hasSuffix)
                    && values.contains { $0.end == characters.count && $0.text.count >= 5 && knownEnglish.contains($0.text.lowercased()) }
            }
            guard completedEnglish else { return nil }
        }
        let particles: Set<String> = ["no","ni","de","wo","ha","ga","to","mo","kara","made"]
        var jpScores: [String:Double] = [:]
        func japaneseScore(_ text: String, final: Bool) -> Double? {
            guard text.first?.isUppercase != true, isRomaji(text) || (final && isRomajiPrefix(text)) else { return nil }
            if final && ["n","d","w","h","g","t","k"].contains(text) { return 0 }
            if particles.contains(text) { return 0.5 }
            if final && !knownEnglish.contains(text.lowercased()) && particles.contains(where:text.hasPrefix) { return Double(text.count)*0.12 }
            if let score = jpScores[text] { return score >= 0 ? score : nil }
            let p = japaneseProbability(text,context:true)
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
                    if !knownJapanese.contains(lower) && !ambiguous.contains(lower)
                        && (englishPrefixes.contains(lower) || (stem && japaneseProbability(tail) < 0.4) || (!isRomaji(tail) && japaneseProbability(tail) < 0.02)) {
                        offer(path,end:characters.count,text:tail,japanese:false,score:0.8)
                    }
                }
                if path.pieces.last?.japanese != false {
                    for anchor in anchors[start] ?? [] {
                        let lexical = compoundEnds[start]?.contains(anchor.end) == true
                        let score = lexical ? 1 + Double(anchor.text.count)*0.2 : 1 - Double(anchor.text.count)*0.06
                        offer(path,end:anchor.end,text:anchor.text,japanese:false,score:score)
                    }
                }
                if path.pieces.last?.japanese != true {
                    let ends = Set(anchors.keys.filter { $0 > start } + [characters.count])
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
