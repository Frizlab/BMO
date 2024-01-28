import CoreData
import Foundation

import BMO



public extension CoreDataAPI {
	
	@discardableResult
	func createSaved<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		savedObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object,
		handler: @escaping @Sendable @MainActor (Result<Bridge.RequestResults, RequestError<Bridge>>) -> Void = { _ in }
	) throws -> RequestOperation<Bridge> {
		let settings = settings ?? defaultSettings
		let requestUserInfo = requestUserInfo ?? defaultRequestUserInfo
		
		return try localDb.context.performAndWaitRW{
			let object = try savedObjectCreator(localDb.context)
			
			let bridgeRequest = settings.createObjectBridgeRequest(object, .saveBeforeGoingRemote)
			let opRequest = Request(localDb: localDb, localRequest: bridgeRequest, remoteUserInfo: requestUserInfo)
			let op = RequestOperation(bridge: bridge, request: opRequest, remoteOperationQueue: settings.remoteOperationQueue, computeOperationQueue: settings.computeOperationQueue, startedOnContext: autoStart)
			op.completionBlock = { /* We keep a strong ref to op but it’s not a problem because we nullify the completion block at the end of the block. */
				DispatchQueue.main.async{
					handler(op.result)
				}
				op.completionBlock = nil /* In theory not needed anymore; I never tested that… */
			}
			if autoStart {
				op.start() /* RequestOperations usually do not need to be queued at all: they mostly queue other operations and don’t do much on their own. */
			}
			return op
		}
	}
	
	/**
	 Same as createAndSave, but does not try and get the created object back.
	 
	 This is useful when the API does not return the same type of object as the one being created. */
	@discardableResult
	@available(macOS 10.15, tvOS 13, iOS 13, watchOS 6, *)
	func createSaved<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		savedObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object
	) async throws -> Bridge.RequestResults {
		return try await withCheckedThrowingContinuation{ continuation in
			do {
				try createSaved(
					objectType,
					requestUserInfo: requestUserInfo,
					settings: settings, autoStart: true,
					savedObjectCreator: savedObjectCreator,
					handler: { res in
						continuation.resume(with: res)
					}
				)
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
	
}
