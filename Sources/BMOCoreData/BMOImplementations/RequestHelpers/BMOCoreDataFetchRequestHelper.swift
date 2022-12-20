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
	
	public enum FetchType {
		case always
		case onlyIfNoLocalResults
		case never
	}
	
	public typealias LocalDbObject = NSManagedObject
	
	public var request: NSFetchRequest<NSFetchRequestResult>
	public var context: NSManagedObjectContext
	public var fetchType: FetchType
	
	public init(request: NSFetchRequest<NSFetchRequestResult>, context: NSManagedObjectContext, fetchType: FetchType) {
		self.request = request
		self.context = context
		self.fetchType = fetchType
	}
	
	public func onContext_requestNeedsRemote() throws -> Bool {
		/* Note:
		 * We might wanna avoid fetching the entity if it is already set, however, it is difficult checking whether the entity has been set:
		 *  if the property is accessed before being set, an (objc) execption is thrown… */
		request.entity = context.persistentStoreCoordinator!.managedObjectModel.entitiesByName[request.entityName!]
		switch fetchType {
			case .always:               return true
			case .onlyIfNoLocalResults: return try context.count(for: request) == 0
			case .never:                return false
		}
	}
	
	public func onContext_failedRemoteConversion(_ error: Error) {
	}
	
	public func onContext_willGoRemote() throws {
	}
	
	public func onContext_willImportRemoteResults() throws -> Bool {
		return true
	}
	
	public func onContext_didImportRemoteResults(_ importChanges: LocalDbChanges<NSManagedObject, Metadata>) throws {
		try context.save()
	}
	
	public func onContext_didFailImportingRemoteResults(_ error: Error) {
		context.rollback()
	}
	
}
