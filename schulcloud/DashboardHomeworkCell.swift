//
//  DashboardHomeworkCell.swift
//  schulcloud
//
//  Created by Carl Julius Gödecken on 31.05.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import UIKit
import CoreData

class DashboardHomeworkCell: UITableViewCell {

    @IBOutlet var numberOfOpenTasksLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        numberOfOpenTasksLabel.text = "?"
            NotificationCenter.default.addObserver(self, selector: #selector(DashboardHomeworkCell.updateHomeworkCount), name: NSNotification.Name(rawValue: Homework.changeNotificationName), object: nil)
        updateHomeworkCount()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateHomeworkCount() {
        let fetchRequest: NSFetchRequest<Homework> = Homework.fetchRequest()
        let oneWeek = DateComponents(day: 8)
        let inOneWeek = Calendar.current.date(byAdding: oneWeek, to: Date())!
        fetchRequest.predicate = NSPredicate(format: "dueDate >= %@ && dueDate <= %@ ", argumentArray: [Date() as NSDate, inOneWeek as NSDate])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        do {
            let resultsInNextWeek = try managedObjectContext.fetch(fetchRequest)
            numberOfOpenTasksLabel.text = String(resultsInNextWeek.count)
            if let nextTask = resultsInNextWeek.first {
                subtitleLabel.isHidden = false
                let timeDifference = Calendar.current.dateComponents([.day, .hour], from: Date(), to: nextTask.dueDate as Date)
                switch timeDifference.day! {
                case 0..<1:
                    subtitleLabel.text = "Nächste in \(timeDifference.hour!) Stunden fällig"
                case 1:
                    subtitleLabel.text = "Nächste morgen fällig"
                case 2:
                    subtitleLabel.text = "Nächste übermorgen fällig"
                case 3...7:
                    subtitleLabel.text = "Nächste in \(timeDifference.day!) Tagen fällig"
                default:
                    subtitleLabel.isHidden = true
                }
            } else {
                subtitleLabel.isHidden = true
            }
        } catch let error {
            log.error(error)
        }
    }

}
