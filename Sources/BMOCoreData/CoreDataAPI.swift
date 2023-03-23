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
	
}
