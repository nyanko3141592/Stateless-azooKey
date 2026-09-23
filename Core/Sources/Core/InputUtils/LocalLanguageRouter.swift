import Foundation

/// A trained logistic language classifier. Inference is pure Swift and never opens a socket.
public final class LocalLanguageRouter: @unchecked Sendable {
    private struct Model: Decodable { let version: Int; let weights: [String:Double]; let ambiguous: [String]; let boundaryWeights: [Double]; let knownEnglish: [String] }
    private let weights: [String:Double]
    private let ambiguous: Set<String>
    private let boundaryWeights: [Double]
    private let knownEnglish: Set<String>
    public static let shared: LocalLanguageRouter = {
        do { return try LocalLanguageRouter() }
        catch { fatalError("Bundled local language model is missing or invalid: \(error)") }
    }()
    public init() throws {
        guard let url = Bundle.module.url(forResource:"LocalLanguageModel",withExtension:"json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let model = try JSONDecoder().decode(Model.self,from:Data(contentsOf:url))
        guard model.version == 1, !model.weights.isEmpty, model.weights.values.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        weights = model.weights; ambiguous = Set(model.ambiguous)
        guard model.boundaryWeights.count == 8, model.boundaryWeights.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        boundaryWeights = model.boundaryWeights; knownEnglish = Set(model.knownEnglish)
    }
    public func japaneseProbability(_ word: String, context: Bool = false, left: String = "", right: String = "", englishNeighbors: Bool = false) -> Double {
        let w = word.lowercased(); let chars = Array(w)
        var features: Set<String> = ["bias","w:" + w,"len:" + String(min(chars.count / 3,6))]
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
        let start = Date(); let spans = JevMixedLexer.spans(raw)
        let targets = spans.indices.filter { !spans[$0].protected }
        let initial = targets.map { japaneseProbability(spans[$0].text) }
        let context = zip(targets,initial).contains { spans[$0.0].text.count > 4 && $0.1 >= 0.8 }
        var decisions: [JevSpanDecision] = []
        for (position,index) in targets.enumerated() {
            let word = spans[index].text
            let left = position > 0 ? spans[targets[position-1]].text : ""
            let right = position+1 < targets.count ? spans[targets[position+1]].text : ""
            let englishNeighbors = position > 0 && position+1 < initial.count && initial[position-1] < 0.2 && initial[position+1] < 0.2
            let p = japaneseProbability(word,context:context,left:left,right:right,englishNeighbors:englishNeighbors)
            var offset: Int? = p >= 0.5 ? 0 : nil
            var confidence = max(p,1-p)
            // The second trained classifier scores a boundary, rather than generating text.
            var bestScore = 0.8
            for suffix in ["desu","kara","made","de","wo","ha","ni","ga","to","no"] where word.hasSuffix(suffix) && word.count > suffix.count + 1 {
                let prefix = String(word.dropLast(suffix.count))
                guard JevMixedRouter.permitsEnglishPrefix(prefix) else { continue }
                let english = 1 - japaneseProbability(prefix)
                let japanese = japaneseProbability(suffix,context:context,left:prefix)
                let x: [Double] = [1, context ? 1 : 0, english, japanese,
                    knownEnglish.contains(word.lowercased()) ? 1 : 0,
                    Double(min(prefix.count,12))/12, prefix.contains(where: { $0.isUppercase }) ? 1 : 0,
                    context ? english : 0]
                let value = zip(x,boundaryWeights).reduce(0.0) { $0 + $1.0 * $1.1 }
                let score = 1 / (1 + exp(-max(-50,min(50,value))))
                if score > bestScore {
                    bestScore = score; offset = prefix.count; confidence = score
                }
            }
            decisions.append(.init(index:index,japaneseStart:offset,probability:confidence))
        }
        return .init(spans:spans,decisions:decisions,elapsedMS:Int(Date().timeIntervalSince(start)*1000))
    }
}
