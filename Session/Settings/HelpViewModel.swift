// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import CryptoKit
import GRDB
import DifferenceKit
import SessionUIKit
import SessionMessagingKit
import SessionUtilitiesKit

class HelpViewModel: SessionTableViewModel, NavigatableStateHolder, ObservableTableSource {
    typealias TableItem = Section
    
    public let dependencies: Dependencies
    public let navigatableState: NavigatableState = NavigatableState()
    public let state: TableDataState<Section, TableItem> = TableDataState()
    public let observableState: ObservableTableSourceState<Section, TableItem> = ObservableTableSourceState()
    
#if DEBUG
    private var databaseKeyEncryptionPassword: String = ""
#endif
    
    // MARK: - Initialization
    
    init(using dependencies: Dependencies = Dependencies()) {
        self.dependencies = dependencies
    }
    
    // MARK: - Section
    
    public enum Section: SessionTableSection {
        case report
        case translate
        case feedback
        case faq
        case support
#if DEBUG
        case exportDatabase
#endif
        
        var style: SessionTableSectionStyle { .padding }
    }
    
    // MARK: - Content
    
    let title: String = "sessionHelp".localized()
    
    lazy var observation: TargetObservation = [
        SectionModel(
            model: .report,
            elements: [
                SessionCell.Info(
                    id: .report,
                    title: "helpReportABug".localized(),
                    subtitle: "helpReportABugExportLogsDescription"
                        .put(key: "app_name", value: Constants.app_name)
                        .localized(),
                    rightAccessory: .highlightingBackgroundLabel(
                        title: "helpReportABugExportLogs".localized()
                    ),
                    onTapView: { HelpViewModel.shareLogs(targetView: $0) }
                )
            ]
        ),
        SectionModel(
            model: .translate,
            elements: [
                SessionCell.Info(
                    id: .translate,
                    title: "helpHelpUsTranslateSession"
                        .put(key: "app_name", value: Constants.app_name)
                        .localized(),
                    rightAccessory: .icon(
                        UIImage(systemName: "arrow.up.forward.app")?
                            .withRenderingMode(.alwaysTemplate),
                        size: .small
                    ),
                    onTap: {
                        guard let url: URL = URL(string: "https://getsession.org/translate") else {
                            return
                        }
                        
                        UIApplication.shared.open(url)
                    }
                )
            ]
        ),
        SectionModel(
            model: .feedback,
            elements: [
                SessionCell.Info(
                    id: .feedback,
                    title: "helpWedLoveYourFeedback".localized(),
                    rightAccessory: .icon(
                        UIImage(systemName: "arrow.up.forward.app")?
                            .withRenderingMode(.alwaysTemplate),
                        size: .small
                    ),
                    onTap: {
                        guard let url: URL = URL(string: "https://getsession.org/survey") else {
                            return
                        }
                        
                        UIApplication.shared.open(url)
                    }
                )
            ]
        ),
        SectionModel(
            model: .faq,
            elements: [
                SessionCell.Info(
                    id: .faq,
                    title: "helpFAQ".localized(),
                    rightAccessory: .icon(
                        UIImage(systemName: "arrow.up.forward.app")?
                            .withRenderingMode(.alwaysTemplate),
                        size: .small
                    ),
                    onTap: {
                        guard let url: URL = URL(string: "https://getsession.org/faq") else {
                            return
                        }
                        
                        UIApplication.shared.open(url)
                    }
                )
            ]
        ),
        SectionModel(
            model: .support,
            elements: [
                SessionCell.Info(
                    id: .support,
                    title: "helpSupport".localized(),
                    rightAccessory: .icon(
                        UIImage(systemName: "arrow.up.forward.app")?
                            .withRenderingMode(.alwaysTemplate),
                        size: .small
                    ),
                    onTap: {
                        guard let url: URL = URL(string: "https://sessionapp.zendesk.com/hc/en-us") else {
                            return
                        }
                        
                        UIApplication.shared.open(url)
                    }
                )
            ]
        ),
        maybeExportDbSection
    ]
    
#if DEBUG
    private lazy var maybeExportDbSection: SectionModel? = SectionModel(
        model: .exportDatabase,
        elements: [
            SessionCell.Info(
                id: .support,
                title: "Export Database", // stringlint:disable
                rightAccessory: .icon(
                    UIImage(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")?
                        .withRenderingMode(.alwaysTemplate),
                    size: .small
                ),
                styling: SessionCell.StyleInfo(
                    tintColor: .danger
                ),
                onTapView: { [weak self] view in self?.exportDatabase(view) }
            )
        ]
    )
#else
    private let maybeExportDbSection: SectionModel? = nil
#endif
    
    // MARK: - Functions
    
    public static func shareLogs(
        viewControllerToDismiss: UIViewController? = nil,
        targetView: UIView? = nil,
        animated: Bool = true,
        onShareComplete: (() -> ())? = nil
    ) {
        guard
            let latestLogFilePath: String = Log.logFilePath(),
            Singleton.hasAppContext,
            let viewController: UIViewController = Singleton.appContext.frontmostViewController
        else { return }
        
        #if targetEnvironment(simulator)
        let modal: ConfirmationModal = ConfirmationModal(
            info: ConfirmationModal.Info(
                title: "Export Logs",      // stringlint:disable
                body: .text(
                    "How would you like to export the logs?\n\n(This modal only appears on the Simulator)" // stringlint:disable
                ),
                confirmTitle: "Copy Path", // stringlint:disable
                cancelTitle: "Share",      // stringlint:disable
                cancelStyle: .alert_text,
                onConfirm: { _ in UIPasteboard.general.string = latestLogFilePath },
                onCancel: { _ in
                    HelpViewModel.shareLogsInternal(
                        viewControllerToDismiss: viewControllerToDismiss,
                        targetView: targetView,
                        animated: animated,
                        onShareComplete: onShareComplete
                    )
                }
            )
        )
        viewController.present(modal, animated: animated, completion: nil)
        #else
        HelpViewModel.shareLogsInternal(
            viewControllerToDismiss: viewControllerToDismiss,
            targetView: targetView,
            animated: animated,
            onShareComplete: onShareComplete
        )
        #endif
    }
    
    private static func shareLogsInternal(
        viewControllerToDismiss: UIViewController? = nil,
        targetView: UIView? = nil,
        animated: Bool = true,
        onShareComplete: (() -> ())? = nil
    ) {
        Log.info("[Version] \(SessionApp.versionInfo)")
        Log.flush()
        
        guard
            let latestLogFilePath: String = Log.logFilePath(),
            Singleton.hasAppContext,
            let viewController: UIViewController = Singleton.appContext.frontmostViewController
        else { return }
        
        let showShareSheet: () -> () = {
            let shareVC = UIActivityViewController(
                activityItems: [ URL(fileURLWithPath: latestLogFilePath) ],
                applicationActivities: nil
            )
            shareVC.completionWithItemsHandler = { _, _, _, _ in onShareComplete?() }
            
            if UIDevice.current.isIPad {
                shareVC.excludedActivityTypes = []
                shareVC.popoverPresentationController?.permittedArrowDirections = (targetView != nil ? [.up] : [])
                shareVC.popoverPresentationController?.sourceView = (targetView ?? viewController.view)
                shareVC.popoverPresentationController?.sourceRect = (targetView ?? viewController.view).bounds
            }
            viewController.present(shareVC, animated: animated, completion: nil)
        }
        
        guard let viewControllerToDismiss: UIViewController = viewControllerToDismiss else {
            showShareSheet()
            return
        }

        viewControllerToDismiss.dismiss(animated: animated) {
            showShareSheet()
        }
    }
    
#if DEBUG
    private func exportDatabase(_ targetView: UIView?) {
        let generatedPassword: String = UUID().uuidString
        self.databaseKeyEncryptionPassword = generatedPassword
        
        self.transitionToScreen(
            ConfirmationModal(
                info: ConfirmationModal.Info(
                    title: "Export Database", // stringlint:disable
                    body: .input(
                        explanation: NSAttributedString(
                            string: """
                            Sharing the database and key together is dangerous!

                            We've generated a secure password for you but feel free to provide your own (we will show the generated password again after exporting)

                            This password will be used to encrypt the database decryption key and will be exported alongside the database
                            """
                        ),
                        placeholder: "Enter a password", // stringlint:disable
                        initialValue: generatedPassword,
                        clearButton: true,
                        onChange: { [weak self] value in self?.databaseKeyEncryptionPassword = value }
                    ),
                    confirmTitle: "Export", // stringlint:disable
                    dismissOnConfirm: false,
                    onConfirm: { [weak self] modal in
                        modal.dismiss(animated: true) {
                            guard let password: String = self?.databaseKeyEncryptionPassword, password.count >= 6 else {
                                self?.transitionToScreen(
                                    ConfirmationModal(
                                        info: ConfirmationModal.Info(
                                            title: "Error", // stringlint:disable
                                            body: .text("Password must be at least 6 characters") // stringlint:disable
                                        )
                                    ),
                                    transitionType: .present
                                )
                                return
                            }
                            
                            do {
                                let exportInfo = try Storage.shared.exportInfo(password: password)
                                let shareVC = UIActivityViewController(
                                    activityItems: [
                                        URL(fileURLWithPath: exportInfo.dbPath),
                                        URL(fileURLWithPath: exportInfo.keyPath)
                                    ],
                                    applicationActivities: nil
                                )
                                shareVC.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                                    guard
                                        completed &&
                                        generatedPassword == self?.databaseKeyEncryptionPassword
                                    else { return }
                                    
                                    self?.transitionToScreen(
                                        ConfirmationModal(
                                            info: ConfirmationModal.Info(
                                                title: "Password", // stringlint:disable
                                                body: .text("""
                                                The generated password was:
                                                \(generatedPassword)
                                                
                                                Avoid sending this via the same means as the database
                                                """),
                                                confirmTitle: "Share", // stringlint:disable
                                                dismissOnConfirm: false,
                                                onConfirm: { [weak self] modal in
                                                    modal.dismiss(animated: true) {
                                                        let passwordShareVC = UIActivityViewController(
                                                            activityItems: [generatedPassword],
                                                            applicationActivities: nil
                                                        )
                                                        if UIDevice.current.isIPad {
                                                            passwordShareVC.excludedActivityTypes = []
                                                            passwordShareVC.popoverPresentationController?.permittedArrowDirections = (targetView != nil ? [.up] : [])
                                                            passwordShareVC.popoverPresentationController?.sourceView = targetView
                                                            passwordShareVC.popoverPresentationController?.sourceRect = (targetView?.bounds ?? .zero)
                                                        }
                                                        
                                                        self?.transitionToScreen(passwordShareVC, transitionType: .present)
                                                    }
                                                }
                                            )
                                        ),
                                        transitionType: .present
                                    )
                                }
                                
                                if UIDevice.current.isIPad {
                                    shareVC.excludedActivityTypes = []
                                    shareVC.popoverPresentationController?.permittedArrowDirections = (targetView != nil ? [.up] : [])
                                    shareVC.popoverPresentationController?.sourceView = targetView
                                    shareVC.popoverPresentationController?.sourceRect = (targetView?.bounds ?? .zero)
                                }
                                
                                self?.transitionToScreen(shareVC, transitionType: .present)
                            }
                            catch {
                                let message: String = {
                                    switch error {
                                        case CryptoKitError.incorrectKeySize:
                                            return "The password must be between 6 and 32 characters (padded to 32 bytes)" // stringlint:disable
                                        
                                        default: return "Failed to export database" // stringlint:disable
                                    }
                                }()
                                
                                self?.transitionToScreen(
                                    ConfirmationModal(
                                        info: ConfirmationModal.Info(
                                            title: "Error", // stringlint:disable
                                            body: .text(message)
                                        )
                                    ),
                                    transitionType: .present
                                )
                            }
                        }
                    }
                )
            ),
            transitionType: .present
        )
    }
#endif
}
