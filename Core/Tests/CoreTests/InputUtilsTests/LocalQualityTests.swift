@testable import Core
import Foundation
import Testing

private struct QualityCase: Decodable {
    let id: String
    let split: String
    let category: String
    let raw: String
    let japaneseRanges: [[Int]]
}
private func labels(_ decision: JevMixedDecision) -> [Bool] {
    let offsets = Dictionary(decision.decisions.map { ($0.index,$0.japaneseStart) }, uniquingKeysWith: { a,_ in a })
    return decision.spans.enumerated().flatMap { index,span in
        let offset = offsets[index] ?? nil
        return Array(span.text).indices.map { !span.protected && offset != nil && $0 >= offset! }
    }
}
@Test func localQualityBenchmark() throws {
    let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let cases = try JSONDecoder().decode([QualityCase].self,from:Data(contentsOf:root.appendingPathComponent("LocalModel/evaluation.json")))
    let model = try LocalLanguageRouter()
    var rows: [[String:Any]] = []
    for c in cases {
        let d = model.classify(c.raw)
        #expect(d.spans.map(\.text).joined() == c.raw)
        let actual = labels(d)
        let expected = Array(c.raw).indices.map { i in c.japaneseRanges.contains { i >= $0[0] && i < $0[1] } }
        #expect(actual.count == expected.count)
        var corruptLiteralPrefixFrames = 0
        var prefixFrames = 0
        for length in 1...c.raw.count {
            let prefix = String(c.raw.prefix(length))
            let pd = model.classify(prefix)
            #expect(pd.spans.map(\.text).joined() == prefix)
            let pl = labels(pd)
            // Only all-English cases: report wrong Japanese conversion while typing, including short ambiguity.
            if c.category == "literal" {
                prefixFrames += 1
                if pl.contains(true) { corruptLiteralPrefixFrames += 1 }
            }
        }
        let bad = zip(actual,expected).filter { $0 != $1 }.count
        let routes = d.decisions.map { x in ["text":d.spans[x.index].text,"jpStart":x.japaneseStart as Any? ?? NSNull()] as [String:Any] }
        rows.append(["id":c.id,"split":c.split,"category":c.category,"raw":c.raw,"exact":bad == 0,"wrongCharacters":bad,"characters":actual.count,"routes":routes,"literalPrefixFrames":prefixFrames,"corruptLiteralPrefixFrames":corruptLiteralPrefixFrames])
    }
    if let path = ProcessInfo.processInfo.environment["LOCAL_QUALITY_REPORT"] {
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path))
    }
    for split in ["development","evaluation","challenge"] {
        let part = rows.filter { $0["split"] as? String == split }
        print("QUALITY",split,"exact",part.filter { $0["exact"] as? Bool == true }.count,"/",part.count)
    }
}
