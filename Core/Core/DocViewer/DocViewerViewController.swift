//
// This file is part of Canvas.
// Copyright (C) 2018-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import UIKit
import PSPDFKit
import PSPDFKitUI

public class DocViewerViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var loadingView: CircleProgressView!
    @IBOutlet weak var syncAnnotationsButton: UIButton!
    let toolbar = UIToolbar()
    let toolbarContainer = FlexibleToolbarContainer()

    public var annotatingDidChange: ((Bool) -> Void)?
    var annotationProvider: DocViewerAnnotationProvider?
    let env = AppEnvironment.shared
    public var fallbackURL: URL!
    var fallbackUsed = false
    public var filename = ""
    public var isAnnotatable = false
    var metadata: APIDocViewerMetadata?
    weak var parentNavigationItem: UINavigationItem?
    let pdf = PDFViewController()
    public var previewURL: URL?
    lazy var session = DocViewerSession { [weak self] in
        performUIUpdate { self?.sessionIsReady() }
    }

    public internal(set) static var hasPSPDFKitLicense = false

    public static func setup(_ secret: Secret) {
        guard let key = secret.string, !hasPSPDFKitLicense else { return }
        SDK.setLicenseKey(key)
        hasPSPDFKitLicense = true
    }

    public static func create(filename: String, previewURL: URL?, fallbackURL: URL, navigationItem: UINavigationItem? = nil) -> DocViewerViewController {
        stylePSPDFKit()

        let controller = loadFromStoryboard()
        controller.parentNavigationItem = navigationItem
        controller.filename = filename
        controller.previewURL = previewURL
        controller.fallbackURL = fallbackURL
        controller.parentNavigationItem = navigationItem
        return controller
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        loadingView.color = nil

        embed(pdf, in: contentView)
        pdf.delegate = self
        pdf.view.isHidden = true
        pdf.updateConfiguration(builder: docViewerConfigurationBuilder)

        syncAnnotationsButton.setTitleColor(.white, for: .normal)
        syncAnnotationsButton.setTitleColor(.textDark, for: .disabled)
        annotationSaveStateChanges(saving: false)

        let gestureRecognizer = UITapGestureRecognizer()
        gestureRecognizer.addTarget(self, action: #selector(tapGestureRecognizerDidChangeState))
        gestureRecognizer.delegate = self
        pdf.interactions.allInteractions.require(toFail: gestureRecognizer)
        pdf.view.addGestureRecognizer(gestureRecognizer)

        if let url = URL(string: previewURL?.absoluteString ?? "", relativeTo: env.api.baseURL), let loginSession = env.currentSession {
            session.load(url: url, session: loginSession)
        } else {
            loadFallback()
        }
    }

    func sessionIsReady() {
        guard
            session.error == nil,
            let annotations = session.annotations,
            let localURL = session.localURL,
            let metadata = session.metadata,
            let sessionID = session.sessionID
        else { return loadFallback() }

        self.metadata = metadata
        let document = Document(url: localURL)
        if let annotationMeta = metadata.annotations {
            document.defaultAnnotationUsername = annotationMeta.user_name
            document.didCreateDocumentProviderBlock = { [weak self] documentProvider in
                guard let self = self else { return }
                let provider = DocViewerAnnotationProvider(documentProvider: documentProvider, metadata: metadata, annotations: annotations, api: self.session.api, sessionID: sessionID)
                provider.docViewerDelegate = self
                documentProvider.annotationManager.annotationProviders.append(provider)
                self.annotationProvider = provider
            }
        }
        load(document: document)
    }

    func loadFallback() {
        if let error = session.error { showError(error) }
        if let url = session.localURL {
            return load(document: Document(url: url))
        }

        guard !fallbackUsed else { return }
        fallbackUsed = true
        session.error = nil
        session.annotations = []
        session.loadDocument(downloadURL: fallbackURL)
    }

    func load(document: Document) {
        pdf.document = document
        pdf.view.isHidden = false
        loadingView.isHidden = true

        let share = UIBarButtonItem(barButtonSystemItem: .action, target: pdf.activityButtonItem.target, action: pdf.activityButtonItem.action)
        share.accessibilityIdentifier = "DocViewer.shareButton"
        let search = UIBarButtonItem(barButtonSystemItem: .search, target: pdf.searchButtonItem.target, action: pdf.searchButtonItem.action)
        search.accessibilityIdentifier = "DocViewer.searchButton"
        parentNavigationItem?.rightBarButtonItems = [ share, search ]

        if isAnnotatable, metadata?.annotations?.enabled == true {
            syncAnnotationsButton.isHidden = false
            contentView.addSubview(toolbar)
            toolbar.pin(inside: contentView, bottom: nil)
            contentView.constraints.first { $0.firstAnchor == pdf.view.topAnchor }? .isActive = false
            pdf.view.topAnchor.constraint(equalTo: toolbar.bottomAnchor).isActive = true

            pdf.annotationStateManager.add(self)
            let annotationToolbar = DocViewerAnnotationToolbar(annotationStateManager: pdf.annotationStateManager)
            annotationToolbar.supportedToolbarPositions = .inTopBar
            annotationToolbar.isDragEnabled = false
            annotationToolbar.showDoneButton = false

            contentView.addSubview(toolbarContainer)
            toolbarContainer.pin(inside: contentView)
            toolbarContainer.flexibleToolbar = annotationToolbar
            toolbarContainer.overlaidBar = toolbar
            toolbarContainer.show(animated: true, completion: nil)

            contentView.layoutIfNeeded()
        }

        pdf.documentViewController?.scrollToSpread(at: 0, scrollPosition: .start, animated: false)
    }

    public func setContentInsets(_ insets: UIEdgeInsets) {
        pdf.updateConfigurationWithoutReloading { config in
            config.additionalScrollViewFrameInsets = insets
        }
    }

    public func showError(_ error: Error) {
        loadingView.isHidden = true
        let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(AlertAction(NSLocalizedString("Dismiss", bundle: .core, comment: ""), style: .default))
        env.router.show(alert, from: self, options: .modal())
    }
}

private let disabledMenuItems: [String] = [
    TextMenu.annotationMenuOpacity.rawValue,
    TextMenu.annotationMenuThickness.rawValue,
]

extension DocViewerViewController: PDFViewControllerDelegate, AnnotationStateManagerDelegate {
    // swiftlint:disable function_parameter_count
    public func pdfViewController(
        _ pdfController: PDFViewController,
        shouldShow menuItems: [MenuItem],
        atSuggestedTargetRect rect: CGRect,
        forSelectedText selectedText: String,
        in textRect: CGRect, on pageView: PDFPageView
    ) -> [MenuItem] {
        return menuItems.filter {
            $0.identifier != TextMenu.annotationMenuHighlight.rawValue
        }
    }

    public func pdfViewController(
        _ pdfController: PDFViewController,
        shouldShow menuItems: [MenuItem],
        atSuggestedTargetRect rect: CGRect,
        for annotations: [Annotation]?,
        in annotationRect: CGRect,
        on pageView: PDFPageView
    ) -> [MenuItem] {
        guard env.app == .teacher || annotations?.isEmpty == false else {
            return [] // no items for adding new annotations in Student
        }

        annotations?.forEach {
            (pageView.annotationView(for: $0) as? FreeTextAnnotationView)?.resizableView?.allowRotating = false
        }
        if annotations?.count == 1, let annotation = annotations?.first, let document = pdfController.document, let metadata = metadata?.annotations {
            var realMenuItems = [MenuItem]()
            realMenuItems.append(MenuItem(title: NSLocalizedString("Comments", bundle: .core, comment: "")) { [weak self] in
                let comments = self?.annotationProvider?.getReplies(to: annotation) ?? []
                let view = CommentListViewController.create(comments: comments, inReplyTo: annotation, document: document, metadata: metadata)
                self?.env.router.show(view, from: pdfController, options: .modal(embedInNav: true))
            })

            realMenuItems.append(contentsOf: menuItems.filter {
                guard let identifier = $0.identifier else { return true }
                if identifier == TextMenu.annotationMenuInspector.rawValue {
                    $0.title = NSLocalizedString("Style", bundle: .core, comment: "")
                }
                return (
                    identifier != TextMenu.annotationMenuRemove.rawValue &&
                    identifier != TextMenu.annotationMenuCopy.rawValue &&
                    identifier != TextMenu.annotationMenuNote.rawValue &&
                    !disabledMenuItems.contains(identifier)
                )
            })

            if annotation.isEditable || metadata.permissions == .readwritemanage {
                realMenuItems.append(MenuItem(title: NSLocalizedString("Remove", bundle: .core, comment: ""), image: .trashLine, block: {
                    pdfController.document?.remove(annotations: [annotation], options: nil)
                }, identifier: TextMenu.annotationMenuRemove.rawValue))
            }
            return realMenuItems
        }

        return menuItems.filter {
            guard let identifier = $0.identifier else { return true }
            return !disabledMenuItems.contains(identifier)
        }
    }

    public func pdfViewController(_ pdfController: PDFViewController, shouldShow controller: UIViewController, options: [String: Any]? = nil, animated: Bool) -> Bool {
        return !(controller is StampViewController)
    }

    public func annotationStateManager(
        _ manager: AnnotationStateManager,
        didChangeState oldState: Annotation.Tool?,
        to newState: Annotation.Tool?,
        variant oldVariant: Annotation.Variant?,
        to newVariant: Annotation.Variant?) {
        annotatingDidChange?(newState?.rawValue.isEmpty == false)
    }
    // swiftlint:enable function_parameter_count
}

extension DocViewerViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        pdf.annotationStateManager.state == .stamp &&
            pdf.documentViewController != nil &&
            pdf.document != nil &&
            metadata?.annotations != nil
    }

    @objc func tapGestureRecognizerDidChangeState(_ gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended, let documentViewController = pdf.documentViewController else { return }
        let viewPoint = gestureRecognizer.location(in: documentViewController.view)
        guard let pageView = documentViewController.visiblePageView(at: viewPoint) else { return }
        performTap(pageView: pageView, at: viewPoint)
    }

    func performTap(pageView: PDFPageView, at viewPoint: CGPoint) {
        let state = pdf.annotationStateManager
        guard state.state == .stamp,
            let document = pdf.document,
            let metadata = metadata?.annotations else {
                return
        }
        let pointAnnotation = DocViewerPointAnnotation()
        pointAnnotation.user = metadata.user_id
        pointAnnotation.userName = metadata.user_name
        pointAnnotation.color = state.drawColor
        pointAnnotation.boundingBox = CGRect(x: 0, y: 0, width: 9.33, height: 13.33)
        pointAnnotation.pageIndex = pageView.pageIndex

        pageView.center(pointAnnotation, aroundPDFPoint: pageView.convert(viewPoint, to: pageView.pdfCoordinateSpace))
        document.add(annotations: [ pointAnnotation ], options: nil)

        let view = CommentListViewController.create(comments: [], inReplyTo: pointAnnotation, document: document, metadata: metadata)
        env.router.show(view, from: pdf, options: .modal(embedInNav: true))
    }

}

extension DocViewerViewController: DocViewerAnnotationProviderDelegate {
    func annotationDidExceedLimit(annotation: APIDocViewerAnnotation) {
        guard annotation.type == .ink, pdf.annotationStateManager.state == .ink, let variant = pdf.annotationStateManager.variant else { return }
        pdf.annotationStateManager.toggleState(.ink, variant: variant)
        pdf.annotationStateManager.toggleState(.ink, variant: variant)
    }

    @IBAction func syncAnnotations() {
        annotationProvider?.syncAllAnnotations()
    }

    func annotationDidFailToSave(error: Error) { performUIUpdate {
        self.syncAnnotationsButton.isEnabled = true
        self.syncAnnotationsButton.backgroundColor = .backgroundDanger
        self.syncAnnotationsButton.setTitle(NSLocalizedString("Error Saving. Tap to retry.", bundle: .core, comment: ""), for: .normal)
    } }

    func annotationSaveStateChanges(saving: Bool) { performUIUpdate {
        self.syncAnnotationsButton.isEnabled = false
        self.syncAnnotationsButton.backgroundColor = .backgroundLight
        self.syncAnnotationsButton.setTitle(saving
            ? NSLocalizedString("Saving...", bundle: .core, comment: "")
            : NSLocalizedString("All annotations saved.", bundle: .core, comment: ""),
        for: .normal)
    } }
}
