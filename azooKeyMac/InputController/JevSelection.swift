import Cocoa
import Core

@MainActor enum JevLocalConfig {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("azooKeyLocal")
    }
    static func apiKey() throws -> String {
        let key = (try? String(contentsOf: directory.appendingPathComponent("gateway.key"), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else { throw JevError.noKey }; return key
    }
}

extension azooKeyMacInputController {
    @MainActor @objc func performJevSelection(_ sender: Any?) {
        guard self.inputState == .composing || self.inputState == .selecting || self.inputState == .previewing else { return }
        self.jevTask?.cancel(); self.jevRequestGeneration &+= 1
        let generation = self.jevRequestGeneration
        self.segmentsManager.update(requestRichCandidates: true)
        guard let snapshot = self.segmentsManager.jevSnapshot(leftContext: self.segmentsManager.getCleanLeftSideContext(maxCount: 120) ?? "") else { NSSound.beep(); return }
        self.jevTask = Task { @MainActor [weak self] in
            do {
                let decision = try await JevReranker.select(snapshot: snapshot, apiKey: JevLocalConfig.apiKey())
                guard let self, !Task.isCancelled, self.jevRequestGeneration == generation,
                      self.segmentsManager.applyJevChoice(decision.choice, snapshot: snapshot) else { return }
                self.presentJevChoice()
            } catch is CancellationError {} catch {
                guard !Task.isCancelled else { return }
                self?.segmentsManager.appendDebugMessage(error.localizedDescription)
                NSSound.beep()
            }
        }
    }
}
