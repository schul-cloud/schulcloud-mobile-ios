//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Common
import UIKit

/// TODO(permissions):
///     contentView? Should we not display the content of lesson if no permission? Seems off
class SingleLessonViewController: UITableViewController {

    var lesson: Lesson! {
        didSet {
            self.contents = self.lesson!.contents.sorted { $0.insertDate < $1.insertDate }
            for content in self.contents {
                guard content.type == .text else { continue }
                self.renderedHTMLCache[content.id] = self.htmlHelper.attributedString(for: content.text!)
            }
        }
    }

    let htmlHelper = HTMLHelper.default
    private var renderedHTMLCache: [String: NSAttributedString] = [:]
    private var contents: [LessonContent] = []

    let textCellVerticalMargin: CGFloat = 25

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = lesson.name
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.contents.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let content = self.contents[indexPath.row]
        switch content.type {
        case .text:
            let attrText = self.renderedHTMLCache[content.id]!
            let width = tableView.readableContentGuide.layoutFrame.width
            let context = NSStringDrawingContext()
            let size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            return attrText.boundingRect(with: size, options: [.usesLineFragmentOrigin], context: context).height + textCellVerticalMargin
        default:
            return 44
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let content = self.contents[indexPath.row]

        switch content.type {
        case .other:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.unknownCell, for: indexPath)!
            let font = UIFont.italicSystemFont(ofSize: 15.0)
            cell.textLabel?.attributedText = NSAttributedString(string: "This content type isn't supported yet",
                                                                attributes: [NSAttributedString.Key.font: font])
            return cell
        case .text:
            let textCell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.textCell, for: indexPath)!
            textCell.configure(text: self.renderedHTMLCache[content.id]!)
            return textCell
        }
    }
}
