// Frozen 2108a60 inference; test target only.
@testable import Core
import Foundation

/// A trained logistic language classifier. Inference is pure Swift and never opens a socket.
public final class AccuracyV6BaselineRouter: @unchecked Sendable {
    private struct Model: Decodable { let version: Int; let weights: [String:Double]; let ambiguous: [String]; let boundaryWeights: [Double]; let knownEnglish: [String]; let knownJapanese: [String] }
    private let weights: [String:Double]
    let ambiguous: Set<String>
    private let boundaryWeights: [Double]
    let knownEnglish: Set<String>
    let knownJapanese: Set<String>
    let englishPrefixes: Set<String>
    public static let shared: AccuracyV6BaselineRouter = {
        do { return try AccuracyV6BaselineRouter() }
        catch { fatalError("Bundled local language model is missing or invalid: \(error)") }
    }()
    public init() throws {
        guard let url = Bundle.module.url(forResource:"LocalLanguageModel",withExtension:"json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let model = try JSONDecoder().decode(Model.self,from:Data(contentsOf:url))
        guard model.version == 3, !model.weights.isEmpty, model.weights.values.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        weights = model.weights; ambiguous = Set(model.ambiguous)
        guard model.boundaryWeights.count == 12, model.boundaryWeights.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        boundaryWeights = model.boundaryWeights; knownEnglish = Set(model.knownEnglish)
        knownJapanese = Set(model.knownJapanese)
        englishPrefixes = Set(model.knownEnglish.flatMap { w in (1...w.count).map { String(w.prefix($0)) } })
    }
    // The same phonotactic features as train.py, compiled once rather than per key.
    private static let syllable = #"(?:[aeiou]|n|(?:[kgsztdnhbpmrwyfvj]|sh|ch|ts|ky|gy|ny|hy|by|py|my|ry|jy|sy|ty|dy|kw|gw|xt|lt)[aeiou]|([kstpbgdz])\1?[aeiou])"#
    private static let completeRomaji = try! NSRegularExpression(pattern: "^(?:" + syllable + #"|([kstpbgdz])(?=[kstpbgdz]))+$"#)
    private static let partialRomaji = try! NSRegularExpression(pattern: "^(?:" + syllable + #"|([kstpbgdz])(?=[kstpbgdz]))*(?:[kgsztdnhbpmrwyfvj]|sh|ch|ts|ky|gy|ny|hy|by|py|my|ry|jy|sy|ty|dy)?$"#)
    private static func matches(_ regex: NSRegularExpression, _ word: String) -> Bool {
        regex.firstMatch(in:word,range:NSRange(word.startIndex...,in:word)) != nil
    }
    func isRomaji(_ word: String) -> Bool { Self.matches(Self.completeRomaji,word.lowercased()) }
    func isRomajiPrefix(_ word: String) -> Bool { Self.matches(Self.partialRomaji,word.lowercased()) }
    public func japaneseProbability(_ word: String, context: Bool = false, left: String = "", right: String = "", englishNeighbors: Bool = false) -> Double {
        let w = word.lowercased(); let chars = Array(w)
        var features: Set<String> = ["bias","w:" + w,"len:" + String(min(chars.count / 3,6))]
        features.insert(isRomaji(w) ? "romaji-complete" : Self.matches(Self.partialRomaji,w) ? "romaji-prefix" : "romaji-invalid")
        for n in 1...4 where chars.count >= n {
            for i in 0...(chars.count-n) { features.insert("g:" + String(chars[i..<i+n])) }
            features.insert("p:" + String(chars.prefix(n))); features.insert("s:" + String(chars.suffix(n)))
        }
        if word.contains(where: { $0.isUppercase }) { features.insert("capital") }
        if word.contains(where: { $0.isNumber }) || word.contains("_") { features.insert("identifier") }
        if englishNeighbors && chars.count <= 5 && !ambiguous.contains(w) { features.insert("english-neighbors") }
        if ambiguous.contains(w) {
            features.insert("ctx:" + w + ":" + (context ? "1" : "0"))
            if !left.isEmpty { features.insert("left:" + w + ":" + left.lowercased()) }
            if !right.isEmpty { features.insert("right:" + w + ":" + right.lowercased()) }
        }
        let value = features.reduce(0.0) { $0 + (weights[$1] ?? 0) }
        return 1 / (1 + exp(-max(-50,min(50,value))))
    }
    public func classify(_ raw: String) -> JevMixedDecision {
        let start = Date()
        var spans: [JevInputSpan] = []
        var segmented: [Int:Bool] = [:]
        for span in JevMixedLexer.spans(raw) {
            if !span.protected, let pieces = mixedSegments(span.text) {
                for piece in pieces {
                    segmented[spans.count] = piece.japanese
                    spans.append(.init(text:piece.text,protected:false))
                }
            } else { spans.append(span) }
        }
        let targets = spans.indices.filter { !spans[$0].protected }
        let initial = targets.map { japaneseProbability(spans[$0].text) }
        func strongJapanese(_ index: Int, _ probability: Double) -> Bool {
            let word = spans[index].text
            return word.count > 4 && word.first?.isUppercase != true && !knownEnglish.contains(word.lowercased()) && probability >= 0.8
        }
        let context = zip(targets,initial).contains { strongJapanese($0.0,$0.1) }
        let englishCount = targets.filter { knownEnglish.contains(spans[$0].text.lowercased()) && !ambiguous.contains(spans[$0].text.lowercased()) }.count
        let japaneseAnchors = targets.filter {
            let w = spans[$0].text.lowercased()
            return knownJapanese.contains(w) && !ambiguous.contains(w)
                || (w.count >= 8 && isRomaji(w) && ["masu","masen","masenn","mashita","desu","deshita","kudasai","shite","shita","nai","natta","tai","masuka","desuka","mashou"].contains(where:w.hasSuffix))
        }
        let englishSentence = englishCount >= 2 && japaneseAnchors.isEmpty
        var decisions: [JevSpanDecision] = []
        for (position,index) in targets.enumerated() {
            let word = spans[index].text
            let left = position > 0 ? spans[targets[position-1]].text : ""
            let right = position+1 < targets.count ? spans[targets[position+1]].text : ""
            let englishNeighbors = position > 0 && position+1 < initial.count && initial[position-1] < 0.2 && initial[position+1] < 0.2
            let lower = word.lowercased()
            let right2 = position+2 < targets.count ? spans[targets[position+2]].text.lowercased() : ""
            let englishPhrase = (lower == "to" && ["me","you","us","them","him","her","it"].contains(right.lowercased()) && !left.isEmpty && !knownJapanese.contains(left.lowercased()))
                || (lower == "no" && knownEnglish.contains(right.lowercased()) && knownEnglish.contains(right2) && !ambiguous.contains(right.lowercased()) && !ambiguous.contains(right2))
            let p = japaneseProbability(word,context:context && !englishPhrase,left:left,right:right,englishNeighbors:englishNeighbors)
            var offset: Int? = p >= 0.5 ? 0 : nil
            var confidence = max(p,1-p)
            if knownEnglish.contains(lower) && !ambiguous.contains(lower) { offset = nil }
            // A recognizable English prefix stays literal until there is positive Japanese evidence.
            if englishPrefixes.contains(lower) && !knownJapanese.contains(lower) && !ambiguous.contains(lower) { offset = nil }
            // Preserve proper names and identifiers unless the boundary model finds an explicit Japanese tail.
            if word.first?.isUppercase == true || word.contains("_") || word.contains("'") || word.contains(where: { $0.isNumber }) {
                offset = nil
            }
            // Two letters cannot reliably distinguish romaji from the start of an English word.
            // Keep them literal until this same composition supplies Japanese context.
            let otherJapanese = zip(targets,initial).contains { $0.0 != index && strongJapanese($0.0,$0.1) }
            if word.count <= 2 && !otherJapanese { offset = nil }
            if englishSentence && !knownJapanese.contains(lower) && !ambiguous.contains(lower) { offset = nil }
            // Score English + Japanese continuations, not just a particle at the very end.
            // Whole known English words win over accidental romaji-looking suffixes (video, made...).
            var bestUtility = -Double.infinity
            if !knownEnglish.contains(word.lowercased()), word.count >= 4 {
                let characters = Array(word)
                for split in 2...(characters.count-2) {
                    let prefix = String(characters.prefix(split))
                    let suffix = String(characters.dropFirst(split))
                    guard ["de","wo","ha","ni","ga","to","no","kara","made"].contains(where:suffix.hasPrefix), isRomaji(suffix) else { continue }
                    if p > 0.95 && prefix.first?.isUppercase != true && isRomaji(prefix) { continue }
                    guard knownEnglish.contains(prefix.lowercased()) || JevMixedRouter.permitsEnglishPrefix(prefix) else { continue }
                    let english = 1 - japaneseProbability(prefix)
                    guard english >= 0.8 else { continue }
                    let japanese = japaneseProbability(suffix,context:context,left:prefix)
                    // A short unrecognizable English fragment must not peel off a Japanese word.
                    guard knownEnglish.contains(prefix.lowercased()) || (prefix.count >= 3 && prefix.contains(where: { $0.isUppercase })) else { continue }
                    let x: [Double] = [1, context ? 1 : 0, english, japanese, 0,
                        Double(min(prefix.count,12))/12, prefix.contains(where: { $0.isUppercase }) ? 1 : 0,
                        context ? english : 0, Double(min(suffix.count,12))/12, isRomaji(suffix) ? 1 : 0,
                        knownEnglish.contains(prefix.lowercased()) ? 1 : 0, japaneseProbability(word)]
                    let value = zip(x,boundaryWeights).reduce(0.0) { $0 + $1.0 * $1.1 }
                    let score = 1 / (1 + exp(-max(-50,min(50,value))))
                    // Logistic scores saturate for long Japanese tails. Rank accepted boundaries by
                    // English evidence with a small length penalty to avoid swallowing Japanese into the name.
                    let utility = english + (knownEnglish.contains(prefix.lowercased()) ? 0.1 : 0) - 0.002 * Double(prefix.count)
                    if score > 0.85 && utility > bestUtility {
                        bestUtility = utility; offset = prefix.count; confidence = score
                    }
                }
            }
            if let japanese = segmented[index] { offset = japanese ? 0 : nil }
            decisions.append(.init(index:index,japaneseStart:offset,probability:confidence))
        }
        // Revisit only completed, short romaji words once this same composition
        // contains a confidently converted Japanese phrase. A growing English prefix
        // stays literal until whitespace closes it; names and known English stay intact.
        let resolvedJapaneseContext = decisions.contains { decision in
            guard let offset = decision.japaneseStart else { return false }
            let suffix = String(spans[decision.index].text.dropFirst(offset))
            return suffix.count >= 4 && (isRomaji(suffix) || isRomajiPrefix(suffix))
                && japaneseProbability(suffix,context:true) >= 0.88
        }
        if resolvedJapaneseContext {
            decisions = decisions.map { decision in
                let index = decision.index
                let word = spans[index].text
                let lower = word.lowercased()
                guard decision.japaneseStart == nil, segmented[index] == nil,
                      word == lower, !knownEnglish.contains(lower), isRomaji(word),
                      index+1 < spans.count, spans[index+1].protected,
                      spans[index+1].text.allSatisfy(\.isWhitespace) else { return decision }
                let contextual = japaneseProbability(word,context:true)
                let particle = word.count <= 2 && ambiguous.contains(lower) && contextual >= 0.8
                let shortRomaji = (3...4).contains(word.count) && !ambiguous.contains(lower) && contextual >= 0.25
                guard particle || shortRomaji else { return decision }
                return .init(index:index,japaneseStart:0,probability:particle ? contextual : decision.probability)
            }
        }
        return .init(spans:spans,decisions:decisions,elapsedMS:Int(Date().timeIntervalSince(start)*1000))
    }
}
