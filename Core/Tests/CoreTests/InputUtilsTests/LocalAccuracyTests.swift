@testable import Core
import Foundation
import Testing

private struct AccuracyCase: Decodable {
    let id: String
    let raw: String
    let japaneseRanges: [[Int]]
    let englishRanges: [[Int]]
}
private func accuracyLabels(_ d: JevMixedDecision) -> [Bool] {
    d.spans.enumerated().flatMap { i,span in
        let offset = d.decisions.first { $0.index == i }?.japaneseStart
        return Array(span.text).indices.map { !span.protected && offset != nil && $0 >= offset! }
    }
}
@Test func localAccuracyComparison() throws {
    guard let fixture = ProcessInfo.processInfo.environment["LOCAL_ACCURACY_CASES"],
          let output = ProcessInfo.processInfo.environment["LOCAL_ACCURACY_REPORT"] else { return }
    let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let cases = try JSONDecoder().decode([AccuracyCase].self,from:Data(contentsOf:root.appendingPathComponent(fixture)))
    let baseline = try AccuracyBaselineRouter(); let model = try LocalLanguageRouter()
    let latestBaseline = try AccuracyV3BaselineRouter()
    let v4Baseline = try AccuracyV4BaselineRouter()
    let v5Baseline = try AccuracyV5BaselineRouter()
    let v6Baseline = try AccuracyV6BaselineRouter()
    let baselineVersion = ProcessInfo.processInfo.environment["LOCAL_ACCURACY_BASELINE"] ?? "60a4e9f"
    let baselineClassify: (String) -> JevMixedDecision = { raw in
        if baselineVersion == "2108a60" { return v6Baseline.classify(raw) }
        if baselineVersion == "707b161" { return v5Baseline.classify(raw) }
        if baselineVersion == "781996f" { return v4Baseline.classify(raw) }
        if baselineVersion == "bf0888d" { return latestBaseline.classify(raw) }
        return baseline.classify(raw)
    }
    var rows: [[String:Any]] = []
    for c in cases {
        for range in c.japaneseRanges + c.englishRanges {
            try #require(range.count == 2)
            #expect(range[0] >= 0 && range[0] < range[1] && range[1] <= c.raw.count)
        }
        for (version,classify) in [(baselineVersion,baselineClassify),("current",model.classify)] {
            let expected = Array(c.raw).indices.map { i in c.japaneseRanges.contains { i >= $0[0] && i < $0[1] } }
            let final = classify(c.raw)
            let labels = accuracyLabels(final)
            var old: [Bool] = []; var damage = 0; var eligible = 0; var reversals = 0; var times: [Double] = []
            for length in 1...c.raw.count {
                let raw = String(c.raw.prefix(length)); let start = Date(); let d = classify(raw)
                times.append(Date().timeIntervalSince(start)*1000)
                #expect(d.spans.map(\.text).joined() == raw)
                let current = accuracyLabels(d)
                if zip(old,current).contains(where: { $0 != $1 }) { reversals += 1 }
                let completed = c.englishRanges.filter { $0[1] <= length }
                if !completed.isEmpty {
                    eligible += 1
                    if completed.contains(where: { current[$0[0]..<$0[1]].contains(true) }) { damage += 1 }
                }
                old = current
            }
            rows.append(["id":c.id,"raw":c.raw,"version":version,"exact":labels == expected,
                         "damagedEnglishFrames":damage,"eligibleFrames":eligible,"labelReversalFrames":reversals,
                         "millisecondsPerPrefix":times,"routes":final.spans.enumerated().map { i,s in
                            ["text":s.text,"jpStart":final.decisions.first { $0.index == i }?.japaneseStart as Any? ?? NSNull()]
                         }])
        }
    }
    try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output))
    for c in cases {
        let previous = rows.first { $0["id"] as? String == c.id && $0["version"] as? String == baselineVersion }!
        let current = rows.first { $0["id"] as? String == c.id && $0["version"] as? String == "current" }!
        #expect(previous["exact"] as? Bool != true || current["exact"] as? Bool == true, "Lost a correct baseline partition: \(c.raw)")
    }
    for version in [baselineVersion,"current"] {
        let r = rows.filter { $0["version"] as? String == version }
        print("ACCURACY",version,r.filter { $0["exact"] as? Bool == true }.count,"/",r.count,
              "damage",r.reduce(0) { $0 + ($1["damagedEnglishFrames"] as! Int) },
              "reversals",r.reduce(0) { $0 + ($1["labelReversalFrames"] as! Int) })
    }
}
