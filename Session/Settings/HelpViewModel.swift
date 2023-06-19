// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import CryptoKit
import GRDB
import DifferenceKit
import SessionUIKit
import SessionMessagingKit
import SessionUtilitiesKit
import SignalCoreKit

class HelpViewModel: SessionTableViewModel<NoNav, HelpViewModel.Section, HelpViewModel.Section> {
#if DEBUG
    private var databaseKeyEncryptionPassword: String = ""
#endif
    
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
    
    override var title: String { "HELP_TITLE".localized() }
    
    public override var observableTableData: ObservableData { _observableTableData }
    
    /// This is all the data the screen needs to populate itself, please see the following link for tips to help optimise
    /// performance https://github.com/groue/GRDB.swift#valueobservation-performance
    ///
    /// **Note:** This observation will be triggered twice immediately (and be de-duped by the `removeDuplicates`)
    /// this is due to the behaviour of `ValueConcurrentObserver.asyncStartObservation` which triggers it's own
    /// fetch (after the ones in `ValueConcurrentObserver.asyncStart`/`ValueConcurrentObserver.syncStart`)
    /// just in case the database has changed between the two reads - unfortunately it doesn't look like there is a way to prevent this
    private lazy var _observableTableData: ObservableData = ValueObservation
        .trackingConstantRegion { db -> [SectionModel] in
            return [
                SectionModel(
                    model: .report,
                    elements: [
                        SessionCell.Info(
                            id: .report,
                            title: "HELP_REPORT_BUG_TITLE".localized(),
                            subtitle: "HELP_REPORT_BUG_DESCRIPTION".localized(),
                            rightAccessory: .highlightingBackgroundLabel(
                                title: "HELP_REPORT_BUG_ACTION_TITLE".localized()
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
                            title: "HELP_TRANSLATE_TITLE".localized(),
                            rightAccessory: .icon(
                                UIImage(systemName: "arrow.up.forward.app")?
                                    .withRenderingMode(.alwaysTemplate),
                                size: .small
                            ),
                            onTap: {
                                guard let url: URL = URL(string: "https://crowdin.com/project/session-ios") else {
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
                            title: "HELP_FEEDBACK_TITLE".localized(),
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
                            title: "HELP_FAQ_TITLE".localized(),
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
                            title: "HELP_SUPPORT_TITLE".localized(),
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
                )
            ]
#if DEBUG
            .appending(
                SectionModel(
                    model: .exportDatabase,
                    elements: [
                        SessionCell.Info(
                            id: .support,
                            title: "Export Database",
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
            )
#endif
        }
        .removeDuplicates()
        .publisher(in: Storage.shared)
        .mapToSessionTableViewData(for: self)
    
    // MARK: - Functions
    
    public static func shareLogs(
        viewControllerToDismiss: UIViewController? = nil,
        targetView: UIView? = nil,
        onShareComplete: (() -> ())? = nil
    ) {
        let version: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            .defaulting(to: "")
        #if DEBUG
        let commitInfo: String? = (Bundle.main.infoDictionary?["GitCommitHash"] as? String).map { "Commit: \($0)" }
        #else
        let commitInfo: String? = nil
        #endif
        
        let versionInfo: [String] = [
            "iOS \(UIDevice.current.systemVersion)",
            "App: \(version)",
            "libSession: \(SessionUtil.libSessionVersion)",
            commitInfo
        ].compactMap { $0 }
        OWSLogger.info("[Version] \(versionInfo.joined(separator: ", "))")
        DDLog.flushLog()
        
        let logFilePaths: [String] = AppEnvironment.shared.fileLogger.logFileManager.sortedLogFilePaths
        
        guard
            let latestLogFilePath: String = logFilePaths.first,
            let viewController: UIViewController = CurrentAppContext().frontmostViewController()
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
            viewController.present(shareVC, animated: true, completion: nil)
        }
        
        guard let viewControllerToDismiss: UIViewController = viewControllerToDismiss else {
            showShareSheet()
            return
        }

        viewControllerToDismiss.dismiss(animated: true) {
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
                    title: "Export Database",
                    body: .input(
                        explanation: NSAttributedString(
                            string: """
                            Sharing the database and key together is dangerous!

                            We've generated a secure password for you but feel free to provide your own (we will show the generated password again after exporting)

                            This password will be used to encrypt the database decryption key and will be exported alongside the database
                            """
                        ),
                        placeholder: "Enter a password",
                        initialValue: generatedPassword,
                        clearButton: true,
                        onChange: { [weak self] value in self?.databaseKeyEncryptionPassword = value }
                    ),
                    confirmTitle: "Export",
                    dismissOnConfirm: false,
                    onConfirm: { [weak self] modal in
                        modal.dismiss(animated: true) {
                            guard let password: String = self?.databaseKeyEncryptionPassword, password.count >= 6 else {
                                self?.transitionToScreen(
                                    ConfirmationModal(
                                        info: ConfirmationModal.Info(
                                            title: "Error",
                                            body: .text("Password must be at least 6 characters")
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
                                                title: "Password",
                                                body: .text("""
                                                The generated password was:
                                                \(generatedPassword)
                                                
                                                Avoid sending this via the same means as the database
                                                """),
                                                confirmTitle: "Share",
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
                                            return "The password must be between 6 and 32 characters (padded to 32 bytes)"
                                        
                                        default: return "Failed to export database"
                                    }
                                }()
                                
                                self?.transitionToScreen(
                                    ConfirmationModal(
                                        info: ConfirmationModal.Info(
                                            title: "Error",
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
