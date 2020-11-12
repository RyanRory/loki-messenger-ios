//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalUtilitiesKit
import SignalUtilitiesKit

@objc(OWSWebRTCCallMessageHandler)
public class WebRTCCallMessageHandler: NSObject/*, OWSCallMessageHandler*/ {

    // MARK: Initializers

    @objc
    public override init()
    {
        super.init()

        SwiftSingletons.register(self)
    }

    // MARK: - Dependencies

    private var messageSender : MessageSender
    {
        return SSKEnvironment.shared.messageSender
    }

    private var accountManager : AccountManager
    {
        return AppEnvironment.shared.accountManager
    }

//    private var callService : CallService
//    {
//        return AppEnvironment.shared.callService
//    }

    // MARK: - Call Handlers

//    public func receivedOffer(_ offer: SSKProtoCallMessageOffer, from callerId: String) {
//        AssertIsOnMainThread()
//
//        let thread = TSContactThread.getOrCreateThread(contactId: callerId)
//        self.callService.handleReceivedOffer(thread: thread, callId: offer.id, sessionDescription: offer.sessionDescription)
//    }
//
//    public func receivedAnswer(_ answer: SSKProtoCallMessageAnswer, from callerId: String) {
//        AssertIsOnMainThread()
//
//        let thread = TSContactThread.getOrCreateThread(contactId: callerId)
//        self.callService.handleReceivedAnswer(thread: thread, callId: answer.id, sessionDescription: answer.sessionDescription)
//    }
//
//    public func receivedIceUpdate(_ iceUpdate: SSKProtoCallMessageIceUpdate, from callerId: String) {
//        AssertIsOnMainThread()
//
//        let thread = TSContactThread.getOrCreateThread(contactId: callerId)
//
//        // Discrepency between our protobuf's sdpMlineIndex, which is unsigned,
//        // while the RTC iOS API requires a signed int.
//        let lineIndex = Int32(iceUpdate.sdpMlineIndex)
//
//        self.callService.handleRemoteAddedIceCandidate(thread: thread, callId: iceUpdate.id, sdp: iceUpdate.sdp, lineIndex: lineIndex, mid: iceUpdate.sdpMid)
//    }
//
//    public func receivedHangup(_ hangup: SSKProtoCallMessageHangup, from callerId: String) {
//        AssertIsOnMainThread()
//
//        let thread = TSContactThread.getOrCreateThread(contactId: callerId)
//        self.callService.handleRemoteHangup(thread: thread, callId: hangup.id)
//    }
//
//    public func receivedBusy(_ busy: SSKProtoCallMessageBusy, from callerId: String) {
//        AssertIsOnMainThread()
//
//        let thread = TSContactThread.getOrCreateThread(contactId: callerId)
//        self.callService.handleRemoteBusy(thread: thread, callId: busy.id)
//    }

}