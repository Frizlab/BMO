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
	
	@discardableResult
	func update<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		objectID: NSManagedObjectID,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		discardableUpdates: @escaping @Sendable (_ object: Object, _ managedObjectContext: NSManagedObjectContext) throws -> Void,
		handler: @escaping @Sendable @MainActor (_ results: Result<Bridge.RequestResults, RequestError<Bridge>>) -> Void = { _ in }
	) throws -> RequestOperation<Bridge> {
		let settings = settings ?? defaultSettings
		let requestUserInfo = requestUserInfo ?? defaultRequestUserInfo
		
		let discardableContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		discardableContext.parent = localDb.context
		
		return try discardableContext.performAndWaitRW{
			guard let discardableObject = try discardableContext.existingObject(with: objectID) as? Object else {
				throw Err.invalidObjectType
			}
			try discardableUpdates(discardableObject, discardableContext)
			
			let bridgeRequest = settings.updateObjectBridgeRequest(discardableObject, .doNothingChangeImportContext(localDb.context))
			let opRequest = Request(localDb: localDb, localDbContextOverwrite: discardableContext, localRequest: bridgeRequest, remoteUserInfo: requestUserInfo)
			let op = RequestOperation(bridge: bridge, request: opRequest, remoteOperationQueue: settings.remoteOperationQueue, computeOperationQueue: settings.computeOperationQueue, startedOnContext: autoStart)
			op.completionBlock = { /* We keep a strong ref to op but it’s not a problem because we nullify the completion block at the end of the block. */
				DispatchQueue.main.async{
					handler(op.result)
				}
				op.completionBlock = nil /* In theory not needed anymore; I never tested that… */
			}
			if autoStart {
				op.start() /* RequestOperations usually do not need to be queued at all: they mostly queue other info and don’t do much on their own. */
			}
			return op
		}
	}
	
	@discardableResult
	@available(macOS 10.15, tvOS 13, iOS 13, watchOS 6, *)
	func update<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		objectID: NSManagedObjectID,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		discardableUpdates: @escaping @Sendable (_ object: Object, _ managedObjectContext: NSManagedObjectContext) throws -> Void
	) async throws -> Bridge.RequestResults {
		return try await withCheckedThrowingContinuation{ continuation in
			do {
				try update(
					objectType, objectID: objectID,
					requestUserInfo: requestUserInfo,
					settings: settings, autoStart: true,
					discardableUpdates: discardableUpdates,
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
