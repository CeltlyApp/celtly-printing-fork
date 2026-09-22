import Foundation
import UIKit
import Flutter

// Shares a preverified private file; no second native file write can be hidden.
final class CeltlyShareFile {
    private static var active = false

    static func share(_ args: [String: Any], result: @escaping FlutterResult) {
        guard !active, UIApplication.shared.applicationState == .active,
              let path = args["path"] as? String,
              let size = args["bytes"] as? NSNumber,
              let hash = args["sha256"] as? String,
              hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              size.int64Value > 0, size.int64Value <= 80 * 1024 * 1024 else {
            result(FlutterError(code: "share-unavailable", message: "Could not open sharing.", details: nil)); return
        }
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("share/celtly-report-share-v1", isDirectory: true)
            .resolvingSymlinksInPath()
        let file = URL(fileURLWithPath: path)
        let resolved = file.resolvingSymlinksInPath()
        let prefix = root.path + "/"
        guard resolved.path.hasPrefix(prefix), resolved.path == file.standardizedFileURL.path,
              String(resolved.path.dropFirst(prefix.count)).range(of: "^op_[A-Za-z0-9]+/[A-Za-z0-9][A-Za-z0-9._-]{0,179}\\.pdf$", options: .regularExpression) != nil,
              !resolved.lastPathComponent.contains(".."),
              let attributes = try? FileManager.default.attributesOfItem(atPath: resolved.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.int64Value == size.int64Value,
              FileManager.default.isReadableFile(atPath: resolved.path),
              let presenter = UIApplication.shared.keyWindow?.rootViewController,
              presenter.presentedViewController == nil, presenter.view.window != nil else {
            result(FlutterError(code: "share-unavailable", message: "Could not open sharing.", details: nil)); return
        }
        active = true
        // A .pdf file URL supplies the PDF type to UIActivityViewController.
        let sheet = UIActivityViewController(activityItems: [resolved], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: (args["x"] as? NSNumber)?.doubleValue ?? 0,
            y: (args["y"] as? NSNumber)?.doubleValue ?? 0,
            width: max(1, (args["w"] as? NSNumber)?.doubleValue ?? 1),
            height: max(1, (args["h"] as? NSNumber)?.doubleValue ?? 1))
        var finished = false
        sheet.completionWithItemsHandler = { _, completed, _, error in
            guard !finished else { return }; finished = true
            active = false
            if error != nil {
                result(FlutterError(code: "share-unavailable", message: "Could not complete sharing.", details: nil))
            } else {
                result(completed ? "unknown" : "cancelled")
            }
            // No deletion: completion does not prove final downstream delivery.
        }
        presenter.present(sheet, animated: true)
        if presenter.presentedViewController !== sheet && sheet.presentingViewController == nil {
            finished = true; active = false
            result(FlutterError(code: "share-unavailable", message: "Could not open sharing.", details: nil))
        }
    }
}
