import Cocoa
import Core

/// Recording-only presentation of the real session. No inference or substituted output.
@MainActor final class SegmentationVideoView: NSView {
    struct Piece { let text: String; let japanese: Bool? }
    var raw = ""
    var output = ""
    var pieces: [Piece] = []
    var committed = false
    var example = 1
    override var isFlipped: Bool { true }
    private let ink = NSColor(calibratedRed:0.94,green:0.95,blue:0.98,alpha:1)
    private let muted = NSColor(calibratedRed:0.53,green:0.58,blue:0.68,alpha:1)
    private let japanese = NSColor(calibratedRed:1,green:0.60,blue:0.47,alpha:1)
    private let english = NSColor(calibratedRed:0.32,green:0.80,blue:0.92,alpha:1)
    func update(raw: String, output: String, decision: JevMixedDecision?, committed: Bool) {
        self.committed = committed
        if !raw.isEmpty {
            self.raw = raw; self.output = output
            pieces = []
            if let decision, decision.spans.map(\.text).joined() == raw {
                for (index,span) in decision.spans.enumerated() {
                    guard !span.protected,
                          let d = decision.decisions.first(where: { $0.index == index }) else {
                        pieces.append(.init(text:span.text,japanese:nil)); continue
                    }
                    if let start = d.japaneseStart, start >= 0, start < span.text.count {
                        if start > 0 { pieces.append(.init(text:String(span.text.prefix(start)),japanese:false)) }
                        pieces.append(.init(text:String(span.text.dropFirst(start)),japanese:true))
                    } else { pieces.append(.init(text:span.text,japanese:false)) }
                }
            }
        } else if !output.isEmpty { self.output = output.trimmingCharacters(in:.whitespacesAndNewlines) }
        needsDisplay = true
    }
    func clear(example: Int) {
        self.example = example; raw = ""; output = ""; pieces = []; committed = false; needsDisplay = true
    }
    private func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor, mono: Bool = false, weight: NSFont.Weight = .regular) {
        let font = mono ? NSFont.monospacedSystemFont(ofSize:size,weight:weight) : NSFont.systemFont(ofSize:size,weight:weight)
        (value as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:[.font:font,.foregroundColor:color])
    }
    private func width(_ value: String, size: CGFloat, mono: Bool = false) -> CGFloat {
        (value as NSString).size(withAttributes:[.font:mono ? NSFont.monospacedSystemFont(ofSize:size,weight:.medium) : NSFont.systemFont(ofSize:size)]).width
    }
    private func panel(_ rect: NSRect) {
        NSColor(calibratedRed:0.075,green:0.092,blue:0.13,alpha:1).setFill()
        NSBezierPath(roundedRect:rect,xRadius:18,yRadius:18).fill()
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed:0.035,green:0.046,blue:0.075,alpha:1).setFill(); bounds.fill()
        text("Stateless-azooKey",x:54,y:31,size:21,color:ink,weight:.semibold)
        text("モード切替なし",x:237,y:35,size:14,color:muted)
        text(String(format:"%02d / 04",example),x:1061,y:35,size:14,color:muted,mono:true)
        panel(NSRect(x:42,y:93,width:1116,height:128))
        panel(NSRect(x:42,y:245,width:1116,height:189))
        panel(NSRect(x:42,y:458,width:1116,height:175))
        text("01  入力",x:66,y:111,size:16,color:muted,weight:.medium)
        let inputSize: CGFloat = min(34,1025 / max(1,width(raw,size:34,mono:true)) * 34)
        text(raw,x:66,y:155,size:inputSize,color:ink,mono:true)
        if !committed {
            english.setFill()
            NSRect(x:min(1119,66+width(raw,size:inputSize,mono:true)+4),y:156,width:2,height:32).fill()
        }
        text("02  区間判定",x:66,y:263,size:16,color:muted,weight:.medium)
        text("日本語 → 変換",x:790,y:263,size:14,color:japanese)
        text("English → そのまま",x:968,y:263,size:14,color:english)
        // All chip text comes from the current decision's source spans, including transient revisions.
        var x: CGFloat = 66; var y: CGFloat = 305
        for piece in pieces {
            let size: CGFloat = 26
            let w = max(20,width(piece.text,size:size,mono:true)+24)
            if x+w > 1134 { x = 66; y += 58 }
            let color = piece.japanese == true ? japanese : piece.japanese == false ? english : muted
            color.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:48),xRadius:9,yRadius:9).fill()
            text(piece.text,x:x+12,y:y+9,size:size,color:color,mono:true,weight:.medium)
            x += w+7
        }
        text("03  ライブ変換",x:66,y:476,size:16,color:muted,weight:.medium)
        let outputSize: CGFloat = min(44,1050 / max(1,width(output,size:44)) * 44)
        let rendered = NSMutableAttributedString(string:output,attributes:[.font:NSFont.systemFont(ofSize:outputSize,weight:.medium),.foregroundColor:japanese])
        let source = output as NSString
        var searchStart = 0
        for piece in pieces where piece.japanese != true && !piece.text.isEmpty {
            let range = source.range(of:piece.text,range:NSRange(location:searchStart,length:source.length-searchStart))
            guard range.location != NSNotFound else {
                rendered.addAttribute(.foregroundColor,value:ink,range:NSRange(location:0,length:rendered.length)); break
            }
            rendered.addAttribute(.foregroundColor,value:piece.japanese == false ? english : muted,range:range)
            searchStart = NSMaxRange(range)
        }
        if !committed {
            rendered.addAttributes([.underlineStyle:NSUnderlineStyle.single.rawValue,.underlineColor:muted.withAlphaComponent(0.4)],range:NSRange(location:0,length:rendered.length))
        }
        rendered.draw(at:NSPoint(x:66,y:525))
        if committed {
            text("↵  確定",x:1050,y:594,size:14,color:english,weight:.medium)
        } else {
            text("入力中",x:1072,y:594,size:14,color:muted)
        }
    }
}
