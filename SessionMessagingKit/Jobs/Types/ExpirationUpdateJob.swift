// Copyright © 2023 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import Combine
import GRDB
import SessionUtilitiesKit
import SessionSnodeKit

public enum ExpirationUpdateJob: JobExecutor {
    public static var maxFailureCount: Int = -1
    public static var requiresThreadId: Bool = false
    public static var requiresInteractionId: Bool = false
    
    public static func run(
        _ job: SessionUtilitiesKit.Job,
        queue: DispatchQueue,
        success: @escaping (SessionUtilitiesKit.Job, Bool) -> (),
        failure: @escaping (SessionUtilitiesKit.Job, Error?, Bool) -> (),
        deferred: @escaping (SessionUtilitiesKit.Job) -> ()
    ) {
        guard
            let detailsData: Data = job.details,
            let details: Details = try? JSONDecoder().decode(Details.self, from: detailsData)
        else {
            SNLog("[ExpirationUpdateJob] Failing due to missing details")
            failure(job, JobRunnerError.missingRequiredDetails, true)
            return
        }
        
        let userPublicKey: String = getUserHexEncodedPublicKey()
        SnodeAPI
            .updateExpiry(
                publicKey: userPublicKey,
                serverHashes: details.serverHashes,
                updatedExpiryMs: details.expirationTimestampMs,
                shortenOnly: true
            )
            .subscribe(on: queue)
            .receive(on: queue)
            .map { response -> [UInt64: [String]] in
                guard
                    let results: [UpdateExpiryResponseResult] = response
                        .compactMap({ _, value in value.didError ? nil : value })
                        .nullIfEmpty(),
                    let unchangedMessages: [UInt64: [String]] = results
                        .reduce([:], { result, next in result.updated(with: next.unchanged) })
                        .groupedByValue()
                        .nullIfEmpty()
                else {
                    return [:]
                }
                
                return unchangedMessages
            }
            .sinkUntilComplete(
                receiveCompletion: { result in
                    switch result {
                        case .finished:
                            success(job, false)
                        case .failure(let error):
                            failure(job, error, true)
                    }
                },
                receiveValue: { unchangedMessages in
                    guard !unchangedMessages.isEmpty else { return }
                    Storage.shared.writeAsync { db in
                        try unchangedMessages.forEach { updatedExpiry, hashes in
                            try hashes.forEach { hash in
                                guard
                                    let expiresInSeconds: TimeInterval = try? Interaction
                                        .filter(Interaction.Columns.serverHash == hash)
                                        .select(Interaction.Columns.expiresInSeconds)
                                        .asRequest(of: TimeInterval.self)
                                        .fetchOne(db)
                                else {
                                    return
                                }
                                
                                let expiresStartedAtMs: TimeInterval = TimeInterval(updatedExpiry - UInt64(expiresInSeconds * 1000))
                                
                                _ = try Interaction
                                    .filter(Interaction.Columns.serverHash == hash)
                                    .updateAll(
                                        db,
                                        Interaction.Columns.expiresStartedAtMs.set(to: expiresStartedAtMs)
                                    )
                            }
                        }
                    }
                }
            )
    }
}

// MARK: - ExpirationUpdateJob.Details

extension ExpirationUpdateJob {
    public struct Details: Codable {
        private enum CodingKeys: String, CodingKey {
            case serverHashes
            case expirationTimestampMs
        }
        
        public let serverHashes: [String]
        public let expirationTimestampMs: Int64
        
        // MARK: - Initialization
        
        public init(
            serverHashes: [String],
            expirationTimestampMs: Int64
        ) {
            self.serverHashes = serverHashes
            self.expirationTimestampMs = expirationTimestampMs
        }
        
        // MARK: - Codable
        
        public init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            
            self = Details(
                serverHashes: try container.decode([String].self, forKey: .serverHashes),
                expirationTimestampMs: try container.decode(Int64.self, forKey: .expirationTimestampMs)
            )
        }
        
        public func encode(to encoder: Encoder) throws {
            var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(serverHashes, forKey: .serverHashes)
            try container.encode(expirationTimestampMs, forKey: .expirationTimestampMs)
        }
    }
}

