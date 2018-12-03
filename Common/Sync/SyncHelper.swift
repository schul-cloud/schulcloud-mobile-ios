//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import BrightFutures
import CoreData
import Foundation
import SyncEngine

// swiftlint:disable line_length

fileprivate let localLog = Logger(subsystem: "org.schulcloud.common.SyncHelper", category: "Common.SyncHelper")

struct SyncHelper {

    private static let syncConfiguration = SchulcloudSyncConfig()
    private static let syncStrategy: SyncStrategy = MainSchulcloudSyncStrategy()
    static var authenticationChallengerHandler: (() -> Void)?

    private static func handleAuthentication(error: SCError) {
        guard case let .synchronization(.api(.response(statusCode: statusCode, headers: _))) = error, statusCode == 401 else { return }
        SyncHelper.authenticationChallengerHandler?()
    }

    static func syncResources<Resource>(withFetchRequest fetchRequest: NSFetchRequest<Resource>,
                                        withQuery query: MultipleResourcesQuery<Resource>,
                                        withConfiguration configuration: SyncConfig = SyncHelper.syncConfiguration,
                                        withStrategy strategy: SyncStrategy = SyncHelper.syncStrategy,
                                        deleteNotExistingResources: Bool = true) -> Future<SyncEngine.SyncMultipleResult, SCError> where Resource: NSManagedObject & Pullable {
        return SyncEngine.syncResources(withFetchRequest: fetchRequest,
                                        withQuery: query,
                                        withConfiguration: configuration,
                                        withStrategy: strategy,
                                        deleteNotExistingResources: deleteNotExistingResources).mapError { syncError -> SCError in
            return .synchronization(syncError)
        }.onSuccess { _ in
            localLog.info("Successfully merged resources of type: %@", Resource.type)
        }.onFailure { error in
            self.handleAuthentication(error: error)
            localLog.error("Failed to sync resources of type: %@ ===> %@", Resource.type, error.description)
        }
    }

    static func syncResource<Resource>(withFetchRequest fetchRequest: NSFetchRequest<Resource>,
                                       withQuery query: SingleResourceQuery<Resource>,
                                       withConfiguration configuration: SyncConfig = SyncHelper.syncConfiguration,
                                       withStrategy strategy: SyncStrategy = SyncHelper.syncStrategy) -> Future<SyncEngine.SyncSingleResult, SCError> where Resource: NSManagedObject & Pullable {
        return SyncEngine.syncResource(withFetchRequest: fetchRequest,
                                       withQuery: query,
                                       withConfiguration: configuration,
                                       withStrategy: strategy).mapError { syncError -> SCError in
            return .synchronization(syncError)
        }.onSuccess { _ in
            localLog.info("Successfully merged resource of type: %@", Resource.type)
        }.onFailure { error in
            self.handleAuthentication(error: error)
            localLog.error("Failed to sync resource of type: %@ ===> %@", Resource.type, error.description)
        }
    }

    @discardableResult static func createResource<Resource>(ofType resourceType: Resource.Type,
                                                            withData resourceData: Data,
                                                            withConfiguration configuration: SyncConfig = SyncHelper.syncConfiguration,
                                                            withStrategy strategy: SyncStrategy = SyncHelper.syncStrategy) -> Future<SyncEngine.SyncSingleResult, SCError> where Resource: NSManagedObject & Pullable & Pushable {
        return SyncEngine.createResource(ofType: resourceType,
                                         withData: resourceData,
                                         withConfiguration: configuration,
                                         withStrategy: strategy).mapError { syncError -> SCError in
            return .synchronization(syncError)
        }.onSuccess { _ in
            localLog.info("Successfully created resource of type: %@", Resource.type)
        }.onFailure { error in
            self.handleAuthentication(error: error)
            localLog.error("Failed to create resource of type: %@ ===> %@", Resource.type, error.description)
        }
    }

    @discardableResult static func createResource(_ resource: Pushable,
                                                  withConfiguration configuration: SyncConfig = SyncHelper.syncConfiguration,
                                                  withStrategy strategy: SyncStrategy = SyncHelper.syncStrategy) -> Future<Void, SCError> {
        return SyncEngine.createResource(resource,
                                         withConfiguration: configuration,
                                         withStrategy: strategy).mapError { syncError -> SCError in
            return .synchronization(syncError)
        }.onSuccess { _ in
            localLog.info("Successfully created resource of type: %@", type(of: resource).type)
        }.onFailure { error in
            self.handleAuthentication(error: error)
            localLog.error("Failed to create resource of type: %@ ===> %@", type(of: resource).type, error.description)
        }
    }

    @discardableResult static func saveResource(_ resource: Pullable & Pushable,
                                                withConfiguration configuration: SyncConfig = SyncHelper.syncConfiguration,
                                                withStrategy strategy: SyncStrategy = SyncHelper.syncStrategy) -> Future<Void, SCError> {
        return SyncEngine.saveResource(resource,
                                       withConfiguration: configuration,
                                       withStrategy: strategy).mapError { syncError -> SCError in
            return .synchronization(syncError)
        }.onSuccess { _ in
            localLog.info("Successfully saved resource of type: %@", type(of: resource).type)
        }.onFailure { error in
            self.handleAuthentication(error: error)
            localLog.error("Failed to save resource of type: %@ ===> %@", type(of: resource).type, error.description)
        }
    }

    @discardableResult static func deleteResource(_ resource: Pushable & Pullable,
                                                  withConfiguration configuration: SyncConfig = SyncHelper.syncConfiguration,
                                                  withStrategy strategy: SyncStrategy = SyncHelper.syncStrategy) -> Future<Void, SCError> {
        return SyncEngine.deleteResource(resource,
                                         withConfiguration: configuration,
                                         withStrategy: strategy).mapError { syncError -> SCError in
            return .synchronization(syncError)
        }.onSuccess { _ in
            localLog.info("Successfully deleted resource of type: %@", type(of: resource).type)
        }.onFailure { error in
            self.handleAuthentication(error: error)
            localLog.error("Failed to delete resource of type: %@ ===> %@", type(of: resource).type, error.description)
        }
    }

}
