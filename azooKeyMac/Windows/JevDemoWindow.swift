import Cocoa
import Carbon
import SwiftUI
import Core
import KanaKanjiConverterModuleWithDefaultDictionary

struct JevExample: Codable, Sendable {
    let context: String
    let reading: String
    let expected: String
}
struct JevRunRecord: Codable, Sendable {
    let createdAt: String
    let example: JevExample
    let snapshot: JevSnapshot
    let decision: JevDecision
    let applied: Bool
    let baseline: String
}

@MainActor final class JevDemoModel: ObservableObject, @preconcurrency SegmentManagerDelegate {
    @Published var context = "出版社から原稿が届いた。誤字や脱字、表記の揺れを一つずつ直す必要がある。明日の打ち合わせで話し合うテーマは"
    @Published var reading = "こうせい"
    @Published var candidates: [String] = []
    @Published var choice = ""
    @Published var status = "読みと文脈を入力して、実際の候補で比較できます。"
    @Published var elapsed = ""
    @Published var busy = false
    @Published var headline = "変換より、書くことに集中したい。"
    @Published var displayContext = ""
    @Published var displayReading = ""
    @Published var stage = 0
    @Published var recording = false
    @Published var completed = false
    @Published var editorMarked = ""
    @Published var editorSuffix = ""
    @Published var editorCommitted = ""
    @Published var showCandidates = false
    @Published var activeCandidate = 0
    @Published var manualMoves = 0
    @Published var keyLabel = ""
    @Published var automatic = false
    @Published var liveReading = ""
    @Published var experiencePhase = "手動で候補を選ぶ"
    private var automaticTask: Task<Void, Never>?
    private var inputGeneration: UInt64 = 0
    var liveTrace: [[String: String]] = []
    private var manager: SegmentsManager?
    var records: [JevRunRecord] = []
    let converter = KanaKanjiConverter.withDefaultDictionary()
    static let examples: [JevExample] = [
        .init(context: "台風による被害を", reading: "ほしょう", expected: "補償"),
        .init(context: "商品の品質を", reading: "ほしょう", expected: "保証"),
        .init(context: "国民の生活を", reading: "ほしょう", expected: "保障"),
        .init(context: "原稿の誤字を直すために", reading: "こうせい", expected: "校正"),
        .init(context: "システム全体の", reading: "こうせい", expected: "構成"),
        .init(context: "選挙の候補者が駅前で行う", reading: "がいとう", expected: "街頭"),
        .init(context: "応募資格に", reading: "がいとう", expected: "該当"),
        .init(context: "新薬の", reading: "こうか", expected: "効果"),
        .init(context: "母校の入学式で歌う", reading: "こうか", expected: "校歌"),
        .init(context: "学生にレポートの提出を", reading: "かす", expected: "課す"),
        .init(context: "友人に本を", reading: "かす", expected: "貸す"),
        .init(context: "足の痛みを", reading: "うったえる", expected: "訴える"),
        .init(context: "会社の新しい", reading: "たいせい", expected: "体制"),
        .init(context: "薬剤への", reading: "たいせい", expected: "耐性"),
        .init(context: "椅子に座る", reading: "しせい", expected: "姿勢"),
        .init(context: "市長が運営する", reading: "しせい", expected: "市政"),
        .init(context: "食品が微生物によって", reading: "はっこう", expected: "発酵"),
        .init(context: "新しい雑誌を", reading: "はっこう", expected: "発行"),
        .init(context: "暗闇で光を放つ", reading: "はっこう", expected: "発光"),
        .init(context: "歴史的な建造物を", reading: "ほぞん", expected: "保存"),
        .init(context: "契約内容の", reading: "かくにん", expected: "確認"),
        .init(context: "議員が法案に", reading: "さんせい", expected: "賛成"),
        .init(context: "レモン汁は", reading: "さんせい", expected: "酸性"),
        .init(context: "会社の売上を", reading: "あげる", expected: "上げる")
    ]
    func getLeftSideContext(maxCount: Int) -> String? { String(context.suffix((!CommandLine.arguments.contains("--jev-benchmark") || CommandLine.arguments.contains("--context120")) ? 120 : maxCount)) }
    func prepare(_ example: JevExample? = nil) -> JevSnapshot? {
        if let example { context = example.context; reading = example.reading }
        converter.stopComposition()
        let temp = JevLocalConfig.directory.appendingPathComponent("demo-memory")
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let manager = SegmentsManager(kanaKanjiConverter: converter, applicationDirectoryURL: temp, containerURL: nil)
        self.manager = manager; manager.delegate = self
        liveTrace = []
        var typed = ""
        for character in reading {
            typed.append(character)
            manager.insertAtCursorPosition(String(character), inputStyle: .direct)
            let marked = manager.getCurrentMarkedText(inputState: .composing).map(\.content).joined()
            liveTrace.append(["typed": typed, "marked": marked])
        }
        manager.update(requestRichCandidates: true)
        let snapshot = manager.jevSnapshot(leftContext: context)
        candidates = snapshot?.candidates ?? []
        choice = ""; elapsed = ""; completed = false
        status = snapshot == nil ? "候補が不足しています。別の読みを試してください。" : "同じ候補をJevに渡して、文脈から選択します。"
        return snapshot
    }
    func choose(_ snapshot: JevSnapshot, example: JevExample) async throws -> JevRunRecord {
        let decision = try await JevReranker.select(snapshot: snapshot, apiKey: JevLocalConfig.apiKey())
        let applied = manager?.applyJevChoice(decision.choice, snapshot: snapshot) ?? false
        guard applied else { throw JevError.invalidResponse }
        choice = decision.choice; elapsed = String(format: "%.2f秒", Double(decision.elapsedMS) / 1000)
        completed = true; status = "azooKeyの同じ候補から選択しました。"
        let record = JevRunRecord(createdAt: ISO8601DateFormatter().string(from: Date()), example: example,
                                  snapshot: snapshot, decision: decision, applied: applied, baseline: snapshot.candidates.first ?? "")
        records.append(record); saveRecords()
        return record
    }
    func selectIME() {
        let filter = [kTISPropertyInputSourceID as String: "dev.naoki.inputmethod.StatelessAzooKey.Japanese"] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
        guard let source = sources.first else { status = "入力ソースがまだ登録されていません。"; return }
        let enabled = TISEnableInputSource(source)
        let selected = TISSelectInputSource(source)
        status = selected == 0 ? "azooKey + Jev を選択しました。変換中に Control + J で実行できます。" : "入力ソース選択: \(selected) / 有効化: \(enabled)"
    }
    func compare() {
        guard !busy else { return }; busy = true
        Task { @MainActor in
            defer { busy = false }
            guard let snapshot = prepare() else { return }
            status = "Jevへ問い合わせ中…"
            do { _ = try await choose(snapshot, example: .init(context: context, reading: reading, expected: "")) }
            catch { status = error.localizedDescription }
        }
    }
    func saveRecords(name: String = "demo-runs.json") {
        try? FileManager.default.createDirectory(at: JevLocalConfig.directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(records) { try? data.write(to: JevLocalConfig.directory.appendingPathComponent(name), options: .atomic) }
    }
    func benchmark() async {
        Config.LiveConversion().value = true
        let data = try? Data(contentsOf: JevLocalConfig.directory.appendingPathComponent("benchmark-examples.json"))
        let examples = data.flatMap { try? JSONDecoder().decode([JevExample].self, from: $0) } ?? Self.examples
        var audits: [[String: Any]] = []
        for example in examples {
            guard let snapshot = prepare(example) else { continue }
            let trace = liveTrace
            do {
                let record = try await choose(snapshot, example: example)
                audits.append(["context":example.context,"reading":example.reading,"expected":example.expected,
                    "zenzai":true,"liveConversion":Config.LiveConversion().value,
                    "zenzaiContextCharacters":CommandLine.arguments.contains("--context120") ? 120 : 30,
                    "trace":trace,"candidates":snapshot.candidates,"baselineRich":record.baseline,
                    "jev":record.decision.choice,"elapsedMS":record.decision.elapsedMS])
            } catch { NSLog("Jev benchmark error: %@", error.localizedDescription) }
        }
        let prefix = CommandLine.arguments.contains("--context120") ? "context120" : "context30"
        saveRecords(name: prefix + "-benchmark.json")
        if let data = try? JSONSerialization.data(withJSONObject: audits, options: [.prettyPrinted,.sortedKeys]) {
            try? data.write(to: JevLocalConfig.directory.appendingPathComponent(prefix + "-live-audit.json"))
        }
        NSApplication.shared.terminate(nil)
    }
    func prepareEditor(_ example: JevExample) -> JevSnapshot? {
        guard let snapshot = prepare(example) else { return nil }
        editorMarked = snapshot.candidates.first ?? example.reading
        editorCommitted = ""; editorSuffix = ""; activeCandidate = 0
        return snapshot
    }
    func nextEditorCandidate() {
        automaticTask?.cancel(); inputGeneration &+= 1
        guard let manager, activeCandidate + 1 < candidates.count else { return }
        activeCandidate += 1
        manager.requestSelectingRow(activeCandidate)
        editorMarked = manager.selectedCandidate?.text ?? candidates[activeCandidate]
        manualMoves += 1; keyLabel = "Space"; showCandidates = true
    }
    @discardableResult func commitEditor() -> String {
        automaticTask?.cancel(); inputGeneration &+= 1
        guard let manager else { return "" }
        // Commit the real engine's selection, not the fixture's expected answer.
        if !completed { manager.requestSelectingRow(activeCandidate) }
        let committed = manager.commitMarkedText(inputState: .selecting)
        editorCommitted += committed; editorMarked = ""; showCandidates = false
        keyLabel = "Enter"
        return committed
    }
    func scheduleAutomaticSelection() {
        automaticTask?.cancel(); inputGeneration &+= 1
        let generation = inputGeneration
        guard !recording else { return }
        guard !liveReading.isEmpty else {
            manager?.stopComposition(); editorMarked = ""; candidates = []; showCandidates = false
            return
        }
        let example = JevExample(context: context, reading: liveReading, expected: "")
        automaticTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, generation == inputGeneration,
                      let snapshot = prepareEditor(example) else { return }
                if automatic {
                    status = "文脈から候補を選択中…"
                    let record = try await choose(snapshot, example: example)
                    guard !Task.isCancelled, generation == inputGeneration else { return }
                    editorMarked = record.decision.choice; activeCandidate = 0
                    candidates = [record.decision.choice] + snapshot.candidates.filter { $0 != record.decision.choice }
                }
            } catch is CancellationError {} catch { status = error.localizedDescription }
        }
    }
    func movie() {
        guard !busy else { return }
        automaticTask?.cancel(); Config.LiveConversion().value = true; busy = true; recording = true
        Task { @MainActor in
            defer { busy = false; recording = false; automatic = false; experiencePhase = "自動選択デモ完了" }
            do {
                let stored = try Data(contentsOf: JevLocalConfig.directory.appendingPathComponent("movie-examples.json"))
                let example = try JSONDecoder().decode([JevExample].self, from: stored)[0]
                automatic = false; manualMoves = 0; keyLabel = "Space"
                experiencePhase = "候補送りの操作を再現"
                headline = "書きたいだけなのに。"
                guard let first = prepareEditor(example), let target = first.candidates.firstIndex(of: example.expected) else { return }
                showCandidates = false; keyLabel = ""
                let firstTrace = liveTrace
                editorMarked = ""
                try await Task.sleep(for: .milliseconds(500))
                for step in firstTrace {
                    editorMarked = step["marked"] ?? ""
                    try await Task.sleep(for: .milliseconds(180))
                }
                try await Task.sleep(for: .milliseconds(500))
                showCandidates = true
                try await Task.sleep(for: .milliseconds(350))
                for _ in 0..<target {
                    nextEditorCandidate()
                    try await Task.sleep(for: .milliseconds(220))
                }
                try await Task.sleep(for: .milliseconds(400))
                let manualText = commitEditor()
                guard manualText == example.expected else { throw JevError.invalidResponse }
                editorSuffix = "。"
                try await Task.sleep(for: .milliseconds(450))

                automatic = true; experiencePhase = "Jev 自動選択 ON"
                headline = "候補を探さず、続きを書く。"
                editorCommitted = ""; editorSuffix = ""; editorMarked = ""
                completed = false; keyLabel = ""; showCandidates = false
                status = "同じ文章を、もう一度。"
                try await Task.sleep(for: .milliseconds(400))
                guard let second = prepareEditor(example) else { return }
                let secondTrace = liveTrace
                for step in secondTrace {
                    editorMarked = step["marked"] ?? ""
                    try await Task.sleep(for: .milliseconds(180))
                }
                keyLabel = ""; status = "文脈から自動選択中…"
                let record = try await choose(second, example: example)
                editorMarked = record.decision.choice
                try await Task.sleep(for: .milliseconds(500))
                let automaticText = commitEditor()
                guard automaticText == record.decision.choice else { throw JevError.invalidResponse }
                for character in "。修正が終わり次第、印刷会社へ送る。" {
                    editorSuffix.append(character); keyLabel = "入力中"
                    try await Task.sleep(for: .milliseconds(80))
                }
                keyLabel = ""; headline = "変換より、書くことに集中したい。"
                status = "この再現：候補送り \(manualMoves)回 → 0回 / Jevが選択、Enterで確定"
                try await Task.sleep(for: .seconds(3))
                saveRecords(name: "experience-runs.json")
                let evidence: [String: Any] = ["context":example.context,"reading":example.reading,"candidates":first.candidates,"manualMoves":manualMoves,"manualCommitted":manualText,"automaticCommitted":automaticText,"sameCandidates":first.candidates == second.candidates,"apiElapsedMS":record.decision.elapsedMS,"inputIsReplay":true,"zenzai":true,"liveConversion":Config.LiveConversion().value,"zenzaiContextCharacters":120,"jevContextCharacters":120,"baselineLiveTrace":firstTrace,"jevLiveTrace":secondTrace]
                let data = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted,.sortedKeys])
                try data.write(to: JevLocalConfig.directory.appendingPathComponent("experience-evidence.json"))
            } catch { status = error.localizedDescription }
        }
    }
}

struct JevDemoView: View {
    @ObservedObject var model: JevDemoModel
    let ink = Color(red: 0.10, green: 0.13, blue: 0.20)
    let green = Color(red: 0.05, green: 0.42, blue: 0.32)
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("原稿メモ").font(.system(size: 16, weight: .medium))
                Spacer()
                Toggle("Jev", isOn: $model.automatic).toggleStyle(.switch)
                    .onChange(of: model.automatic) { _ in if !model.recording { model.scheduleAutomaticSelection() } }
            }.padding(.horizontal, 26).frame(height: 58)
            Divider()
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 22) {
                    Text(model.context).font(.system(size: 27)).lineSpacing(10)
                    (Text(model.editorCommitted)
                     + Text(model.editorMarked).underline(!model.editorMarked.isEmpty)
                     + Text(model.editorSuffix)
                     + Text("▏"))
                        .font(.system(size: 34)).lineSpacing(10)
                    Spacer()
                }
                if model.showCandidates { candidatePopup.padding(.top, 145).padding(.leading, 125) }
            }.padding(32).frame(maxHeight: .infinity)
            if !model.recording { controls.padding(16) }
        }.frame(width: 1100, height: 660).background(.white).foregroundStyle(ink).preferredColorScheme(.light)
    }
    var candidatePopup: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.candidates.prefix(8).enumerated()), id: \.offset) { index, value in
                HStack {
                    Text("\(index + 1)").font(.system(size: 13)).opacity(0.6).frame(width: 20)
                    Text(value).font(.system(size: 20, weight: index == model.activeCandidate ? .semibold : .regular))
                    Spacer()
                }.padding(.horizontal, 12).frame(height: 28)
                    .background(index == model.activeCandidate ? Color(red: 0.18, green: 0.37, blue: 0.85) : .clear)
                    .foregroundStyle(index == model.activeCandidate ? Color.white : ink)
            }
        }.frame(width: 230).padding(6).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.17), radius: 12, y: 5)
    }
    var controls: some View {
        HStack {
            TextField("読み（ひらがな）", text: $model.liveReading).frame(width: 170)
                .onChange(of: model.liveReading) { _ in model.scheduleAutomaticSelection() }
            Toggle("自動選択（外部API）", isOn: $model.automatic).toggleStyle(.switch)
                .onChange(of: model.automatic) { _ in if !model.recording { model.scheduleAutomaticSelection() } }
            Button("次候補") { model.nextEditorCandidate() }
            Button("確定") { _ = model.commitEditor() }
            Spacer()
            Button("収録デモ") { model.movie() }.disabled(model.busy)
        }.font(.system(size: 13))
    }
}

@MainActor final class JevDemoWindow: NSWindowController {
    let model = JevDemoModel()
    init() {
        let window = NSWindow(contentRect: NSRect(x: 50, y: 70, width: 1100, height: 660), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "原稿メモ"
        super.init(window: window)
        window.contentView = NSHostingView(rootView: JevDemoView(model: model))
        window.isReleasedWhenClosed = false
    }
    required init?(coder: NSCoder) { fatalError() }
}
