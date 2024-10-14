// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import CallKit
import GRDB
import WebRTC
import SessionUIKit
import SessionMessagingKit
import SignalUtilitiesKit
import SessionUtilitiesKit

public final class SessionCallManager: NSObject, CallManagerProtocol {
    let provider: CXProvider?
    let callController: CXCallController?
    
    public var currentCall: CurrentCallProtocol? = nil {
        willSet {
            if (newValue != nil) {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            } else {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }
    
    private static var _sharedProvider: CXProvider?
    static func sharedProvider(useSystemCallLog: Bool) -> CXProvider {
        let configuration = buildProviderConfiguration(useSystemCallLog: useSystemCallLog)

        if let sharedProvider = self._sharedProvider {
            sharedProvider.configuration = configuration
            return sharedProvider
        }
        else {
            SwiftSingletons.register(self)
            let provider = CXProvider(configuration: configuration)
            _sharedProvider = provider
            return provider
        }
    }
    
    static func buildProviderConfiguration(useSystemCallLog: Bool) -> CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: "Session") // stringlint:disable
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        let iconMaskImage = #imageLiteral(resourceName: "SessionGreen32")
        providerConfiguration.iconTemplateImageData = iconMaskImage.pngData()
        providerConfiguration.includesCallsInRecents = useSystemCallLog

        return providerConfiguration
    }
    
    // MARK: - Initialization
    
    init(useSystemCallLog: Bool = false) {
        if Preferences.isCallKitSupported {
            self.provider = SessionCallManager.sharedProvider(useSystemCallLog: useSystemCallLog)
            self.callController = CXCallController()
        }
        else {
            self.provider = nil
            self.callController = nil
        }
        
        super.init()
        
        // We cannot assert singleton here, because this class gets rebuilt when the user changes relevant call settings
        self.provider?.setDelegate(self, queue: nil)
    }
    
    // MARK: - Report calls
    
    public static func reportFakeCall(info: String) {
        let callId = UUID()
        let provider = SessionCallManager.sharedProvider(useSystemCallLog: false)
        provider.reportNewIncomingCall(
            with: callId,
            update: CXCallUpdate()
        ) { _ in
            SNLog("[Calls] Reported fake incoming call to CallKit due to: \(info)")
        }
        provider.reportCall(
            with: callId,
            endedAt: nil,
            reason: .failed
        )
    }
    
    public func reportOutgoingCall(_ call: SessionCall) {
        Log.assertOnMainThread()
        UserDefaults.sharedLokiProject?[.isCallOngoing] = true
        UserDefaults.sharedLokiProject?[.lastCallPreOffer] = Date()
        
        call.stateDidChange = {
            if call.hasStartedConnecting {
                self.provider?.reportOutgoingCall(with: call.callId, startedConnectingAt: call.connectingDate)
            }
            
            if call.hasConnected {
                self.provider?.reportOutgoingCall(with: call.callId, connectedAt: call.connectedDate)
            }
        }
    }
    
    public func reportIncomingCall(_ call: SessionCall, callerName: String, completion: @escaping (Error?) -> Void) {
        let provider = provider ?? Self.sharedProvider(useSystemCallLog: false)
        // Construct a CXCallUpdate describing the incoming call, including the caller.
        let update = CXCallUpdate()
        update.localizedCallerName = callerName
        update.remoteHandle = CXHandle(type: .generic, value: call.callId.uuidString)
        update.hasVideo = false

        disableUnsupportedFeatures(callUpdate: update)

        // Report the incoming call to the system
        provider.reportNewIncomingCall(with: call.callId, update: update) { error in
            guard error == nil else {
                self.reportCurrentCallEnded(reason: .failed)
                completion(error)
                return
            }
            UserDefaults.sharedLokiProject?[.isCallOngoing] = true
            UserDefaults.sharedLokiProject?[.lastCallPreOffer] = Date()
            completion(nil)
        }
    }
    
    public func reportCurrentCallEnded(reason: CXCallEndedReason?) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.reportCurrentCallEnded(reason: reason)
            }
            return
        }
        
        func handleCallEnded() {
            WebRTCSession.current = nil
            UserDefaults.sharedLokiProject?[.isCallOngoing] = false
            UserDefaults.sharedLokiProject?[.lastCallPreOffer] = nil
            
            if Singleton.hasAppContext && Singleton.appContext.isInBackground {
                (UIApplication.shared.delegate as? AppDelegate)?.stopPollers()
                Log.flush()
            }
        }
        
        guard let call = currentCall else {
            handleCallEnded()
            Self.suspendDatabaseIfCallEndedInBackground()
            return
        }
        
        if let reason = reason {
            self.provider?.reportCall(with: call.callId, endedAt: nil, reason: reason)
            
            switch (reason) {
                case .answeredElsewhere: call.updateCallMessage(mode: .answeredElsewhere)
                case .unanswered: call.updateCallMessage(mode: .unanswered)
                case .declinedElsewhere: call.updateCallMessage(mode: .local)
                default: call.updateCallMessage(mode: .remote)
            }
        }
        else {
            call.updateCallMessage(mode: .local)
        }
        
        (call as? SessionCall)?.webRTCSession.dropConnection()
        self.currentCall = nil
        handleCallEnded()
    }
    
    public func currentWebRTCSessionMatches(callId: String) -> Bool {
        return (
            WebRTCSession.current != nil &&
            WebRTCSession.current?.uuid == callId
        )
    }
    
    // MARK: - Util
    
    private func disableUnsupportedFeatures(callUpdate: CXCallUpdate) {
        // Call Holding is failing to restart audio when "swapping" calls on the CallKit screen
        // until user returns to in-app call screen.
        callUpdate.supportsHolding = false

        // Not yet supported
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false

        // Is there any reason to support this?
        callUpdate.supportsDTMF = false
    }
    
    public static func suspendDatabaseIfCallEndedInBackground() {
        if Singleton.hasAppContext && Singleton.appContext.isInBackground {
            // FIXME: Initialise the `SessionCallManager` with a dependencies instance
            let dependencies: Dependencies = Dependencies()
            
            // Stop all jobs except for message sending and when completed suspend the database
            JobRunner.stopAndClearPendingJobs(exceptForVariant: .messageSend, using: dependencies) { _ in
                LibSession.suspendNetworkAccess()
                dependencies.storage.suspendDatabaseAccess()
                Log.flush()
            }
        }
    }
    
    // MARK: - UI
    
    public func showCallUIForCall(caller: String, uuid: String, mode: CallMode, interactionId: Int64?) {
        guard let call: SessionCall = Storage.shared.read({ db in SessionCall(db, for: caller, uuid: uuid, mode: mode) }) else {
            return
        }
        
        call.callInteractionId = interactionId
        call.reportIncomingCallIfNeeded { error in
            if let error = error {
                SNLog("[Calls] Failed to report incoming call to CallKit due to error: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                guard Singleton.hasAppContext && Singleton.appContext.isMainAppAndActive else { return }
                
                guard let presentingVC = Singleton.appContext.frontmostViewController else {
                    preconditionFailure()   // FIXME: Handle more gracefully
                }
                
                if
                    let conversationVC: ConversationVC = (presentingVC as? TopBannerController)?.wrappedViewController() as? ConversationVC,
                    conversationVC.viewModel.threadData.threadId == call.sessionId
                {
                    let callVC = CallVC(for: call)
                    callVC.conversationVC = conversationVC
                    conversationVC.inputAccessoryView?.isHidden = true
                    conversationVC.inputAccessoryView?.alpha = 0
                    presentingVC.present(callVC, animated: true, completion: nil)
                }
                else if !Preferences.isCallKitSupported {
                    let incomingCallBanner = IncomingCallBanner(for: call)
                    incomingCallBanner.show()
                }
            }
        }
    }
    
    public func handleICECandidates(message: CallMessage, sdpMLineIndexes: [UInt32], sdpMids: [String]) {
        guard
            let currentWebRTCSession = WebRTCSession.current,
            currentWebRTCSession.uuid == message.uuid
        else { return }
        
        var candidates: [RTCIceCandidate] = []
        let sdps = message.sdps
        for i in 0..<sdps.count {
            let sdp = sdps[i]
            let sdpMLineIndex = sdpMLineIndexes[i]
            let sdpMid = sdpMids[i]
            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: Int32(sdpMLineIndex), sdpMid: sdpMid)
            candidates.append(candidate)
        }
        currentWebRTCSession.handleICECandidates(candidates)
    }
    
    public func handleAnswerMessage(_ message: CallMessage) {
        guard Singleton.hasAppContext else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.handleAnswerMessage(message)
            }
            return
        }
        
        (Singleton.appContext.frontmostViewController as? CallVC)?.handleAnswerMessage(message)
    }
    
    public func dismissAllCallUI() {
        guard Singleton.hasAppContext else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.dismissAllCallUI()
            }
            return
        }
        
        IncomingCallBanner.current?.dismiss()
        (Singleton.appContext.frontmostViewController as? CallVC)?.handleEndCallMessage()
        MiniCallView.current?.dismiss()
    }
}

