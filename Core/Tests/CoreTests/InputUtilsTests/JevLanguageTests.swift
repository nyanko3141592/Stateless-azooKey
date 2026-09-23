@testable import Core
import Testing

@Test func languageLateReplyCannotChangeNewInput() {
    var b = JevComposition(); b.replace("kyouhaiitenki"); let old = b.revision
    b.replace("git status")
    let result1 = !b.apply(.init(intent: .japanese, probability: 0.99, elapsedMS: 10), japanese: "今日はいい天気", revision: old)
    #expect(result1)
    #expect(b.display == "git status")
}
@Test func languageCommitResetsIntentAndRejectsLateResponse() {
    var b = JevComposition(); b.replace("arigatou"); let old = b.revision
    let result2 = b.apply(.init(intent: .japanese, probability: 0.99, elapsedMS: 10), japanese: "ありがとう", revision: old)
    #expect(result2)
    let result3 = b.commit() == "ありがとう"
    #expect(result3)
    #expect(b.raw.isEmpty)
    let result4 = !b.apply(.init(intent: .japanese, probability: 0.99, elapsedMS: 10), japanese: "ありがとう", revision: old)
    #expect(result4)
    b.replace("Hello, world!")
    #expect(b.display == "Hello, world!")
}
@Test func languageUncertaintyAndLiteralPreserveExactBytes() {
    for decision in [JevLanguageDecision(intent: .uncertain, probability: 0.99, elapsedMS: 0), .init(intent: .japanese, probability: 0.84, elapsedMS: 0), .init(intent: .literal, probability: 0.99, elapsedMS: 0)] {
        var b = JevComposition(); b.replace("Git  STATUS --short")
        let result5 = b.apply(decision, japanese: "誤変換", revision: b.revision)
        #expect(result5)
        let result6 = b.commit() == "Git  STATUS --short"
        #expect(result6)
    }
}
@Test func languageDeleteAndRetypeInvalidatesIdenticalOldRequest() {
    var b = JevComposition(); b.replace("ai"); let old = b.revision
    b.replace("a"); b.replace("ai")
    let result7 = !b.apply(.init(intent: .japanese, probability: 1, elapsedMS: 0), japanese: "愛", revision: old)
    #expect(result7)
}
