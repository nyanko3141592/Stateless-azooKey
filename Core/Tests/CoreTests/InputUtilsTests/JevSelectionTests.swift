@testable import Core
import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary
import Testing

@MainActor private func managerForJev() -> SegmentsManager {
    let manager = SegmentsManager(kanaKanjiConverter: .withDefaultDictionary(), applicationDirectoryURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString), containerURL: nil, context: .init(useZenzai: false))
    manager.insertAtCursorPosition("ほしょう", inputStyle: .direct)
    manager.update(requestRichCandidates: true)
    return manager
}

@MainActor @Test func jevRejectsResponseAfterInputChanged() throws {
    let manager = managerForJev()
    let snapshot = try #require(manager.jevSnapshot(leftContext: "被害を"))
    manager.insertAtCursorPosition("する", inputStyle: .direct)
    #expect(!manager.applyJevChoice(snapshot.candidates[1], snapshot: snapshot))
}

@MainActor @Test func jevRejectsResponseAfterCompositionEnded() throws {
    let manager = managerForJev()
    let snapshot = try #require(manager.jevSnapshot(leftContext: "被害を"))
    manager.stopComposition()
    #expect(!manager.applyJevChoice(snapshot.candidates[1], snapshot: snapshot))
}

@MainActor @Test func jevRejectsCandidateNotInRequest() throws {
    let manager = managerForJev()
    let snapshot = try #require(manager.jevSnapshot(leftContext: "被害を"))
    #expect(!manager.applyJevChoice("勝手に生成した文章", snapshot: snapshot))
}

@MainActor @Test func jevPromotesExistingCandidateWithoutLosingOthers() throws {
    let manager = managerForJev()
    let snapshot = try #require(manager.jevSnapshot(leftContext: "被害を"))
    let choice = snapshot.candidates[1]
    #expect(manager.applyJevChoice(choice, snapshot: snapshot))
    let after = try #require(manager.jevSnapshot(leftContext: "被害を"))
    #expect(after.candidates.first == choice)
    #expect(Set(after.candidates) == Set(snapshot.candidates))
    #expect(manager.selectedCandidate?.text == choice)
}

@MainActor @Test func jevDoesNotOverrideManualSelection() throws {
    let manager = managerForJev()
    let snapshot = try #require(manager.jevSnapshot(leftContext: "被害を"))
    manager.requestSelectingRow(1)
    #expect(!manager.applyJevChoice(snapshot.candidates[0], snapshot: snapshot))
}
