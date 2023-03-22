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



public struct CoreDataAPI<Bridge : BridgeProtocol> where Bridge.LocalDb.DbContext == NSManagedObjectContext {
	
	public struct Settings {
		
		public var remoteOperationQueue: OperationQueue
		public var computeOperationQueue: OperationQueue
		
		public var remoteIDPropertyName: String
		
		public var fetchRequestToBridgeRequest: (NSFetchRequest<NSFetchRequestResult>, RemoteFetchType) -> Bridge.LocalDb.DbRequest
		public var createObjectBridgeRequest: (NSManagedObject, BMOCoreDataSaveRequestHelper<Bridge.Metadata>.SaveWorkflow) -> Bridge.LocalDb.DbRequest
		public var updateObjectBridgeRequest: (NSManagedObject, BMOCoreDataSaveRequestHelper<Bridge.Metadata>.SaveWorkflow) -> Bridge.LocalDb.DbRequest
		public var deleteObjectBridgeRequest: (NSManagedObject, BMOCoreDataSaveRequestHelper<Bridge.Metadata>.SaveWorkflow) -> Bridge.LocalDb.DbRequest
		
		public init(
			remoteOperationQueue: OperationQueue,
			computeOperationQueue: OperationQueue,
			remoteIDPropertyName: String,
			fetchRequestToBridgeRequest: @escaping (NSFetchRequest<NSFetchRequestResult>, RemoteFetchType) -> Bridge.LocalDb.DbRequest,
			createObjectBridgeRequest: @escaping (NSManagedObject, BMOCoreDataSaveRequestHelper<Bridge.Metadata>.SaveWorkflow) -> Bridge.LocalDb.DbRequest,
			updateObjectBridgeRequest: @escaping (NSManagedObject, BMOCoreDataSaveRequestHelper<Bridge.Metadata>.SaveWorkflow) -> Bridge.LocalDb.DbRequest,
			deleteObjectBridgeRequest: @escaping (NSManagedObject, BMOCoreDataSaveRequestHelper<Bridge.Metadata>.SaveWorkflow) -> Bridge.LocalDb.DbRequest
		) {
			self.remoteOperationQueue = remoteOperationQueue
			self.computeOperationQueue = computeOperationQueue
			
			self.remoteIDPropertyName = remoteIDPropertyName
			
			self.fetchRequestToBridgeRequest = fetchRequestToBridgeRequest
			self.createObjectBridgeRequest = createObjectBridgeRequest
			self.updateObjectBridgeRequest = updateObjectBridgeRequest
			self.deleteObjectBridgeRequest = deleteObjectBridgeRequest
		}
		
	}
	
	public var bridge: Bridge
	public var localDb: Bridge.LocalDb
	
	public var defaultSettings: Settings
	public var defaultRequestUserInfo: Bridge.RequestUserInfo
	
	public init(bridge: Bridge, localDb: Bridge.LocalDb, defaultSettings: Settings, defaultRequestUserInfo: Bridge.RequestUserInfo) {
		self.bridge = bridge
		self.localDb = localDb
		
		self.defaultSettings = defaultSettings
		self.defaultRequestUserInfo = defaultRequestUserInfo
	}
	
	/**
	 Create and return the `RequestOperation` corresponding to a fetch request.
	 
	 The request is auto-started by default, out of a queue.
	 Most of the time `RequestOperation`s do not need to be queued at all as they mostly queue other operations and don’t do much on their own.
	 If you have specific needs you can set `autoStart` to false and queue the operation yourself.
	 
	 - Important: Do not set the `completionBlock` of the operation if you want the handler to be called (otherwise it’s fine). */
	@discardableResult
	public func remoteFetch(
		_ fetchRequest: NSFetchRequest<NSFetchRequestResult>,
		fetchType: RemoteFetchType = .always,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		handler: @escaping @Sendable @MainActor (_ results: Result<Bridge.RequestResults, RequestError<Bridge>>) -> Void = { _ in }
	) -> RequestOperation<Bridge> {
		let settings = settings ?? defaultSettings
		let requestUserInfo = requestUserInfo ?? defaultRequestUserInfo
		
		let bridgeRequest = settings.fetchRequestToBridgeRequest(fetchRequest, fetchType)
		let opRequest = Request(localDb: localDb, localRequest: bridgeRequest, remoteUserInfo: requestUserInfo)
		let op = RequestOperation(bridge: bridge, request: opRequest, remoteOperationQueue: settings.remoteOperationQueue, computeOperationQueue: settings.computeOperationQueue)
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
	
	/**
	 Create and return the `RequestOperation` corresponding to a fetch of a specific object.
	 
	 The request is auto-started by default, out of a queue.
	 Most of the time `RequestOperation`s do not need to be queued at all as they mostly queue other operations and don’t do much on their own.
	 If you have specific needs you can set `autoStart` to false and queue the operation yourself.
	 
	 - Important: Do not set the `completionBlock` of the operation if you want the handler to be called (otherwise it’s fine). */
	@discardableResult
	public func remoteFetch<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		remoteID: Bridge.LocalDb.UniquingID,
		fetchType: RemoteFetchType = .always,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		handler: @escaping @Sendable @MainActor (_ results: Result<Bridge.RequestResults, RequestError<Bridge>>) -> Void = { _ in }
	) -> RequestOperation<Bridge> {
		let fRequest = Object.fetchRequest()
		fRequest.predicate = NSPredicate(format: "%K == %@", (settings ?? defaultSettings).remoteIDPropertyName, String(describing: remoteID))
		fRequest.fetchLimit = 1
		return remoteFetch(fRequest, fetchType: fetchType, requestUserInfo: requestUserInfo, settings: settings, autoStart: autoStart, handler: handler)
	}
	
	@discardableResult
	public func updateAndSave<Object : NSManagedObject>(
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
			let op = RequestOperation(bridge: bridge, request: opRequest, remoteOperationQueue: settings.remoteOperationQueue, computeOperationQueue: settings.computeOperationQueue, startedOnContext: true)
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
	public func updateAndSave<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		objectID: NSManagedObjectID,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		discardableUpdates: @escaping @Sendable (_ object: Object, _ managedObjectContext: NSManagedObjectContext) throws -> Void
	) async throws -> Bridge.RequestResults {
		return try await withCheckedThrowingContinuation{ continuation in
			do {
				try updateAndSave(
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
	
	@discardableResult
	public func createAndSaveNoRetrievalOfCreated<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		discardableObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object,
		handler: @escaping @Sendable @MainActor (Result<Bridge.RequestResults, RequestError<Bridge>>) -> Void = { _ in }
	) throws -> RequestOperation<Bridge> {
		let settings = settings ?? defaultSettings
		let requestUserInfo = requestUserInfo ?? defaultRequestUserInfo
		
		let discardableContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		discardableContext.parent = localDb.context
		
		return try discardableContext.performAndWaitRW{
			let discardableObject = try discardableObjectCreator(discardableContext)
			
			let bridgeRequest = settings.createObjectBridgeRequest(discardableObject, .doNothingChangeImportContext(localDb.context))
			let opRequest = Request(localDb: localDb, localDbContextOverwrite: discardableContext, localRequest: bridgeRequest, remoteUserInfo: requestUserInfo)
			let op = RequestOperation(bridge: bridge, request: opRequest, remoteOperationQueue: settings.remoteOperationQueue, computeOperationQueue: settings.computeOperationQueue, startedOnContext: true)
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
	
	/**
	 Same as createAndSave, but does not try and get the created object back.
	 
	 This is useful when the API does not return the same type of object as the one being created. */
	@discardableResult
	@available(macOS 10.15, tvOS 13, iOS 13, watchOS 6, *)
	public func createAndSaveNoRetrievalOfCreated<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		discardableObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object
	) async throws -> Bridge.RequestResults {
		return try await withCheckedThrowingContinuation{ continuation in
			do {
				try createAndSaveNoRetrievalOfCreated(
					objectType,
					requestUserInfo: requestUserInfo,
					settings: settings, autoStart: true,
					discardableObjectCreator: discardableObjectCreator,
					handler: { res in
						continuation.resume(with: res)
					}
				)
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
	
	@discardableResult
	public func createAndSave<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		discardableObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object,
		handler: @escaping @Sendable @MainActor (Result<(createdObject: Object, results: Bridge.RequestResults), Error>) -> Void = { _ in }
	) throws -> RequestOperation<Bridge> {
		return try createAndSaveNoRetrievalOfCreated(objectType, requestUserInfo: requestUserInfo, settings: settings, autoStart: autoStart, discardableObjectCreator: discardableObjectCreator, handler: { results in
			do {
				let result = try results.get()
				guard let importedObjects = result.dbChanges?.importedObjects,
						let createdObject = importedObjects.first?.object as? Object,
						importedObjects.count == 1
				else {
					throw Err.creationRequestResultDoesNotContainObject
				}
				handler(.success((createdObject, result)))
			} catch {
				handler(.failure(error))
			}
		})
	}
	
	@discardableResult
	@available(macOS 10.15, tvOS 13, iOS 13, watchOS 6, *)
	public func createAndSave<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		discardableObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object
	) async throws -> (createdObject: Object, results: Bridge.RequestResults) {
		return try await withCheckedThrowingContinuation{ continuation in
			do {
				try createAndSave(
					objectType,
					requestUserInfo: requestUserInfo,
					settings: settings, autoStart: true,
					discardableObjectCreator: discardableObjectCreator,
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
