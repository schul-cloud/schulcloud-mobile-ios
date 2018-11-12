//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Common
import Foundation
import QuickLook

class PreviewManager: NSObject, QLPreviewControllerDataSource {

    let file: File

    public init(file: File) {
        self.file = file
    }

    lazy var previewViewController: UIViewController = {

        switch self.file.localURL.pathExtension.lowercased() {
        case "plist", "json", "txt":
            let webviewPreviewViewContoller = WebviewPreviewViewContoller(nibName: "WebviewPreviewViewContoller",
                                                                          bundle: Bundle(for: WebviewPreviewViewContoller.self))
            let coord = NSFileCoordinator()
            coord.coordinate(readingItemAt: self.file.localURL, options: .withoutChanges, error: nil) { url in
                webviewPreviewViewContoller.fileData = try? Data(contentsOf: url)
            }

            webviewPreviewViewContoller.file = self.file
            return webviewPreviewViewContoller
        default:
            let quickLookPreviewController = QLPreviewController()
            quickLookPreviewController.dataSource = self
            quickLookPreviewController.title = self.file.name
            return quickLookPreviewController
        }
    }()

    // MARK: delegate methods
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return PreviewItem(file: self.file)
    }
}

class PreviewItem: NSObject, QLPreviewItem {

    /*!
     * @abstract The URL of the item to preview.
     * @discussion The URL must be a file URL.
     */

    var file: File

    init(file: File) {
        self.file = file
    }

    var previewItemURL: URL? {
        return self.file.localURL
    }

    var previewItemTitle: String? {
        return self.file.name
    }

}
