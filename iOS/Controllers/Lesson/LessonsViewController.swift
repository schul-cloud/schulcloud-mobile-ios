//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Common
import CoreData
import UIKit

public class LessonsViewController: UITableViewController {

    var course: Course!

    private var coreDataTableViewDataSource: CoreDataTableViewDataSource<LessonsViewController>?

    private lazy var fetchedResultsController: NSFetchedResultsController<Lesson> = {
        let fetchRequest: NSFetchRequest<Lesson> = Lesson.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "course == %@", self.course)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: CoreDataHelper.viewContext,
                                                                  sectionNameKeyPath: nil,
                                                                  cacheName: nil)
        return fetchedResultsController
    }()

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.coreDataTableViewDataSource = CoreDataTableViewDataSource(self.tableView,
                                                                       fetchedResultsController: self.fetchedResultsController,
                                                                       cellReuseIdentifier: R.reuseIdentifier.lessonCell.identifier,
                                                                       delegate: self)

        tableView.rowHeight = UITableView.automaticDimension
        self.title = course.name
        performFetch()
        self.updateData()
    }

    @IBAction private func didTriggerRefresh() {
        self.updateData()
    }

    func updateData() {
        LessonHelper.syncLessons(for: self.course).onFailure { error in
            log.error("Failed to sync lessons", error: error)
        }.onComplete { _ in
            self.refreshControl?.endRefreshing()
        }
    }

    func performFetch() {
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            log.error("Unable to perform lessons FetchRequest", error: error)
        }
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueInfo = R.segue.lessonsViewController.singleLesson(segue: segue) else {
            super.prepare(for: segue, sender: nil)
            return
        }

        guard let currentUser = Globals.currentUser, currentUser.permissions.contains(.contentView) else {
            let controller = UIAlertController(forMissingPermission: .contentView)
            self.present(controller, animated: true)
            return
        }

        guard let selectedCell = sender as? UITableViewCell else { return }
        guard let indexPath = tableView.indexPath(for: selectedCell) else { return }
        segueInfo.destination.lesson = self.fetchedResultsController.object(at: indexPath)
    }
}

extension LessonsViewController: CoreDataTableViewDataSourceDelegate {
    func configure(_ cell: UITableViewCell, for item: Lesson) {
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = item.descriptionText
    }
}
