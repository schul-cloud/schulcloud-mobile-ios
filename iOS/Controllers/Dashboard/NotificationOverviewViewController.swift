//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Common
import UIKit

struct SCNotification { // }: Unmarshaling {
    let body: String
    let title: String?
    let action: URL?

/*
    init(object: MarshaledObject) throws {
        let message = try object.value(for: "message") as JSONObject
        body = try message.value(for: "body")
        title = try? message.value(for: "title")
        action = try? message.value(for: "action")
    }

*/
}

class NotificationOverviewViewController: UITableViewController {

    static let numberOfShownCells = 3

    weak var delegate: ShortNotificationViewControllerDelegate?
    var notifications: [SCNotification] = [] {
        didSet {
            let moreCellsToShow = self.notifications.count > NotificationOverviewViewController.numberOfShownCells
            self.tableView.tableFooterView?.isHidden = !moreCellsToShow
            self.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.tableFooterView?.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.tableView.layoutIfNeeded()
        self.delegate?.viewHeightDidChange(to: self.height)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.notifications.isEmpty {
            return 1
        }

        return min(self.notifications.count, NotificationOverviewViewController.numberOfShownCells)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = self.notifications.isEmpty ? "emptyListCell" : "notificationCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        if let notificationCell = cell as? NotificationCell {
            notificationCell.notification = self.notifications[indexPath.row]
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    @IBAction private func tappedViewMore() {
        self.delegate?.didPressViewMoreButton()
    }
}

extension NotificationOverviewViewController: ViewHeightDataSource {
    var height: CGFloat {
        var viewHeight = self.tableView.contentSize.height
        if let footer = self.tableView.tableFooterView, footer.isHidden {
            let bottomPadding: CGFloat = 16.0
            viewHeight -= footer.frame.size.height - bottomPadding
        }

        return viewHeight
    }
}

extension NotificationOverviewViewController: PermissionInfoDataSource {
    static let requiredPermission = UserPermissions.notificationView
}

protocol ShortNotificationViewControllerDelegate: AnyObject {

    func viewHeightDidChange(to newHeight: CGFloat)
    func didPressViewMoreButton()

}
