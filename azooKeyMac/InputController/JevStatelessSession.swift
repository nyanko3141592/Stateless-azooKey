import Cocoa
import InputMethodKit
import Core
import KanaKanjiConverterModuleWithDefaultDictionary

@MainActor final class JevStatelessSession: @preconcurrency SegmentManagerDelegate {
    var buffer = JevComposition()
    var changed: (() -> Void)?
    var task: Task<Void, Never>?
    var busy = false
    var lastDecision: JevMixedDecision?
    var lastError: String?
    private var decisionEpoch: UInt64?
    private let classifier: (@MainActor (String) async throws -> JevMixedDecision)?
    private var requestNotBefore = Date.distantPast
    private var converterRaw = ""
    private var conversionCache: [String:String] = [:]
    private let manager: SegmentsManager
    init(classifier: (@MainActor (String) async throws -> JevMixedDecision)? = nil) {
        self.classifier = classifier
        let directory = JevLocalConfig.directory.appendingPathComponent("stateless-memory")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        manager = SegmentsManager(kanaKanjiConverter: .withDefaultDictionary(), applicationDirectoryURL: directory, containerURL: nil)
        manager.delegate = self
    }
    func getLeftSideContext(maxCount: Int) -> String? { "" }
    func replace(_ raw: String, delay: Int = 60, caret: Int? = nil) {
        let appendOnly = !buffer.raw.isEmpty && raw.hasPrefix(buffer.raw)
        if !appendOnly { task?.cancel(); task = nil }
        buffer.replace(raw, caret: caret); lastError = nil
        if !appendOnly { lastDecision = nil; decisionEpoch = nil; conversionCache.removeAll() }
        if classifier == nil {
            let decision = LocalLanguageRouter.shared.classify(raw)
            lastDecision = decision; decisionEpoch = buffer.editEpoch
            buffer.renderLocalLive(decision:decision,decisionEpoch:decisionEpoch,trustDecision:true,convert:convertJapanese)
            busy = false; changed?(); return
        }
        // Injected classifier is used only by fault-injection audits; shipping mode is synchronous/local.
        buffer.renderLocalLive(decision: lastDecision, decisionEpoch: decisionEpoch, trustDecision: classifier == nil, convert: convertJapanese)
        busy = !raw.isEmpty; changed?()
        guard !raw.isEmpty, task == nil else { return }
        task = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }
            var rateLimitRetries = 0
            while let self, !Task.isCancelled, !self.buffer.raw.isEmpty {
                let wait = self.requestNotBefore.timeIntervalSinceNow
                if wait > 0 {
                    do { try await Task.sleep(for: .seconds(wait)) } catch { return }
                }
                guard !Task.isCancelled, !self.buffer.raw.isEmpty else { return }
                self.requestNotBefore = Date().addingTimeInterval(2.0)
                let source = self.buffer.raw
                let epoch = self.buffer.editEpoch
                do {
                    let response = try await self.classifier!(source)
                    guard !Task.isCancelled, self.buffer.editEpoch == epoch else { return }
                    let decision = response.stabilizing(with: self.decisionEpoch == epoch ? self.lastDecision : nil)
                    self.lastDecision = decision; self.decisionEpoch = epoch
                    self.lastError = nil; rateLimitRetries = 0
                    self.buffer.renderLocalLive(decision: decision, decisionEpoch: epoch, convert: self.convertJapanese)
                    self.changed?()
                } catch {
                    guard !Task.isCancelled, self.buffer.editEpoch == epoch else { return }
                    self.lastError = error.localizedDescription
                    if case JevError.http(429) = error, rateLimitRetries < 3 {
                        rateLimitRetries += 1
                        self.requestNotBefore = Date().addingTimeInterval(pow(2.0, Double(rateLimitRetries)))
                        continue
                    }
                }
                if self.buffer.raw == source {
                    self.busy = false; self.task = nil; self.changed?(); return
                }
                // One request in flight, at most one start every two seconds; local conversion never waits.
            }
        }
    }
    private func convertJapanese(_ raw: String) -> String {
        if let cached = conversionCache[raw] { return cached }
        if !raw.hasPrefix(converterRaw) { manager.stopComposition(); converterRaw = "" }
        for character in raw.dropFirst(converterRaw.count) {
            manager.insertAtCursorPosition(String(character), inputStyle: .mapped(id: .defaultRomanToKana))
        }
        converterRaw = raw
        // insertAtCursorPosition already updates the local live candidates; do not replay the whole word
        // or request the expensive rich-candidate list on every keystroke.
        let converted = manager.jevSnapshot(leftContext: "")?.candidates.first
            ?? manager.getCurrentMarkedText(inputState: .composing).map(\.content).joined()
        conversionCache[raw] = converted
        return converted
    }
    func append(_ string: String) {
        var edit = buffer; edit.insert(string)
        replace(edit.raw, caret: edit.caret)
    }
    func backspace() {
        guard buffer.caret > 0 else { return }
        var edit = buffer; edit.deleteBackward()
        replace(edit.raw, caret: edit.caret)
    }
    func deleteForward() {
        guard buffer.caret < buffer.raw.count else { return }
        var edit = buffer; edit.deleteForward()
        replace(edit.raw, caret: edit.caret)
    }
    func moveCaret(to offset: Int) {
        buffer.moveCaret(to: offset)
        buffer.renderLocalLive(decision: lastDecision, decisionEpoch: decisionEpoch, trustDecision: classifier == nil, convert: convertJapanese)
        changed?()
    }

    func commit(raw: Bool = false) -> String {
        task?.cancel(); task = nil; busy = false
        buffer.moveCaret(to: buffer.raw.count)
        buffer.renderLocalLive(decision: lastDecision, decisionEpoch: decisionEpoch, trustDecision: classifier == nil, convert: convertJapanese)
        let result = raw ? buffer.raw : buffer.display
        buffer.replace(""); lastDecision = nil; decisionEpoch = nil; conversionCache.removeAll(); converterRaw = ""; manager.stopComposition(); changed?()
        return result
    }
    func reset() { _ = commit(raw: true) }
}

@MainActor extension azooKeyMacInputController {
    @objc func toggleJevStateless(_ sender: NSMenuItem) {
        if let client = self.client(), !statelessSession.buffer.raw.isEmpty { commitStateless(client) }
        if !statelessEnabled { self.commitComposition(self.client()) }
        statelessEnabled.toggle(); sender.state = statelessEnabled ? .on : .off
    }
    func refreshStateless() {
        let text = NSAttributedString(string: statelessSession.buffer.display, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        self.client()?.setMarkedText(text, selectionRange: NSRange(location: statelessSession.buffer.displayCaretUTF16, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    func commitStateless(_ client: IMKTextInput, raw: Bool = false) {
        // Do not clear marked text before replacing it: that would duplicate the composition in some clients.
        statelessSession.changed = nil
        let text = statelessSession.commit(raw: raw)
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    func handleStateless(_ event: NSEvent, client: IMKTextInput) -> Bool {
        statelessSession.changed = { [weak self] in self?.refreshStateless() }
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            if !statelessSession.buffer.raw.isEmpty { commitStateless(client) }
            return false
        }
        switch event.keyCode {
        case 36, 76:
            guard !statelessSession.buffer.raw.isEmpty else { return false }
            commitStateless(client); return true
        case 51:
            guard !statelessSession.buffer.raw.isEmpty else { return false }
            statelessSession.backspace(); return true
        case 123, 124, 115, 119:
            guard !statelessSession.buffer.raw.isEmpty else { return false }
            let current = statelessSession.buffer.caret
            let offset = event.keyCode == 115 ? 0 : event.keyCode == 119 ? statelessSession.buffer.raw.count : current + (event.keyCode == 123 ? -1 : 1)
            statelessSession.moveCaret(to: offset); return true
        case 117:
            guard !statelessSession.buffer.raw.isEmpty else { return false }
            statelessSession.deleteForward(); return true
        case 53:
            guard !statelessSession.buffer.raw.isEmpty else { return false }
            commitStateless(client, raw: true); return true
        case 102, 104: return true // No language state in this experimental mode.
        default: break
        }
        if let chars = event.characters, !chars.isEmpty,
           chars.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value < 127 }) {
            // A sentence stays marked until explicit confirmation, regardless of character count.
            statelessSession.changed = { [weak self] in self?.refreshStateless() }
            statelessSession.append(chars); return true
        }
        if !statelessSession.buffer.raw.isEmpty { commitStateless(client) }
        return false
    }
}
