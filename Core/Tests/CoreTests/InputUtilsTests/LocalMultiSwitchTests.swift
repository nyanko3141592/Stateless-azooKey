@testable import Core
import Foundation
import Testing

private func languageLabels(_ d: JevMixedDecision) -> [Bool] {
    let decisions = Dictionary(uniqueKeysWithValues:d.decisions.map { ($0.index,$0.japaneseStart) })
    return d.spans.enumerated().flatMap { i,span in
        let offset = decisions[i] ?? nil
        return Array(span.text).indices.map { !span.protected && offset != nil && $0 >= offset! }
    }
}
@Test func localMultiSwitchDevelopment() throws {
    let m = try LocalLanguageRouter()
    let cases: [[(String,Bool)]] = [
        [("GitHub",false),("noshoudai",true),("mail",false),("gakimasenn",true)],
        [("Slack",false),("no",true),("screenshot",false),("wookuttekudasai",true)],
        [("GitHub",false),("no",true),("branch",false),("wokaetekudasai",true)],
        [("kono",true),("file",false),("wo",true),("Slack",false),("dekyouyuushitekudasai",true)],
        [("ashitano",true),("meeting",false),("no",true),("link",false),("wooshietekudasai",true)]
    ]
    for pieces in cases {
        let raw = pieces.map(\.0).joined()
        let d = m.classify(raw)
        let expected = pieces.flatMap { Array(repeating:$0.1,count:$0.0.count) }
        print("MULTI",raw,d.spans.enumerated().map { i,s in (s.text,d.decisions.first { $0.index == i }?.japaneseStart) })
        #expect(d.spans.map(\.text).joined() == raw)
        #expect(languageLabels(d) == expected, "\(raw)")
    }
}

private struct MultiCase: Decodable {
    let id: String
    let category: String
    let raw: String
    let japaneseRanges: [[Int]]
    let englishRanges: [[Int]]
}
@Test func localMultiSwitchFreshEvaluation() throws {
    let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let cases = try JSONDecoder().decode([MultiCase].self,from:Data(contentsOf:root.appendingPathComponent("LocalModel/multiswitch-evaluation.json")))
    let current = try LocalLanguageRouter(); let previous = try PreviousLocalLanguageRouter()
    var rows: [[String:Any]] = []
    for c in cases {
        for (name,classify) in [("before",previous.classify),("after",current.classify)] {
            let d = classify(c.raw)
            #expect(d.spans.map(\.text).joined() == c.raw)
            let expected = Array(c.raw).indices.map { i in c.japaneseRanges.contains { i >= $0[0] && i < $0[1] } }
            let wrong = zip(languageLabels(d),expected).filter { $0 != $1 }.count
            var old: [Bool] = []; var reversalFrames = 0; var damagedEnglishFrames = 0; var eligibleFrames = 0
            var times: [Double] = []
            for length in 1...c.raw.count {
                let raw = String(c.raw.prefix(length)); let start = Date(); let pd = classify(raw)
                times.append(Date().timeIntervalSince(start)*1000)
                let labels = languageLabels(pd)
                #expect(pd.spans.map(\.text).joined() == raw)
                #expect(labels.count == length)
                if zip(old,labels).contains(where: { $0 != $1 }) { reversalFrames += 1 }
                let completed = c.englishRanges.filter { $0[1] <= length }
                if !completed.isEmpty {
                    eligibleFrames += 1
                    if completed.contains(where: { labels[$0[0]..<$0[1]].contains(true) }) { damagedEnglishFrames += 1 }
                }
                old = labels
            }
            rows.append(["id":c.id,"category":c.category,"version":name,"raw":c.raw,"exact":wrong == 0,"wrongCharacters":wrong,
                         "labelReversalFrames":reversalFrames,"damagedEnglishFrames":damagedEnglishFrames,"eligibleFrames":eligibleFrames,"millisecondsPerPrefix":times,
                         "routes":d.spans.enumerated().map { i,s in ["text":s.text,"jpStart":d.decisions.first { $0.index == i }?.japaneseStart as Any? ?? NSNull()] }])
        }
    }
    if let path = ProcessInfo.processInfo.environment["LOCAL_MULTI_REPORT"] {
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path))
    }
    for name in ["before","after"] {
        let r = rows.filter { $0["version"] as? String == name }
        print("MULTI FRESH",name,r.filter { $0["exact"] as? Bool == true }.count,"/",r.count,
              "reversals",r.reduce(0) { $0 + ($1["labelReversalFrames"] as! Int) },
              "English damaged",r.reduce(0) { $0 + ($1["damagedEnglishFrames"] as! Int) })
    }
}
@Test func localMultiSwitchRenderingAndCaret() throws {
    let m = try LocalLanguageRouter()
    let raw = "GitHubnobranchwokaetekudasai"
    let d = m.classify(raw)
    var c = JevComposition(); c.replace(raw)
    c.renderLocalLive(decision:d,decisionEpoch:c.editEpoch,trustDecision:true) { "「" + $0 + "」" }
    #expect(c.display == "GitHub「no」branch「wokaetekudasai」")
    for caret in 0...raw.count {
        c.moveCaret(to:caret)
        c.renderLocalLive(decision:d,decisionEpoch:c.editEpoch,trustDecision:true) { "「" + $0 + "」" }
        #expect(c.displayCaretUTF16 >= 0 && c.displayCaretUTF16 <= c.display.utf16.count)
        if caret == 10 { #expect(c.displayCaretUTF16 == "GitHub「no」br".utf16.count) }
    }
    let fullDisplay = c.display
    c.moveCaret(to:10); c.insert("x"); c.deleteBackward(); c.moveCaret(to:raw.count)
    c.renderLocalLive(decision:m.classify(c.raw),decisionEpoch:c.editEpoch,trustDecision:true) { "「" + $0 + "」" }
    #expect(c.display == fullDisplay)
    c.replace("hello");c.renderLocalLive(decision:d,decisionEpoch:c.editEpoch,trustDecision:true) { $0 }
    #expect(c.display == "hello") // exact-source validation rejects an unrelated partition
    let first = languageLabels(m.classify(raw))
    for _ in 0..<20 { #expect(languageLabels(m.classify(raw)) == first) }
}

@Test func localMultiSwitchDoesNotInventParticlesInsideEnglishCompounds() throws {
    let m = try LocalLanguageRouter()
    for word in ["notificationworkflow","downloadmanager","networkconnection"] {
        #expect(m.classify(word).decisions.allSatisfy { $0.japaneseStart == nil })
    }
}
