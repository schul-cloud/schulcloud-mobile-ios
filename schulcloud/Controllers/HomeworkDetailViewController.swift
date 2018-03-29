//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
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
        self.subjectLabel.text = homework.courseName.uppercased()
        self.titleLabel.text = homework.name
        self.coloredStrip.backgroundColor = homework.color

        let description = homework.cleanedDescriptionText
        if let attributedString = NSMutableAttributedString(html: description) {
            let range = NSMakeRange(0, attributedString.string.count)
            attributedString.addAttribute(NSAttributedStringKey.font, value: UIFont.preferredFont(forTextStyle: .body), range: range)
            self.contentLabel.attributedText = attributedString.trailingNewlineChopped
        } else {
            self.contentLabel.text = description
        }

        let (dueText, dueColor) = homework.dueTextAndColor
        self.dueLabel.text = dueText
        self.dueLabel.textColor = dueColor
    }

}
