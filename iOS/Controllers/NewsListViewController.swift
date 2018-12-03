//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Common
import CoreData
import UIKit

fileprivate let localLog = Logger(subsystem: "org.schulcloud.NewsListViewController", category: "iOS.NewsListViewController")

public class NewsListViewController: UITableViewController {

    private var coreDataTableViewDataSource: CoreDataTableViewDataSource<NewsListViewController>?

    private lazy var fetchedResultController: NSFetchedResultsController<NewsArticle> = {
        let fetchRequest: NSFetchRequest<NewsArticle> = NewsArticle.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "displayAt", ascending: false)]
        return NSFetchedResultsController(fetchRequest: fetchRequest,
                                          managedObjectContext: CoreDataHelper.viewContext,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }()

    // MARK: - UI Methods
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.coreDataTableViewDataSource = CoreDataTableViewDataSource(self.tableView,
                                                                       fetchedResultsController: self.fetchedResultController,
                                                                       cellReuseIdentifier: "newsCell",
                                                                       delegate: self)

        self.fetchNewsArticle()
        self.synchronizeNewsArticle()
    }

    @IBAction func didTriggerRefresh(_ sender: Any) {
        self.synchronizeNewsArticle()
    }

    fileprivate func synchronizeNewsArticle() {
        NewsArticleHelper.syncNewsArticles().onFailure { error in
            localLog.error("%@", error.localizedDescription)
        }.onComplete { _ in
            self.refreshControl?.endRefreshing()
        }
    }

    fileprivate func fetchNewsArticle() {
        do {
            try self.fetchedResultController.performFetch()
        } catch let fetchError as NSError {
            localLog.error("%@", fetchError.description)
        }
    }

    @IBAction func donePressed() {
        self.dismiss(animated: true)
    }
}

extension NewsListViewController: CoreDataTableViewDataSourceDelegate {
    func configure(_ cell: NewsArticleCell, for object: NewsArticle) {
        cell.configure(for: object)
    }
}
