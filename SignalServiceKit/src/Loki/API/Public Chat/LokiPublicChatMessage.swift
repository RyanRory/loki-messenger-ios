import PromiseKit

@objc(LKGroupMessage)
public final class LokiPublicChatMessage : NSObject {
    public let serverID: UInt64?
    public let hexEncodedPublicKey: String
    public let displayName: String
    public let body: String
    /// - Note: Expressed as milliseconds since 00:00:00 UTC on 1 January 1970.
    public let timestamp: UInt64
    public let type: String
    public let quote: Quote?
    public var attachments: [Attachment] = []
    public let signature: Signature?
    
    @objc(serverID)
    public var objc_serverID: UInt64 { return serverID ?? 0 }
    
    // MARK: Settings
    private let signatureVersion: UInt64 = 1
    private let attachmentType = "net.app.core.oembed"
    
    // MARK: Types
    public struct Quote {
        public let quotedMessageTimestamp: UInt64
        public let quoteeHexEncodedPublicKey: String
        public let quotedMessageBody: String
        public let quotedMessageServerID: UInt64?
    }
    
    public struct Attachment {
        public let kind: Kind
        public let width: UInt
        public let height: UInt
        public let caption: String
        public let url: String
        public let server: String
        public let serverDisplayName: String
        
        public enum Kind : String { case photo, video }
    }
    
    public struct Signature {
        public let data: Data
        public let version: UInt64
    }
    
    // MARK: Initialization
    public init(serverID: UInt64?, hexEncodedPublicKey: String, displayName: String, body: String, type: String, timestamp: UInt64, quote: Quote?, signature: Signature?) {
        self.serverID = serverID
        self.hexEncodedPublicKey = hexEncodedPublicKey
        self.displayName = displayName
        self.body = body
        self.type = type
        self.timestamp = timestamp
        self.quote = quote
        self.signature = signature
        super.init()
    }
    
    @objc public convenience init(hexEncodedPublicKey: String, displayName: String, body: String, type: String, timestamp: UInt64, quotedMessageTimestamp: UInt64, quoteeHexEncodedPublicKey: String?, quotedMessageBody: String?, quotedMessageServerID: UInt64, signatureData: Data?, signatureVersion: UInt64) {
        let quote: Quote?
        if quotedMessageTimestamp != 0, let quoteeHexEncodedPublicKey = quoteeHexEncodedPublicKey, let quotedMessageBody = quotedMessageBody {
            let quotedMessageServerID = (quotedMessageServerID != 0) ? quotedMessageServerID : nil
            quote = Quote(quotedMessageTimestamp: quotedMessageTimestamp, quoteeHexEncodedPublicKey: quoteeHexEncodedPublicKey, quotedMessageBody: quotedMessageBody, quotedMessageServerID: quotedMessageServerID)
        } else {
            quote = nil
        }
        let signature: Signature?
        if let signatureData = signatureData, signatureVersion != 0 {
            signature = Signature(data: signatureData, version: signatureVersion)
        } else {
            signature = nil
        }
        self.init(serverID: nil, hexEncodedPublicKey: hexEncodedPublicKey, displayName: displayName, body: body, type: type, timestamp: timestamp, quote: quote, signature: signature)
    }
    
    // MARK: Crypto
    internal func sign(with privateKey: Data) -> LokiPublicChatMessage? {
        guard let data = getValidationData(for: signatureVersion) else {
            print("[Loki] Failed to sign public chat message.")
            return nil
        }
        let userKeyPair = OWSIdentityManager.shared().identityKeyPair()!
        guard let signatureData = try? Ed25519.sign(data, with: userKeyPair) else {
            print("[Loki] Failed to sign public chat message.")
            return nil
        }
        let signature = Signature(data: signatureData, version: signatureVersion)
        return LokiPublicChatMessage(serverID: serverID, hexEncodedPublicKey: hexEncodedPublicKey, displayName: displayName, body: body, type: type, timestamp: timestamp, quote: quote, signature: signature)
    }
    
    internal func hasValidSignature() -> Bool {
        guard let signature = signature else { return false }
        guard let data = getValidationData(for: signature.version) else { return false }
        let publicKey = Data(hex: hexEncodedPublicKey.removing05PrefixIfNeeded())
        return (try? Ed25519.verifySignature(signature.data, publicKey: publicKey, data: data)) ?? false
    }
    
    // MARK: JSON
    internal func toJSON() -> JSON {
        var value: JSON = [ "timestamp" : timestamp ]
        if let quote = quote {
            value["quote"] = [ "id" : quote.quotedMessageTimestamp, "author" : quote.quoteeHexEncodedPublicKey, "text" : quote.quotedMessageBody ]
        }
        if let signature = signature {
            value["sig"] = signature.data.toHexString()
            value["sigver"] = signature.version
        }
        let annotation: JSON = [ "type" : type, "value" : value ]
        let attachmentAnnotations: [JSON] = self.attachments.map { attachment in
            let attachmentValue: JSON = [ "version" : 1, "type" : attachment.kind.rawValue, "width" : attachment.width, "height" : attachment.height,
                "title" : attachment.caption, "url" : attachment.url, "provider_name" : attachment.serverDisplayName, "provider_url" : attachment.server ]
            return [ "type" : attachmentType, "value" : attachmentValue ]
        }
        var result: JSON = [ "text" : body, "annotations": [ annotation ] + attachmentAnnotations ]
        if let quotedMessageServerID = quote?.quotedMessageServerID {
            result["reply_to"] = quotedMessageServerID
        }
        return result
    }
    
    // MARK: Convenience
    @objc public func addAttachment(kind: String, width: UInt, height: UInt, caption: String, url: String, server: String, serverDisplayName: String) {
        guard let kind = Attachment.Kind(rawValue: kind) else { preconditionFailure() }
        let attachment = Attachment(kind: kind, width: width, height: height, caption: caption, url: url, server: server, serverDisplayName: serverDisplayName)
        attachments.append(attachment)
    }
    
    private func getValidationData(for signatureVersion: UInt64) -> Data? {
        var string = "\(body.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))\(timestamp)"
        if let quote = quote {
            string += "\(quote.quotedMessageTimestamp)\(quote.quoteeHexEncodedPublicKey)\(quote.quotedMessageBody.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))"
            if let quotedMessageServerID = quote.quotedMessageServerID {
                string += "\(quotedMessageServerID)"
            }
        }
        string += "\(signatureVersion)"
        return string.data(using: String.Encoding.utf8)
    }
}
