// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import SessionUIKit
import SessionSnodeKit
import SessionMessagingKit
import SessionUtilitiesKit

public enum Configuration {
    public static func performMainSetup() {
        // Need to do this first to ensure the legacy database exists
        SNUtilitiesKit.configure(networkMaxFileSize: UInt(Network.maxFileSize))
        SNMessagingKit.configure()
        SNUIKit.configure()
        
    }
}
