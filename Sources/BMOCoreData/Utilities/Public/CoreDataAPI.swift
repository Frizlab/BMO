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



public protocol CoreDataAPIDefaultsSettings {
	
	associatedtype Bridge : BridgeProtocol where Bridge.LocalDb.DbObject == NSManagedObject,
																Bridge.LocalDb.DbContext == NSManagedObjectContext
	
	static var remoteOperationQueue: OperationQueue {get}
	static var computeOperationQueue: OperationQueue {get}
	
	static var remoteIDPropertyName: String {get}
	static var requestUserInfo: Bridge.RequestUserInfo {get}
	
	static var fetchRequestToBridgeRequest: (NSFetchRequest<NSManagedObject>) -> Bridge.LocalDb.DbRequest {get}
	
}


public struct CoreDataAPI<Bridge : BridgeProtocol, DefaultSettings : CoreDataAPIDefaultsSettings> where DefaultSettings.Bridge == Bridge {
	
	public struct Settings {
		
		public var remoteOperationQueue: OperationQueue
		public var computeOperationQueue: OperationQueue
		
		public var remoteIDPropertyName: String
		public var requestUserInfo: Bridge.RequestUserInfo
		
		public var fetchRequestToBridgeRequest: (NSFetchRequest<NSManagedObject>) -> Bridge.LocalDb.DbRequest
		
		public init() {
			self.remoteOperationQueue  = DefaultSettings.remoteOperationQueue
			self.computeOperationQueue = DefaultSettings.computeOperationQueue
			
			self.remoteIDPropertyName = DefaultSettings.remoteIDPropertyName
			self.requestUserInfo      = DefaultSettings.requestUserInfo
			
			self.fetchRequestToBridgeRequest = DefaultSettings.fetchRequestToBridgeRequest
		}
		
		public init(
			remoteOperationQueue: OperationQueue,
			computeOperationQueue: OperationQueue,
			remoteIDPropertyName: String,
			requestUserInfo: Bridge.RequestUserInfo,
			fetchRequestToBridgeRequest: @escaping (NSFetchRequest<NSManagedObject>) -> Bridge.LocalDb.DbRequest
		) {
			self.remoteOperationQueue = remoteOperationQueue
			self.computeOperationQueue = computeOperationQueue
			
			self.remoteIDPropertyName = remoteIDPropertyName
			self.requestUserInfo = requestUserInfo
			
			self.fetchRequestToBridgeRequest = fetchRequestToBridgeRequest
		}
		
	}
	
	public var bridge: Bridge
	public var localDb: Bridge.LocalDb
	
	/**
	 Create and return the `RequestOperation` corresponding to a fetch request.
	 
	 The request is auto-started by default, out of a queue.
	 Most of the time `RequestOperation`s do not need to be queued at all as they mostly queue other operations and don’t do much on their own.
	 If you have specific needs you can set `autoStart` to false and queue the operation yourself.
	 
	 - Important: Do not set the `completionBlock` of the operation if you want the handler to be called (otherwise it’s fine). */
	public func remoteFetch<Object : NSManagedObject>(objectType: Object.Type = Object.self, remoteID: Bridge.LocalDb.UniquingID, settings: Settings = .init(), autoStart: Bool = true, handler: @escaping @Sendable @MainActor (_ results: Result<Bridge.RequestResults, Error>) -> Void = { _ in }) -> RequestOperation<Bridge> {
		let fRequest = Object.fetchRequest()
		fRequest.predicate = NSPredicate(format: "%K == %@", settings.remoteIDPropertyName, String(describing: remoteID))
		fRequest.fetchLimit = 1
		let bridgeRequest = settings.fetchRequestToBridgeRequest(fRequest as! NSFetchRequest<NSManagedObject>)
		let opRequest = Request(localDb: localDb, localRequest: bridgeRequest, remoteUserInfo: settings.requestUserInfo)
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
	
}
