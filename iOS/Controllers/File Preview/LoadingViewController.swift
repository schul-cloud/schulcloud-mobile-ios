//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

/// TODO: Cancel request when poping

import BrightFutures
import Common
import Foundation
import QuickLook

class LoadingViewController: UIViewController {
    // MARK: Lifecycle

    @IBOutlet private var progressView: UIProgressView!
    @IBOutlet private var errorLabel: UILabel!
    @IBOutlet private var cancelButton: UIButton!

    let fileSync = FileSync.default
    var file: File!

    override func viewDidLoad() {
        super.viewDidLoad()
        progressView.setProgress(0, animated: false)
        startDownload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    @IBAction func cancelButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    func startDownload() {
        self.fileSync.download(self.file) { progress in
            DispatchQueue.main.async {
                self.progressView.setProgress(progress, animated: true)
            }
        }.onSuccess { _ in
            DispatchQueue.main.async {
                self.showFile()
            }
        }.onFailure { error in
            DispatchQueue.main.async {
                self.show(error: error)
            }
        }
    }

    func showFile() {
        let previewManager = PreviewManager(file: file)
        let controller = previewManager.previewViewController
        controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true

        if let nav = self.navigationController {
            // TODO: add as subview
            var viewControllers = nav.viewControllers
            viewControllers.removeLast(1)
            viewControllers.append(controller)
            nav.setViewControllers(viewControllers, animated: false)
        } else {
            self.present(controller, animated: false, completion: nil)
        }

        if let quickLook = controller as? QLPreviewController {
            // fix for dataSource magically disappearing because hey let's store it in a weak variable in QLPreviewController
            quickLook.dataSource = previewManager
            quickLook.reloadData()
        }
    }

    func show(error: Error) {
        self.cancelButton.isHidden = true
        self.progressView.isHidden = true
        self.errorLabel.text = error.localizedDescription
        self.errorLabel.isHidden = false
    }
}
