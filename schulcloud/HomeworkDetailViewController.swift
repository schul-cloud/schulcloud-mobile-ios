//
//  HomeworkDetailViewController.swift
//  schulcloud
//
//  Created by Max Bothe on 04.09.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import UIKit

class HomeworkDetailViewController: UIViewController {

    @IBOutlet weak var subjectLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var coloredStrip: UIView!
    @IBOutlet weak var dueLabel: UILabel!

    var homework: Homework?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.coloredStrip.layer.cornerRadius = self.coloredStrip.frame.size.height/2.0

        guard let homework = self.homework else { return }
        self.configure(for: homework)
    }

    func configure(for homework: Homework) {
        self.subjectLabel.text = homework.course?.name.uppercased() ?? "PERSÖNLICH"
        self.titleLabel.text = homework.name
        if let colorString = homework.course?.colorString {
            self.coloredStrip.backgroundColor = UIColor(hexString: colorString)
        } else {
            self.coloredStrip.backgroundColor = UIColor.clear
        }

        let description = homework.descriptionText.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        if let attributedString = NSMutableAttributedString(html: description) {
            let range = NSMakeRange(0, attributedString.string.count)
            attributedString.addAttribute(NSFontAttributeName, value: UIFont.preferredFont(forTextStyle: .body), range: range)
            self.contentLabel.attributedText = attributedString.trailingNewlineChopped
        } else {
            self.contentLabel.text = description
        }

        self.updateDueDate(for: homework)
    }

    private func updateDueDate(for homework: Homework) {
        let highlightColor = UIColor(red: 1.0, green: 45/255, blue: 0.0, alpha: 1.0)
        let timeDifference = Calendar.current.dateComponents([.day, .hour], from: Date(), to: homework.dueDate as Date)

        guard let dueDay = timeDifference.day, !homework.publicSubmissions else {
            self.dueLabel.text = ""
            return
        }

        switch dueDay {
        case Int.min..<0:
            self.dueLabel.text = "⚐ Überfällig"
            self.dueLabel.textColor = highlightColor
        case 0..<1:
            self.dueLabel.text = "⚐ In \(timeDifference.hour!) Stunden fällig"
            self.dueLabel.textColor = highlightColor
        case 1:
            self.dueLabel.text = "⚐ Morgen fällig"
            self.dueLabel.textColor = highlightColor
        case 2:
            self.dueLabel.text = "Übermorgen"
            self.dueLabel.textColor = UIColor.black
        case 3...7:
            self.dueLabel.text = "In \(dueDay) Tagen"
            self.dueLabel.textColor = UIColor.black
        default:
            self.dueLabel.text = ""
        }
    }

}