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



public struct BMOCoreDataSaveRequestHelper<Metadata> : RequestHelperProtocol {
	
	public enum SaveWorkflow {
		
		case saveBeforeBackReturns
		/* TODO: Implement this.
		 * - Because we want to always have a non-modified Core Data view context, we have to allow using this workflow from a child context.
		 * - When using a sub-context, the back results are not imported because the importer we use today do not support sub-contexts (no inter-context locking).
		 *   A modification to BMO would allow us to change the importer per request part. */
//		case saveAfterBackReturns
		case rollbackBeforeBackReturns
		case doNothing
		
	}
	
	public typealias LocalDbObject = NSManagedObject
	
	public var context: NSManagedObjectContext
	public var saveWorkflow: SaveWorkflow
	
	public init(context: NSManagedObjectContext, saveWorkflow: SaveWorkflow) {
		self.context = context
		self.saveWorkflow = saveWorkflow
	}
	
	public func onContext_requestNeedsRemote() throws -> Bool {
		context.processPendingChanges()
		return true
	}
	
	public func onContext_failedRemoteConversion(_ error: Error) {
		context.rollback()
	}
	
	public func onContext_willGoRemote() throws {
		switch saveWorkflow {
			case .doNothing:                 (/*nop*/)
			case .saveBeforeBackReturns:     try context.save()
			case .rollbackBeforeBackReturns: context.rollback()
		}
	}
	
	public func onContext_willImportRemoteResults() throws -> Bool {
		/* We do not support sub-context with our current importers. */
		guard context.parent == nil else {
			context.saveToDiskOrRollback();
			return false
		}
		return true
	}
	
	public func onContext_didImportRemoteResults(_ importChanges: LocalDbChanges<NSManagedObject, Metadata>) throws {
		assert(context.parent == nil)
		context.saveToDiskOrRollback()
	}
	
	public func onContext_didFailImportingRemoteResults(_ error: Error) {
		context.rollback()
	}
	
}
