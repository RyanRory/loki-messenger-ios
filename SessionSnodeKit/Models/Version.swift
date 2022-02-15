// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation

extension OnionRequestAPI {
    public enum Version: String, Codable {
        case v2 = "/loki/v2/lsrpc"
        case v3 = "/loki/v3/lsrpc"
        case v4 = "/oxen/v4/lsrpc"
    }
}
