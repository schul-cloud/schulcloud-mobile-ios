//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Common
import CoreData
import UIKit

class CoursesViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    private lazy var fetchedResultsController: NSFetchedResultsController<Course> = {
        let fetchRequest: NSFetchRequest<Course> = Course.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: CoreDataHelper.viewContext,
                                                                  sectionNameKeyPath: nil,
                                                                  cacheName: nil)
        fetchedResultsController.delegate = self
        return fetchedResultsController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        self.performFetch()
        self.updateData()
    }

    @IBAction private func didTriggerRefresh() {
        self.updateData()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.collectionView.collectionViewLayout.invalidateLayout()
    }

    func updateData() {
        CourseHelper.syncCourses().onFailure { error in
            log.error("Failed syncing courses", error: error)
        }
    }

    func performFetch() {
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            log.error("Unable to Perform Fetch Request", error: error)
        }

        collectionView?.reloadData()
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.courseCell, for: indexPath)!

        let course = fetchedResultsController.object(at: indexPath)
        cell.configure(for: course)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return CGSize.zero
        }

        let minimumCellWidth = CourseCell.minimalWidth(for: self.traitCollection.preferredContentSizeCategory)
        let cellHeight = minimumCellWidth

        let viewWidth = collectionView.bounds.size.width
        let cellSpacing = flowLayout.minimumInteritemSpacing
        let insets = flowLayout.sectionInset

        let availabelSpace = viewWidth - insets.left - insets.right
        let numberOfCellsPerRow = floor((availabelSpace + cellSpacing) / (minimumCellWidth + cellSpacing))
        let cellWidth = (availabelSpace - ((numberOfCellsPerRow - 1) * cellSpacing)) / numberOfCellsPerRow

        return CGSize(width: cellWidth, height: cellHeight)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueInfo = R.segue.coursesViewController.courseDetail(segue: segue) else {
            super.prepare(for: segue, sender: nil)
            return
        }

        guard let selectedCell = sender as? UICollectionViewCell else { return }
        guard let indexPath = self.collectionView?.indexPath(for: selectedCell) else { return }

        segueInfo.destination.course = self.fetchedResultsController.object(at: indexPath)
    }
}

extension CoursesViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.collectionView?.reloadData()
    }
}
