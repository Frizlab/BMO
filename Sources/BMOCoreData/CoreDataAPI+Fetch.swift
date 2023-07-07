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
	
	/**
	 Create and return the `RequestOperation` corresponding to a fetch request.
	 
	 The request is auto-started by default, out of a queue.
	 Most of the time `RequestOperation`s do not need to be queued at all as they mostly queue other operations and don’t do much on their own.
	 If you have specific needs you can set `autoStart` to false and queue the operation yourself.
	 
	 - Important: Do not set the `completionBlock` of the operation if you want the handler to be called (otherwise it’s fine). */
	@discardableResult
	func fetch(
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
			op.start() /* RequestOperations usually do not need to be queued at all: they mostly queue other operations and don’t do much on their own. */
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
	func fetch<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		remoteID: Bridge.LocalDb.UniquingID,
		fetchType: RemoteFetchType = .always,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		handler: @escaping @Sendable @MainActor (_ results: Result<Bridge.RequestResults, RequestError<Bridge>>) -> Void = { _ in }
	) -> RequestOperation<Bridge> {
		let fRequest = Object.fetchRequest()
		fRequest.predicate = NSPredicate(format: "%K == %@", argumentArray: [(settings ?? defaultSettings).remoteIDPropertyName, remoteID])
		fRequest.fetchLimit = 1
		return fetch(fRequest, fetchType: fetchType, requestUserInfo: requestUserInfo, settings: settings, autoStart: autoStart, handler: handler)
	}
	
}
