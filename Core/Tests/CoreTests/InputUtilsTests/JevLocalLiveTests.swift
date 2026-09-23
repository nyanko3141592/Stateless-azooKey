@testable import Core
import Testing

@Test func localLiveDoesNotRequireAnyNetworkDecision() {
    var b = JevComposition(); b.replace("kyouha React $x_i$")
    var converted: [String] = []
    b.renderLocalLive(decision:nil,decisionEpoch:nil) { converted.append($0); return "今日は" }
    #expect(b.display == "今日は React $x_i$")
    #expect(converted == ["kyouha"])
}
@Test func localLiveWorksAfterEveryKeystrokeAndBackspace() {
    var b = JevComposition()
    for raw in ["k","ky","kyo","kyou","kyouh","kyouha","kyouh"] {
        b.replace(raw)
        b.renderLocalLive(decision:nil,decisionEpoch:nil) { "local(\($0))" }
        #expect(b.display == "local(\(raw))")
    }
}
@Test func localLiveLiteralReplyOnlyAppliesToExactToken() {
    var b = JevComposition(); b.replace("ko"); let epoch = b.editEpoch
    let d = JevMixedDecision(spans:JevMixedLexer.spans("ko"),decisions:[.init(index:0,japaneseStart:nil,probability:1)],elapsedMS:0)
    b.renderLocalLive(decision:d,decisionEpoch:epoch) { _ in "変換" }
    #expect(b.display == "ko")
    b.replace("konnichiha")
    b.renderLocalLive(decision:d,decisionEpoch:epoch) { _ in "こんにちは" }
    #expect(b.display == "こんにちは")
}
@Test func localLiveProtectsUnfinishedMathWithoutAPI() {
    var b = JevComposition(); b.replace(#"koreha $abc_{i"#)
    b.renderLocalLive(decision:nil,decisionEpoch:nil) { _ in "これは" }
    #expect(b.display == #"これは $abc_{i"#)
    b.replace(#"\section{hajimeni}"#)
    b.renderLocalLive(decision:nil,decisionEpoch:nil) { _ in "はじめに" }
    #expect(b.display == #"\section{はじめに}"#)
}
@Test func localLiveIgnoresReplyAfterCommitOrReplacement() {
    var b = JevComposition(); b.replace("ko"); let epoch = b.editEpoch
    let d = JevMixedDecision(spans:JevMixedLexer.spans("ko"),decisions:[.init(index:0,japaneseStart:nil,probability:1)],elapsedMS:0)
    _ = b.commit(); b.replace("ko")
    b.renderLocalLive(decision:d,decisionEpoch:epoch) { _ in "こ" }
    #expect(b.display == "こ")
}
@Test func localLiveAppliesEnglishAnswerWithoutChangingMath() {
    var b = JevComposition(); b.replace(#"hello $x$"#)
    let d = JevMixedDecision(spans:JevMixedLexer.spans(b.raw),decisions:[.init(index:0,japaneseStart:nil,probability:1)],elapsedMS:0)
    b.renderLocalLive(decision:d,decisionEpoch:b.editEpoch) { _ in "変換" }
    #expect(b.display == #"hello $x$"#)
}

private func splitDecision(_ raw: String, probability: Double, offset: Int? = 5) -> JevMixedDecision {
    .init(spans: JevMixedLexer.spans(raw), decisions: [
        .init(index: 0, japaneseStart: 0, probability: 0.9),
        .init(index: 2, japaneseStart: offset, probability: probability)
    ], elapsedMS: 0)
}
@Test func localLiveWeakRefreshDoesNotUndoAcceptedParticle() {
    let old = splitDecision("kyouha Reactde", probability: 0.8)
    let update = splitDecision("kyouha Reactde kaihatsu", probability: 0.54).stabilizing(with: old)
    var b = JevComposition(); b.replace("kyouha Reactde kaihatsu")
    b.renderLocalLive(decision: update, decisionEpoch: b.editEpoch) { ["kyouha":"今日は", "de":"で", "kaihatsu":"開発"][$0] ?? $0 }
    #expect(b.display == "今日は Reactで 開発")
}
@Test func localLiveConfidentCorrectionCanReplaceAcceptedSplit() {
    let update = splitDecision("kyouha Reactde", probability: 0.95, offset: nil)
        .stabilizing(with: splitDecision("kyouha Reactde", probability: 0.8))
    #expect(update.decisions[1].japaneseStart == nil)
}
@Test func localLiveChangedTokenNeverInheritsSplit() {
    let update = splitDecision("kyouha Reactdesign", probability: 0.5, offset: nil)
        .stabilizing(with: splitDecision("kyouha Reactde", probability: 0.8))
    #expect(update.decisions[1].japaneseStart == nil)
}
@Test func localLiveFreshCompositionDoesNotInheritConfidence() {
    let update = splitDecision("kyouha Reactde", probability: 0.59).stabilizing(with: nil)
    #expect(update.decisions[1].probability == 0.59)
}

@Test func localLiveSentenceDoesNotCommitAtTwoHundredCharacters() {
    var b = JevComposition()
    let sentence = String(repeating: "nihongo English $x_i$ ", count: 15) + "owari."
    for c in sentence { b.insert(String(c)) }
    #expect(b.raw == sentence)
    #expect(b.raw.count > 200)
    #expect(b.caret == sentence.count)
    let result = b.commit()
    #expect(!result.isEmpty)
    #expect(b.raw.isEmpty)
}
@Test func localLiveMiddleEditKeepsSentenceAndRejectsPendingAnswer() {
    var b = JevComposition(); b.replace("kyouha Reactde kaihatsu $x_i$")
    let epoch = b.editEpoch
    let answer = JevMixedDecision(spans: JevMixedLexer.spans(b.raw), decisions: [.init(index:2,japaneseStart:5,probability:1)], elapsedMS:0)
    b.moveCaret(to: 14); b.deleteBackward(); b.insert("n")
    #expect(b.raw == "kyouha Reactdn kaihatsu $x_i$")
    #expect(b.editEpoch != epoch)
    b.renderLocalLive(decision: answer, decisionEpoch: epoch) { _ in "日本語" }
    #expect(b.display == "日本語 Reactdn 日本語 $x_i$")
    #expect(b.displayCaretUTF16 == "日本語 Reactdn".utf16.count)
}
@Test func localLiveCaretUsesUTF16AndOnlyOpensEditedToken() {
    var b = JevComposition(); b.replace("nihongo hello $x$")
    b.moveCaret(to: 2)
    b.renderLocalLive(decision:nil,decisionEpoch:nil) { $0 == "nihongo" ? "日本語" : "こんにちは" }
    #expect(b.display == "nihongo こんにちは $x$")
    #expect(b.displayCaretUTF16 == 2)
    b.moveCaret(to:b.raw.count)
    b.renderLocalLive(decision:nil,decisionEpoch:nil) { $0 == "nihongo" ? "日本語" : "こんにちは" }
    #expect(b.display == "日本語 こんにちは $x$")
    #expect(b.displayCaretUTF16 == b.display.utf16.count)
}
@Test func localLiveDeletionAndBoundariesPreserveTex() {
    var b = JevComposition(); b.replace("API $x_i$ desu")
    b.moveCaret(to:7); b.deleteForward(); b.insert("j")
    #expect(b.raw == "API $x_j$ desu")
    b.moveCaret(to:0); b.deleteBackward()
    #expect(b.raw == "API $x_j$ desu")
    b.moveCaret(to:10000); b.deleteForward()
    #expect(b.caret == b.raw.count)
}
@Test func mixedLongSentenceBatchesCoverEveryTokenWithoutMath() {
    let spans = JevMixedLexer.spans(String(repeating:"nihongo English $x_i$ ",count:45))
    let batches = JevMixedRouter.targetBatches(spans)
    #expect(batches.map(\.count) == [40,40,10])
    #expect(batches.flatMap { $0 } == spans.indices.filter { !spans[$0].protected })
}
