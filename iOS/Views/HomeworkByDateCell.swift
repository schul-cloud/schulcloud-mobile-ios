//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Common
import UIKit

class HomeworkByDateCell: UITableViewCell {

    @IBOutlet private var subjectLabel: UILabel!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var contentLabel: UILabel!
    @IBOutlet private var coloredStrip: UIView!
    @IBOutlet private var dueLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.coloredStrip.layer.cornerRadius = self.coloredStrip.frame.size.height / 2.0
        self.coloredStrip.layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.coloredStrip.layer.cornerRadius = self.coloredStrip.frame.size.height / 2.0
    }

    func configure(for homework: Homework) {
        self.subjectLabel.text = homework.courseName.uppercased()
        self.titleLabel.text = homework.name
        self.dueLabel.text = Homework.timeFormatter.string(from: homework.dueDate)
        self.coloredStrip.backgroundColor = homework.color

        self.contentLabel.text = HTMLHelper.default.stringContent(of: homework.descriptionText).value
    }
}
