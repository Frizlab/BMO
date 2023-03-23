/*
Copyright 2023 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import CoreData
import Foundation

import BMO



public extension CoreDataAPI {
	
	/* Maybe TODO: Instead of returning a Result with a generic Error, return the properly typed bridge Result and the Core Data deletion operation error. This should also be done for the “create and get” function. */
	@discardableResult
	func delete(
		objectID: NSManagedObjectID,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		handler: @escaping @Sendable @MainActor (_ results: Result<Bridge.RequestResults, Error>) -> Void = { _ in }
	) throws -> RequestOperation<Bridge> {
		let settings = settings ?? defaultSettings
		let requestUserInfo = requestUserInfo ?? defaultRequestUserInfo
		
		let object = try localDb.context.existingObject(with: objectID)
		/* We do not need a temporary context like for update or create operation as we do not modify the context to send the request.
		 * So we use the saveBeforeGoingRemote save workflow (nothing will be saved as there should be no modifications in the context). */
		let bridgeRequest = settings.deleteObjectBridgeRequest(object, .saveBeforeGoingRemote)
		let opRequest = Request(localDb: localDb, localRequest: bridgeRequest, remoteUserInfo: requestUserInfo)
		let op = RequestOperation(bridge: bridge, request: opRequest, remoteOperationQueue: settings.remoteOperationQueue, computeOperationQueue: settings.computeOperationQueue, startedOnContext: true)
		op.completionBlock = { /* We keep a strong ref to op but it’s not a problem because we nullify the completion block at the end of the block. */
			DispatchQueue.main.async{
				let result = op.result
				if case .success = result {
					/* If the request succeeded, we try and remove the Core Data object. */
					localDb.context.perform{
						localDb.context.delete(object)
						if let error = localDb.context.saveOrRollback() {
							handler(.failure(error))
						} else {
							handler(result.mapError{ $0 as Error })
						}
					}
				} else {
					handler(result.mapError{ $0 as Error })
				}
			}
			op.completionBlock = nil /* In theory not needed anymore; I never tested that… */
		}
		if autoStart {
			op.start() /* RequestOperations usually do not need to be queued at all: they mostly queue other info and don’t do much on their own. */
		}
		return op
	}
	
	@discardableResult
	@available(macOS 10.15, tvOS 13, iOS 13, watchOS 6, *)
	func delete(
		objectID: NSManagedObjectID,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil
	) async throws -> Bridge.RequestResults {
		return try await withCheckedThrowingContinuation{ continuation in
			do {
				try delete(
					objectID: objectID,
					requestUserInfo: requestUserInfo,
					settings: settings, autoStart: true,
					handler: { res in
						continuation.resume(with: res.mapError{ $0 as Error })
					}
				)
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
	
}
