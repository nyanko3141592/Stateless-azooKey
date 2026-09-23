import Cocoa
import Core

@MainActor final class StatelessTextView: NSTextView {
    weak var owner: JevStatelessWindow?
    override func keyDown(with event: NSEvent) {
        guard let owner else { super.keyDown(with: event); return }
        if event.modifierFlags.contains(.command) { super.keyDown(with: event); return }
        if event.keyCode == 36 { owner.commitLine(); return }
        if event.keyCode == 51 {
            if !owner.session.buffer.raw.isEmpty { owner.session.backspace() }
            else if !owner.documentText.isEmpty { owner.documentText.removeLast(); owner.render() }
            return
        }
        if [123, 124, 115, 119].contains(event.keyCode) {
            let current = owner.session.buffer.caret
            owner.session.moveCaret(to: event.keyCode == 115 ? 0 : event.keyCode == 119 ? owner.session.buffer.raw.count : current + (event.keyCode == 123 ? -1 : 1))
            return
        }
        if event.keyCode == 117 { owner.session.deleteForward(); return }
        if event.keyCode == 53 { owner.documentText += owner.session.commit(raw: true); owner.render(); return }
        if let chars = event.characters, chars.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value < 127 }) { owner.session.append(chars) }
    }
}

@MainActor final class JevStatelessWindow: NSWindowController {
    let session = JevStatelessSession()
    var documentText = ""
    let editor = StatelessTextView()
    let recordButton = NSButton(title: "デモを再生", target: nil, action: nil)
    var records: [[String: Any]] = []
    var movieTask: Task<Void, Never>?
    var rendering = false
    var trace: [[String:Any]] = []
    var recordingLive = false
    var captureStart = Date()
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 630), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "メモ"; window.center(); window.isReleasedWhenClosed = false
        super.init(window: window)
        let root = NSView(frame: NSRect(x: 0,y: 0,width: 1000,height: 630)); window.contentView = root
        editor.frame = NSRect(x: 42,y: 56,width: 916,height: 542)
        editor.minSize = NSSize(width: 916,height: 542)
        editor.maxSize = NSSize(width: 916,height: 542)
        editor.isVerticallyResizable = false; editor.isHorizontallyResizable = false
        editor.textContainer?.containerSize = NSSize(width: 892,height: 510)
        editor.font = .systemFont(ofSize: 31, weight: .regular)
        editor.textContainerInset = NSSize(width: 12,height: 16)
        editor.isRichText = false; editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false; editor.isAutomaticTextReplacementEnabled = false
        editor.owner = self; root.addSubview(editor)
        recordButton.frame = NSRect(x: 840,y: 12,width: 120,height: 30)
        recordButton.target = self; recordButton.action = #selector(play)
        root.addSubview(recordButton)
        session.changed = { [weak self] in self?.render() }
        window.makeFirstResponder(editor)
    }
    required init?(coder: NSCoder) { fatalError() }
    func render() {
        if recordingLive { trace.append(["t":Date().timeIntervalSince(captureStart),"raw":session.buffer.raw,"display":session.buffer.display,"busy":session.busy]) }

        let all = NSMutableAttributedString(string: documentText, attributes: [.font:NSFont.systemFont(ofSize:31),.foregroundColor:NSColor.labelColor])
        all.append(NSAttributedString(string: session.buffer.display, attributes: [.font:NSFont.systemFont(ofSize:31),.foregroundColor:NSColor.labelColor,.underlineStyle:NSUnderlineStyle.single.rawValue]))
        editor.textStorage?.setAttributedString(all)
        editor.setSelectedRange(NSRange(location: documentText.utf16.count + session.buffer.displayCaretUTF16,length: 0))
    }
    func commitLine() {
        if recordingLive { trace.append(["t":Date().timeIntervalSince(captureStart), "event":"commit", "raw":session.buffer.raw]) }
        let text = session.commit(); documentText += text + "\n\n"; render()
    }
    func save(_ name: String) {
        if let data = try? JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted,.sortedKeys]) {
            try? data.write(to: JevLocalConfig.directory.appendingPathComponent(name), options: .atomic)
        }
    }
    func resolve(_ raw: String, animate: Bool) async throws {
        session.reset()
        if animate {
            for c in raw { session.append(String(c)); try await Task.sleep(for: .milliseconds(90)) }
        } else { session.replace(raw, delay: 0) }
        if let task = session.task { await task.value }
        try Task.checkCancellation()
        var row: [String:Any] = ["raw":raw,"output":session.buffer.display,"stateless":true]
        if let d = session.lastDecision { row["segments"] = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(d))) ?? []; row["elapsedMS"] = d.elapsedMS }
        if let error = session.lastError { row["error"] = error }
        records.append(row)
    }
    @objc func play() {
        guard movieTask == nil else { return }
        movieTask = Task { @MainActor in
            recordButton.isHidden = true; records = []; trace = []; captureStart = Date(); recordingLive = true; documentText = ""; session.reset(); render()
            do {
                try await Task.sleep(for: .milliseconds(500))
                for raw in [
    "Slacknoscreenshotwookuttekudasai.",
    "GitHubnobranchwokaetekudasai.",
    "ashitanomeetingnolinkwooshietekudasai.",
    "konofilewoSlackdekyouyuushitekudasai."
] {
                    documentText = ""; render()
                    try await resolve(raw, animate: true)
                    try await Task.sleep(for: .milliseconds(850))
                    commitLine()
                    try await Task.sleep(for: .milliseconds(1200))
                }
                save("sentence-live-movie.json")
                recordingLive = false
                if let data = try? JSONSerialization.data(withJSONObject: trace, options:[.prettyPrinted,.sortedKeys]) { try? data.write(to:JevLocalConfig.directory.appendingPathComponent("sentence-live-trace.json")) }
                try await Task.sleep(for: .seconds(3))
            } catch { save("stateless-movie-error.json") }
            recordButton.isHidden = false; movieTask = nil
        }
    }
    func auditLocalModel() async {
        var rows: [[String:Any]] = []
        let samples = [
    "Slacknoscreenshotwookuttekudasai.",
    "GitHubnobranchwokaetekudasai.",
    "ashitanomeetingnolinkwooshietekudasai.",
    "konofilewoSlackdekyouyuushitekudasai.",
    "NotionnodocumentwoSlackdekyouyuushimasu",
    "GitHubnoworkflowgafailedninatteimasu",
    "konorepositorynoREADMEwoyondekudasai",
    "ashitanocalendarnolinkwookuttehoshii",
    "raishuunomeetingnoagendawooshietekudasai",
    "Chromenobookmarkgasyncsaremasenn",
    "saishinnoscreenshotwomaildeokurimasu",
    "konothumbnailwodownloadshitaidesu",
    "shinkinopullrequestworeviewshitekudasai",
    "konobackupnofolderwokeshita",
    "kyounotranscriptwosummarynishitai",
    "konodatasetnoschemawokakuninnshimasu",
    "ashitanouchiawasenonaiyouwooshietekudasai",
    "konogoronojikannnotsukaikatawominaoshitai",
    "shiryouwohayakumatometeokimashou",
    "notificationworkflow",
    "Please open the notification settings.",
    "The new thumbnail looks better than before.",
    "I want to review the pull request tomorrow.",
    "There is no reason to change the schema.",
    "kono`git checkout feature/mail`wotsukau",
    "atesakihateam+review@example.comdesu",
    "koreha$\\frac{x}{y}$desu",
    "\\label{sec:workflow} wotsukau",
    "konoservernotimeoutwoconfigdekaeru",
    "Slacknochannelnolinkwookurimasu",
    "atarashiifeaturenotestwotsuikashimasu",
    "konodashboardnowidgetwokesitai",
    "saishinnochangelogwobrowserdehiraku",
    "kaiginorecordingwouploadshita",
    "raigetsunoyoyakuwotorinaoshitekudasai",
    "uchiawasenotochinihaosokunarimasu",
    "The screenshot was attached to the email.",
    "We are waiting for the deployment to finish.",
    "hozonnsakiha~/Projects/workflow/main.swift desu",
    "\\section{houhounosetsumei}"
]
        for raw in samples {
            session.reset(); var times: [Double] = []
            for c in raw {
                let start = Date(); session.append(String(c)); times.append(Date().timeIntervalSince(start)*1000)
            }
            let text = session.buffer.display
            rows.append(["raw":raw,"output":text,"millisecondsPerKey":times,"pendingTask":session.task != nil,
                         "decision":(try? JSONSerialization.jsonObject(with:JSONEncoder().encode(session.lastDecision))) ?? NSNull()])
            _ = session.commit()
        }
        // Exercise a middle-of-sentence edit through the same session used by the IME.
        session.reset(); session.replace(samples[0])
        let beforeEdit = session.buffer.display
        session.moveCaret(to: 20); session.append("x"); session.backspace()
        session.moveCaret(to: session.buffer.raw.count)
        let editRestored = session.buffer.raw == samples[0] && session.buffer.display == beforeEdit
        _ = session.commit()
        let commitCleared = session.buffer.raw.isEmpty && session.lastDecision == nil && session.task == nil
        var probeBlocked = false; var probeError = ""
        do {
            var request = URLRequest(url:URL(string:"https://example.com")!); request.timeoutInterval = 3
            _ = try await URLSession.shared.data(for:request)
        } catch { probeBlocked = true; probeError = error.localizedDescription }
        let result: [String:Any] = ["samples":rows,"middleEditRestored":editRestored,"commitCleared":commitCleared,"networkProbeBlocked":probeBlocked,"networkProbeError":probeError,
            "apiKeyPresent":FileManager.default.fileExists(atPath:JevLocalConfig.directory.appendingPathComponent("gateway.key").path)]
        if let data = try? JSONSerialization.data(withJSONObject:result, options:[.prettyPrinted,.sortedKeys]) {
            try? data.write(to:JevLocalConfig.directory.appendingPathComponent("local-model-audit.json"))
        }
        NSApp.terminate(nil)
    }
    func auditLocalLive() async {
        var rows: [[String:Any]] = []
        // The real session and real Zenzai, with only the network dependency replaced by a delayed failure.
        let offline = JevStatelessSession(classifier: { _ in
            try await Task.sleep(for: .milliseconds(350))
            throw URLError(.timedOut)
        })
        for raw in ["kyouhaiitenki", #"suushikiha $E=mc^2$"#, #"\section{hajimeni}"#] {
            offline.reset()
            var keys: [[String:Any]] = []
            for c in raw {
                let start = Date()
                offline.append(String(c))
                keys.append(["raw":offline.buffer.raw,"display":offline.buffer.display,"milliseconds":Date().timeIntervalSince(start)*1000,"receivedAnswer":offline.lastDecision != nil])
            }
            let before = offline.buffer.display
            if let task = offline.task { await task.value }
            rows.append(["raw":raw,"beforeNetwork":before,"afterFailure":offline.buffer.display,"error":offline.lastError ?? "", "keys":keys])
        }
        offline.reset(); offline.append("kyouhaiitenki")
        let pending = offline.task
        let committed = offline.commit()
        if let pending { await pending.value }
        rows.append(["committed":committed,"afterLateTask":offline.buffer.display,"rawAfterCommit":offline.buffer.raw])
        offline.reset()
        let longSentence = String(repeating: "API $x_i$ ", count: 24) + "desu."
        for character in longSentence { offline.append(String(character)) }
        let retained = offline.buffer.raw == longSentence && offline.buffer.raw.count > 200
        offline.moveCaret(to: 7); offline.deleteForward(); offline.append("j")
        let edited = offline.buffer.raw.hasPrefix("API $x_j$")
        offline.moveCaret(to: offline.buffer.raw.count)
        let final = offline.commit()
        rows.append(["sentenceOver200Retained":retained, "middleMathEdit":edited,
                     "committedLongSentence":final, "emptyAfterCommit":offline.buffer.raw.isEmpty])
        var attempts = 0
        let retrying = JevStatelessSession(classifier: { _ in
            attempts += 1
            if attempts == 1 { throw JevError.http(429) }
            return try JSONDecoder().decode(JevMixedDecision.self, from: Data(#"{"spans":[],"decisions":[],"elapsedMS":0}"#.utf8))
        })
        retrying.replace("kyouhaiitenki", delay:0)
        let immediate = retrying.buffer.display
        if let pending = retrying.task { await pending.value }
        rows.append(["retryAttempts":attempts, "beforeRetry":immediate,
                     "afterRetry":retrying.buffer.display, "retryErrorCleared":retrying.lastError == nil])
        if let data = try? JSONSerialization.data(withJSONObject:rows, options:[.prettyPrinted,.sortedKeys]) {
            try? data.write(to:JevLocalConfig.directory.appendingPathComponent("local-live-offline-audit.json"))
        }
        NSApp.terminate(nil)
    }
    func audit() async {
        records = []
        for raw in ["kyouha React de kaihatsu", "kono API wo tsukau", "Reactde kaihatsu", "kyouhaReactde kaihatsu", "Please run npm install", "ai", "no", "to", #"suushikiha $E=mc^2$ desu"#, #"\section{hajimeni}"#, #"koreha \(\frac{a}{b}\) desu"#, #"mitai $x_{i"#, #"\label{sec:intro}"#, #"\begin{align}a&=b\\c&=d\end{align}"#, #"URLha https://example.com"#] {
            try? await resolve(raw, animate: false)
        }
        save("mixed-audit.json")
        NSApp.terminate(nil)
    }
}
