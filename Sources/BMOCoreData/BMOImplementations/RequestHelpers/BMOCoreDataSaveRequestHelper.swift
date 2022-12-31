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
		 *
		 * Note:
		 * To implement this (properly), we might have to move the importer creation from the bridge to the helper………
		 *  which is annoying because of all the types the importer brings with him.
		 * Maybe another helper (ImporterFactory) would be required instead? idk
		 *
		 * Another (much easier) solution would be to give the original request to the bridge when asking to create the importer.
		 * After all it’s already the bridge that decides what helper to use for a given request, it would make sense the proper importer should be chosen also by the bridge. */
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
	
	/* *****************************************************************
	   MARK: Request Lifecycle Part 1: Local Request to Remote Operation
	   ***************************************************************** */
	
	public func onContext_localToRemote_prepareRemoteConversion(cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		context.processPendingChanges()
		return true
	}
	
	public func onContext_localToRemote_willGoRemote(cancellationCheck throwIfCancelled: () throws -> Void) throws {
		switch saveWorkflow {
			case .doNothing:                 (/*nop*/)
			case .saveBeforeBackReturns:     try context.save()
			case .rollbackBeforeBackReturns: context.rollback()
		}
	}
	
	public func onContext_localToRemoteFailed(_ error: Error) {
		switch saveWorkflow {
			case .doNothing:
				(/*nop*/)
				
			case .saveBeforeBackReturns, .rollbackBeforeBackReturns:
				/* We have to rollback even in the case of “rollbackBeforeBackReturns” save workflow in case the error happened before the “will go remote” step is reached. */
				context.rollback()
		}
	}
	
	/* ************************************************************
	   MARK: Request Lifecycle Part 2: Receiving the Remote Results
	   ************************************************************ */
	
	public func remoteFailed(_ error: Error) {
		/* nop: either we’re in the “do nothing” workflow in which case we do nothing, or the save/rollback happened before the remote operation was started.
		 * Of course, when (if) we implement saveAfterBackReturns we’ll have to rollback here if this save workflow is chosen. */
	}
	
	/* *******************************************************************
	   MARK: Request Lifecycle Part 3: Local Db Representation to Local Db
	   ******************************************************************* */
	
	public func onContext_remoteToLocal_willImportRemoteResults(cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		/* We do not support sub-context with our current importers. */
		guard context.parent == nil else {
			context.saveToDiskOrRollback()
			return false
		}
		assert(!context.hasChanges || saveWorkflow == .doNothing)
		return true
	}
	
	public func onContext_remoteToLocal_didImportRemoteResults(_ importChanges: LocalDbChanges<NSManagedObject, Metadata>, cancellationCheck throwIfCancelled: () throws -> Void) throws {
		assert(context.parent == nil)
		try context.save()
	}
	
	public func onContext_remoteToLocalFailed(_ error: Error) {
		context.rollback()
	}
	
}
