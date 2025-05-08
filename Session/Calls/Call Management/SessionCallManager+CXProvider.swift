// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import AVFAudio
import CallKit
import SessionUtilitiesKit

extension SessionCallManager: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        Log.assertOnMainThread()
        Log.info(.calls, "CXProvider did reset")
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Log.assertOnMainThread()
        if startCallAction() {
            action.fulfill()
        }
        else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Log.assertOnMainThread()
        Log.info(.calls, "Perform CXAnswerCallAction")
        
        guard let call: SessionCall = (self.currentCall as? SessionCall) else {
            Log.warn("[CallKit] No session call")
            return action.fail()
        }
        
        call.answerCallAction = action
        
        if dependencies[singleton: .appContext].isMainAppAndActive {
            self.answerCallAction()
        }
        else {
            call.answerSessionCallInBackground()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Log.info(.calls, "Perform CXEndCallAction")
        Log.assertOnMainThread()
        
        if endCallAction() {
            action.fulfill()
        }
        else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Log.info(.calls, "Perform CXSetMutedCallAction, isMuted: \(action.isMuted)")
        Log.assertOnMainThread()
        
        if setMutedCallAction(isMuted: action.isMuted) {
            action.fulfill()
        }
        else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        Log.info(.calls, "Shouldn't happen: Perform CXSetHeldCallAction.")
    }
    
    public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        Log.info(.calls, "Timed out performing action.")
    }
    
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Log.info(.calls, "Audio session did activate.")
        Log.assertOnMainThread()
        guard let call: SessionCall = (self.currentCall as? SessionCall) else { return }
        
        call.webRTCSession.audioSessionDidActivate(audioSession)
        if call.mode == .offer && !call.hasConnected { CallRingTonePlayer.shared.startPlayingRingTone() }
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Log.info(.calls, "Audio session did deactivate.")
        Log.assertOnMainThread()
        guard let call: SessionCall = (self.currentCall as? SessionCall) else { return }
        
        call.webRTCSession.audioSessionDidDeactivate(audioSession)
    }
}

