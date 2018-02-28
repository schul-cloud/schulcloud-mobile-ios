//
//  HomeworkViewController.swift
//  schulcloud
//
//  Created by Carl Julius Gödecken on 28.05.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import UIKit
import CoreData

class HomeworkViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.performFetch()
        self.updateData()
    }

    @IBAction func didTriggerRefresh() {
        self.updateData()
    }

    func updateData() {
        HomeworkHelper.syncHomework().onSuccess { _ in
            self.performFetch()
        }.onFailure { error in
            log.error(error)
        }.onComplete { _ in
            self.refreshControl?.endRefreshing()
        }
    }

    // MARK: - Table view data source
    fileprivate lazy var fetchedResultsController: NSFetchedResultsController<Homework> = {
        let fetchRequest: NSFetchRequest<Homework> = Homework.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: CoreDataHelper.viewContext,
                                                                  sectionNameKeyPath: "dueDateShort",
                                                                  cacheName: nil)
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()

    func performFetch() {
        do {
            try self.fetchedResultsController.performFetch()
        } catch let fetchError as NSError {
            log.error("Unable to Perform Fetch Request: \(fetchError), \(fetchError.localizedDescription)")
        }
        self.tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.fetchedResultsController.sections?[section].objects?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionInfo = fetchedResultsController.sections?[section] else {
            log.error("Unexpected Section")
            return nil
        }

        guard let date = Homework.shortDateFormatter.date(from: sectionInfo.name) else {
            log.error("Could not parse \(sectionInfo.name)")
            return nil
        }

        return Homework.relativeDateString(for: date)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "task", for: indexPath)

        if let homeworkCell = cell as? HomeworkTableViewCell {
            let homework = self.fetchedResultsController.object(at: indexPath)
            homeworkCell.configure(for: homework)
        }

        return cell
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "taskDetail"?:
            guard let detailVC = segue.destination as? HomeworkDetailViewController else { return }
            guard let cell = sender as? UITableViewCell else { return }
            guard let indexPath = self.tableView.indexPath(for: cell) else { return }
            let homework = self.fetchedResultsController.object(at: indexPath)
            detailVC.homework = homework
        default:
            super.prepare(for: segue, sender: sender)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
}
