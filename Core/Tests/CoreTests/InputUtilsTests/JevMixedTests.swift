@testable import Core
import Testing

@Test func mixedLexerRoundTripsAndProtectsTex() {
    for raw in [#"nihongo $x_{i}+\\alpha$ desu"#, #"$$a+b$$"#, #"\\(x^2\\)"#, #"\\[x\\]"#, #"\\label{sec:romaji}"#, #"\\begin{align}a&=b\\end{align}"#, #"$unfinished"#, #"\\frac{a}{b}"#, #"https://example.com/a"#, #"`npm install`"#, #"% comment"#] {
        let spans = JevMixedLexer.spans(raw)
        #expect(spans.map(\.text).joined() == raw)
    }
    for raw in [#"$x+abc$"#, #"$$x+abc$$"#, #"\(x+abc\)"#, #"\[x+abc\]"#, #"\label{sec:romaji}"#, #"\begin{align}a&=b\end{align}"#, #"$unfinished"#, #"\frac{a}{b}"#] {
        let protected = JevMixedLexer.spans(raw).allSatisfy { $0.protected }; #expect(protected)
    }
}
@Test func mixedTexTextArgumentRemainsConvertible() {
    let spans = JevMixedLexer.spans(#"\section{hajimeni}"#)
    #expect(spans.filter { !$0.protected }.map(\.text) == ["hajimeni"])
}
@Test func mixedNeverConvertsProtectedMathEvenWithBadDecision() {
    let raw = #"$x$ Reactde"#; let spans = JevMixedLexer.spans(raw)
    let decisions = spans.indices.map { JevSpanDecision(index:$0,japaneseStart:0,probability:1) }
    var b = JevComposition(); b.replace(raw)
    let result = b.applyMixed(.init(spans:spans,decisions:decisions,elapsedMS:0),revision:b.revision,convert:{ _ in "変換" })
    #expect(result); #expect(b.display == "$x$ 変換")
}
@Test func mixedPreservesEnglishPrefixAndRejectsStaleResult() {
    var b = JevComposition(); b.replace("Reactde")
    let d = JevMixedDecision(spans:JevMixedLexer.spans(b.raw),decisions:[.init(index:0,japaneseStart:5,probability:0.99)],elapsedMS:0)
    let rev = b.revision
    let applied = b.applyMixed(d,revision:rev,convert:{ _ in "で" })
    #expect(applied); #expect(b.display == "Reactで")
    b.replace("Next")
    let stale = b.applyMixed(d,revision:rev,convert:{ _ in "で" })
    #expect(!stale); #expect(b.display == "Next")
}
@Test func mixedRejectsMismatchedSourceAndKeepsUncertainToken() {
    var b = JevComposition(); b.replace("ai")
    let d = JevMixedDecision(spans:JevMixedLexer.spans("ai"),decisions:[.init(index:0,japaneseStart:0,probability:0.6)],elapsedMS:0)
    let applied = b.applyMixed(d,revision:b.revision,convert:{ _ in "愛" })
    #expect(applied); #expect(b.display == "ai")
    b.replace("new")
    let mismatch = b.applyMixed(d,revision:b.revision,convert:{ _ in "愛" })
    #expect(!mismatch)
}

@Test func mixedProtectsSpacedTexArgumentsAndSplitsCamelBoundary() {
    let protected = JevMixedLexer.spans(#"\label {sec:romaji}"#).allSatisfy { $0.protected }; #expect(protected)
    #expect(JevMixedLexer.spans("kyouhaReactde").map(\.text) == ["kyouha","Reactde"])
    #expect(JevMixedLexer.spans("iPhone").map(\.text) == ["iPhone"])
}

@Test func liveMixedPreservesConvertedPrefixDuringContinuousTyping() {
    var b = JevComposition(); b.replace("kyouha"); let epoch = b.editEpoch
    let d = JevMixedDecision(spans:JevMixedLexer.spans("kyouha"),decisions:[.init(index:0,japaneseStart:0,probability:1)],elapsedMS:0)
    b.replace("kyouha React")
    let applied = b.applyLiveMixed(d,epoch:epoch,convert:{ _ in "今日は" })
    #expect(applied); #expect(b.display == "今日は React")
    b.replace("kyouha React de")
    #expect(b.display == "今日は React de")
    b.replace("kyouha Reac")
    let stale = b.applyLiveMixed(d,epoch:epoch,convert:{ _ in "今日は" })
    #expect(!stale)
}

@Test func mixedSuffixRequiresEvidenceFromSameComposition() {
    var b = JevComposition(); b.replace("Reactde kaihatsu")
    let d = JevMixedDecision(spans:JevMixedLexer.spans(b.raw),decisions:[.init(index:0,japaneseStart:5,probability:0.64),.init(index:2,japaneseStart:0,probability:0.95)],elapsedMS:0)
    let ok = b.applyMixed(d,revision:b.revision,convert:{ $0 == "de" ? "で" : "開発" })
    #expect(ok); #expect(b.display == "Reactで 開発")
    b.replace("Reactde")
    let alone = JevMixedDecision(spans:JevMixedLexer.spans(b.raw),decisions:[.init(index:0,japaneseStart:5,probability:0.64)],elapsedMS:0)
    let held = b.applyMixed(alone,revision:b.revision,convert:{ _ in "で" })
    #expect(held); #expect(b.display == "Reactde")
}

@Test func liveMixedExtendsJapaneseRunWithoutRomanTail() {
    var b = JevComposition(); b.replace("kai"); let epoch = b.editEpoch
    let d = JevMixedDecision(spans:JevMixedLexer.spans("kai"),decisions:[.init(index:0,japaneseStart:0,probability:1)],elapsedMS:0)
    b.replace("kaihatsu $x$")
    let ok = b.applyLiveMixed(d,epoch:epoch,convert:{ $0 == "kaihatsu" ? "開発" : "誤り" })
    #expect(ok); #expect(b.display == "開発 $x$")
}

@Test func mixedDoesNotOfferEnglishPrefixesMadeOfJapaneseSyllables() {
    for prefix in ["gadetano", "dake", "watashi", "kore", "piano"] {
        #expect(!JevMixedRouter.permitsEnglishPrefix(prefix))
    }
    for prefix in ["React", "Slack", "git", "response", "PostgreSQL"] {
        #expect(JevMixedRouter.permitsEnglishPrefix(prefix))
    }
}

@Test func mixedMajoritySplitNeedsStrongJapaneseContext() {
    let spans = JevMixedLexer.spans("Meetno okuttemoraemasuka")
    var b = JevComposition(); b.replace(spans.map(\.text).joined())
    let d = JevMixedDecision(spans:spans,decisions:[.init(index:0,japaneseStart:4,probability:0.56),.init(index:2,japaneseStart:0,probability:0.96)],elapsedMS:0)
    b.renderLocalLive(decision:d,decisionEpoch:b.editEpoch) { $0 == "no" ? "の" : "送ってもらえますか" }
    #expect(b.display == "Meetの 送ってもらえますか")
    b.replace("Meetno")
    let alone = JevMixedDecision(spans:JevMixedLexer.spans(b.raw),decisions:[.init(index:0,japaneseStart:4,probability:0.56)],elapsedMS:0)
    b.renderLocalLive(decision:alone,decisionEpoch:b.editEpoch) { _ in "の" }
    #expect(b.display == "Meetno")
}
