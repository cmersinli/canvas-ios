//
// Copyright (C) 2019-present Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

public class WrongAppViewController: UIViewController {
    weak var delegate: LoginDelegate?

    @IBOutlet var messageTitle: UILabel?
    @IBOutlet var messageDescription: UILabel?
    @IBOutlet var parentButton: WrongAppLinkView?
    @IBOutlet var studentButton: WrongAppLinkView?
    @IBOutlet var teacherButton: WrongAppLinkView?
    @IBOutlet var loginButton: UIButton?
    @IBOutlet var canvasGuidesButton: UIButton?

    public static func create(delegate: LoginDelegate?) -> WrongAppViewController {
        let controller = loadFromStoryboard()
        controller.delegate = delegate
        return controller
    }

    public override func viewDidLoad() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        messageTitle?.text = NSLocalizedString("Whoops!", bundle: .core, comment: "")
        messageDescription?.text = String.localizedStringWithFormat(
            NSLocalizedString("It looks like you aren’t enrolled in any courses as %@. One of our other apps might be a better fit. Tap one to visit the App Store.", bundle: .core, comment: ""), (
            Bundle.main.isParentApp ? NSLocalizedString("a parent", bundle: .core, comment: "Embedded in 'enrolled in any courses as %@'") :
            Bundle.main.isTeacherApp ? NSLocalizedString("a teacher", bundle: .core, comment: "Embedded in 'enrolled in any courses as %@'") :
            NSLocalizedString("a student", bundle: .core, comment: "Embedded in 'enrolled in any courses as %@'")
        ))

        loginButton?.setTitle(NSLocalizedString("Log In Again", bundle: .core, comment: "").localizedUppercase, for: .normal)
        canvasGuidesButton?.setTitle(NSLocalizedString("Canvas Guides", bundle: .core, comment: "").localizedUppercase, for: .normal)
        canvasGuidesButton?.isHidden = !Bundle.main.isParentApp

        parentButton?.isHidden = Bundle.main.isParentApp
        parentButton?.accessibilityLabel = NSLocalizedString("Canvas Parent", bundle: .core, comment: "")
        parentButton?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(parentPressed)))

        studentButton?.isHidden = Bundle.main.isStudentApp
        studentButton?.accessibilityLabel = NSLocalizedString("Canvas Student", bundle: .core, comment: "")
        studentButton?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(studentPressed)))

        teacherButton?.isHidden = Bundle.main.isTeacherApp
        teacherButton?.accessibilityLabel = NSLocalizedString("Canvas Teacher", bundle: .core, comment: "")
        teacherButton?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(teacherPressed)))
    }

    @IBAction func loginAgainButtonPressed(_ sender: UIButton) {
        guard let entry = AppEnvironment.shared.currentSession else { return }
        delegate?.userDidLogout(keychainEntry: entry)
    }

    @IBAction func canvasGuidesButtonPressed(_ sender: UIButton) {
        guard let url = URL(string: "https://community.canvaslms.com/docs/DOC-9919") else {
            return
        }
        delegate?.openExternalURL(url)
    }

    @IBAction func parentPressed() {
        guard let url = URL(string: "https://itunes.apple.com/us/app/canvas-parent/id1097996698?ls=1&mt=8") else { return }
        delegate?.openExternalURL(url)
    }

    @IBAction func studentPressed() {
        guard let url = URL(string: "https://itunes.apple.com/us/app/canvas-student/id480883488?ls=1&mt=8") else { return }
        delegate?.openExternalURL(url)
    }

    @IBAction func teacherPressed() {
        guard let url = URL(string: "https://itunes.apple.com/us/app/canvas-teacher/id1257834464?ls=1&mt=8") else { return }
        delegate?.openExternalURL(url)
    }
}
