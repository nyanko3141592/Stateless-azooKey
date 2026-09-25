import Carbon
import Foundation
let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods/Stateless-azooKey.app")
let status = TISRegisterInputSource(path as CFURL)
print("register", status)
let filter = [kTISPropertyBundleID as String: "dev.naoki.inputmethod.StatelessAzooKey"] as CFDictionary
let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
for source in sources {
    if let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
        print("source", id, "enable", TISEnableInputSource(source))
        if CommandLine.arguments.contains("--select") && id == "dev.naoki.inputmethod.StatelessAzooKey.Japanese" { print("select", TISSelectInputSource(source)) }
    }
}
