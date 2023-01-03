/*
Copyright 2022 happn

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



public struct BMOCoreDataFetchRequestHelper<Metadata> : RequestHelperProtocol {
	
	public typealias LocalDbObject = NSManagedObject
	
	public var request: NSFetchRequest<NSFetchRequestResult>
	public var context: NSManagedObjectContext
	public var fetchType: RemoteFetchType
	
	public init(request: NSFetchRequest<NSFetchRequestResult>, context: NSManagedObjectContext, fetchType: RemoteFetchType) {
		self.request = request
		self.context = context
		self.fetchType = fetchType
	}
	
	/* *****************************************************************
	   MARK: Request Lifecycle Part 1: Local Request to Remote Operation
	   ***************************************************************** */
	
	public func onContext_localToRemote_prepareRemoteConversion(cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		switch fetchType {
			case .always: return true
			case .never:  return false
				
			case .onlyIfNoLocalResults:
				/* Note:
				 * We might wanna avoid fetching the entity if it is already set, however, it is difficult checking whether the entity has been set:
				 *  if the property is accessed before being set, an (objc) execption is thrown… */
				request.entity = context.persistentStoreCoordinator!.managedObjectModel.entitiesByName[request.entityName!]
				return try context.count(for: request) == 0
				
			case let .custom(handler):
				request.entity = context.persistentStoreCoordinator!.managedObjectModel.entitiesByName[request.entityName!]
				return try handler(request)
		}
	}
	
	public func onContext_localToRemote_willGoRemote(cancellationCheck throwIfCancelled: () throws -> Void) throws {
	}
	
	public func onContext_localToRemoteFailed(_ error: Error) {
	}
	
	/* ************************************************************
	   MARK: Request Lifecycle Part 2: Receiving the Remote Results
	   ************************************************************ */
	
	public func remoteFailed(_ error: Error) {
	}
	
	/* *******************************************************************
	   MARK: Request Lifecycle Part 3: Local Db Representation to Local Db
	   ******************************************************************* */
	
	public func onContext_remoteToLocal_willImportRemoteResults(cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		assert(!context.hasChanges)
		return true
	}
	
	public func onContext_remoteToLocal_didImportRemoteResults(_ importChanges: LocalDbChanges<NSManagedObject, Metadata>, cancellationCheck throwIfCancelled: () throws -> Void) throws {
		try context.save()
	}
	
	public func onContext_remoteToLocalFailed(_ error: Error) {
		context.rollback()
	}
	
}
