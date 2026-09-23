@testable import Core
import Foundation
import Testing

@Test func localModelMatchesPythonExport() throws {
    let model = try LocalLanguageRouter()
    #expect(abs(model.japaneseProbability("Google", context: true, left: "", right: "") - 0.000139548623990774) < 1e-10)
    #expect(abs(model.japaneseProbability("no", context: true, left: "Meet", right: "URL") - 0.8631460956905836) < 1e-10)
    #expect(abs(model.japaneseProbability("no", context: true, left: "", right: "errors") - 0.04778796073528099) < 1e-10)
    #expect(abs(model.japaneseProbability("no", context: false, left: "", right: "") - 0.028838129692233976) < 1e-10)
    #expect(abs(model.japaneseProbability("Reactde", context: true, left: "", right: "") - 0.0003321560693020903) < 1e-10)
    #expect(abs(model.japaneseProbability("Meetno", context: true, left: "", right: "") - 0.0020264119383435154) < 1e-10)
    #expect(abs(model.japaneseProbability("gadetanode", context: true, left: "", right: "") - 0.9984808243560673) < 1e-10)
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
