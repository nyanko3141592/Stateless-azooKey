@testable import Core
import Foundation
import Testing

@Test func localModelMatchesPythonExport() throws {
    let model = try LocalLanguageRouter()
    #expect(abs(model.japaneseProbability("Google", context: true, left: "", right: "") - 1.9163443779027892e-05) < 1e-10)
    #expect(abs(model.japaneseProbability("no", context: true, left: "Meet", right: "URL") - 0.4008281668015656) < 1e-10)
    #expect(abs(model.japaneseProbability("no", context: true, left: "", right: "errors") - 0.065696449685893) < 1e-10)
    #expect(abs(model.japaneseProbability("no", context: false, left: "", right: "") - 0.03494276746927694) < 1e-10)
    #expect(abs(model.japaneseProbability("Reactde", context: true, left: "", right: "") - 4.4297097684638684e-05) < 1e-10)
    #expect(abs(model.japaneseProbability("Meetno", context: true, left: "", right: "") - 2.3866936491466665e-05) < 1e-10)
    #expect(abs(model.japaneseProbability("gadetanode", context: true, left: "", right: "") - 0.996789327101692) < 1e-10)
}
@Test func localModelRoutesMixedExamplesWithoutNetwork() throws {
    let model = try LocalLanguageRouter()
    for raw in ["Google Meetno URL wo Slack de okuttemoraemasuka?", "Your session has expired tohyoujisarete, roguinshinaoshitemo sakinisusumemasenn.", "hennshinha Thank you for your help deiikana.mousukoshiteineinishitai.", "git pull shitara conflict ga detanode, kono PRno merge ha sukoshimattekudasai."] {
        let d = model.classify(raw)
        print("LOCAL ROUTING", raw, zip(d.spans.indices,d.spans).filter { !$0.1.protected }.map { index,span in "\(span.text):\(d.decisions.first { $0.index == index }?.japaneseStart.map(String.init) ?? "E")" })
        #expect(d.spans.map(\.text).joined() == raw)
        #expect(d.decisions.count == d.spans.filter { !$0.protected }.count)
    }
    let d = model.classify("Reactde kaihatsu")
    #expect(d.decisions[0].japaneseStart == 5)
    #expect(d.decisions[1].japaneseStart == 0)
    let plain = model.classify("no errors")
    #expect(plain.decisions.allSatisfy { $0.japaneseStart == nil })
}
@Test func localModelProtectsTexAndIsIndependentOfPastInput() throws {
    let m = try LocalLanguageRouter()
    let raw = #"koreha $\frac{a}{b}$ desu"#
    let first = m.classify(raw)
    _ = m.classify("Please write no errors")
    let second = m.classify(raw)
    #expect(first.decisions.map(\.japaneseStart) == second.decisions.map(\.japaneseStart))
    #expect(first.decisions.allSatisfy { !first.spans[$0.index].protected })
}
@Test func localModelLatency() throws {
    let m = try LocalLanguageRouter(); let raw = "Google Meet no URL wo Slack de okuttemoraemasuka?"
    let start = Date()
    for _ in 0..<100 { _ = m.classify(raw) }
    print("LOCAL MODEL mean ms",Date().timeIntervalSince(start)*10)
}

@Test func localModelKeepsEnglishInEnglishSentences() throws {
    let m = try LocalLanguageRouter()
    for raw in ["I would like a banana and a tomato salad.", "Please rename the folder before you upload it.", "There are no changes to the data."] {
        #expect(m.classify(raw).decisions.allSatisfy { $0.japaneseStart == nil }, "\(raw)")
    }
}
@Test func localModelFindsEnglishNameThenLongJapaneseTail() throws {
    let m = try LocalLanguageRouter()
    for (raw,offset) in [("Slackdekyouyuushitekudasai",5),("Gmailnihenjishiteokimashita",5),("Keynotedehenshuushitai",7),("Figmanofairuwohirakimashita",5)] {
        let d = m.classify(raw)
        #expect(d.decisions.count == 1)
        #expect(d.decisions.first?.japaneseStart == offset, "\(raw)")
    }
    #expect(m.classify("kyouha Bluetooth ga tsunagarimasenn").decisions[1].japaneseStart == nil)
}
@Test func localModelRestoresRoutingAfterMiddleEdit() throws {
    let m = try LocalLanguageRouter()
    let raw = "Google Meetno URL wo Slack de okuttemoraemasuka?"
    let first = m.classify(raw)
    let changed = String(raw.prefix(20)) + "x" + String(raw.dropFirst(20))
    _ = m.classify(changed)
    #expect(m.classify(raw).decisions.map(\.japaneseStart) == first.decisions.map(\.japaneseStart))
    var composition = JevComposition(); composition.replace(raw)
    composition.renderLocalLive(decision:first,decisionEpoch:composition.editEpoch,trustDecision:true) { "「" + $0 + "」" }
    let originalDisplay = composition.display
    composition.moveCaret(to:20); composition.insert("x"); composition.deleteBackward(); composition.moveCaret(to:raw.count)
    composition.renderLocalLive(decision:m.classify(composition.raw),decisionEpoch:composition.editEpoch,trustDecision:true) { "「" + $0 + "」" }
    #expect(composition.raw == raw)
    #expect(composition.display == originalDisplay)
    #expect(composition.commit() == originalDisplay)
    #expect(composition.raw.isEmpty)
}
@Test func localModelPreservesOpaqueContentDuringLiveRendering() throws {
    let m = try LocalLanguageRouter()
    for literal in ["naomi@example.com","yuki+dev@example.net","/Users/naomi/Documents","~/Library/Logs/app.log",#"$\frac{a}{b}$"#,"`git rebase --continue`"] {
        let raw = "koreha " + literal + " desu"
        var c = JevComposition(); c.replace(raw)
        c.renderLocalLive(decision:m.classify(raw),decisionEpoch:c.editEpoch,trustDecision:true) { "「" + $0 + "」" }
        #expect(c.display.contains(literal), "\(literal)")
    }
}
